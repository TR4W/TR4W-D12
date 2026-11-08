# Commands E–L

Current setting metadata comes from the 5.0.22 inventory and source snapshot. Inherited help is explicitly labeled and may describe older behavior. [Read the reference conventions](index.md) before editing settings.

## ESCAPE EXITS SEARCH AND POUNCE {#escape-exits-search-and-pounce}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, pressing &lt;Esc&gt; when in S&amp;P Mode causes TR4W to revert to CQ Mode. When the parameter is FALSE, the only way to revert to CQ Mode is to press shift-Tab. However, the FALSE setting is ignored if you have a call ready for a QSO on the other rig. This allows you to abort a second-radio QSO with &lt;Esc&gt; even if this parameter is FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.EscapeExitsSearchAndPounce`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## EXCHANGE MEMORY ENABLE {#exchange-memory-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter allows you to control whether the TR4W exchange memory is used. The exchange memory is useful when working the same station on different bands or modes, and when the exchange contains either a class (e.g., ARRL Field Day), power (ARRL DX), age (All Asian), name, ITU Society name (IARU), zone, or Domestic QTH. If you have worked the station before in the contest, the constant information will appear without you having to re-enter it. Please note that this information is lost if you stop TR4W and the *.RST file is deleted.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.ExchangeMemoryEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## EXCHANGE RECEIVED {#exchange-received}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;UNKNOWN&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter tells TR4W what kind of exchange data to expect. It is normally controlled by the CONTEST statement in the.*.CFG file.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.ExchangeReceived`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: UNKNOWN. This is not a verified current default.

## EXTERNAL LOGGER {#external-logger}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

