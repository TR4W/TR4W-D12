"""Read and write TR4W source files without destroying their line endings.

WHY THIS EXISTS. The obvious Python idiom is wrong for this tree, and wrong
silently:

    s = io.open(p, encoding='utf-8-sig').read()      # universal newlines: \\r\\n -> \\n
    io.open(p, 'w', encoding='utf-8', newline='').write(s)   # writes \\n

That round trip turns a CRLF file into an LF file. Nothing complains at the
time. It cost three separate incidents in one session on 2026-08-29, the worst
of which LF-ified 97 files in one command.

It matters here more than in most trees: CLAUDE.md's "CRLF is load-bearing"
note records that the RAD Studio form designer inserts code BY BYTE OFFSET, so
against an LF file a new event handler is spliced into the middle of an
identifier. It reads like file corruption and is not.

So use these. read() hands back text with newlines intact; write() puts back
exactly the BOM and newline convention the file had, and refuses to invent one.

    from srcfile import read, write
    text = read(path)
    write(path, text.replace('foo', 'bar'))

NEW files: pass newline='\\r\\n' explicitly to write(); there is no file to
inherit from and guessing is how this went wrong in the first place.
"""

import io
import os

BOM = '﻿'
_BOM_BYTES = b'\xef\xbb\xbf'


def read(path):
   """File text with its line endings AS THEY ARE on disk, BOM stripped."""
   raw = io.open(path, 'rb').read()
   return raw.decode('utf-8-sig')


def had_bom(path):
   return io.open(path, 'rb').read(3) == _BOM_BYTES


def newline_of(path):
   """The file's dominant newline: '\\r\\n' or '\\n'."""
   raw = io.open(path, 'rb').read()
   crlf = raw.count(b'\r\n')
   lf = raw.count(b'\n') - crlf
   if crlf == 0 and lf == 0:
      return '\r\n'          # empty or single line: this tree's convention
   return '\r\n' if crlf >= lf else '\n'


def write(path, text, newline=None, bom=None):
   """Write text back, preserving the file's BOM and newline convention.

   `newline` and `bom` override what the existing file had -- required when the
   file does not exist yet, because there is nothing to inherit."""
   exists = os.path.exists(path)
   if newline is None:
      if not exists:
         raise ValueError(
            'new file %r: pass newline explicitly (this tree is CRLF)' % path)
      newline = newline_of(path)
   if bom is None:
      bom = had_bom(path) if exists else False

   # Normalise to \n first so a mixed input cannot produce \r\r\n.
   body = text.replace('\r\n', '\n').replace('\r', '\n')
   if newline != '\n':
      body = body.replace('\n', newline)
   if body.startswith(BOM):
      body = body[1:]
   data = (_BOM_BYTES if bom else b'') + body.encode('utf-8')
   io.open(path, 'wb').write(data)


def lines(path):
   """The file's lines, split on its own newline, without the terminators."""
   return read(path).replace('\r\n', '\n').split('\n')


def write_lines(path, seq, newline=None, bom=None):
   write(path, '\n'.join(seq), newline=newline, bom=bom)
