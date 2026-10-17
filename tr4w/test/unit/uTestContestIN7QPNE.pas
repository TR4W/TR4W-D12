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

(* IN7QPNE, THE COMPOSITE -- design 7.14 and 8.2r (2026-10-14).

  NEW BEHAVIOUR, SO THE MATRIX'S FROZEN RECORD CANNOT JUDGE IT: these
  assertions are written from NY4I's ruling -- each QSO is judged by the
  party the WORKED station is in -- and from each component's own class,
  never read back out of the composite:

    * routing: each party's county keys, the shipped county file whole, and
      no state or province the in-state file includes;
    * points: one case per party, each equal to that party's own class;
    * a QSO in no party: the entrant's own party, else nothing;
    * multipliers and dupes: the party's rule and the party's bands;
    * the typed exchange: the party's parse, and the out-of-area refusal;
    * Cabrillo and ADIF: the IN7QPNE name and id, round trip;
    * no score posting. *)
unit uTestContestIN7QPNE;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestIN7QPNETests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_IN7QPNEIsACompositeOnTheBase;
      procedure Test_RoutingToEachParty;
      procedure Test_EveryCountyKeyRoutesToOneParty;
      procedure Test_PointsAreEachPartysOwn;
      procedure Test_AQSOInNoPartyIsTheEntrantsOrNothing;
      procedure Test_MultipliersArePerParty;
      procedure Test_DupesAndSessionTraits;
      procedure Test_ParseIsThePartysOwn;
      procedure Test_CabrilloAndADIFNameIN7QPNE;
      procedure Test_NoScorePosting;
   end;

implementation

uses
   Classes, SysUtils, VC, uContestBase, uContestRegistry,
   uContestIN7QPNE, uDomFileKeys, uAppStrings,
   uTestContestObjects,
   uTestExchangeParserStub;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

(* An entrant whose MY STATE is aMyState; aInArea is set-up's in-state
   answer (MY STATE is a key of in7qpne_cty.dom). *)
(* THE SESSION'S TABLE AS in7qpne_cty.dom HOLDS IT -- the four parties'
   counties and nothing else, the table an out-of-area entrant loads; the
   routing rule's spelling test answers it. Q107: the components' host-area
   rule asks it. *)
function StubIN7QPNECountyTable(const aQTH: string): boolean;
var
   party: TIN7QPNEParty;
begin
   Result := IN7QPNEPartyOfQTH(aQTH, party);
end;

function Entrant(const aMyState: string; aInArea: boolean): TStationContext;
begin
   Result := NoStation;
   Result.MyState := aMyState;
   Result.InHostState := aInArea;
   Result.IsDomesticQTH := @StubIN7QPNECountyTable;
end;

function OutOfArea: TStationContext;
begin
   Result := Entrant('KS', False);
end;

(* A QSO with the worked station's QTH as the domestic table resolves it. *)
function QsoAt(const aQTH: string; aBand: BandType; aMode: ModeType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.QTHString := ShortString(aQTH);
   Result.DomesticQTH := ShortString(aQTH);
   Result.DomMultQTH := ShortString(aQTH);
end;

function ScoreWith(aContest: ContestType; const aStation: TStationContext;
                   const aQso: ContestExchange): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   qso := aQso;
   qso.QSOPoints := 99;
   contestObject := Make(aContest, aStation);
   try
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

function Composite(const aStation: TStationContext): TContestIN7QPNE;
begin
   Result := Make(IN7QPNE, aStation) as TContestIN7QPNE;
end;

function PartyOf(const aQTH: string): string;
var
   party: TIN7QPNEParty;
begin
   if IN7QPNEPartyOfQTH(aQTH, party) then
      begin
      Result := string(ContestTypeSA[IN7QPNEPartyContest[party]]);
      end
   else
      begin
      Result := '(none)';
      end;
end;

(* EVERY KEY OF A SHIPPED dom FILE, AND OF THE FILES IT INCLUDES -- the
   reader's own rule (uDomFileKeys), the includes followed, as the engine's
   reader follows them. aSkip names a file whose keys are not wanted (its
   includes are not followed either). *)
procedure CollectDomKeys(const aFile: string; const aSkip: string;
                         aKeys: TStrings; aDepth: integer);
var
   lines: TStringList;
   i: integer;
   line, key: string;
begin
   if (aDepth > 4) or SameText(aFile, aSkip) then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + aFile));
      for i := 0 to lines.Count - 1 do
         begin
         line := Trim(string(lines[i]));
         if Pos('INCLUDE FILE ', UpperCase(line)) = 1 then
            begin
            CollectDomKeys(LowerCase(Trim(Copy(line, 14, MaxInt))), aSkip, aKeys, aDepth + 1);
            end
         else
            begin
            key := DomFileLineKey(line);
            if key <> '' then
               begin
               aKeys.Add(key);
               end;
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* THE STUBBED PARSE ENGINE, as uTestContestDelawareQP's: the shape resolves
   the QTH it is told to (as the table would, into DomesticQTH), and the
   domestic table knows the keys in GDomesticKeys. *)
