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

(* KVP.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: EUHFCYear;  AIE: noInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;  XM: NoDXMults;
   QP: OnePhoneTwoCW;  ADIFName: '';  CABName: '';  FriendlyName: ''

  SCORING IS OnePhoneTwoCW, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree):

      if RXData.Mode = CW then 2 else 1

  so the whole rule is FixedModePoints(Mode, 2, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  FCONTEST had an arm for this contest:
      ActiveBand := Band80, with three lines commented out beside it
      (a ZoneInitialExchange, a BranchZones zone mult, and the contest
      name 'KV Prvenstvo ZRS').
  uNewContest asks the operator for the last two digits of the year,
  into the MY ZONE field. Both are contest SETUP, not scoring; the arm is
  DescribeSession since M7a, and the prompt moves at M9.

  FLAGGED, NOT CHANGED: THE ZONE MULTIPLIER IS EUHFCYear -- the European
  HF Championship's "year licensed" multiplier -- while FCONTEST's
  commented-out line names BranchZones. Which one KVP's rules actually
  want has not been checked against the sponsor; the row's value is
  transcribed exactly. Since M11 S5 the rule is this class's own --
  ZoneMultiplierCount (100) and NumbersZonesFromZero (True), which LOGDUPE
  and LOGEDIT read from the session's zone kind until then; LOGSTUFF's
  EUHFCYear range test was vacuous here (ITU zone mode) and was deleted.

  NOT A STATE QSO PARTY: P is 0 and it has no other family, so it
  sits on TContestBase directly and states its own points, calling
  FixedModePoints as a helper (TContestFixedPoints retired at M3).

  BLANK CABName, FriendlyName AND ADIFName ALL MEAN "THE ENUM'S SPELLING";
  the getters below state the value each resolves to, never the empty
  string. ADIFName joined the other two at M1 (2026-10-01): a blank one
  was always exported as the enum's spelling, and the id is now what
  export writes, so import matches it.

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE CLASS'S, THROUGH HELPERS
  (M11 S9b, S9c): the contest has no export rule of its own, so it states its
  ADIF STX_STRING and its two Cabrillo columns by calling the named helpers
  its exchange uses (uADIFExchange, uCabrilloExchange). *)
unit uContestKVP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestKVP = class(TContestBase)
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
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
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
      (* DOES IT HAVE A ZONE MULTIPLIER? -- see
         TContestBase.HasZoneMultiplier (M11 S5 part 2). *)
      function HasZoneMultiplier: boolean; override;
      (* THE ZONE MULTIPLIER -- see TContestBase.ZoneMultiplierCount and
         NumbersZonesFromZero (M11 S5). Its zones are not CQ or ITU zones, so
         ZoneMultiplierZones is the base's. *)
      function ZoneMultiplierCount: integer; override;
      function NumbersZonesFromZero: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesZone: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestKVP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

function TContestKVP.GetDisplayName: string;
begin
   Result := 'KVP';
end;

function TContestKVP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'KVP';
end;

function TContestKVP.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'KVP';
end;

function TContestKVP.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestKVP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestKVP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestKVP.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestKVP.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's
      spelling it resolves to. *)
   Result := 'KVP';
end;

function TContestKVP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestKVP.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestKVP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZone;
end;

function TContestKVP.ParseReceivedExchangeFormat(const aText: string;
                                                 aParsers: TExchangeParsers;
                                                 var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTZone(aText, aExch);
end;

procedure TContestKVP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTZone(SendsStateAfterZone);
end;

function TContestKVP.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestKVP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZone(aMy, aQso);
end;

function TContestKVP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTZone(aMy, aQso, aCtx);
end;

function TContestKVP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTZone(aMy, aQso, aCtx);
end;

function TContestKVP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByMode, cfMultByBand, cfMultByMode];
end;

function TContestKVP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestKVP.DescribeSession(const aStation: TStationContext;
                                      aSession: TSessionDefaults);
begin
   aSession.Band := Band80;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for EUROPEANHFC.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestKVP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, ncfMyZone);
end;

(* THE ZONE MULTIPLIER -- M11 S5, 2026-10-14: the year licensed, 00 to 99 --
   a hundred zones, numbered from zero. What the trait's EUHFCYear gave
   LOGDUPE's zone count and LOGEDIT's remaining-mults list through the
   session kind until S5. *)
function TContestKVP.ZoneMultiplierCount: integer;
begin
   Result := 100;
end;

(* IT HAS A ZONE MULTIPLIER, AT EVERY STATION -- M11 S5 part 2,
   2026-10-14: the answer the session kind gave (`kind <> NoZoneMults`)
   before the kind was deleted. *)
function TContestKVP.HasZoneMultiplier: boolean;
begin
   Result := True;
end;

function TContestKVP.NumbersZonesFromZero: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(KVP, TContestKVP);

end.
