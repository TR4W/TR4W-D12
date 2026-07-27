#!/usr/bin/env python3
"""Kenwood TS-590 CAT simulator -- a virtual radio on a serial port.

Purpose
-------
Exercise TR4W's radio-factory plumbing without hardware.  Most of the bugs found
during the D12 radio migration were in OUR framing, dispatch and state handling
rather than in any radio's protocol -- for example a driver whose frames were read,
logged and then silently dropped because a constructor passed nil, which this kind
of harness would have caught in seconds.

Run it against one half of a virtual null-modem pair (com0com), point TR4W at the
other half, and select "Kenwood TS-590" in the radio dialog.

    python tools/sim_ts590.py COM21            # TR4W then uses COM20

Scope, honestly stated
----------------------
This answers the commands TR4W's TKenwoodSerial driver actually sends, and its IF
response is laid out to match the field offsets that driver PARSES.  It is a test
double for TR4W, NOT a Kenwood conformance model: fields TR4W ignores are filled
plausibly but are not authoritative, and commands TR4W never sends are unhandled.

That distinction matters.  Hamlib's own FT-817 simulator disagrees with hamlib's
FT-817 *driver* (it answers nothing where the driver reads an ack), so a simulator
is good evidence about the program under test and poor evidence about a radio.
Never use this to decide what a real TS-590 does -- use the manual, then a driver
known to work against hardware, and only then a simulator.

Interactive keys (while running)
--------------------------------
    f <hz>   set VFO A frequency, e.g. "f 14025000"
    b <hz>   set VFO B frequency
    m <n>    set mode digit (1 LSB, 2 USB, 3 CW, 4 FM, 5 AM, 6 FSK, 7 CW-R, 9 FSK-R)
    s        toggle split
    r        toggle RIT
    x        toggle XIT
    o <hz>   set RIT/XIT offset (shared register on Kenwood), e.g. "o -1200"
    t        toggle TX/RX
    d        drop the link (stop answering) -- exercises the liveness watchdog
    u        resume answering
    q        quit
"""

import sys
import threading
import time

try:
    import serial                      # pyserial
except ImportError:
    sys.exit("pyserial is required:  python -m pip install pyserial")


class TS590:
    """Radio state plus the CAT command handlers TR4W exercises."""

    def __init__(self):
        self.vfo_a = 14025000
        self.vfo_b = 14030000
        self.rx_vfo = 0                # 0 = A, 1 = B  (Kenwood FR)
        self.tx_vfo = 0                # Kenwood FT; split when != rx_vfo
        self.mode = 3                  # 3 = CW
        self.rit_on = False
        self.xit_on = False
        self.offset = 0                # shared RIT/XIT register, Hz
        self.transmitting = False
        self.answering = True          # 'd'/'u' simulate a dead link

    # -- helpers ----------------------------------------------------------
    @property
    def rx_freq(self):
        return self.vfo_a if self.rx_vfo == 0 else self.vfo_b

    def build_if(self):
        """The IF response, built to satisfy TR4W's ParseIF offsets.

        TR4W indexes from the END (L = length, 1-based):
            3..13   11-digit RX frequency
            L-18    RIT/XIT sign          L-17..L-14  4-digit magnitude
            L-13    RIT on                L-12        XIT on
            L-8     TX/RX                 L-7         mode digit
            L-6     FR (1 = VFO B)        L-4         split

        CRITICAL: the reading thread STRIPS the ';' before dispatching
        (uFactoryRadioBase: "Copy(FSerialBuffer, 1, termPos - 1)"), so ParseIF
        sees L = 37, NOT the 38 characters on the wire.  Getting this wrong shifts
        every field by one -- mode is read out of the TX/RX position and the radio
        window shows no mode at all, which is exactly how this was found.  The
        offsets below are therefore computed for the 37-character string, and the
        self-test at the bottom of this file checks them WITHOUT the terminator.

        Anything TR4W does not read is filled with plausible constants.
        """
        mag = min(abs(self.offset), 9999)
        sign = '-' if self.offset < 0 else '+'
        split = '1' if self.tx_vfo != self.rx_vfo else '0'

        out = (
            'IF'                                   # 1-2
            + '%011d' % self.rx_freq               # 3-13   frequency
            + ' ' * 5                              # 14-18  (ignored)
            + sign                                 # 19     RIT sign      (L-18)
            + '%04d' % mag                         # 20-23  RIT magnitude (L-17..L-14)
            + ('1' if self.rit_on else '0')        # 24     RIT on        (L-13)
            + ('1' if self.xit_on else '0')        # 25     XIT on        (L-12)
            + '0'                                  # 26     memory bank
            + '00'                                 # 27-28  memory channel
            + ('1' if self.transmitting else '0')  # 29     TX/RX         (L-8)
            + str(self.mode)                       # 30     mode          (L-7)
            + str(self.rx_vfo)                     # 31     FR            (L-6)
            + '0'                                  # 32     scan
            + split                                # 33     split         (L-4)
            + '0'                                  # 34     tone
            + '00'                                 # 35-36  tone frequency
            + '0'                                  # 37     shift
        )
        # 37 WITHOUT the terminator -- that is the length TR4W parses against.
        assert len(out) == 37, 'IF body must be 37 chars, got %d' % len(out)
        return out + ';'

    # -- command dispatch -------------------------------------------------
    def handle(self, cmd):
        """cmd is one command WITHOUT its ';'.  Returns the reply, or ''."""
        if not cmd:
            return ''
        head = cmd[:2].upper()
        arg = cmd[2:]

        if head == 'IF':
            return self.build_if()

        if head == 'FA':
            if arg:
                self.vfo_a = int(arg)
                return ''
            return 'FA%011d;' % self.vfo_a

        if head == 'FB':
            if arg:
                self.vfo_b = int(arg)
                return ''
            return 'FB%011d;' % self.vfo_b

        if head == 'MD':
            if arg:
                self.mode = int(arg)
                return ''
            return 'MD%d;' % self.mode

        if head == 'FR':                      # receive VFO
            if arg:
                self.rx_vfo = int(arg)
            return ''
        if head == 'FT':                      # transmit VFO -> split
            if arg:
                self.tx_vfo = int(arg)
            return ''

        if head == 'RT':
            self.rit_on = (arg == '1')
            return ''
        if head == 'XT':
            self.xit_on = (arg == '1')
            return ''
        if head == 'RC':
            self.offset = 0
            return ''
        if head == 'RU':
            self.offset += 10
            return ''
        if head == 'RD':
            self.offset -= 10
            return ''

        if head == 'TX':
            self.transmitting = True
            return ''
        if head == 'RX':
            self.transmitting = False
            return ''

        if head == 'UP':
            self.vfo_a += 1000
            return ''
        if head == 'DN':
            self.vfo_a -= 1000
            return ''

        if head == 'KS':                      # CW speed
            return '' if arg else 'KS030;'

        return None                            # unknown -> reported, not answered


