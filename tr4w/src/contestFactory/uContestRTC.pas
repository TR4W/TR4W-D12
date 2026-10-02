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

(* THE REAL TIME CONTEST (RTC).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 782;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: GridInitialExchange;
   DM: GridSquares;  P: 0;  AE: RSTQSONumberAndGridSquareExchange;
   XM: NoDXMults;  QP: RTCQSOPointMethod;
   ADIFName: 'RTC';  CABName: 'RTC';
   FriendlyName: 'Real Time Contest'

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: RTCQSOPointMethod (Issue #902) -- on 40, 20, 15 and 10 m, CW or
  phone, with MY GRID and the received grid: the haversine distance between
  the two four-character squares' centres (LOGGRID.RTCGridDistance) scores
  1 under 2000 km, 2 under 4000, 3 under 8000 and 4 beyond. Any other band
  or mode: 0 AND no multiplier (InhibitMults) -- the arm's own band rule,
  kept in the arm (UsesBand would not set InhibitMults; Q44). Not reached by
  design Q37: the haversine bounds a short grid.

  SET-UP: WARC off; the CQ, S&P and repeat S&P exchanges are the serial and
  MY GRID; CQ F3, and exchange F4, F5 and Alt-F4, are the serial and grid
  prompts, and exchange F4 and F5 are captioned 'NR' and 'Cl+Ex' (the
  caption memories joined TSessionDefaults at this move).

  NOT MOVED, ON PURPOSE: uExchangeBuilder's HamScore sent and received
  exchanges ("<serial> <grid>", no RST) name it -- a seam not built yet
  (M9). *)
unit uContestRTC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestRTC = class(TContestBase)
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
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
      (* THE CANONICAL SENT EXCHANGE -- M9a. *)
      function CanonicalSentExchange(const aQso: ContestExchange;
                                     const aCtx: TCanonicalExchangeContext): string; override;
   end;

implementation

uses
   uContestRegistry,
   LOGGRID,
   uTR4WStrings,
   SysUtils,
   uCanonicalExchange;

(* RTCQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestRTC.CalculateQSOPoints(var aQso: ContestExchange);
var
   distanceKm: Double;
begin
   (* Rules permit only 40/20/15/10 m on CW and SSB: any QSO outside
      those bands or modes scores 0 and does NOT count as a multiplier. *)
   if not (aQso.Band in [Band40, Band20, Band15, Band10]) then
      begin
      aQso.QSOPoints := 0;
      aQso.InhibitMults := True;
      end
   else if not (aQso.Mode in [CW, Phone]) then
      begin
      aQso.QSOPoints := 0;
      aQso.InhibitMults := True;
      end
   else if (Station.MyGrid <> '') and (aQso.QTHString <> '') then
      begin
      distanceKm := RTCGridDistance(Station.MyGrid, aQso.QTHString);
      if distanceKm < 2000.0 then
         begin
         aQso.QSOPoints := 1;
         end
      else if distanceKm < 4000.0 then
         begin
         aQso.QSOPoints := 2;
         end
      else if distanceKm < 8000.0 then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 4;
         end;
      end;
end;

function TContestRTC.GetDisplayName: string;
begin
   Result := 'Real Time Contest';
end;

function TContestRTC.GetCabrilloName: string;
begin
   Result := 'RTC';
end;

function TContestRTC.GetADIFContestId: string;
begin
   Result := 'RTC';
end;

function TContestRTC.GetWA7BNMId: integer;
begin
   Result := 782;
end;

function TContestRTC.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestRTC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestRTC.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestRTC.GetFriendlyName: string;
begin
   Result := 'Real Time Contest';
end;

function TContestRTC.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestRTC.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestRTC.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestRTC.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := GridSquares;
end;

function TContestRTC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := GridInitialExchange;
end;

function TContestRTC.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndGridSquareExchange;
end;

function TContestRTC.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RTCQSOPointMethod;
end;

function TContestRTC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestRTC.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.WARCEnabled := False;
   aSession.CQExchangeCW := ' # ' + aStation.MyGrid;
   aSession.RepeatSPExchangeCW := ' # ' + aStation.MyGrid;
   aSession.SPExchangeCW := ' # ' + aStation.MyGrid;
   aSession.SetCQMemory(CW, smkF3, '# ' + aStation.MyGrid);
   aSession.SetExchangeMemory(CW, smkF4, 'NR # ' + aStation.MyGrid);
   aSession.SetExchangeMemory(CW, smkF5, '@ DE \ # ' + aStation.MyGrid);
   aSession.SetExchangeMemory(CW, smkAltF4, 'NR?');
   aSession.SetExchangeCaptionMemory(CW, smkF4, 'NR');
   aSession.SetExchangeCaptionMemory(CW, smkF5, 'Cl+Ex');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN,
   ARRLVHFSEP, BATAVIA_FT8, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, MAKROTHEN,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestRTC.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the serial and the grid, with
   NO RST -- the HamScore RTC organizer, 2026-05: the signal report is
   left out of both exchanges. See TContestBase.CanonicalReceivedExchange;
   the caller collapses the whitespace. *)
function TContestRTC.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := IntToStr(aQso.NumberReceived) + ' ' + Trim(string(aQso.QTHString));
end;

(* THE CANONICAL SENT EXCHANGE IS OUR SERIAL AND OUR GRID, WITH NO RST --
   uExchangeBuilder's `ceContest = RTC` test, moved here at M9a (2026-10-02).
   The rules permit an RST on air, and an operator may put 5NN in the CQ
   exchange template; the template is deliberately not read, so none leaks
   into the upload. On-air keying is unaffected. *)
function TContestRTC.CanonicalSentExchange(const aQso: ContestExchange;
                                           const aCtx: TCanonicalExchangeContext): string;
begin
   Result := CollapseWhitespace(IntToStr(aQso.NumberSent) + ' ' + Trim(aCtx.MyGrid));
end;

initialization
   RegisterContest(RTC, TContestRTC);

end.
