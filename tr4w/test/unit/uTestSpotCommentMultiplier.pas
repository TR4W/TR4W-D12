(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* A SPOT'S SECTION FROM ITS COMMENT -- issue 83, 2026-11-05.

  NY4I's ruling: with CLUSTER SPOT COMMENT MULTIPLIER on, a spot such as
  `7037.0 K1DW CW 11 dB 14 WPM CQ NTX` is shown as a needed multiplier when
  NTX is one. THREE LAYERS, each pinned where it lives:

    * the TOKENIZER (uDXSpotParse.SpotCommentCandidates), pure -- from real
      AR-Cluster comments NY4I pasted into the issue and real lines of the
      198,979-line capture corpus, parsed through ParseDXSpotLine so the 30
      comment columns that survive are what is tokenized;
    * the CONTEST-FACING STEP (LogEdit.SpotSectionHint) -- the domestic file
      of the contest decides which word is a section, the call history
      overrules the comment, a contest with no domestic file and a DX station
      get nothing. ARRL Sweepstakes (arrlsect.dom) is the contest;
    * the MULTIPLIER (DetermineIfNewMult / DetermineIfNewSpotMult) through the
      real sheet. THE KEY IS THE ONE THE MULTIPLIER LIST HOLDS, arrlsect.dom's
      `Ut = UT` is 'Ut': a hint spelt as typed misses the list and answers
      "needed on every band", which a test of an UNWORKED section cannot see.
      So the section is WORKED first and must then be NOT needed.

  THE ENGINE STATE EACH TEST CHANGES IS SAVED AND PUT BACK, as
  uTestExchangeWordOrder does. *)
