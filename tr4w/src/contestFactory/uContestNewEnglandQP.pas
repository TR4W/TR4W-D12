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

(* THE NEW ENGLAND QSO PARTY.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 10;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: OnePhoneTwoCW;
   ADIFName: '';  CABName: '';
   FriendlyName: 'New England QSO Party'

  Blank CABName and ADIFName resolved to the enum's spelling, 'NEQP'.

  RENAMED 2026-10-16 (NY4I, design Q105). 'NEQP' is too close to
  NE-QSO-PARTY, the Nebraska QSO Party (uContestNebraskaQP), so:

    TR4W name (ContestTypeSA)  NEWEQP -- DXLog's name for this contest.
                               'NEQP' stays a permanent READ alias
                               (uContestNames.LEGACY_CONTEST_NAMES): every
                               older .cfg and contest log says it.
    Cabrillo CONTEST:          NEWE-QSO-PARTY -- what DXLog's NEWEQP.txt
                               writes; WA7BNM ref 10 lists NEQP first and
                               NEWE-QSO-PARTY as an accepted alias.
    ADIF CONTEST_ID            NEQP, UNCHANGED -- the ADIF 3.1.7 enumeration's
                               New England value (Nebraska is NE-QSO-PARTY).
                               Stated here: the enum spelling it used to fall
                               back to is NEWEQP now.

  BANDS (NY4I, 2026-10-16, from the four parties' rules): 80, 40, 20, 15 and
  10 m -- no 160, no WARC, no VHF. UsesBand states them; a QSO anywhere else
  is logged, scores 0 and earns no multiplier (design 7.4).

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  NOT A STATE QSO PARTY. It is a MULTI-STATE party -- six states -- and its
  row carries no QSOParties index (P: 0), so set-up never ran the party head
  for it, and TContestStateQSOPartyBase's one-host-state rules (the
  out-of-state refusal, the county line) were never applied. It sits on
  TContestBase and keeps exactly that. Whether a multi-state party wants a
  base of its own is a design question recorded in the design doc (M7b),
  not answered here.

  THE SPONSOR'S RULES, READ 2026-10-23 (neqp.org/rules and the neqp.org FAQ
  NY4I supplied). A current rule stated outright overrides D7 (NY4I's
  standing rule), and six of them changed this class that day:

    * POINTS: "Count one point per phone QSO, and two points per CW
      (includes digital modes) QSO." CW 2, DIGITAL 2 (it was 1, the
      OnePhoneTwoCW row's `else`), phone 1, and FM 1 as phone -- it was 1
      and the rule's phone covers it. Three numbers per mode cannot say
      "digital with CW, FM with phone", so CalculateQSOPoints states it
      itself (uContestFixedPoints' own advice).
    * NO DX MULTIPLIER CAP: "DXCC countries (not USA) as multipliers" -- no
      limit stated. DescribeSession stated DXMultLimit := 20 (D7's arm) and
      no longer states one. (That limit has no reader in the engine, here or
      in D7 -- only the contest matrix prints it -- so the cap never applied;
      the statement is removed so the class says what the sponsor says.)
    * FOURTEEN PROVINCES: "Canadian provinces (14 -- VO1/VO2 are
      separate)". neqsow1.dom includes P14.DOM (Nf = VO1, Lb = VO2) where it
      included P13.DOM (one Nl for both).
    * DC IS MARYLAND: "states(50) (Count DC as MD)". neqsow1.dom maps DC to
      the Md multiplier on a line of its own (Dc > Md), BEFORE the shared
      S50.DOM -- which other contests read, and which knows no DC.
    * DUPES: "the same station can be contacted on CW and SSB on each band
      for QSO points (digital QSOs are considered the same as CW)" (FAQ).
      DupeModeOf answers CW for Digital; QSOs still count by band and by
      mode (GetFlags), so a digital QSO is a dupe of a CW QSO on its band.
    * ROVERS: "Mobiles that change counties are considered to be new
      stations" and "can be worked for both multiplier and QSO Point
      credit"; "County line QSOs should be logged as two separate QSOs".
      DupeKeyIncludesReceivedQTH answers True, as every single-state party
      has since Q118: the same call from another county is a new QSO, the
      same call and county on the same band and mode is a dupe. It was the
      call alone, so a rover logged under its bare call from a new county --
      and the second QSO of a county-line pair -- was a dupe. Multipliers
      still count once each (the sheet, not the dupe key, decides those).

  CONFIRMED UNCHANGED THE SAME DAY: multipliers count once per contest
  (no cfMultByBand / cfMultByMode); Alaska and Hawaii are states and the DX
  key leaves out the USA, Canada, KH6 and KL7; an entrant outside New England
  counts the 68 counties of NEQSO (Connecticut's nine planning regions).

  SET-UP, both branches stated. A NEW ENGLAND STATION is one whose MY STATE
  begins with ME, NH, VT, MA, CT or RI -- a string comparison of the first
  two characters, D7's rule, as M2 restored it (inventory defect #3: the
  PWORD read never matched, and crashed on an empty MY STATE). It loads
  NEQSOW1, sends RST and its county or DX, and counts DXCC without
  W/VE/KH6/KL7. Everyone else loads NEQSO and sends RST and a county. K, VE,
  KH6 and KL are domestic for both. *)
