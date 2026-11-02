#!/usr/bin/env python3
"""Cut tr4w/test/unit/fixtures/k4pan-tiers-sample.bin out of a K4 span sweep.

The input is a raw K4 panadapter capture (concatenated 4,162-byte packets, as
tools/k4panwatch.py records them) taken while #SPN was stepped through
5000, 10000, 20000, 40000, 80000, 150000, 190000, 250000 and 368000 Hz --
the 2026-11-02 sweep, which made the K4 serve every frame width it has
(24, 48, 96, 192 and 384 kHz).

For each width it keeps up to three pan-A frames: the one with the widest
LEFT edge pad, the one with the widest RIGHT edge pad, and the middle frame of
that width.  "Pad" is the run of bins at least 8 dB below the frame's median,
counted in from each end -- the same measure uTestK4SpectrumCrop uses.  The
widest pads are the cases the crop has to clear, which is why they are the
ones kept.

REGENERATING THE FIXTURE MEANS UPDATING uTestK4SpectrumCrop (its per-width
frame counts), exactly as for k4pan-sample.bin.

Usage:  python tools/k4pan_tier_fixture.py <sweep.bin> <out.bin>
"""

import statistics
import struct
import sys

PACKET = 4162
PER_WIDTH = 3
WIDTHS = (24000, 48000, 96000, 192000, 384000)
PAD_BELOW_MEDIAN_DB = 8.0


def pad_runs(bins):
   threshold = statistics.median(bins) - PAD_BELOW_MEDIAN_DB
   left = 0
   while left < len(bins) and bins[left] <= threshold:
      left += 1
   right = 0
   while right < len(bins) and bins[len(bins) - 1 - right] <= threshold:
      right += 1
   return left, right


def main(source, target):
   data = open(source, 'rb').read()
   by_width = {width: [] for width in WIDTHS}

   for index in range(len(data) // PACKET):
      packet = data[index * PACKET:(index + 1) * PACKET]
      if chr(packet[6]) != 'A':
         continue
      span = int(packet[7:13])
      if span not in by_width:
         continue
      bins = [raw / 10.0 for raw in struct.unpack('>2048h', packet[64:64 + 4096])]
      left, right = pad_runs(bins)
      by_width[span].append((left, right, index))

   out = bytearray()

   for width in WIDTHS:
      rows = by_width[width]
      if not rows:
         print(width, 'no frames')
         continue
      chosen = []
      for candidate in (max(rows, key=lambda row: row[0]),
                        max(rows, key=lambda row: row[1]),
                        rows[len(rows) // 2]):
         if candidate not in chosen:
            chosen.append(candidate)
      for left, right, index in chosen[:PER_WIDTH]:
         out += data[index * PACKET:(index + 1) * PACKET]
         print(width, 'frame', index, 'pad run L/R', left, right)

   open(target, 'wb').write(out)
   print('wrote', len(out), 'bytes,', len(out) // PACKET, 'frames')


if __name__ == '__main__':
   if len(sys.argv) != 3:
      print(__doc__)
      sys.exit(2)
   main(sys.argv[1], sys.argv[2])
