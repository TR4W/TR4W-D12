"""Loopback integration tests; never connect to a radio or an existing app."""
import asyncio
import math
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from websockets.asyncio.client import connect
from tcimock.radio import Radio, RATE
from tcimock.server import MockServer, Peer
from tcimock.signals import HEADER, IQ, SPECTRUM, Scene, PAIRS


async def until(socket, wanted=None, binary=None):
   async def collect():
      while True:
         item = await socket.recv()
         if binary is not None and isinstance(item, bytes) and HEADER.unpack_from(item)[6] == binary:
            return item
         if wanted is not None and item == wanted:
            return item
   return await asyncio.wait_for(collect(), 3)


class RadioTests(unittest.TestCase):
   def test_rejected_set_does_not_change_state(self):
      radio = Radio()
      for name, args in [('vfo', ['0', '0', '-1']), ('modulation', ['0', 'bogus']),
                         ('rx_filter_band', ['0', '200', '100']), ('split_enable', ['0', 'yes'])]:
         before = radio.burst()
         with self.assertRaises(ValueError):
            radio.command(name, args)
         self.assertEqual(before, radio.burst())

   def test_two_receivers_and_offsets_are_independent(self):
      radio = Radio()
      radio.command('vfo', ['1', '0', '7074000'])
      radio.command('rit_offset', ['1', '123'])
      radio.command('xit_offset', ['1', '-321'])
      self.assertEqual(radio.receivers[0].vfo_a, 14025000)
      self.assertEqual(radio.receivers[1].vfo_a, 7074000)
      self.assertEqual(radio.receivers[1].rit_offset, 123)
      self.assertEqual(radio.receivers[1].xit_offset, -321)

   def test_iq_has_a_real_peak_and_continuous_phase(self):
      scene = Scene(14025000)
      data = scene.iq(14025000)
      samples = [complex(data[i], data[i + 1]) for i in range(0, len(data), 2)]
      def power(hz):
         return abs(sum(v * complex(math.cos(-2 * math.pi * hz * i / RATE),
                                    math.sin(-2 * math.pi * hz * i / RATE))
                        for i, v in enumerate(samples))) ** 2
      self.assertGreater(power(4000), power(7000) * 100)
      next_data = scene.iq(14025000)
      self.assertNotEqual(data, next_data)
      self.assertLess(max(abs(v) for v in samples), 1)