unit uTestSpotCommentMultiplier;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSpotCommentMultiplierTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Tokens_RealCommentsFromTheIssue;
      procedure Test_Tokens_RulesOfTheRuling;
      procedure Test_Tokens_ParsedFromRealClusterLines;
      procedure Test_ShortHistoryLayoutIsNotASpot;
      procedure Test_Hint_EachSectionOfTheIssue;
      procedure Test_Hint_FirstWinsAndExtensionIsLast;
      procedure Test_Hint_NoOpinionCases;
      procedure Test_Hint_ContestWithoutADomesticFileGetsNone;
      procedure Test_Hint_OurOwnKnowledgeOverrulesTheComment;
      procedure Test_Mult_WorkedSectionIsNotNeededAndUnworkedIs;
      procedure Test_Mult_SpotRoutineAndTheSetting;
      procedure Test_Mult_CallHistoryOverridesADifferingComment;
      procedure Test_Key_DomesticKeyOfQTHIsTheListsSpelling;
      procedure Test_Cost_HintForAWholeBandMapIsCheap;
      procedure Test_Worked_PerBandMultiplier;
      procedure Test_Worked_SweepstakesCountsOnceAcrossBands;
      procedure Test_Worked_SpotStoreNeverFlagsADupeOrANeededMult;
      procedure Test_Worked_ColourToken;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uDXSpotParse,
   (* mo -- the multiplier sheet's store. *)
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit,
   (* SpotsList, WorkedMultColorOf -- issue 12. *)
   uSpots;

const
   (* REAL LINES of corpus_test_data/local_test_data/dxcluster, byte for byte. *)
   //         0         1         2         3         4         5         6         7
   //         0123456789012345678901234567890123456789012345678901234567890123456789012345
   LINE_NFL    = 'DX de AC0C-1-#:   3552.0  WA4BAM       CW 24 dB 25 WPM CQ         NFL 0132Z';
   LINE_NYNLI  = 'DX de K2DB-#:    10113.0  WI2X         CW 9 DB 21 WPM CQ       NY-NLI 1646Z';
   LINE_BEACON = 'DX de NU4F-#:    28200.0  VE8AT        CW 3 DB 23 WPM NCDXF B         2225Z';
   LINE_LONGSP = 'DX de 3V/KF5EYY-#:14007.0  PA3DZM      CW 20 DB 33 WPM CQ          PA 1941Z';
   LINE_PLUS   = 'DX de KU7T-#:    14051.6  N4KM         CW 30 DB 33 WPM CQ    +-FL-NFL 2132Z';
   (* The `sh/dx` LAYOUT NY4I pasted: no "DX de", a date, the spotter at the end. *)
   LINE_SHDX   = '  7050.3  W4EDE       05-Nov-2026 0131Z  CW 13 dB 30 WPM CQ       NFL <W8WTS-#>';

var
   savedContest: TContestHandle;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedMyCountry: string;
   savedDomesticFilename: string;
   savedByBand: boolean;
   savedByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedSetting: boolean;

(* The candidates as one comma-separated string, so a case reads as the text
   it pins. *)
function Cands(const aComment: AnsiString): string;
var
   list: TSpotCommentCandidates;
   i: integer;
begin
   Result := '';
   SpotCommentCandidates(aComment, list);
   for i := Low(list) to High(list) do
      begin
      if Result <> '' then
         begin
         Result := Result + ',';
         end;
      Result := Result + string(list[i]);
      end;
end;

function LoadCountryFile: boolean;
var
   ctyPath: string;
begin
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   Result := ctyLoadInCountryFile(ctyPath, False, False, True);
end;

(* THE SESSION AS FoundContest SETS aContest UP, for what the hint reads: the
   contest, its domestic countries, its domestic file in the table and named
   in the setting, a station in the USA, and the multiplier sheet empty. *)
procedure SetUpSession(aContest: ContestType; const aCountries: array of string;
                       const aDomFile: string);
var
   i: integer;
begin
   savedContest := Contest;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedByBand := Settings.Mult.ByBand;
   savedByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedSetting := Settings.Cluster.SpotCommentMultiplier;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;

   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;

   DomesticCountries.Clear;
   for i := Low(aCountries) to High(aCountries) do
      begin
      DomesticCountries.Add(CallString(aCountries[i]));
      end;
   LoadShippedDomFollowingIncludes(DomQTHTable, aDomFile, True, 0);
   Settings.Contest.DomesticFilename := aDomFile;
   Settings.My.DeriveCountry('K');
   Settings.Mult.ByBand := True;
   Settings.Mult.ByMode := False;
   DomesticMultByBand := dmbbDefauld;
   Settings.Cluster.SpotCommentMultiplier := False;

   Contest := ContestHandleOf(aContest);
   ReleaseActiveContest;
   mo.ClearAllMults;
end;

procedure RestoreSession;
var
   i: integer;
begin
   mo.ClearAllMults;
   DomesticCountries.Clear;
   for i := 0 to savedCountries.Count - 1 do
      begin
      DomesticCountries.Add(CallString(savedCountries[i]));
      end;
   savedCountries.Free;
   QualifiedDupes.Free;
   QualifiedDupes := savedQualified;
   CallsignsList.Free;
   CallsignsList := savedList;
   DomQTHTable.Free;
   DomQTHTable := savedTable;
   Settings.Contest.DomesticFilename := savedDomesticFilename;
   Settings.My.DeriveCountry(savedMyCountry);
   Settings.Mult.ByBand := savedByBand;
   Settings.Mult.ByMode := savedByMode;
   DomesticMultByBand := savedDomesticByBand;
   Settings.Cluster.SpotCommentMultiplier := savedSetting;
   Contest := savedContest;
   ReleaseActiveContest;
end;

(* ONE QSO WORKED WITH aQTH, as logsubs2 logs it: the QTH through the domestic
   file (FoundDomesticQTH), then the sheet's flags, then the sheet marked. *)
procedure LogWorked(const aCall: string; const aQTH: string; aBand: BandType);
var
   rx: ContestExchange;
begin
   rx := Default(ContestExchange);
   rx.ceRecordKind := rkQSO;
   rx.Callsign := CallString(aCall);
   rx.Band := aBand;
   rx.Mode := CW;
   rx.Zone := DUMMYZONE;
   rx.QTHString := ShortString(aQTH);
   FoundDomesticQTH(rx);
   Sheet.SetMultFlags(rx);
   Sheet.AddQSOToSheets(@rx, False);
end;

procedure TSpotCommentMultiplierTests.Test_Tokens_RealCommentsFromTheIssue;
begin
   BeginTest('Test_Tokens_RealCommentsFromTheIssue');
   (* NY4I's sh/dx list, the comment as it stands before the spotter. *)
   CheckEquals('NFL', Cands('CW 13 dB 30 WPM CQ       NFL'), 'NFL');
   CheckEquals('NLI', Cands('CW 34 dB 27 WPM CQ       NLI'), 'NLI');
   CheckEquals('NLI', Cands('NLI'), 'NLI alone, no skimmer text');
   CheckEquals('NTX', Cands('CW 21 dB 14 WPM CQ       NTX'), 'NTX');
   CheckEquals('OH', Cands('CW 8 dB 17 WPM CQ         OH'), 'OH');
   CheckEquals('OK', Cands('CW 13 dB 28 WPM CQ        OK'), 'OK');
   CheckEquals('OR', Cands('CW 10 dB 21 WPM CQ        OR'), 'OR');
   CheckEquals('VT', Cands('CW 25 dB 18 WPM CQ        VT'), 'VT');
   (* NO SECTION: the spotter is never a word, the template words never are. *)
   CheckEquals('', Cands('CW 21 dB 14 WPM CQ           <AC0C-1-#>'), 'CQ <AC0C-1-#>');
   CheckEquals('', Cands('CQ <AC0C-1-#>'), 'CQ and a spotter');
   CheckEquals('', Cands('<NC-#>'), 'a spotter that looks like a section');
   CheckEquals('', Cands('CW 24 DB 25 WPM CQ'), 'the upper-case DB some nodes send');
   (* A BEACON HAS NONE -- its own section is the cluster's, not ours. *)
   CheckEquals('', Cands('CW 24 dB 22 WPM NCDXF B  SCV'), 'NCDXF B SCV');
   CheckEquals('', Cands('beacon NC'), 'BEACON in any case');
   CheckEquals('', Cands('NC BCN'), 'BCN after the section');
   (* THE EXTENSION FORM. *)
   CheckEquals('POTA,KFF-2726,NC,NC', Cands('POTA KFF-2726 NC         +NC'), 'plain words, then the + word');
   CheckEquals('MS', Cands('+MS'), '+MS alone');
end;

procedure TSpotCommentMultiplierTests.Test_Tokens_RulesOfTheRuling;
begin
   BeginTest('Test_Tokens_RulesOfTheRuling');
   (* FIRST IS FIRST: two sections stay in the order typed. *)
   CheckEquals('NFL,OR', Cands('NFL OR'), 'NFL OR');
   (* A + WORD COMES AFTER THE PLAIN ONES wherever it was typed. *)
   CheckEquals('OR,NC', Cands('+NC OR'), '+NC then a plain word');
   (* UPPER CASE ONLY. *)
   CheckEquals('', Cands('or in me dB'), 'prose');
   CheckEquals('', Cands('Or In Me'), 'capitalised is not upper case');
   CheckEquals('', Cands('+nc'), 'a lower-case extension');
   (* NUMBERS AND PUNCTUATION ALONE ARE NOT WORDS. *)
   CheckEquals('', Cands('25 + 14.025 -'), 'numbers, a bare plus');
   CheckEquals('', Cands('+ +'), 'a bare plus twice');
   (* EXACTLY ONE LEADING + IS REMOVED. *)
   CheckEquals('+NC', Cands('++NC'), 'a second plus stays and no file knows it');
   (* WHOLE WORDS: nothing is cut out of a longer word. *)
   CheckEquals('NY-NLI', Cands('NY-NLI'), 'NY-NLI is one word');
   CheckEquals('FL-NFL', Cands('FL-NFL'), 'FL-NFL is one word');
   CheckEquals('(TX)', Cands('(TX)'), '(TX) is one word');
   (* A SLASH WORD IS DROPPED -- the domestic lookup keeps what precedes it. *)
   CheckEquals('', Cands('NC/UT'), 'NC/UT');
   (* DX IS NOT A SECTION (several QSO-party files carry a DX alias). *)
   CheckEquals('', Cands('CQ DX'), 'CQ DX');
   CheckEquals('NC', Cands('DX NC'), 'DX is dropped, NC stays');
   CheckEquals('', Cands(''), 'an empty comment');
end;

procedure TSpotCommentMultiplierTests.Test_Tokens_ParsedFromRealClusterLines;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_Tokens_ParsedFromRealClusterLines');
   (* THE LIVE LINE NY4I'S LOCAL CLUSTER SENDS: the section is the last of the
      30 comment columns that survive (columns 39..68; it sits on 66..68). *)
   CheckTrue(ParseDXSpotLine(LINE_NFL, spot), 'the live line decodes');
   CheckEquals('WA4BAM', string(spot.FCall), 'the spotted call');
   CheckEquals('CW 24 dB 25 WPM CQ         NFL', string(SpotNotesText(spot)),
               'the 30 columns kept, to the last one');
   CheckEquals('NFL', Cands(SpotNotesText(spot)), 'the section');

   (* A LONG SPOTTER SHIFTS THE FREQUENCY (it lands on column 23, not 22) AND
      ParseDXSpotLine SHIFTS THE COMMENT WINDOW WITH IT, though the comment
      stays on column 39 -- so the FIRST comment column is dropped and the
      window ends one column late (69, a blank before the time). Here 'CW'
      reads 'W'. PINNED AS IT IS, not fixed: the column arithmetic is the
      decoder's, tuned against real nodes (see the unit header), and the
      section at the end is unaffected. A stray 'W' is a candidate no
      domestic file is likely to know; reported on issue 83. *)
   CheckTrue(ParseDXSpotLine(LINE_LONGSP, spot), 'the long-spotter line decodes');
   CheckEquals('W 20 DB 33 WPM CQ          PA ', string(SpotNotesText(spot)),
               'the first comment column is lost to the spotter''s offset');
   CheckEquals('W,PA', Cands(SpotNotesText(spot)), 'but the section at the end is read');

   CheckTrue(ParseDXSpotLine(LINE_NYNLI, spot), 'NY-NLI decodes');
   CheckEquals('NY-NLI', Cands(SpotNotesText(spot)), 'NY-NLI: one word, a section in no file');

   CheckTrue(ParseDXSpotLine(LINE_PLUS, spot), '+-FL-NFL decodes');
   CheckEquals('-FL-NFL', Cands(SpotNotesText(spot)), '+-FL-NFL: the plus is stripped, nothing more');

   CheckTrue(ParseDXSpotLine(LINE_BEACON, spot), 'the beacon decodes');
   CheckEquals('', Cands(SpotNotesText(spot)), 'a beacon');
end;

procedure TSpotCommentMultiplierTests.Test_ShortHistoryLayoutIsNotASpot;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_ShortHistoryLayoutIsNotASpot');
   (* THE sh/dx LAYOUT (no "DX de", a date and the spotter at the end) IS NEVER
      A SPOT TO THIS PROGRAM: uTelnet.ProcessTelnetLine hands ProcessDX only a
      line that begins 'DX de '. What the decoder would make of it is pinned so
      a change that starts feeding it the node's `SH/DX 50` reply is a
      decision rather than an accident. *)
   CheckFalse(ParseDXSpotLine(LINE_SHDX, spot), 'the sh/dx layout does not decode as a spot');
end;

procedure TSpotCommentMultiplierTests.Test_Hint_EachSectionOfTheIssue;
begin
   BeginTest('Test_Hint_EachSectionOfTheIssue');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckTrue(ContestUsesDomesticFile(ActiveContest(Contest)), 'Sweepstakes uses its domestic file');
      CheckEquals('NFL', UpperCase(SpotSectionHint('W4EDE', 'CW 13 dB 30 WPM CQ       NFL')), 'NFL');
      CheckEquals('NLI', UpperCase(SpotSectionHint('N2KW', 'CW 34 dB 27 WPM CQ       NLI')), 'NLI');
      CheckEquals('NTX', UpperCase(SpotSectionHint('K1DW', 'CW 21 dB 14 WPM CQ       NTX')), 'NTX');
      CheckEquals('OH', UpperCase(SpotSectionHint('KB8AZS', 'CW 8 dB 17 WPM CQ         OH')), 'OH');
      CheckEquals('OK', UpperCase(SpotSectionHint('W5CU', 'CW 13 dB 28 WPM CQ        OK')), 'OK');
      CheckEquals('OR', UpperCase(SpotSectionHint('WV1T', 'CW 10 dB 21 WPM CQ        OR')), 'OR');
      CheckEquals('VT', UpperCase(SpotSectionHint('KA1BSZ', 'CW 25 dB 18 WPM CQ        VT')), 'VT');
      CheckEquals('NC', UpperCase(SpotSectionHint('W4JL', 'POTA KFF-2726 NC         +NC')), 'POTA, a park, NC and +NC');
      CheckEquals('MS', UpperCase(SpotSectionHint('N8NOE', '+MS')), '+MS alone');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Hint_FirstWinsAndExtensionIsLast;
begin
   BeginTest('Test_Hint_FirstWinsAndExtensionIsLast');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckEquals('NFL', UpperCase(SpotSectionHint('W4EDE', 'NFL OR')), 'two sections: the first');
      CheckEquals('OR', UpperCase(SpotSectionHint('W4EDE', 'OR NFL')), 'and the other way round');
      (* A HAND-TYPED SECTION BEATS THE CLUSTER'S +EXTENSION that follows it
         (home QTH UT, operating from WY). *)
      CheckEquals('WY', UpperCase(SpotSectionHint('K7ABC', 'portable WY        +UT')), 'prose before WY is no candidate');
      CheckEquals('WY', UpperCase(SpotSectionHint('K7ABC', 'CQ WY        +UT')), 'WY before +UT');
      CheckEquals('WY', UpperCase(SpotSectionHint('K7ABC', '+UT CQ WY')), 'a + word only when no plain word qualifies');
      CheckEquals('UT', UpperCase(SpotSectionHint('K7ABC', 'CQ ZZ +UT')), 'ZZ is no section, so +UT is used');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Hint_NoOpinionCases;
begin
   BeginTest('Test_Hint_NoOpinionCases');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckEquals('', SpotSectionHint('W4EDE', 'CW 10 dB 21 WPM CQ           <AC0C-1-#>'), 'no section');
      CheckEquals('', SpotSectionHint('W4EDE', 'or in'), 'prose in lower case');
      CheckEquals('', SpotSectionHint('W6WX', 'CW 24 dB 22 WPM NCDXF B  SCV'), 'a beacon, whose section is its own');
      (* A BEACON'S CALL THE PROGRAM KNOWS IS STILL A BEACON: W6WX is the NCDXF
         beacon on 14100 and a contest station, so it can be in the history. *)
      CallsignsList.AddIniitialExchange('W6WX', '18 SCV');
      CheckEquals('', SpotSectionHint('W6WX', 'CW 24 dB 22 WPM NCDXF B  SCV'), 'a beacon with call history');
      CheckEquals('SCV', UpperCase(SpotSectionHint('W6WX', 'CW 24 dB 22 WPM CQ')), 'the same call, not a beacon');
      CheckTrue(SpotCommentIsABeacon('beacon'), 'the beacon test on its own');
      CheckFalse(SpotCommentIsABeacon('CW 24 dB 22 WPM CQ SCV'), 'and not a beacon');
      CheckEquals('', SpotSectionHint('W4EDE', 'CW 9 DB 21 WPM CQ       NY-NLI'), 'NY-NLI is one unknown word');
      CheckEquals('', SpotSectionHint('W4EDE', ''), 'no comment');
      (* A DX STATION SENDS NO SECTION, whatever its comment says. *)
      CheckEquals('', SpotSectionHint('DL1ABC', 'CW 13 dB 30 WPM CQ       NFL'), 'a station outside the domestic countries');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Hint_ContestWithoutADomesticFileGetsNone;
begin
   BeginTest('Test_Hint_ContestWithoutADomesticFileGetsNone');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   (* A GRID CONTEST: grids.dom knows AM, FM, DE, CQ and DB -- words a comment
      holds -- and the contest says it does not look its QTH up in that file,
      so it is not asked. THE CLASS DECIDES, NOT THE FILE THAT HAPPENS TO BE
      LOADED. *)
   SetUpSession(ARRLVHFJUN, [], 'grids.dom');
   try
      CheckFalse(ContestUsesDomesticFile(ActiveContest(Contest)), 'a grid contest has no domestic file');
      CheckEquals('', SpotSectionHint('W4EDE', 'DE AM FM'), 'words a grid file knows');
      CheckEquals('', SpotSectionHint('W4EDE', '+FM'), 'an extension a grid file knows');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Hint_OurOwnKnowledgeOverrulesTheComment;
begin
   BeginTest('Test_Hint_OurOwnKnowledgeOverrulesTheComment');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckEquals('NFL', UpperCase(SpotSectionHint('W7ST', 'CQ NFL')), 'the comment, before the log knows the station');
      (* W7ST sent '18 UT' -- the remembered exchange of the call history file
         or of a QSO already in the log. *)
      CallsignsList.AddIniitialExchange('W7ST', '18 UT');
      CheckEquals('UT', UpperCase(SpotSectionHint('W7ST', 'CQ NFL')), 'our knowledge wins over a differing comment');
      CheckEquals('UT', UpperCase(SpotSectionHint('W7ST', '')), 'and stands without a comment');
      (* A REMEMBERED EXCHANGE THAT NAMES NO SECTION IS NO ANSWER. *)
      CallsignsList.AddIniitialExchange('K1DW', '18');
      CheckEquals('NTX', UpperCase(SpotSectionHint('K1DW', 'CQ NTX')), 'a lone check falls through to the comment');
      (* AN ALIAS IS ITS MULTIPLIER (issue 207): WF is filed as WcF. *)
      CallsignsList.AddIniitialExchange('W1WF', '59 WF');
      CheckEquals('WcF', SpotSectionHint('W1WF', ''), 'the remembered alias gives the key as the list spells it');
   finally
      RestoreSession;
   end;

   (* A KEY THAT IS NOT ONE OF ITS OWN ALIASES (issue 207): michigan_cty.dom
      has 'Presq = PRES'. The remembered text maps to the key ONCE; mapping the
      key again (as the spot path did before the header and the spot hint
      shared one routine) would find nothing for 'Presq'. *)
   SetUpSession(MICHQSOPARTY, DomesticCountriesKVEKH6KL, 'michigan_cty.dom');
   try
      CallsignsList.AddIniitialExchange('K8PRE', 'PRES');
      CheckEquals('Presq', SpotSectionHint('K8PRE', ''), 'a key that does not map back to itself');
   finally
      RestoreSession;
   end;

   (* A NAME BEFORE THE QTH (issue 207): NAQP remembers name + state. *)
   SetUpSession(NAQSOCW, DomesticCountriesKVEKH6KL, 'naqp.dom');
   try
      CallsignsList.AddIniitialExchange('N6ABC', 'TOM CA');
      CheckEquals('CA', UpperCase(SpotSectionHint('N6ABC', 'CQ OR')), 'the state the log remembers, not the name');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Mult_WorkedSectionIsNotNeededAndUnworkedIs;
var
   hint: string;
begin
   BeginTest('Test_Mult_WorkedSectionIsNotNeededAndUnworkedIs');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      hint := SpotSectionHint('K1DW', 'CQ NTX');
      CheckTrue(hint <> '', 'the hint is a key');

      (* NO HINT: unchanged. Sweepstakes states no domestic multiplier for a
         call, so nothing is needed. *)
      CheckFalse(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW), 'no hint, nothing needed');
      CheckFalse(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW, ''), 'an empty hint is the same');
      (* UNWORKED: needed, on every band (the multipliers count per band). *)
      CheckTrue(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW, hint), 'unworked NTX is needed on 20 m');
      CheckTrue(VisibleLog.DetermineIfNewMult('K1DW', Band40, CW, hint), 'and on 40 m');

      (* WORKED ON 20 M: not needed there -- THIS is the test of the key's
         spelling: a hint the list does not hold is "needed on every band". *)
      LogWorked('W5XYZ', 'NTX', Band20);
      CheckFalse(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW, hint), 'NTX worked on 20 m is not needed on 20 m');
      CheckTrue(VisibleLog.DetermineIfNewMult('K1DW', Band40, CW, hint), 'NTX is still needed on 40 m');
      CheckTrue(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW, SpotSectionHint('K1DW', 'CQ NLI')),
                'another section is needed on 20 m');

      (* NOT PER BAND: a section worked anywhere is worked. *)
      mo.ClearAllMults;
      Settings.Mult.ByBand := False;
      CheckTrue(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW, hint), 'not per band, unworked');
      LogWorked('W5XYZ', 'NTX', Band20);
      CheckFalse(VisibleLog.DetermineIfNewMult('K1DW', Band20, CW, hint), 'not per band, worked on 20 m');
      CheckFalse(VisibleLog.DetermineIfNewMult('K1DW', Band40, CW, hint), 'and so worked on 40 m');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Mult_SpotRoutineAndTheSetting;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_Mult_SpotRoutineAndTheSetting');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckTrue(ParseDXSpotLine('DX de AC0C-1-#:   7037.0  K1DW        CW 21 dB 14 WPM CQ         NTX 0127Z', spot),
                'the spot decodes');
      spot.FBand := Band40;
      spot.FMode := CW;

      (* THE SETTING IS OFF BY DEFAULT: the comment changes nothing. *)
      CheckFalse(Settings.Cluster.SpotCommentMultiplier, 'off by default');
      CheckFalse(VisibleLog.DetermineIfNewSpotMult(spot), 'off: not a multiplier');

      Settings.Cluster.SpotCommentMultiplier := True;
      CheckTrue(VisibleLog.DetermineIfNewSpotMult(spot), 'on: NTX is needed on 40 m');
      LogWorked('W5XYZ', 'NTX', Band40);
      CheckFalse(VisibleLog.DetermineIfNewSpotMult(spot), 'on, NTX worked on 40 m: not needed');
      spot.FBand := Band20;
      CheckTrue(VisibleLog.DetermineIfNewSpotMult(spot), 'on, and still needed on 20 m');

      Settings.Cluster.SpotCommentMultiplier := False;
      CheckFalse(VisibleLog.DetermineIfNewSpotMult(spot), 'off again: unchanged');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Mult_CallHistoryOverridesADifferingComment;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_Mult_CallHistoryOverridesADifferingComment');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      Settings.Cluster.SpotCommentMultiplier := True;
      CheckTrue(ParseDXSpotLine('DX de AC0C-1-#:   7037.0  W7ST        CW 21 dB 14 WPM CQ         NTX 0127Z', spot),
                'the spot decodes');
      spot.FBand := Band40;
      spot.FMode := CW;
      LogWorked('W5XYZ', 'UT', Band40);

      CheckTrue(VisibleLog.DetermineIfNewSpotMult(spot), 'the comment says NTX: unworked, needed');
      (* W7ST is known to be in UT, which is worked on 40 m. *)
      CallsignsList.AddIniitialExchange('W7ST', '18 UT');
      CheckFalse(VisibleLog.DetermineIfNewSpotMult(spot), 'our knowledge says UT, worked: NOT needed');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Cost_HintForAWholeBandMapIsCheap;
