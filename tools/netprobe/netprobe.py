"""netprobe -- speak the TR4W multi-op wire protocol 5 at a server.

Standard library only. Indentation is three spaces, as everywhere in this tree.

What it is for: the in-tree client and tr4wserver agree with each other because
both compile the same units, so a change there changes the wire for everyone
else and nothing in the build notices. This tool is an INDEPENDENT second
implementation of the client side: its own framing, its own copy of the row
codec, nothing shared with the Pascal. Point it at any server and it says which
behaviours that server actually has.

PROTOCOL 5 (docs/TR4WSERVER_SQLITE_DESIGN.md 13.6 and 13.7): a QSO is a
length-framed JSON row. The three QSO messages are
   id (2 bytes LE) + payload length (4 bytes LE) + payload
with the payload = one sender byte + the UTF-8 JSON row (defaults omitted, member
"k" the record checksum). Every other message is fixed size, as before.

THE ROW CODEC BELOW (WireCodec) IS A COPY of C:\\projects\\TR4WServerPy\\wire.py
(the Python server's own, itself checked against the Pascal uWireQso). It is
copied, not imported, so this tool stays one standalone file. `--case selftest`
(and test_codec.py beside this file) prove the copy reproduces
tr4w/test/wire/golden_vectors.json, the independent oracle's output, byte for
byte, in both directions. If wire.py changes, re-copy and re-run it.

It prints one line per check:

   RESULT <label> <case> <check>: PASS|FAIL|INFO|SKIP <detail>

and exits 0 when no check FAILed, 1 when one did, 2 when a case could not run
(connection refused, wrong password, timeout in the handshake).

Every wait has a deadline. Nothing here blocks for ever.

With --launch the tool starts the server ITSELF as a child process (fresh
directory per case), which is what lets the cases that need a restart or a kill
(catchup, offline-ack) run, and lets it read the server's .tr4wsrv database and
its backup files afterwards. Without --launch those checks are SKIPped. Whatever
it starts it stops again.

See README.md in this folder for the cases and for what each one proves.
"""

import argparse
import glob
import json
import os
import re
import select
import shutil
import socket
import sqlite3
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
WIRE_DIR = os.path.join(REPO, 'tr4w', 'test', 'wire')

# --- The wire, as this tool understands it ---------------------------------
# DELIBERATELY typed in again rather than imported from anywhere: a probe that
# shared the server's table could not find a wrong entry in it.

NET_MESSAGESTATE_ID = 1000
NET_LOGCOMPARE_ID = 1010
NET_INTERCOMMESSAGE_ID = 1020
NET_NETWORKDXSPOT_ID = 1030
NET_WIRE_QSO_ID = 1041
NET_WIRE_EDIT_ID = 1051
NET_WIRE_OFFLINE_ID = 1057
NET_TAKESERVERQSO_ID = 1060
NET_TIMESYN_ID = 1070
NET_PARAMETER_ID = 1080
NET_STATIONSTATUS_ID = 1090
NET_CLIENTSTATUS_ID = 1110
NET_SPOTVIANETWORK_ID = 1120
NET_COMPUTERID_ID = 1130
NET_SERVERMESSAGE_ID = 1140
NET_HELLO_ID = 1150

# The protocol 4 ids: deleted, unknown to a protocol 5 server.
RETIRED_IDS = {1040: 'QSOINFO', 1050: 'EDITEDQSO', 1055: 'OFFLINEQSO'}
RETIRED_QSO_SIZE = 2 + 376 + 4 + 1 + 1      # what protocol 4 framed them at

VARIABLE_IDS = (NET_WIRE_QSO_ID, NET_WIRE_EDIT_ID, NET_WIRE_OFFLINE_ID)
WIRE_HEADER = struct.Struct('<HI')
MAX_WIRE_PAYLOAD = 60000

NET_PROTOCOL_VERSION = 5
HELLO_VERSION_CHARS = 16
HELLO_CONTEST_CHARS = 48
HELLO_SIZE = 2 + 2 + 1 + 1 + HELLO_VERSION_CHARS + HELLO_CONTEST_CHARS     # 70

SM_CLEARALLLOGS = 8230
SM_SERVERLOG_CHANGED = 8250
SM_DISCONECT_CLIENT = 8260
SM_GETSTATUS = 8270
SM_CLEAR_DUPESHEET = 8280
SM_CLEAR_MULTSHEET = 8290
SM_RECEIVED_UPDATED_QSO = 8300
SM_SERIAL_NUMBER_CHANGED = 8310
SM_COMPUTERID_IN_USE = 8320
SM_PROTOCOL_MISMATCH = 8330

SNT_FREE = 0
SNT_RESERVED = 1

SPOT_RECORD_SIZE = 104          # SizeOf(TSpotRecord)

# Fixed-size messages only. The QSO messages are variable and handled apart.
MESSAGE_SIZE = {
   NET_MESSAGESTATE_ID: 64,
   NET_LOGCOMPARE_ID: 19,
   NET_INTERCOMMESSAGE_ID: 84,
   NET_NETWORKDXSPOT_ID: 2 + SPOT_RECORD_SIZE,
   NET_TAKESERVERQSO_ID: 382,
   NET_TIMESYN_ID: 20,
   NET_PARAMETER_ID: 514,
   NET_STATIONSTATUS_ID: 46,
   NET_CLIENTSTATUS_ID: 3,
   NET_SPOTVIANETWORK_ID: 48,
   NET_COMPUTERID_ID: 4,
   NET_SERVERMESSAGE_ID: 8,
   NET_HELLO_ID: HELLO_SIZE,
}

MESSAGE_NAME = {
   1000: 'MESSAGESTATE', 1010: 'LOGCOMPARE', 1020: 'INTERCOM',
   1030: 'DXSPOT', 1041: 'WIRE_QSO', 1051: 'WIRE_EDIT', 1057: 'WIRE_OFFLINE',
   1060: 'TAKESERVERQSO', 1070: 'TIMESYN', 1080: 'PARAMETER',
   1090: 'STATIONSTATUS', 1110: 'CLIENTSTATUS', 1120: 'SPOTVIANETWORK',
   1130: 'COMPUTERID', 1140: 'SERVERMESSAGE', 1150: 'HELLO',
}

PASSWORD_BYTES = 10
BANNER_OK = b'TR4W'
BANNER_REFUSED = b'PASS'


class ProbeError(Exception):
   """The case could not run at all (as opposed to a check that failed)."""


class WireError(Exception):
   """A row that cannot be encoded, or a wire record that cannot be accepted."""


def password_on_wire(text):
   """Ten bytes, NUL padded, which is what a TR4W client writes."""
   raw = text.encode('ascii', 'replace')[:PASSWORD_BYTES]
   return raw + b'\x00' * (PASSWORD_BYTES - len(raw))


# --- The row codec: a COPY of TR4WServerPy/wire.py (see the header) ---------

_INT64_MIN = -(1 << 63)
_INT64_MAX = (1 << 63) - 1
_CANONICAL_INT = re.compile(r'-?[0-9]+', re.ASCII)
_CRC_TEXT = re.compile(r'[0-9A-Fa-f]{8}', re.ASCII)
CRC_MEMBER = 'k'


def try_canonical_int64(text):
   """The integer for canonical digits, or None."""
   if not _CANONICAL_INT.fullmatch(text):
      return None
   n = int(text)
   if n < _INT64_MIN or n > _INT64_MAX:
      return None
   return n


def wire_text(value):
   """A value as the wire carries it: None is '', and every NUL is removed."""
   if value is None:
      return ''
   return value.replace('\0', '')


def crc_text(crc):
   return '%08X' % crc


class WireCodec:
   """Encode and decode rows over one column list (columns.json's entries). A
   row is a list of strings, one per column, in column order; NULL is ''."""

   def __init__(self, columns):
      self.names = [c['name'] for c in columns]
      self.is_num = [bool(c['num']) for c in columns]
      self.defaults = [c['def'] for c in columns]
      self._index = {n: i for i, n in enumerate(self.names)}

   def default_values(self):
      return list(self.defaults)

   def index(self, name):
      return self._index[name]

   def canonical(self, values):
      """The canonical stream: for EVERY column in order, defaults included,
      the tag (1-based column number), the UTF-8 length (2 bytes LE), the bytes."""
      if len(values) != len(self.names):
         raise WireError('a wire row holds %d values for %d columns'
                         % (len(values), len(self.names)))
      out = bytearray()
      for i, value in enumerate(values):
         b = value.encode('utf-8')
         if len(b) > 0xFFFF:
            raise WireError('column %s is %d bytes' % (self.names[i], len(b)))
         out += bytes([i + 1, len(b) & 0xFF, (len(b) >> 8) & 0xFF])
         out += b
      return bytes(out)

   def crc(self, values):
      return zlib.crc32(self.canonical(values)) & 0xFFFFFFFF

   def encode(self, values, omit=True):
      """The JSON text of a row with its checksum; a field equal to its
      default is left out when omit is True."""
      values = [wire_text(v) for v in values]
      obj = {}
      for i, value in enumerate(values):
         if omit and value == self.defaults[i]:
            continue
         if self.is_num[i]:
            if value == '':
               obj[self.names[i]] = None
            else:
               number = try_canonical_int64(value)
               if number is None:
                  raise WireError('column %s is numeric and holds %r'
                                  % (self.names[i], value))
               obj[self.names[i]] = number
         else:
            obj[self.names[i]] = value
      obj[CRC_MEMBER] = crc_text(self.crc(values))
      return json.dumps(obj, ensure_ascii=False, separators=(',', ':'))

   def decode(self, text):
      """(values, stated checksum or None)."""
      try:
         obj = json.loads(text)
      except (ValueError, RecursionError) as e:
         raise WireError('a wire record is not JSON: %s' % e)
      if not isinstance(obj, dict):
         raise WireError('a wire record is not one JSON object')
      values = self.default_values()
      stated = None
      for name, member in obj.items():
         if name == CRC_MEMBER:
            if isinstance(member, str) and _CRC_TEXT.fullmatch(member):
               stated = int(member, 16)
            continue
         at = self._index.get(name)
         if at is None:
            continue
         if member is None:
            values[at] = ''
         elif isinstance(member, bool):
            raise WireError('column %s holds a JSON boolean' % name)
         elif isinstance(member, str):
            values[at] = wire_text(member)
         elif isinstance(member, int):
            values[at] = str(member)
         else:
            raise WireError('column %s holds a %s' % (name, type(member).__name__))
      for i, value in enumerate(values):
         if self.is_num[i] and value != '' and try_canonical_int64(value) is None:
            raise WireError('column %s is numeric and holds %r' % (self.names[i], value))
      return values, stated

   def decode_verified(self, text):
      values, stated = self.decode(text)
      if stated is None:
         raise WireError('a wire record has no well-formed checksum')
      if stated != self.crc(values):
         raise WireError('bad checksum')
      return values


def load_codec(columns_path=None):
   path = columns_path or os.path.join(WIRE_DIR, 'columns.json')
   with open(path, 'r', encoding='utf-8') as f:
      return WireCodec(json.load(f))


