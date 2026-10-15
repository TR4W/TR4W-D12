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

(* DELAWARE QSO PARTY -- sponsored by the First State Amateur Radio Club.
  First full weekend of May.

  A NEW ContestType, NOT A MOVED ONE (2026-10-14). NY4I ruled it into
  existence on 2026-10-13 (CONTEST_OWNERSHIP_DESIGN.md 7.14). Before that,
  Delaware existed in TR4W only as the fourth party folded into IN7QPNE, which
  scored every QSO by one rule set. IN7QPNE is now a COMPOSITE
  (uContestIN7QPNE, design 8.2r) that judges each QSO by the worked
  station's party, and this class is the Delaware component it delegates to.
  It is an ordinary, self-contained contest -- nothing in it knows a
  composite exists.

  ON THE STATE-PARTY BASE, BECAUSE IT IS ONE: one host state, county
  multipliers for everyone outside it, and "non-DE stations work DE stations
  only" -- which is exactly the base's out-of-state refusal (design 7.10).

  ---------------------------------------------------------------------------
  SOURCES

    the sponsor's rules   https://www.fsarc.org/qsoparty/rules-2024.html
    the Cabrillo page     https://www.fsarc.org/qsoparty/cabrillo.htm
    NY4I, 2026-10-13      the rule summary in design 7.14, and the decision
                          that the electronic-log bonus always applies
    ADIF 3.1.7 Contest_ID DE-QSO-PARTY

  The sponsor's pages were NOT re-read when this was written (2026-10-14);
  every rule below is NY4I's summary of them as recorded in design 7.14 and
  the brief that commissioned this class.

  ---------------------------------------------------------------------------
  WHAT EACH RULE SAYS, AND WHERE IT LANDED

  BANDS -- "All HF bands EXCEPT WARC, plus 6 m and up (repeaters OK)."
    UsesBand: 160, 80, 40, 20, 15 and 10 m, and every band from 6 m up,
    light included. 30, 17 and 12 m are logged, score 0 and earn no
    multiplier (design 7.4). 60 m has no BandType (VC's Band60 is commented
    out), so it cannot be logged at all. 160 m and light are a reading of the
    summary, not of the sponsor's text -- design Q72.

  WHO WORKS WHOM -- "DE stations work everyone; non-DE stations work DE
    stations only." The base's ParseReceivedExchange refuses an out-of-state
    station working a QTH the county file does not hold, with
    SExchangeOutOfStateWorksHostOnly. Nothing to override.

  EXCHANGE -- a DE station sends RST and its county; anyone else RST and a
    state, VE province or "DX". RSTDomesticOrDXQTHExchange, for both sides
    of the state line: the shape accepts a county, a state or a province
    through the session's domestic table and a DX QTH otherwise, and for an
    out-of-state station that table is the three counties, so the base's
    refusal does the rest. (Arizona and Texas narrow an out-of-state
    session to RSTDomesticQTHExchange instead; that refuses the same
    exchanges with the shape's "improper county" message rather than the
    base's clearer one, so it is not copied.)

  QSO POINTS -- by the ENTRANT's location: inside DE phone 1, digital 2,
    CW 2; outside DE phone 10, digital 20, CW 20. CalculateQSOPoints, keyed
    on Station.InHostState -- the answer set-up took when it chose the
    domestic file, from MY STATE RESOLVED (design 7.12), so a per-contest
    MY STATE override moves both together. FM is phone.

  MULTIPLIERS -- once PER BAND (MB1 MM0). A DE entrant counts US states, VE
    provinces and DXCC entities; anyone else counts the three DE counties.
      in state      delaware.dom: the counties (each mapped to De), S50, P13.
                    DX: ARRLDXCCWithNoUSACanadaKH6OrKL7 -- Alaska and Hawaii
                    are STATES here (S50 holds them), so they are not also
                    DXCC multipliers; Texas states the same value for the
                    same rule.
      out of state  delaware_cty.dom: NDE, KDE, SDE, each its own multiplier
                    (FCONTEST sets MultipliersIsCounties). DescribeSession
                    states NoDXMults: such an entrant works only DE stations,
                    and its session should not offer a DX column at all.

  DUPES -- once per band per mode (QB1 QM1). A county-line station counts as
    two QSOs: GetCountyLineCountiesMax = 2 (DE has three counties, and a line
    joins two). "A DE mobile that changes county is a new station" is a
    DUPE-KEY rule, and there is no dupe-key seam (M8, design 8.2l: the sheet
    keeps the state) -- design Q73.

  SCORE -- QSO points x multipliers x POWER MULTIPLIER, + 50 for an
    electronic log. Power is CATEGORY-POWER, the ONE value (design 7.6),
    Station.MyPower: HIGH (over 100 W) x1, LOW (100 W or less) x2, QRP (5 W or
    less) x3 -- CombineWithMultipliers. The 50 is BonusPoints, always: TR4W
    submits electronically (decided, design 8.2q).

  CABRILLO -- CONTEST: DE-QSO-PARTY; modes CW, PH and RY, every digital mode
    being RY (CabrilloModeString). The QSO line is the shared
    RSTDomesticOrDXQTHExchange arm's -- RST and the sent state or county,
    RST and the received QTH or DX -- which is the sponsor's column order.
    The header must carry ARRL-SECTION: or LOCATION:, so
    RequiresCabrilloLocation is True: the writer refuses to start a file
    without a LOCATION. The VALUE (DE, the state or section, DX) is the
    operator's in the summary window; deriving it is design Q74.

  ADIF -- CONTEST_ID DE-QSO-PARTY; export and import are the base's.

  IDENTITY -- no WA7BNM id or submission address is recorded for this
    contest in TR4W yet: 0 and '' (design Q75). *)
unit uContestDelawareQP;

{$I tr4w.inc}

interface

uses
   (* cpLOW / cpQRP -- the entrant's CATEGORY-POWER, as TStationContext
      carries it. First, so VC's names win wherever the two overlap. *)
   uSettingsModel,
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestDelawareQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES. Stated; the
         base makes it abstract so it is never an accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE. The row exists only because
         ContestsArray is array[ContestType] and the compiler demands one;
         Test_MovedRowValuesStillMatchTheArray holds the two together. *)
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      (* THE OLD ROW'S CountyLineAllowed: True, which ADIF export read to split
         a rover's call -- M10 S8; open question Q90. See
         TContestStateQSOPartyBase.GetSplitsRoverCallOnExport. *)
      function GetSplitsRoverCallOnExport: boolean; override;
      function GetFlags: TContestFlags; override;

      (* A county-line station is two QSOs -- see the header. *)
      function GetCountyLineCountiesMax: integer; override;

      (* The writer refuses a Cabrillo file with no LOCATION -- the header. *)
      function GetRequiresCabrilloLocation: boolean; override;

      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* POINTS x MULTIPLIERS x THE POWER MULTIPLIER -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* All HF but WARC, and 6 m up -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;

      (* ' 5NN ' and the state or county this station sends. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;

      (* CW, PH and RY -- every digital mode is RY, FM is phone. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; override;

      (* THE ELECTRONIC-LOG BONUS, 50, always -- the header. *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; override;
   private
      (* DOES THIS ENTRANT COUNT A DX MULTIPLIER? -- the station test
         DescribeSession stated the DX kind under (deleted at M11 S4 part 2);
         HasDXMultiplier, the key and the country list ask it, so the answers
         cannot disagree (M11 S4). *)
      function CountsDXMultiplier: boolean;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
      (* THE ROVER COUNTY -- see TContestBase.StripsRoverCountyFromCall (M11 S7). *)
      function StripsRoverCountyFromCall: boolean; override;
   end;

const
   (* "+ 50 points for submitting your log electronically". *)
   DelawareElectronicLogBonus = 50;

(* THE POWER MULTIPLIER FOR A CATEGORY-POWER -- HIGH x1, LOW x2, QRP x3.
   Public so the tests assert the mapping itself, not only a product. *)
function DelawarePowerMultiplier(aPower: tCategoryPower): longint;

implementation

uses
   uDXMultiplierKey,
   uCabrilloFormat,   (* FormatCabrilloMode *)
   uContestRegistry;

function DelawarePowerMultiplier(aPower: tCategoryPower): longint;
begin
   case aPower of
      cpLOW:
         begin
         Result := 2;
         end;
      cpQRP:
         begin
         Result := 3;
         end;
      else
         begin
         Result := 1;
         end;
      end;
end;

function TContestDelawareQP.GetDisplayName: string;
begin
   Result := 'Delaware QSO Party';
end;

function TContestDelawareQP.GetHostState: string;
begin
   Result := 'DE';
end;

function TContestDelawareQP.GetCabrilloName: string;
begin
   (* The sponsor's Cabrillo page. *)
   Result := 'DE-QSO-PARTY';
end;

function TContestDelawareQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's Contest_ID enumeration. *)
   Result := 'DE-QSO-PARTY';
end;

function TContestDelawareQP.GetWA7BNMId: integer;
begin
   (* Not recorded in TR4W -- design Q75. *)
   Result := 0;
end;

function TContestDelawareQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestDelawareQP.GetSubmissionEmail: string;
begin
   (* Not recorded in TR4W -- design Q75. *)
   Result := '';
end;

function TContestDelawareQP.GetDomesticFileName: string;
begin
   (* The county file. FCONTEST.FoundMyStateInDomFile reads it to decide
      whether MY STATE is a Delaware county, and then loads delaware.dom or
      delaware_cty.dom through this party's QSOParties entry. *)
   Result := 'delaware_cty';
end;

function TContestDelawareQP.GetFriendlyName: string;
begin
   Result := 'Delaware QSO Party';
end;

function TContestDelawareQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestDelawareQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestDelawareQP.GetInStateDomesticFileName: string;
begin
   Result := 'delaware';
end;

function TContestDelawareQP.GetSplitsRoverCallOnExport: boolean;
begin
   Result := True;
end;

function TContestDelawareQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByBand, cfVHFBandsEnabled];
end;

function TContestDelawareQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

function TContestDelawareQP.GetRequiresCabrilloLocation: boolean;
begin
   Result := True;
end;

(* PHONE 1, DIGITAL 2, CW 2 INSIDE DELAWARE; 10, 20 AND 20 OUTSIDE.

   OWN BODY, NOT FixedModePoints: that helper files FM with "everything
   else", which here is digital, so FM would score the digital value. FM is
   a phone mode. Both and NoMode are not modes a contact is made in, and
   score nothing.

   THE ENTRANT'S LOCATION IS Station.InHostState -- see the header. An
   off-band QSO never reaches here (UsesBand). *)
procedure TContestDelawareQP.CalculateQSOPoints(var aQso: ContestExchange);
var
   phonePoints: integer;
   otherPoints: integer;
begin
   if Station.InHostState then
      begin
      phonePoints := 1;
      otherPoints := 2;
      end
   else
      begin
      phonePoints := 10;
      otherPoints := 20;
      end;

   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := otherPoints;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := phonePoints;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;
end;

function TContestDelawareQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := inherited CombineWithMultipliers(aTotals) *
             DelawarePowerMultiplier(Station.MyPower);
end;

function TContestDelawareQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10,
                       Band6, Band2, Band222, Band432, Band902, Band1296,
                       Band2304, Band3456, Band5760, Band10G, Band24G,
                       BandLight];
end;

function TContestDelawareQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   (* aStation.MyState is the state the session SENDS (design 7.11/7.12): a
      Delaware station's county, anyone else's state or province. *)
   Result := ' 5NN ' + aStation.MyState;
end;

function TContestDelawareQP.CabrilloModeString(aMode: ModeType;
                                               aExtMode: ExtendedModeType): string;
begin
   if aMode = Digital then
      begin
      Result := 'RY';
      end
   else
      begin
      Result := FormatCabrilloMode(aMode, aExtMode, True);
      end;
end;

function TContestDelawareQP.BonusPoints(const aTotals: TScoreTotals;
                                        aView: TLoggedQSOView): longint;
begin
   Result := inherited BonusPoints(aTotals, aView) + DelawareElectronicLogBonus;
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestDelawareQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for an entrant inside Delaware; none outside, because such
   an entrant works only Delaware stations. This is the station test the
   session's DX kind was chosen by (the trait, then DescribeSession) until
   that kind was deleted; DXMultiplierKey and the country list ask the same
   predicate, so the answers cannot disagree. *)
function TContestDelawareQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA, Canada, Hawaii and Alaska, for an entrant inside Delaware (the trait's
   ARRLDXCCWithNoUSACanadaKH6OrKL7); none for anyone else, whose
   DescribeSession stated NoDXMults. *)
function TContestDelawareQP.DXMultiplierKey(const aQso: ContestExchange;
                                            out aKey: DXMultiplierString): boolean;
begin
   aKey := '';
   Result := False;
   if CountsDXMultiplier and
      not IsUSACanadaHawaiiOrAlaskaCountry(aQso.QTH.CountryID) then
      begin
      aKey := aQso.QTH.CountryID;
      Result := True;
      end;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestDelawareQP.CountryMode: CountryModeType;
begin
   if CountsDXMultiplier then
      begin
      Result := ARRLCountryMode;
      end
   else
      begin
      Result := CQCountryMode;
      end;
end;

(* A CALL'S /SUFFIX THAT THE DOMESTIC TABLE KNOWS IS A ROVER'S COUNTY, at
   every station -- M11 S7, 2026-10-14. It was the session's
   RSTDomesticOrDXQTH shape; see TContestBase.StripsRoverCountyFromCall. *)
function TContestDelawareQP.StripsRoverCountyFromCall: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(DELAWAREQSOPARTY, TContestDelawareQP);

end.