var
   i: integer;
   started: QWord;
   elapsed: QWord;
   spot: TSpotRecord;
begin
   BeginTest('Test_Cost_HintForAWholeBandMapIsCheap');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      Settings.Cluster.SpotCommentMultiplier := True;
      CheckTrue(ParseDXSpotLine('DX de AC0C-1-#:   7037.0  K1DW        CW 21 dB 14 WPM CQ         NTX 0127Z', spot),
                'the spot decodes');
      spot.FBand := Band40;
      spot.FMode := CW;
      (* UpdateSpotsMultiplierStatus asks this of every spot on the band map on
         every log change, on the main thread. 500 spots is a crowded map, so
         5000 asks is ten refreshes of one. *)
      started := GetTickCount64;
      for i := 1 to 5000 do
         begin
         VisibleLog.DetermineIfNewSpotMult(spot);
         end;
      elapsed := GetTickCount64 - started;
      (* A BOUND, NOT A BENCHMARK: it fails only if the cost goes out of order.
         MEASURED 2026-11-05, i386, unit-test build: 31 ms for the 5000 -- about
         6 microseconds a spot, so a 500-spot map is ~3 ms per log change. *)
      CheckTrue(elapsed < 2000, '5000 hints took ' + IntToStr(elapsed) + ' ms');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Key_DomesticKeyOfQTHIsTheListsSpelling;
