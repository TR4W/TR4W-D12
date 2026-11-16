# Preferences invalid-input sweep, 2026-11-16

What TR4W does at the moment a text box on a Preferences page is LEFT (Tab) after an obviously invalid value: letters (`abcxyz`), an out-of-range number (`-99999999999`) and a pasted 300-character string. A report for deciding which fields need rules; nothing here is asserted.

- Build: `build-out\app-x86_64-win64\tr4w_fpc.exe` (main at be4dc5a6), SHA256 `75be905ffde299fcca35418d413e4fa95e154f57ed0aad0b2a03eef35e83e238`, debug CRC `5A19AD57`. Windows test VM, 1280x800, 96 DPI, CW Open fixture log.
- Cases `sweep-a`/`sweep-b`/`sweep-c` (`tools/gui_test/bench_invalid_sweep.py`), suite `20261116T221335-5122c9`: 72 writable boxes, 216 rows; no crash, no hang, no window from the program on any row. Each box got its original text back after every value and each run ended with Cancel; nothing was saved.
- Station (tag 1) is NOT here: it has rules and its own asserted case, `station-check` (PASS in the same suite).
- "accepted silently": the value stayed as typed, focus moved on, no window, no red text. Whether Save later refuses or clamps it was NOT exercised (the sweep never saves).
- "Windows number-only balloon" / "refused while typing" / "filtered while typing": the box is number-only; Windows itself drops non-digits, so the digits of the out-of-range number get in unchecked.
- "password box": a masked box cannot be read back from another process, so what it kept is unknown.
- NEVER swept by this case: editable combo boxes, grid cells (Radios, Rotators, Keyers, cluster and logger lists), and the separate editor windows those lists open; disabled boxes (enabled only by another setting) are counted below, not swept.
- Control names are the visible captions read by OCR (they are windowless labels): expect small misreads; captions OCR could not read are shown by screen position.
- Regenerate: `python tools/gui_test/sweep_report.py <suite folder>... --output <this file>`.
- Pages walked: 46; pages with no writable text box: 2 Hardware, 3 DX Cluster, 5 UDP Broadcast, 8 Logging, 12 Web Server, 13 External Software, 17 External Logger, 18 DXLab, 21 Operating, 24 Bands, 25 Two Radio Mode, 26 Radios, 27 Rotators, 31 Colors, 32 Messages, 40 QTC, 41 QSO settings, 43 Modes, 45 Multiplier data, 47 Contest rules, 48 CW keyers.
- Text boxes NOT swept: combo box 13, disabled 20, read-only 0; below the fold and swept after scrolling into view: 0; could not be brought into view: 2.

| Behaviour | Rows |
| --- | --- |
| accepted silently | 180 |
| Windows number-only balloon | 18 |
| refused while typing | 18 |
| filtered while typing | 9 |
| no window, no mark | 9 |
| password box | 9 |

