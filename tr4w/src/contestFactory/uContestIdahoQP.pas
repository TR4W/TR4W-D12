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

(* IDAHO QSO PARTY -- "The Spud Run", sponsored by the Magic Valley Amateur
  Radio Club, Twin Falls. Second full weekend of March.

  A NEW ContestType, NOT A MOVED ONE (2026-10-01). Until today there was no
  Idaho contest in TR4W at all: target\dom\Idaho QSO Party.cfg said
  CONTEST = NEQP and overrode NEQP's settings line by line -- including
  QSO POINT METHOD = ONE PHONE TWO CW, which the rotated QSOPointMethodArray
  turns into TwoPhoneFourCW, doubling every claimed score
  (CONTEST_OWNERSHIP_DESIGN.md section 7.2). NY4I: "The only contest that
  should say CONTEST = NEQP is the NEQP." So Idaho is IDAHOQSOPARTY, this
  class owns its rules, and the .cfg names it and overrides nothing.

  WRITTEN FROM THE NEW YORK CLASS'S SHAPE, AND OWNED (ownership design 1.4).
  Nothing here is shared with another party except the state-party base.

  ---------------------------------------------------------------------------
  SOURCES, read 2026-10-01

    the sponsor's rules   https://www.idahoqsoparty.org/rules.htm
    the county list       https://www.idahoqsoparty.org/MAPcountylist.htm
    the Cabrillo page     https://www.idahoqsoparty.org/cabrillo.htm
    WA7BNM, ref=305       https://www.contestcalendar.com/contestdetails.php?ref=305
    ADIF 3.1.7 Contest_ID https://adif.org.uk/317/ADIF_317.htm#Contest_ID
    NY4I, 2026-10-01      the points and the county-line maximum (below)

  ---------------------------------------------------------------------------
  WHAT EACH SOURCE SAYS, AND WHERE IT LANDED

  QSO POINTS -- NY4I: "1 point phone, 2 points CW or digital." The sponsor
    agrees: "Each phone QSO counts as one point. Each CW and Digital QSO counts
    as two points." CalculateQSOPoints. FM is phone (see the routine).

    NOT IMPLEMENTED, AND ON PURPOSE: the sponsor's next line, "ALL QRP QSO's
    count 5 points. voice, CW, digital." It does not say whose power is QRP --
    the entrant's category or the worked station's -- and the class is handed
    neither. A question for NY4I, not a guess.

  COUNTY LINE -- NY4I: "ID QP allows up to 2 counties on a county line." The
    sponsor agrees: "Idaho stations on a county line may be claimed as a QSO
    and a multiplier from each county (2 QSO's and 2 multipliers)."
    GetCountyLineCountiesMax = 2.

  EXCHANGE -- sponsor: Idaho stations send their three-letter county; W/VE
    (including KH6/KL7) send state or province; DX send "DXCC prefix/country".
    "the RST is no longer part of the contest ... 59 is perfect, you are not
    scored on RST reports", and the sponsor's own Cabrillo examples carry it.
    So RSTDomesticOrDXQTHExchange -- RST plus a domestic QTH or a DX one --
    which is what the .cfg selected and what NEQP's row already said.

  MULTIPLIERS -- sponsor:
    "For Idaho stations, count each US state (including Idaho), Canada
     province, and DXCC country as 'a' (one) multiplier ... once per mode,
     regardless of the number of bands."
    "For non-Idaho stations: Idaho counties are multipliers ... counted once
     per mode, regardless of the number of bands."
    So DomesticFile, through this party's P index: idaho.dom in state (the 50
    states, the provinces, and the 44 counties each mapped to ID) and
    idaho_cty.dom out of state (the 44 counties, each its own multiplier --
    FCONTEST sets MultipliersIsCounties). DX: ARRLDXCCWithNoUSAOrCanada, the
    value Florida and Arizona state for the same rule; an out-of-state entrant
    works only Idaho stations, so it never meets a DX multiplier.
    Once per mode across bands is ContestsBooleanArray's MB0 MM1, as the .cfg
    had it.

    THE DX MULTIPLIER IS A CHANGE. Under CONTEST = NEQP the row said
    NoDXMults and the .cfg did not override it, so an Idaho station's DX
    countries counted nothing. The sponsor rule is unambiguous.

  DUPES -- sponsor: "Stations may be worked once per mode, per band (for
    mobiles in each new county)". ContestsBooleanArray's QB1 QM1.

  BANDS -- sponsor: "160 - 80 - 40 - 20 - 15 - 10 meters" (VHF0). WARC is
    excluded and NOTHING ENFORCES THAT: disabling WARC is a FoundContest arm,
    which would be a new contest-name test in shared code. It waits for the
    setup seam (DescribeSession, ownership design section 4).

  NAMES -- ADIF 3.1.7 lists "ID-QSO-PARTY -- Idaho QSO Party"; WA7BNM's
    Cabrillo name is ID-QSO-PARTY (aliases IDQP, IDAHO-QSO-PARTY), and the
    sponsor's own Cabrillo example says CONTEST: ID-QSO-PARTY. Logs are
    uploaded at https://idqp.contesting.com; there is no e-mail address.

  NOT HERE, BECAUSE NO SEAM EXISTS YET (ownership design section 5):
    the dormant-county activation bonus (500 / 1000 / 1500, in-state rovers
    and expeditions); WA7BNM's "5 bonus points each for working K7S, K7P, K7U
    or K7D", which the sponsor's rules page does not mention; and the final
    score, which the sponsor writes as "Multiply QSO x Mode multiplier x
    Mults" against WA7BNM's "(total QSO points x total mults) + bonus points".
    TR4W computes points times multipliers, as for every state party.

  ---------------------------------------------------------------------------
  NO FORMER ADIF ID, AND THAT IS A DECISION. Every Idaho log TR4W ever wrote
  was exported as NEQP -- its CONTEST_ID was NEQP's enum spelling, because
  NEQP's ADIFName is blank. Claiming 'NEQP' here would make every New England
  QSO Party file import as Idaho: NEQP's current id is blank and a blank
  matches nothing, so the former id would win. Those Idaho files cannot be
  told apart from NEQP's, and they stay NEQP.

  FormatsExchange STAYS FALSE. The Cabrillo and ADIF columns come from the
  shared RSTDomesticOrDXQTHExchange arms, as they did under NEQP; export moves
  into the class at M4.
 *)
