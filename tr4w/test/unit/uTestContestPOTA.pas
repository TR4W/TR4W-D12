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

(* POTA AS A CONTEST CLASS -- design Q6, ruled by NY4I 2026-10-13.

  WHAT THE MATRIX CANNOT SEE. The contest matrix's POTA record proves the
  move left set-up, scoring and export unchanged, but its synthetic QSOs
  carry no park: their QTH is a state, their exchange empty. So the three
  branches that only a park, a state or a grid in the EXCHANGE reach -- and
  the two leaves lifted for them -- are pinned here, each against the line
  of PostUnit, MainUnit or FCONTEST it was moved from:

    * the class, on the base, stating its row and writing no CONTEST_ID;
    * one point a contact, every mode;
    * the set-up FoundContest's arm wrote, value for value, and the operator
      name set asked for;
    * the ADIF activation block, in the order the tail wrote it, for a park,
      a state, a grid and nothing; the park tags; the SRX_STRING;
    * the ADIF import, for POTA_REF, SIG/SIG_INFO, a state and none;
    * the park tools offered by POTA alone;
    * uPOTAReference.LooksLikeAState and uGridShape.LooksLikeGridSquare.

  IsValidPOTAPark and ResolvePOTAParkFromADIF keep their own tests in
  uTestRegexValidators, which moved with them. *)
