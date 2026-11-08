"""Single-event-loop server: shared radio state, bounded per-client output."""
import asyncio
from dataclasses import dataclass, field
import math
import struct
import time

from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

from .radio import Radio, RATE, message, integer, boolean
from .signals import Scene, frame, HEADER, IQ, AUDIO, CHRONO, SPECTRUM, PAIRS


@dataclass(eq=False)
class Peer:
   socket: object
   number: int
   output: asyncio.Queue = field(default_factory=lambda: asyncio.Queue(128))
   iq: set = field(default_factory=set)
   audio: set = field(default_factory=set)
   spectrum: bool = False
   buffer: str = ''
   dropped: int = 0


class MockServer:
   def __init__(self, trace=False, log=print):
      self.radio = Radio()
      self.clients = {}
      self.trace = trace
      self.log = log
      self.wake = asyncio.Event()
      self.scenes = [Scene(r.vfo_a, 42 + i) for i, r in enumerate(self.radio.receivers)]
      self.owner = None
      self.cw_task = None
      self.stream_task = None
      self.listener = None
      self.next_client = 1
      self.unknown = set()
      self.stream_frames = 0
      self.late_ticks = 0

   async def start(self, host='127.0.0.1', port=50011):
      self.listener = await serve(self.connection, host, port, compression=None,
                                  max_size=65536, max_queue=8, write_limit=32768,
                                  open_timeout=3, close_timeout=1,
                                  ping_interval=10, ping_timeout=20)
      self.stream_task = asyncio.create_task(self.streams())
      return self.listener.sockets[0].getsockname()[1]

   async def close(self):
      if self.cw_task:
         self.cw_task.cancel()
         await asyncio.gather(self.cw_task, return_exceptions=True)
      if self.stream_task:
         self.stream_task.cancel()
         await asyncio.gather(self.stream_task, return_exceptions=True)
      if self.listener:
         self.listener.close()
         await self.listener.wait_closed()
      self.owner = None
      for state in self.radio.receivers:
         state.transmitting = False

   def enqueue(self, peer, value):
      if isinstance(value, bytes) and peer.output.qsize() >= 8:
         peer.dropped += 1
         return
      try:
         peer.output.put_nowait(value)
      except asyncio.QueueFull:
         # A non-reading client cannot grow memory or stall another client.
         peer.socket.transport.abort()

   def broadcast(self, values):
      for peer in self.clients.values():
         for value in values:
            self.enqueue(peer, value)

   async def sender(self, peer):
      try:
         while True:
            value = await peer.output.get()
            await asyncio.wait_for(peer.socket.send(value), timeout=2)
      except (ConnectionClosed, TimeoutError):
         await peer.socket.close()

   async def connection(self, socket):
      if len(self.clients) >= 8:
         await socket.close(1013, 'mock radio supports eight clients')
         return
      peer = Peer(socket, self.next_client)
      self.next_client += 1
      self.clients[socket] = peer
      for row in self.radio.burst():
         self.enqueue(peer, row)
      writer = asyncio.create_task(self.sender(peer))
      self.log('Client %d connected: %s' % (peer.number, socket.remote_address))
      try:
         async for data in socket:
            if isinstance(data, bytes):
               # TX audio is counted/discarded: this tool never keys hardware.
               continue
            peer.buffer += data
            if len(peer.buffer) > 8192:
               await socket.close(1009, 'command buffer limit')
               break
            while ';' in peer.buffer:
               text, peer.buffer = peer.buffer.split(';', 1)
               if text.strip():
                  self.command(peer, text.strip())
      except ConnectionClosed:
         pass
      finally:
         if self.owner and self.owner[0] is peer:
            if self.cw_task and not self.cw_task.done():
               self.cw_task.cancel()
            self.ptt(peer, self.owner[1], False)
         self.clients.pop(socket, None)
         writer.cancel()
         await asyncio.gather(writer, return_exceptions=True)
         self.log('Client %d disconnected' % peer.number)
         self.wake.set()

   def ptt(self, peer, rx, active):
      if active and self.owner not in (None, (peer, rx)):
         if peer is not None:
            self.enqueue(peer, message('trx', rx, False))
         return False
      if not active and self.owner != (peer, rx):
         return False
      self.owner = (peer, rx) if active else None
      self.radio.receivers[rx].transmitting = active
      self.broadcast([message('trx', rx, active)])
      self.wake.set()
      return True

   async def finish_cw(self, peer, rx, seconds):
      await asyncio.sleep(seconds)
      self.ptt(peer, rx, False)

   def command(self, peer, text):
      if self.trace:
         self.log('RX %d %s;' % (peer.number, text))
      name, colon, rest = text.partition(':')
      name = name.lower()
      args = [s.strip() for s in rest.split(',')] if colon else []
      try:
         if name in ('iq_start', 'iq_stop', 'audio_start', 'audio_stop'):
            if len(args) != 1:
               raise ValueError('stream requires one receiver')
            rx = integer(args[0], 0, 1)
            subscriptions = peer.iq if name.startswith('iq_') else peer.audio
            if name.endswith('start'):
               subscriptions.add(rx)
            else:
               subscriptions.discard(rx)
            self.enqueue(peer, message(name, rx))
            self.wake.set()
         elif name == 'spectrum_event':
            if args not in (['on'], ['off']):
               raise ValueError('spectrum_event takes on or off')
            peer.spectrum = args == ['on']
            self.wake.set()
         elif name in ('audio_samplerate', 'iq_samplerate'):
            if len(args) > 1:
               raise ValueError('one sample rate expected')
            self.enqueue(peer, message(name, RATE))
         elif name in ('audio_stream_sample_type', 'audio_stream_channels', 'audio_stream_samples'):
            actual = {'audio_stream_sample_type': 'float32', 'audio_stream_channels': 2,
                      'audio_stream_samples': PAIRS * 2}[name]
            self.enqueue(peer, message(name, actual))
         elif name == 'trx':
            if len(args) not in (1, 2, 3):
               raise ValueError('trx requires receiver, optional boolean and tci marker')
            rx = integer(args[0], 0, 1)
            if len(args) == 3 and args[2].lower() != 'tci':
               raise ValueError('third trx argument must be tci')
            if len(args) == 1:
               self.enqueue(peer, message('trx', rx, self.radio.receivers[rx].transmitting))
            else:
               self.ptt(peer, rx, boolean(args[1]))
         elif name == 'cw_macros':
            if len(args) != 2 or len(args[1]) > 256:
               raise ValueError('cw_macros requires receiver and up to 256 characters')
            rx = integer(args[0], 0, 1)
            if self.cw_task and not self.cw_task.done():
               raise ValueError('CW already in progress')
            if self.ptt(peer, rx, True):
               self.log('SIMULATED CW RX%d @%d WPM: %s' % (rx, self.radio.speed, args[1]))
               self.cw_task = asyncio.create_task(self.finish_cw(peer, rx,
                  max(0.05, len(args[1]) * 6 / self.radio.speed)))
         elif name == 'cw_macros_stop':
            if self.owner and self.owner[0] is peer:
               if self.cw_task:
                  self.cw_task.cancel()
               self.ptt(peer, self.owner[1], False)
         elif name in ('rx_sensors_enable', 'tx_sensors_enable'):
            # Fixed test telemetry; no timer or unsolicited meter chatter.
            if args and args[0].lower() == 'true':
               self.enqueue(peer, message('rx_sensors', 0, -85))
         elif name in ('start', 'stop') and not args:
            self.enqueue(peer, message(name))
         else:
            rows, changed = self.radio.command(name, args)
            if changed:
               self.broadcast(rows)
               self.log('State: ' + ' '.join(rows))
            else:
               for row in rows:
                  self.enqueue(peer, row)
      except (ValueError, KeyError) as error:
         key = name + ':' + type(error).__name__
         if key not in self.unknown and len(self.unknown) < 64:
            self.unknown.add(key)
            self.log('Ignored unsupported/invalid command: %s (%s)' % (name, error))

   async def streams(self):
      due = time.monotonic()
      tick = 0
      while True:
         peers = list(self.clients.values())
         if not any(p.iq or p.audio or p.spectrum for p in peers) and self.owner is None:
            self.wake.clear()
            await self.wake.wait()
            due = time.monotonic()
            continue
         cache = {}
         for peer in peers:
            for rx in peer.iq:
               key = (IQ, rx)
               if key not in cache:
                  cache[key] = frame(rx, IQ, self.scenes[rx].iq(self.radio.receivers[rx].vfo_a))
               self.enqueue(peer, cache[key])
            for rx in peer.audio:
               key = (AUDIO, rx)
               if key not in cache:
                  # Stereo 700 Hz tone; deliberately synthetic, not a WSJT-X QSO.
                  samples = [0.05 * math.sin(2 * math.pi * 700 * (tick * PAIRS + i) / RATE)
                             for i in range(PAIRS)]
                  cache[key] = frame(rx, AUDIO, [v for sample in samples for v in (sample, sample)])
               self.enqueue(peer, cache[key])
            if peer.spectrum and tick % 5 == 0:
               for rx, state in enumerate(self.radio.receivers):
                  key = (SPECTRUM, rx)
                  if key not in cache:
                     cache[key] = frame(rx, SPECTRUM, self.scenes[rx].spectrum(state.vfo_a),
                        channels=1, low=state.vfo_a - RATE // 2, high=state.vfo_a + RATE // 2)
                  self.enqueue(peer, cache[key])
         if self.owner and self.owner[0] is not None:
            peer, rx = self.owner
            self.enqueue(peer, HEADER.pack(rx, RATE, 3, 0, 0, PAIRS * 2, CHRONO, 2, *([0] * 8)))
         self.stream_frames += len(cache)
         tick += 1
         due += PAIRS / RATE
         now = time.monotonic()
         if now > due + PAIRS / RATE:
            self.late_ticks += 1
            due = now
         await asyncio.sleep(max(0, due - now))

   def status(self):
      return self.radio.status() + '\nClients=%d stream_frames=%d late_ticks=%d dropped=%d' % (
         len(self.clients), self.stream_frames, self.late_ticks,
         sum(p.dropped for p in self.clients.values()))
