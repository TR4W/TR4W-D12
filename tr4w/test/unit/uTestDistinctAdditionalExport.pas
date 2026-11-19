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

(* A CONTEST'S SECOND EXPORT FILE -- issue 272 (NY4I, 2026-11-19).

  A contest class states which QSOs go to an ADIF file of their own
  (TContestBase.DistinctAdditionalExportFormat / Modes / FileTag). Only the
  Vermont QSO Party does: its FT QSOs are sent as an ADIF and are NOT in the
  Cabrillo. The base says none, so no other contest's export may change; the
  first test walks every registered contest to pin that. The last test runs
  the real exports over a small Vermont log. *)
unit uTestDistinctAdditionalExport;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TDistinctAdditionalExportTests = class(TTestCase)
   private
      FDir: string;
      FTrw: string;
      FSavedLogName: string;
      FSavedLogPath: string;
      FSavedSilent: boolean;
      procedure StartEmptyStore;
      procedure StopStore;
   protected
      procedure Test_OnlyVermontStatesASecondFile;
      procedure Test_VermontSendsTheWSJTXModes;
      procedure Test_PickingKeepsTheParallelArraysTogether;
      procedure Test_VermontExportsASecondADIFAndTheCabrilloLeavesItOut;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   Classes, SysUtils, StrUtils, VC, utils_text, uSettingsModel, uCTYDAT,
   uContestBase, uContestRegistry, uContestFactory, uQsoMyFacts, uADIF,
   uLogDatabase, uLogStore, uLogSource, LogStuff, PostUnit, MainUnit,
   uCbrSum, uCabrilloHeader;

const
   VERMONT_ID = 'VT-QSO-PARTY';

var
   GSavedContest: TContestHandle;

function VermontHandle: TContestHandle;
begin
   if not FindContestById(VERMONT_ID, Result) then
      begin
      raise Exception.Create(VERMONT_ID + ' is not registered');
      end;
end;

function Qso(const aCall: string; aMode: ModeType; aExt: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := CallString(aCall);
   Result.Mode := aMode;
   Result.ExtMode := aExt;
   Result.Band := Band20;
end;

function ReadWhole(const aFileName: string): string;
var
   lines: TStringList;
begin
   Result := '';
   if not FileExists(aFileName) then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(aFileName);
      Result := lines.Text;
   finally
      lines.Free;
   end;
end;

function CountOf(const aNeedle, aText: string): integer;
var
   p: integer;
begin
   Result := 0;
   p := PosEx(aNeedle, aText, 1);
   while p > 0 do
      begin
      Inc(Result);
      p := PosEx(aNeedle, aText, p + Length(aNeedle));
      end;
end;

procedure TDistinctAdditionalExportTests.StartEmptyStore;
begin
   LogStoreClose;
   FDir := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w_distinct_' +
           IntToStr(GetProcessID) + PathDelim;
   ForceDirectories(FDir);
   FTrw := FDir + 'vt_distinct.trw';
   DeleteFile(LogDatabaseFileName(FTrw));
   DeleteFile(LogDatabaseFileName(FTrw) + '-wal');
   DeleteFile(LogDatabaseFileName(FTrw) + '-shm');
   FSavedLogName := CharBufferText(TR4W_LOG_FILENAME);
   FSavedLogPath := CharBufferText(TR4W_LOG_PATH_NAME);
   FSavedSilent := tSilentExport;
   GSavedContest := Contest;
   SetCharBuffer(TR4W_LOG_FILENAME, FTrw);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FDir);
   (* No dialog, no preview, no prompt: a headless export. *)
   tSilentExport := True;
end;

procedure TDistinctAdditionalExportTests.StopStore;
var
   found: TSearchRec;
begin
   LogStoreClose;
   SetCharBuffer(TR4W_LOG_FILENAME, FSavedLogName);
   SetCharBuffer(TR4W_LOG_PATH_NAME, FSavedLogPath);
   tSilentExport := FSavedSilent;
   Contest := GSavedContest;
   ReleaseActiveContest;
   (* Only the files this suite made: its own folder, emptied. *)
   if (FDir <> '') and (FindFirst(FDir + '*', faAnyFile, found) = 0) then
      begin
      repeat
         if (found.Attr and faDirectory) = 0 then
            begin
            DeleteFile(FDir + found.Name);
            end;
      until FindNext(found) <> 0;
      FindClose(found);
      RemoveDir(FDir);
      end;
end;

(* THE BASE SAYS NONE, AND SO DOES EVERY CONTEST BUT VERMONT. *)
procedure TDistinctAdditionalExportTests.Test_OnlyVermontStatesASecondFile;
var
   handles: TContestHandleList;
   i: integer;
   rules: TContestBase;
   ft8: ContestExchange;
   vermont: integer;
