"""Self-tests: check each personality against what the TR4W driver PARSES.

Run:  python -m radiosim.selftest

These exist because a simulator is easy to verify against the wrong thing.  The
first TS-590 attempt was checked against the bytes on the WIRE, while the driver
only ever sees the body with the terminator already stripped -- so the check
passed and the radio window still showed no mode.  Every assertion below therefore
strips the terminator first, exactly as uFactoryRadioBase's reading thread does.
"""

from .kenwood import Kenwood
from .kenwood_ts890 import KenwoodTS890
from .elecraft import Elecraft
from .icom import Icom, freq_to_bcd, bcd_to_freq

FAILED = []


def check(label, got, want):
    ok = got == want
    print('  %-46s %-12r %s' % (label, got, 'OK' if ok else 'WRONG want %r' % (want,)))
    if not ok:
        FAILED.append(label)


def strip(reply):
    """What the driver receives: the reading thread removes the terminator."""
    return reply[:-1] if reply.endswith(';') else reply


def test_kenwood():
    print('Kenwood IF -- TKenwoodSerial.ParseIF indexes from the END')
    r = Kenwood()
    r.state.vfo_a = 14025000
    r.state.mode = 'CW'
    r.state.rit_on = True
    r.state.offset = -1200
    r.state.tx_vfo = 1                     # split
    msg = strip(r.build_if())
    L = len(msg)
    check('length the driver parses', L, 37)
    check('freq  Copy(msg,3,11)', int(msg[2:13]), 14025000)
    check('RIT sign  msg[L-18]', msg[L - 19], '-')
    check('RIT mag   Copy(msg,L-17,4)', int(msg[L - 18:L - 14]), 1200)
    check('RIT on    msg[L-13]', msg[L - 14], '1')
    check('XIT on    msg[L-12]', msg[L - 13], '0')
    check('TX/RX     msg[L-8]', msg[L - 9], '0')
    check('mode      msg[L-7]', msg[L - 8], '3')
    check('FR        msg[L-6]', msg[L - 7], '0')
    check('split     msg[L-4]', msg[L - 5], '1')


def test_elecraft():
    print('\nElecraft IF -- ParseIFCommand consumes from the FRONT')
    r = Elecraft()
    r.state.vfo_a = 7025000
    r.state.mode = 'CW'
    r.state.xit_on = True
    r.state.offset = 250
    msg = strip(r.build_if())
    check('length the driver parses', len(msg), 37)
    s = msg[2:]                                    # driver deletes 'IF'
    check('freq  first 11 after IF', int(s[:11]), 7025000)
    s = s[11:][5:]                                 # freq, then 5 blanks
    check('sign', s[0], '+')
    check('RIT offset 4 digits', int(s[1:5]), 250)
    check('RIT on', s[5], '0')
    check('XIT on', s[6], '1')
    # order after the sign is: yyyy r x <space> 00 t m -- mode is 11, not 10
    check('TX flag', s[10], '0')
    check('mode digit', s[11], '3')


