"""Run a simulated radio on a serial port.

    python -m radiosim <model> <port> [baud]

    python -m radiosim TS590   COM37
    python -m radiosim IC7300  COM37
    python -m radiosim K4      COM37 38400

Point TR4W at the OTHER half of the virtual pair and select the matching radio.
Run this from the tools directory (or with tools on PYTHONPATH).

Models are the ones already migrated to the radio factory, since the point is to
exercise the factory.  A simulator for a radio still on the legacy path would test
code we are replacing.  The TS-890/TS-990 are here for their SERIAL port only; their LAN auth handshake
is deliberately not simulated, being better proven against real hardware.
"""

import sys

from .core import SerialTransport, RadioState, run
from .kenwood import Kenwood
from .kenwood_ts890 import KenwoodTS890
from .elecraft import Elecraft
from .icom import Icom
from .yaesu import Yaesu
from .hamlib.simts450 import HamlibTS450


def _kenwood(name):
    return lambda: Kenwood(name)


def _ts890(name, ident):
    return lambda: KenwoodTS890(name, ident)


def _elecraft(name):
    return lambda: Elecraft(name)


def _yaesu(name, type5=False):
    return lambda: Yaesu(name, type5=type5)


def _icom(name, address, supports_vfo_b=True):
    return lambda: Icom(name, address, supports_vfo_b=supports_vfo_b)


# CI-V addresses are the ones the matching TR4W radio class sets.
MODELS = {
    # HAMLIB-DERIVED, kept deliberately distinct from the TR4W-authored models
    # below: this one is a port of hamlib simulators/simts450.c, so agreement
    # with a TR4W driver is independent evidence rather than self-confirmation.
    # Read tools/radiosim/hamlib/__init__.py before trusting or editing it.
    # KNOWN: its IF response is 41 bytes where hamlib's OWN backend declares
    # if_len = 37, so TR4W will (correctly) reject it as malformed.  That makes
    # it a useful NEGATIVE test -- does the driver reject a bad IF gracefully?
    'HL-TS450': (lambda: HamlibTS450(), 4800),

    'TS590':  (_kenwood('Kenwood TS-590'),  4800),
    'TS2000': (_kenwood('Kenwood TS-2000'), 4800),
    'TS480':  (_kenwood('Kenwood TS-480'),  4800),
    'TS570':  (_kenwood('Kenwood TS-570'),  4800),
    # NOT the Kenwood personality above: TR4W drives these with a different class
    # (TKenwoodTS890Radio) that never sends IF and uses discrete queries plus a
    # PS; keepalive.  See kenwood_ts890.py.
    'TS890':  (_ts890('Kenwood TS-890S', '024'), 115200),
    'TS990':  (_ts890('Kenwood TS-990S', '022'), 115200),
    # Yaesu ASCII CAT.  FT991 and FTDX10 differ ONLY in the mode-char map
    # ('E' = C4FM vs PSK31), which is the whole reason TR4W has a separate
    # FT-991 class -- so the pairing is worth testing both ways.
    'FT991':  (_yaesu('Yaesu FT-991'),               4800),
    'FTDX10': (_yaesu('Yaesu FTDX-10', type5=True),  4800),
    'K4':     (_elecraft('Elecraft K4'),    38400),
    'K3':     (_elecraft('Elecraft K3'),    38400),
    'IC7300': (_icom('Icom IC-7300', 0x94),                       19200),
    'IC7610': (_icom('Icom IC-7610', 0x98),                       19200),
    'IC705':  (_icom('Icom IC-705',  0xA4),                       19200),
    'IC718':  (_icom('Icom IC-718',  0x5E, supports_vfo_b=False),  9600),
    # The older rigs have no $25/$26 extended-VFO commands; the simulator NAKs
    # them so a driver that wrongly assumes them is caught rather than tolerated.
    'IC7000': (_icom('Icom IC-7000', 0x70, supports_vfo_b=False), 19200),
    'IC706':  (_icom('Icom IC-706',  0x48, supports_vfo_b=False),  9600),
}


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        print('models: %s' % ', '.join(sorted(MODELS)))
        return 1
    model = sys.argv[1].upper().replace('-', '')
    if model not in MODELS:
        print('unknown model %r' % sys.argv[1])
        print('models: %s' % ', '.join(sorted(MODELS)))
        return 1
    factory, default_baud = MODELS[model]
    port = sys.argv[2]
    baud = int(sys.argv[3]) if len(sys.argv) > 3 else default_baud

    personality = factory()
    transport = SerialTransport(port, baud)
    run(personality, transport)
    return 0


if __name__ == '__main__':
    sys.exit(main())
