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

(* THE CWOPS CW OPEN.

  The ContestsArray row this class states, verbatim:

   Email: 'cwo@cwops.org';  DF: '';  WA7BNM: 532;  QRZRUID: 0;
   Pxm: CallSignPrefix;  ZnM: CQZones;  AIE: NameInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: QSONumberAndNameExchange;
   XM: NoDXMults;  QP: OnePointPerQSO;
   ADIFName: 'CWOPS-CW-OPEN';  CABName: 'CW-OPEN';
   FriendlyName: 'CWOps CW Open'

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: OnePointPerQSO -- 1 in every mode.

  NO ZONE MULTIPLIER, ON THE SPONSOR'S RULE (issue 277, 2026-11-11). The row
  above says `ZnM: CQZones`, and until this date the class counted the 40 CQ
  zones beside the callsign multiplier. The sponsor's current rules
  (cwops.org/cwops-tests/cw-open, read 2026-11-11) name one multiplier only:
  "For each session, each different call sign is a multiplier the first time
  it is worked in that session" and "the total number of multipliers in your
  log is the number of different call signs logged" -- zones are never
  mentioned. [DXLog CWOpen.txt] agrees: a single MULT1_TYPE=CALLSIGN. A
  definitive sponsor rule overrides D7, so the three zone overrides are
  deleted and the base answers no zone multiplier, as CWOPS and MST do. This
  also ends this contest's half of plan F5 / open question Q95 (CQ zones
  counted over an ITU zone mode): there is no zone list left to disagree.
  GetFlags' zone mode (ITU, no cfCQZoneMode) is unchanged.

  SET-UP: nothing in FoundContest. LogCfg's CQ exchange: the serial and
  MY NAME.

  NOT MOVED, ON PURPOSE: uExchangeBuilder's HamScore received exchange
  (serial and name) names it, beside registered contests -- a seam not
  built yet (M9), as All Asian's arm there was left at batch 1. *)
unit uContestCWOpen;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCWOpen = class(TContestBase)
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
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
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
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
   public
      (* DOES IT HAVE A PREFIX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasPrefixMultiplier (M11 S3 part 2). *)
      function HasPrefixMultiplier: boolean; override;
      (* THE PREFIX MULTIPLIER -- see TContestBase.PrefixMultiplierKey
         (M11 S3). *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; override;
      (* NO ZONE MULTIPLIER -- the base's HasZoneMultiplier (False),
         ZoneMultiplierCount (0) and ZoneMultiplierZones stand: see the
         header (issue 277, 2026-11-11). *)
   protected
      (* THE TOTALS GRID'S MULTIPLIER ROW SAYS CALLS -- see
         TContestBase.GetTotalsDisplay (issue 277). *)
      function GetTotalsDisplay: TTotalsDisplay; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uContestFixedPoints,
   uTR4WStrings,
   uAppStrings,
   SysUtils,
   uCanonicalExchange;

(* OnePointPerQSO -- the legacy LOGSTUFF arm for this
   contest's point method, moved here as it stood (M7b batch 2). The arm
   was deleted at M10 S3; see git history or the D7 tree. *)
procedure TContestCWOpen.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestCWOpen.GetDisplayName: string;
begin
   Result := 'CWOps CW Open';
end;

function TContestCWOpen.GetCabrilloName: string;
begin
   Result := 'CW-OPEN';
end;

function TContestCWOpen.GetADIFContestId: string;
begin
   Result := 'CWOPS-CW-OPEN';
end;

function TContestCWOpen.GetWA7BNMId: integer;
begin
   Result := 532;
end;

function TContestCWOpen.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCWOpen.GetSubmissionEmail: string;
begin
   Result := 'cwo@cwops.org';
end;

function TContestCWOpen.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestCWOpen.GetFriendlyName: string;
begin
   Result := 'CWOps CW Open';
end;

function TContestCWOpen.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NameInitialExchange;
end;

function TContestCWOpen.GetExchangeKind: ExchangeType;
begin
   Result := QSONumberAndNameExchange;
end;

function TContestCWOpen.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsQSONumberName;
end;

function TContestCWOpen.ParseReceivedExchangeFormat(const aText: string;
                                                    aParsers: TExchangeParsers;
                                                    var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseQSONumberAndName(aText, aExch);
end;

function TContestCWOpen.GetADIFSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange): string;
begin
   Result := ADIFSentQSONumberName(aMy, aQso);
end;

function TContestCWOpen.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentQSONumberName(aMy, aQso, aCtx);
end;

function TContestCWOpen.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange;
                                                    const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedQSONumberName(aMy, aQso, aCtx);
end;

function TContestCWOpen.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfRTCCapable];
end;

function TContestCWOpen.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (M7b batch 2). See TContestBase.CQExchangeDefault. *)
function TContestCWOpen.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyName;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for EUSPRINT_AUTUMN_CW,
   EUSPRINT_AUTUMN_SSB, EUSPRINT_SPRING_CW, EUSPRINT_SPRING_SSB, MST.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestCWOpen.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURNAME, ncfMyName);
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the serial and the name. See
   TContestBase.CanonicalReceivedExchange; the caller collapses the
   whitespace. *)
function TContestCWOpen.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := IntToStr(aQso.NumberReceived) + ' ' + Trim(string(aQso.Name));
end;

(* A PREFIX MULTIPLIER AT EVERY STATION -- M11 S3 part 2, 2026-10-14:
   the trait this class stated (`CallSignPrefix`) until the kind was deleted. *)
function TContestCWOpen.HasPrefixMultiplier: boolean;
begin
   Result := True;
end;

(* THE PREFIX MULTIPLIER KEY -- M11 S3, 2026-10-14, moved from
   LOGEDIT.SetPrefix.
   The worked callsign itself, cut to the field's six characters --
   SetPrefix's `CallSignPrefix` arm. *)
function TContestCWOpen.PrefixMultiplierKey(const aQso: ContestExchange;
                                            out aKey: PrefixMultiplierString): boolean;
begin
   aKey := aQso.Callsign;
   Result := True;
end;

(* THE TOTALS GRID'S MULTIPLIER ROW SAYS CALLS, NOT PREFIXES -- issue 277
   (2026-11-11). The sponsor (cwops.org/cwops-tests/cw-open, read 2026-11-11):
   "For each session, each different call sign is a multiplier the first time
   it is worked in that session" -- and PrefixMultiplierKey above is the whole
   worked callsign. A LABEL ONLY: no rule, count or score changes here. There
   is no Zones row: the contest has no zone multiplier (header, SCORING), and
   uTotal shows that row only where DoingZoneMults. *)
function TContestCWOpen.GetTotalsDisplay: TTotalsDisplay;
begin
   Result := inherited GetTotalsDisplay;
   Result.PrefixMultsCaption := STotalsCallsignMults;
   Result.PrefixMultsCaptionCW := 'CW Calls';
   Result.PrefixMultsCaptionPhone := 'Ph Calls';
end;

initialization
   RegisterContest(CWOPEN, TContestCWOpen);

end.
