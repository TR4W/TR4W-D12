"""Kenwood TS-890S / TS-990S personality.

DELIBERATELY SEPARATE from kenwood.Kenwood.  These radios are driven by a
different TR4W class (TKenwoodTS890Radio, not TKenwoodSerial) whose command set
barely overlaps: it uses discrete queries -- FA, FB, FR, FT, OM, RT, XT, PS, ID,
KS, RF, TB.  Reusing the TS-590 personality produced nothing but "PS; (unhandled)",
which is what prompted this.

IF differs BETWEEN the two models, and this docstring used to claim flatly that it
"does not exist on these radios" -- half right, and the half that was wrong was
mine, not evidence.  What is actually established:

  * TS-990S: absent from the command set (confirmed by NY4I).  The simulator
    answers '?;' -- Kenwood's rejection for an unsupported command -- rather than
    fabricating a status string.
  * TS-890S: undocumented and supplanted by SF, but still ANSWERED for legacy
    software.  hamlib's own TS-890 simulator implements it under #if LEGACY and
    documents the field layout (source supplied by NY4I).

Either way TR4W's TKenwoodTS890Radio neither sends nor parses IF, so this only
matters if a future driver change reaches for it.

Two quirks that matter for a faithful double:

  * PS; is a KEEPALIVE, not a query about power.  The driver sends it on a timer
    so the radio's LAN idle timeout does not drop the connection, and expects
    PS1;.  It keeps being sent over serial, where it is harmless.
  * The OM reply's VFO byte is OPERATING-VFO-RELATIVE: '0' means the VFO
    currently selected by FR, '1' means the other one -- NOT a fixed A/B.  The
    driver has a comment about getting this wrong and swapping the per-VFO modes
    after an A/B change, so the simulator reproduces the radio's actual behaviour
    rather than the intuitive one.  A simulator that answered a fixed A/B would
    silently hide that whole class of bug.
"""

from .core import RadioState, TerminatorFramer
from .kenwood import build_kenwood_if

MODE_TO_NUM = {'LSB': '1', 'USB': '2', 'CW': '3', 'FM': '4', 'AM': '5',
               'FSK': '6', 'CWR': '7', 'FSKR': '9'}
NUM_TO_MODE = dict((v, k) for k, v in MODE_TO_NUM.items())


