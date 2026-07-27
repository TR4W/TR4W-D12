"""Icom CI-V personalities (IC-7300, IC-7000).

Binary, not ASCII: every frame is FE FE <to> <from> <cmd> [sub] [data] FD, and
payload bytes may be anything below FD.  This is the path where TR4W reads and
writes BYTE-EXACT (SerialProtocolIsBinary), so a simulator here exercises quite
different plumbing from the Kenwood/Elecraft ASCII drivers -- which is most of the
reason it is worth having.

Frequencies are packed BCD, LSB FIRST, 5 bytes = 10 digits (uIcomCIV.IcomBCDToFreq
walks the bytes backwards).  Getting the byte order wrong is the classic CI-V bug.
"""

from .core import RadioState, CivFramer

CONTROLLER = 0xE0          # TR4W's own CI-V address

# CI-V mode byte <-> canonical name.
MODE_TO_NUM = {'LSB': 0x00, 'USB': 0x01, 'AM': 0x02, 'CW': 0x03, 'FSK': 0x04,
               'FM': 0x05, 'CWR': 0x07, 'FSKR': 0x08}
NUM_TO_MODE = dict((v, k) for k, v in MODE_TO_NUM.items())


def freq_to_bcd(hz, nbytes=5):
    """10-digit packed BCD, least-significant byte first."""
    digits = '%010d' % hz
    out = bytearray()
    for i in range(nbytes):                       # pairs from the RIGHT
        pair = digits[len(digits) - 2 * (i + 1): len(digits) - 2 * i]
        out.append(((int(pair[0]) & 0x0F) << 4) | (int(pair[1]) & 0x0F))
    return bytes(out)


def bcd_to_freq(data):
    digits = ''
    for b in reversed(bytearray(data)):           # LSB first -> read backwards
        digits += '%d%d' % ((b >> 4) & 0x0F, b & 0x0F)
    try:
        return int(digits)
    except ValueError:
        return 0


class Icom(object):
    def __init__(self, name='Icom IC-7300', address=0x94, state=None,
                 supports_vfo_b=True):
        self.name = name
        self.address = address
        self.state = state or RadioState()
        self.framer = CivFramer()
        # The older rigs (IC-7000, IC-706 family) have no $25/$26 extended VFO
        # commands -- TR4W declares that through the capability set, and the
        # simulator refuses them so a driver that wrongly relies on them shows up.
        self.supports_vfo_b = supports_vfo_b

    def show(self, frame):
        return ' '.join('%02X' % b for b in bytearray(frame))

    def _reply(self, payload):
        return (b'\xFE\xFE' + bytes(bytearray([CONTROLLER, self.address]))
                + payload + b'\xFD')

    def _ok(self):
        return self._reply(b'\xFB')          # CI-V ACK

    def _ng(self):
        return self._reply(b'\xFA')          # CI-V NAK

    def handle(self, frame):
        data = bytearray(frame)
        if len(data) < 6 or data[0] != 0xFE or data[1] != 0xFE:
            return None
        to_addr, _from = data[2], data[3]
        if to_addr not in (self.address, 0x00):   # 0x00 = broadcast
            return ''                             # not for us; stay silent
        body = data[4:-1]                         # strip preamble/addresses/FD
        if not body:
            return None
        cmd = body[0]
        sub = body[1] if len(body) > 1 else None
        payload = bytes(body[2:]) if len(body) > 2 else b''
        st = self.state

        if cmd == 0x03:                            # read operating frequency
            return self._reply(bytes(bytearray([0x03])) + freq_to_bcd(st.rx_freq))

        if cmd == 0x04:                            # read operating mode
            return self._reply(bytes(bytearray([0x04, MODE_TO_NUM.get(st.mode, 0x03), 0x01])))

        if cmd == 0x05:                            # set frequency
            if len(body) >= 2:
                if st.rx_vfo == 0:
                    st.vfo_a = bcd_to_freq(body[1:])
                else:
                    st.vfo_b = bcd_to_freq(body[1:])
            return self._ok()

        if cmd == 0x06:                            # set mode
            if sub is not None:
                st.mode = NUM_TO_MODE.get(sub, st.mode)
            return self._ok()

        if cmd == 0x25:                            # read/set an explicit VFO freq
            if not self.supports_vfo_b:
                return self._ng()                  # this radio has no $25
            which = 0 if sub in (0x00, None) else 1
            if payload:
                if which == 0:
                    st.vfo_a = bcd_to_freq(payload)
                else:
                    st.vfo_b = bcd_to_freq(payload)
                return self._ok()
            freq = st.vfo_a if which == 0 else st.vfo_b
            return self._reply(bytes(bytearray([0x25, which])) + freq_to_bcd(freq))

        if cmd == 0x26:                            # read/set an explicit VFO mode
            if not self.supports_vfo_b:
                return self._ng()
            which = 0 if sub in (0x00, None) else 1
            if payload:
                st.mode = NUM_TO_MODE.get(payload[0], st.mode)
                return self._ok()
            return self._reply(bytes(bytearray(
                [0x26, which, MODE_TO_NUM.get(st.mode, 0x03), 0x00, 0x01])))

        if cmd == 0x0F:                            # split
            if sub is None:
                return self._reply(bytes(bytearray([0x0F, 1 if st.split else 0])))
            st.tx_vfo = (1 - st.rx_vfo) if sub in (0x01, 0x11) else st.rx_vfo
            return self._ok()

        if cmd == 0x1C and sub == 0x00:            # TX/RX status
            return self._reply(bytes(bytearray([0x1C, 0x00, 1 if st.transmitting else 0])))

        if cmd == 0x14 and sub == 0x0C:            # CW speed
            if payload:
                return self._ok()
            return self._reply(bytes(bytearray([0x14, 0x0C, 0x01, 0x28])))

        if cmd == 0x21:                            # RIT offset / on-off
            return self._ok()

        return None                                 # unhandled -> reported
