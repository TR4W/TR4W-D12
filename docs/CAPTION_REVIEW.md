# Caption review - every design-time Caption in src/ui/lcl

`wired` = the unit assigns `<Control>.Caption :=` at runtime, so the .lfm text is a
design-time placeholder the operator never sees.
`SHIPS`  = the .lfm English is what appears on screen.


## uPrefsForm.lfm  (287 ship / 292 total)

- [wired] `uPrefsForm` = `TR4W Preferences`
- [SHIPS] `layContent` = ``
- [SHIPS] `layCW` = ``
- [SHIPS] `lblMyKeyers` = `CW keying devices`
- [SHIPS] `btnAddKeyer` = `Add...`
- [SHIPS] `btnEditKeyer` = `Edit...`
- [SHIPS] `btnDuplicateKeyer` = `Duplicate`
- [SHIPS] `btnRemoveKeyer` = `Remove`
- [SHIPS] `lblCWSendHeading` = `Sending`
- [SHIPS] `chkCWEnable` = `Send CW`
- [SHIPS] `chkCWSpeedFromDatabase` = `Match the speed a station was worked at before`
- [SHIPS] `lblCWSpeedIncrement` = `Speed step:`
- [SHIPS] `lblCWSpeedIncrementUnits` = `WPM per PageUp / PageDown`
- [SHIPS] `lblCWTone` = `Sidetone:`
- [SHIPS] `lblCWToneUnits` = `Hz  (0 = the radios own sidetone)`
- [SHIPS] `chkCWMessagesChainable` = `Any CW message may chain into the next`
- [SHIPS] `chkTuneWithDits` = `Tune with dits rather than a solid carrier`
- [SHIPS] `chkSendFourLetterCall` = `Always send all four letters of a four-letter call`
- [SHIPS] `chkIncludeFKeyNumber` = `Show the key number on the function-key buttons`
- [SHIPS] `layRadios` = ``
- [SHIPS] `lblMyRadios` = `My radios`
- [SHIPS] `btnAdd` = `Add...`
- [SHIPS] `btnEdit` = `Edit...`
- [SHIPS] `btnDuplicate` = `Duplicate`
- [SHIPS] `btnRemove` = `Remove`
- [SHIPS] `grpProfile` = `Station profile`
- [SHIPS] `btnNewProfile` = `New...`
- [SHIPS] `btnRenameProfile` = `Rename...`
- [SHIPS] `btnDeleteProfile` = `Delete`
- [SHIPS] `lblRadio1` = `Radio 1`
- [SHIPS] `lblCWOutput1` = `CW output 1`
- [SHIPS] `chkSpeedSync1` = `Speed sync`
- [SHIPS] `lblRadio2` = `Radio 2`
- [SHIPS] `lblCWOutput2` = `CW output 2`
- [SHIPS] `chkSpeedSync2` = `Speed sync`
- [SHIPS] `chkSO2R` = `SO2R enabled`
- [wired] `lblActive` = `Active profile: `
- [wired] `btnActivate` = `Activate this profile now`
- [SHIPS] `chkAutoConnect` = `Connect radios at startup`
- [SHIPS] `layRotators` = ``
- [SHIPS] `lblMyRotators` = `My rotators`
- [SHIPS] `btnAddRotator` = `Add...`
- [SHIPS] `btnRemoveRotator` = `Remove`
- [SHIPS] `btnUseRotator` = `Use this`
- [wired] `lblActiveRotator` = ``
- [SHIPS] `lblRotatorName` = `Name:`
- [SHIPS] `lblRotatorType` = `Type:`
- [SHIPS] `lblRotatorPort` = `Port:`
- [SHIPS] `lblRotatorBaud` = `Baud rate:`
- [SHIPS] `lblRotatorBaudHint` = `blank or 0 = the default for this type`
- [SHIPS] `lblRotatorIP` = `IP address:`
- [SHIPS] `lblRotatorUDP` = `UDP port:`
- [SHIPS] `lblRotatorBands` = `Bands:`
- [SHIPS] `layUDP` = ``
- [SHIPS] `chkUDPEnabled` = `Broadcast UDP data`
- [SHIPS] `lblUDPDestinations` = `Destinations`
- [SHIPS] `btnUDPAdd` = `Add...`
- [SHIPS] `btnUDPEdit` = `Edit...`
- [SHIPS] `btnUDPRemove` = `Remove`
- [SHIPS] `btnUDPTest` = `Test`
- [SHIPS] `chkUDPAllQSOs` = `Also broadcast edited and previously logged QSOs`
- [SHIPS] `layLogging` = ``
- [SHIPS] `lblLogLevel` = `Log level:`
- [SHIPS] `lblDetailLogs` = `Detailed logging for one subsystem`
- [SHIPS] `chkTelnetDebug` = `DX cluster - log all telnet traffic`
- [SHIPS] `chkTCIDebug` = `TCI server - log every command, both directions`
- [SHIPS] `chkHamLibDebug` = `HamLib - debug logging`
- [SHIPS] `chkHamLibTrace` = `HamLib - internal trace to hamlib_trace.log`
- [SHIPS] `chkHamLibAsyncOnly` = `HamLib - async callbacks only, no heartbeat (testing)`
- [SHIPS] `btnOpenLogFile` = `Open log file`
- [SHIPS] `lblLogFilesHeading` = `Log files`
- [SHIPS] `chkCheckLogFileSize` = `Warn when the log file grows unexpectedly`
- [SHIPS] `chkUnknownCountryFile` = `Record callsigns with no country match`
- [SHIPS] `chkUpdateRestartFile` = `Keep the restart file up to date`
- [SHIPS] `layTCIServer` = ``
- [SHIPS] `chkTCIServer` = `Enable the TCI server`
- [SHIPS] `lblTCIServerScope` = `- this computer only (127.0.0.1), until you tick the box below`
- [SHIPS] `lblTCIPort` = `Port:`
- [SHIPS] `chkTCIBindAll` = `Also listen on the network (other computers can connect)`
- [SHIPS] `lblTCIMaxTx` = `Stop transmitting after:`
- [SHIPS] `lblTCIMaxTxUnits` = `seconds  (0 = no limit)`
- [SHIPS] `layStation` = ``
- [SHIPS] `lblStationHeading` = `Station information`
- [SHIPS] `lblMyCall` = `Callsign:`
- [SHIPS] `lblMyName` = `First name:`
- [SHIPS] `lblMyGrid` = `Grid square:`
- [SHIPS] `lblMyContinent` = `Continent:`
- [SHIPS] `lblMyZone` = `CQ zone:`
- [SHIPS] `lblMyITUZone` = `ITU zone:`
- [SHIPS] `lblMyState` = `State/Province:`
- [SHIPS] `lblMySection` = `ARRL section:`
- [SHIPS] `lblMyCountry` = `Country:`
- [SHIPS] `lblMyPostalCode` = `Postal code:`
- [SHIPS] `lblContestHeading` = `Contest exchange`
- [SHIPS] `lblMyCheck` = `Check:`
- [SHIPS] `lblMyPrec` = `Precedence:`
- [SHIPS] `lblMyFDClass` = `FD class:`
- [SHIPS] `lblMyFOCNumber` = `FOC number:`
- [SHIPS] `lblMyIOTA` = `IOTA:`
- [SHIPS] `lblMyPark` = `Park:`
- [SHIPS] `layWSJTX` = ``
- [SHIPS] `lblWSJTXHeading` = `WSJT-X / JTDX`
- [SHIPS] `chkWSJTXEnabled` = `Exchange data with WSJT-X`
- [SHIPS] `chkWSJTXRadioControl` = `Let WSJT-X control the radio`
- [SHIPS] `chkWSJTXHighlights` = `Send callsign highlighting to WSJT-X`
- [SHIPS] `lblWSJTXPort` = `Broadcast port:`
- [SHIPS] `lblWSJTXMulticast` = `Multicast group:`
- [SHIPS] `layExternalLogger` = ``
- [SHIPS] `lblLoggerHeading` = `External logger`
- [SHIPS] `lblLoggerType` = `Program:`
- [SHIPS] `chkLoggerEnabled` = `Send QSOs to it as they are logged`
- [SHIPS] `lblLoggerAddress` = `Address:`
- [SHIPS] `lblLoggerPort` = `Port:`
- [SHIPS] `layHardware` = ``
- [SHIPS] `lblHardwareHeading` = `Hardware`
- [SHIPS] `lblRelayPort` = `Relay control port`
- [SHIPS] `lblBandOutput1` = `Radio 1 band output port`
- [SHIPS] `lblBandOutput2` = `Radio 2 band output port`
- [SHIPS] `lblStereoPort` = `Stereo control port`
- [SHIPS] `chkUseControlPort` = `Use the radio control port for paddle and foot switch`
- [SHIPS] `chkYCCCSO2R` = `YCCC SO2R Plus box connected`
- [SHIPS] `layPaddlePTT` = ``
- [SHIPS] `lblPaddlePTTHeading` = `Paddle and PTT`
- [SHIPS] `lblPaddleGroup` = `Paddle`
- [SHIPS] `lblPaddleSpeed` = `Paddle speed`
- [SHIPS] `lblPaddleSpeedUnits` = `WPM  (0 follows the keyboard speed)`
- [SHIPS] `lblPaddleTone` = `Paddle sidetone`
- [SHIPS] `lblPaddleToneUnits` = `Hz`
- [SHIPS] `lblPaddleHold` = `Hold PTT after the last element`
- [SHIPS] `lblPaddleHoldUnits` = `dit counts`
- [SHIPS] `chkSwapPaddles` = `Swap dit and dah`
- [SHIPS] `lblPTTGroup` = `PTT`
- [SHIPS] `chkPTTEnable` = `Assert PTT when transmitting`
- [SHIPS] `lblPTTDelay` = `Delay after PTT before sending`
- [SHIPS] `lblPTTDelayUnits` = `x 1.7 ms  (0 disables)`
- [SHIPS] `chkNoPollDuringPTT` = `Stop polling the radio while transmitting`
- [SHIPS] `chkPTTViaCommands` = `Key the transmitter with a CAT command instead of a hardware line`
- [SHIPS] `chkPTTLockout` = `Lock out PTT`
- [SHIPS] `layOperating` = ``
- [SHIPS] `lblOperatingHeading` = `Operating`
- [SHIPS] `lblOperatingInfo` = `How the log behaves while you are running the contest. Band map, bands, CW, scoring and two-radio settings are on the pages below.`
- [SHIPS] `chkAutoReturnToCQ` = `Return to CQ mode after logging a QSO`
- [SHIPS] `chkAutoCallTerminate` = `Stop sending when the call window changes`
- [SHIPS] `chkEscapeExitsSAP` = `Escape leaves search and pounce`
- [SHIPS] `chkLeaveCursorInCall` = `Leave the cursor in the call window`
- [SHIPS] `chkLogWithSingleEnter` = `Log with a single Enter`
- [SHIPS] `chkSpaceBarDupeCheck` = `Space bar performs a dupe check`
- [SHIPS] `chkConfirmEditChanges` = `Confirm before saving an edited QSO`
- [SHIPS] `chkAutoQSONumberDecrement` = `Give the serial number back when a QSO is abandoned`
- [SHIPS] `layAudio` = ``
- [SHIPS] `lblAudioHeading` = `Audio`
- [SHIPS] `lblAudioInfo` = `Voice keying and QSO recording. CW keying is on the CW Settings page.`
- [SHIPS] `cardDVK` = ``
- [SHIPS] `cardDVKInner` = ``
- [SHIPS] `lblDVKHeading` = `Digital voice keyer`
- [SHIPS] `chkDVKEnable` = `Use the digital voice keyer`
- [SHIPS] `chkDVKLocalizedMessages` = `Use localized DVK message files`
- [SHIPS] `chkUseRecordedSigns` = `Send recorded audio for callsign characters`
- [SHIPS] `lblDVKPath` = `DVK recording folder`
- [SHIPS] `btnBrowseDVKPath` = `Browse...`
- [SHIPS] `lblDVKRecorder` = `DVK recorder program`
- [SHIPS] `btnBrowseDVKRecorder` = `Browse...`
- [SHIPS] `cardMP3` = ``
- [SHIPS] `cardMP3Inner` = ``
- [SHIPS] `lblMP3Heading` = `QSO recording`
- [SHIPS] `chkMP3RecorderEnable` = `Record each QSO to MP3`
- [SHIPS] `lblMP3Path` = `MP3 folder`
- [SHIPS] `btnBrowseMP3Path` = `Browse...`
- [SHIPS] `lblMP3Player` = `MP3 player program`
- [SHIPS] `btnBrowseMP3Player` = `Browse...`
- [SHIPS] `lblAudioNote` = `Bit rate and recording length are not here yet: both are stored through a lookup table rather than directly, and move separately.`
- [SHIPS] `layDXLab` = ``
- [SHIPS] `lblDXLabHeading` = `DXLab`
- [SHIPS] `layMMTTY` = ``
- [SHIPS] `lblMMTTYHeading` = `MMTTY`
- [SHIPS] `lblMMTTYEngine` = `Engine:`
- [SHIPS] `btnBrowseMMTTY` = `Browse...`
- [SHIPS] `layCluster` = ``
- [SHIPS] `lblClusterHeading` = `My DX clusters`
- [SHIPS] `btnAddCluster` = `Add...`
- [SHIPS] `btnRemoveCluster` = `Remove`
- [SHIPS] `btnUseCluster` = `Use this`
- [wired] `lblActiveCluster` = `Connecting to: (none chosen)`
- [SHIPS] `lblClusterName` = `Name:`
- [SHIPS] `lblClusterServer` = `Server:`
- [SHIPS] `lblClusterLogin` = `Log in as:`
- [SHIPS] `lblClusterLoginHint` = `blank = my station callsign`
- [SHIPS] `lblClusterPassword` = `Password:`
- [SHIPS] `lblClusterCommand` = `After connecting:`
- [SHIPS] `lblClusterGlobalHeading` = `For every cluster`
- [SHIPS] `chkClusterAtStartup` = `Connect at startup`
- [SHIPS] `chkSpotCollector` = `Collect spots from the cluster`
- [SHIPS] `layBandMap` = ``
- [SHIPS] `lblBandMapHeading` = `Band map`
- [SHIPS] `lblBandMapDecay` = `Spot expiry:`
- [SHIPS] `lblBandMapDecayUnits` = `minutes`
- [SHIPS] `lblBandMapGuard` = `Guard band:`
- [SHIPS] `lblBandMapGuardUnits` = `Hz`
- [SHIPS] `lblBandMapLimit` = `Display limit:`
- [SHIPS] `lblBandMapLimitUnits` = `spots`
- [SHIPS] `chkBandMapDupes` = `Show duplicates`
- [SHIPS] `chkBandMapMultsOnly` = `Multipliers only`
- [SHIPS] `chkBandMapAllBands` = `All bands`
- [SHIPS] `chkBandMapAllModes` = `All modes`
- [SHIPS] `chkBandMapCQ` = `Show CQ spots`
- [SHIPS] `chkBandMapCallWindow` = `Show the call window entry`
- [SHIPS] `chkBandMapSO2R` = `SO2R display`
- [SHIPS] `chkBandMapGHz` = `Show GHz`
- [SHIPS] `chkCallWindowShowAllSpots` = `Show every spot in the call window`
- [SHIPS] `chkSwapPacketSpotRadios` = `Send spots to the other radio`
- [SHIPS] `laySCP` = ``
- [SHIPS] `lblSCPHeading` = `Super Check Partial`
- [SHIPS] `lblSCPMinLetters` = `Start matching after:`
- [SHIPS] `lblSCPMinLettersUnits` = `letters typed`
- [SHIPS] `lblSCPCountry` = `Restrict to countries:`
- [SHIPS] `lblSCPMatchHeading` = `Matching`
- [SHIPS] `chkPossibleCalls` = `Offer possible calls`
- [SHIPS] `chkPartialCall` = `Match on a partial callsign`
- [SHIPS] `chkWildcardPartials` = `Allow wildcards in a partial`
- [SHIPS] `chkNameFlag` = `Flag a station whose name is already known`
- [SHIPS] `layNetwork` = ``
- [SHIPS] `lblNetHeading` = `Multi-operator network`
- [SHIPS] `lblNetAddress` = `Server:`
- [SHIPS] `lblNetPort` = `Port:`
- [SHIPS] `lblNetPassword` = `Password:`
- [SHIPS] `lblNetComputerID` = `This station:`
- [SHIPS] `lblNetComputerIDHint` = `a single letter, unique in the network`
- [SHIPS] `chkNetAutoSync` = `Synchronize the log when connecting`
- [SHIPS] `chkMultiMultsOnly` = `Pass only new multipliers around the network`
- [SHIPS] `chkIntercomFile` = `Log network messages to INTERCOM.TXT`
- [SHIPS] `lblRadioTCPHeading` = `Radio sharing`
- [SHIPS] `lblRadioTCPPort` = `TCP port:`
- [SHIPS] `layAppearance` = ``
- [SHIPS] `lblAppearHeading` = `Main window`
- [SHIPS] `lblMainFont` = `Font:`
- [SHIPS] `lblFontSize` = `Size:`
- [SHIPS] `chkBoldFont` = `Bold`
- [SHIPS] `chkDupeSheetColor` = `Color the dupe sheet columns`
- [SHIPS] `lblMainWindowHeading` = `Main window`
- [SHIPS] `chkNoBorder` = `Main window has no border`
- [SHIPS] `chkNoCaption` = `Main window has no title bar`
- [SHIPS] `chkNoColumnHeader` = `Hide the log column headings`
- [SHIPS] `chkShowGridlines` = `Draw gridlines in the log`
- [SHIPS] `layBackup` = ``
- [SHIPS] `lblBackupHeading` = `Log backup`
- [SHIPS] `lblBackupEvery` = `Back up every:`
- [SHIPS] `lblBackupEveryUnits` = `QSOs  (0 = never)`
- [SHIPS] `lblBackupFile` = `Copy to:`
- [SHIPS] `btnBrowseBackup` = `Browse...`
- [SHIPS] `layOnlineScoring` = ``
- [SHIPS] `lblScoreHeading` = `Online scoring`
- [SHIPS] `chkHamScoreEnable` = `Post my score while the contest runs`
- [SHIPS] `lblHamScoreURL` = `Service URL:`
- [SHIPS] `lblHamScoreUser` = `Username:`
- [SHIPS] `lblHamScorePass` = `Password:`
- [SHIPS] `chkHamScoreContact` = `Include contact information`
- [SHIPS] `lblScoreBoardHeading` = `Score board`
- [SHIPS] `lblScorePostURL` = `Posting URL:`
- [SHIPS] `lblScoreReadURL` = `Reading URL:`
- [SHIPS] `layOperatingCW` = ``
- [SHIPS] `lblOpCWHeading` = `CW while operating`
- [SHIPS] `chkSayHiEnable` = `Send a greeting to stations worked before`
- [SHIPS] `lblSayHiCutoff` = `Stop above a rate of:`
- [SHIPS] `lblSayHiCutoffUnits` = `QSOs per hour`
- [SHIPS] `chkKeypadCWMemories` = `Number keypad sends CW memories`
- [SHIPS] `lblLeadingZeros` = `Leading zeros:`
- [SHIPS] `lblLeadingZeroChar` = `Sent as:`
- [SHIPS] `lblSerialKeyHeading` = `Radio serial keying  (DTR/RTS keying only)`
- [SHIPS] `lblDitDah` = `Dit/dah ratio:`
- [SHIPS] `lblWeight` = `Weight:`
- [SHIPS] `chkFarnsworth` = `Farnsworth spacing`
- [SHIPS] `lblFarnsworthSpeed` = `Character speed:`
- [SHIPS] `lblFarnsworthUnits` = `WPM`
- [SHIPS] `layBands` = ``
- [SHIPS] `lblBandsHeading` = `Bands in use`
- [SHIPS] `chkHFBands` = `HF (160 - 10 m)`
- [SHIPS] `chkWARCBands` = `WARC (30, 17, 12 m)`
- [SHIPS] `chkVHFBands` = `VHF and up (6 m and above)`
- [SHIPS] `layTwoRadio` = ``
- [SHIPS] `lblTwoRadioHeading` = `Two radio operating`
- [SHIPS] `chkTwoRadioMode` = `Two radio mode`
- [SHIPS] `chkAltDBuffer` = `Alt-D remembers what you typed`
- [SHIPS] `chkAltDCQ` = `Alt-D can start a CQ on the second radio`
- [SHIPS] `chkAlwaysBlindCQ` = `Always call a blind CQ`
- [SHIPS] `chkSkipActiveBand` = `Skip the band the other radio is on`
- [SHIPS] `chkInBandLockout` = `Stop both radios landing on one band`
- [SHIPS] `chkQSYInactive` = `QSY the inactive radio when I change band`
- [SHIPS] `chkSwapRelaySense` = `Invert the radio relay sense`
- [SHIPS] `chkWaitForStrength` = `Wait for a signal strength reading before switching`
- [SHIPS] `btnOK` = `Save and close`
- [SHIPS] `btnCancel` = `Cancel`
- [SHIPS] `btnApply` = `Save`

