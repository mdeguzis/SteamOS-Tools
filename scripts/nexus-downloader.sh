#!/usr/bin/env bash

# Exit immediately on unhandled pipe/command failures
set -eo pipefail

TOKEN_FILE="${HOME}/.nexusapi"

# --- API KEY RESOLUTION ---
if [[ -f "$TOKEN_FILE" ]]; then
    API_KEY=$(cat "$TOKEN_FILE" | xargs) # xargs trims whitespace/newlines
else
    echo "Error: API token file missing at $TOKEN_FILE" >&2
    echo "Please save your token there first: echo 'YOUR_KEY' > ~/.nexusapi" >&2
    exit 1
fi

if [[ -z "$API_KEY" ]]; then
    echo "Error: Token file at $TOKEN_FILE is empty." >&2
    exit 1
fi
# --------------------------

show_help() {
    cat << EOF
Nexus Mods Linux CLI Utility

Usage:
  $0 <command> [arguments]

Commands:
  search   <game-domain> <query-string>  Search Nexus for mods matching a term
  list     <mod-url>                     List all available files for a specific mod
  download <mod-url> [file-id]           Download a file. Prompts if file-id is omitted.
  help, -h, --help                       Show this help layout

Examples:
  $(basename $0) search residentevil5goldedition "quality of life"
  $(basename $0) list "https://www.nexusmods.com/residentevil5goldedition/mods/737"
  $(basename $0) download "https://www.nexusmods.com/residentevil5goldedition/mods/737" 2741
EOF
}

# Helper function to extract game domain and mod ID from a Nexus URL
parse_url() {
    local url="$1"
    if [[ "$url" =~ nexusmods\.com/([^/]+)/mods/([0-9]+) ]]; then
        GAME_DOMAIN="${BASH_REMATCH[1]}"
        MOD_ID="${BASH_REMATCH[2]}"
    else
        echo "Error: Invalid Nexus URL format." >&2
        echo "Expected: https://www.nexusmods.com/<game>/mods/<id>" >&2
        exit 1
    fi
}

# Check if jq is present
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is required to parse API responses. Install it via 'ujust layered-install jq'" >&2
    exit 1
fi

COMMAND="$1"
shift || true # Drop command string from argument array

