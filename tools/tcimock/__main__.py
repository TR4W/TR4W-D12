"""Run with: python tools/tcimock --port 50011"""
import argparse
import asyncio
from pathlib import Path
import sys
import threading

# Directory execution and python -m tcimock share the existing radiosim package.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
try:
   from tcimock.server import MockServer
   from tcimock.radio import integer, boolean
except ImportError as error:
   raise SystemExit('Install dependencies: python -m pip install -r tools/tcimock/requirements.txt\n' + str(error))

HELP = '''TCI MOCK RADIO -- no hardware, no RF
status | clients | trace on/off | spectrum [0|1] | drop | quit
freq RX HZ [A|B] | mode RX CW/USB/LSB/... | split RX on/off
rit RX HZ | xit RX HZ | ptt RX on/off | speed WPM
raw TCI-COMMAND;    Apply a command as a local operator (not a network client).
Example: freq 0 14030000   (frequencies are Hz, not MHz)
Connect clients to ws://127.0.0.1:50011/ by default.'''


async def console(server, stop):
   loop = asyncio.get_running_loop()
   inputs = asyncio.Queue(32)

   def deliver(line):
      if not inputs.full():
         inputs.put_nowait(line)

   def read_input():
      while not stop.is_set():
         line = sys.stdin.readline()
         loop.call_soon_threadsafe(deliver, line)
         if not line:
            return

   threading.Thread(target=read_input, daemon=True).start()
   print(HELP, flush=True)
   while not stop.is_set():
      line = await inputs.get()
      words = line.strip().split()
      if not line or words == ['quit']:
         stop.set()
         break
      if not words:
         continue
      try:
         action = words[0].lower()
         if action == 'help':
            print(HELP)
         elif action in ('status', 'clients'):
            print(server.status())
            for peer in server.clients.values():
               print('Client %d %s IQ=%s audio=%s spectrum=%s' % (
                  peer.number, peer.socket.remote_address, peer.iq, peer.audio, peer.spectrum))
         elif action == 'trace' and len(words) == 2:
            server.trace = boolean({'on': 'true', 'off': 'false'}[words[1]])
         elif action == 'spectrum':
            rx = integer(words[1] if len(words) > 1 else '0', 0, 1)
            print(server.scenes[rx].ascii(server.radio.receivers[rx].vfo_a))
         elif action == 'drop':
            await asyncio.gather(*(p.socket.close(1012, 'simulated link loss')
                                   for p in list(server.clients.values())))
         elif action == 'ptt' and len(words) == 3:
            server.ptt(None, integer(words[1], 0, 1), {'on': True, 'off': False}[words[2]])
         else:
            if action == 'freq' and len(words) in (3, 4):
               text = 'vfo:%s,%d,%s' % (words[1], 1 if words[-1].upper() == 'B' else 0, words[2])
            elif action == 'mode' and len(words) == 3:
               text = 'modulation:%s,%s' % (words[1], words[2])
            elif action == 'split' and len(words) == 3:
               text = 'split_enable:%s,%s' % (words[1], {'on': 'true', 'off': 'false'}[words[2]])
            elif action in ('rit', 'xit') and len(words) == 3:
               rx = integer(words[1], 0, 1)
               rows, _ = server.radio.command(action + '_enable', [str(rx), 'true'])
               server.broadcast(rows)
               text = '%s_offset:%s,%s' % (action, words[1], words[2])
            elif action == 'speed' and len(words) == 2:
               text = 'cw_macros_speed:' + words[1]
            elif action == 'raw':
               text = line.strip()[4:].rstrip(';')
            else:
               raise ValueError('unknown command; type help')
            name, _, rest = text.partition(':')
            rows, _ = server.radio.command(name.lower(), rest.split(',') if rest else [])
            server.broadcast(rows)
            print(server.status())
      except (ValueError, KeyError, IndexError) as error:
         print('Command rejected:', error)


async def run(args):
   server = MockServer(args.trace)
   stop = asyncio.Event()
   try:
      port = await server.start(args.host, args.port)
      print('TCI MOCK listening ws://%s:%d/ -- synthetic radio only' % (args.host, port), flush=True)
      if args.no_console:
         await stop.wait()
      else:
         await console(server, stop)
   finally:
      await server.close()


def main():
   parser = argparse.ArgumentParser(description='Hardware-free TCI radio with synthetic IQ and spectrum')
   parser.add_argument('--host', default='127.0.0.1', help='bind address; loopback by default')
   parser.add_argument('--port', type=int, default=50011)
   parser.add_argument('--trace', action='store_true', help='print incoming text commands')
   parser.add_argument('--no-console', action='store_true', help='run until Ctrl+C without reading stdin')
   args = parser.parse_args()
   if not 0 <= args.port <= 65535:
      parser.error('port must be 0..65535')
   try:
      asyncio.run(run(args))
   except KeyboardInterrupt:
      pass
   except OSError as error:
      raise SystemExit(str(error))


if __name__ == '__main__':
   main()
