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

  SCORING: TwoPhoneThreeCW -- 3 on CW, 2 otherwise.

  SET-UP: an in-state station (FoundContest's own in-state answer,
  aStation.InHostState -- the arm asked FoundMyStateInDomFile again, which
  is the same question on the same data) sends RST and its county or DX
  and counts DXCC without W/VE/KH6/KL7, at most 20; everyone else sends RST
  and a county. LogCfg's CQ exchange: 5NN and MY STATE. *)
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
   public
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
   (* FixedModePoints -- the helper for a number per mode. *)
   uContestFixedPoints;

procedure TContestSevenQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 3, 2, 2);
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
   Result := ADIFSentRSTState(aMy, aQso);
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
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
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
      aSession.DXMultLimit := 20;
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
   DescribeSession stated in state); none for anyone else. *)
function TContestSevenQP.DXMultiplierKey(const aQso: ContestExchange;
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
function TContestSevenQP.CountryMode: CountryModeType;
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