## uRadioEditForm.lfm  (44 ship / 46 total)

- [wired] `uRadioEditForm` = `Radio`
- [SHIPS] `lblName` = `Name`
- [SHIPS] `lblType` = `Radio type`
- [SHIPS] `tabSerial` = `Serial`
- [SHIPS] `lblPort` = `Port`
- [SHIPS] `lblBaud` = `Baud rate`
- [SHIPS] `lblDataBits` = `Data bits`
- [SHIPS] `pnlDataBits` = ``
- [SHIPS] `optData7` = `7`
- [SHIPS] `optData8` = `8`
- [SHIPS] `lblCatRTS` = `CAT RTS`
- [SHIPS] `lblCatDTR` = `CAT DTR`
- [SHIPS] `lblParity` = `Parity`
- [SHIPS] `pnlParity` = ``
- [SHIPS] `optParityNone` = `None`
- [SHIPS] `optParityOdd` = `Odd`
- [SHIPS] `optParityEven` = `Even`
- [SHIPS] `lblStopBits` = `Stop bits`
- [SHIPS] `pnlStopBits` = ``
- [SHIPS] `optStop1` = `1`
- [SHIPS] `optStop2` = `2`
- [SHIPS] `tabNetwork` = `Network`
- [SHIPS] `lblIP` = `IP address`
- [wired] `btnDiscover` = `Discover`
- [SHIPS] `lblFound` = `Found`
- [SHIPS] `lblTCPPort` = `TCP port`
- [SHIPS] `lblUser` = `User name`
- [SHIPS] `lblPassword` = `Password`
- [SHIPS] `tabAdvanced` = `Advanced`
- [SHIPS] `lblStartup` = `Startup command`
- [SHIPS] `lblFilterByte` = `Icom filter byte`
- [SHIPS] `lblDataMode` = `Icom data mode ID`
- [SHIPS] `lblAutoInfo` = `Auto-info level`
- [SHIPS] `lblHamLibID` = `HamLib model ID`
- [SHIPS] `chkUseHamLib` = `Drive through HamLib`
- [SHIPS] `chkWideCW` = `Wide CW filter`
- [SHIPS] `chkFT1000MPReverse` = `FT-1000MP CW reverse`
- [SHIPS] `lblFreqOffset` = `Frequency offset (transverter), Hz`
- [SHIPS] `chkPolling` = `Poll this radio`
- [SHIPS] `lblKeyerPort` = `Keyer output port`
- [SHIPS] `lblCIV` = `CI-V address (hex)`
- [SHIPS] `lblKeyerRTS` = `Keyer RTS line`
- [SHIPS] `lblKeyerStopBits` = `Stop bits`
- [SHIPS] `lblKeyerDTR` = `Keyer DTR line`
- [SHIPS] `btnOK` = `Save and close`
- [SHIPS] `btnCancel` = `Cancel`

