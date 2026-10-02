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

(* EACH CONTEST PARSES AND VALIDATES ITS OWN RECEIVED EXCHANGE -- milestone
  M5b, 2026-10-02 (docs/CONTEST_OWNERSHIP_DESIGN.md 3.1, 7.10).

  The engine hands a contest a TReceivedExchangeSession -- the session's
  exchange shape, its per-shape parser and two engine services -- as DATA.
  The tests hand it STUBS, so what is pinned is the contest's own decision:
  which shape it asks for, what it does before and after, and what a refusal
  says. The engine's per-shape parsers are the contest matrix's to pin (its
  parse section, frozen before anything moved).

    * THE BASE parses the session's own shape and adds nothing.
    * EVERY RULE THAT MOVED -- RAC, the PCC, Arktika Spring, LABRE, IARU,
      UK/EI, SAC, the Russian DX initial exchange -- applies under the shape
      it was written for and defers otherwise.
    * NY4I's RULINGS (design 7.10): Sweepstakes names a missing precedence; a
      state party's out-of-state station works only the host state.
    * THE LIFTED WORD CUTTING (uExchangeTokens) is pinned on the quirks it
      carries from LOGSTUFF, because a "tidier" copy would hand a contest a
      different word.
    * NC's county file is the sponsor's hundred counties, and no party's
      county file pulls in anything but counties. *)
unit uTestContestParse;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestParseTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_BaseParsesTheSessionsShape;
      procedure Test_RACVE0SendsASerial;
      procedure Test_PCCLettersAreAQTH;
      procedure Test_ArktikaDigitsAreASerial;
      procedure Test_LABREPYSendsAState;
      procedure Test_IARUSocietyGetsItsZone;
      procedure Test_UKEIStationMustSendTwoWords;
      procedure Test_SACAbandonsARussianLiveEntry;
      procedure Test_SweepstakesNamesAMissingPrecedence;
      procedure Test_OutOfStateWorksOnlyTheHostState;
      procedure Test_EveryStatePartyRefusesAnOutOfStateContact;
      procedure Test_RussianDXInitialExchangeIsTheOblast;
      procedure Test_SplitExchangeInThree;
      procedure Test_SweepstakesWordReading;
      procedure Test_IsSingleNonNumericToken;
      procedure Test_FieldDayImportDXIsNotASection;
      procedure Test_NCCountyFileIsTheSponsorsList;
      procedure Test_EveryPartyCountyFileHoldsOnlyCounties;
   end;

implementation

uses
   Classes, SysUtils, VC, uContestBase, uContestRegistry,
   uContestStateQSOPartyBase, uExchangeTokens, uCallSignRoutines,
   uDomFileKeys, uAppStrings, uTR4WStrings;

(* ---------------------------------------------------------------------------
   THE STUBBED ENGINE -- what each service was asked, and what it answers
   --------------------------------------------------------------------------- *)

var
   GShapeCalls: integer;
   GShapeAsked: ExchangeType;
   GShapeText: string;
   GShapeResult: boolean;
   GShapeSetsQTH: string;
   GShapeSetsDomestic: string;
   GZoneAsked: string;
   GAbandoned: integer;
   GDomesticKeys: string;

function StubParseShape(aShape: ExchangeType; const aText: string;
                        var aExch: ContestExchange): boolean;
begin
   inc(GShapeCalls);
   GShapeAsked := aShape;
   GShapeText := aText;
   if GShapeSetsQTH <> '' then
      begin
      aExch.QTHString := ShortString(GShapeSetsQTH);
      end;
   if GShapeSetsDomestic <> '' then
      begin
      aExch.DomesticQTH := ShortString(GShapeSetsDomestic);
      end;
   Result := GShapeResult;
end;

function StubZoneOfCall(const aCall: string): Byte;
begin
   GZoneAsked := aCall;
   Result := 8;
end;

(* The table knows exactly the comma-separated keys in GDomesticKeys. *)
function StubIsDomesticQTH(const aQTH: string): boolean;
begin
   Result := Pos(',' + UpperCase(aQTH) + ',', ',' + GDomesticKeys + ',') > 0;
end;

procedure StubAbandonEntry;
begin
   inc(GAbandoned);
end;

procedure ResetStub;
begin
   GShapeCalls := 0;
   GShapeAsked := NoExchangeReceived;
   GShapeText := '';
   GShapeResult := True;
   GShapeSetsQTH := '';
   GShapeSetsDomestic := '';
   GZoneAsked := '';
   GAbandoned := 0;
   GDomesticKeys := '';
end;

