# TR4W on Linux — installing, and what it needs

**Read the two lines under "Will it run here" before anything else.** They rule
out more machines than everything below put together.

TR4W 5.x on Linux is **pre-release and under active test.** It builds, it runs,
it logs QSOs and it drives a radio. It has not been through a contest. You are
being asked to break it.

---

## Will it run here

| requirement | why | how to check |
|---|---|---|
| **glibc 2.34 or newer** | the binary references `GLIBC_2.34` symbols | `ldd --version` |
| **GTK 2** | the widget set the LCL was built against | see below |

**glibc 2.34 is the hard floor.** It is not a preference and there is no
workaround short of rebuilding on an older machine. In practice:

| distribution | glibc | runs? |
|---|---|---|
| Ubuntu 22.04 / Mint 21 | 2.35 | yes |
| Ubuntu 24.04 / Mint 22 | 2.39 | yes |
| Debian 12 | 2.36 | yes |
| Fedora 35 and newer | 2.34+ | yes |
| Ubuntu 20.04 / Mint 20 | 2.31 | **no** |
| Debian 11 | 2.31 | **no** |

A too-old glibc fails at start with `version 'GLIBC_2.34' not found`, which at
least says so plainly.

---

## The AppImage, and why its floor is HIGHER

The release also offers `TR4W-<version>-x86_64.AppImage`: one file, nothing
installed, **GTK 2 included**. If the package list below is the thing standing
between you and a test, take the AppImage instead.

```sh
chmod +x TR4W-5.0.11-x86_64.AppImage
./TR4W-5.0.11-x86_64.AppImage
```

**It needs glibc 2.38, not 2.34.** That is not a typo and it is the one thing
people get wrong about AppImages: an AppImage carries everything *except* the C
library, so its floor is set by the newest bundled library rather than by TR4W
itself. Measured with `objdump -T` over the 38 libraries inside it: thirteen of
them — glib, gio, pango, cairo, harfbuzz, fontconfig, expat, sqlite3, OpenSSL
and friends — reference `GLIBC_2.38`, because it is built on Ubuntu 24.04.

| distribution | glibc | tarball | AppImage |
|---|---|---|---|
| Ubuntu 24.04 / Mint 22 | 2.39 | yes | yes |
| Debian 13 | 2.41 | yes | yes |
| Fedora 39+ | 2.38+ | yes | yes |
| Ubuntu 22.04 / Mint 21 | 2.35 | yes | **no** |
| Debian 12 | 2.36 | yes | **no** |
| Ubuntu 20.04, Debian 11 | 2.31 | **no** | **no** |

**So on Ubuntu 22.04 and Debian 12 the tarball is the answer**, with GTK 2
installed from the package list below.

**It may also want FUSE.** An AppImage normally mounts itself, which needs
libfuse2, and several current distributions no longer ship it. If it refuses to
start with a message about FUSE or about mounting, run it this way instead — it
unpacks into a temporary directory and needs nothing installed:

```sh
./TR4W-5.0.11-x86_64.AppImage --appimage-extract-and-run
```

**Two things are knowingly missing from it:**

- **HamLib is not bundled.** A radio driven through HamLib needs
  `libhamlib.so.4` installed on the machine (`sudo apt install libhamlib4`),
  and that combination has not been tested from inside an AppImage. Radios TR4W
  drives directly — Elecraft, Icom, Kenwood, Yaesu, Flex, TCI — are unaffected.
- **The icon is a placeholder**, a plain blue square. The only artwork in the
  tree is a 32×32 Windows titlebar icon, which is too small to use. Real
  artwork is pending.

Your settings, log and contest files live in the same places either way —
see *Where it puts things* below. Nothing is written inside the AppImage.

---

## Packages to install

**GTK 2 is the one most machines are missing.** It is years past its
retirement and modern desktops do not install it by default, even though they
still package it.

```sh
# Debian, Ubuntu, Mint
sudo apt install libgtk2.0-0t64 libsqlite3-0 libssl3

# Fedora
sudo dnf install gtk2 sqlite-libs openssl-libs

# Arch
sudo pacman -S gtk2 sqlite openssl
```

Older Debian-family releases call the GTK package `libgtk2.0-0` and the
OpenSSL one `libssl1.1`; install whichever your release has.

### What each one is for

**GTK 2** — every window. Missing it means TR4W will not start at all.

**SQLite** — `libsqlite3.so.0`, and **the contest log is a SQLite database**,
so this is not optional. Two traps here, both real:

- The `sqlite3` **package is the command-line tool** and contains no shared
  library. Installing it does nothing for TR4W. You want `libsqlite3-0`.
- FPC's default name for the library is the unversioned `libsqlite3.so`, which
  only the `-dev` package ships. TR4W asks for `libsqlite3.so.0` instead, so a
  normal machine works. You do **not** need a `-dev` package.

**OpenSSL** — the DX cluster over TLS, the CTY.DAT update check and score
posting. Without it those fail and the rest of the program is fine.

**HamLib — optional, and only if you use a HamLib-backed radio.**
`libhamlib.so.4`, from `libhamlib4` (Debian family) or `hamlib` (Fedora,
Arch). Every other radio family talks to the rig directly and needs nothing.
TR4W says so at start-up:

```
HamLib DLL = libhamlib.so.4 not found (no HamLib radio can be used)
```

That line is harmless unless you configured a HamLib radio.

**A graphical text editor**, for *Tools → Open in text editor*. TR4W looks for
`xed`, `gnome-text-editor`, `gedit`, `kate`, `kwrite`, `mousepad`, `pluma`,
`geany` and `leafpad`, in that order. Nearly every desktop ships one.

---

## Running it

```sh
tar xzf tr4w-5.0.2-x86_64-linux.tar.gz
cd tr4w-5.0.2-x86_64-linux
./tr4w
```

There is no installer and nothing is copied into system directories. The
folder is self-contained; move it wherever you like.

### Where it puts things

| what | where |
|---|---|
| settings | `~/.config/tr4w/tr4w.json` |
| the log file | `~/.local/state/tr4w/tr4w.log` |
| contests and their logs | beside the binary, unless you browse elsewhere |

**`tr4w.log` is the first thing to send with a bug report.** It records the
configuration, every window it laid out, which fonts and libraries it
resolved, and any fault with a stack trace.

---

## Known gaps on Linux — please do not report these

These are missing rather than broken, and they are already written down.

**CW keying will not key a contest.** Element timing off Windows falls back to
a plain `Sleep`, which is not accurate enough. TR4W warns at start:

```
[Timing] CW element, paddle and DVP events are Windows-only in this build.
```

**LPT keying does not exist here.** It is on the list; serial and network CAT
control both work.

**Plug-ins are Windows DLLs** and none load.

**The GUI has had days of testing, not months.** Anything that looks wrong
probably is. Layout, fonts, colours and keyboard handling are exactly where
the interesting bugs have been so far.

---

## Reporting something

Include:

1. Your distribution and version, and `ldd --version`.
2. `~/.local/state/tr4w/tr4w.log` — the whole file, not an excerpt.
3. What you did, and what you expected instead.
4. A screenshot if it is visual. Several of the defects found so far were
   invisible in words and obvious in a picture.
