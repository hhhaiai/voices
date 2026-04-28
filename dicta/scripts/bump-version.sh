#!/bin/bash

# Simple version bump script for CI releases
# Usage: ./scripts/bump-version.sh [patch|minor|major]
# This script only bumps version and creates a tag - CI handles the build

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly MAIN_BRANCH="main"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}$1${NC}"; }
log_warn() { echo -e "${YELLOW}$1${NC}"; }
log_error() { echo -e "${RED}$1${NC}"; }

# Parse arguments
RELEASE_TYPE="${1:-}"
if [[ ! "$RELEASE_TYPE" =~ ^(patch|minor|major)$ ]]; then
    log_error "Usage: $0 [patch|minor|major]"
    exit 1
fi

cd "$REPO_ROOT"

# Check we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" != "$MAIN_BRANCH" ]]; then
    log_error "Error: Must be on $MAIN_BRANCH branch (currently on $CURRENT_BRANCH)"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status -s) ]]; then
    log_error "Error: You have uncommitted changes"
    git status -s
    exit 1
fi

# Get current version
CURRENT_VERSION=$(node -p "require('./package.json').version")
log_info "Current version: $CURRENT_VERSION"

# Calculate new version
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
case "$RELEASE_TYPE" in
    major) NEW_VERSION="$((major + 1)).0.0" ;;
    minor) NEW_VERSION="${major}.$((minor + 1)).0" ;;
    patch) NEW_VERSION="${major}.${minor}.$((patch + 1))" ;;
esac

log_info "New version: $NEW_VERSION"

# Confirm
read -p "Bump to v$NEW_VERSION and push tag? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warn "Aborted"
    exit 0
fi

# Pull latest
log_info "Pulling latest changes..."
git pull --ff-only origin "$MAIN_BRANCH"

# Bump version in package.json
npm version "$RELEASE_TYPE" --no-git-tag-version

# Bump version in Cargo.toml
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" src-tauri/Cargo.toml
else
    sed -i "s/^version = \".*\"/version = \"${NEW_VERSION}\"/" src-tauri/Cargo.toml
fi

# Bump version in tauri.conf.json
jq --arg version "$NEW_VERSION" '.version = $version' src-tauri/tauri.conf.json > src-tauri/tauri.conf.json.tmp
mv src-tauri/tauri.conf.json.tmp src-tauri/tauri.conf.json

# Update Cargo.lock
cd src-tauri && cargo update -p dicta && cd ..

# Generate changelog
log_info "Generating changelog..."
npx conventional-changelog -p angular -i CHANGELOG.md -s

# Commit and tag
log_info "Committing and tagging..."
git add package.json src-tauri/Cargo.toml src-tauri/Cargo.lock src-tauri/tauri.conf.json CHANGELOG.md
git commit -m "chore: release v${NEW_VERSION}"
git tag "v${NEW_VERSION}"

# Push
log_info "Pushing to origin..."
git push origin "$MAIN_BRANCH"
git push origin "v${NEW_VERSION}"

log_info "✅ Version bumped to v${NEW_VERSION}"
log_info "🚀 GitHub Actions will now build and create the release"
log_info "📋 Watch progress at: https://github.com/nitintf/dicta/actions"
