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
