#!/usr/bin/env bash
# app-image-manager — AppImage/archive package manager for GitHub releases
# Author: Michael DeGuzis
# Usage: app-image-manager <command> <org/repo|name> [options]
#
# Supports AppImage releases and tar.gz/zip archives containing native binaries.
# All apps live at a constant ~/Applications/<name>.AppImage path so
# non-Steam game shortcuts never need updating after an upgrade.

set -euo pipefail

# ── Paths ──────────────────────────────────────────────────────────────────────
APPS_DIR="${HOME}/Applications"
BACKUP_DIR="${APPS_DIR}/backup"
LIB_DIR="${HOME}/.local/share/app-image-manager"   # extracted archive contents
CONFIG_DIR="${HOME}/.config/app-image-manager"
APPS_CONF="${CONFIG_DIR}/apps.conf"
DESKTOP_DIR="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor"

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info() { echo -e "${CYAN}[aim]${NC} $*"; }
log_ok()   { echo -e "${GREEN}[aim]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[aim]${NC} $*"; }
log_err()  { echo -e "${RED}[aim]${NC} $*" >&2; }

# ── Init ───────────────────────────────────────────────────────────────────────
init_dirs() {
    mkdir -p "${APPS_DIR}" "${BACKUP_DIR}" "${LIB_DIR}" "${CONFIG_DIR}" "${DESKTOP_DIR}"
    [[ -f "${APPS_CONF}" ]] || touch "${APPS_CONF}"
}

# ── Input parsing ──────────────────────────────────────────────────────────────
# Strip GitHub URL prefix, return bare "org/repo"
parse_repo_input() {
    local input="$1"
    input="${input#https://github.com/}"
    input="${input#http://github.com/}"
    input="${input%.git}"
    echo "$input"
}

# Derive a lowercase filesystem-safe name from "org/repo" (uses repo part only)
derive_name() {
    local repo="$1"
    echo "${repo##*/}" | tr '[:upper:]' '[:lower:]'
}