def selftest(codec, vectors_path=None):
   """The copy's output against the oracle's golden vectors. Returns a list of
   (check, ok, detail)."""
   path = vectors_path or os.path.join(WIRE_DIR, 'golden_vectors.json')
   with open(path, 'r', encoding='utf-8') as f:
      vectors = json.load(f)
   results = []
   for v in vectors['rows']:
      values = v['values']
      ok_canon = codec.canonical(values).hex() == v['canonical_hex']
      ok_crc = crc_text(codec.crc(values)) == v['crc']
      ok_json = codec.encode(values) == v['json_omit']
      back, stated = codec.decode(v['json_omit'])
      ok_back = back == values and stated == codec.crc(values)
      results.append((v['label'], ok_canon and ok_crc and ok_json and ok_back,
                      'canonical=%s crc=%s json=%s back=%s'
                      % (ok_canon, ok_crc, ok_json, ok_back)))
   return results


# --- Message builders -------------------------------------------------------

def build_wire(msg_id, sender, text):
   """A QSO message: id, 4-byte payload length, sender byte, UTF-8 JSON."""
   payload = bytes([sender]) + text.encode('utf-8')
   return WIRE_HEADER.pack(msg_id, len(payload)) + payload


def build_wire_row(codec, msg_id, sender, values):
   return build_wire(msg_id, sender, codec.encode(values))


def parse_wire(frame):
   """(sender byte, JSON text) of a whole QSO message."""
   return frame[6], frame[7:].decode('utf-8')


def frame_values(codec, frame):
   return codec.decode_verified(parse_wire(frame)[1])


def build_hello(protocol, ordinal, version, contest_id):
   return struct.pack('<HHBB16s48s', NET_HELLO_ID, protocol, ordinal, 0,
                      version.encode('ascii'), contest_id.encode('ascii'))


def parse_hello(msg):
   """(protocol, computer id, version, contest id) of a 70-byte HELLO."""
   _id, protocol, ordinal, _reserved, version, contest = struct.unpack('<HHBB16s48s', msg)
   return (protocol, ordinal,
           version.split(b'\x00', 1)[0].decode('ascii'),
           contest.split(b'\x00', 1)[0].decode('ascii'))


def build_spot(call='K1ABC', freq_hz=14025000):
   inner = bytearray(SPOT_RECORD_SIZE)
   struct.pack_into('<i', inner, 0, freq_hz)
   struct.pack_into('<d', inner, 8, 46000.5)       # FSysTime, a TDateTime
   text = call.encode('ascii')[:13]
   inner[20] = len(text)
   inner[21:21 + len(text)] = text
   return struct.pack('<H', NET_NETWORKDXSPOT_ID) + bytes(inner)


def build_intercom(sender_ordinal, text):
   body = text.encode('ascii', 'replace')[:80]
   return (struct.pack('<HB', NET_INTERCOMMESSAGE_ID, sender_ordinal) +
           bytes([len(body)]) + body + b'\x00' * (80 - len(body)))


def build_timesync():
   """The REMOVED time-sync packet an older station still sends (20 bytes)."""
   now = time.gmtime()
   systemtime = struct.pack('<8H', now.tm_year, now.tm_mon, (now.tm_wday + 1) % 7,
                            now.tm_mday, now.tm_hour, now.tm_min, now.tm_sec, 0)
   return struct.pack('<H', NET_TIMESYN_ID) + systemtime + b'\x00\x00'


def build_server_message(message, param=0):
   return struct.pack('<HHi', NET_SERVERMESSAGE_ID, message, param)


def build_computer_id(ordinal):
   return struct.pack('<HBB', NET_COMPUTERID_ID, ordinal, 0)


def server_message_fields(msg):
   """(smMessage, smParam) of an 8-byte TServerMessage."""
   _msg_id, message, param = struct.unpack('<HHi', msg)
   return message, param


# --- One connection ---------------------------------------------------------

class Probe:
   """One client connection: handshake, framed receive, timed waits."""

   def __init__(self, name, host, port, password, ordinal, timeout,
                contest_id='ARRL-DX-CW'):
      self.name = name
      self.ordinal = ordinal
      self.contest_id = contest_id
      self.timeout = timeout
      self.buf = b''
      self.inbox = []             # (id, bytes) in arrival order
      self.eof = False
      self.bad_id = None          # (id, hex of the head) when framing was lost
      self.banner = b''
      self.sock = socket.create_connection((host, port), timeout=timeout)
      self.sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
      self._handshake(password)

   def _handshake(self, password):
      self.sock.sendall(password_on_wire(password))
      deadline = time.time() + self.timeout
      while len(self.banner) < 4 and time.time() < deadline:
         ready = select.select([self.sock], [], [], 0.25)[0]
         if ready:
            chunk = self.sock.recv(4 - len(self.banner))
            if not chunk:
               break
            self.banner += chunk
      if self.banner == BANNER_REFUSED:
         raise ProbeError('%s: server answered PASS (password refused)' % self.name)
      if self.banner != BANNER_OK:
         raise ProbeError('%s: no TR4W banner, got %r' % (self.name, self.banner))

   def send(self, data):
      self.sock.sendall(data)

   def claim_id(self):
      """The first message is a HELLO; it carries the computer id and contest."""
      self.send(build_hello(NET_PROTOCOL_VERSION, self.ordinal, 'netprobe',
                            self.contest_id))

   def claim_id_v1(self):
      """What a 4.x station sends first. A protocol 2+ server refuses it."""
      self.send(build_computer_id(self.ordinal))

   def pump(self, wait):
      """Read whatever arrives within `wait` seconds and frame it."""
      if self.eof:
         return
      ready = select.select([self.sock], [], [], wait)[0]
      if not ready:
         return
      try:
         chunk = self.sock.recv(262144)
      except OSError:
         self.eof = True
         return
      if not chunk:
         self.eof = True
         return
      self.buf += chunk
      self._frame()

   def _frame(self):
      while len(self.buf) >= 2 and self.bad_id is None:
         msg_id = struct.unpack('<H', self.buf[:2])[0]
         if msg_id in VARIABLE_IDS:
            if len(self.buf) < WIRE_HEADER.size:
               return
            size = WIRE_HEADER.size + WIRE_HEADER.unpack_from(self.buf)[1]
         else:
            size = MESSAGE_SIZE.get(msg_id)
            if size is None:
               self.bad_id = (msg_id, self.buf[:16].hex(' '))
               return
         if len(self.buf) < size:
            return
         self.inbox.append((msg_id, self.buf[:size]))
         self.buf = self.buf[size:]

   def take(self, msg_id, wait, message=None, where=None):
      """Pop the first message with this id (and, for a server message, this
      smMessage; and, when `where` is given, for which `where(data)` is true)
      that arrives within `wait` seconds, or None."""
      deadline = time.time() + wait
      while True:
         for index, (found_id, data) in enumerate(self.inbox):
            if found_id != msg_id:
               continue
            if message is not None and server_message_fields(data)[0] != message:
               continue
            if where is not None and not where(data):
               continue
            del self.inbox[index]
            return data
         remaining = deadline - time.time()
         if remaining <= 0 or self.eof or self.bad_id is not None:
            return None
         self.pump(min(remaining, 0.25))

   def settle(self, wait):
      """Let whatever the server sends on admit arrive, and return it."""
      deadline = time.time() + wait
      while time.time() < deadline and not self.eof:
         self.pump(0.1)
      return list(self.inbox)

   def count(self, msg_id, wanted, wait):
      """Wait up to `wait` seconds for `wanted` messages of one id."""
      deadline = time.time() + wait
      while time.time() < deadline and not self.eof and self.bad_id is None:
         if sum(1 for found_id, _ in self.inbox if found_id == msg_id) >= wanted:
            break
         self.pump(0.1)
      return sum(1 for found_id, _ in self.inbox if found_id == msg_id)

   def alive(self, wait):
      """Is the link still usable? Sends an intercom line; every server echoes
      that to the sender, so an answer proves the read path is alive."""
      if self.eof:
         return False
      try:
         self.send(build_intercom(self.ordinal, 'probe alive'))
      except OSError:
         return False
      return self.take(NET_INTERCOMMESSAGE_ID, wait) is not None

   def close(self):
      try:
         self.sock.close()
      except OSError:
         pass

   def why_dead(self):
      if self.bad_id is not None:
         return 'framing lost at id %d (%s)' % self.bad_id
      if self.eof:
         return 'the server closed the connection'
      return 'no answer'

   def drop_inbox(self, *ids):
      self.inbox = [item for item in self.inbox if item[0] not in ids]


# --- The sync port: the server's log as a stream of framed rows -------------

def _read_exact(sock, n, deadline):
   data = b''
   while len(data) < n and time.time() < deadline:
      if select.select([sock], [], [], 0.25)[0]:
         chunk = sock.recv(min(262144, n - len(data)))
         if not chunk:
            break
         data += chunk
   return data


def fetch_sync_stream(host, port, password, timeout, send_bytes):
   """Download the sync stream: ten password bytes, then a header frame
   {"contest","rows","schema"} and `rows` row frames, each a 4-byte LE length and
   UTF-8 JSON. Returns (raw bytes of the whole stream, why) -- raw is None on a
   failure, with the reason."""
   try:
      sock = socket.create_connection((host, port + 1), timeout=timeout)
   except OSError as err:
      return None, 'sync port: %s' % err
   try:
      wire = password_on_wire(password)
      wire += b'\x00' * max(0, send_bytes - len(wire))
      sock.sendall(wire)
      deadline = time.time() + timeout
      head = _read_exact(sock, 4, deadline)
      if len(head) < 4:
         return None, 'sync port sent no header frame within %.0f s' % timeout
      size = struct.unpack('<I', head)[0]
      if size > 1024 * 1024:
         return None, 'sync header length %d is not credible' % size
      body = _read_exact(sock, size, deadline)
      if len(body) < size:
         return None, 'sync header: %d of %d bytes' % (len(body), size)
      try:
         rows = json.loads(body.decode('utf-8'))['rows']
      except (ValueError, KeyError, TypeError) as err:
         return None, 'sync header is not {"contest","rows","schema"}: %s' % err
      raw = head + body
      for number in range(rows):
         length_bytes = _read_exact(sock, 4, deadline)
         if len(length_bytes) < 4:
            return None, 'sync port ended after %d of %d rows' % (number, rows)
         length = struct.unpack('<I', length_bytes)[0]
         if length > 1024 * 1024:
            return None, 'sync row length %d is not credible' % length
         row = _read_exact(sock, length, deadline)
         if len(row) < length:
            return None, 'sync row %d: %d of %d bytes' % (number, len(row), length)
         raw += length_bytes + row
      return raw, ''
   except OSError as err:
      return None, 'sync port: %s' % err
   finally:
      sock.close()


