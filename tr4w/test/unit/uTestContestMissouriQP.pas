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

(* THE MISSOURI QSO PARTY'S 2026 RULES (#88, checked 2026-10-26). The
  sponsor's text is docs/ContestRules/QSOParties/Missouri/
  MO-QSO-PARTY-Rules.txt; each test quotes the rule it holds, and none reads
  its answer back out of the class.

    * points: phone 1, CW 2, digital 2 -- FM is phone;
    * the bands: 160-10 m without WARC, 6 m, 2 m, 1.25 m and 70 cm;
    * the modes: FT8, FT4 and JT65 are automatic X-QSOs, every other mode is
      credited;
    * the peak-hour bonus does not count an X-QSO;
    * DC counts as Maryland for a Missouri entrant (missouri.dom, through
      the real loader), and Holt County is HTL.

  The W0MA/K0GQ and peak-hour bonuses are pinned in uTestContestTotals. *)
unit uTestContestMissouriQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestMissouriQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_MissouriPoints;
      procedure Test_MissouriBands;
      procedure Test_MissouriModes;
      procedure Test_MissouriPeakHourBonusSkipsAnXQSO;
      procedure Test_MissouriCountsDCAsMaryland;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uContestRegistry,
   LogDom,
   uTestContestObjects,
   uTestShippedDom;

