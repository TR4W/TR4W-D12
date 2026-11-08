# Commands T–Z

Current setting metadata comes from the 5.0.22 inventory and source snapshot. Inherited help is explicitly labeled and may describe older behavior. [Read the reference conventions](index.md) before editing settings.

## TELNET CONSOLE LINES {#telnet-console-lines}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 1000–100000 (numeric type bounds; see description for units) |
| Initial value in constructor | 10000 |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Telnet.ConsoleLines`. Source type: `TTelnetConsoleLines`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## TELNET SERVER {#telnet-server}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Address of default telnet cluster.

??? info "Evidence and historical context"
    Model path: `Settings.Telnet.Server`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: sk3w.se:8000. This is not a verified current default.

## TEN MINUTE RULE {#ten-minute-rule}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type TenMinuteRuleType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: NONE or TIME OF FIRST QSO. This parameter selects the mode for the ten minute rule. The TIME OF FIRST QSO mode will cause the elapsed time since your first QSO on the active band to be displayed.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.TenMinuteRule`. Source type: `TenMinuteRuleType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## TUNE ALT-D ENABLE {#tune-alt-d-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If this parameter is TRUE, then the following behaviour occurs: if you are in CQ Mode on the active radio, then as you tune the inactive radio, calls from the bandmap (if not dupes) are automatically entered so that they can be worked with the alt-D command. This saves you from having to enter the calls manually.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.TuneAltDEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## TUNE WITH DITS {#tune-with-dits}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.TuneWithDits`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

## TWO RADIO MODE {#two-radio-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: TRUE or FALSE. When this parameter is TRUE, TR4W is in two radio mode.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.TwoRadioMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## UNKNOWN COUNTRY FILE ENABLE {#unknown-country-file-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter controls the generation of the unknown country file. This file will list all the QSOs with callsigns for which TR4W cannot determine the country. This is a good way to find calls that might be new multipliers for you. By default, the file is named UNKNOWN.CTY, but you can change the name of the file with the UNKNOWN COUNTRY FILE NAME command. You can also find unknown countries after the contest using the Multiplier Check procedure in POST.

??? info "Evidence and historical context"
    Model path: `Settings.UnknownCountryFile.Enable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## UNKNOWN COUNTRY FILE NAME {#unknown-country-file-name}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;UNKNOWN.CTY&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: Any valid filename. TR4W will save log entries for QSOs with unknown countries to the named file if UNKNOWN COUNTRY FILE ENABLE is TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.UnknownCountryFile.Name`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: UNKNOWN.CTY. This is not a verified current default.

## UPDATE RESTART FILE ENABLE {#update-restart-file-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    PENDING RE-IMPLEMENTATION. When enabled, TR4W rewrites the restart file after logging QSOs. The calls to Sheet.SaveRestartFile were dropped from LOGSUBS2.PAS circa 2020 (see issue #950).

??? info "Evidence and historical context"
    Model path: `Settings.Log.UpdateRestartFile`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## USE RECORDED SIGNS {#use-recorded-signs}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! warning "Explanation not yet written"
    The setting is present in the inventory, but no usable English description was found. Its name alone is not enough to infer its behavior.

??? info "Evidence and historical context"
    Model path: `Settings.Dvk.UseRecordedSigns`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## USER INFO SHOWN {#user-info-shown}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type UserInfoType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The values correspond to fields in the TRMASTER database. Any one of these can be viewed in a window just below the Call Window for the station you are working. If you choose CUSTOM, your initial exchange will be built using the CUSTOM USER STRING. This allows you to choose multiple data fields and display them in any order.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.UserInfoShown`. Source type: `UserInfoType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## VHF BAND ENABLE {#vhf-band-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When set to TRUE, TR4W will allow the selection of the VHF and UHF bands using the alt-B and alt-V keys.

??? info "Evidence and historical context"
    Model path: `Settings.Bands.VhfEnabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## WAIT FOR STRENGTH {#wait-for-strength}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    When you use the [ character in a CW message, TR4W will allow you to enter the strength of an RST report by pressing a single numeric key. If WAIT FOR STRENGTH is TRUE, the program will wait for you to enter the strength before continuing the CW message. If WAIT FOR STRENGTH is FALSE and you havent pressed a key by the time the program is ready to send the strength, it will act as if you had pressed the 9 key and proceed with the message.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.WaitForStrength`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## WAKE UP TIME OUT {#wake-up-time-out}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–255 (numeric type bounds; see description for units) |
