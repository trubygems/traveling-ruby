#!/usr/bin/env sh
set -e
## Tested with https://www.shellcheck.net/

# Usage: (install the newest ruby version)
#   $ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh
# or
#   $ wget -q https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh -O- | sh

# Options
# TRAVELING_RUBY_VERSION - set ruby version eg TRAVELING_RUBY_VERSION=3.4.12
# TRAVELING_RUBY_REVISION - set package revision of the ruby version eg TRAVELING_RUBY_REVISION=0 (default: the newest)
# TRAVELING_RUBY_INSTALL_PATH - set install path eg TRAVELING_RUBY_INSTALL_PATH=$HOME/.travelling-ruby
# TRAVELING_RUBY_CLEAN_INSTALL - set to true to remove existing install eg TRAVELING_RUBY_CLEAN_INSTALL=true

# Usage: (install fixed version of ruby) -
#   $ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | TRAVELING_RUBY_VERSION=3.4.12 sh
# or
#   $ wget -q https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh -O- | TRAVELING_RUBY_VERSION=3.4.12 sh

# Usage: (install fixed version and revision of ruby) -
#   $ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | TRAVELING_RUBY_VERSION=3.4.12 TRAVELING_RUBY_REVISION=0 sh

# Each ruby version, revision and platform has its own release, eg ruby-3.4.12-0-linux-x86_64.
# A revision is a rebuild of the same ruby version.

PROJECT_NAME='traveling-ruby'
TRAVELING_RUBY_GH_SOURCE=${TRAVELING_RUBY_GH_SOURCE:-trubygems/${PROJECT_NAME}}

usage() {
  echo "Usage: $0 [-v <version>] [-r <revision>] [--set-path] [--clean-install] [--ci]"
  echo ""
  echo "  -v <version>          Ruby version to install (default: the newest)"
  echo "  -r <revision>         Package revision of the ruby version (default: the newest)"
  echo "  --set-path            Add the traveling ruby bin path to the PATH environment variable (default: false)"
  echo "  --clean-install       Remove any existing traveling ruby installation before installing (default: false)"
  echo "  --ci                  Set --set-path to true and --clean-install to true (default: false)"
  echo "  -g                    list of gems to install"
  exit 0
}

while getopts "hg:v:r:-:" opt; do
  case $opt in
  v)
    TRAVELING_RUBY_VERSION=$OPTARG
    ;;
  r)
    TRAVELING_RUBY_REVISION=$OPTARG
    ;;
  g)
  TRAVELING_RUBY_GEM_LIST=$OPTARG
  ;;
  -)
    case "${OPTARG}" in
    set-path)
      TRAVELING_RUBY_SET_PATH=true
      ;;
    clean-install)
      TRAVELING_RUBY_CLEAN_INSTALL=true
      ;;
    ci)
      TRAVELING_RUBY_SET_PATH=true
      TRAVELING_RUBY_CLEAN_INSTALL=true
      ;;
    esac
    ;;
  h|*)
  usage
  ;;
  esac
done

# The latest release is the newest ruby version's, tagged ruby-<version>-<revision>-linux-x86_64
if [ -z "$TRAVELING_RUBY_VERSION" ]; then
  TRAVELING_RUBY_LATEST=$(basename "$(curl -fs -o/dev/null -w "%{redirect_url}" https://github.com/${TRAVELING_RUBY_GH_SOURCE}/releases/latest)")
  TRAVELING_RUBY_VERSION=$(echo "$TRAVELING_RUBY_LATEST" | sed -nE 's/^ruby-([^-]+)-([0-9]+)-.*/\1/p')
  TRAVELING_RUBY_REVISION=${TRAVELING_RUBY_REVISION:-$(echo "$TRAVELING_RUBY_LATEST" | sed -nE 's/^ruby-([^-]+)-([0-9]+)-.*/\2/p')}
fi
if [ -z "$TRAVELING_RUBY_VERSION" ]; then
  echo "Sorry, could not find the latest release of ${PROJECT_NAME}, set a ruby version with -v <version>."
  exit 1
fi
# Revisions are listed on main, one "<version> <revision>" per line
if [ -z "$TRAVELING_RUBY_REVISION" ]; then
  TRAVELING_RUBY_REVISION=$(curl -fsS "https://raw.githubusercontent.com/${TRAVELING_RUBY_GH_SOURCE}/main/versions/RUBY_REVISIONS.txt" | awk -v v="$TRAVELING_RUBY_VERSION" '$1 == v { print $2 }')