var
   GShapeSetsQTH: string;
   GShapeAccepts: boolean;
   GDomesticKeys: string;

function StubParseShape(const aHelper: string; const aText: string;
                        var aExch: ContestExchange): boolean;
begin
   aExch.QTHString := ShortString(GShapeSetsQTH);
   aExch.DomesticQTH := ShortString(GShapeSetsQTH);
   aExch.DomMultQTH := ShortString(GShapeSetsQTH);
   Result := GShapeAccepts;
end;

function StubIsDomesticQTH(const aQTH: string): boolean;
begin
   Result := Pos(',' + UpperCase(aQTH) + ',', ',' + GDomesticKeys + ',') > 0;
end;

function Session: TReceivedExchangeSession;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.Parsers := StubExchangeParsers(@StubParseShape);
   Result.IsDomesticQTH := @StubIsDomesticQTH;
   Result.CallWindowHasCall := True;
end;

function ParseAs(const aStation: TStationContext; const aQTH: string;
                 out aMessage: string; out aExch: ContestExchange): boolean;
var
   contestObject: TContestBase;
begin
   GShapeSetsQTH := aQTH;
   contestObject := Make(IN7QPNE, aStation);
   try
      FillChar(aExch, SizeOf(aExch), 0);
      aExch.Callsign := 'W1AW';
      Result := contestObject.ParseReceivedExchange('599 ' + aQTH, Session, aExch, aMessage);
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   THE TESTS
   --------------------------------------------------------------------------- *)

(* A CLASS OF ITS OWN ON TContestBase -- not a state party (four host areas,
   not one), not a family. Set-up still treats it as a party by its row. *)
procedure TContestIN7QPNETests.Test_IN7QPNEIsACompositeOnTheBase;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_IN7QPNEIsACompositeOnTheBase');
   CheckTrue(ContestClassFor(IN7QPNE) = TContestIN7QPNE, 'registered');
   contestObject := Make(IN7QPNE);
   try
      CheckTrue(contestObject.ClassParent = TContestBase, 'directly on TContestBase');
      CheckTrue(contestObject.IsUSQSOParty, 'set-up runs the party head, by its row');
      CheckEquals('', contestObject.HostState, 'no single host state');
      CheckEquals('in7qpne_cty', contestObject.DomesticFileName, 'the four parties'' counties');
      CheckEquals('in7qpne', contestObject.InStateDomesticFileName, 'the in-area file');
      CheckEquals('Combined Indiana, 7th Call Area, New England and Delaware QSO Party',
                  contestObject.DisplayName, 'the display name is the friendly name');
      CheckTrue(contestObject.MarksDupes, 'marks dupes');
   finally
      contestObject.Free;
   end;

   CheckEquals(Ord(INQSOPARTY), Ord(IN7QPNEPartyContest[ipIndiana]), 'Indiana is IN QSO PARTY');
   CheckEquals(Ord(SEVENQP), Ord(IN7QPNEPartyContest[ipSevenQP]), '7QP');
   CheckEquals(Ord(NEWENGLANDQSO), Ord(IN7QPNEPartyContest[ipNewEngland]), 'NEQP');
   CheckEquals(Ord(DELAWAREQSOPARTY), Ord(IN7QPNEPartyContest[ipDelaware]), 'Delaware');
