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

  THE ZONE MULTIPLIER (the trait EUHFCYear, which KVP shares) is this
  class's own since M11 S5: ZoneMultiplierCount (100) and
  NumbersZonesFromZero (True), which LOGDUPE and LOGEDIT read from the
  session's zone kind until then. LOGSTUFF's EUHFCYear range test in the
  zone parse was vacuous -- two digits are always 0..99, and the CQ-zone
  limit it skipped never applies in this contest's ITU zone mode -- so it
  was deleted rather than moved; the matrix's "599 45" pins the parse.

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

  EXCHANGE PARSING IS NOT MOVED (M5). EXPORT IS THE BASE'S DEFAULT (M4):
  the contest has no export rule of its own, so TContestBase formats it
  through the shared arm for its exchange. *)
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

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
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
   end;

implementation

uses
   uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestEuropeanHFC.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
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
   aPrompts.AskFieldWithComment(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, ncfMyZone);
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

initialization
   RegisterContest(EUROPEANHFC, TContestEuropeanHFC);

end.
