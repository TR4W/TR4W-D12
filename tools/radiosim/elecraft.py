"""Elecraft personality (K4, and the K3 family TElecraftSerial drives).

TR4W polls 'IF;FB;MD$;DT$;' -- IF carries VFO A's frequency, mode, RIT/XIT and
split, while the '$' suffix asks for VFO B's frequency and mode.

Unlike the Kenwood IF, ParseIFCommand consumes the string FROM THE FRONT with
successive Delete() calls, so the layout is positional from the start and the
stripped ';' does NOT shift anything.  The field template is written out in the
driver itself:

    IF[f]*****+yyyyrx*00tmvspbd1*;
       |     |    ||| || ||||||
       |     |    ||| || |||||+- data mode
       |     |    ||| || ||||+-- b
       |     |    ||| || |||+--- split
       |     |    ||| || ||+---- scan
       |     |    ||| || |+----- VFO
       |     |    ||| || +------ mode
       |     |    ||| |+-------- TX
       |     |    ||| +--------- (00)
       |     |    ||+----------- (space)
       |     |    |+------------ XIT on
       |     |    +------------- RIT on
       |     +------------------ 4-digit RIT offset
       +------------------------ sign
"""

from .core import RadioState, TerminatorFramer

MODE_TO_NUM = {'LSB': '1', 'USB': '2', 'CW': '3', 'FM': '4', 'AM': '5',
               'DATA': '6', 'CWR': '7', 'DATAR': '9'}
NUM_TO_MODE = dict((v, k) for k, v in MODE_TO_NUM.items())


class Elecraft(object):
    def __init__(self, name='Elecraft K4', state=None):
        self.name = name
        self.state = state or RadioState()
        self.framer = TerminatorFramer(b';')

    def show(self, frame):
        if isinstance(frame, bytes):
            frame = frame.decode('ascii', 'replace')
        return frame if frame.endswith(';') else frame + ';'

    def build_if(self):
        st = self.state
        mag = min(abs(st.offset), 9999)
        out = (
            'IF'
            + '%011d' % st.rx_freq                    # f
            + ' ' * 5                                 # *****
            + ('-' if st.offset < 0 else '+')         # sign
            + '%04d' % mag                            # yyyy
            + ('1' if st.rit_on else '0')             # r
            + ('1' if st.xit_on else '0')             # x
            + ' '                                     # *
            + '00'                                    # 00
            + ('1' if st.transmitting else '0')       # t
            + MODE_TO_NUM.get(st.mode, '3')           # m
            + str(st.rx_vfo)                          # v
            + '0'                                     # s  scan
            + ('1' if st.split else '0')              # p  split
            + '0'                                     # b
            + '0'                                     # d  data mode
            + '1'
            + ' '
        )
        assert len(out) == 37, 'IF body must be 37 chars, got %d' % len(out)
        return out + ';'

    def handle(self, frame):
        cmd = frame.decode('ascii', 'replace').strip()
        if not cmd:
            return ''
        head, arg = cmd[:2].upper(), cmd[2:]
        st = self.state

        if head == 'IF':
            return self.build_if()

        if head == 'FA':
            if arg and arg != '$':
                st.vfo_a = int(arg)
                return ''
            return 'FA%011d;' % st.vfo_a

        if head == 'FB':
            if arg and arg != '$':
                st.vfo_b = int(arg)
                return ''
            return 'FB%011d;' % st.vfo_b

        if head == 'MD':
            # 'MD$' addresses VFO B; TR4W polls it every cycle.
            if arg.startswith('$'):
                rest = arg[1:]
                if rest:
                    st.mode = NUM_TO_MODE.get(rest[0], st.mode)
                    return ''
                return 'MD$%s;' % MODE_TO_NUM.get(st.mode, '3')
            if arg:
                st.mode = NUM_TO_MODE.get(arg[0], st.mode)
                return ''
            return 'MD%s;' % MODE_TO_NUM.get(st.mode, '3')

        if head == 'DT':
            # Data sub-mode; '$' variant for VFO B.  TR4W only reads it.
            return 'DT$0;' if arg.startswith('$') else 'DT0;'

        if head == 'FT':
            if arg:
                st.tx_vfo = int(arg[0])
            return ''
        if head == 'FR':
            if arg:
                st.rx_vfo = int(arg[0])
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
        if head == 'TX':
            st.transmitting = True
            return ''
        if head == 'RX':
            st.transmitting = False
            return ''
        if head == 'AI':
            return ''                     # auto-info level; accepted silently
        if head == 'KS':
            return '' if arg else 'KS030;'
        if head == 'ID':
            return 'ID017;'
        return None
