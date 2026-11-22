"""Golden vectors for the multi-op wire's canonical QSO row (stage W1).

docs/TR4WSERVER_SQLITE_DESIGN.md section 13; the rulings and measurements are
docs/WIRE_FORMAT_METRICS.md.

THE INDEPENDENT ORACLE. This script knows the format from the design note and
nothing else: it imports no Pascal output and nothing from the bench. It reads
columns.json (the wire's columns in tag order: name, num, def -- written from
uLogRepository's table by the unit test uTestWireColumns, which also pins it)
and writes golden_vectors.json. The Pascal unit test uTestWireQso then asserts
that uWireQso produces the SAME canonical bytes and CRC-32 for every row, and
decodes this script's JSON to the same values.

THE FORMAT, as this script computes it:
   canonical stream: for every column in tag order (tag = 1-based position),
      defaults included: one byte tag, two bytes little-endian UTF-8 byte
      length, the UTF-8 bytes.  NULL is the empty value.
   checksum: CRC-32 (zlib) of the canonical stream.
   JSON (omit): a field EQUAL TO ITS DEFAULT is left out; a numeric field is a
      JSON number, or null when NULL; a text field is a string; member "k" is
      the checksum as 8 upper-case hex digits.
   A NUL character never goes on the wire: an "input" value with one is
      stripped to give "values".

Usage:  python -I tr4w/test/wire/make_vectors.py
"""

import json
import os
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
COLUMNS_PATH = os.path.join(HERE, 'columns.json')
VECTORS_PATH = os.path.join(HERE, 'golden_vectors.json')


def load_columns():
   with open(COLUMNS_PATH, 'r', encoding='utf-8') as f:
      columns = json.load(f)
   for c in columns:
      if set(c.keys()) != {'name', 'num', 'def'}:
         sys.exit('columns.json: unexpected entry %r' % (c,))
   return columns


def canonical(columns, values):
   out = bytearray()
   for i, (col, value) in enumerate(zip(columns, values)):
      b = value.encode('utf-8')
      if len(b) > 0xFFFF:
         sys.exit('%s: value too long for the wire' % col['name'])
      out += bytes([i + 1, len(b) & 0xFF, (len(b) >> 8) & 0xFF])
      out += b
   return bytes(out)


def json_omit(columns, values, crc):
   obj = {}
   for col, value in zip(columns, values):
      if value == col['def']:
         continue
      if col['num']:
         obj[col['name']] = None if value == '' else int(value)
      else:
         obj[col['name']] = value
   obj['k'] = '%08X' % crc
   return json.dumps(obj, ensure_ascii=False, separators=(',', ':'))


def make_row(columns, label, overrides):
   index = {c['name']: i for i, c in enumerate(columns)}
   raw = [c['def'] for c in columns]
   for name, value in overrides.items():
      if name not in index:
         sys.exit('%s: no wire column named %s' % (label, name))
      raw[index[name]] = value
   values = [v.replace('\0', '') for v in raw]
   for col, value in zip(columns, values):
      if col['num'] and value != '':
         int(value)   # a numeric column holds digits or nothing
   stream = canonical(columns, values)
   crc = zlib.crc32(stream) & 0xFFFFFFFF
   row = {
      'label': label,
      'values': values,
      'canonical_hex': stream.hex(),
      'crc': '%08X' % crc,
      'json_omit': json_omit(columns, values, crc),
   }
   if raw != values:
      row['input'] = raw
   return row


def main():
   columns = load_columns()
   typical = {
      'guid': '0190a1b2c3d4e5f60718293a4b5c6d7e',
      'qso_set_id': '0190a1b2c3d4e5f60718293a4b5c6d7e',
      'computer_id': 'B',
      'qso_at': '1780000000',
      'callsign': 'K1ABC',
      'freq_tx_hz': '14025000',
      'freq_rx_hz': '14025000',
      'band': '20',
      'mode': 'CW',
      'rst_sent': '599',
      'rst_received': '579',
      'serial_sent': '12',
      'serial_received': '-1',
      'qso_points': '3',
      'my_call': 'NY4I',
      'my_source': 'logged',
   }
   rows = [
      make_row(columns, 'all defaults', {}),
      make_row(columns, 'typical', typical),
      # DEFAULT 0, nullable: NULL is SENT, as JSON null.
      make_row(columns, 'null where the default is 0', {'callsign': 'K1ABC', 'mult_domestic': ''}),
      # No default, nullable: a real 0 is SENT, never omitted.
      make_row(columns, 'zero in a nullable column', {'callsign': 'K1ABC', 'rst_sent': '0', 'rcvd_year': '0'}),
      # DEFAULT 1: 1 is omitted, 2 is sent.
      make_row(columns, 'radio 2', {'callsign': 'K1ABC', 'radio_nr': '2'}),
      make_row(columns, 'radio 1 is the default', {'callsign': 'K1ABC', 'radio_nr': '1'}),
      make_row(columns, 'the string 0', {'callsign': 'K1ABC', 'exchange_received': '0'}),
      make_row(columns, 'a NUL is stripped', {'callsign': 'K1ABC', 'rcvd_qth': 'A\0B', 'notes': '\0'}),
      make_row(columns, 'accented Latin', {'callsign': 'EA1ABC', 'rcvd_name': 'José'}),
      make_row(columns, 'Cyrillic', {'callsign': 'UA3ABC', 'rcvd_name': 'Иван'}),
      make_row(columns, 'Japanese', {'callsign': 'JA1ABC', 'rcvd_name': '山田太郎'}),
      make_row(columns, '255 two-byte characters', {'callsign': 'K1ABC', 'rcvd_kids': 'Ж' * 255}),
      make_row(columns, 'outside the BMP', {'callsign': 'K1ABC', 'exchange_received': '73 \U0001F600'}),
      make_row(columns, 'Latin-1 and the euro', {'callsign': 'DL1ABC', 'rcvd_qth': 'üßåø€'}),
   ]
   doc = {
      'about': 'Golden vectors for uWireQso; made by make_vectors.py from columns.json. '
               'Do not edit by hand.',
      'columns': len(columns),
      'rows': rows,
   }
   with open(VECTORS_PATH, 'w', encoding='utf-8', newline='\r\n') as f:
      json.dump(doc, f, ensure_ascii=False, indent=1)
      f.write('\n')
   print('%s: %d rows over %d columns' % (VECTORS_PATH, len(rows), len(columns)))


if __name__ == '__main__':
   main()