var
   key: string;
begin
   BeginTest('Test_Key_DomesticKeyOfQTHIsTheListsSpelling');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* arrlsect.dom: `Ut = UT`. The key is the left side, whatever case it
         was asked in, and an alias asked answers the section's key. *)
      CheckTrue(DomesticKeyOfQTH('UT', key), 'UT is known');
      CheckEquals('Ut', key, 'and its key is the file''s spelling');
      CheckTrue(DomesticKeyOfQTH('ut', key), 'in lower case');
      CheckEquals('Ut', key, 'the same key');
      CheckTrue(DomesticKeyOfQTH('PQ', key), 'an alias: PQ');
      CheckEquals('Qc', key, 'answers the section it belongs to');
      CheckFalse(DomesticKeyOfQTH('ZZ', key), 'a word the file does not know');
      CheckEquals('', key, 'with no key');
      CheckFalse(DomesticKeyOfQTH('', key), 'nothing');
      (* DomesticTableKnowsQTH is the same answer without the key. *)
      CheckTrue(DomesticTableKnowsQTH('UT'), 'knows UT');
      CheckFalse(DomesticTableKnowsQTH('ZZ'), 'does not know ZZ');
   finally
      RestoreSession;
   end;
end;

(* ISSUE 12: A WORKED MULTIPLIER ON A CALL THAT IS NOT A DUPE -- a backup.

   NEEDED and WORKED are the two answers of one routine, DetermineMultStatus,
   so they cannot both be True; and a call whose multiplier cannot be named at
   all is NEITHER, which is the case a plain "not needed" would get wrong. *)