## uEditQSOForm.lfm  (43 ship / 43 total)

- [SHIPS] `frmEditQSO` = `Edit QSO`
- [SHIPS] `lblCallsign` = `Callsign`
- [SHIPS] `lblCountryName` = ``
- [SHIPS] `lblRadio` = `RADIO ONE`
- [SHIPS] `lblBand` = `Band`
- [SHIPS] `lblDX` = `DX`
- [SHIPS] `chkDXMult` = `DX Mult`
- [SHIPS] `lblMode` = `Mode`
- [SHIPS] `lblDomestic` = `Domestic`
- [SHIPS] `chkDomesticMult` = `Domestic Mult`
- [SHIPS] `lblFrequency` = `Frequency, Hz`
- [SHIPS] `lblPrefix` = `Prefix`
- [SHIPS] `chkPrefixMult` = `Prefix Mult`
- [SHIPS] `lblDate` = `Date`
- [SHIPS] `lblZone` = `Zone`
- [SHIPS] `chkZoneMult` = `Zone Mult`
- [SHIPS] `lblName` = `Name`
- [SHIPS] `chkNameSent` = `Name Sent`
- [SHIPS] `lblComputerID` = `Computer ID`
- [SHIPS] `lblQTH` = `QTH`
- [SHIPS] `chkInhibitMults` = `Inhibit Mults`
- [SHIPS] `lblQSOPoints` = `QSO points`
- [SHIPS] `lblPostalCode` = `Postal Code`
- [SHIPS] `chkDupe` = `Dupe`
- [SHIPS] `lblAge` = `Age`
- [SHIPS] `lblPower` = `Power`
- [SHIPS] `chkDeleted` = `&Deleted`
- [SHIPS] `lblChapter` = `Chapter`
- [SHIPS] `lblPrecedence` = `Precedence`
- [SHIPS] `chkSAP` = `S&P`
- [SHIPS] `chkXQSO` = `X-QSO`
- [SHIPS] `lblCheck` = `Check`
- [SHIPS] `lblPrefecture` = `Prefecture`
- [SHIPS] `lblClass` = `Class`
- [SHIPS] `lblTenTen` = `Ten Ten Number`
- [SHIPS] `lblNumberSent` = `Number Sent`
- [SHIPS] `lblRSTSent` = `RST sent`
- [SHIPS] `btnPlay` = `&Play`
- [SHIPS] `lblNumberRcvd` = `Number Rcvd`
- [SHIPS] `lblRSTReceived` = `RST received`
- [SHIPS] `btnSave` = `&Save`
- [SHIPS] `lblOperator` = `Operator`
- [SHIPS] `btnCancel` = `Cancel`

