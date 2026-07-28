"""Kenwood TS-890S / TS-990S personality.

DELIBERATELY SEPARATE from kenwood.Kenwood.  These radios are driven by a
different TR4W class (TKenwoodTS890Radio, not TKenwoodSerial) whose command set
barely overlaps: it uses discrete queries -- FA, FB, FR, FT, OM, RT, XT, PS, ID,
KS, RF, TB.  Reusing the TS-590 personality produced nothing but "PS; (unhandled)",
which is what prompted this.

IF DOES NOT EXIST ON THESE RADIOS.  It is absent from the TS-990S command set
(confirmed by NY4I) and the TS-890 driver neither sends nor parses it.  The
simulator answers '?;' -- Kenwood's rejection for an unsupported command -- rather
than fabricating a status string, so a driver that wrongly sends IF here fails the
way it would against real hardware.

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

    def __init__(self, name='Kenwood TS-890S', ident='024', state=None):
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
        self.ai_level = 0            # set by AI<n>; the driver sends AI2
        self._last_push = None       # snapshot for change detection

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
                st.rit_on, st.xit_on, st.transmitting)

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
            # IF is NOT in this radio's command set -- confirmed absent from the
            # TS-990S list by NY4I, and the TS-890 driver never sends or parses it
            # either.  An earlier version ANSWERED IF here on my assumption that
            # "a real TS-890 supports IT", which was unfounded: a simulator that
            # invents a command the radio does not have makes a driver bug
            # (sending IF to a radio that cannot answer) look like it works.
            # '?;' is Kenwood's own rejection for an unsupported command, so a
            # driver that tries gets the same answer the hardware would give.
            return '?;'

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

        if head == 'FT':                       # transmit VFO -> split
            if arg:
                st.tx_vfo = int(arg[0])
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

        if head in ('FL', 'KY', 'TB', 'RF') or cmd.startswith('##'):
            return ''

        return None
