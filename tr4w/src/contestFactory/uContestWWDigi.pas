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

(* THE WORLD WIDE DIGI DX CONTEST.

  The ContestsArray row this class states, verbatim (an older, commented-out
  row above it gave DM: GridSquares):

   Email: 'director@ww-digi.com';  DF: '';  WA7BNM: 650;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: GridInitialExchange;
   DM: GridFields;  P: 0;  AE: Grid2Exchange;
   XM: NoDXMults;  QP: WWDIGIQP;  ADIFName: '';
   CABName: 'WW-DIGI';  FriendlyName: 'World Wide Digi DX Contest'

  Blank ADIFName is the enum's spelling, 'WWDIGI'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = WWDIGI` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS WWDIGIQP, transcribed exactly: with both grids known, one point
  per 3000 km begun --

      Distance := GetDistanceBetweenGrids(MyGrid, RXData.QTHString);
      RXData.QSOPoints := (Distance div 3000) + 1;

  -- gated on our grid and the QSO's DomesticQTH, and measured to its
  QTHString, as the arm does. The geodesic is LOGGRID's, deliberately: see
  uContestARRLDigi for why it is that one and not uGridDistance's.

  TWO EXPORT RULES. Cabrillo: the received grid is the QSO's QTHString,
  whichever his-QTH the exporter would otherwise choose -- postunit tested
  `Settings.Contest.Name = 'WWDIGI'` for it. ADIF: the grid goes to
  GRIDSQUARE (postunit's `ARRLDIGI, WWDIGI, BATAVIA_FT8` arm; each of the
  three owns a copy). *)
unit uContestWWDigi;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWWDigi = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* GetDistanceBetweenGrids -- the arm's own geodesic; see the header. *)
   LogGrid,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF;

procedure TContestWWDigi.CalculateQSOPoints(var aQso: ContestExchange);
var
   distanceKm: integer;
begin
   if (Station.MyGrid <> '') and (aQso.DomesticQTH <> '') then
      begin
      distanceKm := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.QTHString));
      aQso.QSOPoints := (distanceKm div 3000) + 1;
      end;
end;

function TContestWWDigi.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
var
   ctx: TCabrilloQSOContext;
begin
   ctx := aCtx;
   ctx.HisQTH := string(aQso.QTHString);
   Result := inherited FormatCabrilloReceivedExchange(aMy, aQso, ctx);
end;

function TContestWWDigi.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := EmitADIFField('GRIDSQUARE', string(aQso.QTHString));
end;

function TContestWWDigi.GetDisplayName: string;
begin
   Result := 'World Wide Digi DX Contest';
end;

function TContestWWDigi.GetCabrilloName: string;
begin
   Result := 'WW-DIGI';
end;

function TContestWWDigi.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WWDIGI';
end;

function TContestWWDigi.GetWA7BNMId: integer;
begin
   Result := 650;
end;

function TContestWWDigi.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWWDigi.GetSubmissionEmail: string;
begin
   Result := 'director@ww-digi.com';
end;

function TContestWWDigi.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestWWDigi.GetFriendlyName: string;
begin
   Result := 'World Wide Digi DX Contest';
end;

function TContestWWDigi.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWWDigi.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestWWDigi.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestWWDigi.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridFields;
end;

function TContestWWDigi.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := GridInitialExchange;
end;

function TContestWWDigi.GetExchangeKind: ExchangeType;
begin
   Result := Grid2Exchange;
end;

function TContestWWDigi.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := WWDIGIQP;
end;

function TContestWWDigi.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* THE GRID IS THE EXCHANGE AND THE DOMESTIC QTH. *)
procedure TContestWWDigi.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                    const aSession: TADIFImportSession;
                                    var aExch: ContestExchange);
begin
   aExch.ExchString  := ShortString(aTemps.GridSquare);
   aExch.DomesticQTH := ShortString(aTemps.GridSquare);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestWWDigi.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   aSession.DigitalModeEnable := True;
   aSession.QSOByMode := False;
   aSession.QSOByBand := True;
end;

initialization
   RegisterContest(WWDIGI, TContestWWDigi);

end.
