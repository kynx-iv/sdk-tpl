#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") --config <config.json> --output <dir>

Instantiate the SDK template into a new project.

Options:
  --config <file>   JSON file with placeholder values
  --output <dir>    Target directory for the new project
  --help            Show this help message

Config JSON format:
{
  "SDK_NAME": "Acme",
  "SDK_SLUG": "acme",
  "SDK_SLUG_UPPER": "ACME",
  "SDK_SLUG_PASCAL": "Acme",
  "ORG_NAME": "@acme",
  "ORG_SLUG": "acme",
  "API_BASE_URL": "https://api.acme.dev/api/v1/sdk",
  "API_LOCAL_URL": "https://api.acme.localhost/api/v1/sdk",
  "SDK_VERSION": "1.0.0",
  "GITHUB_ORG": "acme",
  "ENV_MODE_VAR": "ACME_MODE"
}
EOF
    exit 1
}

# Parse arguments
CONFIG_FILE=""
OUTPUT_DIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --help|-h)
            usage
            ;;
        *)
            echo -e "${RED}Error: unknown option '$1'${NC}" >&2
            usage
            ;;
    esac
done

if [[ -z "$CONFIG_FILE" || -z "$OUTPUT_DIR" ]]; then
    echo -e "${RED}Error: --config and --output are required${NC}" >&2
    usage
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}Error: config file not found: $CONFIG_FILE${NC}" >&2
    exit 1
fi

if [[ -d "$OUTPUT_DIR" ]] && [[ "$(ls -A "$OUTPUT_DIR" 2>/dev/null)" ]]; then
    echo -e "${RED}Error: output directory is not empty: $OUTPUT_DIR${NC}" >&2
    exit 1
fi

# Read placeholder values from config JSON using python3
echo -e "${BLUE}Reading config from $CONFIG_FILE...${NC}"

read_json() {
    python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d.get('$1',''))" 2>/dev/null || echo ""
}

SDK_NAME=$(read_json SDK_NAME)
SDK_SLUG=$(read_json SDK_SLUG)
SDK_SLUG_UPPER=$(read_json SDK_SLUG_UPPER)
SDK_SLUG_PASCAL=$(read_json SDK_SLUG_PASCAL)
ORG_NAME=$(read_json ORG_NAME)
ORG_SLUG=$(read_json ORG_SLUG)
API_BASE_URL=$(read_json API_BASE_URL)
API_LOCAL_URL=$(read_json API_LOCAL_URL)
SDK_VERSION=$(read_json SDK_VERSION)
GITHUB_ORG=$(read_json GITHUB_ORG)
ENV_MODE_VAR=$(read_json ENV_MODE_VAR)

# Validate all required values
for var_name in SDK_NAME SDK_SLUG SDK_SLUG_UPPER SDK_SLUG_PASCAL ORG_NAME ORG_SLUG API_BASE_URL API_LOCAL_URL SDK_VERSION GITHUB_ORG ENV_MODE_VAR; do
    eval "val=\$$var_name"
    if [[ -z "$val" ]]; then
        echo -e "${RED}Error: missing required placeholder '$var_name' in config${NC}" >&2
        exit 1
    fi
    echo -e "  ${GREEN}$var_name${NC} = $val"
done

# Copy template to output
echo ""
echo -e "${BLUE}Copying template to $OUTPUT_DIR...${NC}"
mkdir -p "$OUTPUT_DIR"
rsync -a --exclude='.git' --exclude='node_modules' --exclude='dist' --exclude='__pycache__' \
    --exclude='sdk-tpl.config.json' --exclude='scripts/scaffold.sh' \
    "$TEMPLATE_DIR/" "$OUTPUT_DIR/"

# Replace {{PLACEHOLDER}} tokens in all text files
echo -e "${BLUE}Replacing placeholders...${NC}"

find "$OUTPUT_DIR" -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -name '*.png' ! -name '*.jpg' ! -name '*.ico' ! -name '*.woff' ! -name '*.woff2' \
    | while read -r file; do
    if grep -q '{{' "$file" 2>/dev/null; then
        sed -i '' \
            -e "s|{{SDK_NAME}}|${SDK_NAME}|g" \
            -e "s|{{SDK_SLUG_UPPER}}|${SDK_SLUG_UPPER}|g" \
            -e "s|{{SDK_SLUG_PASCAL}}|${SDK_SLUG_PASCAL}|g" \
            -e "s|{{SDK_SLUG}}|${SDK_SLUG}|g" \
            -e "s|{{ORG_NAME}}|${ORG_NAME}|g" \
            -e "s|{{ORG_SLUG}}|${ORG_SLUG}|g" \
            -e "s|{{API_BASE_URL}}|${API_BASE_URL}|g" \
            -e "s|{{API_LOCAL_URL}}|${API_LOCAL_URL}|g" \
            -e "s|{{SDK_VERSION}}|${SDK_VERSION}|g" \
            -e "s|{{GITHUB_ORG}}|${GITHUB_ORG}|g" \
            -e "s|{{ENV_MODE_VAR}}|${ENV_MODE_VAR}|g" \
            "$file"
    fi
done

# Replace literal template names in file contents
echo -e "${BLUE}Replacing literal template names in file contents...${NC}"

