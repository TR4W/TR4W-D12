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

(* THE AUTOMATIC X-QSO -- Q98 stage S1 (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2v).

  NY4I (Q98): "automatic X-QSO is OK". An off-band or off-mode QSO is
  LOGGED, shown as an X-QSO, exported as X-QSO: (Cabrillo) and
  APP_TR4W_CLAIMEDQSO 0 (ADIF), scores 0, earns no multiplier, is no dupe and
  makes none, is left out of every total -- and the sent serial still
  advances (Q44). Q51: "x-qso never counts as worked".

  DERIVED, NEVER STORED: X-QSO = the operator's flag (ceXQSO) OR the record's
  own contest refusing its band or mode (uContestBase.QSOIsXQSO). So an
  edited band re-classifies the QSO with nothing written, and a corrected
  band list re-classifies an old log at the next load.

  CQ WW SSB IS THE CONTEST HERE, on purpose: it is what NY4I dry-runs first
  (2026-10-22), and it states both halves -- 160-10 m on its family base,
  phone on its class. A CW QSO and a 17 m QSO are the two cases.

  WHAT IS DRIVEN: the predicate; ScoreQSO; the real ADIF writer
  (EmitADIFRecord) and HamScore's one-QSO Cabrillo line; the dupe list
  (TCallsignsList); the bonus view (uScoreTotals.AddLoggedQSO); the summary
  sheet (PostUnit.TallySummaryTotals). WHAT IS READ, NOT DRIVEN: LOGSUBS2's
  LogContact -- no unit test can drive it (uTestContestById says why) -- so
  its ORDER is pinned from the source: the serial outside the guard, every
  sheet inside it. The Cabrillo FILE writer (PostUnit) is the contest
  matrix's and the corpus's; the window is the bench's (BENCH_QUEUE). *)
unit uTestAutomaticXQSO;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TAutomaticXQSOTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheContestsRuleMakesAnXQSO;
      procedure Test_AnXQSOScoresNothing;
      procedure Test_AnEditedBandReclassifiesTheQSO;
      procedure Test_TheRecordsOwnContestDecides;
      procedure Test_ADIFMarksAnAutomaticXQSO;
      procedure Test_HamScoreLineIsAnXQSOLine;
      procedure Test_AnOffModeQSOIsNoDupeAndMakesNone;
      procedure Test_TheBonusViewKeepsNoXQSO;
      procedure Test_TheSummarySheetCountsNoXQSO;
      procedure Test_LogContactCountsNoXQSOButAdvancesTheSerial;
      procedure Test_TheLoaderAndTheRescoreAskThePredicate;
   end;

implementation

uses
   SysUtils,
   Classes,
   StrUtils,
   VC,
   uSettingsModel,
   uCallsigns,
   uContestBase,
   uContestRegistry,
   uADIF,
   uCabrillo,
   uScoreTotals,
   PostUnit,
   uTestContestObjects,
   uTestRegisteredContests;

(* A CQ WW SSB QSO: a US entrant working Europe on 20 m phone -- 3 points.
   The record's own contest is set, as the log's loader sets it. *)
function SSBQSO(aBand: BandType; aMode: ModeType; aExt: ExtendedModeType): ContestExchange;
begin
   FillChar(Result, SizeOf(ContestExchange), 0);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := ContestHandleOf(CQWWSSB);
   Result.Callsign := 'DL1ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExt;
   Result.RSTSent := 59;
   Result.RSTReceived := 59;
   Result.Zone := 14;
   Result.QTH.Continent := Europe;
   Result.QTH.CountryID := 'DL';
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 10;
   Result.tSysTime.qtDay := 25;
   Result.tSysTime.qtHour := 12;
end;

function InBandPhone: ContestExchange;
begin
   Result := SSBQSO(Band20, Phone, eUSB);
end;

function USStation: TStationContext;
begin
   Result := NoStation;
   Result.MyCall := 'K0AAA';
   Result.MyCountry := 'K';
   Result.MyContinent := NorthAmerica;
   Result.MyState := 'KS';
end;

function CQWWSSBRules: TContestBase;
begin
   Result := ContestIdentity(ContestHandleOf(CQWWSSB));
end;

procedure TAutomaticXQSOTests.Test_TheContestsRuleMakesAnXQSO;
var
   qso: ContestExchange;
begin
   BeginTest('Test_TheContestsRuleMakesAnXQSO');

   CheckFalse(QSOIsXQSO(CQWWSSBRules, InBandPhone), '20 m phone is a CQ WW SSB QSO');
   CheckTrue(QSOCountsTowardTotals(CQWWSSBRules, InBandPhone), 'and counts');

   CheckTrue(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band20, CW, eCW)), 'a CW QSO in CQ WW SSB is an X-QSO');
   CheckTrue(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band20, Digital, eRTTY)), 'so is RTTY');
   CheckTrue(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band20, Digital, eFT8)), 'and FT8');
   CheckTrue(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band2, FM, eFM)), 'and 2 m FM');
   CheckTrue(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band17, Phone, eUSB)), '17 m phone (WARC) is an X-QSO');
   CheckTrue(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band6, Phone, eUSB)), '6 m phone is an X-QSO');
   CheckFalse(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band160, Phone, eLSB)), '160 m LSB is a QSO');
   CheckFalse(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band10, Phone, eNoMode)),
              'a phone record with no submode is never proven off-mode');
   CheckFalse(QSOCountsTowardTotals(CQWWSSBRules, SSBQSO(Band20, CW, eCW)), 'an X-QSO counts nowhere');

   (* CQ WW CW and RTTY the other way round. *)
   CheckFalse(QSOIsXQSO(ContestIdentity(ContestHandleOf(CQWWCW)), SSBQSO(Band20, CW, eCW)),
              'a CW QSO is a CQ WW CW QSO');
   CheckTrue(QSOIsXQSO(ContestIdentity(ContestHandleOf(CQWWCW)), InBandPhone),
             'a phone QSO in CQ WW CW is an X-QSO');
   CheckFalse(QSOIsXQSO(ContestIdentity(ContestHandleOf(CQWWRTTY)), SSBQSO(Band40, Digital, eRTTY)),
              '40 m RTTY is a CQ WW RTTY QSO');
   CheckTrue(QSOIsXQSO(ContestIdentity(ContestHandleOf(CQWWRTTY)), SSBQSO(Band40, Digital, eFT8)),
             'FT8 in CQ WW RTTY is an X-QSO');
   CheckTrue(QSOIsXQSO(ContestIdentity(ContestHandleOf(CQWWRTTY)), SSBQSO(Band160, Digital, eRTTY)),
             'CQ WW RTTY has no 160 m');

   (* A RECORD WITH NO BAND OR NO MODE IS MALFORMED, NOT AN X-QSO -- and a
      QTC record is never one. *)
   CheckFalse(QSOIsXQSO(CQWWSSBRules, SSBQSO(NoBand, CW, eCW)), 'no band: not an X-QSO by rule');
   CheckFalse(QSOIsXQSO(CQWWSSBRules, SSBQSO(Band17, NoMode, eNoMode)), 'no mode: not an X-QSO by rule');
   qso := SSBQSO(Band17, CW, eCW);
   qso.ceRecordKind := rkQTCS;
   CheckFalse(QSOIsXQSO(CQWWSSBRules, qso), 'a QTC record is never an X-QSO');

   (* THE OPERATOR'S FLAG ON AN IN-BAND QSO, and "no contest" credits all. *)
   qso := InBandPhone;
   qso.ceXQSO := True;
   CheckTrue(QSOIsXQSO(CQWWSSBRules, qso), 'the operator''s flag makes an in-band QSO an X-QSO');
   CheckFalse(QSOIsXQSO(nil, SSBQSO(Band17, CW, eCW)), 'a classless contest credits every band and mode');
end;

procedure TAutomaticXQSOTests.Test_AnXQSOScoresNothing;
var
   obj: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_AnXQSOScoresNothing');
   obj := NewContestLike(CQWWSSBRules, USStation);
   try
      qso := InBandPhone;
      obj.ScoreQSO(qso);
      CheckEquals(3, qso.QSOPoints, 'the control: 20 m phone with Europe is 3');

      qso := SSBQSO(Band20, CW, eCW);
      obj.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'a CW QSO in CQ WW SSB scores 0');

      qso := SSBQSO(Band17, Phone, eUSB);
      obj.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'a 17 m QSO scores 0');

      (* THE OPERATOR'S FLAG SCORES 0 ON EVERY PATH NOW, not only the
         rescore's X arm. *)
      qso := InBandPhone;
      qso.ceXQSO := True;
      obj.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'a flagged X-QSO scores 0 through ScoreQSO');
   finally
      obj.Free;
      end;
