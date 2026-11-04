#! /usr/bin/env bash
#
# Builds a self-contained, single-file TclProDebug "starpack" for one platform.
#
# The result is a Tcl/Tk 8.6 runtime (built from source with KitCreator) with
# the debugger application and the "parser" extension compiled/embedded into
# it.  Nothing needs to be installed to run it.  Note that the debugger's own
# runtime is independent of the interpreter you debug with: the application
# being debugged runs in whatever tclsh/wish you point the project at (Tcl 8.5,
# 8.6 or 9.x).
#
# Usage:   packaging/build-starpack.sh <target>
#
# Targets: linux-x86_64     build on Linux
#          windows-x86_64   cross-compile on Linux (needs mingw-w64)
#          macos-arm64      build on an Apple Silicon Mac
#          macos-x86_64     build on an Intel Mac
#
# Environment:
#   KITCREATOR_DIR   checkout of https://github.com/rkeene/kitcreator
#                    (default: ./.kitcreator).  CI pins a commit.
#   TCLVERS          Tcl/Tk version to build (default 8.6.12, the newest that
#                    KitCreator can verify against a known checksum).
#   KIT_STORAGE      how the application is stored in the executable:
#                    cvfs (default; compiled into the binary, so the file is
#                    never modified after linking and can be code-signed) or zip.
#   DIST_DIR         where to put the result (default: ./dist).
#
# Requires: bash, a C compiler, autoconf, make, and a native tclsh (to run
# KitCreator's own scripts).  On Linux the X11, Xft and fontconfig development
# headers are needed for Tk.

set -euo pipefail

target="${1:-}"
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "${here}/.." && pwd)"
kc="$(cd "${KITCREATOR_DIR:-${root}/.kitcreator}" && pwd)"
TCLVERS="${TCLVERS:-8.6.12}"
KIT_STORAGE="${KIT_STORAGE:-cvfs}"
dist="${DIST_DIR:-${root}/dist}"
mkdir -p "${dist}"

die() { echo "error: $*" >&2; exit 1; }

case "${target}" in
	linux-x86_64|windows-x86_64|macos-arm64|macos-x86_64) ;;
	*) die "usage: $0 {linux-x86_64|windows-x86_64|macos-arm64|macos-x86_64}" ;;
esac

# ---------------------------------------------------------------------------
# 1. Stage the pieces KitCreator will build.
# ---------------------------------------------------------------------------

# The manifest lists every file of the application.  Fail loudly if it is out
# of date instead of silently producing a broken program.
missing=0
while read -r f; do
	[ -z "${f}" ] && continue
	if [ ! -e "${root}/${f}" ]; then
		echo "starkit.manifest lists a file that does not exist: ${f}" >&2
		missing=1
	fi
done < "${root}/starkit.manifest"
[ "${missing}" = 0 ] || die "starkit.manifest is out of date"

# Application: the manifest files, laid out as they are in the repository.
rm -rf "${kc}/tclprodebug" "${kc}/tclparser"
mkdir -p "${kc}/tclprodebug/buildsrc" "${kc}/tclparser/buildsrc"
cp "${here}/kitcreator/tclprodebug/build.sh" "${kc}/tclprodebug/build.sh"
while read -r f; do
	[ -z "${f}" ] && continue
	mkdir -p "${kc}/tclprodebug/buildsrc/$(dirname "${f}")"
	cp "${root}/${f}" "${kc}/tclprodebug/buildsrc/${f}"
done < "${root}/starkit.manifest"

# Parser extension: linked into the kit statically.
cp "${here}/kitcreator/tclparser/build.sh" "${kc}/tclparser/build.sh"
cp -R "${root}/lib/tclparser/." "${kc}/tclparser/buildsrc/"
rm -rf "${kc}/tclparser/buildsrc/tests" "${kc}/tclparser/buildsrc/doc"
chmod +x "${kc}/tclprodebug/build.sh" "${kc}/tclparser/build.sh"

# ---------------------------------------------------------------------------
# 2. Per-platform toolchain settings.
# ---------------------------------------------------------------------------

flags=()
exe_suffix=""
case "${target}" in
	linux-x86_64)
		;;
	windows-x86_64)
		triple=x86_64-w64-mingw32
		export AR="${triple}-ar" CC="${triple}-gcc" CXX="${triple}-g++"
		export RANLIB="${triple}-ranlib" RC="${triple}-windres"
		export STRIP="${STRIP:-${triple}-strip}"
		# Tcl's configure cannot run test programs when cross-compiling and
		# assumes the worst; tell it what we know to be true.
		export ac_cv_func_memcmp_working=yes tcl_cv_strstr_unbroken=ok \
			tcl_cv_strtoul_unbroken=ok tcl_cv_strtod_unbroken=ok \
			tcl_cv_strtod_buggy=ok
		flags+=(--host="${triple}")
		exe_suffix=".exe"
		;;
	macos-arm64|macos-x86_64)
		arch="${target#macos-}"
		export CC="clang -arch ${arch}" CXX="clang++ -arch ${arch}"
		# Keep the binaries runnable on reasonably old systems.
		export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-11.0}"
		flags+=(--enable-aqua)
		;;
esac

export KITCREATOR_PKGS="tk tclparser tclprodebug"
export STATICTK=1
flags+=("--enable-kit-storage=${KIT_STORAGE}")

# ---------------------------------------------------------------------------
# 3. Build.
# ---------------------------------------------------------------------------

cd "${kc}"
if ! find kitsh/buildsrc -name configure -type f | grep -q .; then
	./build/pre.sh
fi

# Print KitCreator's per-package logs (collapsible in GitHub Actions).
# Usage: show_logs <lines> [package...]   (no packages = all of them)
show_logs() {
	local lines="$1"; shift
	local log pkg
	local pkgs=("$@")
	if [ "${#pkgs[@]}" = 0 ]; then
		pkgs=($(ls -d */ | tr -d /))
	fi
	for pkg in "${pkgs[@]}"; do
		log="${pkg}/build.log"
		[ -f "${log}" ] || continue
		echo "::group::${log} (last ${lines} lines)"
		tail -n "${lines}" "${log}"
		echo "::endgroup::"
	done
}

./kitcreator distclean >/dev/null 2>&1 || true
if ! ./kitcreator "${TCLVERS}" "${flags[@]}"; then
	show_logs 80
	die "KitCreator failed"
fi
[ -f "tclkit-${TCLVERS}" ] || { show_logs 80; die "KitCreator did not produce a kit"; }
# Always show the logs of the parts we add; they are the ones most likely to
# need attention and are short.
show_logs 400 tclparser tclprodebug
show_logs 60 kitsh

out="${dist}/TclProDebug-${target}${exe_suffix}"
cp "tclkit-${TCLVERS}" "${out}"
chmod +x "${out}"

# Apple Silicon refuses to run unsigned code; an ad-hoc signature is enough to
# run locally (distribution outside the App Store additionally needs the
# quarantine flag cleared, see the README).
case "${target}" in
	macos-*) codesign --force --sign - "${out}" ;;
esac

echo "Built ${out} ($(wc -c < "${out}") bytes)"
