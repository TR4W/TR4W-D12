# Commands E–L

Setting metadata was extracted from TR4W 5.1.0. The English help accompanying each setting may still need operator review. [Read the reference conventions](index.md) before editing settings.

## ENABLE N1MM LOG LISTENER {#enable-n1mm-log-listener}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    Accept QSOs logged by JTDX (TCP port 52001) or JTAlert and WSJT-X (UDP port 2333), sent in N1MM Logger+&#x27;s Log format. Off by default. Anything that can reach the listener can add QSOs to the open contest log.

??? info "Evidence and historical context"
    Model path: `Settings.Wsjtx.N1mmListenerEnabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## ENFORCE VALID CALLSIGN {#enforce-valid-callsign}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    TRUE refuses to log a QSO whose base call (the longest part around any /, so W1AW/P, VE3/W1AW and NY4I/PIN all count as W1AW or NY4I) is not a DXCC entity in the country file. The QSO is not logged, the call and exchange stay as typed, and the reason is shown on the status line. No check is made when no country file is loaded. Default FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.EnforceValidCallsign`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## ESCAPE EXITS SEARCH AND POUNCE {#escape-exits-search-and-pounce}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, pressing &lt;Esc&gt; when in S&amp;P Mode causes TR4W to revert to CQ Mode. When the parameter is FALSE, the only way to revert to CQ Mode is to press shift-Tab. However, the FALSE setting is ignored if you have a call ready for a QSO on the other rig. This allows you to abort a second-radio QSO with &lt;Esc&gt; even if this parameter is FALSE.

??? info "Evidence and historical context"
    Model path: `Settings.Cq.EscapeExitsSearchAndPounce`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## EXCHANGE MEMORY ENABLE {#exchange-memory-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    This parameter allows you to control whether the TR4W exchange memory is used. The exchange memory is useful when working the same station on different bands or modes, and when the exchange contains either a class (e.g., ARRL Field Day), power (ARRL DX), age (All Asian), name, ITU Society name (IARU), zone, or Domestic QTH. If you have worked the station before in the contest, the constant information will appear without you having to re-enter it. Please note that this information is lost if you stop TR4W and the *.RST file is deleted.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.ExchangeMemoryEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## EXTERNAL LOGGER {#external-logger}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;NONE&#x27; |
| Other accepted names | None listed |

