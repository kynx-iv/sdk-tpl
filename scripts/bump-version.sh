#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$ROOT_DIR/VERSION"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") <version|bump-type> [--commit]

Bump the SDK version across all files.

Arguments:
  version      Explicit semver version (e.g., 1.2.3)
  bump-type    One of: major, minor, patch

Options:
  --commit     Auto-commit changes after bumping

Examples:
  $(basename "$0") patch              # 1.0.0 → 1.0.1
  $(basename "$0") minor              # 1.0.0 → 1.1.0
  $(basename "$0") major              # 1.0.0 → 2.0.0
  $(basename "$0") 2.1.0              # Set explicit version
  $(basename "$0") minor --commit     # Bump and commit
EOF
    exit 1
}

# Parse arguments
BUMP_ARG=""
AUTO_COMMIT=false

for arg in "$@"; do
    case "$arg" in
        --commit)
            AUTO_COMMIT=true
            ;;
        --help|-h)
            usage
            ;;
        *)
            if [[ -n "$BUMP_ARG" ]]; then
                echo -e "${RED}Error: unexpected argument '$arg'${NC}" >&2
                usage
            fi
            BUMP_ARG="$arg"
            ;;
    esac
done

if [[ -z "$BUMP_ARG" ]]; then
    echo -e "${RED}Error: version or bump type required${NC}" >&2
    usage
fi

# Read current version
if [[ ! -f "$VERSION_FILE" ]]; then
    echo -e "${RED}Error: VERSION file not found at $VERSION_FILE${NC}" >&2
    exit 1
fi

CURRENT_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")