end;

procedure TAutomaticXQSOTests.Test_AnEditedBandReclassifiesTheQSO;
var
   qso: ContestExchange;
begin
   BeginTest('Test_AnEditedBandReclassifiesTheQSO');
   qso := SSBQSO(Band17, Phone, eUSB);
   CheckTrue(LoggedQSOIsXQSO(qso), 'logged on 17 m: an X-QSO');
   qso.Band := Band20;
   CheckFalse(LoggedQSOIsXQSO(qso), 'edited to 20 m: an ordinary QSO, nothing written');
   CheckFalse(qso.ceXQSO, 'and the stored flag was never set');
   qso.Mode := CW;
   qso.ExtMode := eCW;
   CheckTrue(LoggedQSOIsXQSO(qso), 'edited to CW: an X-QSO again');
end;

procedure TAutomaticXQSOTests.Test_TheRecordsOwnContestDecides;
var
   qso: ContestExchange;
begin
   BeginTest('Test_TheRecordsOwnContestDecides');
   qso := SSBQSO(Band20, CW, eCW);
   CheckTrue(LoggedQSOIsXQSO(qso), 'a CQ WW SSB record in CW');
   qso.ceContest := ContestHandleOf(CQWWCW);
   CheckFalse(LoggedQSOIsXQSO(qso), 'the same QSO in a CQ WW CW log');
   qso.ceContest := NoContest;
   CheckFalse(LoggedQSOIsXQSO(qso), 'no contest credits it');