class SyncView:
   """A downloaded sync stream, decoded: header dict, rows (value lists, each
   checksum verified) and the raw bytes."""

   def __init__(self, codec, raw):
      self.raw = raw
      self.problem = ''
      self.header = {}
      self.rows = []
      self.frames = []
      at = 0
      length = struct.unpack_from('<I', raw, at)[0]
      self.header = json.loads(raw[at + 4:at + 4 + length].decode('utf-8'))
      at += 4 + length
      while at < len(raw):
         length = struct.unpack_from('<I', raw, at)[0]
         text = raw[at + 4:at + 4 + length].decode('utf-8')
         self.frames.append(text)
         try:
            self.rows.append(codec.decode_verified(text))
         except WireError as err:
            self.problem = 'row %d: %s' % (len(self.rows), err)
            self.rows.append(None)
         at += 4 + length

   def guids(self, codec):
      i = codec.index('guid')
      return [r[i] if r else None for r in self.rows]


# --- Launching a server as a child process ----------------------------------

class Launcher:
   """Starts, kills and restarts one server in a work directory. kind is
   'pascal' (path = tr4wserver.exe) or 'python' (path = tr4wserver.py)."""

   def __init__(self, kind, path, workdir, port, lockout=False):
      self.kind = kind
      self.path = path
      self.workdir = workdir
      self.port = port
      self.lockout = lockout
      self.proc = None
      self.logfile = None

   @property
   def db_path(self):
      return os.path.join(self.workdir, 'SERVERLOG.tr4wsrv')

   def _port_open(self):
      c = socket.socket()
      c.settimeout(0.3)
      try:
         c.connect(('127.0.0.1', self.port))
         return True
      except OSError:
         return False
      finally:
         c.close()

   def start(self):
      if self._port_open():
         raise ProbeError('something already listens on port %d' % self.port)
      os.makedirs(self.workdir, exist_ok=True)
      ini = os.path.join(self.workdir, 'TR4WSERVER.INI')
      with open(ini, 'w', newline='') as f:
         f.write('[TR4WSERVER]\r\nPORT=%d\r\nSERIAL NUMBER LOCKOUT=%d\r\n'
                 % (self.port, 1 if self.lockout else 0))
      self.logfile = open(os.path.join(self.workdir, 'server.out'), 'ab')
      if self.kind == 'pascal':
         # The exe is copied beside sqlite3.dll by the caller; its working
         # directory is the case directory (ini, log, database land there).
         command = [self.path]
      else:
         # No -I: isolated mode would drop the script's own directory from
         # sys.path and its sibling modules would not import.
         command = [sys.executable, self.path, '-c', ini]
      self.proc = subprocess.Popen(command, cwd=self.workdir, stdin=subprocess.DEVNULL,
                                   stdout=self.logfile, stderr=self.logfile)
      for _ in range(100):
         time.sleep(0.2)
         if self._port_open():
            return
         if self.proc.poll() is not None:
            break
      raise ProbeError('the %s server did not listen on port %d' % (self.kind, self.port))

   def kill(self):
      """Terminate the process abruptly (TerminateProcess): no shutdown code."""
      if self.proc is not None and self.proc.poll() is None:
         self.proc.kill()
         try:
            self.proc.wait(5)
         except subprocess.TimeoutExpired:
            pass
      time.sleep(0.5)
      if self.logfile is not None:
         self.logfile.close()
         self.logfile = None

   def restart(self):
      self.kill()
      self.start()


def read_database(path):
   """Every column of every qso row in seq order, and the meta rows, from a
   .tr4wsrv file, read-only. Returns {'columns': [...], 'rows': [[...]], 'meta':
   {...}} or None."""
   if not os.path.exists(path):
      return None
   conn = sqlite3.connect('file:%s?mode=ro' % path.replace('\\', '/'), uri=True)
   try:
      cursor = conn.execute('SELECT * FROM qso ORDER BY seq')
      columns = [d[0] for d in cursor.description]
      rows = [list(r) for r in cursor.fetchall()]
      meta = {k: v for k, v in conn.execute('SELECT key, value FROM meta')}
   finally:
      conn.close()
   return {'columns': columns, 'rows': rows, 'meta': meta}


# --- Reporting --------------------------------------------------------------

class Report:
   def __init__(self, label):
      self.label = label
      self.lines = []
      self.failed = 0
      self.errored = 0

   def add(self, case, check, status, detail=''):
      line = 'RESULT %s %s %s: %s %s' % (self.label, case, check, status, detail)
      line = line.rstrip()
      self.lines.append(line)
      print(line, flush=True)
      if status == 'FAIL':
         self.failed += 1

   def ok(self, case, check, condition, detail=''):
      self.add(case, check, 'PASS' if condition else 'FAIL', detail)

   def error(self, case, detail):
      self.add(case, 'run', 'ERROR', detail)
      self.errored += 1


# --- The cases --------------------------------------------------------------

# THE GUIDS A RUN HANDS OUT ARE UNIQUE ACROSS ITS CASES AND ACROSS RUNS. A server
# stores a QSO once whatever number of times it arrives (the guid is the key), so
# two cases that reused one would find the second "already held". The default
# seed is the clock; --seed-ids makes a run repeatable, which the comparison of
# the two servers needs (the same inputs, so the same rows).
_NEXT_ID = [int(time.time() * 1000) & 0x7FFFFFF0]


class Context:
   def __init__(self, args, report, codec, launcher=None):
      self.args = args
      self.report = report
      self.codec = codec
      self.launcher = launcher
      self.probes = []

   def probe(self, name, ordinal, claim=True, contest_id=None):
      p = Probe(name, self.args.host, self.args.port, self.args.password,
                ordinal, self.args.timeout, contest_id or self.args.contest)
      self.probes.append(p)
      if claim:
         p.claim_id()
      return p

   def next_n(self):
      _NEXT_ID[0] += 1
      return _NEXT_ID[0]

   def row(self, call, n=None, **over):
      """A deterministic row: the guid and times come from the counter."""
      if n is None:
         n = self.next_n()
      values = self.codec.default_values()
      fields = {'guid': '%032x' % n, 'callsign': call,
                'qso_at': str(1700000000 + n % 1000000), 'band': '20',
                'mode': 'CW', 'computer_id': 'A', 'serial_sent': str(n % 1000),
                'freq_tx_hz': '14025000', 'exchange_received': '599 05'}
      fields.update(over)
      for name, value in fields.items():
         values[self.codec.index(name)] = value
      return values

   def msg(self, msg_id, sender, values):
      return build_wire_row(self.codec, msg_id, sender, values)

   def close_all(self):
      for p in self.probes:
         p.close()
      self.probes = []

   def view(self):
      """The server's log through the sync port, or None (reported INFO)."""
      raw, why = fetch_sync_stream(self.args.host, self.args.port, self.args.password,
                                   self.args.sync_timeout, self.args.sync_bytes)
      if raw is None:
         self.report.add('sync', 'log download', 'INFO', why)
         return None
      return SyncView(self.codec, raw)

   def rows(self):
      v = self.view()
      return None if v is None else v.rows

   def wait_rows(self, count, wait):
      """Poll the log until it holds `count` rows, or `wait` seconds pass."""
      deadline = time.time() + wait
      v = self.view()
      while v is not None and len(v.rows) < count and time.time() < deadline:
         time.sleep(0.3)
         v = self.view()
      return v


def describe_receipt(got, sent, probe):
   if got is None:
      return probe.why_dead()
   if got == sent:
      return '%d bytes, identical' % len(got)
   first = next((i for i in range(min(len(got), len(sent))) if got[i] != sent[i]), -1)
   return '%d bytes, differs from what was sent at byte %d' % (len(got), first)


def relayed_equals(ctx, got, sent_values, expect_sender):
   """A relayed QSO message: the sender byte is the HELLO's station and the row
   is the one sent (compared as values, so a server that re-encodes the JSON is
   judged on the row and not on its spelling)."""
   if got is None:
      return False, 'nothing received'
   sender = got[6]
   try:
      values = frame_values(ctx.codec, got)
   except (WireError, UnicodeDecodeError) as err:
      return False, 'relayed row does not verify: %s' % err
   if sender != expect_sender:
      return False, 'sender byte %d, wanted %d' % (sender, expect_sender)
   if values != sent_values:
      return False, 'row differs'
   return True, '%d bytes, sender %d' % (len(got), sender)


def log_growth(before, after):
   if before is None or after is None:
      return None
   return len(after) - len(before)


def case_selftest(ctx):
   r = ctx.report
   for label, ok, detail in selftest(ctx.codec):
      r.ok('selftest', 'golden vector: %s' % label, ok, detail)