## uKeyerEditForm.lfm  (21 ship / 22 total)

- [wired] `uKeyerEditForm` = `CW keying device`
- [SHIPS] `lblName` = `Name`
- [SHIPS] `lblKind` = `Keyer type`
- [SHIPS] `lblPort` = `Port`
- [SHIPS] `grpWinKeyer` = `WinKeyer settings`
- [SHIPS] `lblWKKeyerMode` = `Keyer mode`
- [SHIPS] `lblWKSidetone` = `Sidetone`
- [SHIPS] `lblWKWeight` = `Weight`
- [SHIPS] `lblWKRatio` = `Dit/dah ratio`
- [SHIPS] `lblWKSwitchpoint` = `Switchpoint`
- [SHIPS] `lblWKLeadIn` = `Lead-in`
- [SHIPS] `lblWKTail` = `Tail`
- [SHIPS] `lblWKComp` = `Compensation`
- [SHIPS] `lblWKFirstExt` = `First extension`
- [SHIPS] `chkWKAutospace` = `Auto space`
- [SHIPS] `chkWKCTSpacing` = `CT spacing`
- [SHIPS] `chkWKIgnoreSpeedPot` = `Ignore speed pot`
- [SHIPS] `chkWKSidetoneEnable` = `Sidetone on`
- [SHIPS] `chkWKPaddleOnlySidetone` = `Paddle-only sidetone`
- [SHIPS] `chkWKPaddleSwap` = `Swap paddles`
- [SHIPS] `btnOK` = `Save and close`
- [SHIPS] `btnCancel` = `Cancel`