procedure TSpotCommentMultiplierTests.Test_Worked_PerBandMultiplier;
var
   hint: string;
   needed: boolean;
   worked: boolean;
begin
   BeginTest('Test_Worked_PerBandMultiplier');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      hint := SpotSectionHint('K1DW', 'CQ NTX');
      CheckTrue(hint <> '', 'the hint is a key');

      (* NEW MULT: needed, so not flagged worked. *)
      VisibleLog.DetermineMultStatus('K1DW', Band20, CW, hint, needed, worked);
      CheckTrue(needed, 'unworked NTX is needed on 20 m');
      CheckFalse(worked, 'and so is not a backup');
      CheckFalse(VisibleLog.DetermineIfWorkedMult('K1DW', Band20, CW, hint), 'DetermineIfWorkedMult agrees');

      (* NO MULTIPLIER NAMED: neither. The empty hint is Sweepstakes with no
         comment and no call history -- "not needed" is true and "worked" is not. *)
      VisibleLog.DetermineMultStatus('K1DW', Band20, CW, '', needed, worked);
      CheckFalse(needed, 'no hint: not needed');
      CheckFalse(worked, 'no hint: and NOT worked either');

      (* WORKED ON 20 M, PER BAND: a backup on 20 m, and still NEEDED on 40 m. *)
      LogWorked('W5XYZ', 'NTX', Band20);
      VisibleLog.DetermineMultStatus('K1DW', Band20, CW, hint, needed, worked);
      CheckFalse(needed, 'NTX worked on 20 m is not needed there');
      CheckTrue(worked, 'NTX worked on 20 m: a backup on 20 m');
      CheckTrue(VisibleLog.DetermineIfWorkedMult('K1DW', Band20, CW, hint), 'DetermineIfWorkedMult agrees');
      VisibleLog.DetermineMultStatus('K1DW', Band40, CW, hint, needed, worked);
      CheckTrue(needed, 'NTX is still needed on 40 m');
      CheckFalse(worked, 'and is not a backup there');
      (* ANOTHER SECTION IS UNAFFECTED. *)
      VisibleLog.DetermineMultStatus('K1DW', Band20, CW, SpotSectionHint('K1DW', 'CQ NLI'), needed, worked);
      CheckTrue(needed, 'NLI is needed on 20 m');
      CheckFalse(worked, 'NLI is not worked');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Worked_SweepstakesCountsOnceAcrossBands;
