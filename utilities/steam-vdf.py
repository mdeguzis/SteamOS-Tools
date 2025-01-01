#!/usr/bin/env python

import argparse
import datetime
import json
import logging
import os
import platform
import readline
import shutil
import subprocess
import time
import vdf
from pathlib import Path


def get_non_steam_usage(steam_path):
    """Get sizes of directories on same drive as Steam, excluding Steam directory"""
    steam_path = os.path.abspath(steam_path)
    home_dir = str(Path.home())
    parent_dir = os.path.dirname(steam_path)
    sizes = []

    for entry in os.scandir(parent_dir):
        if entry.is_dir() and entry.path != steam_path:
            try:
                total = 0
                for dirpath, dirnames, filenames in os.walk(entry.path):
                    try:
                        for f in filenames:
                            fp = os.path.join(dirpath, f)
                            if not os.path.islink(fp):
                                total += os.path.getsize(fp)
                    except (PermissionError, FileNotFoundError):
                        continue

                if total > 0:  # Only include if it has size
                    sizes.append(
                        {"path": entry.path, "size": total / (1024**3)}  # Convert to GB
                    )
            except (PermissionError, FileNotFoundError):
                continue

    return sorted(sizes, key=lambda x: x["size"], reverse=True)


def restart_steam():
    """
    Prompt user to restart Steam and handle the restart process
    """
    try:
        restart = (
            input("\nWould you like to restart Steam now? (y/N): ").strip().lower()
        )
        if restart == "y":
            print("\nRestarting Steam...")
            logger.info("User requested Steam restart")

            # Kill existing Steam process
            try:
                subprocess.run(["killall", "steam"], check=True)
                logger.info("Successfully terminated Steam process")
            except subprocess.CalledProcessError:
                logger.warning("No Steam process found to terminate")
            except Exception as e:
                logger.error(f"Error terminating Steam: {str(e)}")
                return False

            # Wait a moment for Steam to fully close
            time.sleep(2)

            # Start Steam in background
            try:
                subprocess.Popen(
                    ["steam"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True,
                )
                logger.info("Successfully started Steam")
                print("Steam is restarting...")
                return True
            except Exception as e:
                logger.error(f"Error starting Steam: {str(e)}")
                print("Error starting Steam. Please restart manually.")
                return False
        else:
            print("\nPlease restart Steam manually for changes to take effect.")
            return False
    except (KeyboardInterrupt, EOFError):
        logger.info("\nRestart operation cancelled by user")
        print("\nPlease restart Steam manually for changes to take effect.")
        return False


def dump_vdf_to_json(vdf_data, vdf_path):
    """
    Dump VDF data to JSON file in /tmp directory
    The JSON filename will include the source directory (steamapps or config)
    """

    if not args.dump_vdfs:
        return

    if not args.dump_vdfs:
        return

    # Get the base filename and parent directory
    base_name = os.path.basename(vdf_path)
    parent_dir = os.path.basename(os.path.dirname(vdf_path))

    # If it's libraryfolders.vdf, use parent directory in name
    if base_name == "libraryfolders.vdf":
        json_filename = f"steam-{parent_dir}-vdf.json"
    else:
        # For other files (like loginusers.vdf), use the base name without .vdf
        json_filename = f"steam-{os.path.splitext(base_name)[0]}.json"

    json_path = os.path.join("/tmp", json_filename)

    try:
        with open(json_path, "w", encoding="utf-8") as f:
            json.dump(vdf_data, f, indent=4)
        logger.info(f"VDF data ({base_name}) dumped to JSON at: {json_path}")
        return True
    except Exception as e:
        logger.error(f"Error dumping VDF to JSON: {str(e)}")
        return False


def delete_shortcut(library_path):
    """
    Delete an existing shortcut after selecting user and shortcut
    """
    userdata_path = os.path.join(library_path, "userdata")
    if not os.path.exists(userdata_path):
        logger.error(f"No userdata directory found at: {userdata_path}")
        return False

    user_dirs = [
        d
        for d in os.listdir(userdata_path)
        if os.path.isdir(os.path.join(userdata_path, d))
    ]

    if not user_dirs:
        logger.error("No Steam users found in userdata directory")
        return False

    user_names = get_steam_user_names(library_path)

    # Present user selection
    print("\nAvailable Steam users:")
    for idx, user_dir in enumerate(user_dirs, 1):
        user_info = user_names.get(
            user_dir,
            {"PersonaName": "Unknown Account", "AccountName": "Unknown Account"},
        )
        persona_name = user_info["PersonaName"]
        account_name = user_info["AccountName"]

        if account_name != "Unknown Account":
            print(f"{idx}. {persona_name} ({account_name})")
        else:
            print(f"{idx}. {persona_name}")

    # Get user selection
    while True:
        try:
            choice = input("\nEnter user number: ").strip()
            if not choice:
                logger.error("No user selected")
                return False

            choice_idx = int(choice) - 1
            if 0 <= choice_idx < len(user_dirs):
                selected_user = user_dirs[choice_idx]
                break
            else:
                print("Invalid selection. Please try again.")
        except ValueError:
            print("Please enter a valid number.")
        except (KeyboardInterrupt, EOFError):
            logger.info("\nOperation cancelled by user")
            return False

    shortcuts_vdf = os.path.join(
        userdata_path, selected_user, "config", "shortcuts.vdf"
    )

    if not os.path.exists(shortcuts_vdf):
        logger.error("No shortcuts.vdf file found")
        return False

    try:
        with open(shortcuts_vdf, "rb") as f:
            shortcuts = vdf.binary_load(f)

        if not shortcuts or "shortcuts" not in shortcuts:
            logger.error("No shortcuts found")
            return False

        # Show available shortcuts
        print("\nAvailable shortcuts:")
        print("-" * 50)

        shortcut_list = []
        for idx, shortcut in shortcuts["shortcuts"].items():
            shortcut_list.append((idx, shortcut))
            print(f"\n{len(shortcut_list)}. {shortcut.get('AppName', 'Unknown')}:")
            print(f"   Executable: {shortcut.get('Exe', 'Unknown').strip('\"')}")
            print(
                f"   Start Directory: {shortcut.get('StartDir', 'Unknown').strip('\"')}"
            )

        print("\n" + "-" * 50)

        # Get shortcut selection
        while True:
            try:
                choice = input(
                    "\nEnter number of shortcut to delete (or 'q' to quit): "
                ).strip()
                if choice.lower() == "q":
                    logger.info("Delete operation cancelled by user")
                    return False

                choice_idx = int(choice) - 1
                if 0 <= choice_idx < len(shortcut_list):
                    shortcut_id = shortcut_list[choice_idx][0]
                    shortcut_name = shortcuts["shortcuts"][shortcut_id].get(
                        "AppName", "Unknown"
                    )

                    # Confirm deletion
                    confirm = (
                        input(
                            f"\nAre you sure you want to delete '{shortcut_name}'? (y/N): "
                        )
                        .strip()
                        .lower()
                    )
                    if confirm != "y":
                        logger.info("Delete operation cancelled by user")
                        return False

                    # Delete the shortcut
                    del shortcuts["shortcuts"][shortcut_id]

                    # Save the modified shortcuts back to file
                    with open(shortcuts_vdf, "wb") as f:
                        vdf.binary_dump(shortcuts, f)

                    logger.info(f"Successfully deleted shortcut: {shortcut_name}")
                    print(f"\nSuccessfully deleted shortcut: {shortcut_name}")

                    # Dump updated shortcuts to JSON
                    json_path = os.path.join(
                        "/tmp", f"steam-shortcuts-{selected_user}.json"
                    )
                    with open(json_path, "w", encoding="utf-8") as f:
                        json.dump(shortcuts, f, indent=4)
                    logger.info(f"Updated shortcuts dumped to JSON at: {json_path}")

                    return True
                else:
                    print("Invalid selection. Please try again.")
            except ValueError:
                print("Please enter a valid number.")
            except (KeyboardInterrupt, EOFError):
                logger.info("\nOperation cancelled by user")
                return False
            except Exception as e:
                logger.error(f"Error deleting shortcut: {str(e)}")
                return False

    except Exception as e:
        logger.error(f"Error reading shortcuts file: {str(e)}")
        return False


def list_shortcuts(library_path):
    """
    List existing non-Steam game shortcuts
    """
    userdata_path = os.path.join(library_path, "userdata")
    if not os.path.exists(userdata_path):
        logger.error(f"No userdata directory found at: {userdata_path}")
        return False

    user_dirs = [
        d
        for d in os.listdir(userdata_path)
        if os.path.isdir(os.path.join(userdata_path, d))
    ]

    if not user_dirs:
        logger.error("No Steam users found in userdata directory")
        return False

    user_names = get_steam_user_names(library_path)

    for user_dir in user_dirs:
        shortcuts_vdf = os.path.join(userdata_path, user_dir, "config", "shortcuts.vdf")

        # Get user info
        user_info = user_names.get(
            user_dir,
            {"PersonaName": "Unknown Account", "AccountName": "Unknown Account"},
        )
        persona_name = user_info["PersonaName"]
        account_name = user_info["AccountName"]

        if account_name != "Unknown Account":
            print(f"\nShortcuts for user: {persona_name} ({account_name})")
        else:
            print(f"\nShortcuts for user: {persona_name}")

        if os.path.exists(shortcuts_vdf):
            print(f"Loading shortcuts from: {shortcuts_vdf}")
            try:
                with open(shortcuts_vdf, "rb") as f:
                    shortcuts = vdf.binary_load(f)

                if not shortcuts or "shortcuts" not in shortcuts:
                    print("  No shortcuts found")
                    continue

                print("\n  Found shortcuts:")
                print("  " + "-" * 50)

                # The negative App IDs in Steam shortcuts are intentionally used to
                # avoid conflicts with real Steam games, which use positive IDs.
                # The negative IDs are generated using a hash of the shortcut's
                # properties to create a unique identifier.
                for idx, shortcut in shortcuts["shortcuts"].items():
                    print(f"\n  Shortcut #{idx}:")
                    print(f"    Name: {shortcut.get('AppName', 'Unknown')}")
                    print(
                        f"    Executable: {shortcut.get('Exe', 'Unknown').strip('\"')}"
                    )
                    print(
                        f"    Start Directory: {shortcut.get('StartDir', 'Unknown').strip('\"')}"
                    )
                    print(f"    App ID: {shortcut.get('appid', 'Unknown')}")

                    launch_options = shortcut.get("LaunchOptions", "")
                    if launch_options:
                        print(f"    Launch Options: {launch_options}")

                    # Show if hidden
                    if shortcut.get("IsHidden", 0) == 1:
                        print("    [Hidden]")

                    # Show icon path if it exists
                    if shortcut.get("icon"):
                        print(f"    Icon: {shortcut.get('icon')}")

                    # Show tags if any
                    tags = shortcut.get("tags", {})
                    if tags:
                        print("    Tags:", ", ".join(tags.values()))
                print()
            except Exception as e:
                logger.error(
                    f"Error reading shortcuts for user {persona_name}: {str(e)}"
                )
                print(f"  Error reading shortcuts: {str(e)}")
        else:
            print("  No shortcuts.vdf file found")

    return True


def steam64_to_steam32(steam64_id):
    """Convert Steam64 ID to Steam32 ID"""
    try:
        return str(int(steam64_id) - 76561197960265728)
    except (ValueError, TypeError):
        return None


def steam32_to_steam64(steam32_id):
    """Convert Steam32 ID to Steam64 ID"""
    try:
        return str(int(steam32_id) + 76561197960265728)
    except (ValueError, TypeError):
        return None


def get_steam_user_names(steam_path):
    """
    Get Steam account names from both loginusers.vdf and config.vdf
    Returns a dictionary mapping user IDs to account names
    """
    logger.debug("Attempting to read Steam user names")
    user_names = {}

    # Read from loginusers.vdf first
    login_file = os.path.join(steam_path, "config", "loginusers.vdf")

    try:
        if os.path.exists(login_file):
            with open(login_file, "r", encoding="utf-8") as f:
                login_data = vdf.load(f)
                dump_vdf_to_json(login_data, login_file)

            if "users" in login_data:
                for steam64_id, user_data in login_data["users"].items():
                    # Convert Steam64 ID to Steam32 ID
                    steam32_id = steam64_to_steam32(steam64_id)
                    if steam32_id:
                        user_names[steam32_id] = {
                            "PersonaName": user_data.get(
                                "PersonaName", "Unknown Account"
                            ),
                            "AccountName": user_data.get(
                                "AccountName", "Unknown Account"
                            ),
                            "Steam64ID": steam64_id,
                        }
                        logger.debug(
                            f"Found user in loginusers.vdf: Steam64:{steam64_id} -> Steam32:{steam32_id}"
                        )

                    # Also store under Steam64 ID
                    user_names[steam64_id] = {
                        "PersonaName": user_data.get("PersonaName", "Unknown Account"),
                        "AccountName": user_data.get("AccountName", "Unknown Account"),
                        "Steam32ID": steam32_id,
                    }
    except Exception as e:
        logger.error(f"Error reading loginusers.vdf: {str(e)}")

    # Then try config.vdf for additional info
    config_file = os.path.join(steam_path, "config", "config.vdf")
    try:
        if os.path.exists(config_file):
            with open(config_file, "r", encoding="utf-8") as f:
                config_data = vdf.load(f)
                dump_vdf_to_json(config_data, config_file)

            # Process config data...
            if "InstallConfigStore" in config_data:
                if "Software" in config_data["InstallConfigStore"]:
                    if "Valve" in config_data["InstallConfigStore"]["Software"]:
                        if (
                            "Steam"
                            in config_data["InstallConfigStore"]["Software"]["Valve"]
                        ):
                            steam_config = config_data["InstallConfigStore"][
                                "Software"
                            ]["Valve"]["Steam"]

                            if "Accounts" in steam_config:
                                for user_id, account_data in steam_config[
                                    "Accounts"
                                ].items():
                                    # Try both Steam32 and Steam64 IDs
                                    steam64_id = steam32_to_steam64(user_id)
                                    if steam64_id in user_names:
                                        # We already have this user from loginusers.vdf
                                        continue

                                    # If we don't have this user yet, add them
                                    user_names[user_id] = {
                                        "PersonaName": account_data.get(
                                            "PersonaName", "Unknown Account"
                                        ),
                                        "AccountName": account_data.get(
                                            "AccountName", "Unknown Account"
                                        ),
                                        "Steam64ID": steam64_id,
                                    }
    except Exception as e:
        logger.error(f"Error reading config.vdf: {str(e)}")

    return user_names


def get_installed_games(library_path):
    apps_path = os.path.join(library_path, "steamapps")
    installed_games = []

    if os.path.exists(apps_path):
        for file in os.listdir(apps_path):
            if file.startswith("appmanifest_"):
                manifest_path = os.path.join(apps_path, file)
                try:
                    with open(manifest_path, "r", encoding="utf-8") as f:
                        manifest = vdf.load(f)
                        app_data = manifest.get("AppState", {})
                        installed_games.append(
                            {
                                "name": app_data.get("name", "Unknown"),
                                "app_id": app_data.get("appid", "Unknown"),
                                "size": int(app_data.get("SizeOnDisk", 0))
                                / (1024 * 1024 * 1024),  # Convert to GB
                            }
                        )
                except Exception as e:
                    logger.error(f"Error reading manifest {file}: {str(e)}")

    return installed_games


def get_library_storage_info(library_path):
    try:
        total, used, free = shutil.disk_usage(library_path)
        return {
            "total": total // (1024 * 1024 * 1024),  # GB
            "used": used // (1024 * 1024 * 1024),
            "free": free // (1024 * 1024 * 1024),
        }
    except Exception as e:
        logger.error(f"Error getting storage info: {str(e)}")
        return None


def get_recent_games(userdata_path, user_id):
    config_path = os.path.join(userdata_path, user_id, "config", "localconfig.vdf")
    recent_games = []

    if os.path.exists(config_path):
        try:
            with open(config_path, "r", encoding="utf-8") as f:
                config = vdf.load(f)
                if (
                    "Software" in config
                    and "Valve" in config["Software"]
                    and "Steam" in config["Software"]["Valve"]
                ):
                    steam_config = config["Software"]["Valve"]["Steam"]
                    if "apps" in steam_config:
                        for app_id, app_data in steam_config["apps"].items():
                            if "LastPlayed" in app_data:
                                recent_games.append(
                                    {
                                        "app_id": app_id,
                                        "last_played": datetime.datetime.fromtimestamp(
                                            int(app_data["LastPlayed"])
                                        ),
                                    }
                                )
        except Exception as e:
            logger.error(f"Error reading localconfig.vdf: {str(e)}")

    return sorted(recent_games, key=lambda x: x["last_played"], reverse=True)[
        :5
    ]  # Return top 5


def analyze_storage(steam_library):
    storage_info = get_library_storage_info(steam_library)
    if storage_info:
        print("\nStorage Information:")
        print(f"Total: {storage_info['total']} GB")
        print(f"Used: {storage_info['used']} GB")
        print(f"Free: {storage_info['free']} GB")

    print("\nInstalled Games (Top 20 by size):")
    installed_games = get_installed_games(steam_library)
    if installed_games:
        # Sort the games list by size in descending order and take top 20
        sorted_games = sorted(installed_games, key=lambda x: x["size"], reverse=True)[
            :20
        ]
        total_size = sum(
            game["size"] for game in installed_games
        )  # Calculate total from ALL games
        for game in sorted_games:
            print(f"- {game['name']} (ID: {game['app_id']}) - {game['size']:.2f} GB")
        print(f"\nTotal space used by all games: {total_size:.2f} GB")
    else:
        print("No games installed")

    # Add the non-Steam usage display
    print("\nLargest Non-Steam Directories (Top 20):")
    print("-" * 60)
    sizes = get_non_steam_usage(steam_library)
    if sizes:
        total_non_steam = sum(item["size"] for item in sizes)
        for item in sizes[:20]:
            # Get relative path from home directory if possible
            home = str(Path.home())
            display_path = item["path"].replace(home, "~")
            print(f"{display_path:<50} {item['size']:.2f} GB")
        print("-" * 60)
        print(f"Total size of all non-Steam directories: {total_non_steam:.2f} GB")
    else:
        print("No accessible non-Steam directories found")


def get_user_info():
    # user account display code
    userdata_path = os.path.join(selected_library, "userdata")
    if os.path.exists(userdata_path):
        user_dirs = [
            d
            for d in os.listdir(userdata_path)
            if os.path.isdir(os.path.join(userdata_path, d))
        ]

        if user_dirs:
            user_names = get_steam_user_names(selected_library)
            print("\nSteam Accounts:")
            for user_dir in user_dirs:
                # Try both the directory name and its Steam64 equivalent
                user_info = user_names.get(user_dir, None)
                if not user_info:
                    steam64_id = steam32_to_steam64(user_dir)
                    if steam64_id:
                        user_info = user_names.get(steam64_id, None)

                if user_info:
                    persona_name = user_info["PersonaName"]
                    account_name = user_info["AccountName"]
                    if account_name != "Unknown Account":
                        print(f"- {user_dir} - {persona_name} ({account_name})")
                    else:
                        print(f"- {user_dir} - {persona_name}")
                else:
                    print(f"- {user_dir} - Unknown Account")

                # Add recent games for each user
                recent_games = get_recent_games(userdata_path, user_dir)
                if recent_games:
                    print("\n  Recent Games:")
                    for game in recent_games:
                        print(
                            f"  - App ID {game['app_id']}, Last played: {game['last_played']}"
                        )
        else:
            print("\nNo Steam accounts found")
        print()
    else:
        print("\nNo Steam userdata directory found")


def display_steam_info(this_steam_library):
    """
    Display Steam library and account information
    """
    logger.info("Displaying Steam information")

    # Display user info
    get_user_info()

    # Display storage information
    if args.analyze_storage:
        analyze_storage(this_steam_library)


def setup_logging():
    """
    Configure logging for the application.
    Creates a logs directory if it doesn't exist.
    """
    # Create logs directory if it doesn't exist
    log_dir = "/tmp/"
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)

    # Configure logger
    logger = logging.getLogger("steam_library_finder")
    logger.setLevel(logging.DEBUG)

    # Create file handler
    file_handler = logging.FileHandler(os.path.join(log_dir, "steam_library.log"))
    file_handler.setLevel(logging.DEBUG)

    # Create console handler
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.INFO)

    # Create formatter
    formatter = logging.Formatter("%(levelname)s - %(message)s")
    file_handler.setFormatter(formatter)
    console_handler.setFormatter(formatter)

    # Add handlers to logger
    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    return logger