Select the destination logging application. The factory recognizes NONE, DXKEEPER, ACLOG, and HRD. DXKeeper has a QSO delivery implementation; the ACLog and HRD QSO-send methods are unimplemented in this snapshot, despite being selectable. This setting is separate from Hamlib radio-control bridges.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.LoggerType`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER ADDRESS {#external-logger-address}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;127.0.0.1&#x27; |
| Other accepted names | None listed |

Address of the receiving external logger's TCP service. Use the service's local address when both programs run on one computer. This is the logger service address, not the radio's address. Changes take effect on the next TR4W start.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.Address`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER ENABLED {#external-logger-enabled}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

Enable forwarding of newly logged contacts to the selected external logger. Select an implemented destination and configure its address and port first. The Preferences panel says these changes take effect on the next TR4W start. Confirm delivery in the receiving application.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.Enabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER PORT {#external-logger-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Integer |
| Initial value in constructor | 52001 |
| Other accepted names | None listed |

TCP listening port of the receiving external logger. Match the receiver's actual configuration and restart TR4W after applying the change. An open connection alone is not proof of a successful QSO transfer.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.Port`. Source type: `integer`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## FARNSWORTH ENABLE {#farnsworth-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When slowing down the CW speed, it is often desirable to increase the space between letters. Turning on FARNSWORTH ENABLE will increase the spaces between letters exponentially as your speed decreases below the value of FARNSWORTH SPEED (default is 25 WPM). You can control this parameter dynamically while sending a CW message.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.FarnsworthEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## FARNSWORTH SPEED {#farnsworth-speed}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–99 (numeric type bounds; see description for units) |
| Initial value in constructor | 25 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Integer (WPM). Controls the CW speed at which the Farnsworth effect starts. As you decrease the code speed below this value, there will be exponentially more space added between characters. For increased Farnsworth effect at very slow speeds, increase the value of FARNSWORTH SPEED. You can also control this parameter dynamically within CW messages.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.FarnsworthSpeed`. Source type: `TCwFarnsworthSpeed`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 25. This is not a verified current default.

## FONT SIZE {#font-size}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–2 (numeric type bounds; see description for units) |
| Initial value in constructor | 2 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Adjust some font sizes down to &#x27;0&#x27; and upto &#x27;2&#x27;. This may affect other windows, like bandmap (See Band Map Size setting)

??? info "Evidence and historical context"
    Model path: `Settings.Font.Size`. Source type: `TMainFontSize`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 2. This is not a verified current default.

## FREQUENCY MEMORY ENABLE {#frequency-memory-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When set to TRUE, this parameter will enable the frequency memory. This means that you will return to the frequency you were last using when returning to a band (even with the other radio).

??? info "Evidence and historical context"
    Model path: `Settings.Operating.FrequencyMemoryEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## FREQUENCY POLL RATE {#frequency-poll-rate}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 10–1000 (numeric type bounds; see description for units) |
| Initial value in constructor | 10 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Integer 10 to 1000 (msec). This command tells TR4W how frequently to poll the rig for a new frequency. The value is in milliseconds, and the allowed values are in the range 10 to 1000.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.FrequencyPollRate`. Source type: `TFreqPollRate`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 10. This is not a verified current default.

## GRID MAP CENTER {#grid-map-center}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Four- or six-character grid reference. This parameter will set the centre of a grid map that will show you at a glance the grids you have worked. The grid map will be displayed in VGA mode (if available). The ctrl-Left and ctrl-Right keys may be used to move the grid map sideways. (There is no way to move the grid map vertically.)

??? info "Evidence and historical context"
    Model path: `Settings.GridMap.Center`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## HAMSCORE ENABLE {#hamscore-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If true, then the real-time contest sacoring is sent to hamscore.net. Note this only applies to certain contests.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.HamscoreEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## HAMSCORE PASSWORD {#hamscore-password}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Credential; use the settings UI |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Password used for real-time contest uploads for RTC contests.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.Password`. Source type: `TSecretText`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: Blank. This is not a verified current default.

## HAMSCORE SEND CONTACT INFO {#hamscore-send-contact-info}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Some contests prefer that the real-time information not be sent (strategy reasons one presumes). If false, the contact daty will not be sent--just the scores.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.SendContactInfo`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## HAMSCORE URL {#hamscore-url}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;http://scoredistributor.net/&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This is the URL used to send real-time contest data, to post score info or both.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.Url`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: http://scoredistributor.net/. This is not a verified current default.

## HAMSCORE USERNAME {#hamscore-username}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type TCaseSensitiveText; allowed values need editorial review |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    User used for real-time contest uploads for RTC contests. Note this is typically your callsign but woudl be whatever your account with Hamscore indicates.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.Username`. Source type: `TCaseSensitiveText`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: Blank. This is not a verified current default.

## HAND LOG MODE {#hand-log-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.HandLogMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## HF BAND ENABLE {#hf-band-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter enables the HF bands below 30 MHz. It is automatically set to FALSE when you select a VHF contest.

??? info "Evidence and historical context"
    Model path: `Settings.Bands.HfEnabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## HOUR DISPLAY {#hour-display}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type HourDisplayType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: THIS HOUR, LAST SIXTY MINUTES or BAND CHANGES. This parameter determines how the hour rate display works. In the THIS HOUR mode, it shows the number of QSOs made during the current hour (starting at 15:00, for example). In the LAST SIXTY MINUTES, it shows the number of contacts made during the last 60 minutes. The BAND CHANGES mode will count how many band changes have been made since the current hour began.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.HourDisplay`. Source type: `HourDisplayType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: THIS HOUR. This is not a verified current default.

## IE SWITCH {#ie-switch}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE, only spots matched to active InitialExhange and TRMaster File will display to BandMap.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.IeSwitch`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## IN BAND LOCKOUT {#in-band-lockout}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    values:True/False. Default of TRUE prevents Band Map selection that would place both radios on a single band.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.InBandLockout`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## INCLUDE F-KEY NUMBER {#include-f-key-number}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.IncludeFKeyNumber`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## INCREMENT TIME ENABLE {#increment-time-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Determines whether the &quot;increment time function&quot; using Alt-1 to Alt-0 is enabled. If this flag is set to TRUE, the alt-1 to alt-0 keys will increment the time by 1 to 10 minutes respectively. This function can be useful when entering a log by hand after the contest.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.IncrementTimeEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## INITIAL EXCHANGE {#initial-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter controls the generation of an initial exchange based upon the callsign. All information except the zone must come from the TRMASTER.DTA database. The zone may come from the database, or if not found there, will be calculated based upon the callsign and the information found in the CTY.DAT country file. If this parameter is set to CUSTOM, your initial exchange will be built using the CUSTOM INITIAL EXCHANGE STRING parameter. This allows you to choose multiple data fields and place them in any order. You can program initial exchanges using the file specified by the INITIAL EXCHANGE FILENAME parameter. Initial exchanges can also come from the initial exchange memory if you have already worked the station once in the contest.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchange`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## INITIAL EXCHANGE CURSOR POS {#initial-exchange-cursor-pos}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;AT END&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: AT START or AT END. When an initial exchange is inserted into the Exchange Window, this command controls whether the cursor is placed at the start or at the end of the exchange.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchangeCursorPos`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: AT END. This is not a verified current default.

## INITIAL EXCHANGE FILENAME {#initial-exchange-filename}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;INITIAL.EX&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter allows you to specify the name of the initial exchange file. This file is used by TR4W to determine initial exchanges for the callsigns included in the file. The calls will also be used in the partial call list. The format for the file is: callsign, followed by a space, and then the initial exchange information as you want it to appear in the Exchange Window.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchangeFilename`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: INITIAL.EX. This is not a verified current default.

## INITIAL EXCHANGE OVERWRITE {#initial-exchange-overwrite}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If this parameter is TRUE, then pressing any key after an initial exchange has been entered into the Exchange Window by TR4W will cause the exchange to be erased, allowing you to insert a complete exchange manually.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchangeOverwrite`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## INSERT MODE {#insert-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command allows you to define the initial state of the insert mode, which controls whether characters are overwritten or inserted when editing a callsign or exchange. You can toggle the insert mode while TR4W is running with ctrl-V or the INSERT key.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.InsertMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## INTERCOM FILE ENABLE {#intercom-file-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, all messages sent between computers during the contest will be logged to the file INTERCOM.TXT.

??? info "Evidence and historical context"
    Model path: `Settings.Network.IntercomFileEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## KEYPAD CW MEMORIES {#keypad-cw-memories}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, the keys 0 to 9 on the keypad will send CQ MEMORIES ctrl-F1 to ctrl-F10 respectively.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.KeypadMemories`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LEADING ZERO CHARACTER {#leading-zero-character}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;0&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter allows you to customize the character used as a leading zero when generating serial numbers and LEADING ZEROS has a value greater than zero. Normally, the character is T. However, you might prefer the number 0 or the letter O. If you use the ctrl-J menu to access this parameter, it will let you cycle among those three characters.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.LeadingZeroCharacter`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: T. This is not a verified current default.

## LEADING ZEROS {#leading-zeros}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–3 (numeric type bounds; see description for units) |
| Initial value in constructor | 3 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If you want your serial number to be a certain length by adding leading zeros, you can specify the length with this command. A value of zero disables the addition of any leading zeros. You can set the character used for leading zeros with the LEADING ZERO CHARACTER command.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.LeadingZeros`. Source type: `TCwLeadingZeros`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 3. This is not a verified current default.

## LEAVE CURSOR IN CALL WINDOW {#leave-cursor-in-call-window}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, the cursor will remain in the Call Window instead of moving automatically to the Exchange Window during the QSO process. Some people prefer this mode in contests where a zone is displayed as the initial exchange and you rarely need to change it.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.LeaveCursor`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LITERAL DOMESTIC QTH {#literal-domestic-qth}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Normally, TR4W will filter the domestic QTH that you type, and log the QTH as shown in the domestic file. If you would rather log exactly what you type, set this parameter to TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.LiteralDomesticQth`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LOG FREQUENCY ENABLE {#log-frequency-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, the serial number will be replaced with the frequency of the QSO (without the leading Megahertz part of the value). The band and mode will still be written at the start of the log entry. This feature is only useful if you have an interfaced radio.

??? info "Evidence and historical context"
    Model path: `Settings.Log.FrequencyEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LOG RS SENT {#log-rs-sent}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 11–59 (numeric type bounds; see description for units) |
| Initial value in constructor | 59 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The outbound signal report that appears in your log can be changed from the default of 59 or 599. Note that the [ character in your CW exchange allows you to enter the strength of the RST transmitted, and this value will be placed in your log instead of the default.

??? info "Evidence and historical context"
    Model path: `Settings.Log.RsSent`. Source type: `TLogRsSent`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 59. This is not a verified current default.

## LOG RST SENT {#log-rst-sent}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 111–599 (numeric type bounds; see description for units) |
| Initial value in constructor | 599 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The outbound signal report that appears in your log can be changed from the default of 59 or 599. Note that the [ character in your CW exchange allows you to enter the strength of the RST transmitted, and this value will be placed in your log instead of the default.

??? info "Evidence and historical context"
    Model path: `Settings.Log.RstSent`. Source type: `TLogRstSent`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 599. This is not a verified current default.

## LOG SUB TITLE {#log-sub-title}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Use this command if you want a subtitle to appear at the top of each printed log page.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.LogSubTitle`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## LOG WITH SINGLE ENTER {#log-with-single-enter}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If this parameter is TRUE, the QSO will be logged as soon as you press the initial &lt;Enter&gt; (to send the exchange). In other words, it behaves as if you have pressed &lt;Enter&gt; followed by ctrl-Enter.

??? info "Evidence and historical context"
    Model path: `Settings.Log.WithSingleEnter`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LOOK FOR RST SENT {#look-for-rst-sent}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, a transmitted RST may be entered into the Exchange Window by preceding it with S. For example, typing S57 would place 57 into the log as the transmitted exchange for this QSO.

??? info "Evidence and historical context"
    Model path: `Settings.Log.LookForRstSent`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.
