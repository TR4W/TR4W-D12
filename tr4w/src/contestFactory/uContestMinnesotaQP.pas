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

(* MINNESOTA QSO PARTY.

  THE RULES ARE THE SPONSOR'S, DATED JUNE 8, 2026, FOR THE 2027 CONTEST ON
  (issue #193, from TR4W/TR4W#1082): docs/ContestRules/QSOParties/Minnesota/
  (MNQP_2027_Contest_Rules_A.pdf, transcribed in MN-QSO-PARTY-Rules.txt).
  Each rule below is quoted from it; uTestContestMinnesotaQP pins each one.
  The class states the sponsor's CURRENT rules and is not year-gated, so a
  pre-2027 log rescored here gets the 2027 points and multipliers.

  IDENTITY, from the ContestsArray row (deleted at M10 S8): legacy contest
  MINNQSOPARTY; Cabrillo and ADIF MN-QSO-PARTY; WA7BNM 238; the county file
  minnesota_cty, the in-state file minnesota.

  BANDS: "HF: 160m - 10m (excluding WARC bands)." UsesBand. No 6 m and up,
  so no cfVHFBandsEnabled.

  MODES: "Phone (SSB, DSB, FM, AM all count as Phone) / CW - only". UsesMode:
  CW, Phone and FM; a digital QSO is an automatic X-QSO.

  POINTS (NEW 2027): "Phone QSO's equal 2 points each. CW QSO's equal 3 QSO
  points each." FM is Phone. "The final score is QSO points total times
  multiplier total" -- the base's CombineWithMultipliers.

  MULTIPLIERS (NEW 2027): "Multipliers may be worked once on each mode" and
  "Multipliers count by mode - once for CW and once for SSB." cfMultByMode;
  the multiplier sheet files FM under Phone (uMults.DupeSlot).
    * "Multipliers for Minnesota Stations: 50 states (includes Minnesota),
      1 District of Columbia, 10 Canadian provinces, 3 Canadian Territories,
      and 1 DX; 65 per mode". "In state county multipliers no longer count
      for MN stations while QSO's still count." DATA: minnesota_cty.dom maps
      each county to Mn (KEY > Mn), minnesota.dom adds the states, DC and the
      13 provinces and territories -- 64 domestic multipliers.
    * THE 1 DX: "Minnesota stations may work DXCC countries for points and
      receive 1 multiplier for working a DX station." ONE DOMESTIC
      multiplier, MN_DX_MULTIPLIER_KEY, which CalculateQSOPoints writes as
      the QSO's DomMultQTH for a Minnesota entrant's QSO with any country but
      the USA, Canada, Hawaii and Alaska (states and provinces here);
      minnesota.dom lists it, so the in-state table is the rules' 65.
      NOT THE DX KIND: the sheet counts a DX multiplier per DXCC country
      (uMults.IsDXMult keys on QTH.Country; the class's key only switches
      it on), so a constant key would still give one per country. NOT the
      .dom lookup alone: the name-and-QTH parser never looks a DX call's
      QTH up. KNOWN LAG: the rescore runs SetMultFlags BEFORE
      CalculateQSOPoints (live entry scores first), so a row that carries no
      key yet (one logged before this class wrote it, or imported) gets it
      on its first rescore and is credited from the next; a row entered live
      keeps the key it was stored with. A "QSO POINTS ..." override that
      applies skips CalculateQSOPoints, so such a QSO gets no DX key -- the
      same hole MWC has.
    * "Multipliers for W/VE and DX (outside Minnesota): MN counties: 87 per
      mode" -- the county file, each county its own multiplier.

  ROVERS (NEW 2027): "Rovers may operate simultaneously from up to 2
  counties." GetCountyLineCountiesMax = 2. A rover in a new county is a new
  station -- the party base's received-QTH dupe key.
    NOT BUILT: one typed entry naming two counties ("BOB AIT/CRW") is not
    split into two QSOs on this contest's name-and-QTH parser -- only the
    RST and serial parsers carry the county-line queue -- so two entries are
    logged, one per county, as the base's dupe key allows. A TR4W entrant who
    IS the two-county rover, and "Mobile stations may operate in only one
    county at a time, county line operation not permitted", need the
    entrant's category, which does not reach scoring (#133).
 *)
unit uContestMinnesotaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

const
   (* "receive 1 multiplier for working a DX station" -- the domestic
      multiplier a Minnesota entrant's DX QSO counts as. minnesota.dom's
      DX entry is spelt the same, so the remaining-multiplier list crosses
      it off. *)
   MN_DX_MULTIPLIER_KEY = 'DX';

type
   TContestMinnesotaQP = class(TContestStateQSOPartyBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- a class body with no visibility
         section defaults to public, which would make both X.HostState and
         X.GetHostState callable. Callers use the property; descendants
         override the getter. *)
      function GetDisplayName: string; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'MN' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident. *)
      function GetHostState: string; override;

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class." Every getter below returns what the array holds today, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what the contest is without cross-referencing a 185-row
         table by enum position.

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and for every accessor a class does not
         override. *)
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

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetFlags: TContestFlags; override;
      function GetCountyLineCountiesMax: integer; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* THE BANDS AND MODES THE RULES NAME -- see TContestBase.UsesBand. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   (* DXCCKeyExceptUSACanadaHawaiiAlaska -- issue #136; here only the
      country test. *)
   uDXMultiplierKey,
   uContestRegistry;

