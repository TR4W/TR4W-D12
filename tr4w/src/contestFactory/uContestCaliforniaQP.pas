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

(* CALIFORNIA QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'california_cty';  WA7BNM: 140;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 6;  AE: QSONumberDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: ThreePointsPerQSO;  ADIFName: 'CA-QSO-PARTY';  CABName: '';
   CountyLineAllowed: True;  FriendlyName: 'California QSO Party'

  ITS FORMER ADIF ID IS 'CALIFORNIA QSO PARTY'. The ADIF id was blank until
  2026-09-29, and while it was, ADIF export fell back to the enum's spelling
  -- so every file exported before then carries CONTEST_ID 'CALIFORNIA QSO
  PARTY'. Import accepts it, export never writes it: NY4I, "Yes support old
  spellings."

  FOUR COUNTIES, AND THE NUMBER IS THE SPONSOR'S RATHER THAN A GUESS. NY4I,
  2026-09-29: "4 since that is the intersection of 4 counties with common 90
  degree angle borders." A four-county junction is the most counties that can
  physically meet at a point, and CQP lets a station on one claim all four.

  IT IS THE LARGEST OF THE THREE ANSWERS THAT EXIST SO FAR -- Michigan none,
  Florida two, California four -- which is precisely why the rule is a COUNT on
  the base and not a boolean. A flag can express only the first distinction and
  the wrong answer would read as a legal one.
 *)
unit uContestCaliforniaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestCaliforniaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'CA' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFormerADIFContestIds: TContestIdList; override;
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

      (* The county-line maximum, from the sponsor -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* The received column -- see the implementation. *)
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

(* THE RECEIVED COUNTY IS THE QSO'S OWN QTHString, OR 'DX' -- M4, 2026-10-01.

   PostUnit's Cabrillo writer carried this as `if Contest in [CALQSOPARTY]`:
   whatever his-QTH the exporter had chosen, California's column took the
   QSO's QTHString, and 'DX' when the QSO earned no domestic multiplier
   (DomMultQTH empty) -- an out-of-state or DX station. That is California's
   rule about its own column, so it is stated here and the shared arm for the
   session's exchange still lays out the line.

   The writer also set the record's DomMultQTH to 'DX' while doing it. Nothing
   downstream read that -- the arm reads only the his-QTH, and the next record
   replaces the whole exchange -- so the copy is not made. *)
function TContestCaliforniaQP.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                             const aQso: ContestExchange;
                                                             const aCtx: TCabrilloQSOContext): string;
var
   ctx: TCabrilloQSOContext;
begin
   ctx := aCtx;
   ctx.HisQTH := string(aQso.QTHString);
   if aQso.DomMultQTH = '' then
      begin
      ctx.HisQTH := 'DX';
      end;
   Result := inherited FormatCabrilloReceivedExchange(aMy, aQso, ctx);
end;

function TContestCaliforniaQP.GetDisplayName: string;
begin
   Result := 'California QSO Party';
end;

function TContestCaliforniaQP.GetHostState: string;
begin
   Result := 'CA';
end;

function TContestCaliforniaQP.GetCabrilloName: string;
begin
   Result := 'CALIFORNIA QSO PARTY';
end;

function TContestCaliforniaQP.GetADIFContestId: string;
begin
   (* STATED, NOT LEFT BLANK. The row held '' until 2026-09-29; ADIF 3.1.7
      defines CA-QSO-PARTY and NY4I had VC.pas corrected.

      ADIFName IS WHAT ADIF EXPORT WRITES AS CONTEST_ID (NY4I, who wrote
      that code), and it is also what import matches on. A BLANK IS NOT
      'no id' -- export falls back to the contest's quoted name -- so a
      blank row still produced a CONTEST_ID, just not the standard one.
      Stating it means the exported file now carries the ADIF identifier
      a sponsor's robot expects, and the class cannot drift from it. *)
   Result := 'CA-QSO-PARTY';
end;

function TContestCaliforniaQP.GetFormerADIFContestIds: TContestIdList;
begin
   (* What ADIF export wrote while the row's ADIFName was blank: the enum's
      spelling. See the unit header. *)
   Result := ContestIdList(['CALIFORNIA QSO PARTY']);
end;

function TContestCaliforniaQP.GetWA7BNMId: integer;
begin
   Result := 140;
end;

function TContestCaliforniaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCaliforniaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCaliforniaQP.GetDomesticFileName: string;
begin
   Result := 'california_cty';
end;

function TContestCaliforniaQP.GetFriendlyName: string;
begin
   Result := 'California QSO Party';
end;

function TContestCaliforniaQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCaliforniaQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCaliforniaQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCaliforniaQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCaliforniaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCaliforniaQP.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberDomesticOrDXQTHExchange;
end;

function TContestCaliforniaQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ThreePointsPerQSO;
end;

function TContestCaliforniaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 4;
end;

(* ThreePointsPerQSO -- `RXData.QSOPoints := 3`, a flat three whatever the
   mode. All three numbers are the same and are still written out: the
   day this contest gains a mode rule, the shape is already here. *)
procedure TContestCaliforniaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 3, 3);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCaliforniaQP.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   (* BOTH SIDES OF THE STATE LINE, STATED (inventory D8). *)
   if aStation.InHostState then
      begin
      aSession.Exchange := QSONumberDomesticOrDXQTHExchange;
      end
   else
      begin
      aSession.Exchange := QSONumberDomesticQTHExchange;
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestCaliforniaQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyState;
end;

initialization
   RegisterContest(CALQSOPARTY, TContestCaliforniaQP);

end.
