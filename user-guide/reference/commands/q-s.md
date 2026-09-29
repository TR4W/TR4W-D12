# Commands Q–S

Current setting metadata comes from the 5.0.22 inventory and source snapshot. Inherited help is explicitly labeled and may describe older behavior. [Read the reference conventions](index.md) before editing settings.

## QSL CW MESSAGE {#qsl-cw-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;TU \ TEST&#x27; |
| Other accepted names | QSL MESSAGE |

!!! quote "Inherited English help — behavior needs review"
    The CW message sent to confirm (QSL) a completed QSO when logging in CQ Mode. Programmed via Alt+P. Typically includes your callsign and a TU or similar.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QslCw`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## QSL MODE {#qsl-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: STANDARD, QSL AND LOG, or QSL BUT NO LOG. This command can be used to change the criteria used to QSL an exchange and to log it when you are in CQ Mode. Normally, TR4W requires the complete exchange to be entered before you can QSL and log the contact. However, if you select QSL BUT NO LOG, the QSL message will be sent even if the exchange information is not completed, but you need to finish entering the exchange and hit &lt;Enter&gt; again before it will be logged. QSL AND LOG will totally eliminate any syntax checking on the exchange and log whatever you have entered. This mode is NOT recommended in normal operations.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.QslMode`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: STANDARD. This is not a verified current default.

## QSL SSB MESSAGE {#qsl-ssb-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;QSL.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The SSB voice message sent to confirm a completed QSO. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QslSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## QSO BEFORE CW MESSAGE {#qso-before-cw-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27; SRI QSO B4 TU \ TEST&#x27; |
| Other accepted names | QSO BEFORE MESSAGE |

!!! quote "Inherited English help — behavior needs review"
    CW message sent before the QSO exchange in CQ Mode - typically not used in standard operation. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QsoBeforeCw`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## QSO BEFORE SSB MESSAGE {#qso-before-ssb-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;QSOB4.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    SSB voice message sent before the QSO exchange. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QsoBeforeSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## QSO BY BAND {#qso-by-band}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    These parameters determine whether QSOs can be counted again if they occur on different bands or modes. The parameters are set up automatically when the CONTEST statement in your *.CFG file is executed, and normally do not require any changes.

??? info "Evidence and historical context"
    Model path: `Settings.Qso.ByBand`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## QSO BY MODE {#qso-by-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    These parameters determine whether QSOs can be counted again if they occur on different bands or modes. The parameters are set up automatically when the CONTEST statement in your *.CFG file is executed, and normally do not require any changes.

??? info "Evidence and historical context"
    Model path: `Settings.Qso.ByMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## QSO NUMBER BY BAND {#qso-number-by-band}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When set to TRUE, the QSO numbers that are displayed on the screen, those that are sent in a CW message with the # character, and those shown in the log will be calculated from the total number of contacts on the active band. This is useful in a multi-transmitter situation where QSO numbers are being sent (e.g., the CQ WPX contest).

??? info "Evidence and historical context"
    Model path: `Settings.Contest.QsoNumberByBand`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## QSO POINT METHOD {#qso-point-method}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.QsoPointMethod`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## QSO POINTS DOMESTIC CW {#qso-points-domestic-cw}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | -1–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | -1 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    These parameters allow you to control the QSO point values for the class of QSOs indicated. These will over-ride any existing QSO point method for the contacts in the category indicated.

??? info "Evidence and historical context"
    Model path: `Settings.Qso.PointsDomesticCw`. Source type: `TQsoPoints`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: -1. This is not a verified current default.

## QSO POINTS DOMESTIC PHONE {#qso-points-domestic-phone}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | -1–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | -1 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    These parameters allow you to control the QSO point values for the class of QSOs indicated. These will over-ride any existing QSO point method for the contacts in the category indicated.

??? info "Evidence and historical context"
    Model path: `Settings.Qso.PointsDomesticPhone`. Source type: `TQsoPoints`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: -1. This is not a verified current default.

