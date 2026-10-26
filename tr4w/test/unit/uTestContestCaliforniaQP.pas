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

(* THE CALIFORNIA QSO PARTY'S 2026 RULES (#88, checked 2026-10-26). The
  sponsor's text is docs/ContestRules/QSOParties/California/
  CA-QSO-PARTY-Rules.txt; each test quotes the rule it holds.

    * points: CW 3, phone 3 -- FM is phone;
    * "MODES: CW, Phone" -- a digital QSO is an automatic X-QSO;
    * "BANDS: 160, 80, 40, 20, 15, and 10 meters";
    * "Maximum of 58 Scored Multipliers out of 63 Total" -- the final score
      at 57, 58, 59 and 63 multipliers. *)
unit uTestContestCaliforniaQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestCaliforniaQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_CaliforniaPoints;
      procedure Test_CaliforniaBands;
      procedure Test_CaliforniaDigitalIsAnXQSO;
      procedure Test_CaliforniaScoresAtMost58Multipliers;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uTestContestObjects;

(* A California entrant (Alameda) or one in Kansas; outside the state the
   host-area table knows every QTH, so a points test is not about that
   rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'ALAM';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function CaliforniaQso(aBand: BandType; aMode: ModeType;
                       aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'W6ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'ALAM';
   Result.DomesticQTH := 'ALAM';
end;

(* What ScoreQSO gives -- the one public scoring entry. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(CALQSOPARTY, Entrant(aInState));
   try
      qso := CaliforniaQso(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "Each complete non-duplicate Phone contact is worth 3 points. **NEW IN
   2026**"; "Each complete non-duplicate CW contact is worth 3 points." FM
   is phone. Inside California and outside it alike. *)
procedure TContestCaliforniaQPTests.Test_CaliforniaPoints;
var
   inState: boolean;
   who: string;
begin
   BeginTest('Test_CaliforniaPoints');
   for inState := False to True do
      begin
      if inState then
         begin
         who := 'in CA';
         end
      else
         begin
         who := 'outside CA';
         end;
      CheckEquals(3, PointsFor(inState, Band20, CW, eCW), who + ': CW is 3');
      CheckEquals(3, PointsFor(inState, Band20, Phone, eSSB), who + ': phone is 3');
      CheckEquals(3, PointsFor(inState, Band10, FM, eFM), who + ': FM is phone, 3');
      CheckEquals(0, PointsFor(inState, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inState, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "BANDS: 160, 80, 40, 20, 15, and 10 meters". Every BandType, both ways:
   on the list scores, off it is an automatic X-QSO. *)
procedure TContestCaliforniaQPTests.Test_CaliforniaBands;
const
   SPONSOR_BANDS = [Band160, Band80, Band40, Band20, Band15, Band10];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_CaliforniaBands');
   identity := ContestIdentity(CALQSOPARTY);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in SPONSOR_BANDS;
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor lists it');
      qso := CaliforniaQso(b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if expected then
         begin
         CheckEquals(3, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 3');
         end
      else
         begin
         CheckEquals(0, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores 0');
         end;
      end;
end;

(* "MODES: CW, Phone". No submode of digital is credited, so a digital QSO
   is logged and is an automatic X-QSO -- 0 points, no multiplier. CW, phone
   and FM are credited whatever the submode. *)
procedure TContestCaliforniaQPTests.Test_CaliforniaDigitalIsAnXQSO;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   qso: ContestExchange;
begin
   BeginTest('Test_CaliforniaDigitalIsAnXQSO');
   identity := ContestIdentity(CALQSOPARTY);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      CheckFalse(ContestCreditsMode(identity, Digital, ext),
                 'no digital submode is credited, ext ' + IntToStr(Ord(ext)));
      qso := CaliforniaQso(Band20, Digital, ext);
      CheckTrue(QSOIsXQSO(identity, qso), 'a digital QSO is an X-QSO, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, FM, ext), 'FM is credited, ext ' + IntToStr(Ord(ext)));
      end;
   CheckFalse(ContestCreditsModeKey(identity, Digital), 'the Digital key is not credited');
   CheckEquals(0, PointsFor(True, Band20, Digital, eRTTY), 'in CA, an RTTY QSO scores 0');
   CheckEquals(0, PointsFor(False, Band20, Digital, eNoMode), 'outside CA, a digital QSO scores 0');
end;

(* "A. California Stations: Maximum of 58 Scored Multipliers out of 63 Total
   Multipliers"; "The final score is the total number of QSO Points
   multiplied by the total number of scored multipliers (58 maximum)." *)
procedure TContestCaliforniaQPTests.Test_CaliforniaScoresAtMost58Multipliers;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;

   function ScoreAt(aMultipliers: integer): longint;
   begin
      t.Mults[AllBands, Both, rmDomestic] := aMultipliers;
      Result := contestObject.FinalScore(t, view);
   end;

begin
   BeginTest('Test_CaliforniaScoresAtMost58Multipliers');
   t := Default(TScoreTotals);
   t.QSOPoints := 300;
   t.ScoredBand := AllBands;
   t.SessionCountsMultipliers := True;
   view := TLoggedQSOList.Create;
   contestObject := Make(CALQSOPARTY, Entrant(True));
   try
      CheckEquals(300 * 57, ScoreAt(57), '57 multipliers: all scored');
      CheckEquals(300 * 58, ScoreAt(58), '58 multipliers: all scored');
      CheckEquals(300 * 58, ScoreAt(59), '59 multipliers: 58 scored');
      CheckEquals(300 * 58, ScoreAt(63), 'all 63: 58 scored');
      CheckEquals(0, ScoreAt(0), 'no multiplier, no score');

      (* THE CAP IS ON THE SUM, whichever kinds make it up. *)
      t.Mults[AllBands, Both, rmDX] := 10;
      CheckEquals(300 * 58, ScoreAt(50), '50 domestic and 10 more: 58 scored');
      t.Mults[AllBands, Both, rmDX] := 0;
   finally
      contestObject.Free;
      view.Free;
   end;
end;

procedure TContestCaliforniaQPTests.RunAllTests;
begin
   Test_CaliforniaPoints;
   Test_CaliforniaBands;
   Test_CaliforniaDigitalIsAnXQSO;
   Test_CaliforniaScoresAtMost58Multipliers;
end;

end.
