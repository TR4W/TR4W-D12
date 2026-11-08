# Commands A–D

Current setting metadata comes from the 5.0.22 inventory and source snapshot. Inherited help is explicitly labeled and may describe older behavior. [Read the reference conventions](index.md) before editing settings.

## ALERT COLOR {#alert-color}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;ALERT&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.AlertColor`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## ALL CW MESSAGES CHAINABLE {#all-cw-messages-chainable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Normally, when you press a function key memory when a CW message is already playing, the previous message will be aborted and the new message started. However, if you set this flag to TRUE, the new message will not start until the old one is complete. You can also do this for selected CW messages by placing a ctrl-D at the start of the message.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.AllMessagesChainable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## ALLOW AUTO UPDATE {#allow-auto-update}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Allow auto rescore of the log in networked mode after QSO edit.

??? info "Evidence and historical context"
    Model path: `Settings.Network.AllowAutoUpdate`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## ALT-D BUFFER ENABLE {#alt-d-buffer-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command controls whether the alt-D buffer is enabled. When this flag is enabled, TR4W obtains calls and frequencies from the bandmap when performing a dupecheck on the second radio.

??? info "Evidence and historical context"
    Model path: `Settings.AltD.BufferEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## ALT-D CQ ENABLE {#alt-d-cq-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    (SO2R) Setting this to true will enable a CQ to be automatically sent on the run rig upon completion of exchange on S&amp;P rig.

??? info "Evidence and historical context"
    Model path: `Settings.AltD.CqEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## ALWAYS CALL BLIND CQ {#always-call-blind-cq}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This function is principally designed to be useful in contests like the Sprint when you are using TR4W with two rigs. In such a situation, you often want to send a CQ on the other rig while you are receiving the exchange from the station to whom you are about to cede the frequency. Normally you do this by pressing F7 or F8, which by default sends CQ on the inactive rig. Setting the ALWAYS CALL BLIND CQ function to TRUE causes that CQ to occur automatically as soon as the CQ EXCHANGE has been sent. (It sends whatever message is stored in Exchange memory F7.). Note that this does force you to be ready for that CQ by finding a clear frequency in time for it to be sent.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.AlwaysCallBlind`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## ASK FOR FREQUENCIES {#ask-for-frequencies}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When using the bandmap or submitting packet spots in an environment in which you do not have a radio that communicates with TR4W, the program will normally ask you for the frequency of stations as you perform dupe checks. Setting this parameter to FALSE will stop TR4W from asking you for these frequencies.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.AskForFrequencies`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## AUTO CALL TERMINATE {#auto-call-terminate}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When you are on CW and this parameter is TRUE, TR4W can automatically terminate callsigns that you enter in response to a CQ. When coupled with the START SENDING NOW KEY or the AUTO SEND CHARACTER COUNT commands, TR-LOG will assume that a call is complete when all the characters entered in the Call Window have been transmitted. For example, assume that 4U1ITU has answered your CQ. If you press the key identified by the START SENDING NOW KEY command after entering 4U1I, the program will start to send 4U1I. If you enter one or more additional characters before it completes sending, TR-LOG will send those characters as well. If there are no new characters to send, it will automatically send the CQ EXCHANGE. TR4W works the same way if the AUTO SEND CHARACTER COUNT function causes the program to start sending the callsign. In this case, it is possible to respond to a station by using the same number of keystrokes that are in its callsign.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.AutoCallTerminate`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## AUTO DISPLAY DUPE QSO {#auto-display-dupe-qso}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When you are working a duplicate QSO in CQ Mode and this parameter is TRUE, TR4W will automatically show you the log entries for the previous QSO(s) with that station. This command is nonfunctional if you set AUTO DUPE ENABLE CQ to FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.DupeSheet.AutoDisplayQso`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## AUTO DUPE ENABLE CQ {#auto-dupe-enable-cq}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter is now ignored. It did produce a &#x27;QSO B4&#x27; message. Reference GitHub issue 556 for more information. &#x27;QSO B4&#x27; message may be added to any F key if desired.