function Session(aShape: ExchangeType; aLive: boolean): TReceivedExchangeSession;
begin
   Result.Exchange := aShape;
   Result.ParseShape := @StubParseShape;
   Result.ZoneOfCall := @StubZoneOfCall;
   Result.IsDomesticQTH := @StubIsDomesticQTH;
   Result.CallWindowHasCall := aLive;
   Result.AbandonEntry := @StubAbandonEntry;
end;

function NewExch(const aCall, aCountry: string): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Callsign := ShortString(aCall);
   Result.QTH.CountryID := ShortString(aCountry);
   Result.Zone := DUMMYZONE;
end;

(* A contest's registered class, made fresh, with the station given. The
   caller frees it. *)
function Make(aContest: ContestType; aInHostState: boolean): TContestBase;
var
   station: TStationContext;
begin
   Result := ContestClassFor(aContest).Create(aContest);
   FillChar(station, SizeOf(station), 0);
   station.InHostState := aInHostState;
   Result.SetStation(station);
end;

(* One parse through aContest's class: the result, with the shape asked and
   the message given for the caller to check. *)
function Parse(aContest: ContestType; aShape: ExchangeType; aLive: boolean;
               const aText: string; var aExch: ContestExchange;
               out aMessage: string): boolean;
var
   contestObject: TContestBase;
begin
   contestObject := Make(aContest, False);
   try
      Result := contestObject.ParseReceivedExchange(aText, Session(aShape, aLive),
                                                    aExch, aMessage);
   finally
      contestObject.Free;
   end;
end;

function ShapeName(aShape: ExchangeType): string;
begin
   Result := IntToStr(Ord(aShape));
end;

(* ---------------------------------------------------------------------------
   THE BASE
   --------------------------------------------------------------------------- *)

procedure TContestParseTests.Test_BaseParsesTheSessionsShape;
var
   exch: ContestExchange;
   msg: string;
   ok: boolean;
