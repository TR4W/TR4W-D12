# Third-party notices

What TR4W ships that other people wrote, and the notice each licence asks to
travel with it.

**THIS LIST IS NOT COMPLETE.** It was started on 2026-11-12 with the first
library whose licence text the build collects itself. The runtime libraries TR4W
has shipped for longer -- HamLib, SQLite, OpenSSL, the MinGW runtime, libusb --
are described in [`UPDATING_RUNTIME_DLLS.md`](UPDATING_RUNTIME_DLLS.md) and are
not listed here yet. Adding them is open work, not a statement that they need no
notice.

## libtailcat (the Tailcat tunnel, issue 293)

| | |
|---|---|
| What | `libtailcat.dll` / `libtailcat.so` / `libtailcat.dylib`: Tailscale's Tailcat, built as a C library |
| Source | https://github.com/tailscale/tailcat, at the commit in `tr4w/build/tailcat.pin` |
| Built by | `tr4w/build/Build-Tailcat.ps1`, `tr4w/build/build-tailcat.sh`. It is never committed |
| Licence | BSD-3-Clause (below), plus the licences of the Go runtime and of every Go module linked into it |
| Ships as | the library, and **`libtailcat-NOTICES.txt` beside it** |

`libtailcat-NOTICES.txt` is written by the build from the library itself: it
asks the binary which modules were linked (`go version -m`) and copies each
one's licence files from the module cache that build used. The build fails if
any module has none. That file -- not this page -- is the complete notice, and
**a package that carries the library must carry it too**: clause 2 below, and
its counterparts in the MIT and Apache-2.0 texts inside the file, are conditions
of redistributing the binary.

TR4W itself is GPL (see `LICENSE`). BSD-3-Clause, MIT and Apache-2.0 code may be
distributed alongside it; nothing here is linked into `tr4w.exe`, the library is
loaded at run time and only when *Use Tailcat* is ticked.

### Tailcat's own licence

```
BSD 3-Clause License

Copyright (c) 2020 Tailscale Inc & contributors.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its
   contributors may be used to endorse or promote products derived from
   this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