??? info "Evidence and historical context"
    Model path: `Settings.AutoDupe.EnableCq`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## AUTO DUPE ENABLE S AND P {#auto-dupe-enable-s-and-p}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If this parameter is TRUE, when you try to call a dupe with the &lt;Enter&gt; key in S&amp;P Mode, TR4W will refuse to call the station. You might want to set this parameter to FALSE in contests like the Internet Sprint, in which you often call the same station on the same band and mode several times during the contest.

??? info "Evidence and historical context"
    Model path: `Settings.AutoDupe.EnableSAndP`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## AUTO QSL INTERVAL {#auto-qsl-interval}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–6 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Normally when you press &lt;Enter&gt; to log a QSO, the QSL MESSAGE is transmitted. The AUTO QSL INTERVAL command can be used to send the QUICK QSL MESSAGE instead, except that once every AUTO QSL INTERVAL QSOs, the QSL MESSAGE is transmitted instead. This is typically used when dealing with a large pileup. If you set AUTO QSL INTERVAL to 3, then the QUICK QSL MESSAGE would be sent, except for every third QSO. A value of zero disables this feature, in which case the QSL MESSAGE is sent at the end of every QSO.

??? info "Evidence and historical context"
    Model path: `Settings.Message.AutoQslInterval`. Source type: `TAutoQslInterval`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## AUTO QSO NUMBER DECREMENT {#auto-qso-number-decrement}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If you have programmed an S&amp;P exchange that includes a QSO number, you might find yourself in the situation in which you have just logged a station who is now asking for a repeat of the exchange you sent him. If you press F2, you will send the next QSO number, which will be one more than the one you sent the first time. To fix this problem, you can set AUTO QSO NUMBER DECREMENT to TRUE; this causes TR4W to decrement the QSO number when you press F2 when both the Call Window and the Exchange Window are empty.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.AutoQsoNumberDecrement`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## AUTO RETURN TO CQ MODE {#auto-return-to-cq-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If this parameter is TRUE, then pressing &lt;Enter&gt; in S&amp;P Mode when there is no information in either the Call Window or the Exchange Window will cause TR4W to return to CQ Mode.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.AutoReturnToMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## AUTO S&P ENABLE {#auto-s-p-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, TR4W will automatically jump into S&amp;P Mode if it detects you have moved the VFO quickly. See also AUTO S&amp;P See also AUTO S&amp;P ENABLE SENSITIVITY.

??? info "Evidence and historical context"
    Model path: `Settings.AutoSap.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## AUTO S&P ENABLE SENSITIVITY {#auto-s-p-enable-sensitivity}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 10–10000 (numeric type bounds; see description for units) |
| Initial value in constructor | 500 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Controls how quickly you must move the VFO (in Hz/sec) in order for the program to jump automatically into S&amp;P Mode if AUTO S&amp;P ENABLE is TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.AutoSap.Sensitivity`. Source type: `TAutoSapSensitivity`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 500. This is not a verified current default.