begin
   BeginTest('Test_BaseParsesTheSessionsShape');
   ResetStub;
   GShapeResult := False;
   exch := NewExch('W1AW', 'K');
   (* WRTC's class (M7b batch 2) states no parse rule: it inherits the
      base's, which is what this pins. *)
   ok := ContestIdentity(WRTC).ParseReceivedExchange('599 ARRL',
            Session(RSTZoneOrSocietyExchange, True), exch, msg);
   CheckFalse(ok, 'the base returns the shape''s answer');
   CheckEquals(1, GShapeCalls, 'the base parses once');
   CheckEquals(Ord(RSTZoneOrSocietyExchange), Ord(GShapeAsked), 'the session''s own shape');
   CheckEquals('599 ARRL', GShapeText, 'the text as typed');
   CheckEquals('', msg, 'the base names no reason of its own');
   CheckEquals(Ord(DUMMYZONE), Ord(exch.Zone), 'the base fills no zone -- that is IARU''s rule');
end;

(* ---------------------------------------------------------------------------
   THE RULES THAT MOVED
   --------------------------------------------------------------------------- *)

procedure TContestParseTests.Test_RACVE0SendsASerial;
var
   exch: ContestExchange;
   msg: string;
   c: ContestType;
begin
   BeginTest('Test_RACVE0SendsASerial');
   for c in [CANADA_DAY, CANADA_WINTER] do
      begin
      ResetStub;
      exch := NewExch('VE0ABC', 'VE');
      Parse(c, RSTAndQSONumberOrDomesticQTHExchange, True, '599 123', exch, msg);
      CheckEquals(Ord(RSTQSONumberExchange), Ord(GShapeAsked),
                  string(ContestTypeSA[c]) + ': a VE0 station''s serial');

      ResetStub;
      exch := NewExch('VE3ABC', 'VE');
      Parse(c, RSTAndQSONumberOrDomesticQTHExchange, True, '59 ON', exch, msg);
      CheckEquals(Ord(RSTAndQSONumberOrDomesticQTHExchange), Ord(GShapeAsked),
                  string(ContestTypeSA[c]) + ': anybody else, the shape''s own rule');

      ResetStub;
      exch := NewExch('VE0ABC', 'VE');
      Parse(c, RSTQSONumberAndDomesticQTHExchange, True, '599 123', exch, msg);
      CheckEquals(Ord(RSTQSONumberAndDomesticQTHExchange), Ord(GShapeAsked),
                  string(ContestTypeSA[c]) + ': under another shape the rule defers');
      end;
end;

procedure TContestParseTests.Test_PCCLettersAreAQTH;
var
   exch: ContestExchange;
   msg: string;
begin
   BeginTest('Test_PCCLettersAreAQTH');
   ResetStub;
   exch := NewExch('PA3ABC', 'PA');
   Parse(PCC, RSTAndQSONumberOrDomesticQTHExchange, True, '123', exch, msg);
   CheckEquals(Ord(RSTQSONumberExchange), Ord(GShapeAsked), 'digits: a serial');

   ResetStub;
   Parse(PCC, RSTAndQSONumberOrDomesticQTHExchange, True, '599 GR', exch, msg);
   CheckEquals(Ord(RSTDomesticQTHExchange), Ord(GShapeAsked), 'letters: a QTH');

   ResetStub;
   Parse(PCC, RSTDomesticQTHExchange, True, '123', exch, msg);
   CheckEquals(Ord(RSTDomesticQTHExchange), Ord(GShapeAsked), 'another shape: the session''s');

   CheckFalse(ContestIdentity(PCC).MayBeACallsign('N/X'), 'PCC: N/X is not a call');
   CheckTrue(ContestIdentity(PCC).MayBeACallsign('PA3ABC'), 'PCC: a call is a call');
   CheckTrue(ContestIdentity(PCC).MayBeACallsign('N/XY'), 'PCC: only three characters');
   CheckTrue(ContestIdentity(WRTC).MayBeACallsign('N/X'), 'the base objects to no word');
end;

procedure TContestParseTests.Test_ArktikaDigitsAreASerial;
var
   exch: ContestExchange;
   msg: string;
begin
   BeginTest('Test_ArktikaDigitsAreASerial');
   ResetStub;
   exch := NewExch('UA9ABC', 'UA9');
   Parse(ARKTIKA_SPRING, RSTAndQSONumberOrDomesticQTHExchange, True, '599 123', exch, msg);
   CheckEquals(Ord(RSTQSONumberExchange), Ord(GShapeAsked), 'digits and blanks: a serial');

   ResetStub;
   Parse(ARKTIKA_SPRING, RSTAndQSONumberOrDomesticQTHExchange, True, '599 KO85', exch, msg);
   CheckEquals(Ord(RSTDomesticQTHExchange), Ord(GShapeAsked), 'anything else: a QTH');
end;

procedure TContestParseTests.Test_LABREPYSendsAState;
var
   exch: ContestExchange;
   msg: string;
begin
   BeginTest('Test_LABREPYSendsAState');
   ResetStub;
   exch := NewExch('PY2ABC', 'PY');
   Parse(LABRE, RSTDomesticOrDXQTHExchange, True, '599 SP', exch, msg);
   CheckEquals(Ord(RSTDomesticQTHExchange), Ord(GShapeAsked), 'a PY station: a domestic QTH');

   ResetStub;
   exch := NewExch('DL1ABC', 'DL');
   Parse(LABRE, RSTDomesticOrDXQTHExchange, True, '599 DL', exch, msg);
   CheckEquals(Ord(RSTDomesticOrDXQTHExchange), Ord(GShapeAsked), 'anybody else: the shape''s');
end;

procedure TContestParseTests.Test_IARUSocietyGetsItsZone;
var
   exch: ContestExchange;
   msg: string;
begin
   BeginTest('Test_IARUSocietyGetsItsZone');
   ResetStub;
   exch := NewExch('W1AW', 'K');
   Parse(IARU, RSTZoneOrSocietyExchange, True, 'ARRL', exch, msg);
   CheckEquals(8, exch.Zone, 'a society''s one word: the zone from the call');
   CheckEquals('W1AW', GZoneAsked, 'asked of the worked call');

   ResetStub;
   GShapeResult := False;
   exch := NewExch('W1AW', 'K');
   Parse(IARU, RSTZoneOrSocietyExchange, True, 'XYZ', exch, msg);
   CheckEquals(8, exch.Zone, 'whatever the parse answered, as it was');

   ResetStub;
   exch := NewExch('W1AW', 'K');
   Parse(IARU, RSTZoneOrSocietyExchange, True, '599 ARRL', exch, msg);
   CheckEquals(Ord(DUMMYZONE), Ord(exch.Zone), 'two words: no zone');

   ResetStub;
   exch := NewExch('W1AW', 'K');
   Parse(IARU, RSTZoneOrSocietyExchange, True, '8', exch, msg);
   CheckEquals(Ord(DUMMYZONE), Ord(exch.Zone), 'a zone: the zone path, untouched');

   ResetStub;
   exch := NewExch('W1AW', 'K');
   exch.Zone := 7;
   Parse(IARU, RSTZoneOrSocietyExchange, True, 'ARRL', exch, msg);
   CheckEquals(7, exch.Zone, 'a zone already set stands');

   ResetStub;
   exch := NewExch('W1AW', 'K');
   Parse(IARU, RSTDomesticQTHExchange, True, 'ARRL', exch, msg);
   CheckEquals(Ord(DUMMYZONE), Ord(exch.Zone), 'another shape: no zone');

   ResetStub;
   exch := NewExch('W1AW', 'K');
   ContestIdentity(WRTC).ParseReceivedExchange('ARRL', Session(RSTZoneOrSocietyExchange, True),
                                               exch, msg);
   CheckEquals(Ord(DUMMYZONE), Ord(exch.Zone), 'WRTC runs the shape and not the rule');
end;

procedure TContestParseTests.Test_UKEIStationMustSendTwoWords;
var
   exch: ContestExchange;
   msg: string;
   ok: boolean;
begin
   BeginTest('Test_UKEIStationMustSendTwoWords');
   ResetStub;
   exch := NewExch('G3ABC', 'G');
   ok := Parse(UKEI, RSTQSONumberAndPossibleDomesticQTHExchange, True, '123', exch, msg);
   CheckFalse(ok, 'a UK station sending one word is refused');
   CheckEquals(string(TC_INVALID), msg, 'with the message it always had');
   CheckEquals(0, GShapeCalls, 'before the shape is parsed');

   ResetStub;
   ok := Parse(UKEI, RSTQSONumberAndPossibleDomesticQTHExchange, True, '599 123 LN', exch, msg);
   CheckTrue(ok, 'two words or more: the shape decides');
   CheckEquals(1, GShapeCalls, 'parsed');

   ResetStub;
   exch := NewExch('DL1ABC', 'DL');
   ok := Parse(UKEI, RSTQSONumberAndPossibleDomesticQTHExchange, True, '123', exch, msg);
   CheckTrue(ok, 'a station outside the UK and Ireland: the shape decides');

   ResetStub;
   exch := NewExch('G3ABC', 'G');
   ok := Parse(UKEI, RSTQSONumberExchange, True, '123', exch, msg);
   CheckTrue(ok, 'another shape: the rule defers');
end;

procedure TContestParseTests.Test_SACAbandonsARussianLiveEntry;
const
   RUSSIAN_COUNTRIES: array[0..3] of string = ('UA', 'UA9', 'UA2', 'EU');
var
   exch: ContestExchange;
   msg: string;
   ok: boolean;
   c: ContestType;
   i: integer;
   country: string;
begin
   BeginTest('Test_SACAbandonsARussianLiveEntry');
   for c in [SACCW, SACSSB] do
      begin
      for i := Low(RUSSIAN_COUNTRIES) to High(RUSSIAN_COUNTRIES) do
         begin
         country := RUSSIAN_COUNTRIES[i];
         ResetStub;
         exch := NewExch('UA3ABC', country);
         ok := Parse(c, RSTQSONumberExchange, True, '599 123', exch, msg);
         CheckFalse(ok, string(ContestTypeSA[c]) + ' ' + country + ': refused');
         CheckEquals(1, GAbandoned, string(ContestTypeSA[c]) + ' ' + country + ': the entry is abandoned');
         CheckEquals(0, GShapeCalls, string(ContestTypeSA[c]) + ' ' + country + ': not parsed');
         CheckEquals('', msg, string(ContestTypeSA[c]) + ' ' + country + ': silently, as it always was');
         end;

      ResetStub;
      exch := NewExch('UA3ABC', 'UA');
      ok := Parse(c, RSTQSONumberExchange, False, '599 123', exch, msg);
      CheckTrue(ok, string(ContestTypeSA[c]) + ': not live entry -- parsed');
      CheckEquals(0, GAbandoned, string(ContestTypeSA[c]) + ': nothing abandoned');

      ResetStub;
      exch := NewExch('SM5ABC', 'SM');
      ok := Parse(c, RSTQSONumberExchange, True, '599 123', exch, msg);
      CheckTrue(ok, string(ContestTypeSA[c]) + ': a Scandinavian station is parsed');
      end;
end;

(* NY4I, 2026-10-02 (design 7.10, Q19): "A sweepstakes entry should not have
   been logged without a precedence." *)
procedure TContestParseTests.Test_SweepstakesNamesAMissingPrecedence;
var
   exch: ContestExchange;
   msg: string;
   ok: boolean;
   c: ContestType;
begin
   BeginTest('Test_SweepstakesNamesAMissingPrecedence');
   for c in [ARRLSSCW, ARRLSSSSB] do
      begin
      ResetStub;
      GShapeResult := False;
      exch := NewExch('W1AW', 'K');
      ok := Parse(c, QSONumberPrecedenceCheckDomesticQTHExchange, True, '123 99 CT', exch, msg);
      CheckFalse(ok, string(ContestTypeSA[c]) + ': refused');
      CheckEquals(SExchangeNoPrecedence, msg, string(ContestTypeSA[c]) + ': and says why');

      ResetStub;
      GShapeResult := False;
      ok := Parse(c, QSONumberPrecedenceCheckDomesticQTHExchange, True, '123 A CT', exch, msg);
      CheckFalse(ok, string(ContestTypeSA[c]) + ': refused for its missing check');
      CheckEquals('', msg, string(ContestTypeSA[c]) + ': a precedence was there -- not that reason');

      ResetStub;
      GShapeResult := True;
      ok := Parse(c, QSONumberPrecedenceCheckDomesticQTHExchange, True, '123 A 99 CT', exch, msg);
      CheckTrue(ok, string(ContestTypeSA[c]) + ': a whole exchange is accepted');
      CheckEquals('', msg, string(ContestTypeSA[c]) + ': with nothing to say');

      ResetStub;
      GShapeResult := False;
      ok := Parse(c, RSTQSONumberExchange, True, '123', exch, msg);
      CheckEquals('', msg, string(ContestTypeSA[c]) + ': another shape carries no precedence');
      end;
end;

(* NY4I, 2026-10-02 (design 7.10): an out-of-state station works only the
   host state; an in-state station works everyone. *)
procedure TContestParseTests.Test_OutOfStateWorksOnlyTheHostState;
var
   contestObject: TContestBase;
   exch: ContestExchange;
   msg: string;
   ok: boolean;
begin
   BeginTest('Test_OutOfStateWorksOnlyTheHostState');

   contestObject := Make(FLORIDAQSOPARTY, False);
   try
      ResetStub;
      GDomesticKeys := 'ALAC,BAKE';
      GShapeSetsQTH := 'DL';
      exch := NewExch('DL1ABC', 'DL');
      ok := contestObject.ParseReceivedExchange('599 DL', Session(RSTDomesticOrDXQTHExchange, True),
                                                exch, msg);
      CheckFalse(ok, 'out of state, a DX station: refused');
      CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['FL']), msg, 'with the reason');

      ResetStub;
      GDomesticKeys := 'ALAC,BAKE';
      GShapeSetsQTH := 'ALAC';
      exch := NewExch('W4ABC', 'K');
      ok := contestObject.ParseReceivedExchange('599 ALAC', Session(RSTDomesticOrDXQTHExchange, True),
                                                exch, msg);
      CheckTrue(ok, 'out of state, a host county: accepted');
      CheckEquals('', msg, 'nothing to say');

      ResetStub;
      GDomesticKeys := 'ALAC,BAKE';
      GShapeSetsQTH := 'ALAC';
      GShapeSetsDomestic := '';
      exch := NewExch('DL1ABC', 'DL');
      exch.DomesticQTH := 'BAKE';
      GShapeSetsQTH := 'DL';
      ok := contestObject.ParseReceivedExchange('599 DL', Session(RSTDomesticOrDXQTHExchange, True),
                                                exch, msg);
      CheckFalse(ok, 'a domestic QTH left from an earlier attempt does not make DX a host county');

      ResetStub;
      GShapeResult := False;
      exch := NewExch('W4ABC', 'K');
      ok := contestObject.ParseReceivedExchange('599 ZZZ', Session(RSTDomesticOrDXQTHExchange, True),
                                                exch, msg);
      CheckFalse(ok, 'a county the shape refused stays refused');
      CheckEquals('', msg, 'with the shape''s own message, not this one');
   finally
      contestObject.Free;
   end;

   contestObject := Make(FLORIDAQSOPARTY, True);
   try
      ResetStub;
      GDomesticKeys := 'ALAC,BAKE';
      GShapeSetsQTH := 'DL';
      exch := NewExch('DL1ABC', 'DL');
      ok := contestObject.ParseReceivedExchange('599 DL', Session(RSTDomesticOrDXQTHExchange, True),
                                                exch, msg);
      CheckTrue(ok, 'in state, a DX station: accepted -- in-state stations work everyone');
   finally
      contestObject.Free;
   end;
