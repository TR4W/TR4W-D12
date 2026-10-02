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

(* ARRL INTERNATIONAL DIGITAL CONTEST.

  POINTS ARE A FUNCTION OF DISTANCE: one per 500 km begun, plus one, and a flat
  two for a station in your own grid. The whole of ARRLDIGIQSOPointMethod
  (Issue 577), which was one arm of LOGSTUFF's 88-way case.

  THE GUARD SCORES ZERO AND THAT IS A REAL ANSWER, not a missing else. The
  legacy arm has no else at all: CalculateQSOPoints zeroes QSOPoints on entry,
  so a QSO with no grid of ours or no domestic QTH of theirs keeps the zero. It
  is written out here rather than left implicit, because a class that simply
  omitted the branch would leave whatever the caller had in the record.

  TWO POINTS FOR THE SAME GRID IS TESTED ON QTHString, WHILE THE GUARD IS ON
  DomesticQTH, and the two are different fields. The arm reads that way and this
  reproduces it; they normally agree for this contest because MainUnit copies
  the typed grid into both, but reproducing the arm means reproducing which
  field each test read. *)
unit uContestARRLDigi;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLDigi = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. A class body with no visibility section
         defaults to public, which would make both X.DisplayName and
         X.GetDisplayName callable -- two ways to ask one question is exactly
         the ambiguity a property removes. *)
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
      function GetIsUSQSOParty: boolean; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class."

         Every getter above returns what the array holds today, so this changes
         no behaviour -- it moves the ANSWER, so that reading this one file tells
         you what the ARRL Digital contest is without cross-referencing a 200-row
         table by enum position. When the array goes, these are already the
         definition.

         The array row this replaces, verbatim:

           Email: 'contests@arrl.org';  DF: '';  WA7BNM: 716;  QRZRUID: 0;
           Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: GridInitialExchange;
           DM: NoDomesticMults {GridFields};  P: 0;  AE: Grid2Exchange;
           XM: NoDXMults;  QP: ARRLDIGIQSOPointMethod;  ADIFName: '';
           CABName: 'ARRL-DIGI';  FriendlyName: 'ARRL Inter. Digital Contest'

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and TContestBase still reads it for the ones
         that do not override. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   Math,       (* Ceil -- the rule is "per 500 km BEGUN" *)
   (* THE GEODESIC, AND WHY IT IS THIS ONE.

      LOGGRID.GetDistanceBetweenGrids pads a four-character grid with 'LL' and
      runs a Thomas spheroidal geodesic. uGridDistance.GridHaversineKm -- the
      obvious leaf-unit candidate, and the one a contest class would rather
      depend on -- takes the geometric CENTRE of the square and uses Haversine,
      and uGridDistance's own header says the two are numerically different BY
      DESIGN. Calling it here would move points for this contest while every
      gate stayed green on the arithmetic being plausible.

      SO THE DEPENDENCY IS THE TRDOS UNIT, DELIBERATELY. It is grid arithmetic
      and touches no display; what makes it heavier than a contest class wants
      is that Calc_GeoDist reads Settings.GridMap.RadiusOfEarth and is shared
      with the bearing display. Extracting it into uGridDistance beside
      GridHaversineKm is the right end state and is its own change with its own
      gate -- eleven other scoring arms in LOGSTUFF call the same function, so
      it is not this contest's to do alone. *)
   LogGrid,
   uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   uTR4WStrings;

procedure TContestARRLDigi.CalculateQSOPoints(var aQso: ContestExchange);
var
   distanceKm: integer;
begin
   aQso.QSOPoints := 0;

   if (Station.MyGrid = '') or (aQso.DomesticQTH = '') then
      begin
      Exit;
      end;

   if Station.MyGrid = string(aQso.QTHString) then
      begin
      aQso.QSOPoints := 2;
      Exit;
      end;

   distanceKm := GetDistanceBetweenGrids(Station.MyGrid, string(aQso.QTHString));
   aQso.QSOPoints := Ceil(distanceKm / 500) + 1;
end;

function TContestARRLDigi.GetDisplayName: string;
begin
   Result := 'ARRL Inter. Digital Contest';
end;

function TContestARRLDigi.GetCabrilloName: string;
begin
   (* The CONTEST: line of a submitted log. It happens to equal the enum's own
      spelling here, which is what the base would have fallen back to -- but it
      is stated because the array states it, not because the fallback agrees. *)
   Result := 'ARRL-DIGI';
end;

function TContestARRLDigi.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'ARRL-DIGI';
end;

function TContestARRLDigi.GetWA7BNMId: integer;
begin
   Result := 716;
end;

function TContestARRLDigi.GetQRZRUId: integer;
begin
   (* 0 -- not listed on the QRZ.RU calendar. *)
   Result := 0;
end;

function TContestARRLDigi.GetSubmissionEmail: string;
begin
   Result := 'contests@arrl.org';
end;

function TContestARRLDigi.GetDomesticFileName: string;
begin
   (* Blank: there is no .DOM file, because the exchange is a grid square and a
      grid is validated by its shape rather than against a list. *)
   Result := '';
end;

function TContestARRLDigi.GetFriendlyName: string;
begin
   (* The array's spelling exactly, abbreviation and all. It is what the
      contest-selection UI shows today, so expanding it here would change what
      an operator sees -- and that is a decision, not a transcription. *)
   Result := 'ARRL Inter. Digital Contest';
end;

function TContestARRLDigi.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARRLDigi.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARRLDigi.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestARRLDigi.GetDomesticMultiplierType: DomesticMultType;
begin
   (* NoDomesticMults, WHICH IS THE VALUE THE ARRAY CHOOSES AND NOT OBVIOUSLY
      THE RIGHT ONE. The row reads `DM: NoDomesticMults {GridFields}` -- the
      alternative is written beside it, commented out, and grid FIELDS are in
      fact what this contest multiplies on. Moving the row means moving the
      value it actually holds; changing it is a scoring decision and would show
      up in the rescore gate as a divergence, which is exactly what that gate
      is for. *)
   Result := NoDomesticMults;
end;

function TContestARRLDigi.GetInitialExchangeKind: InitialExchangeType;
begin
   (* The call-history / initial-exchange field offered when a callsign is
      typed is a grid square. *)
   Result := GridInitialExchange;
end;

function TContestARRLDigi.GetExchangeKind: ExchangeType;
begin
   Result := Grid2Exchange;
end;

function TContestARRLDigi.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* WHAT WAS DELIBERATELY NOT TAKEN OVER, AND WHY.

   THE ADIF GRIDSQUARE FIELD STAYS IN POSTUNIT. Its arm reads
   `ARRLDIGI, WWDIGI, BATAVIA_FT8:` and emits GRIDSQUARE from QTHString. It is
   an EXPORT decision shared with two contests that have no class, so moving
   this contest's third of it would duplicate the emission rather than relocate
   it, and would have to be undone when the other two move. It becomes the
   classes' when all three have one.

   THE EDIT-QSO FIELD MAPPING STAYS IN MainUnit. `WWDIGI, ARRLDIGI:` there
   copies the typed grid into ExchString and DomesticQTH when a logged QSO is
   edited. That is the UI's mapping from a dialog field to the record, not a
   contest rule, and TContestBase has no seam for it -- nor should it acquire
   one to serve a dialog.

   THE EXCHANGE COLUMNS ARE THE BASE'S DEFAULT (M4), the shared Grid2Exchange
   arm. What IS this contest's in export is the worked station's grid going
   to ADIF GRIDSQUARE -- EmitADIFContestFields, below. *)