unit uTestContestPOTA;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestPOTATests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure LoadParkFixture;
      procedure Test_POTAIsAClassOnTheBase;
      procedure Test_POTAScoresOnePointEveryMode;
      procedure Test_POTASessionIsFoundContestsArm;
      procedure Test_POTAExportsItsActivation;
      procedure Test_POTAWorkedStationDXCCIsItsCallsigns;
      procedure Test_POTAMyDXCCAndStateComeFromMyPark;
      procedure Test_TheBaseExchangeBlockIsTheSRXString;
      procedure Test_POTAImportsAParkOrAState;
      procedure Test_OnlyPOTAOffersTheParkTools;
      procedure Test_LooksLikeAState;
      procedure Test_LooksLikeGridSquare;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uADIF,
   uPOTAReference,
   uGridShape,
   uPOTAParks,
   Classes,
   uTestContestObjects,
   (* IdentitiesToWalk, IsLegacyContest, HandleOf, ContestWho -- the two
      every-contest invariants walk the registry (issue #135). *)
   uTestRegisteredContests;

(* A QSO WITH THE FIELDS THE POTA RULES READ, everything else zero. *)
function POTAQso(const aQTH, aExch: string): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := ContestHandleOf(POTA);
   Result.Band := Band20;
   Result.Mode := CW;
   Result.RSTReceived := 599;
   Result.QTHString := ShortString(aQTH);
   Result.ExchString := ShortString(aExch);
end;

(* THE SAME, WORKED FROM aCall, which CTY.DAT put in the entity aCountryID
   (the primary prefix: 'K', 'VE', 'DL', '*GM/s') -- the one thing the
   worked station's DXCC is read from (Q62). *)
function POTAQsoFrom(const aCall, aCountryID, aQTH, aExch: string): ContestExchange;
begin
   Result := POTAQso(aQTH, aExch);
   Result.Callsign := ShortString(aCall);
   Result.QTH.CountryID := ShortString(aCountryID);
end;

(* THE PARK LIST OUR PARK IS LOOKED UP IN, in the real file's shape
   (all_parks_ext.csv: entityId is POTA's own ADIF DXCC code, locationDesc the
   subdivision or subdivisions). It REPLACES whatever list is loaded, so a
   developer's downloaded list cannot change an answer here. *)
procedure TContestPOTATests.LoadParkFixture;
var
   csv: TStringList;
   path: string;
begin
   path := IncludeTrailingPathDelimiter(GetTempDir) + 'tr4w-pota-park-fixture.csv';
   csv := TStringList.Create;
   try
      csv.Add('"reference","name","active","entityId","locationDesc","latitude","longitude","grid"');
      csv.Add('"US-0663","A Georgia Park","1","291","US-GA","33.0","-84.0","EM83aa"');
      csv.Add('"US-0002","An Alaska Park","1","6","US-AK","59.0","-156.4","BO19sc"');
      csv.Add('"US-0100","A Hawaii Park","1","110","US-HI","19.5","-155.5","BL19aa"');
      csv.Add('"US-0015","A Park In Three States","1","291","US-DC,US-MD,US-WV","39.6","-77.8","FM19co"');
      csv.Add('"CA-0001","A British Columbia Park","1","1","CA-BC","49.1","-123.1","CN89jc"');
      csv.Add('"GB-0349","An English Park","1","223","GB-ENG","50.5","-3.7","IO80cn"');
      csv.Add('"VE-0001","A Row Without An Entity","1","","","","",""');
      csv.SaveToFile(path);
   finally
      csv.Free;
      end;
   CheckEquals(7, LoadPOTAParks(path), 'the park fixture loads');
   DeleteFile(path);
end;

(* OUR SIDE, WITH ONLY MY PARK SET. *)
function MyPark(const aPark: string): TMyStationExchange;
begin
   Result.MyState := '';
   Result.MyGrid := '';
   Result.MyName := '';
   Result.MyZone := '';
   Result.MyFDClass := '';
   Result.MySection := '';
   Result.MyCheck := '';
   Result.MyPrec := '';
   Result.MyFOCNumber := '';
   Result.MyPostalCode := '';
   Result.MyPark := aPark;
end;

function ExchangeBlock(const aMy: TMyStationExchange;
                       const aQso: ContestExchange): string;
begin
   Result := ContestIdentity(POTA).EmitADIFExchangeFields(aMy, aQso, True);
end;

procedure TContestPOTATests.Test_POTAIsAClassOnTheBase;
var
   obj: TContestBase;
begin
   BeginTest('Test_POTAIsAClassOnTheBase');
   CheckTrue(ContestClassFor(POTA) <> nil, 'POTA has a registered class');
   obj := Make(POTA);
   try
      CheckEquals('TContestPOTA', obj.ClassName, 'the POTA class');
      CheckTrue(obj.ClassParent = TContestBase, 'sits on TContestBase directly');
      CheckEquals('Parks on the Air(r) Logging', obj.DisplayName, 'display name: the friendly name');
      CheckEquals('POTA', obj.CabrilloName, 'Cabrillo name: the enum spelling');
      CheckEquals('POTA', obj.ADIFContestId, 'ADIF id: the enum spelling');
      CheckFalse(obj.WritesADIFContestId, 'an activation writes no CONTEST_ID');
      CheckTrue(obj.IsActive, 'active');
      CheckFalse(obj.IsUSQSOParty, 'P 0');
      CheckEquals(Ord(RSTAndPOTAPark), Ord(obj.ExchangeKind), 'the POTA exchange shape');
   finally
      obj.Free;
      end;
end;

(* The legacy LOGSTUFF OnePointPerQSO arm (deleted at M10 S3):
   `RXData.QSOPoints := 1`, whatever the mode. *)
procedure TContestPOTATests.Test_POTAScoresOnePointEveryMode;
var
   obj: TContestBase;
   qso: ContestExchange;
   m: ModeType;
begin
   BeginTest('Test_POTAScoresOnePointEveryMode');
   obj := Make(POTA);
   try
      for m := CW to FM do
         begin
         qso := POTAQso('US-1234', '');
         qso.Mode := m;
         qso.QSOPoints := 99;
         obj.ScoreQSO(qso);
         CheckEquals(1, qso.QSOPoints, 'one point, mode ' + IntToStr(Ord(m)));
         end;
   finally
      obj.Free;
      end;
end;

(* FCONTEST.FoundContest's POTA arm, value for value. *)
procedure TContestPOTATests.Test_POTASessionIsFoundContestsArm;
var
   obj: TContestBase;
   session: TSessionDefaults;
   memory: TSessionMemory;
begin
   BeginTest('Test_POTASessionIsFoundContestsArm');
   obj := Make(POTA);
   session := TSessionDefaults.Create;
   try
      obj.DescribeSession(NoStation, session);
      CheckTrue(session.IsStated(svAllowDupeQSOs) and session.AllowDupeQSOs, 'dupes allowed');
      CheckTrue(session.IsStated(svAutoDupeEnableCQ) and not session.AutoDupeEnableCQ,
                'auto-dupe off running');
      CheckTrue(session.IsStated(svAutoDupeEnableSAndP) and not session.AutoDupeEnableSAndP,
                'auto-dupe off searching');
      CheckEquals('POTA', session.ContestName, 'the session name');
      CheckTrue(session.IsStated(svWARCEnabled) and session.WARCEnabled, 'WARC on');
      CheckEquals('73 \ EE', session.QSLCW, 'the QSL message');
      CheckTrue(session.IsStated(svOperatorNameSet), 'the operator name set asked for');
      CheckFalse(session.IsStated(svExchange), 'no exchange stated -- the row''s stands');

      CheckEquals(2, session.MemoryCount, 'two CQ memories');
      memory := session.Memory(0);
      CheckTrue((memory.Bank = smbCQ) and (memory.Mode = CW) and (memory.Key = smkF1),
                'F1 first');
      CheckEquals('CQ^POTA \ \ ', memory.Text, 'CQ F1');
      memory := session.Memory(1);
      CheckTrue((memory.Bank = smbCQ) and (memory.Mode = CW) and (memory.Key = smkF2),
                'then F2');
      CheckEquals('CQ^POTA CQ^POTA \ \ FD', memory.Text, 'CQ F2');
   finally
      session.Free;
      obj.Free;
      end;
end;

(* PostUnit's tail, as it wrote a POTA QSO: the activation, the SRX_STRING,
   then a state or a grid when the QTH is not a park. *)
procedure TContestPOTATests.Test_POTAExportsItsActivation;
var
   my: TMyStationExchange;
   activation: string;
begin
   BeginTest('Test_POTAExportsItsActivation');
   LoadParkFixture;
   my := MyPark('US-0663');
   (* OUR PARK IS IN GEORGIA (the fixture): MY_DXCC 291 and MY_STATE GA follow
      the park tags, Q62. *)
   activation := EmitADIFField('MY_SIG', 'POTA') +
                 EmitADIFField('MY_SIG_INFO', 'US-0663') +
                 EmitADIFField('MY_POTA_REF', 'US-0663') +
                 EmitADIFField('MY_DXCC', '291') +
                 EmitADIFField('MY_STATE', 'GA');

   (* A PARK WORKED: it is the SRX_STRING, and nothing follows. The QSO here
      carries no country, so no DXCC. *)
   CheckEquals(activation + EmitADIFField('SRX_STRING', 'US-1234'),
               ExchangeBlock(my, POTAQso('US-1234', 'PA')),
               'a park: activation, then the park');

   (* A HUNTER WHO SENT A STATE -- DXCC from his callsign's country (Q62; it
      was the literal 291), STATE as sent. *)
   CheckEquals(activation + EmitADIFField('SRX_STRING', 'PA') +
               EmitADIFField('DXCC', '291') + EmitADIFField('STATE', 'PA'),
               ExchangeBlock(my, POTAQsoFrom('W3ABC', 'K', '', 'PA')),
               'a state: DXCC and STATE after it');

   (* A HUNTER WHO SENT A GRID. (Until M11 S9b this was asked of the
      session's exchange too, and a second case fed a session that carried no
      grid; POTA's session exchange cannot be anything else, so that case is
      gone with the argument.) *)
   CheckEquals(activation + EmitADIFField('SRX_STRING', 'FN31') +
               EmitADIFField('GRIDSQUARE', 'FN31'),
               ExchangeBlock(my, POTAQso('', 'FN31')),
               'a grid: GRIDSQUARE after it');

   (* NOTHING RECOGNISABLE: the exchange as typed, nothing after it. *)
   CheckEquals(activation + EmitADIFField('SRX_STRING', 'JOE'),
               ExchangeBlock(my, POTAQso('CT', 'JOE')),
               'neither: the typed exchange');

   (* NO MY PARK: MY_SIG alone, as the matrix's records show it. *)
   CheckEquals(EmitADIFField('MY_SIG', 'POTA'),
               ExchangeBlock(MyPark(''), POTAQso('CT', '')),
               'no park of our own, nothing received');

   (* THE RECEIVED EXCHANGE IGNORES THE RST FLAG. *)
   CheckEquals('US-1234', ContestIdentity(POTA).FormatADIFReceivedExchange(
               POTAQso('US-1234', 'PA'), True), 'the park, never the RST');
   CheckEquals('PA', ContestIdentity(POTA).FormatADIFReceivedExchange(
               POTAQso('', 'PA'), True), 'else the exchange, never the RST');

   (* THE PARK TAGS -- PostUnit's location arm. *)
   CheckEquals(EmitADIFField('SIG', 'POTA') + EmitADIFField('SIG_INFO', 'US-1234') +
               EmitADIFField('POTA_REF', 'US-1234'),
               ContestIdentity(POTA).EmitADIFContestFields(POTAQso('US-1234', '')),
               'a park: SIG, SIG_INFO and POTA_REF');
   CheckEquals('', ContestIdentity(POTA).EmitADIFContestFields(POTAQso('CT', '')),
               'not a park: nothing');
end;

(* Q62, THE WORKED STATION'S HALF: DXCC IS THE CALLSIGN'S COUNTRY, NEVER THE
   SHAPE OF WHAT IT SENT. *)
procedure TContestPOTATests.Test_POTAWorkedStationDXCCIsItsCallsigns;
var
   my: TMyStationExchange;
   header: string;
begin
   BeginTest('Test_POTAWorkedStationDXCCIsItsCallsigns');
   my := MyPark('');
   header := EmitADIFField('MY_SIG', 'POTA');

   (* A CANADIAN HUNTER who sent a province: Canada (1), not the US (291) the
      old export wrote for anything that looked like a state. STATE stays ON. *)
   CheckEquals(header + EmitADIFField('SRX_STRING', 'ON') +
               EmitADIFField('DXCC', '1') + EmitADIFField('STATE', 'ON'),
               ExchangeBlock(my, POTAQsoFrom('VE3ABC', 'VE', '', 'ON')),
               'VE3ABC sending ON is DXCC 1');

   (* A US HUNTER: 291, as before. *)
   CheckEquals(header + EmitADIFField('SRX_STRING', 'PA') +
               EmitADIFField('DXCC', '291') + EmitADIFField('STATE', 'PA'),
               ExchangeBlock(my, POTAQsoFrom('W3ABC', 'K', '', 'PA')),
               'W3ABC sending PA is DXCC 291');

   (* PARK-TO-PARK: the hunter is in a park of his own, which used to get no
      DXCC at all. His country is his callsign's, here Germany (230). *)
   CheckEquals(header + EmitADIFField('SRX_STRING', 'DE-0123') +
               EmitADIFField('DXCC', '230'),
               ExchangeBlock(my, POTAQsoFrom('DL1ABC', 'DL', 'DE-0123', '')),
               'a park-to-park QSO: DXCC 230 from the call');

   (* ALASKA AND HAWAII ARE ENTITIES OF THEIR OWN IN CTY.DAT AND IN DXCC. *)
   CheckEquals(header + EmitADIFField('SRX_STRING', 'AK') +
               EmitADIFField('DXCC', '6') + EmitADIFField('STATE', 'AK'),
               ExchangeBlock(my, POTAQsoFrom('KL7ABC', 'KL', '', 'AK')),
               'KL7ABC is DXCC 6');

   (* A SUB-ENTITY'S STARRED ID (Shetland) IS THE DXCC ENTITY IT COUNTS FOR. *)
   CheckEquals(header + EmitADIFField('SRX_STRING', 'JOE') +
               EmitADIFField('DXCC', '279'),
               ExchangeBlock(my, POTAQsoFrom('GM3ABC', '*GM/s', 'CT', 'JOE')),
               'Shetland is Scotland, 279');

   (* NO COUNTRY, OR ONE THE TABLE DOES NOT KNOW: the tag is left out, never
      guessed. *)
   CheckEquals(header + EmitADIFField('SRX_STRING', 'JOE'),
               ExchangeBlock(my, POTAQsoFrom('XX1ABC', '', 'CT', 'JOE')),
               'no country: no DXCC');
   CheckEquals(header + EmitADIFField('SRX_STRING', 'JOE'),
               ExchangeBlock(my, POTAQsoFrom('XX1ABC', 'QQ9', 'CT', 'JOE')),
               'an entity not in the table: no DXCC');
end;

(* Q62, OUR HALF: MY_DXCC AND MY_STATE FROM OUR PARK, in the park list. *)
procedure TContestPOTATests.Test_POTAMyDXCCAndStateComeFromMyPark;

   function Mine(const aPark: string): string;
   begin
      Result := ExchangeBlock(MyPark(aPark), POTAQso('CT', ''));
   end;

   function Tags(const aPark, aDXCC, aState: string): string;
   begin
      Result := EmitADIFField('MY_SIG', 'POTA') +
                EmitADIFField('MY_SIG_INFO', aPark) +
                EmitADIFField('MY_POTA_REF', aPark) +
                EmitADIFField('MY_DXCC', aDXCC) +
                EmitADIFField('MY_STATE', aState);
   end;

begin
   BeginTest('Test_POTAMyDXCCAndStateComeFromMyPark');
   LoadParkFixture;

   (* A US PARK: the USA and its state. *)
   CheckEquals(Tags('US-0663', '291', 'GA'), Mine('US-0663'), 'a Georgia park');

   (* A CANADIAN PARK: Canada and its province. (The reference POTA gives
      Canada is CA-, not VE-.) *)
   CheckEquals(Tags('CA-0001', '1', 'BC'), Mine('CA-0001'), 'a British Columbia park');

   (* THE LIST'S ENTITY, NOT THE REFERENCE'S TWO LETTERS: US-0002 is Alaska. *)
   CheckEquals(Tags('US-0002', '6', 'AK'), Mine('US-0002'), 'an Alaska park is DXCC 6');
   CheckEquals(Tags('US-0100', '110', 'HI'), Mine('US-0100'), 'a Hawaii park is DXCC 110');

   (* A PARK IN SEVERAL STATES names no one state: MY_DXCC alone. *)
   CheckEquals(Tags('US-0015', '291', ''), Mine('US-0015'),
               'a three-state park: MY_DXCC, no MY_STATE');

   (* A COUNTRY ADIF HAS NO STATE LIST FOR: MY_DXCC alone. *)
   CheckEquals(Tags('GB-0349', '223', ''), Mine('GB-0349'),
               'an English park: MY_DXCC, no MY_STATE');

   (* A PARK THE LIST DOES NOT HOLD, OR HOLDS WITHOUT AN ENTITY: neither. *)
   CheckEquals(Tags('US-9999', '', ''), Mine('US-9999'), 'a park not in the list');
   CheckEquals(Tags('VE-0001', '', ''), Mine('VE-0001'), 'a row with no entity');

   (* NO PARK OF OUR OWN: nothing to look up. *)
   CheckEquals(Tags('', '', ''), Mine(''), 'no MY PARK');
end;

(* EVERY OTHER CONTEST'S BLOCK IS THE SRX_STRING THE TAIL ALWAYS WROTE --
   every identity the registry answers with, by-id contests included
   (issue #135). *)
procedure TContestPOTATests.Test_TheBaseExchangeBlockIsTheSRXString;
var
   identities: TContestIdentityList;
   k: integer;
   qso: ContestExchange;
   contest: TContestBase;
begin
   BeginTest('Test_TheBaseExchangeBlockIsTheSRXString');
   identities := IdentitiesToWalk;
   for k := 0 to High(identities) do
      begin
      contest := identities[k];
      if IsLegacyContest(contest, POTA) then
         begin
         Continue;
         end;
      qso := POTAQso('CT', '123');
      qso.ceContest := HandleOf(contest);
      CheckEquals(EmitADIFField('SRX_STRING', contest.FormatADIFReceivedExchange(qso, True)),
                  contest.EmitADIFExchangeFields(MyPark('US-0663'), qso, True),
                  ContestWho(contest) + ': the SRX_STRING alone');
      end;
end;

(* MainUnit.ApplyClasslessADIFImport's POTA arm. *)
procedure TContestPOTATests.Test_POTAImportsAParkOrAState;

   function Imported(const aPOTARef, aSIG, aSIGInfo, aState: string): ContestExchange;
   var
      t: TADIFRecordTemps;
   begin
      InitADIFRecordTemps(t);
      t.POTARef := aPOTARef;
      t.SIG := aSIG;
      t.SIG_Info := aSIGInfo;
      t.State := aState;
      InitContestExchangeForParse(Result);
      Result.ceContest := ContestHandleOf(POTA);
      Result.QTHString := 'KEPT';
      Result.DomesticQTH := 'KEPT';
      ContestIdentity(POTA).ApplyADIFImport(t, NeutralADIFImportSession, Result);
   end;

var
   x: ContestExchange;
begin
   BeginTest('Test_POTAImportsAParkOrAState');
   x := Imported('US-1234', 'POTA', 'US-9999', 'PA');
   CheckEquals('US-1234', string(x.QTHString), 'POTA_REF wins');
   CheckEquals('KEPT', string(x.DomesticQTH), 'a park leaves the domestic QTH');

   x := Imported('', 'POTA', 'US-5678', '');
   CheckEquals('US-5678', string(x.QTHString), 'SIG/SIG_INFO when SIG is POTA');

   x := Imported('', 'WWFF', 'US-5678', 'PA');
   CheckEquals('PA', string(x.QTHString), 'not a POTA SIG: the state');
   CheckEquals('PA', string(x.DomesticQTH), 'the state is the domestic QTH too');

   x := Imported('', '', '', 'XX');
   CheckEquals('KEPT', string(x.QTHString), 'neither: what the generic import gave');
   CheckEquals('KEPT', string(x.DomesticQTH), 'neither: the domestic QTH kept');
end;

(* ONLY POTA -- among every identity the registry answers with, by-id
   contests included (issue #135). *)
procedure TContestPOTATests.Test_OnlyPOTAOffersTheParkTools;
var
   identities: TContestIdentityList;
   k: integer;
   obj: TContestBase;
begin
   BeginTest('Test_OnlyPOTAOffersTheParkTools');
   identities := IdentitiesToWalk;
   for k := 0 to High(identities) do
      begin
      obj := Make(HandleOf(identities[k]), NoStation);
      try
         CheckEquals(Ord(IsLegacyContest(identities[k], POTA)), Ord(obj.OffersParkTools),
                     ContestWho(identities[k]) + ': the park tools');
      finally
         obj.Free;
         end;
      end;
end;

(* Tree's list, moved: the states, DC and the provinces, upper case only. *)
procedure TContestPOTATests.Test_LooksLikeAState;
begin
   BeginTest('Test_LooksLikeAState');
   CheckTrue(LooksLikeAState('PA'), 'a state');
   CheckTrue(LooksLikeAState('DC'), 'DC');
   CheckTrue(LooksLikeAState('ON'), 'a province');
   CheckTrue(LooksLikeAState('NU'), 'the last of Tree''s chain');
   CheckTrue(LooksLikeAState('TX'), 'listed twice, still once');
   CheckFalse(LooksLikeAState('pa'), 'case-sensitive, as Tree''s was');
   CheckFalse(LooksLikeAState('PR'), 'Puerto Rico was never in it');
   CheckFalse(LooksLikeAState('XX'), 'not a state');
   CheckFalse(LooksLikeAState(''), 'empty');
   CheckFalse(LooksLikeAState('PAX'), 'three letters');
end;

(* Tree's character walk, moved: four or six, A..R twice, two digits. *)
procedure TContestPOTATests.Test_LooksLikeGridSquare;
begin
   BeginTest('Test_LooksLikeGridSquare');
   CheckTrue(LooksLikeGridSquare('FN31'), 'four');
   CheckTrue(LooksLikeGridSquare('fn31pr'), 'six, lower case');
   CheckTrue(LooksLikeGridSquare('AR09'), 'the edges, A and R');
   CheckTrue(LooksLikeGridSquare('FN31!!'), 'characters 5 and 6 are not examined');
   CheckFalse(LooksLikeGridSquare('SN31'), 'S is past R');
   CheckFalse(LooksLikeGridSquare('FN3A'), 'a letter where a digit goes');
   CheckFalse(LooksLikeGridSquare('FN31P'), 'five');
   CheckFalse(LooksLikeGridSquare('FN3'), 'three');
   CheckFalse(LooksLikeGridSquare(''), 'empty');
   (* The contest question LooksLikeAGrid asks first -- it was the POTA
      shape's membership of uGridShape.GRID_CARRYING_EXCHANGES, deleted at
      M11 S9e part 1 for the contest's own answer. *)
   CheckTrue(ContestIdentity(POTA).ExchangeTextMayHoldGridSquare, 'POTA''s exchange word may be a grid');
   CheckFalse(ContestIdentity(CQWPXCW).ExchangeTextMayHoldGridSquare, 'an RST-and-serial contest''s may not');
end;

procedure TContestPOTATests.RunAllTests;
begin
   Test_POTAIsAClassOnTheBase;
   Test_POTAScoresOnePointEveryMode;
   Test_POTASessionIsFoundContestsArm;
   Test_POTAExportsItsActivation;
   Test_POTAWorkedStationDXCCIsItsCallsigns;
   Test_POTAMyDXCCAndStateComeFromMyPark;
   Test_TheBaseExchangeBlockIsTheSRXString;
   Test_POTAImportsAParkOrAState;
   Test_OnlyPOTAOffersTheParkTools;
   Test_LooksLikeAState;
   Test_LooksLikeGridSquare;
end;

end.
