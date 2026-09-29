# Install TR4W

Choose a package for your operating system and CPU, and read the release notes supplied with that package. This guide describes the 5.x source snapshot; it does not establish which preview artifacts are currently published.

TR4W runs natively on Windows, macOS, and Linux. Start at the [TR4W website](https://tr4w.net/) or the project's release channel and select the intended version; these pages document 5.x.

=== "Windows"

    1. Obtain the intended Windows installer or complete preview package from the project's release channel.
    2. Close TR4W before replacing an existing installation. Preserve your contest files and settings.
    3. Run the installer, or extract the complete preview package into a writable location according to its supplied instructions. Keep required libraries and data with the application.
    4. When moving from 4.x, run the [INI-to-JSON converter](ini-to-json.md) before the first normal launch.
    5. Launch using the installed shortcut. Windows data and contest defaults are based on the working directory, so a custom shortcut's **Start in** folder matters.

=== "Linux"

    Native preview packages include a tarball and an AppImage. Choose the package compatible with your system using the requirements below.

    ## Linux requirements and troubleshooting

    These requirements describe the preview packages reviewed for this guide. Check the requirements supplied with a newer package rather than assuming its build dependencies are identical.

    | Component | Tarball | Reviewed AppImage |
    | --- | --- | --- |
    | glibc | 2.34 or newer | 2.38 or newer, because bundled libraries require newer symbols |
    | GTK2 | Install the distribution's GTK2 runtime | Bundled |
    | SQLite | Requires `libsqlite3.so.0` | Bundled |
    | OpenSSL | Needed for TLS connections, online updates, and score posting | Bundled |
    | Hamlib | Install `libhamlib.so.4` if using a Hamlib-backed radio | Not bundled; host-library use needs testing with the package |

    Run `ldd --version` in a terminal to check glibc. An error such as `GLIBC_2.34 not found` means the tarball needs a newer runtime than the system provides. An AppImage does not eliminate the glibc requirement. Do not replace the operating system's C library manually to launch TR4W; use a compatible package or OS.

    For the tarball, install runtime libraries through your distribution's package manager. Debian-family package names include `libgtk2.0-0` or `libgtk2.0-0t64`, `libsqlite3-0`, and the OpenSSL runtime matching the release. Fedora uses `gtk2`, `sqlite-libs`, and `openssl-libs`; Arch uses `gtk2`, `sqlite`, and `openssl`. Package availability and exact names depend on the distribution release. The `sqlite3` command-line tool alone is not a substitute for the SQLite shared library, and TR4W does not require the SQLite development package.

    For an AppImage, make the actual downloaded file executable with `chmod +x` and launch it. If FUSE mounting fails, add `--appimage-extract-and-run` to that launch command. Keep the full tarball contents together when using the tarball, then run `./tr4w` from the extracted directory.

    A missing-Hamlib message matters only if you selected a Hamlib-backed radio; native TR4W radio drivers do not require it. Check the [radio support table](../reference/radios.md) before installing an optional backend. Windows DLL plug-ins cannot be assumed to work on Linux, and [CPU-generated CW has platform limitations](../station/cw.md).

    Both package formats use the same [operator file locations](files.md): contest databases default to `~/tr4w`, with settings and diagnostic logs in their separate user directories. Nothing should be stored inside an AppImage. For startup problems, record the distribution/version, package filename, exact error, glibc version, and the [diagnostic log](../log/diagnostics.md) if one was created.

=== "macOS"

    TR4W runs natively on macOS as a `TR4W.app` bundle. The packaging code supports signed/notarized releases. Use a package built for your Mac and supplied through the project's release channel.

    If supplied as a disk image, open the image and copy the application bundle to Applications before launching. If supplied as an archive, extract and retain the complete bundle. Follow the package's own installation instructions if they differ.

    Keep contest files and downloaded updates outside the bundle. The application writes operator files under your home directory. If macOS rejects a package, retain the exact message and request a correctly packaged build; this guide does not require disabling system protections.

## First-launch checks

Confirm the version, [language](../station/language.md), callsign, and writable [file locations](files.md). Enter your station's **Maidenhead grid locator** when prompted during initial setup; see [initial station setup](first-contest.md#complete-the-initial-station-setup). Create a practice contest, save and reopen a contact, and test [backups](../log/backup.md). Then check the radio, keying method, and integrations individually.

Keep the previous working installation and its files until the new setup has passed your station's checks. Platform support remains a release-specific statement, especially for CW timing and external hardware.

## Build-source references

Windows/build documentation (`tr4w/docs/BUILD.md`) · macOS build wrapper and caveats (`tr4w/build/build-mac.sh`) · Unix packaging implementation (`tr4w/build/build-unix.sh`)

These installation paths have not been exercised on all three platforms for this documentation update.
