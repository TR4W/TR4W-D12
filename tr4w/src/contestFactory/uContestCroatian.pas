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

(* THE CROATIAN DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'croat';  WA7BNM: 206;  QRZRUID: 91;
   Pxm: NoPrefixMults;  ZnM: ITUZones;  AIE: ZoneInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTZONEORDOMESTICQTH;
   XM: NODXMULTS;  QP: CroatianQSOPointMethod;  ADIFName: '';
   CABName: '';  FriendlyName: 'Croatian DX Contest'

  Blank ADIFName and CABName are the enum's spelling, 'CROATIAN'.

  WHY IT HAS A CLASS. Its scoring arm read the PC's clock at SCORING time
  (design Q21), and the fix -- read the QSO's own recorded time -- is a
  contest rule, which belongs on the contest. Registering a class makes it
  this contest's scorer, so the whole row and the whole arm come with it;
  Test_MovedRowValuesStillMatchTheArray holds the row, and the contest
  matrix the rest: every line of its record but `contest.class` is
  unchanged, which is the transcription proof (its synthetic QSOs are
  stamped 12:xx UTC, outside the night window).

  MOVED AT M7a: FCONTEST.FoundContest's CROATIAN arm, which gives a 9A
  station CQ DXCC multipliers, is this class's DescribeSession.

  SCORING IS CroatianQSOPointMethod, transcribed in its order, because later
  steps overwrite earlier ones and the order IS the rule:

   1. a 9A station working 9A: 1, and nothing else applies (no doubling);
   2. a 9A station otherwise: by band, Europe 4 4 2 2 2 2, elsewhere
      10 10 8 6 6 6 (160 80 40 20 15 10), and nothing else applies;
   3. anyone else working 9A: 10 10 10 6 6 6;
   4. then, a contact on our own continent: 2 2 2 1 1 1 -- this overwrites
      step 3 for a 9A contact on our continent, as the arm always did;
   5. then, a contact off our continent that is not 9A: 6 6 6 3 3 3;
   6. then the night doubling, below.

  A band outside the six keeps whatever the steps before it wrote -- 0, since
  ScoreQSO zeroes the points first -- exactly as the arm's `case` statements
  without an `else` did.

  THE NIGHT DOUBLING READS THE QSO'S RECORDED TIME, NEVER THE CLOCK. NY4I,
  2026-10-01: "the event source is the wall clock recorded in the QSO". The
  legacy arm called tGetSystemTime, so a rescore at 23:30 UTC doubled every
  QSO in the log. aQso.tSysTime is the time the program stamped when the QSO
  was logged (tGetQSOSystemTime, UTC) or the time ADIF import read from
  TIME_ON, so rescore, edit, import and a multi-op merge all score the hour
  the QSO happened in. Hours 23 and 00-04 UTC double: 23:00 does, 22:59 does
  not, 04:59 does, 05:00 does not. *)
unit uContestCroatian;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCroatian = class(TContestBase)
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
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* DOES IT HAVE A ZONE MULTIPLIER? -- see
         TContestBase.HasZoneMultiplier (M11 S5 part 2). *)
      function HasZoneMultiplier: boolean; override;
      (* THE ZONE MULTIPLIER -- see TContestBase.ZoneMultiplierCount and
         ZoneMultiplierZones (M11 S5). *)
      function ZoneMultiplierCount: integer; override;
      function ZoneMultiplierZones: TZoneMultiplierZones; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestCroatian.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: string;
   qsoHour: integer;