def complete_path(text, state):
    """
    Tab completion function for file paths
    """
    if "~" in text:
        text = os.path.expanduser(text)

    # Get the dirname and basename of the path
    dirname = os.path.dirname(text) if text else "."
    basename = os.path.basename(text)

    if not dirname:
        dirname = "."

    try:
        # Get all matching files/directories
        if state == 0:
            if dirname == ".":
                complete_path.matches = [
                    f for f in os.listdir(dirname) if f.startswith(basename)
                ]
            else:
                if not os.path.exists(dirname):
                    complete_path.matches = []
                else:
                    complete_path.matches = [
                        os.path.join(os.path.dirname(text), f)
                        for f in os.listdir(dirname)
                        if f.startswith(os.path.basename(text))
                    ]

        # Return match or None if no more matches
        if state < len(complete_path.matches):
            return complete_path.matches[state]
        else:
            return None
    except (OSError, AttributeError):
        complete_path.matches = []
        return None


def add_shortcut_entry():
    """
    Add a new shortcut entry
    """
    # Get the application name
    app_name = input("Enter application name: ").strip()
    if not app_name:
        # Assume we are done
        logger.info("Exiting entry process, blank name entered")
        return None

    # Get the executable path
    exe_path = prompt_path("Enter path to executable: ", is_file=True)
    if not exe_path:
        return None

    # Get the start directory (default to executable's directory)
    exe_dir = os.path.dirname(exe_path)
    start_dir = prompt_path(
        "Enter start directory (press Enter for executable's directory): ",
        is_file=False,
        default_path=exe_dir,
    )
    if start_dir is None:  # User cancelled
        return None

    # Get launch options (optional)
    launch_options = input("Enter launch options (optional): ").strip()

    # Create the shortcut entry
    entry = {
        "appname": app_name,
        "exe": f'"{exe_path}"',
        "StartDir": f'"{start_dir}"',
        "icon": "",
        "ShortcutPath": "",
        "LaunchOptions": launch_options,
        "IsHidden": 0,
        "AllowDesktopConfig": 1,
        "AllowOverlay": 1,
        "OpenVR": 0,
        "Devkit": 0,
        "DevkitGameID": "",
        "LastPlayTime": 0,
        "tags": {},
    }

    return entry


