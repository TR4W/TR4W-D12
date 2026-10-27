"""netprobe -- speak the TR4W multi-op V1 wire protocol at a server.

Standard library only. Indentation is three spaces, as everywhere in this tree.

What it is for: the in-tree client and tr4wserver agree with each other because
both compile VC.pas, so a size change in VC.pas (DX spot, 98 -> 106 bytes) breaks
every other implementation of the protocol and no test here notices. This tool
is an INDEPENDENT second implementation of the client side: its own size table,
its own record builders, nothing shared with the Pascal. Point it at any server
and it says which of the V1 behaviours that server actually has.

It prints one line per check:

   RESULT <label> <case> <check>: PASS|FAIL|INFO|SKIP <detail>

and exits 0 when no check FAILed, 1 when one did, 2 when a case could not run
(connection refused, wrong password, timeout in the handshake).

Every wait has a deadline. Nothing here blocks for ever.

See README.md in this folder for the cases and for what each one proves.
"""

import argparse
import select
import socket
import struct
import sys
import time

# --- The wire, as this tool understands it ---------------------------------
# These are DELIBERATELY typed in again rather than imported from anywhere: a
# probe that shared the server's table could not find a wrong entry in it.

NET_MESSAGESTATE_ID = 1000
NET_LOGCOMPARE_ID = 1010
NET_INTERCOMMESSAGE_ID = 1020
NET_NETWORKDXSPOT_ID = 1030
NET_QSOINFO_ID = 1040
NET_EDITEDQSO_ID = 1050
NET_OFFLINEQSO_ID = 1055
NET_TAKESERVERQSO_ID = 1060
NET_TIMESYN_ID = 1070
NET_PARAMETER_ID = 1080
NET_STATIONSTATUS_ID = 1090
NET_CLIENTSTATUS_ID = 1110
NET_SPOTVIANETWORK_ID = 1120
NET_COMPUTERID_ID = 1130
NET_SERVERMESSAGE_ID = 1140
NET_HELLO_ID = 1150

NET_PROTOCOL_VERSION = 2        # network protocol 2: the first message is a HELLO
HELLO_VERSION_CHARS = 16
HELLO_CONTEST_CHARS = 48
HELLO_SIZE = 2 + 2 + 1 + 1 + HELLO_VERSION_CHARS + HELLO_CONTEST_CHARS     # 70

SM_CLEARALLLOGS = 8230
SM_SERVERLOG_CHANGED = 8250
SM_DISCONECT_CLIENT = 8260
SM_GETSTATUS = 8270
SM_RECEIVED_UPDATED_QSO = 8300
SM_SERIAL_NUMBER_CHANGED = 8310
SM_COMPUTERID_IN_USE = 8320
SM_PROTOCOL_MISMATCH = 8330

SNT_FREE = 0
SNT_RESERVED = 1

CONTEST_EXCHANGE_SIZE = 376     # SizeOf(ContestExchange); pinned in the Pascal tests
CE_BAND = 6
CE_MODE = 7
CE_QSOID1 = 8
CE_QSOID2 = 12
CE_FREQUENCY = 16
CE_CALLSIGN = 44                # string[13]: a length byte and 13 characters
CE_NUMBER_SENT = 204
CE_CONTEST = 265                # one byte, a legacy contest handle

SPOT_RECORD_SIZE = 104          # SizeOf(TSpotRecord) on i386-win32

MESSAGE_SIZE = {
   NET_MESSAGESTATE_ID: 64,
   NET_LOGCOMPARE_ID: 19,
   NET_INTERCOMMESSAGE_ID: 84,
   NET_NETWORKDXSPOT_ID: 2 + SPOT_RECORD_SIZE,
   NET_QSOINFO_ID: 2 + CONTEST_EXCHANGE_SIZE + 4 + 1 + 1,
   NET_EDITEDQSO_ID: 2 + CONTEST_EXCHANGE_SIZE + 4 + 1 + 1,
   NET_OFFLINEQSO_ID: 2 + CONTEST_EXCHANGE_SIZE + 4 + 1 + 1,
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
   1030: 'DXSPOT', 1040: 'QSOINFO', 1050: 'EDITEDQSO', 1055: 'OFFLINEQSO',
   1060: 'TAKESERVERQSO', 1070: 'TIMESYN', 1080: 'PARAMETER',
   1090: 'STATIONSTATUS', 1110: 'CLIENTSTATUS', 1120: 'SPOTVIANETWORK',
   1130: 'COMPUTERID', 1140: 'SERVERMESSAGE', 1150: 'HELLO',
}

PASSWORD_BYTES = 10
BANNER_OK = b'TR4W'
BANNER_REFUSED = b'PASS'


