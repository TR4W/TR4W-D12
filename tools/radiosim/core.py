"""Shared machinery for the TR4W radio simulators.

Every simulated radio needs the same things -- a bit of state, a transport, a way
to cut a byte stream into frames, and a console to poke it from.  Only two things
actually differ per radio: HOW frames are delimited and WHAT the commands mean.
Those are the two hooks a personality implements; everything else lives here.

    core.py        state, transports, framers, console, runner   <- this file
    kenwood.py     TS-590 / TS-890 / TS-990   (';'-terminated ASCII)
    elecraft.py    K4                          (';'-terminated ASCII)
    icom.py        IC-7300 / IC-7000           (CI-V binary)

SCOPE -- read this before trusting a simulator about a radio.  These are test
doubles for TR4W: they answer what TR4W's drivers send, and their responses are
laid out to match what those drivers PARSE.  They are not conformance models of
the radios.  Hamlib's own FT-817 simulator contradicts hamlib's FT-817 driver, so
treat any simulator as evidence about the program under test and nothing more:
manual first, a driver proven against hardware second, simulator last.
"""

import sys
import threading
import time


# ---------------------------------------------------------------------------
# Radio state -- what every simulated rig has
# ---------------------------------------------------------------------------

class RadioState(object):
    def __init__(self, vfo_a=14025000, vfo_b=14030000, mode='CW'):
        self.vfo_a = vfo_a
        self.vfo_b = vfo_b
        self.rx_vfo = 0          # 0 = A, 1 = B
        self.tx_vfo = 0          # differs from rx_vfo when split
        self.mode = mode         # canonical name; personalities map to their codes
        self.rit_on = False
        self.xit_on = False
        self.offset = 0          # RIT/XIT offset in Hz
        self.transmitting = False
        self.answering = True    # 'd'/'u' -- simulate a rig that stops replying

    @property
    def rx_freq(self):
        return self.vfo_a if self.rx_vfo == 0 else self.vfo_b

    @property
    def split(self):
        return self.tx_vfo != self.rx_vfo

    def toggle_split(self):
        self.tx_vfo = (1 - self.rx_vfo) if not self.split else self.rx_vfo

    def summary(self):
        return ('A=%d B=%d rx=%s mode=%s split=%s rit=%s xit=%s off=%d tx=%s'
                % (self.vfo_a, self.vfo_b, 'AB'[self.rx_vfo], self.mode,
                   self.split, self.rit_on, self.xit_on, self.offset,
                   self.transmitting))


# ---------------------------------------------------------------------------
# Transports -- a COM port or a TCP listener, same three methods
# ---------------------------------------------------------------------------

class SerialTransport(object):
    """One half of a virtual pair (com0com / VSP Manager), or real hardware."""

    def __init__(self, port, baud=4800, stopbits=2):
        try:
            import serial
        except ImportError:
            raise SystemExit('pyserial is required:  python -m pip install pyserial')
        self._port = serial.Serial(port, baud, bytesize=8, parity='N',
                                   stopbits=stopbits, timeout=0.2)
        self.description = '%s @ %d 8N%d' % (port, baud, stopbits)

    def read(self, n=256):
        return self._port.read(n)

    def write(self, data):
        self._port.write(data)

    def close(self):
        self._port.close()


# ---------------------------------------------------------------------------
# Framers -- turn a byte stream into whole commands
# ---------------------------------------------------------------------------

class TerminatorFramer(object):
    """ASCII CAT: commands end with a terminator, normally ';'.

    NOTE FOR PERSONALITY AUTHORS: TR4W's reading thread STRIPS the terminator
    before the driver sees a command (uFactoryRadioBase: "Copy(FSerialBuffer, 1,
    termPos - 1)").  Drivers that index fields from the END of the string -- the
    Kenwood IF response is the obvious one -- therefore parse a string ONE
    CHARACTER SHORTER than what went over the wire.  Getting that wrong shifts
    every such field by one and is very hard to spot: the fields at fixed offsets
    (frequency) stay perfect while the rest quietly land on their neighbours.
    """

    def __init__(self, terminator=b';'):
        self.terminator = terminator
        self._buf = b''

    def feed(self, data):
        self._buf += data
        out = []
        while self.terminator in self._buf:
            frame, self._buf = self._buf.split(self.terminator, 1)
            frame = frame.strip()
            if frame:
                out.append(frame)
        return out

    def render(self, frame):
        return frame if isinstance(frame, bytes) else frame.encode('ascii')