## uFunctionKeysForm.lfm  (13 ship / 13 total)

- [SHIPS] `uFunctionKeysForm` = `Function keys`
- [SHIPS] `pnlF1` = `F1`
- [SHIPS] `pnlF2` = `F2`
- [SHIPS] `pnlF3` = `F3`
- [SHIPS] `pnlF4` = `F4`
- [SHIPS] `pnlF5` = `F5`
- [SHIPS] `pnlF6` = `F6`
- [SHIPS] `pnlF7` = `F7`
- [SHIPS] `pnlF8` = `F8`
- [SHIPS] `pnlF9` = `F9`
- [SHIPS] `pnlF10` = `F10`
- [SHIPS] `pnlF11` = `F11`
- [SHIPS] `pnlF12` = `F12`

## uUDPDestinationEditForm.lfm  (12 ship / 14 total)

- [SHIPS] `uUDPDestinationEditForm` = `UDP Destination`
- [SHIPS] `lblAddress` = `Address`
- [SHIPS] `lblPort` = `Port`
- [SHIPS] `grpStreams` = `Send this destination`
- [SHIPS] `chkStreamContact` = `Contact info`
- [SHIPS] `chkStreamRadio` = `Radio info`
- [SHIPS] `chkStreamScore` = `Score`
- [SHIPS] `chkStreamRotor` = `Rotor`
- [SHIPS] `chkStreamLookup` = `Callsign lookup`
- [wired] `chkStreamAppInfo` = `App info`
- [SHIPS] `btnTest` = `Test`
- [wired] `lblTestResult` = ``
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uBandMapForm.lfm  (9 ship / 12 total)