(* THE WORKED STATION'S GRID GOES TO ADIF GRIDSQUARE -- M4, 2026-10-01, the
   ARRLDIGI share of postunit's `ARRLDIGI, WWDIGI, BATAVIA_FT8` arm, moved
   here; the other two contests have their own copies. PostUnit asks only for
   a QTH it did not already recognise as a grid. *)
function TContestARRLDigi.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := EmitADIFField('GRIDSQUARE', string(aQso.QTHString));
end;

(* THE GRID IS THE EXCHANGE AND THE DOMESTIC QTH. *)
procedure TContestARRLDigi.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                    const aSession: TADIFImportSession;
                                    var aExch: ContestExchange);
begin
   aExch.ExchString  := ShortString(aTemps.GridSquare);
   aExch.DomesticQTH := ShortString(aTemps.GridSquare);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARRLDigi.DescribeSession(const aStation: TStationContext;
                                           aSession: TSessionDefaults);
begin
   aSession.DigitalModeEnable := True;
   aSession.QSOByMode := False;
   aSession.QSOByBand := True;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLVHFJAN, ARRLVHFJUN,
   ARRLVHFSEP, BATAVIA_FT8, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, MAKROTHEN,
   RTC, STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRLDigi.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

initialization
   RegisterContest(ARRLDIGI, TContestARRLDigi);

end.