def prompt_path(prompt_text, is_file=True, default_path=None):
    """
    Prompt for a path with autocompletion
    """
    readline.set_completer_delims(" \t\n;")
    readline.parse_and_bind("tab: complete")
    readline.set_completer(complete_path)

    while True:
        try:
            path = input(prompt_text).strip()

            # Handle empty input - use default if provided
            if not path:
                if default_path:
                    logger.info(f"Using default path: {default_path}")
                    return default_path
                else:
                    logger.warning("Empty path provided")
                    logger.info("Please enter a valid path")
                    continue

            # Expand user path if needed
            if "~" in path:
                path = os.path.expanduser(path)

            # Convert to absolute path
            path = os.path.abspath(path)

            if is_file:
                if os.path.isfile(path):
                    return path
                else:
                    logger.warning(f"Invalid file path: {path}")
                    logger.info("Please enter a valid file path")
            else:
                if os.path.isdir(path):
                    return path
                else:
                    logger.warning(f"Invalid directory path: {path}")
                    logger.info("Please enter a valid directory path")
        except (KeyboardInterrupt, EOFError):
            logger.info("\nOperation cancelled by user")
            return None
        except Exception as e:
            logger.error(f"Error processing path: {str(e)}")
            logger.info("Please enter a valid path")


def add_shortcut_to_shortcuts(shortcuts, new_entry):
    """
    Add a new shortcut entry to the shortcuts structure
    """
    # Initialize shortcuts list if it doesn't exist
    if "shortcuts" not in shortcuts:
        shortcuts["shortcuts"] = {}

    # Find the next available index
    next_index = 0
    while str(next_index) in shortcuts["shortcuts"]:
        next_index += 1

    # Add the new entry
    shortcuts["shortcuts"][str(next_index)] = new_entry
    logger.info(f"Added new shortcut '{new_entry['appname']}' at index {next_index}")
    return shortcuts


