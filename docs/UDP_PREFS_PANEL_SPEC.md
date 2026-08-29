# UDP broadcast — Preferences panel: control-name spec

**For NY4I to lay out in the IDE designer.** The code behind it is written against
these exact names, so a name changed in the Object Inspector has to be told back
to me — `Lint-FormFields.ps1` gates the build and fails a published field that
has no component of the same name (and vice versa is what produced the
`EReadError: cbxRadio1.OnChange` on 2026-08-08).

The settings themselves already exist and are tested: `TUDPBroadcastConfig` and
`TUDPBroadcaster` (commit `37a17018`, 15 tests). Nothing below changes them —
this is the panel that edits them.

---

## The model the panel edits

One **destination** is an endpoint — an address, a port, and the kinds of data it
wants:

```
10.0.0.5 : 12060   Contact, Score
10.0.0.5 : 12061   Radio
192.168.1.255 : 12040   Rotor
```

Two rules the panel has to respect, both enforced by `Validate` and both
reported rather than silently corrected:

- **The same address and port twice is refused.** One endpoint, one row; put
  every kind of data it should receive on that row. (A different *port* at the
  same address is a different endpoint — that is the N1MM case, RadioInfo on
  12060 and ContactInfo on 12061.)
- **A row with nothing ticked is refused.** It looks configured and sends
  nothing. Going quiet is what the master switch is for.

---

## Panel 1 — the UDP section in `TPrefsForm`

Drop a `TLayout` in `layContent`, same as `layCW`. **`Tag` must be `5`**
(`NAV_UDPBROADCAST`) — that is the whole wiring; `ShowSelectedSection` finds it
by Tag and nothing else needs to know it exists.

| Name | Type | Purpose |
|---|---|---|
| `layUDP` | `TLayout` | The section panel. **Tag = 5**, `Align = Client`. |
| `chkUDPEnabled` | `TCheckBox` | Master switch — "Broadcast UDP data". |
| `lblUDPDestinations` | `TLabel` | Heading over the list. |
| `lstUDPDestinations` | `TListBox` | One row per destination. |
| `btnUDPAdd` | `TButton` | Add… |
| `btnUDPEdit` | `TButton` | Edit… |
| `btnUDPRemove` | `TButton` | Remove |
| `btnUDPTest` | `TButton` | Test the **selected** row. |
| `chkUDPAllQSOs` | `TCheckBox` | "Also broadcast edited and previously logged QSOs". |
| `lblUDPHint` | `TLabel` | Hint line under the list (wraps). |

Suggested arrangement, matching the CW and radio sections:

```
[x] Broadcast UDP data

Destinations
+------------------------------------------+  [ Add...  ]
| 10.0.0.5:12060      Contact, Score       |  [ Edit... ]
| 10.0.0.5:12061      Radio                |  [ Remove  ]
| 192.168.1.255:12040 Rotor                |  [ Test    ]
+------------------------------------------+

[ ] Also broadcast edited and previously logged QSOs

Each destination is one program listening. Add a second row for the same
address when it expects different data on a different port.
```

Notes for the layout:

- `chkUDPEnabled` sits **above** the list and greys the rest of the panel when
  off — but the destinations stay visible and editable, because "off" means "not
  right now", not "forget my settings".
- `btnUDPTest` is enabled only with a row selected. It sends one packet under its
  own XML root (`<TR4WTest>`), so a test can never land in anybody's log, and it
  works whether or not `chkUDPEnabled` is ticked.
- Row text is built in code from the destination; leave the list empty in the
  designer. (A populated list bakes itself into the `.fmx` — see the note in
  `radio-editor-designed-form-plan`.)

---

## Panel 2 — `TUDPDestinationEditForm`, its own unit and `.fmx`

Same shape as `TRadioEditForm` / `TKeyerEditForm`: a modal editor for one row,
one form per unit. Unit `src/ui/fmx/uUDPDestinationEditForm.pas`.

| Name | Type | Purpose |
|---|---|---|
| `lblAddress` / `edtAddress` | `TLabel` / `TEdit` | Host name or IP. A broadcast address is fine. |
| `lblPort` / `edtPort` | `TLabel` / `TEdit` | 1–65535. |
| `grpStreams` | `TGroupBox` | "Send this destination:" |
| `chkStreamContact` | `TCheckBox` | Contact info (each QSO). |
| `chkStreamRadio` | `TCheckBox` | Radio info (frequency, mode, focus). |
| `chkStreamScore` | `TCheckBox` | Score. |
| `chkStreamRotor` | `TCheckBox` | Rotor headings. |
| `chkStreamLookup` | `TCheckBox` | Callsign lookup requests. |
| `chkStreamAppInfo` | `TCheckBox` | App info — **unimplemented**; see below. |
| `btnTest` | `TButton` | Test what is typed, before saving. |
| `lblTestResult` | `TLabel` | What the test said. |
| `btnOK` / `btnCancel` | `TButton` | Footer. |

`chkStreamAppInfo` stays on the panel because the feature is unfinished rather
than withdrawn (your call, 2026-08-08). The code disables it and appends
"(not implemented yet)" to its text at runtime, so nobody ticks a box that does
nothing — leave the plain caption in the designer.

The Test button reports **that the packet was handed to the socket**, and the
result text says so: UDP cannot tell us it arrived, and wording it as "reached
10.0.0.5" would be a lie the operator would then debug against.

---

## What I do after you save the `.fmx`

1. Add the published fields and published event handlers (both must be
   published, or the form streams and does nothing — that is the `cbxRadio1`
   trap).
2. Wire the `OnClick`/`OnChange` handlers **in code** after streaming, so you do
   not need a second trip through the designer to pick handlers that did not
   exist when you laid it out. If you later wire them in the Object Inspector
   too, that is harmless — the assignments are the same method.
3. Load / capture / validate, and hand the config to `UDPBroadcaster.Configure`
   on Apply, exactly as the radio profile does.
4. Add the `<FormName>` metadata to `tr4w.lproj` and the `{FormName}` entry in
   `tr4w.lpr` for the new editor form. **Order matters** — metadata without
   `{$R *.fmx}` opens an empty designer and leaves every field nil at runtime.

Only step 1 depends on you; everything else follows.
