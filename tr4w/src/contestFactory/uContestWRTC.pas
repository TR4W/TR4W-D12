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

(* THE WRTC (IARU HF WORLD CHAMPIONSHIP RULES).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'iaruhq';  WA7BNM: 67;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: ZoneInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTZoneOrSocietyExchange;
   XM: ARRLDXCC;  QP: WRTCQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'IARU HF World Championship'

  Blank CABName and ADIFName resolve to the enum's spelling, 'WRTC'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: WRTCQSOPointMethod -- on 80 to 10 m, 2 for Europe and 5
  elsewhere; 0 on any other band, which still earns its multipliers (the
  arm sets no InhibitMults, and this states no UsesBand -- design Q44).

  SET-UP: 80 m. FoundContest's arm named it beside CQ WPX RTTY until M7b
  batch 1; it is its own now.

  NOT MOVED, ON PURPOSE: the main menu and OpenTR4WWindow refuse it the
  TRMASTER, Telnet and post-scores windows; LOGEDIT turns off Super Check
  Partial for it; LOGSUBS2's score posting reports two multipliers for it.
  Each is a display or networking rule with no seam yet (M9) -- the same
  reason All Asian's HamScore arm stayed at batch 1. *)
unit uContestWRTC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWRTC = class(TContestBase)
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

(* WRTCQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestWRTC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Band in [Band80..Band10] then
      begin
      if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end;
end;

function TContestWRTC.GetDisplayName: string;
begin
   Result := 'WRTC';
end;

function TContestWRTC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'WRTC';
end;

function TContestWRTC.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'WRTC';
end;

function TContestWRTC.GetWA7BNMId: integer;
begin
   Result := 67;
end;

function TContestWRTC.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWRTC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestWRTC.GetDomesticFileName: string;
begin
   Result := 'iaruhq';
end;

function TContestWRTC.GetFriendlyName: string;
begin
   Result := 'IARU HF World Championship';
end;

function TContestWRTC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestWRTC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestWRTC.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestWRTC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := WYSIWYGDomestic;
end;

function TContestWRTC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestWRTC.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrSocietyExchange;
end;

function TContestWRTC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := WRTCQSOPointMethod;
end;

function TContestWRTC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestWRTC.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
end;

initialization
   RegisterContest(WRTC, TContestWRTC);

end.
