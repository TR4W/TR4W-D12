# TR4W settings inventory

Every setting TR4W accepts, where its value lives, and whether it belongs
to the STATION or to the CONTEST.

**The Notes column is yours.** Write `move` in it for anything filed in the
wrong place and I will move it; write a confirmation for anything you have
checked. The rest of the table is generated, so do not hand-edit it -- see
the note on regeneration at the bottom.

## What the two scopes mean, because the distinction is the point

**global** -- a property of the STATION. It lives in `settings/tr4w.json`,
survives every contest, and is the same whatever you are operating. A
callsign, a keyer port, a cluster host.

**CONTEST** -- a property of the CONTEST. It is captured into the contest
database and deliberately kept OUT of the station settings file, because
the contest chooses it and nothing sets it back afterwards. Whether a
multiplier counts per band, what a QSO is worth, which bands are in play.

The test for which one a setting is: **if the contest file assigns it and
nothing ever restores it, it is the contest's.** That is why the band
enables are contest-scoped even though they look like station preferences --
the contest definition assigns all three the moment a contest loads.

## A name that misleads, and is on its way out

`Config.<field>` in the source is **not** the contest config. It is a global
record variable holding station settings, and it exists only because the
config array is a table of ADDRESSES -- a record field has one at link time
where a property does not. It is a staging post: every row that reaches the
settings model leaves the record, and it is down to a handful of fields.
Read `Config.X` as "a station setting that has not finished moving yet".

## Settings that have moved (238)

These are published properties. The command name is DERIVED from the
property path unless an alias says otherwise, and an alias exists only
where the historic name cannot be derived -- a hyphen, a subject that
comes last, a word run together.

