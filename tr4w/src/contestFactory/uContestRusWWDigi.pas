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

(* THE RUSSIAN WW DIGITAL CONTEST (RUS-WW-DIGI) -- added 2026-11-22, issue
  #93 (factory question Q137).

  THE SOURCE. The sponsor's (Russian Digital Radio Club, RDRC) rules as NY4I
  supplied them, docs/ContestRules/RUS-WW-DIGI/rules-rus-ww-digi.txt (the
  12th-14th runnings, 2025-2027). The older UA9QCQ copy,
  docs/ContestRules/RussianDigital/rules.md, is SUPERSEDED and is quoted
  below only where the current text is silent, and says so. DXLog.net's
  definition (Contest\RUS_WW_DIGI.txt, "Updated 2026-07-31") is a
  cross-check, never the source. Nothing here comes from D7, which never had
  this contest.

  A NEW CONTEST, SO IT REGISTERS BY ITS ID (Q108 S3/S4): no ContestType
  member, no legacy number, no VC.pas entry. Its id 'RUS-WW-DIGI' is STORED
  DATA from today and is never given to another contest.

  THE CONTEST, rule by rule, and where each lives:
    * schedule -- "annually to first week-end of October ... from 12.00 UTC
      on Saturday ... till 11:59 UTC on Sunday"; the three listed runnings
      (04.10.2025, 03.10.2026, 02.10.2027) are each the 1st Saturday of
      October: GetSchedule. The 2027 line's end, "11:59 UTC 02.10.2027", is
      the sponsor's typo for 03.10 (reported).
    * modes -- "Types of modulation: RTTY45, BPSK63": UsesMode credits RTTY
      (and reverse RTTY) and PSK63, plus the "some submode" values; any other
      digital submode, CW or phone is an automatic X-QSO. RunsInMode Digital;
      DescribeSession starts the session in Digital.
    * bands -- "Bands: 160 m, 80 m, 40 m, 20 m, 15 m, 10 m": UsesBand.
    * exchange -- "Participants from Russia, and also the foreign
      radioamateurs who are being in territory of Russia, should send
      RS,RST(Q) plus 2-letter abbreviation of Russian Area (oblast) Code
      (example for Moscow region - 599 MA) ... Participants from other
      countries ... should send RS,RST(Q) plus QSO number, starting 001
      (example - 599 001)." The engine's RST + domestic-QTH-or-serial format,
      the one the Russian DX Contest uses; the oblast is looked up in
      russian.dom.
    * what I send -- a Russian station RST + MY STATE (its oblast), anybody
      else RST + serial: DescribeSession clears the sent state for an entrant
      whose country is not Russian, and the StateOrQSONumber helpers write
      the serial when no state is sent.
    * points -- "Each contact between stations on 20, 15 and 10 m is worth:
      inside the country - 1 point; with other country - 3 points; with
      other continents - 5 points; with QRP-stations - 5 points. The points
      on 160, 80 and 40 m are doubled." CalculateQSOPoints. "Country" is the
      CTY.DAT (DXCC) entity, so European Russia working Asiatic Russia is
      another country AND another continent: 5 (DXLog scores it the same --
      an open question for the owner). A QRP station is known by its call:
      "SOQRP - is necessary to indicate in your call /QRP"; it scores 5 even
      inside the country, doubled on the low bands (the superseded text says
      "10 points ... per QSO with QRP-station on 160, 80 and 40 m").
    * multipliers -- "The multiplier are the countries according to the list
      of DXCC and Russian areas on each mode and each band." The DX
      multiplier is every CTY country on the DXCC (ARRL) list, Russia's own
      entities included (cfCountsDomesticCountries); the oblast is the
      domestic multiplier from russian.dom. cfMultByBand, cfMultByMode.
    * score -- "the total points multiplied by the sum of multipliers": the
      base's CombineWithMultipliers.
    * dupes -- "The repeated contacts are permitted on different bands and
      different modes": cfQSOByBand, cfQSOByMode.
    * logs -- Cabrillo, CONTEST: RUS-WW-DIGI (every header example). The
      current text names no address; logs go to the sponsor's robot. The
      superseded text's "RTTY - RY, BPSK63 - PM" mode column is kept
      (CabrilloModeString) -- the current text is silent and DXLog writes
      the same.

  NOT BUILT, REPORTED:
    * RTTY AND BPSK63 ARE ONE MODE TO THE SHEETS. Both are ModeType Digital,
      and the dupe and multiplier sheets have one digital slot (the
      Mississippi QSO Party's finding: uSortedStringList.DupeSlot,
      TDupesArray -- not re-measured here), so a second
      QSO with the same station on the same band in the other submode is a
      dupe, and earns no second multiplier, though the rules allow both.
    * "not earlier than in 3 minutes" between repeats; "no more than 10"
      band changes an hour; LOCATION: (an RDA code in the examples) in the
      Cabrillo header; CATEGORY-OVERLAY: JUNIOR and CATEGORY-MODE: BPSK.
    * the oblast list: the rules point at an appendix the supplied text does
      not hold. russian.dom is the Russian DX Contest's list (89 subjects plus
      DO, HE, LU, ZP, with FJ and AN); it is NOT checked against RDRC's own.
    * a /MM station: the rules are silent; DXLog gives it no DXCC
      multiplier. Not built.
    * CE9 IS NOT A DOMESTIC COUNTRY here, unlike the Russian DX Contest (its
      rule 7.3): the few exact RI1ANx calls CTY.DAT files under Antarctica
      are treated as non-Russian stations (no oblast pre-fill; scored by
      their own entity).

  NO ADIF CONTEST_ID was found for it (the vendored validator lists none), so
  export writes the contest's own id, as a by-id contest does, and import
  matches it. *)
