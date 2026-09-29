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

(* WASHINGTON STATE SALMON RUN -- WASHINGTON'S STATE QSO PARTY.

  It does not say "QSO party" in its name, and it is one: it has its own entry
  in QSOParties (index 9, StateName 'WA', county files washington.dom and
  washington_cty.dom), so the inherited IsUSQSOParty already answered True
  before this class existed.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'washington_cty';  WA7BNM: 126;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 9;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: SalmonRunQSOPointMethod;  ADIFName: 'WA-QSO-PARTY';
   CABName: 'WA-SALMON-RUN';  FriendlyName: 'Washington State Salmon Run'

  ---------------------------------------------------------------------------
  THE ROW IS NOT WHAT A RUNNING CONTEST USES FOR TWO OF THESE FIELDS, AND THE
  CLASS STATES THE ROW ANYWAY.

  FCONTEST's SALMONRUN arm rewrites them at setup, by where the operator is:

    in Washington      ActiveExchange := RSTDomesticOrDXQTHExchange
                       ActiveDXMult   := ARRLDXCCWithNoUSAOrCanada
    outside it         ActiveExchange := RSTDomesticQTHExchange
                       (DX multiplier left at the row's NoDXMults)

  That decision reads a file (FoundMyStateInDomFile), which is setup work and
  belongs to FCONTEST until the setup migration; a contest class that read it
  could not be constructed in a test. Nothing outside the factory reads these
  accessors today -- setup reads ContestsArray and then FCONTEST adjusts -- so
  stating the row here changes nothing. It does mean GetExchangeKind and
  GetDXMultiplierType describe the ROW, not an in-state operator's contest.

  ---------------------------------------------------------------------------
  THE ROW CARRIES NO CountyLineAllowed FIELD, so the array boolean reads False,
  which means UNKNOWN rather than "forbidden". No maximum has been established
  from the sponsor's rules, so this inherits CountyLineCountiesUnlimited --
  what TR4W does today.

  BOTH NAMES WERE BLANK UNTIL 2026-09-29, AND NY4I RULED BOTH.

    ADIF    'WA-QSO-PARTY' -- ADIF 3.1.7's "Washington QSO Party".
    Cabrillo 'WA-SALMON-RUN' -- the sponsor's own: "the WA-SALMON-RUN (our
            official name)", https://salmonrun.wwdxc.org/rules/.

  While they were blank, both exports fell back to the enum's spelling,
  'SALMON RUN', space included. So every ADIF file exported before the change
  carries CONTEST_ID 'SALMON RUN', and that is this contest's former id --
  import accepts it: "Yes support old spellings." The display name is
  unchanged; it was never the blank.
 *)
unit uContestWashingtonSalmonRun;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestWashingtonSalmonRun = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'WA' -- but the base makes it abstract
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
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestFixedPoints,   (* FixedModePoints *)
   uContestRegistry;

function TContestWashingtonSalmonRun.GetDisplayName: string;
begin
   Result := 'Washington State Salmon Run';
end;

function TContestWashingtonSalmonRun.GetHostState: string;
begin
   Result := 'WA';
end;

function TContestWashingtonSalmonRun.GetCabrilloName: string;
begin
   Result := 'WA-SALMON-RUN';
end;

function TContestWashingtonSalmonRun.GetADIFContestId: string;
begin
   Result := 'WA-QSO-PARTY';
end;

function TContestWashingtonSalmonRun.GetFormerADIFContestIds: TContestIdList;
begin
   (* What ADIF export wrote while the row's ADIFName was blank: the enum's
      spelling. See the unit header. *)
   Result := ContestIdList(['SALMON RUN']);
end;

function TContestWashingtonSalmonRun.GetWA7BNMId: integer;
begin
   Result := 126;
end;

function TContestWashingtonSalmonRun.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWashingtonSalmonRun.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWashingtonSalmonRun.GetDomesticFileName: string;
begin
   Result := 'washington_cty';
end;

function TContestWashingtonSalmonRun.GetFriendlyName: string;
begin
   Result := 'Washington State Salmon Run';
end;

function TContestWashingtonSalmonRun.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWashingtonSalmonRun.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestWashingtonSalmonRun.GetDXMultiplierType: DXMultType;
begin
   (* The ROW's value. An in-state operator runs with ARRLDXCCWithNoUSAOrCanada,
      set by FCONTEST at setup -- see the unit header. *)
   Result := NoDXMults;
end;

function TContestWashingtonSalmonRun.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestWashingtonSalmonRun.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestWashingtonSalmonRun.GetExchangeKind: ExchangeType;
begin
   (* The ROW's value. An out-of-state operator runs with
      RSTDomesticQTHExchange, set by FCONTEST at setup -- see the unit
      header. *)
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestWashingtonSalmonRun.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := SalmonRunQSOPointMethod;
end;

(* SalmonRunQSOPointMethod -- `if Mode = CW then 4 else 2`, identical in D7.
   DIGITAL scores the PHONE value, 2, which is why the third number is stated.

   THE MECHANISM IS FixedModePoints, CALLED RATHER THAN INHERITED: this class's
   one base is spent on the state-party family, and inheriting
   TContestFixedPoints instead would silently take it out of that family (the
   Florida trap in uContestFixedPoints' header). *)
procedure TContestWashingtonSalmonRun.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 4, 2, 2);
end;

initialization
   RegisterContest(SALMONRUN, TContestWashingtonSalmonRun);

end.
