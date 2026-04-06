#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION=$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
    cat <<EOF
Usage: $(basename "$0") [options] <sdk|all>

Release SDK(s) to their respective package registries.

Arguments:
  all           Release all SDKs
  typescript    Release TypeScript SDK to npm
  react         Release React SDK to npm
  python        Release Python SDK to PyPI
  go            Release Go SDK (git tag)
  java          Release Java SDK to Maven Central
  kotlin        Release Kotlin SDK to Maven Central
  php           Release PHP SDK to Packagist
  swift         Release Swift SDK (git tag)
  ruby          Release Ruby SDK to RubyGems
  rust          Release Rust SDK to crates.io
  dart          Release Dart SDK to pub.dev
  dotnet        Release .NET SDK to NuGet

Options:
  --dry-run     Simulate release without publishing
  --help        Show this help message
EOF
    exit 1
}

# Parse arguments
DRY_RUN=false
TARGET=""

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            usage
            ;;
        *)
            if [[ -n "$TARGET" ]]; then
                echo -e "${RED}Error: unexpected argument '$arg'${NC}" >&2
                usage
            fi
            TARGET="$arg"
            ;;
    esac
done

if [[ -z "$TARGET" ]]; then
    echo -e "${RED}Error: SDK target required${NC}" >&2
    usage
fi

DRY_PREFIX=""
if [[ "$DRY_RUN" == "true" ]]; then
    DRY_PREFIX="[DRY RUN] "
    echo -e "${YELLOW}═══ DRY RUN MODE ═══${NC}"
fi

echo -e "${BLUE}Releasing version $VERSION...${NC}"
echo ""

# Pre-flight checks
echo -e "${BLUE}Pre-flight checks...${NC}"

# Clean working directory
if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" ]]; then
    echo -e "${RED}Error: working directory is not clean${NC}" >&2
    echo "Please commit or stash your changes before releasing."
    exit 1
fi
echo -e "  ${GREEN}✓ Clean working directory${NC}"

# On main branch
BRANCH=$(git -C "$ROOT_DIR" branch --show-current)
if [[ "$BRANCH" != "main" ]]; then
    echo -e "${YELLOW}  ⚠ Not on main branch (on '$BRANCH')${NC}"
fi

echo ""

release_typescript() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing TypeScript SDK to npm...${NC}"
    cd "$ROOT_DIR/sdks/typescript"
    npm run build
    if [[ "$DRY_RUN" == "true" ]]; then
        npm publish --dry-run --access public 2>&1 || true
    else
        npm publish --access public
    fi
    echo -e "  ${GREEN}✓ TypeScript SDK published${NC}"
}

release_react() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing React SDK to npm...${NC}"
    cd "$ROOT_DIR/sdks/react"
    npm run build
    if [[ "$DRY_RUN" == "true" ]]; then
        npm publish --dry-run --access public 2>&1 || true
    else
        npm publish --access public
    fi
    echo -e "  ${GREEN}✓ React SDK published${NC}"
}

release_python() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Python SDK to PyPI...${NC}"
    cd "$ROOT_DIR/sdks/python"
    python -m build
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would upload dist/* to PyPI"
    else
        python -m twine upload dist/*
    fi
    echo -e "  ${GREEN}✓ Python SDK published${NC}"
}

release_go() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Go SDK (git tag)...${NC}"
    cd "$ROOT_DIR"
    TAG="v$VERSION"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would create tag $TAG and push"
    else
        git tag -a "$TAG" -m "Release $TAG"
        git push origin "$TAG"
    fi
    echo -e "  ${GREEN}✓ Go SDK tagged${NC}"
}

release_java() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Java SDK to Maven Central...${NC}"
    cd "$ROOT_DIR/sdks/java"
    if [[ "$DRY_RUN" == "true" ]]; then
        mvn package -q
        echo "  Would deploy to Maven Central"
    else
        mvn deploy
    fi
    echo -e "  ${GREEN}✓ Java SDK published${NC}"
}

release_kotlin() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Kotlin SDK to Maven Central...${NC}"
    cd "$ROOT_DIR/sdks/kotlin"
    if [[ "$DRY_RUN" == "true" ]]; then
        ./gradlew build
        echo "  Would publish to Maven Central"
    else
        ./gradlew publish
    fi
    echo -e "  ${GREEN}✓ Kotlin SDK published${NC}"
}

release_php() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing PHP SDK to Packagist...${NC}"
    echo "  PHP auto-publishes via Packagist webhook on git push"
    echo -e "  ${GREEN}✓ PHP SDK (webhook)${NC}"
}

release_swift() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Swift SDK (git tag)...${NC}"
    echo "  Swift publishes via git tag (same as Go)"
    echo -e "  ${GREEN}✓ Swift SDK tagged${NC}"
}

release_ruby() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Ruby SDK to RubyGems...${NC}"
    cd "$ROOT_DIR/sdks/ruby"
    GEM_FILE=$(ls *.gem 2>/dev/null | head -1)
    if [[ -z "$GEM_FILE" ]]; then
        gem build *.gemspec
        GEM_FILE=$(ls *.gem 2>/dev/null | head -1)
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would push $GEM_FILE to RubyGems"
    else
        gem push "$GEM_FILE"
    fi
    echo -e "  ${GREEN}✓ Ruby SDK published${NC}"
}

release_rust() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Rust SDK to crates.io...${NC}"
    cd "$ROOT_DIR/sdks/rust"
    if [[ "$DRY_RUN" == "true" ]]; then
        cargo publish --dry-run
    else
        cargo publish
    fi
    echo -e "  ${GREEN}✓ Rust SDK published${NC}"
}

release_dart() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing Dart SDK to pub.dev...${NC}"
    cd "$ROOT_DIR/sdks/dart"
    if [[ "$DRY_RUN" == "true" ]]; then
        dart pub publish --dry-run
    else
        dart pub publish --force
    fi
    echo -e "  ${GREEN}✓ Dart SDK published${NC}"
}

release_dotnet() {
    echo -e "${BLUE}${DRY_PREFIX}Publishing .NET SDK to NuGet...${NC}"
    cd "$ROOT_DIR/sdks/dotnet"
    dotnet pack -c Release
    NUPKG=$(find . -name "*.nupkg" | head -1)
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  Would push $NUPKG to NuGet"
    else
        dotnet nuget push "$NUPKG" --source https://api.nuget.org/v3/index.json
    fi
    echo -e "  ${GREEN}✓ .NET SDK published${NC}"
}

# Execute releases
case "$TARGET" in
    all)
        release_typescript
        release_react
        release_python
        release_go
        release_java
        release_kotlin
        release_php
        release_swift
        release_ruby
        release_rust
        release_dart
        release_dotnet
        ;;
    typescript) release_typescript ;;
    react) release_react ;;
    python) release_python ;;
    go) release_go ;;
    java) release_java ;;
    kotlin) release_kotlin ;;
    php) release_php ;;
    swift) release_swift ;;
    ruby) release_ruby ;;
    rust) release_rust ;;
    dart) release_dart ;;
    dotnet) release_dotnet ;;
    *)
        echo -e "${RED}Error: unknown SDK '$TARGET'${NC}" >&2
        usage
        ;;
esac

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}${DRY_PREFIX}Release $VERSION complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