## AUTO SEND CHARACTER COUNT {#auto-send-character-count}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–6 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TR4W can start to send the callsign of a station responding to your CQ after you have typed a certain number of characters in the callsign of the calling station. This number of characters is controlled with the AUTO SEND CHARACTER COUNT command. For example, if you set AUTO SEND CHARACTER COUNT to 3 and 4U1ITU calls you, the program will start sending the call after you have typed 4U1. If you enable the AUTO CALL TERMINATE feature, the program will transmit the CQ EXCHANGE message when it has sent all the characters you have typed. When the AUTO SEND CHARACTER COUNT is non-zero, an arrow will appear above the Call Window to indicate the point at which TR4W will begin to transmit the callsign. You can disable this function with the Alt-- command. The arrow will then disappear. To re-enable it, press Alt-- again and the arrow will reappear. You can delete any unsent characters with the backspace key.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.AutoSendCharacterCount`. Source type: `TAutoSendCharacterCount`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## AUTO TIME INCREMENT {#auto-time-increment}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If you are entering a log by hand, the AUTO TIME INCREMENT feature can be very useful. Setting the value to a non-zero value n will cause the clock to increment by one after every n QSOs. A value of zero disables the feature.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.AutoTimeIncrement`. Source type: `TAutoTimeIncrement`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## AUTO-CQ DELAY TIME {#auto-cq-delay-time}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 500–10000 (numeric type bounds; see description for units) |
| Initial value in constructor | 3000 |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.AutoDelay`. Source type: `TAutoCqDelay`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 3000. This is not a verified current default.

## BACKUP LOG FILE NAME {#backup-log-file-name}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;logback.db&#x27; |
| Other accepted names | None listed |

Destination filename for a verified snapshot of the open contest database. Set it before invoking Backup Log; an empty destination causes the manual handler to return without creating a copy. Use a distinct destination for each contest. The implementation stages and verifies the new snapshot before publishing it, retaining the preceding destination as .bak.

[Step-by-step guide](../../log/backup.md)

??? info "Evidence and historical context"
    Model path: `Settings.Log.BackupFileName`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## BACKUP LOG FREQUENCY {#backup-log-frequency}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

Number of QSOs between automatic backups. Zero disables the automatic schedule. Set a backup destination as well. The logging path tests the total QSO count against this interval; this value is not a time interval.

[Step-by-step guide](../../log/backup.md)

??? info "Evidence and historical context"
    Model path: `Settings.Log.BackupFrequency`. Source type: `TBackupLogFrequency`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 0. This is not a verified current default.

## BAND {#band}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;160&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    You can select the band on which TR4W will start if no contacts have yet been made. After the program is running, use alt-B or alt-V to change band. Some contests are single-band contests and may not let you change bands after a QSO has been made.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.Band`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 160. This is not a verified current default.

## BAND MAP ALL BANDS {#band-map-all-bands}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE, the bandmap displays entries from all bands. If FALSE, the bandmap displays entries on the current band only. When the cursor is in the bandmap, the value of this flag may be toggled with the B key.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.AllBands`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## BAND MAP ALL MODES {#band-map-all-modes}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE, the bandmap displays entries from all modes. If FALSE, the bandmap displays those entries associated with the current mode only. When the cursor is in the bandmap, the value of this flag may be toggled with the M key.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.AllModes`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## BAND MAP CALL WINDOW ENABLE {#band-map-call-window-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this is TRUE, and you tune to a frequency that has a station in the bandmap, the callsign and exchange information of the station will be displayed in the Call Window. This allows you to renew the entry by simply pressing the space bar1. The exchange information is shown to help you to identify the station quickly. If you start entering a new callsign, the entry in the Call Window will first be erased.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.CallWindowEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## BAND MAP DECAY TIME {#band-map-decay-time}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 60 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This controls the number of minutes for which a new entry will remain visible on the bandmap. The value can be any positive integer less than 32,768. 1Renewing a station with QSX information in this manner will remove the QSX information.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.DecayTime`. Source type: `TBandMapDecayTime`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 60. This is not a verified current default.

## BAND MAP DISPLAY CQ {#band-map-display-cq}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When FALSE, CQ entries will not appear in the band map.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.DisplayCQ`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## BAND MAP DISPLAY GHZ {#band-map-display-ghz}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    For VHF contests, displays GHz frequencies in the bandmap

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.DisplayGhz`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## BAND MAP DISPLAY LIMIT {#band-map-display-limit}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 30–1000 (numeric type bounds; see description for units) |
| Initial value in constructor | 164 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter allows you to limit the number of spots the bandmap will display. Above the limit the displayed spots will be centred on the operating frequency. The value must be an even number between 30 and 1000.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.DisplayLimit`. Source type: `TBandMapDisplayLimit`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 164. This is not a verified current default.

## BAND MAP DUPE DISPLAY {#band-map-dupe-display}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Controls whether the bandmap will dispay [D]upes.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.DupeDisplay`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## BAND MAP GUARD BAND {#band-map-guard-band}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Integer (Hz). The bandmap will indicate if a displayed entry is near the frequency of your interfaced radio by causing the appropriate entry to highlight.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.GuardBand`. Source type: `TBandMapGuardBand`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 200. This is not a verified current default.

