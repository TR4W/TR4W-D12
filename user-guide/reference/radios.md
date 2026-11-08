# Radio support and connection reference

**101 registrations** extracted from the radio factory in this source snapshot. This is a declared driver/transport inventory, not a report of successful hardware tests.

## Read the table

- **Native TR4W** means a direct TR4W driver registration. It does not mean an operating-system release is production-ready.
- **Serial / Network** are the transports explicitly registered for that driver. Network support does not imply discovery support.
- **Port** and serial parameters are setup defaults, not requirements that override the radio’s actual configuration.
- **Hamlib only** means the connection goes through a Hamlib backend. The registry exposes both transports generically; the backend and radio decide what works. A Hamlib model ID on a native radio is not proof it requires Hamlib.

## Important exceptions

- **Expert TCI (HamLib bridge)** is a retained placeholder. Its source says the shipped Hamlib backend is absent; do not treat that entry as a working alternative. The distinct native **TCI (ExpertSDR / Thetis / AetherSDR)** entry is documented in the [TCI guide](../station/tci.md).
- **HamLib (any supported rig)** uses a placeholder model ID; choose the actual rig’s Hamlib model ID during setup.
- CW-by-CAT, spectrum, voice keying, and model-specific operating limits live in driver capability code. They are not inferred by this table.

[Connect a radio](../station/radio.md)

## Registered models


### Icom

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Icom IC-7000 | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-705 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-706 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-706MkII | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-706MkIIG | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-707 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-7100 | Native TR4W | Yes | No | — | No | 19200 / 8 / NONE / 1 |
| Icom IC-7110 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-718 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-7200 | Native TR4W | Yes | No | — | No | 19200 / 8 / NONE / 1 |
| Icom IC-725 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-726 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-728 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-729 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-7300 | Native TR4W | Yes | No | — | No | 19200 / 8 / NONE / 1 |
| Icom IC-7300MK2 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-735 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-736 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-737 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-738 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-7410 | Native TR4W | Yes | No | — | No | 19200 / 8 / NONE / 1 |
| Icom IC-746 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-746PRO | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-756 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-756PRO | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-756PROII | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-756PROIII | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-7600 | Native TR4W | Yes | Yes | 50001 | Yes | 9600 / 8 / NONE / 1 |
| Icom IC-761 | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-7610 | Native TR4W | Yes | Yes | 50001 | Yes | 9600 / 8 / NONE / 1 |
| Icom IC-765 | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-7700 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-775 | Native TR4W | Yes | No | — | No | 19200 / 8 / NONE / 1 |
| Icom IC-7760 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-78 | Native TR4W | Yes | No | — | No | 1200 / 8 / NONE / 1 |
| Icom IC-7800 | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-781 | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-7850 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-7851 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-905 | Native TR4W | Yes | Yes | 50001 | Yes | 19200 / 8 / NONE / 1 |
| Icom IC-910 | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Icom IC-9100 | Native TR4W | Yes | No | — | No | 19200 / 8 / NONE / 1 |
| Icom IC-9700 | Native TR4W | Yes | Yes | 50001 | Yes | 38400 / 8 / NONE / 1 |
| Icom IC-970D | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |

### Elecraft

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Elecraft K2 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 1 |
| Elecraft K3 | Native TR4W | Yes | No | — | No | 38400 / 8 / NONE / 1 |
| Elecraft K4 | Native TR4W | Yes | Yes | 9200 | Yes | 38400 / 8 / NONE / 1 |
| Elecraft KX3 | Native TR4W | Yes | No | — | No | 38400 / 8 / NONE / 1 |

### Kenwood

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Kenwood TS-140 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-2000 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-440 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-450 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-480 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-570 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-590 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-690 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-850 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-870 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-890S | Native TR4W | Yes | Yes | 60000 | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-940 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-950 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Kenwood TS-990S | Native TR4W | Yes | Yes | 50000 | No | 4800 / 8 / NONE / 2 |

### Yaesu

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Yaesu FT-100 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 1 |
| Yaesu FT-1000 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-1000MP | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-1200 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-2000 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-450 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-710 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-736R (via HamLib) | Hamlib only (ID 1010) | Backend-dependent | Backend-dependent | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-747GX | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-757GXII (via HamLib) | Hamlib only (ID 1007) | Backend-dependent | Backend-dependent | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-767 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-817 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-818 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-840 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-847 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-857 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-890 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-891 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-897 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-900 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-920 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-950 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-990 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FT-991 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FTDX-10 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FTDX-101 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FTDX-3000 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FTDX-5000 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FTDX-9000 | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |
| Yaesu FTX-1F | Native TR4W | Yes | No | — | No | 4800 / 8 / NONE / 2 |

### FlexRadio

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Flex 6000+ | Native TR4W | Yes | Yes | 4992 | Yes | 4800 / 8 / NONE / 2 |

### Ten-Tec

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Ten-Tec Omni VI (CI-V) | Native TR4W | Yes | No | — | No | 9600 / 8 / NONE / 1 |
| Ten-Tec Orion | Native TR4W | Yes | No | — | No | 57600 / 8 / NONE / 1 |

### Hamlib — generic

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| HamLib (any supported rig) | Hamlib only (ID 1) | Backend-dependent | Backend-dependent | — | No | 57600 / 8 / NONE / 2 |

### Software interfaces and other models

| Model | Driver | Serial | Network | Network port | Discovery | Serial defaults: baud / bits / parity / stops |
| --- | --- | --- | --- | --- | --- | --- |
| Expert TCI (HamLib bridge) | Hamlib only (ID 7) | Backend-dependent | Backend-dependent | — | No | 57600 / 8 / NONE / 2 |
| FLRig (HamLib bridge) | Hamlib only (ID 4) | Backend-dependent | Backend-dependent | — | No | 57600 / 8 / NONE / 2 |
| N3FJP ACLog (HamLib bridge) | Hamlib only (ID 8) | Backend-dependent | Backend-dependent | — | No | 57600 / 8 / NONE / 2 |
| TCI (ExpertSDR / Thetis / AetherSDR) | Native TR4W | No | Yes | 50001 | No | — |
| TRX-Manager (HamLib bridge) | Hamlib only (ID 5) | Backend-dependent | Backend-dependent | — | No | 57600 / 8 / NONE / 2 |

## Reproduce and verify

`python tools/build_command_reference.py` extracts initialization registrations and fails on unparsed registration calls or duplicate identifiers. It does not instantiate drivers, open ports, or check the linked application at runtime. Review model-specific source and bench status before claiming hardware validation.

Source snapshot: `24f06a30081b607dbca5020fe583d97944be97d8`.