- [SHIPS] `frmBandMap` = `Band map`
- [SHIPS] `miAllBands` = `BAND MAP ALL BANDS`
- [SHIPS] `miAllModes` = `BAND MAP ALL MODES`
- [SHIPS] `miDisplayCQ` = `BAND MAP DISPLAY CQ`
- [SHIPS] `miDupeDisplay` = `BAND MAP DUPE DISPLAY`
- [SHIPS] `miMultsOnly` = `BAND MAP MULTS ONLY`
- [SHIPS] `miSep1` = `-`
- [wired] `miDeleteSpot` = `Delete selected spot`
- [wired] `miRemoveAll` = `Remove all spots`
- [SHIPS] `miSep2` = `-`
- [wired] `miQSYInactive` = `Send spot to inactive radio`
- [SHIPS] `miSO2RDisplay` = `BAND MAP SO2R DISPLAY`

## uRadioPanelForm.lfm  (7 ship / 7 total)

- [SHIPS] `frmRadioPanel` = `Radio`
- [SHIPS] `lblVFOACaption` = `VFO A`
- [SHIPS] `lblVFOBCaption` = `VFO B`
- [SHIPS] `lblRIT` = `RIT`
- [SHIPS] `lblXIT` = `XIT`
- [SHIPS] `lblSplit` = `SPLIT`
- [SHIPS] `btnSpectrum` = `Spectrum`

