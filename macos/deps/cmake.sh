# https://github.com/Kitware/CMake/releases/
NAME=cmake
VERSION=4.4.5
URL=https://github.com/Kitware/CMake/releases/download/v$VERSION/cmake-$VERSION-macos-universal.tar.gz
SHA256=679e77a96b9ef9484cc6c1445255fc4f84206b48a65420efbedf16bdab55fbff
DEPS=

# Kitware's universal build; building CMake from source took longer than
# everything else put together
function build()
{
	fetch
	run mkdir -p "$RUNTIME_DIR/bin" "$RUNTIME_DIR/share"
	run cp -R cmake-$VERSION-macos-universal/CMake.app/Contents/bin/. "$RUNTIME_DIR/bin/"
	run cp -R cmake-$VERSION-macos-universal/CMake.app/Contents/share/. "$RUNTIME_DIR/share/"
}
