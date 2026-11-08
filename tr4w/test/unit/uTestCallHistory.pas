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
      CheckEquals(5, gCollected.Count, 'five complete rows');
      CheckEquals('NY4I=80 WCF', string(gCollected[0]), 'NY4I');
      CheckEquals('N6TV=72 SCV', string(gCollected[1]), 'N6TV');
      CheckEquals('N4AF=58 NC', string(gCollected[2]), 'N4AF');
      CheckEquals('4U1WB=89 MDC', string(gCollected[3]), 'Sect MDC, not State DC');
      CheckEquals('AA0A=60 MO', string(gCollected[4]), 'Exch1 is not asked');
      CheckEquals(7, reader.DataRows, 'seven rows with a call');
      CheckEquals(2, reader.Incomplete, 'no Sect (KK6L) and no CK (K0QL): not prefilled');
      CheckEquals(5, reader.Added, 'the store took five');
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
      CheckEquals(2, gCollected.Count, 'two rows carry both the check and the section');
      CheckEquals('4U1WB=89 MDC', string(gCollected[0]), 'the site''s layout: 4U1WB, the same text');
      CheckEquals('AA0AO=14 MN', string(gCollected[1]), 'a blank precedence does not matter');
      CheckEquals(5, reader.DataRows, 'five rows');
      CheckEquals(3, reader.Incomplete, 'no check (AA0YY), no section (AE2NY), neither (K1IP)');
      reader.ReadLine('4U1WB,U,89,MDC,', values);
      CheckEquals('U', values[chfExch1], 'the precedence is read into Exch1, ready for a class that asks it');
   finally
      reader.Free;
   end;
end;

(* EVERY REGISTERED CONTEST STATES WHAT IT PREFILLS: Sweepstakes in both
   modes CK then Sect, every other contest nothing. A contest that starts
   using a call history adds itself here. *)
procedure TCallHistoryTests.Test_EveryContestStatesItsCallHistoryFields;
var
   contests: TContestIdentityList;
   k: integer;
   fields: TCallHistoryFields;
   isSweepstakes: boolean;
begin
   BeginTest('Test_EveryContestStatesItsCallHistoryFields');
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      fields := contests[k].CallHistoryFields;
      isSweepstakes := IsLegacyContest(contests[k], ARRLSSCW) or
                       IsLegacyContest(contests[k], ARRLSSSSB);
      if IsLegacyContest(contests[k], ARRLSSCW) then
         begin
         CheckEquals('ARRL-SS-CW.txt', contests[k].CallHistoryFileName, 'SS CW''s default file: the site''s name');
         CheckEquals('ARRL-SS-CW', contests[k].CallHistorySiteName, 'SS CW''s site file');
         CheckEquals('SSCW.txt', contests[k].CallHistoryLegacyFileName, 'SS CW''s legacy file: N1MM''s name');
         end
      else if IsLegacyContest(contests[k], ARRLSSSSB) then
         begin
         CheckEquals('ARRL-SS-SSB.txt', contests[k].CallHistoryFileName, 'SS SSB''s default file: the site''s name');
         CheckEquals('ARRL-SS-SSB', contests[k].CallHistorySiteName, 'SS SSB''s site file');
         CheckEquals('SSSSB.txt', contests[k].CallHistoryLegacyFileName, 'SS SSB''s legacy file: N1MM''s name');
         end
      else
         begin
         CheckEquals('', contests[k].CallHistoryFileName, ContestWho(contests[k]) + ' names no default file');
         CheckEquals('', contests[k].CallHistorySiteName, ContestWho(contests[k]) + ' has no site file');
         CheckEquals('', contests[k].CallHistoryLegacyFileName, ContestWho(contests[k]) + ' has no legacy file');
         end;
      (* THE INVARIANT: a site file is offered only for a contest that can read
         it, and the default name follows the site's, and the SS site name IS
         the Cabrillo name. *)
      if contests[k].CallHistorySiteName <> '' then
         begin
         CheckTrue(Length(fields) > 0, ContestWho(contests[k]) + ': a site file needs fields to prefill');
         CheckEquals(contests[k].CallHistorySiteName + '.txt', contests[k].CallHistoryFileName,
                     ContestWho(contests[k]) + ': the default file follows the site name');
         end;
      if isSweepstakes then
         begin
         CheckEquals(contests[k].CabrilloName, contests[k].CallHistorySiteName,
                     ContestWho(contests[k]) + ': the site name is the Cabrillo name');
         end;
      if isSweepstakes then
         begin
         CheckEquals(2, Length(fields), ContestWho(contests[k]) + ' prefills two fields');
         if Length(fields) = 2 then
            begin
            CheckTrue(fields[0] = chfCK, ContestWho(contests[k]) + ': the check first');
            CheckTrue(fields[1] = chfSect, ContestWho(contests[k]) + ': then the section');
            end;
         end
      else
         begin
         CheckEquals(0, Length(fields), ContestWho(contests[k]) + ' uses no call history');
         end;
      end;
   (* "No contest" too. *)
   CheckEquals(0, Length(ContestIdentity(NoContest).CallHistoryFields), 'no contest: none');
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

      CheckEquals(5, LoadCallHistoryFile,
                  'N6TV N4AF 4U1WB AA0A AA1RB added; NY4I known; KK6L K1IEB incomplete; N4AF''s second row known');
      CheckEquals('72 SCV', CallsignsList.GetIniitialExchange('N6TV'), 'N6TV');
      CheckEquals('58 NC', CallsignsList.GetIniitialExchange('N4AF'), 'N4AF: the first of its two rows');
      CheckEquals('08 VA', CallsignsList.GetIniitialExchange('AA1RB'), 'a one-digit CK, padded');
      CheckEquals('80 NFL', CallsignsList.GetIniitialExchange('NY4I'), 'INITIAL.EX''s entry stands');
      CheckFalse(CallsignsList.InitialExchangeIsFromCallHistory('NY4I'), 'and is not the file''s');
      CheckTrue(CallsignsList.InitialExchangeIsFromCallHistory('N6TV'), 'N6TV is the file''s');
      CheckEquals('', CallsignsList.GetIniitialExchange('KK6L'), 'no Sect: not prefilled');
      CheckEquals('', CallsignsList.GetIniitialExchange('K1IEB'), 'CK -1: not prefilled');

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