## uTelnetForm.lfm  (7 ship / 8 total)

- [SHIPS] `frmTelnet` = `Telnet`
- [SHIPS] `btnConnect` = `Connect`
- [SHIPS] `btnDisconnect` = `Disconnect`
- [wired] `btnFreeze` = `Freeze`
- [SHIPS] `btnClear` = `Clear`
- [SHIPS] `btnCommands` = `Commands`
- [SHIPS] `btnShow50` = `SH/50`
- [SHIPS] `btnSend` = `Send`

## uHamScoreForm.lfm  (5 ship / 6 total)

- [SHIPS] `frmHamScore` = `HamScore`
- [SHIPS] `lblQueueTitle` = `Queued contacts:`
- [wired] `lblQueueValue` = `--`
- [SHIPS] `lblStatusTitle` = `Last status:`
- [SHIPS] `btnPushNow` = `Push Now`
- [SHIPS] `btnResync` = `Resync from log`

## uPanadapterForm.lfm  (4 ship / 9 total)

- [SHIPS] `frmPanadapter` = `Panadapter`
- [SHIPS] `pnlTop` = ``
- [wired] `lblSource` = `Pan A`
- [wired] `lblStatus` = `Disconnected`
- [wired] `btnPause` = `Pause`
- [wired] `lblScale` = `80 dB`
- [wired] `lblSpan` = `Span --`
- [SHIPS] `btnSpanNarrow` = `-`
- [SHIPS] `btnSpanWide` = `+`