end;

procedure TAutomaticXQSOTests.Test_ADIFMarksAnAutomaticXQSO;
var
   text: string;
begin
   BeginTest('Test_ADIFMarksAnAutomaticXQSO');
   text := EmitADIFRecord(SSBQSO(Band20, CW, eCW));
   CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0,
             'an off-mode QSO is not claimed: ' + text);
   text := EmitADIFRecord(SSBQSO(Band12, Phone, eUSB));
   CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0,
             'an off-band QSO is not claimed: ' + text);
   text := EmitADIFRecord(InBandPhone);
   CheckTrue(Pos('CLAIMEDQSO', text) = 0, 'an in-band phone QSO carries no marker: ' + text);
end;

procedure TAutomaticXQSOTests.Test_HamScoreLineIsAnXQSOLine;
var
   line: string;
begin
   BeginTest('Test_HamScoreLineIsAnXQSOLine');
   line := string(BuildSingleQsoCabrilloLine(SSBQSO(Band20, CW, eCW)));
   CheckTrue(Pos('X-QSO: ', line) = 1, 'an off-mode QSO goes as an X-QSO: line: ' + line);
   line := string(BuildSingleQsoCabrilloLine(InBandPhone));
   CheckTrue(Pos('QSO: ', line) = 1, 'an in-band QSO goes as a QSO: line: ' + line);
end;

procedure TAutomaticXQSOTests.Test_AnOffModeQSOIsNoDupeAndMakesNone;
var
   list: TCallsignsList;
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
   index: integer;
