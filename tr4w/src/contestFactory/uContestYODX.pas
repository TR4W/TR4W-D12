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

(* THE YO DX HF CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'romania';  WA7BNM: 98;  QRZRUID: 328;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTAndQSONumberOrDomesticQTHExchange;
   XM: ARRLDXCC;  QP: YODXQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'YO DX HF Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'YO-DX-HF'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: YODXQSOPointMethod -- a YO station 8; another country 4 off our
  continent and 2 on it; our own country 1.

  SET-UP: the contest name 'YO-DX-HF Contest', YO as a domestic country.

  NOT MOVED, ON PURPOSE: LOGEDIT's new-multiplier check names this contest
  (a Y call's initial exchange) -- the multiplier seam is M8. *)
unit uContestYODX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestYODX = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;

      (* THE COUNTY THE LOG REMEMBERS FOR A ROMANIAN CALL, FOR THE
         NEED-MULTIPLIER HINT -- the arm LOGEDIT.GetMultArray held for this
         contest, moved here at M8 and transcribed exactly: a call whose
         first character is 'Y', then the initial exchange the session holds
         for it (CallsignsList, through aLookups.InitialExchangeOf). *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   uTR4WStrings;

function TContestYODX.DomesticMultiplierFromCall(const aCall: string;
                                                 const aLookups: TMultiplierHintLookups): string;
begin
   Result := '';
   (* The arm read Call[1] of a ShortString, which for an empty call reads a
      stale byte. The length test answers '' there; so did the arm, because
      no entry has an empty call. *)
   if (Length(aCall) > 0) and (aCall[1] = 'Y') and Assigned(aLookups.InitialExchangeOf) then
      begin
      Result := aLookups.InitialExchangeOf(aCall);
      end;
end;

(* YODXQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestYODX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if rxCty = 'YO' then
      begin
      aQso.QSOPoints := 8;
      end
   else if Station.MyCountry <> rxCty then
      begin
      if aQso.QTH.Continent <> Station.MyContinent then
         begin
         aQso.QSOPoints := 4;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestYODX.GetDisplayName: string;
begin
   Result := 'YO DX HF Contest';
end;

function TContestYODX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'YO-DX-HF';
end;

function TContestYODX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'YO-DX-HF';
end;

function TContestYODX.GetWA7BNMId: integer;
begin
   Result := 98;
end;

function TContestYODX.GetQRZRUId: integer;
begin
   Result := 328;
end;

function TContestYODX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestYODX.GetDomesticFileName: string;
begin
   Result := 'romania';
end;

function TContestYODX.GetFriendlyName: string;
begin
   Result := 'YO DX HF Contest';
end;

function TContestYODX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestYODX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestYODX.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestYODX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestYODX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestYODX.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestYODX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := YODXQSOPointMethod;
end;

function TContestYODX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestYODX.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.ContestName := 'YO-DX-HF Contest';
   aSession.AddDomesticCountry('YO');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on ticking the box stood for EUDX, LZDX, OKDX, OKOMSSB,
   RSGB18, SPDX.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestYODX.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_ROMANIA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
end;

initialization
   RegisterContest(YODX, TContestYODX);

end.
