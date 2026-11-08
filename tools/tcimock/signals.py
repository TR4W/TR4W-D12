"""Synthetic scene and TCI binary framing, independent of the network."""
from array import array
import math
import random
import struct
import sys

from .radio import RATE

HEADER = struct.Struct('<16I')
IQ = 0
AUDIO = 1
CHRONO = 3
SPECTRUM = 4  # AetherSDR extension, not standard TCI.
PAIRS = 1024


def frame(receiver, kind, samples, rate=RATE, channels=2, low=0, high=0):
   payload = array('f', samples)
   if sys.byteorder != 'little':
      payload.byteswap()
   header = HEADER.pack(receiver, rate, 3, 0, 0, len(payload), kind, channels,
                        low, high, 0, 0, 0, 0, 0, 0)
   return header + payload.tobytes()


class Scene:
   def __init__(self, center, seed=1):
      self.carriers = [(center - 9000, 0.16), (center - 2500, 0.10),
                       (center + 4000, 0.22), (center + 11500, 0.08)]
      self.phases = [0.0] * len(self.carriers)
      self.noise = random.Random(seed)

   def iq(self, center):
      samples = []
      steps = [2 * math.pi * (frequency - center) / RATE for frequency, _ in self.carriers]
      waves = [complex(math.cos(phase), math.sin(phase)) * amplitude
               if abs(frequency - center) < RATE / 2 else 0j
               for phase, (frequency, amplitude) in zip(self.phases, self.carriers)]
      rotations = [complex(math.cos(step), math.sin(step)) for step in steps]
      # Rotate oscillators rather than recomputing sine/cosine for every sample.
      for _ in range(PAIRS):
         value = sum(waves) + complex(self.noise.uniform(-0.008, 0.008),
                                      self.noise.uniform(-0.008, 0.008))
         samples.extend((value.real, value.imag))
         waves = [wave * rotation for wave, rotation in zip(waves, rotations)]
      self.phases = [(phase + step * PAIRS) % (2 * math.pi)
                     for phase, step in zip(self.phases, steps)]
      return samples

   def spectrum(self, center, bins=512):
      result = []
      for i in range(bins):
         hz = center - RATE / 2 + i * RATE / bins
         peak = max(-115 + 65 * math.exp(-((hz - freq) / 160) ** 2)
                    for freq, _ in self.carriers)
         result.append(peak + self.noise.uniform(-2, 2))
      return result

   def ascii(self, center):
      chars = ' .:-=+*#%@'
      return ''.join(chars[max(0, min(9, int((v + 120) / 8)))]
                     for v in self.spectrum(center, 96))