| Page | Control | Value | Behaviour |
| --- | --- | --- | --- |
| 4 SCP | Restrict to countries: | letters | accepted silently |
| 4 SCP | Restrict to countries: | out-of-range number | accepted silently |
| 4 SCP | Restrict to countries: | 300-char string | accepted silently |
| 4 SCP | Possible Call Accept Key | letters | accepted silently |
| 4 SCP | Possible Call Accept Key | out-of-range number | accepted silently |
| 4 SCP | Possible Call Accept Key | 300-char string | accepted silently |
| 4 SCP | Possible Call Left Key | letters | accepted silently |
| 4 SCP | Possible Call Left Key | out-of-range number | accepted silently |
| 4 SCP | Possible Call Left Key | 300-char string | accepted silently |
| 4 SCP | Possible Call Right Key | letters | accepted silently |
| 4 SCP | Possible Call Right Key | out-of-range number | accepted silently |
| 4 SCP | Possible Call Right Key | 300-char string | accepted silently |
| 6 Network | Server: | letters | accepted silently |
| 6 Network | Server: | out-of-range number | accepted silently |
| 6 Network | Server: | 300-char string | accepted silently |
| 6 Network | Port: | letters | accepted silently |
| 6 Network | Port: | out-of-range number | accepted silently |
| 6 Network | Port: | 300-char string | accepted silently |
| 6 Network | Password: | letters | password box (value not readable); no window, no mark |
| 6 Network | Password: | out-of-range number | password box (value not readable); no window, no mark |
| 6 Network | Password: | 300-char string | password box (value not readable); no window, no mark |
| 6 Network | Tailcat address: | letters | password box (value not readable); no window, no mark |
| 6 Network | Tailcat address: | out-of-range number | password box (value not readable); no window, no mark |
| 6 Network | Tailcat address: | 300-char string | password box (value not readable); no window, no mark |
| 6 Network | This station: | letters | accepted silently |
| 6 Network | This station: | out-of-range number | accepted silently |
| 6 Network | This station: | 300-char string | accepted silently |
| 6 Network | Computer Name | letters | accepted silently |
| 6 Network | Computer Name | out-of-range number | accepted silently |
| 6 Network | Computer Name | 300-char string | accepted silently |
| 6 Network | Net Status Update Interval | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 6 Network | Net Status Update Interval | out-of-range number | filtered while typing to '99999999999' |
| 6 Network | Net Status Update Interval | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 6 Network | Stations Callsigns Mask | letters | accepted silently |
| 6 Network | Stations Callsigns Mask | out-of-range number | accepted silently |
| 6 Network | Stations Callsigns Mask | 300-char string | accepted silently |
| 7 Appearance | Font: | letters | accepted silently |
| 7 Appearance | Font: | out-of-range number | accepted silently |
| 7 Appearance | Font: | 300-char string | accepted silently |
| 7 Appearance | Size: | letters | accepted silently |
| 7 Appearance | Size: | out-of-range number | accepted silently |
| 7 Appearance | Size: | 300-char string | accepted silently |
| 9 Backup | Back up evey. | letters | accepted silently |
| 9 Backup | Back up evey. | out-of-range number | accepted silently |
| 9 Backup | Back up evey. | 300-char string | accepted silently |
| 9 Backup | Copy to: | letters | accepted silently |
| 9 Backup | Copy to: | out-of-range number | accepted silently |
| 9 Backup | Copy to: | 300-char string | accepted silently |
| 10 Contest | Auto-CQ Delay Time | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 10 Contest | Auto-CQ Delay Time | out-of-range number | filtered while typing to '99999999999' |
| 10 Contest | Auto-CQ Delay Time | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 10 Contest | Contest Name | letters | accepted silently |
| 10 Contest | Contest Name | out-of-range number | accepted silently |
| 10 Contest | Contest Name | 300-char string | accepted silently |
| 10 Contest | Contest Title | letters | accepted silently |
| 10 Contest | Contest Title | out-of-range number | accepted silently |
| 10 Contest | Contest Title | 300-char string | accepted silently |
| 10 Contest | Grid Map Center | letters | accepted silently |
| 10 Contest | Grid Map Center | out-of-range number | accepted silently |
| 10 Contest | Grid Map Center | 300-char string | accepted silently |
| 10 Contest | Log RSt Sent | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 10 Contest | Log RSt Sent | out-of-range number | filtered while typing to '99999999999' |
| 10 Contest | Log RSt Sent | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 11 CW Settings | Sidetone: | letters | accepted silently |
| 11 CW Settings | Sidetone: | out-of-range number | accepted silently |
| 11 CW Settings | Sidetone: | 300-char string | accepted silently |
| 14 Advanced | Radius Of Earth | letters | accepted silently |
| 14 Advanced | Radius Of Earth | out-of-range number | accepted silently |
| 14 Advanced | Radius Of Earth | 300-char string | accepted silently |
| 15 TCI Server | Port: - 50001 | letters | accepted silently |
| 15 TCI Server | Port: - 50001 | out-of-range number | accepted silently |
| 15 TCI Server | Port: - 50001 | 300-char string | accepted silently |
| 15 TCI Server | Stop transmitting after: | letters | accepted silently |
| 15 TCI Server | Stop transmitting after: | out-of-range number | accepted silently |
| 15 TCI Server | Stop transmitting after: | 300-char string | accepted silently |
| 16 WSJT-X | Broadcast port: | letters | accepted silently |
| 16 WSJT-X | Broadcast port: | out-of-range number | accepted silently |
| 16 WSJT-X | Broadcast port: | 300-char string | accepted silently |
| 16 WSJT-X | Multicast group: | letters | accepted silently |
| 16 WSJT-X | Multicast group: | out-of-range number | accepted silently |
| 16 WSJT-X | Multicast group: | 300-char string | accepted silently |
| 19 MMTTY | Engine: | letters | accepted silently |
| 19 MMTTY | Engine: | out-of-range number | accepted silently |
| 19 MMTTY | Engine: | 300-char string | accepted silently |
| 20 Band Map | Guard band: | letters | accepted silently |
| 20 Band Map | Guard band: | out-of-range number | accepted silently |
| 20 Band Map | Guard band: | 300-char string | accepted silently |
| 20 Band Map | Display limit: | letters | accepted silently |
| 20 Band Map | Display limit: | out-of-range number | accepted silently |
| 20 Band Map | Display limit: | 300-char string | accepted silently |
| 22 Online Scoring | Service URL: | letters | accepted silently |
| 22 Online Scoring | Service URL: | out-of-range number | accepted silently |
| 22 Online Scoring | Service URL: | 300-char string | accepted silently |
| 22 Online Scoring | Username: | letters | accepted silently |
| 22 Online Scoring | Username: | out-of-range number | accepted silently |
| 22 Online Scoring | Username: | 300-char string | accepted silently |
| 22 Online Scoring | Password: | letters | password box (value not readable); no window, no mark |
| 22 Online Scoring | Password: | out-of-range number | password box (value not readable); no window, no mark |
| 22 Online Scoring | Password: | 300-char string | password box (value not readable); no window, no mark |
| 22 Online Scoring | Posting URL: | letters | accepted silently |
| 22 Online Scoring | Posting URL: | out-of-range number | accepted silently |
| 22 Online Scoring | Posting URL: | 300-char string | accepted silently |
| 22 Online Scoring | Reading URL: | letters | accepted silently |
| 22 Online Scoring | Reading URL: | out-of-range number | accepted silently |
| 22 Online Scoring | Reading URL: | 300-char string | accepted silently |
| 23 While operating | Stop above a rate of: | letters | accepted silently |
| 23 While operating | Stop above a rate of: | out-of-range number | accepted silently |
| 23 While operating | Stop above a rate of: | 300-char string | accepted silently |
| 23 While operating | Sent as: | letters | accepted silently |
| 23 While operating | Sent as: | out-of-range number | accepted silently |
| 23 While operating | Sent as: | 300-char string | accepted silently |
| 23 While operating | Weight: | letters | accepted silently |
| 23 While operating | Weight: | out-of-range number | accepted silently |
| 23 While operating | Weight: | 300-char string | accepted silently |
| 23 While operating | Character speed: | letters | accepted silently |
| 23 While operating | Character speed: | out-of-range number | accepted silently |
| 23 While operating | Character speed: | 300-char string | accepted silently |
| 28 Paddle and PTT | Paddle speed | letters | accepted silently |
| 28 Paddle and PTT | Paddle speed | out-of-range number | accepted silently |
| 28 Paddle and PTT | Paddle speed | 300-char string | accepted silently |
| 28 Paddle and PTT | Paddle sidetone | letters | accepted silently |
| 28 Paddle and PTT | Paddle sidetone | out-of-range number | accepted silently |
| 28 Paddle and PTT | Paddle sidetone | 300-char string | accepted silently |
| 28 Paddle and PTT | Hold PTT after the last element | letters | accepted silently |
| 28 Paddle and PTT | Hold PTT after the last element | out-of-range number | accepted silently |
| 28 Paddle and PTT | Hold PTT after the last element | 300-char string | accepted silently |
| 28 Paddle and PTT | Delay after PTT before sending | letters | accepted silently |
| 28 Paddle and PTT | Delay after PTT before sending | out-of-range number | accepted silently |
| 28 Paddle and PTT | Delay after PTT before sending | 300-char string | accepted silently |
| 29 Audio | DVK recording folder | letters | accepted silently |
| 29 Audio | DVK recording folder | out-of-range number | accepted silently |
| 29 Audio | DVK recording folder | 300-char string | accepted silently |
| 29 Audio | DVK recorder program | letters | accepted silently |
| 29 Audio | DVK recorder program | out-of-range number | accepted silently |
| 29 Audio | DVK recorder program | 300-char string | accepted silently |
| 29 Audio | Wake Up Time Out | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 29 Audio | Wake Up Time Out | out-of-range number | filtered while typing to '99999999999' |
| 29 Audio | Wake Up Time Out | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 33 Speed and characters | Code Speed | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 33 Speed and characters | Code Speed | out-of-range number | filtered while typing to '99999999999' |
| 33 Speed and characters | Code Speed | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 33 Speed and characters | Start Sending Now Key | letters | accepted silently |
| 33 Speed and characters | Start Sending Now Key | out-of-range number | accepted silently |
| 33 Speed and characters | Start Sending Now Key | 300-char string | accepted silently |
| 33 Speed and characters | box at [715, 315, 995, 338] | letters | accepted silently |
| 33 Speed and characters | box at [715, 315, 995, 338] | out-of-range number | accepted silently |
| 33 Speed and characters | box at [715, 315, 995, 338] | 300-char string | accepted silently |
| 33 Speed and characters | Short 1 | letters | accepted silently |
| 33 Speed and characters | Short 1 | out-of-range number | accepted silently |
| 33 Speed and characters | Short 1 | 300-char string | accepted silently |
| 33 Speed and characters | Short 2 | letters | accepted silently |
| 33 Speed and characters | Short 2 | out-of-range number | accepted silently |
| 33 Speed and characters | Short 2 | 300-char string | accepted silently |
| 33 Speed and characters | box at [715, 405, 995, 428] | letters | accepted silently |
| 33 Speed and characters | box at [715, 405, 995, 428] | out-of-range number | accepted silently |
| 33 Speed and characters | box at [715, 405, 995, 428] | 300-char string | accepted silently |
| 33 Speed and characters | Question Mark Char | letters | accepted silently |
| 33 Speed and characters | Question Mark Char | out-of-range number | accepted silently |
| 33 Speed and characters | Question Mark Char | 300-char string | accepted silently |
| 33 Speed and characters | Slash Mark Char | letters | accepted silently |
| 33 Speed and characters | Slash Mark Char | out-of-range number | accepted silently |
| 33 Speed and characters | Slash Mark Char | 300-char string | accepted silently |
| 34 Printed log | Log Sub Title | letters | accepted silently |
| 34 Printed log | Log Sub Title | out-of-range number | accepted silently |
| 34 Printed log | Log Sub Title | 300-char string | accepted silently |
| 34 Printed log | Contacts Per Page | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 34 Printed log | Contacts Per Page | out-of-range number | filtered while typing to '99999999999' |
| 34 Printed log | Contacts Per Page | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 35 Entry and dupe checking | Auto S? Enable Sensitivity | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 35 Entry and dupe checking | Auto S? Enable Sensitivity | out-of-range number | filtered while typing to '99999999999' |
| 35 Entry and dupe checking | Auto S? Enable Sensitivity | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 35 Entry and dupe checking | Complete Callsign Mask | letters | accepted silently |
| 35 Entry and dupe checking | Complete Callsign Mask | out-of-range number | accepted silently |
| 35 Entry and dupe checking | Complete Callsign Mask | 300-char string | accepted silently |
| 36 Log display | Custom User String | letters | accepted silently |
| 36 Log display | Custom User String | out-of-range number | accepted silently |
| 36 Log display | Custom User String | 300-char string | accepted silently |
| 37 Files and updates | Country Information File | letters | accepted silently |
| 37 Files and updates | Country Information File | out-of-range number | accepted silently |
| 37 Files and updates | Country Information File | 300-char string | accepted silently |
| 37 Files and updates | Unknown Country File Name | letters | accepted silently |
| 37 Files and updates | Unknown Country File Name | out-of-range number | accepted silently |
| 37 Files and updates | Unknown Country File Name | 300-char string | accepted silently |
| 38 Window and tuning | Band Map Item Width | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 38 Window and tuning | Band Map Item Width | out-of-range number | filtered while typing to '99999999999' |
| 38 Window and tuning | Band Map Item Width | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 39 Spots and console | Telnet Console Lines | letters | Windows number-only balloon; refused while typing (field stayed empty) |
| 39 Spots and console | Telnet Console Lines | out-of-range number | filtered while typing to '99999999999' |
| 39 Spots and console | Telnet Console Lines | 300-char string | Windows number-only balloon; refused while typing (field stayed empty) |
| 42 Quick QSL | Quick QSL CW Message 1 | letters | accepted silently |
| 42 Quick QSL | Quick QSL CW Message 1 | out-of-range number | accepted silently |
| 42 Quick QSL | Quick QSL CW Message 1 | 300-char string | accepted silently |
| 42 Quick QSL | Quick QSL SSB Message | letters | accepted silently |
| 42 Quick QSL | Quick QSL SSB Message | out-of-range number | accepted silently |
| 42 Quick QSL | Quick QSL SSB Message | 300-char string | accepted silently |
| 42 Quick QSL | Quick QSL Key 1 | letters | accepted silently |
| 42 Quick QSL | Quick QSL Key 1 | out-of-range number | accepted silently |
| 42 Quick QSL | Quick QSL Key 1 | 300-char string | accepted silently |
| 42 Quick QSL | Quick QSL Key 2 | letters | accepted silently |
| 42 Quick QSL | Quick QSL Key 2 | out-of-range number | accepted silently |
| 42 Quick QSL | Quick QSL Key 2 | 300-char string | accepted silently |
| 42 Quick QSL | Quick QSL Message 2 | letters | accepted silently |
| 42 Quick QSL | Quick QSL Message 2 | out-of-range number | accepted silently |
| 42 Quick QSL | Quick QSL Message 2 | 300-char string | accepted silently |
| 44 Initial exchange | Initial Exchange Filename | letters | accepted silently |
| 44 Initial exchange | Initial Exchange Filename | out-of-range number | accepted silently |
| 44 Initial exchange | Initial Exchange Filename | 300-char string | accepted silently |
| 44 Initial exchange | Call History Filename | letters | accepted silently |
| 44 Initial exchange | Call History Filename | out-of-range number | accepted silently |
| 44 Initial exchange | Call History Filename | 300-char string | accepted silently |
| 44 Initial exchange | Custom Initial Exchange String | letters | accepted silently |
| 44 Initial exchange | Custom Initial Exchange String | out-of-range number | accepted silently |
| 44 Initial exchange | Custom Initial Exchange String | 300-char string | accepted silently |
| 46 Cabrillo headings | Category-Overlay | letters | accepted silently |
| 46 Cabrillo headings | Category-Overlay | out-of-range number | accepted silently |
| 46 Cabrillo headings | Category-Overlay | 300-char string | accepted silently |