find "$OUTPUT_DIR" -type f \
    ! -path '*/.git/*' \
    ! -path '*/node_modules/*' \
    ! -name '*.png' ! -name '*.jpg' ! -name '*.ico' ! -name '*.woff' ! -name '*.woff2' \
    | while read -r file; do
    if grep -qE 'sdk_tpl|SdkTpl|sdk-tpl|SDK_TPL' "$file" 2>/dev/null; then
        sed -i '' \
            -e "s|SDK_TPL|${SDK_SLUG_UPPER}|g" \
            -e "s|SdkTpl|${SDK_SLUG_PASCAL}|g" \
            -e "s|sdk-tpl|${SDK_SLUG}|g" \
            -e "s|sdk_tpl|${SDK_SLUG}|g" \
            "$file"
    fi
done

# Rename directories containing template names (depth-first)
echo -e "${BLUE}Renaming template directories...${NC}"

find "$OUTPUT_DIR" -mindepth 1 -depth -type d \( -name '*sdk_tpl*' -o -name '*SdkTpl*' -o -name '*sdk-tpl*' \) | while read -r dir; do
    parent=$(dirname "$dir")
    base=$(basename "$dir")
    new_base="${base//SDK_TPL/$SDK_SLUG_UPPER}"
    new_base="${new_base//SdkTpl/$SDK_SLUG_PASCAL}"
    new_base="${new_base//sdk-tpl/$SDK_SLUG}"
    new_base="${new_base//sdk_tpl/$SDK_SLUG}"
    if [[ "$base" != "$new_base" ]]; then
        mv "$dir" "$parent/$new_base"
        echo -e "  ${GREEN}Renamed dir${NC}: $base → $new_base"
    fi
done

# Rename files containing template names
echo -e "${BLUE}Renaming template files...${NC}"

find "$OUTPUT_DIR" -depth -type f \( -name '*sdk_tpl*' -o -name '*SdkTpl*' -o -name '*sdk-tpl*' -o -name '*SDK_TPL*' \) | while read -r file; do
    dir=$(dirname "$file")
    base=$(basename "$file")
    new_base="${base//SDK_TPL/$SDK_SLUG_UPPER}"
    new_base="${new_base//SdkTpl/$SDK_SLUG_PASCAL}"
    new_base="${new_base//sdk-tpl/$SDK_SLUG}"
    new_base="${new_base//sdk_tpl/$SDK_SLUG}"
    if [[ "$base" != "$new_base" ]]; then
        mv "$file" "$dir/$new_base"
        echo -e "  ${GREEN}Renamed${NC}: $base → $new_base"
    fi
done

# Validate no remaining placeholders
echo ""
echo -e "${BLUE}Validating...${NC}"
REMAINING=$(grep -r '{{[A-Z_]*}}' "$OUTPUT_DIR" --include='*.ts' --include='*.py' --include='*.go' \
    --include='*.java' --include='*.kt' --include='*.php' --include='*.swift' --include='*.rb' \
    --include='*.rs' --include='*.dart' --include='*.cs' --include='*.json' --include='*.yml' \
    --include='*.yaml' --include='*.toml' --include='*.md' --include='*.sh' \
    -l 2>/dev/null || true)

REMAINING_LITERAL=$(grep -rE 'sdk_tpl|SdkTpl|sdk-tpl|SDK_TPL' "$OUTPUT_DIR" --include='*.ts' --include='*.py' --include='*.go' \
    --include='*.java' --include='*.kt' --include='*.php' --include='*.swift' --include='*.rb' \
    --include='*.rs' --include='*.dart' --include='*.cs' --include='*.json' --include='*.yml' \
    --include='*.yaml' --include='*.toml' \
    -l 2>/dev/null || true)

if [[ -n "$REMAINING" ]]; then
    echo -e "${YELLOW}Warning: files still contain {{PLACEHOLDER}} tokens:${NC}"
    echo "$REMAINING" | while read -r f; do
        echo -e "  ${YELLOW}$f${NC}"
    done
else
    echo -e "  ${GREEN}✓ No remaining {{PLACEHOLDER}} tokens${NC}"
fi

if [[ -n "$REMAINING_LITERAL" ]]; then
    echo -e "${YELLOW}Warning: files still contain template literal names:${NC}"
    echo "$REMAINING_LITERAL" | while read -r f; do
        echo -e "  ${YELLOW}$f${NC}"
    done
else
    echo -e "  ${GREEN}✓ No remaining template literal names${NC}"
fi

# Initialize git repo
echo ""
echo -e "${BLUE}Initializing git repository...${NC}"
cd "$OUTPUT_DIR"
git init -q
git add -A
git commit -q -m "Initial scaffold from sdk-tpl"

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ SDK scaffolded successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BLUE}Project:${NC}  ${SDK_NAME} SDK"
echo -e "  ${BLUE}Location:${NC} $OUTPUT_DIR"
echo -e "  ${BLUE}Version:${NC}  ${SDK_VERSION}"
echo ""
echo -e "  Next steps:"
echo -e "    cd $OUTPUT_DIR"
echo -e "    task setup"
echo -e "    task build"
echo -e "    task test"
echo ""