fi
TRAVELING_RUBY_REVISION=${TRAVELING_RUBY_REVISION:-0}
TRAVELING_RUBY_RELEASE=${TRAVELING_RUBY_VERSION}-${TRAVELING_RUBY_REVISION}
echo "Thanks for downloading ${PROJECT_NAME} $TRAVELING_RUBY_RELEASE."
echo "-------------"
echo "Note:"
echo "-------------"
echo "You can download a fixed ruby version and revision by setting the TRAVELING_RUBY_VERSION and TRAVELING_RUBY_REVISION environment variables"
echo "example:"
echo "  curl -fsSL https://raw.githubusercontent.com/${TRAVELING_RUBY_GH_SOURCE}/main/cli.sh | TRAVELING_RUBY_VERSION=$TRAVELING_RUBY_VERSION TRAVELING_RUBY_REVISION=$TRAVELING_RUBY_REVISION sh"
echo "-------------"

echo "detecting platform & architecture"
case $(uname -sm) in
'Linux x86_64')
  TRAVELING_RUBY_OS=linux
  TRAVELING_RUBY_ARCH=x86_64
  ;;
'Linux aarch64')
  TRAVELING_RUBY_OS=linux
  TRAVELING_RUBY_ARCH=arm64
  ;;
'Darwin arm64')
  TRAVELING_RUBY_OS=macos
  TRAVELING_RUBY_ARCH=arm64
  ;;
'Darwin x86_64')
  TRAVELING_RUBY_OS=macos
  TRAVELING_RUBY_ARCH=x86_64
  ;;
"Windows"* | "MINGW"* | "MSYS"* | "CYGWIN"*)
  TRAVELING_RUBY_OS=windows
  # x64 shells on Windows on Arm report x86_64, the processor does not
  case "$(uname -m) ${PROCESSOR_IDENTIFIER}" in
  aarch64* | arm64* | *ARM*)
    TRAVELING_RUBY_ARCH=arm64
    ;;
  *)
    TRAVELING_RUBY_ARCH=x86_64
    ;;
  esac
  ;;
*)
  echo "Sorry, you'll need to install the ${PROJECT_NAME} manually."
  exit 1
  ;;
esac

if [ "$TRAVELING_RUBY_OS" = "linux" ] && ldd --version 2>&1 | grep -qi musl; then
  TRAVELING_RUBY_OS=linux-musl
fi

TRAVELING_RUBY_EXE_SUFFIX=
if [ "$TRAVELING_RUBY_OS" = "windows" ]; then
  TRAVELING_RUBY_EXE_SUFFIX=.bat
fi

TRAVELING_RUBY_PLATFORM="${TRAVELING_RUBY_OS}-${TRAVELING_RUBY_ARCH}"
TRAVELING_RUBY_INSTALL_PATH="${TRAVELING_RUBY_INSTALL_PATH:-$HOME/.travelling-ruby}"
TRAVELING_RUBY_BASENAME=traveling-ruby-${TRAVELING_RUBY_RELEASE}-${TRAVELING_RUBY_PLATFORM}
TRAVELING_RUBY_RELEASE_TAG=ruby-${TRAVELING_RUBY_RELEASE}-${TRAVELING_RUBY_PLATFORM}
TRAVELING_RUBY_FILENAME="${TRAVELING_RUBY_BASENAME}.tar.gz"
TRAVELING_RUBY_BIN_PATH="${TRAVELING_RUBY_INSTALL_PATH}/bin"
echo "-------------"
echo "TRAVELING_RUBY_VERSION: $TRAVELING_RUBY_VERSION"
echo "TRAVELING_RUBY_REVISION: $TRAVELING_RUBY_REVISION"
echo "TRAVELING_RUBY_RELEASE_TAG: $TRAVELING_RUBY_RELEASE_TAG"
echo "TRAVELING_RUBY_OS: $TRAVELING_RUBY_OS"
echo "TRAVELING_RUBY_ARCH: $TRAVELING_RUBY_ARCH"
echo "TRAVELING_RUBY_PLATFORM: $TRAVELING_RUBY_PLATFORM"
echo "TRAVELLING_RUBY_BASENAME: $TRAVELING_RUBY_BASENAME"
echo "TRAVELING_RUBY_GH_SOURCE: $TRAVELING_RUBY_GH_SOURCE"
echo "TRAVELING_RUBY_INSTALL_PATH: $TRAVELING_RUBY_INSTALL_PATH"
echo "TRAVELING_RUBY_FILENAME: $TRAVELING_RUBY_FILENAME"

if [ "$TRAVELING_RUBY_CLEAN_INSTALL" = "true" ]; then
  echo "-------------"
  echo "Cleaning up ${PROJECT_NAME} @ $TRAVELING_RUBY_INSTALL_PATH"
  rm -rf "$TRAVELING_RUBY_INSTALL_PATH"
fi

