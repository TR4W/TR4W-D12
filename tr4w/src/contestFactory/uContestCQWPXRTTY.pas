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

(* THE CQ WW WPX RTTY CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: 'rtty@cqwpx.com';  DF: '';  WA7BNM: 245;  QRZRUID: 6;
   Pxm: Prefix;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTQSONumberExchange;
   XM: NoDXMults;  QP: CQWPXRTTYQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'CQ WW RTTY WPX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CQ-WPX-RTTY'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A MEMBER OF THE CQ WPX FAMILY (M7b, DECIDED on evidence).
  TContestCQWPXBase holds the CW and SSB runnings under ONE rule -- its
  CQWPXQSOPointMethod band table and its own Cabrillo and ADIF columns.
  This contest scores by another arm (CQWPXRTTYQSOPointMethod: no band
  table, the 80/40 m doubling) and has always exported through the shared
  RST-and-serial arm; under the base it would inherit both and change. Same
  sponsor, different rule, so it is its own class on TContestBase.

  SCORING: our own country 1, our own continent 2, elsewhere 3; doubled on
  80 m and 40 m.

  SET-UP: 80 m (FoundContest's arm named it beside WRTC, which keeps it). *)
unit uContestCQWPXRTTY;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCQWPXRTTY = class(TContestBase)
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
   end;

implementation

uses
   uContestRegistry;

procedure TContestCQWPXRTTY.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent = Station.MyContinent then
      begin
      if rxCty = Station.MyCountry then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else
      begin
      aQso.QSOPoints := 3;
      end;

   if (aQso.Band = Band80) or
      (aQso.Band = Band40) then
      begin
      aQso.QSOPoints := aQso.QSOPoints + aQso.QSOPoints;
      end;
end;

function TContestCQWPXRTTY.GetDisplayName: string;
begin
   Result := 'CQ WW RTTY WPX Contest';
end;

function TContestCQWPXRTTY.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'CQ-WPX-RTTY';
end;

function TContestCQWPXRTTY.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'CQ-WPX-RTTY';
end;

function TContestCQWPXRTTY.GetWA7BNMId: integer;
begin
   Result := 245;
end;

function TContestCQWPXRTTY.GetQRZRUId: integer;
begin
   Result := 6;
end;

function TContestCQWPXRTTY.GetSubmissionEmail: string;
begin
   Result := 'rtty@cqwpx.com';
end;

function TContestCQWPXRTTY.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCQWPXRTTY.GetFriendlyName: string;
begin
   Result := 'CQ WW RTTY WPX Contest';
end;

function TContestCQWPXRTTY.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := Prefix;
end;

function TContestCQWPXRTTY.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCQWPXRTTY.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCQWPXRTTY.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestCQWPXRTTY.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCQWPXRTTY.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestCQWPXRTTY.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := CQWPXRTTYQSOPointMethod;
end;

function TContestCQWPXRTTY.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestCQWPXRTTY.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
end;

initialization
   RegisterContest(CQWPXRTTY, TContestCQWPXRTTY);

end.