def load_shortcuts_file(shortcuts_vdf):
    """
    Load shortcuts.vdf file using binary mode
    """
    try:
        if os.path.exists(shortcuts_vdf):
            with open(shortcuts_vdf, "rb") as f:  # Use binary mode
                shortcuts = vdf.binary_load(
                    f
                )  # Use vdf.binary_load instead of vdf.load
                dump_vdf_to_json(shortcuts, shortcuts_vdf)
                return shortcuts
        else:
            logger.debug(f"No shortcuts.vdf found at: {shortcuts_vdf}")
            return {"shortcuts": []}
    except Exception as e:
        logger.error(f"Error loading shortcuts.vdf: {str(e)}")
        print(f"Error loading shortcuts file: {str(e)}")
        return {"shortcuts": []}


def save_shortcuts(shortcuts_vdf, shortcuts):
    """
    Save the shortcuts back to the VDF file
    """
    try:
        with open(shortcuts_vdf, "wb") as f:  # Use binary mode
            vdf.binary_dump(shortcuts, f)  # Use vdf.binary_dump instead of vdf.dump
        logger.info(f"Successfully saved shortcuts to: {shortcuts_vdf}")
        return True
    except Exception as e:
        logger.error(f"Error saving shortcuts: {str(e)}")
        return False