var
   hint: string;
   needed: boolean;
   worked: boolean;
begin
   BeginTest('Test_Worked_SweepstakesCountsOnceAcrossBands');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* THE SESSION CAN SAY PER BAND; SWEEPSTAKES DOES NOT: its contest class
         states no cfMultByBand, so FoundContest leaves Settings.Mult.ByBand
         False. Set it as the contest does. *)
      Settings.Mult.ByBand := False;
      hint := SpotSectionHint('K1DW', 'CQ NTX');

      VisibleLog.DetermineMultStatus('K1DW', Band40, CW, hint, needed, worked);
      CheckTrue(needed, 'unworked: needed');
      CheckFalse(worked, 'unworked: not a backup');

      LogWorked('W5XYZ', 'NTX', Band20);
      VisibleLog.DetermineMultStatus('K1DW', Band20, CW, hint, needed, worked);
      CheckFalse(needed, 'worked on 20 m: not needed on 20 m');
      CheckTrue(worked, 'worked on 20 m: a backup on 20 m');
      (* ONCE PER CONTEST: the section worked on 20 m is a backup on 40 m and
         on 10 m too, and is never needed again. *)
      VisibleLog.DetermineMultStatus('K1DW', Band40, CW, hint, needed, worked);
      CheckFalse(needed, 'and not needed on 40 m');
      CheckTrue(worked, 'a backup on 40 m');
      VisibleLog.DetermineMultStatus('K1DW', Band10, CW, hint, needed, worked);
      CheckFalse(needed, 'and not needed on 10 m');
      CheckTrue(worked, 'a backup on 10 m');
   finally
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Worked_SpotStoreNeverFlagsADupeOrANeededMult;
var
   spot: TSpotRecord;
