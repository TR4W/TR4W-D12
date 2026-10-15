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

(* THE NEW ENGLAND QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 10;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;
   ADIFName: '';  CABName: '';
   FriendlyName: 'New England QSO Party'

  Blank CABName and ADIFName resolve to the enum's spelling, 'NEQP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A STATE QSO PARTY. It is a MULTI-STATE party -- six states -- and its
  row carries no QSOParties index (P: 0), so set-up never ran the party head
  for it, and TContestStateQSOPartyBase's one-host-state rules (the
  out-of-state refusal, the county line) were never applied. It sits on
  TContestBase and keeps exactly that. Whether a multi-state party wants a
  base of its own is a design question recorded in the design doc (M7b),
  not answered here.

  SCORING: OnePhoneTwoCW -- 2 on CW, 1 otherwise.

  SET-UP, both branches stated. A NEW ENGLAND STATION is one whose MY STATE
  begins with ME, NH, VT, MA, CT or RI -- a string comparison of the first
  two characters, D7's rule, as M2 restored it (inventory defect #3: the
  PWORD read never matched, and crashed on an empty MY STATE). It loads
  NEQSOW1, sends RST and its county or DX, and counts DXCC without
  W/VE/KH6/KL7. Everyone else loads NEQSO and sends RST and a county. Both
  count at most 20 DX multipliers, and K, VE, KH6 and KL are domestic. *)
unit uContestNewEnglandQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNewEnglandQP = class(TContestBase)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   private
      (* Does MY STATE begin with one of the six New England states? *)
      class function IsNewEnglandState(const aMyState: string): boolean;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the station test
         DescribeSession stated the DX kind under (deleted at M11 S4 part 2);
         HasDXMultiplier, the key and the country list ask it, so the answers
         cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
      (* THE ROVER COUNTY -- see TContestBase.StripsRoverCountyFromCall (M11 S7)
         and SplitsRoverCallOnExport (Q90/Q94). *)
      function StripsRoverCountyFromCall: boolean; override;
      function SplitsRoverCallOnExport: boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   end;

implementation

uses
   uDXMultiplierKey,
   uContestRegistry,
   (* FixedModePoints -- the helper for a number per mode. *)
   uContestFixedPoints,
   uTR4WStrings;

procedure TContestNewEnglandQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

class function TContestNewEnglandQP.IsNewEnglandState(const aMyState: string): boolean;
var
   state: string;
begin
   state := Copy(aMyState, 1, 2);
   Result := (state = 'ME') or
             (state = 'NH') or
             (state = 'VT') or
             (state = 'MA') or
             (state = 'CT') or
             (state = 'RI');
end;

function TContestNewEnglandQP.GetDisplayName: string;
begin
   Result := 'New England QSO Party';
end;

function TContestNewEnglandQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'NEQP';
end;

function TContestNewEnglandQP.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'NEQP';
end;

function TContestNewEnglandQP.GetWA7BNMId: integer;
begin
   Result := 10;
end;

function TContestNewEnglandQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewEnglandQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNewEnglandQP.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestNewEnglandQP.GetFriendlyName: string;
begin
   Result := 'New England QSO Party';
end;

function TContestNewEnglandQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewEnglandQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestNewEnglandQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode];
end;

function TContestNewEnglandQP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestNewEnglandQP.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   if IsNewEnglandState(aStation.MyState) then
      begin
      aSession.DomesticFile := 'NEQSOW1';
      aSession.Exchange := RSTDomesticOrDXQTHExchange;
      end
   else
      begin
      aSession.DomesticFile := 'NEQSO';
      aSession.Exchange := RSTDomesticQTHExchange;
      end;

   aSession.DXMultLimit := 20;
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestNewEnglandQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NEWENGLAND);
   aPrompts.AskFieldWithCommentWhenInside(TC_NEWENGLANDSTATEABREVIATION, ncfMyState);
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestNewEnglandQP.CountsDXMultiplier: boolean;
begin
   Result := IsNewEnglandState(Station.MyState);
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for an entrant in New England; none for anyone else. This
   is the station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey and the
   country list ask the same predicate, so the answers cannot disagree. *)
function TContestNewEnglandQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA, Canada, Hawaii and Alaska, for an entrant in New England (ARRLDXCCWithNoUSACanadaKH6OrKL7, which
   DescribeSession stated there); none for anyone else. *)
function TContestNewEnglandQP.DXMultiplierKey(const aQso: ContestExchange;
                                              out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if CountsDXMultiplier and
      not IsUSACanadaHawaiiOrAlaskaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestNewEnglandQP.CountryMode: CountryModeType;
begin
   if CountsDXMultiplier then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestNewEnglandQP.UsesDomesticFile: boolean;
begin
   Result := True;
end;

(* A CALL'S /SUFFIX THAT THE DOMESTIC TABLE KNOWS IS A ROVER'S COUNTY, at
   every station, stripped live AND split on ADIF export. M11 S7 transcribed
   the strip from the session's RSTDomesticOrDXQTH (in New England) or
   RSTDomesticQTH shape; NY4I's ruling on Q94 with Q90 (2026-10-14) made both
   every QSO party's answer: "yes QSO parties allow it". NEQP is a
   multi-state party on TContestBase, so it states them here rather than
   inheriting them from TContestStateQSOPartyBase. See
   TContestBase.StripsRoverCountyFromCall. *)
function TContestNewEnglandQP.StripsRoverCountyFromCall: boolean;
begin
   Result := True;
end;

function TContestNewEnglandQP.SplitsRoverCallOnExport: boolean;
begin
   Result := True;
end;

(* OUTSIDE NEW ENGLAND ONE ENTRY MAY CARRY SEVERAL QTHs (RSTDomesticQTH);
   inside it, not (RSTDomesticOrDXQTH) -- M11 S7, 2026-10-14. It was the
   session's shape, and this is the station test DescribeSession chooses the
   shape by; see TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestNewEnglandQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := not CountsDXMultiplier;
end;

initialization
   RegisterContest(NEWENGLANDQSO, TContestNewEnglandQP);

end.