| Initial value in constructor | 0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    TR4W can keep track of how many minutes have passed since your last QSO. If this number reaches a programmable limit, an alarm will sound once a minute until you work somebody. This is useful for long contests where you operate until brain death and need 20 or 30 minutes to become functional again. Since this is a dangerous time to try to set an alarm, the program will automatically start counting the minutes. The wake up time out alarm is disabled if the alarm has been set.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.WakeUpTimeOut`. Source type: `TWakeUpTimeOut`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 0. This is not a verified current default.

## WARC BAND ENABLE {#warc-band-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command allows you to operate on 30, 17 and 12 metres. The default is FALSE, unless you are in General QSO mode.

??? info "Evidence and historical context"
    Model path: `Settings.Bands.WarcEnabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## WEIGHT {#weight}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Number |
| Initial value in constructor | 1.0 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    Values: 0.5 to 1.5. This command controls the weight of the CW generated by the computer. For example, a value of 1.05 will add 5 percent to the duration of each dot and dash.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.Weight`. Source type: `double`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 1.00. This is not a verified current default.

## WILDCARD PARTIALS {#wildcard-partials}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This command controls the working of the partial call function. When this parameter is FALSE, only calls that start with the input call will be shown. When set to TRUE (the default), the input call can appear anywhere within the partial call. This allows you to perform a partial call check with the prefix or the suffix, instead of only with the prefix. If your partial call function is working too slowly, you might try setting this flag to FALSE. This flag only affects the partial call display from the dupesheet. The super check partial display always will use wildcard partials.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.WildcardPartials`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## WINDOW SIZE {#window-size}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 1–15 (numeric type bounds; see description for units) |
| Initial value in constructor | 5 |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    The relative ratio of 1 to 15, which determines the size of the main program window.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.WindowSize`. Source type: `TMainWindowSize`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 5. This is not a verified current default.

## WSJT-X BROADCAST PORT {#wsjt-x-broadcast-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 1–65535 (numeric type bounds; see description for units) |
| Initial value in constructor | 2237 |
| Other accepted names | None listed |

UDP receive port for the WSJT-X connection. Match it to the sending application's port. The initial value is 2237; this is separate from a radio-control TCP port.

[Step-by-step guide](../../station/wsjtx.md)

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.BroadcastPort`. Source type: `TWsjtxPort`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 2237. This is not a verified current default.

## WSJT-X ENABLED {#wsjt-x-enabled}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

Controls whether TR4W enables the WSJT-X listener. The source initializes this to true. Match the UDP destination and port in WSJT-X, then verify that a completed contact reaches the intended TR4W contest.

[Step-by-step guide](../../station/wsjtx.md)

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.Enabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## WSJT-X MULTICAST GROUP {#wsjt-x-multicast-group}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

Multicast group for the WSJT-X listener. An empty value selects ordinary unicast. A multicast configuration requires matching group and port settings and an appropriate network interface in the sending application.

[Step-by-step guide](../../station/wsjtx.md)

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.MulticastGroup`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## WSJT-X RADIO CONTROL ENABLED {#wsjt-x-radio-control-enabled}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

Allows frequency changes from WSJT-X to move the radio. The source initializes this to false. Enabling it is not by itself a complete CAT setup; first establish the radio connection and the integration's control path.

[Step-by-step guide](../../station/wsjtx.md)

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.RadioControlEnabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## WSJT-X SEND HIGHLIGHTS {#wsjt-x-send-highlights}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

Controls whether TR4W sends callsign highlight information to WSJT-X. Receiving logged QSOs and sending highlights are separate checks; enable Accept UDP requests in WSJT-X when using the highlighting path.

[Step-by-step guide](../../station/wsjtx.md)

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.SendHighlights`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## YCCC SO2R ENABLE {#yccc-so2r-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    If TRUE, the YCCC SO2R box is supported for switching radio audio streams and other steps involving two-radio mode.

??? info "Evidence and historical context"
    Model path: `Settings.Yccc.So2rEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## ZONE MULTIPLIER {#zone-multiplier}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

!!! quote "Inherited English help — behavior needs review"
    This parameter tells TR4W how to handle the zone multipliers. It is normally set up by the CONTEST statement in your *.CFG file.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.ZoneMultiplier`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Inherited help (`tr4w/target/commands_help_eng.ini`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.
