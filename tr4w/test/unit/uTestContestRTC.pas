(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE REAL TIME CONTEST (RTC) -- the 2026 rules
   (https://blog.contestonlinescore.com/real-time-contest-rtc-rules/, read
   2026-10-23).

   "Each station may be worked only ONCE per band on CW, and ONCE per band
   on SSB" -- the sponsor's "most important change". Multipliers are
   "unique 4-character grid locators worked per band" -- per band, NOT per
   mode. Bands 40, 20, 15 and 10 m; modes CW and SSB.

   Test_RTCDupesPerBandAndModeMultipliersPerBand drives the REAL engine --
   ParametersOkay, the dupe question LogContact asks, SetMultFlags and the
   sheets -- with the dupe and multiplier settings taken FROM THE CLASS, as
   FCONTEST.ApplyContestTraits writes them, so a wrong flag is seen as a
   wrong dupe or a wrong multiplier, not only as a wrong set. *)
unit uTestContestRTC;

{$I tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestRTCTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_RTCStatesItsBandsModesAndFlags;
      procedure Test_RTCDupesPerBandAndModeMultipliersPerBand;
      procedure Test_RTCRefusesARecordWithSerialZero;
      procedure Test_EditQSOSaveAsksTheRefusalFirst;
      procedure Test_RTCImportWithASerialZeroImportsNothing;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   (* PosEx *)
   StrUtils,
   (* SourceText -- a routine's source, for an order no headless test can drive. *)
   uTestAutomaticXQSO,
   (* SetCharBuffer / CharBufferText -- TR4W_LOG_FILENAME *)
   utils_text,
   (* LogStoreClose -- the import test's scratch log *)
   uLogStore,
   (* LogDatabaseFileName -- the same *)
   uLogDatabase,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestRegistry,
   (* ReleaseActiveContest *)
   uContestFactory,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   (* TC_QSONUMBERZERONOTVALID *)
   uTR4WStrings,
   LogDupe,
   LogEdit,
   LogWind,
   LogStuff,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   MainUnit;

(* ---------------------------------------------------------------------------
   WHAT THE CLASS STATES
   --------------------------------------------------------------------------- *)

procedure TContestRTCTests.Test_RTCStatesItsBandsModesAndFlags;
var
   c: TContestBase;
   b: BandType;
begin
   BeginTest('Test_RTCStatesItsBandsModesAndFlags');
   c := ContestIdentity(RTC);

   (* "Bands: 40m, 20m, 15m, 10m." Every real band -- AllBands and NoBand
      are keys, not bands. *)
   for b := Band160 to BandLight do
      begin
      if b in [Band40, Band20, Band15, Band10] then
         begin
         CheckTrue(ContestCreditsBand(c, b), 'RTC credits band ' + IntToStr(Ord(b)));
         end
      else
         begin
         CheckFalse(ContestCreditsBand(c, b), 'RTC refuses band ' + IntToStr(Ord(b)));
         end;
      end;

   (* "mixed mode format (CW and SSB)": SSB is Phone, FM refused (Q120(a)). *)
   CheckTrue(ContestCreditsMode(c, CW, eNoMode), 'credits CW');
   CheckTrue(ContestCreditsMode(c, Phone, eUSB), 'credits SSB');
   CheckTrue(ContestCreditsMode(c, Phone, eNoMode), 'phone with no submode is never off-mode');
   CheckFalse(ContestCreditsMode(c, FM, eFM), 'refuses FM');
   CheckFalse(ContestCreditsMode(c, Digital, eRTTY), 'refuses RTTY');
   CheckFalse(ContestCreditsMode(c, Digital, eFT8), 'refuses FT8');

   (* Dupes per band AND mode; multipliers per band, NOT per mode. *)
   CheckTrue(c.QSOByBand, 'QSOs by band');
   CheckTrue(c.QSOByMode, 'QSOs by mode -- once per band on CW, once on SSB (2026)');
   CheckTrue(c.MultByBand, 'grids by band');
   CheckFalse(c.MultByMode, 'grids NOT by mode');
end;

(* ---------------------------------------------------------------------------
   THE REAL ENGINE -- ParametersOkay, the dupe question and the sheets
   --------------------------------------------------------------------------- *)

procedure TContestRTCTests.Test_RTCDupesPerBandAndModeMultipliersPerBand;
var
   rtcHandle: TContestHandle;
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedGrid: string;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   ctyPath: string;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT: ParametersOkay, then what
      LogContact does with the record it accepts -- the dupe question, the
      dupe's zero points, the sheets. Returns whether it was a dupe. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; out aAccepted: boolean;
                  var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      ActiveMode := aMode;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      ExchangeErrorToken := '';
      aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                                  14025000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
      Result := False;
      if aAccepted then
         begin
         Result := VisibleLog.QSOIsADupe(aRX);
         if Result then
            begin
            aRX.ceDupe := True;
            aRX.QSOPoints := 0;
            end;
         Sheet.SetMultFlags(aRX);
         Sheet.AddQSOToSheets(@aRX, False);
         AddQSOToDupeSheets(aRX, False);
         end;
   end;

begin
   BeginTest('Test_RTCDupesPerBandAndModeMultipliersPerBand');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

   rtcHandle := ContestHandleOf(RTC);
   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedGrid := Settings.My.Grid;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      (* AS FoundContest SETS IT UP: no domestic countries (the matrix's
         `domestic.countries =` line for RTC is empty), MY GRID FN36, and
         the class's flags. *)
      DomesticCountries.Clear;
      Settings.My.Grid := 'FN36';
      CheckEquals('FN36', Settings.My.ResolvedGrid,
                  'precondition: MY GRID resolves to FN36 (no contest override)');
      Contest := rtcHandle;
      ReleaseActiveContest;
      Settings.Qso.ByBand := ContestIdentity(rtcHandle).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(rtcHandle).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(rtcHandle).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(rtcHandle).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* 20 m CW: FN36 to JO62 is between 4000 and 8000 km -- 3 points, and
         JO62 is a new grid on 20 m. *)
      dupe := Enter('DL1AAA', '599 001 JO62', Band20, CW, accepted, rx);
      CheckTrue(accepted, '599 001 JO62 is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the first QSO is not a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), 'FN36 to JO62 scores 3');
      CheckTrue(rx.DomesticMult, 'JO62 is a new multiplier on 20 m');

      (* "ONCE per band on CW, and ONCE per band on SSB": the same station on
         20 m SSB is a new QSO and earns its points ... *)
      dupe := Enter('DL1AAA', '59 002 JO62', Band20, Phone, accepted, rx);
      CheckTrue(accepted, '59 002 JO62 on SSB is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, 'the same station on 20 m SSB after 20 m CW is NOT a dupe');
      CheckEquals(3, Integer(rx.QSOPoints), 'and scores its 3 points');
      (* ... but "grid locators worked per band": JO62 is not a new
         multiplier on 20 m SSB once worked on 20 m CW. *)
      CheckFalse(rx.DomesticMult, 'JO62 on 20 m SSB is NOT a new multiplier after 20 m CW');

      (* Same band, same mode: a dupe, 0 points. *)
      dupe := Enter('DL1AAA', '599 003 JO62', Band20, CW, accepted, rx);
      CheckTrue(dupe, 'the same station again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      dupe := Enter('DL1AAA', '59 004 JO62', Band20, Phone, accepted, rx);
      CheckTrue(dupe, 'the same station again on 20 m SSB IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');

      (* THE CONTROL, per band: the same grid on 40 m is a new multiplier. *)
      dupe := Enter('DL1AAA', '599 005 JO62', Band40, CW, accepted, rx);
      CheckFalse(dupe, 'the same station on 40 m CW is not a dupe');
      CheckTrue(rx.DomesticMult, 'JO62 IS a new multiplier on 40 m');

      (* Off its bands: logged, an automatic X-QSO, nothing earned. *)
      dupe := Enter('DL2BBB', '599 006 JO51', Band80, CW, accepted, rx);
      CheckTrue(accepted, 'an 80 m QSO is logged');
      CheckTrue(QSOIsXQSO(ContestIdentity(rtcHandle), rx), 'as an X-QSO');
      CheckEquals(0, Integer(rx.QSOPoints), 'and scores 0');
      CheckFalse(rx.DomesticMult, 'and earns no multiplier');

      (* "The QSO is logged with sent or reseived QSO serial number 0" is not
         valid, and NY4I (2026-10-23): "a qso with a serial number of 0 should
         have never made it past input editing" -- REFUSED, with its reason
         and the caret after the word that carried it. *)
      Enter('DL3CCC', '0 FN31', Band20, CW, accepted, rx);
      CheckFalse(accepted, '0 FN31 is refused');
      CheckEquals(TC_QSONUMBERZERONOTVALID, string(ExchangeErrorMessage),
                  'with the serial-0 reason');
      CheckEquals('0', string(ExchangeErrorToken), 'the caret goes after the 0');
      Enter('DL3CCC', '599 000 FN31', Band20, CW, accepted, rx);
      CheckFalse(accepted, '599 000 FN31 is refused');
      CheckEquals(TC_QSONUMBERZERONOTVALID, string(ExchangeErrorMessage),
                  '000 is a serial of 0 too');
      CheckEquals('000', string(ExchangeErrorToken), 'the caret goes after the 000');

      (* THE CONTROL: serial 1 is taken. *)
      dupe := Enter('DL3CCC', '599 1 FN31', Band20, CW, accepted, rx);
      CheckTrue(accepted, '599 1 FN31 is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(1, rx.NumberReceived, 'serial 1');
      CheckEquals('', string(ExchangeErrorToken), 'no caret');

      (* NO SERIAL AT ALL -- the format's own refusal, unchanged and measured
         2026-10-23: refused, and WITHOUT a message (LOGSTUFF's
         ProcessRSTAndQSONumberExchange exits on Val('') before it names
         one -- the positional parsers' known silence, Q115). *)
      Enter('DL4DDD', 'FN31', Band20, CW, accepted, rx);
      CheckFalse(accepted, 'FN31 alone is refused (no serial)');
      CheckEquals('', string(ExchangeErrorMessage), 'with no message today');
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      mo.ClearAllMults;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      Settings.My.Grid := savedGrid;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

(* ---------------------------------------------------------------------------
   A SERIAL OF 0 IS REFUSED OUTRIGHT -- TContestBase.LoggedQSORefusal
   (2026-10-23). NY4I: "a qso with a serial number of 0 should have never
   made it past input editing (or import)". ONE rule, asked by typed entry
   (above), Edit QSO's save and the ADIF import, which aborts the WHOLE import
   with nothing written (Q112's ruling).
   --------------------------------------------------------------------------- *)

(* An ADIF record line for the import tests. *)
function AdifRecord(const aCall: string; const aContestId: string;
                    const aSent: string; const aReceived: string): string;
begin
   Result := '<CALL:' + IntToStr(Length(aCall)) + '>' + aCall +
             '<BAND:3>20m<MODE:2>CW<QSO_DATE:8>20260115<TIME_ON:4>1200' +
             '<RST_SENT:3>599<RST_RCVD:3>599' +
             '<STX:' + IntToStr(Length(aSent)) + '>' + aSent +
             '<SRX:' + IntToStr(Length(aReceived)) + '>' + aReceived +
             '<GRIDSQUARE:4>JO62' +
             '<CONTEST_ID:' + IntToStr(Length(aContestId)) + '>' + aContestId +
             '<EOR>';
end;

(* THE DECISION -- what Edit QSO's save and the import ask, of the record's
   own contest, station-less. *)
procedure TContestRTCTests.Test_RTCRefusesARecordWithSerialZero;
var
   rtcRules: TContestBase;
   q: ContestExchange;
begin
   BeginTest('Test_RTCRefusesARecordWithSerialZero');
   rtcRules := ContestIdentity(RTC);
   q := Default(ContestExchange);
   q.ceContest := ContestHandleOf(RTC);

   q.NumberSent := 5;
   q.NumberReceived := 0;
   CheckEquals(TC_QSONUMBERZERONOTVALID, ContestLoggedQSORefusal(rtcRules, q),
               'a received serial of 0 is refused');
   q.NumberSent := 0;
   q.NumberReceived := 7;
   CheckEquals(TC_QSONUMBERZERONOTVALID, ContestLoggedQSORefusal(rtcRules, q),
               'a sent serial of 0 is refused');
   q.NumberSent := 5;
   CheckEquals('', ContestLoggedQSORefusal(rtcRules, q), 'serials 5 and 7 are taken');
   (* MISSING IS NOT 0: ClearContestExchange's -1, and ADIF's $FFFF for a
      record with no SRX/STX tag. *)
   q.NumberReceived := -1;
   CheckEquals('', ContestLoggedQSORefusal(rtcRules, q), 'a missing received serial (-1) is not 0');
   q.NumberReceived := $FFFF;
   CheckEquals('', ContestLoggedQSORefusal(rtcRules, q), 'a missing ADIF SRX ($FFFF) is not 0');

   (* THE BASE ACCEPTS EVERY RECORD: CQ WW with a 0 is not refused. *)
   q.ceContest := ContestHandleOf(CQWWCW);
   q.NumberSent := 0;
   q.NumberReceived := 0;
   CheckEquals('', ContestLoggedQSORefusal(ContestIdentity(CQWWCW), q),
               'CQ WW states no such rule');
   CheckEquals('', ContestLoggedQSORefusal(nil, q), 'nor does a classless contest');
end;

(* EDIT QSO'S SAVE -- READ, because the form is not driven headless: it asks
   the refusal of the record's contest, shows it as the bad-call refusal is
   shown, and refuses BEFORE anything leaves -- the UDP and HamScore notices
   and the store's write. *)
procedure TContestRTCTests.Test_EditQSOSaveAsksTheRefusalFirst;
var
   text: string;
   save: integer;
   ask: integer;
begin
   BeginTest('Test_EditQSOSaveAsksTheRefusalFirst');
   text := SourceText('uEditQSO.pas');
   save := Pos('function SaveQSOToEditableLog: boolean;' + sLineBreak + 'label', text);
   CheckTrue(save > 0, 'SaveQSOToEditableLog is found');
   ask := PosEx('TempString := ContestLoggedQSORefusal(ContestIdentity(EditableQSORXData.ceContest),',
                text, save);
   CheckTrue(ask > save, 'the save asks the record''s contest');
   CheckTrue(PosEx('showwarning(TempString);', text, ask) > ask, 'and shows its reason');
   (* PostQsoEvent is the one call that carries the UDP, external-logger and
      HamScore notices to the QSO dispatcher (2026-10-24). *)
   CheckTrue(ask < PosEx('PostQsoEvent(', text, save),
             'before any UDP, external-logger or HamScore notice');
   CheckTrue(ask < PosEx('LogStoreUpdateQSOAtIndex(', text, save), 'before the store''s write');
   (* After the two serials are read from the form, or it would judge the old
      values. *)
   CheckTrue(ask > PosEx('EditableQSORXData.NumberReceived := TempInteger;', text, save),
             'after the received serial is read');
   CheckTrue(ask > PosEx('EditableQSORXData.NumberSent := EditQSOGetInt(FLD_NUMBERSEND',
                         text, save),
             'after the sent serial is read');
end;

(* THE ADIF IMPORT, DRIVEN: three RTC records, the second with a received
   serial of 0. NOTHING is imported -- the import stops before its one write
   -- and the report names the record, its time and the reason. *)
procedure TContestRTCTests.Test_RTCImportWithASerialZeroImportsNothing;
const
   SCRATCH_SUFFIXES: array[0..3] of string = ('', '-wal', '-shm', '-journal');
var
   savedContest: TContestHandle;
   savedSilent: boolean;
   savedLogName: string;
   scratchLog: string;
   fileName: string;
   lines: TStringList;
   report: string;
   text: string;
   refuse: integer;
   rx: ContestExchange;
   i: integer;
begin
   BeginTest('Test_RTCImportWithASerialZeroImportsNothing');
   savedContest := Contest;
   savedSilent := tSilentExport;
   savedLogName := CharBufferText(TR4W_LOG_FILENAME);
   fileName := ExtractFilePath(ParamStr(0)) + 'rtc_serial_zero_import.adi';
   (* THE LOG, IN THE SYSTEM'S TEMP DIRECTORY: if the refusal ever stops
      working, the import goes on to write -- and must not write into the
      tree (a mutation run left tr4w/test/unit/.db behind, 2026-10-23). *)
   scratchLog := GetTempDir(False) + 'tr4w_rtc_serial_zero.trw';
   lines := TStringList.Create;
   try
      Contest := ContestHandleOf(RTC);
      ReleaseActiveContest;
      SetCharBuffer(TR4W_LOG_FILENAME, scratchLog);
      (* Headless: a refusal is a log line and a False, never a modal. *)
      tSilentExport := True;

      (* THE PRECONDITION, so a broken rule fails here rather than letting
         the import go on to its write and rescore. *)
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('DL2BBB', 'RTC', '2', '0'), rx), 'the 0 record parses');
      if ContestLoggedQSORefusal(ContestIdentity(rx.ceContest), rx) = '' then
         begin
         CheckTrue(False, 'RTC does not refuse a received serial of 0 -- the import is not driven');
         Exit;
         end;
      rx := Default(ContestExchange);
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('DL4DDD', 'RTC', '0', '14'), rx), 'the sent-0 record parses');
      if ContestLoggedQSORefusal(ContestIdentity(rx.ceContest), rx) = '' then
         begin
         CheckTrue(False, 'RTC does not refuse a sent serial of 0 -- the import is not driven');
         Exit;
         end;

      lines.Add('TR4W unit test');
      lines.Add('<EOH>');
      lines.Add(AnsiString(AdifRecord('DL1AAA', 'RTC', '1', '11')));
      lines.Add(AnsiString(AdifRecord('DL2BBB', 'RTC', '2', '0')));
      lines.Add(AnsiString(AdifRecord('DL3CCC', 'RTC', '3', '13')));
      lines.SaveToFile(AnsiString(fileName));

      CheckFalse(ImportFromADIF(fileName, report), 'the import fails');
      CheckTrue(Pos('NOTHING was imported', report) > 0, 'nothing was imported: ' + report);
      CheckTrue(Pos('record 2 (DL2BBB', report) > 0, 'the second record is named: ' + report);
      CheckTrue(Pos(TC_QSONUMBERZERONOTVALID, report) > 0, 'with the reason: ' + report);

      (* A SENT serial of 0 is refused the same way. *)
      lines.Clear;
      lines.Add('<EOH>');
      lines.Add(AnsiString(AdifRecord('DL4DDD', 'RTC', '0', '14')));
      lines.SaveToFile(AnsiString(fileName));
      CheckFalse(ImportFromADIF(fileName, report), 'a sent 0 fails the import too');
      CheckTrue(Pos('record 1 (DL4DDD', report) > 0, 'and names it: ' + report);

      (* THE CLEAN RECORD AND ANOTHER CONTEST'S 0 ARE NOT REFUSED. The write
         path itself (the store's one transaction, the rescore) is not driven
         here -- the corpus round trip drives it; this asks exactly what the
         loop asks of each record. *)
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('DL1AAA', 'RTC', '1', '11'), rx), 'a clean RTC record');
      CheckEquals('', ContestLoggedQSORefusal(ContestIdentity(rx.ceContest), rx),
                  'is not refused');
      Contest := ContestHandleOf(CQWWCW);
      ReleaseActiveContest;
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('DL1AAA', 'CQ-WW-CW', '0', '0'), rx),
                'a CQ WW record with serials of 0');
      CheckEquals(0, rx.NumberReceived, 'carries its 0');
      CheckEquals('', ContestLoggedQSORefusal(ContestIdentity(rx.ceContest), rx),
                  'and is not refused');

      (* AND THE ORDER, READ: the refusal is asked before a record joins the
         batch, and the abort comes before the batch's one write. *)
      text := SourceText('MainUnit.pas');
      refuse := Pos('refusal := ContestLoggedQSORefusal(ContestIdentity(TempRXData.ceContest),', text);
      CheckTrue(refuse > 0, 'the import asks the record''s contest');
      CheckTrue(refuse < PosEx('Pending.Add(TempRXData, recordMyFacts, recordSentExchange);', text, refuse),
                'before the record joins the batch');
      CheckTrue(PosEx('if refusedRecord <> '''' then', text, refuse) <
                PosEx('if not LogStoreAppendQSOs(Pending, FailedIndex, Failure) then', text, refuse),
                'and the abort comes before the one write');
   finally
      lines.Free;
      if FileExists(fileName) then
         begin
         DeleteFile(fileName);
         end;
      LogStoreClose;
      for i := Low(SCRATCH_SUFFIXES) to High(SCRATCH_SUFFIXES) do
         begin
         if FileExists(LogDatabaseFileName(scratchLog) + SCRATCH_SUFFIXES[i]) then
            begin
            DeleteFile(LogDatabaseFileName(scratchLog) + SCRATCH_SUFFIXES[i]);
            end;
         end;
      SetCharBuffer(TR4W_LOG_FILENAME, savedLogName);
      tSilentExport := savedSilent;
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestRTCTests.RunAllTests;
begin
   Test_RTCStatesItsBandsModesAndFlags;
   Test_RTCDupesPerBandAndModeMultipliersPerBand;
   Test_RTCRefusesARecordWithSerialZero;
   Test_EditQSOSaveAsksTheRefusalFirst;
   Test_RTCImportWithASerialZeroImportsNothing;
end;

end.
