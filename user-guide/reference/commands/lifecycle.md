# Actions and moved configuration

## Actions

These commands do work rather than simply storing a preference. They are handled separately in `TryApplyCommandAction`; do not document them as persistent checkboxes.

| Command | Current handler behavior |
| --- | --- |
| ADD DOMESTIC COUNTRY | Adds a country to the domestic list; CLEAR clears that list. |
| CLEAR DUPE SHEET | Records the requesting config file as the clear-dupe instruction; its value is ignored. |
| BAND MAP CUTOFF FREQUENCY | Parses an integer and adds a band-map mode cutoff. |
| FREQUENCY MEMORY | Adds a band/mode frequency memory; the handler distinguishes SSB-prefixed values. |

## Moved to a settings store

These are not withdrawn features. The compatibility parser recognizes the old name, but configuration belongs to its owning store or setup panel. This list alone does not establish an import recipe.

- `CONNECTION COMMAND`
- `FT1000MP CW REVERSE`
- `HAMLIB ASYNC ONLY`
- `HAMLIB DEBUG`
- `HAMLIB TRACE`
- `TCI DEBUG`
- `TCI MAX TX SECONDS`
- `TELNET DEBUG`
- `UDP BROADCAST ADDRESS`
- `UDP BROADCAST ALL QSOS`
- `UDP BROADCAST APP INFO`
- `UDP BROADCAST CONTACT INFO`
- `UDP BROADCAST LOOKUP INFO`
- `UDP BROADCAST PORT APP INFO`
- `UDP BROADCAST PORT CONTACT`
- `UDP BROADCAST PORT LOOKUP`
- `UDP BROADCAST PORT RADIO`
- `UDP BROADCAST PORT SCORE`
- `UDP BROADCAST RADIO INFO`
- `UDP BROADCAST ROTOR`
- `UDP BROADCAST ROTOR PORT`
- `UDP BROADCAST SCORE`
- `WK AUTOSPACE`
- `WK CT SPACING`
- `WK DIT DAH RATIO`
- `WK ENABLE`
- `WK FIRST EXTENSION`
- `WK IGNORE SPEED POT`
- `WK KEYER COMPENSATION`
- `WK KEYER MODE`
- `WK LEADIN TIME`
- `WK PADDLE ONLY SIDETONE`
- `WK PADDLE SWAP`
- `WK PADDLE SWITCHPOINT`
- `WK PORT`
- `WK SIDETONE ENABLE`
- `WK SIDETONE FREQUENCY`
- `WK TAIL TIME`
- `WK WEIGHT`

## Radio and keyer commands

The dispatch recognizes the RADIO ONE / RADIO TWO and KEYER RADIO ONE / KEYER RADIO TWO families, plus POLL RADIO ONE and POLL RADIO TWO. A prefix match is not validation of every suffix. Use the [radio setup guide](../../station/radio.md) until the library fields have a dedicated reviewed reference.

## Withdrawn names

These exact names are in RETIRED_COMMANDS. Their acceptance avoids invalid-statement errors for older files; it does not apply their values. Do not infer the status of an entire hardware family from the retirement of one command name.

- `AUTO ALT-D ENABLE`
- `BACKCOPY ENABLE`
- `BAND MAP ENABLE`
- `CALL WINDOW POSITION`
- `COLUMN DUPESHEET ENABLE`
- `CURTIS KEYER MODE`
- `CUSTOM CARET`
- `DUPE SHEET ENABLE`
- `EIGHT BIT PACKET PORT`
- `EX MENU`
- `EXCHANGE WINDOW S&P BACKGROUND`
- `FOOT SWITCH MODE`
- `FOOT SWITCH PORT`
- `FREQUENCY ADDER RADIO ONE`
- `FREQUENCY ADDER RADIO TWO`
- `ICOM RESPONSE TIMEOUT`
- `LATEST CONFIG FILE`
- `LOG FILE NAME`
- `MODEM PORT`
- `MODEM PORT BAUD RATE`
- `MOUSE ENABLE`
- `MP3 PATH`
- `MP3 PLAYER`
- `MP3 RECORDER BITRATE`
- `MP3 RECORDER DURATION`
- `MP3 RECORDER ENABLE`
- `MP3 RECORDER SAMPLERATE`
- `MULTI INFO MESSAGE`
- `MULTI PORT`
- `MULTI PORT BAUD RATE`
- `MULTI RETRY TIME`
- `MULTI UPDATE MULT DISPLAY`
- `ORION PORT`
- `PACKET ADD LF`
- `PACKET AUTO CR`
- `PACKET BAND SPOTS`
- `PACKET BAUD RATE`
- `PACKET BEEP`
- `PACKET LOG FILENAME`
- `PACKET PORT`
- `PACKET PORT BAUD RATE`
- `PACKET RETURN PER MINUTE`
- `PACKET SPOT COMMENT`
- `PACKET SPOT DISABLE`
- `PACKET SPOT EDIT ENABLE`
- `PACKET SPOT KEY`
- `PACKET SPOT PREFIX ONLY`
- `PACKET SPOTS`
- `PADDLE BUG ENABLE`
- `PARTIAL CALL LOAD LOG ENABLE`
- `PARTIAL CALL MULT INFO ENABLE`
- `PRINTER ENABLE`
- `QUICK QSL KEY`
- `QUICK QSL MESSAGE`
- `RADIO ONE COMMAND PAUSE`
- `RADIO ONE ICOM NETWORK PASSWORD`
- `RADIO ONE ICOM NETWORK USERNAME`
- `RADIO ONE ID CHARACTER`
- `RADIO ONE TRACKING ENABLE`
- `RADIO ONE UPDATE SECONDS`
- `RADIO TWO COMMAND PAUSE`
- `RADIO TWO ICOM NETWORK PASSWORD`
- `RADIO TWO ICOM NETWORK USERNAME`
- `RADIO TWO ID CHARACTER`
- `RADIO TWO TRACKING ENABLE`
- `RADIO TWO UPDATE SECONDS`
- `REMINDER`
- `RTTY PORT`
- `RTTY RECEIVE STRING`
- `RTTY SEND STRING`
- `SCORE POSTING ID`
- `SEND ALT-D SPOTS TO PACKET`
- `SEND QSO IMMEDIATELY`
- `SERIAL 5 PORT ADDRESS`
- `SERIAL 6 PORT ADDRESS`
- `SHOW SEARCH AND POUNCE`
- `SIMULATOR ENABLE`
- `SINGLE RADIO MODE`
- `TAB MODE`
- `TOTAL OFF TIME`
- `TOTAL SCORE MESSAGE`
- `UDP BROADCAST PORT`
- `USE BIOS KEY CALLS`
- `USE IRQS`
- `VGA DISPLAY ENABLE`
- `VISIBLE DUPESHEET`
- `WIDE FREQUENCY DISPLAY`
- `YAESU RESPONSE TIMEOUT`

Classification source (`tr4w/src/uCFG.pas`)
