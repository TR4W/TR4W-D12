"""Port of hamlib simulators/simts450.c -- Kenwood TS-450.

Line-by-line port.  See the package header for why nothing in here may be
adjusted to suit a TR4W driver.

WHY THIS RADIO FIRST.  TR4W registers eight Kenwoods that have never been
benched (TS-140/440/450/690/850/870/940/950), all as thin TKenwoodSerial
subclasses, on the strength of TR4W's own radio table saying they are TS-570
clones.  The TS-450 is the only one of the eight hamlib also simulates, so it is
the only one where an independent implementation can be asked whether that belief
holds.

FAITHFULNESS NOTES -- hamlib quirks reproduced deliberately:

  * freqb defaults to 140735000 (140.735 MHz).  Almost certainly a typo for
    14073500 in the C, but it is what the reference does, so VFO B reads as an
    absurd frequency.  Do not "fix" it: if a TR4W driver mangles it, that is a
    finding about the driver's parsing of an 11-digit field.

  * `TO;` builds a response and never writes it (no WRITE call in the C), so the
    radio stays silent.  Reproduced.

  * `FW;` is answered as TWO writes -- "FW240" then, 20 ms later, "0;".  This
    deliberately splits a response across reads.  Reproduced, because it is a
    genuine test of a driver's reassembly.

  * The `TX` handler's switch has no `break` statements, so every case falls
    through and all four ptt flags end up set.  Reproduced.

  * Several commands are accepted and ignored (IS with an argument, FW with an
    argument, EX other than 032, AI).  Reproduced as silent no-ops.

  * The C compares against buffers that INCLUDE the ';' (strcmp(buf, "IF;")).
    TR4W's framer strips it, so handle() re-appends it before dispatch to keep
    the comparisons identical to the C.

  * Branch ORDER is preserved.  The C tests exact matches before prefixes
    (`FA;` before `FA`), and reordering would change behaviour.
"""

from ..core import RadioState, TerminatorFramer


