# Command reference

**Find a setting by its current name or an older name from the reference manual.**

This reference combines the current settings inventory, source declarations, English help, and the v4.01 manual contents. It targets the same 5.0.22 snapshot as this guide.

There are **288 settings** with **298 accepted names**, plus **4 action commands** documented separately. Radio, keyer, message, and compatibility command routes are not all ordinary settings.

## Browse by name

- [Commands A–D](a-d.md)
- [Commands E–L](e-l.md)
- [Commands M–P](m-p.md)
- [Commands Q–S](q-s.md)
- [Commands T–Z](t-z.md)
- [Old-to-new lookup](legacy-map.md)
- [Actions and moved configuration](lifecycle.md)
- [Coverage and review gaps](coverage.md)

## Read an entry

- **Station** settings belong to the station settings model; **Contest** settings are captured with the contest. Do not carry forward the old manual’s INI/CFG storage column as a current editing recipe.
- **Initial value** means a direct literal in the source constructor. Loading a station, a contest definition, or a saved database can change it. An unextracted value is not an empty or zero default.
- **Values** gives boolean choices or literal numeric type bounds when available. Other validation can apply; numeric bounds do not establish units.
- **Other accepted names** are inventory aliases. They do not imply that every input route applies the value.
- **Inherited help** is useful background, not a reviewed 5.x procedure. Older hotkeys, file paths, default values, and platform assumptions require checking.

Prefer the settings UI. Current command dispatch can recognize a name without applying it, depending on the caller and ownership. Recognition alone does not prove a legacy config line takes effect.

## Topic starting points

- [Log backup](../../log/backup.md)
- [Radio connection](../../station/radio.md)
- [WSJT-X](../../station/wsjtx.md)
- [POTA](../../operating/pota.md)

## All current setting names