## BAND MAP ITEM HEIGHT {#band-map-item-height}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 12–50 (numeric type bounds; see description for units) |
| Initial value in constructor | 14 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Height of band map items. Range of 100-200.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.ItemHeight`. Source type: `TBandMapItemHeight`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 14. This is not a verified current default.

## BAND MAP ITEM WIDTH {#band-map-item-width}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 100–200 (numeric type bounds; see description for units) |
| Initial value in constructor | 135 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Band Map item width. Change this in accordance with BAND MAP SIZE. Range = 100-200.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.ItemWidth`. Source type: `TBandMapItemWidth`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 135. This is not a verified current default.

## BAND MAP MULTS ONLY {#band-map-mults-only}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Only display multipliers.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.MultsOnly`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## BAND MAP SIZE {#band-map-size}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–8 (numeric type bounds; see description for units) |
| Initial value in constructor | 3 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values range between smallest (0) and largest (8). You need to adjust BAND MAP ITEM HEIGHT accordingly.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.Size`. Source type: `TBandMapSize`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 2. This is not a verified current default.

## BAND MAP SO2R DISPLAY {#band-map-so2r-display}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TO BE COMPLETED

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.So2rDisplay`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## BAND MAP SPLIT MODE {#band-map-split-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type BandMapSplitModeType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter allows you to handle properly the mode of stations that are on the bandmap and are operating split. The default value allows you to tailor the CW and PHONE ranges with the BAND MAP CUTOFF FREQUENCY command.