begin
   BeginTest('Test_OnlyVermontStatesASecondFile');
   ft8 := Qso('W1AW', Digital, eFT8);
   handles := KnownContests;
   CheckTrue(Length(handles) > 100, 'the walk sees the registered contests');
   vermont := 0;
   for i := 0 to High(handles) do
      begin
      rules := ContestIdentity(handles[i]);
      if ContestId(handles[i]) = VERMONT_ID then
         begin
         Inc(vermont);
         CheckTrue(rules.DistinctAdditionalExportFormat = defADIF, 'Vermont: an ADIF');
         end
      else
         begin
         CheckTrue(rules.DistinctAdditionalExportFormat = defNone,
                   ContestId(handles[i]) + ' states no second file');
         CheckTrue(rules.DistinctAdditionalExportModes = [],
                   ContestId(handles[i]) + ' names no mode for one');
         CheckEquals('', rules.DistinctAdditionalExportFileTag,
                     ContestId(handles[i]) + ' has no file tag');
         CheckFalse(rules.GoesToDistinctAdditionalExport(ft8),
                    ContestId(handles[i]) + ' keeps an FT8 QSO in its one file');
         end;
      end;
   CheckEquals(1, vermont, 'Vermont is registered once');
end;

procedure TDistinctAdditionalExportTests.Test_VermontSendsTheWSJTXModes;
var
   rules: TContestBase;
   m: ExtendedModeType;
   phoneFT8: ContestExchange;
begin
   BeginTest('Test_VermontSendsTheWSJTXModes');
   rules := ContestIdentity(VermontHandle);
   CheckTrue(rules.DistinctAdditionalExportFormat = defADIF, 'format');
   CheckEquals('ft', rules.DistinctAdditionalExportFileTag, 'tag');
   CheckTrue(rules.DistinctAdditionalExportModes = [eFT8, eFT4, eJT65, eFST4, eFST4W],
             'the WSJT-X modes Vermont already scores as such');
   for m := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckTrue((m in [eFT8, eFT4, eJT65, eFST4, eFST4W]) =
                rules.GoesToDistinctAdditionalExport(Qso('W1AW', Digital, m)),
                ExtendedModeStringArray[m] + ' as a digital QSO');
      end;
   CheckFalse(rules.GoesToDistinctAdditionalExport(Qso('W1AW', Digital, eRTTY)),
              'RTTY stays in the Cabrillo (NY4I)');
   (* OPEN QUESTION FOR NY4I (issue 120/272): JTTY is not in the WSJT-X set
     the class already had (IsWSJTXQSO), so it stays in the Cabrillo. This
     pins what the class does today, not a ruling. *)
   CheckFalse(rules.GoesToDistinctAdditionalExport(Qso('W1AW', Digital, eJTTY)),
              'JTTY is not in the class''s WSJT-X set today (open question)');
   CheckFalse(rules.GoesToDistinctAdditionalExport(Qso('W1AW', CW, eCW)), 'CW');
   (* The mode, not the extended mode alone. *)
   phoneFT8 := Qso('W1AW', Phone, eFT8);
   CheckFalse(rules.GoesToDistinctAdditionalExport(phoneFT8), 'a phone QSO');
end;

(* THREE PARALLEL ARRAYS, PICKED TOGETHER. *)
procedure TDistinctAdditionalExportTests.Test_PickingKeepsTheParallelArraysTogether;
var
   records, pickedRecords: TContestExchangeArray;
   facts, pickedFacts: TQsoMyFactsArray;
   sent, pickedSent: TSentExchangeArray;
   notRecorded: integer;
   rules: TContestBase;
begin
   BeginTest('Test_PickingKeepsTheParallelArraysTogether');
   SetLength(records, 4);
   SetLength(facts, 4);
   SetLength(sent, 4);
   records[0] := Qso('AA1CW', CW, eCW);
   records[1] := Qso('BB1FT', Digital, eFT8);
   records[2] := Qso('CC1RY', Digital, eRTTY);
   records[3] := Qso('DD1FT', Digital, eFT4);
   facts[0] := NotCapturedMyFacts;
   facts[1] := NotCapturedMyFacts;
   facts[2] := NotCapturedMyFacts;
   facts[3] := NotCapturedMyFacts;
   facts[3].Call := 'K0AAA';
   facts[3].Source := mfsLogged;
   sent[0] := 'zero';
   sent[1] := 'one';
   sent[2] := 'two';
   sent[3] := 'three';

   rules := ContestIdentity(VermontHandle);
   PickDistinctExportRecords(rules, records, facts, sent,
                             pickedRecords, pickedFacts, pickedSent, notRecorded);
   CheckEquals(2, Length(pickedRecords), 'the two FT QSOs');
   CheckEquals(2, Length(pickedFacts), 'their facts');
   CheckEquals(2, Length(pickedSent), 'their sent exchanges');
   CheckEquals('BB1FT', string(pickedRecords[0].Callsign), 'first, in log order');
   CheckEquals('one', string(pickedSent[0]), 'with its own sent exchange');
   CheckEquals('DD1FT', string(pickedRecords[1].Callsign), 'second');
   CheckEquals('three', string(pickedSent[1]), 'with its own sent exchange');
   CheckEquals('K0AAA', string(pickedFacts[1].Call), 'and its own station');
   CheckEquals(1, notRecorded, 'one picked row recorded no station');

   (* A contest with no second file picks nothing. *)
   PickDistinctExportRecords(ContestIdentity(ContestHandleOf(CQWWSSB)), records,
                             facts, sent, pickedRecords, pickedFacts,
                             pickedSent, notRecorded);
   CheckEquals(0, Length(pickedRecords), 'CQ WW SSB: none');
   CheckEquals(0, Length(pickedSent), 'and no sent exchanges');
