# ShortString / `@X[1]` boundary audit

Audit requested by NY4I (2026-07-27) after a real corruption bug: the radio dialog
wrote `RADIO TWO CONTROL PORT=SERIAL 17 - USB-CI-V (COM17)` into `tr4w.ini` while the
trace log correctly showed `CMD = SERIAL 17`.

## The rule

A Delphi `ShortString` is **length-prefixed, not NUL-terminated**. So:

| how the buffer was written | is `@X[1]` NUL-terminated? |
|---|---|
| `X := 'something';` (Delphi assignment) | **No.** Sets `X[0]` and the characters. Whatever followed stays. |
| `X[0] := AnsiChar(SomeWin32Api(@X[1], ...))` | **Yes.** The API wrote the NUL; the length byte is set afterwards. |
| `MoveMemory(@X[1], src, n)` | Irrelevant - the consumer is length-based too. |

The second form is TR4W's dominant idiom and is self-consistent. The **first form
combined with a `PAnsiChar` consumer is the hazard**, and it is invisible twice over:
Delphi-side code and the logger both honour the length byte, so only the API sees the
overrun.

The failure that motivated this audit needed one extra ingredient - **re-assignment**.
The enclosing loop did `ZeroMemory` once per iteration, so a single assignment was
safe; assigning a *second*, shorter value in the same pass left the previous value's
tail in place, and `WritePrivateProfileStringA` read straight through it.

## Classification

```
ShortString @X[1] sites, classified
   40  HAZARD      - written by a Delphi ":=" (no terminator) and read as PAnsiChar
   24  api-filled  - filled by an API that NUL-terminates, length byte set after
   10  length-based- MoveMemory/CopyMemory etc, explicit length, termination irrelevant
```

The `api-filled` and `length-based` classes need no action.

## Hazard list

Sites where a `ShortString` is written by a Delphi `:=` and read as a `PAnsiChar`.
Most are currently *mitigated* by a `ZeroMemory`/`FillChar` before the fill - that is
what keeps them working today - but the mitigation is invisible at the call site and
silently lapses if anyone assigns twice, which is exactly what happened in uCAT.

```
LPT.pas
       119  CMD              Windows.WritePrivateProfileStringA(_COMMANDS, @ID[1], @CMD[1], TR4W_INI_FILENAME);
       119  ID               Windows.WritePrivateProfileStringA(_COMMANDS, @ID[1], @CMD[1], TR4W_INI_FILENAME);
  MainUnit.pas
      7375  KeyName          Windows.WritePrivateProfileStringA('COMMANDS', @KeyName[1], @WidthStr[1], @TR4W_CFG_FILENAME);
  trdos\LOGPACK.PAS
       725  PacketString     QuickDisplay(string(PAnsiChar(@PacketString[1])));
  trdos\LOGPROM.PAS
      1028  FileName         if FileExists(@FileName[1]) then
      1042  FileName         until (not FileExists(@FileName[1])) or (Key = 'Y');
  trdos\LOGSTUFF.PAS
      1154  Name             p := @Name[1]
  trdos\LOGWIND.PAS
      1457  TempString       SetMainWindowText(mweBeamHeading, string(PAnsiChar(@TempString[1])));
      3505  InfoString       SetMainWindowText(mweUserInfo, string(PAnsiChar(@InfoString[1])));
      3881  ID               Format(QuickDisplayBuffer, TC_REPEATING, @ID[1], AutoCQDelayTime);
  trdos\LogCfg.pas
       151  ID               if AnsiStrings.StrComp(CFGCA[I].crCommand, @ID[1]) = 0 then
  trdos\PostUnit.PAS
      2733  PreviousQTHString string( PAnsiChar( @PreviousQTHString[ 1 ] ) ), contacts, pnr,
      3349  TempGrid         cMyGrid                          := @TempGrid[ 1 ];
  uAltP.pas
       294  TempString       elvi.pszText := @TempString[1];
       309  TempString       elvi.pszText := @TempString[1];
  uCAT.pas
      1571  CMD              Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1571  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1599  CMD              Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1599  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1613  CMD              Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1613  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1619  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], nil, TR4W_INI_FILENAME);
      1638  CMD              Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1638  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1654  CMD              Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1654  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1661  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], nil, TR4W_INI_FILENAME);
      1670  CMD              Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1670  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], @CMD[1], TR4W_INI_FILENAME);
      1677  ID               Windows.WritePrivateProfileStringA('Radio', @ID[1], nil, TR4W_INI_FILENAME);
  uOption.pas
       607  TempString       tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(@TempString[1])));
       645  TempString       tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(@TempString[1])));
       713  TempString       tLVSetText(SettingshLV, Row, 1, string(PAnsiChar(@TempString[1])));
  uProcessCommand.pas
       252  CommandString    if utils_text.StrComp(sCommandsArray[i].caCommand, @CommandString[1]) = 0 then
       356  scFileName       if Windows.WinExec(@scFileName[1], SW_SHOWMINIMIZED) < 31 then
       396  scFileName       if FileExists(@scFileName[1]) then
       611  scFileName       uTelnet.SendViaTelnetSocket(@scFileName[1]);
       634  scFileName       if utils_text.StrComp(@scFileName[1], CFGCA[i].crCommand) = 0 then
       646  scFileName       Format(QuickDisplayBuffer, '%s=%s', @scFileName[1], BA[PBoolean(CFGCA[i].crAddress)^]);
  uQTCS.pas
       366  TempString       TempString[0] := AnsiChar(TF.Format(@TempString[1], Format, Time, p, Number));
```

## Recommended fix

Change the buffers to `AnsiString` and pass `PAnsiChar(X)`, which is NUL-terminated by
construction. Then no zeroing discipline is required and the class of bug disappears.

**Not done yet, deliberately.** For the config path (`ID`/`CMD`) the ripple is 21
`CheckCommand` call sites and 28 `GetDialogItemText` sites, reaching into
`trdos\CfgCmd.pas` and `trdos\LogCfg.pas` - the `.cfg` contest-config loader. That
wants its own pass with the golden-master corpus as the regression net, not a
drive-by change.

## Detecting regressions

```
grep -rnE "@\s*[A-Za-z_][A-Za-z0-9_]*\s*\[\s*1\s*\]" --include=*.pas --include=*.PAS src
```

Then check how the variable was last written. The generator for this document is
`shortstring_audit2.py` (session scratchpad) - it classifies automatically and can be
re-run to refresh the list.