end;

(* THE DEFAULT IS THE BASE'S, SO EVERY SINGLE-STATE PARTY HAS IT -- and no
   class overrides it today. A party whose sponsor rules otherwise joins an
   exception list here, in the commit that states the rule. *)
procedure TContestParseTests.Test_EveryStatePartyRefusesAnOutOfStateContact;
var
   c: ContestType;
   cls: TContestClass;
   contestObject: TContestBase;
   exch: ContestExchange;
   msg: string;
   ok: boolean;
   parties: integer;
begin
   BeginTest('Test_EveryStatePartyRefusesAnOutOfStateContact');
   parties := 0;
   for c := Succ(Low(ContestType)) to High(ContestType) do
      begin
      cls := ContestClassFor(c);
      if (cls = nil) or (not cls.InheritsFrom(TContestStateQSOPartyBase)) then
         begin
         Continue;
         end;
      inc(parties);
      contestObject := Make(c, False);
      try
         ResetStub;
         GDomesticKeys := 'HOSTCOUNTY';
         GShapeSetsQTH := 'DX';
         exch := NewExch('DL1ABC', 'DL');
         ok := contestObject.ParseReceivedExchange('599 DX',
                  Session(contestObject.ExchangeKind, True), exch, msg);
         CheckFalse(ok, string(ContestTypeSA[c]) + ': out of state, a DX station is refused');
         CheckTrue(msg <> '', string(ContestTypeSA[c]) + ': and the refusal says why');
      finally
         contestObject.Free;
      end;
      end;
   CheckTrue(parties >= 19, 'every single-state party was asked -- found ' + IntToStr(parties));
