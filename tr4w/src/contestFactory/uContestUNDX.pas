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

(* THE UN DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'kda';  WA7BNM: 480;  QRZRUID: 13;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticQTHOrQSONumberExchange;
   XM: ARRLDXCC;  QP: UNDXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'UN DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'UN DX'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: UNDXQSOPointMethod -- another continent 5, another country 3,
  our own 2; 10 for a UN station worked from outside UN.

  SET-UP: UN as a domestic country. *)
unit uContestUNDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUNDX = class(TContestBase)
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
   uADIFExchange,
   uContestRegistry,
   uTR4WStrings;

(* UNDXQSOPointMethod -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestUNDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;

   if rxCty = 'UN' then
      begin
      if Station.MyCountry <> 'UN' then
         begin
         aQso.QSOPoints := 10;
         end;
      end;
end;

function TContestUNDX.GetDisplayName: string;
begin
   Result := 'UN DX Contest';
end;

function TContestUNDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'UN DX';
end;

function TContestUNDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'UN DX';
end;

function TContestUNDX.GetWA7BNMId: integer;
begin
   Result := 480;
end;

function TContestUNDX.GetQRZRUId: integer;
begin
   Result := 13;
end;

function TContestUNDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUNDX.GetDomesticFileName: string;
begin
   Result := 'kda';
end;

function TContestUNDX.GetFriendlyName: string;
begin
   Result := 'UN DX Contest';
end;

function TContestUNDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUNDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestUNDX.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestUNDX.GetADIFSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrQSONumber(aMy, aQso);
end;

function TContestUNDX.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand,
              cfQSOByMode,
              cfMultByBand,
              cfCountsDomesticCountries];
end;

function TContestUNDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestUNDX.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('UN');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on ticking the box stood for CIS, RU3AXMEMORIAL,
   RUSSIANDX, UKRAINIAN.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestUNDX.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_KAZAKHSTAN);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOUROBLASTID, ncfMyState);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`ARRLDXCC`) until the kind was deleted. *)
function TContestUNDX.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's ARRLDXCC. *)
function TContestUNDX.DXMultiplierKey(const aQso: ContestExchange;
                                      out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station -- the ARRLDXCC kind was in the ARRL set. *)
function TContestUNDX.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestUNDX.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(UNDX, TContestUNDX);

end.