end;

(* THE COUNTY KEY SAYS THE PARTY, whatever its case: Indiana IN+3, 7QP's
   eight states +3, New England's six +3, Delaware's three keys. A state, a
   province, 'dx' or nothing is in no party. *)
procedure TContestIN7QPNETests.Test_RoutingToEachParty;
begin
   BeginTest('Test_RoutingToEachParty');
   CheckEquals('IN QSO PARTY', PartyOf('INADA'), 'an Indiana county');
   CheckEquals('7QP', PartyOf('Azaph'), 'an Arizona county, as the table spells it');
   CheckEquals('7QP', PartyOf('WYALB'), 'a Wyoming county, as typed');
   CheckEquals('7QP', PartyOf(' idada '), 'blanks and case ignored');
   CheckEquals('NEWEQP', PartyOf('MEAnd'), 'a Maine county');
   CheckEquals('NEWEQP', PartyOf('CTCap'), 'a Connecticut planning region');
   CheckEquals('DELAWARE QSO PARTY', PartyOf('NDE'), 'New Castle');
   CheckEquals('DELAWARE QSO PARTY', PartyOf('kde'), 'Kent');
   CheckEquals('DELAWARE QSO PARTY', PartyOf('SDE'), 'Sussex');

   CheckEquals('(none)', PartyOf('IN'), 'the state of Indiana is not a county');
   CheckEquals('(none)', PartyOf('DE'), 'nor Delaware');
   CheckEquals('(none)', PartyOf('FL'), 'Florida');
   CheckEquals('(none)', PartyOf('ON'), 'Ontario');
   CheckEquals('(none)', PartyOf('dx'), 'the in-area file''s DX');
   CheckEquals('(none)', PartyOf(''), 'nothing');
   CheckEquals('(none)', PartyOf('JAPAN'), 'five letters that start no party state');
   CheckEquals('(none)', PartyOf('ADE'), 'three letters ending DE that are not a county');
end;

(* THE CONVENTION HOLDS FOR THE SHIPPED FILES -- read, not assumed:

     * every key of in7qpne_cty.dom routes to a party, Delaware's exactly to
       its three;
     * no key the in-area file adds (the states, the provinces, 'dx')
       routes to any;
     * Indiana's, 7QP's and Delaware's OWN county files route to their
       party, so the combined file and theirs agree on those three.

   NEW ENGLAND IS THE EXCEPTION, AND IT IS PINNED AS ONE (design Q81): NEQP's
   own neqso.dom spells a county county-first (AndME), the combined file
   state-first (MEAnd), so NEQP's own keys do not route as NEQP's -- a few
   even read as another party's (WasVT starts WA). The session never loads
   neqso.dom for IN7QPNE, so routing is not affected; when the two files are
   reconciled, this assertion is the one to change. *)
procedure TContestIN7QPNETests.Test_EveryCountyKeyRoutesToOneParty;
var
   keys: TStringList;
   i: integer;
   party: TIN7QPNEParty;
   perParty: array[TIN7QPNEParty] of integer;
   p: TIN7QPNEParty;
   neRouted: integer;
