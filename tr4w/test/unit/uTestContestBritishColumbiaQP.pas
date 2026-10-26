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

(* THE BRITISH COLUMBIA QSO PARTY'S 2026 RULES (#88, checked 2026-10-26).
  The sponsor's texts are docs/ContestRules/QSOParties/BritishColumbia/
  (BC-QSO-PARTY-Rules.txt, -FAQ.txt, -Districts.txt); each test quotes the
  rule it holds.

    * points: CW 4, phone 2 -- FM is phone;
    * "Contest bands: 160m to 10m, no WARC bands. Contest modes: Phone and
      CW" -- off either is an automatic X-QSO;
    * VA7ODX: +20 after the multiplication, once on each band in each mode,
      never for a dupe or an X-QSO, and the FAQ's two worked examples;
    * "Maryland and DC are lumped together as MD" (ve7.dom, through the real
      loader). *)
unit uTestContestBritishColumbiaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestBritishColumbiaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_BritishColumbiaPoints;
      procedure Test_BritishColumbiaBands;
      procedure Test_BritishColumbiaModes;
      procedure Test_BritishColumbiaVA7ODXOncePerBandAndMode;
      procedure Test_BritishColumbiaFAQExamples;
      procedure Test_BritishColumbiaCountsDCAsMaryland;
   end;

implementation

uses
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uContestRegistry,
   LogDom,
   uTestContestObjects,
   uTestShippedDom;

(* A BC entrant (Delta) or one in Washington; outside the province the
   host-area table knows every QTH, so a points test is not about that
   rule. *)