class ProbeError(Exception):
   """The case could not run at all (as opposed to a check that failed)."""


def password_on_wire(text):
   """Ten bytes, NUL padded, which is what a TR4W client writes."""
   raw = text.encode('ascii', 'replace')[:PASSWORD_BYTES]
   return raw + b'\x00' * (PASSWORD_BYTES - len(raw))


# --- Record builders --------------------------------------------------------

def build_exchange(call, id1, id2, band=3, mode=0, freq=14025000,
                   contest=1, number_sent=1):
   """A 376-byte ContestExchange with only the fields a server reads set."""
   rec = bytearray(CONTEST_EXCHANGE_SIZE)
   rec[CE_BAND] = band
   rec[CE_MODE] = mode
   struct.pack_into('<II', rec, CE_QSOID1, id1, id2)
   struct.pack_into('<i', rec, CE_FREQUENCY, freq)
   text = call.encode('ascii')[:13]
   rec[CE_CALLSIGN] = len(text)
   rec[CE_CALLSIGN + 1:CE_CALLSIGN + 1 + len(text)] = text
   struct.pack_into('<I', rec, CE_NUMBER_SENT, number_sent)
   rec[CE_CONTEST] = contest
   return bytes(rec)


def exchange_call(rec):
   length = rec[CE_CALLSIGN]
   return rec[CE_CALLSIGN + 1:CE_CALLSIGN + 1 + length].decode('ascii', 'replace')


def build_qso(msg_id, exchange, computer_id, sender=0):
   """TNetQSOInformation: id, ContestExchange, a Cardinal that tells one run
   of a station from another, then qiSenderID (the sending station's ordinal
   1..26, network protocol 2) and one reserved byte."""
   return struct.pack('<H', msg_id) + exchange + struct.pack('<IBB', computer_id, sender, 0)


def build_hello(protocol, ordinal, version, contest_id):
   """THelloMessage (70 bytes): id, protocol, computer id (0 = the server),
   reserved, 16 bytes of program version and 48 bytes of contest id, each NUL
   padded."""
   return struct.pack('<HHBB16s48s', NET_HELLO_ID, protocol, ordinal, 0,
                      version.encode('ascii'), contest_id.encode('ascii'))


def parse_hello(msg):
   """(protocol, computer id, version, contest id) of a 70-byte HELLO."""
   _id, protocol, ordinal, _reserved, version, contest = struct.unpack('<HHBB16s48s', msg)
   return (protocol, ordinal,
           version.split(b'\x00', 1)[0].decode('ascii'),
           contest.split(b'\x00', 1)[0].decode('ascii'))


def build_spot(call='K1ABC', freq_hz=14025000):
   """TNetDXSpot: id, then a TSpotRecord of SPOT_RECORD_SIZE bytes."""
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
   """TNetTimeSync: id, SYSTEMTIME (eight Words), two reserved bytes."""
   now = time.gmtime()
   systemtime = struct.pack('<8H', now.tm_year, now.tm_mon, (now.tm_wday + 1) % 7,
                            now.tm_mday, now.tm_hour, now.tm_min, now.tm_sec, 0)
   return struct.pack('<H', NET_TIMESYN_ID) + systemtime + b'\x00\x00'


def build_server_message(message, param=0):
   return struct.pack('<HHi', NET_SERVERMESSAGE_ID, message, param)


def build_computer_id(ordinal):
   return struct.pack('<HBB', NET_COMPUTERID_ID, ordinal, 0)


def build_client_status(telnet):
   return struct.pack('<HB', NET_CLIENTSTATUS_ID, 1 if telnet else 0)


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
      """Network protocol 2: the first message is a HELLO, and it carries the
      computer id (and the contest) that COMPUTERID used to."""
      self.send(build_hello(NET_PROTOCOL_VERSION, self.ordinal, 'netprobe',
                            self.contest_id))

   def claim_id_v1(self):
      """What a 4.x station sends first. A protocol 2 server refuses it."""
      self.send(build_computer_id(self.ordinal))

   def pump(self, wait):
      """Read whatever arrives within `wait` seconds and frame it."""
      if self.eof:
         return
      ready = select.select([self.sock], [], [], wait)[0]
      if not ready:
         return
      try:
         chunk = self.sock.recv(65536)
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
      """Is the link still usable? Sends an intercom line; every V1 server
      echoes that to the sender, so an answer proves the read path is alive."""
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


# --- The sync port: the only way to see the server's log from outside -------