case "$COMMAND" in
    search)
        GAME="$1"
        QUERY="$2"
        if [[ -z "$GAME" || -z "$QUERY" ]]; then
            echo "Error: Syntax requires both game-domain and a query string." >&2
            echo "Example: $0 search residentevil5goldedition \"patch\"" >&2
            exit 1
        fi

        # Translate common alphanumeric slugs to Nexus internal Integer IDs for GraphQL
        case "$GAME" in
            residentevil5goldedition|residentevil5)  GRAPHQL_GAME_ID=125 ;;
            cyberpunk2077)                           GRAPHQL_GAME_ID=3333 ;;
            skyrimspecialedition)                    GRAPHQL_GAME_ID=1704 ;;
            fallout4)                                GRAPHQL_GAME_ID=1151 ;;
            *) 
                # Fallback: if user already passed an integer, use it. Otherwise, guess the slug.
                if [[ "$GAME" =~ ^[0-9]+$ ]]; then
                    GRAPHQL_GAME_ID="$GAME"
                else
                    echo "Warning: Unmapped game slug. Attempting raw filter..." >&2
                    GRAPHQL_GAME_ID="$GAME"
                fi
                ;;
        esac
        
        echo "Searching Nexus v2 API for '$QUERY' matching Game ID #$GRAPHQL_GAME_ID..."
        
	# Quoted again because it expects a 'String!', but using WILDCARD to match the indexing engine
        GRAPHQL_QUERY="query {
          mods(filter: { name: { value: \"$QUERY\", op: WILDCARD }, gameId: { value: \"$GRAPHQL_GAME_ID\", op: WILDCARD } }) {
            nodes {
              id
              name
              summary
            }
          }
        }"

        JSON_PAYLOAD=$(jq -n --arg q "$GRAPHQL_QUERY" '{query: $q}')
        
        RESPONSE=$(curl -s -X POST "https://api.nexusmods.com/v2/graphql" \
            -H "Content-Type: application/json" \
            -H "apikey: ${API_KEY}" \
            -d "$JSON_PAYLOAD")
            
        if echo "$RESPONSE" | grep -q '"errors"' || [[ -z "$RESPONSE" ]]; then
            echo "GraphQL Error or Empty Response received." >&2
            echo "$RESPONSE" | jq -r '.errors[0].message' 2>/dev/null || true
            exit 1
        fi

        echo "--------------------------------------------------------------------------------"
        printf "%-10s | %s\n" "Mod ID" "Mod Name / Summary"
        echo "--------------------------------------------------------------------------------"
        
        echo "$RESPONSE" | jq -r '.data.mods.nodes[] | "\(.id)\t| \(.name) — \(.summary)"' | while IFS=$'\t' read -r id details; do
            printf "%-10s | %s\n" "$id" "$details"
        done
        ;; 
    list)
        URL="$1"
        if [[ -z "$URL" ]]; then
            show_help
            exit 1
        fi
        parse_url "$URL"
        
        echo "Fetching file index for Mod #$MOD_ID ($GAME_DOMAIN)..."
        FILES_JSON=$(curl -s -X GET "https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files.json" \
            -H "accept: application/json" \
            -H "apikey: ${API_KEY}")
            
        if echo "$FILES_JSON" | grep -q '"message"'; then
            echo "API Error: $(echo "$FILES_JSON" | jq -r '.message')" >&2
            exit 1
        fi
        
        echo "--------------------------------------------------------------------------------"
        echo "Available Files:"
        echo "--------------------------------------------------------------------------------"
        echo "$FILES_JSON" | jq -r '.files[] | "[\(.file_id)] \(.name) (v\(.version)) -\n    Type: \(.category_name) | Size: \(.size_kb) KB\n"'
        ;;

    download)
        URL="$1"
        FILE_ID="$2"
        if [[ -z "$URL" ]]; then
            show_help
            exit 1
        fi
        parse_url "$URL"
        
        # If no File ID was provided as a positional parameter, fetch index and prompt interactively
        if [[ -z "$FILE_ID" ]]; then
            echo "Fetching files to prompt for ID..."
            FILES_JSON=$(curl -s -X GET "https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files.json" \
                -H "accept: application/json" \
                -H "apikey: ${API_KEY}")
                
            echo "--------------------------------------------------------------------------------"
            echo "$FILES_JSON" | jq -r '.files[] | "[\(.file_id)] \(.name) (\(.category_name))"'
            echo "--------------------------------------------------------------------------------"
            
            read -p "Enter the file_id to download: " FILE_ID
            if [[ -z "$FILE_ID" ]]; then
                echo "Action aborted."
                exit 0
            fi
        fi
        
        echo "Requesting direct download CDN link for File #$FILE_ID..."
        DL_JSON=$(curl -s -X GET "https://api.nexusmods.com/v1/games/${GAME_DOMAIN}/mods/${MOD_ID}/files/${FILE_ID}/download_link.json" \
            -H "accept: application/json" \
            -H "apikey: ${API_KEY}")
            
        DL_URL=$(echo "$DL_JSON" | jq -r '.[0].URI')
        
        if [[ -z "$DL_URL" || "$DL_URL" == "null" ]]; then
            echo "Error: Target link generation failed. Double check file_id or API permissions." >&2
            exit 1
        fi
        
        echo "Downloading archive natively..."
        # -L follows redirect headers, -O retains structural remote headers, -J parses original download filename
        curl -L -O -J "$DL_URL"
        echo "Download target finalized successfully."
        ;;

    help|-h|--help|"")
        show_help
        ;;

    *)
        echo "Unknown command: $COMMAND" >&2
        show_help
        exit 1
        ;;
esac
