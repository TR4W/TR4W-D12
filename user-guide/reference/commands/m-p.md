# Commands M–P

Setting metadata was extracted from TR4W 5.1.0. The English help accompanying each setting may still need operator review. [Read the reference conventions](index.md) before editing settings.

## MAIN CALLSIGN {#main-callsign}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Your station&#x27;s own callsign, remembered from contest to contest. The New Contest dialog fills its callsign box from it (or from MY CALL when this is empty), and the first callsign you enter there is saved here if it is empty. It is not the callsign you log with: that is MY CALL, which a contest may change (for example to a club call) without touching this one.

??? info "Evidence and historical context"
    Model path: `Settings.My.MainCallsign`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MAIN FONT {#main-font}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;Arial&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    The typeface of the main contest window (default Arial). In Preferences &gt; Appearance, Choose... opens the font dialog, where you pick the typeface and whether it is bold (BOLD FONT). The text size is not set in the dialog: it follows the width of the main window, plus FONT SIZE. Takes effect when TR4W next starts.

??? info "Evidence and historical context"
    Model path: `Settings.Font.Face`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: Arial. This is not a verified current default.

## MESSAGE ENABLE {#message-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    This command determines whether the various messages located in the alt-P menu are sent. If you disable them by setting this parameter to FALSE, messages such as the CQ EXCHANGE and QSL MESSAGE will not be sent. This command would be used if you want to send these messages manually.

??? info "Evidence and historical context"
    Model path: `Settings.Message.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## MINITOUR DURATION {#minitour-duration}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | 0–60 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "English settings help"
    Value: integer from 5 to 60. Specifies in minutes tour duration in multi-tours contests.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.MinitourDuration`. Source type: `TTourDuration`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## MISSINGCALLSIGNS FILE ENABLE {#missingcallsigns-file-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    Works with USE RECORDED SIGNS. When this parameter is TRUE and the voice keyer has no recording &lt;callsign&gt;.WAV in its FULLCALLSIGNS folder for a callsign it has to say, that callsign is added to the file MISSINGCALLSIGNS.TXT in the same folder, so you can record it later.

??? info "Evidence and historical context"
    Model path: `Settings.Dvk.MissingCallsignsFileEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## MMTTY ENGINE {#mmtty-engine}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    The path to the MMTTY program for working RTTY contests (experimental).

??? info "Evidence and historical context"
    Model path: `Settings.Mmtty.Engine`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MODE {#mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;CW&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    You can use this command to select the mode in which TR4W will start when no QSOs have been made. Normally, you would just use alt-M to select the desired mode.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.Mode`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: CW. This is not a verified current default.

## MULT BY BAND {#mult-by-band}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    These commands determine whether multipliers can be counted again on different bands or modes. These parameters are configured when the CONTEST statement is executed and normally do not require any changes.

??? info "Evidence and historical context"
    Model path: `Settings.Mult.ByBand`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## MULT BY MODE {#mult-by-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    These commands determine whether multipliers can be counted again on different bands or modes. These parameters are configured when the CONTEST statement is executed and normally do not require any changes.

??? info "Evidence and historical context"
    Model path: `Settings.Mult.ByMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## MULT REPORT MINIMUM BANDS {#mult-report-minimum-bands}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Integer |
| Initial value in constructor | 4 |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Integer in range 2 to 4. These commands are synonymous. When executing the ctrl-O command, you will be shown DX multipliers that you have worked on a certain number, but not all, bands. This parameter sets the minimum number of bands on which the country must have been worked in order to appear on this report.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.MultReportMinimumBands`. Source type: `integer`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 4. This is not a verified current default.

## MULT SHEET AUTO RESET {#mult-sheet-auto-reset}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    TO BE COMPLETED

??? info "Evidence and historical context"
    Model path: `Settings.Mult.SheetAutoReset`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## MULTI MULTS ONLY {#multi-mults-only}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    If you are using a computer network for a multi operation, this command will determine whether all QSOs are passed around the network, or only those that are new multipliers.

??? info "Evidence and historical context"
    Model path: `Settings.Network.MultiMultsOnly`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## MULTIPLE BANDS {#multiple-bands}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    These commands control the ability to change bands or modes while working the contest. If you are working a single mode or single band contest, it is recommended that the corresponding flag be set to FALSE. This will prevent you from changing band or mode accidentally during the contest. Before you make your first QSO, you will be able to set the band and mode regardless of the value of these parameters.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.MultipleBands`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## MULTIPLE MODES {#multiple-modes}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    These commands control the ability to change bands or modes while working the contest. If you are working a single mode or single band contest, it is recommended that the corresponding flag be set to FALSE. This will prevent you from changing band or mode accidentally during the contest. Before you make your first QSO, you will be able to set the band and mode regardless of the value of these parameters.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.MultipleModes`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## MY CALL {#my-call}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Your callsign. This must be the first statement of your *.CFG file. You should include any portable designation. The ctrl-J menu allows you to view the value of MY CALL, but not to edit it.

??? info "Evidence and historical context"
    Model path: `Settings.My.Call`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY CHECK {#my-check}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any string. This command is mandatory when operating the Sweepstakes contest. If CONTEST is set to SWEEPSTAKES, TR4W will prompt you for this value if it is not already set.

??? info "Evidence and historical context"
    Model path: `Settings.My.Check`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY CONTINENT {#my-continent}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: AF, AS, EU, NA, OC or SA. Normally, your continent is determined by your callsign. However, if you want the program to place you in a different continent, use this command. It is best to put this command before the CONTEST statement in your *.CFG file so that TR4W can configure the contest correctly. The ctrl-J menu allows you to view the value of MY CONTINENT, but not to dit it.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.MyContinent`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY COUNTRY {#my-country}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any valid country ID. Normally, your country is determined by your callsign. However, if you want the program to place you in a different country, use this command. It is best to put this command before the CONTEST statement in your *.CFG file so that TR4W can configure the contest correctly. The ctrl-J menu allows you to view the value of MY COUNTRY, but not to edit it.

??? info "Evidence and historical context"
    Model path: `Settings.My.Country`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY FD CLASS {#my-fd-class}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any valid ARRL Field Day class. This is used to set your station class for ARRL Field Day (e.g., 1A). If you are operating the Field Day, TR4W will prompt you for this value if it is not already set

??? info "Evidence and historical context"
    Model path: `Settings.My.FdClass`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY FOC NUMBER {#my-foc-number}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Enter your FOC number.

??? info "Evidence and historical context"
    Model path: `Settings.My.FocNumber`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## MY GRID {#my-grid}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Four- or six-character grid identifier. This parameter identifies the grid from which you are operating. This is used to generate beam heading from your location. It is also used to determine QSO points when using a QSO point method that computes points based upon distance. Use GRID MAP CENTER to set separately the center of the grid map.

??? info "Evidence and historical context"
    Model path: `Settings.My.Grid`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY IOTA {#my-iota}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    PENDING RE-IMPLEMENTATION. Values: IOTA designator. Sets the IOTA identifier of the island from which you are operating (e.g., EU-006).

??? info "Evidence and historical context"
    Model path: `Settings.My.Iota`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY ITU ZONE {#my-itu-zone}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–90 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "English settings help"
    Enter your ITU Zone.

??? info "Evidence and historical context"
    Model path: `Settings.My.ItuZone`. Source type: `TMyItuZone`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 0. This is not a verified current default.

## MY LICENSE YEAR {#my-license-year}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Enter the year you were first licensed, for the contests that exchange it (the European HF Championship, KVP). Four digits (1985) or the last two (85) are both accepted; the contest decides what is sent -- two digits, four digits or the number of years licensed. A contest may state its own value; this is the default. It is read when the contest is set up, so a change takes effect for the next contest or when TR4W next starts.

??? info "Evidence and historical context"
    Model path: `Settings.My.LicenseYear`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## MY NAME {#my-name}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any string. Use this command before the CONTEST statement if you are operating a contest that uses your name as part of the exchange. In contests where the exchange includes the name received in the prior QSO (using the special CW character (), TR4W will use this value as the name that is sent in the first QSO.

??? info "Evidence and historical context"
    Model path: `Settings.My.Name`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY PARK {#my-park}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

Your activating park reference, for example US-0663. It supplies the country prefix for digits-only worked-park entries. ADIF uses the park recorded with each QSO when available, with the current station value as a fallback for older rows.

[Step-by-step guide](../../operating/pota.md)

??? info "Evidence and historical context"
    Model path: `Settings.My.Park`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## MY POSTAL CODE {#my-postal-code}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any string. Used in the RSGB ROPOCO (Rotating Post Code) contest as the postcode sent in the first QSO.

??? info "Evidence and historical context"
    Model path: `Settings.My.PostalCode`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY PREC {#my-prec}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: A, B, M, Q, S or U. This command is mandatory when operating Sweepstakes. If you are operating Sweepstakes, TR4W will prompt you for this value if it is not already set.

??? info "Evidence and historical context"
    Model path: `Settings.My.Prec`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY SECTION {#my-section}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any string. This is mandatory when operating Sweepstakes or ARRL Field Day. If your chosen contest requires this information, TR4W will prompt you for this value if it is not already set.

??? info "Evidence and historical context"
    Model path: `Settings.My.Section`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY STATE {#my-state}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | MY QTH |

!!! quote "English settings help"
    Values: Any string. In some of the contests where a state or province is part of the exchange, TR4W will automatically configure the CW messages to include your location. This command allows you to tell the program what state (or province) to use in these messages. This command is also used to determine your state for various state QSO parties. Use the ordinary United States Postal Service two-letter state abbreviation to set your state. It is best to put this command before the CONTEST statement in your *.CFG file so that the information is processed correctly.

??? info "Evidence and historical context"
    Model path: `Settings.My.State`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## MY ZONE {#my-zone}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Integer Normally, your zone is determined by your callsign. However, if you want TR4W to place you in a different zone, use this command. It is best to put this command before the CONTEST statement in your *.CFG file, so that TR4W will configure the contest properly. However, the relationship between what happens when the contest executes the MY ZONE command and when it executes the CONTEST command is complex, and under some circumstances (for example, the IARU contest) the MY ZONE command should appear after the CONTEST command. The most common symptom of having these commands in the incorrect order is that TR4W will score the contest as if you were in a different zone from the one in which you are actually located. If you see that TR4W does not seem to be scoring the contest properly, you should try switching

??? info "Evidence and historical context"
    Model path: `Settings.My.Zone`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## N1MM LISTEN ADDRESS {#n1mm-listen-address}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;127.0.0.1&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    The address the N1MM log listener binds to. 127.0.0.1 accepts only the same computer; use this computer&#x27;s LAN address to accept QSOs from another computer. Blank means 127.0.0.1.

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.N1mmListenAddress`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## NAME FLAG ENABLE {#name-flag-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, an asterisk is shown in the log when you make a QSO with a station whose name is known.

??? info "Evidence and historical context"
    Model path: `Settings.Scp.NameFlagEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## NET STATUS UPDATE INTERVAL {#net-status-update-interval}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 1000–10000 (numeric type bounds; see description for units) |
| Initial value in constructor | 5000 |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: 1000 to 10000 milliseconds. While you want to be connected to the multi-op network and the link is down, TR4W tries to connect again at this interval. A change takes effect the next time you connect.

??? info "Evidence and historical context"
    Model path: `Settings.Network.StatusUpdateInterval`. Source type: `TNetStatusInterval`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 5000. This is not a verified current default.

## NETWORK AUTO CONNECT {#network-auto-connect}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When TRUE, TR4W connects to the multi-op server when it starts, provided COMPUTER ID is set to a letter A to Z. When FALSE, connect with Connect on the Net menu. Leave it FALSE on a single-operator station.

??? info "Evidence and historical context"
    Model path: `Settings.Network.AutoConnect`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## NETWORK HTTP TRANSPORT {#network-http-transport}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;generic&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Chooses what carries TR4W&#x27;s internet requests: the downloads (country file, TRMASTER, call history, POTA parks, version check) and the uploads (the external logging services, HamScore, contest scores, SuperCheckPartial). generic is TR4W&#x27;s own connection code, which checks server certificates against the cacert.pem shipped with the program. auto and platform use the operating system&#x27;s own connection code where this platform has one (Windows only, today: WinHTTP). It trusts the Windows certificate store, follows the system proxy settings and needs no cacert.pem. Where there is none, both use generic, and platform says so in the log. A change applies from the next request, with no restart. A request that fails is never repeated on the other transport. The Windows transport is new: leave this on generic unless you were asked to try it.

??? info "Evidence and historical context"
    Model path: `Settings.Network.HttpTransport`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## NETWORK SHARE SPOTS {#network-share-spots}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    When TRUE, this station sends the DX spots its own cluster connection receives to the other stations on the multi-op network, and accepts the spots they send. When FALSE it does neither. Each station has its own setting, and a change takes effect at once.

??? info "Evidence and historical context"
    Model path: `Settings.Network.ShareSpots`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## NO BORDER {#no-border}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, the panels of the main window and the call and exchange entry fields are drawn flat, without their sunken edge. It takes effect the next time TR4W starts.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.NoBorder`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## NO CAPTION {#no-caption}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    If the value is TRUE after startup all windows except the main will not have a title. Hold Alt and drag anywhere in a window to move it.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.NoCaption`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## NO COLUMN HEADER {#no-column-header}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    If the value is TRUE, the log windows show no row of column headings: the log on the main window (and the B4 list that takes its place), View/Edit Log, Log Search and the downloaded server log, and also the Network and Stations windows. The QSOs themselves are unchanged. The change takes effect at once in every open window; a column&#x27;s width cannot be dragged while its heading is hidden.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.NoColumnHeader`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## NO LOG {#no-log}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    If you want to disable a computer on the network from logging any QSOs, set this parameter to TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Log.Disabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## NO POLL DURING PTT {#no-poll-during-ptt}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, TR4W will not poll the radio for frequency information during the time the PTT signal is active.

??? info "Evidence and historical context"
    Model path: `Settings.Ptt.NoPollDuring`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## OPERATING STANDARD EDIT KEYS {#operating-standard-edit-keys}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When TRUE, Ctrl+C, Ctrl+V, Ctrl+X and Ctrl+A copy, paste, cut and select all in a text box or drop-down list of any window other than the main window, instead of running the TR4W command assigned to that key. The main window always keeps TR4W&#x27;s commands.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.StandardEditKeys`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## PADDLE MONITOR TONE {#paddle-monitor-tone}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 700 |
| Other accepted names | None listed |

!!! quote "English settings help"
    The computer speaker monitor is normally used when you send with a paddle connected to the parallel port. This command controls the frequency of the generated sidetone. A value of zero disables the tone.

??? info "Evidence and historical context"
    Model path: `Settings.Paddle.MonitorTone`. Source type: `TPaddleMonitorTone`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 700. This is not a verified current default.

## PADDLE PTT HOLD COUNT {#paddle-ptt-hold-count}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 13 |
| Other accepted names | None listed |

!!! quote "English settings help"
    This command controls the delay between when you stop sending CW with the paddle and when the PTT is released. The delay is measured in dit counts.

??? info "Evidence and historical context"
    Model path: `Settings.Paddle.PttHoldCount`. Source type: `TPaddlePttHoldCount`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 13. This is not a verified current default.

## PADDLE SPEED {#paddle-speed}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–99 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "English settings help"
    This command Controls the speed of CW sent with the paddle. A value of zero causes the paddle to send at the same speed as TR4W.

??? info "Evidence and historical context"
    Model path: `Settings.Paddle.Speed`. Source type: `TPaddleSpeed`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## PARTIAL CALL ENABLE {#partial-call-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    This command allows you to control the partial call function. This is a separate feature from the super check partial (which uses the TRMASTER.DTA database). The callsigns used by the partial call function come from the dupesheet and initial exchange file. When this function is enabled, partial calls will be shown on the bottom of the screen after the second character of a call has been typed into the Call Window. A partial call is defined to be any call that starts with the same letters as those in the Call Window. The WILDCARD PARTIALS parameter determines whether the partial call must appear at the start of

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.PartialCallEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## POSSIBLE CALL ACCEPT KEY {#possible-call-accept-key}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any character.

??? info "Evidence and historical context"
    Model path: `Settings.PossibleCall.AcceptKey`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: ;. This is not a verified current default.

## POSSIBLE CALL LEFT KEY {#possible-call-left-key}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;,&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any character.

??? info "Evidence and historical context"
    Model path: `Settings.PossibleCall.LeftKey`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: ,. This is not a verified current default.

## POSSIBLE CALL MODE {#possible-call-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type PossibleCallActionType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: NAMES or ALL. The possible calls that come from the TRMASTER.DTA file can either come from all of the calls or only those with names associated with them. When set to NAMES, the operation is identical to older versions of TR4W which used the name database for possible calls.

??? info "Evidence and historical context"
    Model path: `Settings.Scp.PossibleCallMode`. Source type: `PossibleCallActionType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NAMES. This is not a verified current default.

## POSSIBLE CALL RIGHT KEY {#possible-call-right-key}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;.&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Any character. When you are using the PARTIAL CALL ENABLE or the POSSIBLE CALLS feature, you are shown a list of calls in the bottom of the operating screen. The first call shown will have a cursor around it (like this: &lt;G4AMJ&gt;). You can transfer the callsign with the cursor around it to the Call Window with the POSSIBLE CALL ACCEPT KEY. You can move the cursor to the left and the right with the POSSIBLE CALL LEFT KEY and the POSSIBLE CALL RIGHT KEY.

??? info "Evidence and historical context"
    Model path: `Settings.PossibleCall.RightKey`. Source type: `Char`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: .. This is not a verified current default.

## POSSIBLE CALLS {#possible-calls}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, the possible call feature is enabled. This causes TR4W to display similar calls from the TRMASTER.DTA database and from your dupesheet when you are working a new station.

??? info "Evidence and historical context"
    Model path: `Settings.PossibleCall.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## PSTROTATOR IP ADDRESS {#pstrotator-ip-address}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;127.0.0.1&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    If using PSTRotator, the IP address of the computer where it is running. Note to use this, you still have to enable PSTROTATOR as the ROTOR Type below.

??? info "Evidence and historical context"
    Model path: `Settings.Rotator.IpAddress`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 127.0.0.1. This is not a verified current default.

## PSTROTATOR UDP PORT {#pstrotator-udp-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 1–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 12000 |
| Other accepted names | None listed |

!!! quote "English settings help"
    If using PSTRotator, the UDP port upon which it listens. This is not the same as the N1MM-style UDP broadcast. This is the port that corresponds to the PSTRotator setting in its Comm menu under UDP Control Setup. You still have to enable PSTROTATOR as the ROTOR Type below. Enable DEBUG TRACE to see the messages sent.

??? info "Evidence and historical context"
    Model path: `Settings.Rotator.UdpPort`. Source type: `TRotatorUdpPort`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 12000. This is not a verified current default.

## PTT ENABLE {#ptt-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    This command controls whether the PTT signal is active. The PTT signal is intended to be used to turn on your transmitter just before a CW message starts and to turn it off as soon as the message being sent has concluded. If you are using break-in (QSK), you should disable this signal.

??? info "Evidence and historical context"
    Model path: `Settings.Ptt.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## PTT LOCKOUT {#ptt-lockout}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    Ñommand determines whether or not to use the PTT lockout in networked mode.

??? info "Evidence and historical context"
    Model path: `Settings.Ptt.Lockout`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## PTT TURN ON DELAY {#ptt-turn-on-delay}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 15 |
| Other accepted names | None listed |

!!! quote "English settings help"
    This parameter controls the amount of time that elapses between the assertion of the PTT signal and the start of the first transmitted CW character. The value is multiplied by 1.7 milliseconds. A value of zero disables the feature.

??? info "Evidence and historical context"
    Model path: `Settings.Ptt.TurnOnDelay`. Source type: `TPttTurnOnDelay`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 15. This is not a verified current default.

## PTT TX INHIBIT BEEP {#ptt-tx-inhibit-beep}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When TRUE, TR4W beeps once when you key up a radio that reports it will not transmit (for example a K4 in TX test mode). The PTT indicator and the status line show this whatever the setting. BEEP ENABLE must also be TRUE for the beep to sound.

??? info "Evidence and historical context"
    Model path: `Settings.Ptt.TxInhibitBeep`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## PTT VIA COMMANDS {#ptt-via-commands}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    Send PTT command to rig via CAT interface.

??? info "Evidence and historical context"
    Model path: `Settings.Ptt.ViaCommands`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.