def fetch_server_log(host, port, password, timeout, send_bytes):
   """Download the server's log on the sync port. Returns bytes, or None with
   a reason string. `send_bytes` is how many bytes to write as the password:
   10 is what the TR4W client writes."""
   try:
      sock = socket.create_connection((host, port + 1), timeout=timeout)
   except OSError as err:
      return None, 'sync port: %s' % err
   try:
      wire = password_on_wire(password)
      wire += b'\x00' * max(0, send_bytes - len(wire))
      sock.sendall(wire)
      deadline = time.time() + timeout
      head = b''
      while len(head) < 4 and time.time() < deadline:
         if select.select([sock], [], [], 0.25)[0]:
            chunk = sock.recv(4 - len(head))
            if not chunk:
               break
            head += chunk
      if len(head) < 4:
         return None, 'sync port sent no size within %.0f s' % timeout
      size = struct.unpack('<I', head)[0]
      if size > 64 * 1024 * 1024:
         return None, 'sync port size %d is not credible' % size
      body = b''
      while len(body) < size and time.time() < deadline:
         if select.select([sock], [], [], 0.25)[0]:
            chunk = sock.recv(min(65536, size - len(body)))
            if not chunk:
               break
            body += chunk
      if len(body) < size:
         return None, 'sync port sent %d of %d bytes' % (len(body), size)
      return body, ''
   except OSError as err:
      return None, 'sync port: %s' % err
   finally:
      sock.close()


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

   def error(self, case, detail):
      self.add(case, 'run', 'ERROR', detail)
      self.errored += 1


# --- The cases --------------------------------------------------------------

# THE QSO IDS A RUN HANDS OUT ARE UNIQUE ACROSS ITS CASES, AND ACROSS RUNS. A
# server now stores a QSO once whatever number of times it arrives (the pair
# ceQSOID1/ceQSOID2 is the key), so two cases that happened to reuse an id would
# find the second one "already held" and every check about it would fail for a
# reason that has nothing to do with the server. The seed is in milliseconds,
# so a run that starts seconds after another is past all the ids it used.
_NEXT_ID = [int(time.time() * 1000) & 0x7FFFFFF0]


class Context:
   def __init__(self, args, report):
      self.args = args
      self.report = report
      self.probes = []

   def probe(self, name, ordinal, claim=True, contest_id=None):
      p = Probe(name, self.args.host, self.args.port, self.args.password,
                ordinal, self.args.timeout, contest_id or self.args.contest)
      self.probes.append(p)
      if claim:
         p.claim_id()
      return p

   def next_ids(self):
      _NEXT_ID[0] += 2
      return _NEXT_ID[0], _NEXT_ID[0] + 1

   def close_all(self):
      for p in self.probes:
         p.close()
      self.probes = []

   def log_records(self):
      """The server log as a list of 376-byte records (header skipped), or
      None when the sync port could not be read."""
      data, why = fetch_server_log(self.args.host, self.args.port,
                                   self.args.password, self.args.sync_timeout,
                                   self.args.sync_bytes)
      if data is None:
         self.report.add('sync', 'log download', 'INFO', why)
         return None
      body = data[CONTEST_EXCHANGE_SIZE:]
      return [body[i:i + CONTEST_EXCHANGE_SIZE]
              for i in range(0, len(body) - CONTEST_EXCHANGE_SIZE + 1,
                             CONTEST_EXCHANGE_SIZE)]