mkdir -p "$TRAVELING_RUBY_INSTALL_PATH"
cd "$TRAVELING_RUBY_INSTALL_PATH"

echo "-------------"
echo "Downloading:"
echo "-------------"
echo curl --fail -LO https://github.com/${TRAVELING_RUBY_GH_SOURCE}/releases/download/"${TRAVELING_RUBY_RELEASE_TAG}"/"${TRAVELING_RUBY_FILENAME}"
(curl --fail -LO https://github.com/${TRAVELING_RUBY_GH_SOURCE}/releases/download/"${TRAVELING_RUBY_RELEASE_TAG}"/"${TRAVELING_RUBY_FILENAME}" && echo downloaded "${TRAVELING_RUBY_FILENAME}") || (echo "Sorry, you'll need to install the ${PROJECT_NAME} manually." && exit 1)
(tar xzf "${TRAVELING_RUBY_FILENAME}" && echo unarchived "${TRAVELING_RUBY_FILENAME}") || (echo "Sorry, you'll need to unarchived ${PROJECT_NAME} manually." && exit 1)
(rm "${TRAVELING_RUBY_FILENAME}" && echo removed "${TRAVELING_RUBY_FILENAME}") || (echo "Sorry, you'll need to remove ${PROJECT_NAME} archive manually." && exit 1)

echo "${PROJECT_NAME} ${TRAVELING_RUBY_RELEASE_TAG} installed to $TRAVELING_RUBY_INSTALL_PATH"
echo "-------------------"
echo "Successfully installed ${PROJECT_NAME} to:"
echo "  $TRAVELING_RUBY_INSTALL_PATH:"
echo "-------------------"
echo "ls -1 $TRAVELING_RUBY_INSTALL_PATH"
echo "-------------------"
ls -1 "$TRAVELING_RUBY_INSTALL_PATH"
echo "-------------------"
echo "$TRAVELING_RUBY_BIN_PATH/ruby$TRAVELING_RUBY_EXE_SUFFIX --version"
echo "-------------------"

"$TRAVELING_RUBY_BIN_PATH/ruby$TRAVELING_RUBY_EXE_SUFFIX" --version || echo "Sorry, we couldnt find the right path to ruby to check the installed. Please check your installation at $TRAVELING_RUBY_BIN_PATH!"
echo "-------------------"

if [ "$TRAVELING_RUBY_SET_PATH" ]; then
  if [ "$GITHUB_PATH" ]; then
    TRAVELING_RUBY_CI_BIN_PATH=$TRAVELING_RUBY_BIN_PATH
    if [ "$TRAVELING_RUBY_OS" = "windows" ] && command -v cygpath >/dev/null; then
      TRAVELING_RUBY_CI_BIN_PATH=$(cygpath -w "$TRAVELING_RUBY_BIN_PATH")
    fi
    echo "Added the following to your path to make ${PROJECT_NAME} available:"
    echo ""
    echo "$TRAVELING_RUBY_CI_BIN_PATH"
    echo "$TRAVELING_RUBY_CI_BIN_PATH" >>"$GITHUB_PATH"
  elif [ "$CIRRUS_CI" ]; then
    echo "Added the following to your path to make ${PROJECT_NAME} available:"
    echo ""
    echo "PATH=$TRAVELING_RUBY_BIN_PATH:\${PATH}"
    echo "PATH=$TRAVELING_RUBY_BIN_PATH:${PATH}" >>"$CIRRUS_ENV"
  else
    echo "Add the following to your path to make ${PROJECT_NAME} available:"
    echo "--- Linux/MacOS/Windows Bash Users --------"
    echo ""
    echo "  PATH=$TRAVELING_RUBY_BIN_PATH:\${PATH}"
  fi
fi

if [ "$TRAVELING_RUBY_GEM_LIST" ]; then
  for GEM in $TRAVELING_RUBY_GEM_LIST; do
    # name-1.2.3 installs version 1.2.3, a name without a version suffix the latest
    GEM_NAME=$(echo "$GEM" | sed -E 's/-[0-9][^-]*$//')
    GEM_VERSION=$(echo "$GEM" | sed -nE 's/.*-([0-9][^-]*)$/\1/p')
    echo "-------------------"
    echo "gem install $GEM"
    echo "version: $GEM_VERSION"
    echo "-------------------"
    if [ "$GEM_VERSION" ]; then
      "$TRAVELING_RUBY_BIN_PATH/gem$TRAVELING_RUBY_EXE_SUFFIX" install "$GEM_NAME" -v "$GEM_VERSION"
    else
      "$TRAVELING_RUBY_BIN_PATH/gem$TRAVELING_RUBY_EXE_SUFFIX" install "$GEM_NAME"
    fi
    echo "-------------------"
  done
fi