class CivFramer(object):
    """Icom CI-V: FE FE <to> <from> ... FD.

    Binary and byte-exact -- no encoding, no terminator character, and payload
    bytes can be anything below FD.
    """

    PREAMBLE = b'\xFE\xFE'
    END = b'\xFD'

    def __init__(self):
        self._buf = b''

    def feed(self, data):
        self._buf += data
        out = []
        while True:
            start = self._buf.find(self.PREAMBLE)
            if start < 0:
                # nothing usable; keep only a possible partial preamble
                self._buf = self._buf[-1:]
                break
            end = self._buf.find(self.END, start)
            if end < 0:
                self._buf = self._buf[start:]
                break
            out.append(self._buf[start:end + 1])
            self._buf = self._buf[end + 1:]
        return out

    def render(self, frame):
        return frame


# ---------------------------------------------------------------------------
# Console + runner
# ---------------------------------------------------------------------------

COMMON_KEYS = """\
  f <hz>   VFO A frequency        r        toggle RIT
  b <hz>   VFO B frequency        x        toggle XIT
  m <name> mode (CW/USB/LSB/...)  o <hz>   RIT/XIT offset, e.g. o -1200
  s        toggle split           t        toggle TX
  d        drop the link (stop answering)  u  resume
  ?        show state             q        quit
"""


def _reader(transport, personality, stop):
    while not stop.is_set():
        try:
            data = transport.read()
        except Exception as exc:
            if not stop.is_set():
                print('\n[read error] %s' % exc)
            return
        if not data:
            continue
        for frame in personality.framer.feed(data):
            shown = personality.show(frame)
            reply = personality.handle(frame)
            if reply is None:
                print('  <- %-22s (unhandled)' % shown)
                continue
            if not personality.state.answering:
                print('  <- %-22s [link down]' % shown)
                continue
            if reply:
                transport.write(personality.framer.render(reply))
                print('  <- %-22s -> %s' % (shown, personality.show(reply)))
            else:
                print('  <- %-22s (accepted)' % shown)


def run(personality, transport):
    st = personality.state
    print('%s simulator on %s.  "?" for keys, "q" to quit.'
          % (personality.name, transport.description))
    print('   %s' % st.summary())

    stop = threading.Event()
    threading.Thread(target=_reader, args=(transport, personality, stop),
                     daemon=True).start()
    try:
        while True:
            line = sys.stdin.readline()
            if not line:
                break
            key, _, val = line.strip().partition(' ')
            key = key.lower()
            if key == 'q':
                break
            elif key == '?':
                print(COMMON_KEYS + '   ' + st.summary())
            elif key == 'f' and val:
                st.vfo_a = int(val)
            elif key == 'b' and val:
                st.vfo_b = int(val)
            elif key == 'm' and val:
                st.mode = val.upper()
            elif key == 'o' and val:
                st.offset = int(val)
            elif key == 's':
                st.toggle_split()
            elif key == 'r':
                st.rit_on = not st.rit_on
            elif key == 'x':
                st.xit_on = not st.xit_on
            elif key == 't':
                st.transmitting = not st.transmitting
            elif key == 'd':
                st.answering = False
                print('   link DOWN')
                continue
            elif key == 'u':
                st.answering = True
                print('   link UP')
                continue
            elif key:
                print('   ? unknown key %r' % key)
                continue
            print('   %s' % st.summary())
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        time.sleep(0.3)
        transport.close()
        print('closed')
