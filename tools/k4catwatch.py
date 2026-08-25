#!/usr/bin/env python3
"""
k4catwatch -- watch the Elecraft K4's CAT port, with an eye on the '#' display
commands.

WHY THIS EXISTS.  TR4W now draws a panadapter from the K4's spectrum stream
(port 9200 + 1), and it invents its own reference level, averaging and colours.
The radio has opinions about all three, and it appears to broadcast them: TR4QT
sees them and throws them away, with a comment naming
'#AR, #AVG, #CAL$, #DSM, #FPS, #REF$, #SPN$, #VFA, #WFC$'
(src/radio/K4Radio.cpp:249).  TR4W's K4 driver handles none of them.

Before deciding whether TR4W should follow the radio's settings, somebody has
to know what those commands actually say.  That is this tool: it does not
assume the list above is right, complete, or correctly interpreted -- it prints
what the radio sends.

SAFETY.  By default this SENDS ONLY 'PING;'.  That is not optional politeness:
unlike the panadapter port, the K4's CAT port drops a client that says nothing
for about ten seconds, which is why TR4W's own driver polls it.  --ai and
--query are opt-in, and both are described below.

  --ai N     sets the auto-info level on THIS connection.  The K4 pushes state
             changes when AI is on, so this is usually what makes '#' commands
             appear at all.  TR4W's driver sends AI5 on its own network
             connection, so this is the state TR4W actually runs in.

  --query    sends the QUERY form of each '#' command -- '#REF$;' and so on.
             In the Elecraft grammar a command with no value is a read, so this
             asks rather than sets.  Nothing here writes a setting.

USAGE
    python k4catwatch.py --host 192.168.73.108
    python k4catwatch.py --host 192.168.73.108 --ai 5 --seconds 20
    python k4catwatch.py --host 192.168.73.108 --ai 5 --query
"""

import argparse
import socket
import sys
import time

DEFAULT_CAT_PORT = 9200

# Taken from QK4's own handlers (src/models/radiostate/spectrumdisplaystate.cpp),
# which is a far more complete list than TR4QT's comment -- QK4 parses each of
# these with a documented range.  Still treated as a LIST TO CHECK rather than a
# specification: the radio answers an unknown command with '?', and that answer
# is itself a result worth having.
#
# QK4's stated ranges, for comparison against what the radio actually says:
#   #REF/#REF$ -200..50   #SPN/#SPN$ 1..999999   #SCL 10..150   #FPS 12..30
#   #WFC 0..4             #WFH/#HWFH 0..100      #AVG 1..20     #PKM 0/1
#   #DPM/#HDPM 0..2       #DSM/#HDSM 0/1         #FXT 0/1       #FXA 0..4
#   #FRZ 0/1              #VFA/#VFB 0..3         #NB 0..2       #NBL 0..14
#   #MP/#MP$ bool         #AR  last char A or M
DISPLAY_QUERIES = [
   "#REF", "#REF$", "#SPN", "#SPN$", "#SCL",
   "#MP", "#MP$", "#DPM", "#HDPM", "#DSM", "#HDSM",
   "#FPS", "#WFC", "#WFH", "#HWFH", "#AVG", "#PKM",
   "#FXT", "#FXA", "#FRZ", "#VFA", "#VFB", "#AR",
   "#NB", "#NBL",
]

KEEPALIVE_SECONDS = 5.0


def split_messages(buf):
   """Split a buffer on ';' and return (complete messages, remainder)."""
   out = []

   while ";" in buf:
      i = buf.index(";")
      msg = buf[:i].strip()
      buf = buf[i + 1:]

      if msg:
         out.append(msg)

   return out, buf


def main():
   ap = argparse.ArgumentParser(
      description="Watch the K4 CAT port and report its '#' display commands.")
   ap.add_argument("--host", required=True, help="K4 IP address")
   ap.add_argument("--port", type=int, default=DEFAULT_CAT_PORT)
   ap.add_argument("--seconds", type=float, default=15.0)
   ap.add_argument("--ai", type=int, default=None, metavar="N",
                   help="set auto-info level on this connection (TR4W uses 5). "
                        "Usually required before the radio pushes anything.")
   ap.add_argument("--query", action="store_true",
                   help="also send the READ form of each '#' command")
   ap.add_argument("--all", action="store_true",
                   help="print every message, not just the '#' ones")
   args = ap.parse_args()

   print("connecting to %s:%d ..." % (args.host, args.port))
   sock = socket.create_connection((args.host, args.port), timeout=5.0)
   sock.settimeout(0.5)
   print("connected.  keepalive PING; every %.0f s" % KEEPALIVE_SECONDS)

   if args.ai is not None:
      sock.sendall(("AI%d;" % args.ai).encode("latin-1"))
      print("sent AI%d;" % args.ai)

   started = time.monotonic()
   last_ping = started
   queried = False
   buf = ""
   seen = {}          # command prefix -> most recent full message
   order = []         # first-seen order, so the report reads chronologically
   other = 0

   print("listening for %.0f s (Ctrl-C to stop)" % args.seconds)
   print()

   try:
      while time.monotonic() - started < args.seconds:
         now = time.monotonic()

         # Give the radio a moment to settle after AI before asking it things,
         # so the query answers are not tangled up in the initial push.
         if args.query and not queried and (now - started) > 2.0:
            for q in DISPLAY_QUERIES:
               sock.sendall((q + ";").encode("latin-1"))
               time.sleep(0.05)

            queried = True
            print("--- sent %d '#' queries ---" % len(DISPLAY_QUERIES))

         if now - last_ping >= KEEPALIVE_SECONDS:
            sock.sendall(b"PING;")
            last_ping = now

         try:
            data = sock.recv(65536)
         except socket.timeout:
            continue

         if not data:
            print("*** the radio closed the connection")
            break

         buf += data.decode("latin-1", "replace")
         msgs, buf = split_messages(buf)

         for msg in msgs:
            if msg.startswith("#"):
               # Key on the alphabetic head so '#REF$010' and '#REF$012' are
               # the same setting reported twice, not two findings.
               head = "#"

               for ch in msg[1:]:
                  if ch.isalpha() or ch == "$":
                     head += ch
                  else:
                     break

               if head not in seen:
                  order.append(head)

               seen[head] = msg
               print("  %-10s %s" % (head, msg))
            else:
               other += 1

               if args.all:
                  print("  (cat)      %s" % msg)

   except KeyboardInterrupt:
      print("\ninterrupted")
   finally:
      try:
         sock.close()
      except Exception:
         pass

   print()
   print("=" * 62)
   print("DISPLAY COMMANDS SEEN")
   print("=" * 62)

   if not order:
      print("  none.")
      print("  If this ran without --ai, try --ai 5: the radio pushes state")
      print("  only when auto-info is on, and that is the mode TR4W runs in.")
   else:
      for head in order:
         print("  %-10s last value: %s" % (head, seen[head]))

   print()
   print("  other (non-#) messages: %d" % other)


if __name__ == "__main__":
   main()