def case_connect(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   admitted = a.settle(0.8)
   ids = [found_id for found_id, _ in admitted]
   r.add('connect', 'banner', 'PASS', 'TR4W')
   r.ok('connect', 'LOGCOMPARE on admit', NET_LOGCOMPARE_ID in ids,
        'sizes %s' % [len(d) for i, d in admitted if i == NET_LOGCOMPARE_ID])
   for i, d in admitted:
      if i == NET_LOGCOMPARE_ID:
         _id, crc1, crc2, rows, local, contest = struct.unpack('<HIIIIB', d)
         r.ok('connect', 'LOGCOMPARE carries the row count, no CRC and no contest',
              crc1 == 0 and contest == 0, 'rows %d, crc %d, contest %d' % (rows, crc1, contest))
   r.ok('connect', 'link alive', a.alive(ctx.args.timeout),
        '' if not a.eof else a.why_dead())


def case_spot(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   spot = build_spot()
   r.add('spot', 'size sent', 'INFO', '%d bytes' % len(spot))
   a.send(spot)
   got = b.take(NET_NETWORKDXSPOT_ID, ctx.args.timeout)
   r.ok('spot', 'B receives the spot', got == spot, describe_receipt(got, spot, b))
   alive = a.alive(ctx.args.timeout)
   r.ok('spot', 'sender still connected', alive, '' if alive else a.why_dead())


def case_qso(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   before = ctx.rows()
   values = ctx.row('K1QSO', rcvd_name='José', notes='a note')
   msg = ctx.msg(NET_WIRE_QSO_ID, 1, values)
   r.add('qso', 'size sent', 'INFO', '%d bytes' % len(msg))
   a.send(msg)
   got = b.take(NET_WIRE_QSO_ID, ctx.args.timeout)
   ok, detail = relayed_equals(ctx, got, values, 1)
   r.ok('qso', 'B receives the QSO, row intact, sender = A', ok, detail)
   r.ok('qso', 'sender not echoed', a.take(NET_WIRE_QSO_ID, 0.5) is None)
   # A lies about who it is: the server re-stamps the sender byte from the HELLO.
   other = ctx.row('K1QSO2')
   a.send(ctx.msg(NET_WIRE_QSO_ID, 9, other))
   got = b.take(NET_WIRE_QSO_ID, ctx.args.timeout)
   ok, detail = relayed_equals(ctx, got, other, 1)
   r.ok('qso', 'the sender byte is re-stamped from the accepted HELLO', ok, detail)
   after = ctx.wait_rows((len(before) if before is not None else 0) + 2, 3)
   grew = log_growth(before, None if after is None else after.rows)
   if grew is None:
      r.add('qso', 'server log grew by two rows', 'SKIP', 'log not readable')
      return
   r.ok('qso', 'server log grew by two rows', grew == 2, 'rows grew by %d' % grew)
   r.ok('qso', 'every stored row checksum verifies', after.problem == '', after.problem)
   r.ok('qso', 'stored rows are the rows sent, in order',
        after.rows[-2:] == [values, other])


def case_burst(ctx):
   r = ctx.report
   count = ctx.args.burst
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   before = ctx.rows()
   sent = [ctx.row('K1BST') for _ in range(count)]
   blob = b''.join(ctx.msg(NET_WIRE_QSO_ID, 1, v) for v in sent)
   a.send(blob)                       # ONE write: the server sees a coalesced read
   r.add('burst', 'bytes written in one send', 'INFO', str(len(blob)))
   got = b.count(NET_WIRE_QSO_ID, count, ctx.args.timeout + 3)
   r.ok('burst', 'B receives all %d' % count, got == count,
        'received %d%s' % (got, '' if b.bad_id is None else '; ' + b.why_dead()))
   after = ctx.wait_rows((len(before) if before is not None else 0) + count, 5)
   grew = log_growth(before, None if after is None else after.rows)
   if grew is None:
      r.add('burst', 'server log grew by %d' % count, 'SKIP', 'log not readable')
   else:
      r.ok('burst', 'server log grew by %d' % count, grew == count, 'grew by %d' % grew)
      r.ok('burst', 'in arrival order, row for row', after.rows[len(before):] == sent)


def case_edit(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   n = ctx.next_n()
   original = ctx.row('K1OLD', n, rcvd_name='Bob', notes='first')
   a.send(ctx.msg(NET_WIRE_QSO_ID, 1, original))
   b.take(NET_WIRE_QSO_ID, ctx.args.timeout)
   before = ctx.wait_rows(1, 3)
   edited = ctx.row('K1NEW', n)                 # rcvd_name and notes omitted
   a.send(ctx.msg(NET_WIRE_EDIT_ID, 1, edited))
   got = b.take(NET_WIRE_EDIT_ID, ctx.args.timeout)
   ok, detail = relayed_equals(ctx, got, edited, 1)
   r.ok('edit', 'B receives the edit', ok, detail)
   ack = a.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_RECEIVED_UPDATED_QSO)
   r.ok('edit', 'sender gets the 8300 ACK', ack is not None)
   time.sleep(0.5)
   after = ctx.view()
   if before is None or after is None:
      r.add('edit', 'server row rewritten in place, whole', 'SKIP', 'log not readable')
   else:
      r.ok('edit', 'server row rewritten in place, whole (an omitted field is its default)',
           len(after.rows) == len(before.rows) and after.rows[-1] == edited,
           'rows %d -> %d, last call %s' % (len(before.rows), len(after.rows),
                                            after.rows[-1][ctx.codec.index('callsign')]))
   # An edit of a guid the server never held: relayed and ACKed, stores nothing.
   a.take(NET_SERVERMESSAGE_ID, 0.2, SM_RECEIVED_UPDATED_QSO)
   stray = ctx.row('K1STRAY')
   a.send(ctx.msg(NET_WIRE_EDIT_ID, 1, stray))
   got = b.take(NET_WIRE_EDIT_ID, ctx.args.timeout)
   r.ok('edit', 'an edit of an unheld guid is relayed', got is not None)
   ack = a.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_RECEIVED_UPDATED_QSO)
   r.ok('edit', 'and acknowledged', ack is not None)
   time.sleep(0.5)
   final = ctx.view()
   if final is not None and after is not None:
      r.ok('edit', 'and stores nothing', len(final.rows) == len(after.rows))
   # An edit that carries an empty guid changes nothing (13.6 rule 5).
   anon = ctx.row('K1ANON', guid='')
   a.send(ctx.msg(NET_WIRE_QSO_ID, 1, anon))
   b.take(NET_WIRE_QSO_ID, ctx.args.timeout)
   mid = ctx.wait_rows(len(after.rows) + 1 if after is not None else 1, 3)
   a.send(ctx.msg(NET_WIRE_EDIT_ID, 1, ctx.row('K1ANON2', guid='')))
   a.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_RECEIVED_UPDATED_QSO)
   time.sleep(0.5)
   end = ctx.view()
   if mid is not None and end is not None:
      r.ok('edit', 'an edit with an empty guid changes nothing',
           end.rows == mid.rows)


def case_disc(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   b.close()
   msg = a.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_DISCONECT_CLIENT)
   if msg is None:
      r.add('disc', 'A told that B left', 'FAIL', 'no 8260 within %.0f s' % ctx.args.timeout)
      return
   param = server_message_fields(msg)[1]
   r.add('disc', 'A told that B left', 'PASS', 'param %d' % param)
   r.ok('disc', 'param is the ordinal 1..26 (the client range-checks this)',
        1 <= param <= 26, 'param %d' % param)
   r.ok('disc', "param is B's ordinal (2)", param == 2)


def case_dup(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   c = ctx.probe('C', 1)              # a second station claiming ordinal 1
   refusal = c.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_COMPUTERID_IN_USE)
   r.ok('dup', 'second claimant gets 8320', refusal is not None,
        '' if refusal else 'accepted silently')
   r.ok('dup', 'first holder not refused',
        a.take(NET_SERVERMESSAGE_ID, 0.5, SM_COMPUTERID_IN_USE) is None)
   a.claim_id()
   r.ok('dup', 'a station re-announcing its own id is not refused',
        a.take(NET_SERVERMESSAGE_ID, 0.5, SM_COMPUTERID_IN_USE) is None)

   # The same row twice (by guid), then the same guid from another station: one
   # stored, one relayed.
   before = ctx.rows()
   values = ctx.row('K1DUP')
   msg = ctx.msg(NET_WIRE_QSO_ID, 1, values)
   b.take(NET_HELLO_ID, 0.1)
   a.send(msg)
   got = b.take(NET_WIRE_QSO_ID, ctx.args.timeout)
   r.ok('dup', 'a new row is relayed', got is not None)
   a.send(msg)
   b.send(ctx.msg(NET_WIRE_QSO_ID, 2, values))
   r.ok('dup', 'the same guid again, from A or from B, is not relayed',
        b.take(NET_WIRE_QSO_ID, 1.0) is None and a.take(NET_WIRE_QSO_ID, 0.3) is None)
   time.sleep(0.5)
   after = ctx.rows()
   grew = log_growth(before, after)
   if grew is not None:
      r.ok('dup', 'and is stored once', grew == 1, 'grew by %d' % grew)

   a.close()
   time.sleep(1.0)
   d = ctx.probe('D', 1)
   r.ok('dup', 'the id of a station that has left can be taken again',
        d.take(NET_SERVERMESSAGE_ID, 1.0, SM_COMPUTERID_IN_USE) is None)


def case_serial(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   admitted = a.settle(1.0)
   first = [server_message_fields(d) for i, d in admitted
            if i == NET_SERVERMESSAGE_ID and
            server_message_fields(d)[0] == SM_SERIAL_NUMBER_CHANGED]
   if not first:
      r.add('serial', '8310 pushed on admit', 'SKIP',
            'none seen: the server has SERIAL NUMBER LOCKOUT off')
      return
   n0 = first[-1][1]
   r.add('serial', '8310 pushed on admit', 'PASS', 'next serial %d' % n0)
   b = ctx.probe('B', 2)
   got = b.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_SERIAL_NUMBER_CHANGED)
   r.ok('serial', 'B is told the same next serial',
        got is not None and server_message_fields(got)[1] == n0,
        'got %s' % (server_message_fields(got)[1] if got else 'nothing'))
   a.send(build_server_message(SM_SERIAL_NUMBER_CHANGED, SNT_RESERVED))
   bumped = b.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_SERIAL_NUMBER_CHANGED)
   r.ok('serial', 'B sees the next serial advance after A reserves',
        bumped is not None and server_message_fields(bumped)[1] == n0 + 1,
        'got %s' % (server_message_fields(bumped)[1] if bumped else 'nothing'))
   # The scan over the log: rows with serial_sent 700..704 are stored, the
   # server restarts, and the next serial it announces is reported (INFO: the
   # two servers must agree, which compare.py checks).
   if ctx.launcher is None:
      r.add('serial', 'next serial after a restart', 'SKIP', 'needs --launch')
      return
   for k in (700, 704, 702):
      a.send(ctx.msg(NET_WIRE_OFFLINE_ID, 1, ctx.row('K1SER', serial_sent=str(k))))
   count_acks(a, 3, ctx.args.timeout + 3)
   ctx.close_all()
   ctx.launcher.restart()
   a2 = ctx.probe('A', 1)
   seen = [server_message_fields(d)[1] for i, d in a2.settle(1.0)
           if i == NET_SERVERMESSAGE_ID and
           server_message_fields(d)[0] == SM_SERIAL_NUMBER_CHANGED]
   r.add('serial', 'next serial after a restart over serials up to 704', 'INFO',
         '%s' % (seen[-1] if seen else 'none announced'))


def case_time(ctx):
   """"Synchronize time on all computers" was REMOVED (2026-11-03). An OLDER
   station still sends the packet, so the server must SKIP its 20 bytes and NOT
   relay it. The intercom line in the SAME write proves the skip landed on a
   message boundary."""
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   a.send(build_timesync() + build_intercom(1, 'after the time sync'))
   behind = b.take(NET_INTERCOMMESSAGE_ID, ctx.args.timeout)
   r.ok('time', 'the message behind a TIMESYN is relayed to B', behind is not None,
        'got it' if behind is not None else 'nothing: the framing did not skip 20 bytes')
   relayed = b.take(NET_TIMESYN_ID, 0.5) is not None
   r.ok('time', 'TIMESYN is not relayed to B', not relayed,
        'relayed' if relayed else 'not relayed')
   a.take(NET_INTERCOMMESSAGE_ID, 0.5)
   r.ok('time', 'A is still connected after sending it', a.alive(ctx.args.timeout))


def hello_of(station):
   """A `where` for Probe.take: a HELLO announcing this station."""
   return lambda data: parse_hello(data)[1] == station


def wait_closed(probe, wait):
   """Did the server close this connection within `wait` seconds?"""
   deadline = time.time() + wait
   while time.time() < deadline and not probe.eof:
      probe.pump(0.1)
   return probe.eof