def test_ts890():
    print('')
    print('TS-890 -- discrete queries, no IF; PS is a keepalive')
    r = KenwoodTS890()
    r.state.vfo_a, r.state.vfo_b = 14025000, 7010000
    r.state.mode, r.mode_b = 'CW', 'USB'
    check('PS keepalive answered', r.handle(b'PS'), 'PS1;')
    check('ID identifies TS-890S', r.handle(b'ID'), 'ID024;')
    check('FA', r.handle(b'FA'), 'FA00014025000;')
    check('FB', r.handle(b'FB'), 'FB00007010000;')
    # OM's VFO byte is OPERATING-VFO-RELATIVE, not fixed A/B.
    r.state.rx_vfo = 0
    check('OM0 with A operating -> A mode (CW)', r.handle(b'OM0'), 'OM03;')
    check('OM1 with A operating -> B mode (USB)', r.handle(b'OM1'), 'OM12;')
    r.state.rx_vfo = 1
    check('OM0 with B operating -> B mode (USB)', r.handle(b'OM0'), 'OM02;')
    check('OM1 with B operating -> A mode (CW)', r.handle(b'OM1'), 'OM13;')

    # Split is ONE fact with ONE home: RadioState.split, derived from
    # tx_vfo != rx_vfo.  It briefly had a second, hand-maintained copy on the
    # personality, and the two disagreed the first time NY4I touched the console:
    # 's' moved tx_vfo, the status line said split=True, the duplicate stayed
    # False, and no TB was ever pushed -- so TR4W's indicator never cleared.
    # These check the three ways split can change all agree and all report TB.
    r2 = KenwoodTS890()
    r2.handle(b'AI2')
    r2.pending()                                   # establish the push baseline
    r2.state.toggle_split()                        # the operator, at the radio
    check("operator 's' pushes FT and TB", r2.pending(), ['FT1;', 'TB1;'])
    check("operator 's' -> split on", r2.state.split, True)
    r2.state.toggle_split()
    check("operator 's' again -> split off", r2.pending(), ['FT0;', 'TB0;'])

    r2.handle(b'FT1')                              # TR4W's Split(), D7 style
    check('FT1; alone reports split', r2.pending(), ['FT1;', 'TB1;'])
    r2.handle(b'TB0')                              # split cleared explicitly
    check('TB0; moves the TX VFO back', r2.pending(), ['FT0;', 'TB0;'])
    check('TB query agrees with state', r2.handle(b'TB'), 'TB0;')
    check('TS-990 stays silent on ID', KenwoodTS890(ident=None).handle(b'ID'), '')
    check('unknown command reported', r.handle(b'ZZ'), None)
    # IF on the TS-890 is UNDOCUMENTED but real (supplanted by SF, kept for legacy
    # software) -- hamlib's TS-890 simulator documents the format from a real
    # radio.  It is absent from the TS-990S command set, which rejects it.
    body = r.handle(b'IF')[:-1]
    check('TS-890 answers legacy IF, 37-char body', len(body), 37)
    r.handle(b'TB1')
    check('IF split field tracks split state', r.handle(b'IF')[:-1][-5], '1')
    r.handle(b'TB0')
    check('TS-990 rejects IF', KenwoodTS890(ident='022', legacy_if=False).handle(b'IF'), '?;')
    # TB is the split command per the Kenwood PC Command Reference, NOT FT.
    check('TB1 sets split', (r.handle(b'TB1'), r.state.split)[1], True)
    check('TB reports split', r.handle(b'TB'), 'TB1;')
    r.handle(b'TB0')

    # AI2 PUSH -- this radio is push-driven (PollRadioState sends only PS;), so a
    # simulator that merely answers queries would never move TR4W's display.
    p = KenwoodTS890()
    check('no push before AI is enabled', p.pending(), [])
    p.handle(b'AI2')
    check('AI2 establishes a baseline, no push yet', p.pending(), [])
    p.state.vfo_a = 14200000
    check('frequency change is pushed', p.pending(), ['FA00014200000;'])
    p.state.rx_vfo = 1
    # TB rides along because split is derived: moving the RX VFO away from the TX
    # VFO IS split, and a real radio would report that too.
    check('VFO change pushes FR, BOTH relative modes, and the new split',
          p.pending(), ['FR1;', 'OM02;', 'OM13;', 'TB1;'])
    check('nothing pushed when nothing changed', p.pending(), [])


def test_icom():
    print('\nIcom CI-V -- packed BCD, LSB first (uIcomCIV.IcomBCDToFreq)')
    # 14025000 -> '0014025000' -> LSB-first pairs 00 50 02 14 00
    check('freq_to_bcd(14025000)', freq_to_bcd(14025000).hex().upper(), '0050021400')
    check('round trip 14025000', bcd_to_freq(freq_to_bcd(14025000)), 14025000)
    check('round trip 7025000', bcd_to_freq(freq_to_bcd(7025000)), 7025000)
    check('round trip 144200000', bcd_to_freq(freq_to_bcd(144200000)), 144200000)

    r = Icom(address=0x94)
    r.state.vfo_a = 14025000
    r.state.mode = 'CW'
    # TR4W asks for the operating frequency: FE FE 94 E0 03 FD
    reply = r.handle(b'\xFE\xFE\x94\xE0\x03\xFD')
    check('reply is addressed to the controller', reply[2], 0xE0)
    check('reply is from the radio', reply[3], 0x94)
    check('reply command byte', reply[4], 0x03)
    check('reply frequency decodes', bcd_to_freq(reply[5:-1]), 14025000)
    reply = r.handle(b'\xFE\xFE\x94\xE0\x04\xFD')
    check('mode reply is CW (0x03)', reply[5], 0x03)

    # An older rig must REFUSE $25 rather than answer it.
    old = Icom(address=0x70, supports_vfo_b=False)
    check('IC-7000 NAKs $25', old.handle(b'\xFE\xFE\x70\xE0\x25\x00\xFD')[4], 0xFA)


def main():
    test_kenwood()
    test_elecraft()
    test_ts890()
    test_icom()
    print()
    if FAILED:
        print('*** %d CHECK(S) FAILED: %s ***' % (len(FAILED), ', '.join(FAILED)))
        return 1
    print('*** all checks passed ***')
    return 0


if __name__ == '__main__':
    import sys
    sys.exit(main())