| Command | Also accepted as | Scope | Lives at | Type | Notes |
|---|---|---|---|---|---|
| `ALL CW MESSAGES CHAINABLE` |  | global | `Settings.Cw.AllMessagesChainable` | boolean |  |
| `ALLOW AUTO UPDATE` |  | global | `Settings.Network.AllowAutoUpdate` | boolean |  |
| `ALT-D BUFFER ENABLE` |  | global | `Settings.AltD.BufferEnable` | boolean |  |
| `ALT-D CQ ENABLE` |  | global | `Settings.AltD.CqEnable` | boolean |  |
| `ALWAYS CALL BLIND CQ` |  | global | `Settings.Cq.AlwaysCallBlind` | boolean |  |
| `ASK FOR FREQUENCIES` |  | global | `Settings.Operating.AskForFrequencies` | boolean |  |
| `AUTO CALL TERMINATE` |  | global | `Settings.Cq.AutoCallTerminate` | boolean |  |
| `AUTO DISPLAY DUPE QSO` |  | global | `Settings.DupeSheet.AutoDisplayQso` | boolean |  |
| `AUTO DUPE ENABLE CQ` |  | **CONTEST** | `Settings.AutoDupe.EnableCq` | boolean |  |
| `AUTO DUPE ENABLE S AND P` |  | **CONTEST** | `Settings.AutoDupe.EnableSAndP` | boolean |  |
| `AUTO QSL INTERVAL` |  | global | `Settings.Message.AutoQslInterval` | TAutoQslInterval |  |
| `AUTO QSO NUMBER DECREMENT` |  | global | `Settings.Operating.AutoQsoNumberDecrement` | boolean |  |
| `AUTO RETURN TO CQ MODE` |  | global | `Settings.Cq.AutoReturnToMode` | boolean |  |
| `AUTO S&P ENABLE` |  | global | `Settings.AutoSap.Enable` | boolean |  |
| `AUTO S&P ENABLE SENSITIVITY` |  | global | `Settings.AutoSap.Sensitivity` | TAutoSapSensitivity |  |
| `AUTO SEND CHARACTER COUNT` |  | global | `Settings.Cw.AutoSendCharacterCount` | TAutoSendCharacterCount |  |
| `AUTO TIME INCREMENT` |  | global | `Settings.Operating.AutoTimeIncrement` | TAutoTimeIncrement |  |
| `AUTO-CQ DELAY TIME` |  | global | `Settings.Cq.AutoDelay` | TAutoCqDelay |  |
| `BACKUP LOG FREQUENCY` |  | global | `Settings.Log.BackupFrequency` | TBackupLogFrequency |  |
| `BAND MAP ALL BANDS` |  | global | `Settings.BandMap.AllBands` | boolean |  |
| `BAND MAP ALL MODES` |  | global | `Settings.BandMap.AllModes` | boolean |  |
| `BAND MAP CALL WINDOW ENABLE` |  | global | `Settings.BandMap.CallWindowEnable` | boolean |  |
| `BAND MAP DECAY TIME` |  | global | `Settings.BandMap.DecayTime` | TBandMapDecayTime |  |
| `BAND MAP DISPLAY CQ` |  | global | `Settings.BandMap.DisplayCQ` | boolean |  |
| `BAND MAP DISPLAY GHZ` |  | global | `Settings.BandMap.DisplayGhz` | boolean |  |
| `BAND MAP DISPLAY LIMIT` |  | global | `Settings.BandMap.DisplayLimit` | TBandMapDisplayLimit |  |
| `BAND MAP DUPE DISPLAY` |  | global | `Settings.BandMap.DupeDisplay` | boolean |  |
| `BAND MAP GUARD BAND` |  | global | `Settings.BandMap.GuardBand` | TBandMapGuardBand |  |
| `BAND MAP ITEM HEIGHT` |  | global | `Settings.BandMap.ItemHeight` | TBandMapItemHeight |  |
| `BAND MAP ITEM WIDTH` |  | global | `Settings.BandMap.ItemWidth` | TBandMapItemWidth |  |
| `BAND MAP MULTS ONLY` |  | global | `Settings.BandMap.MultsOnly` | boolean |  |
| `BAND MAP SIZE` |  | global | `Settings.BandMap.Size` | TBandMapSize |  |
| `BAND MAP SO2R DISPLAY` |  | global | `Settings.BandMap.So2rDisplay` | boolean |  |
| `BEEP ENABLE` |  | global | `Settings.Operating.BeepEnable` | boolean |  |
| `BEEP EVERY 10 QSOS` |  | global | `Settings.Log.BeepEvery10Qsos` | boolean |  |
| `BOLD FONT` |  | global | `Settings.Font.Bold` | boolean |  |
| `BROADCAST ALL PACKET DATA` |  | global | `Settings.Cluster.BroadcastAllPacketData` | boolean |  |
| `CALL OK NOW CW MESSAGE` | `CALL OK NOW MESSAGE` | **CONTEST** | `Settings.Messages.CallOkNowCw` | string |  |
| `CALL OK NOW SSB MESSAGE` |  | **CONTEST** | `Settings.Messages.CallOkNowSsb` | string |  |
| `CALL WINDOW SHOW ALL SPOTS` |  | global | `Settings.CallWindow.ShowAllSpots` | boolean |  |
| `CALLSIGN UPDATE ENABLE` |  | global | `Settings.CallWindow.CallsignUpdateEnable` | boolean | moved 2026-09-12, and now defaults TRUE |
| `CHECK LOG FILE SIZE` |  | global | `Settings.Log.CheckFileSize` | boolean |  |
| `COLUMN AUTOSIZE` |  | global | `Settings.Log.ColumnAutoSize` | boolean |  |
| `COMPLETE CALLSIGN MASK` |  | global | `Settings.CallWindow.CompleteCallsignMask` | string |  |
| `COMPUTER ID` |  | global | `Settings.Computer.Id` | AnsiChar |  |
| `COMPUTER NAME` |  | global | `Settings.Computer.Name` | string |  |
| `CONFIRM EDIT CHANGES` |  | global | `Settings.Log.ConfirmEditChanges` | boolean |  |
| `CONNECTION AT STARTUP` |  | global | `Settings.Cluster.ConnectionAtStartup` | boolean |  |
| `CONTACTS PER PAGE` |  | **CONTEST** | `Settings.Contest.ContactsPerPage` | TContactsPerPage |  |
| `COUNT DOMESTIC COUNTRIES` |  | **CONTEST** | `Settings.Contest.CountDomesticCountries` | boolean |  |
| `COUNTRY INFORMATION FILE` |  | global | `Settings.Country.InformationFile` | string |  |
| `CQ CW EXCHANGE` | `CQ EXCHANGE` | **CONTEST** | `Settings.Messages.CqExchangeCw` | string |  |
| `CQ CW EXCHANGE NAME KNOWN` | `CQ EXCHANGE NAME KNOWN` | **CONTEST** | `Settings.Messages.CqExchangeCwNameKnown` | string |  |
| `CQ SSB EXCHANGE` |  | **CONTEST** | `Settings.Messages.CqExchangeSsb` | string |  |
| `CQ SSB EXCHANGE NAME KNOWN` |  | **CONTEST** | `Settings.Messages.CqExchangeSsbNameKnown` | string |  |
| `CTY UPDATE CHECK ON STARTUP` |  | global | `Settings.Country.UpdateCheckOnStartup` | boolean |  |
| `CUSTOM INITIAL EXCHANGE STRING` |  | **CONTEST** | `Settings.Contest.CustomInitialExchangeString` | string |  |
| `CUSTOM USER STRING` |  | global | `Settings.Operating.CustomUserString` | string |  |
| `CW SPEED FROM DATABASE` |  | global | `Settings.Cw.SpeedFromDatabase` | boolean |  |
| `CW SPEED INCREMENT` |  | global | `Settings.Cw.SpeedIncrement` | TCwSpeedIncrement |  |
| `DE ENABLE` |  | global | `Settings.Message.DeEnable` | boolean |  |
| `DIGITAL MODE ENABLE` |  | **CONTEST** | `Settings.Contest.DigitalModeEnable` | boolean |  |
| `DIT DAH RATIO` |  | global | `Settings.Cw.DitDahRatio` | TCwDitDahRatio |  |
| `DOMESTIC FILENAME` |  | **CONTEST** | `Settings.Contest.DomesticFilename` | string |  |
| `DUPE SHEET AUTO RESET` |  | global | `Settings.DupeSheet.AutoReset` | boolean |  |
| `DVK ENABLE` |  | global | `Settings.Dvk.Enable` | boolean |  |
| `DVK LOCALIZED MESSAGES ENABLE` |  | global | `Settings.Dvk.LocalizedMessagesEnable` | boolean |  |
| `ESCAPE EXITS SEARCH AND POUNCE` |  | global | `Settings.Cq.EscapeExitsSearchAndPounce` | boolean |  |
| `EXCHANGE MEMORY ENABLE` |  | **CONTEST** | `Settings.Contest.ExchangeMemoryEnable` | boolean |  |
| `EXTERNAL LOGGER ADDRESS` |  | global | `Settings.ExternalLogger.Address` | string |  |
| `EXTERNAL LOGGER ENABLED` |  | global | `Settings.ExternalLogger.Enabled` | boolean |  |
| `EXTERNAL LOGGER PORT` |  | global | `Settings.ExternalLogger.Port` | integer |  |
| `FONT SIZE` |  | global | `Settings.Font.Size` | TMainFontSize |  |
| `FREQUENCY MEMORY ENABLE` |  | global | `Settings.Operating.FrequencyMemoryEnable` | boolean |  |
| `FREQUENCY POLL RATE` |  | global | `Settings.Operating.FrequencyPollRate` | TFreqPollRate |  |
| `GRID MAP CENTER` |  | global | `Settings.GridMap.Center` | string |  |
| `HAMSCORE ENABLE` |  | **CONTEST** | `Settings.Contest.HamscoreEnable` | boolean | moved 2026-09-12; URL and credentials stay with the station |
| `HAMSCORE PASSWORD` |  | global | `Settings.Hamscore.Password` | TSecretText |  |
| `HAMSCORE SEND CONTACT INFO` |  | global | `Settings.Hamscore.SendContactInfo` | boolean |  |
| `HAMSCORE URL` |  | global | `Settings.Hamscore.Url` | string |  |
| `HAMSCORE USERNAME` |  | global | `Settings.Hamscore.Username` | TCaseSensitiveText |  |
| `HAND LOG MODE` |  | global | `Settings.Operating.HandLogMode` | boolean |  |
| `HF BAND ENABLE` |  | **CONTEST** | `Settings.Bands.HfEnabled` | boolean |  |
| `IE SWITCH` |  | global | `Settings.Operating.IeSwitch` | boolean |  |
| `IN BAND LOCKOUT` |  | global | `Settings.So2r.InBandLockout` | boolean |  |
| `INCLUDE F-KEY NUMBER` |  | global | `Settings.Cw.IncludeFKeyNumber` | boolean |  |
| `INCREMENT TIME ENABLE` |  | global | `Settings.Operating.IncrementTimeEnable` | boolean |  |
| `INITIAL EXCHANGE OVERWRITE` |  | **CONTEST** | `Settings.Contest.InitialExchangeOverwrite` | boolean |  |
| `INSERT MODE` |  | global | `Settings.CallWindow.InsertMode` | boolean |  |
| `INTERCOM FILE ENABLE` |  | global | `Settings.Network.IntercomFileEnable` | boolean |  |
| `KEYPAD CW MEMORIES` |  | global | `Settings.Cw.KeypadMemories` | boolean |  |
| `LEADING ZERO CHARACTER` |  | global | `Settings.Cw.LeadingZeroCharacter` | AnsiChar |  |
| `LEADING ZEROS` |  | global | `Settings.Cw.LeadingZeros` | TCwLeadingZeros |  |
| `LEAVE CURSOR IN CALL WINDOW` |  | global | `Settings.CallWindow.LeaveCursor` | boolean |  |
| `LITERAL DOMESTIC QTH` |  | **CONTEST** | `Settings.Contest.LiteralDomesticQth` | boolean |  |
| `LOG FREQUENCY ENABLE` |  | global | `Settings.Log.FrequencyEnable` | boolean |  |
| `LOG RS SENT` |  | global | `Settings.Log.RsSent` | TLogRsSent |  |
| `LOG RST SENT` |  | global | `Settings.Log.RstSent` | TLogRstSent |  |
| `LOG SUB TITLE` |  | global | `Settings.Operating.LogSubTitle` | string |  |
| `LOG WITH SINGLE ENTER` |  | global | `Settings.Log.WithSingleEnter` | boolean |  |
| `LOOK FOR RST SENT` |  | global | `Settings.Log.LookForRstSent` | boolean |  |
| `MAIN CALLSIGN` |  | global | `Settings.My.MainCallsign` | string |  |
| `MAIN FONT` |  | global | `Settings.Font.Face` | string |  |
| `MESSAGE ENABLE` |  | global | `Settings.Message.Enable` | boolean |  |
| `MINITOUR DURATION` |  | **CONTEST** | `Settings.Contest.MinitourDuration` | TTourDuration |  |
| `MISSINGCALLSIGNS FILE ENABLE` |  | global | `Settings.Dvk.MissingCallsignsFileEnable` | boolean |  |
| `MMTTY ENGINE` |  | global | `Settings.Mmtty.Engine` | string |  |
| `MP3 RECORDER ENABLE` |  | global | `Settings.Mp3.RecorderEnable` | boolean |  |
| `MULT BY BAND` |  | **CONTEST** | `Settings.Mult.ByBand` | boolean |  |
| `MULT BY MODE` |  | **CONTEST** | `Settings.Mult.ByMode` | boolean |  |
| `MULT SHEET AUTO RESET` |  | **CONTEST** | `Settings.Mult.SheetAutoReset` | boolean |  |
| `MULTI MULTS ONLY` |  | global | `Settings.Network.MultiMultsOnly` | boolean |  |
| `MULTIPLE BANDS` |  | **CONTEST** | `Settings.Contest.MultipleBands` | boolean |  |
| `MULTIPLE MODES` |  | **CONTEST** | `Settings.Contest.MultipleModes` | boolean |  |
| `MY CALL` |  | global | `Settings.My.Call` | string |  |
| `MY CHECK` |  | global | `Settings.My.Check` | string |  |
| `MY COUNTRY` |  | global | `Settings.My.Country` | string |  |
| `MY FD CLASS` |  | global | `Settings.My.FdClass` | string |  |
| `MY FOC NUMBER` |  | global | `Settings.My.FocNumber` | string |  |
| `MY GRID` |  | global | `Settings.My.Grid` | string |  |
| `MY IOTA` |  | global | `Settings.My.Iota` | string |  |
| `MY ITU ZONE` |  | global | `Settings.My.ItuZone` | TMyItuZone |  |
| `MY NAME` |  | global | `Settings.My.Name` | string |  |
| `MY PARK` |  | global | `Settings.My.Park` | string |  |
| `MY POSTAL CODE` |  | global | `Settings.My.PostalCode` | string |  |
| `MY PREC` |  | global | `Settings.My.Prec` | string |  |
| `MY SECTION` |  | global | `Settings.My.Section` | string |  |
| `MY STATE` | `MY QTH` | global | `Settings.My.State` | string |  |
| `MY ZONE` |  | global | `Settings.My.Zone` | string |  |
| `NAME FLAG ENABLE` |  | global | `Settings.Scp.NameFlagEnable` | boolean |  |
| `NET STATUS UPDATE INTERVAL` |  | global | `Settings.Network.StatusUpdateInterval` | TNetStatusInterval |  |
| `NO BORDER` |  | global | `Settings.MainWindow.NoBorder` | boolean |  |
| `NO CAPTION` |  | global | `Settings.MainWindow.NoCaption` | boolean |  |
| `NO COLUMN HEADER` |  | global | `Settings.MainWindow.NoColumnHeader` | boolean |  |
| `NO LOG` |  | global | `Settings.Log.Disabled` | boolean |  |
| `NO POLL DURING PTT` |  | global | `Settings.Ptt.NoPollDuring` | boolean |  |
| `PADDLE MONITOR TONE` |  | global | `Settings.Paddle.MonitorTone` | TPaddleMonitorTone |  |
| `PADDLE PTT HOLD COUNT` |  | global | `Settings.Paddle.PttHoldCount` | TPaddlePttHoldCount |  |
| `PADDLE SPEED` |  | global | `Settings.Paddle.Speed` | TPaddleSpeed |  |
| `PARTIAL CALL ENABLE` |  | global | `Settings.CallWindow.PartialCallEnable` | boolean |  |
| `POSSIBLE CALL ACCEPT KEY` |  | global | `Settings.PossibleCall.AcceptKey` | Char |  |
| `POSSIBLE CALL LEFT KEY` |  | global | `Settings.PossibleCall.LeftKey` | Char |  |
| `POSSIBLE CALL RIGHT KEY` |  | global | `Settings.PossibleCall.RightKey` | Char |  |
| `POSSIBLE CALLS` |  | global | `Settings.PossibleCall.Enable` | boolean |  |
| `PSTROTATOR IP ADDRESS` |  | global | `Settings.Rotator.IpAddress` | string |  |
| `PSTROTATOR UDP PORT` |  | global | `Settings.Rotator.UdpPort` | TRotatorUdpPort |  |
| `PTT ENABLE` |  | global | `Settings.Ptt.Enable` | boolean |  |
| `PTT LOCKOUT` |  | global | `Settings.Ptt.Lockout` | boolean |  |
| `PTT TURN ON DELAY` |  | global | `Settings.Ptt.TurnOnDelay` | TPttTurnOnDelay |  |
| `PTT VIA COMMANDS` |  | global | `Settings.Ptt.ViaCommands` | boolean |  |
| `QSL CW MESSAGE` | `QSL MESSAGE` | **CONTEST** | `Settings.Messages.QslCw` | string |  |
| `QSL SSB MESSAGE` |  | **CONTEST** | `Settings.Messages.QslSsb` | string |  |
| `QSO BEFORE CW MESSAGE` | `QSO BEFORE MESSAGE` | **CONTEST** | `Settings.Messages.QsoBeforeCw` | string |  |
| `QSO BEFORE SSB MESSAGE` |  | **CONTEST** | `Settings.Messages.QsoBeforeSsb` | string |  |
| `QSO BY BAND` |  | **CONTEST** | `Settings.Qso.ByBand` | boolean |  |
| `QSO BY MODE` |  | **CONTEST** | `Settings.Qso.ByMode` | boolean |  |
| `QSO NUMBER BY BAND` |  | **CONTEST** | `Settings.Contest.QsoNumberByBand` | boolean |  |
| `QSO POINTS DOMESTIC CW` |  | **CONTEST** | `Settings.Qso.PointsDomesticCw` | TQsoPoints |  |
| `QSO POINTS DOMESTIC PHONE` |  | **CONTEST** | `Settings.Qso.PointsDomesticPhone` | TQsoPoints |  |
| `QSO POINTS DX CW` |  | **CONTEST** | `Settings.Qso.PointsDxCw` | TQsoPoints |  |
| `QSO POINTS DX PHONE` |  | **CONTEST** | `Settings.Qso.PointsDxPhone` | TQsoPoints |  |
| `QSX ENABLE` |  | global | `Settings.Qsx.Enable` | boolean |  |
| `QSY INACTIVE RADIO` |  | global | `Settings.So2r.QsyInactiveRadio` | boolean |  |
| `QTC ENABLE` |  | **CONTEST** | `Settings.Qtc.Enable` | boolean |  |
| `QTC EXTRA SPACE` |  | **CONTEST** | `Settings.Qtc.ExtraSpace` | boolean |  |
| `QTC MINUTES` |  | **CONTEST** | `Settings.Qtc.Minutes` | boolean |  |
| `QTC QRS` |  | **CONTEST** | `Settings.Qtc.Qrs` | boolean |  |
| `QUESTION MARK CHAR` |  | global | `Settings.Cw.QuestionMarkChar` | Char |  |
| `QUICK QSL CW MESSAGE` | `QUICK QSL CW MESSAGE1, QUICK QSL MESSAGE 1` | **CONTEST** | `Settings.Messages.QuickQslCw1` | string |  |
| `QUICK QSL KEY 1` |  | global | `Settings.Message.QuickQslKey1` | Char |  |
| `QUICK QSL KEY 2` |  | global | `Settings.Message.QuickQslKey2` | Char |  |
| `QUICK QSL MESSAGE 2` |  | **CONTEST** | `Settings.Messages.QuickQslCw2` | string |  |
| `QUICK QSL SSB MESSAGE` |  | **CONTEST** | `Settings.Messages.QuickQslSsb` | string |  |
| `QZB RANDOM OFFSET ENABLE` |  | global | `Settings.Qzb.RandomOffsetEnable` | boolean |  |
| `R150S MODE` |  | **CONTEST** | `Settings.Contest.R150SMode` | boolean |  |
| `RADIO TCP SERVER PORT` |  | global | `Settings.Radio.TcpServerPort` | integer |  |
| `RADIUS OF EARTH` |  | global | `Settings.GridMap.RadiusOfEarth` | double |  |
| `RANDOM CQ MODE` |  | global | `Settings.Cq.RandomMode` | boolean |  |
| `REPEAT S&P CW EXCHANGE` | `REPEAT S&P EXCHANGE` | **CONTEST** | `Settings.Messages.RepeatSpExchangeCw` | string |  |
| `REPEAT S&P SSB EXCHANGE` |  | **CONTEST** | `Settings.Messages.RepeatSpExchangeSsb` | string |  |
| `REVERSE INITIAL EX` |  | global | `Settings.InitialExchange.Reverse` | boolean |  |
| `RFOBL MODE` |  | **CONTEST** | `Settings.Contest.RfoblMode` | boolean |  |
| `ROW COUNT` |  | global | `Settings.MainWindow.RowCount` | TLogRowCount |  |
| `S&P CW EXCHANGE` | `S&P EXCHANGE` | **CONTEST** | `Settings.Messages.SpExchangeCw` | string |  |
| `S&P SSB EXCHANGE` |  | **CONTEST** | `Settings.Messages.SpExchangeSsb` | string |  |
| `SAY HI ENABLE` |  | global | `Settings.SayHi.Enable` | boolean |  |
| `SAY HI RATE CUTOFF` |  | global | `Settings.SayHi.RateCutoff` | TSayHiRateCutoff |  |
| `SCORE POSTING URL` |  | global | `Settings.Score.PostingUrl` | string |  |
| `SCORE READING URL` |  | global | `Settings.Score.ReadingUrl` | string |  |
| `SCP MINIMUM LETTERS` |  | global | `Settings.Scp.MinimumLetters` | integer |  |
| `SEND COMPLETE FOUR LETTER CALL` |  | global | `Settings.Cw.SendCompleteFourLetterCall` | boolean |  |
| `SERVER ADDRESS` |  | global | `Settings.Server.Address` | string |  |
| `SERVER AUTO SYNCHRONIZE LOG ON CONNECT` |  | global | `Settings.Server.AutoSynchronizeLogOnConnect` | boolean |  |
| `SERVER PASSWORD` |  | global | `Settings.Server.Password` | TSecretText |  |
| `SERVER PORT` |  | global | `Settings.Server.Port` | TServerPort |  |
| `SHIFT KEY ENABLE` |  | global | `Settings.Operating.ShiftKeyEnable` | boolean |  |
| `SHORT 0` |  | global | `Settings.Cw.Short0` | AnsiChar |  |
| `SHORT 1` |  | global | `Settings.Cw.Short1` | AnsiChar |  |
| `SHORT 2` |  | global | `Settings.Cw.Short2` | AnsiChar |  |
| `SHORT 9` |  | global | `Settings.Cw.Short9` | AnsiChar |  |
| `SHORT INTEGERS` |  | global | `Settings.Cw.ShortIntegers` | boolean |  |
| `SHOW ALL SERIAL PORTS` |  | global | `Settings.SerialPorts.ShowAll` | boolean |  |
| `SHOW DOMESTIC MULTIPLIER NAME` |  | global | `Settings.RemainingMults.ShowDomesticName` | boolean |  |
| `SHOW FREQUENCY IN LOG` |  | global | `Settings.Log.ShowFrequency` | boolean |  |
| `SHOW GRIDLINES` |  | global | `Settings.MainWindow.ShowGridlines` | boolean |  |
| `SHOW TYPED CALLSIGN` |  | global | `Settings.Network.ShowTypedCallsign` | boolean |  |
| `SKIP ACTIVE BAND` |  | global | `Settings.So2r.SkipActiveBand` | boolean |  |
| `SLASH MARK CHAR` |  | global | `Settings.Cw.SlashMarkChar` | Char |  |
| `SPACE BAR DUPE CHECK ENABLE` |  | global | `Settings.CallWindow.SpaceBarDupeCheck` | boolean |  |
| `SPOT COLLECTOR ENABLED` |  | global | `Settings.SpotCollector.Enabled` | boolean |  |
| `SPRINT QSY RULE` |  | **CONTEST** | `Settings.Contest.SprintQsyRule` | boolean |  |
| `START SENDING NOW KEY` |  | global | `Settings.Cw.StartSendingNowKey` | Char |  |
| `STATIONS CALLSIGNS MASK` |  | global | `Settings.Stations.CallsignsMask` | string |  |
| `STEREO CONTROL PIN` |  | global | `Settings.Hardware.StereoControlPin` | integer |  |
| `SWAP PACKET SPOT RADIOS` |  | global | `Settings.So2r.SwapPacketSpotRadios` | boolean |  |
| `SWAP PADDLES` |  | global | `Settings.Paddle.Swap` | boolean |  |
| `SWAP RADIO RELAY SENSE` |  | global | `Settings.So2r.SwapRelaySense` | boolean |  |
| `TELNET SERVER` |  | global | `Settings.Telnet.Server` | string |  |
| `TUNE ALT-D ENABLE` |  | global | `Settings.Operating.TuneAltDEnable` | boolean |  |
| `TUNE WITH DITS` |  | global | `Settings.Cw.TuneWithDits` | boolean |  |
| `TWO RADIO MODE` |  | global | `Settings.So2r.TwoRadioMode` | boolean |  |
| `UNKNOWN COUNTRY FILE ENABLE` |  | global | `Settings.UnknownCountryFile.Enable` | boolean |  |
| `UNKNOWN COUNTRY FILE NAME` |  | global | `Settings.UnknownCountryFile.Name` | string |  |
| `UPDATE RESTART FILE ENABLE` |  | global | `Settings.Log.UpdateRestartFile` | boolean |  |
| `USE CONTROL PORT` |  | global | `Settings.Hardware.UseControlPort` | boolean |  |
| `USE RECORDED SIGNS` |  | global | `Settings.Dvk.UseRecordedSigns` | boolean |  |
| `VHF BAND ENABLE` |  | **CONTEST** | `Settings.Bands.VhfEnabled` | boolean |  |
| `WAIT FOR STRENGTH` |  | global | `Settings.So2r.WaitForStrength` | boolean |  |
| `WAKE UP TIME OUT` |  | global | `Settings.Operating.WakeUpTimeOut` | TWakeUpTimeOut |  |
| `WARC BAND ENABLE` |  | **CONTEST** | `Settings.Bands.WarcEnabled` | boolean |  |
| `WILDCARD PARTIALS` |  | global | `Settings.CallWindow.WildcardPartials` | boolean |  |
| `WINDOW SIZE` |  | global | `Settings.MainWindow.WindowSize` | TMainWindowSize |  |
| `WSJT-X BROADCAST PORT` |  | global | `Settings.Wsjtx.BroadcastPort` | TWsjtxPort |  |
| `WSJT-X ENABLED` |  | global | `Settings.Wsjtx.Enabled` | boolean |  |
| `WSJT-X MULTICAST GROUP` |  | global | `Settings.Wsjtx.MulticastGroup` | string |  |
| `WSJT-X RADIO CONTROL ENABLED` |  | global | `Settings.Wsjtx.RadioControlEnabled` | boolean |  |
| `WSJT-X SEND HIGHLIGHTS` |  | global | `Settings.Wsjtx.SendHighlights` | boolean |  |
| `YCCC SO2R ENABLE` |  | global | `Settings.Yccc.So2rEnable` | boolean |  |

