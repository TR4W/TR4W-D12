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

(* THE CANADIAN PRAIRIES QSO PARTY -- a NEW contest, registered BY ID
  (2026-11-18, GitHub issue #117).

  ITS ID IS CP-QSO-PARTY AND IT IS STORED DATA FROM THE FIRST LOG MADE WITH
  IT: never give it to another contest. There is no ContestType member -- the
  enum is frozen -- so its UDP contest number is derived from its id.

  ON THE STATE-PARTY BASE, AND THE FIRST WHOSE HOST IS SEVERAL PROVINCES.
  The base's "host area" is "a key of the county file", which is exactly
  this contest's rule across Alberta, Saskatchewan and Manitoba: an entrant
  whose MY STATE is a district is in the area, everyone else is outside and
  works only prairie stations ("Contacts between non VE/VA 4, 5 and 6
  stations do not count"). What did not fit was the single two-letter
  HostState, so the base takes several (2026-11-18, the same commit):
  HostState is 'AB SK MB', cpqp_cty.dom maps each district to its province
  with '>', and the ADIF STATE of a district is that province (the base's
  ADIFCountyState through CountyFileHostState). Atlantic Canada (#116) will
  state 'NB NS PE NL' the same way. Its exchange row is Georgia's (A3): a DX
  entrant sends "DX". The rest of the skeleton is Louisiana's.

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor   docs/ContestRules/QSOParties/CanadianPrairies/ --
                  cpqp-rules.md, the rules page "Rules: 2025 Canadian
                  Prairies QSO Party", "Last Update: March 8, 2026"
                  (https://cpqp.ve6hams.ca/rules-2/, saved by NY4I
                  2026-11-18); canadian-prairies-districts.md, the
                  "Federal Electoral District 2023" table ("Total 65
                  Canadian Prairies District Multipliers") and the chart of
                  the 60 exchanges sent from outside the prairies, both
                  transcribed by NY4I 2026-11-18.
    NY4I          issue 117, 2026-11-18: 65 districts (the table), not the
                  rules' prose 62; DC counts as MD (the sponsor chart).
    DXLog.net     CPQP.txt (updated 2026-09-05). A cross-check only: its 65
                  district codes, split AB 37 / SK 14 / MB 14, are the
                  table's exactly; its Cabrillo name is CP-QSO-PARTY.
    ADIF          no Contest_ID for this contest in ADIF 3.1.8. CP-QSO-PARTY
                  is written (below).

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  DATES -- "Begins 1700 UTC - May 9, 2026 Ends: 0300 UTC - May 10, 2025".
    The end year is a typo for 2026 (ten hours; May 9, 2026 is a Saturday,
    the second of May and of the second full weekend). The page states no
    recurrence rule, so GetSchedule states the date, Louisiana's form; it
    ran out on May 10, 2026. A question for NY4I (issue 117).

  BANDS -- "10, 15, 20 and 40 meters". UsesBand states those four; an
    off-band QSO is an automatic X-QSO. No VHF.

  MODES -- "CW, Phone"; points for "Each complete non-duplicate CW or SSB
    contact". UsesMode credits CW, Phone and FM (FM is phone, issue 117's
    research); a digital QSO is an automatic X-QSO.

  DUPES -- note 3: "Stations may be worked once on CW and once on Phone on
    each of the 4 bands". cfQSOByBand and cfQSOByMode; FM shares phone's
    dupe slot in the engine.

  QSO POINTS -- 1 per QSO.

  OUT-OF-AREA ENTRANTS -- "Contacts between non VE/VA 4, 5 and 6 stations
    do not count for QSO credit": the party base's host-area rule, refused
    when typed and an automatic X-QSO when logged any other way.

  EXCHANGE -- "VE/VA 4, 5 and 6 stations send RS/RST and 3-letter district
    abbreviation"; others "RS/RST and 2-letter State, Canadian provincial
    abbreviation, or "DX"". RSTDomesticOrDXQTHExchange, Georgia's helper
    row: a DX entrant SENDS "DX" (ADIFSentRSTStateOrDX,
    CabrilloSentRSTStateOrDX); the received column of a DX station is "DX"
    ("Stations outside the USA and Canada should be logged as DX";
    CabrilloReceivedRSTDomesticQTHOrDX).

  MULTIPLIERS -- PER BAND, not per mode ("on each of the four bands"):
    cfMultByBand, not cfMultByMode.
      Outside the area  cpqp_cty.dom: the 65 districts (FCONTEST sets
                        MultipliersIsCounties, so each is its own). The
                        rules' prose says 62 (Alberta 34); NY4I ruled 65 on
                        the sponsor's table (issue 117).
      Inside the area   cpqp.dom: the districts, each counting as its
                        province ("a provincial multiplier for the first
                        VA/VE 4, 5 or 6 station worked on each band,
                        including their own province"), DC as Maryland
                        ("DC counts as MD"), s50.dom, and the 10 other
                        provinces and territories written in the file.
                        50 + 13 = 63 per band, the rules' maximum (the sheet
                        holds 63 multipliers; pinned). P12/P13 are NOT
                        included: their call-area aliases would feed the
                        rover strip, and AB, SK and MB are no received
                        exchange (a prairie station sends its district), so
                        those three carry a display name only.
    DX -- "count for QSO credit (1 point each) but not as a multiplier":
      HasDXMultiplier False for every entrant.
    THE SPONSOR'S TOTALS DISAGREE -- the rules say 63 in area, the district
      chart's note says "a total of 66" (which fits the older 63-district
      table plus three provinces; with 65 districts it would be 68). Built
      from the rules text; no total is asserted in code beyond the sheet's
      63 entries. A question for NY4I (issue 117).

  SCORE -- "QSO Points x # Multipliers": the base's formula. No bonus, no
    power multiplier.

  DISTRICT LINES -- note 12: "If a rover station operates on a district line
    ... a separate QSO and complete exchange must be made and logged for
    each FED worked." No maximum: CountyLineCountiesUnlimited, stated.

  ROVERS -- note 11: "When Rover Stations change to a new FED they are now
    considered to be new stations": on the WORKING side this is the party
    base's received-QTH dupe key (Q118), inherited. NOT BUILT, issue #133:
    the rover ENTRANT's own side -- "Only VE/VA 4, 5 or 6 stations can enter
    as Rover Stations", "a minimum of 10 total QSOs in at least 2 FEDs to
    qualify", the sent district changing with the FED (N1MM's ROVERQTH). The
    entrant's station category does not reach the contest object.

  MOBILES -- note 13: outside-area entrants who send their current location;
    nothing to state.

  CABRILLO -- CONTEST: CP-QSO-PARTY (DXLog's CABRILLO_CONTEST_NAME; WA7BNM
    717; the rules page states none). The line is RST and the sent QTH, RST
    and the received QTH -- the rules' own example, "QSO: 14184 PH
    2023-05-24 0046 VE5CPU 59 RGQ VE5SF 59 RGW" (pinned). MODES: CW and PH;
    an FM QSO is written PH, because the sponsor's modes are CW and phone
    and its point rule says "CW or SSB" (FormatCabrilloModeDigitalAsRY: FM
    PH; a digital QSO, an X-QSO here, RY). A choice, recorded for NY4I.

  ADIF -- CONTEST_ID CP-QSO-PARTY, the Cabrillo name: ADIF's Contest_ID
    enumeration has no value for this contest. The vendored K1MU validator
    accepts it; adifmt v0.1.23 WARNS ("unknown value ... for enumeration
    Contest_ID"), as it would for any id not in the enumeration (checked
    2026-11-18). STATE: a district's province (AB, SK or MB) from
    cpqp_cty.dom; another station's state or province as itself; none for
    DX. CNTY: NOT written -- ADIF's CNTY enumeration defines nothing for
    Canada (British Columbia, Ontario, Quebec).

  THE NEW CONTEST DIALOG -- its own prompt (a district, not a county), the
    host-area box with the area 'AB/SK/MB', the district row label and
    notice (the Hawaii QSO Party's texts), and the outside rule "a state, a
    province or DX" -- AB, SK and MB are refused there (HostState's codes).

  SUBMISSION -- note 15: "Upload logs in Cabrillo format using the form in
    the Log Submission page": no address, so ''.

  3830 -- the base's one "Mults" column; the form was not checked. *)
unit uContestCanadianPrairiesQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* ITS ID -- stored data; see the header. *)
   CP_QSO_PARTY_CONTEST_ID = 'CP-QSO-PARTY';

type
   TContestCanadianPrairiesQP = class(TContestStateQSOPartyBase)
   protected
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
      function GetFriendlyName: string; override;
      (* THE THREE PROVINCES, blank-separated -- see the header. *)
      function GetHostState: string; override;
      (* The words of the New Contest box, "I am in AB/SK/MB". *)
      function GetQSOPartyArea: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetInStateDomesticFileName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function GetFlags: TContestFlags; override;
      (* "a separate QSO ... for each FED worked", no maximum. *)
      function GetCountyLineCountiesMax: integer; override;
      function ParseReceivedExchangeFormat(const aText: string;
         aParsers: TExchangeParsers; var aExch: ContestExchange): boolean; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
         const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string; override;
      (* 1 point on CW, phone and FM. Protected, as on TContestBase: ScoreQSO
         is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* 40, 20, 15 and 10 m -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* CW and phone (FM is phone); no digital -- the header. *)
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
      (* CW and PH; FM is PH -- the header. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;
      (* ' 5NN ' and the district, state or province this station sends; DX
         when it sends none. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* THE MULTIPLIERS -- districts, or states and provinces, from the
         domestic file; no DX, zone or prefix multiplier for any entrant. *)
      function HasDXMultiplier: boolean; override;
      function HasZoneMultiplier: boolean; override;
      function HasPrefixMultiplier: boolean; override;
      function ExchangeCarriesDomesticQTH: boolean; override;
      (* NO ADIF CNTY -- the header. *)
      function WritesADIFCounty: boolean; override;
      (* ITS OWN NEW CONTEST PROMPT, AND THE DISTRICT TEXTS IN THE BOX. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
      function DescribeNewContestHostArea(out aArea: TNewContestHostArea): boolean; override;
   end;

implementation

uses
   SysUtils,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* FormatCabrilloModeDigitalAsRY -- FM is PH. *)
   uCabrilloFormat,
   (* SNewContestCPQPDistrictOrLocation, the district label and notice. *)
   uAppStrings,
   uContestRegistry;

function TContestCanadianPrairiesQP.GetDisplayName: string;
begin
   Result := 'Canadian Prairies QSO Party';
end;

(* WHEN IT RUNS -- https://cpqp.ve6hams.ca/rules-2/, "Last Update: March 8,
   2026": "Begins 1700 UTC - May 9, 2026 Ends: 0300 UTC - May 10, 2025" (the
   end year a typo). The sponsor states no recurrence rule, only the 2026
   date; NY4I ruled (issue 117, 2026-11-22) that it recurs on the 2nd
   Saturday of May, 1700 UTC for 10 hours: May 9, 2026 is that Saturday, and
   a fixed date goes stale every year. One period, so it can show time left
   (issue 243). *)
function TContestCanadianPrairiesQP.GetSchedule: string;
begin
   Result := '2nd Saturday of May at 17:00 UTC for 10h';
end;

function TContestCanadianPrairiesQP.GetFriendlyName: string;
begin
   Result := 'Canadian Prairies QSO Party';
end;

function TContestCanadianPrairiesQP.GetHostState: string;
begin
   (* Alberta, Saskatchewan and Manitoba -- each district names its own in
      cpqp_cty.dom. *)
   Result := 'AB SK MB';
end;

function TContestCanadianPrairiesQP.GetQSOPartyArea: string;
begin
   Result := 'AB/SK/MB';
end;

function TContestCanadianPrairiesQP.GetCabrilloName: string;
begin
   (* The rules page states none; DXLog's CABRILLO_CONTEST_NAME. *)
   Result := 'CP-QSO-PARTY';
end;

function TContestCanadianPrairiesQP.GetADIFContestId: string;
begin
   (* Not in ADIF's Contest_ID enumeration -- the header. Export writes it,
      import matches it. *)
   Result := CP_QSO_PARTY_CONTEST_ID;
end;

function TContestCanadianPrairiesQP.GetWA7BNMId: integer;
begin
   (* issue 117's research (2026-10-26); not re-read -- the calendar bars
      automated access. *)
   Result := 717;
end;

function TContestCanadianPrairiesQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestCanadianPrairiesQP.GetSubmissionEmail: string;
begin
   (* Note 15: "Upload logs in Cabrillo format using the form in the Log
      Submission page" -- no address takes logs. *)
   Result := '';
end;

function TContestCanadianPrairiesQP.GetDomesticFileName: string;
begin
   (* The district file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a prairie district, and then loads cpqp.dom or
      this file; the ADIF export reads its '>' provinces. *)
   Result := 'cpqp_cty';
end;

function TContestCanadianPrairiesQP.GetInStateDomesticFileName: string;
begin
   Result := 'cpqp';
end;

function TContestCanadianPrairiesQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCanadianPrairiesQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestCanadianPrairiesQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestCanadianPrairiesQP.GetFlags: TContestFlags;
begin
   (* Note 3 "once on CW and once on Phone on each of the 4 bands";
      multipliers "on each of the four bands", not per mode. *)
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand];
end;

function TContestCanadianPrairiesQP.GetCountyLineCountiesMax: integer;
begin
   (* Note 12: "a separate QSO and complete exchange must be made and logged
      for each FED worked" -- no maximum. The base's value, stated so the
      rule is read here. *)
   Result := CountyLineCountiesUnlimited;
end;

function TContestCanadianPrairiesQP.ParseReceivedExchangeFormat(const aText: string;
   aParsers: TExchangeParsers; var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
end;

(* "Stations outside the VE/VA 4, 5 and 6 areas send RS/RST and 2-letter
   State, Canadian provincial abbreviation, or "DX"" -- a DX entrant sends
   DX (Georgia's row). *)
function TContestCanadianPrairiesQP.GetADIFSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTStateOrDX(aMy, aQso);
end;

function TContestCanadianPrairiesQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
end;

function TContestCanadianPrairiesQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
   const aQso: ContestExchange; const aCtx: TCabrilloQSOContext): string;
begin
   (* "Stations outside the USA and Canada should be logged as DX": DX
      whenever the record holds no domestic QTH. *)
   Result := CabrilloReceivedRSTDomesticQTHOrDX(aMy, aQso, aCtx);
end;

(* ONE POINT, CW, PHONE OR FM. An off-band or off-mode QSO never reaches
   here, nor a station this entrant may not credit. *)
procedure TContestCanadianPrairiesQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Phone, FM:
         begin
         aQso.QSOPoints := 1;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestCanadianPrairiesQP.UsesBand(aBand: BandType): boolean;
begin
   (* "BANDS: 10, 15, 20 and 40 meters". *)
   Result := aBand in [Band40, Band20, Band15, Band10];
end;

(* CW and phone, FM being phone. Any submode of CW, Phone or FM is credited
   -- eNoMode and eData included, as the contract asks -- and no submode of
   Digital is. An identity fact: no station is asked. *)
function TContestCanadianPrairiesQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;

function TContestCanadianPrairiesQP.CabrilloModeString(aMode: ModeType;
                                                       aExtMode: ExtendedModeType): string;
begin
   Result := FormatCabrilloModeDigitalAsRY(aMode, aExtMode);
end;

function TContestCanadianPrairiesQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is what the session SENDS (design 7.11/7.12): a
      prairie station's district, anyone else's state or province. A DX
      entrant states none, or DX, and sends DX. *)
   if Trim(aStation.MyState) = '' then
      begin
      Result := ' 5NN DX';
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyState;
      end;
end;

function TContestCanadianPrairiesQP.HasDXMultiplier: boolean;
begin
   (* DX stations "count for QSO credit (1 point each) but not as a
      multiplier". *)
   Result := False;
end;

function TContestCanadianPrairiesQP.HasZoneMultiplier: boolean;
begin
   Result := False;
end;

function TContestCanadianPrairiesQP.HasPrefixMultiplier: boolean;
begin
   Result := False;
end;

function TContestCanadianPrairiesQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

(* ADIF's CNTY enumeration defines nothing for Canada (British Columbia,
   Ontario, Quebec): a district is no ADIF county. *)
function TContestCanadianPrairiesQP.WritesADIFCounty: boolean;
begin
   Result := False;
end;

procedure TContestCanadianPrairiesQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(SNewContestCPQPDistrictOrLocation, ncfMyState);
end;

(* THE BOX AS THE BASE STATES IT -- area AB/SK/MB, places the district file's
   keys, AB, SK and MB refused outside -- with the district texts. *)
function TContestCanadianPrairiesQP.DescribeNewContestHostArea(out aArea: TNewContestHostArea): boolean;
begin
   Result := inherited DescribeNewContestHostArea(aArea);
   aArea.PlaceLabel := SNewContestHostAreaDistrictLabel;
   aArea.InsideNotice := SNewContestHostAreaInsideDistrictNotice;
end;

initialization
   RegisterContestById(CP_QSO_PARTY_CONTEST_ID, TContestCanadianPrairiesQP);

end.