end;

procedure TContestParseTests.Test_RussianDXInitialExchangeIsTheOblast;
var
   answer: string;
   c: ContestType;
begin
   BeginTest('Test_RussianDXInitialExchangeIsTheOblast');
   for c in [RUSSIANDX, RU3AXMEMORIAL] do
      begin
      CheckTrue(ContestIdentity(c).InitialExchangeFromCall('UA3ABC', 'UA', answer),
                string(ContestTypeSA[c]) + ': a Russian station has an answer');
      CheckEquals(GetRussiaOblastID('UA3ABC'), answer,
                  string(ContestTypeSA[c]) + ': its oblast');
      CheckTrue(ContestIdentity(c).InitialExchangeFromCall('UA9ABC', 'UA9', answer),
                string(ContestTypeSA[c]) + ': Asiatic Russia too');
      CheckFalse(ContestIdentity(c).InitialExchangeFromCall('DL1ABC', 'DL', answer),
                 string(ContestTypeSA[c]) + ': anybody else, none');
      CheckFalse(ContestIdentity(c).InitialExchangeFromCall('VE3ABC', 'VE', answer),
                 string(ContestTypeSA[c]) + ': and a Canadian is the province rule''s');
      end;
   CheckFalse(ContestIdentity(WRTC).InitialExchangeFromCall('UA3ABC', 'UA', answer),
              'the base has no answer');