begin
   BeginTest('Test_AnOffModeQSOIsNoDupeAndMakesNone');
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   list := TCallsignsList.Create;
   try
      Contest := ContestHandleOf(CQWWSSB);
      Settings.Qso.ByBand := True;
      (* NOT PER MODE: the case where a CW QSO would otherwise make the
         same station a phone dupe. *)
      Settings.Qso.ByMode := False;

      list.AddCallsign('DL1ABC', CW, Band20, False);
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band20, Phone, index),
                 'a CW QSO in CQ WW SSB makes no later phone QSO a dupe');
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band20, CW, index),
                 'nor is a second CW QSO a dupe');

      list.AddCallsign('DL1ABC', Phone, Band20, False);
      CheckTrue(list.CallsignIsDupe('DL1ABC', Band20, Phone, index),
                'the control: a phone QSO marks the station worked');
      CheckFalse(list.CallsignIsDupe('DL1ABC', Band20, CW, index),
                 'an off-mode QSO is never a dupe, even of an in-mode one');
   finally
      list.Free;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
      end;
end;

procedure TAutomaticXQSOTests.Test_TheBonusViewKeepsNoXQSO;
var
   before: integer;
begin
   BeginTest('Test_TheBonusViewKeepsNoXQSO');
   ResetLoggedQSOs;
   try
      before := LoggedQSOView.Count;
      AddLoggedQSO(SSBQSO(Band20, CW, eCW));
      AddLoggedQSO(SSBQSO(Band17, Phone, eUSB));
      CheckEquals(before, LoggedQSOView.Count, 'no X-QSO reaches the view a bonus reads');
      AddLoggedQSO(InBandPhone);
      CheckEquals(before + 1, LoggedQSOView.Count, 'the control: an in-band QSO does');
   finally
      ResetLoggedQSOs;
      end;
end;

var
   GRecords: array of ContestExchange;
   GNext: integer;

function NextRecord(out aQso: ContestExchange): boolean;
begin
   Result := GNext <= High(GRecords);
   if Result then
      begin
      aQso := GRecords[GNext];
      Inc(GNext);
      end
   else
      begin
      FillChar(aQso, SizeOf(ContestExchange), 0);
      end;
end;

procedure TAutomaticXQSOTests.Test_TheSummarySheetCountsNoXQSO;
var
   savedContest: TContestHandle;
begin
   BeginTest('Test_TheSummarySheetCountsNoXQSO');
   SetLength(GRecords, 3);
   GRecords[0] := InBandPhone;
   GRecords[0].QSOPoints := 3;
   (* Points stored as an old log could hold them: none may reach the sheet. *)
   GRecords[1] := SSBQSO(Band20, CW, eCW);
   GRecords[1].QSOPoints := 3;
   GRecords[2] := SSBQSO(Band17, Phone, eUSB);
   GRecords[2].QSOPoints := 3;

   savedContest := Contest;
   try
      Contest := ContestHandleOf(CQWWSSB);
      GNext := 0;
      TallySummaryTotals(@NextRecord);
   finally
      Contest := savedContest;
      end;

   CheckEquals(1, RawQSOTotals[AllBands, Both], 'the summary counts the phone QSO alone');
   CheckEquals(0, RawQSOTotals[Band20, CW], 'no 20 m CW row');
   CheckEquals(0, RawQSOTotals[Band17, Phone], 'no 17 m row');
   CheckEquals(3, QSOPointTotals[AllBands, Both], 'only the phone QSO''s points');
   SetLength(GRecords, 0);
end;

function SourceText(const aRelative: string): string;
var
   lines: TStringList;