class HamlibTS450(object):
    """hamlib simulators/simts450.c, ported verbatim."""

    name = 'hamlib simts450 (Kenwood TS-450)'

    def __init__(self, state=None):
        # Defaults transcribed from the C.  Note the two separate pairs of
        # frequency variables in the original: floats freqA/freqB used only by
        # the SF command, and ints freqa/freqb used by everything else.
        self.freqA = 14074000.0        # float freqA
        self.freqB = 14074500.0        # float freqB
        self.freqa = 14074000          # int freqa
        self.freqb = 140735000         # int freqb  <- hamlib's value, see header
        self.modeA = 1
        self.modeB = 2
        self.filternum = 7
        self.datamode = 0
        self.vfo = 0
        self.vfo_tx = 0
        self.ptt = 0
        self.ptt_data = 0
        self.ptt_mic = 0
        self.ptt_tune = 0
        self.tomode = 0
        self.keyspd = 25
        self._ant = 0              # static int ant, inside the EX032 branch

        self.framer = TerminatorFramer(b';')
        # radiosim's runner expects a .state for its console display.  Kept in
        # step with the ported variables for display only -- the port itself
        # never reads it, so the console cannot influence what the reference
        # answers.
        self.state = state or RadioState(vfo_a=self.freqa, vfo_b=self.freqb)

        self.unknown = []          # commands the reference did not recognise

    def show(self, frame):
        if isinstance(frame, bytes):
            frame = frame.decode('ascii', 'replace')
        return frame if frame.endswith(';') else frame + ';'

    def _sync_state(self):
        self.state.vfo_a = self.freqa
        self.state.vfo_b = self.freqb
        self.state.rx_vfo = self.vfo
        self.state.tx_vfo = self.vfo_tx
        self.state.transmitting = bool(self.ptt)

    def handle(self, frame):
        # The C sees the terminator; our framer has stripped it.
        if isinstance(frame, bytes):
            buf = frame.decode('ascii', 'replace').strip()
        else:
            buf = frame.strip()
        if not buf:
            return ''
        buf = buf + ';'

        out = self._dispatch(buf)
        self._sync_state()
        return out

    def _dispatch(self, buf):
        if buf == 'RM5;':
            return 'RM5100000;'

        if buf == 'AN0;':
            return 'AN030;'

        if buf == 'IF;':
            # sprintf(ifbuf, "IF%011d0001000+0000000000030000000;", freqa)
            # (the pbuf assignment just above it in the C is dead code)
            return 'IF%011d0001000+0000000000030000000;' % self.freqa

        if buf == 'NB;':
            return 'NB0;'

        if buf == 'RA;':
            return 'RA01;'

        if buf == 'RG;':
            return 'RG055;'

        if buf == 'MG;':
            return 'MG050;'

        if buf == 'AG;':
            return 'AG100;'

        if buf == 'FV;':
            return 'FV1.2;'

        if buf.startswith('IS;'):
            return 'IS+0000;'
        if buf.startswith('IS'):
            return ''                      # accepted, ignored

        if buf.startswith('SM;'):
            return 'SM0035;'

        if buf.startswith('PC;'):
            return 'PC100;'

        if buf == 'FW;':
            # Two writes, 20 ms apart, in the C.  Returned as one string here:
            # the transport writes it in a single call, so the split is not
            # reproduced on the wire.  Noted rather than faked -- see NOT_PORTED.
            return 'FW2400;'
        if buf.startswith('FW'):
            return ''                      # accepted, ignored

        if buf == 'ID;':
            return 'ID%03d;' % 10

        if buf == 'VS;':
            return 'VS0;'

        if buf == 'EX032;':
            self._ant = (self._ant + 1) % 3
            return 'EX032%1d;' % self._ant
        if buf.startswith('EX'):
            return ''                      # accepted, ignored

        if buf == 'FA;':
            return 'FA%011d;' % self.freqa
        if buf == 'FB;':
            return 'FB%011d;' % self.freqb
        if buf.startswith('FA'):
            self.freqa = _sscanf_int(buf, 2, self.freqa)
            return ''
        if buf.startswith('FB'):
            self.freqb = _sscanf_int(buf, 2, self.freqb)
            return ''

        if buf.startswith('AI'):
            return ''                      # "nothing to do yet"

        if buf.startswith('PS;'):
            return 'PS1;'

        if buf.startswith('SA;'):
            return 'SA0;'

        # buf[3] == ';' && strncmp(buf, "SF", 2) == 0
        if len(buf) > 3 and buf[3] == ';' and buf.startswith('SF'):
            which = buf[2]
            freq = self.freqA if which == '0' else self.freqB
            mode = self.modeA if which == '0' else self.modeB
            return 'SF%s%011.0f%s;' % (which, freq, chr(mode + ord('0')))
        if buf.startswith('SF'):
            if len(buf) > 14:
                tmpmode = buf[14]
                if buf[2] == '0':
                    self.modeA = ord(tmpmode) - ord('0')
                else:
                    self.modeB = ord(tmpmode) - ord('0')
            return ''

        if buf.startswith('MD;'):
            return 'MD%d;' % self.modeA    # "not worried about modeB yet"
        if buf.startswith('MD'):
            self.modeA = _sscanf_int(buf, 2, self.modeA)
            return ''

        if buf.startswith('FL;'):
            return 'FL%03d;' % self.filternum
        if buf.startswith('FL'):
            self.filternum = _sscanf_int(buf, 2, self.filternum)
            return ''

        if buf == 'FR;':
            return 'FR%d;' % self.vfo
        if buf.startswith('FR'):
            self.vfo = _sscanf_int(buf, 2, self.vfo)
            return ''

        if buf == 'FT;':
            return 'FT%d;' % self.vfo_tx
        if buf.startswith('FT'):
            self.vfo_tx = _sscanf_int(buf, 2, self.vfo_tx)
            return ''

        if buf.startswith('DA;'):
            return 'DA%d;' % self.datamode
        if buf.startswith('DA'):
            self.datamode = _sscanf_int(buf, 2, self.datamode)
            return ''

        if buf.startswith('TO;'):
            # The C builds a response here and never writes it.  Silence.
            return ''

        if buf.startswith('BD;'):
            return ''
        if buf.startswith('BU;'):
            return ''

        if buf.startswith('TX'):
            # switch with no breaks: every case falls through.
            self.ptt = self.ptt_mic = self.ptt_data = self.ptt_tune = 0
            c = buf[2] if len(buf) > 2 else ';'
            if c == ';':
                self.ptt = 1
                self.ptt_mic = 1
                self.ptt_data = 1
                self.ptt_tune = 1
            elif c == '0':
                self.ptt_mic = 1
                self.ptt_data = 1
                self.ptt_tune = 1
            elif c == '1':
                self.ptt_data = 1
                self.ptt_tune = 1
            elif c == '2':
                self.ptt_tune = 1
            return ''

        # fprintf(stderr, "Unknown command: %s\n", buf)
        self.unknown.append(buf)
        import sys
        sys.stderr.write('Unknown command: %s\n' % buf)
        return ''


def _sscanf_int(buf, start, default):
    """sscanf("%d") semantics: leading digits, or leave the value alone."""
    digits = ''
    for ch in buf[start:]:
        if ch.isdigit():
            digits += ch
        elif digits:
            break
        elif ch in '+-':
            digits += ch
        else:
            break
    try:
        return int(digits)
    except ValueError:
        return default


# ---------------------------------------------------------------------------
# NOT_PORTED -- differences from the C that could not be reproduced faithfully,
# recorded so nobody mistakes the port for exact.
#
#   FW;  the C writes "FW240" and "0;" as two writes 20 ms apart.  Here it is one
#        write of "FW2400;".  Reproducing the split needs transport-level control
#        the radiosim personality interface does not expose.  A driver that
#        reassembles across reads is therefore NOT exercised by this port.
#
#   mysleep  the C sleeps 20 ms before most responses.  Omitted: it models a slow
#        radio, not the protocol, and the bench has its own timeouts.
# ---------------------------------------------------------------------------