begin
   BeginTest('Test_Worked_SpotStoreNeverFlagsADupeOrANeededMult');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      Settings.Cluster.SpotCommentMultiplier := True;
      CheckTrue(ParseDXSpotLine('DX de AC0C-1-#:   7037.0  K1DW        CW 21 dB 14 WPM CQ         NTX 0127Z', spot),
                'the spot decodes');
      spot.FBand := Band40;
      spot.FMode := CW;
      spot.FSysTime := Now;
      SpotsList.Clear;
      SpotsList.AddSpot(spot, False);
      CheckEquals(1, SpotsList.Count, 'the spot is on the map');

      (* NEW MULT: flagged M, never B. *)
      SpotsList.UpdateSpotsMultiplierStatus;
      CheckTrue(SpotsList.Get(0).FMult, 'NTX unworked: a new multiplier');
      CheckFalse(SpotsList.Get(0).FWorkedMult, 'and not a backup');

      (* WORKED MULT, NOT A DUPE: B, not M. *)
      LogWorked('W5XYZ', 'NTX', Band40);
      SpotsList.UpdateSpotsMultiplierStatus;
      CheckFalse(SpotsList.Get(0).FMult, 'NTX worked: no longer a new multiplier');
      CheckTrue(SpotsList.Get(0).FWorkedMult, 'a backup');
      CheckFalse(SpotsList.Get(0).FDupe, 'and not a dupe');

      (* THE CALL ITSELF IS NOW WORKED: a dupe is a dupe, never a backup. *)
      SpotsList.UpdateSpotsDupeStatus('K1DW', Band40, CW);
      CheckTrue(SpotsList.Get(0).FDupe, 'the call is a dupe');
      CheckFalse(SpotsList.Get(0).FWorkedMult, 'a dupe is not a backup');
      SpotsList.UpdateSpotsMultiplierStatus;
      CheckFalse(SpotsList.Get(0).FWorkedMult, 'and the re-ask keeps it so');
   finally
      SpotsList.Clear;
      RestoreSession;
   end;