begin
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(ExtractFilePath(ParamStr(0)) +
         '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim + aRelative)));
      Result := lines.Text;
   finally
      lines.Free;
      end;
end;

(* LOGSUBS2.LogContact, READ: the serial advances for every QSO with a band
   and a mode (Q44 -- OUTSIDE the guard), and every sheet, total and view is
   behind QSOCountsTowardTotals, the loader's own test. *)
procedure TAutomaticXQSOTests.Test_LogContactCountsNoXQSOButAdvancesTheSerial;
var
   text: string;
   body: string;
   serial: integer;
   guard: integer;
   p: integer;
   e: integer;
begin
   BeginTest('Test_LogContactCountsNoXQSOButAdvancesTheSerial');
   text := SourceText('trdos' + PathDelim + 'logsubs2.pas');
   (* THE SECOND DECLARATION IS THE BODY; the first is the interface's. *)
   p := Pos('procedure LogContact(var RXData: ContestExchange; MyComputer: boolean);', text);
   p := PosEx('procedure LogContact(var RXData: ContestExchange; MyComputer: boolean);', text, p + 1);
   CheckTrue(p > 0, 'LogContact''s body is found');
   e := PosEx('procedure LogContactToUDP(RXData: ContestExchange);' + sLineBreak, text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);

   serial := Pos('UpdateMaxSerialSent(RXData.Band, RXData.NumberSent)', body);
   guard := Pos('if QSOCountsTowardTotals(contestRules, RXData) then', body);
   CheckTrue(serial > 0, 'LogContact advances the serial');
   CheckTrue(guard > 0, 'LogContact asks QSOCountsTowardTotals');
   CheckTrue(serial < guard, 'the serial is advanced BEFORE, outside, the guard');
   CheckTrue(Pos('end;', Copy(body, serial, guard - serial)) > 0,
             'and its block is closed before the guard');
   CheckTrue(guard < Pos('inc(QSOTotals[RXData.Band, TempMode]);', body), 'the totals are behind the guard');
   CheckTrue(guard < Pos('Sheet.SetMultFlags(RXData);', body), 'the multipliers are behind the guard');
   CheckTrue(guard < Pos('Sheet.AddQSOToSheets(@RXData, True);', body), 'the sheets are behind the guard');
   CheckTrue(guard < Pos('AddLoggedQSO(RXData', body), 'the bonus view is behind the guard');
   CheckTrue(guard < Pos('AddQSOToDupeSheets(RXData, False);', body), 'the dupe sheet is behind the guard');
   CheckTrue(guard < Pos('inc(ContinentQSOCount[', body), 'the continent count is behind the guard');
   (* THE INITIAL-EXCHANGE HISTORY IS WHAT THE STATION SENT, NOT CREDIT: an
      automatic X-QSO still feeds it (the contest matrix's initialexchange
      section, which S1 must not move). *)
   p := Pos('CallsignsList.AddIniitialExchange(RXData.Callsign', body);
   CheckTrue((p > serial) and (p < guard),
             'the initial-exchange history is fed beside the serial, outside the guard');
end;

(* THE LOADER (MainUnit.LoadinLog) AND THE RESCORE'S X ARM (tUpdateLog), READ:
   each asks the predicate of the record's own contest. *)
procedure TAutomaticXQSOTests.Test_TheLoaderAndTheRescoreAskThePredicate;
var
   text: string;
begin
   BeginTest('Test_TheLoaderAndTheRescoreAskThePredicate');
   text := SourceText('MainUnit.pas');
   CheckTrue(Pos('if QSOCountsTowardTotals(ContestIdentity(TempRXData.ceContest), TempRXData) then', text) > 0,
             'the loader asks QSOCountsTowardTotals of the record''s contest');
   CheckTrue(Pos('if LoggedQSOIsXQSO(RescoredRXData) then', text) > 0,
             'the rescore''s X arm asks LoggedQSOIsXQSO');
   CheckTrue(Pos('if RescoredRXData.ceXQSO then', text) = 0,
             'and no longer the stored flag alone');
   CheckTrue(Pos('if QSOCountsTowardTotals(nil, TempRXData) and', text) > 0,
             'the loader feeds the initial-exchange history by the contest-blind test');
end;

procedure TAutomaticXQSOTests.RunAllTests;
begin
   Test_TheContestsRuleMakesAnXQSO;
   Test_AnXQSOScoresNothing;
   Test_AnEditedBandReclassifiesTheQSO;
   Test_TheRecordsOwnContestDecides;
   Test_ADIFMarksAnAutomaticXQSO;
   Test_HamScoreLineIsAnXQSOLine;
   Test_AnOffModeQSOIsNoDupeAndMakesNone;
   Test_TheBonusViewKeepsNoXQSO;
   Test_TheSummarySheetCountsNoXQSO;
   Test_LogContactCountsNoXQSOButAdvancesTheSerial;
   Test_TheLoaderAndTheRescoreAskThePredicate;
end;

end.