end;

(* THE REAL EXPORTS, OVER A SMALL VERMONT LOG: CW, RTTY, FT8, FT4. *)
procedure TDistinctAdditionalExportTests.Test_VermontExportsASecondADIFAndTheCabrilloLeavesItOut;
var
   rx: ContestExchange;
   adif, second, cabrillo: string;
   n: integer;
   savedLocation: string;

   procedure Log(const aCall: string; aMode: ModeType; aExt: ExtendedModeType);
   begin
      Inc(n);
      rx := Qso(aCall, aMode, aExt);
      rx.id := 'distinct' + IntToStr(n);
      rx.ceContest := Contest;
      rx.ceQSOID1 := 7000 + n;
      rx.ceQSOID2 := 8000 + n;
      rx.tSysTime.qtYear := 27;
      rx.tSysTime.qtMonth := 2;
      rx.tSysTime.qtDay := 6;
      rx.tSysTime.qtHour := 12;
      rx.tSysTime.qtMinute := n;
      rx.Frequency := 14074000;
      rx.RSTSent := 59;
      rx.RSTReceived := 59;
      rx.NumberSent := n;
      rx.NumberReceived := n;
      rx.QTHString := 'CT';
      rx.DomesticQTH := 'CT';
      rx.DomMultQTH := 'CT';
      CheckTrue(LogStoreAppendQSO(rx), aCall + ' is logged');
   end;

begin
   BeginTest('Test_VermontExportsASecondADIFAndTheCabrilloLeavesItOut');
   StartEmptyStore;
   try
      Contest := VermontHandle;
      ActiveContest(Contest);
      n := 0;
      Log('AA1CW', CW, eCW);
      Log('BB1FT', Digital, eFT8);
      Log('CC1RY', Digital, eRTTY);
      Log('DD1FT', Digital, eFT4);

      PostUnit.ExportToADIF;
      adif := ReadWhole(FDir + 'vt_distinct.adi');
      second := ReadWhole(FDir + 'vt_distinct-ft.adi');
      CheckEquals(4, CountOf('<CALL:', adif), 'the first ADIF holds every QSO');
      CheckEquals(2, CountOf('<CALL:', second), 'the second holds the FT QSOs');
      CheckTrue(Pos('>BB1FT ', second) > 0, 'FT8 is in it');
      CheckTrue(Pos('>DD1FT ', second) > 0, 'FT4 is in it');
      CheckEquals(0, CountOf('>AA1CW ', second), 'CW is not');
      CheckEquals(0, CountOf('>CC1RY ', second), 'RTTY is not');
      CheckTrue(Pos('<ADIF_VER:', second) > 0, 'it is a whole ADIF: a header');
      CheckEquals(1, CountOf('Created by TR4W', second), 'with its own banner');

      (* VERMONT'S CABRILLO NEEDS A LOCATION (RequiresCabrilloLocation): without
        one the export stops at a warning. The header store is the settings
        file beside the test program; the value is put back. *)
      savedLocation := HeaderValue(CABRILLOSECTION, CabrilloTagsArray[ctLocation].ctrTag);
      SetHeaderValue(CABRILLOSECTION, CabrilloTagsArray[ctLocation].ctrTag, 'NY');
      try
         PostUnit.CreateCabrilloFile;
      finally
         SetHeaderValue(CABRILLOSECTION, CabrilloTagsArray[ctLocation].ctrTag, savedLocation);
      end;
      cabrillo := ReadWhole(FDir + 'vt_distinct.log');
      CheckTrue(cabrillo <> '', 'the Cabrillo is written');
      CheckTrue(Pos(' AA1CW ', cabrillo) > 0, 'the Cabrillo holds CW');
      CheckTrue(Pos(' CC1RY ', cabrillo) > 0, 'and RTTY');
      CheckEquals(0, CountOf(' BB1FT ', cabrillo), 'and not the FT8 QSO');
      CheckEquals(0, CountOf(' DD1FT ', cabrillo), 'nor the FT4 QSO');
      CheckEquals(2, CountOf('QSO: ', cabrillo), 'two QSO lines');
   finally
      StopStore;
   end;
end;

procedure TDistinctAdditionalExportTests.RunAllTests;
begin
   Test_OnlyVermontStatesASecondFile;
   Test_VermontSendsTheWSJTXModes;
   Test_PickingKeepsTheParallelArraysTogether;
   Test_VermontExportsASecondADIFAndTheCabrilloLeavesItOut;
end;

end.
