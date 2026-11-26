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

  STORED SINCE LOG SCHEMA 10 (NY4I, 2026-11-19): X-QSO = the operator's flag
  (ceXQSO, is_xqso) OR the record's own contest refusing it, as that answer
  was STAMPED on the record (ceOffContest, is_off_contest) by
  uContestRegistry.StampOffContest where the QSO was logged, rescored,
  imported or saved from Edit QSO. A READER asks StoredQSOIsXQSO and works no
  rule out: a rule changed after logging moves no export until the next
  rescore re-stamps, and the operator's flag is never written by the rule.
  It was derived each time it was asked until then -- NY4I: "Otherwise we
  have business rules being derived at cabrillo generation."

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
      procedure Test_ASharedSerialAdvancesTheNextByOne;
      procedure Test_TheMultiCountyDrainKeepsOneSerial;
      (* 2026-11-18: a QSO the log would not take keeps the entry and the
         status line's reason (read from the source). *)
      procedure Test_ARefusedSaveKeepsTheEntryAndItsReason;
      (* Issue 347 (2026-11-22): a QSO logged here is published only after
         the log has committed it (read from the source). *)
      procedure Test_AQSOIsPublishedOnlyAfterItsCommit;
      (* Issue 348 (plan commit 5): an entry of several legs is ONE write,
         the windows are cleared only after it, and a refusal rebuilds the
         score from the log (read from the source). *)
      procedure Test_AnEntryOfSeveralLegsIsOneWrite;
      (* Issue 347 (plan commits 6 and 7): a peer's QSO the log refuses is
         refused and reported, and a note or QTC record is sent only after its
         commit (read from the source). *)
      procedure Test_APeersRefusedQSOIsReportedNotAssumedSaved;
      procedure Test_ANoteOrQTCRecordIsSentOnlyAfterItsCommit;
      (* Issue 349 (2026-11-22): Edit QSO's save and Alt-Y announce a change
         only after the log has committed it (read from the source). *)
      procedure Test_AChangeIsAnnouncedOnlyAfterItsCommit;
      (* 2026-11-18: ARRL Sweepstakes CW and Phone each credit only their own
         mode (sponsor rule 2.4); NY4I saw CW QSOs scored in SS Phone. *)
      procedure Test_SweepstakesCreditsOnlyItsOwnMode;
      (* LOG SCHEMA 10 (2026-11-19): the readers read the STORED rule, a
         rescore re-stamps it, and the operator's flag stands on its own. *)
      procedure Test_TheExportsReadTheStoredRuleNotTheContest;
      procedure Test_TheOperatorsFlagStandsWhenTheRuleReleases;
      procedure Test_EverySettingPointStampsTheRule;
   end;

(* A SOURCE FILE UNDER tr4w/src, as text -- for a test that pins the ORDER of
   calls in a routine no headless test can drive. Exported 2026-10-23 for
   uTestContestRTC (the Edit QSO and import refusals). *)
function SourceText(const aRelative: string): string;

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
   uTestRegisteredContests,
   (* MaxSerialSent -- the high-water mark; ServerSerialNumber -- 0 off a net. *)
   LogDupe,
   uNet,
   (* NextSerialToSend, UpdateMaxSerialSent. *)
   LogEdit,
   (* ActiveBand -- the band a by-band serial is read for. *)
   LogWind;

(* A CQ WW SSB QSO: a US entrant working Europe on 20 m phone -- 3 points.
   The record's own contest is set, as the log's loader sets it. *)
function SSBQSO(aBand: BandType; aMode: ModeType; aExt: ExtendedModeType): ContestExchange;
begin
   Result.Clear;
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

(* aQso AS THE LOG HOLDS IT: its contest's rule stamped on it, as every
   append, the rescore and Edit QSO's save stamp it (log schema 10). What the
   readers below are handed. *)
function AsLogged(const aQso: ContestExchange): ContestExchange;
begin
   Result := aQso;
   StampOffContest(Result);
end;

(* THE CONTEST THAT JUDGES A LOGGED RECORD, CHANGEABLE BY A TEST -- the
   registered provider swapped for one that answers GFlipJudge, so a test can
   change a contest's rule under a QSO already logged. *)
var
   GFlipJudge: TContestBase = nil;

function FlipJudgeProvider(aContest: TContestHandle): TContestBase;
begin
   Result := GFlipJudge;
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

(* AN ARRL SWEEPSTAKES QSO: a US entrant working Connecticut on 20 m, in the
   running given -- 2 points in its own mode. *)
function SSQSO(aContest: ContestType; aMode: ModeType; aExt: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.ceContest := ContestHandleOf(aContest);
   Result.Callsign := 'W1AW';
   Result.Band := Band20;
   Result.Mode := aMode;
   Result.ExtMode := aExt;
   Result.QTH.Continent := NorthAmerica;
   Result.QTH.CountryID := 'K';
   Result.tSysTime.qtYear := 26;
   Result.tSysTime.qtMonth := 11;
   Result.tSysTime.qtDay := 21;
   Result.tSysTime.qtHour := 22;
end;

(* ARRL SWEEPSTAKES: "Use only CW during the CW weekend and Phone during the
   Phone weekend" (rule 2.4, docs/ContestRules/ARRL/ARRL-SS-Rules.txt). Phone
   is SSB/USB/LSB/AM; FM is not credited until NY4I rules (the rules do not
   define Phone). Every ModeType through UsesMode for both runnings, then the
   off-mode QSO through QSOIsXQSO and ScoreQSO, with an on-mode control. *)
procedure TAutomaticXQSOTests.Test_SweepstakesCreditsOnlyItsOwnMode;
var
   cwRules: TContestBase;
   ssbRules: TContestBase;
   mode: ModeType;
   obj: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_SweepstakesCreditsOnlyItsOwnMode');
   cwRules := ContestIdentity(ContestHandleOf(ARRLSSCW));
   ssbRules := ContestIdentity(ContestHandleOf(ARRLSSSSB));

   for mode := Low(ModeType) to High(ModeType) do
      begin
      CheckTrue(cwRules.UsesMode(mode, eNoMode) = (mode = CW),
                'SS CW credits CW only (mode ' + IntToStr(Ord(mode)) + ')');
      CheckTrue(ssbRules.UsesMode(mode, eNoMode) = (mode = Phone),
                'SS Phone credits Phone only (mode ' + IntToStr(Ord(mode)) + ')');
      end;

   (* EVERY PHONE SUBMODE IS PHONE; FM IS ITS OWN ModeType AND IS NOT. *)
   CheckTrue(ssbRules.UsesMode(Phone, eUSB), 'USB is phone');
   CheckTrue(ssbRules.UsesMode(Phone, eLSB), 'LSB is phone');
   CheckTrue(ssbRules.UsesMode(Phone, eSSB), 'SSB is phone');
   CheckTrue(ssbRules.UsesMode(Phone, eAM), 'AM is phone');
   CheckFalse(ssbRules.UsesMode(FM, eFM), 'FM is not credited in SS Phone');
   CheckTrue(cwRules.UsesMode(CW, eCW), 'CW in SS CW');
   CheckFalse(cwRules.UsesMode(Digital, eRTTY), 'RTTY is not CW');

   (* THE AUTOMATIC X-QSO, both ways round. *)
   CheckTrue(QSOIsXQSO(ssbRules, SSQSO(ARRLSSSSB, CW, eCW)), 'a CW QSO in SS Phone is an X-QSO');
   CheckTrue(QSOIsXQSO(ssbRules, SSQSO(ARRLSSSSB, CW, eNoMode)),
             'so is a CW record with no submode (the corpus''s N0TST shape)');
   CheckTrue(QSOIsXQSO(ssbRules, SSQSO(ARRLSSSSB, FM, eFM)), 'and FM');
   CheckTrue(QSOIsXQSO(ssbRules, SSQSO(ARRLSSSSB, Digital, eFT8)), 'and FT8');
   CheckFalse(QSOIsXQSO(ssbRules, SSQSO(ARRLSSSSB, Phone, eUSB)), 'USB is an SS Phone QSO');
   CheckFalse(QSOIsXQSO(ssbRules, SSQSO(ARRLSSSSB, Phone, eNoMode)),
              'a phone record with no submode is never proven off-mode');
   CheckTrue(QSOIsXQSO(cwRules, SSQSO(ARRLSSCW, Phone, eUSB)), 'a phone QSO in SS CW is an X-QSO');
   CheckTrue(QSOIsXQSO(cwRules, SSQSO(ARRLSSCW, Digital, eRTTY)), 'and RTTY');
   CheckFalse(QSOIsXQSO(cwRules, SSQSO(ARRLSSCW, CW, eCW)), 'CW is an SS CW QSO');
   CheckFalse(QSOIsXQSO(cwRules, SSQSO(ARRLSSCW, NoMode, eNoMode)), 'no mode: not an X-QSO by rule');

   (* SCORING: 2 in its own mode, 0 off it. *)
   obj := NewContestLike(ssbRules, USStation);
   try
      qso := SSQSO(ARRLSSSSB, Phone, eUSB);
      obj.ScoreQSO(qso);
      CheckEquals(2, qso.QSOPoints, 'the control: an SS Phone QSO on USB is 2');
      qso := SSQSO(ARRLSSSSB, CW, eNoMode);
      obj.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'a CW QSO in SS Phone scores 0');
   finally
      obj.Free;
      end;
   obj := NewContestLike(cwRules, USStation);
   try
      qso := SSQSO(ARRLSSCW, CW, eCW);
      obj.ScoreQSO(qso);
      CheckEquals(2, qso.QSOPoints, 'the control: an SS CW QSO is 2');
      qso := SSQSO(ARRLSSCW, Phone, eLSB);
      obj.ScoreQSO(qso);
      CheckEquals(0, qso.QSOPoints, 'a phone QSO in SS CW scores 0');
   finally
      obj.Free;
      end;
end;

procedure TAutomaticXQSOTests.Test_AnEditedBandReclassifiesTheQSO;
var
   qso: ContestExchange;
begin
   BeginTest('Test_AnEditedBandReclassifiesTheQSO');
   (* LOGGED ON 17 m: the rule is stamped, and that is the stored answer. *)
   qso := AsLogged(SSBQSO(Band17, Phone, eUSB));
   CheckTrue(qso.ceOffContest, 'logged on 17 m: the contest''s rule refuses it, stamped');
   CheckTrue(StoredQSOIsXQSO(qso), 'so it is an X-QSO');
   CheckTrue(LoggedQSOIsXQSO(qso), 'which is what the rule says now, too');

   (* EDITED TO 20 m BUT NOT YET SAVED: the record still carries what was
     stamped; the judge, asked now, would credit it. *)
   qso.Band := Band20;
   CheckFalse(LoggedQSOIsXQSO(qso), 'on 20 m the rule credits it');
   CheckTrue(StoredQSOIsXQSO(qso), 'but a reader reads the stamp until the save');

   (* SAVED -- Edit QSO's save stamps again: an ordinary QSO, and the
     operator's flag was never written. *)
   StampOffContest(qso);
   CheckFalse(StoredQSOIsXQSO(qso), 'saved on 20 m: an ordinary QSO');
   CheckFalse(qso.ceXQSO, 'and the operator''s flag was never set');

   qso.Mode := CW;
   qso.ExtMode := eCW;
   StampOffContest(qso);
   CheckTrue(StoredQSOIsXQSO(qso), 'edited to CW and saved: an X-QSO again');
   CheckFalse(qso.ceXQSO, 'still by the rule alone');
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
   text := EmitADIFRecord(AsLogged(SSBQSO(Band20, CW, eCW)));
   CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0,
             'an off-mode QSO is not claimed: ' + text);
   text := EmitADIFRecord(AsLogged(SSBQSO(Band12, Phone, eUSB)));
   CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0,
             'an off-band QSO is not claimed: ' + text);
   text := EmitADIFRecord(AsLogged(InBandPhone));
   CheckTrue(Pos('CLAIMEDQSO', text) = 0, 'an in-band phone QSO carries no marker: ' + text);
   (* THE WRITER READS THE STAMP AND WORKS NO RULE OUT: the same off-mode
     record that was never stamped -- no setting point has seen it -- is
     written as an ordinary QSO. *)
   text := EmitADIFRecord(SSBQSO(Band20, CW, eCW));
   CheckTrue(Pos('CLAIMEDQSO', text) = 0,
             'an off-mode record no setting point has stamped carries no marker: ' + text);
end;

procedure TAutomaticXQSOTests.Test_HamScoreLineIsAnXQSOLine;
var
   line: string;
begin
   BeginTest('Test_HamScoreLineIsAnXQSOLine');
   line := string(BuildSingleQsoCabrilloLine(AsLogged(SSBQSO(Band20, CW, eCW))));
   CheckTrue(Pos('X-QSO: ', line) = 1, 'an off-mode QSO goes as an X-QSO: line: ' + line);
   line := string(BuildSingleQsoCabrilloLine(AsLogged(InBandPhone)));
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
      AddLoggedQSO(AsLogged(SSBQSO(Band20, CW, eCW)));
      AddLoggedQSO(AsLogged(SSBQSO(Band17, Phone, eUSB)));
      CheckEquals(before, LoggedQSOView.Count, 'no X-QSO reaches the view a bonus reads');
      AddLoggedQSO(AsLogged(InBandPhone));
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
      aQso.Clear;
      end;
end;

procedure TAutomaticXQSOTests.Test_TheSummarySheetCountsNoXQSO;
var
   savedContest: TContestHandle;
begin
   BeginTest('Test_TheSummarySheetCountsNoXQSO');
   SetLength(GRecords, 3);
   (* AS THE LOG HOLDS THEM: each stamped with its contest's rule. *)
   GRecords[0] := AsLogged(InBandPhone);
   GRecords[0].QSOPoints := 3;
   (* Points stored as an old log could hold them: none may reach the sheet. *)
   GRecords[1] := AsLogged(SSBQSO(Band20, CW, eCW));
   GRecords[1].QSOPoints := 3;
   GRecords[2] := AsLogged(SSBQSO(Band17, Phone, eUSB));
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

const
   (* THE TWO DECLARATIONS THE SOURCE READS FIND THEIR BODIES BY. LogContact
      became a function on 2026-11-18 (a refused save answers False). The
      county-line drain (DrainPendingMultiQSORefs, one LogContact per leg)
      became the leg builder of ONE submission at issue 348 (plan commit 5):
      it builds each further leg and logs none. *)
   LOG_CONTACT_DECLARATION =
      'function LogContact(var RXData: ContestExchange; MyComputer: boolean): boolean;';
   DRAIN_DECLARATION =
      'procedure TEntryLegs.BuildLeg(aLeg: integer; var aLegs: array of ContestExchange);';

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
   p := Pos(LOG_CONTACT_DECLARATION, text);
   p := PosEx(LOG_CONTACT_DECLARATION, text, p + 1);
   CheckTrue(p > 0, 'LogContact''s body is found');
   e := PosEx('procedure LogContactToUDP(RXData: ContestExchange);' + sLineBreak, text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);

   (* ISSUE 347 (plan commit 4): LogContact's step after the write is split.
      LiveQSOScore holds what the loader rebuilds (totals, sheets, dupe
      sheets), behind the guard; LiveQSORelease feeds the serial and the
      initial-exchange history OUTSIDE its own guard, and the bonus view
      behind it. Each routine is read on its own. *)
   p := Pos('procedure LiveQSOScore(var RXData: ContestExchange; aLeg: TLiveQSOLeg);', body);
   e := Pos('procedure LiveQSORelease(var RXData: ContestExchange; aLeg: TLiveQSOLeg;', body);
   CheckTrue((p > 0) and (e > p), 'LogContact''s Score step is found');
   text := Copy(body, p, e - p);
   guard := Pos('if QSOCountsTowardTotals(contestRules, RXData) then', text);
   CheckTrue(guard > 0, 'Score asks QSOCountsTowardTotals');
   CheckTrue(guard < Pos('inc(QSOTotals[RXData.Band, TempMode]);', text), 'the totals are behind the guard');
   CheckTrue(guard < Pos('Sheet.SetMultFlags(RXData);', text), 'the multipliers are behind the guard');
   CheckTrue(guard < Pos('Sheet.AddQSOToSheets(@RXData, True);', text), 'the sheets are behind the guard');
   CheckTrue(guard < Pos('AddQSOToDupeSheets(RXData, False);', text), 'the dupe sheet is behind the guard');
   CheckTrue(guard < Pos('inc(ContinentQSOCount[', text), 'the continent count is behind the guard');
   CheckEquals(0, Pos('UpdateMaxSerialSent(', text), 'the serial is not Score''s');

   p := e;
   e := PosEx('procedure TLiveQSOLeg.FreeMessage;', body, p);
   CheckTrue(e > p, 'LogContact''s Release step is found');
   text := Copy(body, p, e - p);
   serial := Pos('UpdateMaxSerialSent(RXData.Band, RXData.NumberSent)', text);
   guard := Pos('counted := QSOCountsTowardTotals(contestRules, RXData);', text);
   CheckTrue(serial > 0, 'LogContact advances the serial');
   CheckTrue(guard > 0, 'Release asks QSOCountsTowardTotals');
   CheckTrue(serial < guard, 'the serial is advanced BEFORE, outside, the guard');
   CheckTrue(Pos('end;', Copy(text, serial, guard - serial)) > 0,
             'and its block is closed before the guard');
   CheckTrue(guard < Pos('AddLoggedQSO(RXData', text), 'the bonus view is behind the guard');
   CheckTrue(PosEx('if counted then', text, guard) < Pos('AddLoggedQSO(RXData', text),
             'behind the guard''s answer');
   (* THE INITIAL-EXCHANGE HISTORY IS WHAT THE STATION SENT, NOT CREDIT: an
      automatic X-QSO still feeds it (the contest matrix's initialexchange
      section, which S1 must not move). *)
   p := Pos('CallsignsList.AddIniitialExchange(RXData.Callsign', text);
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
   (* LOG SCHEMA 10: the loader READS the stamped rule; the rescore stamps it
      again first and then decides its X arm by the stored answer. *)
   CheckTrue(Pos('if StoredQSOCountsTowardTotals(TempRXData) then', text) > 0,
             'the loader counts a record by its stored answer');
   CheckTrue(Pos('if QSOCountsTowardTotals(LoggedQSOContest(TempRXData.ceContest), TempRXData) then', text) = 0,
             'and no longer works the rule out at load');
   CheckTrue(Pos('StampOffContest(RescoredRXData);', text) > 0,
             'the rescore re-stamps the rule');
   CheckTrue(Pos('if StoredQSOIsXQSO(RescoredRXData) then', text) > 0,
             'and its X arm reads the stored answer');
   CheckTrue(Pos('StampOffContest(RescoredRXData);', text) <
             Pos('if StoredQSOIsXQSO(RescoredRXData) then', text),
             'stamped BEFORE the X arm reads it');
   CheckTrue(Pos('if RescoredRXData.ceXQSO then', text) = 0,
             'and no longer the operator''s flag alone');
   CheckTrue(Pos('if QSOCountsTowardTotals(nil, TempRXData) then', text) > 0,
             'the loader feeds the initial-exchange history by the contest-blind test');
   (* ISSUE 267: on EVERY load, not only start-up's -- D7's latch is gone. *)
   CheckTrue((Pos('not IntitialExLoaded', text) = 0) and
             (Pos('IntitialExLoaded :=', text) = 0),
             'and on every load: no latch keeps a reload from feeding it');
end;

(* ISSUE 28 -- A MULTI-COUNTY ENTRY LOGS ONE QSO PER COUNTY, ALL WITH THE SAME
   SENT SERIAL; the next number to send must be one past that serial, not one
   past the QSO count. DRIVEN: UpdateMaxSerialSent and NextSerialToSend
   directly, as LogContact calls them (LogContact itself cannot be driven
   headless -- see the header). *)
procedure TAutomaticXQSOTests.Test_ASharedSerialAdvancesTheNextByOne;
var
   savedMax: array[BandType] of integer;
   savedServer: integer;
   savedByBand: boolean;
   savedBand: BandType;
   b: BandType;
begin
   BeginTest('Test_ASharedSerialAdvancesTheNextByOne');
   savedBand := ActiveBand;
   for b := Low(BandType) to High(BandType) do
      begin
      savedMax[b] := MaxSerialSent[b];
      end;
   savedServer := ServerSerialNumber;
   savedByBand := Settings.Contest.QsoNumberByBand;
   try
      for b := Low(BandType) to High(BandType) do
         begin
         MaxSerialSent[b] := 0;
         end;
      ServerSerialNumber := 0;
      Settings.Contest.QsoNumberByBand := False;

      CheckEquals(1, NextSerialToSend, 'an empty log starts at 1');

      (* Serial 1 logged twice: two county legs of one exchange. *)
      UpdateMaxSerialSent(Band20, 1);
      UpdateMaxSerialSent(Band20, 1);
      CheckEquals(2, NextSerialToSend, 'two legs on serial 1: next is 2, not 3');

      UpdateMaxSerialSent(Band20, 2);
      UpdateMaxSerialSent(Band20, 2);
      UpdateMaxSerialSent(Band20, 2);
      CheckEquals(3, NextSerialToSend, 'three legs on serial 2: next is 3');

      (* A single-county entry after them: one record, one number. *)
      UpdateMaxSerialSent(Band20, 3);
      CheckEquals(4, NextSerialToSend, 'a single entry on serial 3: next is 4');

      (* QSO NUMBER BY BAND: two legs on 40 m serial 1 move only 40 m's
         number, and only by one; 20 m keeps its own. *)
      Settings.Contest.QsoNumberByBand := True;
      UpdateMaxSerialSent(Band40, 1);
      UpdateMaxSerialSent(Band40, 1);
      ActiveBand := Band40;
      CheckEquals(2, NextSerialToSend, 'by band: two legs on 40 m serial 1, next on 40 m is 2');
      ActiveBand := Band20;
      CheckEquals(4, NextSerialToSend, 'by band: 20 m is untouched by the 40 m legs');
   finally
      for b := Low(BandType) to High(BandType) do
         begin
         MaxSerialSent[b] := savedMax[b];
         end;
      ServerSerialNumber := savedServer;
      Settings.Contest.QsoNumberByBand := savedByBand;
      ActiveBand := savedBand;
   end;
end;

(* ISSUE 28, THE PATH AROUND THE HIGH-WATER MARK, READ (neither routine can be
   driven headless): the multi-county drain copies the first leg's record and
   never assigns NumberSent, so every leg carries one serial; and the rescore
   the GUI runs ends in LoadinLog, which empties the mark
   (DisposeOfMemoryAndZeroTotals) and rebuilds it from every stored serial, so
   an edit, a delete or a rescore never restarts the count. *)
procedure TAutomaticXQSOTests.Test_TheMultiCountyDrainKeepsOneSerial;
var
   text: string;
   body: string;
   p: integer;
   e: integer;
begin
   BeginTest('Test_TheMultiCountyDrainKeepsOneSerial');
   text := SourceText('MainUnit.pas');

   p := Pos(DRAIN_DECLARATION, text);
   CheckTrue(p > 0, 'the leg builder (was DrainPendingMultiQSORefs) is found');
   e := PosEx('function LocateCallStrippingRoverCounty(', text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);
   (* ISSUE 348: each leg is a copy of the leg before it as the submission
      holds it (prepared and scored) -- the drain's chained TempRX, which
      started from ReceivedData after leg 0 was logged. *)
   CheckTrue(Pos('TempRX := aLegs[aLeg - 1];', body) > 0,
             'every leg is a copy of the leg before it, from the first leg''s record');
   CheckTrue(Pos('NumberSent :=', body) = 0,
             'and the drain assigns no serial of its own');

   p := Pos('procedure RescoreLog;' + sLineBreak + 'begin', text);
   CheckTrue(p > 0, 'RescoreLog''s body is found');
   e := PosEx('end;', text, p);
   body := Copy(text, p, e - p);
   CheckTrue(Pos('tUpdateLog(actRescore);', body) > 0, 'RescoreLog rescores');
   CheckTrue(Pos('tUpdateLog(actRescore);', body) < Pos('LoadinLog;', body),
             'and then reloads, which rebuilds the serial mark');

   p := PosEx('UpdateMaxSerialSent(TempRXData.Band, TempRXData.NumberSent);',
              text, Pos('procedure LoadinLog;' + sLineBreak + 'label', text));
   CheckTrue(p > 0, 'the loader feeds every stored serial to the mark');
end;

(* A QSO THE LOG WOULD NOT TAKE LEAVES THE ENTRY AS TYPED, AND ITS REASON
   STANDS -- NY4I, 2026-11-18, on a full D: drive. LogContact was a procedure:
   a refused save went on to clear the call and exchange windows (the typed
   QSO lost) and to ClearQuickDisplayText (the "not saved" line wiped, so
   Enter seemed to do nothing). The Enter path cannot be driven headless, so
   this READS it, and fails if any of that comes back. *)
procedure TAutomaticXQSOTests.Test_ARefusedSaveKeepsTheEntryAndItsReason;
var
   text, body, refusal: string;
   p, e, r, x, q, t, next: integer;
begin
   BeginTest('Test_ARefusedSaveKeepsTheEntryAndItsReason');

   (* LOGSUBS2: a log that cannot take an own QSO is refused BEFORE the QSO
      is posted anywhere, and the answer is True only once it is in the log. *)
   text := SourceText('trdos' + PathDelim + 'logsubs2.pas');
   p := Pos(LOG_CONTACT_DECLARATION, text);
   p := PosEx(LOG_CONTACT_DECLARATION, text, p + 1);
   CheckTrue(p > 0, 'LogContact''s body is found');
   e := PosEx('procedure LogContactToUDP(RXData: ContestExchange);' + sLineBreak, text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);
   r := Pos('LogStoreNotSavedText', body);
   CheckTrue(r > 0, 'LogContact refuses an unsaveable QSO with the store''s text');
   (* ISSUE 347 (plan commit 4): the message is BUILT (BuildLoggedQso) in
      Prepare and posted (QsoDispatcher.Post) in Release; PostLoggedQso is
      gone. The refusal still comes before all of it. *)
   CheckTrue(r < Pos('BuildLoggedQso(', body), 'before the QSO''s UDP / logger message is built');
   CheckTrue(r < Pos('QsoDispatcher.Post(', body), 'or posted');
   CheckTrue(r < Pos('SendRecordToServer(', body), 'and before it is sent to the server');
   (* A FULL DISK FREED SINCE: the store is tried again right there, before
      the post too -- so a probe that fails posts nothing (2026-11-18). *)
   x := Pos('LogStoreTryRecoverWrites', body);
   CheckTrue(x > 0, 'LogContact tries the log again before refusing');
   CheckTrue(x < Pos('TLiveQSOSubmission.Create', body), 'before the QSO is prepared');
   CheckTrue(x < Pos('QsoDispatcher.Post(', body), 'before the QSO is posted');
   CheckTrue(x < Pos('SendRecordToServer(', body), 'and before it is sent to the server');
   (* LogContact's own answer is the submission's, which is True only when
      the write committed (TSubmitSequence; uTestSubmitSequence). *)
   x := Pos('Result := submission.Submit;', body);
   CheckTrue(x > 0, 'LogContact answers with the submission');
   CheckTrue(Pos('Result := True;', Copy(body, 1, Pos('procedure LiveQSOPrepare(', body))) = 0,
             'and never answers True itself');
   x := Pos('Result := tAddQSOsToLog(FQsos, FFacts);', body);
   CheckTrue(x > 0, 'the submission''s write is the log''s append');

   (* MAINUNIT.TryLogContact: on False, out -- before anything that clears a
      window, the exchange or the status line. *)
   text := SourceText('MainUnit.pas');
   p := Pos('function TryLogContact: boolean;' + sLineBreak + 'var', text);
   CheckTrue(p > 0, 'TryLogContact''s body is found');
   e := PosEx('procedure ResetRadioPorts;', text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);
   (* ISSUE 348: the whole entry -- every leg -- is ONE LogEntry, and its
      answer is acted on. *)
   CheckTrue(Pos('saved := LogEntry(ReceivedData, True, entryLegs.ExtraLegCount,', body) > 0,
             'TryLogContact logs the entry with all its legs at once');
   r := Pos('if not saved then', body);
   CheckTrue(r > 0, 'TryLogContact acts on the entry''s answer');
   CheckEquals(0, Pos('      LogContact(ReceivedData, True);', body),
               'and never ignores it');
   x := PosEx('Exit;', body, r);
   CheckTrue(x > r, 'a refused save leaves at once');
   refusal := Copy(body, r, x - r);
   CheckTrue(Pos('QSOSaveRefused := True;', refusal) > 0, 'saying so to the Enter paths');
   CheckTrue(Pos('ClearPendingParks;', refusal) > 0, 'emptying the park queue');
   CheckTrue(Pos('ClearPendingCounties;', refusal) > 0, 'and the county queue');
   CheckEquals(0, Pos('QuickDisplay', refusal), 'and NOT touching the status line');
   CheckEquals(0, Pos('ClearQuickDisplayText', refusal), 'nor clearing it');
   CheckEquals(0, Pos('CleanUpDisplay', refusal), 'nor cleaning up the display');
   CheckEquals(0, Pos('UpdateWindows', refusal), 'nor updating the windows');
   CheckTrue(x < Pos('ClearQuickDisplayText;', body), 'the status line is cleared only after a save');
   CheckTrue(x < Pos('ClearContestExchange(ReceivedData);', body), 'and the exchange');
   (* The call is passed a reason now ('QSO logged'), so the pin names the
      routine and its opening parenthesis. *)
   CheckTrue(x < Pos('tCleareCallWindow(', body), 'and the call window');
   CheckTrue(x < Pos('tCleareExchangeWindow;', body), 'and the exchange window');
   CheckTrue(x < Pos('CleanUpDisplay;', body), 'and the display');
   CheckTrue(x < Pos('UpdateWindows;', body), 'and the windows');
   CheckTrue(x < Pos('SendSerialNumberChange(', body), 'and the serial');
   CheckTrue(Pos('LogStoreShowRecoveryNotice;', body) > Pos('ClearQuickDisplayText;', body),
             '"writable again" is said AFTER the status line is cleared, not wiped by it');

   (* THE CQ ENTER PATH: TryLogContact, then at once the flag, then out --
      before its own clearing of the windows. *)
   q := Pos('if QSOSaveRefused then', text);
   CheckTrue(q > 0, 'the CQ Enter path asks the flag');
   t := 0;
   next := Pos('TryLogContact;', text);
   while (next > 0) and (next < q) do
      begin
      t := next;
      next := PosEx('TryLogContact;', text, next + 1);
      end;
   CheckTrue(t > 0, 'after a TryLogContact');
   CheckEquals('', Trim(Copy(text, t + Length('TryLogContact;'),
                             q - t - Length('TryLogContact;'))),
               'directly after it');
   CheckTrue(PosEx('Exit;', text, q) < PosEx('tCleareCallWindow(', text, q),
             'and leaves before clearing the call window');

   (* THE S&P ENTER PATH: out before the several-QTH loop re-enters. *)
   q := PosEx('if QSOSaveRefused then', text, q + 1);
   CheckTrue(q > 0, 'the S&P Enter path asks the flag');
   CheckTrue(PosEx('Exit;', text, q) < PosEx('goto loop;', text, q),
             'and leaves before the several-QTH loop');
end;

(* ISSUE 347 (plan commit 4, 2026-11-22): A QSO LOGGED HERE IS PUBLISHED ONLY
   AFTER THE LOG HAS COMMITTED IT. LogContact sent the multi-op packet and
   posted the UDP / external-logger / HamScore message BEFORE the append, so
   a QSO the log refused had already left the station. It cannot be driven
   headless, so this READS it: Prepare builds and never posts, the write is
   asked and its answer acted on, Release posts, a refusal frees what was
   built, and the backup and restart file come last. The ORDER the steps run
   in is TSubmitSequence's, pinned by uTestSubmitSequence. *)
procedure TAutomaticXQSOTests.Test_AQSOIsPublishedOnlyAfterItsCommit;
var
   text, body, part: string;
   p, e, w: integer;

   function Span(const aFrom, aTo: string): string;
   var
      a, b: integer;
   begin
      Result := '';
      a := Pos(aFrom, text);
      if a = 0 then
         begin
         Exit;
         end;
      b := PosEx(aTo, text, a + Length(aFrom));
      if b = 0 then
         begin
         Exit;
         end;
      Result := Copy(text, a, b - a);
   end;

begin
   BeginTest('Test_AQSOIsPublishedOnlyAfterItsCommit');
   text := SourceText('trdos' + PathDelim + 'logsubs2.pas');

   (* LOGCONTACT ITSELF: the refusal of an unwritable log, then one
      submission; it posts nothing of its own. *)
   p := Pos(LOG_CONTACT_DECLARATION, text);
   p := PosEx(LOG_CONTACT_DECLARATION, text, p + 1);
   e := PosEx('procedure LiveQSOPrepare(', text, p);
   CheckTrue((p > 0) and (e > p), 'LogContact''s own body is found');
   body := Copy(text, p, e - p);
   CheckTrue(Pos('LogStoreTryRecoverWrites', body) < Pos('TLiveQSOSubmission.Create', body),
             'an unwritable log is refused before anything is prepared');
   CheckTrue(Pos('RXData := submission.Qso(0);', body) > 0,
             'the record goes back to the caller as the steps left it');
   CheckEquals(0, Pos('SendRecordToServer(', body), 'LogContact sends no packet itself');
   CheckEquals(0, Pos('QsoDispatcher.Post(', body), 'nor posts a message');

   (* PREPARE BUILDS, NEVER POSTS. *)
   part := Span('procedure LiveQSOPrepare(', 'procedure LiveQSOScore(');
   CheckTrue(part <> '', 'Prepare is found');
   CheckTrue(Pos('aLeg.Packet := RXData;', part) > 0, 'Prepare copies the packet''s record');
   CheckTrue(Pos('aLeg.Message := BuildLoggedQso(', part) > 0, 'and builds the message');
   CheckTrue(Pos('SecondDomesticKeyForUDP(', part) > 0,
             'asking the second domestic key before Score puts the QSO on the sheets');
   CheckEquals(0, Pos('SendRecordToServer(', part), 'Prepare sends no packet');
   CheckEquals(0, Pos('QsoDispatcher.Post(', part), 'nor posts a message');
   CheckEquals(0, Pos('PostQsoEvent(', part), 'nor posts an event');
   CheckEquals(0, Pos('LogStoreAppend', part), 'nor writes the log');
   CheckEquals(0, Pos('Sheet.AddQSOToSheets(', part), 'nor scores');

   (* THE WRITE: asked, and its answer is the submission's. *)
   part := Span('function TLiveQSOSubmission.WriteLegs(', 'procedure TLiveQSOSubmission.ReleaseLeg(');
   CheckTrue(Pos('Result := tAddQSOsToLog(FQsos, FFacts);', part) > 0,
             'the write is the log''s append, and its answer is returned');
   part := Span('function tAddQSOsToLog(const aQsos: array of ContestExchange;' + sLineBreak +
                '                       out aFacts: TLiveQsoFacts): boolean;' + sLineBreak + 'var',
                'TR4WEditableLogRefreshCount;');
   w := Pos('if not LogStoreAppendLiveQSOs(aQsos, aFacts, rowIds) then', part);
   CheckTrue(w > 0, 'the append is the live, all-or-none store call');
   CheckTrue((PosEx('Exit;', part, w) > w) and
             (PosEx('Exit;', part, w) < Pos('inc(tRestartInfo.riTotalRecordsInLog', part)),
             'and a refusal leaves before anything counts or shows the record');

   (* RELEASE POSTS -- the packet, then the message -- and lets go first. *)
   part := Span('procedure LiveQSORelease(', 'procedure TLiveQSOLeg.FreeMessage;');
   CheckTrue(part <> '', 'Release is found');
   w := Pos('SendRecordToServer(NET_WIRE_QSO_ID, aLeg.Packet)', part);
   CheckTrue(w > 0, 'Release sends the packet Prepare copied');
   CheckTrue(w < Pos('QsoDispatcher.Post(msg);', part), 'then posts the message');
   CheckTrue(Pos('aLeg.Message := nil;', part) < Pos('QsoDispatcher.Post(msg);', part),
             'having let go of it first (the dispatcher owns it)');
   CheckTrue(Pos('QsoDispatcher.Post(msg);', part) < Pos('CountQsoTowardPeriodicBackup;', part),
             'and the periodic backup comes after the posts');
   CheckTrue(Pos('QsoDispatcher.Post(msg);', part) < Pos('Sheet.SaveRestartFile;', part),
             'as does the restart file');
   CheckTrue(Pos('SendScoreToUDP;', part) < Pos('CountQsoTowardPeriodicBackup;', part),
             'LAST, after the score message');

   (* A REFUSAL FREES WHAT WAS BUILT AND POSTS NOTHING. *)
   part := Span('procedure TLiveQSOSubmission.DiscardLeg(', 'procedure TLiveQSOSubmission.RebuildAfterRefusal;');
   CheckTrue(Pos('FreeMessage;', part) > 0, 'Discard frees the message');
   CheckEquals(0, Pos('SendRecordToServer(', part), 'and sends nothing');
   CheckEquals(0, Pos('QsoDispatcher.Post(', part), 'and posts nothing');
   part := Span('destructor TLiveQSOLeg.Destroy;', 'constructor TLiveQSOSubmission.Create;');
   CheckTrue(Pos('FreeMessage;', part) > 0, 'a leg frees a message it still holds');
   part := Span('constructor TLiveQSOSubmission.Create;', 'destructor TLiveQSOSubmission.Destroy;');
   CheckTrue(Pos('FSequence.OnWrite := WriteLegs;', part) > 0, 'the sequence drives the write');
   CheckTrue(Pos('FSequence.OnDiscard := DiscardLeg;', part) > 0, 'and the discard');
   CheckTrue(Pos('FSequence.OnRelease := ReleaseLeg;', part) > 0, 'and the release');
end;

(* ISSUE 348 (plan commit 5, 2026-11-22): A COUNTY LINE, SEVERAL PARKS OR A
   ROVER'S BOUNDARY IS ONE ENTRY, WRITTEN IN ONE TRANSACTION. Every leg was
   its own LogContact -- its own commit and its own publication -- so a later
   leg the log refused left the earlier legs logged and sent, and the retyped
   entry logged them again under a new exchange id. None of it can be driven
   headless, so this READS it: TryLogContact makes one LogEntry of every leg
   and clears nothing before its answer; the leg builder logs nothing; the
   submission builds each leg just before preparing it; a refusal of several
   legs rebuilds the score from the log; and the store's failure notice is
   held until that rebuild. The ORDER is TSubmitSequence's (uTestSubmitSequence). *)
procedure TAutomaticXQSOTests.Test_AnEntryOfSeveralLegsIsOneWrite;
var
   text, body, part: string;
   p, e, w: integer;

   function Span(const aFrom, aTo: string): string;
   var
      a, b: integer;
   begin
      Result := '';
      a := Pos(aFrom, text);
      if a = 0 then
         begin
         Exit;
         end;
      b := PosEx(aTo, text, a + Length(aFrom));
      if b = 0 then
         begin
         Exit;
         end;
      Result := Copy(text, a, b - a);
   end;

begin
   BeginTest('Test_AnEntryOfSeveralLegsIsOneWrite');

   (* MAINUNIT.TryLogContact: ONE call for the whole entry, before anything
      that clears the windows; no LogContact of its own; no drain. *)
   text := SourceText('MainUnit.pas');
   CheckEquals(0, Pos('function DrainPendingMultiQSORefs', text),
               'the per-leg drain is gone');
   p := Pos('function TryLogContact: boolean;' + sLineBreak + 'var', text);
   e := PosEx('procedure ResetRadioPorts;', text, p);
   CheckTrue((p > 0) and (e > p), 'TryLogContact''s body is found');
   body := Copy(text, p, e - p);
   w := Pos('saved := LogEntry(ReceivedData, True, entryLegs.ExtraLegCount,', body);
   CheckTrue(w > 0, 'the entry is ONE LogEntry, with every further leg');
   CheckEquals(0, PosEx('LogEntry(', body, w + Length('saved := LogEntry(')), 'and only one');
   CheckEquals(0, Pos('LogContact(', body), 'TryLogContact logs no leg on its own');
   CheckTrue(Pos('entryLegs := TEntryLegs.Create;', body) < w,
             'the queued legs are taken before the entry is logged');
   CheckTrue(w < Pos('if not saved then', body), 'the answer is asked after the one write');
   CheckTrue(Pos('if not saved then', body) < Pos('tCleareCallWindow(', body),
             'and the call window is cleared only after it');
   CheckTrue(Pos('if not saved then', body) < Pos('tCleareExchangeWindow;', body),
             'as is the exchange window');
   CheckTrue(Pos('if not saved then', body) < Pos('ClearContestExchange(ReceivedData);', body),
             'and the exchange');

   (* THE LEG BUILDER BUILDS AND NEVER LOGS. *)
   part := Span(DRAIN_DECLARATION, 'function LocateCallStrippingRoverCounty(');
   CheckTrue(part <> '', 'the leg builder is found');
   CheckEquals(0, Pos('LogContact(', part), 'it logs no leg');
   CheckEquals(0, Pos('LogEntry(', part), 'nor an entry');
   CheckTrue(Pos('TempRX.ceClearDupeSheet := True;', part) > 0,
             'a county leg is still no dupe of the first');
   CheckTrue(Pos('CalculateQSOPoints(TempRX);', part) > 0,
             'and a rover copy still works out its own points');

   (* LOGSUBS2: the leg is built just before it is prepared; several legs hold
      the store's notice around the submission; the rebuild is the loader. *)
   text := SourceText('trdos' + PathDelim + 'logsubs2.pas');
   part := Span('function TLiveQSOSubmission.PrepareLeg(', 'procedure TLiveQSOSubmission.ScoreLeg(');
   CheckTrue(part <> '', 'PrepareLeg is found');
   w := Pos('FBuildLeg(aLeg, FQsos);', part);
   CheckTrue(w > 0, 'a further leg is built in PrepareLeg');
   CheckTrue(w < Pos('LiveQSOPrepare(FQsos[aLeg], FLegs[aLeg]);', part),
             'just before it is prepared');

   part := Span('function LogEntry(var RXData: ContestExchange; MyComputer: boolean;' + sLineBreak +
                '                  aExtraLegs: integer; aBuildLeg: TLiveQSOBuildLeg): boolean;' + sLineBreak +
                'var',
                'procedure LiveQSOPrepare(');
   CheckTrue(part <> '', 'LogEntry''s body is found');
   w := Pos('Result := submission.Submit;', part);
   CheckTrue(w > 0, 'one submission');
   CheckTrue(Pos('LogStoreTryRecoverWrites', part) < Pos('TLiveQSOSubmission.Create', part),
             'an unwritable log is refused before anything is prepared');
   CheckTrue((Pos('LogStoreHoldFailureNotices;', part) > 0) and
             (Pos('LogStoreHoldFailureNotices;', part) < w),
             'several legs hold the store''s notice before the submission');
   CheckTrue(PosEx('LogStoreShowHeldFailureNotices;', part, w) > w,
             'and show it after (so after the rebuild)');
   CheckTrue(Pos('holdNotices := aExtraLegs > 0;', part) > 0,
             'only for several legs: one leg''s notice comes where it always did');

   part := Span('procedure TLiveQSOSubmission.RebuildAfterRefusal;', 'function SearchAndPounce: boolean;');
   CheckTrue(part <> '', 'the rebuild is found');
   CheckTrue(Pos('LoadinLog;', part) > 0, 'the rebuild is the log''s reload');
   CheckEquals(0, Pos('raise ', part), 'and it is wired: no longer a loud stub');

   (* LOGCONTACT IS THE ONE-LEG CASE OF THE SAME PATH. *)
   part := Span('function LogContact(var RXData: ContestExchange; MyComputer: boolean): boolean;' + sLineBreak + '{',
                'function LogEntry(');
   CheckTrue(Pos('Result := LogEntry(RXData, MyComputer, 0, nil);', part) > 0,
             'LogContact is LogEntry with no further leg');
end;

(* ISSUE 349 (2026-11-22): AN EDIT, A DELETE OR A RESTORE IS ANNOUNCED ONLY
   AFTER THE LOG HAS COMMITTED IT. Edit QSO's save and Alt-Y posted to the
   external loggers, UDP and HamScore, and sent the change to the multi-op
   server, BEFORE the store's write -- which answered nothing -- and Alt-Y
   flipped its delete state first too. Neither can be driven headless, so this
   READS them: the write is asked first, its answer is acted on, and a False
   leaves before anything is said to anyone. uTestLogStore pins the store's
   answer itself. *)
procedure TAutomaticXQSOTests.Test_AChangeIsAnnouncedOnlyAfterItsCommit;
var
   text, body: string;
   p, e, w, x: integer;
begin
   BeginTest('Test_AChangeIsAnnouncedOnlyAfterItsCommit');

   (* UEDITQSO.SaveQSOToEditableLog. *)
   text := SourceText('uEditQSO.pas');
   p := Pos('function SaveQSOToEditableLog: boolean;' + sLineBreak + 'label', text);
   CheckTrue(p > 0, 'SaveQSOToEditableLog is found');
   e := PosEx('function CheckSystemTimeRecord(', text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);
   w := Pos('saved := LogStoreUpdateQSOAtIndex(IndexInMap, EditableQSORXData', body);
   CheckTrue(w > 0, 'the edit''s write is asked, and its answer kept');
   x := PosEx('if not saved then', body, w);
   CheckTrue(x > w, 'the answer is acted on');
   CheckTrue(PosEx('Result := False;', body, x) < PosEx('Exit;', body, x),
             'a refused write answers False, so the window stays open');
   CheckTrue(Pos('LogStoreChangeNotSavedText', body) > x, 'and says why');
   CheckTrue(x < Pos('PostQsoEvent(', body), 'before any UDP, logger or HamScore notice');
   CheckTrue(x < Pos('SendRecordToServer(', body), 'and before the server is told');
   CheckTrue(x < Pos('RescoreLog;', body), 'and before the rescore');

   (* LOGSUBS2.DeleteLastContact (Alt-Y). *)
   text := SourceText('trdos' + PathDelim + 'logsubs2.pas');
   p := Pos('procedure DeleteLastContact;' + sLineBreak + 'var', text);
   CheckTrue(p > 0, 'DeleteLastContact is found');
   e := PosEx('function WaitForPollingThreadFlag(', text, p);
   CheckTrue(e > p, 'and its end');
   body := Copy(text, p, e - p);
   w := Pos('if not LogStoreUpdateNewestQSO(TempRXData) then', body);
   CheckTrue(w > 0, 'Alt-Y asks the write and acts on its answer');
   CheckTrue(Pos('LogStoreChangeNotSavedText', body) > w, 'a refusal says why');
   CheckTrue(w < Pos('InvertBoolean(tLastLogEntryIsDeleted);', body),
             'the delete state flips only after the commit');
   CheckTrue(w < Pos('PostQsoEvent(', body), 'and the notices go only after it');
   CheckTrue(w < Pos('SendRecordToServer(', body), 'and the server is told only after it');
   CheckTrue(w < Pos('ShowMessage(p);', body), 'and so is the operator');
end;

(* LOG SCHEMA 10 -- THE READERS READ THE STORED RULE (NY4I, 2026-11-19).

  A CW QSO is logged under CQ WW SSB's rule: stamped off-contest, and every
  reader -- the ADIF writer, HamScore's Cabrillo line, the totals -- says
  X-QSO. Then the contest's rule CHANGES under it (the provider that judges a
  logged record now answers CQ WW CW's rule, which credits CW). The judge,
  asked now, credits the QSO; the readers do NOT move, because they work no
  rule out. Only the rescore's stamp moves them -- and then they all follow. *)
procedure TAutomaticXQSOTests.Test_TheExportsReadTheStoredRuleNotTheContest;
var
   saved: TLoggedQSOContestProvider;
   qso: ContestExchange;
   text: string;
   line: string;
begin
   BeginTest('Test_TheExportsReadTheStoredRuleNotTheContest');
   saved := RegisteredLoggedQSOContestProvider;
   try
      RegisterLoggedQSOContestProvider(@FlipJudgeProvider);

      (* LOGGED UNDER CQ WW SSB'S RULE. *)
      GFlipJudge := CQWWSSBRules;
      qso := SSBQSO(Band20, CW, eCW);
      StampOffContest(qso);
      CheckTrue(qso.ceOffContest, 'logged: the rule refuses a CW QSO, stamped');
      CheckFalse(qso.ceXQSO, 'the operator''s flag is untouched');
      CheckTrue(StoredQSOIsXQSO(qso), 'an X-QSO as stored');
      text := EmitADIFRecord(qso);
      CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0, 'the ADIF says not claimed: ' + text);
      line := string(BuildSingleQsoCabrilloLine(qso));
      CheckTrue(Pos('X-QSO: ', line) = 1, 'the Cabrillo line is X-QSO: ' + line);
      CheckFalse(StoredQSOCountsTowardTotals(qso), 'and it counts toward no total');

      (* THE CONTEST'S RULE CHANGES UNDER THE LOGGED QSO. *)
      GFlipJudge := ContestIdentity(ContestHandleOf(CQWWCW));
      CheckFalse(LoggedQSOIsXQSO(qso), 'the judge, asked now, credits the CW QSO');
      CheckTrue(StoredQSOIsXQSO(qso), 'the stored answer stands until a rescore');
      text := EmitADIFRecord(qso);
      CheckTrue(Pos('<APP_TR4W_CLAIMEDQSO:1>0', text) > 0,
                'the ADIF writer reads the stamp, not the rule: ' + text);
      line := string(BuildSingleQsoCabrilloLine(qso));
      CheckTrue(Pos('X-QSO: ', line) = 1,
                'the Cabrillo line reads the stamp, not the rule: ' + line);
      CheckFalse(StoredQSOCountsTowardTotals(qso), 'nor do the totals move');

      (* THE RESCORE STAMPS AGAIN: now every reader follows the new rule. *)
      StampOffContest(qso);
      CheckFalse(qso.ceOffContest, 'rescored: the new rule credits it');
      CheckFalse(StoredQSOIsXQSO(qso), 'an ordinary QSO');
      text := EmitADIFRecord(qso);
      CheckTrue(Pos('CLAIMEDQSO', text) = 0, 'the ADIF carries no marker now: ' + text);
      line := string(BuildSingleQsoCabrilloLine(qso));
      CheckTrue(Pos('QSO: ', line) = 1, 'the Cabrillo line is QSO: now: ' + line);
      CheckTrue(StoredQSOCountsTowardTotals(qso), 'and it counts');
   finally
      RegisterLoggedQSOContestProvider(saved);
      GFlipJudge := nil;
   end;
end;

(* THE OPERATOR'S FLAG IS HIS AND STAYS HIS. A QSO he marked X-QSO stays one
  when the contest's rule releases it, and a rule that refuses a QSO never
  writes his flag -- which is what lets a changed rule release a QSO at all. *)
procedure TAutomaticXQSOTests.Test_TheOperatorsFlagStandsWhenTheRuleReleases;
var
   saved: TLoggedQSOContestProvider;
   qso: ContestExchange;
   line: string;
begin
   BeginTest('Test_TheOperatorsFlagStandsWhenTheRuleReleases');
   saved := RegisteredLoggedQSOContestProvider;
   try
      RegisterLoggedQSOContestProvider(@FlipJudgeProvider);

      (* OFF-MODE BY THE RULE, AND FLAGGED BY THE OPERATOR TOO. *)
      GFlipJudge := CQWWSSBRules;
      qso := SSBQSO(Band20, CW, eCW);
      qso.ceXQSO := True;
      StampOffContest(qso);
      CheckTrue(qso.ceOffContest, 'the rule refuses it');
      CheckTrue(StoredQSOIsXQSO(qso), 'an X-QSO');

      (* THE RULE RELEASES IT AND THE RESCORE STAMPS THAT: still an X-QSO,
         because the operator said so. *)
      GFlipJudge := ContestIdentity(ContestHandleOf(CQWWCW));
      StampOffContest(qso);
      CheckFalse(qso.ceOffContest, 'the rule no longer refuses it');
      CheckTrue(qso.ceXQSO, 'the operator''s flag is untouched by the stamp');
      CheckTrue(StoredQSOIsXQSO(qso), 'so it is still an X-QSO');
      line := string(BuildSingleQsoCabrilloLine(qso));
      CheckTrue(Pos('X-QSO: ', line) = 1, 'and exports as one: ' + line);
      CheckFalse(StoredQSOCountsTowardTotals(qso), 'and counts toward no total');

      (* AND A QSO ONLY THE RULE REFUSED: released, it never gained a flag. *)
      GFlipJudge := CQWWSSBRules;
      qso := AsLogged(SSBQSO(Band20, CW, eCW));
      CheckFalse(qso.ceXQSO, 'the rule''s X-QSO writes no operator flag');
      GFlipJudge := ContestIdentity(ContestHandleOf(CQWWCW));
      StampOffContest(qso);
      CheckFalse(StoredQSOIsXQSO(qso), 'so the changed rule releases it');
   finally
      RegisterLoggedQSOContestProvider(saved);
      GFlipJudge := nil;
   end;
end;

(* EVERY PLACE THAT SETS THE STORED RULE STAMPS IT BEFORE ANYTHING READS THE
  RECORD -- read from the source, because LogContact, Edit QSO's save and the
  store's open cannot be driven whole headless (see the header). The lint
  (Lint-XQSOReads) fences the other direction: no other unit works the rule
  out. *)
procedure TAutomaticXQSOTests.Test_EverySettingPointStampsTheRule;
var
   text: string;
   body: string;
   p: integer;
   e: integer;
   s: integer;
begin
   BeginTest('Test_EverySettingPointStampsTheRule');

   (* LOGSUBS2.LogContact: before the multipliers, the network packet and the
      UDP / external logger / HamScore post. *)
   text := SourceText('trdos' + PathDelim + 'logsubs2.pas');
   p := Pos(LOG_CONTACT_DECLARATION, text);
   p := PosEx(LOG_CONTACT_DECLARATION, text, p + 1);
   e := PosEx('procedure LogContactToUDP(RXData: ContestExchange);' + sLineBreak, text, p);
   CheckTrue((p > 0) and (e > p), 'LogContact''s body is found');
   body := Copy(text, p, e - p);
   s := Pos('StampOffContest(RXData);', body);
   CheckTrue(s > 0, 'LogContact stamps the rule');
   CheckTrue(s < Pos('VisibleLog.ProcessMultipliers(RXData);', body), 'before the multipliers');
   (* Issue 347: the packet is copied (aLeg.Packet) and the message built
      (BuildLoggedQso) in Prepare; both are posted after the append. *)
   CheckTrue(s < Pos('aLeg.Packet := RXData;', body), 'before the network packet is taken');
   CheckTrue(s < Pos('SendRecordToServer(', body), 'before the network packet');
   CheckTrue(s < Pos('BuildLoggedQso(', body), 'before the UDP, logger and HamScore message');
   CheckTrue(s < Pos('Result := tAddQSOsToLog(FQsos, FFacts);', body), 'and before the append');

   (* uEditQSO: the save stamps before it posts, sends or writes -- and the
      operator's flag is read back only when the box was his to tick. *)
   text := SourceText('uEditQSO.pas');
   s := Pos('StampOffContest(EditableQSORXData);', text);
   CheckTrue(s > 0, 'Edit QSO''s save stamps the rule');
   CheckTrue(s < Pos('SendRecordToServer(NET_WIRE_EDIT_ID, EditableQSORXData);', text),
             'before the edit goes to the network');
   CheckTrue(s < Pos('LogStoreUpdateQSOAtIndex(IndexInMap, EditableQSORXData', text),
             'and before it is written');
   CheckTrue(Pos('if not XQSOIsAutomatic then', text) > 0,
             'a greyed box never writes the operator''s flag');
   CheckTrue(Pos('EditableQSORXData.ceOffContest;', text) > 0,
             'and the box greys from the STORED rule');

   (* uLogStore: every append, a batch append, a peer's edit, and the
      one-shot stamp of a migrated log. *)
   text := SourceText('uLogStore.pas');
   s := Pos('StampOffContest(stamped);', text);
   CheckTrue(s > 0, 'an append is stamped');
   CheckTrue(PosEx('StampOffContest(stamped);', text, s + 1) > s, 'and a peer''s edit');
   CheckTrue(Pos('aQsos.StampEach(@StampOffContest);', text) > 0, 'and a batch append');
   CheckTrue(Pos('GRepository.BackfillOffContest(@StampOffContest);', text) > 0,
             'and a migrated log, once');

   (* uGetServerLog: the server's records as they arrive. *)
   text := SourceText('uGetServerLog.pas');
   CheckTrue(Pos('StampOffContest(aRecord);', text) > 0,
             'a record from the server''s log is stamped as it arrives');
end;

(* ISSUE 347, PLAN COMMIT 6 (NY4I ruling 3, 2026-11-21): THE PEER ARM ACTS ON
   THE LOG'S ANSWER. It used to call LogContact, drop the Boolean and redraw
   the windows as for a saved QSO. PROTOCOL 5 (2026-11-22): the arm stores the
   sender's row (AcceptPeerQso -> LogStoreSaveWireRow, which answers True only
   after the COMMIT) and only then drives the sheets and redraws the windows
   (ProcessStoredPeerRow). A False is reported through ReportPeerQsoRefused (an
   Error line each time, one notice per link) and queued nowhere -- catch-up and
   Synchronize are the retry. Read from the source: the arm needs a booted
   contest session to run its second half. *)
procedure TAutomaticXQSOTests.Test_APeersRefusedQSOIsReportedNotAssumedSaved;
var
   text, arm, report, process: string;
   p, e, w: integer;
begin
   BeginTest('Test_APeersRefusedQSOIsReportedNotAssumedSaved');
   text := SourceText('uNet.pas');
   p := Pos('procedure AcceptPeerQso(', text);
   e := PosEx('procedure AcceptPeerEdit(', text, p);
   CheckTrue((p > 0) and (e > p), 'the new-QSO arm is found');
   arm := Copy(text, p, e - p);
   w := Pos('if not LogStoreSaveWireRow(', arm);
   CheckTrue(w > 0, 'the arm asks the log''s answer');
   CheckTrue(PosEx('ReportPeerQsoRefused(aValues);', arm, w) > w,
             'a False is reported, after that');
   CheckTrue(PosEx('ProcessStoredPeerRow(rowId);', arm, w) >
             PosEx('ReportPeerQsoRefused(aValues);', arm, w),
             'and the sheets are driven only after the report branch has left');
   CheckEquals(0, Pos('LogStoreSaveWireRow(', Copy(arm, PosEx('ProcessStoredPeerRow(rowId);', arm, w),
                                                      Length(arm))),
               'nothing is written after the sheets are driven');

   p := Pos('procedure ProcessStoredPeerRow(', text);
   e := PosEx('procedure AcceptPeerQso(', text, p);
   CheckTrue((p > 0) and (e > p), 'the stored-row processing is found');
   process := Copy(text, p, e - p);
   w := Pos('if LogStoredPeerQSO(rec, facts) then', process);
   CheckTrue(w > 0, 'the sheets are driven by the peer path that writes nothing');
   CheckTrue(PosEx('UpdateWindows;', process, w) > w, 'and the windows are redrawn only on True');

   p := Pos('procedure ReportPeerQsoRefused(', text);
   e := PosEx('procedure ReportPeerVersion(', text, p);
   CheckTrue((p > 0) and (e > p), 'the report is found');
   report := Copy(text, p, e - p);
   CheckTrue(Pos('logger.Error(', report) > 0, 'it logs an Error line');
   CheckTrue(Pos('guid', report) > 0, 'naming the row''s guid');
   CheckTrue(Pos('GPeerQsosRefused > 1', report) > 0, 'and tells the operator only once');
   CheckEquals(0, Pos('LogContact(', report), 'a refused QSO is never retried here');
   CheckTrue(Pos('GPeerQsosRefused := 0;', text) >
             Pos('procedure NetBeginLinkSession;' + sLineBreak + 'begin', text),
             'the once is per link');
end;

(* ISSUE 347, PLAN COMMIT 7 (NY4I ruling 4, 2026-11-21): A NOTE OR QTC RECORD
   IS SENT ONLY AFTER ITS COMMIT. AddRecordToLogAndSendToNetwork sent first and
   appended after, with a comment leaving the order alone for NY4I. The write is
   now the condition of the send, a refused record sends nothing and counts no
   tUSQ, and Result stays the network's answer (the QTC callers pace on it). *)
procedure TAutomaticXQSOTests.Test_ANoteOrQTCRecordIsSentOnlyAfterItsCommit;
var
   text, body: string;
   p, e, w: integer;
begin
   BeginTest('Test_ANoteOrQTCRecordIsSentOnlyAfterItsCommit');
   text := SourceText('MainUnit.pas');
   p := Pos('function AddRecordToLogAndSendToNetwork(var CE: ContestExchange): boolean;' +
            sLineBreak + 'begin', text);
   e := PosEx('THE CALL-FIELD FLASH.', text, p);
   CheckTrue((p > 0) and (e > p), 'the routine is found');
   body := Copy(text, p, e - p);
   w := Pos('if tAddQSOToLog(CE) then', body);
   CheckTrue(w > 0, 'the log is written first and its answer is the condition');
   CheckTrue(PosEx('SendRecordToServer(NET_WIRE_QSO_ID, CE)', body, w) > w,
             'the packet is sent after it, inside that branch');
   CheckEquals(0, PosEx('SendRecordToServer(', body,
                        PosEx('SendRecordToServer(', body, w) + 1),
               'and there is no other send');
   CheckTrue(Pos('did NOT commit', body) >
             PosEx('SendRecordToServer(NET_WIRE_QSO_ID, CE)', body, w),
             'a refusal is reported at Error, after the send branch');
   CheckTrue(Pos('Result := False;', body) > 0, 'a refused record answers False (no pacing)');
end;

procedure TAutomaticXQSOTests.RunAllTests;
begin
   Test_APeersRefusedQSOIsReportedNotAssumedSaved;
   Test_ANoteOrQTCRecordIsSentOnlyAfterItsCommit;
   Test_ARefusedSaveKeepsTheEntryAndItsReason;
   Test_AQSOIsPublishedOnlyAfterItsCommit;
   Test_AnEntryOfSeveralLegsIsOneWrite;
   Test_AChangeIsAnnouncedOnlyAfterItsCommit;
   Test_ASharedSerialAdvancesTheNextByOne;
   Test_TheMultiCountyDrainKeepsOneSerial;
   Test_TheContestsRuleMakesAnXQSO;
   Test_AnXQSOScoresNothing;
   Test_SweepstakesCreditsOnlyItsOwnMode;
   Test_AnEditedBandReclassifiesTheQSO;
   Test_TheRecordsOwnContestDecides;
   Test_ADIFMarksAnAutomaticXQSO;
   Test_HamScoreLineIsAnXQSOLine;
   Test_AnOffModeQSOIsNoDupeAndMakesNone;
   Test_TheBonusViewKeepsNoXQSO;
   Test_TheSummarySheetCountsNoXQSO;
   Test_LogContactCountsNoXQSOButAdvancesTheSerial;
   Test_TheLoaderAndTheRescoreAskThePredicate;
   Test_TheExportsReadTheStoredRuleNotTheContest;
   Test_TheOperatorsFlagStandsWhenTheRuleReleases;
   Test_EverySettingPointStampsTheRule;
end;

end.
