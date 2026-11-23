"""The copy of the row codec inside netprobe.py against the golden vectors.

netprobe.py carries its own copy of TR4WServerPy's wire.py so that it stays one
standalone file. This test proves the copy reproduces tr4w/test/wire/
golden_vectors.json (made by the independent oracle make_vectors.py) byte for
byte, in both directions, and refuses what the contract says to refuse. The same
check runs as `netprobe.py --case selftest`.

Run it from the repository root:

   python -I -m unittest discover -s tools/netprobe -v
"""

import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import netprobe  # noqa: E402


class TestCodecCopy(unittest.TestCase):
   def setUp(self):
      self.codec = netprobe.load_codec()

   def test_the_copy_reproduces_every_golden_vector(self):
      results = netprobe.selftest(self.codec)
      self.assertEqual(len(results), 14)
      for label, ok, detail in results:
         with self.subTest(label):
            self.assertTrue(ok, detail)

   def test_there_are_89_columns(self):
      self.assertEqual(len(self.codec.names), 89)

   def test_a_bad_checksum_is_refused(self):
      values = self.codec.default_values()
      text = self.codec.encode(values)
      altered = text.replace(text[-10:-2], '00000000')
      if altered == text:
         altered = text.replace('"k":"', '"k":"F')
      with self.assertRaises(netprobe.WireError):
         self.codec.decode_verified(altered)

   def test_a_non_canonical_number_is_refused(self):
      values = self.codec.default_values()
      values[self.codec.index('freq_tx_hz')] = '0x1F'
      with self.assertRaises(netprobe.WireError):
         self.codec.encode(values)

   def test_the_wire_message_header(self):
      frame = netprobe.build_wire(netprobe.NET_WIRE_QSO_ID, 3, '{}')
      self.assertEqual(frame[:6], bytes([0x11, 0x04, 3, 0, 0, 0]))
      self.assertEqual(netprobe.parse_wire(frame), (3, '{}'))


if __name__ == '__main__':
   unittest.main()