end;

(* ---------------------------------------------------------------------------
   THE LIFTED WORD CUTTING
   --------------------------------------------------------------------------- *)

procedure TContestParseTests.Test_SplitExchangeInThree;
var
   a, b, c: Str10;
begin
   BeginTest('Test_SplitExchangeInThree');
   SplitExchangeInThree('', a, b, c);
   CheckEquals('||', string(a) + '|' + string(b) + '|' + string(c), 'nothing');
   SplitExchangeInThree('599', a, b, c);
   CheckEquals('599||', string(a) + '|' + string(b) + '|' + string(c), 'one word');
   SplitExchangeInThree('599 123', a, b, c);
   CheckEquals('599|123|', string(a) + '|' + string(b) + '|' + string(c), 'two');
   SplitExchangeInThree('599 123 LN XX', a, b, c);
   CheckEquals('599|123|LN XX', string(a) + '|' + string(b) + '|' + string(c),
               'the third holds the rest');
   SplitExchangeInThree('599  123', a, b, c);
   CheckEquals('599|123|', string(a) + '|' + string(b) + '|' + string(c), 'blanks between collapse');
   (* LOGSTUFF's quirks, kept: a leading blank makes an empty first word, and
      a first word longer than ten characters is cut at ten and the rest of
      the cut-off word is lost. *)
   SplitExchangeInThree(' 599', a, b, c);
   CheckEquals('|599|', string(a) + '|' + string(b) + '|' + string(c), 'a leading blank');
   SplitExchangeInThree('12345678901 X', a, b, c);
   CheckEquals('1234567890|X|', string(a) + '|' + string(b) + '|' + string(c),
               'a first word over ten characters');
end;

procedure TContestParseTests.Test_SweepstakesWordReading;
var
   f: TSweepstakesFields;