function Entrant(aInProvince: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInProvince;
   if aInProvince then
      begin
      Result.MyState := 'DEL';
      end
   else
      begin
      Result.MyState := 'WA';
      end;
end;

function BCQso(const aCall: string; aBand: BandType; aMode: ModeType;
               aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := ShortString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'DEL';
   Result.DomesticQTH := 'DEL';
end;

(* What ScoreQSO gives -- the one public scoring entry. *)
function PointsFor(aInProvince: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(BCQP, Entrant(aInProvince));
   try
      qso := BCQso('VE7ABC', aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "2 points for Phone QSOs; 4 points for CW QSOs" -- and the FAQ: "CW
   contacts are worth 4 points. SSB contacts are worth 2 points." FM is
   phone. Inside the province and outside it alike. *)
procedure TContestBritishColumbiaQPTests.Test_BritishColumbiaPoints;
var
   inProvince: boolean;
   who: string;
begin
   BeginTest('Test_BritishColumbiaPoints');
   for inProvince := False to True do
      begin
      if inProvince then
         begin
         who := 'in BC';
         end
      else
         begin
         who := 'outside BC';
         end;
      CheckEquals(4, PointsFor(inProvince, Band20, CW, eCW), who + ': CW is 4');
      CheckEquals(2, PointsFor(inProvince, Band20, Phone, eSSB), who + ': phone is 2');
      CheckEquals(2, PointsFor(inProvince, Band10, FM, eFM), who + ': FM is phone, 2');
      CheckEquals(0, PointsFor(inProvince, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inProvince, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "Contest bands: 160m to 10m, no WARC bands." Every BandType, both ways. *)
procedure TContestBritishColumbiaQPTests.Test_BritishColumbiaBands;
const
   SPONSOR_BANDS = [Band160, Band80, Band40, Band20, Band15, Band10];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_BritishColumbiaBands');
   identity := ContestIdentity(BCQP);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in SPONSOR_BANDS;
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor lists it');
      qso := BCQso('VE7ABC', b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if expected then
         begin
         CheckEquals(4, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 4');
         end
      else
         begin
         CheckEquals(0, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores 0');
         end;
      end;
end;

(* "Contest modes: Phone and CW". No digital submode is credited; CW, phone
   and FM are, whatever the submode. Until #88 a digital QSO scored the CW
   value, 4. *)
procedure TContestBritishColumbiaQPTests.Test_BritishColumbiaModes;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
begin
   BeginTest('Test_BritishColumbiaModes');
   identity := ContestIdentity(BCQP);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'no digital submode is credited, ext ' + IntToStr(Ord(ext)));
      qso := BCQso('VE7ABC', Band20, Digital, ext);
      CheckTrue(QSOIsXQSO(identity, qso), 'a digital QSO is an X-QSO, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, FM, ext), 'FM is credited, ext ' + IntToStr(Ord(ext)));
      end;
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckEquals(0, PointsFor(True, Band20, Digital, eRTTY), 'in BC, an RTTY QSO scores 0');
   CheckEquals(0, PointsFor(False, Band20, Digital, eNoMode), 'outside BC, a digital QSO scores 0');
end;

(* "Any QSO with the Orca DXCC station, VA7ODX, will be worth an additional
   20 points." "The same station may be worked for QSO points on each band
   on CW and Phone" -- so once on each band in each mode. A dupe is not a
   QSO, nor is an X-QSO (a WARC band, a digital mode); another call, or
   VA7ODX/P, is not VA7ODX. *)
procedure TContestBritishColumbiaQPTests.Test_BritishColumbiaVA7ODXOncePerBandAndMode;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   dupe: ContestExchange;
   xqso: ContestExchange;
begin
   BeginTest('Test_BritishColumbiaVA7ODXOncePerBandAndMode');
   t := Default(TScoreTotals);
   view := TLoggedQSOList.Create;
   contestObject := Make(BCQP, Entrant(False));
   try
      CheckEquals(0, contestObject.BonusPoints(t, view), 'an empty log');

      view.Add(BCQso('VA7ODX', Band20, CW, eCW));
      CheckEquals(20, contestObject.BonusPoints(t, view), '20 m CW: 20');

      view.Add(BCQso('VA7ODX', Band20, CW, eCW));
      CheckEquals(20, contestObject.BonusPoints(t, view), '20 m CW again: still 20');

      view.Add(BCQso('VA7ODX', Band40, CW, eCW));
      CheckEquals(40, contestObject.BonusPoints(t, view), '40 m CW: a second band, 40');

      view.Add(BCQso('VA7ODX', Band20, Phone, eSSB));
      CheckEquals(60, contestObject.BonusPoints(t, view), '20 m phone: a second mode, 60');

      view.Add(BCQso('VA7ODX', Band20, FM, eFM));
      CheckEquals(60, contestObject.BonusPoints(t, view), '20 m FM is 20 m phone: still 60');

      dupe := BCQso('VA7ODX', Band15, CW, eCW);
      dupe.ceDupe := True;
      view.Add(dupe);
      CheckEquals(60, contestObject.BonusPoints(t, view), 'a dupe on 15 m CW pays nothing');

      xqso := BCQso('VA7ODX', Band10, CW, eCW);
      xqso.ceXQSO := True;
      view.Add(xqso);
      CheckEquals(60, contestObject.BonusPoints(t, view), 'an operator''s X-QSO on 10 m pays nothing');

      view.Add(BCQso('VA7ODX', Band30, CW, eCW));
      CheckEquals(60, contestObject.BonusPoints(t, view), 'a WARC QSO is an X-QSO and pays nothing');

      view.Add(BCQso('VA7ODX', Band80, Digital, eRTTY));
      CheckEquals(60, contestObject.BonusPoints(t, view), 'a digital QSO is an X-QSO and pays nothing');

      view.Add(BCQso('VA7ODX/P', Band160, CW, eCW));
      view.Add(BCQso('VE7ODX', Band160, CW, eCW));
      CheckEquals(60, contestObject.BonusPoints(t, view), 'another call pays nothing');

      view.Add(BCQso('VA7ODX', Band15, CW, eCW));
      CheckEquals(80, contestObject.BonusPoints(t, view),
                  'a valid 15 m CW QSO after the dupe pays: 80');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* THE FAQ'S TWO WORKED EXAMPLES, as hand-built totals: "Bonus points are
   added after calculating QSO points and location multipliers."
     Example 1: 100 CW QSOs, 33 multipliers, 5 QSOs with VA7ODX --
       ((100 x 4) x 33) + (5 x 20) = 13,300.
     Example 2: 25 CW and 25 SSB QSOs, 50 multipliers, 6 QSOs with VA7ODX
       -- (((25 x 4) + (25 x 2)) x 50) + (6 x 20) = 7,620.
   The VA7ODX QSOs are on distinct bands and modes, as the rule lets them
   be. *)
procedure TContestBritishColumbiaQPTests.Test_BritishColumbiaFAQExamples;
const
   HF: array[0..5] of BandType = (Band160, Band80, Band40, Band20, Band15, Band10);
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   i: integer;
begin
   BeginTest('Test_BritishColumbiaFAQExamples');
   view := TLoggedQSOList.Create;
   contestObject := Make(BCQP, Entrant(True));
   try
      t := Default(TScoreTotals);
      t.ScoredBand := AllBands;
      t.SessionCountsMultipliers := True;
      t.QSOPoints := 100 * 4;
      t.Mults[AllBands, Both, rmDomestic] := 33;
      for i := 0 to 4 do
         begin
         view.Add(BCQso('VA7ODX', HF[i], CW, eCW));
         end;
      CheckEquals(13300, contestObject.FinalScore(t, view), 'Example 1: 13,300');

      view.Clear;
      t.QSOPoints := (25 * 4) + (25 * 2);
      t.Mults[AllBands, Both, rmDomestic] := 50;
      for i := 0 to 2 do
         begin
         view.Add(BCQso('VA7ODX', HF[i], CW, eCW));
         view.Add(BCQso('VA7ODX', HF[i], Phone, eSSB));
         end;
      CheckEquals(7620, contestObject.FinalScore(t, view), 'Example 2: 7,620');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* "Maryland and DC are lumped together as MD." A BC entrant's multipliers
   include the states, so ve7.dom -- the in-province file -- maps DC to MD;
   read through the real loader with its INCLUDEs. *)
procedure TContestBritishColumbiaQPTests.Test_BritishColumbiaCountsDCAsMaryland;
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_BritishColumbiaCountsDCAsMaryland');
   CheckEquals('ve7', ContestIdentity(BCQP).InStateDomesticFileName,
               've7.dom is the in-province file');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      CheckEquals('VE7_CTY.DOM S50.DOM P13.DOM',
                  LoadShippedDomFollowingIncludes(table, 've7.dom', True, 0),
                  've7.dom includes the districts, the 50 states and the 13 provinces');
      CheckEquals('MD', MultiplierOf(table, 'DC'), 'DC counts as Maryland');
      CheckEquals('MD', MultiplierOf(table, 'MD'), 'and so does Maryland');
      CheckEquals('DC', QTHOf(table, 'DC'), 'the QTH stays DC');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

procedure TContestBritishColumbiaQPTests.RunAllTests;
begin
   Test_BritishColumbiaPoints;
   Test_BritishColumbiaBands;
   Test_BritishColumbiaModes;
   Test_BritishColumbiaVA7ODXOncePerBandAndMode;
   Test_BritishColumbiaFAQExamples;
   Test_BritishColumbiaCountsDCAsMaryland;
end;

end.
