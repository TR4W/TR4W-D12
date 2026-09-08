# TR4W

TR4W — Cross-platform contest logging
The TRLOG-descended contest logger for Windows, macOS (pending), and Linux (pending).

Website available at https://tr4w.net

New to contesting? The big loggers are powerful — and intimidating enough that most newcomers give up and just use their everyday logger, missing dupe checking, spotting, and live scoring. TR4W takes the other path: type the exchange in plain order into one field, let the software handle CW and FT8 for you, and plug a modern radio straight into the network. Real contest features, none of the learning cliff. 

## Free and open-source.

We welcome you to check out the code. 

- Want to see how to send multi-cast UDP from a FreePascal/Lazarus app to WSJT-X? It's in the code. 

- Want to see how to talk to a Kenwood, Elecraft, Flex or Icom radio over the network? 

- What about statically linking to the hamlib C library? 

- Implementing a waterfall display from a K4, Flex, Icom? 

- What about code to automatically download the latest CTY.DAT or POTA parks file. 

  All there for the viewing. All here too...

The benefit of this project being open source is you get to not only see how the program works, but you can use it for your own projects. You are welcome to take pieces of our code for your own projects. Follow the terms of the GPLv3 (e.g., *put your changes back to the TR4W code in a pull request*) and it is customary to attribute the source material. We want to share what we have done here. Unlike too many open source projects, we do not feel like we can get the benefit of open source but still get to dictate the terms of how you use the software (beyond the GPLv3 license). We relied upon the community to help us develop this project. We're darn well going to let the community use it on their own terms. Isn't that what open source should be?  

And there will never be a priced component/subscription service/extra "pro tier" or myriad of other ways out there people try to make money on ham radio software. No one is using TR4W as a source of income--we're all set, thanks. 

We do this because we love programming, contesting and giving back to the ham community. That's it.

## Building on Linux

Verified on **Ubuntu 24.04** (Debian-derived) with FPC 3.2.2 and Lazarus 3.0.
Debian works the same way -- check which Lazarus your release ships, since only
3.0 has been tested.

### Dependencies

```sh
sudo apt install build-essential git fpc lazarus
```

That is enough to **build**. Two more are needed for the full check, and
neither announces itself, which is why they are listed rather than left to be
discovered:

```sh
sudo apt install libsqlite3-dev   # the contest log
sudo apt install xvfb             # only to RUN the tests on a headless box
```

| package | why, and what its absence looks like |
| --- | --- |
| `fpc` | the compiler. TR4W needs 3.2.2 |
| `lazarus` | the **LCL** -- the units, not the IDE. Without it: `Can't find unit Interfaces` |
| `libsqlite3-dev` | the log is SQLite. The runtime `libsqlite3.so.0` is usually already installed; FPC looks for the unversioned `libsqlite3.so` **symlink**, which only `-dev` provides. You get `Can not load SQLite client library "libsqlite3.so"` -- which names the library, not the package |
| `xvfb` | the test binary links GTK2, so on a headless machine it dies with `Gtk-WARNING: cannot open display:` before running a single test. Run it as `xvfb-run -a ./tr4w_unit_tests_linux`. Not needed on a desktop |

### Build

```sh
git clone git@github.com:TR4W/TR4W-D12.git
cd TR4W-D12
./tr4w/build/build-linux.sh
```

It discovers the toolchain, sets every unit search path, reads the version from
`src/Version.pas`, and runs four stages -- **app**, **unit tests**,
**tr4wserver**, **package** -- reporting each and, for any that fails, its first
error. When all four pass it writes
`build-out/dist/tr4w-<version>-<arch>.tar.gz`.

Individual stages: `--app`, `--tests`, `--server`, `--package`, `--list`.

**It also prints the gates that CANNOT run on Linux** -- ten lints needing
PowerShell, the UI field check that drives the Windows binary, and the PE
version and manifest checks that have no ELF equivalent. A build that skips a
gate is not a build that passed it, so the script says which.

### Checking one unit, or the whole tree

```sh
./tools/compile-native.sh MainUnit.pas    # one unit
./tools/compile-native.sh --tree          # MainUnit and everything it needs
./tools/compile-native.sh --all           # the pinned list
./tools/compile-native.sh --every         # a census of every unit; SLOW
```

`--tree` is the one to reach for: FPC resolves the graph itself, so it walks the
tree once -- seconds. `--every` compiles each unit independently with the cache
cleared between them, which is minutes. What it buys for that price is finding
units nothing reaches any more.

### Raspberry Pi and other ARM boards

The scripts read the CPU from `uname -m`, so aarch64 (64-bit Pi OS) and arm
(32-bit) need no flag. **This is untested.** What can be said is that nothing
obvious blocks it: no live inline assembly anywhere in the tree, no live x86
port I/O, ARM is little-endian like x86 so the binary logs and the network
protocol are unaffected, and parallel-port keying is already Windows-only. The
first command worth running there is `./tools/compile-native.sh --tree`.

