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

(* THE 7TH CALL AREA QSO PARTY (7QP).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'seven_cty';  WA7BNM: 404;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 10;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: TwoPhoneThreeCW;
   ADIFName: '7QP';  CABName: '';
   FriendlyName: '7th Call Area QSO Party'

  A blank CABName resolves to the enum's spelling, '7QP'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A STATE QSO PARTY, ALTHOUGH ITS ROW SAYS P: 10. It is a MULTI-STATE
  party -- eight states share one exchange -- and TContestStateQSOPartyBase
  assumes ONE host state: its out-of-state refusal (design 7.10) and its
  county-line rule are written for that. So it sits on TContestBase and
  keeps exactly what the program did: the row's P still makes set-up treat
  it as a party (the in-state test against seven_cty, the in-state file
  `seven`, K/VE/KH6/KL), stated here as IsUSQSOParty, and its exchange is
  parsed by the session's shape with no party rule. Whether a multi-state
  party wants a base of its own is a design question recorded in the
  design doc (M7b), not answered here. Its county-line maximum is 4 by the
  sponsor's rule (ADDING_A_CONTEST.md's worksheet) and is NOT enforced --
  nothing enforced it before.

  SCORING: 3 on CW, 4 on digital (Q85, the sponsor's), 2 otherwise. It was
  TwoPhoneThreeCW -- digital 2 -- until 2026-10-17.

  SET-UP: an in-state station (FoundContest's own in-state answer,
  aStation.InHostState -- the arm asked FoundMyStateInDomFile again, which
  is the same question on the same data) sends RST and its county or DX
  and counts DXCC without W/VE/KH6/KL7; everyone else sends RST and a
  county. LogCfg's CQ exchange: 5NN and MY STATE.

  #88 ROUND 3 (2026-10-26), the sponsor's 2026 rules
  (docs/ContestRules/QSOParties/SeventhCallArea/7QP-Rules.txt):
    * THE DX CAP IS 10, ON THE DX KIND ONLY: "7th-area stations multiply
      total QSO points by the total of states (50), provinces (13) and other
      DXCC entities (maximum of 10) worked." CombineWithMultipliers caps the
      DX count; the states and provinces are not capped. D7's arm stated a
      limit of 20 into a global that NOTHING read, in D7 or here, so no cap
      had ever applied -- that statement and the global are deleted.
    * A ROVER IN A NEW COUNTY IS A NEW QSO: "7th-area mobiles ... may be
      worked again as they enter new counties." The received QTH joins the
      dupe key (DupeKeyIncludesReceivedQTH), as on every single-state party
      since Q118 -- the /county suffix already did; now the bare call does.

  BANDS (NY4I, 2026-10-16, from the four parties' rules): 160, 80, 40, 20,
  15 and 10 m -- no WARC, no VHF. UsesBand states them; a QSO anywhere else
  is logged, scores 0 and earns no multiplier (design 7.4). The row's
  cfVHFBandsEnabled went with that ruling: it put 6 m and up in band
  stepping and the band map, for a contest that credits neither. *)
unit uContestSevenQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestSevenQP = class(TContestBase)
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

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetInStateDomesticFileName: string; override;
      function GetQSOPartyArea: string; override;
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
      (* Points times the multipliers, at most 10 of them DX -- the header. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* 160 to 10 m without WARC -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
      (* A MOBILE IN A NEW COUNTY IS A NEW QSO -- the received QTH is part of
         the dupe key. See TContestBase.DupeKeyIncludesReceivedQTH and the
         header. *)
      function DupeKeyIncludesReceivedQTH: boolean; override;
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
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
   public
      (* A STATION OUTSIDE THE 7TH AREA WORKS ONLY 7TH-AREA STATIONS -- Q107
         (NY4I, 2026-10-16), the rule he gave for "qso parties in general"
         (Q29, 2026-10-15). Until Q107 this multi-state party was never held
         to it (the header): out of area its exchange shape already refused
         a QTH its county file does not know, so typing barely changes, but
         a logged QSO -- imported, networked, rescored -- scored whoever it
         was with.

         THE SAME PREDICATE AS EVERY STATE PARTY, uContestBase.
         HostAreaRuleCredits, with this contest's own in-area answer: the
         station test DescribeSession and the DX multiplier ask
         (CountsDXMultiplier, Station.InHostState -- set-up's in-state test
         against seven_cty). Out of area the table is seven_cty, the 7th
         area's counties. The refusal names QSOPartyArea ('7th area'). *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* THE WORKED STATION'S ADIF STATE -- see TContestBase.ADIFCountyState
         and ADIFWorkedStationState (Q76/Q89, NY4I 2026-10-16). A county key
         of seven_cty.dom is five letters, the state first (Azaph); the
         county's state is those two letters when they are one of the eight
         7th-area states. No CNTY: WritesADIFCounty stays False, as before. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function ADIFWorkedStationState(const aQso: ContestExchange): string; override;
      (* THE ROVER COUNTY -- see TContestBase.StripsRoverCountyFromCall (M11 S7)
         and SplitsRoverCallOnExport (Q90/Q94). *)
      function StripsRoverCountyFromCall: boolean; override;
      function SplitsRoverCallOnExport: boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   (* FIRST, so every later unit wins a shared name: SysUtils for
      UpperCase, uADIF for ADIFPartyQTHKey and ADIFStateOfPartyQSO
      (Q76/Q89). *)
   SysUtils,
   uADIF,
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uDXMultiplierKey,
   uContestRegistry,
   (* SExchangeOutOfStateWorksHostOnly -- the host-area refusal (Q107). *)
   uAppStrings,
   (* FixedModePoints -- the helper for a number per mode. *)
   uContestFixedPoints;

(* THE HOST-AREA RULE, BOTH SIDES -- see the declaration (Q107). *)
function TContestSevenQP.ParseReceivedExchange(const aText: string;
                                               const aSession: TReceivedExchangeSession;
                                               var aExch: ContestExchange;
                                               out aErrorMessage: string): boolean;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if not Result then
      begin
      Exit;
      end;

   if not HostAreaRuleCredits(CountsDXMultiplier,
                              string(aExch.QTHString),
                              aSession.IsDomesticQTH) then
      begin
      Result := False;
      aErrorMessage := Format(SExchangeOutOfStateWorksHostOnly, [QSOPartyArea]);
      end;
end;

function TContestSevenQP.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   Result := HostAreaRuleCredits(CountsDXMultiplier,
                                 string(aQso.QTHString),
                                 Station.IsDomesticQTH);
end;

(* CW 3, DIGITAL 4, PHONE 2 -- Q85 (2026-10-15). The 7QP sponsor's page
   scores SSB 2, CW 3 and digital 4, and DXLog's 7QP.txt agrees ("CW QSO give
   3 points, SSB QSO give 2 points, digital mode QSO give 4 points"). TR4W
   gave digital 2 (TwoPhoneThreeCW). FM and anything else stays 2, as it was
   -- the sponsor's phone value; FM on 10 m is phone. *)
procedure TContestSevenQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Mode = Digital then
      begin
      aQso.QSOPoints := 4;
      end
   else
      begin
      aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 2, 2);
      end;
end;

const
   (* "other DXCC entities (maximum of 10)" -- the sponsor's Scoring. *)
   SEVENQP_MAXIMUM_DX_MULTIPLIERS = 10;

(* THE DX CAP -- the header. Out of the 7th area there is no DX multiplier,
   so the DX count is 0 and the cap never bites. *)
function TContestSevenQP.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) *
             SummedMultipliersWithKindCapped(aTotals, rmDX, SEVENQP_MAXIMUM_DX_MULTIPLIERS);
end;

(* "7th-area mobiles (and those participating in other concurrent QSO
   parties or contests) may be worked again as they enter new counties" --
   the sponsor's 2026 rules. At both kinds of entrant. *)
function TContestSevenQP.DupeKeyIncludesReceivedQTH: boolean;
begin
   Result := True;
end;

function TContestSevenQP.GetDisplayName: string;
begin
   Result := '7th Call Area QSO Party';
end;

function TContestSevenQP.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := '7QP';
end;

function TContestSevenQP.GetADIFContestId: string;
begin
   Result := '7QP';
end;

function TContestSevenQP.GetWA7BNMId: integer;
begin
   Result := 404;
end;

function TContestSevenQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestSevenQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestSevenQP.GetDomesticFileName: string;
begin
   Result := 'seven_cty';
end;

function TContestSevenQP.GetFriendlyName: string;
begin
   Result := '7th Call Area QSO Party';
end;

function TContestSevenQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestSevenQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

(* AN ENTRANT IN THE 7TH AREA RECEIVES THE RST AND A STATE OR COUNTRY
   (RSTDomesticOrDXQTH); ANYONE ELSE THE RST, A NUMBER AND A COUNTY
   (RSTDomesticQTH) -- the two shapes
   DescribeSession chooses between, by the station test CountsDXMultiplier
   asks. M11 S9a. *)
function TContestSevenQP.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   if CountsDXMultiplier then
      begin
      Result := ExchangeFieldsRSTQTH;
      end
   else
      begin
      Result := ExchangeFieldsRSTQSONumberQTH;
      end;
end;

function TContestSevenQP.ParseReceivedExchangeFormat(const aText: string;
                                                     aParsers: TExchangeParsers;
                                                     var aExch: ContestExchange): boolean;
begin
   if CountsDXMultiplier then
      begin
      Result := aParsers.ParseRSTDomesticOrDXQTH(aText, aExch);
      end
   else
      begin
      Result := aParsers.ParseRSTDomesticQTH(aText, aExch);
      end;
end;

procedure TContestSevenQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   (* The station test the parse format chooses by: an entrant who
      receives the domestic-or-DX exchange gets no default messages
      (the old `case` had no arm for its shape). *)
   if not CountsDXMultiplier then
      begin
      aMessages.WriteRSTStateOrQSONumber;
      end;
end;

function TContestSevenQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestSevenQP.GetADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
begin
   (* WHAT THE CABRILLO SENT COLUMN SAYS (below): an entrant who counts DX
      sends its state, the others its state or DX. *)
   if CountsDXMultiplier then
      begin
      Result := ADIFSentRSTState(aMy, aQso);
      end
   else
      begin
      Result := ADIFSentRSTStateOrDX(aMy, aQso);
      end;
end;

function TContestSevenQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   if CountsDXMultiplier then
      begin
      Result := CabrilloSentRSTState(aMy, aQso, aCtx);
      end
   else
      begin
      Result := CabrilloSentRSTStateOrDX(aMy, aQso, aCtx);
      end;
end;

function TContestSevenQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   if CountsDXMultiplier then
      begin
      Result := CabrilloReceivedRSTQTHOrDXQTH(aMy, aQso, aCtx);
      end
   else
      begin
      Result := CabrilloReceivedRSTQTHDX(aMy, aQso, aCtx);
      end;
end;

function TContestSevenQP.GetInStateDomesticFileName: string;
begin
   Result := 'seven';
end;

function TContestSevenQP.GetQSOPartyArea: string;
begin
   Result := '7th area';
end;

function TContestSevenQP.GetFlags: TContestFlags;
begin
   (* NO cfVHFBandsEnabled since 2026-10-16 -- no VHF band is credited
      (UsesBand). *)
   Result := [cfQSOByBand, cfQSOByMode];
end;

function TContestSevenQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

function TContestSevenQP.GetIsUSQSOParty: boolean;
begin
   (* P: 10 -- the row indexes QSOParties, so set-up treats it as a
      QSO party (the in-state test, both domestic files). See the header for
      why it is nevertheless not on TContestStateQSOPartyBase. *)
   Result := True;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestSevenQP.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   if aStation.InHostState then
      begin
      aSession.Exchange := RSTDomesticOrDXQTHExchange;
      (* NO DX LIMIT HERE: D7's 20 went into a global nothing read. The
         sponsor's 10 is CombineWithMultipliers' (#88 round 3). *)
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestSevenQP.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + aStation.MyState;
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestSevenQP.CountsDXMultiplier: boolean;
begin
   Result := Station.InHostState;
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for an entrant inside the 7th area; none outside. This is
   the station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey and the
   country list ask the same predicate, so the answers cannot disagree. *)
function TContestSevenQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA, Canada, Hawaii and Alaska, for an entrant inside the 7th area (ARRLDXCCWithNoUSACanadaKH6OrKL7, which
   DescribeSession stated in state); none for anyone else. The key is
   uDXMultiplierKey's shared one (issue #136); WHO counts is this class's. *)
function TContestSevenQP.DXMultiplierKey(const aQso: ContestExchange;
                                         out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestSevenQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestSevenQP.UsesDomesticFile: boolean;
begin
   Result := True;
end;

(* A CALL'S /SUFFIX THAT THE DOMESTIC TABLE KNOWS IS A ROVER'S COUNTY, at
   every station, stripped live AND split on ADIF export. M11 S7 transcribed
   the strip from the session's RSTDomesticOrDXQTH (in state) or
   RSTDomesticQTH shape; NY4I's ruling on Q94 with Q90 (2026-10-14) made both
   every QSO party's answer: "yes QSO parties allow it". 7QP is a multi-state
   party on TContestBase, so it states them here rather than inheriting them
   from TContestStateQSOPartyBase. See TContestBase.StripsRoverCountyFromCall. *)
function TContestSevenQP.StripsRoverCountyFromCall: boolean;
begin
   Result := True;
end;

function TContestSevenQP.SplitsRoverCallOnExport: boolean;
begin
   Result := True;
end;

(* OUT OF THE HOST STATE ONE ENTRY MAY CARRY SEVERAL QTHs (RSTDomesticQTH);
   in it, not (RSTDomesticOrDXQTH) -- M11 S7, 2026-10-14. It was the
   session's shape, and this is the station test DescribeSession chooses the
   shape by; see TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestSevenQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := not CountsDXMultiplier;
end;

const
   (* THE EIGHT 7TH-AREA STATES -- the first two letters of a seven_cty.dom
      county key. This class's own copy (design 1.4); IN7QPNE keeps its. *)
   SEVENQP_COUNTY_STATES = ' AZ ID MT NV OR UT WA WY ';

function TContestSevenQP.ADIFCountyState(const aQso: ContestExchange): string;
var
   key: string;
   state: string;
begin
   Result := '';
   key := UpperCase(ADIFPartyQTHKey(aQso));
   if Length(key) = 5 then
      begin
      state := Copy(key, 1, 2);
      if Pos(' ' + state + ' ', SEVENQP_COUNTY_STATES) > 0 then
         begin
         Result := state;
         end;
      end;
end;

function TContestSevenQP.ADIFWorkedStationState(const aQso: ContestExchange): string;
begin
   Result := ADIFStateOfPartyQSO(ADIFCountyState(aQso), aQso);
end;

initialization
   RegisterContest(SEVENQP, TContestSevenQP);

end.