begin
   BeginTest('Test_SweepstakesWordReading');
   ScanSweepstakesExchange('123 A 99 CT', f);
   CheckEquals('123|A|99|CT', string(f.Number) + '|' + string(f.Prec) + '|' +
               string(f.Check) + '|' + string(f.Section), 'four words');
   ScanSweepstakesExchange('123A 99CT', f);
   CheckEquals('123|A|99|CT', string(f.Number) + '|' + string(f.Prec) + '|' +
               string(f.Check) + '|' + string(f.Section), 'packed');
   ScanSweepstakesExchange('A99CT 123', f);
   CheckEquals('123|A|99|CT', string(f.Number) + '|' + string(f.Prec) + '|' +
               string(f.Check) + '|' + string(f.Section), 'precedence, check and section in one word');
   ScanSweepstakesExchange('123 99 CT', f);
   CheckTrue(f.Prec = Chr(0), 'no precedence');
   ScanSweepstakesExchange('123 AB', f);
   CheckTrue(f.Prec = Chr(0), 'AB is a section (Alberta), not a precedence');
   CheckEquals('AB', string(f.Section), 'read as the section');
end;

procedure TContestParseTests.Test_IsSingleNonNumericToken;
begin
   BeginTest('Test_IsSingleNonNumericToken');
   CheckTrue(IsSingleNonNumericToken('ARRL'), 'one word');
   CheckTrue(IsSingleNonNumericToken('  DAL  '), 'outer blanks trimmed');
   CheckFalse(IsSingleNonNumericToken('DAL/BAY'), 'a county line is two words');
   CheckFalse(IsSingleNonNumericToken('599 DAL'), 'two words');
   CheckFalse(IsSingleNonNumericToken('8'), 'a number');
end;

(* ---------------------------------------------------------------------------
   FIELD DAY'S DX, AND NC'S COUNTIES
   --------------------------------------------------------------------------- *)

(* NY4I (design Q1, Q25): DX is never an ARRL section -- on the way in either. *)
procedure TContestParseTests.Test_FieldDayImportDXIsNotASection;
var
   temps: TADIFRecordTemps;
   session: TADIFImportSession;
   exch: ContestExchange;
   fd: ContestType;
begin
   BeginTest('Test_FieldDayImportDXIsNotASection');
   FillChar(session, SizeOf(session), 0);
   for fd in [ARRLFIELDDAY, WINTERFIELDDAY] do
      begin
      FillChar(temps, SizeOf(temps), 0);
      exch := NewExch('DL1ABC', 'DL');
      exch.QTHString := 'DX';
      ContestIdentity(fd).ApplyADIFImport(temps, session, exch);
      CheckEquals('DX', string(exch.QTHString), string(ContestTypeSA[fd]) + ': QTH DX stays the QTH');
      CheckEquals('', string(exch.DomesticQTH), string(ContestTypeSA[fd]) + ': and is no section');

      FillChar(temps, SizeOf(temps), 0);
      temps.ARRL_Sect := 'DX';
      exch := NewExch('DL1ABC', 'DL');
      ContestIdentity(fd).ApplyADIFImport(temps, session, exch);
      CheckEquals('DX', string(exch.QTHString), string(ContestTypeSA[fd]) + ': another logger''s ARRL_SECT DX');
      CheckEquals('', string(exch.DomesticQTH), string(ContestTypeSA[fd]) + ': is no section either');

      FillChar(temps, SizeOf(temps), 0);
      temps.ARRL_Sect := 'WCF';
      exch := NewExch('W4ABC', 'K');
      ContestIdentity(fd).ApplyADIFImport(temps, session, exch);
      CheckEquals('WCF', string(exch.DomesticQTH), string(ContestTypeSA[fd]) + ': a section is a section');
      end;
end;

function ShippedDomDir: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
             'target' + PathDelim + 'dom' + PathDelim;
end;

(* EVERY KEY A DOM FILE DECLARES, upper case, in file order -- the reading
   FoundMyStateInDomFile and the matrix apply. *)
function DomFileKeys(const aPath: string): TStringList;
var
   lines: TStringList;
   i: integer;
   key: string;
begin
   Result := TStringList.Create;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(aPath));
      for i := 0 to lines.Count - 1 do
         begin
         key := DomFileLineKey(string(lines[i]));
         if key <> '' then
            begin
            Result.Add(AnsiString(key));
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* THE SPONSOR'S HUNDRED COUNTIES (design Q14, 7.10), from
   https://ncqsoparty.org/wp-content/uploads/2022/11/NCQP_Abbreviations_221121.pdf
   -- the abbreviations NCQP publishes, read 2026-10-02. *)
