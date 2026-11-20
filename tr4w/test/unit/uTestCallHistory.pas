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

(* A CALL HISTORY FILE -- 2026-11-07 (uCallHistory, TContestBase.CallHistoryFields,
  LOGDUPE.LoadCallHistoryFile).

  THREE LAYERS, each pinned where it lives:
    * the READER, on inline text: the !!Order!! directive, the default order,
      semicolons, comments, blank lines, short rows, a skipped column, a CK
      that is not a number, a one-digit CK, truncation, an unknown directive;
    * the CONTEST'S STATEMENT, over the registry: Sweepstakes (both modes)
      prefills CK then Sect, every other contest nothing;
    * the STORE and the LOADER: an entry already known is not replaced, a
      logged QSO replaces the file's, the setting off reads nothing, a missing
      file is no crash, and the real loader fills CallsignsList from the
      fixture with Sweepstakes' text ('72 SCV').

  The typed-call prefill and the needs strip through a real session are
  uTestStatusAndNotice's (they need the main form); the spot-comment order is
  uTestSpotCommentMultiplier's. NEVER NY4I's own SSCW.txt: it is gitignored
  and changes; the rows used are copied into fixtures/callhistory_ss_sample.txt. *)
unit uTestCallHistory;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCallHistoryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Reader_OrderDirective;
      procedure Test_Reader_DefaultOrderAndSemicolons;
      procedure Test_Reader_CommentsBlankAndShortRows;
      procedure Test_Reader_CheckAndTruncation;
      procedure Test_Reader_UnknownDirectiveIsIgnoredAndNamed;
      procedure Test_Reader_OrderMayChangeMidFile;
      procedure Test_ExchangeText_SweepstakesShape;
      procedure Test_Reader_BothPublishedLayoutsGiveOnePrefill;
      procedure Test_EveryContestStatesItsCallHistoryFields;
      procedure Test_SiteLayoutsGiveTheRememberedText;
      procedure Test_APartialRowPrefillsWhatItHas;
      procedure Test_Store_KnownEntryIsKeptAndALoggedQSOReplaces;
      procedure Test_Loader_SettingOffMissingFileAndOtherContest;
      procedure Test_Loader_FillsTheStoreForSweepstakes;
      procedure Test_Path_BareNameAndFullPath;
      procedure Test_Browse_StoresABareNameOnlyWhenItFindsThePickedFile;
      procedure Test_Cost_ALargeFileLoadsQuickly;
      procedure Test_FlushInitialExSkipsCallHistoryEntries;
   end;

implementation