| Name | Scope |
| --- | --- |
| [ALERT COLOR](a-d.md#alert-color) | Station |
| [ALL CW MESSAGES CHAINABLE](a-d.md#all-cw-messages-chainable) | Station |
| [ALLOW AUTO UPDATE](a-d.md#allow-auto-update) | Station |
| [ALT-D BUFFER ENABLE](a-d.md#alt-d-buffer-enable) | Station |
| [ALT-D CQ ENABLE](a-d.md#alt-d-cq-enable) | Station |
| [ALWAYS CALL BLIND CQ](a-d.md#always-call-blind-cq) | Station |
| [ASK FOR FREQUENCIES](a-d.md#ask-for-frequencies) | Station |
| [AUTO CALL TERMINATE](a-d.md#auto-call-terminate) | Station |
| [AUTO DISPLAY DUPE QSO](a-d.md#auto-display-dupe-qso) | Station |
| [AUTO DUPE ENABLE CQ](a-d.md#auto-dupe-enable-cq) | Contest |
| [AUTO DUPE ENABLE S AND P](a-d.md#auto-dupe-enable-s-and-p) | Contest |
| [AUTO QSL INTERVAL](a-d.md#auto-qsl-interval) | Station |
| [AUTO QSO NUMBER DECREMENT](a-d.md#auto-qso-number-decrement) | Station |
| [AUTO RETURN TO CQ MODE](a-d.md#auto-return-to-cq-mode) | Station |
| [AUTO S&amp;P ENABLE](a-d.md#auto-s-p-enable) | Station |
| [AUTO S&amp;P ENABLE SENSITIVITY](a-d.md#auto-s-p-enable-sensitivity) | Station |
| [AUTO SEND CHARACTER COUNT](a-d.md#auto-send-character-count) | Station |
| [AUTO TIME INCREMENT](a-d.md#auto-time-increment) | Station |
| [AUTO-CQ DELAY TIME](a-d.md#auto-cq-delay-time) | Station |
| [BACKUP LOG FILE NAME](a-d.md#backup-log-file-name) | Station |
| [BACKUP LOG FREQUENCY](a-d.md#backup-log-frequency) | Station |
| [BAND](a-d.md#band) | Contest |
| [BAND MAP ALL BANDS](a-d.md#band-map-all-bands) | Station |
| [BAND MAP ALL MODES](a-d.md#band-map-all-modes) | Station |
| [BAND MAP CALL WINDOW ENABLE](a-d.md#band-map-call-window-enable) | Station |
| [BAND MAP DECAY TIME](a-d.md#band-map-decay-time) | Station |
| [BAND MAP DISPLAY CQ](a-d.md#band-map-display-cq) | Station |
| [BAND MAP DISPLAY GHZ](a-d.md#band-map-display-ghz) | Station |
| [BAND MAP DISPLAY LIMIT](a-d.md#band-map-display-limit) | Station |
| [BAND MAP DUPE DISPLAY](a-d.md#band-map-dupe-display) | Station |
| [BAND MAP GUARD BAND](a-d.md#band-map-guard-band) | Station |
| [BAND MAP ITEM HEIGHT](a-d.md#band-map-item-height) | Station |
| [BAND MAP ITEM WIDTH](a-d.md#band-map-item-width) | Station |
| [BAND MAP MULTS ONLY](a-d.md#band-map-mults-only) | Station |
| [BAND MAP SIZE](a-d.md#band-map-size) | Station |
| [BAND MAP SO2R DISPLAY](a-d.md#band-map-so2r-display) | Station |
| [BAND MAP SPLIT MODE](a-d.md#band-map-split-mode) | Station |
| [BEEP ENABLE](a-d.md#beep-enable) | Station |
| [BEEP EVERY 10 QSOS](a-d.md#beep-every-10-qsos) | Station |
| [BOLD FONT](a-d.md#bold-font) | Station |
| [BROADCAST ALL PACKET DATA](a-d.md#broadcast-all-packet-data) | Station |
| [CALL OK NOW CW MESSAGE](a-d.md#call-ok-now-cw-message) | Contest |
| [CALL OK NOW SSB MESSAGE](a-d.md#call-ok-now-ssb-message) | Contest |
| [CALL WINDOW SHOW ALL SPOTS](a-d.md#call-window-show-all-spots) | Station |
| [CALLSIGN UPDATE ENABLE](a-d.md#callsign-update-enable) | Station |
| [CATEGORY-ASSISTED](a-d.md#category-assisted) | Contest |
| [CATEGORY-BAND](a-d.md#category-band) | Contest |
| [CATEGORY-MODE](a-d.md#category-mode) | Contest |
| [CATEGORY-OPERATOR](a-d.md#category-operator) | Contest |
| [CATEGORY-OVERLAY](a-d.md#category-overlay) | Contest |
| [CATEGORY-POWER](a-d.md#category-power) | Contest |
| [CATEGORY-TRANSMITTER](a-d.md#category-transmitter) | Contest |
| [CHECK LOG FILE SIZE](a-d.md#check-log-file-size) | Station |
| [CODE SPEED](a-d.md#code-speed) | Station |
| [COLUMN AUTOSIZE](a-d.md#column-autosize) | Station |
| [COMPLETE CALLSIGN MASK](a-d.md#complete-callsign-mask) | Station |
| [COMPUTER ID](a-d.md#computer-id) | Station |
| [COMPUTER NAME](a-d.md#computer-name) | Station |
| [CONFIRM EDIT CHANGES](a-d.md#confirm-edit-changes) | Station |
| [CONNECTION AT STARTUP](a-d.md#connection-at-startup) | Station |
| [CONTACTS PER PAGE](a-d.md#contacts-per-page) | Contest |
| [CONTEST](a-d.md#contest) | Contest |
| [CONTEST NAME](a-d.md#contest-name) | Contest |
| [CONTEST TITLE](a-d.md#contest-title) | Contest |
| [COUNT DOMESTIC COUNTRIES](a-d.md#count-domestic-countries) | Contest |
| [COUNTRY INFORMATION FILE](a-d.md#country-information-file) | Station |
| [CQ CW EXCHANGE](a-d.md#cq-cw-exchange) | Contest |
| [CQ CW EXCHANGE NAME KNOWN](a-d.md#cq-cw-exchange-name-known) | Contest |
| [CQ SSB EXCHANGE](a-d.md#cq-ssb-exchange) | Contest |
| [CQ SSB EXCHANGE NAME KNOWN](a-d.md#cq-ssb-exchange-name-known) | Contest |
| [CTY UPDATE CHECK ON STARTUP](a-d.md#cty-update-check-on-startup) | Station |
| [CUSTOM INITIAL EXCHANGE STRING](a-d.md#custom-initial-exchange-string) | Contest |
| [CUSTOM USER STRING](a-d.md#custom-user-string) | Station |
| [CW ENABLE](a-d.md#cw-enable) | Station |
| [CW SPEED FROM DATABASE](a-d.md#cw-speed-from-database) | Station |
| [CW SPEED INCREMENT](a-d.md#cw-speed-increment) | Station |
| [CW TONE](a-d.md#cw-tone) | Station |
| [DE ENABLE](a-d.md#de-enable) | Station |
| [DEBUG LOG LEVEL](a-d.md#debug-log-level) | Station |
| [DIGITAL MODE ENABLE](a-d.md#digital-mode-enable) | Contest |
| [DISPLAY LANGUAGE](a-d.md#display-language) | Station |
| [DISTANCE MODE](a-d.md#distance-mode) | Station |
| [DIT DAH RATIO](a-d.md#dit-dah-ratio) | Station |
| [DOMESTIC FILENAME](a-d.md#domestic-filename) | Contest |
| [DOMESTIC MULTIPLIER](a-d.md#domestic-multiplier) | Contest |
| [DUPE CHECK SOUND](a-d.md#dupe-check-sound) | Station |
| [DUPE SHEET AUTO RESET](a-d.md#dupe-sheet-auto-reset) | Station |
| [DVK ENABLE](a-d.md#dvk-enable) | Station |
| [DVK LOCALIZED MESSAGES ENABLE](a-d.md#dvk-localized-messages-enable) | Station |
| [DVK PATH](a-d.md#dvk-path) | Station |
| [DVK RECORDER](a-d.md#dvk-recorder) | Station |
| [DX MULTIPLIER](a-d.md#dx-multiplier) | Contest |
| [ESCAPE EXITS SEARCH AND POUNCE](e-l.md#escape-exits-search-and-pounce) | Station |
| [EXCHANGE MEMORY ENABLE](e-l.md#exchange-memory-enable) | Contest |
| [EXCHANGE RECEIVED](e-l.md#exchange-received) | Contest |
| [EXTERNAL LOGGER](e-l.md#external-logger) | Station |
| [EXTERNAL LOGGER ADDRESS](e-l.md#external-logger-address) | Station |
| [EXTERNAL LOGGER ENABLED](e-l.md#external-logger-enabled) | Station |
| [EXTERNAL LOGGER PORT](e-l.md#external-logger-port) | Station |
| [FARNSWORTH ENABLE](e-l.md#farnsworth-enable) | Station |
| [FARNSWORTH SPEED](e-l.md#farnsworth-speed) | Station |
| [FONT SIZE](e-l.md#font-size) | Station |
| [FREQUENCY MEMORY ENABLE](e-l.md#frequency-memory-enable) | Station |
| [FREQUENCY POLL RATE](e-l.md#frequency-poll-rate) | Station |
| [GRID MAP CENTER](e-l.md#grid-map-center) | Station |
| [HAMSCORE ENABLE](e-l.md#hamscore-enable) | Contest |
| [HAMSCORE PASSWORD](e-l.md#hamscore-password) | Station |
| [HAMSCORE SEND CONTACT INFO](e-l.md#hamscore-send-contact-info) | Station |
| [HAMSCORE URL](e-l.md#hamscore-url) | Station |
| [HAMSCORE USERNAME](e-l.md#hamscore-username) | Station |
| [HAND LOG MODE](e-l.md#hand-log-mode) | Station |
| [HF BAND ENABLE](e-l.md#hf-band-enable) | Contest |
| [HOUR DISPLAY](e-l.md#hour-display) | Station |
| [IE SWITCH](e-l.md#ie-switch) | Station |
| [IN BAND LOCKOUT](e-l.md#in-band-lockout) | Station |
| [INCLUDE F-KEY NUMBER](e-l.md#include-f-key-number) | Station |
| [INCREMENT TIME ENABLE](e-l.md#increment-time-enable) | Station |
| [INITIAL EXCHANGE](e-l.md#initial-exchange) | Contest |
| [INITIAL EXCHANGE CURSOR POS](e-l.md#initial-exchange-cursor-pos) | Contest |
| [INITIAL EXCHANGE FILENAME](e-l.md#initial-exchange-filename) | Contest |
| [INITIAL EXCHANGE OVERWRITE](e-l.md#initial-exchange-overwrite) | Contest |
| [INSERT MODE](e-l.md#insert-mode) | Station |
| [INTERCOM FILE ENABLE](e-l.md#intercom-file-enable) | Station |
| [KEYPAD CW MEMORIES](e-l.md#keypad-cw-memories) | Station |
| [LEADING ZERO CHARACTER](e-l.md#leading-zero-character) | Station |
| [LEADING ZEROS](e-l.md#leading-zeros) | Station |
| [LEAVE CURSOR IN CALL WINDOW](e-l.md#leave-cursor-in-call-window) | Station |
| [LITERAL DOMESTIC QTH](e-l.md#literal-domestic-qth) | Contest |
| [LOG FREQUENCY ENABLE](e-l.md#log-frequency-enable) | Station |
| [LOG RS SENT](e-l.md#log-rs-sent) | Station |
| [LOG RST SENT](e-l.md#log-rst-sent) | Station |
| [LOG SUB TITLE](e-l.md#log-sub-title) | Station |
| [LOG WITH SINGLE ENTER](e-l.md#log-with-single-enter) | Station |
| [LOOK FOR RST SENT](e-l.md#look-for-rst-sent) | Station |
| [MAIN CALLSIGN](m-p.md#main-callsign) | Station |
| [MAIN FONT](m-p.md#main-font) | Station |
| [MESSAGE ENABLE](m-p.md#message-enable) | Station |
| [MINITOUR DURATION](m-p.md#minitour-duration) | Contest |
| [MISSINGCALLSIGNS FILE ENABLE](m-p.md#missingcallsigns-file-enable) | Station |
| [MMTTY ENGINE](m-p.md#mmtty-engine) | Station |
| [MODE](m-p.md#mode) | Contest |
| [MULT BY BAND](m-p.md#mult-by-band) | Contest |
| [MULT BY MODE](m-p.md#mult-by-mode) | Contest |
| [MULT REPORT MINIMUM BANDS](m-p.md#mult-report-minimum-bands) | Contest |
| [MULT SHEET AUTO RESET](m-p.md#mult-sheet-auto-reset) | Contest |
| [MULTI MULTS ONLY](m-p.md#multi-mults-only) | Station |
| [MULTIPLE BANDS](m-p.md#multiple-bands) | Contest |
| [MULTIPLE MODES](m-p.md#multiple-modes) | Contest |
| [MY CALL](m-p.md#my-call) | Station |
| [MY CHECK](m-p.md#my-check) | Station |
| [MY CONTINENT](m-p.md#my-continent) | Contest |
| [MY COUNTRY](m-p.md#my-country) | Station |
| [MY FD CLASS](m-p.md#my-fd-class) | Station |
| [MY FOC NUMBER](m-p.md#my-foc-number) | Station |
| [MY GRID](m-p.md#my-grid) | Station |
| [MY IOTA](m-p.md#my-iota) | Station |
| [MY ITU ZONE](m-p.md#my-itu-zone) | Station |
| [MY NAME](m-p.md#my-name) | Station |
| [MY PARK](m-p.md#my-park) | Station |
| [MY POSTAL CODE](m-p.md#my-postal-code) | Station |
| [MY PREC](m-p.md#my-prec) | Station |
| [MY SECTION](m-p.md#my-section) | Station |
| [MY STATE](m-p.md#my-state) | Station |
| [MY ZONE](m-p.md#my-zone) | Station |
| [NAME FLAG ENABLE](m-p.md#name-flag-enable) | Station |
| [NET STATUS UPDATE INTERVAL](m-p.md#net-status-update-interval) | Station |
| [NO BORDER](m-p.md#no-border) | Station |
| [NO CAPTION](m-p.md#no-caption) | Station |
| [NO COLUMN HEADER](m-p.md#no-column-header) | Station |
| [NO LOG](m-p.md#no-log) | Station |
| [NO POLL DURING PTT](m-p.md#no-poll-during-ptt) | Station |
| [OPERATING STANDARD EDIT KEYS](m-p.md#operating-standard-edit-keys) | Station |
| [PADDLE MONITOR TONE](m-p.md#paddle-monitor-tone) | Station |
| [PADDLE PTT HOLD COUNT](m-p.md#paddle-ptt-hold-count) | Station |
| [PADDLE SPEED](m-p.md#paddle-speed) | Station |
| [PARTIAL CALL ENABLE](m-p.md#partial-call-enable) | Station |
| [POSSIBLE CALL ACCEPT KEY](m-p.md#possible-call-accept-key) | Station |
| [POSSIBLE CALL LEFT KEY](m-p.md#possible-call-left-key) | Station |
| [POSSIBLE CALL MODE](m-p.md#possible-call-mode) | Station |
| [POSSIBLE CALL RIGHT KEY](m-p.md#possible-call-right-key) | Station |
| [POSSIBLE CALLS](m-p.md#possible-calls) | Station |
| [PREFIX MULTIPLIER](m-p.md#prefix-multiplier) | Contest |
| [PSTROTATOR IP ADDRESS](m-p.md#pstrotator-ip-address) | Station |
| [PSTROTATOR UDP PORT](m-p.md#pstrotator-udp-port) | Station |
| [PTT ENABLE](m-p.md#ptt-enable) | Station |
| [PTT LOCKOUT](m-p.md#ptt-lockout) | Station |
| [PTT TURN ON DELAY](m-p.md#ptt-turn-on-delay) | Station |
| [PTT VIA COMMANDS](m-p.md#ptt-via-commands) | Station |
| [QSL CW MESSAGE](q-s.md#qsl-cw-message) | Contest |
| [QSL MODE](q-s.md#qsl-mode) | Contest |
| [QSL SSB MESSAGE](q-s.md#qsl-ssb-message) | Contest |
| [QSO BEFORE CW MESSAGE](q-s.md#qso-before-cw-message) | Contest |
| [QSO BEFORE SSB MESSAGE](q-s.md#qso-before-ssb-message) | Contest |
| [QSO BY BAND](q-s.md#qso-by-band) | Contest |
| [QSO BY MODE](q-s.md#qso-by-mode) | Contest |
| [QSO NUMBER BY BAND](q-s.md#qso-number-by-band) | Contest |
| [QSO POINT METHOD](q-s.md#qso-point-method) | Contest |
| [QSO POINTS DOMESTIC CW](q-s.md#qso-points-domestic-cw) | Contest |
| [QSO POINTS DOMESTIC PHONE](q-s.md#qso-points-domestic-phone) | Contest |
| [QSO POINTS DX CW](q-s.md#qso-points-dx-cw) | Contest |
| [QSO POINTS DX PHONE](q-s.md#qso-points-dx-phone) | Contest |
| [QSX ENABLE](q-s.md#qsx-enable) | Station |
| [QSY INACTIVE RADIO](q-s.md#qsy-inactive-radio) | Station |
| [QTC ENABLE](q-s.md#qtc-enable) | Contest |
| [QTC EXTRA SPACE](q-s.md#qtc-extra-space) | Contest |
| [QTC MINUTES](q-s.md#qtc-minutes) | Contest |
| [QTC QRS](q-s.md#qtc-qrs) | Contest |
| [QUESTION MARK CHAR](q-s.md#question-mark-char) | Station |
| [QUICK QSL CW MESSAGE](q-s.md#quick-qsl-cw-message) | Contest |
| [QUICK QSL KEY 1](q-s.md#quick-qsl-key-1) | Station |
| [QUICK QSL KEY 2](q-s.md#quick-qsl-key-2) | Station |
| [QUICK QSL MESSAGE 2](q-s.md#quick-qsl-message-2) | Contest |
| [QUICK QSL SSB MESSAGE](q-s.md#quick-qsl-ssb-message) | Contest |
| [QZB RANDOM OFFSET ENABLE](q-s.md#qzb-random-offset-enable) | Station |
| [R150S MODE](q-s.md#r150s-mode) | Contest |
| [RADIO TCP SERVER PORT](q-s.md#radio-tcp-server-port) | Station |
| [RADIUS OF EARTH](q-s.md#radius-of-earth) | Station |
| [RANDOM CQ MODE](q-s.md#random-cq-mode) | Station |
| [RATE DISPLAY](q-s.md#rate-display) | Station |
| [REMAINING MULT DISPLAY MODE](q-s.md#remaining-mult-display-mode) | Station |
| [REPEAT S&amp;P CW EXCHANGE](q-s.md#repeat-s-p-cw-exchange) | Contest |
| [REPEAT S&amp;P SSB EXCHANGE](q-s.md#repeat-s-p-ssb-exchange) | Contest |
| [REVERSE INITIAL EX](q-s.md#reverse-initial-ex) | Station |
| [RFOBL MODE](q-s.md#rfobl-mode) | Contest |
| [ROTATOR PORT](q-s.md#rotator-port) | Station |
| [ROTATOR TYPE](q-s.md#rotator-type) | Station |
| [ROW COUNT](q-s.md#row-count) | Station |
| [S&amp;P CW EXCHANGE](q-s.md#s-p-cw-exchange) | Contest |
| [S&amp;P SSB EXCHANGE](q-s.md#s-p-ssb-exchange) | Contest |
| [SAY HI ENABLE](q-s.md#say-hi-enable) | Station |
| [SAY HI RATE CUTOFF](q-s.md#say-hi-rate-cutoff) | Station |
| [SCORE POSTING URL](q-s.md#score-posting-url) | Station |
| [SCORE READING URL](q-s.md#score-reading-url) | Station |
| [SCP COUNTRY STRING](q-s.md#scp-country-string) | Station |
| [SCP MINIMUM LETTERS](q-s.md#scp-minimum-letters) | Station |
| [SEND COMPLETE FOUR LETTER CALL](q-s.md#send-complete-four-letter-call) | Station |
| [SERVER ADDRESS](q-s.md#server-address) | Station |
| [SERVER AUTO SYNCHRONIZE LOG ON CONNECT](q-s.md#server-auto-synchronize-log-on-connect) | Station |
| [SERVER PASSWORD](q-s.md#server-password) | Station |
| [SERVER PORT](q-s.md#server-port) | Station |
| [SHIFT KEY ENABLE](q-s.md#shift-key-enable) | Station |
| [SHORT 0](q-s.md#short-0) | Station |
| [SHORT 1](q-s.md#short-1) | Station |
| [SHORT 2](q-s.md#short-2) | Station |
| [SHORT 9](q-s.md#short-9) | Station |
| [SHORT INTEGERS](q-s.md#short-integers) | Station |
| [SHOW ALL SERIAL PORTS](q-s.md#show-all-serial-ports) | Station |
| [SHOW DOMESTIC MULTIPLIER NAME](q-s.md#show-domestic-multiplier-name) | Station |
| [SHOW FREQUENCY IN LOG](q-s.md#show-frequency-in-log) | Station |
| [SHOW GRIDLINES](q-s.md#show-gridlines) | Station |
| [SHOW TYPED CALLSIGN](q-s.md#show-typed-callsign) | Station |
| [SINGLE BAND SCORE](q-s.md#single-band-score) | Contest |
| [SKIP ACTIVE BAND](q-s.md#skip-active-band) | Station |
| [SLASH MARK CHAR](q-s.md#slash-mark-char) | Station |
| [SPACE BAR DUPE CHECK ENABLE](q-s.md#space-bar-dupe-check-enable) | Station |
| [SPOT COLLECTOR ENABLED](q-s.md#spot-collector-enabled) | Station |
| [SPRINT QSY RULE](q-s.md#sprint-qsy-rule) | Contest |
| [START SENDING NOW KEY](q-s.md#start-sending-now-key) | Station |
| [STATIONS CALLSIGNS MASK](q-s.md#stations-callsigns-mask) | Station |
| [STEREO PIN HIGH](q-s.md#stereo-pin-high) | Station |
| [SWAP PACKET SPOT RADIOS](q-s.md#swap-packet-spot-radios) | Station |
| [SWAP PADDLES](q-s.md#swap-paddles) | Station |
| [SWAP RADIO RELAY SENSE](q-s.md#swap-radio-relay-sense) | Station |
| [TELNET CONSOLE LINES](t-z.md#telnet-console-lines) | Station |
| [TELNET SERVER](t-z.md#telnet-server) | Station |
| [TEN MINUTE RULE](t-z.md#ten-minute-rule) | Station |
| [TUNE ALT-D ENABLE](t-z.md#tune-alt-d-enable) | Station |
| [TUNE WITH DITS](t-z.md#tune-with-dits) | Station |
| [TWO RADIO MODE](t-z.md#two-radio-mode) | Station |
| [UNKNOWN COUNTRY FILE ENABLE](t-z.md#unknown-country-file-enable) | Station |
| [UNKNOWN COUNTRY FILE NAME](t-z.md#unknown-country-file-name) | Station |
| [UPDATE RESTART FILE ENABLE](t-z.md#update-restart-file-enable) | Station |
| [USE RECORDED SIGNS](t-z.md#use-recorded-signs) | Station |
| [USER INFO SHOWN](t-z.md#user-info-shown) | Station |
| [VHF BAND ENABLE](t-z.md#vhf-band-enable) | Contest |
| [WAIT FOR STRENGTH](t-z.md#wait-for-strength) | Station |
| [WAKE UP TIME OUT](t-z.md#wake-up-time-out) | Station |
| [WARC BAND ENABLE](t-z.md#warc-band-enable) | Contest |
| [WEIGHT](t-z.md#weight) | Station |
| [WILDCARD PARTIALS](t-z.md#wildcard-partials) | Station |
| [WINDOW SIZE](t-z.md#window-size) | Station |
| [WSJT-X BROADCAST PORT](t-z.md#wsjt-x-broadcast-port) | Station |
| [WSJT-X ENABLED](t-z.md#wsjt-x-enabled) | Station |
| [WSJT-X MULTICAST GROUP](t-z.md#wsjt-x-multicast-group) | Station |
| [WSJT-X RADIO CONTROL ENABLED](t-z.md#wsjt-x-radio-control-enabled) | Station |
| [WSJT-X SEND HIGHLIGHTS](t-z.md#wsjt-x-send-highlights) | Station |
| [YCCC SO2R ENABLE](t-z.md#yccc-so2r-enable) | Station |
| [ZONE MULTIPLIER](t-z.md#zone-multiplier) | Contest |
