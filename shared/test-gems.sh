#!/bin/bash
# set -e

SELFDIR=`dirname "$0"`
SELFDIR=`cd "$SELFDIR" && pwd`
source "$SELFDIR/library.sh"

BUILD_OUTPUT_DIR=

function usage()
{
	echo "Usage: ./test-gems.sh [options] <BUILD OUTPUT DIR>"
	echo "Test the native extension gems."
	echo
	echo "Options:"
	echo "  -h         Show this help"
}

function parse_options()
{
	local OPTIND=1
	local opt
	while getopts "ha:p:" opt; do
		case "$opt" in
		h)
			usage
			exit
			;;
		p)
			PLATFORM="$OPTARG"
			;;
		a)
			ARCHITECTURE="$OPTARG"
			;;
		*)
			return 1
			;;
		esac
	done

	(( OPTIND -= 1 )) || true
	shift $OPTIND || true
	BUILD_OUTPUT_DIR="$1"

	if [[ "$BUILD_OUTPUT_DIR" = "" ]]; then
		usage
		exit 1
	fi
	if [[ ! -e "$BUILD_OUTPUT_DIR" ]]; then
		echo "ERROR: $BUILD_OUTPUT_DIR doesn't exist."
		exit 1
	fi

	if [[ "$PLATFORM" = "" ]]; then
		PLATFORM=$(uname | tr '[:upper:]' '[:lower:]')
		if [[ "$PLATFORM" = "darwin" ]]; then
			PLATFORM="macos"
		fi
	fi

	if [[ "$PLATFORM" != "" && "$PLATFORM" != "macos" && "$PLATFORM" != "windows" && "$PLATFORM" != "linux" ]]; then
		echo "ERROR: Invalid platform specified. Must be 'macos', 'windows', or 'linux'."
		exit 1
	fi

	if [[ "$ARCHITECTURE" = "" ]]; then
		if [[ "$BUILD_OUTPUT_DIR" == *"arm64"* ]]; then
			ARCHITECTURE="arm64"
		elif [[ "$BUILD_OUTPUT_DIR" == *"x86_64"* ]]; then
			ARCHITECTURE="x86_64"
		fi
	fi

	if [[ "$ARCHITECTURE" != "" && "$ARCHITECTURE" != "arm64" && "$ARCHITECTURE" != "x86_64" ]]; then
		echo "ERROR: Invalid architecture specified. Must be 'arm64' or 'x86_64'."
		exit 1
	fi
}


parse_options "$@"

# Set executable suffix for Windows
if [[ "$PLATFORM" = "windows" ]]; then
	EXE_SUFFIX=".bat"
else
	EXE_SUFFIX=""
fi

##########

GEMS_TO_TEST=(
	)
GEMS_TO_FAIL=(
	)
if [[ "$PLATFORM" != "windows" ]]; then
	GEMS_TO_FAIL+=(
		"win32ole"
		"win32/registry"
	)
fi
GEMS_TO_SKIP=(
rubocop
rubocop-ast
rubocop-performance
rubocop-rails
rubocop-rails-omakase
repl_type_completor
solid_cable
vips
)
# /home/linux/output/3.4.7-arm64/lib/ruby/gems/3.4.0/gems/ffi-1.17.2/lib/ffi/dynamic_library.rb:94:in 'FFI::DynamicLibrary.load_library': Could not open library 'vips.so.42': vips.so.42: cannot open shared object file: No such file or directory. (LoadError)
# Could not open library 'libvips.so.42': libvips.so.42: cannot open shared object file: No such file or directory.
if [[ "$BUILD_OUTPUT_DIR" == *"3.0."* ]]; then
	GEMS_TO_FAIL+=("debug")
fi

echo "Testing gems in $BUILD_OUTPUT_DIR"
echo "Platform: $PLATFORM"
echo "Architecture: $ARCHITECTURE"
echo "Gems to test: ${GEMS_TO_TEST[@]}"
echo "Gems to fail: ${GEMS_TO_FAIL[@]}"