def case_hello(ctx):
   """The HELLO handshake, the contest id it carries and what a server does
   with a station that does not speak it (protocol 5)."""
   r = ctx.report
   timeout = ctx.args.timeout

   a = ctx.probe('A', 1, contest_id='ARRL-DX-CW')
   server_hello = a.take(NET_HELLO_ID, timeout, where=hello_of(0))
   if server_hello is None:
      r.add('hello', 'server answers a HELLO with its own', 'FAIL', a.why_dead())
   else:
      protocol, _ordinal, version, contest = parse_hello(server_hello)
      r.add('hello', 'server answers a HELLO with its own', 'PASS',
            'protocol %d' % protocol)
      r.add('hello', "the server's own version text (differs by build)", 'INFO', '"%s"' % version)
      r.ok('hello', 'the server speaks protocol %d' % NET_PROTOCOL_VERSION,
           protocol == NET_PROTOCOL_VERSION)
      r.ok('hello', "the server's HELLO has a version text", bool(version))
      r.ok('hello', "the server's HELLO names no contest", contest == '', '"%s"' % contest)
   alive = a.alive(timeout)
   r.ok('hello', 'a good HELLO is admitted (link stays up)', alive, '' if alive else a.why_dead())

   long_id = 'REGION 1 FIELD DAY-RCC-SSB'
   b = ctx.probe('B', 2, contest_id=long_id)
   replay = b.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.ok('hello', 'a station that joins is told what A announced',
        replay is not None and parse_hello(replay)[3] == 'ARRL-DX-CW',
        parse_hello(replay)[3] if replay else b.why_dead())
   sent_by_b = build_hello(NET_PROTOCOL_VERSION, 2, 'netprobe', long_id)
   relayed = a.take(NET_HELLO_ID, timeout, where=hello_of(2))
   r.ok('hello', 'A is told what B announced, byte for byte', relayed == sent_by_b,
        '' if relayed == sent_by_b else (parse_hello(relayed)[3] if relayed else a.why_dead()))
   r.ok('hello', 'a HELLO is not echoed to its sender',
        b.take(NET_HELLO_ID, 0.5, where=hello_of(2)) is None)

   a.send(build_hello(NET_PROTOCOL_VERSION, 1, 'netprobe', 'CQ-WW-CW'))
   again = b.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.ok('hello', 'a contest change is relayed',
        again is not None and parse_hello(again)[3] == 'CQ-WW-CW',
        parse_hello(again)[3] if again else b.why_dead())
   c = ctx.probe('C', 3, contest_id='CQ-WW-SSB')
   latest = c.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.ok('hello', 'a later joiner is told the LATEST contest, not the first',
        latest is not None and parse_hello(latest)[3] == 'CQ-WW-CW',
        parse_hello(latest)[3] if latest else c.why_dead())
   other = c.take(NET_HELLO_ID, timeout, where=hello_of(2))
   r.ok('hello', "and every other station's as well",
        other is not None and parse_hello(other)[3] == long_id)

   # The QSO still flows and carries the sender.
   values = ctx.row('K1HLO')
   a.send(ctx.msg(NET_WIRE_QSO_ID, 1, values))
   got = b.take(NET_WIRE_QSO_ID, timeout)
   ok, detail = relayed_equals(ctx, got, values, 1)
   r.ok('hello', 'a QSO after the HELLO is relayed with its sender byte intact', ok, detail)

   # What is refused.
   v1 = ctx.probe('V1', 4, claim=False)
   v1.claim_id_v1()
   r.ok('hello', "no HELLO first (a 4.x station's COMPUTERID): connection closed",
        wait_closed(v1, timeout))
   stray = [MESSAGE_NAME.get(found_id, str(found_id)) for found_id, _data in v1.inbox
            if found_id not in (NET_LOGCOMPARE_ID, NET_SERVERMESSAGE_ID)]
   r.ok('hello', 'and it was answered with no HELLO', not stray, ', '.join(stray))

   q = ctx.probe('Q', 5, claim=False)
   q.send(ctx.msg(NET_WIRE_QSO_ID, 5, ctx.row('K1NOH')))
   r.ok('hello', 'a QSO sent before any HELLO: connection closed', wait_closed(q, timeout))
   r.ok('hello', 'and it was not relayed', a.take(NET_WIRE_QSO_ID, 0.5) is None)

   # Protocol 4 (the version before this one) must be refused READABLY: its
   # HELLO is the same 70 bytes, so the server can answer it with an 8330.
   for version, label in ((NET_PROTOCOL_VERSION - 1, 'older'), (NET_PROTOCOL_VERSION + 1, 'newer')):
      p = ctx.probe('P%d' % version, 6, claim=False)
      p.send(build_hello(version, 6, 'netprobe', 'X'))
      refusal = p.take(NET_SERVERMESSAGE_ID, timeout, SM_PROTOCOL_MISMATCH)
      r.ok('hello', 'protocol %d (%s) is refused with 8330' % (version, label),
           refusal is not None, '' if refusal else p.why_dead())
      if refusal:
         param = server_message_fields(refusal)[1]
         r.ok('hello', "8330 carries the server's protocol (%d)" % NET_PROTOCOL_VERSION,
              param == NET_PROTOCOL_VERSION, 'param %d' % param)
      r.ok('hello', 'protocol %d: connection closed afterwards' % version,
           wait_closed(p, timeout))
   r.ok('hello', 'a refused station is never announced to the others',
        a.take(NET_HELLO_ID, 0.5, where=hello_of(6)) is None)

   dup = ctx.probe('D', 1, claim=False, contest_id='DUP-CONTEST')
   dup.send(build_hello(NET_PROTOCOL_VERSION, 1, 'netprobe', 'DUP-CONTEST'))
   refusal = dup.take(NET_SERVERMESSAGE_ID, timeout, SM_COMPUTERID_IN_USE)
   r.ok('hello', "a HELLO claiming A's id is refused with 8320", refusal is not None,
        '' if refusal else 'accepted')
   r.ok('hello', 'and its contest is not announced',
        b.take(NET_HELLO_ID, 0.5, where=lambda d: parse_hello(d)[3] == 'DUP-CONTEST') is None)
   # The refused station is still connected but unidentified: a QSO from it must
   # not be stored or relayed (the contract is silent; this records what each
   # server does).
   dup.send(ctx.msg(NET_WIRE_QSO_ID, 1, ctx.row('K1UNID')))
   got = b.take(NET_WIRE_QSO_ID, 1.0)
   r.add('hello', 'a QSO from a station refused for its id is relayed', 'INFO',
         'relayed' if got is not None else 'not relayed')

   for bad in (0, 27):
      p = ctx.probe('I%d' % bad, bad, claim=False)
      p.send(build_hello(NET_PROTOCOL_VERSION, bad, 'netprobe', 'X'))
      refusal = p.take(NET_SERVERMESSAGE_ID, timeout, SM_COMPUTERID_IN_USE)
      r.ok('hello', 'computer id %d is refused with 8320' % bad, refusal is not None)

   # A HELLO with an EMPTY contest (a station with no contest open): admitted;
   # what the server then holds as its contest is compared by compare.py.
   e = ctx.probe('E', 7, claim=False)
   e.send(build_hello(NET_PROTOCOL_VERSION, 7, 'netprobe', ''))
   r.ok('hello', 'a HELLO with an empty contest is admitted', e.alive(timeout))


def case_resend(ctx):
   """A station that was disconnected sends again what it logged meanwhile, and
   one that crashed before it noted what it had sent sends some of it twice.
   The server must store a QSO ONCE however many times it arrives, relay it
   once, and still tell every sender it has it. The guid tells one QSO from
   another; an empty guid identifies nothing."""
   r = ctx.report
   timeout = ctx.args.timeout
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)

   before = ctx.rows()
   n = ctx.next_n()
   values = ctx.row('K1RS1', n)
   first = ctx.msg(NET_WIRE_QSO_ID, 1, values)
   a.send(first)
   got = b.take(NET_WIRE_QSO_ID, timeout)
   ok, detail = relayed_equals(ctx, got, values, 1)
   r.ok('resend', 'a new QSO is relayed', ok, detail)
   held = ctx.wait_rows((len(before) if before is not None else 0) + 1, 3)
   grew = log_growth(before, None if held is None else held.rows)
   if grew is None:
      r.add('resend', 'a new QSO is stored once', 'SKIP', 'log not readable')
   else:
      r.ok('resend', 'a new QSO is stored once', grew == 1, 'grew by %d' % grew)
   held_rows = None if held is None else held.rows

   a.send(first)
   again = b.take(NET_WIRE_QSO_ID, 1.5)
   r.ok('resend', 'a second NEW of a held QSO is not relayed', again is None,
        '' if again is None else 'B received it again')
   time.sleep(0.5)
   after = ctx.rows()
   grew = log_growth(held_rows, after)
   if grew is None:
      r.add('resend', 'a second NEW of a held QSO is not stored', 'SKIP', 'log not readable')
   else:
      r.ok('resend', 'a second NEW of a held QSO is not stored', grew == 0, 'grew by %d' % grew)
   r.ok('resend', 'the sender stays connected', a.alive(timeout))

   # The same QSO as OFFLINE: not stored, but acknowledged.
   a.take(NET_SERVERMESSAGE_ID, 0.2, SM_RECEIVED_UPDATED_QSO)
   a.send(ctx.msg(NET_WIRE_OFFLINE_ID, 1, values))
   ack = a.take(NET_SERVERMESSAGE_ID, timeout, SM_RECEIVED_UPDATED_QSO)
   r.ok('resend', 'an OFFLINE row of a held QSO is acknowledged', ack is not None)
   time.sleep(0.5)
   grew = log_growth(held_rows, ctx.rows())
   if grew is not None:
      r.ok('resend', 'an OFFLINE row of a held QSO is not stored', grew == 0, 'grew by %d' % grew)

   # An OFFLINE row the server has never seen: stored and acknowledged, not
   # relayed (which is why the client resends as NEW).
   fresh = ctx.row('K1RS2')
   a.send(ctx.msg(NET_WIRE_OFFLINE_ID, 1, fresh))
   ack = a.take(NET_SERVERMESSAGE_ID, timeout, SM_RECEIVED_UPDATED_QSO)
   r.ok('resend', 'a new OFFLINE row is acknowledged', ack is not None)
   time.sleep(0.5)
   now = ctx.rows()
   grew = log_growth(held_rows, now)
   if grew is not None:
      r.ok('resend', 'a new OFFLINE row is stored', grew == 1, 'grew by %d' % grew)
   relayed = b.take(NET_WIRE_OFFLINE_ID, 1.0) or b.take(NET_WIRE_QSO_ID, 0.2)
   r.ok('resend', 'an OFFLINE row is not relayed', relayed is None,
        'relayed' if relayed else 'not relayed')

   # An empty guid identifies nothing: never a duplicate.
   held_rows = ctx.rows()
   anon = ctx.row('K1RS3', guid='')
   a.send(ctx.msg(NET_WIRE_QSO_ID, 1, anon))
   a.send(ctx.msg(NET_WIRE_QSO_ID, 1, anon))
   got = b.count(NET_WIRE_QSO_ID, 2, timeout)
   time.sleep(0.5)
   grew = log_growth(held_rows, ctx.rows())
   r.ok('resend', 'a row with an empty guid is relayed every time', got >= 2,
        'B has %d' % got)
   if grew is not None:
      r.ok('resend', 'a row with an empty guid is stored every time', grew == 2,
           'grew by %d' % grew)

   # An edit of a held QSO is relayed and applied.
   held_rows = ctx.rows()
   edited = ctx.row('K1RS1X', n)
   a.send(ctx.msg(NET_WIRE_EDIT_ID, 1, edited))
   got = b.take(NET_WIRE_EDIT_ID, timeout)
   ok, detail = relayed_equals(ctx, got, edited, 1)
   r.ok('resend', 'an edit of a held QSO is relayed', ok, detail)
   time.sleep(0.5)
   after = ctx.rows()
   if held_rows is not None and after is not None:
      r.ok('resend', 'an edit of a held QSO is applied in place',
           edited in after and values not in after and len(after) == len(held_rows),
           'rows %d -> %d' % (len(held_rows), len(after)))

   # A whole burst sent twice is relayed and stored once.
   count = ctx.args.burst
   held_rows = ctx.rows()
   burst = [ctx.row('K1RS4') for _ in range(count)]
   blob = b''.join(ctx.msg(NET_WIRE_QSO_ID, 1, v) for v in burst)
   b.drop_inbox(NET_WIRE_QSO_ID)
   a.send(blob)
   got = b.count(NET_WIRE_QSO_ID, count, timeout + 3)
   r.ok('resend', 'a burst of %d is relayed whole' % count, got >= count, 'B has %d' % got)
   have = sum(1 for found_id, _ in b.inbox if found_id == NET_WIRE_QSO_ID)
   a.send(blob)
   time.sleep(1.5)
   b.pump(0.5)
   now = sum(1 for found_id, _ in b.inbox if found_id == NET_WIRE_QSO_ID)
   r.ok('resend', 'the same burst sent again is not relayed again', now == have,
        'B went from %d to %d' % (have, now))
   time.sleep(0.5)
   grew = log_growth(held_rows, ctx.rows())
   if grew is not None:
      r.ok('resend', 'the same burst sent again is stored once', grew == count,
           'grew by %d, wanted %d' % (grew, count))
   r.ok('resend', 'both stations still connected', a.alive(timeout) and b.alive(timeout))