## Building on macOS

Verified on **macOS 26 / Apple Silicon (aarch64)** with FPC 3.2.2 and Lazarus
installed through [fpcupdeluxe](https://github.com/LongDirtyAnimAlf/fpcupdeluxe),
which is the practical way to get both on a Mac.

```sh
./tools/compile-native.sh --tree
```

**This compiles the whole unit graph. It does not yet LINK an application** --
there is no `build-mac.sh` counterpart to `build-linux.sh`. What the compile
proves is that every unit TR4W consists of is free of Windows dependencies on a
third platform, which is a real result and not the same as a program.

`compile-native.sh` finds fpcupdeluxe at `~/fpcupdeluxe` by default; override
with `FPCROOT` and `LAZROOT`. The widget set defaults to **cocoa** here and
gtk2 on Linux; override with `LCL_WIDGETSET`.

### What the Mac found that two other platforms could not

Worth reading before dismissing a third target as redundant. **Every one of
these was invisible to both Windows and Linux**, and none of them is a macOS
problem -- they are TR4W bugs that only a third type system could expose:

- **`TThreadID` is a POINTER on the BSD RTL** and an integer on Windows and
  Linux. TR4W stored thread ids in `DWORD`, `Cardinal`, `LongWord` and
  `THandle` -- all of which are correct on Windows by coincidence. 21
  declarations and 25 comparisons now use the RTL's own type.
- **A thread was being tested against a FILE-handle sentinel.** The
  paddle/footswitch thread was initialised to `INVALID_HANDLE_VALUE` (-1),
  but `BeginThread` returns **zero** on failure -- so
  `if tPaddleFootSwitchThread <> INVALID_HANDLE_VALUE` was **true before any
  thread had ever been started**. A live bug, found because macOS refuses to
  put -1 in a pointer.
- **`univint` ships its own `Menus` unit**, which shadowed the LCL's and made
  `Forms` fail its checksum -- a search-path ORDER bug that reads as a broken
  Lazarus install. The same trap, with Free Vision's `menus`, was already
  documented in the Windows probe and had never been carried across.
- **A registry read that would have compiled and done nothing.** FPC's
  `fcl-registry` provides a `Registry` unit off Windows backed by an XML file,
  so adding the package would have made `GetWindowsNTPServer` build -- and then
  read a W32Time service key that does not exist, forever, in silence.


### Where this actually stands

Honest status, measured rather than hoped:

- the **application**, **tr4wserver** and a **tarball** all build natively on
  x86_64 Linux
- **19,883 of 19,884 unit tests pass** there; the one failure is a timing
  assumption in a test fixture, not a defect in the program
- the **whole unit graph compiles on macOS/aarch64** -- see
  [Building on macOS](#building-on-macos). No application is linked there yet
- **ARM is untested.** Nothing obvious blocks it; nothing has tried it
- **nobody has run the GUI on any of them.** Building is not running, and a
  contest logger is not proven by a compiler

## Frequently Asked Questions

- Does TR4W still mean “TRLOG for Windows”?
  Historically, yes. Today TR4W is the product name for the cross-platform logger. It retains its TRLOG heritage while supporting Windows, macOS, and Linux.

- Is this TRLinux?
  No. TRLinux is a separate project with its own lineage as a Linux port of N6TR’s DOS TRlog. TR4W is its own cross-platform application and development line.

- Are the Mac and Linux versions native?
  Yes, and Linux now builds. The FreePascal/Lazarus migration is done -- that hurdle is behind us -- and as of 2026-09-08 the application, the server and a distributable tarball all build natively on x86_64 Linux, with 19,883 of 19,884 unit tests passing there. **Nobody has run the GUI on Linux yet**, which is the next thing; building is not running. The Mac is further back: there is a build script for it but no machine with FreePascal on it. Running this on Mac and Linux is why this port even exists. See [Building on Linux](#building-on-linux) if you want to try it now.

  TR4W was originally a native Win32 API [Petzold](https://en.wikipedia.org/wiki/Charles_Petzold) app. Even running in Delphi, it did not use the VCL at all. It used far too mush assembler code in the program. There may have been a time and place for that but it is long gone. Every single day we take steps to remove native Win32, hwnd references and other non-FreePascal/Lazarus tools as that is how we get true cross-platform. Not a WINE compatibility layer for Linux and not running on Parallels for the Mac. NY4I uses a Mac as his daily driver and Howie N4AF uses Linux. We will call it done when we can run this on a pi400 Raspberry Pi and a simple MacBook Air. 

  Stay tuned!