def find_steam_library():
    """
    Find the Steam library location based on the operating system.
    Returns the path to the Steam library or None if not found.
    """
    system = platform.system().lower()
    home = os.path.expanduser("~")
    logger.info(f"Searching for Steam library on {system} system")

    if system == "windows":
        # Check common Windows locations
        possible_paths = [
            "C:\\Program Files (x86)\\Steam",
            "C:\\Program Files\\Steam",
            os.path.join(os.getenv("ProgramFiles(x86)", ""), "Steam"),
            os.path.join(os.getenv("ProgramFiles", ""), "Steam"),
        ]

    elif system == "darwin":  # macOS
        possible_paths = [
            os.path.join(home, "Library/Application Support/Steam"),
            "/Applications/Steam.app/Contents/MacOS",
        ]

    elif system == "linux":
        possible_paths = [
            os.path.join(home, ".local/share/Steam"),
            os.path.join(home, ".steam/steam"),
            os.path.join(home, ".steam"),
            "/usr/share/steam",
        ]
    else:
        logger.error(f"Unsupported operating system: {system}")
        return None

    logger.debug(f"Checking possible paths: {possible_paths}")
    # Check each possible path
    for path in possible_paths:
        if os.path.exists(path):
            logger.info(f"Found Steam library at: {path}")
            return path

    logger.warning("No Steam library found in common locations")
    return None