??? info "Evidence and historical context"
    Model path: `Settings.BandMap.SplitMode`. Source type: `BandMapSplitModeType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: BY CUTOFF FREQ. This is not a verified current default.

## BEEP ENABLE {#beep-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When set to FALSE, all beeps generated on the PC speaker by TR4W are disabled.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.BeepEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## BEEP EVERY 10 QSOS {#beep-every-10-qsos}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When set to TRUE, a short beep will be generated every tenth QSO. This is useful when entering a log by hand after the contest to make sure that you havent skipped any contacts.

??? info "Evidence and historical context"
    Model path: `Settings.Log.BeepEvery10Qsos`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## BOLD FONT {#bold-font}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Set bold font in program windows.

??? info "Evidence and historical context"
    Model path: `Settings.Font.Bold`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## BROADCAST ALL PACKET DATA {#broadcast-all-packet-data}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is set to TRUE and you are using a multi network, all data coming from the TNC are sent to all the computers in the network, where the packet information is viewable with the ctrl-B command. Commands may also be sent from any computer on the network to the TNC. Beware that data are not sent to the TNC until &lt;Enter&gt; is pressed.

??? info "Evidence and historical context"
    Model path: `Settings.Cluster.BroadcastAllPacketData`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## CALL OK NOW CW MESSAGE {#call-ok-now-cw-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;} OK %&#x27; |
| Other accepted names | CALL OK NOW MESSAGE |

!!! quote "Inherited English help — behavior needs review"
    CW message sent when the operator confirms the callsign of a station calling during a CQ QSO by pressing the call-ok-now key. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.CallOkNowCw`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CALL OK NOW SSB MESSAGE {#call-ok-now-ssb-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;CORCALL.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    SSB message sent when the operator confirms the callsign of a station calling during a CQ QSO. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.CallOkNowSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CALL WINDOW SHOW ALL SPOTS {#call-window-show-all-spots}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.ShowAllSpots`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CALLSIGN UPDATE ENABLE {#callsign-update-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is set to TRUE, TR4W will parse the Exchange Window looking for callsigns; if it finds one, the program will act exactly as if the call had been changed in the Call Window. You must type in the complete call, and spaces must both precede and follow it. If this parameter is TRUE, ctrl-U will send the call in the Exchange Window (otherwise it sends the call in the Call Window).

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.CallsignUpdateEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## CATEGORY-ASSISTED {#category-assisted}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | See type tCategoryAssisted; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Used to generate Cabrillo file and for posting score to on-line score systems.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryAssisted`. Source type: `tCategoryAssisted`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NON-ASSISTED. This is not a verified current default.

## CATEGORY-BAND {#category-band}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | See type tCategoryBand; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Used to generate Cabrillo file and for posting score to on-line score systems.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryBand`. Source type: `tCategoryBand`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: ALL. This is not a verified current default.

## CATEGORY-MODE {#category-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | See type tCategoryMode; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Used to generate Cabrillo file and for posting score to on-line score systems.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryMode`. Source type: `tCategoryMode`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: CW. This is not a verified current default.

## CATEGORY-OPERATOR {#category-operator}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | See type tCategoryOperator; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Used to generate Cabrillo file and for posting score to on-line score systems.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryOperator`. Source type: `tCategoryOperator`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: SINGLE-OP. This is not a verified current default.

## CATEGORY-OVERLAY {#category-overlay}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TO BE COMPLETED

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryOverlay`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TO BE COMPLETED. This is not a verified current default.

## CATEGORY-POWER {#category-power}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | See type tCategoryPower; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Used to generate Cabrillo file and for posting score to on-line score systems.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryPower`. Source type: `tCategoryPower`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: HIGH. This is not a verified current default.

## CATEGORY-TRANSMITTER {#category-transmitter}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | See type tCategoryTransmitter; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Used to generate Cabrillo file and for posting score to on-line score systems.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CategoryTransmitter`. Source type: `tCategoryTransmitter`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: ONE. This is not a verified current default.

## CHECK LOG FILE SIZE {#check-log-file-size}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When TRUE, TR4W will check the size of the log *.trw file to ensure it is the proper size for the number of contacts. This feature can alert you to a disk failure and prevent you from losing too much data. If this error occurs, you should stop the program, back up the files you have to a floppy, run a disk utility to see if you can recover any lost data, and then reboot your computer.

??? info "Evidence and historical context"
    Model path: `Settings.Log.CheckFileSize`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## CODE SPEED {#code-speed}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–99 (numeric type bounds; see description for units) |
| Initial value in constructor | 35 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Use this command to set the CW speed at which TR4W will start. While the program is running, you can use the alt-S command to set a new speed or use the Page-Up/Page-Down keys to change the code speed in increments of CW SPEED INCREMENT, which is 3 WPM by default. The changes instantly affect any CW being sent.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.CodeSpeed`. Source type: `TCwCodeSpeed`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 35. This is not a verified current default.

## COLUMN AUTOSIZE {#column-autosize}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TO BE COMPLETED

??? info "Evidence and historical context"
    Model path: `Settings.Log.ColumnAutoSize`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## COMPLETE CALLSIGN MASK {#complete-callsign-mask}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    A string defines a mask call, which will be inserted into the input box when you hit function key programmed with the command &lt;03&gt;COMPLETECALL&lt;04&gt;.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.CompleteCallsignMask`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## COMPUTER ID {#computer-id}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: A to Z, or none. When the COMPUTER ID is set to a letter, that letter will be printed just after the QSO number in the log sheet. There is a command in POST that can be used to separate the logs by COMPUTER ID, which can be useful in multi-multi environments.

??? info "Evidence and historical context"
    Model path: `Settings.Computer.Id`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## COMPUTER NAME {#computer-name}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;New&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The name of the computer in the TR4W network. The name will be displayed in the window &quot;Network&quot;.

??? info "Evidence and historical context"
    Model path: `Settings.Computer.Name`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: New. This is not a verified current default.

## CONFIRM EDIT CHANGES {#confirm-edit-changes}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter determines whether you are asked if you want to save the changes made after editing one of your five most recent QSOs (i.e., the QSOs in the editable log) using the alt-E command. Normally, TR4W will ask you whether you want to save changes before updating the LOG.TMP file. To stop TR4W from asking this question, set this parameter to FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.Log.ConfirmEditChanges`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## CONNECTION AT STARTUP {#connection-at-startup}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If the value is TRUE and if &quot;DX-Cluster&quot; window is opened the program will try to connect to telnet cluster at startup.

??? info "Evidence and historical context"
    Model path: `Settings.Cluster.ConnectionAtStartup`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## CONTACTS PER PAGE {#contacts-per-page}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | 10–100 (numeric type bounds; see description for units) |
| Initial value in constructor | 50 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This controls the number of contacts printed on each page of the log.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.ContactsPerPage`. Source type: `TContactsPerPage`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 50. This is not a verified current default.

## CONTEST {#contest}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;DUMMY CONTEST&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The CONTEST statement tells TR4W which contest you are going to operate.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.ContestToken`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: DUMMY CONTEST. This is not a verified current default.

## CONTEST NAME {#contest-name}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter specifies the name of the contest. TR4W adds your call and the year to generate the CONTEST TITLE.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.Name`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## CONTEST TITLE {#contest-title}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The CONTEST TITLE is displayed at the top of the screen and in the header of the log pages.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.Title`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## COUNT DOMESTIC COUNTRIES {#count-domestic-countries}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Setting this parameter to TRUE causes TR4W to include domestic QSOs in the count of DX countries. (This is in addition to any domestic multiplier that the QSO might accrue.)

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CountDomesticCountries`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## COUNTRY INFORMATION FILE {#country-information-file}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Country.InformationFile`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CQ CW EXCHANGE {#cq-cw-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | CQ EXCHANGE |

!!! quote "Inherited English help — behavior needs review"
    The CW message sent as your CQ exchange when operating in CQ Mode. This is typically set to your standard contest exchange, and is programmed via Alt+P or as a function key. The # character inserts the QSO number; the @ character inserts your callsign.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.CqExchangeCw`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CQ CW EXCHANGE NAME KNOWN {#cq-cw-exchange-name-known}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | CQ EXCHANGE NAME KNOWN |

!!! quote "Inherited English help — behavior needs review"
    Alternate CQ CW exchange message sent when the name of the calling station is known from the TRMASTER database. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.CqExchangeCwNameKnown`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CQ SSB EXCHANGE {#cq-ssb-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;CQEXCHNG.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The SSB voice message sent as your CQ exchange. Programmed via Alt+P. For DVK/SSB operation, this specifies the audio file to play. ### D

??? info "Evidence and historical context"
    Model path: `Settings.Messages.CqExchangeSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CQ SSB EXCHANGE NAME KNOWN {#cq-ssb-exchange-name-known}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;CQEXNAME.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Alternate CQ SSB exchange message sent when the name of the calling station is known. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.CqExchangeSsbNameKnown`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## CTY UPDATE CHECK ON STARTUP {#cty-update-check-on-startup}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When TRUE, caused TR4W to check the version of the CTY.DAT file to see if a more recent one is available. If so, it offers to download the latest file via ALT-O.

??? info "Evidence and historical context"
    Model path: `Settings.Country.UpdateCheckOnStartup`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## CUSTOM INITIAL EXCHANGE STRING {#custom-initial-exchange-string}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This string defines how your initial exchange will be constructed if you set INITIAL EXCHANGE to the value CUSTOM. You may select any number of the following fields, and put them in any order: CHECK, CQZONE, FOC, GRID, ITUZONE, NAME, OLDCALL, QTH, SECTION, TENTEN, USER1, USER2, USER3, USER4 and USER5.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.CustomInitialExchangeString`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## CUSTOM USER STRING {#custom-user-string}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This string defines how your user info will be shown if you set USER INFO SHOWN to the value CUSTOM. You may select any number of the following fields, and put them in any order: CHECK, CQZONE, FOC, GRID, ITUZONE, NAME, OLDCALL, QTH, SECTION, TENTEN, USER1, USER2, USER3, USER4 and USER5.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.CustomUserString`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## CW ENABLE {#cw-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is FALSE, the computer is prevented from sending any CW, except CW sent from the paddle.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## CW SPEED FROM DATABASE {#cw-speed-from-database}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is true, TR4W will look in the TRMASTER database for a CW Speed entry for the callsign you are working. If it finds one, it will send the CQ EXCHANGE at that speed. The CW speed will return to the previous value when sending the QSL MESSAGE or a new CQ (if the QSO is aborted).

??? info "Evidence and historical context"
    Model path: `Settings.Cw.SpeedFromDatabase`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## CW SPEED INCREMENT {#cw-speed-increment}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 1–10 (numeric type bounds; see description for units) |
| Initial value in constructor | 3 |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.SpeedIncrement`. Source type: `TCwSpeedIncrement`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 3. This is not a verified current default.

## CW TONE {#cw-tone}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 700 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The computer can send the CW over its speaker for the purpose of monitoring the transmission. This command allows you to select the pitch of that CW. Setting the value to zero disables sending the CW to the speaker (but the rig will still be keyed). The PADDLE MONITOR TONE command separately controls the tone frequency of CW sent with the paddle.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Tone`. Source type: `TCwTone`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 700. This is not a verified current default.

## DE ENABLE {#de-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This determines whether DE is sent before your callsign when using the F1 key in S&amp;P Mode. If you dont want the program to put DE in front of your call (which is the case for most operators), set this flag to FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.Message.DeEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## DEBUG LOG LEVEL {#debug-log-level}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type tLogLevels; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Normally set to NONE. Support may request the following options: NONE, FATAL, ERROR, WARN, INFO, DEBUG, and TRACE. Check TR4W directory for file named tr4w.log

??? info "Evidence and historical context"
    Model path: `Settings.Log.DebugLevel`. Source type: `tLogLevels`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: NONE. This is not a verified current default.

## DIGITAL MODE ENABLE {#digital-mode-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, you can select DIG as a mode when using the alt-M command. DIG is treated as a distinct mode, separate from CW and SSB. This feature is intended to allow you to log digital QSOs made during the ARRL Field Day.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.DigitalModeEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## DISPLAY LANGUAGE {#display-language}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Display.Language`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## DISTANCE MODE {#distance-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type DistanceDisplayType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter controls the display of the distance to the station you are working. The distance is shown along with the beam headings. The value of the distance depends on the value of RADIUS OF EARTH.

??? info "Evidence and historical context"
    Model path: `Settings.Log.DistanceMode`. Source type: `DistanceDisplayType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: KM. This is not a verified current default.

## DIT DAH RATIO {#dit-dah-ratio}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 3–6 (numeric type bounds; see description for units) |
| Initial value in constructor | 3 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Ratio dit/dah in CW.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.DitDahRatio`. Source type: `TCwDitDahRatio`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 3. This is not a verified current default.

## DOMESTIC FILENAME {#domestic-filename}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command allows you to specify the name of the domestic multiplier file that will be used by the program. This is normally determined by TR4W automatically when you specify a certain contest with the CONTEST parameter. However, if you are creating your own domestic multiplier file and want the program to use yours instead, you can use this command. Make sure you also set the DOMESTIC MULTIPLIER parameter to the value DOMESTIC FILE, so that TR4W will know to look for a file.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.DomesticFilename`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## DOMESTIC MULTIPLIER {#domestic-multiplier}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter defines which type of domestic multiplier the program will use.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.DomesticMultiplier`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## DUPE CHECK SOUND {#dupe-check-sound}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type DupeCheckSoundType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When performing a dupe check with the space bar, TR4W will normally generate a beep if the station is a dupe. However, you can change the program to be silent, or to use the fanfare sound instead.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.DupeCheckSound`. Source type: `DupeCheckSoundType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: DUPE BEEP. This is not a verified current default.

## DUPE SHEET AUTO RESET {#dupe-sheet-auto-reset}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When TRUE the program will automatically reset dupe sheet after each tour in multi-tours contests.

??? info "Evidence and historical context"
    Model path: `Settings.DupeSheet.AutoReset`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## DVK ENABLE {#dvk-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command determines whether the DVK is enabled.

??? info "Evidence and historical context"
    Model path: `Settings.Dvk.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## DVK LOCALIZED MESSAGES ENABLE {#dvk-localized-messages-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TO BE COMPLETED

??? info "Evidence and historical context"
    Model path: `Settings.Dvk.LocalizedMessagesEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## DVK PATH {#dvk-path}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;DVK&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Dvk.Path`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: DVK. This is not a verified current default.

## DVK RECORDER {#dvk-recorder}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Dvk.Recorder`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: NONE. This is not a verified current default.

## DX MULTIPLIER {#dx-multiplier}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command determines which type of DX multiplier the program will use.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.DxMultiplier`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.