procedure TContestParseTests.Test_NCCountyFileIsTheSponsorsList;
const
   SPONSOR = 'ALA ALE ALL ANS ASH AVE BEA BER BLA BRU BUN BUR CAB CAL CAM CAR CAS ' +
             'CAT CHA CHE CHO CLA CLE COL CRA CUM CUR DAR DVD DAV DUP DUR EDG FOR ' +
             'FRA GAS GAT GRM GRA GRE GUI HAL HAR HAY HEN HER HOK HYD IRE JAC JOH ' +
             'JON LEE LEN LIN MAC MAD MAR MCD MEC MIT MON MOO NAS NEW NOR ONS ORA ' +
             'PAM PAS PEN PEQ PER PIT POL RAN RIC ROB ROC ROW RUT SAM SCO STA STO ' +
             'SUR SWA TRA TYR UNI VAN WAK WAR WAS WAT WAY WLK WIL YAD YAN';
var
   keys: TStringList;
   expected: TStringList;
   i: integer;
begin
   BeginTest('Test_NCCountyFileIsTheSponsorsList');
   expected := TStringList.Create;
   keys := DomFileKeys(ShippedDomDir + ContestIdentity(NCQSOPARTY).DomesticFileName + '.dom');
   try
      expected.Delimiter := ' ';
      expected.DelimitedText := AnsiString(SPONSOR);
      CheckEquals(100, expected.Count, 'the sponsor lists a hundred');
      CheckEquals(100, keys.Count, 'nc_cty.dom declares a hundred keys');
      expected.Sort;
      keys.Sort;
      for i := 0 to expected.Count - 1 do
         begin
         if i < keys.Count then
            begin
            CheckEquals(string(expected[i]), string(keys[i]), 'county ' + IntToStr(i + 1));
            end;
         end;
   finally
      keys.Free;
      expected.Free;
   end;
end;

(* A PARTY'S COUNTY FILE IS COUNTIES. It is what an out-of-state station
   loads, so whatever else it declared -- NC's pulled in the fifty states with
   an INCLUDE and listed DC and the provinces -- an out-of-state station could
   work, and a station from there counted as "in state". No county file
   includes another; the in-state file is where the rest belongs. *)
procedure TContestParseTests.Test_EveryPartyCountyFileHoldsOnlyCounties;
var
   c: ContestType;
   cls: TContestClass;
   lines: TStringList;
   i: integer;
   path: string;
begin
   BeginTest('Test_EveryPartyCountyFileHoldsOnlyCounties');
   for c := Succ(Low(ContestType)) to High(ContestType) do
      begin
      cls := ContestClassFor(c);
      if (cls = nil) or (not cls.InheritsFrom(TContestStateQSOPartyBase)) then
         begin
         Continue;
         end;
      path := ShippedDomDir + ContestIdentity(c).DomesticFileName + '.dom';
      CheckTrue(FileExists(path), string(ContestTypeSA[c]) + ': its county file ships');
      if not FileExists(path) then
         begin
         Continue;
         end;
      lines := TStringList.Create;
      try
         lines.LoadFromFile(AnsiString(path));
         for i := 0 to lines.Count - 1 do
            begin
            CheckFalse(Pos('INCLUDE', UpperCase(Trim(string(lines[i])))) = 1,
                       string(ContestTypeSA[c]) + ': ' + ContestIdentity(c).DomesticFileName +
                       '.dom line ' + IntToStr(i + 1) + ' includes another file');
            end;
      finally
         lines.Free;
      end;
      end;
end;

procedure TContestParseTests.RunAllTests;
begin
   Test_BaseParsesTheSessionsShape;
   Test_RACVE0SendsASerial;
   Test_PCCLettersAreAQTH;
   Test_ArktikaDigitsAreASerial;
   Test_LABREPYSendsAState;
   Test_IARUSocietyGetsItsZone;
   Test_UKEIStationMustSendTwoWords;
   Test_SACAbandonsARussianLiveEntry;
   Test_SweepstakesNamesAMissingPrecedence;
   Test_OutOfStateWorksOnlyTheHostState;
   Test_EveryStatePartyRefusesAnOutOfStateContact;
   Test_RussianDXInitialExchangeIsTheOblast;
   Test_SplitExchangeInThree;
   Test_SweepstakesWordReading;
   Test_IsSingleNonNumericToken;
   Test_FieldDayImportDXIsNotASection;
   Test_NCCountyFileIsTheSponsorsList;
   Test_EveryPartyCountyFileHoldsOnlyCounties;
end;

end.