## QSO POINTS DX CW {#qso-points-dx-cw}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | -1–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | -1 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    These parameters allow you to control the QSO point values for the class of QSOs indicated. These will over-ride any existing QSO point method for the contacts in the category indicated.

??? info "Evidence and historical context"
    Model path: `Settings.Qso.PointsDxCw`. Source type: `TQsoPoints`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: -1. This is not a verified current default.

## QSO POINTS DX PHONE {#qso-points-dx-phone}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | -1–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | -1 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    These parameters allow you to control the QSO point values for the class of QSOs indicated. These will over-ride any existing QSO point method for the contacts in the category indicated.

??? info "Evidence and historical context"
    Model path: `Settings.Qso.PointsDxPhone`. Source type: `TQsoPoints`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: -1. This is not a verified current default.

## QSX ENABLE {#qsx-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter determines whether QSX information is decoded from packet spots. You might want to disable this feature if you are a DX station and are not interested in split spots.

??? info "Evidence and historical context"
    Model path: `Settings.Qsx.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## QSY INACTIVE RADIO {#qsy-inactive-radio}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE, when you click on BANDMAP entry, it will QSY on the inactive radio. Note that TwoRadioMode must also be enabled for this to work.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.QsyInactiveRadio`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## QTC ENABLE {#qtc-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This is normally turned on automatically when a WAE is being configured. When you have enabled QTCs, you will need to remember that ctrl-Q is the magic key to send (if you are not in EU) or receive (if you are in EU) QTCs. TR4W will automatically ensure that you do not send a QTC containing the call of the station to whom you are sending the QTC. On CW, both the ctrl-Enter and alt-K keys work as usual even when QTCs are being sent.

??? info "Evidence and historical context"
    Model path: `Settings.Qtc.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## QTC EXTRA SPACE {#qtc-extra-space}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, extra spaces are inserted between the elements of a QTC.

??? info "Evidence and historical context"
    Model path: `Settings.Qtc.ExtraSpace`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## QTC MINUTES {#qtc-minutes}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, the QTC function will send only the minutes of QTC times that are in the same hour as the time previously sent.

??? info "Evidence and historical context"
    Model path: `Settings.Qtc.Minutes`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## QTC QRS {#qtc-qrs}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, TR4W will send QTCs with the CW. speed approximately 6% slower than the normal sending speed.

??? info "Evidence and historical context"
    Model path: `Settings.Qtc.Qrs`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## QUESTION MARK CHAR {#question-mark-char}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;?&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any key. Some keyboards require the use of a shift key to type the question mark. This command can be used to assign the ? key to another key2. This allows 2The author finds it useful to assign the = character with this command. operation without pressing the shift key, which may be inconvenient, or may change the rig frequency if your rig is interfaced to the computer.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.QuestionMarkChar`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: ?. This is not a verified current default.

## QUICK QSL CW MESSAGE {#quick-qsl-cw-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;TU&#x27; |
| Other accepted names | QUICK QSL CW MESSAGE1, QUICK QSL MESSAGE 1 |

!!! quote "Inherited English help — behavior needs review"
    Short CW acknowledgement message used instead of the full QSL MESSAGE when the AUTO QSL INTERVAL is active or when the QUICK QSL KEY is pressed. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QuickQslCw1`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## QUICK QSL KEY 1 {#quick-qsl-key-1}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;\&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any key. When you finish a contact while running on CW, normally you press &lt;Enter&gt; to log the contact and send the QSL MESSAGE. If you want to send the QUICK QSL MESSAGE 1 instead, you press the QUICK QSL KEY1 instead of &lt;Enter&gt;.

??? info "Evidence and historical context"
    Model path: `Settings.Message.QuickQslKey1`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## QUICK QSL KEY 2 {#quick-qsl-key-2}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;=&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any key. When you finish a contact while running on CW, normally you press &lt;Enter&gt; to log the contact and send the QSL MESSAGE. If you want to send the QUICK QSL MESSAGE 2 instead, you press the QUICK QSL KEY2 instead of &lt;Enter&gt;.

??? info "Evidence and historical context"
    Model path: `Settings.Message.QuickQslKey2`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: =. This is not a verified current default.

## QUICK QSL MESSAGE 2 {#quick-qsl-message-2}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;TU&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Short CW acknowledgement message 2, sent when QUICK QSL KEY 2 is pressed. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QuickQslCw2`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: Blank. This is not a verified current default.