## Settings still in the config array (137)

Each of these still writes through a table of addresses. The **Why still
here** column is the reason it has not moved; an empty one means nothing is
stopping it and it is simply next in line.

The **Written to a contest file** column is the config array's own flag for
whether a value was ever saved into a contest `.cfg`. Treat it as a HINT and
not as the answer: nothing in the program reads that flag any more, so it
records what somebody intended years ago rather than what happens now. It is
here because it is evidence, and because where it disagrees with your
instinct one of the two is worth looking at.

| Command | Written to a contest file | Type | Why still here | Notes |
|---|---|---|---|---|
| `ADD DOMESTIC COUNTRY` | no | ctString | an accumulating LIST, not a value |  |
| `BACKUP LOG FILE NAME` | no | ctFileName | path type -- same ruling |  |
| `BAND` | yes | ctBand |  |  |
| `BAND MAP CUTOFF FREQUENCY` | no | ctFreqList | an accumulating LIST, not a value |  |
| `BAND MAP SPLIT MODE` | no | ctOther |  |  |
| `CATEGORY-ASSISTED` | yes | ctOther |  |  |
| `CATEGORY-BAND` | yes | ctOther |  |  |
| `CATEGORY-MODE` | yes | ctOther |  |  |
| `CATEGORY-OPERATOR` | yes | ctOther |  |  |
| `CATEGORY-POWER` | yes | ctOther |  |  |
| `CATEGORY-TRANSMITTER` | yes | ctOther |  |  |
| `CLEAR DUPE SHEET` | no | ctBoolean | an ACTION, not a setting |  |
| `CODE SPEED` | no | ctInteger | live session state -- a global for ALL keyers, not a setting |  |
| `CONNECTION COMMAND` | no | ctString | the cluster library writes it -- two models to merge |  |
| `CONTEST` | no | ctOther |  |  |
| `CONTEST NAME` | no | ctString | derived by FCONTEST at run time, and carries a hook |  |
| `CONTEST TITLE` | no | ctString | derived by FCONTEST at run time from the year and name |  |
| `CW ENABLE` | no | ctBoolean | live session state -- control codes change it mid-message |  |
| `CW TONE` | no | ctInteger | live session state -- changed by a control code |  |
| `DEBUG LOG LEVEL` | no | ctOther |  |  |
| `DISTANCE MODE` | no | ctOther |  |  |
| `DOMESTIC MULTIPLIER` | no | ctMultiplier |  |  |
| `DUPE CHECK SOUND` | no | ctOther |  |  |
| `DVK PATH` | no | ctDirectory | path type -- what a path setting validates is undecided |  |
| `DVK RECORDER` | no | ctFileName | path type -- same ruling |  |
| `DX MULTIPLIER` | no | ctMultiplier |  |  |
| `EXCHANGE RECEIVED` | no | ctOther |  |  |
| `EXTERNAL LOGGER` | no | ctOther |  |  |
| `FARNSWORTH ENABLE` | no | ctBoolean | live session state |  |
| `FARNSWORTH SPEED` | no | ctInteger | live session state |  |
| `FREQUENCY MEMORY` | no | ctFreqList | an accumulating LIST, not a value |  |
| `HOUR DISPLAY` | no | ctOther |  |  |
| `INITIAL EXCHANGE` | yes | ctOther |  |  |
| `INITIAL EXCHANGE CURSOR POS` | yes | ctOther |  |  |
| `INITIAL EXCHANGE FILENAME` | yes | ctFilename | path type -- same ruling |  |
| `KEYER RADIO ONE OUTPUT PORT` | no | ctOther |  |  |
| `KEYER RADIO TWO OUTPUT PORT` | no | ctOther |  |  |
| `LPT1 BASE ADDRESS` | no | ctInteger | port identity track |  |
| `LPT2 BASE ADDRESS` | no | ctInteger | port identity track |  |
| `LPT3 BASE ADDRESS` | no | ctInteger | port identity track |  |
| `MODE` | yes | ctOther |  |  |
| `MP3 PATH` | no | ctDirectory | path type -- same ruling |  |
| `MP3 PLAYER` | no | ctFileName | path type -- same ruling |  |
| `MULT REPORT MINIMUM BANDS` | no | ctInteger |  |  |
| `MY CONTINENT` | no | ctOther |  |  |
| `PADDLE PORT` | no | ctPortLPT | port identity track |  |
| `POLL RADIO ONE` | no | ctBoolean | radio library -- a field of the radio record |  |
| `POLL RADIO TWO` | no | ctBoolean | radio library -- a field of the radio record |  |
| `POSSIBLE CALL MODE` | no | ctOther |  |  |
| `PREFIX MULTIPLIER` | no | ctMultiplier |  |  |
| `QSL MODE` | no | ctOther |  |  |
| `QSO POINT METHOD` | no | ctOther |  |  |
| `RADIO ONE BAND OUTPUT PORT` | no | ctPortLPT | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE BAUD RATE` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE CAT DTR` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE CAT RTS` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE CONTROL PORT` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE CW BY CAT` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE CW SPEED SYNC` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE FACTORY ID` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE FREQUENCY ADDER` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE FT1000MP CW REVERSE` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE HAMLIB ID` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE ICOM DATA MODE ID` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE ICOM FILTER BYTE` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE IP ADDRESS` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE KEYER DTR` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE KEYER RTS` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE KEYER STOP BITS` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE NAME` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE NETWORK PASSWORD` | no | ctPassword | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE NETWORK USERNAME` | no | ctCaseSensitive | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE RECEIVER ADDRESS` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE SERIAL FORMAT` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE STARTUP COMMAND` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE TCP PORT` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE TYPE` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE USE HAMLIB` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO ONE WIDE CW FILTER` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO BAND OUTPUT PORT` | no | ctPortLPT | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO BAUD RATE` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO CAT DTR` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO CAT RTS` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO CONTROL PORT` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO CW BY CAT` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO CW SPEED SYNC` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO FACTORY ID` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO FREQUENCY ADDER` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO FT1000MP CW REVERSE` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO HAMLIB ID` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO ICOM DATA MODE ID` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO ICOM FILTER BYTE` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO IP ADDRESS` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO KEYER DTR` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO KEYER RTS` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO KEYER STOP BITS` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO NAME` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO NETWORK PASSWORD` | no | ctPassword | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO NETWORK USERNAME` | no | ctCaseSensitive | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO RECEIVER ADDRESS` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO SERIAL FORMAT` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO STARTUP COMMAND` | no | ctString | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO TCP PORT` | no | ctInteger | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO TYPE` | no | ctOther | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO USE HAMLIB` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RADIO TWO WIDE CW FILTER` | no | ctBoolean | radio library -- CheckCommand is the transport for these, so they move with that track |  |
| `RATE DISPLAY` | no | ctOther |  |  |
| `RELAY CONTROL PORT` | no | ctPortLPT | port identity track |  |
| `REMAINING MULT DISPLAY MODE` | no | ctOther |  |  |
| `REMINDER` | no | ctOther |  |  |
| `ROTATOR PORT` | no | ctOther |  |  |
| `ROTATOR TYPE` | no | ctOther |  |  |
| `SCP COUNTRY STRING` | no | ctString | a field of the SCP database object, read by bare name |  |
| `SINGLE BAND SCORE` | yes | ctBand |  |  |
| `STEREO CONTROL PORT` | no | ctPortLPT | port identity track |  |
| `STEREO PIN HIGH` | no | ctBoolean | live session state -- a keystroke toggles it |  |
| `TEN MINUTE RULE` | yes | ctOther |  |  |
| `USER INFO SHOWN` | no | ctOther |  |  |
| `WEIGHT` | no | ctReal | live session state |  |
| `WK AUTOSPACE` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK CT SPACING` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK DIT DAH RATIO` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `WK ENABLE` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK FIRST EXTENSION` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `WK IGNORE SPEED POT` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK KEYER COMPENSATION` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `WK KEYER MODE` | no | ctOther | keyer library -- same shape as the radio rows |  |
| `WK LEADIN TIME` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `WK PADDLE ONLY SIDETONE` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK PADDLE SWAP` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK PADDLE SWITCHPOINT` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `WK PORT` | no | ctOther | keyer library -- same shape as the radio rows |  |
| `WK SIDETONE ENABLE` | no | ctBoolean | keyer library -- same shape as the radio rows |  |
| `WK SIDETONE FREQUENCY` | no | ctOther | keyer library -- same shape as the radio rows |  |
| `WK TAIL TIME` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `WK WEIGHT` | no | ctByte | keyer library -- same shape as the radio rows |  |
| `ZONE MULTIPLIER` | no | ctMultiplier |  |  |

## The credentials, which are a case of their own

`HAMSCORE USERNAME`, `HAMSCORE PASSWORD` and `SERVER PASSWORD` are held
back by one mechanical problem, not by a design question. The config loader
re-reads every password and case-sensitive value from the old `.ini` a
second time to put the operator's original capitalisation back, and it
finds them by walking the config array BY ADDRESS. A setting that has moved
is not in that walk, so its password would silently arrive upper-cased.

`uKeychain` is the answer and is already built: on Windows the value lives
in Credential Manager and the settings file holds only a reference. The
remaining work is to mark secrecy on the property type so the settings
model, the Preferences masking, the import and the multi-op sync all read it
from one place.

The radio network credentials are in the same position but belong to the
radio library track.

## Regenerating this

It is generated from `uSettingsModel.pas` and `uCFG.pas`, and validated
against the frozen command vocabulary in `uTestSettingsModel.pas` -- which
is read out of the live settings object, so if the generator and the program
ever disagree, the generator is wrong. At the time of writing they agree
exactly on all 233 command names.

**Keep the Notes column when regenerating.** The rest of the table is
reproducible; your notes are not.
