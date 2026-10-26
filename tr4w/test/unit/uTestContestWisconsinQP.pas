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

(* THE WISCONSIN QSO PARTY'S 2026 RULES (#88 round 2, checked 2026-10-26).
  The sponsor's texts are docs/ContestRules/QSOParties/Wisconsin/; each test
  quotes the rule it holds.

    * points: CW 2, digital 2, phone 1 -- FM is phone;
    * "FT8/FT4 QSO's are not accepted" -- automatic X-QSOs, nothing else;
    * "All amateur bands ... not prohibited for contesting" -- every band but
      WARC;
    * "Mobiles or portables may not sit on a county line" -- no county line;
    * W9FK: +100 once on each band and mode below 50 MHz, after multiplying;
    * Cabrillo: CONTEST: WI-QSO-PARTY, the location alone, DX outside the US
      and Canada -- with the stored and ADIF ids unmoved;
    * a Wisconsin entrant's logged DX QSO scores its points, and the in-state
      table has no DX entry (the typed refusal is reported on #88). *)
unit uTestContestWisconsinQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestWisconsinQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_WisconsinPoints;
      procedure Test_WisconsinBands;
      procedure Test_WisconsinModes;
      procedure Test_WisconsinHasNoCountyLine;
      procedure Test_WisconsinW9FKOncePerBandAndModeBelow50MHz;
      procedure Test_WisconsinCabrilloIsTheLocationAlone;
      procedure Test_WisconsinEntrantsDXQSO;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   uMults,
   uContestBase,
   uContestRegistry,
   uContestStateQSOPartyBase,
   LogDom,
   uTestContestObjects,
   uTestShippedDom;

(* A Wisconsin entrant (Adams County) or one in Illinois; outside the state
   the host-area table knows every QTH, so a points test is not about that
   rule. *)
function Entrant(aInState: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   Result.InHostState := aInState;
   if aInState then
      begin
      Result.MyState := 'ADA';
      end
   else
      begin
      Result.MyState := 'IL';
      end;
end;

function WisconsinQso(const aCall: string; aBand: BandType; aMode: ModeType;
                      aExtMode: ExtendedModeType): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.ceRecordKind := rkQSO;
   Result.Callsign := ShortString(aCall);
   Result.Band := aBand;
   Result.Mode := aMode;
   Result.ExtMode := aExtMode;
   Result.QTHString := 'MIL';
   Result.DomesticQTH := 'MIL';
end;

(* What ScoreQSO gives -- the one public scoring entry. *)
function PointsFor(aInState: boolean; aBand: BandType; aMode: ModeType;
                   aExtMode: ExtendedModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(WISCONSINQSOPARTY, Entrant(aInState));
   try
      qso := WisconsinQso('W9ABC', aBand, aMode, aExtMode);
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* "Phone contacts count 1 point; CW and Digital contacts count 2 points." FM
   is phone. Inside Wisconsin and outside it alike. *)
procedure TContestWisconsinQPTests.Test_WisconsinPoints;
var
   inState: boolean;
   who: string;
begin
   BeginTest('Test_WisconsinPoints');
   for inState := False to True do
      begin
      if inState then
         begin
         who := 'in WI';
         end
      else
         begin
         who := 'outside WI';
         end;
      CheckEquals(2, PointsFor(inState, Band20, CW, eCW), who + ': CW is 2');
      CheckEquals(2, PointsFor(inState, Band20, Digital, eRTTY), who + ': RTTY is 2');
      CheckEquals(2, PointsFor(inState, Band40, Digital, ePSK31), who + ': PSK31 is 2');
      CheckEquals(2, PointsFor(inState, Band40, Digital, eNoMode), who + ': digital, no submode, is 2');
      CheckEquals(1, PointsFor(inState, Band20, Phone, eSSB), who + ': phone is 1');
      CheckEquals(1, PointsFor(inState, Band2, FM, eFM), who + ': FM is phone, 1');
      CheckEquals(0, PointsFor(inState, Band20, Both, eNoMode), who + ': no mode a contact is made in');
      CheckEquals(0, PointsFor(inState, Band20, NoMode, eNoMode), who + ': nor this one');
      end;
end;

(* "All amateur bands and modes not prohibited for contesting may be used."
   Every band but the WARC bands, both ways. *)
procedure TContestWisconsinQPTests.Test_WisconsinBands;
const
   WARC = [Band30, Band17, Band12];
var
   identity: TContestBase;
   b: BandType;
   expected: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_WisconsinBands');
   identity := ContestIdentity(WISCONSINQSOPARTY);
   CheckTrue(identity.VHFBandsEnabled, 'the VHF bands can be reached');
   for b := Low(BandType) to High(BandType) do
      begin
      expected := not (b in WARC + [AllBands, NoBand]);
      CheckTrue(identity.UsesBand(b) = expected,
                'band ' + IntToStr(Ord(b)) + ' credited exactly when it is not WARC');
      qso := WisconsinQso('W9ABC', b, CW, eCW);
      (* NoBand is a record that names no band, never proven off-band. *)
      CheckTrue(QSOIsXQSO(identity, qso) = ((not expected) and (b <> NoBand)),
                'band ' + IntToStr(Ord(b)) + ': off the list is an X-QSO');
      end;
   CheckEquals(2, PointsFor(True, Band6, CW, eCW), '6 m CW scores');
   CheckEquals(1, PointsFor(True, Band432, FM, eFM), '70 cm FM scores');
   CheckEquals(0, PointsFor(True, Band30, CW, eCW), '30 m scores nothing');
end;

(* "CW, Phone and Digital (RTTY, PSK, Olivia, Feld-Hell). FT8/FT4 QSO's are
   not accepted." FT8 and FT4 only -- the two the sponsor names. *)
procedure TContestWisconsinQPTests.Test_WisconsinModes;
var
   identity: TContestBase;
   ext: ExtendedModeType;
   refused: boolean;
   qso: ContestExchange;
begin
   BeginTest('Test_WisconsinModes');
   identity := ContestIdentity(WISCONSINQSOPARTY);
   for ext := Low(ExtendedModeType) to High(ExtendedModeType) do
      begin
      refused := ext in [eFT8, eFT4];
      CheckTrue(ContestCreditsMode(identity, Digital, ext) = (not refused),
                'digital submode ' + IntToStr(Ord(ext)) + ' credited unless FT8 or FT4');
      qso := WisconsinQso('W9ABC', Band20, Digital, ext);
      CheckTrue(QSOIsXQSO(identity, qso) = refused,
                'digital submode ' + IntToStr(Ord(ext)) + ': an X-QSO exactly when refused');
      CheckTrue(ContestCreditsMode(identity, CW, ext), 'CW is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, Phone, ext), 'phone is credited, ext ' + IntToStr(Ord(ext)));
      CheckTrue(ContestCreditsMode(identity, FM, ext), 'FM is credited, ext ' + IntToStr(Ord(ext)));
      end;
   CheckEquals(0, PointsFor(True, Band20, Digital, eFT8), 'an FT8 QSO scores 0');
   CheckEquals(0, PointsFor(True, Band20, Digital, eFT4), 'an FT4 QSO scores 0');
   CheckEquals(2, PointsFor(True, Band20, Digital, eJT65), 'JT65 is not named: it scores 2');
end;

(* "Mobiles or portables may not sit on a county line", and a fixed station
   has one location: no county line at all, as Michigan. *)
procedure TContestWisconsinQPTests.Test_WisconsinHasNoCountyLine;
var
   contestObject: TContestBase;
   party: TContestStateQSOPartyBase;
   msg: string;
begin
   BeginTest('Test_WisconsinHasNoCountyLine');
   contestObject := Make(WISCONSINQSOPARTY);
   try
      party := contestObject as TContestStateQSOPartyBase;
      CheckEquals(0, party.CountyLineCountiesMax, 'no county line');
      CheckFalse(party.CountyLineAllowed, 'the derived boolean follows the count');
      CheckTrue(party.ValidateQTHCount(1, msg), 'one county');
      CheckFalse(party.ValidateQTHCount(2, msg), 'two are refused');
      CheckTrue(msg <> '', 'with a reason');
      CheckTrue(contestObject.StripsRoverCountyFromCall, 'a rover is still a QSO party''s');
   finally
      contestObject.Free;
   end;
end;

(* "W9FK: Add 100 points for each time you work W9FK on each band and mode
   below 50Mhz." "Then multiply by your multiplier count ... Finally, add your
   bonus points." A dupe is not a QSO, nor is an X-QSO; 6 m and up pay
   nothing; another call is not W9FK. *)
procedure TContestWisconsinQPTests.Test_WisconsinW9FKOncePerBandAndModeBelow50MHz;
var
   contestObject: TContestBase;
   view: TLoggedQSOList;
   t: TScoreTotals;
   dupe: ContestExchange;
begin
   BeginTest('Test_WisconsinW9FKOncePerBandAndModeBelow50MHz');
   t := Default(TScoreTotals);
   view := TLoggedQSOList.Create;
   contestObject := Make(WISCONSINQSOPARTY, Entrant(False));
   try
      CheckEquals(0, contestObject.BonusPoints(t, view), 'an empty log');
      view.Add(WisconsinQso('W9FK', Band20, CW, eCW));
      CheckEquals(100, contestObject.BonusPoints(t, view), '20 m CW: 100');
      view.Add(WisconsinQso('W9FK', Band20, CW, eCW));
      CheckEquals(100, contestObject.BonusPoints(t, view), '20 m CW again: still 100');
      view.Add(WisconsinQso('W9FK', Band40, CW, eCW));
      CheckEquals(200, contestObject.BonusPoints(t, view), '40 m CW: 200');
      view.Add(WisconsinQso('W9FK', Band40, Phone, eLSB));
      CheckEquals(300, contestObject.BonusPoints(t, view), '40 m phone: 300');
      view.Add(WisconsinQso('W9FK', Band40, Digital, eRTTY));
      CheckEquals(400, contestObject.BonusPoints(t, view), '40 m RTTY: 400');
      view.Add(WisconsinQso('W9FK', Band40, Digital, ePSK31));
      CheckEquals(400, contestObject.BonusPoints(t, view), '40 m PSK31 is 40 m digital again: 400');
      view.Add(WisconsinQso('W9FK', Band20, Digital, eFT8));
      CheckEquals(400, contestObject.BonusPoints(t, view), 'an FT8 QSO is an X-QSO: nothing');
      view.Add(WisconsinQso('W9FK', Band6, Phone, eUSB));
      view.Add(WisconsinQso('W9FK', Band2, FM, eFM));
      CheckEquals(400, contestObject.BonusPoints(t, view), '6 m and 2 m are not below 50 MHz');
      view.Add(WisconsinQso('W9FK', Band17, CW, eCW));
      CheckEquals(400, contestObject.BonusPoints(t, view), 'a WARC QSO is an X-QSO: nothing');
      dupe := WisconsinQso('W9FK', Band15, CW, eCW);
      dupe.ceDupe := True;
      view.Add(dupe);
      CheckEquals(400, contestObject.BonusPoints(t, view), 'a dupe pays nothing');
      view.Add(WisconsinQso('W9FK/M', Band10, CW, eCW));
      view.Add(WisconsinQso('W9FKX', Band10, CW, eCW));
      CheckEquals(400, contestObject.BonusPoints(t, view), 'another call pays nothing');
      view.Add(WisconsinQso('W9FK', Band160, CW, eCW));
      CheckEquals(500, contestObject.BonusPoints(t, view), '160 m CW: 500');

      (* AFTER MULTIPLYING: 120 points x 30 multipliers, then + 500. *)
      t.QSOPoints := 120;
      t.ScoredBand := AllBands;
      t.SessionCountsMultipliers := True;
      t.Mults[AllBands, Both, rmDomestic] := 30;
      CheckEquals(120 * 30 + 500, contestObject.FinalScore(t, view), 'the bonus is added last');
   finally
      contestObject.Free;
      view.Free;
   end;
end;

(* THE SPONSOR'S CABRILLO PAGE: "CONTEST: WI-QSO-PARTY"; "The column alignment
   of the QSO data lines are the same as the ARRL 160M contest example ...
   except that RST columns are not needed"; "The received exchange for QSO's
   with stations outside the U.S. states and Canadian provinces should show
   'DX'." Its example line, word for word:
     QSO: 21030 CW 2020-03-15 1924 W9HNW RAC K6LL AZ
   The Cabrillo name is write-only: the stored id and the ADIF id stay. *)
procedure TContestWisconsinQPTests.Test_WisconsinCabrilloIsTheLocationAlone;
const
   SPONSOR_EXAMPLE = 'QSO: 21030 CW 2020-03-15 1924 W9HNW RAC K6LL AZ';
var
   identity: TContestBase;
   my: TMyStationExchange;
   qso: ContestExchange;
   ctx: TCabrilloQSOContext;
   firstPart: string;
   line: string;
   found: TContestHandle;

   function Words(const aText: string): string;
   var
      list: TStringList;
   begin
      list := TStringList.Create;
      try
         list.Delimiter := ' ';
         list.StrictDelimiter := False;
         list.DelimitedText := Trim(aText);
         Result := list.CommaText;
      finally
         list.Free;
      end;
   end;

begin
   BeginTest('Test_WisconsinCabrilloIsTheLocationAlone');
   identity := ContestIdentity(WISCONSINQSOPARTY);
   CheckEquals('WI-QSO-PARTY', identity.CabrilloName, 'CONTEST: WI-QSO-PARTY');
   CheckEquals('WISCONSIN QSO PARTY', string(ContestTypeSA[WISCONSINQSOPARTY]),
               'the stored id does not move');
   CheckEquals('WI-QSO-PARTY', identity.ADIFContestId, 'the ADIF id does not move');
   CheckTrue(FindContestByADIFContestId('WI-QSO-PARTY', found), 'import resolves it');
   CheckTrue(found = ContestHandleOf(WISCONSINQSOPARTY), 'to Wisconsin');

   my := Default(TMyStationExchange);
   my.MyState := 'RAC';
   qso := WisconsinQso('K6LL', Band15, CW, eCW);
   qso.QTHString := 'AZ';
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';
   ctx.HisQTH := 'AZ';
   firstPart := Format('QSO: %5s %s %d-%.2d-%.2d %.2d%.2d %-7s ',
                       ['21030', identity.CabrilloModeString(CW, eCW),
                        2020, 3, 15, 19, 24, 'W9HNW']);
   CheckEquals('RAC    ', identity.FormatCabrilloSentExchange(my, qso, ctx), 'sent: the county alone');
   CheckEquals('AZ     ', identity.FormatCabrilloReceivedExchange(my, qso, ctx), 'received: the state alone');
   line := Format(identity.CabrilloQSOLineFormat,
                  [firstPart, identity.FormatCabrilloSentExchange(my, qso, ctx), 'K6LL',
                   identity.FormatCabrilloReceivedExchange(my, qso, ctx), '']);
   CheckEquals(Words(SPONSOR_EXAMPLE), Words(line), 'the sponsor''s example, word for word: ' + line);

   (* "QSO: 28567 PH 2020-03-15 2145 W9HNW RAC DL6QK DX" *)
   qso.QTHString := '';
   ctx.HisQTH := '';
   CheckEquals('DX     ', identity.FormatCabrilloReceivedExchange(my, qso, ctx),
               'a station outside the US and Canada is DX');
   (* A DX entrant (no state of its own) sends DX. *)
   my.MyState := '';
   CheckEquals('DX     ', identity.FormatCabrilloSentExchange(my, qso, ctx), 'a DX entrant sends DX');
end;

(* "DX countries worked count for QSO points but not as multipliers." A
   Wisconsin entrant's DX QSO, once logged, scores its points; wisconsin.dom
   (the in-state table) has no DX entry, so it earns no domestic multiplier.
   TYPING "599 DX" IS REFUSED as an improper QTH -- the exchange is
   domestic-only -- which is reported on #88, not pinned here. *)
procedure TContestWisconsinQPTests.Test_WisconsinEntrantsDXQSO;
var
   contestObject: TContestBase;
   qso: ContestExchange;
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_WisconsinEntrantsDXQSO');
   contestObject := Make(WISCONSINQSOPARTY, Entrant(True));
   try
      qso := WisconsinQso('DL1ABC', Band20, CW, eCW);
      qso.QTHString := '';
      qso.DomesticQTH := '';
      qso.QTH.CountryID := 'DL';
      contestObject.ScoreQSO(qso);
      CheckEquals(2, qso.QSOPoints, 'a logged DX CW QSO scores 2');
      CheckFalse(contestObject.HasDXMultiplier, 'and there is no DX multiplier');
   finally
      contestObject.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      CheckEquals('WISCONSIN_CTY.DOM S50.DOM P13.DOM',
                  LoadShippedDomFollowingIncludes(table, 'wisconsin.dom', True, 0),
                  'wisconsin.dom: the counties, the 50 states and the 13 provinces');
      CheckEquals('', MultiplierOf(table, 'DX'), 'no DX entry: no DX multiplier');
      CheckEquals('WI', MultiplierOf(table, 'WI'),
                  '"Wisconsin may be counted as a state multiplier"');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

procedure TContestWisconsinQPTests.RunAllTests;
begin
   Test_WisconsinPoints;
   Test_WisconsinBands;
   Test_WisconsinModes;
   Test_WisconsinHasNoCountyLine;
   Test_WisconsinW9FKOncePerBandAndModeBelow50MHz;
   Test_WisconsinCabrilloIsTheLocationAlone;
   Test_WisconsinEntrantsDXQSO;
end;

end.