## uAltDForm.lfm  (3 ship / 4 total)

- [SHIPS] `frmAltD` = `Dupe Check On Inactive Radio`
- [wired] `lblPrompt` = `Enter call to be checked on:`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uAutoCQForm.lfm  (3 ship / 5 total)

- [SHIPS] `frmAutoCQ` = `Auto-CQ`
- [wired] `lblMemoryKey` = `Press the memory key you want to repeat:`
- [wired] `lblDelay` = `Number of milliseconds of listening time:`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uBandPlanForm.lfm  (3 ship / 3 total)

- [SHIPS] `frmBandPlan` = `Band plan`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uEditMessageForm.lfm  (3 ship / 7 total)

- [SHIPS] `frmEditMessage` = `Program message`
- [wired] `lblMessage` = `Message`
- [wired] `lblCaption` = `Caption`
- [wired] `btnEditWav` = `&Edit`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`
- [wired] `btnList` = `List of commands`

## uIniRetireForm.lfm  (3 ship / 5 total)

- [SHIPS] `frmIniRetire` = `Old settings file`
- [wired] `lblPrompt` = `lblPrompt`
- [wired] `chkDontAsk` = `chkDontAsk`
- [SHIPS] `btnYes` = `&Yes`
- [SHIPS] `btnNo` = `&No`

## uInputQueryForm.lfm  (3 ship / 4 total)

- [SHIPS] `frmInputQuery` = `TR4W`
- [wired] `lblPrompt` = `Enter value:`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uLPTForm.lfm  (3 ship / 3 total)

- [SHIPS] `frmLPT` = `LPT`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uMessagesListForm.lfm  (3 ship / 3 total)

- [SHIPS] `frmMessagesList` = `List of commands`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uSendSpotForm.lfm  (3 ship / 7 total)

- [SHIPS] `frmSendSpot` = `Send spot`
- [wired] `lblCallsign` = `Callsign`
- [wired] `lblFrequency` = `Frequency`
- [wired] `lblComment` = `Comment`
- [wired] `chkContestName` = `Contest name in comment`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uWinManagerForm.lfm  (3 ship / 3 total)

- [SHIPS] `frmWinManager` = `Window control`
- [SHIPS] `btnOK` = `OK`
- [SHIPS] `btnCancel` = `Cancel`

## uAboutForm.lfm  (2 ship / 3 total)

- [SHIPS] `uAboutForm` = `About TR4W`
- [wired] `lblURL` = `http://www.tr4w.net`
- [SHIPS] `btnOK` = `OK`

## uMP3RecorderForm.lfm  (2 ship / 3 total)

- [SHIPS] `frmMP3Recorder` = `MP3 Recorder`
- [wired] `chkRecord` = `Record`
- [SHIPS] `btnControl` = `...`

## uSendKeyboardForm.lfm  (2 ship / 2 total)

- [SHIPS] `frmSendKeyboard` = `Sending CW`
- [SHIPS] `btnClose` = `Close`

## uBeaconsForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmBeacons` = `Beacons monitor`

## uCT1BOHForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmCT1BOH` = `CT1BOH information`

## uDupeSheetForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmDupeSheet` = `Dupe sheet`

## uIntercomForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmIntercom` = `Intercom`

## uLogCompareForm.lfm  (1 ship / 4 total)

- [SHIPS] `frmLogCompare` = `Differences in the log`
- [wired] `btnSynchronize` = `Synchronize`
- [wired] `btnClearAllLogs` = `Clear all logs`
- [wired] `btnExit` = `Exit`

## uMMTTYForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmMMTTY` = `MMTTY`

## uMainForm.lfm  (1 ship / 1 total)

- [SHIPS] `TR4WMainForm` = `TR4W`

## uMasterForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmMaster` = `Super check partial`

## uNetworkForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmNetwork` = `Network`

## uPostScoresForm.lfm  (1 ship / 3 total)

- [SHIPS] `frmPostScores` = `Post scores`
- [wired] `btnPostNow` = `Post now`
- [wired] `btnShowScores` = `Show scores`

## uRemMultsForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmRemMults` = `Remaining mults`

## uStationsForm.lfm  (1 ship / 1 total)

- [SHIPS] `frmStations` = `Stations`

## uProgramMessageForm.lfm  (0 ship / 4 total)

- [wired] `uProgramMessageForm` = `Memory program function`
- [wired] `btnCQ` = `Press &C to program a CQ function key.`
- [wired] `btnExchange` = `Press &E to program an exchange/search and pounce function key.`
- [wired] `btnOther` = `Press &O to program the other non function key messages.`
