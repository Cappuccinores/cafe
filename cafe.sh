#!/bin/bash
# Cafe Version 0.6.1

DEFAULT_REPO_URL="https://github.com/archlinux/aur"
REPO_URL="$DEFAULT_REPO_URL"
OPERATION="$1"

shift 

BRANCH_NAME=""
CUSTOM_REPO_URL=""
NO_CONFIRM=""

usage() {
    echo "Usage: $0 <operation> [branch-name] [repository-url] [--noconfirm]"
    echo "Operations:"
    echo "  install    Clone a package from a branch of selected repo and install it."
    echo "             Requires a branch name (the package name)"
    echo "             Example: $0 install <package-name> [repository-url] [--noconfirm]"
    echo ""
    echo "  remove     Remove a package and all then-unused installed dependencies via pacman."
    echo "             Requires the package name (branch name)."
    echo "             Example: $0 remove <package-name>"
    echo ""
    echo "  search     Search for branches matching the specified branch name in the selected repository."
    echo "             Requires a search term."
    echo "             Example: $0 search <search-term>"
    echo ""
    echo "  searchex   Search for branches with an exact match to the specified branch name."
    echo "             Requires a search term."
    echo "             Example: $0 searchex <exact-search-term>"
    echo ""
    echo "  version    Fetch the version of a specific branch/package from the selected repository."
    echo "             Requires the package name (branch name)."
    echo "             Example: $0 version <package-name>"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message."
    echo "  --noconfirm        Skip confirmation prompts during installation."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --noconfirm)
            NO_CONFIRM="--noconfirm"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [[ -z "$BRANCH_NAME" ]]; then
                BRANCH_NAME="$1"
            else
                CUSTOM_REPO_URL="$1"
            fi
            shift
            ;;
    esac
done

if [[ -n "$CUSTOM_REPO_URL" ]]; then
    REPO_URL="$CUSTOM_REPO_URL"
fi

error_exit() {
    echo "$1" 1>&2
    usage
    exit 1
}

usage() {
    echo "Usage: $0 <operation> [branch-name] [repository-url] [--noconfirm]"
    echo "Operations:"
    echo "  install    Clone a package from a branch of selected repo and install it."
    echo "             Requires a branch name (the package name)"
    echo "             Example: $0 install <package-name> [repository-url] [--noconfirm]"
    echo ""
    echo "  remove     Remove a package and all then-unused installed dependencies via pacman."
    echo "             Requires the package name (branch name)."
    echo "             Example: $0 remove <package-name>"
    echo ""
    echo "  search     Search for branches matching the specified branch name in the selected repository."
    echo "             Requires a search term."
    echo "             Example: $0 search <search-term>"
    echo ""
    echo "  searchex   Search for branches with an exact match to the specified branch name."
    echo "             Requires a search term."
    echo "             Example: $0 searchex <exact-search-term>"
    echo ""
    echo "  version    Fetch the version of a specific branch/package from the selected repository."
    echo "             Requires the package name (branch name)."
    echo "             Example: $0 version <package-name>"
    echo ""
    echo "Options:"
    echo "  -h, --help         Show this help message."
    echo "  --noconfirm        Skip confirmation prompts during installation."
    exit 1
}

if [ -z "$OPERATION" ]; then
    usage
fi

if [[ ! "$OPERATION" =~ ^(install|remove|search|searchex|version)$ ]]; then
    usage
fi

if [[ "$OPERATION" == "install" || "$OPERATION" == "remove" || "$OPERATION" == "version" ]]; then
    if [ -z "$BRANCH_NAME" ]; then
        error_exit "Branch name must be specified for $OPERATION."
    fi
fi

if ! sudo -v; then
    echo "Sudo authorization required. Please try again."
    exit 1
fi

TEMP_DIR="$HOME/tmpcafe"

if [ -d "$TEMP_DIR" ]; then
    echo "Clearing existing temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR" || error_exit "Failed to remove existing temporary directory."
fi