header "Listing gems versions in $BUILD_OUTPUT_DIR"
GEM_LIST=$("$BUILD_OUTPUT_DIR/bin/gem$EXE_SUFFIX" list)
echo "$GEM_LIST"
echo "$GEM_LIST" >> "$BUILD_OUTPUT_DIR/test_report"
# header "modifying gem names in $BUILD_OUTPUT_DIR for testing"
GEMS=($("$BUILD_OUTPUT_DIR/bin/gem$EXE_SUFFIX" list | awk '{gsub(/tzinfo-data/, "tzinfo/data"); gsub(/bundler-audit/, "bundler/audit"); gsub(/ruby-vips/, "vips"); gsub(/rubyzip/, "zip"); gsub(/unicode-emoji/, "unicode/emoji"); gsub(/unicode-display_width/, "unicode/display_width"); gsub(/rinda/, "rinda/rinda"); gsub(/win32-registry/, "win32/registry"); gsub(/io-/, "io/"); gsub(/net-/, "net/"); gsub(/term-ansicolor/, "term/ansicolor"); gsub(/yajl-ruby/, "yajl"); gsub(/railties/, "rails/railtie"); gsub(/semver2/, "semver"); gsub(/pact-provider-verifier/, "pact/provider_verifier/cli/verify"); gsub(/pact_broker-client/, "pact_broker/client/tasks"); gsub(/pact-/, "pact/"); gsub(/faraday-/, "faraday/"); gsub(/action_text-trix/, "action_text/trix"); gsub(/actioncable/, "action_cable"); gsub(/actionmailbox/, "action_mailbox"); gsub(/actionmailer/, "action_mailer"); gsub(/actionpack/, "action_pack"); gsub(/actiontext/, "action_text"); gsub(/actionview/, "action_view"); gsub(/activejob/, "active_job"); gsub(/activemodel/, "active_model"); gsub(/activerecord/, "active_record"); gsub(/activestorage/, "active_storage"); gsub(/activesupport/, "active_support"); gsub(/as-notifications/, "as/notifications"); gsub(/rack-session/, "rack/session"); gsub(/rack-test/, "rack/test"); gsub(/ruby-next-core/, "ruby-next/core"); gsub(/websocket-driver/, "websocket/driver"); gsub(/websocket-extensions/, "websocket/extensions"); sub(/-ext$/, ""); sub(/-ruby$/, ""); sub(/english/, "English"); print $1}' | grep -v -- "-ext"))
if [ ${#GEMS[@]} -eq 0 ]; then
	GEMS=("${GEMS_TO_TEST[@]}")
else
	all_gems=("${GEMS[@]}" "${GEMS_TO_TEST[@]}")
	GEMS=("${all_gems[@]}")
fi

header "Testing gems..."
export LD_BIND_NOW=1
export DYLD_BIND_AT_LAUNCH=1
ERRORS=()
for LIB in ${GEMS[@]}; do
	if [[ " ${GEMS_TO_SKIP[@]} " =~ " ${LIB} " ]]; then # Check if the current gem is in the GEMS_TO_SKIP array
		warning "Skipping gem $LIB"
		continue
	fi
	if ! "$BUILD_OUTPUT_DIR/bin/ruby$EXE_SUFFIX" -r$LIB -e true ; then
		if [[ "$LIB" == "action_text/trix" || "$LIB" == "rails/railtie" || "$LIB" == "solid_cache" || "$LIB" == "solid_cable" || "$LIB" == "solid_queue" || "$LIB" == "stimulus-rails" || "$LIB" == "turbo-rails" || "$LIB" == "active_storage" ]]; then
			echo "Testing $LIB with active_support/all required first"
			if "$BUILD_OUTPUT_DIR/bin/ruby$EXE_SUFFIX" -rrails -ractive_support -ractive_model -r$LIB -e true ; then
				success "Gem $LIB OK!"
				continue
			fi
		fi
		if [[ "$LIB" == "eventmachine" || "$LIB" == "thin" ]]; then
			echo "Testing $LIB with em/pure_ruby required first"
			if "$BUILD_OUTPUT_DIR/bin/ruby$EXE_SUFFIX" -rem/pure_ruby -r$LIB -e true ; then
				success "Gem $LIB OK!"
				continue
			fi
		fi
		if [[ ! " ${GEMS_TO_FAIL[@]} " =~ " ${LIB} " ]]; then # Check if the current gem is not in the GEMS_TO_FAIL array
			ERRORS+=("$LIB")
		else # If the current gem is in the GEMS_TO_FAIL array, then it's OK
			warning "Gem $LIB failed to load but exit code supressed. "
		fi
	else
		success "Gem $LIB OK!"
		if [[ "$LIB" == "pact/ffi" ]]; then
		echo "Testing pact-ffi gem loads shared library (via ffi gem)"
		"$BUILD_OUTPUT_DIR/bin/ruby$EXE_SUFFIX" -r$LIB -e "puts PactFfi.pactffi_version"
		fi
	fi
done

if [ ${#ERRORS[@]} -eq 0 ]; then
	success "All gems OK!"
	echo "All gems OK!" > "$BUILD_OUTPUT_DIR/test_report"
else
	error "The following gems failed to load:"
	printf '%s\n' "${ERRORS[@]}"
	echo "The following gems failed to load:" > "$BUILD_OUTPUT_DIR/test_report"
	printf '%s\n' "${ERRORS[@]}" >> "$BUILD_OUTPUT_DIR/test_report"
	exit 1 
fi