begin
   BeginTest('Test_EveryCountyKeyRoutesToOneParty');
   for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
      begin
      perParty[p] := 0;
      end;

   keys := TStringList.Create;
   try
      CollectDomKeys('in7qpne_cty.dom', '', keys, 0);
      CheckTrue(keys.Count > 400, 'the combined county file was read');
      for i := 0 to keys.Count - 1 do
         begin
         CheckTrue(IN7QPNEPartyOfQTH(keys[i], party), keys[i] + ' routes to a party');
         inc(perParty[party]);
         end;
      CheckEquals(3, perParty[ipDelaware], 'Delaware: its three counties');
      CheckTrue(perParty[ipIndiana] > 0, 'Indiana has counties');
      CheckTrue(perParty[ipSevenQP] > 0, '7QP has counties');
      CheckTrue(perParty[ipNewEngland] > 0, 'New England has counties');

      keys.Clear;
      CollectDomKeys('IN7QPNE.dom', 'in7qpne_cty.dom', keys, 0);
      CheckTrue(keys.Count > 50, 'the in-area file''s states and provinces were read');
      for i := 0 to keys.Count - 1 do
         begin
         CheckFalse(IN7QPNEPartyOfQTH(keys[i], party), keys[i] + ' is in no party');
         end;

      keys.Clear;
      CollectDomKeys('in_cty.dom', '', keys, 0);
      for i := 0 to keys.Count - 1 do
         begin
         CheckEquals('IN QSO PARTY', PartyOf(keys[i]), 'Indiana''s own key ' + keys[i]);
         end;

      keys.Clear;
      CollectDomKeys('seven_cty.dom', '', keys, 0);
      for i := 0 to keys.Count - 1 do
         begin
         CheckEquals('7QP', PartyOf(keys[i]), '7QP''s own key ' + keys[i]);
         end;

      keys.Clear;
      CollectDomKeys('delaware_cty.dom', '', keys, 0);
      for i := 0 to keys.Count - 1 do
         begin
         CheckEquals('DELAWARE QSO PARTY', PartyOf(keys[i]), 'Delaware''s own key ' + keys[i]);
         end;

      keys.Clear;
      CollectDomKeys('neqso.dom', '', keys, 0);
      CheckTrue(keys.Count > 0, 'NEQP''s own county file was read');
      neRouted := 0;
      for i := 0 to keys.Count - 1 do
         begin
         if PartyOf(keys[i]) = 'NEWEQP' then
            begin
            inc(neRouted);
            end;
         end;
      CheckTrue(neRouted < keys.Count, 'NEQP''s own spelling is not the combined file''s (Q81)');
      CheckTrue(keys.IndexOf('ANDME') >= 0, 'NEQP spells Androscoggin ANDME');
      CheckEquals('(none)', PartyOf('ANDME'), 'which the combined convention does not route');
   finally
      keys.Free;
   end;
end;

(* ONE CASE PER PARTY, EACH EQUAL TO THAT PARTY'S OWN CLASS -- and to the
   number its rule gives, so a component that changed would be seen too.
   The entrant is outside all four areas unless said. *)
procedure TContestIN7QPNETests.Test_PointsAreEachPartysOwn;
var
   inDelaware: TStationContext;