begin
   rxCty := string(aQso.QTH.CountryID);

   (* 1. A 9A station working 9A. *)
   if (Station.MyCountry = '9A') and
      (rxCty = '9A')             then
      begin
      aQso.QSOPoints := 1;
      Exit;
      end;

   (* 2. A 9A station working anyone else. *)
   if Station.MyCountry = '9A' then
      begin
      if aQso.QTH.Continent = Europe then
         begin
         case aQso.Band of
            Band160: aQso.QSOPoints := 4;
            Band80:  aQso.QSOPoints := 4;
            Band40:  aQso.QSOPoints := 2;
            Band20:  aQso.QSOPoints := 2;
            Band15:  aQso.QSOPoints := 2;
            Band10:  aQso.QSOPoints := 2;
         end;
         end;
      if aQso.QTH.Continent <> Europe then
         begin
         case aQso.Band of
            Band160: aQso.QSOPoints := 10;
            Band80:  aQso.QSOPoints := 10;
            Band40:  aQso.QSOPoints := 8;
            Band20:  aQso.QSOPoints := 6;
            Band15:  aQso.QSOPoints := 6;
            Band10:  aQso.QSOPoints := 6;
         end;
         end;
      Exit;
      end;

   (* 3. Anyone else working 9A. *)
   if rxCty = '9A' then
      begin
      case aQso.Band of
         Band160: aQso.QSOPoints := 10;
         Band80:  aQso.QSOPoints := 10;
         Band40:  aQso.QSOPoints := 10;
         Band20:  aQso.QSOPoints := 6;
         Band15:  aQso.QSOPoints := 6;
         Band10:  aQso.QSOPoints := 6;
      end;
      end;

   (* 4. Our own continent -- overwrites step 3, as the arm did. *)
   if aQso.QTH.Continent = Station.MyContinent then
      begin
      case aQso.Band of
         Band160: aQso.QSOPoints := 2;
         Band80:  aQso.QSOPoints := 2;
         Band40:  aQso.QSOPoints := 2;
         Band20:  aQso.QSOPoints := 1;
         Band15:  aQso.QSOPoints := 1;
         Band10:  aQso.QSOPoints := 1;
      end;
      end;

   (* 5. Another continent, not 9A. *)
   if (Station.MyContinent <> aQso.QTH.Continent) and
      (rxCty <> '9A')                            then
      begin
      case aQso.Band of
         Band160: aQso.QSOPoints := 6;
         Band80:  aQso.QSOPoints := 6;
         Band40:  aQso.QSOPoints := 6;
         Band20:  aQso.QSOPoints := 3;
         Band15:  aQso.QSOPoints := 3;
         Band10:  aQso.QSOPoints := 3;
      end;
      end;

   (* 6. THE NIGHT DOUBLING, by the hour the QSO was recorded in (UTC) --
      see the header. Never the clock. *)
   qsoHour := aQso.tSysTime.qtHour;
   if (qsoHour >= 23) or
      (qsoHour < 5)   then
      begin
      aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
      end;
end;

function TContestCroatian.GetDisplayName: string;
begin
   Result := 'Croatian DX Contest';
end;

function TContestCroatian.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CROATIAN';
end;

function TContestCroatian.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CROATIAN';
end;

function TContestCroatian.GetWA7BNMId: integer;
begin
   Result := 206;
end;

function TContestCroatian.GetQRZRUId: integer;
begin
   Result := 91;
end;

function TContestCroatian.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCroatian.GetDomesticFileName: string;
begin
   Result := 'croat';
end;

function TContestCroatian.GetFriendlyName: string;
begin
   Result := 'Croatian DX Contest';
end;

function TContestCroatian.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCroatian.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestCroatian.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestCroatian.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand,
              cfQSOByMode,
              cfMultByBand,
              cfMultByMode,
              cfCQZoneMode];
end;

function TContestCroatian.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for a Croatian entrant; none for anyone else. This is the
   station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey asks it, so
   the two cannot disagree. *)
function TContestCroatian.HasDXMultiplier: boolean;
begin
   Result := Station.MyCountry = '9A';
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country, for a Croatian entrant (CQDXCC, which DescribeSession
   states for 9A); none for anyone else, whose session ran the trait's
   NoDXMults. *)
function TContestCroatian.DXMultiplierKey(const aQso: ContestExchange;
                                          out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if HasDXMultiplier then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE ZONE MULTIPLIER -- M11 S5, 2026-10-14: the ITU zones, at every
   station. What the trait's ITUZones gave LOGDUPE's zone count and the
   zone-list readers (LOGEDIT, POSTUNIT) through the session kind until
   S5.

   PLAN F5 / OPEN QUESTION Q95, TRANSCRIBED, NOT FIXED: this contest counts
   ITU zones while its CTY zone mode (GetFlags, cfCQZoneMode) is CQ, so a
   logged zone is a CQ zone and ADIF export writes it as ITUZ -- W1AW, CQ
   zone 5, exports <ITUZ:2>05. The two facts are kept apart here and pinned
   side by side in uTestZoneMultiplier; reconciling them is NY4I's call. *)
function TContestCroatian.ZoneMultiplierCount: integer;
begin
   Result := ITU_ZONE_MULTIPLIERS;
end;

(* IT HAS A ZONE MULTIPLIER, AT EVERY STATION -- M11 S5 part 2,
   2026-10-14: the answer the session kind gave (`kind <> NoZoneMults`)
   before the kind was deleted. *)
function TContestCroatian.HasZoneMultiplier: boolean;
begin
   Result := True;
end;

function TContestCroatian.ZoneMultiplierZones: TZoneMultiplierZones;
begin
   Result := zmzITUZones;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestCroatian.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(CROATIAN, TContestCroatian);

end.