def find_steam_library_folders():
    """
    Find all Steam library folders including additional library folders.
    Returns a list of paths to all found Steam libraries.
    """
    libraries = []
    main_library = find_steam_library()

    if not main_library:
        logger.warning("No main Steam library found")
        return libraries

    libraries.append(main_library)

    # Check for additional library folders in libraryfolders.vdf
    vdf_paths = [
        os.path.join(main_library, "steamapps/libraryfolders.vdf"),
        os.path.join(main_library, "config/libraryfolders.vdf"),
    ]

    logger.debug(f"Checking VDF paths: {vdf_paths}")
    for vdf_path in vdf_paths:
        if os.path.exists(vdf_path):
            try:
                logger.debug(f"Reading VDF file: {vdf_path}")
                with open(vdf_path, "r", encoding="utf-8") as f:
                    content = vdf.load(f)
                    dump_vdf_to_json(content, vdf_path)

                    # Process library folders
                    if isinstance(content, dict):
                        for key, value in content.items():
                            if isinstance(value, dict) and "path" in value:
                                path = value["path"]
                                if os.path.exists(path) and path not in libraries:
                                    logger.info(f"Found additional library at: {path}")
                                    libraries.append(path)
            except Exception as e:
                logger.error(f"Error reading VDF file {vdf_path}: {str(e)}")
                continue

    return libraries