begin
   BeginTest('Test_PointsAreEachPartysOwn');

   (* INDIANA: two a QSO, whatever the mode -- the merged rule gave phone 1. *)
   CheckEquals(2, ScoreWith(IN7QPNE, OutOfArea, QsoAt('INADA', Band20, Phone)), 'Indiana phone');
   CheckEquals(ScoreWith(INQSOPARTY, OutOfArea, QsoAt('INADA', Band20, Phone)),
               ScoreWith(IN7QPNE, OutOfArea, QsoAt('INADA', Band20, Phone)),
               'Indiana: the Indiana class''s answer');

   (* 7QP: three on CW, two otherwise. *)
   CheckEquals(3, ScoreWith(IN7QPNE, OutOfArea, QsoAt('Azaph', Band40, CW)), '7QP CW');
   CheckEquals(2, ScoreWith(IN7QPNE, OutOfArea, QsoAt('Azaph', Band40, Phone)), '7QP phone');
   CheckEquals(ScoreWith(SEVENQP, OutOfArea, QsoAt('Azaph', Band40, CW)),
               ScoreWith(IN7QPNE, OutOfArea, QsoAt('Azaph', Band40, CW)),
               '7QP: the 7QP class''s answer');

   (* NEW ENGLAND: two on CW, one otherwise. *)
   CheckEquals(2, ScoreWith(IN7QPNE, OutOfArea, QsoAt('MEAnd', Band80, CW)), 'NEQP CW');
   CheckEquals(1, ScoreWith(IN7QPNE, OutOfArea, QsoAt('MEAnd', Band80, Digital)), 'NEQP digital');
   CheckEquals(ScoreWith(NEWENGLANDQSO, OutOfArea, QsoAt('MEAnd', Band80, Phone)),
               ScoreWith(IN7QPNE, OutOfArea, QsoAt('MEAnd', Band80, Phone)),
               'NEQP: the NEQP class''s answer');

   (* DELAWARE: by the ENTRANT's location -- outside DE 20 CW, 10 phone; in
      DE 2 CW, 1 phone -- and nothing on its WARC bands. *)
   CheckEquals(20, ScoreWith(IN7QPNE, OutOfArea, QsoAt('NDE', Band20, CW)), 'DE, entrant outside, CW');
   CheckEquals(10, ScoreWith(IN7QPNE, OutOfArea, QsoAt('NDE', Band20, Phone)), 'DE, entrant outside, phone');
   CheckEquals(0, ScoreWith(IN7QPNE, OutOfArea, QsoAt('NDE', Band30, CW)), 'DE on 30 m: Delaware''s bands');
   CheckEquals(ScoreWith(DELAWAREQSOPARTY, Entrant('KS', False), QsoAt('SDE', Band15, Digital)),
               ScoreWith(IN7QPNE, OutOfArea, QsoAt('SDE', Band15, Digital)),
               'Delaware: the Delaware class''s answer, outside');

   inDelaware := Entrant('KDE', True);
   CheckEquals(1, ScoreWith(IN7QPNE, inDelaware, QsoAt('SDE', Band20, Phone)), 'DE, entrant in DE, phone');
   CheckEquals(2, ScoreWith(IN7QPNE, inDelaware, QsoAt('SDE', Band20, CW)), 'DE, entrant in DE, CW');
   CheckEquals(ScoreWith(DELAWAREQSOPARTY, inDelaware, QsoAt('NDE', Band20, CW)),
               ScoreWith(IN7QPNE, inDelaware, QsoAt('NDE', Band20, CW)),
               'Delaware: the Delaware class''s answer, inside');

   (* A DE ENTRANT WORKING ANOTHER PARTY IS OUTSIDE THAT PARTY: 7QP's rule. *)
   CheckEquals(3, ScoreWith(IN7QPNE, inDelaware, QsoAt('Wyalb', Band20, CW)), 'DE entrant works 7QP');
end;

(* A QSO WHOSE QTH IS IN NO PARTY -- a state, a province, DX -- belongs to the
   ENTRANT's party when the entrant is in one, and to none otherwise. *)
procedure TContestIN7QPNETests.Test_AQSOInNoPartyIsTheEntrantsOrNothing;
var
   contestObject: TContestIN7QPNE;
   party: TIN7QPNEParty;
   inSeven: TStationContext;
begin
   BeginTest('Test_AQSOInNoPartyIsTheEntrantsOrNothing');
   inSeven := Entrant('Azaph', True);

   CheckEquals(3, ScoreWith(IN7QPNE, inSeven, QsoAt('FL', Band20, CW)), 'a 7QP entrant works FL: 7QP''s 3');
   CheckEquals(2, ScoreWith(IN7QPNE, inSeven, QsoAt('', Band20, Phone)), 'a 7QP entrant works DX: 7QP''s 2');
   CheckEquals(2, ScoreWith(IN7QPNE, Entrant('INALL', True), QsoAt('ON', Band20, Phone)),
               'an Indiana entrant works ON: Indiana''s 2');
   CheckEquals(2, ScoreWith(IN7QPNE, Entrant('KDE', True), QsoAt('PA', Band20, CW)),
               'a Delaware entrant works PA: Delaware''s in-state 2');

   CheckEquals(0, ScoreWith(IN7QPNE, OutOfArea, QsoAt('FL', Band20, CW)), 'outside, working FL: no party, 0');
   CheckEquals(0, ScoreWith(IN7QPNE, OutOfArea, QsoAt('', Band20, CW)), 'outside, working DX: 0');
   CheckEquals(0, ScoreWith(IN7QPNE, Entrant('Azaph', False), QsoAt('FL', Band20, CW)),
               'MY STATE a county but set-up found it out of state: in no party');
   CheckEquals(0, ScoreWith(IN7QPNE, Entrant('KS', True), QsoAt('FL', Band20, CW)),
               'in state by set-up but MY STATE in no party: no party');

   contestObject := Composite(inSeven);
   try
      CheckTrue(contestObject.JudgingParty(QsoAt('MEAnd', Band20, CW), party), 'a 7QP entrant works NE');
      CheckEquals(Ord(ipNewEngland), Ord(party), 'the WORKED station''s party judges it');
      CheckTrue(contestObject.JudgingParty(QsoAt('FL', Band20, CW), party), 'a 7QP entrant works FL');
      CheckEquals(Ord(ipSevenQP), Ord(party), 'the entrant''s party judges it');
   finally
      contestObject.Free;
   end;

   contestObject := Composite(OutOfArea);
   try
      CheckFalse(contestObject.JudgingParty(QsoAt('FL', Band20, CW), party), 'outside, working FL: no party');
   finally
      contestObject.Free;
   end;
end;

(* MULTIPLIERS ARE THE PARTY'S: Indiana's "a DX QTH earns none", Delaware's
   bands, and nothing for a QSO in no party. Which multiplier a QTH counts
   AS is the session's one table's -- not testable here, and design 8.2r's
   finding. *)
procedure TContestIN7QPNETests.Test_MultipliersArePerParty;
const
   KINDS: array[0..3] of RemainingMultiplierType = (rmDomestic, rmDX, rmZone, rmPrefix);
var
   contestObject: TContestBase;
   i: integer;
begin
   BeginTest('Test_MultipliersArePerParty');

   contestObject := Make(IN7QPNE, Entrant('INALL', True));
   try
      CheckFalse(contestObject.CountsAsMultiplier(QsoAt('DX', Band20, CW), rmDomestic),
                 'an Indiana entrant: Indiana''s rule, DX is no multiplier');
      CheckTrue(contestObject.CountsAsMultiplier(QsoAt('INADA', Band20, CW), rmDomestic),
                'an Indiana entrant: an Indiana county is one');
   finally
      contestObject.Free;
   end;

   contestObject := Make(IN7QPNE, Entrant('Azaph', True));
   try
      CheckTrue(contestObject.CountsAsMultiplier(QsoAt('DX', Band20, CW), rmDomestic),
                'a 7QP entrant: 7QP has no such rule');
   finally
      contestObject.Free;
   end;

   contestObject := Make(IN7QPNE, OutOfArea);
   try
      CheckTrue(contestObject.CountsAsMultiplier(QsoAt('NDE', Band20, CW), rmDomestic),
                'a Delaware county on 20 m');
      CheckFalse(contestObject.CountsAsMultiplier(QsoAt('NDE', Band30, CW), rmDomestic),
                 'a Delaware county on 30 m: Delaware''s bands');
      CheckFalse(contestObject.CountsAsMultiplier(QsoAt('Azaph', Band30, CW), rmDomestic),
                 'a 7QP county on 30 m: 7QP''s bands have no WARC (2026-10-16)');
      CheckTrue(contestObject.CountsAsMultiplier(QsoAt('Azaph', Band160, CW), rmDomestic),
                'a 7QP county on 160 m');
      for i := Low(KINDS) to High(KINDS) do
         begin
         CheckFalse(contestObject.CountsAsMultiplier(QsoAt('FL', Band20, CW), KINDS[i]),
                    'a QSO in no party earns nothing, kind ' + IntToStr(Ord(KINDS[i])));
         end;
   finally
      contestObject.Free;
   end;
end;

(* ONE DUPE RULE FOR THE SESSION, AND IT IS EVERY PARTY'S: each of the four
   works a station once per band per mode, and marks dupes. THE BAND
   QUESTION ASKED WITHOUT A QSO cannot route, so the composite credits every
   band there (the dupe sheet, the need-multiplier hint); the party's bands
   are applied per QSO above.

   THE SESSION TRAITS THAT DIFFER ARE PINNED AS FINDINGS (design 8.2r):
   Delaware counts multipliers per band and turns VHF on; the session, one
   value for all four, keeps the row's once-per-contest and no VHF. *)
procedure TContestIN7QPNETests.Test_DupesAndSessionTraits;
var
   contestObject, component: TContestBase;
   p: TIN7QPNEParty;
   b: BandType;
begin
   BeginTest('Test_DupesAndSessionTraits');
   contestObject := Make(IN7QPNE);
   try
      for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
         begin
         component := Make(IN7QPNEPartyContest[p]);
         try
            CheckEquals(Ord(component.QSOByBand), Ord(contestObject.QSOByBand),
                        component.DisplayName + ': once per band, as the session');
            CheckEquals(Ord(component.QSOByMode), Ord(contestObject.QSOByMode),
                        component.DisplayName + ': once per mode, as the session');
            CheckTrue(component.MarksDupes, component.DisplayName + ' marks dupes');
         finally
            component.Free;
         end;
         end;
      CheckTrue(contestObject.QSOByBand and contestObject.QSOByMode, 'per band, per mode');

      (* THE UNION OF THE FOUR PARTIES' BANDS since 2026-10-16 -- it credited
         every band before. uTestQSOPartyBands pins each party's set. *)
      for b := Low(BandType) to High(BandType) do
         begin
         CheckEquals(Ord(not (b in [Band30, Band17, Band12, AllBands, NoBand])),
                     Ord(ContestCreditsBand(contestObject, b)),
                     'the band question with no QSO: the union, band ' + IntToStr(Ord(b)));
         end;

      CheckFalse(contestObject.MultByBand, 'the session: once per contest (the row)');
      CheckTrue(ContestIdentity(DELAWAREQSOPARTY).MultByBand, 'Delaware alone: per band -- a finding');
      CheckTrue(contestObject.VHFBandsEnabled,
                'the session: VHF on since 2026-10-16, for Delaware''s 6 m up');
      CheckTrue(ContestIdentity(DELAWAREQSOPARTY).VHFBandsEnabled, 'Delaware alone: VHF on -- a finding');
   finally
      contestObject.Free;
   end;
end;

(* THE TYPED EXCHANGE IS PARSED BY THE JUDGING PARTY. A QSO in no party,
   from an entrant in no party, is refused with the out-of-area reason; a
   shape refusal stands as the shape left it. *)
procedure TContestIN7QPNETests.Test_ParseIsThePartysOwn;
var
   msg: string;
   exch: ContestExchange;
begin
   BeginTest('Test_ParseIsThePartysOwn');
   GShapeAccepts := True;
   GDomesticKeys := 'INADA,AZAPH,MEAND,NDE,KDE,SDE';

   CheckTrue(ParseAs(OutOfArea, 'AZAPH', msg, exch), 'outside, a 7QP county');
   CheckEquals('', msg, 'nothing to say');
   CheckEquals('AZAPH', string(exch.QTHString), 'the party''s parse wrote the QTH');
   CheckTrue(ParseAs(OutOfArea, 'NDE', msg, exch), 'outside, a Delaware county');

   (* THE PARTY ITSELF ANSWERED: Delaware's own out-of-state refusal, when
      the session's table does not know the county. Only Delaware's class
      says "DE". *)
   GDomesticKeys := 'INADA,AZAPH,MEAND';
   CheckFalse(ParseAs(OutOfArea, 'NDE', msg, exch), 'Delaware''s own refusal');
   CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, ['DE']), msg, 'in Delaware''s words');
   GDomesticKeys := 'INADA,AZAPH,MEAND,NDE,KDE,SDE';

   CheckFalse(ParseAs(OutOfArea, 'FL', msg, exch), 'outside, a Florida station: in no party');
   CheckEquals(Format(SExchangeOutOfStateWorksHostOnly, [IN7QPNEPartyAreas]), msg,
               'refused with the out-of-area reason');

   CheckTrue(ParseAs(Entrant('KDE', True), 'FL', msg, exch), 'a Delaware entrant works Florida');
   CheckTrue(ParseAs(Entrant('Azaph', True), 'FL', msg, exch), 'a 7QP entrant works Florida');

   GShapeAccepts := False;
   CheckFalse(ParseAs(Entrant('KDE', True), 'XYZ', msg, exch), 'the shape refuses');
   CheckEquals('', msg, 'with no reason of the contest''s');
   CheckEquals('XYZ', string(exch.QTHString), 'and the record as the shape left it');
   GShapeAccepts := True;
end;

(* ONE COMBINED LOG UNDER THE IN7QPNE NAME, never a component's; the ADIF id
   export writes is the one import resolves. *)
procedure TContestIN7QPNETests.Test_CabrilloAndADIFNameIN7QPNE;
var
   contestObject: TContestBase;
   c: TContestHandle;
   p: TIN7QPNEParty;
begin
   BeginTest('Test_CabrilloAndADIFNameIN7QPNE');
   contestObject := Make(IN7QPNE);
   try
      CheckEquals('IN7QPNE-QSO-PARTY', contestObject.CabrilloName, 'the Cabrillo name');
      CheckEquals('IN7QPNE-QSO-PARTY', contestObject.CabrilloContestName('2027 IN7QPNE NY4I', 'X'),
                  'the CONTEST: line, whatever the title');
      for p := Low(TIN7QPNEParty) to High(TIN7QPNEParty) do
         begin
         CheckTrue(contestObject.CabrilloName <> ContestIdentity(IN7QPNEPartyContest[p]).CabrilloName,
                   'not ' + ContestIdentity(IN7QPNEPartyContest[p]).CabrilloName);
         end;
      CheckEquals('IN7QPNE-QSO-PARTY', contestObject.ADIFContestId, 'the ADIF id');
      CheckTrue(contestObject.WritesADIFContestId, 'export writes it');
   finally
      contestObject.Free;
   end;

   CheckTrue(FindContestByADIFContestId('IN7QPNE-QSO-PARTY', c), 'import resolves it');
   CheckEquals(Ord(IN7QPNE), c.ToByte, 'to IN7QPNE');
end;

(* NOT POSTED TO HAMSCORE OR THE SCOREBOARD (design 7.14): the contest says
   so through the aids it permits, as WRTC does. The menus, the post-scores
   window and the HamScore uploader read it. *)
procedure TContestIN7QPNETests.Test_NoScorePosting;
begin
   BeginTest('Test_NoScorePosting');
   CheckFalse(oaScorePosting in ContestIdentity(IN7QPNE).PermittedOperatingAids, 'no score posting');
   CheckTrue(ContestIdentity(IN7QPNE).PermittedOperatingAids = [oaSuperCheckPartial, oaDXCluster],
             'Super Check Partial and the cluster stay');
end;

procedure TContestIN7QPNETests.RunAllTests;
begin
   Test_IN7QPNEIsACompositeOnTheBase;
   Test_RoutingToEachParty;
   Test_EveryCountyKeyRoutesToOneParty;
   Test_PointsAreEachPartysOwn;
   Test_AQSOInNoPartyIsTheEntrantsOrNothing;
   Test_MultipliersArePerParty;
   Test_DupesAndSessionTraits;
   Test_ParseIsThePartysOwn;
   Test_CabrilloAndADIFNameIN7QPNE;
   Test_NoScorePosting;
end;

end.
