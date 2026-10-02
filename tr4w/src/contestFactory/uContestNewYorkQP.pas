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

(* NEW YORK QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'newyork_cty';  WA7BNM: 473;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 3;  AE: RSTDomesticQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;  ADIFName: 'NY-QSO-PARTY';
   CABName: '';  FriendlyName: 'New York QSO Party'

  TWO COUNTIES ON A COUNTY LINE -- NY4I, 2026-09-29: "NY allows up to 2
  counties on a county line."

  So GetCountyLineCountiesMax returns 2, the way North Carolina's and
  Indiana's do. THE ROW CARRIES NO CountyLineAllowed FIELD AT ALL, so the
  array boolean reads False -- which only ever meant UNKNOWN -- and the number
  was never going to come from it. Until this ruling the class inherited
  CountyLineCountiesUnlimited; a third county on one exchange is now refused.

  CABName IS BLANK, AND BLANK MEANS "THE ENUM'S SPELLING", which for this
  contest is 'NY-QSO-PARTY' (ContestTypeSA). GetCabrilloName states that
  resolved value, not the empty string.

  ONE NEW YORK RULE STILL LIVES IN SHARED CODE AND IS NOT MOVED HERE.
  logdupe.pas: "if (Contest = NYQP) and (RXData.DomMultQTH = 'DX') then exit"
  -- a DX station is no domestic multiplier. That is multiplier logic, which no
  contest class owns yet; British Columbia and Indiana have the same shape in
  the same routine and were left there too. It is the same in D7.

  FCONTEST's NYQP arm set ActiveDomesticMult := DomesticFile, which is what
  the row already says; it is DescribeSession since M7a, still stated, so it
  still overwrites a DOMESTIC MULTIPLIER line before CONTEST as it did.
 *)
unit uContestNewYorkQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestNewYorkQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'NY' -- but the base makes it abstract
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

      (* The county-line maximum, from NY4I's ruling -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestNewYorkQP.GetDisplayName: string;
begin
   Result := 'New York QSO Party';
end;

function TContestNewYorkQP.GetHostState: string;
begin
   Result := 'NY';
end;

function TContestNewYorkQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'NY-QSO-PARTY';
end;

function TContestNewYorkQP.GetADIFContestId: string;
begin
   (* Matches ADIF 3.1.7's Contest_ID enumeration, "NY-QSO-PARTY -- New York
      QSO Party", checked against the published table on 2026-09-29. *)
   Result := 'NY-QSO-PARTY';
end;

function TContestNewYorkQP.GetWA7BNMId: integer;
begin
   Result := 473;
end;

function TContestNewYorkQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewYorkQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNewYorkQP.GetDomesticFileName: string;
begin
   Result := 'newyork_cty';
end;

function TContestNewYorkQP.GetFriendlyName: string;
begin
   Result := 'New York QSO Party';
end;

function TContestNewYorkQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestNewYorkQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestNewYorkQP.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestNewYorkQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestNewYorkQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewYorkQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHExchange;
end;

function TContestNewYorkQP.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OnePhoneTwoCW;
end;

(* OnePhoneTwoCW -- `if Mode = CW then 2 else 1`, so DIGITAL scores the PHONE
   value. That is why the third number is stated rather than left to a
   CW-versus-not test, which would be wrong here and silent about it. *)
function TContestNewYorkQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

procedure TContestNewYorkQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestNewYorkQP.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.DomesticMult := DomesticFile;
end;

initialization
   RegisterContest(NYQP, TContestNewYorkQP);

end.