unit uContestIdahoQP;

{$I tr4w.inc}

interface

uses
   VC, uContestStateQSOPartyBase;

type
   TContestIdahoQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES. Stated; the
         base makes it abstract so it is never an accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE. The row exists only because
         ContestsArray is array[ContestType] and the compiler demands one; it
         carries the same values, and Test_MovedRowValuesStillMatchTheArray
         holds the two together until the array goes (M10). *)
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

      (* Two -- NY4I and the sponsor, quoted in the header. *)
      function GetCountyLineCountiesMax: integer; override;
   public
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   end;

implementation

uses
   uContestRegistry;

function TContestIdahoQP.GetDisplayName: string;
begin
   Result := 'Idaho QSO Party';
end;

function TContestIdahoQP.GetHostState: string;
begin
   Result := 'ID';
end;

function TContestIdahoQP.GetCabrilloName: string;
begin
   (* WA7BNM's Cabrillo name and the sponsor's own example header. *)
   Result := 'ID-QSO-PARTY';
end;

function TContestIdahoQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's Contest_ID enumeration: "ID-QSO-PARTY -- Idaho QSO Party". *)
   Result := 'ID-QSO-PARTY';
end;

function TContestIdahoQP.GetWA7BNMId: integer;
begin
   Result := 305;
end;

function TContestIdahoQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestIdahoQP.GetSubmissionEmail: string;
begin
   (* None: logs are uploaded at https://idqp.contesting.com. *)
   Result := '';
end;

function TContestIdahoQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is an Idaho county, and then loads idaho.dom or
      idaho_cty.dom through this party's QSOParties entry. *)
   Result := 'idaho_cty';
end;

function TContestIdahoQP.GetFriendlyName: string;
begin
   Result := 'Idaho QSO Party';
end;

function TContestIdahoQP.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestIdahoQP.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestIdahoQP.GetDXMultiplierType: DXMultType;
begin
   (* "each US state (including Idaho), Canada province, and DXCC country" --
      the states and provinces are domestic; the countries are these. *)
   Result := ARRLDXCCWithNoUSAOrCanada;
end;

function TContestIdahoQP.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestIdahoQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestIdahoQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestIdahoQP.GetQSOPointMethod: QSOPointMethodType;
begin
   (* A DESCRIPTION IN THE LEGACY ENGINE'S VOCABULARY, NOT A CHOICE OF RULE.
      Nothing scores Idaho through it -- logstuff.CalculateQSOPoints hands a
      registered contest to its class and exits. It is the one existing value
      whose arm says the same thing as this class: phone and FM one, every
      other mode two. OnePhoneTwoCW would describe digital as one point, which
      is wrong for this contest. None of the ActiveQSOPointMethod readers
      outside that case tests for this value. It retires with the setting. *)
   Result := ARRLFieldDayQSOPointMethod;
end;

function TContestIdahoQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* ONE POINT PHONE, TWO POINTS CW OR DIGITAL -- NY4I and the sponsor agree.

   OWN BODY, NOT FixedModePoints. That helper files FM with "everything else",
   which here is digital, so FM would score two; FM is a phone mode, and the
   sponsor counts "Each phone QSO" as one. This is the Field Day shape
   (ownership design 1.5: a rule that does not fit three numbers gets its own
   body).

   Both and NoMode are not modes a contact is made in, so they score nothing
   rather than inheriting either number. *)
procedure TContestIdahoQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 2;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

initialization
   RegisterContest(IDAHOQSOPARTY, TContestIdahoQP);

end.
