# Packaging: single-file executables ("starpacks")

TclProDebug is built into one self-contained executable per platform, so users
do not need to install Tcl/Tk, compile the `parser` extension, or run any build
tools:

| File                              | Platform                          |
|-----------------------------------|-----------------------------------|
| `TclProDebug-linux-x86_64`        | Linux, x86-64 (needs X11 libraries, present on any desktop) |
| `TclProDebug-windows-x86_64.exe`  | Windows, 64-bit                   |
| `TclProDebug-macos-arm64`         | macOS, Apple Silicon              |
| `TclProDebug-macos-x86_64`        | macOS, Intel                      |

The executable contains its own Tcl/Tk 8.6 runtime. **That is independent of the
program you debug**: your application runs in whichever `tclsh`/`wish` you select
in the project settings (Tcl 8.5, 8.6 and 9.x are supported, Tk 9 included).

## How it is built

`packaging/build-starpack.sh <target>` does the whole build:

1. Checks that every file in `starkit.manifest` exists (so a stale manifest fails
   the build instead of producing a broken program).
2. Hands two packages to [KitCreator](https://github.com/rkeene/kitcreator)
   (pinned to an exact commit in `.github/workflows/starpack.yml`):
   * `tclparser`: `lib/tclparser`, compiled and **linked statically** into the
     runtime (no shared library to extract or load at run time);
   * `tclprodebug`: the application files listed in `starkit.manifest`, stored at
     the root of the executable's virtual file system, which makes `main.tcl` the
     program that runs at startup.
3. KitCreator builds Tcl 8.6.12 and Tk 8.6.12 (the newest versions it can verify
   against a known checksum) from source and produces the executable. The
   application is compiled *into* the binary (`cvfs` storage) rather than
   appended to it, so the file is never modified after linking. That keeps it
   code-signable on macOS.

Windows is cross-compiled on Linux with mingw-w64; the other targets are built
natively on their own platform.

### Building locally

```sh
git clone https://github.com/rkeene/kitcreator .kitcreator
git -C .kitcreator checkout dc14b6f1f0ac82d4a694b6dba0187fceaec668b1
packaging/build-starpack.sh linux-x86_64     # result: dist/TclProDebug-linux-x86_64
```

You need a C compiler, `autoconf`, `make` and a native `tclsh`; on Linux also the
X11, Xft and fontconfig development headers (see the workflow for the exact
package list).

## Testing

Every binary can check itself:

```sh
TclProDebug --selftest report.txt [debuggee-interpreter]
```

It verifies Tk, the parser and the debugger package, and, if you name an
interpreter (e.g. `tclsh9.0`), runs a short Tcl/Tk program under the real
debugger engine in that interpreter. The report is written to `report.txt` and
the exit status is 0 only if everything passed. CI runs this on each platform:
Linux against Tcl 8.6 and Tk 9, macOS against Tcl 8.6 and Tcl/Tk 9, Windows
against nothing but itself (no interpreter is installed on the runner).

## Releasing

Push a tag named `vX.Y.Z`. The workflow builds all four binaries, tests them, and
creates a GitHub release containing archives (`.tar.gz` for Linux/macOS,
`.zip` for Windows) and a `SHA256SUMS` file. Pushes to branches and pull
requests build and test but do not publish; the binaries are available as
workflow artifacts.

## Notes for users

* **macOS**: the binaries are ad-hoc signed, not notarized. After downloading in
  a browser, clear the quarantine flag once:
  `xattr -d com.apple.quarantine TclProDebug-macos-*`.
* **Windows**: the executable is unsigned, so SmartScreen may warn on first run.
* The VS Code debug adapter (`bin/debugadapter`) is a separate entry point and is
  not part of the starpack; it still runs from a checkout with `tclsh`.