def case_connect(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   admitted = a.settle(0.8)
   ids = [found_id for found_id, _ in admitted]
   r.add('connect', 'banner', 'PASS', 'TR4W')
   r.add('connect', 'LOGCOMPARE on admit',
         'PASS' if NET_LOGCOMPARE_ID in ids else 'FAIL',
         'sizes %s' % [len(d) for _, d in admitted if _ == NET_LOGCOMPARE_ID])
   r.add('connect', 'link alive', 'PASS' if a.alive(ctx.args.timeout) else 'FAIL',
         '' if not a.eof else a.why_dead())


def describe_receipt(got, sent, probe):
   """What a receive check saw, in words. A message of the right SIZE with the
   wrong bytes is reported as such: against a server that frames the spot at
   98 bytes, B receives 98 spot bytes plus an 8-byte DISCONNECT, which this
   probe's 106-byte table reads as one spot."""
   if got is None:
      return probe.why_dead()
   if got == sent:
      return '%d bytes, identical' % len(got)
   first = next((i for i in range(min(len(got), len(sent))) if got[i] != sent[i]), -1)
   return '%d bytes, differs from what was sent at byte %d' % (len(got), first)


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
   r.add('spot', 'B receives the spot', 'PASS' if got == spot else 'FAIL',
         describe_receipt(got, spot, b))
   alive = a.alive(ctx.args.timeout)
   r.add('spot', 'sender still connected', 'PASS' if alive else 'FAIL',
         '' if alive else a.why_dead())


def case_qso(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   before = ctx.log_records()
   id1, id2 = ctx.next_ids()
   exchange = build_exchange('K1QSO', id1, id2)
   msg = build_qso(NET_QSOINFO_ID, exchange, 1, a.ordinal)
   r.add('qso', 'size sent', 'INFO', '%d bytes' % len(msg))
   a.send(msg)
   got = b.take(NET_QSOINFO_ID, ctx.args.timeout)
   r.add('qso', 'B receives the QSO', 'PASS' if got == msg else 'FAIL',
         describe_receipt(got, msg, b))
   r.add('qso', 'sender not echoed',
         'PASS' if a.take(NET_QSOINFO_ID, 0.5) is None else 'FAIL')
   time.sleep(0.5)
   after = ctx.log_records()
   if before is None or after is None:
      r.add('qso', 'server log grew by one record', 'SKIP', 'log not readable')
   else:
      grew = len(after) - len(before)
      r.add('qso', 'server log grew by one record', 'PASS' if grew == 1 else 'FAIL',
            'records %d -> %d' % (len(before), len(after)))
      if after and grew == 1:
         r.add('qso', 'stored record is the one sent',
               'PASS' if after[-1] == exchange else 'FAIL')


def case_burst(ctx):
   r = ctx.report
   count = ctx.args.burst
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   before = ctx.log_records()
   blob = b''
   for _ in range(count):
      id1, id2 = ctx.next_ids()
      blob += build_qso(NET_QSOINFO_ID, build_exchange('K1BST', id1, id2), 1, a.ordinal)
   a.send(blob)                       # ONE write: the server sees a coalesced read
   r.add('burst', 'bytes written in one send', 'INFO', str(len(blob)))
   got = b.count(NET_QSOINFO_ID, count, ctx.args.timeout + 3)
   r.add('burst', 'B receives all %d' % count, 'PASS' if got == count else 'FAIL',
         'received %d%s' % (got, '' if b.bad_id is None else '; ' + b.why_dead()))
   time.sleep(0.5)
   after = ctx.log_records()
   if before is None or after is None:
      r.add('burst', 'server log grew by %d' % count, 'SKIP', 'log not readable')
   else:
      grew = len(after) - len(before)
      r.add('burst', 'server log grew by %d' % count,
            'PASS' if grew == count else 'FAIL', 'grew by %d' % grew)


def case_edit(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   id1, id2 = ctx.next_ids()
   original = build_exchange('K1OLD', id1, id2)
   a.send(build_qso(NET_QSOINFO_ID, original, 1, a.ordinal))
   b.take(NET_QSOINFO_ID, ctx.args.timeout)
   time.sleep(0.5)
   before = ctx.log_records()
   edited = build_exchange('K1NEW', id1, id2)
   msg = build_qso(NET_EDITEDQSO_ID, edited, 1, a.ordinal)
   a.send(msg)
   got = b.take(NET_EDITEDQSO_ID, ctx.args.timeout)
   r.add('edit', 'B receives the edit', 'PASS' if got == msg else 'FAIL',
         describe_receipt(got, msg, b))
   ack = a.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_RECEIVED_UPDATED_QSO)
   r.add('edit', 'sender gets the 8300 ACK', 'PASS' if ack else 'FAIL')
   time.sleep(0.5)
   after = ctx.log_records()
   if before is None or after is None:
      r.add('edit', 'server record rewritten in place', 'SKIP', 'log not readable')
   else:
      same_count = len(before) == len(after)
      changed = bool(after) and after[-1] == edited
      r.add('edit', 'server record rewritten in place',
            'PASS' if (same_count and changed) else 'FAIL',
            'records %d -> %d, last call %s' %
            (len(before), len(after), exchange_call(after[-1]) if after else '-'))


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
   r.add('disc', 'param is the ordinal 1..26 (the client range-checks this)',
         'PASS' if 1 <= param <= 26 else 'FAIL',
         'param %d%s' % (param, ' (an ASCII letter)' if 65 <= param <= 90 else ''))
   r.add('disc', 'param is B\'s ordinal (2)', 'PASS' if param == 2 else 'FAIL')


def case_dup(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   a.settle(0.5)
   c = ctx.probe('C', 1)              # a second station claiming ordinal 1
   refusal = c.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_COMPUTERID_IN_USE)
   r.add('dup', 'second claimant gets 8320', 'PASS' if refusal else 'FAIL',
         '' if refusal else 'accepted silently')
   r.add('dup', 'first holder not refused',
         'PASS' if a.take(NET_SERVERMESSAGE_ID, 0.5, SM_COMPUTERID_IN_USE) is None
         else 'FAIL')
   # Only CONNECTED stations count, and a station's own claim is not a clash.
   a.claim_id()
   r.add('dup', 'a station re-announcing its own id is not refused',
         'PASS' if a.take(NET_SERVERMESSAGE_ID, 0.5, SM_COMPUTERID_IN_USE) is None
         else 'FAIL')
   a.close()
   time.sleep(1.0)
   d = ctx.probe('D', 1)
   r.add('dup', 'the id of a station that has left can be taken again',
         'PASS' if d.take(NET_SERVERMESSAGE_ID, 1.0, SM_COMPUTERID_IN_USE) is None
         else 'FAIL')


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
   r.add('serial', 'B is told the same next serial',
         'PASS' if got and server_message_fields(got)[1] == n0 else 'FAIL',
         'got %s' % (server_message_fields(got)[1] if got else 'nothing'))
   a.send(build_server_message(SM_SERIAL_NUMBER_CHANGED, SNT_RESERVED))
   bumped = b.take(NET_SERVERMESSAGE_ID, ctx.args.timeout, SM_SERIAL_NUMBER_CHANGED)
   r.add('serial', 'B sees the next serial advance after A reserves',
         'PASS' if bumped and server_message_fields(bumped)[1] == n0 + 1 else 'FAIL',
         'got %s' % (server_message_fields(bumped)[1] if bumped else 'nothing'))


def case_time(ctx):
   r = ctx.report
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)
   a.send(build_timesync())
   got = b.take(NET_TIMESYN_ID, ctx.args.timeout)
   relayed = got is not None
   expect = ctx.args.expect_time
   if expect == 'any':
      r.add('time', 'TIMESYN relayed to B', 'INFO', 'relayed' if relayed else 'not relayed')
   else:
      r.add('time', 'TIMESYN %s as the server is configured' % expect,
            'PASS' if relayed == (expect == 'relay') else 'FAIL',
            'relayed' if relayed else 'not relayed')


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
   """Network protocol 2: the HELLO handshake, the contest id it carries and
   what a server does with a station that does not speak it."""
   r = ctx.report
   timeout = ctx.args.timeout

   # --- a good HELLO is admitted and answered ------------------------------
   a = ctx.probe('A', 1, contest_id='ARRL-DX-CW')
   server_hello = a.take(NET_HELLO_ID, timeout, where=hello_of(0))
   if server_hello is None:
      r.add('hello', 'server answers a HELLO with its own', 'FAIL', a.why_dead())
   else:
      protocol, _ordinal, version, contest = parse_hello(server_hello)
      r.add('hello', 'server answers a HELLO with its own', 'PASS',
            'protocol %d, version "%s"' % (protocol, version))
      r.add('hello', 'the server speaks protocol %d' % NET_PROTOCOL_VERSION,
            'PASS' if protocol == NET_PROTOCOL_VERSION else 'FAIL')
      r.add('hello', "the server's HELLO has a version text",
            'PASS' if version else 'FAIL')
      r.add('hello', "the server's HELLO names no contest",
            'PASS' if contest == '' else 'FAIL', '"%s"' % contest)
   alive = a.alive(timeout)
   r.add('hello', 'a good HELLO is admitted (link stays up)',
         'PASS' if alive else 'FAIL', '' if alive else a.why_dead())

   # --- the contest id reaches the others, byte for byte -------------------
   # A long id with blanks on purpose: 26 characters of the 48.
   long_id = 'REGION 1 FIELD DAY-RCC-SSB'
   b = ctx.probe('B', 2, contest_id=long_id)
   replay = b.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.add('hello', 'a station that joins is told what A announced',
         'PASS' if replay and parse_hello(replay)[3] == 'ARRL-DX-CW' else 'FAIL',
         parse_hello(replay)[3] if replay else b.why_dead())
   sent_by_b = build_hello(NET_PROTOCOL_VERSION, 2, 'netprobe', long_id)
   relayed = a.take(NET_HELLO_ID, timeout, where=hello_of(2))
   r.add('hello', 'A is told what B announced, byte for byte',
         'PASS' if relayed == sent_by_b else 'FAIL',
         '' if relayed == sent_by_b else
         (parse_hello(relayed)[3] if relayed else a.why_dead()))
   r.add('hello', 'a HELLO is not echoed to its sender',
         'PASS' if b.take(NET_HELLO_ID, 0.5, where=hello_of(2)) is None else 'FAIL')

   # --- a change of contest is a second HELLO, relayed ---------------------
   a.send(build_hello(NET_PROTOCOL_VERSION, 1, 'netprobe', 'CQ-WW-CW'))
   again = b.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.add('hello', 'a contest change is relayed',
         'PASS' if again and parse_hello(again)[3] == 'CQ-WW-CW' else 'FAIL',
         parse_hello(again)[3] if again else b.why_dead())
   c = ctx.probe('C', 3, contest_id='CQ-WW-SSB')
   latest = c.take(NET_HELLO_ID, timeout, where=hello_of(1))
   r.add('hello', 'a later joiner is told the LATEST contest, not the first',
         'PASS' if latest and parse_hello(latest)[3] == 'CQ-WW-CW' else 'FAIL',
         parse_hello(latest)[3] if latest else c.why_dead())
   other = c.take(NET_HELLO_ID, timeout, where=hello_of(2))
   r.add('hello', "and every other station's as well",
         'PASS' if other and parse_hello(other)[3] == long_id else 'FAIL')

   # --- the QSO still flows, and carries the sender --------------------------
   id1, id2 = ctx.next_ids()
   qso = build_qso(NET_QSOINFO_ID, build_exchange('K1HLO', id1, id2), 1, a.ordinal)
   a.send(qso)
   got = b.take(NET_QSOINFO_ID, timeout)
   r.add('hello', 'a QSO after the HELLO is relayed with its sender byte intact',
         'PASS' if got == qso else 'FAIL', describe_receipt(got, qso, b))

   # --- what is refused ----------------------------------------------------
   v1 = ctx.probe('V1', 4, claim=False)
   v1.claim_id_v1()
   r.add('hello', "no HELLO first (a 4.x station's COMPUTERID): connection closed",
         'PASS' if wait_closed(v1, timeout) else 'FAIL')
   # Only what the server sends on admission (the log-compare packet and, with
   # the lockout on, a serial number) may be in the inbox: no HELLO, no refusal
   # message a 4.x station could misread.
   stray = [MESSAGE_NAME.get(found_id, str(found_id)) for found_id, _data in v1.inbox
            if found_id not in (NET_LOGCOMPARE_ID, NET_SERVERMESSAGE_ID)]
   r.add('hello', 'and it was answered with no HELLO',
         'PASS' if not stray else 'FAIL', ', '.join(stray))

   q = ctx.probe('Q', 5, claim=False)
   id1, id2 = ctx.next_ids()
   q.send(build_qso(NET_QSOINFO_ID, build_exchange('K1NOH', id1, id2), 1, 5))
   r.add('hello', 'a QSO sent before any HELLO: connection closed',
         'PASS' if wait_closed(q, timeout) else 'FAIL')
   r.add('hello', 'and it was not relayed',
         'PASS' if a.take(NET_QSOINFO_ID, 0.5) is None else 'FAIL')

   for version, label in ((1, 'older'), (3, 'newer')):
      p = ctx.probe('P%d' % version, 6, claim=False)
      p.send(build_hello(version, 6, 'netprobe', 'X'))
      refusal = p.take(NET_SERVERMESSAGE_ID, timeout, SM_PROTOCOL_MISMATCH)
      r.add('hello', 'protocol %d (%s) is refused with 8330' % (version, label),
            'PASS' if refusal else 'FAIL', '' if refusal else p.why_dead())
      if refusal:
         param = server_message_fields(refusal)[1]
         r.add('hello', "8330 carries the server's protocol",
               'PASS' if param == NET_PROTOCOL_VERSION else 'FAIL', 'param %d' % param)
      r.add('hello', 'protocol %d: connection closed afterwards' % version,
            'PASS' if wait_closed(p, timeout) else 'FAIL')
   r.add('hello', 'a refused station is never announced to the others',
         'PASS' if a.take(NET_HELLO_ID, 0.5, where=hello_of(6)) is None else 'FAIL')

   dup = ctx.probe('D', 1, claim=False, contest_id='DUP-CONTEST')
   dup.send(build_hello(NET_PROTOCOL_VERSION, 1, 'netprobe', 'DUP-CONTEST'))
   refusal = dup.take(NET_SERVERMESSAGE_ID, timeout, SM_COMPUTERID_IN_USE)
   r.add('hello', "a HELLO claiming A's id is refused with 8320",
         'PASS' if refusal else 'FAIL', '' if refusal else 'accepted')
   r.add('hello', 'and its contest is not announced',
         'PASS' if b.take(NET_HELLO_ID, 0.5,
                          where=lambda d: parse_hello(d)[3] == 'DUP-CONTEST') is None
         else 'FAIL')

   for bad in (0, 27):
      p = ctx.probe('I%d' % bad, bad, claim=False)
      p.send(build_hello(NET_PROTOCOL_VERSION, bad, 'netprobe', 'X'))
      refusal = p.take(NET_SERVERMESSAGE_ID, timeout, SM_COMPUTERID_IN_USE)
      r.add('hello', 'computer id %d is refused with 8320' % bad,
            'PASS' if refusal else 'FAIL')


def log_growth(before, after):
   """Records added between two downloads of the server log, or None when
   either could not be read."""
   if before is None or after is None:
      return None
   return len(after) - len(before)


def case_resend(ctx):
   """A station that was disconnected sends again what it logged meanwhile, and
   one that crashed before it noted what it had sent sends some of it twice.
   The server must store a QSO ONCE however many times it arrives, relay it
   once, and still tell every sender it has it. A QSO is told from another by
   the pair (ceQSOID1, ceQSOID2); the pair (0, 0) identifies nothing."""
   r = ctx.report
   timeout = ctx.args.timeout
   a = ctx.probe('A', 1)
   b = ctx.probe('B', 2)
   a.settle(0.5)
   b.settle(0.5)

   # 1. A new QSO is relayed and stored, as ever.
   before = ctx.log_records()
   id1, id2 = ctx.next_ids()
   exchange = build_exchange('K1RS1', id1, id2)
   first = build_qso(NET_QSOINFO_ID, exchange, 1, a.ordinal)
   a.send(first)
   got = b.take(NET_QSOINFO_ID, timeout)
   r.add('resend', 'a new QSO is relayed', 'PASS' if got == first else 'FAIL',
         describe_receipt(got, first, b))
   time.sleep(0.5)
   held = ctx.log_records()
   grew = log_growth(before, held)
   if grew is None:
      r.add('resend', 'a new QSO is stored once', 'SKIP', 'log not readable')
   else:
      r.add('resend', 'a new QSO is stored once', 'PASS' if grew == 1 else 'FAIL',
            'grew by %d' % grew)

   # 2. The same QSO as QSOINFO again: neither stored nor relayed.
   a.send(first)
   again = b.take(NET_QSOINFO_ID, 1.5)
   r.add('resend', 'a second QSOINFO of a held QSO is not relayed',
         'PASS' if again is None else 'FAIL',
         '' if again is None else 'B received it again')
   time.sleep(0.5)
   after = ctx.log_records()
   grew = log_growth(held, after)
   if grew is None:
      r.add('resend', 'a second QSOINFO of a held QSO is not stored', 'SKIP',
            'log not readable')
   else:
      r.add('resend', 'a second QSOINFO of a held QSO is not stored',
            'PASS' if grew == 0 else 'FAIL', 'grew by %d' % grew)
   r.add('resend', 'the sender stays connected', 'PASS' if a.alive(timeout) else 'FAIL')

   # 3. The same QSO as OFFLINEQSO: not stored, but acknowledged.
   a.take(NET_SERVERMESSAGE_ID, 0.2, SM_RECEIVED_UPDATED_QSO)
   a.send(build_qso(NET_OFFLINEQSO_ID, exchange, 1, a.ordinal))
   ack = a.take(NET_SERVERMESSAGE_ID, timeout, SM_RECEIVED_UPDATED_QSO)
   r.add('resend', 'an OFFLINEQSO of a held QSO is acknowledged',
         'PASS' if ack else 'FAIL')
   time.sleep(0.5)
   grew = log_growth(held, ctx.log_records())
   if grew is None:
      r.add('resend', 'an OFFLINEQSO of a held QSO is not stored', 'SKIP',
            'log not readable')
   else:
      r.add('resend', 'an OFFLINEQSO of a held QSO is not stored',
            'PASS' if grew == 0 else 'FAIL', 'grew by %d' % grew)

   # 4. An OFFLINEQSO the server has never seen is stored and acknowledged. It
   #    is not relayed: that is why the client resends as QSOINFO.
   n1, n2 = ctx.next_ids()
   new_offline = build_qso(NET_OFFLINEQSO_ID, build_exchange('K1RS2', n1, n2), 1, a.ordinal)
   a.send(new_offline)
   ack = a.take(NET_SERVERMESSAGE_ID, timeout, SM_RECEIVED_UPDATED_QSO)
   r.add('resend', 'a new OFFLINEQSO is acknowledged', 'PASS' if ack else 'FAIL')
   time.sleep(0.5)
   grew = log_growth(held, ctx.log_records())
   if grew is None:
      r.add('resend', 'a new OFFLINEQSO is stored', 'SKIP', 'log not readable')
   else:
      r.add('resend', 'a new OFFLINEQSO is stored', 'PASS' if grew == 1 else 'FAIL',
            'grew by %d' % grew)
   relayed = b.take(NET_OFFLINEQSO_ID, 1.0) or b.take(NET_QSOINFO_ID, 0.2)
   r.add('resend', 'an OFFLINEQSO is not relayed (the client resends as QSOINFO)',
         'INFO', 'relayed' if relayed else 'not relayed')

   # 5. The pair (0, 0) identifies nothing: such a QSO is never a duplicate.
   held = ctx.log_records()
   anon = build_qso(NET_QSOINFO_ID, build_exchange('K1RS3', 0, 0), 1, a.ordinal)
   a.send(anon)
   a.send(anon)
   got = b.count(NET_QSOINFO_ID, 2, timeout)
   time.sleep(0.5)
   grew = log_growth(held, ctx.log_records())
   r.add('resend', 'a QSO with ids (0, 0) is relayed every time',
         'PASS' if got >= 2 else 'FAIL', 'B has %d QSOINFO' % got)
   if grew is None:
      r.add('resend', 'a QSO with ids (0, 0) is stored every time', 'SKIP',
            'log not readable')
   else:
      r.add('resend', 'a QSO with ids (0, 0) is stored every time',
            'PASS' if grew == 2 else 'FAIL', 'grew by %d' % grew)

   # 6. An edit of a held QSO is still relayed and applied.
   held = ctx.log_records()
   edited = build_exchange('K1RS1X', id1, id2)
   edit = build_qso(NET_EDITEDQSO_ID, edited, 1, a.ordinal)
   a.send(edit)
   got = b.take(NET_EDITEDQSO_ID, timeout)
   r.add('resend', 'an edit of a held QSO is relayed', 'PASS' if got == edit else 'FAIL',
         describe_receipt(got, edit, b))
   time.sleep(0.5)
   after = ctx.log_records()
   if held is None or after is None:
      r.add('resend', 'an edit of a held QSO is applied in place', 'SKIP',
            'log not readable')
   else:
      applied = edited in after and exchange not in after
      r.add('resend', 'an edit of a held QSO is applied in place',
            'PASS' if (applied and len(after) == len(held)) else 'FAIL',
            'records %d -> %d' % (len(held), len(after)))

   # 7. A whole burst sent twice -- a station that lost the link half way
   #    through a catch-up and sent all of it again -- is relayed and stored once.
   count = ctx.args.burst
   held = ctx.log_records()
   blob = b''
   for _ in range(count):
      b1, b2 = ctx.next_ids()
      blob += build_qso(NET_QSOINFO_ID, build_exchange('K1RS4', b1, b2), 1, a.ordinal)
   b.inbox = [item for item in b.inbox if item[0] != NET_QSOINFO_ID]   # count only this burst
   a.send(blob)
   got = b.count(NET_QSOINFO_ID, count, timeout + 3)
   r.add('resend', 'a burst of %d is relayed whole' % count,
         'PASS' if got >= count else 'FAIL', 'B has %d' % got)
   have = sum(1 for found_id, _ in b.inbox if found_id == NET_QSOINFO_ID)
   a.send(blob)
   time.sleep(1.5)
   b.pump(0.5)
   now = sum(1 for found_id, _ in b.inbox if found_id == NET_QSOINFO_ID)
   r.add('resend', 'the same burst sent again is not relayed again',
         'PASS' if now == have else 'FAIL', 'B went from %d to %d' % (have, now))
   time.sleep(0.5)
   grew = log_growth(held, ctx.log_records())
   if grew is None:
      r.add('resend', 'the same burst sent again is stored once', 'SKIP',
            'log not readable')
   else:
      r.add('resend', 'the same burst sent again is stored once',
            'PASS' if grew == count else 'FAIL',
            'grew by %d, wanted %d' % (grew, count))
   r.add('resend', 'both stations still connected',
         'PASS' if (a.alive(timeout) and b.alive(timeout)) else 'FAIL')


CASES = {
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
}


def run_case(name, args, report):
   ctx = Context(args, report)
   try:
      CASES[name](ctx)
   except ProbeError as err:
      report.error(name, str(err))
   except (OSError, socket.timeout) as err:
      report.error(name, 'socket: %s' % err)
   finally:
      ctx.close_all()


def parse_args(argv):
   p = argparse.ArgumentParser(description='Speak TR4W multi-op V1 at a server.')
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
                  help='QSOs in the burst case')
   p.add_argument('--contest', default='ARRL-DX-CW',
                  help='the contest id the probes announce in their HELLO')
   p.add_argument('--expect-time', choices=('relay', 'none', 'any'), default='any',
                  help='whether the server is configured to relay TIMESYN')
   return p.parse_args(argv)


def main(argv):
   args = parse_args(argv)
   names = list(CASES) if args.case == 'all' else [args.case]
   for name in names:
      if name not in CASES:
         print('unknown case %r; choose from %s' % (name, ', '.join(CASES)))
         return 2
   report = Report(args.label)
   for name in names:
      run_case(name, args, report)
      time.sleep(1.0)                 # let the server notice the closed sockets
   print('SUMMARY %s: %d failed, %d could not run' %
         (args.label, report.failed, report.errored), flush=True)
   if report.errored:
      return 2
   return 1 if report.failed else 0


if __name__ == '__main__':
   sys.exit(main(sys.argv[1:]))