## QUICK QSL SSB MESSAGE {#quick-qsl-ssb-message}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;QUICKQSL.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Short SSB voice acknowledgement message. Programmed via Alt+P. ### R

??? info "Evidence and historical context"
    Model path: `Settings.Messages.QuickQslSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: Blank. This is not a verified current default.

## QZB RANDOM OFFSET ENABLE {#qzb-random-offset-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Qzb.RandomOffsetEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## R150S MODE {#r150s-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE calculation of contriyes-multipliers will be based on R-150-S list.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.R150SMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## RADIO TCP SERVER PORT {#radio-tcp-server-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Integer |
| Initial value in constructor | 52002 |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Radio.TcpServerPort`. Source type: `integer`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## RADIUS OF EARTH {#radius-of-earth}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Number |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any number. This parameter can be used to override the internal value of the Earths radius that is used for distance calculations. Enter the new radius in kilometers. A value of 0 causes TR4W to use the default internal value (which is 6378.1370 km3).

??? info "Evidence and historical context"
    Model path: `Settings.GridMap.RadiusOfEarth`. Source type: `double`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0.00. This is not a verified current default.

## RANDOM CQ MODE {#random-cq-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, the Auto-CQ function will behave differently when selecting CQ MEMORY F1. Instead of always playing the message recorded in F1, the Auto-CQ procedure will randomly pick CQs from memories F1 through F4. This allows you to sound like you are awake. Blank messages in F1 through F4 are ignored.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.RandomMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## RATE DISPLAY {#rate-display}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type RateDisplayType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: QSOS or QSO POINTS. The rate display can show either the rate at which you are making QSOs, or the rate at which your QSO points are increasing.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.RateDisplay`. Source type: `RateDisplayType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: QSOS. This is not a verified current default.

## REMAINING MULT DISPLAY MODE {#remaining-mult-display-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type RemainingMultDisplayModeType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: NONE, ERASE, HILIGHT. This command allows you to control how the remaining multiplier display function will work. If it is set to NONE, there will not be any display of remaining multipliers. If set to ERASE, the multipliers will be removed from the list as they are worked. If set to HILIGHT, multipliers that you have not worked yet will be highlighted.

??? info "Evidence and historical context"
    Model path: `Settings.RemainingMults.DisplayMode`. Source type: `RemainingMultDisplayModeType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: HILIGHT. This is not a verified current default.

## REPEAT S&P CW EXCHANGE {#repeat-s-p-cw-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | REPEAT S&amp;P EXCHANGE |

!!! quote "Inherited English help — behavior needs review"
    CW Exchange sent ween repeating the exchange in S&amp;P mode.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.RepeatSpExchangeCw`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: Blank. This is not a verified current default.

## REPEAT S&P SSB EXCHANGE {#repeat-s-p-ssb-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;RPTSPEX.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    SSB exchange message sent when repeating your exchange in S&amp;P mode. Programmed via Alt+P. ### S

??? info "Evidence and historical context"
    Model path: `Settings.Messages.RepeatSpExchangeSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## REVERSE INITIAL EX {#reverse-initial-ex}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Turning REVERSE INITIAL EX on to TRUE will reverse the search order so that TRMASTER is searched before Initial.Ex

??? info "Evidence and historical context"
    Model path: `Settings.InitialExchange.Reverse`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## RFOBL MODE {#rfobl-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TO BE COMPLETED

??? info "Evidence and historical context"
    Model path: `Settings.Contest.RfoblMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TO BE COMPLETED. This is not a verified current default.