def choose_library(libraries):
    """
    Prompt user to choose a Steam library from the available options.
    Returns the chosen library path or None if no valid selection is made.
    """
    if not libraries:
        logger.warning("No Steam libraries found")
        logger.error("No Steam libraries found.")
        return None

    if len(libraries) == 1:
        logger.info(f"Using only available Steam library: {libraries[0]}")
        return libraries[0]

    logger.info("Available Steam libraries:")
    for idx, library in enumerate(libraries, 1):
        logger.info(f"{idx}. {library}")

    while True:
        try:
            choice = input("\nChoose a Steam library (enter number): ")
            index = int(choice) - 1
            if 0 <= index < len(libraries):
                selected = libraries[index]
                logger.info(f"User selected library: {selected}")
                return selected
            else:
                logger.warning(f"Invalid selection: {choice}")
                logger.info(f"Please enter a number between 1 and {len(libraries)}")
        except ValueError:
            logger.warning(f"Invalid input: {choice}")
            logger.info("Please enter a valid number")
        except KeyboardInterrupt:
            logger.info("Operation cancelled by user")
            logger.info("\nOperation cancelled")
            return None


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(description="Steam VDF Tool")
    subparsers = parser.add_subparsers(dest="command")

    # Info command and its options
    info_parser = subparsers.add_parser(
        "info", help="Display Steam library information"
    )
    info_parser.add_argument(
        "--analyze-storage",
        action="store_true",
        help="Analyze storage usage including non-Steam directories",
    )
    info_parser.set_defaults(info=True)

    # Other main commands
    add_parser = subparsers.add_parser(
        "add-shortcut", help="Add a new non-Steam game shortcut"
    )
    add_parser.set_defaults(add_shortcut=True)

    list_parser = subparsers.add_parser(
        "list-shortcuts", help="List existing non-Steam game shortcuts"
    )
    list_parser.set_defaults(list_shortcuts=True)

    delete_parser = subparsers.add_parser(
        "delete-shortcut", help="Delete an existing non-Steam game shortcut"
    )
    delete_parser.set_defaults(delete_shortcut=True)

    restart_parser = subparsers.add_parser("restart-steam", help="Restart Steam")
    restart_parser.set_defaults(restart_steam=True)

    # Optional flags
    parser.add_argument(
        "-v", "--dump-vdfs", action="store_true", help="Enable dumping of VDFs to JSON"
    )

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        parser.exit()

    return args