class KenwoodTS890(object):

    def __init__(self, name='Kenwood TS-890S', ident='024', state=None,
                 legacy_if=True):
        self.name = name
        # ID024 = TS-890S, ID022 = TS-990S (the latter supplied by NY4I).
        # NOTE: TKenwoodTS890Radio only recognises ID024 and logs
        # "Unexpected ID response" for anything else, so a TS-990 answering
        # honestly WILL produce that warning.  That is the point -- it surfaces a
        # real gap in the driver rather than hiding it behind a simulator that
        # impersonates a TS-890.  ident=None suppresses the reply entirely.
        self.ident = ident
        self.state = state or RadioState()
        self.framer = TerminatorFramer(b';')
        self.mode_b = 'USB'          # the VFOs can carry different modes
        # IF is UNDOCUMENTED on the TS-890S -- supplanted by SF -- but still
        # answered for legacy software (hamlib's TS-890 simulator documents the
        # format and notes it reflects a real radio).  NY4I confirmed it is absent
        # from the TS-990S command set, so that model rejects it instead.
        self.legacy_if = legacy_if
        self.ai_level = 0            # set by AI<n>; the driver sends AI2
        self._last_push = None       # snapshot for change detection

    def is_heartbeat(self, frame):
        # PS; every 5 seconds, forever.  Answered and counted, never printed --
        # otherwise it scrolls the interesting traffic off the screen.
        return frame.strip().upper().startswith(b'PS')

    def show(self, frame):
        if isinstance(frame, bytes):
            frame = frame.decode('ascii', 'replace')
        return frame if frame.endswith(';') else frame + ';'

    # -- AI2 auto-information push ----------------------------------------
    # This radio is PUSH-driven, and getting that wrong makes the simulator
    # useless: TKenwoodTS890Radio.PollRadioState sends nothing but PS; as a
    # keepalive ("AI2 pushes everything else, so this is keepalive only -- no
    # real polling"), so without unsolicited output the operator could change
    # frequency here all day and TR4W's display would never move.
    #
    # Only the messages the driver actually PARSES are pushed.  IF is not among
    # them and never will be: it is not in these radios' command set at all.
    def _snapshot(self):
        st = self.state
        return (st.vfo_a, st.vfo_b, st.rx_vfo, st.tx_vfo, st.mode, self.mode_b,
                st.rit_on, st.xit_on, st.transmitting, st.split)

    def pending(self):
        if self.ai_level < 1:
            return []
        now = self._snapshot()
        if now == self._last_push:
            return []
        was = self._last_push
        self._last_push = now
        st = self.state
        out = []
        if was is None:
            return []                       # first call just establishes a baseline
        if now[0] != was[0]:
            out.append('FA%011d;' % st.vfo_a)
        if now[1] != was[1]:
            out.append('FB%011d;' % st.vfo_b)
        if now[2] != was[2]:
            out.append('FR%d;' % st.rx_vfo)
        if now[3] != was[3]:
            out.append('FT%d;' % st.tx_vfo)
        if now[4] != was[4] or now[5] != was[5] or now[2] != was[2]:
            # Modes are reported RELATIVE to the operating VFO -- same quirk as
            # the OM query, so a VFO change re-reports both.
            out.append('OM0%s;' % MODE_TO_NUM.get(self._mode_of(st.rx_vfo), '3'))
            out.append('OM1%s;' % MODE_TO_NUM.get(self._mode_of(1 - st.rx_vfo), '3'))
        if now[6] != was[6]:
            out.append('RT%d;' % (1 if st.rit_on else 0))
        if now[7] != was[7]:
            out.append('XT%d;' % (1 if st.xit_on else 0))
        if now[8] != was[8]:
            out.append('TX0;' if st.transmitting else 'RX0;')
        if now[9] != was[9]:
            out.append('TB%d;' % (1 if st.split else 0))
        return out

    def _mode_of(self, vfo):
        return self.state.mode if vfo == 0 else self.mode_b

    def _set_mode_of(self, vfo, name):
        if vfo == 0:
            self.state.mode = name
        else:
            self.mode_b = name

    def handle(self, frame):
        cmd = frame.decode('ascii', 'replace').strip()
        if not cmd:
            return ''
        st = self.state
        head, arg = cmd[:2].upper(), cmd[2:]

        if head == 'PS':                       # keepalive -- MUST be answered
            return 'PS1;'

        if head == 'IF':
            if not self.legacy_if:
                return '?;'          # TS-990S: not in the command set
            # Legacy-but-real on the TS-890S.  Same field layout as the rest of
            # the Kenwood family, which hamlib's own TS-890 simulator corroborates
            # independently -- 37-character body once the ';' is stripped.
            return build_kenwood_if(self.state)

        if head == 'ID':
            return ('ID%s;' % self.ident) if self.ident else ''

        if head == 'FA':
            if arg:
                st.vfo_a = int(arg)
                return ''
            return 'FA%011d;' % st.vfo_a

        if head == 'FB':
            if arg:
                st.vfo_b = int(arg)
                return ''
            return 'FB%011d;' % st.vfo_b

        if head == 'FR':                       # operating (RX) VFO
            if arg:
                st.rx_vfo = int(arg[0])
                return ''
            return 'FR%d;' % st.rx_vfo

        if head == 'FT':                       # transmit VFO
            if arg:
                st.tx_vfo = int(arg[0])
                # Split needs NO assignment here: RadioState.split is DERIVED,
                # tx_vfo != rx_vfo.  A TX VFO different from the RX VFO IS split,
                # so the radio reports it via TB on the next push and TR4W's
                # Split() -- which sends only FT, the D7 behaviour reported
                # working on hardware -- is seen.
                #
                # This was once a second, hand-maintained boolean sitting beside
                # the derived one.  It drifted immediately: the console 's' key
                # moves tx_vfo through RadioState, so the status line read
                # split=True while the duplicate stayed False and no TB was ever
                # pushed.  NY4I hit it within minutes.  One fact, one place.
                #
                # UNVERIFIED against a real TS-890: the command reference gives TB
                # as the explicit split flag and says nothing about FT implying
                # it.  If the bench shows FT alone does NOT set split, this model
                # is wrong AND TR4W's Split() needs to send TB.
                return ''
            return 'FT%d;' % st.tx_vfo

        if head == 'OM':
            # P1 is RELATIVE: '0' = operating VFO, '1' = the other one.
            if arg:
                rel = arg[0]
                physical = st.rx_vfo if rel == '0' else 1 - st.rx_vfo
                if len(arg) > 1:               # a set
                    self._set_mode_of(physical, NUM_TO_MODE.get(arg[1], 'CW'))
                    return ''
                return 'OM%s%s;' % (rel, MODE_TO_NUM.get(self._mode_of(physical), '3'))
            return ''

        if head == 'RT':
            if arg:
                st.rit_on = (arg[0] == '1')
                return ''
            return 'RT%d;' % (1 if st.rit_on else 0)

        if head == 'XT':
            if arg:
                st.xit_on = (arg[0] == '1')
                return ''
            return 'XT%d;' % (1 if st.xit_on else 0)

        if head == 'RC':
            st.offset = 0
            return ''
        if head == 'RU':
            st.offset += 10
            return ''
        if head == 'RD':
            st.offset -= 10
            return ''

        if head == 'TX':
            st.transmitting = True
            return 'TX0;'
        if head == 'RX':
            st.transmitting = False
            return 'RX0;'

        if head == 'KS':
            if arg:
                return ''
            return 'KS030;'

        if head == 'UP':
            st.vfo_a += 1000
            return ''
        if head == 'DN':
            st.vfo_a -= 1000
            return ''

        # Accepted silently -- the driver sends these but a reply is optional, and
        # answering with invented data would be worse than saying nothing:
        #   AI2   auto-information level        FL0n  roofing filter selection
        #   KY    CW keying text                TB    text buffer (RTTY/PSK)
        #   ##KN / ##VP  LAN-only control       RF    RF-related query
        if head == 'AI':
            # Record the level: AI2 turns on the push that this radio relies on.
            self.ai_level = int(arg[0]) if arg and arg[0].isdigit() else 0
            self._last_push = self._snapshot()
            return ''

        if head == 'TB':                       # SPLIT on this radio
            if arg:
                # Setting split moves the TX VFO -- same fact, same storage,
                # rather than a parallel boolean that can disagree with it.
                if (arg[0] == '1') != st.split:
                    st.toggle_split()
                return ''
            return 'TB%d;' % (1 if st.split else 0)

        if head in ('FL', 'KY', 'RF') or cmd.startswith('##'):
            return ''

        return None
