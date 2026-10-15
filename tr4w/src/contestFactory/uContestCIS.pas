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

(* THE CIS DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'cis';  WA7BNM: 197;  QRZRUID: 500;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: ARRLDXCC;  QP: CISQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'CIS DX Contest, CW'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CIS'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  SCORING: CISQSOPointMethod -- 1; another country 2 on our continent, 3
  elsewhere; then, for a station outside the CIS, a CIS station 5.

  SET-UP: the Russian countries, then UR EU 4J EK UN EX ER EY EZ UK 4L, in
  that order. *)
unit uContestCIS;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCIS = class(TContestBase)
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
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
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
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   (* CISCountry -- the leaf the arm asked. *)
   uCallSignRoutines,
   uTR4WStrings;

procedure TContestCIS.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   aQso.QSOPoints := 1;

   if rxCty <> Station.MyCountry then
      begin
      if aQso.QTH.Continent = Station.MyContinent then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      end;

   if not CISCountry(string(Station.MyCountry)) then
      begin
      if CISCountry(string(rxCty)) then
         begin
         aQso.QSOPoints := 5;
         end;
      end;
end;

function TContestCIS.GetDisplayName: string;
begin
   Result := 'CIS DX Contest, CW';
end;

function TContestCIS.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CIS';
end;

function TContestCIS.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CIS';
end;

function TContestCIS.GetWA7BNMId: integer;
begin
   Result := 197;
end;

function TContestCIS.GetQRZRUId: integer;
begin
   Result := 500;
end;

function TContestCIS.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCIS.GetDomesticFileName: string;
begin
   Result := 'cis';
end;

function TContestCIS.GetFriendlyName: string;
begin
   Result := 'CIS DX Contest, CW';
end;

function TContestCIS.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCIS.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestCIS.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestCIS.GetADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrQSONumber(aMy, aQso);
end;

function TContestCIS.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrQSONumber(aMy, aQso, aCtx);
end;

function TContestCIS.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrQSONumber(aMy, aQso, aCtx);
end;

function TContestCIS.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand, cfCountsDomesticCountries];
end;

function TContestCIS.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCIS.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   aSession.AddDomesticCountry('UR');
   aSession.AddDomesticCountry('EU');
   aSession.AddDomesticCountry('4J');
   aSession.AddDomesticCountry('EK');
   aSession.AddDomesticCountry('UN');
   aSession.AddDomesticCountry('EX');
   aSession.AddDomesticCountry('ER');
   aSession.AddDomesticCountry('EY');
   aSession.AddDomesticCountry('EZ');
   aSession.AddDomesticCountry('UK');
   aSession.AddDomesticCountry('4L');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on ticking the box stood for RU3AXMEMORIAL, RUSSIANDX,
   UKRAINIAN, UNDX.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestCIS.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_CIS);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOUROBLASTID, ncfMyState);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCC`) until the kind was deleted. *)
function TContestCIS.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's ARRLDXCC. *)
function TContestCIS.DXMultiplierKey(const aQso: ContestExchange;
                                     out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station -- the ARRLDXCC kind was in the ARRL set. *)
function TContestCIS.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestCIS.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(CIS, TContestCIS);

end.