Legacy provider selection used to seed the External Logger grid when migrating a single-destination configuration. Configure current destinations in the grid.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.LoggerType`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER ACCOUNT ID {#external-logger-account-id}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

Legacy account identifier used to seed a logger definition. Set the account on the appropriate row in the External Logger grid.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.AccountId`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER ADDRESS {#external-logger-address}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;127.0.0.1&#x27; |
| Other accepted names | None listed |

Legacy address copied when seeding a logger definition. Set the host or URL on the individual destination for the current configuration.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.Address`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER API KEY {#external-logger-api-key}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Credential; use the settings UI |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

Legacy API credential used to seed a logger definition. Enter credentials for each destination in the External Logger grid.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.ApiKey`. Source type: `TSecretText`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER ENABLED {#external-logger-enabled}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

Legacy enable flag used when seeding a logger definition. To control forwarding now, set Enabled on the individual logger row and save Preferences.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.Enabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER LOGBOOK ID {#external-logger-logbook-id}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

Legacy logbook identifier used to seed a logger definition. Choose the logbook on the individual destination.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.LogbookId`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## EXTERNAL LOGGER PORT {#external-logger-port}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Integer |
| Initial value in constructor | 52001 |
| Other accepted names | None listed |

Legacy TCP port copied when seeding a logger definition. Set the port on the individual destination if its provider requires one.

[Step-by-step guide](../../station/external-loggers.md)

??? info "Evidence and historical context"
    Model path: `Settings.ExternalLogger.Port`. Source type: `integer`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## FARNSWORTH ENABLE {#farnsworth-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When slowing down the CW speed, it is often desirable to increase the space between letters. Turning on FARNSWORTH ENABLE will increase the spaces between letters exponentially as your speed decreases below the value of FARNSWORTH SPEED (default is 25 WPM). You can control this parameter dynamically while sending a CW message.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.FarnsworthEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## FARNSWORTH SPEED {#farnsworth-speed}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–99 (numeric type bounds; see description for units) |
| Initial value in constructor | 25 |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Integer (WPM). Controls the CW speed at which the Farnsworth effect starts. As you decrease the code speed below this value, there will be exponentially more space added between characters. For increased Farnsworth effect at very slow speeds, increase the value of FARNSWORTH SPEED. You can also control this parameter dynamically within CW messages.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.FarnsworthSpeed`. Source type: `TCwFarnsworthSpeed`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 25. This is not a verified current default.

## FONT SIZE {#font-size}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–2 (numeric type bounds; see description for units) |
| Initial value in constructor | 2 |
| Other accepted names | None listed |

!!! quote "English settings help"
    A small step added to the main window&#x27;s text: 0, 1 or 2 (default 2). It is not a point size; the main window&#x27;s text size follows the width of the window, and this adds 0 to 2 pixels on top of it. It also sizes the text of the MMTTY window. Takes effect when TR4W next starts.

??? info "Evidence and historical context"
    Model path: `Settings.Font.Size`. Source type: `TMainFontSize`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: 2. This is not a verified current default.

## FREQUENCY MEMORY ENABLE {#frequency-memory-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    When set to TRUE, this parameter will enable the frequency memory. This means that you will return to the frequency you were last using when returning to a band (even with the other radio).

??? info "Evidence and historical context"
    Model path: `Settings.Operating.FrequencyMemoryEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## GRID MAP CENTER {#grid-map-center}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: Four- or six-character grid reference. This parameter will set the centre of a grid map that will show you at a glance the grids you have worked. The grid map will be displayed in VGA mode (if available). The ctrl-Left and ctrl-Right keys may be used to move the grid map sideways. (There is no way to move the grid map vertically.)

??? info "Evidence and historical context"
    Model path: `Settings.GridMap.Center`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## HAMSCORE ENABLE {#hamscore-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    If true, then the real-time contest sacoring is sent to hamscore.net. Note this only applies to certain contests.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.HamscoreEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## HAMSCORE PASSWORD {#hamscore-password}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Credential; use the settings UI |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Password used for real-time contest uploads for RTC contests.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.Password`. Source type: `TSecretText`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: Blank. This is not a verified current default.

## HAMSCORE SEND CONTACT INFO {#hamscore-send-contact-info}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    Some contests prefer that the real-time information not be sent (strategy reasons one presumes). If false, the contact daty will not be sent--just the scores.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.SendContactInfo`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## HAMSCORE URL {#hamscore-url}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    This is the URL used to send real-time contest data, to post score info or both.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.Url`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: http://scoredistributor.net/. This is not a verified current default.

## HAMSCORE URL DEFAULT MIGRATED {#hamscore-url-default-migrated}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

Internal flag recording whether TR4W has checked the saved HamScore URL for the one-time default URL migration. Set the service URL through Online scoring.

[Step-by-step guide](../../station/online-scores.md)

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.UrlDefaultMigrated`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## HAMSCORE USERNAME {#hamscore-username}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type TCaseSensitiveText; allowed values need editorial review |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    User used for real-time contest uploads for RTC contests. Note this is typically your callsign but woudl be whatever your account with Hamscore indicates.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.Username`. Source type: `TCaseSensitiveText`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: Blank. This is not a verified current default.

## HAMSCORE VERIFY SERVER {#hamscore-verify-server}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    When TRUE, TR4W checks the HamScore server&#x27;s certificate before uploading, as long as the program-wide certificate check in settings/tr4w.json is on (it is by default). Clear it only for a server whose certificate cannot be checked: the server&#x27;s identity is then not checked and anyone between you and it can read what you send, including your HamScore password. It is read when the uploader starts, at TR4W startup.

??? info "Evidence and historical context"
    Model path: `Settings.Hamscore.VerifyServer`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

## HAND LOG MODE {#hand-log-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    For entering a paper log after the event. When this parameter is TRUE, the QSO time no longer follows the computer clock; it moves only when you advance it with Alt-1 to Alt-0 (1 to 10 minutes) or through AUTO TIME INCREMENT; when it is FALSE, those increment-time menu items are greyed out. TR4W shows a warning at startup while this is TRUE; restart TR4W after changing it.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.HandLogMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## HF BAND ENABLE {#hf-band-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    This parameter enables the HF bands below 30 MHz. It is automatically set to FALSE when you select a VHF contest.

??? info "Evidence and historical context"
    Model path: `Settings.Bands.HfEnabled`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## HOUR DISPLAY {#hour-display}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | See type HourDisplayType; allowed values need editorial review |
| Initial value in constructor | Not extracted; see source |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: THIS HOUR, LAST SIXTY MINUTES or BAND CHANGES. This parameter determines how the hour rate display works. In the THIS HOUR mode, it shows the number of QSOs made during the current hour (starting at 15:00, for example). In the LAST SIXTY MINUTES, it shows the number of contacts made during the last 60 minutes. The BAND CHANGES mode will count how many band changes have been made since the current hour began.

??? info "Evidence and historical context"
    Model path: `Settings.MainWindow.HourDisplay`. Source type: `HourDisplayType`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: THIS HOUR. This is not a verified current default.

## IE SWITCH {#ie-switch}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    If TRUE, only spots matched to active InitialExhange and TRMaster File will display to BandMap.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.IeSwitch`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: FALSE. This is not a verified current default.

## IN BAND LOCKOUT {#in-band-lockout}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    values:True/False. Default of TRUE prevents Band Map selection that would place both radios on a single band.

??? info "Evidence and historical context"
    Model path: `Settings.So2r.InBandLockout`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name was not found in the extracted v4.01 contents; that does not establish when the feature was introduced.

    Historical help default: TRUE. This is not a verified current default.

## INCLUDE F-KEY NUMBER {#include-f-key-number}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When viewing the F-Keys window, if this option is true, the F key name/number is displayed (e.g., F1 - &lt;caption&gt;).

??? info "Evidence and historical context"
    Model path: `Settings.Cw.IncludeFKeyNumber`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## INCREMENT TIME ENABLE {#increment-time-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    Determines whether the &quot;increment time function&quot; using Alt-1 to Alt-0 is enabled. If this flag is set to TRUE, the alt-1 to alt-0 keys will increment the time by 1 to 10 minutes respectively. This function can be useful when entering a log by hand after the contest.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.IncrementTimeEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## INITIAL EXCHANGE CURSOR POS {#initial-exchange-cursor-pos}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;AT END&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Values: AT START or AT END. When an initial exchange is inserted into the Exchange Window, this command controls whether the cursor is placed at the start or at the end of the exchange.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchangeCursorPos`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: AT END. This is not a verified current default.

## INITIAL EXCHANGE FILENAME {#initial-exchange-filename}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | Text |
| Initial value in constructor | &#x27;INITIAL.EX&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    This parameter allows you to specify the name of the initial exchange file. This file is used by TR4W to determine initial exchanges for the callsigns included in the file. The calls will also be used in the partial call list. The format for the file is: callsign, followed by a space, and then the initial exchange information as you want it to appear in the Exchange Window.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchangeFilename`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: INITIAL.EX. This is not a verified current default.

## INITIAL EXCHANGE OVERWRITE {#initial-exchange-overwrite}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    If this parameter is TRUE, then pressing any key after an initial exchange has been entered into the Exchange Window by TR4W will cause the exchange to be erased, allowing you to insert a complete exchange manually.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.InitialExchangeOverwrite`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## INSERT MODE {#insert-mode}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | True |
| Other accepted names | None listed |

!!! quote "English settings help"
    This command allows you to define the initial state of the insert mode, which controls whether characters are overwritten or inserted when editing a callsign or exchange. You can toggle the insert mode while TR4W is running with ctrl-V or the INSERT key.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.InsertMode`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: TRUE. This is not a verified current default.

## INTERCOM FILE ENABLE {#intercom-file-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, all messages sent between computers during the contest will be logged to the file INTERCOM.TXT.

??? info "Evidence and historical context"
    Model path: `Settings.Network.IntercomFileEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## KEYPAD CW MEMORIES {#keypad-cw-memories}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, the keys 0 to 9 on the keypad will send CQ MEMORIES ctrl-F1 to ctrl-F10 respectively.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.KeypadMemories`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LEADING ZERO CHARACTER {#leading-zero-character}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Single character |
| Initial value in constructor | &#x27;0&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    This parameter allows you to customize the character used as a leading zero when generating serial numbers and LEADING ZEROS has a value greater than zero. Normally, the character is T. However, you might prefer the number 0 or the letter O. If you use the ctrl-J menu to access this parameter, it will let you cycle among those three characters.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.LeadingZeroCharacter`. Source type: `AnsiChar`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: T. This is not a verified current default.

## LEADING ZEROS {#leading-zeros}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 0–3 (numeric type bounds; see description for units) |
| Initial value in constructor | 3 |
| Other accepted names | None listed |

!!! quote "English settings help"
    If you want your serial number to be a certain length by adding leading zeros, you can specify the length with this command. A value of zero disables the addition of any leading zeros. You can set the character used for leading zeros with the LEADING ZERO CHARACTER command.

??? info "Evidence and historical context"
    Model path: `Settings.Cw.LeadingZeros`. Source type: `TCwLeadingZeros`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 3. This is not a verified current default.

## LEAVE CURSOR IN CALL WINDOW {#leave-cursor-in-call-window}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, the cursor will remain in the Call Window instead of moving automatically to the Exchange Window during the QSO process. Some people prefer this mode in contests where a zone is displayed as the initial exchange and you rarely need to change it.

??? info "Evidence and historical context"
    Model path: `Settings.CallWindow.LeaveCursor`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LITERAL DOMESTIC QTH {#literal-domestic-qth}

| Detail | Current metadata |
| --- | --- |
| Scope | Contest |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    Normally, TR4W will filter the domestic QTH that you type, and log the QTH as shown in the domestic file. If you would rather log exactly what you type, set this parameter to TRUE.

??? info "Evidence and historical context"
    Model path: `Settings.Contest.LiteralDomesticQth`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LOG FREQUENCY ENABLE {#log-frequency-enable}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, the serial number will be replaced with the frequency of the QSO (without the leading Megahertz part of the value). The band and mode will still be written at the start of the log entry. This feature is only useful if you have an interfaced radio.

??? info "Evidence and historical context"
    Model path: `Settings.Log.FrequencyEnable`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LOG RS SENT {#log-rs-sent}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 11–59 (numeric type bounds; see description for units) |
| Initial value in constructor | 59 |
| Other accepted names | None listed |

!!! quote "English settings help"
    The outbound signal report that appears in your log can be changed from the default of 59 or 599. Note that the [ character in your CW exchange allows you to enter the strength of the RST transmitted, and this value will be placed in your log instead of the default.

??? info "Evidence and historical context"
    Model path: `Settings.Log.RsSent`. Source type: `TLogRsSent`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 59. This is not a verified current default.

## LOG RST SENT {#log-rst-sent}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | 111–599 (numeric type bounds; see description for units) |
| Initial value in constructor | 599 |
| Other accepted names | None listed |

!!! quote "English settings help"
    The outbound signal report that appears in your log can be changed from the default of 59 or 599. Note that the [ character in your CW exchange allows you to enter the strength of the RST transmitted, and this value will be placed in your log instead of the default.

??? info "Evidence and historical context"
    Model path: `Settings.Log.RstSent`. Source type: `TLogRstSent`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: 599. This is not a verified current default.

## LOG SUB TITLE {#log-sub-title}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | Text |
| Initial value in constructor | &#x27;&#x27; |
| Other accepted names | None listed |

!!! quote "English settings help"
    Use this command if you want a subtitle to appear at the top of each printed log page.

??? info "Evidence and historical context"
    Model path: `Settings.Operating.LogSubTitle`. Source type: `string`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: NONE. This is not a verified current default.

## LOG WITH SINGLE ENTER {#log-with-single-enter}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    If this parameter is TRUE, the QSO will be logged as soon as you press the initial &lt;Enter&gt; (to send the exchange). In other words, it behaves as if you have pressed &lt;Enter&gt; followed by ctrl-Enter.

??? info "Evidence and historical context"
    Model path: `Settings.Log.WithSingleEnter`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.

## LOOK FOR RST SENT {#look-for-rst-sent}

| Detail | Current metadata |
| --- | --- |
| Scope | Station |
| Values | TRUE or FALSE |
| Initial value in constructor | False |
| Other accepted names | None listed |

!!! quote "English settings help"
    When this parameter is TRUE, a transmitted RST may be entered into the Exchange Window by preceding it with S. For example, typing S57 would place 57 into the log as the transmitted exchange for this QSO.

??? info "Evidence and historical context"
    Model path: `Settings.Log.LookForRstSent`. Source type: `boolean`.

    Settings model (`tr4w/src/uSettingsModel.pas`) · Inventory (`tr4w/docs/SETTINGS_INVENTORY.md`) · Current English help (`i18n/help_en.po`)

    This exact name appears in the v4.01 manual contents.

    Historical help default: FALSE. This is not a verified current default.