end;

procedure TSpotCommentMultiplierTests.Test_Worked_ColourToken;
begin
   BeginTest('Test_Worked_ColourToken');
   CheckEquals('ORANGE', Settings.BandMap.WorkedMultColor, 'the default token');
   CheckTrue(WorkedMultColorOf('ORANGE') = trOrange, 'ORANGE');
   CheckTrue(WorkedMultColorOf('orange') = trOrange, 'any case');
   CheckTrue(WorkedMultColorOf('LIGHT BLUE') = trLightBlue, 'another colour of the palette');
   CheckTrue(WorkedMultColorOf('RED') = trRed, 'RED');
   CheckTrue(WorkedMultColorOf('not a colour') = trOrange, 'a spelling the palette lacks gives the default');
   CheckTrue(WorkedMultColorOf('') = trOrange, 'empty gives the default');
   CheckTrue(WorkedMultColor = trOrange, 'the setting as it stands');
   CheckEquals('ORANGE', tr4wColorsSA[trOrange], 'the palette spells it');
end;

procedure TSpotCommentMultiplierTests.RunAllTests;
begin
   Test_Tokens_RealCommentsFromTheIssue;
   Test_Tokens_RulesOfTheRuling;
   Test_Tokens_ParsedFromRealClusterLines;
   Test_ShortHistoryLayoutIsNotASpot;
   Test_Key_DomesticKeyOfQTHIsTheListsSpelling;
   Test_Hint_EachSectionOfTheIssue;
   Test_Hint_FirstWinsAndExtensionIsLast;
   Test_Hint_NoOpinionCases;
   Test_Hint_ContestWithoutADomesticFileGetsNone;
   Test_Hint_OurOwnKnowledgeOverrulesTheComment;
   Test_Mult_WorkedSectionIsNotNeededAndUnworkedIs;
   Test_Mult_SpotRoutineAndTheSetting;
   Test_Mult_CallHistoryOverridesADifferingComment;
   Test_Cost_HintForAWholeBandMapIsCheap;
   Test_Worked_PerBandMultiplier;
   Test_Worked_SweepstakesCountsOnceAcrossBands;
   Test_Worked_SpotStoreNeverFlagsADupeOrANeededMult;
   Test_Worked_ColourToken;
end;

end.