def reader(port, radio, stop):
    buf = ''
    while not stop.is_set():
        try:
            data = port.read(64)
        except Exception as exc:               # port closed underneath us
            if not stop.is_set():
                print('\n[read error] %s' % exc)
            return
        if not data:
            continue
        buf += data.decode('ascii', 'replace')
        while ';' in buf:
            cmd, buf = buf.split(';', 1)
            cmd = cmd.strip()
            if not cmd:
                continue
            reply = radio.handle(cmd)
            if reply is None:
                print('  <- %-14s (unhandled)' % (cmd + ';'))
                continue
            if not radio.answering:
                print('  <- %-14s [link down, no reply]' % (cmd + ';'))
                continue
            if reply:
                port.write(reply.encode('ascii'))
                print('  <- %-14s -> %s' % (cmd + ';', reply))
            else:
                print('  <- %-14s (accepted)' % (cmd + ';'))


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    portname = sys.argv[1]
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 4800

    radio = TS590()
    # TR4W opens Kenwood serial as 8N2 by default (RadioParametersArray).
    port = serial.Serial(portname, baud, bytesize=8, parity='N',
                         stopbits=2, timeout=0.2)
    print('TS-590 simulator on %s @ %d 8N2.  "q" to quit, "?" for keys.' % (portname, baud))
    print('VFO A %d   VFO B %d   mode %d' % (radio.vfo_a, radio.vfo_b, radio.mode))

    stop = threading.Event()
    t = threading.Thread(target=reader, args=(port, radio, stop), daemon=True)
    t.start()

    try:
        while True:
            line = sys.stdin.readline()
            if not line:
                break
            line = line.strip()
            if not line:
                continue
            key, _, val = line.partition(' ')
            key = key.lower()
            if key == 'q':
                break
            elif key == '?':
                print(__doc__[__doc__.index('Interactive keys'):])
            elif key == 'f' and val:
                radio.vfo_a = int(val); print('   VFO A = %d' % radio.vfo_a)
            elif key == 'b' and val:
                radio.vfo_b = int(val); print('   VFO B = %d' % radio.vfo_b)
            elif key == 'm' and val:
                radio.mode = int(val); print('   mode = %d' % radio.mode)
            elif key == 'o' and val:
                radio.offset = int(val); print('   offset = %d Hz' % radio.offset)
            elif key == 's':
                radio.tx_vfo = 1 - radio.rx_vfo if radio.tx_vfo == radio.rx_vfo else radio.rx_vfo
                print('   split = %s' % (radio.tx_vfo != radio.rx_vfo))
            elif key == 'r':
                radio.rit_on = not radio.rit_on; print('   RIT = %s' % radio.rit_on)
            elif key == 'x':
                radio.xit_on = not radio.xit_on; print('   XIT = %s' % radio.xit_on)
            elif key == 't':
                radio.transmitting = not radio.transmitting
                print('   TX = %s' % radio.transmitting)
            elif key == 'd':
                radio.answering = False; print('   link DOWN -- radio will not answer')
            elif key == 'u':
                radio.answering = True; print('   link UP')
            else:
                print('   ? unknown key %r' % key)
    except KeyboardInterrupt:
        pass
    finally:
        stop.set()
        time.sleep(0.3)
        port.close()
        print('closed %s' % portname)


if __name__ == '__main__':
    main()
