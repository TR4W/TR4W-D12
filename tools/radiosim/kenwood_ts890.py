"""Kenwood TS-890S / TS-990S personality.

DELIBERATELY SEPARATE from kenwood.Kenwood.  These radios are driven by a
different TR4W class (TKenwoodTS890Radio, not TKenwoodSerial) whose command set
barely overlaps: it never sends or parses IF at all, using discrete queries
instead -- FA, FB, FR, FT, OM, RT, XT, PS, ID, KS, RF, TB.  Reusing the TS-590
personality produced nothing but "PS; (unhandled)", which is what prompted this.

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

MODE_TO_NUM = {'LSB': '1', 'USB': '2', 'CW': '3', 'FM': '4', 'AM': '5',
               'FSK': '6', 'CWR': '7', 'FSKR': '9'}
NUM_TO_MODE = dict((v, k) for k, v in MODE_TO_NUM.items())


class KenwoodTS890(object):

    def __init__(self, name='Kenwood TS-890S', ident='024', state=None):
        self.name = name
        # ID024 = TS-890S; the driver checks for exactly that and warns otherwise.
        # ident=None means "do not answer ID" -- used for the TS-990, whose real
        # identifier is not documented anywhere in this repo.  Inventing one would
        # either fake a TS-890 or produce a confidently wrong log line; staying
        # silent is the honest option and costs nothing, since the driver only
        # logs the reply.
        self.ident = ident
        self.state = state or RadioState()
        self.framer = TerminatorFramer(b';')
        self.mode_b = 'USB'          # the VFOs can carry different modes

    def show(self, frame):
        if isinstance(frame, bytes):
            frame = frame.decode('ascii', 'replace')
        return frame if frame.endswith(';') else frame + ';'

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
        if head in ('AI', 'FL', 'KY', 'TB', 'RF') or cmd.startswith('##'):
            return ''

        return None
