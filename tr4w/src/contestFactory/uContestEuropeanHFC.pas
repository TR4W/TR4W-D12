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

(* EUROPEAN HF CHAMPIONSHIP -- EUROPEAN HFC.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 82;  QRZRUID: 31;
   Pxm: NoPrefixMults;  ZnM: EUHFCYear;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTZoneExchange;  XM: NoDXMults;
   QP: OnePointPerQSO;  ADIFName: 'EU-HF';  CABName: '';
   FriendlyName: 'European HF Championship'

  SCORING IS OnePointPerQSO, an arm of the legacy LOGSTUFF scoring
  case (deleted at M10 S3; see git history or the D7 tree):

      RXData.QSOPoints := 1;

  so the whole rule is FixedModePoints(Mode, 1, 1, 1) -- CW, phone, everything
  else. Digital scores the phone value, as the legacy arm does.

  uNewContest asks the operator for the last two digits of the year,
  into the MY ZONE field -- operator SETUP, and it stays there. LOGCFG
  carries a CQ-exchange line naming this contest, and it is COMMENTED
  OUT; nothing is read from it. FCONTEST has no arm for it.

  THE LICENCE YEAR IS ITS OWN EXCHANGE FIELD, STORED IN THE ZONE SLOT
  (2026-11-11). Rules 5 and 6 (docs/ContestRules/euhfc_rules_latest.md): RS
  on SSB / RST on CW plus the two-digit year of the operator's first-ever
  licence, 00..99; the multipliers are the different two-digit values, once
  per band regardless of mode (GetFlags: cfMultByBand, no cfMultByMode).
    - PARSE: aParsers.ParseRSTLicenceYear (LOGSTUFF's
      ProcessRSTAndLicenceYearExchange), the zone parser's word shapes with
      no zone rule. Until 2026-11-11 the year went through ParseRSTZone and
      was accepted only because FoundContest set ITU zone mode here (no
      cfCQZoneMode), so the 40-CQ-zone limit never ran; it no longer asks the
      zone mode at all.
    - STORAGE: ContestExchange.Zone (rcvd_zone) and ZoneMult (mult_zone),
      through uContestBase.LicenceYearOf / StoreLicenceYear -- the encoding
      is the contract; no column, stored value or export byte changed.
      SINCE ISSUE 298 the year is a field of its own (RcvdYear, rcvd_year);
      stage 2 (2026-11-12) gave the class its stated kind,
      GetReceivedYearKind = rykTwoDigitYear, and the readers read the field.
      StoreLicenceYear still writes the zone slot for the multiplier sheet.
      Stage 3 (2026-11-12) moved display and export to the field: the
      received Cabrillo column is CabrilloReceivedRSTYear, and the grid,
      Edit QSO, SRX_STRING, the canonical exchange, the totals row and the
      column heading follow the stated kind from the base.
    - MULTIPLIER: the zone sheet, a hundred "zones" numbered from zero
      (ZoneMultiplierCount 100, NumbersZonesFromZero, HasZoneMultiplier);
      ZoneMultiplierZones is the base's zmzNotCQOrITU, so the hint never
      offers a CTY zone and ADIF writes no CQZ/ITUZ tag.
    - SENT: MY LICENSE YEAR holds the operator's year (the New Contest
      prompt; issue 298 -- it was MY ZONE until then), read through the
      stated kind: two digits (TContestBase.SentZoneText).
  A field and a multiplier kind of its own would be a schema change (a
  column, or the 376-byte record the wire and server log carry) -- not taken.
  The ITU zone mode stays: it is what CTY.DAT gives a logged call, and
  changing it would change the stored cty zone of new rows.

  THE ADIF ID WAS BLANK UNTIL 2026-09-29 AND IS NOW 'EU-HF', the ADIF 3.1.7
  Contest_ID enumeration's spelling (EU HF Championship), on NY4I's ruling.
  While it was blank, ADIF export fell back to the enum's spelling, so every
  file exported before the change carries CONTEST_ID 'EUROPEAN HFC'. That is
  this contest's former id, and import accepts it: "Yes support old
  spellings."

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
unit uContestEuropeanHFC;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestEuropeanHFC = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFormerADIFContestIds: TContestIdList; override;
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
      (* THE YEAR, NOT A ZONE, ON SCREEN AND ON THE AIR -- from the stated
         kind since issue 298: the totals row, the log column's heading, and
         the year it SENDS (MY LICENSE YEAR, TContestBase.SentZoneText) all
         follow ReceivedYearKind, so none is stated here. *)
      (* THE YEAR IT RECEIVES IS TWO DIGITS, 00..99 -- rule 5 (issue 298,
         stage 2). See TContestBase.ReceivedYearKind: the parser's range, the
         ADIF import and Edit QSO follow from it. *)
      function GetReceivedYearKind: TReceivedYearKind; override;
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
      (* THE YEAR A CALL IMPLIES -- issue 70; see the body and
         TContestBase.ZoneMultiplierFromCall. *)
      function ZoneMultiplierFromCall(const aCall: string;
                                      const aLookups: TMultiplierHintLookups;
                                      out aZone: integer): boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesZone: boolean; override;
   end;

implementation

uses
   SysUtils,         (* Trim -- ZoneMultiplierFromCall *)
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry, uContestFixedPoints,
   uTR4WStrings,
   uAppStrings;      (* SNewContestLicenseYearLabel *)