def case_catchup(ctx):
   """A station that comes up in the middle of a contest fetches the server's log
   on the sync port. From outside the server that is: what a late joiner is and
   is not told on connect, and that the download is the header frame and one
   framed row per QSO, in arrival order, every row verifying, the same twice,
   and (with --launch) the same after the server is killed and restarted."""
   r = ctx.report
   timeout = ctx.args.timeout
   count = ctx.args.burst
   a = ctx.probe('A', 1)
   a.settle(0.5)

   ours = [ctx.row('K1CU%d' % (i % 10), rcvd_name='Zoë %d' % i) for i in range(count)]
   a.send(b''.join(ctx.msg(NET_WIRE_QSO_ID, 1, v) for v in ours))
   r.add('catchup', 'QSOs logged while the joiner is away', 'INFO', str(count))
   guid_at = ctx.codec.index('guid')
   keys = [v[guid_at] for v in ours]
   view = ctx.wait_rows(count, timeout + 6)
   if view is None:
      r.add('catchup', 'the server log can be downloaded on the sync port', 'FAIL', 'no download')
      return

   c = ctx.probe('C', 3)
   admitted = c.settle(1.0)
   announced = [d for found_id, d in admitted if found_id == NET_LOGCOMPARE_ID]
   view = ctx.view()
   if view is None:
      r.add('catchup', 'the server log can be downloaded on the sync port', 'FAIL', 'no download')
      return
   r.add('catchup', 'the server log can be downloaded on the sync port', 'PASS',
         '%d rows' % len(view.rows))
   r.ok('catchup', 'the header frame is {contest, rows, schema} and agrees with the rows',
        view.header.get('rows') == len(view.rows) and view.header.get('schema') == 5
        and set(view.header.keys()) == {'contest', 'rows', 'schema'},
        'header %s' % json.dumps(view.header, sort_keys=True))
   r.ok('catchup', 'the header names the contest the first station announced',
        view.header.get('contest') == ctx.args.contest,
        '"%s"' % view.header.get('contest'))
   if announced:
      rows_announced = struct.unpack('<HIIIIB', announced[0])[3]
      r.ok('catchup', 'LOGCOMPARE announced the ROW COUNT of the log',
           rows_announced == len(view.rows),
           'announced %d, downloaded %d' % (rows_announced, len(view.rows)))
   else:
      r.add('catchup', 'LOGCOMPARE announced the ROW COUNT of the log', 'FAIL', 'no LOGCOMPARE on admit')
   r.ok('catchup', 'every row checksum verifies', view.problem == '', view.problem)
   got_guids = view.guids(ctx.codec)
   missing = [k for k in keys if k not in got_guids]
   r.ok('catchup', 'every QSO logged meanwhile is in the download', not missing,
        '%d of %d present' % (count - len(missing), count))
   r.ok('catchup', 'and each is the row that was sent', view.rows[-count:] == ours)
   positions = [got_guids.index(k) if k in got_guids else -1 for k in keys]
   r.ok('catchup', 'in the order they arrived',
        positions == sorted(positions) and -1 not in positions)
   r.ok('catchup', 'no guid appears twice in the download',
        len(set(g for g in got_guids if g)) == len([g for g in got_guids if g]))
   r.ok('catchup', 'the joiner is not sent the earlier QSOs on admit (so it must fetch)',
        c.take(NET_WIRE_QSO_ID, 1.0) is None)
   latest = c.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.ok('catchup', 'it is told what contest the others announced',
        latest is not None and parse_hello(latest)[3] == ctx.args.contest,
        parse_hello(latest)[3] if latest else c.why_dead())
   again = ctx.view()
   r.ok('catchup', 'a second download is the same bytes',
        again is not None and again.raw == view.raw)

   edited = ctx.row('K1CUEDIT', int(keys[0], 16))
   a.send(ctx.msg(NET_WIRE_EDIT_ID, 1, edited))
   a.take(NET_SERVERMESSAGE_ID, timeout, SM_RECEIVED_UPDATED_QSO)
   time.sleep(0.5)
   edit_view = ctx.view()
   if edit_view is None:
      r.add('catchup', 'an edit shows in the download, in place', 'SKIP', 'no download')
   else:
      p0 = positions[0]
      r.ok('catchup', "the server's copy of an edited QSO is the edited row, in place",
           len(edit_view.rows) == len(view.rows) and edit_view.rows[p0] == edited)
   r.ok('catchup', 'both stations still connected', a.alive(timeout) and c.alive(timeout))

   # THE RESTART: a server killed and started again holds every row it held.
   if ctx.launcher is None:
      r.add('catchup', 'after a kill and restart the download is the same bytes', 'SKIP',
            'needs --launch')
      return
   ctx.close_all()
   ctx.launcher.restart()
   restarted = ctx.view()
   r.ok('catchup', 'after a kill and restart the download is the same bytes',
        restarted is not None and edit_view is not None and restarted.raw == edit_view.raw,
        'rows %s' % (len(restarted.rows) if restarted else 'unreadable'))
   if restarted is not None:
      r.ok('catchup', 'and the contest survives the restart',
           restarted.header.get('contest') == ctx.args.contest,
           '"%s"' % restarted.header.get('contest'))
   # A catch-up is OPENED by a connection: the joiner on the restarted server.
   late = ctx.probe('C', 3)
   admitted = late.settle(1.0)
   announced = [d for found_id, d in admitted if found_id == NET_LOGCOMPARE_ID]
   if announced and restarted is not None:
      r.ok('catchup', 'LOGCOMPARE after the restart still counts the rows',
           struct.unpack('<HIIIIB', announced[0])[3] == len(restarted.rows))


def count_acks(probe, wanted, wait):
   """Wait up to `wait` seconds for `wanted` acknowledgements (8300) and return
   how many have arrived."""
   def acks():
      return sum(1 for found_id, data in probe.inbox
                 if found_id == NET_SERVERMESSAGE_ID and
                 server_message_fields(data)[0] == SM_RECEIVED_UPDATED_QSO)
   deadline = time.time() + wait
   while time.time() < deadline and not probe.eof and probe.bad_id is None:
      if acks() >= wanted:
         break
      probe.pump(0.1)
   return acks()


def forget_acks(probe):
   probe.inbox = [item for item in probe.inbox
                  if not (item[0] == NET_SERVERMESSAGE_ID and
                          server_message_fields(item[1])[0] == SM_RECEIVED_UPDATED_QSO)]


def restock_round(ctx, a, b, count, tag):
   """One restock of `count` QSOs: a station whose log holds QSOs the server
   lacks sends them all as OFFLINE in one write. Every one is acknowledged,
   nobody else is sent any, the server's log grows by exactly those rows, once
   each and in order, and sending the same set again adds nothing."""
   r = ctx.report
   timeout = ctx.args.timeout
   wait = timeout + 6 + count * 0.05
   before = ctx.rows()
   ours = [ctx.row('K1%s%d' % (tag, i % 10)) for i in range(count)]
   blob = b''.join(ctx.msg(NET_WIRE_OFFLINE_ID, 1, v) for v in ours)
   forget_acks(a)
   b.drop_inbox(NET_WIRE_QSO_ID, NET_WIRE_OFFLINE_ID)

   started = time.time()
   a.send(blob)                       # ONE write: the server sees a coalesced read
   acks = count_acks(a, count, wait)
   took = time.time() - started
   r.add(tag, 'bytes written in one send', 'INFO', '%d (%d QSOs)' % (len(blob), count))
   r.ok(tag, 'every OFFLINE row is acknowledged (8300)', acks == count, '%d of %d' % (acks, count))
   r.add(tag, 'timing', 'INFO', '%.2f s (%.1f ms each)' % (took, 1000.0 * took / max(count, 1)))

   b.pump(1.0)
   relayed = sum(1 for found_id, _ in b.inbox if found_id in (NET_WIRE_QSO_ID, NET_WIRE_OFFLINE_ID))
   r.ok(tag, 'a second connected station receives NONE of them (not relayed)',
        relayed == 0, 'B received %d' % relayed)

   after = ctx.wait_rows((len(before) if before is not None else 0) + count, wait)
   if before is None or after is None:
      r.add(tag, 'the download holds exactly the pushed rows', 'SKIP', 'log not readable')
   else:
      added = after.rows[len(before):]
      r.ok(tag, 'the server log grew by exactly %d rows' % count, len(added) == count,
           'grew by %d' % len(added))
      r.ok(tag, 'the new rows are what was sent, in order', added == ours,
           '%d of %d identical' % (sum(1 for x, y in zip(added, ours) if x == y), count))
      guids = [g for g in after.guids(ctx.codec) if g]
      r.ok(tag, 'no guid appears twice in the log', len(guids) == len(set(guids)))

   held = None if after is None else after.rows
   forget_acks(a)
   a.send(blob)
   acks = count_acks(a, count, wait)
   r.ok(tag, 'the same set sent again is still acknowledged', acks == count,
        '%d of %d' % (acks, count))
   time.sleep(0.5)
   grew = log_growth(held, ctx.rows())
   if grew is not None:
      r.ok(tag, 'the same set sent again adds none', grew == 0, 'grew by %d' % grew)
   b.pump(0.5)
   relayed = sum(1 for found_id, _ in b.inbox if found_id in (NET_WIRE_QSO_ID, NET_WIRE_OFFLINE_ID))
   r.ok(tag, 'and still relays nothing', relayed == 0, 'B received %d' % relayed)
   r.ok(tag, 'both stations still connected', a.alive(timeout) and b.alive(timeout))