## ROTATOR PORT {#rotator-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: SERIAL 1 to SERIAL 6. This command is used to choose a serial port over which commands will be sent to the rotator control (which may be set with the ROTATOR TYPE command). To send the rotator to the direction for the country of a callsign in the Call Window, use the ctrl-P command.

??? info "Evidence and historical context"
    Model path: `Settings.Rotator.Port`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## ROTATOR TYPE {#rotator-type}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: DCU1, ORION, YAESU, ALFA SPID or PSTROTATOR. Sets the type of the rotator control.

??? info "Evidence and historical context"
    Model path: `Settings.Rotator.RotatorType`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## ROW COUNT {#row-count}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 5–15 (numeric type bounds; see description for units) |
| Initial value in constructor | 5 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Number of log lines displayed in the main window.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.RowCount`. Source type: `TLogRowCount`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 5. This is not a verified current default.

## S&P CW EXCHANGE {#s-p-cw-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | S&amp;P EXCHANGE |

!!! quote "Inherited English help — behavior needs review"
    The CW exchange message sent in Search and Pounce mode. This is separate from the CQ exchange to allow different content when calling a station. Programmed via Alt+P.

??? info "Evidence and historical context"
    Model path: `Settings.Messages.SpExchangeCw`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## S&P SSB EXCHANGE {#s-p-ssb-exchange}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;SAPEXCHG.WAV&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The SSB voice exchange message sent in S&amp;P mode. Programmed via Alt+P. ### T

??? info "Evidence and historical context"
    Model path: `Settings.Messages.SpExchangeSsb`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## SAY HI ENABLE {#say-hi-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If you have programmed CW messages that include names from the TRMASTER database, SAY HI ENABLE will determine whether the names are actually used. This allows you to program the messages with the names included, but to disable them all without having to edit each message.

??? info "Evidence and historical context"
    Model path: `Settings.SayHi.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SAY HI RATE CUTOFF {#say-hi-rate-cutoff}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 200 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If SAY HI ENABLE is TRUE, TR4W will cease to greet the other station when your rate exceeds the value of SAY HI RATE CUTOFF.

??? info "Evidence and historical context"
    Model path: `Settings.SayHi.RateCutoff`. Source type: `TSayHiRateCutoff`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 200. This is not a verified current default.

## SCORE POSTING URL {#score-posting-url}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;https://post.contestonlinescore.com/post/&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Post to Online Scoreboard

??? info "Evidence and historical context"
    Model path: `Settings.Score.PostingUrl`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: http://post.contestonlinescore.com/. This is not a verified current default.

## SCORE READING URL {#score-reading-url}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;https://contestonlinescore.com/scoreboard/&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Read Online Scoreboard

??? info "Evidence and historical context"
    Model path: `Settings.Score.ReadingUrl`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: https://contestonlinescore.com/scoreboard/. This is not a verified current default.

## SCP COUNTRY STRING {#scp-country-string}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Comma-separated list of country prefixes. This command allows you to limit the stations that are displayed by the Super Check Partial function. Entering a comma-separated list of country prefixes (e.g., K, VE, KL7, KH6, KP2, KP4) causes only stations from those countries to be displayed when performing the Super Check Partial function. The default is to list stations from all countries. If you place a ! or - in front of the list of countries, then only stations in countries not in the list will be displayed by Super Check Partial.

??? info "Evidence and historical context"
    Model path: `Settings.Scp.CountryString`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## SCP MINIMUM LETTERS {#scp-minimum-letters}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Integer |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: 0, 3, 4, or 5. When this parameter is non-zero, it enables the automatic Super Check Partial function. When you enter the number of characters specified, partial calls will be automatically displayed. You must have a TRMASTER.DTA file available for the program for this feature to work.

??? info "Evidence and historical context"
    Model path: `Settings.Scp.MinimumLetters`. Source type: `integer`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## SEND COMPLETE FOUR LETTER CALL {#send-complete-four-letter-call}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The } character in a CW message will send the prefix or suffix of a corrected callsign. If you set this parameter to TRUE, it will send the complete callsign if it is only four characters in length.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.SendCompleteFourLetterCall`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SERVER ADDRESS {#server-address}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;LOCALHOST&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The name or IP address of the computer that is running TR4WSERVER.

??? info "Evidence and historical context"
    Model path: `Settings.Server.Address`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: LOCALHOST. This is not a verified current default.

## SERVER AUTO SYNCHRONIZE LOG ON CONNECT {#server-auto-synchronize-log-on-connect}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When running in network mode, rather than asking th euser if they want to sync the logs, the program does so automatically. It reports any errors it finds.

??? info "Evidence and historical context"
    Model path: `Settings.Server.AutoSynchronizeLogOnConnect`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## SERVER PASSWORD {#server-password}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Credential; use the settings UI |
| Initial value in constructor | &#x27;TR4WSERVER&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Value: 10 chars length string. Password for connection to TR4WSERVER.

??? info "Evidence and historical context"
    Model path: `Settings.Server.Password`. Source type: `TSecretText`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TR4WSERVER. This is not a verified current default.

## SERVER PORT {#server-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 1061 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Ethernet port number, which will used connection with TR4WSERVER.

??? info "Evidence and historical context"
    Model path: `Settings.Server.Port`. Source type: `TServerPort`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 1061. This is not a verified current default.

## SHIFT KEY ENABLE {#shift-key-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The shift keys can be used to adjust the frequency of Kenwood, Flex, Icom and some Yaesu rigs. To disable this feature, set this parameter to FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.ShiftKeyEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## SHORT 0 {#short-0}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;0&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any character. Defines the character to be sent instead of a 0 in a QSO number if SHORT INTEGERS is TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Short0`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: T. This is not a verified current default.

## SHORT 1 {#short-1}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;1&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any character. Defines the character to be sent instead of a 1 in a QSO number if SHORT INTEGERS is TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Short1`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: A. This is not a verified current default.

## SHORT 2 {#short-2}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;2&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any character. Defines the character to be sent instead of a 2 in a QSO number if SHORT INTEGERS is TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Short2`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 2. This is not a verified current default.

## SHORT 9 {#short-9}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;9&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any character. Defines the character to be sent instead of a 9 in a QSO number if SHORT INTEGERS is TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Short9`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: N. This is not a verified current default.

## SHORT INTEGERS {#short-integers}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, TR4W will allow short abbreviations for some integers when they are sent as part of a QSO number. The actual abbreviations that are used can be programmed using the Alt-P command or the SHORT 0, SHORT 1, SHORT 2, and SHORT 9 commands.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.ShortIntegers`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SHOW ALL SERIAL PORTS {#show-all-serial-ports}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.SerialPorts.ShowAll`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## SHOW DOMESTIC MULTIPLIER NAME {#show-domestic-multiplier-name}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.RemainingMults.ShowDomesticName`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SHOW FREQUENCY IN LOG {#show-frequency-in-log}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If the value is TRUE in Cabrillo log will substitute the actual frequency of QSO.

??? info "Evidence and historical context"
    Model path: `Settings.Log.ShowFrequency`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## SHOW GRIDLINES {#show-gridlines}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.ShowGridlines`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SHOW TYPED CALLSIGN {#show-typed-callsign}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE typed callsign in callsign window will displayed in &quot;Network&quot; window.

??? info "Evidence and historical context"
    Model path: `Settings.Network.ShowTypedCallsign`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## SINGLE BAND SCORE {#single-band-score}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;160&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command can be used to force the score calculator to use the QSOs for only a single band. If you change the value of the SINGLE BAND SCORE parameter during a contest, you will need to delete your *.RST file before restarting TR4W.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.SingleBandScore`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: All. This is not a verified current default.

## SKIP ACTIVE BAND {#skip-active-band}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If you are using two rigs and SKIP ACTIVE BAND is TRUE, TR4W will skip over the band to which the other rig is tuned when switching bands using the alt-B or alt-V commands.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.SkipActiveBand`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SLASH MARK CHAR {#slash-mark-char}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;/&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any character. If you wish to use a different keyboard character to make the / mark, use this command to specify it. This is handy for some European keyboards.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.SlashMarkChar`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: /. This is not a verified current default.

## SPACE BAR DUPE CHECK ENABLE {#space-bar-dupe-check-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Normally when you press &lt;Space&gt; when a callsign is present in the Call Window, TR4W will perform a dupe check on the displayed callsign. If you press &lt;Space&gt; without a callsign in the window, you will be put into S&amp;P Mode and your callsign will be sent. If you set SPACE BAR DUPE CHECK ENABLE to FALSE, you will always go into S&amp;P Mode and send your call, even if a call is present in the Call Window.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.SpaceBarDupeCheck`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## SPOT COLLECTOR ENABLED {#spot-collector-enabled}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When using the DXLab Suite of programs, this will allow SpotCollector to populate the TR4W callsign window when clicking on a spot.

??? info "Evidence and historical context"
    Model path: `Settings.SpotCollector.Enabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## SPRINT QSY RULE {#sprint-qsy-rule}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If this parameter is TRUE, TR4W will automatically enter CQ Mode after completing a QSO in S&amp;P Mode. This parameter is automatically set to TRUE when the Sprint contest is selected. See subsection 6.18.1 for more information on operating the Sprint. You should not set this variable to TRUE unless you are operating the Sprint. For similar (but not quite identical) behaviour in other contests, see the AUTO S&amp;P ENABLE command.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.SprintQsyRule`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## START SENDING NOW KEY {#start-sending-now-key}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;&#x27;&#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any key. If you are running stations on CW and a station that has answered you has already finished sending his call, but you have not yet finished typing his call, you can press the START SENDING NOW KEY. This will send the characters you have already typed, and also the ones that you type after hitting the key, until you press &lt;Enter&gt;. After pressing &lt;Enter&gt;, the normal exchange will be sent. You may set the START SENDING NOW KEY to the &lt;Space&gt; key with the command: START SENDING NOW KEY = SPACE If the cursor is in the Call Window, then the space bar only causes sending to begin if there is at least one character in the window.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.StartSendingNowKey`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: «&#x27;» (the open-single-quote key, not the apostrophe). This is not a verified current default.

## STATIONS CALLSIGNS MASK {#stations-callsigns-mask}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Stations.CallsignsMask`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## STEREO PIN HIGH {#stereo-pin-high}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command sets the state of the STEREO CONTROL PIN on the STEREO CONTROL PORT. The value may be toggled with the function key command TOGGLESTEREOPIN.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.StereoPinHigh`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SWAP PACKET SPOT RADIOS {#swap-packet-spot-radios}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, TR4W reverses which rig receives a packet spot when ctrl-U and the left/right cursor keys are used. This is useful if your station is configured such that your rig number 2 is physically on the left.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.SwapPacketSpotRadios`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SWAP PADDLES {#swap-paddles}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter swaps the dit and dah inputs on the paddle port. This is handy if your paddle is wired backwards.

??? info "Evidence and historical context"
    Model path: `Settings.Paddle.Swap`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## SWAP RADIO RELAY SENSE {#swap-radio-relay-sense}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When this parameter is TRUE, TR4W reverses the polarity of the relay for controlling the radio.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.SwapRelaySense`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.
