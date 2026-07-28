"""Yaesu ASCII CAT personality -- FT-991 and the FTDX-10 family.

Answers what TR4W's TYaesuSerial driver sends: IF;OI;FT;TX; every 100 ms, plus the
sets it issues (FA/FB/MD0n/FT2/FT3/RT/XT/RC/RU/RD/TX/RX/UP/DN/KS/PB).

GROUNDING -- read before changing a field position.

The IF/OI field offsets here are the ones TR4W's BENCH-PROVEN legacy path reads
(uRadioPolling.GetVFOInfoForYaesuType3/Type5, unchanged since the D7 tree):

    pos 1-2    'IF' / 'OI'
    pos 6-14   frequency, 9 digits        <- 9 not 8; ny4i Issue #218
    pos 15-19  clarifier, sign + 4 digits
    pos 20     RIT on/off
    pos 21     XIT on/off
    pos 22     mode character

Everything else in the response is FILLER here, and is marked as such below.  The
Yaesu CAT manual assigns those bytes (memory channel, CTCSS, tone, shift), but TR4W
has never read them, so this simulator does not pretend to know their values -- it
emits placeholders rather than inventing plausible-looking data that could later be
mistaken for evidence about a real radio.

LENGTH: 27-character body + ';' = 28 bytes on the wire, which is what the legacy
poller's ReadFromCOMPort(28, rig) expects.  The factory's reading thread STRIPS the
';' before the driver sees it, so ParseIFResponse works on 27 characters.  Size the
BODY, not the wire string -- the Kenwood personality was once built to the wire
length and every end-relative field shifted by one, which cost a debugging session
(see kenwood.build_kenwood_if).  Here the fields are START-relative so an off-by-one
in the tail would go unnoticed; the assertion pins it anyway.
"""

from .core import RadioState, TerminatorFramer

# Mode character at IF position 22.
#
# The FT-991 (legacy "Type3") and the FTDX-10 (legacy "Type5") disagree on exactly
# one character, which is the entire reason TR4W has a separate FT-991 class:
#
#     'E'   FT-991 -> C4FM (System Fusion)      FTDX-10 -> PSK31
#     'F'   FT-991 -> not defined               FTDX-10 -> DATA-FM
#
# Both maps are transcribed from uRadioPolling, not guessed.
MODE_TYPE3 = {'1': 'LSB', '2': 'USB', '3': 'CW', '4': 'FM', '5': 'AM',
              '6': 'RTTY-R', '7': 'CW-R', '8': 'DATA-R', '9': 'RTTY',
              'A': 'DATA-FM', 'B': 'FM-N', 'C': 'DATA', 'D': 'AM-N',
              'E': 'C4FM'}

MODE_TYPE5 = {'1': 'LSB', '2': 'USB', '3': 'CW', '4': 'FM', '5': 'AM',
              '6': 'RTTY-R', '7': 'CW-R', '8': 'DATA-R', '9': 'RTTY',
              'A': 'DATA-FM', 'B': 'FM-N', 'C': 'DATA', 'D': 'AM-N',
              'E': 'PSK31', 'F': 'DATA-FM'}


def build_yaesu_if(head, freq, mode_char, offset, rit_on, xit_on):
    """One IF;/OI; response.  `head` is 'IF' (VFO A) or 'OI' (VFO B)."""
    mag = min(abs(offset), 9999)
    body = (
        head                                        # 1-2
        + '000'                                     # 3-5    memory ch (filler)
        + '%09d' % freq                             # 6-14   frequency
        + ('-' if offset < 0 else '+')              # 15     clarifier sign
        + '%04d' % mag                              # 16-19  clarifier magnitude
        + ('1' if rit_on else '0')                  # 20     RIT
        + ('1' if xit_on else '0')                  # 21     XIT
        + mode_char                                 # 22     mode
        + '0'                                       # 23     VFO/memory (filler)
        + '0'                                       # 24     CTCSS      (filler)
        + '00'                                      # 25-26  tone       (filler)
        + '0'                                       # 27     shift      (filler)
    )
    assert len(body) == 27, 'IF body must be 27 chars, got %d' % len(body)
    return body + ';'


class Yaesu(object):
    """FT-991 by default; pass type5=True for the FTDX-10 mode map."""

    def __init__(self, name='Yaesu FT-991', state=None, type5=False):
        self.name = name
        self.state = state or RadioState()
        self.framer = TerminatorFramer(b';')
        self.modes = MODE_TYPE5 if type5 else MODE_TYPE3
        self.to_char = dict((v, k) for k, v in self.modes.items())
        self.mode_b = 'USB'          # OI; reports VFO B, which carries its own mode

    def show(self, frame):
        if isinstance(frame, bytes):
            frame = frame.decode('ascii', 'replace')
        return frame if frame.endswith(';') else frame + ';'

    def _mode_char(self, name):
        # 'C4FM' has no counterpart in the Type5 map and vice versa; fall back to
        # CW rather than raising, so a mismatched pairing degrades visibly instead
        # of killing the simulator mid-session.
        return self.to_char.get(name, '3')

    def handle(self, frame):
        cmd = frame.decode('ascii', 'replace').strip()
        if not cmd:
            return ''
        st = self.state
        head, arg = cmd[:2].upper(), cmd[2:]

        if head == 'IF':
            return build_yaesu_if('IF', st.vfo_a, self._mode_char(st.mode),
                                  st.offset, st.rit_on, st.xit_on)
        if head == 'OI':
            # VFO B needs its OWN command on these radios -- IF; cannot return
            # both, which is why the driver polls IF;OI; rather than one query.
            return build_yaesu_if('OI', st.vfo_b, self._mode_char(self.mode_b),
                                  st.offset, st.rit_on, st.xit_on)

        if head == 'FA':
            if arg:
                st.vfo_a = int(arg)
                return ''
            return 'FA%09d;' % st.vfo_a
        if head == 'FB':
            if arg:
                st.vfo_b = int(arg)
                return ''
            return 'FB%09d;' % st.vfo_b

        if head == 'MD':
            # Yaesu MD carries an extra VFO byte: MD0n; to set, MD0; to query.
            # (Kenwood's is MDn; -- a real difference between the dialects.)
            if len(arg) >= 2:
                st.mode = self.modes.get(arg[1].upper(), st.mode)
                return ''
            return 'MD0%s;' % self._mode_char(st.mode)

        if head == 'FT':
            # SET is FT3; (split on) / FT2; (split off).  QUERY replies with the
            # TX VFO, 0 or 1 -- the driver treats any non-'0' as split.
            if arg:
                if arg[0] == '3':
                    if not st.split:
                        st.toggle_split()
                elif arg[0] == '2':
                    if st.split:
                        st.toggle_split()
                return ''
            return 'FT%d;' % st.tx_vfo

        if head == 'TX':
            if arg:
                st.transmitting = (arg[0] != '0')
                return ''
            return 'TX%d;' % (1 if st.transmitting else 0)
        if head == 'RX':
            st.transmitting = False
            return ''

        if head == 'RT':
            st.rit_on = (arg[:1] == '1')
            return ''
        if head == 'XT':
            st.xit_on = (arg[:1] == '1')
            return ''
        if head == 'RC':
            st.offset = 0
            return ''
        if head == 'RU':
            st.offset += 10
            return ''
        if head == 'RD':
            st.offset -= 10
            return ''

        if head == 'UP':
            st.vfo_a += 1000
            return ''
        if head == 'DN':
            st.vfo_a -= 1000
            return ''

        if head == 'KS':
            if arg:
                return ''
            return 'KS030;'

        if head == 'PB':                 # message-memory playback -- no reply
            return ''

        return None