# Given a name or org/repo or URL, echo "name|repo".
# Returns 1 if it's a bare name and not in the registry.
resolve_app() {
    local input="$1"
    local name repo

    if [[ "$input" == */* || "$input" == *github.com* ]]; then
        repo=$(parse_repo_input "$input")
        name=$(derive_name "$repo")
    else
        name="$input"
        repo=$(grep "^${name}=" "${APPS_CONF}" 2>/dev/null | cut -d= -f2- | head -1)
        [[ -n "$repo" ]] || return 1
    fi
    echo "${name}|${repo}"
}

# ── App registry ───────────────────────────────────────────────────────────────
register_app() {
    local name="$1" repo="$2"
    grep -q "^${name}=" "${APPS_CONF}" 2>/dev/null || echo "${name}=${repo}" >> "${APPS_CONF}"
}

remove_app_registration() {
    sed -i "/^${1}=/d" "${APPS_CONF}" 2>/dev/null || true
}

get_installed_version() {
    local ver_file="${CONFIG_DIR}/${1}.version"
    [[ -f "$ver_file" ]] && cat "$ver_file" || true
}

set_installed_version() {
    echo "$2" > "${CONFIG_DIR}/${1}.version"
}

set_install_type() {
    echo "$2" > "${CONFIG_DIR}/${1}.type"
}

get_install_type() {
    local type_file="${CONFIG_DIR}/${1}.type"
    if [[ -f "$type_file" ]]; then
        cat "$type_file"
    elif [[ -d "${LIB_DIR}/${1}" ]]; then
        echo "archive"
    elif [[ -f "${APPS_DIR}/${1}.AppImage" ]]; then
        echo "appimage"
    else
        echo "unknown"
    fi
}

# ── GitHub API ─────────────────────────────────────────────────────────────────
get_latest_release_info() {
    local repo="$1"
    local resp
    resp=$(curl -fsSL \
        ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} \
        "https://api.github.com/repos/${repo}/releases/latest")
    if echo "$resp" | grep -q '"API rate limit exceeded"'; then
        log_err "GitHub API rate limit exceeded. Set GITHUB_TOKEN env var to raise limits."
        exit 1
    fi
    echo "$resp"
}

get_latest_tag() {
    local json="$1"
    if command -v jq &>/dev/null; then
        echo "$json" | jq -r '.tag_name // empty'
    else
        echo "$json" | grep -o '"tag_name": "[^"]*"' | head -1 | sed 's/.*": "\(.*\)"/\1/'
    fi
}

# ── Arch helpers ───────────────────────────────────────────────────────────────
arch_patterns() {
    case "$(uname -m)" in
        x86_64)  echo "x86_64 linux-x64 linux_x64 amd64 x64" ;;
        aarch64) echo "aarch64 linux-arm64 linux_arm64 arm64" ;;
        armv7l)  echo "armv7l arm" ;;
        *)       uname -m ;;
    esac
}

# ── Asset selection ────────────────────────────────────────────────────────────
# Returns "url|type" where type is: appimage, targz, zip
get_best_asset() {
    local json="$1"
    local patterns
    read -r -a patterns <<< "$(arch_patterns)"

    _find_asset() {
        local pat="$1"
        if command -v jq &>/dev/null; then
            echo "$json" | jq -r --arg p "$pat" \
                '[.assets[] | select(.name | test($p;"i")) | .browser_download_url] | first // empty'
        else
            echo "$json" | grep -o '"browser_download_url": "[^"]*"' \
                | grep -i "$pat" | head -1 | sed 's/.*": "\(.*\)"/\1/'
        fi
    }

    local url="" type=""

    # Prefer AppImage → tar.gz → zip; prefer arch-specific over generic
    # Single backslash in single-quotes: '\.ext$' → jq/grep sees literal-dot regex
    for ext_pat in '\.AppImage$' '\.tar\.gz$' '\.zip$'; do
        local ext_type
        case "$ext_pat" in
            *AppImage*) ext_type="appimage" ;;
            *tar*)      ext_type="targz" ;;
            *)          ext_type="zip" ;;
        esac

        for arch in "${patterns[@]}"; do
            url=$(_find_asset "${arch}.*${ext_pat}")
            [[ -n "$url" ]] && type="$ext_type" && break 2
        done
        url=$(_find_asset "$ext_pat")
        [[ -n "$url" ]] && type="$ext_type" && break
    done

    [[ -n "$url" ]] && echo "${url}|${type}" || true
}

# ── Desktop integration ────────────────────────────────────────────────────────
install_desktop_entry() {
    local name="$1" launcher_path="$2" search_dir="${3:-}"
    local tmp_dir="" cleanup_tmp=0 gen_desktop=""

    if [[ -z "$search_dir" ]]; then
        tmp_dir=$(mktemp -d)
        cleanup_tmp=1
        log_info "Extracting AppImage for desktop integration..."
        if ! (cd "$tmp_dir" && "$launcher_path" --appimage-extract >/dev/null 2>&1); then
            log_warn "AppImage extraction failed; skipping desktop integration."
            rm -rf "$tmp_dir"
            return 0
        fi
        search_dir="${tmp_dir}/squashfs-root"
    fi

    local desktop_src
    desktop_src=$(find "$search_dir" -maxdepth 4 -name "*.desktop" 2>/dev/null | head -1)

    if [[ -z "$desktop_src" ]]; then
        log_warn "No .desktop file found; generating minimal entry."
        gen_desktop=$(mktemp --suffix=.desktop)
        local display_name
        display_name=$(echo "$name" | sed 's/-/ /g; s/\b./\u&/g')
        cat > "$gen_desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${display_name}
Exec=${launcher_path}
Icon=${name}
Categories=Utility;
Terminal=false
EOF
        desktop_src="$gen_desktop"
    fi

    # Install icon if present
    local icon_name
    icon_name=$(grep "^Icon=" "$desktop_src" | head -1 | cut -d= -f2- | tr -d '[:space:]')
    local icon_src=""
    if [[ -n "$icon_name" ]]; then
        icon_src=$(find "$search_dir" -name "${icon_name}.png" 2>/dev/null | head -1)
        [[ -z "$icon_src" ]] && icon_src=$(find "$search_dir" -name "${icon_name}.svg" 2>/dev/null | head -1)
    fi
    [[ -z "$icon_src" ]] && icon_src=$(find "$search_dir" -name "*.png" 2>/dev/null | head -1)
    [[ -z "$icon_src" ]] && icon_src=$(find "$search_dir" -name "*.svg" 2>/dev/null | head -1)

    if [[ -n "$icon_src" ]]; then
        local ext="${icon_src##*.}"
        local icon_dest_dir="${ICON_DIR}/256x256/apps"
        mkdir -p "$icon_dest_dir"
        cp "$icon_src" "${icon_dest_dir}/${name}.${ext}"
        gtk-update-icon-cache -f -t "${ICON_DIR}" 2>/dev/null || true
        log_ok "Icon installed: ${icon_dest_dir}/${name}.${ext}"
    fi

    local desktop_dest="${DESKTOP_DIR}/${name}.desktop"
    sed \
        -e "s|^Exec=.*|Exec=${launcher_path}|" \
        -e "s|^Icon=.*|Icon=${name}|" \
        "$desktop_src" > "$desktop_dest"
    chmod +x "$desktop_dest"
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    log_ok "Desktop entry installed: ${desktop_dest}"

    [[ $cleanup_tmp -eq 1 ]] && rm -rf "$tmp_dir"
    [[ -n "$gen_desktop" ]] && rm -f "$gen_desktop"
}

# ── Session detection ──────────────────────────────────────────────────────────
# Returns 0 (true) if the current session is SteamOS/Bazzite Gaming Mode
is_gaming_mode() {
    # Gamescope session systemd unit active (most reliable on SteamOS/Bazzite)
    systemctl --user is-active gamescope-session.service &>/dev/null && return 0
    systemctl --user is-active gamescope-session-plus@steamos.service &>/dev/null && return 0
    # STEAM_GAMEPADUI flag set in a running Steam process environment
    local steam_pid
    steam_pid=$(pgrep -x steam 2>/dev/null | head -1)
    if [[ -n "$steam_pid" ]]; then
        grep -q "STEAM_GAMEPADUI=1" "/proc/${steam_pid}/environ" 2>/dev/null && return 0
    fi
    # XDG_CURRENT_DESKTOP hint (gamescope sets this)
    [[ "${XDG_CURRENT_DESKTOP:-}" == "gamescope" ]] && return 0
    return 1
}

steam_restart_hint() {
    if is_gaming_mode; then
        log_warn "You are in Gaming Mode. Switch to Desktop Mode, restart Steam,"
        log_warn "then switch back for the shortcut to appear in your library."
    else
        log_warn "Restart Steam for the shortcut to appear in your library."
    fi
}

# ── Steam shortcut integration ─────────────────────────────────────────────────
# Finds all shortcuts.vdf files under Steam userdata (handles multiple accounts)
find_shortcuts_vdf() {
    # Collect unique real paths to avoid double-counting symlinks
    find \
        "${HOME}/.local/share/Steam/userdata" \
        "${HOME}/.steam/steam/userdata" \
        "${HOME}/.steam/root/userdata" \
        -maxdepth 3 -name "shortcuts.vdf" 2>/dev/null \
    -maxdepth 3 \
    | while read -r vdf; do realpath "$vdf" 2>/dev/null || echo "$vdf"; done \
    | sort -u
}

steam_add_shortcut() {
    local name="$1" launcher="$2" icon="${3:-}"

    local display_name
    display_name=$(echo "$name" | sed 's/-/ /g; s/\b./\u&/g')
    local start_dir
    start_dir=$(dirname "$launcher")

    # Resolve icon path if not given
    if [[ -z "$icon" ]]; then
        icon=$(find "${ICON_DIR}" -name "${name}.*" 2>/dev/null | head -1)
    fi

    local vdf_files
    mapfile -t vdf_files < <(find_shortcuts_vdf)

    if [[ ${#vdf_files[@]} -eq 0 ]]; then
        log_warn "No shortcuts.vdf found — Steam may not be installed or never launched."
        return 1
    fi

    for vdf in "${vdf_files[@]}"; do
        log_info "Adding Steam shortcut in: ${vdf}"
        python3 - "$vdf" "$display_name" "$launcher" "$start_dir" "$icon" <<'PYEOF'
import sys, struct, zlib, os, shutil, time

vdf_path, app_name, exe, start_dir, icon = sys.argv[1:6]

def gen_appid(exe, name):
    # Matches Steam's CRC-based non-Steam appid algorithm
    key = exe + name
    top = zlib.crc32(key.encode('utf-8')) | 0x80000000
    return top & 0xFFFFFFFF

def pack_str(key, val):
    return b'\x01' + key.encode() + b'\x00' + val.encode() + b'\x00'

def pack_int(key, val):
    return b'\x02' + key.encode() + b'\x00' + struct.pack('<I', val)

def build_entry(idx, app_name, exe, start_dir, icon):
    appid = gen_appid(exe, app_name)
    entry = (
        b'\x00' + str(idx).encode() + b'\x00' +
        pack_int('appid',              appid) +
        pack_str('AppName',            app_name) +
        pack_str('Exe',                exe) +
        pack_str('StartDir',           start_dir) +
        pack_str('icon',               icon) +
        pack_str('ShortcutPath',       '') +
        pack_str('LaunchOptions',      '') +
        pack_int('IsHidden',           0) +
        pack_int('AllowDesktopConfig', 1) +
        pack_int('AllowOverlay',       1) +
        pack_int('OpenVR',             0) +
        pack_int('Devkit',             0) +
        pack_str('DevkitGameID',       '') +
        pack_int('DevkitOverrideAppID',0) +
        pack_int('LastPlayTime',       int(time.time())) +
        pack_str('FlatpakAppID',       '') +
        b'\x00tags\x00\x08\x08'
    )
    return entry

# Read existing file (or create minimal skeleton if missing/empty)
if os.path.exists(vdf_path) and os.path.getsize(vdf_path) > 4:
    with open(vdf_path, 'rb') as f:
        data = f.read()
else:
    # Minimal valid shortcuts.vdf: \x00shortcuts\x00 ... \x08\x08
    data = b'\x00shortcuts\x00\x08\x08'

# Check if this app is already registered (by AppName)
if app_name.encode() in data:
    print(f"[aim] Steam shortcut for '{app_name}' already exists, skipping.")
    sys.exit(0)

# Count existing entries to get next index
import re
existing = re.findall(rb'\x00(\d+)\x00', data)
next_idx = len(existing)

new_entry = build_entry(next_idx, app_name, exe, start_dir, icon)

# Backup and write
shutil.copy2(vdf_path, vdf_path + '.bak')
# Insert before final \x08\x08
if data.endswith(b'\x08\x08'):
    data = data[:-2] + new_entry + b'\x08\x08'
else:
    data = data + new_entry + b'\x08\x08'

with open(vdf_path, 'wb') as f:
    f.write(data)

print(f"[aim] Steam shortcut added: '{app_name}'")
PYEOF
    done

    steam_restart_hint
}

steam_remove_shortcut() {
    local name="$1"
    local display_name
    display_name=$(echo "$name" | sed 's/-/ /g; s/\b./\u&/g')

    local vdf_files
    mapfile -t vdf_files < <(find_shortcuts_vdf)
    if [[ ${#vdf_files[@]} -eq 0 ]]; then
        log_warn "No shortcuts.vdf found; skipping Steam shortcut removal."
        return 0
    fi

    for vdf in "${vdf_files[@]}"; do
        log_info "Removing Steam shortcut from: ${vdf}"
        python3 - "$vdf" "$display_name" <<'PYEOF'
import sys, re, os, shutil

vdf_path = sys.argv[1]
target_name = sys.argv[2]

with open(vdf_path, 'rb') as f:
    data = f.read()

HEADER = b'\x00shortcuts\x00'
if not data.startswith(HEADER):
    print("Unexpected shortcuts.vdf format", file=sys.stderr)
    sys.exit(1)

needle = b'\x01AppName\x00' + target_name.encode() + b'\x00'
pos = data.find(needle)
if pos == -1:
    print(f"[aim] '{target_name}' not found in Steam shortcuts, skipping.")
    sys.exit(0)

# Walk backward from AppName to find the entry start (\x00<digits>\x00)
entry_start = None
for i in range(pos - 1, len(HEADER) - 1, -1):
    if data[i] == 0x00:
        j = i + 1
        while j < len(data) and 0x30 <= data[j] <= 0x39:
            j += 1
        if j > i + 1 and j < len(data) and data[j] == 0x00:
            entry_start = i
            break

if entry_start is None:
    print("Could not locate entry start", file=sys.stderr)
    sys.exit(1)

# Entry ends after \x00tags\x00\x08\x08
tags_pos = data.find(b'\x00tags\x00', pos)
if tags_pos == -1:
    print("Could not locate tags dict", file=sys.stderr)
    sys.exit(1)

# Skip past \x00tags\x00 then find \x08\x08 (end-of-tags + end-of-entry)
entry_end = data.find(b'\x08\x08', tags_pos)
if entry_end == -1:
    print("Could not locate entry end", file=sys.stderr)
    sys.exit(1)
entry_end += 2  # include the \x08\x08

shutil.copy2(vdf_path, vdf_path + '.bak')
with open(vdf_path, 'wb') as f:
    f.write(data[:entry_start] + data[entry_end:])

print(f"[aim] Steam shortcut removed: '{target_name}'")
PYEOF
    done
}

remove_desktop_entry() {
    local name="$1"
    rm -f "${DESKTOP_DIR}/${name}.desktop"
    find "${ICON_DIR}" -name "${name}.*" -delete 2>/dev/null || true
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    log_ok "Desktop entry/icon removed for ${name}."
}

# ── Install helpers ────────────────────────────────────────────────────────────
_install_appimage() {
    local name="$1" url="$2" tag="$3"
    local appimage_path="${APPS_DIR}/${name}.AppImage"
    local tmp_file
    tmp_file=$(mktemp "${APPS_DIR}/.${name}-XXXXXX.AppImage")

    log_info "Downloading AppImage..."
    if ! curl -fL --progress-bar -o "$tmp_file" "$url"; then
        log_err "Download failed."
        rm -f "$tmp_file"
        exit 1
    fi

    chmod +x "$tmp_file"
    mv "$tmp_file" "$appimage_path"
    set_installed_version "$name" "$tag"
    set_install_type "$name" "appimage"
    log_ok "${name} ${tag} → ${appimage_path}"

    install_desktop_entry "$name" "$appimage_path"
}

_install_archive() {
    local name="$1" url="$2" tag="$3" type="$4"
    local extract_dir="${LIB_DIR}/${name}"
    local launcher="${APPS_DIR}/${name}.AppImage"
    local tmp_file
    tmp_file=$(mktemp)

    log_info "Downloading archive..."
    if ! curl -fL --progress-bar -o "$tmp_file" "$url"; then
        log_err "Download failed."
        rm -f "$tmp_file"
        exit 1
    fi

    rm -rf "${extract_dir}"
    mkdir -p "${extract_dir}"

    log_info "Extracting to ${extract_dir}..."
    if [[ "$type" == "targz" ]]; then
        tar -xzf "$tmp_file" -C "${extract_dir}" --strip-components=0
    else
        unzip -q "$tmp_file" -d "${extract_dir}"
    fi
    rm -f "$tmp_file"

    # Find the main executable: match repo/app name first.
    # Don't require -executable; tarballs often strip the bit (we chmod +x below).
    local search_pat
    search_pat=$(echo "$name" | tr -d '-' | tr '[:upper:]' '[:lower:]')

    local main_bin=""
    # 1. Name match, exclude known non-binary extensions
    main_bin=$(find "${extract_dir}" -maxdepth 2 -type f \
        ! -name "*.so" ! -name "*.so.*" ! -name "*.json" \
        ! -name "*.xml"  ! -name "*.txt" ! -name "*.md" \
        | grep -i "$search_pat" | head -1 || true)
    # 2. Already-executable file (some archives do preserve the bit)
    if [[ -z "$main_bin" ]]; then
        main_bin=$(find "${extract_dir}" -maxdepth 2 -type f -executable \
            ! -name "*.so" ! -name "*.so.*" | head -1 || true)
    fi
    # 3. Largest non-config file (binary is usually the biggest file)
    if [[ -z "$main_bin" ]]; then
        main_bin=$(find "${extract_dir}" -maxdepth 2 -type f \
            ! -name "*.so" ! -name "*.so.*" ! -name "*.json" \
            ! -name "*.xml" ! -name "*.txt" ! -name "*.md" \
            | xargs ls -S 2>/dev/null | head -1 || true)
    fi

    if [[ -z "$main_bin" ]]; then
        log_err "Could not find executable in archive. Contents:"
        find "${extract_dir}" -maxdepth 3 | head -20
        exit 1
    fi

    chmod +x "$main_bin"
    log_ok "Main binary: ${main_bin}"

    # Wrapper at constant path — cd + LD_LIBRARY_PATH for bundled .so files
    local app_dir bin_name
    app_dir=$(dirname "$main_bin")
    bin_name=$(basename "$main_bin")
    cat > "$launcher" <<LAUNCHER
#!/usr/bin/env bash
# Auto-generated by app-image-manager — do not edit manually
APP_DIR="${app_dir}"
export LD_LIBRARY_PATH="\${APP_DIR}\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}"
cd "\${APP_DIR}"
exec "\${APP_DIR}/${bin_name}" "\$@"
LAUNCHER
    chmod +x "$launcher"

    set_installed_version "$name" "$tag"
    set_install_type "$name" "archive-${type}"
    log_ok "${name} ${tag} → ${launcher} (wraps ${main_bin})"

    install_desktop_entry "$name" "$launcher" "${extract_dir}"
}

_backup_existing() {
    local name="$1"
    local launcher="${APPS_DIR}/${name}.AppImage"
    local extract_dir="${LIB_DIR}/${name}"

    if [[ -f "$launcher" ]]; then
        cp "$launcher" "${BACKUP_DIR}/${name}.AppImage"
        log_info "Backed up launcher → ${BACKUP_DIR}/${name}.AppImage"
    fi
    if [[ -d "$extract_dir" ]]; then
        rm -rf "${BACKUP_DIR}/${name}"
        cp -r "$extract_dir" "${BACKUP_DIR}/${name}"
        log_info "Backed up archive contents → ${BACKUP_DIR}/${name}/"
    fi
}

_fetch_and_install() {
    local name="$1" repo="$2" release_json="${3:-}"

    if [[ -z "$release_json" ]]; then
        log_info "Fetching latest release info for ${repo}..."
        release_json=$(get_latest_release_info "$repo")
    fi

    local latest_tag
    latest_tag=$(get_latest_tag "$release_json")
    if [[ -z "$latest_tag" ]]; then
        log_err "Could not determine latest tag for ${repo}"
        exit 1
    fi

    local asset_info
    asset_info=$(get_best_asset "$release_json")
    if [[ -z "$asset_info" ]]; then
        log_err "No supported asset found in ${repo} release ${latest_tag}"
        log_err "Looked for: .AppImage, .tar.gz, .zip"
        exit 1
    fi

    local url type
    url="${asset_info%%|*}"
    type="${asset_info##*|}"

    log_info "Asset: ${type} — ${url}"

    case "$type" in
        appimage)  _install_appimage "$name" "$url" "$latest_tag" ;;
        targz|zip) _install_archive  "$name" "$url" "$latest_tag" "$type" ;;
    esac
}

# ── Commands ───────────────────────────────────────────────────────────────────
cmd_install() {
    local input="${1:?'GitHub repo required: org/repo or https://github.com/org/repo'}"
    local add_steam=0
    # Parse flags from remaining args
    shift
    for arg in "$@"; do
        [[ "$arg" == "--steam" ]] && add_steam=1
    done

    local repo name
    repo=$(parse_repo_input "$input")
    name=$(derive_name "$repo")

    local launcher="${APPS_DIR}/${name}.AppImage"
    if [[ -f "$launcher" ]]; then
        log_warn "${name} is already installed ($(get_installed_version "$name")). Use 'reinstall' or 'update'."
        exit 0
    fi

    log_info "Installing ${name} from ${repo}..."
    _fetch_and_install "$name" "$repo"
    register_app "$name" "$repo"

    if [[ $add_steam -eq 1 ]]; then
        steam_add_shortcut "$name" "$launcher"
    fi
}

cmd_update() {
    local input="${1:-}"
    if [[ -n "$input" ]]; then
        _update_one "$input"
    else
        _update_all_interactive
    fi
}

_update_one() {
    local input="$1"
    local info name repo
    info=$(resolve_app "$input") || {
        log_err "'${input}' not found in registry. Install it first."
        exit 1
    }
    name="${info%%|*}"; repo="${info##*|}"

    local launcher="${APPS_DIR}/${name}.AppImage"
    if [[ ! -f "$launcher" ]]; then
        log_warn "${name} is not installed. Use 'install' first."
        exit 1
    fi

    log_info "Checking ${name}..."
    local release_json latest_tag installed
    release_json=$(get_latest_release_info "$repo")
    latest_tag=$(get_latest_tag "$release_json")
    installed=$(get_installed_version "$name")

    if [[ "$latest_tag" == "$installed" ]]; then
        log_ok "${name} is already up to date (${installed})."
        return 0
    fi

    log_info "Upgrading ${name}: ${installed:-unknown} → ${latest_tag}"
    _backup_existing "$name"
    _fetch_and_install "$name" "$repo" "$release_json"
}

_update_all_interactive() {
    if [[ ! -s "${APPS_CONF}" ]]; then
        log_warn "No managed apps. Install something first."
        return 0
    fi

    log_info "Checking for updates..."
    echo ""
    printf "  %-24s %-32s %-32s %s\n" "APP" "INSTALLED" "LATEST" "STATUS"
    printf "  %-24s %-32s %-32s %s\n" "---" "---------" "------" "------"

    # Collect release info for all apps first, then print table
    declare -A _pending_name   # index → name
    declare -A _pending_repo   # index → repo
    declare -A _pending_json   # index → release_json
    declare -A _pending_tag    # index → latest_tag
    local idx=0

    while IFS='=' read -r name repo; do
        [[ -z "$name" ]] && continue
        local release_json latest_tag installed status_str
        release_json=$(get_latest_release_info "$repo")
        latest_tag=$(get_latest_tag "$release_json")
        installed=$(get_installed_version "$name")

        if [[ "$latest_tag" == "$installed" ]]; then
            status_str="up to date"
            printf "  %-24s %-32s %-32s \033[0;32m%s\033[0m\n" \
                "$name" "${installed:-(unknown)}" "$latest_tag" "$status_str"
        else
            status_str="update available"
            printf "  %-24s %-32s %-32s \033[1;33m%s\033[0m\n" \
                "$name" "${installed:-(none)}" "${latest_tag:-(unknown)}" "$status_str"
            _pending_name[$idx]="$name"
            _pending_repo[$idx]="$repo"
            _pending_json[$idx]="$release_json"
            _pending_tag[$idx]="$latest_tag"
            idx=$(( idx + 1 ))
        fi
    done < <(sort "${APPS_CONF}")

    echo ""

    if [[ $idx -eq 0 ]]; then
        log_ok "All apps are up to date."
        return 0
    fi

    printf "\033[1;33m%d update(s) available.\033[0m Apply? [y/N] " "$idx"
    read -r answer
    [[ "$answer" =~ ^[Yy]$ ]] || { log_info "Aborted."; return 0; }
    echo ""

    local i
    for (( i=0; i<idx; i++ )); do
        local n="${_pending_name[$i]}" r="${_pending_repo[$i]}"
        local installed
        installed=$(get_installed_version "$n")
        log_info "Upgrading ${n}: ${installed:-none} → ${_pending_tag[$i]}"
        _backup_existing "$n"
        _fetch_and_install "$n" "$r" "${_pending_json[$i]}"
    done

    log_ok "Done."
}

cmd_reinstall() {
    local input="${1:?'app name or org/repo required'}"
    local info name repo
    info=$(resolve_app "$input") || {
        log_err "'${input}' not found in registry. Install it first."
        exit 1
    }
    name="${info%%|*}"; repo="${info##*|}"

    _backup_existing "$name"
    rm -f "${APPS_DIR}/${name}.AppImage"
    rm -rf "${LIB_DIR}/${name}"
    _fetch_and_install "$name" "$repo"
}


cmd_uninstall() {
    local input="${1:?'app name or org/repo required'}"
    local info name repo
    info=$(resolve_app "$input") || {
        log_err "'${input}' not found in registry."
        exit 1
    }
    name="${info%%|*}"; repo="${info##*|}"

    if [[ ! -f "${APPS_DIR}/${name}.AppImage" && ! -d "${LIB_DIR}/${name}" ]]; then
        log_warn "${name} is not installed."
        exit 0
    fi

    rm -f "${APPS_DIR}/${name}.AppImage"
    rm -rf "${LIB_DIR}/${name}"
    rm -f "${BACKUP_DIR}/${name}.AppImage"
    rm -rf "${BACKUP_DIR}/${name}"
    rm -f "${CONFIG_DIR}/${name}.version"
    rm -f "${CONFIG_DIR}/${name}.type"
    remove_app_registration "$name"
    remove_desktop_entry "$name"
    steam_remove_shortcut "$name"
    log_ok "${name} uninstalled."
}


cmd_list() {
    echo ""
    printf "  %-24s %-30s %-12s %s\n" "APP" "VERSION" "TYPE" "LAUNCHER"
    printf "  %-24s %-30s %-12s %s\n" "---" "-------" "----" "--------"

    if [[ ! -s "${APPS_CONF}" ]]; then
        echo "  (no apps installed)"
        echo ""
        return 0
    fi

    while IFS='=' read -r name repo; do
        [[ -z "$name" ]] && continue
        local ver type launcher
        ver=$(get_installed_version "$name")
        type=$(get_install_type "$name")
        launcher="${APPS_DIR}/${name}.AppImage"
        [[ -f "$launcher" ]] || launcher="(missing)"
        printf "  %-24s %-30s %-12s %s\n" \
            "$name" \
            "${ver:-(not installed)}" \
            "$type" \
            "${launcher/$HOME/\~}"
    done < <(sort "${APPS_CONF}")
    echo ""
}

cmd_view() {
    local input="${1:?'app name or org/repo required'}"
    local info name repo
    info=$(resolve_app "$input") || {
        log_err "'${input}' not found in registry."
        exit 1
    }
    name="${info%%|*}"; repo="${info##*|}"

    local ver type launcher install_date
    ver=$(get_installed_version "$name")
    type=$(get_install_type "$name")
    launcher="${APPS_DIR}/${name}.AppImage"

    # Install date from mtime of version file
    local ver_file="${CONFIG_DIR}/${name}.version"
    if [[ -f "$ver_file" ]]; then
        install_date=$(date -r "$ver_file" "+%Y-%m-%d %H:%M" 2>/dev/null || stat -c "%y" "$ver_file" | cut -d. -f1)
    else
        install_date="unknown"
    fi

    # Check for latest version (hits GitHub API)
    local latest_tag update_status
    log_info "Checking latest release..."
    local release_json
    release_json=$(get_latest_release_info "$repo")
    latest_tag=$(get_latest_tag "$release_json")
    if [[ -n "$ver" && "$latest_tag" == "$ver" ]]; then
        update_status="${GREEN}up to date${NC}"
    elif [[ -n "$latest_tag" && "$latest_tag" != "$ver" ]]; then
        update_status="${YELLOW}update available: ${latest_tag}${NC}"
    else
        update_status="unknown"
    fi

    # Desktop entry
    local desktop="${DESKTOP_DIR}/${name}.desktop"
    local desktop_status
    [[ -f "$desktop" ]] && desktop_status="${desktop/$HOME/\~}" || desktop_status="${RED}not installed${NC}"

    # Icon
    local icon_path
    icon_path=$(find "${ICON_DIR}" -name "${name}.*" 2>/dev/null | head -1)
    local icon_status
    [[ -n "$icon_path" ]] && icon_status="${icon_path/$HOME/\~}" || icon_status="${YELLOW}not found${NC}"

    # Extracted dir (archive-based)
    local extract_dir="${LIB_DIR}/${name}"
    local extract_status=""
    if [[ -d "$extract_dir" ]]; then
        local size
        size=$(du -sh "$extract_dir" 2>/dev/null | cut -f1)
        extract_status="${extract_dir/$HOME/\~}  (${size})"
    fi

    # Launcher size
    local launcher_size=""
    if [[ -f "$launcher" ]]; then
        launcher_size=$(du -sh "$launcher" 2>/dev/null | cut -f1)
    fi

    # Backup
    local backup_status=""
    local backup_launcher="${BACKUP_DIR}/${name}.AppImage"
    local backup_dir="${BACKUP_DIR}/${name}"
    if [[ -f "$backup_launcher" ]]; then
        backup_status="${backup_launcher/$HOME/\~}"
    elif [[ -d "$backup_dir" ]]; then
        backup_status="${backup_dir/$HOME/\~}/"
    else
        backup_status="${YELLOW}none${NC}"
    fi

    local SEP="  ────────────────────────────────────────────────────"
    echo ""
    echo -e "  ${CYAN}${name}${NC}"
    echo -e "$SEP"
    printf "  %-16s %s\n"  "Repo:"          "${repo}"
    printf "  %-16s %s\n"  "GitHub:"        "https://github.com/${repo}"
    printf "  %-16s %s\n"  "Installed:"     "${ver:-(none)}"
    echo -e "  $(printf '%-16s' 'Latest:')   $(echo -e "${update_status}")"
    printf "  %-16s %s\n"  "Install date:"  "${install_date}"
    printf "  %-16s %s\n"  "Type:"          "${type}"
    echo -e "$SEP"
    printf "  %-16s %s\n"  "Launcher:"      "${launcher/$HOME/\~}${launcher_size:+  (${launcher_size})}"
    [[ -n "$extract_status" ]] && \
        printf "  %-16s %s\n" "Extract dir:"  "${extract_status}"
    echo -e "  $(printf '%-16s' 'Desktop:')"  "$(echo -e "${desktop_status}")"
    echo -e "  $(printf '%-16s' 'Icon:')"     "$(echo -e "${icon_status}")"
    echo -e "$SEP"
    echo -e "  $(printf '%-16s' 'Backup:')"   "$(echo -e "${backup_status}")"
    echo ""
}

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF

app-image-manager (aim) — AppImage/archive package manager for GitHub releases

Usage:
  app-image-manager install <org/repo|URL> [--steam]  Install; --steam adds a Steam shortcut
  app-image-manager reinstall <name|org/repo>         Force reinstall latest version
  app-image-manager update [name|org/repo]            Check and apply updates (all if no arg)
  app-image-manager uninstall <name|org/repo>         Remove app, launcher, desktop entry, icon
  app-image-manager list                              List all installed apps with location/type
  app-image-manager view <name|org/repo>              Full metadata (checks for updates)
  app-image-manager steam-add <name|org/repo>         Add an already-installed app to Steam

Examples:
  app-image-manager install Optiscaler-Client/Optiscaler-Client
  app-image-manager install Optiscaler-Client/Optiscaler-Client --steam
  app-image-manager update
  app-image-manager update optiscaler-client
  app-image-manager uninstall optiscaler-client
  app-image-manager steam-add optiscaler-client

The app name is derived from the repo name (lowercased).
Install once; upgrade/uninstall by that short name thereafter.

Paths:
  ~/Applications/<name>.AppImage           constant launcher (safe for non-Steam shortcuts)
  ~/Applications/backup/                   previous version backup
  ~/.local/share/app-image-manager/<name>  extracted archive contents (non-AppImage releases)

Supported asset types (preference order): .AppImage > .tar.gz > .zip
Architecture: $(uname -m) → tries $(arch_patterns | tr ' ' '/')

EOF
}

# ── Entry point ────────────────────────────────────────────────────────────────
# --help/-h wins no matter where it appears in the args
for _arg in "$@"; do
    [[ "$_arg" == "-h" || "$_arg" == "--help" ]] && usage && exit 0
done

init_dirs

case "${1:-}" in
    install)    cmd_install "${2:-}" "${@:3}" ;;
    reinstall)  cmd_reinstall "${2:-}" ;;
    update)     cmd_update "${2:-}" ;;
    uninstall)  cmd_uninstall "${2:-}" ;;
    list)       cmd_list ;;
    view)       cmd_view "${2:-}" ;;
    steam-add)
        input="${2:?'app name or org/repo required'}"
        info=$(resolve_app "$input") || { log_err "'${input}' not found in registry."; exit 1; }
        n="${info%%|*}"
        steam_add_shortcut "$n" "${APPS_DIR}/${n}.AppImage"
        ;;
    -h|--help)  usage ;;
    *)          usage; exit 1 ;;
esac