unit uContestRusWWDigi;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

const
   (* ITS ID -- stored data; see the header. *)
   RUS_WW_DIGI_CONTEST_ID = 'RUS-WW-DIGI';

type
   TContestRusWWDigi = class(TContestBase)
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
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* IS THE WORKED STATION QRP? -- its call ends /QRP (see the header).
         Public for the tests; nothing else needs it. *)
      class function CallIsQRP(const aCall: string): boolean;
   public
      (* THE BANDS AND THE MODES -- see the header and TContestBase.UsesBand,
         UsesMode, RunsInMode. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      function RunsInMode(aMode: ModeType): boolean; override;
      (* THE CABRILLO MODE COLUMN -- RY for RTTY, PM for BPSK63. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;
      (* A RUSSIAN STATION'S OBLAST, from its call -- the one rule (Q50),
         uCallSignRoutines.RussianStationOblast. *)
      function InitialExchangeFromCall(const aCall: string;
                                       const aCountryID: string;
                                       out aExchange: string): boolean; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* THE NEW CONTEST DIALOG'S PROMPTS -- a Russian station's oblast. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
      function DescribeNewContestHome(out aHome: TNewContestHome): boolean; override;
   public
      (* THE MULTIPLIERS -- the DXCC country and the oblast; no zone or
         prefix multiplier. *)
      function UsesDomesticFile: boolean; override;
      function HasDXMultiplier: boolean; override;
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      function CountryMode: CountryModeType; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      (* THE EXCHANGE CARRIES A DOMESTIC QTH -- a Russian station's oblast. *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   public
      (* AN RTTY CONTEST SENDS 599 -- see
         TContestBase.DefaultSignalReport. *)
      function DefaultSignalReport: string; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   (* RussianID, RussianStationOblast. *)
   uCallSignRoutines,
   uTR4WStrings;

(* "SOQRP - is necessary to indicate in your call /QRP". The call as logged,
   read upper case and trimmed. *)
class function TContestRusWWDigi.CallIsQRP(const aCall: string): boolean;
var
   call: string;
   n: integer;
begin
   call := Trim(aCall);
   n := Length(call);
   Result := (n > 4)                                       and
             (call[n - 3] = '/')                           and
             ((call[n - 2] = 'Q') or (call[n - 2] = 'q')) and
             ((call[n - 1] = 'R') or (call[n - 1] = 'r')) and
             ((call[n] = 'P') or (call[n] = 'p'));
end;

(* THE POINTS -- see the header. A QRP station 5; else the same CTY country
   1; else the same continent 3; else 5. Doubled on 160, 80 and 40 m. With
   no country of my own known, nothing is "inside the country".

   THE BAND IS ALWAYS ONE OF THE SIX: ScoreQSO never asks about another
   (UsesBand). *)
procedure TContestRusWWDigi.CalculateQSOPoints(var aQso: ContestExchange);
var
   points: integer;
   myCountry: string;
   rxCountry: string;
begin
   myCountry := string(Station.MyCountry);
   rxCountry := string(aQso.QTH.CountryID);

   if CallIsQRP(string(aQso.Callsign)) then
      begin
      points := 5;
      end
   else if (myCountry <> '') and (rxCountry = myCountry) then
      begin
      points := 1;
      end
   else if aQso.QTH.Continent = Station.MyContinent then
      begin
      points := 3;
      end
   else
      begin
      points := 5;
      end;

   if aQso.Band in [Band160, Band80, Band40] then
      begin
      points := points * 2;
      end;

   aQso.QSOPoints := points;
end;

function TContestRusWWDigi.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

(* "Types of modulation: RTTY45, BPSK63." A digital QSO with no submode, or a
   generic data one, is "some submode" and credited (DigitalSubmodeAllowed). *)
function TContestRusWWDigi.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := (aMode = Digital) and
             DigitalSubmodeAllowed(aExtMode, RTTY_SUBMODES + [ePSK63]);
end;

function TContestRusWWDigi.RunsInMode(aMode: ModeType): boolean;
begin
   Result := aMode = Digital;
end;

(* The superseded rules: "Modes in Cabrillo file must be identified as
   follows: RTTY - RY, BPSK63 - PM" (DXLog: CABRILLO_MODES=RY;PM). The base
   writes DG for PSK63 and for reverse RTTY. Anything else is the base's. *)
function TContestRusWWDigi.CabrilloModeString(aMode: ModeType;
                                              aExtMode: ExtendedModeType): string;
begin
   if (aMode = Digital) and (aExtMode = ePSK63) then
      begin
      Result := 'PM';
      end
   else if (aMode = Digital) and (aExtMode in RTTY_SUBMODES) then
      begin
      Result := 'RY';
      end
   else
      begin
      Result := inherited CabrilloModeString(aMode, aExtMode);
      end;
end;

function TContestRusWWDigi.InitialExchangeFromCall(const aCall: string;
                                                   const aCountryID: string;
                                                   out aExchange: string): boolean;
begin
   Result := RussianID(aCountryID);
   aExchange := RussianStationOblast(aCall, aCountryID);
end;

function TContestRusWWDigi.GetDisplayName: string;
begin
   Result := 'Russian WW Digital Contest';
end;

(* WHEN IT RUNS -- docs/ContestRules/RUS-WW-DIGI/rules-rus-ww-digi.txt
   (2025-2027): "first week-end of October", 12:00 UTC Saturday to 11:59 UTC
   Sunday. 04.10.2025, 03.10.2026 and 02.10.2027 are each the 1st Saturday
   of October. *)
function TContestRusWWDigi.GetSchedule: string;
begin
   Result := '1st Saturday of October at 12:00 UTC for 24h';
end;

function TContestRusWWDigi.GetCabrilloName: string;
begin
   (* Every Cabrillo header example in the rules: CONTEST: RUS-WW-DIGI. *)
   Result := 'RUS-WW-DIGI';
end;

function TContestRusWWDigi.GetADIFContestId: string;
begin
   (* No ADIF id was found -- see the header. *)
   Result := RUS_WW_DIGI_CONTEST_ID;
end;

function TContestRusWWDigi.GetWA7BNMId: integer;
begin
   (* Not looked up. *)
   Result := 0;
end;

function TContestRusWWDigi.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestRusWWDigi.GetSubmissionEmail: string;
begin
   (* The current text names no address ("All logs must be sent no later
      than 5 days after the contest"). The superseded text offered the
      ua9qcq web form or rusww@rdrclub.ru; not stated until the owner
      confirms it. *)
   Result := '';
end;

function TContestRusWWDigi.GetDomesticFileName: string;
begin
   Result := 'russian';
end;

function TContestRusWWDigi.GetFriendlyName: string;
begin
   Result := 'Russian WW Digital Contest';
end;

function TContestRusWWDigi.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestRusWWDigi.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticQTHOrQSONumberExchange;
end;

function TContestRusWWDigi.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestRusWWDigi.ParseReceivedExchangeFormat(const aText: string;
                                                       aParsers: TExchangeParsers;
                                                       var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticQTHOrQSONumber(aText, aExch);
end;

function TContestRusWWDigi.DefaultSignalReport: string;
begin
   Result := RTTY_DEFAULT_REPORT;
end;

procedure TContestRusWWDigi.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTStateOrQSONumber;
end;

function TContestRusWWDigi.GetADIFSentExchange(const aMy: TMyStationExchange;
                                               const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrQSONumber(aMy, aQso);
end;

function TContestRusWWDigi.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrQSONumber(aMy, aQso, aCtx);
end;

function TContestRusWWDigi.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQTHOrQSONumber(aMy, aQso, aCtx);
end;

function TContestRusWWDigi.GetFlags: TContestFlags;
begin
   (* QSOs and multipliers per band and per mode; a Russian DXCC entity
      counts as a DX multiplier too (see the header). *)
   Result := [cfQSOByBand,
              cfQSOByMode,
              cfMultByBand,
              cfMultByMode,
              cfCountsDomesticCountries];
end;

function TContestRusWWDigi.GetIsUSQSOParty: boolean;
begin
   Result := False;
end;

(* A Russian station sends its oblast; anybody else a serial, so its sent
   state is cleared. The domestic countries are Russia's CTY entities. *)
procedure TContestRusWWDigi.DescribeSession(const aStation: TStationContext;
                                            aSession: TSessionDefaults);
begin
   aSession.Mode := Digital;
   aSession.AddDomesticCountries(DomesticCountriesRussia);
   if not RussianID(string(aStation.MyCountry)) then
      begin
      aSession.SentState := '';
      end;
end;

procedure TContestRusWWDigi.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_RUSSIA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOUROBLASTID, ncfMyState);
end;

(* THE BOX'S REGION IS THE DOMESTIC COUNTRIES DescribeSession states --
   issue 167. *)
function TContestRusWWDigi.DescribeNewContestHome(out aHome: TNewContestHome): boolean;
begin
   Result := HomeIsDomesticCountries(aHome);
end;

function TContestRusWWDigi.UsesDomesticFile: boolean;
begin
   Result := True;
end;

function TContestRusWWDigi.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* EVERY DXCC COUNTRY IS A MULTIPLIER, Russia's own included: the key is the
   CTY country on the DXCC list (CountryMode). *)
function TContestRusWWDigi.DXMultiplierKey(const aQso: ContestExchange;
                                           out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;

(* "the countries according to the list of DXCC" -- the ARRL list, not
   CTY.DAT's DXCC + WAE list (DXLog: DXCC_DB_USE_ARRL_LIST=YES). *)
function TContestRusWWDigi.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;

function TContestRusWWDigi.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestRusWWDigi.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestRusWWDigi.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

initialization
   RegisterContestById(RUS_WW_DIGI_CONTEST_ID, TContestRusWWDigi);

end.
