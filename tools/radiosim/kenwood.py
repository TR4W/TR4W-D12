"""Kenwood ASCII CAT personalities (TS-590 and relatives).

Answers what TR4W's TKenwoodSerial driver sends: IF;FA;FB; each poll cycle, plus
the sets it issues (FA/FB/MD/FR/FT/RT/XT/RC/RU/RD/TX/RX/UP/DN).
"""

from .core import RadioState, TerminatorFramer

# Kenwood MD digits <-> canonical mode names.
MODE_TO_NUM = {'LSB': '1', 'USB': '2', 'CW': '3', 'FM': '4', 'AM': '5',
               'FSK': '6', 'CWR': '7', 'FSKR': '9'}
NUM_TO_MODE = dict((v, k) for k, v in MODE_TO_NUM.items())


class Kenwood(object):
    """TS-590 / TS-2000 / TS-480 family as TR4W drives them."""

    def __init__(self, name='Kenwood TS-590', state=None):
        self.name = name
        self.state = state or RadioState()
        self.framer = TerminatorFramer(b';')

    # -- display helper for the console log -------------------------------
    def show(self, frame):
        if isinstance(frame, bytes):
            frame = frame.decode('ascii', 'replace')
        return frame if frame.endswith(';') else frame + ';'

    # -- the IF response ---------------------------------------------------
    def build_if(self):
        """IF status, laid out for TKenwoodSerial.ParseIF.

        ParseIF indexes from the END (L = length, 1-based): L-18 RIT sign,
        L-17..L-14 magnitude, L-13 RIT, L-12 XIT, L-8 TX, L-7 mode, L-6 FR,
        L-4 split.  Frequency is at the fixed 3..13.

        CRITICAL: TR4W's reading thread strips the ';' before the driver sees the
        command, so ParseIF parses a 37-character BODY, not the 38 bytes on the
        wire.  Sizing this for 38 shifts every end-relative field by one -- and
        because frequency is at a FIXED offset it keeps working perfectly, which
        makes the mistake look like a driver bug.  That cost a debugging session
        the first time; the assertion below pins the body length.
        """
        st = self.state
        mag = min(abs(st.offset), 9999)
        out = (
            'IF'                                            # 1-2
            + '%011d' % st.rx_freq                          # 3-13   frequency
            + ' ' * 5                                       # 14-18  filler
            + ('-' if st.offset < 0 else '+')               # 19     RIT sign   L-18
            + '%04d' % mag                                  # 20-23  magnitude  L-17
            + ('1' if st.rit_on else '0')                   # 24     RIT        L-13
            + ('1' if st.xit_on else '0')                   # 25     XIT        L-12
            + '0' + '00'                                    # 26-28  memory
            + ('1' if st.transmitting else '0')             # 29     TX         L-8
            + MODE_TO_NUM.get(st.mode, '3')                 # 30     mode       L-7
            + str(st.rx_vfo)                                # 31     FR         L-6
            + '0'                                           # 32     scan
            + ('1' if st.split else '0')                    # 33     split      L-4
            + '0' + '00' + '0'                              # 34-37  tone etc
        )
        assert len(out) == 37, 'IF body must be 37 chars, got %d' % len(out)
        return out + ';'

    # -- command dispatch --------------------------------------------------
    def handle(self, frame):
        cmd = frame.decode('ascii', 'replace').strip()
        if not cmd:
            return ''
        head, arg = cmd[:2].upper(), cmd[2:]
        st = self.state

        if head == 'IF':
            return self.build_if()
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
        if head == 'MD':
            if arg:
                st.mode = NUM_TO_MODE.get(arg[0], st.mode)
                return ''
            return 'MD%s;' % MODE_TO_NUM.get(st.mode, '3')
        if head == 'FR':
            if arg:
                st.rx_vfo = int(arg)
            return ''
        if head == 'FT':
            if arg:
                st.tx_vfo = int(arg)
            return ''
        if head == 'RT':
            st.rit_on = (arg == '1')
            return ''
        if head == 'XT':
            st.xit_on = (arg == '1')
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
        if head == 'TX':
            st.transmitting = True
            return ''
        if head == 'RX':
            st.transmitting = False
            return ''
        if head == 'UP':
            st.vfo_a += 1000
            return ''
        if head == 'DN':
            st.vfo_a -= 1000
            return ''
        if head == 'KS':
            return '' if arg else 'KS030;'
        if head == 'ID':
            return 'ID021;'          # TS-590 identifier
        return None
