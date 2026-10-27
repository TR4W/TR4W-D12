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

SM_CLEARALLLOGS = 8230
SM_SERVERLOG_CHANGED = 8250
SM_DISCONECT_CLIENT = 8260
SM_GETSTATUS = 8270
SM_RECEIVED_UPDATED_QSO = 8300
SM_SERIAL_NUMBER_CHANGED = 8310
SM_COMPUTERID_IN_USE = 8320

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
}

MESSAGE_NAME = {
   1000: 'MESSAGESTATE', 1010: 'LOGCOMPARE', 1020: 'INTERCOM',
   1030: 'DXSPOT', 1040: 'QSOINFO', 1050: 'EDITEDQSO', 1055: 'OFFLINEQSO',
   1060: 'TAKESERVERQSO', 1070: 'TIMESYN', 1080: 'PARAMETER',
   1090: 'STATIONSTATUS', 1110: 'CLIENTSTATUS', 1120: 'SPOTVIANETWORK',
   1130: 'COMPUTERID', 1140: 'SERVERMESSAGE',
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


def build_qso(msg_id, exchange, computer_id):
   """TNetQSOInformation: id, ContestExchange, computer id (Cardinal), 2 bytes."""
   return struct.pack('<H', msg_id) + exchange + struct.pack('<IBB', computer_id, 0, 0)


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

   def __init__(self, name, host, port, password, ordinal, timeout):
      self.name = name
      self.ordinal = ordinal
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

   def take(self, msg_id, wait, message=None):
      """Pop the first message with this id (and, for a server message, this
      smMessage) that arrives within `wait` seconds, or None."""
      deadline = time.time() + wait
      while True:
         for index, (found_id, data) in enumerate(self.inbox):
            if found_id != msg_id:
               continue
            if message is not None and server_message_fields(data)[0] != message:
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

class Context:
   def __init__(self, args, report):
      self.args = args
      self.report = report
      self.probes = []
      self.serial = int(time.time()) & 0x7FFFFFF0

   def probe(self, name, ordinal, claim=True):
      p = Probe(name, self.args.host, self.args.port, self.args.password,
                ordinal, self.args.timeout)
      self.probes.append(p)
      if claim:
         p.claim_id()
      return p

   def next_ids(self):
      self.serial += 2
      return self.serial, self.serial + 1

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
   msg = build_qso(NET_QSOINFO_ID, exchange, 1)
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
      blob += build_qso(NET_QSOINFO_ID, build_exchange('K1BST', id1, id2), 1)
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
   a.send(build_qso(NET_QSOINFO_ID, original, 1))
   b.take(NET_QSOINFO_ID, ctx.args.timeout)
   time.sleep(0.5)
   before = ctx.log_records()
   edited = build_exchange('K1NEW', id1, id2)
   msg = build_qso(NET_EDITEDQSO_ID, edited, 1)
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
