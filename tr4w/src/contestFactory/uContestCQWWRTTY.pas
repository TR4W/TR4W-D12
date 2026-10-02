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

(* THE CQ WORLDWIDE DX CONTEST, RTTY.

  The ContestsArray row this class states, verbatim:

   Email: 'rtty@cqww.com';  DF: 's48p14dc';  WA7BNM: 130;  QRZRUID: 191;
   Pxm: NoPrefixMults;  ZnM: CQZones;  AIE: ZoneInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTZoneAndPossibleDomesticQTHExchange;
   XM: CQDXCC;  QP: CQWWRTTYQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'CQ Worldwide DX Contest, RTTY'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-WW-RTTY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A MEMBER OF THE CQ WW FAMILY (M7b, DECIDED on evidence).
  TContestCQWWBase holds the CW and SSB runnings under ONE rule:
  CQWWQSOPointMethod (our own country 0, North America's 2) and its own
  ADIF import. This contest scores by another arm (our own country 1, no
  North American rule), sends a zone AND a state, counts domestic
  multipliers from s48p14dc, and has always imported through the base's
  default. Same sponsor, different rule, so it is its own class on
  TContestBase.

  SCORING: CQWWRTTYQSOPointMethod -- another continent 3, another country 2,
  our own country 1.

  SET-UP: none -- FoundContest's arm for it was commented out in D7, and
  that dead block was deleted at M7b. *)
unit uContestCQWWRTTY;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQWWRTTY = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry;

procedure TContestCQWWRTTY.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 3;
      end
   else if rxCty <> Station.MyCountry then
      begin
      aQso.QSOPoints := 2;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestCQWWRTTY.GetDisplayName: string;
begin
   Result := 'CQ-WW-RTTY';
end;

function TContestCQWWRTTY.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CQ-WW-RTTY';
end;

function TContestCQWWRTTY.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CQ-WW-RTTY';
end;

function TContestCQWWRTTY.GetWA7BNMId: integer;
begin
   Result := 130;
end;

function TContestCQWWRTTY.GetQRZRUId: integer;
begin
   Result := 191;
end;

function TContestCQWWRTTY.GetSubmissionEmail: string;
begin
   Result := 'rtty@cqww.com';
end;

function TContestCQWWRTTY.GetDomesticFileName: string;
begin
   Result := 's48p14dc';
end;

function TContestCQWWRTTY.GetFriendlyName: string;
begin
   Result := 'CQ Worldwide DX Contest, RTTY';
end;

function TContestCQWWRTTY.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCQWWRTTY.GetZoneMultiplierType: ZoneMultType;
begin
   Result := CQZones;
end;

function TContestCQWWRTTY.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestCQWWRTTY.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCQWWRTTY.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestCQWWRTTY.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneAndPossibleDomesticQTHExchange;
end;

function TContestCQWWRTTY.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQWWRTTYQSOPointMethod;
end;

function TContestCQWWRTTY.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(CQWWRTTY, TContestCQWWRTTY);

end.