uses
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uCallHistory,
   uCallHistoryDownload,
   uCallsigns,
   uContestBase,
   uContestRegistry,
   uTestRegisteredContests,
   (* Contest -- the session's contest handle. *)
   PostUnit,
   LogDupe,
   (* GenerateCallsignsList -- FLUSH INITIAL EX. *)
   MainUnit;

var
   (* What a ReadAll handed its store, 'CALL=TEXT' per row, in order. *)
   gCollected: TStringList;
   (* The answer the collecting store gives. *)
   gAnswer: TCallHistoryAddResult;

function CollectRow(const aCall: string; const aExchange: string): TCallHistoryAddResult;
begin
   gCollected.Add(AnsiString(aCall + '=' + aExchange));
   Result := gAnswer;
end;

(* The real store, as LOGDUPE's loader uses it. *)
function CallHistoryIntoCallsignsList(const aCall: string; const aExchange: string): TCallHistoryAddResult;
begin
   Result := CallsignsList.AddCallHistoryExchange(aCall, aExchange);
end;

function FixturePath: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'callhistory_ss_sample.txt';
end;

(* The values one line gives, through a fresh reader. *)
function ValuesOf(aReader: TCallHistoryReader; const aLine: string;
                  out aValues: TCallHistoryValues): boolean;
begin
   Result := aReader.ReadLine(aLine, aValues);
end;

function SweepstakesFields: TCallHistoryFields;
begin
   Result := ContestIdentity(ContestHandleOf(ARRLSSCW)).CallHistoryFields;
end;

(* ReadAll over aText (lines separated by #13#10), the store collecting. *)
procedure ReadText(aReader: TCallHistoryReader; const aText: string;
                   const aFields: array of TCallHistoryField);
var
   lines: TStringList;
begin
   lines := TStringList.Create;
   try
      lines.Text := AnsiString(aText);
      gCollected.Clear;
      gAnswer := charAdded;
      aReader.ReadAll(lines, aFields, CollectRow);
   finally
      lines.Free;
   end;
end;

procedure TCallHistoryTests.Test_Reader_OrderDirective;
var
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
begin
   BeginTest('Test_Reader_OrderDirective');
   reader := TCallHistoryReader.Create;
   try
      CheckFalse(ValuesOf(reader, '!!Order!!,Call,Sect,State,CK,Exch1,', values),
                 'the directive is not a row');
      CheckTrue(ValuesOf(reader, 'N6TV,SCV,CA,72,', values), 'N6TV is a row');
      CheckEquals('N6TV', values[chfCall], 'the call');
      CheckEquals('SCV', values[chfSect], 'Sect is the second column');
      CheckEquals('CA', values[chfState], 'State the third');
      CheckEquals('72', values[chfCK], 'CK the fourth');
      CheckEquals('', values[chfExch1], 'Exch1 empty');
      CheckEquals('', values[chfName], 'a field the order does not name is empty');

      CheckTrue(ValuesOf(reader, 'AA0A,MO,MO,60,U,', values), 'AA0A is a row');
      CheckEquals('U', values[chfExch1], 'Exch1 the fifth');

      (* THE DIRECTIVE IS CASE-BLIND, its names too. *)
      CheckFalse(ValuesOf(reader, '!!ORDER!!,call,ck,sect', values), 'an upper-case directive');
      CheckTrue(ValuesOf(reader, 'n4af,58,NC', values), 'a row in the new order');
      CheckEquals('N4AF', values[chfCall], 'the call, upper-cased');
      CheckEquals('58', values[chfCK], 'CK now second');
      CheckEquals('NC', values[chfSect], 'Sect now third');
   finally
      reader.Free;
   end;
end;

procedure TCallHistoryTests.Test_Reader_DefaultOrderAndSemicolons;
var
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
begin
   BeginTest('Test_Reader_DefaultOrderAndSemicolons');
   reader := TCallHistoryReader.Create;
   try
      (* NO !!Order!!: Call,Name,Loc1,Loc2,Sect,State,CK,BirthDate,Exch1,... *)
      CheckTrue(ValuesOf(reader, 'W1AW,HIRAM,FN31,,CT,CT,36,,A,M,KW,5,8,hello,2026', values),
                'a default-order row');
      CheckEquals('HIRAM', values[chfName], 'Name second');
      CheckEquals('FN31', values[chfLoc1], 'Loc1 third');
      CheckEquals('', values[chfLoc2], 'Loc2 empty');
      CheckEquals('CT', values[chfSect], 'Sect fifth');
      CheckEquals('36', values[chfCK], 'CK seventh');
      CheckEquals('A', values[chfExch1], 'Exch1 ninth');
      CheckEquals('KW', values[chfPower], 'Power eleventh');
      CheckEquals('5', values[chfCqZone], 'CqZone');
      CheckEquals('8', values[chfITUZone], 'ITUZone');
      CheckEquals('hello', values[chfUserText], 'UserText kept as written');
      CheckEquals('2026', values[chfLastUpdateNote], 'LastUpdateNote last');

      (* SEMICOLONS, AND BLANKS AROUND A VALUE, mixed with commas. *)
      CheckTrue(ValuesOf(reader, 'K1AR ; JOHN;FN42 , ;EMA', values), 'a semicolon row');
      CheckEquals('K1AR', values[chfCall], 'the call, trimmed');
      CheckEquals('JOHN', values[chfName], 'the name');
      CheckEquals('FN42', values[chfLoc1], 'Loc1 after a comma');
      CheckEquals('EMA', values[chfSect], 'Sect after an empty Loc2');
   finally
      reader.Free;
   end;
end;

procedure TCallHistoryTests.Test_Reader_CommentsBlankAndShortRows;
var
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
begin
   BeginTest('Test_Reader_CommentsBlankAndShortRows');
   reader := TCallHistoryReader.Create;
   try
      CheckFalse(ValuesOf(reader, '# Current contest: SSCW', values), 'a comment');
      CheckFalse(ValuesOf(reader, '   # indented comment', values), 'an indented comment');
      CheckFalse(ValuesOf(reader, '', values), 'a blank line');
      CheckFalse(ValuesOf(reader, '    ', values), 'a line of blanks');
      CheckFalse(ValuesOf(reader, ',SCV,CA,72', values), 'a row with no call');

      ValuesOf(reader, '!!Order!!,Call,Sect,State,CK', values);
      CheckTrue(ValuesOf(reader, 'W7ST', values), 'a row of the call alone');
      CheckEquals('', values[chfSect], 'its Sect is empty');
      CheckTrue(ValuesOf(reader, 'W7ST,UT,UT,18,X,Y,Z', values), 'columns past the order');
      CheckEquals('18', values[chfCK], 'what the order names is read');

      (* A BLANK OR UNKNOWN COLUMN NAME SKIPS THE COLUMN. *)
      ValuesOf(reader, '!!Order!!,Call,,Bogus,Sect', values);
      CheckTrue(ValuesOf(reader, 'W7ST,ignored,also,UT', values), 'skipped columns');
      CheckEquals('UT', values[chfSect], 'Sect is the fourth column');
      CheckEquals('', values[chfName], 'nothing landed in Name');
   finally
      reader.Free;
   end;
end;

procedure TCallHistoryTests.Test_Reader_CheckAndTruncation;
var
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
begin
   BeginTest('Test_Reader_CheckAndTruncation');
   reader := TCallHistoryReader.Create;
   try
      ValuesOf(reader, '!!Order!!,Call,Sect,State,CK,Exch1,', values);
      ValuesOf(reader, 'K1IEB,AZ,AZ,-1,', values);
      CheckEquals('', values[chfCK], '-1 (unknown in the files) is no CK');
      ValuesOf(reader, 'K1IEB,AZ,AZ,U,', values);
      CheckEquals('', values[chfCK], 'a letter is no CK');
      ValuesOf(reader, 'AA1RB,VA,VA,8,', values);
      CheckEquals('08', values[chfCK], 'a one-digit CK gets its leading zero');
      ValuesOf(reader, 'AA1WA,EMA,MA,0,', values);
      CheckEquals('00', values[chfCK], '0 is 00');
      ValuesOf(reader, 'AA1WA,EMA,MA,05,', values);
      CheckEquals('05', values[chfCK], 'a written zero is kept');

      (* TRUNCATED TO N1MM's MAXIMUM: Call 15, Sect 8. *)
      ValuesOf(reader, 'ABCDEFGHIJKLMNOPQRST,ABCDEFGHIJ,CA,72', values);
      CheckEquals('ABCDEFGHIJKLMNO', values[chfCall], 'the call cut to 15');
      CheckEquals('ABCDEFGH', values[chfSect], 'Sect cut to 8');
   finally
      reader.Free;
   end;
end;

procedure TCallHistoryTests.Test_Reader_UnknownDirectiveIsIgnoredAndNamed;
var
   reader: TCallHistoryReader;
begin
   BeginTest('Test_Reader_UnknownDirectiveIsIgnoredAndNamed');
   reader := TCallHistoryReader.Create;
   try
      ReadText(reader, '!!Order!!,Call,Sect,State,CK'#13#10 +
                       '!!MapStateToSect!!'#13#10 +
                       'N6TV,SCV,CA,72'#13#10 +
                       '!!FourCharGridSq!!,whatever'#13#10 +
                       '!!MapStateToSect!!'#13#10 +
                       'N4AF,NC,NC,58', SweepstakesFields);
      CheckEquals(2, reader.DataRows, 'both rows read: a directive stops nothing');
      CheckEquals('MapStateToSect, FourCharGridSq', reader.UnknownDirectives,
                  'each unknown directive named once');
      CheckEquals('N6TV=72 SCV', string(gCollected[0]), 'the order still in force');
   finally
      reader.Free;
   end;
end;

procedure TCallHistoryTests.Test_Reader_OrderMayChangeMidFile;
var
   reader: TCallHistoryReader;
begin
   BeginTest('Test_Reader_OrderMayChangeMidFile');
   reader := TCallHistoryReader.Create;
   try
      ReadText(reader, '!!Order!!,Call,Sect,CK'#13#10 +
                       'N6TV,SCV,72'#13#10 +
                       '!!Order!!,Call,CK,Sect'#13#10 +
                       'N4AF,58,NC', SweepstakesFields);
      CheckEquals(2, gCollected.Count, 'two rows');
      CheckEquals('N6TV=72 SCV', string(gCollected[0]), 'the first order');
      CheckEquals('N4AF=58 NC', string(gCollected[1]), 'the second order');
   finally
      reader.Free;
   end;
end;

(* NY4I'S ROWS (2026-11-07, verbatim from his SSCW.txt) GIVE SWEEPSTAKES'
   REMEMBERED TEXT: check then section, the State column ignored -- the
   shape LOGDUPE.GetInitialExchangeStringFromContestExchange writes for a
   logged SS QSO ('18 UT'). *)
procedure TCallHistoryTests.Test_ExchangeText_SweepstakesShape;
var
   reader: TCallHistoryReader;
begin
   BeginTest('Test_ExchangeText_SweepstakesShape');
   reader := TCallHistoryReader.Create;
   try
      ReadText(reader, '!!Order!!,Call,Sect,State,CK,Exch1,'#13#10 +
                       'NY4I,WCF,FL,80,'#13#10 +
                       'N6TV,SCV,CA,72,'#13#10 +
                       'N4AF,NC,NC,58,'#13#10 +
                       '4U1WB,MDC,DC,89,'#13#10 +
                       'AA0A,MO,MO,60,U,'#13#10 +
                       'KK6L,,CA,95,'#13#10 +
                       'K0QL,SC,SC,', SweepstakesFields);
      CheckEquals(7, gCollected.Count, 'five complete rows and two partial');
      CheckEquals('NY4I=80 WCF', string(gCollected[0]), 'NY4I');
      CheckEquals('N6TV=72 SCV', string(gCollected[1]), 'N6TV');
      CheckEquals('N4AF=58 NC', string(gCollected[2]), 'N4AF');
      CheckEquals('4U1WB=89 MDC', string(gCollected[3]), 'Sect MDC, not State DC');
      CheckEquals('AA0A=60 MO', string(gCollected[4]), 'Exch1 is not asked');
      CheckEquals('KK6L=95', string(gCollected[5]), 'no Sect (KK6L): prefilled with the check alone');
      CheckEquals('K0QL=SC', string(gCollected[6]), 'no CK (K0QL): prefilled with the section alone');
      CheckEquals(7, reader.DataRows, 'seven rows with a call');
      CheckEquals(0, reader.Incomplete, 'every row carries one of the two');
      CheckEquals(2, reader.Partial, 'two rows carry only one');
      CheckEquals(7, reader.Added, 'the store took seven');
   finally
      reader.Free;
   end;
end;

(* THE TWO LAYOUTS IN CIRCULATION GIVE ONE PREFILL: NY4I's SSCW.txt
   (Call,Sect,State,CK,Exch1) and supercheckhistory.com's ARRL-SS-CW.txt
   (Call,Exch1,CK,Sect,UserText, 2026-11-07), whose rows often lack the
   precedence, the check or the section. Exch1 is the precedence there and
   is read, though Sweepstakes does not prefill it today. A row missing the
   check OR the section is not prefilled; a missing precedence does not
   matter, since the class does not ask it. *)
procedure TCallHistoryTests.Test_Reader_BothPublishedLayoutsGiveOnePrefill;
var
   reader: TCallHistoryReader;
   values: TCallHistoryValues;
begin
   BeginTest('Test_Reader_BothPublishedLayoutsGiveOnePrefill');
   reader := TCallHistoryReader.Create;
   try
      ReadText(reader, '!!Order!!,Call,Sect,State,CK,Exch1,'#13#10 +
                       '4U1WB,MDC,DC,89,'#13#10 +
                       'AA0AO,MN,MN,14,', SweepstakesFields);
      CheckEquals('4U1WB=89 MDC', string(gCollected[0]), 'NY4I''s layout: 4U1WB');
      CheckEquals('AA0AO=14 MN', string(gCollected[1]), 'NY4I''s layout: AA0AO');
   finally
      reader.Free;
   end;

   reader := TCallHistoryReader.Create;
   try
      ReadText(reader, '# ARRL-SS-CW'#13#10 +
                       '# Generated by bb-sch, data through 2025-11-19'#13#10 +
                       '!!Order!!,Call,Exch1,CK,Sect,UserText'#13#10 +
                       '4U1WB,U,89,MDC,'#13#10 +
                       'AA0AO,,14,MN,'#13#10 +
                       'AA0YY,A,,MO,'#13#10 +
                       'AE2NY,A,24,,'#13#10 +
                       'K1IP,U,,,', SweepstakesFields);
      CheckEquals(4, gCollected.Count, 'two rows carry both, two carry one');
      CheckEquals('4U1WB=89 MDC', string(gCollected[0]), 'the site''s layout: 4U1WB, the same text');
      CheckEquals('AA0AO=14 MN', string(gCollected[1]), 'a blank precedence does not matter');
      CheckEquals('AA0YY=MO', string(gCollected[2]), 'no check: the section alone');
      CheckEquals('AE2NY=24', string(gCollected[3]), 'no section: the check alone');
      CheckEquals(5, reader.DataRows, 'five rows');
      CheckEquals(1, reader.Incomplete, 'neither (K1IP): nothing to prefill');
      CheckEquals(2, reader.Partial, 'AA0YY and AE2NY');
      reader.ReadLine('4U1WB,U,89,MDC,', values);
      CheckEquals('U', values[chfExch1], 'the precedence is read into Exch1, ready for a class that asks it');
   finally
      reader.Free;
   end;
end;

(* WHAT EACH CONTEST PREFILLS, AS LITERALS -- the exact set of contests that
   name a supercheckhistory.com file (the call history download sweep,
   2026-11-20). A contest that starts using a call history file adds a row
   to the three tables below, and its layout to Test_SiteLayoutsGiveTheRememberedText;
   the walk fails a contest that names a stem and is not here, and a row here
   whose contest names none.

   The stem is the N1MM file's name on the site (<stem>.txt), which is NOT
   always the Cabrillo name. The fields are N1MM's names in the order the log
   remembers a worked station (see TContestBase.CallHistoryFields). The
   second layout of each file was READ from the site on 2026-11-20 and is
   in Test_SiteLayoutsGiveTheRememberedText. *)
const
   CALL_HISTORY_MEMBERS: array[0..52] of ContestType = (
      ARRLSSCW, ARRLSSSSB, ARRL10, ARRLFIELDDAY, CWOPEN, IARU, NAQSOCW, NAQSOSSB, NAQSORTTY,
      ARRL160, ARRL_RTTY_ROUNDUP, ARRLDIGI, CWOPS, NASPRINTCW, NASPRINTRTTY, SPRINTSSB, SST,
      WINTERFIELDDAY, CQ160CW, CQ160SSB, NYQP, TEXASQSOPARTY, FLORIDAQSOPARTY, ARRLDXCW,
      ARRLDXSSB, ArizonaQsoParty, CALQSOPARTY, MICHQSOPARTY, MOQSOPARTY, NEBRASKAQSO,
      NCQSOPARTY, OHIOQSOPARTY, TENNESSEEQSOPARTY, VAQP, WISCONSINQSOPARTY, MINNQSOPARTY,
      COLORADOQSOPARTY, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST,
      DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST,
      DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST, DUMMYCONTEST);
   (* A contest that registers by its id has no member (its row's member is
      the placeholder DUMMYCONTEST); the id decides there. '' for a member row. *)
   CALL_HISTORY_IDS: array[0..52] of string = (
      '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', '',
      '', '', '', '', '', '', '', '', '', '', '', '', '', '', '', 'AL-QSO-PARTY',
      'AR-QSO-PARTY', 'GA-QSO-PARTY', 'HI-QSO-PARTY', 'IL-QSO-PARTY', 'KS-QSO-PARTY',
      'KY-QSO-PARTY', 'LA-QSO-PARTY', 'MS-QSO-PARTY', 'NH-QSO-PARTY', 'NJ-QSO-PARTY',
      'OK-QSO-PARTY', 'SC-QSO-PARTY', 'SD-QSO-PARTY', 'VT-QSO-PARTY', 'WV-QSO-PARTY');
   CALL_HISTORY_STEMS: array[0..52] of string = (
      'ARRL-SS-CW', 'ARRL-SS-SSB', 'ARRL-10M', 'ARRL-FD', 'CW-OPEN', 'IARU-HF', 'NAQP-CW',
      'NAQP-SSB', 'NAQP-RTTY', 'ARRL-160M', 'ARRL-RTTY', 'ARRL-DIGI', 'CWOPS', 'NA-SPRINT-CW',
      'NA-SPRINT-RTTY', 'NA-SPRINT-SSB', 'K1USNSST', 'WFD', 'CQ-160-CW', 'CQ-160-SSB',
      'QSOP_NY', 'QSOP_TX', 'QSOP_FL', 'ARRL-DX-CW', 'ARRL-DX-SSB', 'QSOP_AZ', 'QSOP_CA',
      'QSOP_MI', 'QSOP_MO', 'QSOP_NE', 'QSOP_NC', 'QSOP_OH', 'QSOP_TN', 'QSOP_VA', 'QSOP_WI',
      'QSOP_MN', 'QSOP_CO', 'QSOP_AL', 'QSOP_AR', 'QSOP_GA', 'QSOP_HI', 'QSOP_IL', 'QSOP_KS',
      'QSOP_KY', 'QSOP_LA', 'QSOP_MS', 'QSOP_NH', 'QSOP_NJ', 'QSOP_OK', 'QSOP_SC', 'QSOP_SD',
      'QSOP_VT', 'QSOP_WV');
   CALL_HISTORY_FIELD_NAMES: array[0..52] of string = (
      'CK Sect', 'CK Sect', 'Exch1', 'Exch1 Sect', 'Name', 'Sect', 'Name State', 'Name State',
      'Name State', 'Exch1', 'Exch1', 'Loc1', 'Name Exch1', 'Name State', 'Name State',
      'Name State', 'Name Exch1', 'Exch1 Sect', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1',
      'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1',
      'Exch1', 'Exch1', 'Name Exch1', 'Name Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1',
      'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1', 'Exch1',
      'Exch1', 'Exch1');

(* The fields as N1MM names them, one blank between. *)
function FieldNamesText(const aFields: TCallHistoryFields): string;
var
   i: integer;
begin
   Result := '';
   for i := 0 to High(aFields) do
      begin
      if Result <> '' then
         begin
         Result := Result + ' ';
         end;
      Result := Result + CallHistoryFieldName(aFields[i]);
      end;
end;

(* EVERY REGISTERED CONTEST STATES WHAT IT PREFILLS: the contests in the
   tables above name their site file and fields, every other contest nothing.
   A contest that starts using a call history adds itself to the tables. *)
procedure TCallHistoryTests.Test_EveryContestStatesItsCallHistoryFields;
var
   contests: TContestIdentityList;
   k, m, row: integer;
   fields: TCallHistoryFields;
   seen: array[0..52] of boolean;
   reader: TCallHistoryReader;
begin
   BeginTest('Test_EveryContestStatesItsCallHistoryFields');
   for m := Low(seen) to High(seen) do
      begin
      seen[m] := False;
      end;
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      fields := contests[k].CallHistoryFields;
      row := -1;
      for m := Low(CALL_HISTORY_MEMBERS) to High(CALL_HISTORY_MEMBERS) do
         begin
         if CALL_HISTORY_IDS[m] <> '' then
            begin
            if ContestId(HandleOf(contests[k])) = CALL_HISTORY_IDS[m] then
               begin
               row := m;
               seen[m] := True;
               end;
            end
         else if IsLegacyContest(contests[k], CALL_HISTORY_MEMBERS[m]) then
            begin
            row := m;
            seen[m] := True;
            end;
         end;
      if row >= 0 then
         begin
         CheckEquals(CALL_HISTORY_STEMS[row], contests[k].CallHistorySiteName,
                     ContestWho(contests[k]) + ': its site file');
         CheckEquals(CALL_HISTORY_STEMS[row] + '.txt', contests[k].CallHistoryFileName,
                     ContestWho(contests[k]) + ': the default file follows the site name');
         CheckEquals(CALL_HISTORY_FIELD_NAMES[row], FieldNamesText(fields),
                     ContestWho(contests[k]) + ': the fields, in the remembered order');
         CheckTrue(CallHistoryDownloadURL(CALL_HISTORY_SITE_URL, contests[k].CallHistorySiteName) <> '',
                   ContestWho(contests[k]) + ': the stem makes a URL');
         (* A QSO PARTY'S FILE, QSOP_<ST>.txt, is !!Order!!,Call,Exch1,UserText
            for every party sampled: a county code or a state is its QTH. *)
         if Copy(CALL_HISTORY_STEMS[row], 1, 5) = 'QSOP_' then
            begin
            reader := TCallHistoryReader.Create;
            try
               ReadText(reader, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AJ,MN,'#13#10 +
                                'K2AA,,'#13#10, fields);
               CheckEquals(1, gCollected.Count, ContestWho(contests[k]) + ': one row prefilled');
               if gCollected.Count > 0 then
                  begin
                  CheckEquals('AA0AJ=MN', string(gCollected[0]), ContestWho(contests[k]) + ': the QTH alone');
                  end;
               CheckEquals(1, reader.Incomplete, ContestWho(contests[k]) + ': a row with no QTH is refused');
            finally
               reader.Free;
            end;
            end;
         end
      else
         begin
         CheckEquals('', contests[k].CallHistoryFileName, ContestWho(contests[k]) + ' names no default file');
         CheckEquals('', contests[k].CallHistorySiteName, ContestWho(contests[k]) + ' has no site file');
         CheckEquals('', contests[k].CallHistoryLegacyFileName, ContestWho(contests[k]) + ' has no legacy file');
         CheckEquals(0, Length(fields), ContestWho(contests[k]) + ' uses no call history');
         end;
      (* THE INVARIANT: a site file is offered only for a contest that can read it. *)
      if contests[k].CallHistorySiteName <> '' then
         begin
         CheckTrue(Length(fields) > 0, ContestWho(contests[k]) + ': a site file needs fields to prefill');
         end;
      (* THE SWEEPSTAKES KEEP THEIR HISTORY: the site name is the Cabrillo name
         and the file N1MM called it stays the fallback. *)
      if IsLegacyContest(contests[k], ARRLSSCW) then
         begin
         CheckEquals(contests[k].CabrilloName, contests[k].CallHistorySiteName, 'SS CW: the Cabrillo name');
         CheckEquals('SSCW.txt', contests[k].CallHistoryLegacyFileName, 'SS CW''s legacy file: N1MM''s name');
         end;
      if IsLegacyContest(contests[k], ARRLSSSSB) then
         begin
         CheckEquals(contests[k].CabrilloName, contests[k].CallHistorySiteName, 'SS SSB: the Cabrillo name');
         CheckEquals('SSSSB.txt', contests[k].CallHistoryLegacyFileName, 'SS SSB''s legacy file: N1MM''s name');
         end;
      end;
   for m := Low(seen) to High(seen) do
      begin
      CheckTrue(seen[m], CALL_HISTORY_STEMS[m] + ': its contest is registered');
      end;
   (* "No contest" too. *)
   CheckEquals(0, Length(ContestIdentity(NoContest).CallHistoryFields), 'no contest: none');
end;

(* THE SITE'S OWN LAYOUTS, as read on 2026-11-20 (the !!Order!! line of each
   file and a row or two, trimmed; the NAQP SSB and RTTY layouts are INFERRED
   from the CW file, never sampled): each contest's fields turn a row into the
   text the log remembers for a worked station -- 'Name State' for NAQP, 'Class
   Section' for Field Day -- and refuse a row missing one. No network. *)
procedure TCallHistoryTests.Test_SiteLayoutsGiveTheRememberedText;
var
   reader: TCallHistoryReader;

   procedure Layout(aMember: ContestType; const aText: string; aAdded, aIncomplete: integer;
                    const aFirst: string);
   begin
      reader := TCallHistoryReader.Create;
      try
         ReadText(reader, aText, ContestIdentity(ContestHandleOf(aMember)).CallHistoryFields);
         CheckEquals(aAdded, gCollected.Count, 'rows prefilled for ' + aFirst);
         CheckEquals(aIncomplete, reader.Incomplete, 'rows refused for ' + aFirst);
         if gCollected.Count > 0 then
            begin
            CheckEquals(aFirst, string(gCollected[0]), 'the first prefill');
            end;
      finally
         reader.Free;
      end;
   end;

begin
   BeginTest('Test_SiteLayoutsGiveTheRememberedText');
   (* NAQP-CW.txt: !!Order!!,Call,Name,State,UserText -- a row with no name is refused. *)
   Layout(NAQSOCW, '!!Order!!,Call,Name,State,UserText'#13#10 +
                   '4L5O,,DX,'#13#10 + '4U1WB,MASA,DC,'#13#10, 2, 0, '4L5O=DX');
   Layout(NAQSOSSB, '!!Order!!,Call,Name,State,UserText'#13#10 + '4A2MAX,MAX,XE,'#13#10,
          1, 0, '4A2MAX=MAX XE');
   Layout(NAQSORTTY, '!!Order!!,Call,Name,State,UserText'#13#10 + '4A2MAX,MAX,XE,'#13#10,
          1, 0, '4A2MAX=MAX XE');
   (* ARRL-10M.txt: !!Order!!,Call,Exch1,UserText -- the QTH alone. *)
   Layout(ARRL10, '!!Order!!,Call,Exch1,UserText'#13#10 + '4U1WB,DC,'#13#10 + 'AA0A,MO,'#13#10,
          2, 0, '4U1WB=DC');
   (* ARRL-FD.txt: !!Order!!,Call,Exch1,Sect,UserText -- the class, then the section. *)
   Layout(ARRLFIELDDAY, '!!Order!!,Call,Exch1,Sect,UserText'#13#10 +
                        '4U1WB,,MDC,'#13#10 + '2E0FHM,1D,DX,'#13#10, 2, 0, '4U1WB=MDC');
   (* CW-OPEN.txt: !!Order!!,Call,Name,UserText. *)
   Layout(CWOPEN, '!!Order!!,Call,Name,UserText'#13#10 + '2E0OBO,BOB,'#13#10,
          1, 0, '2E0OBO=BOB');
   (* ARRL-160M.txt, ARRL-RTTY.txt, CQ-160-CW.txt, QSOP_NY/AL/TX/FL.txt: all
      !!Order!!,Call,Exch1,UserText -- the QTH as the station sent it. *)
   Layout(ARRL160, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AI,IA,'#13#10 + 'W3LPL,EPA,'#13#10,
          2, 0, 'AA0AI=IA');
   Layout(ARRL_RTTY_ROUNDUP, '!!Order!!,Call,Exch1,UserText'#13#10 + '4U1WB,DC,'#13#10,
          1, 0, '4U1WB=DC');
   Layout(CQ160CW, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AC,MN,'#13#10 + '2E0AMO,08,'#13#10,
          2, 0, 'AA0AC=MN');
   Layout(CQ160SSB, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AC,MN,'#13#10,
          1, 0, 'AA0AC=MN');
   Layout(NYQP, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AO,MN,'#13#10 + 'K2AA,ERI,'#13#10,
          2, 0, 'AA0AO=MN');
   Layout(TEXASQSOPARTY, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AJ,MN,'#13#10,
          1, 0, 'AA0AJ=MN');
   Layout(FLORIDAQSOPARTY, '!!Order!!,Call,Exch1,UserText'#13#10 + 'AA0AJ,MN,'#13#10,
          1, 0, 'AA0AJ=MN');
   (* ARRL-DX-CW.txt and ARRL-DX-SSB.txt: !!Order!!,Call,Exch1,UserText -- a DX
      station's row is its power, a W or VE station's its state. *)
   Layout(ARRLDXCW, '!!Order!!,Call,Exch1,UserText'#13#10 + '2E0BLN,100,'#13#10 + 'W3LPL,PA,'#13#10 +
                    '2E0CEA,KW,'#13#10, 3, 0, '2E0BLN=100');
   Layout(ARRLDXSSB, '!!Order!!,Call,Exch1,UserText'#13#10 + '2E0CEA,50,'#13#10 + 'K1TTT,MA,'#13#10,
          2, 0, '2E0CEA=50');
   (* ARRL-DIGI.txt: !!Order!!,Call,Loc1,UserText -- the grid. *)
   Layout(ARRLDIGI, '!!Order!!,Call,Loc1,UserText'#13#10 + '2E0CVN,IO80,'#13#10,
          1, 0, '2E0CVN=IO80');
   (* CWOPS.txt: !!Order!!,Call,Name,Exch1,UserText -- name, then number or state. *)
   Layout(CWOPS, '!!Order!!,Call,Name,Exch1,UserText'#13#10 + '2E0OBO,BOB,2381,'#13#10 +
                 '2E0JGV,DAVID,,'#13#10, 2, 0, '2E0OBO=BOB 2381');
   (* NA-SPRINT-CW.txt: !!Order!!,Call,Name,State,UserText. *)
   Layout(NASPRINTCW, '!!Order!!,Call,Name,State,UserText'#13#10 + '4U1UN,ADRIAN,DX,'#13#10,
          1, 0, '4U1UN=ADRIAN DX');
   Layout(NASPRINTRTTY, '!!Order!!,Call,Name,State,UserText'#13#10 + '4U1UN,ADRIAN,DX,'#13#10,
          1, 0, '4U1UN=ADRIAN DX');
   Layout(SPRINTSSB, '!!Order!!,Call,Name,State,UserText'#13#10 + '4U1UN,ADRIAN,DX,'#13#10,
          1, 0, '4U1UN=ADRIAN DX');
   (* K1USNSST.txt: !!Order!!,Call,Name,Exch1,UserText. *)
   Layout(SST, '!!Order!!,Call,Name,Exch1,UserText'#13#10 + 'AA0BY,,OR,'#13#10 +
               'AA0AJ,DOREEN,MN,'#13#10, 2, 0, 'AA0BY=OR');
   (* WFD.txt: !!Order!!,Call,Exch1,Sect,UserText. *)
   Layout(WINTERFIELDDAY, '!!Order!!,Call,Exch1,Sect,UserText'#13#10 + '6Y5PW,1H,DX,'#13#10,
          1, 0, '6Y5PW=1H DX');
   (* IARU-HF.txt: !!Order!!,Call,Sect,UserText -- the zone or the society. *)
   Layout(IARU, '!!Order!!,Call,Sect,UserText'#13#10 + '2E0AMO,27,'#13#10 + '4U1WB,HQ,'#13#10,
          2, 0, '2E0AMO=27');
end;

(* A ROW WITH SOME OF WHAT THE CONTEST REMEMBERS (NY4I, 2026-11-20: "the
   history does not have to be complete to be useful"). Minnesota remembers
   Name then QTH and its site file has the county only: AA0AC gives 'CRL',
   the operator adds the name. A full row is as it always was, and a row
   with none of the fields prefills nothing. *)
procedure TCallHistoryTests.Test_APartialRowPrefillsWhatItHas;
var
   reader: TCallHistoryReader;
   list: TCallsignsList;
begin
   BeginTest('Test_APartialRowPrefillsWhatItHas');
   reader := TCallHistoryReader.Create;
   try
      ReadText(reader, '!!Order!!,Call,Name,Exch1,UserText'#13#10 +
                       'AA0AC,,CRL,'#13#10 +
                       'N6TV,STEVE,CA,'#13#10 +
                       'K1AR,JOHN,,'#13#10 +
                       'W1AW,,,'#13#10,
               [chfName, chfExch1]);
      CheckEquals(3, gCollected.Count, 'three rows give a prefill');
      CheckEquals('AA0AC=CRL', string(gCollected[0]), 'county only: the county, no leading blank in the text');
      CheckEquals('N6TV=STEVE CA', string(gCollected[1]), 'a full row is unchanged');
      CheckEquals('K1AR=JOHN', string(gCollected[2]), 'name only: the name');
      CheckEquals(4, reader.DataRows, 'four rows with a call');
      CheckEquals(2, reader.Partial, 'two partial rows');
      CheckEquals(1, reader.Incomplete, 'W1AW carries nothing to prefill');
   finally
      reader.Free;
   end;
   (* THE STORE KEEPS IT AS THE LOG KEEPS A LOGGED QSO'S TEXT: the engine
      puts one blank before and after it in the exchange box. *)
   list := TCallsignsList.Create;
   try
      CheckTrue(list.AddCallHistoryExchange('AA0AC', 'CRL') = charAdded, 'the partial text is added');
      CheckEquals('CRL', list.GetIniitialExchange('AA0AC'), 'and read back as written');
   finally
      list.Free;
   end;
end;

procedure TCallHistoryTests.Test_Store_KnownEntryIsKeptAndALoggedQSOReplaces;
var
   list: TCallsignsList;
begin
   BeginTest('Test_Store_KnownEntryIsKeptAndALoggedQSOReplaces');
   list := TCallsignsList.Create;
   try
      (* INITIAL.EX (or the log) KNOWS N4AF: the file does not replace it. *)
      list.AddIniitialExchange('N4AF', '58 NC');
      CheckTrue(list.AddCallHistoryExchange('N4AF', '11 GA') = charAlreadyKnown, 'known: kept');
      CheckEquals('58 NC', list.GetIniitialExchange('N4AF'), 'the known text stands');
      CheckFalse(list.InitialExchangeIsFromCallHistory('N4AF'), 'and is not the file''s');

      (* A NEW CALL: the file's, marked so. *)
      CheckTrue(list.AddCallHistoryExchange('N6TV', '72 SCV') = charAdded, 'new: added');
      CheckEquals('72 SCV', list.GetIniitialExchange('N6TV'), 'the file''s text');
      CheckTrue(list.InitialExchangeIsFromCallHistory('n6tv'), 'marked as the file''s, case-blind');

      (* A LATER ROW FOR THE SAME CALL: the first row stands. *)
      CheckTrue(list.AddCallHistoryExchange('N6TV', '99 LAX') = charAlreadyKnown, 'second row: known');
      CheckEquals('72 SCV', list.GetIniitialExchange('N6TV'), 'the first row''s text');

      (* A LOGGED QSO REPLACES THE FILE'S TEXT, and the mark goes. *)
      list.AddIniitialExchange('N6TV', '72 LAX');
      CheckEquals('72 LAX', list.GetIniitialExchange('N6TV'), 'the log''s text');
      CheckFalse(list.InitialExchangeIsFromCallHistory('N6TV'), 'no longer the file''s');

      (* A CALL THE LIST HOLDS WITH NO EXCHANGE (worked, nothing remembered)
         takes the file's. *)
      list.AddCallsign('W7ST', CW, Band20, True);
      CheckTrue(list.AddCallHistoryExchange('W7ST', '18 UT') = charAdded, 'an empty entry takes it');
      CheckFalse(list.InitialExchangeIsFromCallHistory('K1AR'), 'an unknown call is not the file''s');
   finally
      list.Free;
   end;
end;

procedure TCallHistoryTests.Test_Loader_SettingOffMissingFileAndOtherContest;
var
   savedList: TCallsignsList;
   savedContest: TContestHandle;
   savedUse: boolean;
   savedName: string;
   defaults: TContestSettings;
begin
   BeginTest('Test_Loader_SettingOffMissingFileAndOtherContest');
   savedList := CallsignsList;
   savedContest := Contest;
   savedUse := Settings.Contest.UseCallHistoryFile;
   savedName := Settings.Contest.CallHistoryFilename;
   CallsignsList := TCallsignsList.Create;
   try
      Contest := ContestHandleOf(ARRLSSCW);
      Settings.Contest.CallHistoryFilename := FixturePath;

      (* OFF BY DEFAULT, and off reads nothing. *)
      defaults := TContestSettings.Create;
      try
         CheckFalse(defaults.UseCallHistoryFile, 'the default is off');
         CheckEquals('', defaults.CallHistoryFilename, 'and names no file');
      finally
         defaults.Free;
      end;
      Settings.Contest.UseCallHistoryFile := False;
      CheckEquals(0, LoadCallHistoryFile, 'off: nothing loaded');
      CheckEquals(0, CallsignsList.Count, 'off: the list is empty');

      (* A FILE THAT IS NOT THERE: nothing, and no exception. *)
      Settings.Contest.UseCallHistoryFile := True;
      Settings.Contest.CallHistoryFilename := FixturePath + '.missing';
      CheckEquals(0, LoadCallHistoryFile, 'missing file: nothing loaded');
      (* NO NAME: the contest's default, ARRL-SS-CW.txt, and its legacy
         SSCW.txt, which no CallHistoryFiles folder beside the test program
         holds. *)
      Settings.Contest.CallHistoryFilename := '';
      CheckEquals(0, LoadCallHistoryFile, 'no name, the default not there: nothing loaded');
      CheckEquals(0, CallsignsList.Count, 'missing file: the list is empty');

      (* A CONTEST THAT PREFILLS NOTHING reads no file. *)
      Settings.Contest.CallHistoryFilename := FixturePath;
      Contest := ContestHandleOf(CQWWCW);
      CheckEquals(0, LoadCallHistoryFile, 'CQ WW: nothing loaded');
      CheckEquals(0, CallsignsList.Count, 'CQ WW: the list is empty');
   finally
      CallsignsList.Free;
      CallsignsList := savedList;
      Contest := savedContest;
      Settings.Contest.UseCallHistoryFile := savedUse;
      Settings.Contest.CallHistoryFilename := savedName;
   end;
end;

procedure TCallHistoryTests.Test_Loader_FillsTheStoreForSweepstakes;
var
   savedList: TCallsignsList;
   savedContest: TContestHandle;
   savedUse: boolean;
   savedName: string;
begin
   BeginTest('Test_Loader_FillsTheStoreForSweepstakes');
   CheckTrue(FileExists(FixturePath), 'the fixture is there: ' + FixturePath);
   savedList := CallsignsList;
   savedContest := Contest;
   savedUse := Settings.Contest.UseCallHistoryFile;
   savedName := Settings.Contest.CallHistoryFilename;
   CallsignsList := TCallsignsList.Create;
   try
      Contest := ContestHandleOf(ARRLSSSSB);
      Settings.Contest.UseCallHistoryFile := True;
      Settings.Contest.CallHistoryFilename := FixturePath;
      (* INITIAL.EX, loaded first, knows NY4I. *)
      CallsignsList.AddIniitialExchange('NY4I', '80 NFL');

      CheckEquals(7, LoadCallHistoryFile,
                  'N6TV N4AF 4U1WB AA0A AA1RB added, KK6L and K1IEB added partial; NY4I known; N4AF''s second row known');
      CheckEquals('72 SCV', CallsignsList.GetIniitialExchange('N6TV'), 'N6TV');
      CheckEquals('58 NC', CallsignsList.GetIniitialExchange('N4AF'), 'N4AF: the first of its two rows');
      CheckEquals('08 VA', CallsignsList.GetIniitialExchange('AA1RB'), 'a one-digit CK, padded');
      CheckEquals('80 NFL', CallsignsList.GetIniitialExchange('NY4I'), 'INITIAL.EX''s entry stands');
      CheckFalse(CallsignsList.InitialExchangeIsFromCallHistory('NY4I'), 'and is not the file''s');
      CheckTrue(CallsignsList.InitialExchangeIsFromCallHistory('N6TV'), 'N6TV is the file''s');
      CheckEquals('95', CallsignsList.GetIniitialExchange('KK6L'), 'no Sect: the check alone');
      CheckEquals('AZ', CallsignsList.GetIniitialExchange('K1IEB'), 'CK -1: the section alone');

      (* THE LOG AFTER IT REPLACES THE FILE'S TEXT -- the loader's own call. *)
      CallsignsList.AddIniitialExchange('N6TV', '72 LAX');
      CheckEquals('72 LAX', CallsignsList.GetIniitialExchange('N6TV'), 'a logged QSO wins');
   finally
      CallsignsList.Free;
      CallsignsList := savedList;
      Contest := savedContest;
      Settings.Contest.UseCallHistoryFile := savedUse;
      Settings.Contest.CallHistoryFilename := savedName;
   end;
end;

(* THE COST OF A LARGE FILE: ~25,000 rows and ~224 KB, the size of NY4I's
   SSCW.txt doubled, written to the temp directory and read through the real
   path (ReadCallHistoryLines, ReadAll into a CallsignsList). Twice: in call
   order, as the files are kept, and shuffled -- the list is sorted, so an
   out-of-order row is an insertion in the middle. A BOUND, NOT A BENCHMARK:
   it fails only if the cost goes out of order; the times are printed. *)
procedure TCallHistoryTests.Test_Cost_ALargeFileLoadsQuickly;
const
   ROWS = 25000;
   SECTIONS: array[0..7] of string = ('NC', 'SCV', 'WCF', 'MO', 'EMA', 'NLI', 'STX', 'VA');
var
   lines: TStringList;
   path: string;
   i, j: integer;
   swap: AnsiString;
   pass: integer;
   started, readMs, totalMs: QWord;
   reader: TCallHistoryReader;
   savedList: TCallsignsList;
   bytes: Int64;
   info: TSearchRec;
   savedSeed: Cardinal;
begin
   BeginTest('Test_Cost_ALargeFileLoadsQuickly');
   path := string(GetTempDir(False)) + 'tr4w_callhistory_cost_' + IntToStr(GetProcessID) + '.txt';
   savedList := CallsignsList;
   lines := TStringList.Create;
   try
      for pass := 0 to 1 do
         begin
         lines.Clear;
         lines.Add('!!Order!!,Call,Sect,State,CK,Exch1,');
         for i := 0 to ROWS - 1 do
            begin
            (* K0A .. calls in sorted order, Sect, State, a check. *)
            lines.Add(AnsiString('W' + string(IntToStr(i mod 10)) +
                      Chr(Ord('A') + (i div 10) mod 26) + Chr(Ord('A') + (i div 260) mod 26) +
                      Chr(Ord('A') + (i div 6760) mod 26) + ',' +
                      SECTIONS[i mod 8] + ',ST,' + string(IntToStr(i mod 100)) + ','));
            end;
         if pass = 1 then
            begin
            savedSeed := RandSeed;
            RandSeed := 20261107;
            for i := lines.Count - 1 downto 2 do
               begin
               j := 1 + Random(i);
               swap := lines[i];
               lines[i] := lines[j];
               lines[j] := swap;
               end;
            RandSeed := savedSeed;
            end;
         lines.SaveToFile(AnsiString(path));
         bytes := 0;
         if FindFirst(AnsiString(path), faAnyFile, info) = 0 then
            begin
            bytes := info.Size;
            FindClose(info);
            end;

         CallsignsList := TCallsignsList.Create;
         reader := TCallHistoryReader.Create;
         try
            started := GetTickCount64;
            lines.Clear;
            CheckTrue(ReadCallHistoryLines(path, lines), 'the file reads');
            readMs := GetTickCount64 - started;
            reader.ReadAll(lines, SweepstakesFields, CallHistoryIntoCallsignsList);
            totalMs := GetTickCount64 - started;
            CheckEquals(ROWS, reader.DataRows, 'every row read');
            CheckTrue(reader.Added > 0, 'rows stored');
            WriteLn('  [CallHistory cost] ', BoolToStr(pass = 1, 'shuffled', 'in call order'), ': ',
                    reader.DataRows, ' rows, ', bytes, ' bytes, ', reader.Added, ' stored: read ',
                    readMs, ' ms, total ', totalMs, ' ms');
            CheckTrue(totalMs < 5000, string(IntToStr(ROWS)) + ' rows took ' + string(IntToStr(totalMs)) + ' ms');
         finally
            reader.Free;
            CallsignsList.Free;
            CallsignsList := savedList;
         end;
         end;
   finally
      lines.Free;
      DeleteFile(path);
   end;
end;

(* FLUSH INITIAL EX WRITES THE LOG'S ENTRIES AND NOT THE FILE'S: written into
   INITIAL.EX, a history entry would come back next open as the operator's
   own and outrank a spot comment. *)
procedure TCallHistoryTests.Test_FlushInitialExSkipsCallHistoryEntries;
var
   savedList: TCallsignsList;
   path: string;
   written: TStringList;
begin
   BeginTest('Test_FlushInitialExSkipsCallHistoryEntries');
   path := string(GetTempDir(False)) + 'tr4w_callhistory_flush_' + IntToStr(GetProcessID) + '.ex';
   savedList := CallsignsList;
   CallsignsList := TCallsignsList.Create;
   written := TStringList.Create;
   try
      CallsignsList.AddIniitialExchange('N4AF', '58 NC');
      CallsignsList.AddCallHistoryExchange('N6TV', '72 SCV');
      GenerateCallsignsList(path);
      written.LoadFromFile(AnsiString(path));
      CheckTrue(Pos('N4AF', string(written.Text)) > 0, 'the log''s entry is written');
      CheckTrue(Pos('58 NC', string(written.Text)) > 0, 'with its exchange');
      CheckTrue(Pos('N6TV', string(written.Text)) = 0, 'the call history file''s entry is not');
   finally
      written.Free;
      CallsignsList.Free;
      CallsignsList := savedList;
      DeleteFile(AnsiString(path));
   end;
end;

procedure TCallHistoryTests.Test_Path_BareNameAndFullPath;
begin
   BeginTest('Test_Path_BareNameAndFullPath');
   CheckEquals('', CallHistoryFilePath(''), 'no name, no path');
   CheckEquals(FixturePath, CallHistoryFilePath(FixturePath), 'a full path is used as it is');
   CheckTrue(Pos(CALL_HISTORY_FOLDER + PathDelim, CallHistoryFilePath('SSCW.txt')) > 0,
             'a bare name is looked for in the CallHistoryFiles folder: ' +
             CallHistoryFilePath('SSCW.txt'));
end;

(* WHAT PREFERENCES' BROWSE STORES (CallHistoryNameToStore): the bare name
   when the lookup brings that name back to the file picked, else the full
   path -- and either way the program then opens the file picked. The decision
   is pinned on given paths (CallHistoryStoredName), the wrapper on the real
   lookup without writing a file: a name in no CallHistoryFiles folder
   resolves beside the program, which is exactly where it was "picked". *)
procedure TCallHistoryTests.Test_Browse_StoresABareNameOnlyWhenItFindsThePickedFile;
var
   folder, picked, other, stored: string;
   savedContest: TContestHandle;
begin
   BeginTest('Test_Browse_StoresABareNameOnlyWhenItFindsThePickedFile');
   folder := string(GetTempDir(False)) + CALL_HISTORY_FOLDER + PathDelim;
   picked := folder + 'SSCW.txt';
   other  := string(GetTempDir(False)) + 'elsewhere' + PathDelim + 'SSCW.txt';

   CheckEquals('', CallHistoryStoredName('', picked), 'nothing picked, nothing stored');
   CheckEquals('SSCW.txt', CallHistoryStoredName(picked, picked),
               'the bare name finds the picked file: stored bare');
   CheckEquals(picked, CallHistoryStoredName(picked, other),
               'the bare name finds ANOTHER file (a same-named copy shadows it): the full path');
   CheckEquals(picked, CallHistoryStoredName(picked, ''), 'no lookup answer: the full path');
{$IFDEF WINDOWS}
   CheckEquals('SSCW.txt', CallHistoryStoredName(picked, UpperCase(picked)),
               'Windows file names are case-blind');
{$ENDIF}

   (* THE REAL LOOKUP. *)
   picked := CallHistoryFilePath('tr4w_no_such_call_history.txt');
   stored := CallHistoryNameToStore(picked);
   CheckEquals('tr4w_no_such_call_history.txt', stored,
               'a file in the CallHistoryFiles folder is stored bare: ' + picked);
   CheckEquals(picked, CallHistoryFilePath(stored), 'and the bare name finds it again');

   stored := CallHistoryNameToStore(FixturePath);
   CheckEquals(FixturePath, stored, 'a file anywhere else keeps its path');
   CheckEquals(FixturePath, CallHistoryFilePath(stored), 'and is opened as picked');

   (* THE BLANK BOX'S HINT is the contest's own default. *)
   savedContest := Contest;
   try
      Contest := ContestHandleOf(ARRLSSCW);
      CheckEquals('ARRL-SS-CW.txt', ContestCallHistoryFileName, 'SS CW: the default the loader reads');
      Contest := ContestHandleOf(CQWWCW);
      CheckEquals('', ContestCallHistoryFileName, 'CQ WW: none');
   finally
      Contest := savedContest;
   end;
end;

procedure TCallHistoryTests.RunAllTests;
begin
   gCollected := TStringList.Create;
   try
      Test_Reader_OrderDirective;
      Test_Reader_DefaultOrderAndSemicolons;
      Test_Reader_CommentsBlankAndShortRows;
      Test_Reader_CheckAndTruncation;
      Test_Reader_UnknownDirectiveIsIgnoredAndNamed;
      Test_Reader_OrderMayChangeMidFile;
      Test_ExchangeText_SweepstakesShape;
      Test_Reader_BothPublishedLayoutsGiveOnePrefill;
      Test_EveryContestStatesItsCallHistoryFields;
      Test_SiteLayoutsGiveTheRememberedText;
      Test_APartialRowPrefillsWhatItHas;
      Test_Store_KnownEntryIsKeptAndALoggedQSOReplaces;
      Test_Loader_SettingOffMissingFileAndOtherContest;
      Test_Loader_FillsTheStoreForSweepstakes;
      Test_Path_BareNameAndFullPath;
      Test_Browse_StoresABareNameOnlyWhenItFindsThePickedFile;
      Test_Cost_ALargeFileLoadsQuickly;
      Test_FlushInitialExSkipsCallHistoryEntries;
   finally
      FreeAndNil(gCollected);
   end;
end;

end.