unit uContestNewEnglandQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestNewEnglandQP = class(TContestBase)
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
   public
      (* 80 to 10 m without WARC -- the header. *)
      function UsesBand(aBand: BandType): boolean; override;
   protected
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* DIGITAL IS A DUPE OF CW -- see TContestBase.DupeModeOf and the
         header (the FAQ, 2026-10-23). *)
      function DupeModeOf(aMode: ModeType): ModeType; override;
      (* A MOBILE IN A NEW COUNTY IS A NEW STATION -- the received QTH is
         part of the dupe key, as on every single-state party since Q118.
         See TContestBase.DupeKeyIncludesReceivedQTH and the header (the
         sponsor, 2026-10-23). *)
      function DupeKeyIncludesReceivedQTH: boolean; override;
   private
      (* Does MY STATE begin with one of the six New England states? *)
      class function IsNewEnglandState(const aMyState: string): boolean;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
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
      (* A STATION OUTSIDE NEW ENGLAND WORKS ONLY NEW ENGLAND STATIONS --
         Q107 (NY4I, 2026-10-16), the rule he gave for "qso parties in
         general" (Q29, 2026-10-15). Until Q107 this multi-state party was
         never held to it (the header): out of New England its exchange
         shape already refused a QTH NEQSO does not know, so typing barely
         changes, but a logged QSO -- imported, networked, rescored -- scored
         whoever it was with.

         THE SAME PREDICATE AS EVERY STATE PARTY, uContestBase.
         HostAreaRuleCredits, with this contest's own in-area answer: the
         MY STATE test DescribeSession chooses the file by
         (CountsDXMultiplier -- this is not a US state party, so set-up's
         Station.InHostState is always False here). Out of New England the
         table is NEQSO, the six states' counties. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
      (* THE ROVER COUNTY -- see TContestBase.StripsRoverCountyFromCall (M11 S7)
         and SplitsRoverCallOnExport (Q90/Q94). *)
      function StripsRoverCountyFromCall: boolean; override;
      function SplitsRoverCallOnExport: boolean; override;
      (* SEVERAL QTHs FROM ONE ENTRY -- see TContestBase.LogsSeveralQTHsFromOneEntry (M11 S7). *)
      function LogsSeveralQTHsFromOneEntry: boolean; override;
      (* THE WORKED STATION'S ADIF STATE -- see TContestBase.ADIFCountyState
         and ADIFWorkedStationState (Q76/Q89, NY4I 2026-10-16). Both of this
         contest's county files (NEQSO, NEQSOW1) key a county five letters,
         the state FIRST and then the county (MEAnd, VTAdd, CTCap) -- the
         sponsor's spelling and in7qpne_cty.dom's, since Q81 (2026-10-17;
         it was county first, AndME, with Connecticut's eight old counties).
         A typed alias may be shorter (NEQSOW1's AD) or the old county-first
         spelling (ANDME), which is why the key is read, not the text. No
         CNTY: WritesADIFCounty stays False, as before. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function ADIFWorkedStationState(const aQso: ContestExchange): string; override;
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
   uTR4WStrings,
   (* SExchangeOutOfStateWorksHostOnly -- the host-area refusal (Q107). *)
   uAppStrings;

const
   (* The area the host-area refusal names. *)
   NEQP_HOST_AREA = 'New England';

(* THE HOST-AREA RULE, BOTH SIDES -- see the declaration (Q107). *)
function TContestNewEnglandQP.ParseReceivedExchange(const aText: string;
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
      aErrorMessage := Format(SExchangeOutOfStateWorksHostOnly, [NEQP_HOST_AREA]);
      end;
end;

function TContestNewEnglandQP.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   Result := HostAreaRuleCredits(CountsDXMultiplier,
                                 string(aQso.QTHString),
                                 Station.IsDomesticQTH);
end;

(* "two points per CW (includes digital modes) QSO", one per phone QSO --
   the sponsor, 2026-10-23 (the header). FM is phone; anything else (no
   mode recorded) scores the phone point, as the old row's `else` did. *)
procedure TContestNewEnglandQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   case aQso.Mode of
      CW, Digital:
         begin
         aQso.QSOPoints := 2;
         end;
      else
         begin
         aQso.QSOPoints := 1;
         end;
      end;
end;

(* DIGITAL IS CW FOR DUPES -- the FAQ, 2026-10-23 (the header). Every other
   mode is its own. *)
function TContestNewEnglandQP.DupeModeOf(aMode: ModeType): ModeType;
begin
   if aMode = Digital then
      begin
      Result := CW;
      end
   else
      begin
      Result := aMode;
      end;
end;

(* THE ROVER RULE -- "Mobiles that change counties are considered to be new
   stations", 2026-10-23 (the header). At both kinds of entrant: the
   received QTH, whatever it names, joins the call in the dupe key. *)
function TContestNewEnglandQP.DupeKeyIncludesReceivedQTH: boolean;
begin
   Result := True;
end;

class function TContestNewEnglandQP.IsNewEnglandState(const aMyState: string): boolean;
var
   state: string;
begin
   state := Copy(aMyState, 1, 2);
   Result := (state = 'ME') or
             (state = 'NH') or
             (state = 'VT') or
             (state = 'MA') or
             (state = 'CT') or
             (state = 'RI');
end;

function TContestNewEnglandQP.GetDisplayName: string;
begin
   Result := 'New England QSO Party';
end;

function TContestNewEnglandQP.GetCabrilloName: string;
begin
   (* NEWE-QSO-PARTY since 2026-10-16 (Q105) -- see the header. It was
      'NEQP', the enum spelling the row's blank CABName resolved to. *)
   Result := 'NEWE-QSO-PARTY';
end;

function TContestNewEnglandQP.GetADIFContestId: string;
begin
   (* ADIF 3.1.7's New England value, and what every TR4W export of this
      contest has written since M1 -- so old exports still import here.
      Stated, not the enum spelling: that is NEWEQP now (Q105). *)
   Result := 'NEQP';
end;

function TContestNewEnglandQP.GetWA7BNMId: integer;
begin
   Result := 10;
end;

function TContestNewEnglandQP.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestNewEnglandQP.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestNewEnglandQP.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestNewEnglandQP.GetFriendlyName: string;
begin
   Result := 'New England QSO Party';
end;

function TContestNewEnglandQP.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestNewEnglandQP.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

(* AN ENTRANT IN NEW ENGLAND RECEIVES THE RST AND A STATE, PROVINCE OR
   COUNTRY (RSTDomesticOrDXQTH); ANYONE ELSE THE RST, A NUMBER AND A
   COUNTY (RSTDomesticQTH) -- the two shapes
   DescribeSession chooses between, by the station test CountsDXMultiplier
   asks. M11 S9a. *)
function TContestNewEnglandQP.GetReceivedExchangeFields: ExchangeInformationRecord;
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

function TContestNewEnglandQP.ParseReceivedExchangeFormat(const aText: string;
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

procedure TContestNewEnglandQP.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   (* The station test the parse format chooses by: an entrant who
      receives the domestic-or-DX exchange gets no default messages
      (the old `case` had no arm for its shape). *)
   if not CountsDXMultiplier then
      begin
      aMessages.WriteRSTStateOrQSONumber;
      end;
end;

function TContestNewEnglandQP.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestNewEnglandQP.GetADIFSentExchange(const aMy: TMyStationExchange;
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

function TContestNewEnglandQP.GetCabrilloSentExchange(const aMy: TMyStationExchange;
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

function TContestNewEnglandQP.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
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

function TContestNewEnglandQP.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode];
end;

function TContestNewEnglandQP.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band80, Band40, Band20, Band15, Band10];
end;

function TContestNewEnglandQP.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestNewEnglandQP.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   if IsNewEnglandState(aStation.MyState) then
      begin
      aSession.DomesticFile := 'NEQSOW1';
      aSession.Exchange := RSTDomesticOrDXQTHExchange;
      end
   else
      begin
      aSession.DomesticFile := 'NEQSO';
      aSession.Exchange := RSTDomesticQTHExchange;
      end;

   (* NO DXMultLimit: the sponsor sets no cap (2026-10-23, the header). D7's
      arm stated 20 here. *)
   aSession.AddDomesticCountries(DomesticCountriesKVEKH6KL);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts. *)
procedure TContestNewEnglandQP.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NEWENGLAND);
   aPrompts.AskFieldWithCommentWhenInside(TC_NEWENGLANDSTATEABREVIATION, ncfMyState);
end;

(* THE STATION TEST -- DescribeSession's, asked of Station. See the declaration. *)
function TContestNewEnglandQP.CountsDXMultiplier: boolean;
begin
   Result := IsNewEnglandState(Station.MyState);
end;

(* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4 part 2,
   2026-10-14. Yes for an entrant in New England; none for anyone else. This
   is the station test the session's DX kind was chosen by (the trait, then
   DescribeSession) until that kind was deleted; DXMultiplierKey and the
   country list ask the same predicate, so the answers cannot disagree. *)
function TContestNewEnglandQP.HasDXMultiplier: boolean;
begin
   Result := CountsDXMultiplier;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country but the USA, Canada, Hawaii and Alaska, for an entrant in New England (ARRLDXCCWithNoUSACanadaKH6OrKL7, which
   DescribeSession stated there); none for anyone else. The key is
   uDXMultiplierKey's shared one (issue #136); WHO counts is this class's. *)
function TContestNewEnglandQP.DXMultiplierKey(const aQso: ContestExchange;
                                              out aKey: DXMultiplierString): boolean;
begin
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(CountsDXMultiplier, aQso, aKey);
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only where the entrant counts the DX multiplier; the CQ list
   for anyone else, who counts none. *)
function TContestNewEnglandQP.CountryMode: CountryModeType;
begin
   Result := DXCCCountryMode(CountsDXMultiplier);
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestNewEnglandQP.UsesDomesticFile: boolean;
begin
   Result := True;
end;

(* A CALL'S /SUFFIX THAT THE DOMESTIC TABLE KNOWS IS A ROVER'S COUNTY, at
   every station, stripped live AND split on ADIF export. M11 S7 transcribed
   the strip from the session's RSTDomesticOrDXQTH (in New England) or
   RSTDomesticQTH shape; NY4I's ruling on Q94 with Q90 (2026-10-14) made both
   every QSO party's answer: "yes QSO parties allow it". NEQP is a
   multi-state party on TContestBase, so it states them here rather than
   inheriting them from TContestStateQSOPartyBase. See
   TContestBase.StripsRoverCountyFromCall. *)
function TContestNewEnglandQP.StripsRoverCountyFromCall: boolean;
begin
   Result := True;
end;

function TContestNewEnglandQP.SplitsRoverCallOnExport: boolean;
begin
   Result := True;
end;

(* OUTSIDE NEW ENGLAND ONE ENTRY MAY CARRY SEVERAL QTHs (RSTDomesticQTH);
   inside it, not (RSTDomesticOrDXQTH) -- M11 S7, 2026-10-14. It was the
   session's shape, and this is the station test DescribeSession chooses the
   shape by; see TContestBase.LogsSeveralQTHsFromOneEntry. *)
function TContestNewEnglandQP.LogsSeveralQTHsFromOneEntry: boolean;
begin
   Result := not CountsDXMultiplier;
end;

const
   (* THE SIX NEW ENGLAND STATES -- the FIRST two letters of a county key of
      NEQSO / NEQSOW1 since Q81 (2026-10-17), which spells a county state
      first as the sponsor does (MEAND, CTCAP); it was the last two while
      the files spelled it county first (ANDME). This class's own copy
      (design 1.4). *)
   NEQP_COUNTY_STATES = ' CT MA ME NH RI VT ';

function TContestNewEnglandQP.ADIFCountyState(const aQso: ContestExchange): string;
var
   key: string;
   state: string;
begin
   Result := '';
   key := UpperCase(ADIFPartyQTHKey(aQso));
   if Length(key) = 5 then
      begin
      state := Copy(key, 1, 2);
      if Pos(' ' + state + ' ', NEQP_COUNTY_STATES) > 0 then
         begin
         Result := state;
         end;
      end;
end;

(* VO1 AND VO2 ARE TWO MULTIPLIERS BUT ONE ADIF PROVINCE. Since 2026-10-23
   neqsow1.dom includes P14.DOM, whose keys are Nf (VO1) and Lb (VO2); ADIF's
   Canadian list has neither, only NL, which P13's single key was. So either
   half writes NL, when the worked station is Canadian. *)
function TContestNewEnglandQP.ADIFWorkedStationState(const aQso: ContestExchange): string;
var
   key: string;
begin
   key := UpperCase(ADIFPartyQTHKey(aQso));
   if (key = 'NF') or (key = 'LB') then
      begin
      Result := '';
      if IsADIFPrimarySubdivision(string(aQso.QTH.CountryID), 'NL') then
         begin
         Result := 'NL';
         end;
      Exit;
      end;
   Result := ADIFStateOfPartyQSO(ADIFCountyState(aQso), aQso);
end;

initialization
   RegisterContest(NEWENGLANDQSO, TContestNewEnglandQP);

end.