def case_restock(ctx):
   """A server that lost its log is restocked by a station that still has the
   QSOs: it sends exactly what the server lacks as OFFLINE rows. Both servers
   store an OFFLINE row, acknowledge it, do not relay it, and do not store a guid
   they already hold. --burst rows in the first round, --restock-big in a
   second (0 skips it)."""
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   restock_round(ctx, a, b, ctx.args.burst, 'restock')
   if ctx.args.restock_big > 0:
      restock_round(ctx, a, b, ctx.args.restock_big, 'restockbig')


def case_badcrc(ctx):
   """A row the server cannot accept is refused: not stored, not relayed, and
   THE LINK STAYS UP (the frame was whole, so framing is intact). Each refusal is
   followed by a good row on the same connection, which must arrive: that proves
   the bad frame was consumed."""
   r = ctx.report
   timeout = ctx.args.timeout
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   before = ctx.rows()
   codec = ctx.codec

   def refused(label, frame):
      b.drop_inbox(NET_WIRE_QSO_ID)
      a.send(frame)
      good = ctx.row('K1GOOD')
      a.send(ctx.msg(NET_WIRE_QSO_ID, 1, good))
      got = b.take(NET_WIRE_QSO_ID, timeout)
      ok, detail = relayed_equals(ctx, got, good, 1)
      r.ok('badcrc', '%s: not relayed, and the good row behind it is' % label, ok, detail)
      extra = b.take(NET_WIRE_QSO_ID, 0.3)
      r.ok('badcrc', '%s: nothing else was relayed' % label, extra is None)
      r.ok('badcrc', '%s: the link stays up' % label, a.alive(timeout))
      return good

   goods = []
   values = ctx.row('K1BAD')
   text = codec.encode(values)
   wrong = json.loads(text)
   wrong['k'] = '%08X' % ((int(wrong['k'], 16) + 1) & 0xFFFFFFFF)
   goods.append(refused('a wrong checksum', build_wire(NET_WIRE_QSO_ID, 1, json.dumps(wrong, separators=(',', ':')))))
   changed = json.loads(text)
   changed['callsign'] = 'K1ALTERED'
   goods.append(refused('a field changed after the checksum', build_wire(NET_WIRE_QSO_ID, 1, json.dumps(changed, separators=(',', ':')))))
   missing = json.loads(text)
   del missing['k']
   goods.append(refused('no checksum', build_wire(NET_WIRE_QSO_ID, 1, json.dumps(missing, separators=(',', ':')))))
   goods.append(refused('JSON that is not JSON', build_wire(NET_WIRE_QSO_ID, 1, '{"guid": oops')))
   goods.append(refused('JSON that is not an object', build_wire(NET_WIRE_QSO_ID, 1, '[1,2,3]')))
   numeric = json.loads(text)
   numeric['freq_tx_hz'] = '0x1F'
   goods.append(refused('a numeric column holding 0x1F', build_wire(NET_WIRE_QSO_ID, 1, json.dumps(numeric, separators=(',', ':')))))
   decimal = json.loads(text)
   decimal['freq_tx_hz'] = 14.025
   goods.append(refused('a numeric column holding 14.025', build_wire(NET_WIRE_QSO_ID, 1, json.dumps(decimal, separators=(',', ':')))))
   goods.append(refused('a payload that is not UTF-8',
                        WIRE_HEADER.pack(NET_WIRE_QSO_ID, 4) + bytes([1, 0xFF, 0xFE, 0xFD])))
   goods.append(refused('a payload of the sender byte alone',
                        WIRE_HEADER.pack(NET_WIRE_QSO_ID, 1) + bytes([1])))
   goods.append(refused('an EDIT with a wrong checksum', build_wire(NET_WIRE_EDIT_ID, 1, json.dumps(wrong, separators=(',', ':')))))
   # A bad row inside an OFFLINE run: the good ones around it are acknowledged,
   # the bad one is not (it was refused before it reached the store).
   forget_acks(a)
   run = [ctx.row('K1RUN1'), None, ctx.row('K1RUN2')]
   blob = (ctx.msg(NET_WIRE_OFFLINE_ID, 1, run[0]) +
           build_wire(NET_WIRE_OFFLINE_ID, 1, json.dumps(wrong, separators=(',', ':'))) +
           ctx.msg(NET_WIRE_OFFLINE_ID, 1, run[2]))
   a.send(blob)
   acks = count_acks(a, 3, timeout + 1)
   r.add('badcrc', 'an OFFLINE run of good, bad, good: acknowledgements', 'INFO', '%d' % acks)
   time.sleep(0.5)
   after = ctx.rows()
   if before is not None and after is not None:
      stored = after[len(before):]
      expected = goods + [run[0], run[2]]
      r.ok('badcrc', 'the log holds exactly the good rows (%d), none of the bad' % len(expected),
           stored == expected, 'grew by %d' % len(stored))


def case_big(ctx):
   """A legal row near the 60000-byte cap travels whole; a payload exactly at the
   cap is accepted; a declaration over the cap disconnects the sender, which is
   then not trusted to be in step (the bytes behind it cannot be framed)."""
   r = ctx.report
   timeout = ctx.args.timeout
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   before = ctx.rows()

   n = ctx.next_n()
   big = ctx.row('K1BIG', n, notes='x' * 58000)
   msg = ctx.msg(NET_WIRE_QSO_ID, 1, big)
   r.add('big', 'size of the big message', 'INFO', '%d bytes' % len(msg))
   a.send(msg)
   got = b.take(NET_WIRE_QSO_ID, timeout + 5)
   ok, detail = relayed_equals(ctx, got, big, 1)
   r.ok('big', 'a row of about 58000 bytes is relayed whole', ok, detail)

   # Exactly the cap: payload (sender byte + JSON) = 60000.
   n = ctx.next_n()
   size = 58000
   for _ in range(3):
      exact = ctx.row('K1CAP', n, notes='y' * size)
      payload = 1 + len(ctx.codec.encode(exact).encode('utf-8'))
      if payload == MAX_WIRE_PAYLOAD:
         break
      size += MAX_WIRE_PAYLOAD - payload
   msg = ctx.msg(NET_WIRE_QSO_ID, 1, exact)
   r.add('big', 'payload of the at-cap message', 'INFO', '%d' % (len(msg) - 6))
   a.send(msg)
   got = b.take(NET_WIRE_QSO_ID, timeout + 5)
   ok, detail = relayed_equals(ctx, got, exact, 1)
   r.ok('big', 'a payload of exactly %d bytes is accepted and relayed' % MAX_WIRE_PAYLOAD, ok, detail)
   after = ctx.wait_rows((len(before) if before is not None else 0) + 2, 5)
   if before is not None and after is not None:
      r.ok('big', 'both are stored whole', after.rows[len(before):] == [big, exact],
           'grew by %d' % (len(after.rows) - len(before)))
      big_frames = [len(f.encode('utf-8')) for f in after.frames[-2:]]
      r.ok('big', 'and the sync stream carries them as frames of the same size',
           all(s > 57000 for s in big_frames))
      r.add('big', 'sync frame sizes (the server spells the JSON its own way)', 'INFO', '%s' % big_frames)
   r.ok('big', 'A is still connected', a.alive(timeout))

   # Over the cap, declared in the header alone: decided from six bytes.
   b.drop_inbox(NET_WIRE_QSO_ID)
   c = ctx.probe('C', 3)
   c.settle(0.3)
   c.send(WIRE_HEADER.pack(NET_WIRE_QSO_ID, MAX_WIRE_PAYLOAD + 1))
   r.ok('big', 'a payload declared as %d (over the cap): the sender is disconnected' % (MAX_WIRE_PAYLOAD + 1),
        wait_closed(c, timeout + 2))
   r.ok('big', 'and the other stations are untouched', b.alive(timeout))
   d = ctx.probe('D', 4)
   d.settle(0.3)
   d.send(WIRE_HEADER.pack(NET_WIRE_EDIT_ID, 0xFFFFFFFF))
   r.ok('big', 'a payload declared as 4 GB: the sender is disconnected',
        wait_closed(d, timeout + 2))
   r.ok('big', 'nothing was relayed', b.take(NET_WIRE_QSO_ID, 0.3) is None)


def case_legacy(ctx):
   """Protocol 4's fixed-size QSO frames (1040, 1050, 1055) are unknown ids now:
   logged, and the connection is dropped (the bytes cannot be framed)."""
   r = ctx.report
   timeout = ctx.args.timeout
   b = ctx.probe('B', 2)
   b.settle(0.5)
   for number, (old_id, name) in enumerate(sorted(RETIRED_IDS.items())):
      a = ctx.probe('A%d' % number, 1 + number)
      a.settle(0.3)
      a.send(struct.pack('<H', old_id) + b'\x00' * (RETIRED_QSO_SIZE - 2))
      r.ok('legacy', 'an old %s frame (id %d): connection closed' % (name, old_id),
           wait_closed(a, timeout + 2))
      r.ok('legacy', 'and it was not relayed', b.take(NET_WIRE_QSO_ID, 0.3) is None and
           not any(i == old_id for i, _ in b.inbox))
   r.ok('legacy', 'the other station is untouched', b.alive(timeout))
   # An id nobody knows at all is the same.
   z = ctx.probe('Z', 9)
   z.settle(0.3)
   z.send(struct.pack('<H', 4242) + b'\x00' * 40)
   r.ok('legacy', 'an unknown id (4242): connection closed', wait_closed(z, timeout + 2))