if __name__ == "__main__":
    # Initialize logger
    logger = setup_logging()

    # Parse arguments
    args = parse_arguments()

    logger.info("Starting Steam tool")
    # Initialize the matches attribute for the complete_path function
    complete_path.matches = []

    # Find Steam libraries
    all_libraries = find_steam_library_folders()
    if not all_libraries:
        logger.error("No Steam libraries found")
        print("No Steam libraries found. Exiting.")
        exit(1)

    # Select library
    selected_library = choose_library(all_libraries)
    if not selected_library:
        logger.error("No Steam library selected")
        print("No library selected. Exiting.")
        exit(1)

    if args.info:
        display_steam_info(selected_library)

    elif args.list_shortcuts:
        list_shortcuts(selected_library)

    elif args.delete_shortcut:
        delete_shortcut(selected_library)
        restart_steam()

    elif args.restart_steam:
        restart_steam()

    elif args.add_shortcut:
        # Add new shortcut
        shortcuts_vdf = os.path.join(selected_library, "userdata")

        if not os.path.exists(shortcuts_vdf):
            logger.error(f"No userdata directory found at: {shortcuts_vdf}")
            print("No Steam user data found.")
            exit(1)

        user_dirs = [
            d
            for d in os.listdir(shortcuts_vdf)
            if os.path.isdir(os.path.join(shortcuts_vdf, d))
        ]

        if not user_dirs:
            logger.error("No Steam users found in userdata directory")
            print("No Steam users found.")
            exit(1)

        if len(user_dirs) > 1:
            user_names = get_steam_user_names(selected_library)
            print("\nMultiple Steam users found. Please choose one:")
            for idx, user_dir in enumerate(user_dirs, 1):
                user_info = user_names.get(
                    user_dir,
                    {
                        "PersonaName": "Unknown Account",
                        "AccountName": "Unknown Account",
                    },
                )
                persona_name = user_info["PersonaName"]
                account_name = user_info["AccountName"]

                if account_name != "Unknown Account":
                    print(f"{idx}. {user_dir} - {persona_name} ({account_name})")
                else:
                    print(f"{idx}. {user_dir} - {persona_name}")

            while True:
                try:
                    choice = int(input("\nEnter user number: ")) - 1
                    if 0 <= choice < len(user_dirs):
                        user_dir = user_dirs[choice]
                        break
                    else:
                        logger.info(
                            f"Please enter a number between 1 and {len(user_dirs)}"
                        )
                except ValueError:
                    logger.info("Please enter a valid number")
        else:
            user_dir = user_dirs[0]
            user_names = get_steam_user_names(selected_library)
            account_name = user_names.get(user_dir, "Unknown Account")
            logger.info(f"Using only available user: {user_dir} ({account_name})")

        shortcuts_vdf = os.path.join(shortcuts_vdf, user_dir, "config", "shortcuts.vdf")

        try:
            if os.path.exists(shortcuts_vdf):
                with open(shortcuts_vdf, "r", encoding="utf-8") as f:
                    shortcuts = load_shortcuts_file(shortcuts_vdf)
                    new_entry = add_shortcut_entry()
                    if new_entry:
                        shortcuts = add_shortcut_to_shortcuts(shortcuts, new_entry)
                        if save_shortcuts(shortcuts_vdf, shortcuts):
                            logger.info("Shortcut added successfully")
                            restart_steam()
                            restart_steam()
                        else:
                            logger.error("Failed to save shortcuts")
        except Exception as e:
            logger.error(f"Error loading shortcuts.vdf: {str(e)}")
            exit(1)

    logger.info("Exiting Steam VDF tool")
    logger.info("Make sure you restart steam for any changes to take effect")