function TContestMinnesotaQP.GetDisplayName: string;
begin
   Result := 'Minnesota QSO Party';
end;

function TContestMinnesotaQP.GetHostState: string;
begin
   Result := 'MN';
end;

function TContestMinnesotaQP.GetCabrilloName: string;
begin
   Result := 'MN-QSO-PARTY';
end;

function TContestMinnesotaQP.GetADIFContestId: string;
begin
   Result := 'MN-QSO-PARTY';
end;

function TContestMinnesotaQP.GetWA7BNMId: integer;
begin
   Result := 238;
end;

function TContestMinnesotaQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestMinnesotaQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestMinnesotaQP.GetDomesticFileName: string;
begin
   Result := 'minnesota_cty';
end;

function TContestMinnesotaQP.GetFriendlyName: string;
begin
   Result := 'Minnesota QSO Party';
end;

function TContestMinnesotaQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestMinnesotaQP.GetExchangeKind: ExchangeType;
begin
   Result := NameAndDomesticOrDXQTHExchange;
end;

function TContestMinnesotaQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNameQTH;
end;

function TContestMinnesotaQP.ParseReceivedExchangeFormat(const aText: string;
                                                         aParsers: TExchangeParsers;
                                                         var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseNameAndDomesticOrDXQTH(aText, aExch);
end;

procedure TContestMinnesotaQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteNameAndState;
end;

function TContestMinnesotaQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestMinnesotaQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := ADIFSentNameState(aMy, aQso);
end;

function TContestMinnesotaQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentNameState(aMy, aQso, aCtx);
end;

function TContestMinnesotaQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNameQTH(aMy, aQso, aCtx);
end;

function TContestMinnesotaQP.GetInStateDomesticFileName: string;
begin
   Result := 'minnesota';
end;

(* "Work stations once per band & mode" (cfQSOByBand, cfQSOByMode);
   "Multipliers count by mode - once for CW and once for SSB" (cfMultByMode,
   NEW 2027); HF only, so no cfVHFBandsEnabled; RTC through HamScore. *)
function TContestMinnesotaQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfMultByMode, cfRTCCapable];
end;

(* "Rovers may operate simultaneously from up to 2 counties." (NEW 2027) *)
function TContestMinnesotaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* "Phone QSO's equal 2 points each. CW QSO's equal 3 QSO points each."
   (NEW 2027). "SSB, DSB, FM, AM all count as Phone". Any other mode scores
   nothing (a digital QSO is an X-QSO by UsesMode and never reaches here).

   AND THE ONE DX MULTIPLIER, written HERE as the QSO's domestic multiplier
   key -- see the header for why it is not the DX kind (the sheet counts
   that one per DXCC country). A Minnesota entrant's QSO with a station
   whose located country is not the USA, Canada, Hawaii or Alaska counts as
   MN_DX_MULTIPLIER_KEY. MWC, the RF Championships and YOTA write
   DomMultQTH from this method too: it is the one class seam live entry,
   the rescore, the import and the matrix all reach. A QSO whose call was
   never located (no country) is left alone. *)
procedure TContestMinnesotaQP.CalculateQSOPoints(var aQso: ContestExchange);
var
   unusedKey: DXMultiplierString;
begin
   case aQso.Mode of
      CW:
         begin
         aQso.QSOPoints := 3;
         end;
      Phone, FM:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;

   if (aQso.QTH.CountryID <> '') and
      DXCCKeyExceptUSACanadaHawaiiAlaska(Station.InHostState, aQso, unusedKey) then
      begin
      aQso.DomMultQTH := MN_DX_MULTIPLIER_KEY;
      end;
end;

(* "HF: 160m - 10m (excluding WARC bands)." *)
function TContestMinnesotaQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

(* "Phone (SSB, DSB, FM, AM all count as Phone) / CW - only". Every submode
   of CW and Phone, and FM; no digital mode. *)
function TContestMinnesotaQP.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone, FM];
end;


(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for COLORADOQSOPARTY.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestMinnesotaQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   (* The party head first -- the county or state, as for every party. *)
   inherited DescribeNewContestPrompts(aPrompts);
   aPrompts.AskField(ncfMyName);
end;

initialization
   RegisterContest(MINNQSOPARTY, TContestMinnesotaQP);

end.
