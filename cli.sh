#!/usr/bin/env sh
set -e
## Tested with https://www.shellcheck.net/

# Usage: (install latest release & its default ruby version)
#   $ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | sh
# or
#   $ wget -q https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh -O- | sh

# Options
# TRAVELING_RUBY_VERSION - set ruby version eg TRAVELING_RUBY_VERSION=3.4.12
# TRAVELING_RUBY_RELEASE_TAG - set release tag eg TRAVELING_RUBY_RELEASE_TAG=rel-20261102
# TRAVELING_RUBY_INSTALL_PATH - set install path eg TRAVELING_RUBY_INSTALL_PATH=$HOME/.travelling-ruby
# TRAVELING_RUBY_CLEAN_INSTALL - set to true to remove existing install eg TRAVELING_RUBY_CLEAN_INSTALL=true

# Usage: (install fixed version of a release) -
#   $ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | TRAVELING_RUBY_RELEASE_TAG=rel-20261102 sh
# or
#   $ wget -q https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh -O- | TRAVELING_RUBY_RELEASE_TAG=rel-20261102 sh

# Usage: (install fixed version of ruby) -
#   $ curl -fsSL https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh | TRAVELING_RUBY_VERSION=3.4.12 sh
# or
#   $ wget -q https://raw.githubusercontent.com/trubygems/traveling-ruby/main/cli.sh -O- | TRAVELING_RUBY_VERSION=3.4.12 sh

PROJECT_NAME='traveling-ruby'
TRAVELING_RUBY_GH_SOURCE=${TRAVELING_RUBY_GH_SOURCE:-trubygems/${PROJECT_NAME}}

usage() {
  echo "Usage: $0 [-v <version>] [-d <release-date>] [--set-path] [--clean-install] [--ci]"
  echo ""
  echo "  -v <version>          Ruby version to install (default: the first version built by the release)"
  echo "  -d <release-date>     Release date of the traveling ruby package to download (default: latest)"
  echo "  --set-path            Add the traveling ruby bin path to the PATH environment variable (default: false)"
  echo "  --clean-install       Remove any existing traveling ruby installation before installing (default: false)"
  echo "  --ci                  Set --set-path to true and --clean-install to true (default: false)"
  echo "  -g                    list of gems to install"
  exit 0
}

while getopts "hg:v:d:-:" opt; do
  case $opt in
  v)
    TRAVELING_RUBY_VERSION=$OPTARG
    ;;
  d)
    TRAVELING_RUBY_PKG_DATE=$OPTARG
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

if [ "$TRAVELING_RUBY_PKG_DATE" ]; then
  TRAVELING_RUBY_RELEASE_TAG=rel-${TRAVELING_RUBY_PKG_DATE}
elif [ -z "$TRAVELING_RUBY_RELEASE_TAG" ]; then
  TRAVELING_RUBY_RELEASE_TAG=$(basename "$(curl -fs -o/dev/null -w "%{redirect_url}" https://github.com/${TRAVELING_RUBY_GH_SOURCE}/releases/latest)")
fi
if [ -z "$TRAVELING_RUBY_RELEASE_TAG" ] || [ "$TRAVELING_RUBY_RELEASE_TAG" = "latest" ]; then
  echo "Sorry, could not find the latest release of ${PROJECT_NAME}, set it with -d <release-date>."
  exit 1
fi
TRAVELING_RUBY_PKG_DATE=$(echo "$TRAVELING_RUBY_RELEASE_TAG" | cut -d '-' -f 2)
echo "Thanks for downloading ${PROJECT_NAME} $TRAVELING_RUBY_RELEASE_TAG."
echo "-------------"
echo "Note:"
echo "-------------"
echo "You can download a fixed version by setting the TRAVELING_RUBY_RELEASE_TAG environment variable eg TRAVELING_RUBY_RELEASE_TAG=$TRAVELING_RUBY_RELEASE_TAG"
echo "example:"
echo "  curl -fsSL https://raw.githubusercontent.com/${TRAVELING_RUBY_GH_SOURCE}/main/cli.sh | TRAVELING_RUBY_RELEASE_TAG=$TRAVELING_RUBY_RELEASE_TAG sh"

# Each release lists the ruby versions it builds, the first one is its default
if [ -z "$TRAVELING_RUBY_VERSION" ]; then
  TRAVELING_RUBY_VERSION=$(curl -fsS "https://raw.githubusercontent.com/${TRAVELING_RUBY_GH_SOURCE}/${TRAVELING_RUBY_RELEASE_TAG}/versions/RUBY_VERSIONS.txt" | head -n 1)
fi
if [ -z "$TRAVELING_RUBY_VERSION" ]; then
  echo "Sorry, could not find the ruby versions in ${TRAVELING_RUBY_RELEASE_TAG}, set one with -v <version>."
  exit 1
fi

echo "-------------"
echo "You can download a fixed ruby version by setting the TRAVELING_RUBY_VERSION environment variable eg TRAVELING_RUBY_VERSION=$TRAVELING_RUBY_VERSION"
echo "example:"
echo "  curl -fsSL https://raw.githubusercontent.com/${TRAVELING_RUBY_GH_SOURCE}/main/cli.sh | TRAVELING_RUBY_VERSION=$TRAVELING_RUBY_VERSION sh"
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
TRAVELING_RUBY_BASENAME=traveling-ruby-${TRAVELING_RUBY_PKG_DATE}-${TRAVELING_RUBY_VERSION}-${TRAVELING_RUBY_PLATFORM}
TRAVELING_RUBY_FILENAME="${TRAVELING_RUBY_BASENAME}.tar.gz"
TRAVELING_RUBY_BIN_PATH="${TRAVELING_RUBY_INSTALL_PATH}/bin"
echo "-------------"
echo "TRAVELING_RUBY_PKG_DATE: $TRAVELING_RUBY_PKG_DATE"
echo "TRAVELING_RUBY_VERSION: $TRAVELING_RUBY_VERSION"
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
