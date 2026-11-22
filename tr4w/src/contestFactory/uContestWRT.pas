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

(* WRT, THE WEEKLY RTTY TEST -- added 2026-11-22 (issue 25).

  THE SOURCE. The organizers' rules page, https://radiosport.world/wrt.html
  (N3QE and WV4P), transcribed in docs/ContestRules/WRT/rules.md with the
  organizers' own N1MM+ module beside it (WRT.udc, revision 1.0.2). DXLog.net's
  definition (Contest\WRT.txt, "Weekly RTTY Test") agrees on every point
  below. Nothing here comes from D7, which never had this contest.

  A NEW CONTEST, SO IT REGISTERS BY ITS ID (Q108 S3/S4): no ContestType
  member, no legacy number, no VC.pas entry. Its id 'WRT' is STORED DATA from
  today and is never given to another contest.

  THE CONTEST, rule by rule, and where each lives:
    * schedule -- "Held every Thursday night, 0145-0215Z (Friday UTC)":
      GetSchedule, every Friday 01:45 UTC for 30 minutes.
    * mode -- RTTY (the UDC's Mode = RTTY, DXLog's MODES=RTTY; the rules
      page names it only in the title): UsesMode credits the RTTY submodes
      (DigitalSubmodeAllowed), RunsInMode is Digital and DescribeSession
      starts the session in Digital. Any other QSO is logged and is an
      automatic X-QSO (Q98).
    * bands -- "10, 15, 20, 40, and 80 Meter bands": UsesBand. No 160 m, no
      WARC, no VHF.
    * exchange -- "W/VE - Name and State; DX - Name and Country Prefix": the
      engine's name-and-domestic-or-DX-QTH format, as the CWT's. There is no
      domestic file and no domestic multiplier, so a W/VE station's state is
      taken as typed (TDomQTHTable.GetDomQTH answers True for a contest with
      no domestic multiplier) -- exactly as in the CWT.
    * what I send -- MY NAME and MY STATE. A DX entrant states its country
      prefix as MY STATE (the New Contest prompt asks for "US state, Canadian
      Province or DX country"); nothing derives it. OPEN: see below.
    * points -- "1 Point per QSO": CalculateQSOPoints.
    * multipliers -- "Each unique call (once per session) is a multiplier":
      the worked callsign is the PREFIX multiplier key (PrefixMultiplierKey,
      as the CWT and the CW Open), counted once for the whole session -- the
      flags state neither cfMultByBand nor cfMultByMode. No DX, zone or
      domestic multiplier. The totals grid says Calls (GetTotalsDisplay).
    * score -- the QSO points times the calls: the base's
      CombineWithMultipliers.
    * dupes -- once per band (cfQSOByBand): NY4I on issue 25, the UDC's
      DupeType = 2 is "Each band (stations may be worked once on each band)";
      DXLog's DOUBLE_QSO=PER_BAND says the same. RTTY only, so not by mode.
    * categories -- "100 Watt (Low-Power) and 5 Watt (QRP)": the Cabrillo
      summary's CATEGORY-POWER; no rule here.
    * reporting -- "Report your results on 3830scores.com. Hamscore
      real-time scoring is supported": no submission e-mail, and
      cfRTCCapable.
    * Cabrillo CONTEST: WRT -- the UDC's CabrilloName and DXLog's
      CABRILLO_CONTEST_NAME. The rules page states none.

  NO ADIF CONTEST_ID EXISTS for it (ADIF 3.1.6's Contest_ID enumeration has
  no WRT entry, checked 2026-11-22), so export writes the contest's own id,
  as a by-id contest does, and import matches it.

  KNOWN LIMIT -- A CALL LONGER THAN SIX CHARACTERS (OPEN, owner's decision).
  The prefix multiplier key is a PrefixMultiplierString, string[6], carried in
  ContestExchange.Prefix -- a field of the 376-byte record the .TRW import and
  the multi-op wire read as raw bytes -- and the multiplier sheet compares its
  keys at ten characters (TSortedStringList, a Str10). So two calls that share
  their first six characters (WB9ABCD and WB9ABCE; K1ABC/4 and K1ABC/7) count
  as ONE multiplier, exactly as in the CWT and the CW Open
  (uTestPrefixMultiplierKey pins CWOPEN's WB9ABCD as 'WB9ABC'). Widening the
  key is a change to that encoding and to the sheet, not to this class; it is
  not made here. uTestContestWRT pins today's answer so the fix moves it. *)
unit uContestWRT;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

const
   (* ITS ID -- stored data; see the header. *)
   WRT_CONTEST_ID = 'WRT';

type
   TContestWRT = class(TContestBase)
   protected
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
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
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags. *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE TOTALS GRID'S MULTIPLIER ROW SAYS CALLS -- see
         TContestBase.GetTotalsDisplay. *)
      function GetTotalsDisplay: TTotalsDisplay; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* THE BANDS AND THE MODE -- see the header and TContestBase.UsesBand,
         UsesMode, RunsInMode. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function RunsInMode(aMode: ModeType): boolean; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* THE NEW CONTEST DIALOG'S PROMPTS -- my name, and my state, province
         or DX country prefix. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange. *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   public
      (* THE MULTIPLIER -- the worked call, on the prefix sheet; no DX, zone
         or domestic multiplier. *)
      function HasPrefixMultiplier: boolean; override;
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      (* THE EXCHANGE CARRIES A STATE (or a DX prefix); the readiness check
         then asks for MY STATE. *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uAppStrings;      (* SNewContestEnterNameAndQTH, STotalsCallsignMults *)

(* "1 Point per QSO". The band and the mode were asked before this
   (ScoreQSO: UsesBand, UsesMode), so every QSO that reaches here scores 1. *)
procedure TContestWRT.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 1;
end;

(* "10, 15, 20, 40, and 80 Meter bands". *)
function TContestWRT.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

(* RTTY -- the UDC's Mode = RTTY and DXLog's MODES=RTTY. A Digital QSO with
   no submode, or a generic data one, is "some submode" and credited by
   DigitalSubmodeAllowed; every other digital submode, CW and phone are not. *)
function TContestWRT.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := (aMode = Digital) and
             DigitalSubmodeAllowed(aExtMode, RTTY_SUBMODES);
end;

function TContestWRT.RunsInMode(aMode: ModeType): boolean;
begin
   Result := aMode = Digital;
end;

function TContestWRT.GetDisplayName: string;
begin
   Result := 'Weekly RTTY Test';
end;

(* WHEN IT RUNS -- https://radiosport.world/wrt.html, read for issue 25
   (fetched 2026-11-15), General Rules: "Held every Thursday night,
   0145-0215Z (Friday UTC)". *)
function TContestWRT.GetSchedule: string;
begin
   Result := 'every Friday at 01:45 UTC for 30m';
end;

function TContestWRT.GetCabrilloName: string;
begin
   (* The organizers' UDC (CabrilloName = WRT) and DXLog.net's
      CABRILLO_CONTEST_NAME=WRT; the rules page states none. *)
   Result := 'WRT';
end;

function TContestWRT.GetADIFContestId: string;
begin
   (* ADIF has no id for it -- see the header. *)
   Result := WRT_CONTEST_ID;
end;

function TContestWRT.GetWA7BNMId: integer;
begin
   (* Not looked up: no WA7BNM reference was available on 2026-11-22. *)
   Result := 0;
end;

function TContestWRT.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestWRT.GetSubmissionEmail: string;
begin
   (* Results are reported on 3830scores.com -- see the header. *)
   Result := '';
end;

function TContestWRT.GetDomesticFileName: string;
begin
   (* No domestic file: the state is no multiplier -- see the header. *)
   Result := '';
end;

function TContestWRT.GetFriendlyName: string;
begin
   Result := 'Weekly RTTY Test';
end;

function TContestWRT.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameQTHInitialExchange;
end;

function TContestWRT.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestWRT.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNameQTH;
end;

function TContestWRT.ParseReceivedExchangeFormat(const aText: string;
                                                 aParsers: TExchangeParsers;
                                                 var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseNameAndDomesticOrDXQTH(aText, aExch);
end;

procedure TContestWRT.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteNameAndState;
end;

function TContestWRT.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestWRT.GetADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange): string;
begin
   Result := ADIFSentNameState(aMy, aQso);
end;

function TContestWRT.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentNameState(aMy, aQso, aCtx);
end;

function TContestWRT.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNameQTH(aMy, aQso, aCtx);
end;

function TContestWRT.GetFlags: TContestFlags;
begin
   (* QSOs once per band (NY4I, issue 25); the call multiplier once per
      session, so neither multiplier flag; Hamscore real-time scoring. *)
   Result := [cfQSOByBand, cfRTCCapable];
end;

function TContestWRT.GetIsUSQSOParty: boolean;
begin
   Result := False;
end;

(* THE TOTALS GRID'S MULTIPLIER ROW SAYS CALLS, NOT PREFIXES -- the key is
   the whole worked call (PrefixMultiplierKey). A LABEL ONLY, as the CW
   Open's. *)
function TContestWRT.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.PrefixMultsCaption := STotalsCallsignMults;
   Result.PrefixMultsCaptionCW := 'CW Calls';
   Result.PrefixMultsCaptionPhone := 'Ph Calls';
end;

procedure TContestWRT.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.Mode := Digital;
end;

(* MY NAME, THEN MY STATE -- which holds a W/VE entrant's state or province,
   or a DX entrant's country prefix: "W/VE - Name and State; DX - Name and
   Country Prefix". *)
procedure TContestWRT.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskField(ncfMyName);
   aPrompts.AskFieldWithComment(SNewContestEnterNameAndQTH, ncfMyState);
end;

(* THE NAME, THEN THE STATE OR COUNTRY PREFIX -- both as received; the
   caller collapses the whitespace. *)
function TContestWRT.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := Trim(string(aQso.Name)) + ' ' + Trim(string(aQso.QTHString));
end;

function TContestWRT.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* "Each unique call (once per session) is a multiplier": the worked call
   itself -- cut to the key's six characters, the KNOWN LIMIT in the
   header. *)
function TContestWRT.PrefixMultiplierKey(const aQso: ContestExchange;
                                         out aKey: PrefixMultiplierString): boolean;
begin
   aKey := aQso.Callsign;
   Result := True;
end;

function TContestWRT.HasDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestWRT.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

initialization
   RegisterContestById(WRT_CONTEST_ID, TContestWRT);

end.