if [[ ! "$CURRENT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}Error: invalid current version '$CURRENT_VERSION'${NC}" >&2
    exit 1
fi

# Calculate new version
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

case "$BUMP_ARG" in
    major)
        NEW_VERSION="$((MAJOR + 1)).0.0"
        ;;
    minor)
        NEW_VERSION="${MAJOR}.$((MINOR + 1)).0"
        ;;
    patch)
        NEW_VERSION="${MAJOR}.${MINOR}.$((PATCH + 1))"
        ;;
    *)
        if [[ ! "$BUMP_ARG" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo -e "${RED}Error: invalid version format '$BUMP_ARG'${NC}" >&2
            usage
        fi
        NEW_VERSION="$BUMP_ARG"
        ;;
esac

echo -e "${BLUE}Bumping version: ${YELLOW}$CURRENT_VERSION${NC} → ${GREEN}$NEW_VERSION${NC}"
echo ""

UPDATED=0
SKIPPED=0

update_file() {
    local file="$1"
    local search="$2"
    local replace="$3"
    local label="${4:-$file}"

    if [[ ! -f "$ROOT_DIR/$file" ]]; then
        echo -e "  ${YELLOW}⊘ $label${NC} (not found)"
        SKIPPED=$((SKIPPED + 1))
        return
    fi

    if grep -q "$search" "$ROOT_DIR/$file" 2>/dev/null; then
        if [[ "$(uname)" == "Darwin" ]]; then
            sed -i '' "s|$search|$replace|g" "$ROOT_DIR/$file"
        else
            sed -i "s|$search|$replace|g" "$ROOT_DIR/$file"
        fi
        echo -e "  ${GREEN}✓ $label${NC}"
        UPDATED=$((UPDATED + 1))
    else
        echo -e "  ${YELLOW}⊘ $label${NC} (pattern not found)"
        SKIPPED=$((SKIPPED + 1))
    fi
}

# Update VERSION file
echo "$NEW_VERSION" > "$VERSION_FILE"
echo -e "  ${GREEN}✓ VERSION${NC}"
UPDATED=$((UPDATED + 1))

# TypeScript SDK
update_file "sdks/typescript/package.json" \
    "\"version\": \"$CURRENT_VERSION\"" \
    "\"version\": \"$NEW_VERSION\"" \
    "TypeScript package.json"

update_file "sdks/typescript/src/utils/version.ts" \
    "$CURRENT_VERSION" "$NEW_VERSION" \
    "TypeScript version.ts"

# React SDK
update_file "sdks/react/package.json" \
    "\"version\": \"$CURRENT_VERSION\"" \
    "\"version\": \"$NEW_VERSION\"" \
    "React package.json"

# Python SDK
update_file "sdks/python/pyproject.toml" \
    "version = \"$CURRENT_VERSION\"" \
    "version = \"$NEW_VERSION\"" \
    "Python pyproject.toml"

# Find and update Python version.py (handles any SDK slug)
PYTHON_VERSION_FILE=$(find "$ROOT_DIR/sdks/python/src" -name "version.py" -path "*/utils/*" 2>/dev/null | head -1)
if [[ -n "$PYTHON_VERSION_FILE" ]]; then
    REL_PATH="${PYTHON_VERSION_FILE#$ROOT_DIR/}"
    update_file "$REL_PATH" "$CURRENT_VERSION" "$NEW_VERSION" "Python version.py"
fi

# Go SDK
update_file "sdks/go/internal/version/version.go" \
    "$CURRENT_VERSION" "$NEW_VERSION" \
    "Go version.go"

# Java SDK
update_file "sdks/java/pom.xml" \
    "<version>$CURRENT_VERSION</version>" \
    "<version>$NEW_VERSION</version>" \
    "Java pom.xml"

# Kotlin SDK
update_file "sdks/kotlin/build.gradle.kts" \
    "version = \"$CURRENT_VERSION\"" \
    "version = \"$NEW_VERSION\"" \
    "Kotlin build.gradle.kts"

# PHP SDK
update_file "sdks/php/composer.json" \
    "\"version\": \"$CURRENT_VERSION\"" \
    "\"version\": \"$NEW_VERSION\"" \
    "PHP composer.json"

# Swift SDK
SWIFT_VERSION_FILE=$(find "$ROOT_DIR/sdks/swift" -name "Version.swift" 2>/dev/null | head -1)
if [[ -n "$SWIFT_VERSION_FILE" ]]; then
    REL_PATH="${SWIFT_VERSION_FILE#$ROOT_DIR/}"
    update_file "$REL_PATH" "$CURRENT_VERSION" "$NEW_VERSION" "Swift Version.swift"
fi

# Ruby SDK
RUBY_VERSION_FILE=$(find "$ROOT_DIR/sdks/ruby/lib" -name "version.rb" 2>/dev/null | head -1)
if [[ -n "$RUBY_VERSION_FILE" ]]; then
    REL_PATH="${RUBY_VERSION_FILE#$ROOT_DIR/}"
    update_file "$REL_PATH" "$CURRENT_VERSION" "$NEW_VERSION" "Ruby version.rb"
fi

# Rust SDK
update_file "sdks/rust/Cargo.toml" \
    "version = \"$CURRENT_VERSION\"" \
    "version = \"$NEW_VERSION\"" \
    "Rust Cargo.toml"

# Dart SDK
update_file "sdks/dart/pubspec.yaml" \
    "version: $CURRENT_VERSION" \
    "version: $NEW_VERSION" \
    "Dart pubspec.yaml"

# .NET SDK
CSPROJ_FILE=$(find "$ROOT_DIR/sdks/dotnet" -name "*.csproj" 2>/dev/null | head -1)
if [[ -n "$CSPROJ_FILE" ]]; then
    REL_PATH="${CSPROJ_FILE#$ROOT_DIR/}"
    update_file "$REL_PATH" \
        "<Version>$CURRENT_VERSION</Version>" \
        "<Version>$NEW_VERSION</Version>" \
        ".NET .csproj"
fi

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "  Updated: ${GREEN}$UPDATED${NC} files"
echo -e "  Skipped: ${YELLOW}$SKIPPED${NC} files"
echo -e "  Version: ${YELLOW}$CURRENT_VERSION${NC} → ${GREEN}$NEW_VERSION${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"

# Auto-commit if requested
if [[ "$AUTO_COMMIT" == "true" ]]; then
    echo ""
    echo -e "${BLUE}Committing version bump...${NC}"
    cd "$ROOT_DIR"
    git add -A
    git commit -m "chore: bump version to $NEW_VERSION"
    echo -e "${GREEN}✓ Committed${NC}"
fi