def case_offline_ack(ctx):
   """An OFFLINE run is acknowledged only after it is durable: the moment the
   FIRST acknowledgement arrives the server process is killed (no shutdown
   code), restarted, and every acknowledged row must still be there."""
   r = ctx.report
   timeout = ctx.args.timeout
   if ctx.launcher is None:
      r.add('offline-ack', 'acknowledged rows survive a kill', 'SKIP', 'needs --launch')
      return
   count = ctx.args.burst
   a = ctx.probe('A', 1)
   a.settle(0.5)
   rows = [ctx.row('K1OFF%d' % (i % 10), rcvd_name='Zoë') for i in range(count)]
   a.send(b''.join(ctx.msg(NET_WIRE_OFFLINE_ID, 1, v) for v in rows))
   first = a.take(NET_SERVERMESSAGE_ID, timeout + 5, SM_RECEIVED_UPDATED_QSO)
   r.ok('offline-ack', 'the first acknowledgement arrives', first is not None)
   # Kill at once: everything the server has acknowledged must already be on disk.
   ctx.launcher.kill()
   acks = count_acks(a, count, 0.3)
   r.add('offline-ack', 'timing', 'INFO',
         'acknowledgements seen before the kill took effect: %d of %d' % (acks, count))
   ctx.close_all()
   ctx.launcher.start()
   view = ctx.view()
   if view is None:
      r.add('offline-ack', 'acknowledged rows survive a kill', 'FAIL', 'no download')
      return
   # Every row of the run is acknowledged together after ONE commit, so the
   # first ack means all of them are durable.
   r.ok('offline-ack', 'after the kill and restart the log holds every row of the run',
        view.rows[-count:] == rows if len(view.rows) >= count else False,
        '%d rows held, %d sent' % (len(view.rows), count))
   r.ok('offline-ack', 'and every stored row verifies', view.problem == '', view.problem)
   # A run that is cut mid-write must leave nothing half-stored: send half of the
   # next run's last frame, kill, restart.
   b = ctx.probe('B', 1)
   b.settle(0.5)
   second = [ctx.row('K1CUT%d' % i) for i in range(5)]
   blob = b''.join(ctx.msg(NET_WIRE_OFFLINE_ID, 1, v) for v in second)
   b.send(blob[:-20])                 # the last frame is incomplete
   count_acks(b, 4, timeout)
   ctx.launcher.kill()
   ctx.close_all()
   ctx.launcher.start()
   after = ctx.view()
   if after is not None:
      r.add('offline-ack', 'a run cut mid-frame: rows stored after the restart', 'INFO',
            '%d of 4 whole frames' % (len(after.rows) - len(view.rows)))
      r.ok('offline-ack', 'and the cut frame is not stored', second[4] not in after.rows)


def newest_backup(workdir):
   found = [p for p in glob.glob(os.path.join(workdir, '*.tr4wsrv'))
            if os.path.basename(p).upper() != 'SERVERLOG.TR4WSRV']
   return sorted(found)


def case_clear(ctx):
   """Clear-all-logs copies the database to a dated backup FIRST, then clears;
   a new contest is accepted afterwards (the server forgot the old one)."""
   r = ctx.report
   timeout = ctx.args.timeout
   a = ctx.probe('A', 1, contest_id='OLD-CONTEST')
   b = ctx.probe('B', 2, contest_id='OLD-CONTEST')
   a.settle(0.5)
   b.settle(0.5)
   rows = [ctx.row('K1CLR%d' % i, clear_dupe_sheet='0') for i in range(3)]
   for v in rows:
      a.send(ctx.msg(NET_WIRE_QSO_ID, 1, v))
   b.count(NET_WIRE_QSO_ID, 3, timeout + 2)
   view = ctx.wait_rows(3, 5)
   r.ok('clear', 'three rows are held', view is not None and len(view.rows) >= 3)
   r.ok('clear', 'the server contest is the first one announced',
        view is not None and view.header.get('contest') == 'OLD-CONTEST')
   held = len(view.rows) if view is not None else 3

   # The two flag clears are rewrites of the held rows, relayed to the others.
   a.send(build_server_message(SM_CLEAR_DUPESHEET))
   got = b.take(NET_SERVERMESSAGE_ID, timeout, SM_CLEAR_DUPESHEET)
   r.add('clear', 'set-dupesheet is relayed to the other station', 'INFO',
         'relayed' if got else 'not relayed')
   time.sleep(0.5)
   flagged = ctx.view()
   if flagged is not None:
      i = ctx.codec.index('clear_dupe_sheet')
      r.ok('clear', 'set-dupesheet sets clear_dupe_sheet = 1 on every QSO row',
           all(row[i] == '1' for row in flagged.rows), '%s' % sorted(set(row[i] for row in flagged.rows)))
   a.send(build_server_message(SM_CLEAR_MULTSHEET))
   time.sleep(0.5)
   flagged = ctx.view()
   if flagged is not None:
      i = ctx.codec.index('clear_mult_sheet')
      r.ok('clear', 'clear-mults sets clear_mult_sheet = 1 on every QSO row',
           all(row[i] == '1' for row in flagged.rows))

   a.send(build_server_message(SM_CLEARALLLOGS))
   got = b.take(NET_SERVERMESSAGE_ID, timeout + 2, SM_CLEARALLLOGS)
   r.ok('clear', 'the other station is told the log was cleared', got is not None)
   time.sleep(0.5)
   cleared = ctx.view()
   r.ok('clear', 'the log is empty afterwards', cleared is not None and len(cleared.rows) == 0,
        '' if cleared is None else '%d rows' % len(cleared.rows))
   if ctx.launcher is not None:
      backups = newest_backup(ctx.launcher.workdir)
      r.ok('clear', 'a dated backup of the database exists beside it', len(backups) == 1,
           '%d file(s)' % len(backups))
      if backups:
         snap = read_database(backups[0])
         r.ok('clear', 'and it holds every row the log held before the clear',
              snap is not None and len(snap['rows']) == held,
              '%s rows' % (len(snap['rows']) if snap else 'unreadable'))
   else:
      r.add('clear', 'a dated backup of the database exists beside it', 'SKIP', 'needs --launch')

   # A new contest is then accepted: the HELLO names it, the next row is stored.
   a.send(build_hello(NET_PROTOCOL_VERSION, 1, 'netprobe', 'NEW-CONTEST'))
   time.sleep(0.5)
   fresh = ctx.row('K1NEWC')
   a.send(ctx.msg(NET_WIRE_QSO_ID, 1, fresh))
   got = b.take(NET_WIRE_QSO_ID, timeout)
   r.ok('clear', 'a row of the new contest is relayed', got is not None)
   time.sleep(0.5)
   final = ctx.view()
   if final is not None:
      r.ok('clear', 'and stored', final.rows == [fresh], '%d rows' % len(final.rows))
      r.ok('clear', 'and the server now holds the NEW contest',
           final.header.get('contest') == 'NEW-CONTEST', '"%s"' % final.header.get('contest'))


CASES = {
   'selftest': case_selftest,
   'connect': case_connect,
   'spot': case_spot,
   'qso': case_qso,
   'burst': case_burst,
   'edit': case_edit,
   'disc': case_disc,
   'dup': case_dup,
   'serial': case_serial,
   'time': case_time,
   'hello': case_hello,
   'resend': case_resend,
   'catchup': case_catchup,
   'restock': case_restock,
   'badcrc': case_badcrc,
   'big': case_big,
   'legacy': case_legacy,
   'offline-ack': case_offline_ack,
   'clear': case_clear,
}

# What `all` runs: every case that talks to a server.
ALL_CASES = [name for name in CASES if name != 'selftest']


def save_artifacts(args, report, codec, launcher, name):
   """With --launch: the sync stream and the database as the case left them,
   for compare.py. The database is read after the server is stopped, so its
   write-ahead log is folded in."""
   out = launcher.workdir
   raw, why = fetch_sync_stream(args.host, args.port, args.password, args.sync_timeout,
                                args.sync_bytes)
   if raw is not None:
      with open(os.path.join(out, 'final-sync.bin'), 'wb') as f:
         f.write(raw)
   else:
      report.add(name, 'final sync stream', 'INFO', why)
   launcher.kill()
   snapshot = read_database(launcher.db_path)
   if snapshot is None:
      report.add(name, 'final database', 'INFO', 'no database file')
      return
   with open(os.path.join(out, 'final-db.json'), 'w', encoding='utf-8') as f:
      json.dump(snapshot, f, ensure_ascii=False)


def run_case(name, args, report, codec):
   launcher = None
   if args.launch:
      workdir = os.path.join(args.workdir, name)
      if os.path.isdir(workdir):
         shutil.rmtree(workdir)
      launcher = Launcher(args.launch, args.server, workdir, args.port,
                          lockout=(name == 'serial'))
   ctx = Context(args, report, codec, launcher)
   try:
      if launcher is not None:
         launcher.start()
      CASES[name](ctx)
      if launcher is not None and name != 'selftest':
         ctx.close_all()
         save_artifacts(args, report, codec, launcher, name)
   except ProbeError as err:
      report.error(name, str(err))
   except (OSError, socket.timeout) as err:
      report.error(name, 'socket: %s' % err)
   finally:
      ctx.close_all()
      if launcher is not None:
         launcher.kill()


def parse_args(argv):
   p = argparse.ArgumentParser(description='Speak TR4W multi-op protocol 5 at a server.')
   p.add_argument('--case', default='all',
                  help='one of %s, or all (default)' % ', '.join(CASES))
   p.add_argument('--host', default='127.0.0.1')
   p.add_argument('--port', type=int, default=1061,
                  help='main port; the sync port is PORT + 1')
   p.add_argument('--password', default='TR4WSERVER')
   p.add_argument('--label', default='server',
                  help='name printed on every RESULT line')
   p.add_argument('--timeout', type=float, default=3.0,
                  help='seconds to wait for any one message')
   p.add_argument('--sync-timeout', type=float, default=20.0,
                  help='seconds to wait for the sync-port download')
   p.add_argument('--sync-bytes', type=int, default=PASSWORD_BYTES,
                  help='bytes written as the password on the sync port')
   p.add_argument('--burst', type=int, default=30,
                  help='QSOs in the burst, resend, catchup, offline-ack cases and the first restock round')
   p.add_argument('--restock-big', type=int, default=0,
                  help='QSOs in the second, large round of the restock case (default 0 = skip; '
                       'the in-tree server takes about 45 ms per OFFLINE row)')
   p.add_argument('--contest', default='ARRL-DX-CW',
                  help='the contest id the probes announce in their HELLO')
   p.add_argument('--seed-ids', type=int, default=None,
                  help='first row number the run hands out (default: the clock, so '
                       'a run is unique; give a number for a repeatable run)')
   p.add_argument('--columns', default=None,
                  help='columns.json (default tr4w/test/wire/columns.json)')
   p.add_argument('--launch', choices=('pascal', 'python'), default=None,
                  help='start this kind of server as a child process, one fresh '
                       'directory per case, and stop it after')
   p.add_argument('--server', default=None,
                  help='with --launch: tr4wserver.exe (pascal) or tr4wserver.py (python)')
   p.add_argument('--workdir', default=None,
                  help='with --launch: the directory the case directories go in')
   return p.parse_args(argv)


def main(argv):
   args = parse_args(argv)
   names = ALL_CASES if args.case == 'all' else [args.case]
   for name in names:
      if name not in CASES:
         print('unknown case %r; choose from %s' % (name, ', '.join(CASES)))
         return 2
   if args.launch and not (args.server and args.workdir):
      print('--launch needs --server and --workdir')
      return 2
   if args.seed_ids is not None:
      _NEXT_ID[0] = args.seed_ids
   codec = load_codec(args.columns)
   report = Report(args.label)
   for name in names:
      run_case(name, args, report, codec)
      if name != 'selftest':
         time.sleep(1.0)              # let the server notice the closed sockets
   print('SUMMARY %s: %d failed, %d could not run' %
         (args.label, report.failed, report.errored), flush=True)
   if report.errored:
      return 2
   return 1 if report.failed else 0


if __name__ == '__main__':
   sys.exit(main(sys.argv[1:]))