class ServerTests(unittest.IsolatedAsyncioTestCase):
   async def asyncSetUp(self):
      self.server = MockServer(log=lambda text: None)
      self.port = await self.server.start(port=0)
      self.sockets = []

   async def asyncTearDown(self):
      for socket in self.sockets:
         await socket.close()
      await self.server.close()

   async def client(self):
      socket = await connect('ws://127.0.0.1:%d/' % self.port, proxy=None)
      self.sockets.append(socket)
      burst = []
      while True:
         text = await asyncio.wait_for(socket.recv(), 3)
         burst.append(text)
         if text == 'ready;':
            break
      self.assertEqual(burst[-2:], ['start;', 'ready;'])
      self.assertIn('device:TR4W-TCI-MOCK;', burst)
      self.assertIn('channels_count:2;', burst)
      self.assertFalse(any(s.startswith(('iq_start', 'audio_start')) for s in burst))
      return socket

   async def test_set_broadcast_and_queries_with_partial_commands(self):
      one, two = await self.client(), await self.client()
      await one.send('vfo:0,0,140')
      await one.send(['30000;', 'modulation:1,lsb;'])
      await until(two, 'vfo:0,0,14030000;')
      await until(two, 'modulation:1,lsb;')
      await one.send('vfo:1,0;')
      await until(one, 'vfo:1,0,7025000;')
      self.assertEqual(self.server.radio.receivers[0].vfo_a, 14030000)
      self.assertEqual(self.server.radio.receivers[1].mode, 'lsb')

   async def test_ptt_owner_survives_other_client_and_unkeys_on_disconnect(self):
      one, two = await self.client(), await self.client()
      await one.send('trx:0,true;')
      await until(two, 'trx:0,true;')
      await two.send('trx:0,false;vfo:0,0;')
      await until(two, 'vfo:0,0,14025000;')
      self.assertTrue(self.server.radio.receivers[0].transmitting)
      await one.close()
      await until(two, 'trx:0,false;')
      self.assertFalse(self.server.radio.receivers[0].transmitting)

   async def test_iq_and_spectrum_subscriptions_and_header(self):
      one, two = await self.client(), await self.client()
      await one.send('iq_start:1;spectrum_event:on;')
      data = await until(one, binary=IQ)
      header = HEADER.unpack_from(data)
      self.assertEqual(header[:8], (1, RATE, 3, 0, 0, PAIRS * 2, IQ, 2))
      self.assertEqual(len(data), 64 + PAIRS * 8)
      floats = struct.unpack('<%df' % (PAIRS * 2), data[64:])
      self.assertTrue(all(math.isfinite(v) and abs(v) < 1 for v in floats))
      spectrum = await until(one, binary=SPECTRUM)
      header = HEADER.unpack_from(spectrum)
      self.assertEqual(header[7], 1)
      self.assertEqual(header[9] - header[8], RATE)
      self.assertEqual(len(spectrum), 64 + header[5] * 4)
      with self.assertRaises(TimeoutError):
         await asyncio.wait_for(two.recv(), 0.08)
      await one.send('iq_stop:1;spectrum_event:off;')
      await until(one, 'iq_stop:1;')
      while True:
         try:
            await asyncio.wait_for(one.recv(), 0.08)
         except TimeoutError:
            break
      with self.assertRaises(TimeoutError):
         await asyncio.wait_for(one.recv(), 0.08)

   async def test_invalid_frame_does_not_poison_next_command(self):
      socket = await self.client()
      await socket.send('vfo:9,0,14000000;rit_enable:0,yes;vfo:0,0;')
      await until(socket, 'vfo:0,0,14025000;')
      self.assertFalse(self.server.radio.receivers[0].rit_on)

   async def test_cw_finishes_and_can_be_aborted(self):
      socket = await self.client()
      await socket.send('cw_macros_speed:80;cw_macros:0,E;')
      await until(socket, 'trx:0,true;')
      await until(socket, 'trx:0,false;')
      await socket.send('cw_macros:0,CQ CQ CQ;cw_macros_stop;')
      await until(socket, 'trx:0,true;')
      await until(socket, 'trx:0,false;')

   async def test_independent_existing_tr4w_wire_client(self):
      import socket as sockets
      from tciclient import handshake, encode_text, decode_frames
      def exchange():
         with sockets.create_connection(('127.0.0.1', self.port), timeout=3) as sock:
            buffer = handshake(sock, '127.0.0.1', self.port)
            replies = []
            sock.sendall(encode_text(b'vfo:0,0,14040000;'))
            while 'vfo:0,0,14040000;' not in replies:
               frames, buffer = decode_frames(buffer)
               replies.extend(data.decode() for opcode, data in frames if opcode == 1)
               if 'vfo:0,0,14040000;' not in replies:
                  buffer += sock.recv(65536)
            return replies
      replies = await asyncio.wait_for(asyncio.to_thread(exchange), 4)
      self.assertIn('ready;', replies)
      self.assertEqual(self.server.radio.receivers[0].vfo_a, 14040000)

   async def test_audio_and_chrono_use_tci_headers(self):
      socket = await self.client()
      await socket.send('audio_start:0;')
      audio = await until(socket, binary=1)
      header = HEADER.unpack_from(audio)
      self.assertEqual(header[5:8], (2048, 1, 2))
      await socket.send('trx:0,true;')
      chrono = await until(socket, binary=3)
      self.assertEqual(len(chrono), 64)
      self.assertEqual(HEADER.unpack_from(chrono)[5:8], (2048, 3, 2))
      await socket.send(bytes(16448))
      await socket.send('vfo:0,0;')
      await until(socket, 'vfo:0,0,14025000;')

   async def test_two_receiver_iq_stream_pacing(self):
      import time
      socket = await self.client()
      await socket.send('iq_start:0;iq_start:1;')
      counts = [0, 0]
      cpu_start = time.process_time()
      started = time.monotonic()
      while time.monotonic() - started < 0.35:
         data = await until(socket, binary=IQ)
         counts[HEADER.unpack_from(data)[0]] += 1
      wall = time.monotonic() - started
      cpu = time.process_time() - cpu_start
      self.assertGreater(min(counts), 5, 'both receivers must produce sustained IQ')
      print('TCI mock IQ measurement: blocks=%s wall=%.3fs CPU=%.3fs late_ticks=%d' %
            (counts, wall, cpu, self.server.late_ticks), flush=True)

   async def test_streams_do_no_work_while_idle(self):
      await self.client()
      await asyncio.sleep(0.05)
      self.assertEqual(self.server.stream_frames, 0)

   async def test_slow_peer_has_bounded_queue(self):
      class Transport:
         aborted = False
         def abort(self):
            self.aborted = True
      class Socket:
         transport = Transport()
      peer = Peer(Socket(), 99)
      for _ in range(1000):
         self.server.enqueue(peer, b'dummy stream frame')
      self.assertEqual(peer.output.qsize(), 8)
      self.assertEqual(peer.dropped, 992)
      for _ in range(200):
         self.server.enqueue(peer, 'vfo:0,0,14025000;')
      self.assertLessEqual(peer.output.qsize(), 128)
      self.assertTrue(peer.socket.transport.aborted)


if __name__ == '__main__':
   unittest.main()