(* A Missouri entrant (St. Louis County) or one in Kansas. Outside the
   state the host-area table knows every QTH, so a points test is not about
   that rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'SLC';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function MissouriQso(aBand: BandType; aMode: ModeType;
                     aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := 'K0ABC';
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'SLC';
   Result.DomesticQTH := 'SLC';
end;

(* What ScoreQSO gives -- the one public scoring entry, so an off-band or
   off-mode QSO's X-QSO zero is seen here too. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(MOQSOPARTY, Entrant(aInState));
   try
      qso := MissouriQso(aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "1. Valid phone contacts equals one point each. 2. Valid CW contacts
   equals two points each. 3. Valid digital contacts equals two points
   each." FM is phone. Inside Missouri and outside it alike. *)
procedure TContestMissouriQPTests.Test_MissouriPoints;
var
   inState: boolean;
   who: string;
begin
   BeginTest('Test_MissouriPoints');
   for inState := False to True do
      begin
      if inState then
         begin
         who := 'in MO';
         end
      else
         begin
         who := 'outside MO';
         end;
      CheckEquals(1, PointsFor(inState, Band20, Phone, eSSB), who + ': phone is 1');
      CheckEquals(1, PointsFor(inState, Band2, FM, eFM), who + ': FM is phone, 1');
      CheckEquals(2, PointsFor(inState, Band20, CW, eCW), who + ': CW is 2');
      CheckEquals(2, PointsFor(inState, Band20, Digital, eRTTY), who + ': RTTY is 2');
      CheckEquals(2, PointsFor(inState, Band40, Digital, ePSK31), who + ': PSK31 is 2');
      CheckEquals(2, PointsFor(inState, Band40, Digital, eNoMode),
                  who + ': a digital QSO with no submode is 2');
      CheckEquals(0, PointsFor(inState, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inState, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "CW, Digital, and phone operation on 160M, 80M, 40M, 20M, 15M, 10M, 6M,
   2M, 1.25M, and 70cm." Every BandType, both ways: on the list scores, off
   it is an automatic X-QSO. *)
procedure TContestMissouriQPTests.Test_MissouriBands;
const
   SPONSOR_BANDS = [Band160, Band80, Band40, Band20, Band15, Band10,
                    Band6, Band2, Band222, Band432];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_MissouriBands');
   identity := ContestIdentity(MOQSOPARTY);
   for b := Low(BandType) to High(BandType) do
      begin
      expected := b in SPONSOR_BANDS;
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when the sponsor lists it');
      qso := MissouriQso(b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      if expected then
         begin
         CheckEquals(2, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' CW scores 2');
         end
      else
         begin
         CheckEquals(0, PointsFor(True, b, CW, eCW), 'band ' + IntToStr(Ord(b)) + ' scores 0');
         end;
      end;
end;

(* "8. FT4/FT8 or similar modes that do not allow free text sending will not
   be allowed." FT8, FT4 and JT65 -- the WSJT structured-message modes -- are
   X-QSOs; every other digital submode is credited, and so is a digital QSO
   whose submode is not recorded. CW, phone and FM are credited whatever the
   submode. Asked of the station-less identity, as every X-QSO reader asks
   it. *)
procedure TContestMissouriQPTests.Test_MissouriModes;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   refused: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_MissouriModes');
   identity := ContestIdentity(MOQSOPARTY);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      refused := ext in [eFT8, eFT4, eJT65];
      CheckTrue(ContestCreditsMode(identity, Digital, ext) = (not refused),
                'digital submode ' + IntToStr(Ord(ext)) + ' credited unless FT8, FT4 or JT65');
      qso := MissouriQso(Band20, Digital, ext);
      CheckTrue(QSOIsXQSO(identity, qso) = refused,
                'digital submode ' + IntToStr(Ord(ext)) + ': an X-QSO exactly when refused');
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, FM, ext), 'FM is credited, ext ' + IntToStr(Ord(ext)));
      end;
   CheckEquals(0, PointsFor(True, Band20, Digital, eFT8), 'an FT8 QSO scores 0');
   CheckEquals(0, PointsFor(True, Band20, Digital, eFT4), 'an FT4 QSO scores 0');
   CheckEquals(0, PointsFor(True, Band20, Digital, eJT65), 'a JT65 QSO scores 0');
   CheckEquals(2, PointsFor(True, Band20, Digital, eJS8), 'a JS8 QSO (free text) scores 2');
   CheckTrue(ContestCreditsModeKey(identity, Digital),
             'the Digital key is credited: the dupe sheet knows no submode');
end;

(* "Any valid contacts made between ... 1400 UTC ... to 2000 UTC ... on the
   40 and 80 meter bands will count as an additional point each." An FT8
   QSO is not a valid contact, so it earns no peak-hour point. *)
procedure TContestMissouriQPTests.Test_MissouriPeakHourBonusSkipsAnXQSO;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   qso: ContestExchange;
begin
   BeginTest('Test_MissouriPeakHourBonusSkipsAnXQSO');
   t := Default(TScoreTotals);
   view := TLoggedQSOList.Create;
   contestObject := Make(MOQSOPARTY, Entrant(True));
   try
      qso := MissouriQso(Band40, Digital, eFT8);
      qso.tSysTime.qtYear := 26;
      qso.tSysTime.qtMonth := 4;
      qso.tSysTime.qtDay := 11;
      qso.tSysTime.qtHour := 15;
      view.Add(qso);
      CheckEquals(0, contestObject.BonusPoints(t, view), 'an FT8 QSO at 1500 on 40 m: no point');
      qso.ExtMode := eRTTY;
      view.Add(qso);
      CheckEquals(1, contestObject.BonusPoints(t, view), 'an RTTY QSO at 1500 on 40 m: one point');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* Table 2's note: "'Maryland' includes the District of Columbia." A
   Missouri entrant's multipliers are states, so missouri.dom -- the
   in-state file -- maps DC to MD; read through the real loader with its
   INCLUDEs. And Table 1's "Holt HTL" (DXLog's HLT is not the sponsor's).
   Round 2: "Missouri counties (115 maximum), US states (49 maximum), and
   Canadian provinces and territories (13 maximum) ... An additional
   multiplier of the value of one will be added if at least one DX station
   is worked" -- Missouri is not one of the 49. *)
procedure TContestMissouriQPTests.Test_MissouriCountsDCAsMaryland;
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   rules: TStringList;
   path: string;
   i: integer;
   holtLine: string;
begin
   BeginTest('Test_MissouriCountsDCAsMaryland');
   CheckEquals('missouri', ContestIdentity(MOQSOPARTY).InStateDomesticFileName,
               'missouri.dom is the in-state file');

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      (* THE COUNTIES FIRST, and no S50: the states are listed so Missouri
         can be left out (#88 round 2). *)
      CheckEquals('MISSOURI_CTY.DOM',
                  LoadShippedDomFollowingIncludes(table, 'missouri.dom', True, 0),
                  'missouri.dom includes the counties and no states file');
      CheckEquals('MD', MultiplierOf(table, 'DC'), 'DC counts as Maryland');
      CheckEquals('MD', MultiplierOf(table, 'MD'), 'and so does Maryland');
      CheckEquals('DC', QTHOf(table, 'DC'), 'the QTH stays DC');
      CheckEquals('HTL', MultiplierOf(table, 'HTL'), 'Holt County is HTL');
      CheckEquals('', MultiplierOf(table, 'HLT'), 'HLT is not a Missouri county');

      (* "US states (49 maximum)": every state but Missouri, Alaska and
         Hawaii included; the provinces; one DX multiplier. *)
      CheckEquals('', MultiplierOf(table, 'MO'), 'Missouri is not a state multiplier');
      CheckEquals('', MultiplierOf(table, 'MISSO'), 'nor under its other alias');
      CheckEquals('KS', MultiplierOf(table, 'KS'), 'Kansas is');
      CheckEquals('AK', MultiplierOf(table, 'AK'), 'Alaska is');
      CheckEquals('HI', MultiplierOf(table, 'HI'), 'Hawaii is');
      CheckEquals('MS', MultiplierOf(table, 'MS'), 'Mississippi is');
      CheckEquals('VE3', MultiplierOf(table, 'ON'), 'Ontario is');
      CheckEquals('NU', MultiplierOf(table, 'NU'), 'Nunavut is');
      CheckEquals('DX', MultiplierOf(table, 'DX'), 'and DX is one multiplier');

      (* MIS IS MISSISSIPPI COUNTY, NOT THE STATE: s48.dom gives Mississippi
         the alias MIS, and the table keeps the first entry added -- so the
         counties come first. NWT likewise is Newton County, not the NWT. *)
      CheckEquals('MIS', MultiplierOf(table, 'MIS'), 'MIS is Mississippi County');
      CheckEquals('NWT', MultiplierOf(table, 'NWT'), 'NWT is Newton County');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;

   (* THE SPONSOR'S TABLE SAYS SO -- read from the committed rules text. *)
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           '..' + PathDelim + 'docs' + PathDelim + 'ContestRules' + PathDelim +
           'QSOParties' + PathDelim + 'Missouri' + PathDelim + 'MO-QSO-PARTY-Rules.txt';
   rules := TStringList.Create;
   try
      rules.LoadFromFile(path);
      holtLine := '';
      for i := 0 to rules.Count - 1 do
         begin
         if Pos('Holt ', rules[i]) > 0 then
            begin
            holtLine := rules[i];
            Break;
            end;
         end;
      CheckTrue(Pos('HTL', holtLine) > Pos('Holt ', holtLine),
                'Table 1 gives Holt the code HTL: ' + holtLine);
      CheckEquals(0, Pos('HLT', holtLine), 'and not HLT');
   finally
      rules.Free;
   end;
end;

procedure TContestMissouriQPTests.RunAllTests;
begin
   Test_MissouriPoints;
   Test_MissouriBands;
   Test_MissouriModes;
   Test_MissouriPeakHourBonusSkipsAnXQSO;
   Test_MissouriCountsDCAsMaryland;
end;

end.