mkdir -p "$TEMP_DIR" || error_exit "Unable to create temporary directory."


if [ "$OPERATION" = "install" ]; then
    echo "Cloning branch '$BRANCH_NAME' from repository '$REPO_URL'..."
    
    git clone --single-branch --branch "$BRANCH_NAME" "$REPO_URL" "$TEMP_DIR" || {
        echo "Failed to clone branch '$BRANCH_NAME'. Aborting..."
        rm -rf "$TEMP_DIR"
        exit 1
    }

    cd "$TEMP_DIR" || {
        echo "Failed to enter the cloned repository. Aborting operation."
        rm -rf "$TEMP_DIR"
        exit 1
    }

    if [ ! -f "PKGBUILD" ]; then
        echo "PKGBUILD file not found. Aborting."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    PKGVER=$(grep "^pkgver=" PKGBUILD | cut -d'=' -f2 | tr -d ' ')
    if ! makepkg -si ${NO_CONFIRM}; then
        echo "Installation failed due to dependency issues."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    TAR_FILE=$(find . -name '*.pkg.tar.*' | head -n 1)
    if [ -z "$TAR_FILE" ]; then
        rm -rf "$TEMP_DIR"
        error_exit "No package file found!"
    fi

    PACKAGE_NAME="$(basename "$TAR_FILE" .pkg.tar.*)"
    PACKAGE_VERSION="${PACKAGE_NAME##*-}"  
    echo "Package '$PACKAGE_NAME' version '$PACKAGE_VERSION' installed successfully."

    rm -rf "$TEMP_DIR"

elif [ "$OPERATION" = "remove" ]; then
    echo "Removing package '$BRANCH_NAME'..."
    if ! sudo pacman -Rns "$BRANCH_NAME" ${NO_CONFIRM}; then
        echo "Package removal failed."
        exit 1
    fi
    echo "Removed package '$BRANCH_NAME'."

elif [ "$OPERATION" = "search" ]; then
    echo "Searching for branches matching '$BRANCH_NAME'..."
    git ls-remote --heads "$REPO_URL" | grep "$BRANCH_NAME" | while read -r hash ref; do
        echo "Found branch: $ref (Commit: $hash)"
    done || {
        echo "No matching branches found."
    }

elif [ "$OPERATION" = "searchex" ]; then
    echo "Searching for branches with exact match '$BRANCH_NAME'..."
    git ls-remote --heads "$REPO_URL" | grep "/$BRANCH_NAME$" | while read -r hash ref; do
        echo "Found exact match: $ref (Commit: $hash)"
    done || {
        echo "No matching branches found."
    }

elif [ "$OPERATION" = "version" ]; then
    if [ -n "$BRANCH_NAME" ]; then
        echo "Fetching version for branch '$BRANCH_NAME'..."
        git ls-remote --heads "$REPO_URL" | grep "$BRANCH_NAME" &> /dev/null
        if [ $? -ne 0 ]; then
            error_exit "Branch '$BRANCH_NAME' does not exist in the repository."
        fi

        git clone --single-branch --branch "$BRANCH_NAME" "$REPO_URL" "$TEMP_DIR" || {
            rm -rf "$TEMP_DIR"
            error_exit "Failed to clone branch '$BRANCH_NAME'."
        }

        cd "$TEMP_DIR" || {
            rm -rf "$TEMP_DIR"
            error_exit "Failed to enter the cloned repository."
        }

        if [ ! -f "PKGBUILD" ]; then
            echo "PKGBUILD file not found. Aborting."
            rm -rf "$TEMP_DIR"
            exit 1
        fi

        # Use safer approach to get the version from PKGBUILD
        VERSION=$(grep -E "^pkgver=" PKGBUILD | cut -d'=' -f2 | xargs)
        if [ -z "$VERSION" ]; then
            echo "No version found in PKGBUILD."
        else
            echo "Version of '$BRANCH_NAME' is: $VERSION"
        fi

        rm -rf "$TEMP_DIR"
    fi

fi