procedure TContestEuropeanHFC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestEuropeanHFC.GetReceivedYearKind: TReceivedYearKind;
begin
   Result := rykTwoDigitYear;
end;

function TContestEuropeanHFC.GetDisplayName: string;
begin
   Result := 'European HF Championship';
end;

function TContestEuropeanHFC.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'EUROPEAN HFC';
end;

function TContestEuropeanHFC.GetADIFContestId: string;
begin
   Result := 'EU-HF';
end;

function TContestEuropeanHFC.GetFormerADIFContestIds: TContestIdList;
begin
   (* What ADIF export wrote while the row's ADIFName was blank: the enum's
      spelling. See the unit header. *)
   Result := ContestIdList(['EUROPEAN HFC']);
end;

function TContestEuropeanHFC.GetWA7BNMId: integer;
begin
   Result := 82;
end;

function TContestEuropeanHFC.GetQRZRUId: integer;
begin
   Result := 31;
end;

function TContestEuropeanHFC.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestEuropeanHFC.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestEuropeanHFC.GetFriendlyName: string;
begin
   Result := 'European HF Championship';
end;

function TContestEuropeanHFC.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestEuropeanHFC.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneExchange;
end;

function TContestEuropeanHFC.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTZone;
end;

(* RS(T) AND THE LICENCE YEAR, 00..99 -- rule 5. Its own parser since
   2026-11-11, not the zone parser: see the unit header. *)
function TContestEuropeanHFC.ParseReceivedExchangeFormat(const aText: string;
                                                         aParsers: TExchangeParsers;
                                                         var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTLicenceYear(aText, ReceivedYearKind, aExch);
end;

procedure TContestEuropeanHFC.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTZone(SendsStateAfterZone);
end;

function TContestEuropeanHFC.ExchangeCarriesZone: boolean;
begin
   Result := True;
end;

function TContestEuropeanHFC.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTZone(aMy, aQso);
end;

function TContestEuropeanHFC.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTZone(aMy, aQso, aCtx);
end;

function TContestEuropeanHFC.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   (* THE YEAR FROM ITS FIELD (issue 298 stage 3), in the seven columns the
      zone helper printed it in: two digits, byte for byte as before. *)
   Result := CabrilloReceivedRSTYear(ReceivedYearKind, aMy, aQso, aCtx);
end;

function TContestEuropeanHFC.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestEuropeanHFC.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for KVP.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestEuropeanHFC.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   (* The year is MY LICENSE YEAR (issue 298); the row reads "License year". *)
   aPrompts.AskFieldWithCommentAndLabel(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, ncfMyLicenseYear,
                                        SNewContestLicenseYearLabel);
end;

(* THE ZONE MULTIPLIER -- M11 S5, 2026-10-14: the year licensed, 00 to 99 --
   a hundred zones, numbered from zero. What the trait's EUHFCYear gave
   LOGDUPE's zone count and LOGEDIT's remaining-mults list through the
   session kind until S5. *)
function TContestEuropeanHFC.ZoneMultiplierCount: integer;
begin
   Result := 100;
end;

(* IT HAS A ZONE MULTIPLIER, AT EVERY STATION -- M11 S5 part 2,
   2026-10-14: the answer the session kind gave (`kind <> NoZoneMults`)
   before the kind was deleted. *)
function TContestEuropeanHFC.HasZoneMultiplier: boolean;
begin
   Result := True;
end;

function TContestEuropeanHFC.NumbersZonesFromZero: boolean;
begin
   Result := True;
end;

(* THE YEAR LICENSED THE PROGRAM REMEMBERS FOR A CALL -- issue 70 (HB9RB:
   "Allow initial_ex to contain mult, say YEAR in EUHFC, when spotted ... should
   trigger id as mult"). The remembered exchange is INITIAL.EX's text, a call
   history file's, or the last logged QSO's (LOGDUPE's
   GetInitialExchangeStringFromContestExchange writes the zone field, the
   year, as IntToStr -- so 05 is remembered as '5'). Its LAST word is read,
   so an INITIAL.EX line that also carries the RST ('599 85') still gives the
   year. One or two digits, 0 to 99; anything else -- no text, a name, a
   four-digit year -- is no opinion, never a guess. *)
function TContestEuropeanHFC.ZoneMultiplierFromCall(const aCall: string;
                                                    const aLookups: TMultiplierHintLookups;
                                                    out aZone: integer): boolean;
var
   remembered: string;
   first: integer;
   year: integer;
begin
   aZone := 0;
   Result := False;
   if not Assigned(aLookups.InitialExchangeOf) then
      begin
      Exit;
      end;
   remembered := Trim(aLookups.InitialExchangeOf(aCall));
   (* The last word: after the last blank, if any. *)
   first := Length(remembered) + 1;
   while (first > 1) and (remembered[first - 1] <> ' ') do
      begin
      Dec(first);
      end;
   (* A YEAR OF THIS CONTEST'S KIND -- the one word test the parser, Edit QSO
      and the import ask too (issue 298, stage 2; it was a digit loop of its
      own here). No QSO, so the ceiling is the latest year a QSO can carry,
      which a two-digit year never reaches. *)
   if not ReceivedYearFromWord(ReceivedYearKind,
                               Copy(remembered, first, Length(remembered) - first + 1),
                               LATEST_QSO_YEAR, year) then
      begin
      Exit;
      end;
   aZone := year;
   Result := True;
end;

initialization
   RegisterContest(EUROPEANHFC, TContestEuropeanHFC);

end.
