"""Run a simulated radio on a serial port.

    python -m radiosim <model> <port> [baud]

    python -m radiosim TS590   COM37
    python -m radiosim IC7300  COM37
    python -m radiosim K4      COM37 38400

Point TR4W at the OTHER half of the virtual pair and select the matching radio.
Run this from the tools directory (or with tools on PYTHONPATH).

Models are the ones already migrated to the radio factory, since the point is to
exercise the factory.  A simulator for a radio still on the legacy path would test
code we are replacing.  Network-only radios (TS-890, TS-990) are absent
deliberately: they cannot be driven over a COM port and their auth handshake is
better proven against real hardware.
"""

import sys

from .core import SerialTransport, RadioState, run
from .kenwood import Kenwood
from .elecraft import Elecraft
from .icom import Icom


def _kenwood(name):
    return lambda: Kenwood(name)


def _elecraft(name):
    return lambda: Elecraft(name)


def _icom(name, address, supports_vfo_b=True):
    return lambda: Icom(name, address, supports_vfo_b=supports_vfo_b)


# CI-V addresses are the ones the matching TR4W radio class sets.
MODELS = {
    'TS590':  (_kenwood('Kenwood TS-590'),  4800),
    'TS2000': (_kenwood('Kenwood TS-2000'), 4800),
    'TS480':  (_kenwood('Kenwood TS-480'),  4800),
    'TS570':  (_kenwood('Kenwood TS-570'),  4800),
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
