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

(* THE CONTEST FACTORY -- ONE CLASS PER CONTEST, AS THE RADIO FACTORY IS ONE
  CLASS PER RADIO.

  NY4I: "a contest factory to go along with the radio factory we already have",
  and from CLAUDE.md: "we want to do this once. Refactoring is not as important
  a factor as getting the object model correct."

  WHY THE UNIT IS A CONTEST AND NOT A STRATEGY ENUM. TR4W decomposed a
  contest into strategy enums -- QSOPointMethodType (deleted at M10 S4),
  ExchangeType, DXMultType (deleted at M11 S4), PrefixMultType (deleted at
  M11 S3), ZoneMultType (deleted at M11 S5) --
  each dispatched by
  its own `case`, and it would have been less work to turn each enum into a
  class. That is the wrong object model for this program:

    A CONTEST IS THE THING THAT EXISTS. An operator selects ARRL-DX-CW, not a
    point method. ContestsArray is already a row per contest; the enums are how
    that row is currently SPELLED, not what it is.

    THE ENUMS DO NOT COMPOSE CLEANLY. The legacy CalculateQSOPoints branched
    on the point method and then, inside several arms, on Contest anyway --
    because scoring depends on things the enum does not carry. Splitting by
    enum keeps that second branch; splitting by contest removes it.

    A NEW CONTEST WOULD STILL TOUCH SHARED FILES. Adding a radio touches its own
    unit, tr4w.lpr and the test .lpr -- verified when TCI was added. That is the
    property worth copying, and only one-class-per-contest gives it.

  INHERITANCE CARRIES THE FAMILIES. ARRL DX, ARRL Sweepstakes and Field Day
  share far more with each other than with CQ WW, and QSO parties share almost
  everything. Those are base classes, and a contest overrides what it actually
  differs in.

  THE RULE THE RADIO FACTORY LEARNED THE HARD WAY APPLIES HERE UNCHANGED:
  A BASE CLASS MUST NEVER ASK WHICH CONTEST IT IS. The subclass declares the
  trait; the base guards on the trait. Three defects in one afternoon had the
  shape `if RadioModel in [FT857, FT897]`, and `if Contest = ...` inside a base
  would be the same mistake with different nouns.

  STRANGLER, NOT REWRITE -- the pattern CLAUDE.md names for both existing
  factories: "thin adapters over the existing globals first, prove the seam on
  hardware, then delete the legacy path". A contest that has no class here falls
  through to the legacy `case` untouched, so the two can coexist for as long as
  it takes, and the golden corpus proves each move byte for byte. *)
unit uContestBase;

{$I tr4w.inc}

interface

uses
   (* tCategoryPower, the entrant's CATEGORY-POWER -- see TStationContext.
      FIRST, so that VC's names win anywhere the two units overlap. The type is
      the settings model's own enum rather than a copy here: a second
      HIGH/LOW/QRP list would be a second definition, free to drift. *)
   uSettingsModel,
   VC;

const
   (* THE SHAPE OF ONE QSO: LINE IN A CABRILLO FILE, for every contest that has
      not said otherwise.

      The five arguments, in order: the frequency/mode/date/time prefix already
      assembled by PostUnit, our sent exchange, the worked callsign, the
      received exchange, and the multi-op transmitter flag.

      IT IS DECLARED HERE, ONCE, AND ONLY THE BASE RETURNS IT. Since M4 PostUnit
      asks every contest -- uContestRegistry.ContestIdentity answers a
      classless one with a plain TContestBase -- so no second copy of the
      layout exists anywhere to drift. *)
   CabrilloQSOLineFormatDefault = '%s%s%-15s%-10s %-5s' + #13#10;

   (* THE DOMESTIC-COUNTRY GROUPS SEVERAL CONTESTS NAME -- M7a, 2026-10-02.

      DATA, STATED ONCE, AND READ BY TWO SIDES: a class's DescribeSession
      passes one to TSessionDefaults.AddDomesticCountries, and FCONTEST's
      Add_KVE / Add_KVEKH6KL / AddARRLSectionDomesticCountries /
      AddRussianDomesticCountrys -- which the classless arms and the QSO-party
      head still call -- loop over the same constant. Before M7a each group
      was written once, in FCONTEST; a copy here would have been a second
      list free to drift from the first. The order is the order they are
      added, which is the order the domestic-country list holds them. *)
   DomesticCountriesKVE: array[0..1] of string = ('K', 'VE');
   DomesticCountriesKVEKH6KL: array[0..3] of string = ('K', 'VE', 'KH6', 'KL');

   (* K, VE, KH6 and KL, then every other US possession that has an ARRL
      section -- the Field Days' and Sweepstakes' domestic countries. *)
   DomesticCountriesARRLSections: array[0..19] of string = (
      'K', 'VE', 'KH6', 'KL',
      'KC6', 'KG4', 'KH0', 'KH1', 'KH2', 'KH3', 'KH4', 'KH5', 'KH7', 'KH8',
      'KH9', 'KP1', 'KP2', 'KP3', 'KP4', 'KP5');

   (* European and Asiatic Russia and the two Russian islands with their
      own country entry. *)
   DomesticCountriesRussia: array[0..4] of string = ('UA', 'UA2', 'UA9', 'R1FJ', 'R1MV');

type
   (* ONE OF THE FOUR `QSO POINTS ...` OVERRIDES -- QSO POINTS DOMESTIC CW and
      its three siblings: a fixed point value the OPERATOR states, which
      replaces the contest's own rule for the QSOs it matches.

      STATED IS A FIELD, NOT A SENTINEL VALUE. The setting itself says "not
      stated" with -1 (uSettingsModel.TQsoPoints), and copying that here would
      make the record's ZERO value mean "every QSO scores 0" -- so a test, or
      anything else, that FillChars a TStationContext would silently score
      every QSO zero. With a Stated flag the zero value is "no override",
      which is what every contest did with no such line in its .cfg. *)
   TQSOPointOverride = record
      Stated: boolean;
      Points: integer;
   end;

   (* THE FOUR, matched on mode (CW or phone) and on whether the QSO carries a
      domestic QTH. FM and digital match none of them -- that is the engine's
      rule as it has always been written, and it is reproduced, not
      corrected. *)
   TQSOPointOverrides = record
      DomesticCW: TQSOPointOverride;
      DXCW: TQSOPointOverride;
      DomesticPhone: TQSOPointOverride;
      DXPhone: TQSOPointOverride;
   end;

   (* IS THIS CALLSIGN IN ONE OF THE SESSION'S DOMESTIC COUNTRIES? -- a CTY.DAT
      lookup of the call against the domestic-country list set-up built
      (ZoneCont.DomesticCountryCall). A SERVICE the station context carries,
      M7b (2026-10-02), the same shape M5b's parse session hands its engine
      services in: the contest reads no global, and a test hands it a stub.
      ARRL 160's scoring is the first rule that asks. *)
   TDomesticCountryCallTest = function(const aCall: string): boolean;

   (* MY CQ ZONE, RESOLVED -- design 7.12 -- as a SERVICE, 2026-10-14.

      THE STATED ZONE IF THERE IS ONE, ELSE THE CQ ZONE CTY.DAT GIVES MY
      CALL. "Stated" is the contest's override (New Contest, its .cfg, its
      log) or the station's own MY ZONE when the operator typed one. 0 when
      neither can answer.

      WHY IT IS NOT TStationContext.MyZone. That field is MY ZONE resolved,
      and when nobody stated a zone FCONTEST derives it from MY CALL in the
      CONTEST'S zone mode -- so in an ITU-zone contest it is the ITU zone
      (measured in the contest matrix: K0AAA, VE3AAA and DL1AAA carry MY ZONE
      7, 4 and 28 in the UA4W Championship, where their CQ zones are 4, 4 and
      14). IARU relies on exactly that. A rule that needs the CQ zone in an
      ITU-mode contest cannot read MyZone.

      A SERVICE, NOT A VALUE, because the station context is rebuilt on every
      ActiveContest request and the CTY lookup is needed by one rule of one
      contest, on one branch. The UA4W Championship is its first reader. *)
   TMyCQZoneQuery = function: integer;

   (* Does the session's domestic QTH table know this QTH? The table the
      engine loaded for this contest and this station -- for a state QSO
      party's out-of-state station, the host's county file. Handed to a
      contest twice, by the same engine function (LOGDUPE.
      DomesticTableKnowsQTH): in TReceivedExchangeSession when an exchange
      is typed, and in TStationContext when a logged QSO is scored (Q107),
      so the two can never answer differently. *)
   TDomesticQTHTest = function(const aQTH: string): boolean;

   (* WHICH SHEET A "NEW MULTIPLIER" QUESTION IS ASKED OF. *)
   TNewMultiplierKind = (nmkDomestic, nmkDX);

   (* IS THIS QSO'S MULTIPLIER STILL UNWORKED ANYWHERE? -- design 7.13 (NY4I,
      2026-10-13: "All multipliers are based on what was worked before").

      READ-ONLY. The engine answers from the shared multiplier sheet; the
      contest never writes the sheet and never reads the log.

      ANYWHERE MEANS THE SHEET'S ALL-BAND, BOTH-MODE ROW -- not the session's
      by-band or by-mode key. That is RSGB 1.8 MHz's legacy reading, which
      asked mo.IsDmMult / mo.IsDXMult with AllBands and Both, and it is
      transcribed exactly. nmkDomestic asks of aQso.DomMultQTH (with the
      session's domestic multiplier kind), nmkDX of aQso.QTH.Country. An empty
      domestic QTH is "new" to the sheet -- the rule must test for it first,
      as the legacy arm did. *)
   TNewMultiplierQuery = function(const aQso: ContestExchange;
                                  aKind: TNewMultiplierKind): boolean;

   (* WHAT SCORING KNOWS ABOUT US.

      Contest rules are a function of two things: the QSO, and the station
      making it. The QSO arrives as a parameter; this is the other half.

      IT IS A SNAPSHOT, NOT A VIEW OF THE GLOBALS, and that is the point. MyCountry
      and its neighbours live in LOGWIND, PostUnit and elsewhere -- read them
      directly and every one of ~200 contest classes acquires a dependency on the
      display layer and cannot be tested without booting the program. Taken once,
      here, they become data a test can construct.

      IT GROWS AS CONTESTS ARE MOVED. Adding a field is adding one line here and
      one in Refresh; guessing at every field 88 point methods might want, before
      moving them, would be inventing a structure to fit code nobody has read
      yet. *)
   TStationContext = record
      MyCountry: CallString;
      MyContinent: ContinentType;

      (* THE ZONE AS AN INTEGER, converted once here rather than at each use.

         MyZone is a STRING global, and the scoring arms that want it all
         call `Val(MyZone, MyZoneValue, Result)` and compare the result. Doing that per QSO
         in every contest that scores by zone is the sort of repetition that
         eventually disagrees with itself -- and a Val whose error code nobody
         reads is a 0 that looks like zone 0.

         MyZoneValid says whether the conversion worked, so a contest can tell
         "zone 0" from "no zone set" instead of scoring against a silent 0.

         THIS IS MY ZONE, RESOLVED -- design 7.12: the contest's override if
         it stated one (New Contest, its .cfg, its log), else the station's
         MY ZONE -- which is the operator's stated zone, or the zone CTY.DAT
         gives MY CALL IN THE CONTEST'S ZONE MODE. So in an ITU-zone contest
         an unstated zone is the ITU zone, and IARU compares it with the
         worked ITU zone. It is NOT always the CQ zone, whatever 7.12 first
         said: a rule that needs MY CQ ZONE asks MyCQZone below (2026-10-14,
         the UA4W Championship). A class never asks CTY.DAT itself. *)
      MyZone: integer;
      MyZoneValid: boolean;

      (* THE OPERATOR'S OWN MAIDENHEAD GRID.

         Added when ARRL-DIGI moved, which is the growth rule this record's
         header states: a field arrives with the first contest that needs it,
         not in advance. Distance scoring is a function of BOTH grids, and only
         one of them is on the QSO. *)
      MyGrid: string;

      (* THE ENTRANT'S OWN POWER CATEGORY -- Cabrillo CATEGORY-POWER.

         Added when Idaho's QRP rule moved (2026-10-01), by the same growth
         rule. NY4I: "qrp means our power. You can get that from the cabrillo
         fields in the new contest dialog." The New Contest dialog applies its
         CATEGORY-POWER choice as a command, which the settings model aliases
         to Contest.CategoryPower, so uContestFactory.CurrentStation reads it
         from there -- the same value Stew Perry's legacy arm already reads.
         Since M9b (design 7.6) it is the ONLY value: the Cabrillo summary
         window's CATEGORY-POWER row writes this setting too, and a change
         with QSOs logged rescores (uCategoryPowerChange).

         The zero value is cpHIGH, so a test that FillChars this record scores
         as a high-power entrant, which is what every contest did before this
         field existed. *)
      MyPower: tCategoryPower;

      (* THE FOUR `QSO POINTS ...` OVERRIDES the operator has stated.

         Added at M3 (2026-10-01), when ScoreQSO became the one scoring entry
         point: the overrides run INSIDE it, between the band check and the
         contest's rule, so the class must be handed them -- the base never
         reads a global. They are the station's statement, not the contest's,
         which is why they arrive here and not as a class trait.

         The zero value states none of them; see TQSOPointOverride. *)
      PointOverrides: TQSOPointOverrides;

      (* THE STATION'S OWN STATE, PROVINCE OR ISLAND -- MY STATE, as text.

         Added at M4 (2026-10-01), when the RSGB IOTA contest and the PCC
         gained classes: both score against it (IOTA compares it with the
         worked island; PCC asks whether it is all digits). Same growth rule
         as every field here. '' when unset, which both rules test for.

         SINCE M9a (2026-10-02) IT IS THE STATE THE SESSION SENDS --
         FCONTEST.SentMyState, which is MY STATE unless the contest's set-up
         stated another (TSessionDefaults.SentState, design 7.11). Set-up
         used to write that value into MY STATE and this read it back, so
         every rule sees exactly what it saw. *)
      MyState: string;

      (* THE CONTEST TITLE the operator's session carries -- Settings.Contest.
         Title, usually '<year> <name> <call>'.

         Added at M4 for the Batavia FT8 contest, whose legacy arm tests it
         for 'YBDXDI-FT8'. Recorded in the inventory (D7) as a test that
         cannot match with default settings; it is transcribed, not judged. *)
      ContestTitle: string;

      (* THE STATION'S OWN CALLSIGN -- MY CALL.

         Added at M5b (2026-10-02) for the UA4W Championship, whose scoring
         asks which Russian oblast the station's own call is in; that class
         was built on 2026-10-14. Same growth rule as every field here. *)
      MyCall: string;

      (* IS THE STATION IN THE QSO PARTY'S HOST STATE? -- M5b.

         FCONTEST.FoundContest decides it once, as it opens a state QSO party
         (MY STATE is a key of the host's county file), and loads the
         in-state or the out-of-state domestic file by the answer. This is
         that same answer, so the rule a party applies to an exchange and the
         table the exchange was looked up in can never disagree. False for a
         contest that is not a state party, and for a station with no MY
         STATE -- an operator with no state is in nobody's state.

         NY4I, 2026-10-02 (design 7.10): an out-of-state station may work
         only host-state stations. TContestStateQSOPartyBase reads this. *)
      InHostState: boolean;

      (* THE ENTRANT'S OWN MODE CATEGORY -- Cabrillo CATEGORY-MODE.

         Added at M6 (2026-10-02) for the Salmon Run's W7DX bonus, by the
         same growth rule: "A single-mode entry ... may claim the 500-point
         bonus only once", and "contacts on modes other than the mode of
         entry may not be counted for ... bonus credit". It is read from
         Settings.Contest.CategoryMode, the value the Cabrillo header
         writes, so the score and the category the log declares cannot
         disagree.

         THE ZERO VALUE IS cmCW, NOT "UNSTATED" -- the setting has no unstated
         state, and an operator who never chooses one exports CATEGORY-MODE:
         CW. A rule that reads this must say what it does with cmCW. *)
      MyCategoryMode: tCategoryMode;

      (* THE REST OF THE STATION'S OWN EXCHANGE -- MY NAME, MY FD CLASS, MY
         SECTION, MY PREC and MY CHECK, as text.

         Added at M7a (2026-10-02), when FCONTEST.FoundContest's arms moved
         into DescribeSession: those arms build the CW exchange messages and
         memories out of them (the Field Days' class and section,
         Sweepstakes' precedence and check, the sprints' name). Same growth
         rule as every field here. '' when unset. *)
      MyName: string;
      MyFDClass: string;
      MySection: string;
      MyPrec: string;
      MyCheck: string;

      (* MY ZONE AS THE SETTING HOLDS IT -- the text, not MyZone's integer.

         Added at M7a for CQExchangeDefault: the default CQ exchange LogCfg
         built put the setting's TEXT into the message, and '05' is not '5'.
         A rule that compares zones reads MyZone; one that SENDS the zone
         reads this. *)
      MyZoneText: string;

      (* THE SESSION'S CONTEST NAME -- Settings.Contest.Name, as set-up and the
         operator's CONTEST NAME line left it.

         Added at M7b (2026-10-02) for the European VHF contest, whose legacy
         arm measures to the QSO's whole QTH when the name is 'EURASIA' -- an
         event with no ContestType of its own (inventory D7, design Q8).
         Transcribed, not judged. *)
      ContestName: string;

      (* IS A CALL IN THE SESSION'S DOMESTIC COUNTRIES? -- a SERVICE, M7b.
         See TDomesticCountryCallTest. uContestFactory.CurrentStation supplies
         the engine's CTY lookup; the zero value (nil) is "no service", which a
         rule must answer as the engine answers an empty list -- not
         domestic. ARRL 160 is its first reader. *)
      IsDomesticCountryCall: TDomesticCountryCallTest;

      (* MY CQ ZONE, RESOLVED -- a SERVICE, 2026-10-14. See TMyCQZoneQuery.
         uContestFactory.CurrentStation supplies the engine's answer; the
         zero value (nil) is "no service", which a rule answers as zone 0 --
         what CTY.DAT gives a call it cannot place. *)
      MyCQZone: TMyCQZoneQuery;

      (* IS THIS QSO A NEW MULTIPLIER ON THE SHEET? -- a READ-ONLY SERVICE,
         design 7.13 (2026-10-14). See TNewMultiplierQuery. The zero value
         (nil) is "no sheet": nothing is new. RSGB 1.8 MHz is its first
         reader. *)
      IsNewMultiplierAnywhere: TNewMultiplierQuery;

      (* DOES THE SESSION'S DOMESTIC TABLE KNOW THIS QTH? -- a READ-ONLY
         SERVICE, Q107 (NY4I, 2026-10-16). See TDomesticQTHTest: the SAME
         engine function the typed exchange's session carries, so scoring a
         logged QSO and refusing a typed one ask one table one question. The
         host-area rule (HostAreaRuleCredits) is its reader. The zero value
         (nil) is "no table": it knows no QTH, so an out-of-area entrant
         credits nothing -- the engine with no table loaded answers the same. *)
      IsDomesticQTH: TDomesticQTHTest;

      (* THERE IS NO CLOCK HERE, AND THERE MUST NOT BE ONE.

         A time-of-day rule -- Croatian's 23-05 UTC doubling, UK/EI's 01-05 --
         reads the hour the QSO was RECORDED in, aQso.tSysTime, never the
         time it is scored at. NY4I, 2026-10-01: "the event source is the wall
         clock recorded in the QSO." M4 added a LogClockUTCHour function here
         that asked the PC's clock, transcribing the legacy arms, and a
         rescore at night doubled a whole log; it is gone (design Q21). The
         clock is not a fact about the station. *)
   end;

   (* THE MY-STATION HALF OF AN EXCHANGE.

      IT LIVED IN uCabrilloExchange AND HAD TO MOVE. That unit needs to ask a
      contest how to format its exchange, and the contest needs this record to
      answer -- which is a cycle if the type stays there. It is contest-model
      data rather than Cabrillo data anyway: uADIFExchange already shares it,
      with a note saying "two records that differ by one field are two records
      that drift".

      uCabrilloExchange re-exports it as an alias, so every existing caller and
      both units' tests are untouched. *)
   TMyStationExchange = record
      MyState     : string;
      MyGrid      : string;
      MyName      : string;
      MyZone      : string;
      MyFDClass   : string;
      MySection   : string;
      MyCheck     : string;
      MyPrec      : string;
      MyFOCNumber : string;
      MyPostalCode: string;
      MyPark      : string;
   end;

   (* WHAT THE CABRILLO EXPORTER HAS DECIDED ABOUT ONE QSO BEFORE IT ASKS THE
      CONTEST FOR THE TWO EXCHANGE COLUMNS -- M4, 2026-10-01.

      CHOOSING THE INPUTS IS THE EXPORTER'S; ARRANGING THEM INTO COLUMNS IS THE
      CONTEST'S. The RST strings are already formatted (599, or an FT8 report
      converted), the his-QTH is already selected, and the previous record's
      values are carried by the exporter's loop -- none of that is a contest
      rule, and a contest asked to format a line must never need the log.

      A RECORD BECAUSE IT IS AN INTERFACE PARAMETER, the one exemption CLAUDE.md
      grants: it is the argument list of three virtuals, and a class here would
      need constructing and freeing per QSO for no gain.

      THERE IS NO SESSION EXCHANGE IN IT any more (M11 S9c, 2026-10-14). The
      exporter used to hand in the exchange shape the session had resolved,
      and a `case` over it chose the layout. Nine contests' shape moved with
      the STATION (ARRL 160, the 7QP, Arizona, NEQP, Texas, the Salmon Run,
      JIDX, PACC; California's two shapes print alike); those classes now test
      the station themselves, through the object PostUnit asks
      (ActiveContest, which holds it), as DescribeSession does. *)
   TCabrilloQSOContext = record
      RSTSent: string;
      RSTReceived: string;
      HisQTH: string;

      (* The QTHString of the PREVIOUS log record, whatever it was -- RSGB
         RoPoCo sends the postcode it was given last. Truncated to 10 by the
         exporter, as it always was. *)
      PreviousQTH: string;

      (* The previous GOOD QSO's received number, mod 1000 -- Radio YOC sends
         it back. The exporter carries it; nothing here mutates state. *)
      PreviousNumberReceived: integer;

      (* 1-based count of log records read so far, the current one included.
         RSGB RoPoCo's first QSO sends its own postcode. *)
      RecordNumber: integer;

      (* Settings.Contest.Title -- read by the shared helpers' 'PGA' test, an
         operator-titled event with no ContestType (inventory D7, design Q8). *)
      ContestTitle: string;
   end;

   (* WHAT THE GENERIC ADIF IMPORTER CAPTURED FOR THE CONTEST TO INTERPRET --
      M5a, 2026-10-01.

      THE IMPORTER NAMES NO CONTEST. uADIF.ApplyADIFFieldsToExchange maps the
      standard tags to the standard fields (CALL, BAND, MODE, RST, SRX, STX,
      QTH, CLASS, CQZ/ITUZ and the rest) and puts every tag whose MEANING
      depends on the contest here, as the raw text ADIF carried. Once the
      WHOLE record has been read -- so the order its tags arrived in no longer
      matters -- the contest named by its CONTEST_ID turns these into the
      fields it keeps, through ApplyADIFImport below.

      TAG SPELLINGS ARE ADIF'S, AND MEANINGS ARE THE CONTEST'S: STATE is a US
      state to one contest, the second half of the exchange to another, and a
      NAQP multiplier to a third.

      A RECORD HERE AS ELSEWHERE IN THIS UNIT BECAUSE IT IS AN INTERFACE
      PARAMETER -- the argument of a virtual. It lived in uADIF until M5a;
      uADIF re-exports it under its old name so no caller moves. *)
   TADIFRecordTemps = record
      SRX_String: string;
      STX_String: string;
      State: string;
      ARRL_Sect: string;
      VE_Prov: string;
      POTARef: string;
      SIG: string;
      SIG_Info: string;
      GridSquare: string;
      FOC_Num: string;
      APP_HQ: string;

      (* The WAG DOK and the RSGB IOTA island: written by those contests'
         exporters and, until M5a, read by nothing. *)
      DOK: string;
      IOTA: string;

      (* APP_N1MM_EXCHANGE1, the tag N1MM writes the contest's own exchange
         item into: a class for the Field Days, a membership number for the
         FOC Marathon. WHICH, is the contest's to say -- and the tag can arrive
         before or after CONTEST_ID, which is why it is captured and not read
         as it goes by. *)
      N1MM_Exchange1: string;

      FromWSJTX: boolean;
   end;

   (* WHAT THE IMPORT KNOWS ABOUT THE SESSION IT RUNS IN.

      THE CONTEST READS NO GLOBAL, SO THE IMPORTER HANDS THESE IN AS DATA --
      the way TCabrilloQSOContext hands the exporter's decisions to a contest.
      They are the engine's own answers for the contest the OPERATOR has open,
      which is not necessarily the contest a record names (an operator can
      import another contest's log into this one), and the classless default
      below has always read them for whatever contest the record names. That
      is reproduced, not corrected.

      Operator is the logging operator -- a record with none gets it, for every
      contest, before the contest is asked. *)
   TADIFImportSession = record
      Operator: OperatorType;
      (* Does the open contest's received exchange carry a grid square --
         M11 S9b. It was the session's exchange KIND, of which the one
         reader (the base's ApplyADIFImport) tested four members: the Grid
         and Grid2 exchanges, RSTAndOrGrid and RSTAndGrid3. The open contest
         answers it (TContestBase.ReceivesGridSquareExchange). *)
      ReceivesGridSquare: boolean;
      (* The open contest's HasGridSquareMultiplier -- M11 S6 part 1b. It was
         the session's DomesticMult, of which the one reader (the base's
         ApplyADIFImport) tested one member, GridSquares. *)
      CountsGridSquares: boolean;
      (* The open contest's HasDomesticMultiplier -- M11 S6 part 2; it was
         the session's DoingDomesticMults, the kind's "not none". *)
      DoingDomesticMults: boolean;
   end;

   (* THE ENGINE'S EXCHANGE PARSERS, ONE NAMED METHOD PER FORMAT -- M11 S9d,
      2026-10-15 (plan S9d; NY4I's Q92, option 2).

      An exchange FORMAT is what an RST-and-serial, a name-and-QTH or a
      class-and-section looks like typed: which word is which, and what the
      domestic-QTH table makes of a QTH. LOGSTUFF holds one parser per format
      and they name no contest. They read the engine's tables -- the domestic
      QTH table, CTY.DAT -- so a contest class cannot link them; the engine
      hands an object that implements this class in, through the session, and
      a contest CALLS THE METHOD FOR ITS FORMAT BY NAME
      (TContestBase.ParseReceivedExchangeFormat). No enum selects one.

      UNTIL S9d this was one function taking the exchange KIND --
      LOGSTUFF.ParseExchangeShape, a `case` over ExchangeType -- and the base
      class handed it the session's kind. Each method here is one of that
      machine's reached arms, unchanged and named for the kind it answered
      ('Parse' + the member, less 'Exchange'), so a reader can find the old
      arm. Five arms no registered contest reached went with the machine.

      AN ABSTRACT CLASS, NOT A RECORD OF FUNCTION POINTERS: fifty-one
      parsers, and a test double that forgets one fails by name
      (EAbstractError) instead of calling nil. LOGSTUFF's
      TEngineExchangeParsers is the one implementation the program uses; the
      unit tests hand stubs (uTestExchangeParserStub). Each method parses
      aText into aExch and answers whether the exchange is acceptable. *)
   TExchangeParsers = class
   public
      function ParseAgeAndQSONumber(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseClassDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseGrid(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseGrid2(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseKidsDay(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseNZFieldDay(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseNameAndDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseNameAndPossibleGridSquare(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseNameQTHAndPossibleTenTenNumber(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndCoordinatesSum(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndGeoCoordinates(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndGridSquare(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndName(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndPreviousQSONumber(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberAndZone(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberNameChapterAndQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberNameDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseQSONumberPrecedenceCheckDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTALLJAPrefectureAndPrecedence(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAge(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAgeAndPossibleSK(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndContinent(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndGrid(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndGridSquareOrRDA(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndOrGrid(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndPOTAPark(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndPostalCode(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndQSONumberOrDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTAndQSONumberOrFrenchDepartment(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTDomesticQTHOrQSONumber(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTLongJAPrefecture(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTNameAndQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTPossibleDomesticQTHAndPower(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTPower(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTPrefecture(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQSONumber(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQSONumberAndDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQSONumberAndGridSquare(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQSONumberAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQSONumberAndRandomCharacters(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTQTHNameAndFistsNumberOrPower(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTZone(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTZoneAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTZoneOrDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
      function ParseRSTZoneOrSociety(const aText: string; var aExch: ContestExchange): boolean; virtual; abstract;
   end;

   (* THE ENGINE'S DEFAULT CW EXCHANGE MESSAGES, ONE NAMED METHOD PER SET --
      M11 S9e part 1, 2026-10-15 (plan F30; NY4I's Q92, option 2).

      Set-up (FCONTEST.FoundContest) installs default CW exchange messages
      -- the CQ, S&P and repeat exchanges and the exchange memories F3-F5,
      Alt-F3 and Alt-F4 -- after the contest has described its session. The
      routines that write them are FCONTEST's (they write the settings and
      the CW memory banks, which a contest class cannot link), so the engine
      hands an object implementing this class in and a contest CALLS THE
      METHOD FOR ITS SET BY NAME (TContestBase.WriteDefaultExchangeMessages).
      No enum selects one. The same technique as TExchangeParsers, for the
      same reason.

      UNTIL S9e this was a `case` over the session's exchange shape at the
      foot of FoundContest. Each method is one of its arms, unchanged:
        WriteNameAndState        -- NameAndDomesticOrDXQTH
        WriteRSTQSONumber        -- RSTQSONumber
        WriteRSTStateOrQSONumber -- RSTDomesticQTH, RSTAndContinent,
                                    RSTAndQSONumberOrFrenchDepartment,
                                    RSTAndQSONumberOrDomesticQTH,
                                    RSTDomesticQTHOrQSONumber
        WriteRSTZone             -- RSTZone, RSTZoneAndPossibleDomesticQTH
        WriteRSTStateOrZone      -- RSTZoneOrSociety
      The two "or" methods keep the arms' own test: the state the contest
      sends (FCONTEST.SentMyState) when it sends one, else the serial or the
      zone. aStateAfterZone is the contest's SendsStateAfterZone (CQ WW
      RTTY's), which the arm was handed. *)
   TExchangeMessageWriters = class
   public
      procedure WriteNameAndState; virtual; abstract;
      procedure WriteRSTQSONumber; virtual; abstract;
      procedure WriteRSTStateOrQSONumber; virtual; abstract;
      procedure WriteRSTZone(aStateAfterZone: boolean); virtual; abstract;
      procedure WriteRSTStateOrZone(aStateAfterZone: boolean); virtual; abstract;
   end;

   (* CTY.DAT's zone for a callsign, in the session's zone list. *)
   TCallZoneLookup = function(const aCall: string): Byte;

   (* What live entry does to give up on the QSO being typed: the call and
      exchange windows are cleared and the cursor goes back to the call. *)
   TEntryAbandon = procedure;

   (* A TEXT ANSWER ABOUT A CALL THAT ONLY THE ENGINE HOLDS -- M8. '' when the
      engine has none. *)
   TCallTextLookup = function(const aCall: string): string;

   (* WHAT A CONTEST IS HANDED WHEN THE NEED-MULTIPLIER HINT ASKS IT WHICH
      DOMESTIC MULTIPLIER A CALL IMPLIES -- M8, 2026-10-02. See
      TContestBase.DomesticMultiplierFromCall.

      The contest reads no global, so the engine passes in the two answers
      the rules that moved here asked of it: the initial exchange the session
      remembers for a call (CallsignsList, loaded from the log and the
      initial-exchange file), and CTY.DAT's grid for a call. A RECORD BECAUSE
      IT IS AN INTERFACE PARAMETER, the exemption CLAUDE.md grants -- the
      same shape as TReceivedExchangeSession. A nil lookup is "no service",
      which a rule answers as ''.

      CountryOfCall (Q50, 2026-10-15) is CTY.DAT's country ID for a call --
      what uCallSignRoutines.RussianStationOblast and RussianID are asked of,
      so "is this a Russian station" is the country's answer, never the
      call's first letters. *)
   TMultiplierHintLookups = record
      InitialExchangeOf: TCallTextLookup;
      GridOfCall: TCallTextLookup;
      CountryOfCall: TCallTextLookup;
   end;

   (* WHICH ZONE LIST A CONTEST'S ZONE MULTIPLIER COUNTS -- M11 S5,
      2026-10-14. See TContestBase.ZoneMultiplierZones.

      zmzNotCQOrITU covers TWO cases on purpose, because every reader treats
      them alike: no zone multiplier at all, and one the contest numbers
      itself (the European HF Championship's year licensed, the NZART
      branch, the RF Championship's seven zones). Whether a contest counts a
      zone multiplier at all is TContestBase.HasZoneMultiplier (S5 part 2).

      THIS IS NOT THE CTY ZONE MODE. ZoneModeType (TContestBase.ZoneMode, from
      cfCQZoneMode) says which zone CTY.DAT gives a logged call; this says
      which list the multiplier counts. They disagree for the Croatian and
      CW Open today (plan F5, open question Q95), and S5 transcribes that. *)
   TZoneMultiplierZones = (zmzNotCQOrITU, zmzCQZones, zmzITUZones);

   (* WHAT A CONTEST SAYS ABOUT A RECEIVED DOMESTIC QTH -- M11 S6 part 1,
      2026-10-14. See TContestBase.DomesticMultiplierFromQTH.

      dqaDecided: the contest's own rule has answered, and the domestic file
      is not consulted. dqaLookUpDomesticFile: the engine's domestic-file
      lookup follows -- the base's answer, and what the old kind arms did for
      DomesticFile, NumericID and, through a fall-through kept exactly, the
      IOTA reference (plan F6). *)
   TDomesticQTHAnswer = (dqaDecided, dqaLookUpDomesticFile);

const
   (* THE TWO STANDARD ZONE LISTS' SIZES -- the counts LOGDUPE's
      `case ZoneMult of` gave CQZones and ITUZones until M11 S5. Eight and
      seven contests count them, so each is stated once. *)
   CQ_ZONE_MULTIPLIERS = 40;
   ITU_ZONE_MULTIPLIERS = 75;

type
   (* Declared below; the session record names it. *)
   TContestBase = class;

   (* WHAT A CONTEST IS HANDED WITH A TYPED EXCHANGE -- M5b, 2026-10-02.

      The counterpart of TADIFImportSession: the contest reads no global, so
      the engine passes in what it knows about the session, its parsers and
      the engine services a rule needs. A RECORD BECAUSE IT IS AN INTERFACE
      PARAMETER, the exemption CLAUDE.md grants.

      Parsers IS THE ENGINE'S PARSER FOR EACH FORMAT (M11 S9d) -- see
      TExchangeParsers. It replaced the session's exchange KIND and the one
      function that took it: a contest no longer says which kind it runs, it
      calls the parser for its format.

      ExchangeFormatOf SAYS WHOSE FORMAT TO PARSE IN, and nil -- what the
      engine hands -- means the contest being asked. It exists for one
      contest: IN7QPNE hands its judging party the session with itself
      named here, so the party's rules judge an exchange parsed in IN7QPNE's
      format. Until S9d that came for free: the party parsed the session's
      KIND, which was IN7QPNE's.

      CallWindowHasCall says the exchange is being entered against a call in
      the call window -- live entry. SAC's rule acts only then. *)
   TReceivedExchangeSession = record
      Parsers: TExchangeParsers;
      ExchangeFormatOf: TContestBase;
      ZoneOfCall: TCallZoneLookup;
      IsDomesticQTH: TDomesticQTHTest;
      CallWindowHasCall: boolean;
      AbandonEntry: TEntryAbandon;
   end;

   (* A LIST OF IDENTIFIERS A CONTEST ANSWERS TO -- see FormerADIFContestIds. *)
   TContestIdList = array of string;

   (* THE MULTIPLIER SHEET'S COUNTS AND THE QSO COUNTS, as the score reads
      them: by band (AllBands included), by mode (CW, Digital, Phone and
      Both), and for the multipliers by kind. The application copies them
      out of the sheet; the contest never sees the sheet itself. *)
   TScoreMultTotals = array[BandType, CW..Both, RemainingMultiplierType] of longint;
   TScoreQSOTotals = array[BandType, CW..Both] of longint;

   (* WHAT THE FINAL SCORE IS COMPUTED FROM -- M6, 2026-10-02, stage 3 of
      the three scoring stages (docs/CONTEST_OWNERSHIP_DESIGN.md 7.7).

      FILLED BY THE APPLICATION, which owns the log and the sheet
      (uScoreTotals.GatherScoreTotals); the contest reads these and never a
      global. A field arrives with the first rule that needs it, as in
      TStationContext.

      A RECORD BECAUSE IT IS AN INTERFACE PARAMETER -- the argument of the
      score virtuals below -- which is the one exemption CLAUDE.md grants. It
      is pure data with no behaviour; a class would have to be constructed,
      filled and freed by every caller for no gain, as TCabrilloQSOContext
      records for the export.

      THE "Session" FIELDS ARE THE SESSION'S, NOT THE CONTEST'S TRAITS, for
      the reason TCabrilloQSOContext states: set-up (DescribeSession) and the
      operator's statements set them per station, and today's score has
      always read the session's answer. *)
   TScoreTotals = record
      (* The QSO points stored in the log, summed -- for a single-band entry,
         the points of that band only (LOGDUPE's TotalQSOPoints). *)
      QSOPoints: longint;

      (* QTCs counted as points: TotalNumberQTCsProcessed when QTCs are
         enabled, else 0. Every contest with QTCs on has always added them. *)
      QTCPoints: longint;

      Mults: TScoreMultTotals;
      QSOs: TScoreQSOTotals;

      (* AllBands, or the one band a single-band entry scores (SingleBand). *)
      ScoredBand: BandType;

      (* Does the session count any multiplier at all? False when the four
         Active* multiplier kinds are all None. *)
      SessionCountsMultipliers: boolean;

      (* WHEN THE LOG SAYS ITS CONTEST STARTED -- the contest row's
         start_time, UTC, as TLogRepository.LogStartTime read it when the log
         was opened; 0 when the row records none. Q35 (2026-10-17) is its
         first reader, through LogContestYear below.

         A LOG FACT, NOT A STATION FACT AND NOT THE CLOCK: a 2026 log reopened
         in 2029 carries 2026 here. Nothing WRITES start_time yet (Q99 seeds
         it at New Contest), so today it is 0 for every log and the year comes
         from the QSOs. *)
      LogStartTime: TDateTime;

      (* The session's exchange stood here until M11 S7 (2026-10-14): its one
         reader, CombineScore's FISTS test, is FISTS's own formula now. (Its
         DX multiplier kind stood beside it until M11 S4 part 2.) *)

      (* ~~LiveSessionTally~~ stood here: a count kept while the program ran,
         not from the log -- Missouri's peak-hour tally, 0 after every reload.
         DELETED with TContestBase.TalliesLiveQSO at Q32 (NY4I, 2026-10-15;
         built 2026-10-17): the bonus is counted over the view, from each
         QSO's own logged time, like every other bonus. *)
   end;

   (* A READ-ONLY VIEW OF THE LOGGED QSOs -- what a bonus rule reads (M6).

      EVERY QSO THAT COUNTS TOWARD THE TOTALS (QSOCountsTowardTotals): the
      set the log's loader adds to the sheet when a contest is opened, in log
      order, and every QSO live entry has counted since. Dupes are in it, as
      they are in the loader's walk; a rule that does not want them says so
      (TContestBase.CountsTowardBonus).

      AN ABSTRACT CLASS AND NOT AN ARRAY, so the contest can only READ: there
      is no Add here. The application keeps its list beside the totals
      (uScoreTotals says why, with the measurement); a test hands in its own
      TLoggedQSOList. *)
   TLoggedQSOView = class
   public
      function Count: integer; virtual; abstract;
      function QSO(aIndex: integer): ContestExchange; virtual; abstract;
   end;

   (* A VIEW HELD IN MEMORY -- what a test fills, and what the application
      keeps beside the totals (uScoreTotals). *)
   TLoggedQSOList = class(TLoggedQSOView)
   private
      FQSOs: array of ContestExchange;
      FCount: integer;
   public
      procedure Add(const aQso: ContestExchange);
      (* Empties the list and keeps its storage, for the next fill. *)
      procedure Clear;
      function Count: integer; override;
      function QSO(aIndex: integer): ContestExchange; override;
   end;

   (* A STATION WHOSE CONTACT EARNS A BONUS -- DECLARED DATA (M6).

      The contest LISTS its bonus stations; the base counts them over the view
      (TContestBase.BonusPoints). The two contests that have them -- Missouri's
      W0MA and K0GQ, the Salmon Run's W7DX -- differ only in these three
      values and in which contacts and modes they credit, which are the two
      virtuals beside BonusPoints. Points is paid once, or once for each mode
      the contest credits when OncePerMode. *)
   TBonusStation = record
      Call: string;
      Points: longint;
      OncePerMode: boolean;
   end;
   TBonusStationList = array of TBonusStation;

   (* EVERY VALUE A CONTEST'S SET-UP MAY STATE -- M7a, 2026-10-02.

      One member per value FCONTEST.FoundContest's per-contest arms wrote for
      a contest that has a class: the engine's Active* choices the arms made
      per station, the session settings, the CW exchange messages, what a
      contest sends where MY STATE goes (SentState -- never written into MY
      STATE since M9a), and the domestic file. A member
      arrives with the first contest that states it -- the arms of the
      CLASSLESS contests set more (a zone multiplier, an initial exchange,
      the R150S list) and those join when their contest gains a class.

      M7b (2026-10-02) brought the first of them: the initial exchange and
      the zone multiplier (JIDX, JTDX, KCJ), the DX multiplier limit (NEQP,
      7QP), the R150S list (CQ-M, Gagarin Cup, OZCHR teams), and JIDX's
      refusal of the shared zone-exchange messages (gone at M11 S9e part 1:
      the contest's own choice of messages). M7b batch 2 brought the
      last two the arms wrote: the initial-exchange cursor at the start (IRTS,
      RAEM) and the DXCC multiplier by band (CQMM). *)
   TSessionValue = (
      svExchange,
      svBand, svMode, svDomesticMultByBand, svAllowDupeQSOs,
      svInitialExchange, svDXMultLimit,
      svInitialExchangeCursorAtStart, svDXCCMultByBand,
      svR150SMode,
      svMultByBand, svQSOByMode, svQSOByBand,
      svWARCEnabled, svHFEnabled,
      svContestName, svSentState, svDomesticFile,
      svLiteralDomesticQTH, svDigitalModeEnable, svExchangeMemoryEnable,
      svSprintQSYRule, svMultipleBands, svMultipleModes,
      svInitialExchangeOverwrite, svQSONumberByBand,
      svMinitourDuration, svContactsPerPage, svQTCEnable, svRfoblMode,
      svAutoDupeEnableCQ, svAutoDupeEnableSAndP,
      svCQExchangeCW, svSPExchangeCW, svRepeatSPExchangeCW, svQSLCW,
      svQuickQSLCW1, svQSOBeforeCW, svCallOkNowCW,
      svRSTQSONumberExchangeMemories, svOperatorNameSet);
   TSessionValues = set of TSessionValue;

   (* A FUNCTION-KEY MEMORY A CONTEST'S SET-UP FILLS.

      NAMED, NOT CODED: the engine's key codes are TRDOS constants (Tree's F1
      is CHR(112)), and a contest class does not reach into TRDOS for them.
      FCONTEST's applier translates; the class says which key it means. Only
      the keys some contest fills are here. *)
   TSessionMemoryKey = (smkF1, smkF2, smkF3, smkF4, smkF5, smkF6, smkF7, smkF8,
                        smkAltF1, smkAltF2, smkAltF3, smkAltF4, smkAltF5,
                        smkAltF6, smkAltF7);

   (* The CQ memories, the exchange (search-and-pounce) memories, or the
      exchange memories' CAPTIONS -- the key's label in the function-key
      window (the RTC contest names F4 'NR' and F5 'Cl+Ex'; M7b batch 2). *)
   TSessionMemoryBank = (smbCQ, smbExchange, smbExchangeCaption);

   (* ONE MEMORY A CONTEST FILLS -- an element of TSessionDefaults' list.

      A RECORD BECAUSE IT IS AN INTERFACE PARAMETER, the exemption CLAUDE.md
      grants: it is what the defaults object hands FCONTEST's applier, and it
      is pure data. *)
   TSessionMemory = record
      Bank: TSessionMemoryBank;
      Mode: ModeType;
      Key: TSessionMemoryKey;
      Text: string;
   end;

   (* WHAT A CONTEST WANTS ITS SESSION TO START FROM -- M7a, 2026-10-02
      (docs/CONTEST_OWNERSHIP_DESIGN.md section 4.2).

      FILLED BY THE CONTEST (TContestBase.DescribeSession), APPLIED BY
      FCONTEST (ApplySessionDefaults), the only writer. The class touches no
      global: it says what it wants, and the program decides how that reaches
      the engine. That is what lets a test construct a contest, hand it a
      station and read back what it would set up, without booting TR4W.

      A CLASS, NOT A RECORD, because every value has THREE states and a record
      field has two. A contest that names no exchange must leave the engine's
      exchange exactly as the head wrote it -- the trait, or the operator's
      statement -- and "not stated" cannot be spelled as a value of
      ExchangeType, WarcEnabled or the state sent (an empty one is a real
      statement: Canada Day sends none for a non-VE station). So each setter
      records that its value was stated, and the applier writes only what
      was. It also owns two ordered lists, the domestic countries and the
      memories. It is created and freed by the one caller, FoundContest.

      A STATED VALUE OVERWRITES, AS THE ARM DID. Today's precedence is kept
      exactly: the head applies the contest's traits and the operator's
      statements (FCONTEST.ApplyContestTraits), then this, so a value a
      contest states here wins over a statement made BEFORE the CONTEST line
      and loses to one made after it -- what the arm always did. *)
   TSessionDefaults = class
   private
      FStated: TSessionValues;
      FExchange: ExchangeType;
      FBand: BandType;
      FMode: ModeType;
      FDomesticMultByBand: TAdditionalMultByBand;
      FInitialExchange: InitialExchangeType;
      FDXMultLimit: integer;
      FDXCCMultByBand: TAdditionalMultByBand;
      FMinitourDuration: TTourDuration;
      FContactsPerPage: TContactsPerPage;
      FFlags: array[TSessionValue] of boolean;
      FTexts: array[TSessionValue] of string;
      FDomesticCountries: array of string;
      FMemories: array of TSessionMemory;

      procedure Stated(aValue: TSessionValue);
      procedure SetExchange(aValue: ExchangeType);
      procedure SetBand(aValue: BandType);
      procedure SetMode(aValue: ModeType);
      procedure SetDomesticMultByBand(aValue: TAdditionalMultByBand);
      procedure SetInitialExchange(aValue: InitialExchangeType);
      procedure SetDXMultLimit(aValue: integer);
      procedure SetDXCCMultByBand(aValue: TAdditionalMultByBand);
      procedure SetMinitourDuration(aValue: TTourDuration);
      procedure SetContactsPerPage(aValue: TContactsPerPage);
      function GetFlag(aIndex: integer): boolean;
      procedure SetFlag(aIndex: integer; aValue: boolean);
      function GetText(aIndex: integer): string;
      procedure SetText(aIndex: integer; const aValue: string);
      procedure AddMemory(aBank: TSessionMemoryBank; aMode: ModeType;
                          aKey: TSessionMemoryKey; const aText: string);
   public
      (* DID THE CONTEST STATE THIS VALUE? The applier writes nothing else. *)
      function IsStated(aValue: TSessionValue): boolean;

      (* THE ENGINE'S CHOICES -- ActiveExchange, ActiveBand, ActiveMode,
         DomesticMultByBand and tAllowDupeQSOs. (DXMult went with the DX kind
         at M11 S4 part 2, DomesticMult with the domestic kind at M11 S6 part
         2: the contest answers HasDXMultiplier and HasDomesticMultiplier.) *)
      property Exchange: ExchangeType read FExchange write SetExchange;
      property Band: BandType read FBand write SetBand;
      property Mode: ModeType read FMode write SetMode;
      property DomesticMultByBand: TAdditionalMultByBand
         read FDomesticMultByBand write SetDomesticMultByBand;
      property AllowDupeQSOs: boolean index Ord(svAllowDupeQSOs)
         read GetFlag write SetFlag;

      (* The session's InitialExchange (uContestSession, M10 S9a) and
         DXMultLimit -- M7b. (ZoneMult went with the zone kind at M11 S5
         part 2: the contest answers HasZoneMultiplier.) *)
      property InitialExchange: InitialExchangeType
         read FInitialExchange write SetInitialExchange;
      property DXMultLimit: integer read FDXMultLimit write SetDXMultLimit;

      (* THE INITIAL EXCHANGE'S CURSOR AT THE START OF THE WINDOW -- M7b
         batch 2. The engine's InitialExchangeCursorPos (LOGWIND), which the
         IRTS and RAEM arms set to AtStart; True is AtStart, False AtEnd. A
         flag and not the engine's type, which is TRDOS's to declare. *)
      property InitialExchangeCursorAtStart: boolean
         index Ord(svInitialExchangeCursorAtStart) read GetFlag write SetFlag;

      (* DXCCMultByBand -- the CQMM arm's dmbbAllBand (M7b batch 2), the
         DXCC twin of DomesticMultByBand. *)
      property DXCCMultByBand: TAdditionalMultByBand
         read FDXCCMultByBand write SetDXCCMultByBand;

      (* ~~SuppressZoneExchangeMessages~~ (M7b) stood here: the JIDX contests
         refused the closing set-up's zone-exchange messages. It went at M11
         S9e part 1 -- the messages are each contest's own choice
         (TContestBase.WriteDefaultExchangeMessages), and the JIDX choose
         none. *)

      (* THE SESSION'S SETTINGS -- each is the setting of the same name. *)
      property MultByBand: boolean index Ord(svMultByBand) read GetFlag write SetFlag;
      property QSOByMode: boolean index Ord(svQSOByMode) read GetFlag write SetFlag;
      property QSOByBand: boolean index Ord(svQSOByBand) read GetFlag write SetFlag;
      property WARCEnabled: boolean index Ord(svWARCEnabled) read GetFlag write SetFlag;
      property HFEnabled: boolean index Ord(svHFEnabled) read GetFlag write SetFlag;
      property LiteralDomesticQTH: boolean index Ord(svLiteralDomesticQTH)
         read GetFlag write SetFlag;
      property DigitalModeEnable: boolean index Ord(svDigitalModeEnable)
         read GetFlag write SetFlag;
      property ExchangeMemoryEnable: boolean index Ord(svExchangeMemoryEnable)
         read GetFlag write SetFlag;
      property SprintQSYRule: boolean index Ord(svSprintQSYRule)
         read GetFlag write SetFlag;
      property MultipleBands: boolean index Ord(svMultipleBands)
         read GetFlag write SetFlag;
      property MultipleModes: boolean index Ord(svMultipleModes)
         read GetFlag write SetFlag;
      property InitialExchangeOverwrite: boolean index Ord(svInitialExchangeOverwrite)
         read GetFlag write SetFlag;
      property QSONumberByBand: boolean index Ord(svQSONumberByBand)
         read GetFlag write SetFlag;
      property QTCEnable: boolean index Ord(svQTCEnable) read GetFlag write SetFlag;
      property RfoblMode: boolean index Ord(svRfoblMode) read GetFlag write SetFlag;
      property R150SMode: boolean index Ord(svR150SMode) read GetFlag write SetFlag;
      property AutoDupeEnableCQ: boolean index Ord(svAutoDupeEnableCQ)
         read GetFlag write SetFlag;
      property AutoDupeEnableSAndP: boolean index Ord(svAutoDupeEnableSAndP)
         read GetFlag write SetFlag;
      property MinitourDuration: TTourDuration
         read FMinitourDuration write SetMinitourDuration;
      property ContactsPerPage: TContactsPerPage
         read FContactsPerPage write SetContactsPerPage;
      property ContestName: string index Ord(svContestName) read GetText write SetText;

      (* WHAT THE STATION SENDS WHERE MY STATE GOES, IN THIS CONTEST -- a
         contest that sends nothing there for a station outside its country
         (Canada Day, the Russian DX contests) or the grid in its place (the
         Russian cups).

         IT WAS `MyState` UNTIL M9a (2026-10-02), AND THE APPLIER WROTE IT
         INTO THE STATION'S MY STATE. That was design 7.11's defect: MY STATE
         is the operator's, stored in settings/tr4w.json, so a later save
         carried the contest's value out of the contest. FCONTEST's applier
         now holds it as the SESSION's sent state (FCONTEST.SentMyState) and
         MY STATE is never written by set-up. Every reader of the sent
         exchange asks SentMyState. *)
      property SentState: string index Ord(svSentState) read GetText write SetText;

      (* THE DOMESTIC FILE, without its extension -- what the head chose,
         overwritten. An EMPTY one is a statement too: it leaves DOMESTIC
         FILENAME as it stood (the ALRS cup's non-capital Russian station). *)
      property DomesticFile: string index Ord(svDomesticFile) read GetText write SetText;

      (* THE CW EXCHANGE MESSAGES -- CQ EXCHANGE, S&P EXCHANGE and the rest. *)
      property CQExchangeCW: string index Ord(svCQExchangeCW) read GetText write SetText;
      property SPExchangeCW: string index Ord(svSPExchangeCW) read GetText write SetText;
      property RepeatSPExchangeCW: string index Ord(svRepeatSPExchangeCW)
         read GetText write SetText;
      property QSLCW: string index Ord(svQSLCW) read GetText write SetText;
      property QuickQSLCW1: string index Ord(svQuickQSLCW1) read GetText write SetText;
      property QSOBeforeCW: string index Ord(svQSOBeforeCW) read GetText write SetText;
      property CallOkNowCW: string index Ord(svCallOkNowCW) read GetText write SetText;

      (* THE RST-AND-SERIAL EXCHANGE MEMORIES, as FCONTEST's shared set-up
         for that exchange writes them (UK/EI's non-UK station). A shared
         arm, asked for by name rather than copied: it carries a per-language
         caption, and it is the same set the session's closing exchange
         set-up writes for every RST-and-serial contest. *)
      procedure UseRSTQSONumberExchangeMemories;

      (* THE OPERATORS' NAMES FROM TRMASTER.DTA, INDEXED FOR THE SESSION --
         asked for, not stated: FCONTEST's applier builds LOGSCP's operator
         name set (InitOperatorNameSet), which the POTA exchange shape reads to
         tell a name from a park or a state. It is built once per run and
         never unbuilt, so there is nothing to state False. POTA's FoundContest
         arm called it last; the applier calls it last. (2026-10-13, design
         Q6.) *)
      procedure UseOperatorNameSet;

      (* DOMESTIC COUNTRIES, in the order AddDomesticCountry is to see them. *)
      procedure AddDomesticCountry(const aID: string);
      procedure AddDomesticCountries(const aIDs: array of string);
      function DomesticCountryCount: integer;
      function DomesticCountry(aIndex: integer): string;

      (* FUNCTION-KEY MEMORIES, applied in the order they were set. *)
      procedure SetCQMemory(aMode: ModeType; aKey: TSessionMemoryKey;
                            const aText: string);
      procedure SetExchangeMemory(aMode: ModeType; aKey: TSessionMemoryKey;
                                  const aText: string);
      (* An exchange memory's CAPTION, in the same ordered list. *)
      procedure SetExchangeCaptionMemory(aMode: ModeType; aKey: TSessionMemoryKey;
                                         const aText: string);
      function MemoryCount: integer;
      function Memory(aIndex: integer): TSessionMemory;
   end;

   (* ------------------------------------------------------------------------
      M9a (2026-10-02): WHAT A CONTEST TELLS THE DISPLAY AND THE REPORTS.

      EVERY TYPE BELOW IS DATA THE UI ASKS FOR. A contest never touches a
      form, a canvas or a global: the New Contest dialog, the totals window,
      the summary sheet, the Cabrillo writer and the score-posting clients
      ask the contest (ContestIdentity) and render the answer. Each stood as a
      `case Contest of` or an `if Contest = ...` in the unit that renders it.
      ------------------------------------------------------------------------ *)

   (* ONE OF THE STATION'S OWN FIELDS THE NEW CONTEST DIALOG MAY ASK FOR --
      each is the MY ... command of the same name, which is what the dialog
      queues the answer as. It was uNewContest's InitialCommands, a list
      private to the dialog; a contest has to be able to name a field
      without reaching into a UI unit, so the list lives here and the dialog
      reads it. *)
   TNewContestField = (ncfMyCheck, ncfMyFDClass, ncfMyGrid, ncfMyFOC, ncfMyIOTA,
                       ncfMyName, ncfMyPark, ncfMyPrec, ncfMyQTH, ncfMySection,
                       ncfMyState, ncfMyZone, ncfMyPostalCode);

   (* WHAT ONE STEP OF A PROMPT DOES, in the dialog's own terms:
        npkField             offer the field's row (the next free one);
        npkFieldWithComment  offer the row, then put the text in the comment;
        npkIAmIn             show the "I am in <region>" box;
        npkIAmInCaption      show the box with this caption as it stands. *)
   TNewContestPromptKind = (npkField, npkFieldWithComment, npkIAmIn, npkIAmInCaption);

   (* ONE STEP -- the element of TNewContestPrompts' two lists. A RECORD
      BECAUSE IT IS AN INTERFACE PARAMETER, as TSessionMemory is: pure data
      the prompts object hands the dialog. *)
   TNewContestPrompt = record
      Kind: TNewContestPromptKind;
      Field: TNewContestField;
      Text: string;
   end;

   (* WHAT THE NEW CONTEST DIALOG ASKS FOR WHEN THIS CONTEST IS CHOSEN -- M9a.

      TWO ORDERED LISTS, because the dialog asks at two moments: when the
      contest is CHOSEN, and when its "I am in ..." box is TICKED. Each step
      is what one line of the dialog's two `case SelectedContest of` did,
      in the order it did it -- the order matters, because rows are handed
      out in the order the fields are asked for, and the last comment wins.

      A CLASS, NOT A RECORD, for TSessionDefaults' reason: it owns two
      ordered lists and the steps that fill them. Filled by
      TContestBase.DescribeNewContestPrompts; read and freed by the dialog. *)
   TNewContestPrompts = class
   private
      FOnChoice: array of TNewContestPrompt;
      FWhenInside: array of TNewContestPrompt;
      procedure AddChoice(aKind: TNewContestPromptKind; aField: TNewContestField;
                          const aText: string);
   public
      (* WHEN THE CONTEST IS CHOSEN. *)
      procedure AskField(aField: TNewContestField);
      procedure AskFieldWithComment(const aComment: string; aField: TNewContestField);
      (* "I am in <aRegion>" -- the dialog supplies the words around it. *)
      procedure OfferIAmIn(const aRegion: string);
      (* The box with aCaption as it stands (the IOTA's island station). *)
      procedure OfferIAmInCaption(const aCaption: string);

      (* WHEN THE "I AM IN" BOX IS TICKED -- every arm of the ticked case
         offered one row with a comment. *)
      procedure AskFieldWithCommentWhenInside(const aComment: string;
                                              aField: TNewContestField);

      function ChoiceCount: integer;
      function Choice(aIndex: integer): TNewContestPrompt;
      function InsideCount: integer;
      function Inside(aIndex: integer): TNewContestPrompt;
   end;

   (* WHAT THE TOTALS WINDOW SHOWS DIFFERENTLY FOR THIS CONTEST -- M9a
      (uTotal.UpdateTotals2). A RECORD BECAUSE IT IS AN INTERFACE PARAMETER --
      the answer of one getter, pure data -- as TScoreTotals is.

      ShowsModeShares: when QSOs count per mode and both CW and phone have
      QSOs, the left column shows each mode's SHARE of the QSOs ('CW: 60%',
      'PH: 40%') in place of the per-mode QSO rows -- the OZCHR teams'
      display. The domestic-multiplier captions are the row labels for the
      domestic multipliers: all modes, and per mode on CW and on phone. *)
   TTotalsDisplay = record
      ShowsModeShares: boolean;
      DomesticMultsCaption: string;
      DomesticMultsCaptionCW: string;
      DomesticMultsCaptionPhone: string;
   end;

   (* HOW THIS CONTEST'S SUMMARY SHEET COUNTS -- M9a
      (PostUnit.WriteScoreInformationToSummarySheet). A RECORD BECAUSE IT IS
      AN INTERFACE PARAMETER, as TTotalsDisplay is.

      MultiplierPerBandModeRow: each multiplier column of a band/mode row
      shows 1, and the total row shows the number of rows -- Winter Field
      Day's "one multiplier for each band and mode worked".
      ClaimedScoreIsQSOPoints: the claimed-score line states the QSO point
      total, not the final score -- ARRL Field Day's sheet. *)
   TSummarySheetLayout = record
      MultiplierPerBandModeRow: boolean;
      ClaimedScoreIsQSOPoints: boolean;
   end;

   (* AN OPERATING AID A SPONSOR MAY FORBID -- M9a. WRTC is the contest that
      forbids them: no Super Check Partial (the master file and its window),
      no DX cluster, no live score posting. The menus, OpenTR4WWindow and
      LOGEDIT's Super Check Partial ask TContestBase.PermittedOperatingAids. *)
   TOperatingAid = (oaSuperCheckPartial, oaDXCluster, oaScorePosting);
   TOperatingAids = set of TOperatingAid;

   (* WHAT A SCORE-REPORTING CLIENT HANDS A CONTEST WITH THE QSO WHEN IT ASKS
      FOR THE CANONICAL SENT EXCHANGE -- M9a. The contest reads no global;
      these are the station's own values the canonical forms are built from.
      A RECORD BECAUSE IT IS AN INTERFACE PARAMETER.

      CQExchangeTemplate is CQ EXCHANGE CW as the session holds it -- the base
      rebuilds what was SENT from it. MyGrid is MY GRID (the RTC's sent
      exchange is its serial and grid). *)
   TCanonicalExchangeContext = record
      CQExchangeTemplate: string;
      MyGrid: string;
   end;

   (* THE CONTEST'S YES/NO FACTS, AS ONE SET -- M10 S5, 2026-10-14.

      These were the nine bits of the contest's ContestsBooleanArray word,
      and the members are declared IN BIT ORDER (cfQSOByBand is bit 0,
      cfRTCCapable bit 8), so a set compares bit for bit with the word while
      the word exists (plan S8 deletes it; the base stopped reading it at
      M10 S6 and answers []). Each member answers the property of the
      same name on TContestBase:

        cfQSOByBand, cfQSOByMode       a station may be worked once per
                                       band / per mode
        cfMultByBand, cfMultByMode     a multiplier counts per band / mode
        cfErmakSpecification           the ERMAK Cabrillo specification is
                                       offered to a Russian station
        cfVHFBandsEnabled              the VHF bands are on
        cfCQZoneMode                   CTY.DAT answers CQ zones; absent
                                       means ITU zones (ZoneMode)
        cfCountsDomesticCountries      a domestic country counts as one
        cfRTCCapable                   HamScore's real-time contact upload

      A SET, NOT NINE VIRTUALS, on the radio factory's model
      (TRadioCapabilitySet): a contest states ONE line that a reader can
      take in at a glance, the members cannot be stated twice or disagree,
      and a fact added later is a member, not a getter in 186 classes. The
      nine properties are still asked by name and are answered from it. *)
   TContestFlag = (
      cfQSOByBand,
      cfQSOByMode,
      cfMultByBand,
      cfMultByMode,
      cfErmakSpecification,
      cfVHFBandsEnabled,
      cfCQZoneMode,
      cfCountsDomesticCountries,
      cfRTCCapable
      );
   TContestFlags = set of TContestFlag;

   TContestBase = class
   private
      FContest: TContestHandle;
      (* The contest's id -- its stored name, uContestRegistry.ContestId,
         read once at construction (Q108 S2). *)
      FId: string;
      FStation: TStationContext;
   protected
      (* THE GETTERS BEHIND THE PROPERTIES BELOW.

         PROPERTIES RATHER THAN BARE FUNCTIONS, on NY4I's question and to match
         the radio factory, which publishes 27 of them in the same shape --
         `property radioPort: integer read GetRadioPort write SetRadioPort`.

         The call syntax is identical either way in Pascal, so this changes no
         caller. What it buys is the seam: a property can later gain a check
         before the value is returned, a setter, or a cached field, without any
         call site moving -- and a descendant overrides the GETTER, so the
         property stays declared once.

         The split is WHAT A CONTEST IS versus WHAT IT DOES. These are the
         former. CalculateQSOPoints, ValidateClass, ValidateDXQTH and the
         exchange formatters take arguments and do work, so they stay
         methods. *)
      function GetDisplayName: string; virtual;
      function GetCabrilloName: string; virtual;
      function GetADIFContestId: string; virtual;
      function GetFormerADIFContestIds: TContestIdList; virtual;
      function GetWA7BNMId: integer; virtual;
      function GetSubmissionEmail: string; virtual;
      function GetDomesticFileName: string; virtual;
      function GetFriendlyName: string; virtual;
      function GetQRZRUId: integer; virtual;
      function GetInitialExchangeKind: InitialExchangeType; virtual;
      function GetExchangeKind: ExchangeType; virtual;

      (* WHICH FIELDS THE RECEIVED EXCHANGE CARRIES -- M11 S9a, 2026-10-14
         (docs/CONTEST_FACTORY_M11_PLAN.md S9a). Start-up puts the answer
         in LOGDUPE.ExchangeInformation, which the log-string parses
         (LOGDUPE, LOGSTUFF), LOGSUBS2's age message, the ADIF RST and zone
         tags (POSTUNIT) and the external logger read.

         It was LOGDUPE.SetUpExchangeInformation, a `case` over the
         session's exchange shape. Each contest now states its own list by
         calling a named helper in uExchangeFields (NY4I's ruling on Q92):
         no enum selects one. A contest whose exchange depends on the
         station tests the station here as DescribeSession does, through
         the same predicate (Station is ActiveContest's).

         THE BASE MARKS NOTHING -- what the machine gave the classless
         DUMMYCONTEST (UnknownExchange had no arm). Every registered contest
         states its list, on its class or its family base. *)
      function GetReceivedExchangeFields: ExchangeInformationRecord; virtual;

      (* THE FORMAT A TYPED EXCHANGE IS PARSED IN -- M11 S9d, 2026-10-15
         (docs/CONTEST_FACTORY_M11_PLAN.md S9d). The base ParseReceivedExchange
         asks this for the plain parse; a rule a contest adds goes on
         ParseReceivedExchange, around it.

         It was LOGSTUFF.ParseExchangeShape, a `case` over the session's
         exchange shape that the base handed the session's kind. Each contest
         now calls the engine's parser for its format by name, on aParsers
         (NY4I's ruling on Q92: no enum selects one). A contest whose format
         depends on the station tests the station here as DescribeSession
         does, through the same predicate as its field list (Station is
         ActiveContest's); one whose format depends on the TEXT chooses by the
         text (Arktika Spring, the PCC).

         THE BASE PARSES NOTHING AND ANSWERS False -- what the machine gave
         the classless DUMMYCONTEST (UnknownExchange had no arm). Every
         registered contest states its format, on its class or its family
         base; uTestExchangeParse fails for one that does not. *)
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; virtual;

      (* THE DEFAULT CW EXCHANGE MESSAGES SET-UP INSTALLS -- M11 S9e part 1,
         2026-10-15 (docs/CONTEST_FACTORY_M11_PLAN.md F30). The procedure
         behind SetUpDefaultExchangeMessages: a contest calls the engine's
         writer for its set by name, on aMessages (TExchangeMessageWriters),
         or calls none.

         It was a `case` over the session's exchange shape at the foot of
         FCONTEST.FoundContest. A contest whose set depends on the station
         tests the station here as DescribeSession does, through the same
         predicate as its field list and parse format (Station is
         ActiveContest's).

         THE BASE WRITES NOTHING -- what the `case` did for every shape it
         had no arm for, the classless DUMMYCONTEST's among them. Most
         contests write none: their messages come from DescribeSession's
         memories and LogCfg's defaults. uTestExchangeKindReaders pins every
         contest at every roster station. *)
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); virtual;

      (* THE ADIF STX_STRING -- OUR SIDE OF THE EXCHANGE -- M11 S9b,
         2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S9b). The getter behind
         FormatADIFSentExchange: each contest states the string it sends by
         calling a named helper in uADIFExchange (NY4I's ruling on Q92: no
         enum selects one), or builds its own. It was a `case` over the
         session's exchange shape,
         uADIFExchange.FormatADIFExchangeOfKind, which this base called for
         every contest without an override.

         The worked QSO carries the RST and the serial SENT; aMy is the
         station's own exchange. The caller has decided the QSO is a good
         one. A getter that cannot build its string RAISES (a format that
         fails, or uADIFExchange.ADIFSentNotImplemented for a contest with no
         layout) and TryFormatADIFSentExchange reports it -- no placeholder
         string stands in for an exchange any more (plan F25/F26, NY4I
         2026-10-14).

         A contest whose exchange depends on the station tests the station
         here as DescribeSession does (Station is ActiveContest's).

         THE BASE STATES NO LAYOUT: it raises, what the classless
         DUMMYCONTEST (UnknownExchange had no arm) gets. Every registered
         contest states its string, on its class or its family base, or calls
         ADIFSentNotImplemented by name. *)
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; virtual;

      (* THE TWO CABRILLO EXCHANGE COLUMNS -- M11 S9c, 2026-10-14
         (docs/CONTEST_FACTORY_M11_PLAN.md S9c). The getters behind
         FormatCabrilloSentExchange and FormatCabrilloReceivedExchange: each
         contest states the column it writes by calling a named helper in
         uCabrilloExchange (NY4I's ruling on Q92: no enum selects one), or
         builds its own. They were a `case` over the session's exchange shape,
         uCabrilloExchange.FormatCabrilloExchangeOfKind, which this base
         called for every contest without an override.

         The worked QSO carries the serials; aCtx what the exporter decided
         about it (the formatted RSTs, the his-QTH it selected, the previous
         record's values). A contest whose exchange depends on the station
         tests the station here as DescribeSession does (Station is
         ActiveContest's -- PostUnit asks that object).

         THE BASE PRINTS THE ERROR MARKER IN BOTH COLUMNS -- what the machine
         gave the classless DUMMYCONTEST (UnknownExchange had no arm), and the
         loud answer for a contest that forgets to state its columns (Issue
         #1043). Every registered contest states both, on its class or its
         family base. *)
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; virtual;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; virtual;

      (* DOES THE RECEIVED EXCHANGE CARRY A GRID SQUARE? -- M11 S9b. The
         generic ADIF import reads GRIDSQUARE into the exchange of a contest
         that does (the base's ApplyADIFImport, through the import session).
         True for the Grid and Grid2 exchanges (ARRL Digi, WW Digi, Batavia
         FT8, Makrothen) and for the RST-and-grid exchange (the three ARRL
         VHF contests, the CQ VHF, the Stew Perry). THE BASE ANSWERS FALSE.
         Not HasGridSquareMultiplier: the Digi contests carry a grid and count
         no grid multiplier. *)
      function GetReceivesGridSquareExchange: boolean; virtual;
      function GetIsUSQSOParty: boolean; virtual;
      function GetHostState: string; virtual;

      (* WHICH ADIF TAG CARRIES THE QSO'S Power FIELD -- M4, 2026-10-01.

         The Power field holds what the parser put there, and that MEANS
         different things per contest: a power for ARRL DX, the FOC
         membership number for the FOC Marathon. ADIF has a tag for each, and
         which one applies is the contest's knowledge, so uADIF.EmitADIFRecord
         asks rather than testing `ceContest = FOCMARATHON`. The base answers
         RX_PWR, what every other contest has always written. *)
      function GetADIFPowerTag: string; virtual;

      (* DOES ADIF EXPORT WRITE A CONTEST_ID FOR THIS CONTEST? -- M4.

         True for every contest, except an operating mode that is not a contest
         at all: General QSO and POTA say False. uADIF.EmitADIFRecord asks; it
         used to test `ceContest in [POTA, GENERALQSO]`, and POTA kept a test
         of its own there until it gained its class (2026-10-13, design Q6).
         The id itself is still answered -- the score-posting clients send
         it. *)
      function GetWritesADIFContestId: boolean; virtual;

      (* WHAT CONTEST SET-UP READS BESIDES THE ROW -- M2, 2026-10-01.

         FCONTEST.FoundContest's head used to read these straight out of
         ContestsBooleanArray, a word of flag bits per contest. They are facts
         about the contest -- whether a station may be worked once per band or
         per mode, whether a multiplier counts per band or per mode, whether
         the VHF bands are on, which zone list CTY.DAT answers with, whether a
         domestic country counts as a country -- so the contest states them,
         and set-up asks the contest (FCONTEST.ApplyContestTraits).

         A CONTEST STATES THEM ALL AT ONCE, in GetFlags (M10 S5, 2026-10-14):
         every registered contest states its set, in its leaf or -- for the
         CW/SSB pairs, whose set is their family's rule -- on its family base.
         The getters below are NOT virtual any more; each answers from the
         set, so there is one statement per contest and nothing to disagree
         with it.

         THE BASE ANSWERS THE EMPTY SET (M10 S6) -- DUMMYCONTEST's word, 0 --
         and reads no table; Test_MovedRowValuesStillMatchTheArray proves
         every stated set equal to its row, bit by bit, until plan S8 deletes
         the row. *)
      function GetFlags: TContestFlags; virtual;
      function GetQSOByBand: boolean;
      function GetQSOByMode: boolean;
      function GetMultByBand: boolean;
      function GetMultByMode: boolean;
      function GetVHFBandsEnabled: boolean;
      function GetCountsDomesticCountries: boolean;

      (* CQ ZONES OR ITU ZONES -- which list CTY.DAT answers a zone from.

         A STATED MAPPING, NOT A CAST, and that is the fix for inventory defect
         #2 (docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2a). The head wrote
         `ZoneModeType(<flag test> = 0)`: a Boolean cast to an enum. Delphi 7
         gave True the ordinal 1, so the D7 program got ITUZoneMode for a
         contest without the bit and CQZoneMode for one with it. FPC gave 255
         for True -- measured in the contest matrix, 160 of 185 contests --
         which is neither member, so every `case CTY.ctyZoneMode of` in
         uctydat matched no arm and a zone came back 0.

         The array's own legend states the rule this restores: ciCQZoneMode0
         is "ITU ZONE MODE", ciCQZoneMode1 is "CQ ZONE MODE". The bit is
         identical in D7's VC.pas for every contest (compared 2026-10-01).
         Since M10 S5 it is the set's cfCQZoneMode, mapped here. *)
      function GetZoneMode: ZoneModeType;

      (* A QSO PARTY'S OTHER DOMESTIC FILE -- the one an IN-STATE station
         loads. DomesticFileName is the file every other station loads: for a
         state party, the host's counties. '' for a contest that is not a QSO
         party. Default '' (M10 S6); it used to be the QSOParties entry the
         row's P indexed, and since M10 S5 every one of the 22 contests with
         an entry states its own file. *)
      function GetInStateDomesticFileName: string; virtual;

      (* THE AREA A QSO PARTY'S NEW CONTEST PROMPT NAMES -- M10 S5.

         The QSOParties entry's StateName: a two-letter state for a
         single-state party, and for the others what the dialog showed --
         the 7QP's '7th area', 'IN7QPNE', British Columbia's 'VE7'. NOT
         HostState, which was two letters only when it was derived from the
         table (VC.USQSOPartyStateName, deleted at M10 S6).
         Default '' -- not a QSO party (M10 S6). TContestStateQSOPartyBase
         answers its HostState, and the three that are not a two-letter state
         state their own. ASKED BY: the base's DescribeNewContestPrompts and
         the matrix's contest list (since M10 S6). ADIF's STATE asked it too
         (the two-letter ones only) until Q76/Q89, 2026-10-16; it is the
         worked station's now -- ADIFWorkedStationState. *)
      function GetQSOPartyArea: string; virtual;

      (* THE LAST TWO BITS OF THE ROW'S FLAG WORD -- M10 S0, 2026-10-14.

         ErmakSpecification: the contest offers the ERMAK Cabrillo
         specification to a Russian station (MainUnit's set-up, ERMAK_BIT).
         RTCCapable: the contest takes HamScore's real-time contact upload
         (uHamScore, RTC_CAPABLE_BIT).

         Both are members of the set like the seven above. MainUnit's ERMAK
         menu and uHamScore's contact upload ask them since M10 S6 (they read
         ContestsBooleanArray before). Test_MovedRowValuesStillMatchTheArray
         pins the class's answer against the table for every contest -- the
         matrix records neither. *)
      function GetErmakSpecification: boolean;
      function GetRTCCapable: boolean;

      (* DOES THIS CONTEST MARK A REPEATED CONTACT AS A DUPE? -- M3, 2026-10-01.

         A SPONSOR'S DUPE POLICY, AND IT WAS SPELLED AS A POINT METHOD.
         LOGSUBS2 skipped the dupe flag when the global ActiveQSOPointMethod
         was AlwaysOnePointPerQSO, whose only meaning beside OnePointPerQSO is
         VC.pas's own note "Ignores dupes". So the rule was "this contest counts
         every contact", reached through the scoring vocabulary -- and an
         operator's QSO POINT METHOD line reached it too, although it is a
         statement about points.

         THE BASE SAYS TRUE (M10 S4, 2026-10-14). It read the row -- True
         unless the row's point method was AlwaysOnePointPerQSO -- until the
         point method was deleted as a concept. Exactly two rows held that
         value, INTERNETSPRINT and YOUTHCHAMPIONSHIPRF, and they are exactly
         the two classes that override this to say False; so the constant is
         the row's answer for every contest, DUMMYCONTEST included. A contest
         that ignores dupes states it here. *)
      function GetMarksDupes: boolean; virtual;

      (* ~~GetCountyLineCountiesMax~~ AND ~~GetCountyLineAllowed~~ ARE NOT HERE.
         They are on TContestStateQSOPartyBase -- 2026-09-29, NY4I: "Arktika
         Spring is clearly not a qso party so I am not sure why that would be in
         the conversation of two counties", and "ARRL-DIGI is not of course
         either."

         A COUNTY LINE IS A QSO-PARTY CONCEPT, so putting it on the root made
         every contest in the program answer a question only about twenty of
         them can be asked -- and three classes duly answered it, two of which
         (Arktika Spring, ARRL Digital) have no counties at all.

         Moving it down is not tidiness. Nothing outside the QSO-party
         hierarchy can now EXPRESS a county-line rule, which is the same guard
         "a base must never ask which contest it is" buys one level up. *)

      (* THE CABRILLO QSO: LINE LAYOUT.

         A CONTEST-SHAPED FACT THAT WAS WRITTEN AS `if Contest = ...` IN
         PostUnit -- ARKTIKA-SPRING uses a narrower line than everything else --
         which is precisely the shape this factory exists to remove.

         SEPARATE FROM THE EXCHANGE COLUMNS. FormatCabrilloSentExchange and
         FormatCabrilloReceivedExchange arrange the columns; this is the line
         they are placed into, and a contest overrides either without the
         other -- Arktika Spring states its line and keeps the shared columns.

         The base answers CabrilloQSOLineFormatDefault, and PostUnit asks every
         contest through ContestIdentity, so a contest changes nothing here
         until it overrides. *)
      function GetCabrilloQSOLineFormat: string; virtual;

      (* THE CONTEST'S BONUS STATIONS -- declared data, M6. The base has none.
         See TBonusStation and BonusPoints. *)
      function GetBonusStations: TBonusStationList; virtual;

      (* WHAT THE DISPLAY AND THE REPORTS ASK -- M9a. See the properties. *)
      function GetTotalsDisplay: TTotalsDisplay; virtual;
      function GetSummarySheet: TSummarySheetLayout; virtual;
      function GetRequiresCabrilloLocation: boolean; virtual;
      function GetReportsRunningScore: boolean; virtual;
      function GetPermittedOperatingAids: TOperatingAids; virtual;
      function GetOffersQTCs: boolean; virtual;
      function GetOffersParkTools: boolean; virtual;

      (* WHAT THE UI ITSELF ASKS -- M9b. See the properties. *)
      function GetIsActive: boolean; virtual;
      function GetShowsContestStatus: boolean; virtual;
      function GetMaximumContestDates: integer; virtual;
      function GetMinimumOffTimeMinutes: integer; virtual;
      function GetBandStepIncludesWARC: boolean; virtual;
      function GetPowerFieldIsFOCNumber: boolean; virtual;

      (* WHICH CONTEST THIS INSTANCE IS -- READABLE BY SUBCLASSES, AND NOT TO BE
         BRANCHED ON.

         It exists for diagnostics and for the few places that legitimately need
         to name the contest in a message. A subclass that reads it to decide
         BEHAVIOUR has reintroduced the thing this class removes: state the
         behaviour as an override, or as a trait on the base. *)
      property Contest: TContestHandle read FContest;

      (* THE CONTEST'S ID -- its stored name (for a legacy contest, its
         ContestTypeSA spelling). The base's name fallbacks and its log
         messages read it; the same rule as Contest applies. *)
      property Id: string read FId;

      (* The station, as it was when this contest object was made or last
         refreshed.  Subclasses read this instead of the globals. *)
      property Station: TStationContext read FStation;
   public
      (* aContest is the registry's handle (Q108 S2). The registry makes
         the identity objects; a test makes one with
         Create(ContestHandleOf(<member>)). *)
      constructor Create(aContest: TContestHandle); virtual;

      (* IS THIS THE CONTEST aQso WAS LOGGED IN? -- 2026-10-17. For a caller
         holding an object that carries the station (ActiveContest) and a
         record that may belong to another contest: uADIF.EmitADIFRecord
         asks the station-carrying object only for its own contest's QSOs,
         and the identity object for any other ("a logged QSO reads its
         record"). It is a question, not a handle: Contest stays protected so
         that nothing branches on it. *)
      function IsContestOfQso(const aQso: ContestExchange): boolean;

      property DisplayName: string read GetDisplayName;
      property CabrilloName: string read GetCabrilloName;
      property ADIFContestId: string read GetADIFContestId;

      (* EVERY ADIF CONTEST_ID THIS CONTEST HAS BEEN EXPORTED UNDER BEFORE, AND
         IS NO LONGER. Import accepts them; export never writes them.

         NY4I, 2026-09-29, renaming several ids at once: "Yes support old
         spellings." An operator's existing files carry whatever TR4W wrote the
         day they were exported, and a rename must not make those files stop
         resolving to their contest.

         THE CONTEST OWNS ITS OWN HISTORY, rather than a table in the ADIF unit
         owning everyone's. A rename is a change to ONE contest, and the old
         name belongs beside the new one in that contest's file -- where the
         next person to rename it will see both. A central alias table would be
         a second place a contest's identity is written down, which is the
         drift RadioParametersArray demonstrated.

         WHAT GOES HERE is an id TR4W actually EMITTED. That includes the
         export fallback for a contest whose ADIFName was blank -- ADIF export
         wrote the enum's spelling (ContestTypeSA) then -- so a contest that
         gained an ADIF id also lists the spelling it used to be exported under.
         An id that only differed by surrounding whitespace does NOT go here:
         the lookup trims its input.

         EMPTY BY DEFAULT, and empty for every contest that has no class. A
         contest with no class therefore cannot carry a former id -- see the
         lookup, uContestRegistry.FindContestByADIFContestId. *)
      property FormerADIFContestIds: TContestIdList read GetFormerADIFContestIds;

      property WA7BNMId: integer read GetWA7BNMId;
      property SubmissionEmail: string read GetSubmissionEmail;
      property DomesticFileName: string read GetDomesticFileName;
      property FriendlyName: string read GetFriendlyName;
      property QRZRUId: integer read GetQRZRUId;
      property InitialExchangeKind: InitialExchangeType read GetInitialExchangeKind;
      property ExchangeKind: ExchangeType read GetExchangeKind;
      property ReceivedExchangeFields: ExchangeInformationRecord read GetReceivedExchangeFields;
      property ReceivesGridSquareExchange: boolean read GetReceivesGridSquareExchange;
      property IsUSQSOParty: boolean read GetIsUSQSOParty;

      (* ADIF facts -- see the getters. *)
      property ADIFPowerTag: string read GetADIFPowerTag;
      property WritesADIFContestId: boolean read GetWritesADIFContestId;

      (* Set-up's facts -- see the getters. Flags is the contest's whole set;
         each property below answers one member of it. *)
      property Flags: TContestFlags read GetFlags;
      property QSOByBand: boolean read GetQSOByBand;
      property QSOByMode: boolean read GetQSOByMode;
      property MultByBand: boolean read GetMultByBand;
      property MultByMode: boolean read GetMultByMode;
      property VHFBandsEnabled: boolean read GetVHFBandsEnabled;
      property CountsDomesticCountries: boolean read GetCountsDomesticCountries;
      property ZoneMode: ZoneModeType read GetZoneMode;
      property InStateDomesticFileName: string read GetInStateDomesticFileName;
      property QSOPartyArea: string read GetQSOPartyArea;
      property ErmakSpecification: boolean read GetErmakSpecification;
      property RTCCapable: boolean read GetRTCCapable;

      (* The dupe policy -- see the getter. LOGSUBS2 asks it through
         uContestRegistry.ContestIdentity when a QSO is logged. *)
      property MarksDupes: boolean read GetMarksDupes;

      (* THE TWO-LETTER POSTAL CODE OF THE STATE THIS CONTEST BELONGS TO.

         '' FOR ALMOST EVERY CONTEST, AND THAT IS A REAL ANSWER -- CQ WW has no
         host state. It is the single-state QSO parties that have one, and they
         need it because their QTHString carries a COUNTY: the ADIF exporter
         cannot name the state from the exchange and has to ask the contest. *)
      property HostState: string read GetHostState;

      property CabrilloQSOLineFormat: string read GetCabrilloQSOLineFormat;

      (* THE CONTEST'S NAME, for logging and for the "which class am I" question
         a bench session asks. Defaults to the enum's own spelling. *)
      
      (* THE THREE IDENTIFIERS EVERY CONTEST HAS, and TR4QT's
         docs/CONTEST_DEVELOPMENT.md says a contest class "must" define all
         three: the WA7BNM calendar id, the Cabrillo CONTEST: name, and the
         ADIF CONTEST_ID.

         NY4I: "We also need something in the classes where we set the cabrillo
         name and adif name in the factory."

         THEY DEFAULTED TO ContestsArray until M10 S6 -- the strangler: the
         table was the current answer, the class the eventual one. Since M9a
         every class states all three, and since M10 S6 the base answers the
         enum's spelling and reads no table (DUMMYCONTEST, the one contest
         with no class, has blank fields, so the spelling is what it always
         answered).

         THESE GETTERS ARE THE ONLY ANSWER, SINCE M1 (2026-10-01). Every
         consumer outside the factory -- the Cabrillo header, ADIF export, the
         UDP score and contact broadcasts, both score-posting clients, the
         external logger, the summary sheet, the log database and the calendar
         menus -- asks through uContestRegistry.ContestIdentity. Before M1 the
         two-step below existed in seven hand-written copies at those sites,
         and one of them had already drifted (logsubs2's contact broadcast
         tested the ACTIVE contest's CABName and then spelled the QSO's).

         CabrilloName AND ADIFContestId ARE THE SAME TWO-STEP: the row's field,
         else the enum's own spelling. That is what the exporters always wrote
         -- most contests have neither field -- so it is the default here, not
         just the field. Returning '' for the contests with no CABName would
         put an empty CONTEST: line in their headers.

         ADIFContestId WAS ONCE THE OTHER WAY ROUND, and that was inventory
         defect D9. It returned '' for a blank ADIFName, calling that "no ADIF
         id", while export wrote the enum's spelling -- so import
         (uContestRegistry.FindContestByADIFContestId, which matches this
         getter) could not resolve 139 contests' own export. The id is now
         WHAT EXPORT WRITES, by construction: one getter, read by both.

         ONE EXCEPTION, AND IT IS NOT HERE: POTA and GENERALQSO write no
         CONTEST_ID at all. Each says so through WritesADIFContestId -- General
         QSO since M4, POTA since it gained its class (2026-10-13, design Q6).
         Their ids still answer here, because the score-posting clients send
         them. *)
                  
      (* THE REST OF THE ContestsArray ROW.

         NY4I: "we also have to capture the details from the ContestArray such as
         CABName and ADIFName. All that content would be represented or processed
         in the contest class."

         So every field of the row gets an accessor, not only the three
         identifiers, and every one DEFAULTED TO THE ARRAY. That is what made the
         move incremental: a contest states what it wants to own and inherits the
         rest, and a contest with no class is unaffected because nothing reads
         these unless a class exists.

         WHY ACCESSORS RATHER THAN A COPY OF THE ROW. A copied record would be a
         second definition, and the two would drift the moment somebody edited
         the array -- which is the exact failure the radio factory hit with
         RadioParametersArray. Reading through means there is still one answer
         until a contest deliberately overrides.

         SubmissionEmail and DomesticFileName are PAnsiChar in the array, which
         is why they arrive as string here: a contest class should not be handing
         out pointers into a const table.

         SINCE M10 S5 (2026-10-14) NO REGISTERED CLASS INHERITS A NON-NEUTRAL
         VALUE from these defaults: the 15 that did (ARRL DX and SS, CQ WPX and
         WW, Florida, Michigan, General QSO, IARU, the NA Sprints, Winter Field
         Day) state them in the leaf. SINCE M10 S6 THE DEFAULTS READ NO TABLE:
         each is a constant, and the constants are DUMMYCONTEST's neutral row
         (see the implementation). The paragraphs above describe how the
         accessors began. *)
                                                                              
      (* SCORING -- THE ONE PUBLIC ENTRY POINT (M3, 2026-10-01; design 7.7).

         NY4I: "yes one public entry point". Every caller -- the engine's
         LOGSTUFF.CalculateQSOPoints, and through it live entry, the rescore,
         the editable log and the contest matrix; and the unit tests -- scores
         through this, and gets the order below whether or not it knows it:

           1. QSOPoints := 0;
           2. a band the contest does not use (UsesBand) scores 0 -- NY4I,
              2026-10-01, design 7.4 -- and nothing below is asked;
           2b. a worked station the entrant may not credit
              (CreditsWorkedStation -- a QSO party's host-area rule, Q107,
              2026-10-16) scores 0 the same way;
           3. the four QSO POINTS ... overrides the operator stated
              (Station.PointOverrides), each applying to the QSOs it matches;
           4. otherwise the contest's own rule, CalculateQSOPoints.

         That is exactly the order the engine ran it in before M3, moved here
         so it is written once. The overrides come after the band check on
         purpose: an override is the operator's point VALUE for contest QSOs,
         not permission to score one the contest does not count.

         NOT VIRTUAL. It is a template; a contest's rule is CalculateQSOPoints,
         which is protected so that nothing outside the hierarchy can score a
         QSO while skipping steps 1-3.

         A PROCEDURE ON A var RECORD, NOT A FUNCTION RETURNING POINTS. A
         contest's rule writes more than the points -- ARRL DX inhibits the
         multipliers of a W/VE-to-W/VE contact, and thirteen legacy arms write
         InhibitMults, DomMultQTH, DomesticMult, ZoneMult, Prefix or DXQTH. A
         function returning an integer would read as pure and hide those
         writes; this is the shape the engine's own entry already has. *)
      procedure ScoreQSO(var aQso: ContestExchange);

      (* DOES THIS CONTEST USE THIS BAND? -- the contest owns its bands.

         NY4I, 2026-10-01: a QSO on a band the contest does not use is LOGGED
         normally, "but we should not score it". It is not refused and not an
         automatic X-QSO ("that would be confusing to an op"), and it earns no
         multiplier ("correct, no multiplier credit for off-band QSOs"). "This
         rule applies to basically any contest."

         SO IT IS ONE QUESTION, ASKED WHEREVER A QSO COULD AFFECT THE CONTEST
         -- every time through ContestCreditsBand below, so none can forget
         the classless case:
           points       ScoreQSO (LOGSTUFF.CalculateQSOPoints until M3),
                        BEFORE the four QSO POINTS ... overrides, so an
                        operator's override cannot give an off-band QSO
                        points either;
           multipliers  logdupe's DupeAndMultSheet.SetMultFlags, after it has
                        cleared the four flags, so nothing is set and nothing
                        reaches the multiplier sheet;
           dupes        uCallsigns' TCallsignsList.AddCallsign marks no dupe
                        bit for an off-band QSO, and CallsignIsDupe calls none
                        a dupe (M8) -- "an off-band QSO is not a dupe and
                        makes no later QSO a dupe", NY4I, 7.4;
           the hint     LOGEDIT's need-multiplier display shows no off-band
                        band as needing a multiplier (CreditedBands, M8) --
                        "off-band should not impact need multiplier".

         THE BASE ANSWERS TRUE FOR EVERY BAND, which is exactly what every
         contest did before this existed. A contest that states its bands
         overrides; one that has not yet is unchanged, and a classless contest
         is unchanged by construction because ContestCreditsBand answers True
         for nil. Each contest's band rule is its own move. Idaho was first. *)
      function UsesBand(aBand: BandType): boolean; virtual;

      (* DOES THIS QSO EARN A MULTIPLIER OF THIS KIND AT ALL? -- M8,
         2026-10-02: stage 2 of design 7.7, "the contest DECLARES the rules;
         the shared sheet keeps the state".

         Asked by logdupe's DupeAndMultSheet.SetMultFlags, through
         ContestCountsMultiplier below, before it asks the sheet whether the
         multiplier is NEW. False means the QSO earns no multiplier of
         aKind whatever the sheet holds; True leaves it to the sheet. aKind
         is one of the sheet's four kinds -- rmDomestic, rmDX, rmZone,
         rmPrefix -- never rmNoRemMultDisplay.

         A RULE ABOUT THE QSO, NOT ABOUT THE LOG. Whether the multiplier was
         worked before is the sheet's question and stays there; this is what
         a sponsor writes as "a DX station is not a multiplier" or "your own
         branch does not count". Each such rule stood in SetMultFlags naming
         its contest (BC, NY and Indiana QSO parties, the PCC, the Jock White
         Field Day) and is the contest's own override now.

         A BAND THE CONTEST DOES NOT USE IS NOT ASKED HERE -- that is UsesBand,
         which SetMultFlags asks first, as ScoreQSO does. A contest never
         restates its band list in this.

         THE BASE ANSWERS TRUE FOR EVERY QSO AND KIND, which is exactly what
         SetMultFlags did for every contest it did not name. *)
      function CountsAsMultiplier(const aQso: ContestExchange;
                                  aKind: RemainingMultiplierType): boolean; virtual;

      (* MAY THIS ENTRANT CREDIT A QSO WITH THIS WORKED STATION AT ALL? --
         Q107 (NY4I, 2026-10-16: "yes, go with your recommendation").

         A QSO party's out-of-area entrant works only the host area. That
         was enforced only when a QSO was TYPED (the M5b refusal, design
         7.10), so an imported, networked or rescored QSO scored against the
         rule. Under Q13 a logged QSO is scored from its record by the
         contest's rules, so the rule is asked here too.

         FALSE MEANS THE QSO IS LOGGED, SCORES 0 AND EARNS NO MULTIPLIER --
         exactly an off-band QSO (UsesBand), and asked in the same two
         places: ScoreQSO, after the band check and BEFORE the four QSO
         POINTS overrides (an override is a point value, not permission to
         score a QSO the contest does not count), and logdupe's
         SetMultFlags, after its band exit, through
         ContestCreditsWorkedStation. So CalculateQSOPoints and
         CountsAsMultiplier never see such a QSO, and a class must not repeat
         the rule there. The dupe sheet is NOT asked (an uncredited QSO is
         still a contact with that call), unlike the band rule.

         A CLASS THAT STATES THE RULE CALLS HostAreaRuleCredits -- the ONE
         predicate, which its ParseReceivedExchange refusal calls too, with
         the same QTH text and the same table. THE BASE ANSWERS TRUE: a
         contest with no host area credits every worked station, which is
         what every contest did before this existed. *)
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; virtual;

      (* THE DOMESTIC MULTIPLIER A CALL IMPLIES BEFORE ANY EXCHANGE IS TYPED
         -- M8, 2026-10-02.

         The need-multiplier hint (LOGEDIT's EditableLog.GetMultArray, behind
         DetermineIfNewMult and the "needs" display) asks it when no exchange
         has been typed: a Russian station's oblast from its call, a grid
         from CTY.DAT, the exchange the log remembers for that call. Each
         rule stood in GetMultArray's `case Contest of` and is its contest's
         own now. aLookups carries what only the engine holds (see
         TMultiplierHintLookups).

         A HINT, NOT A CREDIT. What the QSO earns is decided from the typed
         exchange by SetMultFlags; this only says what to show while the call
         is in the window. THE BASE ANSWERS '' -- no opinion -- which is what
         GetMultArray did for every contest it did not name. *)
      function DomesticMultiplierFromCall(const aCall: string;
                                          const aLookups: TMultiplierHintLookups): string; virtual;

      (* THE PREFIX MULTIPLIER KEY A QSO EARNS IN THIS CONTEST -- M11 S3,
         2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S3).

         LOGEDIT.SetPrefix asks it, fetching the contest once per QSO; it is
         the only place a prefix KEY is computed (the QSO editor, the log
         read and the binary-log import copy a stored one). The rule stood in
         SetPrefix as `case ContestSession.PrefixMult of`, an enum choosing a
         computation FOR the contest; each prefix contest states its own now,
         calling uPrefixMultiplierKey where the computation is shared.

         TRUE WITH aKey MEANS "THE QSO'S PREFIX IS aKey" -- possibly empty.
         FALSE MEANS "LEAVE THE QSO'S PREFIX AS IT WAS", which is not the
         same thing: several old arms assigned only on a match and the
         rescore runs over a stored record, so the distinction is kept
         exactly. aKey is the field's own type, so no conversion stands
         between the rule and the record.

         A RULE THAT DEPENDS ON THE ENTRANT ASKS Station (UBA, SAC, WAE, the
         All Asian, OK DX, CQ MM, the South American WW, YB DX). Station is
         refreshed on every ActiveContest call, so the rule follows MY CALL
         live. Where the entrant decides whether there is a prefix
         multiplier at all, the key asks HasPrefixMultiplier, so the two
         answers cannot disagree.

         THE BASE ANSWERS FALSE -- what SetPrefix did for every
         NoPrefixMults session. *)
      function PrefixMultiplierKey(const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean; virtual;

      (* DOES THIS CONTEST HAVE A PREFIX MULTIPLIER AT THIS STATION? -- M11 S3
         part 2, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S3, F20).

         It replaces the session's prefix KIND, deleted with PrefixMultType:
         the engine asked `kind <> NoPrefixMults` (ContestSession's
         DoingPrefixMults) whether to set a prefix at all, size the prefix
         column, count the remaining prefixes and total them. That question
         has no QSO in hand, so it cannot be "does the key assign", and it is
         answered here, per contest, against Station.

         LIVE, NOT FIXED AT SET-UP. The kind was resolved once, by
         FoundContest, while the key read Station on every call; a
         mid-session change of the entrant's country left them disagreeing
         (plan F20). Both read Station now. A contest whose answer depends on
         the entrant tests exactly what its DescribeSession tested to choose
         the kind (UBA, the All Asian, OK DX, WAE, SAC); every other prefix
         contest answers True.

         INVARIANT: PrefixMultiplierKey assigns only where this is True --
         pinned for every contest at every roster station by
         uTestPrefixMultiplierKey. THE BASE ANSWERS FALSE. *)
      function HasPrefixMultiplier: boolean; virtual;

      (* THE DX MULTIPLIER KEY A QSO EARNS IN THIS CONTEST -- M11 S4,
         2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S4).

         LOGDUPE.GetDXQTH asks it, after its own engine head (COUNT DOMESTIC
         COUNTRIES, the WYSIWYG domestic QTH, the domestic-country call),
         which is not a contest rule and stays there. The rule stood in
         GetDXQTH as `case ContestSession.DXMult of`, an enum choosing which
         countries count FOR the contest; each DX contest states its own now,
         calling uDXMultiplierKey where a country list is shared.

         TRUE WITH aKey MEANS "THE QSO'S DX QTH IS aKey" -- possibly empty
         (ARI's first-letter test on an empty country). FALSE MEANS "LEAVE
         THE QSO'S DX QTH AS IT WAS": every arm of the old case assigned only
         on a match, and the rescore runs over a stored record. aKey is the
         field's own type, so no conversion stands between rule and record.

         A RULE THAT DEPENDS ON THE ENTRANT ASKS Station (ARRL DX, ARRL 160,
         the All Asian, JIDX, SAC, Helvetia, the Croatian, WAG, UBA, WAE,
         PACC, RDA, the ALRS cup, YU DX's list, and the parties' host-state
         rules), testing exactly what its DescribeSession tested to choose the
         session's DX kind. Station is refreshed on every ActiveContest call,
         so the rule follows MY CALL live -- and since M11 S4 part 2 so does
         whether GetDXQTH runs at all (HasDXMultiplier, below; F21 closed).

         THE BASE ANSWERS FALSE -- what GetDXQTH did for every NoDXMults
         session. *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; virtual;

      (* DOES THIS CONTEST HAVE A DX MULTIPLIER AT THIS STATION? -- M11 S4
         part 2, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S4, F21).

         It replaces the session's DX KIND, deleted with DXMultType: the
         engine asked `kind <> NoDXMults` (ContestSession's DoingDXMults)
         whether to run GetDXQTH at all, flag a DX multiplier, show the DX
         column, list the remaining countries and total them. That question
         has no QSO in hand, so it cannot be "does the key assign", and it is
         answered here, per contest, against Station.

         LIVE, NOT FIXED AT SET-UP. The kind was resolved once, by
         FoundContest, while the key, the country list and the remaining-
         countries filter read Station on every call; a mid-session change of
         the entrant's country, continent or host state left them disagreeing
         (plan F21). All read Station now. A contest whose answer depends on
         the entrant tests exactly what its DescribeSession tested to choose
         the kind, through the private predicate its key and country list
         already ask (ARRL DX, ARRL 160, the All Asian, JIDX, SAC, Helvetia,
         the Croatian, WAG, WAE, PACC, RDA, the ALRS cup and the host-state
         parties); every other DX contest answers True.

         INVARIANT: DXMultiplierKey assigns only where this is True -- pinned
         for every contest at every roster station by uTestDXMultiplierKey.
         THE BASE ANSWERS FALSE. *)
      function HasDXMultiplier: boolean; virtual;

      (* WHICH CTY COUNTRY LIST THIS CONTEST COUNTS -- M11 S4, 2026-10-14.
         ARRLCountryMode is DXCC only; CQCountryMode is DXCC plus the WAE
         countries. The CONTEST setting's effect (uSettingsEffects) asks it
         once, straight after FoundContest, and tells CTY.DAT; it stood there
         as `ContestSession.DXMult in [the six ARRL kinds]`. This is DATA, the
         list CTY.DAT resolves calls against, so CountryModeType outlives the
         DX kind (M11 S4 part 2).

         CQ IS THE ANSWER FOR NO DX MULTIPLIER TOO -- a station that runs
         none gets the CQ list, and so does the North American kind, its
         ARRL-sounding name notwithstanding: the set never held it. A rule
         that depends on the entrant asks Station, as DXMultiplierKey does.
         THE BASE ANSWERS CQCountryMode. *)
      function CountryMode: CountryModeType; virtual;

      (* DOES THE REMAINING-MULTS WINDOW LIST THIS COUNTRY? -- M11 S4,
         2026-10-14. uMults.FillVisibleBytes asks it per CTY country, only
         where the contest has a DX multiplier (HasDXMultiplier). It reproduces the window's
         filters exactly (WAE's European countries for an entrant outside
         Europe, UBA's list for an entrant outside Belgium; the third, the
         non-European countries, ran for no contest) -- NOT the whole DX
         rule, which the window never knew (plan F7). THE BASE ANSWERS
         TRUE. *)
      function ListsRemainingDXCountry(const aCountryID: DXMultiplierString;
                                       aContinent: ContinentType): boolean; virtual;

      (* DOES THIS CONTEST HAVE A ZONE MULTIPLIER AT THIS STATION? -- M11 S5
         part 2, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S5).

         It replaces the session's ZONE KIND, deleted with ZoneMultType: the
         engine asked `kind <> NoZoneMults` (ContestSession's DoingZoneMults)
         whether to flag a zone multiplier, set up and list the remaining
         zones, show the zone totals, add the zone to the hint and blank the
         zone column. That question has no QSO in hand, and it is answered
         here, per contest, against Station -- LIVE, as HasDXMultiplier and
         HasPrefixMultiplier are, so a mid-session change of MY CALL without
         a CONTEST change is followed (the kind was resolved once, by
         FoundContest).

         Eighteen contests answer True at every station; JIDX CW and SSB answer
         True for a Japanese entrant only, through the private predicate
         their zone count, zone list and DX answers already ask -- the test
         DescribeSession stated the zone kind under.

         INVARIANT: True exactly where ZoneMultiplierCount is above 0 --
         pinned for every contest at every roster station by
         uTestZoneMultiplier. THE BASE ANSWERS FALSE. *)
      function HasZoneMultiplier: boolean; virtual;

      (* HOW MANY ZONES THIS CONTEST'S ZONE MULTIPLIER HAS -- M11 S5,
         2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S5).

         LOGDUPE.SetUpRemainingMultiplierArrays asks it, where the contest
         has a zone multiplier (HasZoneMultiplier), for MaxNumberOfZones --
         the zones the remaining-mults window walks. It stood there as `case
         ContestSession.ZoneMult of` (CQ 40, ITU 75, the year licensed 100,
         the NZART branch 99, the RF Championship 7; the JA-prefecture arm,
         50, ran for no contest and is gone). A rule that depends on the
         entrant asks Station, testing exactly what its DescribeSession tested
         to state the zone kind (JIDX: a Japanese entrant counts CQ zones).
         THE BASE ANSWERS 0. *)
      function ZoneMultiplierCount: integer; virtual;

      (* WHICH ZONE LIST THE ZONE MULTIPLIER COUNTS -- M11 S5. The one
         question five sites asked of the session kind: the need-multiplier
         hint (CQ or ITU zone of a call), the ITU initial zone, POSTUNIT's
         ZoneSentForThisContest and the ADIF CQZ/ITUZ tag. NOT the CTY zone
         mode -- see TZoneMultiplierZones. A rule that depends on the entrant
         asks Station, as ZoneMultiplierCount does. THE BASE ANSWERS
         zmzNotCQOrITU. *)
      function ZoneMultiplierZones: TZoneMultiplierZones; virtual;

      (* DOES THE ZONE MULTIPLIER NUMBER ITS ZONES FROM ZERO? -- M11 S5. The
         remaining-mults window lists zone i as i - 1 when it does. It stood
         in LOGEDIT.ShowRemMultsInWindow as `ContestSession.ZoneMult =
         EUHFCYear`: True for the European HF Championship and KVP, whose
         "zone" is the year licensed, 00 to 99. THE BASE ANSWERS FALSE. *)
      function NumbersZonesFromZero: boolean; virtual;

      (* WHAT A RECEIVED DOMESTIC QTH MEANS IN THIS CONTEST -- M11 S6 part 1,
         2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S6).

         LOGDOM.GetDomQTH asks it, after its own engine head (the outputs
         zeroed, the text upper-cased, and the no-domestic-multiplier exit,
         which still asks the session) and before the domestic-file lookup,
         which is the engine's table and stays there. The rule stood in
         GetDomQTH as `if ContestSession.DomesticMult = ...`, six arms
         choosing a shape FOR the contest -- an RDA district, the text as
         written (WYSIWYG), a DOK, an IOTA reference, a grid square, a grid
         field; each contest whose QTH is one of those states its own now,
         calling uDomesticKey where a shape is shared.

         aMultiplier, aQTH AND aFound ARE THE ENGINE'S, ZEROED; a rule writes
         what it decides and leaves the rest. dqaDecided ends the lookup with
         aFound as the answer. dqaLookUpDomesticFile hands on to the file
         lookup WITH WHATEVER WAS WRITTEN -- the RSGB IOTA's valid reference
         reaches the file already found, as GetDomQTH's IOTA arm, which had
         no Exit, always did (plan F6, transcribed and not fixed).

         A RULE THAT DEPENDS ON THE ENTRANT ASKS Station (the ALRS cup, WAG,
         the DARC 10 m), testing exactly what its DescribeSession tests to
         choose the session's domestic kind.

         THE BASE ANSWERS dqaLookUpDomesticFile and writes nothing -- what
         GetDomQTH did for every DomesticFile and NumericID session. *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; virtual;

      (* WHAT THE NEED-MULTIPLIER HINT SHOWS FOR A REMEMBERED EXCHANGE -- M11
         S6 part 1. LOGSTUFF.DomStringParse asks it (behind LOGEDIT's station
         information) with the initial exchange the log remembers for a call,
         upper-cased. It was DomStringParse's copy of GetDomQTH's ladder (plan
         F6), which never consulted the domestic file: a shape answers its
         key, or '' when the text does not have the shape. A rule that
         depends on the entrant asks Station, as DomesticMultiplierFromQTH
         does. THE BASE ANSWERS THE TEXT ITSELF -- what DomStringParse did
         for every other session. *)
      function DomesticMultiplierHint(const aText: Str14): string; virtual;

      (* IS THE DOMESTIC MULTIPLIER THE FOUR-CHARACTER GRID SQUARE, A ROVER
         BEING WORKED AGAIN IN EVERY SQUARE? -- M11 S6 part 1. Four engine
         sites asked `ContestSession.DomesticMult = GridSquares`: a rover is
         never a dupe (LOGEDIT.CallIsADupe), a rover's squares worked before
         zero its points (LOGSUBS2.LogContact), the partial-call mults are
         shown from any window (LOGSUBS2.ShowPartialCallMults), and the grid
         status (LOGSTUFF.DisplayGridSquareStatus). True for the ARRL VHF
         contests, the CQ VHF, the OZHCR VHF and the RTC, each holding its
         own copy (design 1.4). THE BASE ANSWERS FALSE. *)
      function HasGridSquareMultiplier: boolean; virtual;

      (* IS THE DOMESTIC MULTIPLIER THE TWO-LETTER GRID FIELD? -- M11 S6 part
         1. The sheet keys such a multiplier on the field and reads an old
         log's four-character keys too (uMults.IsDmMult), and WSJT-X's
         station hint shows the field (uWSJTX); both asked
         `ContestSession.DomesticMult = GridFields`. True for the Russian
         Cups CW and SSB, TOEC, WW Digi and WWL. THE BASE ANSWERS FALSE. *)
      function HasGridFieldMultiplier: boolean; virtual;

      (* DOES A DOMESTIC QTH TAKE THE PLACE OF THE DX MULTIPLIER? -- M11 S6
         part 1. LOGDUPE.GetDXQTH gives no DX QTH to a QSO that has a
         domestic QTH (unless COUNT DOMESTIC COUNTRIES) in a contest whose
         domestic multiplier is the text as written; it asked
         `ContestSession.DomesticMult = WYSIWYGDomestic`. True for the eleven
         WYSIWYG contests, at the stations that run it (the ALRS cup but for
         a Russian entrant who counts RDA districts, the DARC 10 m for a
         German entrant only). THE BASE ANSWERS FALSE. *)
      function DomesticQTHReplacesDXMultiplier: boolean; virtual;

      (* IS A DOMESTIC QTH THAT LOOKS LIKE A GRID NEVER ONE? -- M11 S6 part 1.
         An RDA district ('MO12') has a grid square's shape; the ADIF tail
         (POSTUNIT) writes such a QTH as GRIDSQUARE unless the contest says
         no. It asked `ContestSession.DomesticMult <> RDADistrict`. True for
         RDA, and for the ALRS cup at a Russian entrant who counts RDA
         districts. THE BASE ANSWERS FALSE. *)
      function DomesticQTHIsNeverAGrid: boolean; virtual;

      (* IS THE DOMESTIC QTH LOOKED UP IN THIS CONTEST'S DOMESTIC FILE? -- M11
         S6 part 1b, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S6).

         Two engine sites asked `ContestSession.DomesticMult = DomesticFile`:
         LOGSUBS2.LogContact rewrites a mobile's call to call/QTH in such a
         contest (a QSO party's rover), and uContestReadiness reports such a
         contest with no file named. It is STATED, not derived: the
         contest's domestic file NAME says nothing about it (plan 2.6 -- eight
         contests disagree).

         A CONTEST THAT ANSWERS TRUE STATES NO SHAPE: its
         DomesticMultiplierFromQTH is the base's (consult the file) and none
         of the four flags above is set -- pinned for every contest at every
         roster station by uTestDomesticMultiplier.

         STATED ONCE PER FAMILY WHERE THE RULE IS THE FAMILY'S -- the state
         QSO parties (each counts the counties and states of its .dom),
         Sweepstakes' two modes and the NRAU-Baltic's -- and per class
         otherwise. A rule that depends on the entrant asks Station, testing
         exactly what its DescribeSession tests to state DomesticFile (ARRL
         DX, JIDX, OK DX, UBA, the Ukrainian DX, YU DX).

         THE BASE ANSWERS FALSE -- every contest whose session ran another
         domestic kind, or none. *)
      function UsesDomesticFile: boolean; virtual;

      (* DOES THIS CONTEST HAVE A DOMESTIC MULTIPLIER AT THIS STATION? -- M11
         S6 part 2, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S6, F23).

         It replaces the session's DOMESTIC KIND, deleted with
         DomesticMultType: the engine asked `kind <> NoDomesticMults`
         (ContestSession's DoingDomesticMults) whether to read a domestic QTH
         at all, flag a domestic multiplier, show the domestic column, list
         the remaining domestic multipliers and total them. That question has
         no QSO in hand, and it is answered here, against Station -- LIVE, as
         HasDXMultiplier, HasPrefixMultiplier and HasZoneMultiplier are, so a
         mid-session change of MY CALL without a CONTEST change is followed
         (F23 closed: the kind was resolved once, by FoundContest, while the
         rules read Station).

         COMPOSED ONCE, HERE, FROM WHAT EACH CONTEST ALREADY STATES: a
         contest looks its domestic QTH up in its file (UsesDomesticFile), or
         states one of the shapes whose answers the engine asks
         (HasGridSquareMultiplier, HasGridFieldMultiplier, the WYSIWYG
         DomesticQTHReplacesDXMultiplier, the RDA DomesticQTHIsNeverAGrid).
         So the 94 domestic-file contests and the 22 with such a shape state
         nothing more. THE THREE WHOSE SHAPE HAS NO SUCH ANSWER OVERRIDE IT:
         the RSGB IOTA (an IOTA reference) and WAG and the DARC 10 m (a DOK,
         outside Germany).

         INVARIANT: True exactly where the contest reads a domestic QTH --
         looks it up in its file, or decides at least one text itself --
         pinned for every contest at every roster station by
         uTestDomesticMultiplier. THE BASE'S COMPOSITION IS FALSE FOR A
         CONTEST THAT STATES NONE OF THEM. *)
      function HasDomesticMultiplier: boolean; virtual;

      (* THE EXCHANGE RULES THE ENGINE DECIDED BY THE SESSION'S SHAPE -- M11
         S7, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S7).

         Each was a test of ContestSession.Exchange outside the four shape
         machines: a sponsor's decision written as "the exchange is spelled
         this way". Each is now the contest's own answer, STATED PER CLASS
         FOR EXACTLY THE CONTESTS WHOSE SESSION RAN THE TESTED SHAPES, and
         where the entrant decides that shape, asking Station through the
         test its DescribeSession chooses the shape by. Pinned for every
         contest at every roster station by uTestExchangeRules, with a
         cross-check against the old compares until S9 deletes the shape.

         THE BASE ANSWERS FALSE TO EACH.

         IS A CALL'S /SUFFIX A ROVER'S COUNTY? MainUnit's two rover routines
         strip a /suffix the domestic table knows before the country lookup,
         and offer it as the exchange. S7 transcribed it from the
         RSTDomesticQTH, RSTQTH and RSTDomesticOrDXQTH shapes (25 contests).

         NY4I RULED ON Q94 WITH Q90 (2026-10-14): "yes QSO parties allow it
         but in any contest NY4I/7 or VP9/NY4I is a valid call." A /suffix
         is a county rover ONLY IN A QSO PARTY, and there it is BOTH
         stripped here AND split on export (SplitsRoverCallOnExport, below).
         So every state party answers True on TContestStateQSOPartyBase;
         the multi-state parties (7QP, NEQP, IN7QPNE) state it on their own
         classes; County Hunter keeps its strip (a decision recorded in
         docs/CONTEST_FACTORY_OPEN_QUESTIONS.md Q94, not NY4I's). Every
         other contest leaves the slash call alone -- the ARRL DX, ARRL
         160, PACC, LABRE, TOEC and ALRS stopped stripping. *)
      function StripsRoverCountyFromCall: boolean; virtual;

      (* DOES ADIF EXPORT WRITE A ROVER'S CALL AS THE BARE CALL PLUS
         APP_TR4W_ROVERCALL? -- uADIF.ResolveRoverCall, through
         uContestRegistry.ContestSplitsRoverCallOnExport, and only where the
         /suffix is the QSO's own QTH. M10 S8 put it on the state-party base
         for the fifteen parties whose deleted row said CountyLineAllowed;
         Q90/Q94 (2026-10-14, above) made it every QSO party's answer, and
         it moved here so a multi-state party, which is not on that base,
         can state it. True exactly where StripsRoverCountyFromCall is,
         except County Hunter, which strips and does not split. *)
      function SplitsRoverCallOnExport: boolean; virtual;

      (* IS THE RECEIVED QTH PART OF THE DUPE KEY? -- False (the base): the
         dupe key is the call as logged, on the band and mode, as it has
         always been. True says the same call on the same band and mode is a
         NEW QSO when the QTH it SENT differs: Q118, NY4I 2026-10-17, "New
         QSO per county" for the New York QSO Party, then "All state
         parties" -- TContestStateQSOPartyBase answers True (DXLog's
         DOUBLE_QSO=PER_BAND_MODE_RCVD / _RECINFO for every one of them).

         THE ONE VIRTUAL; DupeKeyQualifier, below, is derived from it and is
         deliberately not virtual, so a class cannot say "qualified" while
         answering no qualifier, or the reverse -- the shape CountyLineAllowed
         uses. Asked of ContestIdentity (the answer must not depend on the
         station; a class that ever makes it so must move LOGEDIT's callers to
         ActiveContest). Pinned by uTestNYQPRover. *)
      function DupeKeyIncludesReceivedQTH: boolean; virtual;

      (* THE TEXT, BESIDES THE CALL, THAT MAKES aQso A NEW QSO FOR DUPES --
         '' when DupeKeyIncludesReceivedQTH is False, else the QSO's own
         received QTH: the domestic QTH the contest's file resolved it to,
         else the text as typed (a DX station's DX), upper case; '' when
         nothing was received, which is the call alone.

         READ FROM THE RECORD, never from live state ("a logged QSO reads its
         record"), so the live check at LogContact, the log loader and the
         rescore build one dupe sheet (LOGEDIT.QSOIsADupe and
         AddQSOToDupeSheets). A check made BEFORE the exchange exists has no
         record and asks the call alone (EditableLog.CallIsADupe), as it
         always has: a call worked from one county shows DUPE until the QSO
         from the new county is logged -- NY4I, 2026-10-18, "a reasonable
         compromise" (Q118). *)
      function DupeKeyQualifier(const aQso: ContestExchange): string;

      (* WHOSE COUNTY IS THIS QSO'S QTH? -- the state (or province) of the
         party county the QSO's QTH names, '' when it names none (a state, a
         province, DX, nothing). Read by ADIFWorkedStationState, below, and
         by PostUnit's CNTY block as the county's prefix (Q76/Q89, NY4I
         2026-10-16). The QTH is uADIF.ADIFPartyQTHKey: the domestic table's
         key, else the logged QTH.

         EACH PARTY KNOWS ITS OWN SPELLING. A single-state party
         (TContestStateQSOPartyBase) answers its HostState for any key that
         is not two letters -- every county key in target/dom is longer,
         every state and province key is two. The 7QP's keys lead with the
         state (AZAPH), New England's end with it (ANDME), and IN7QPNE routes
         its own (IN7QPNEPartyOfQTH; Delaware's NDE/KDE/SDE are DE).
         Base ''. *)
      function ADIFCountyState(const aQso: ContestExchange): string; virtual;

      (* THE ADIF STATE OF THE WORKED STATION -- uADIF.GetADIFStateForQSO,
         read by EmitADIFRecord for a QSO carrying a QTH. ADIF's STATE is
         "the contacted station's Primary Administrative Subdivision (e.g.
         US State, JA Island, VE Province)" (Q89), and the entrant's own is
         MY_STATE (Q76, NY4I 2026-10-16).

         A QSO PARTY ANSWERS uADIF.ADIFStateOfPartyQSO(ADIFCountyState(aQso),
         aQso): the county's state for a party county, the QTH itself when
         it is a code ADIF allows for the worked station's country (an
         out-of-state station's state, a VE's province), else '' (DX). Stated
         once on TContestStateQSOPartyBase, and by the 7QP, New England and
         IN7QPNE classes.

         D7, AND THIS PROGRAM UNTIL Q76, wrote the PARTY's state on every QSO
         carrying a QTH -- a Michigan log said STATE:MI for a station in DC
         -- and British Columbia none at all, because the old test wanted a
         two-letter QSOPartyArea and BC's is 'VE7'. Base '': no other
         contest's QTH is known to be a state, so none writes one here. *)
      function ADIFWorkedStationState(const aQso: ContestExchange): string; virtual;

      (* DOES ADIF EXPORT WRITE CNTY (state,county) FOR A QSO OF THIS PARTY?
         -- PostUnit's CNTY block, beside ADIFCountyState, which is the
         county's prefix (Q89, NY4I 2026-10-16). ADIF's CNTY is an
         ENUMERATION (Secondary Administrative Subdivision, ADIF 3.1.6
         III.B.22) defined for Alaska, Hawaii, the USA, the Russian entities,
         Ukraine, Japan, New Zealand and Spain and NOTHING for Canada, so a
         BC regional district written there is a value the spec does not
         allow: British Columbia answers False and its district goes to the
         sponsor in the Cabrillo exchange only. True on
         TContestStateQSOPartyBase; base False. *)
      function WritesADIFCounty: boolean; virtual;

      (* DOES ONE SEARCH-AND-POUNCE ENTRY CARRY SEVERAL QTHs? --
         MainUnit.ReturnInSAPOpMode, after logging, re-enters the first QTH of
         an exchange whose second field is a word. It asked for the
         RSTDomesticQTH and RSTQTH shapes: 21 contests, a subset of the
         rover's (plan F4). *)
      function LogsSeveralQTHsFromOneEntry: boolean; virtual;

      (* MAY THE RECEIVED EXCHANGE BE BLANK? -- ParametersOkay logs a QSO
         with an empty exchange, and LOGSTUFF.ProcessExchange hands one that
         ParseArray cannot cut to the contest, only where this says so. It
         asked for the RSTNameAndQTH and RSTAndPOTAPark shapes: BWQP, the
         General QSO and POTA. *)
      function AcceptsBlankExchange: boolean; virtual;

      (* DOES THE ZONE EXCHANGE CARRY THE STATE SENT? -- FCONTEST's zone
         messages append the state this contest sends (SentMyState, when
         there is one) after the zone. It asked for the
         RSTZoneAndPossibleDomesticQTH shape: CQ WW RTTY. *)
      function SendsStateAfterZone: boolean; virtual;

      (* WHAT THE EXCHANGE CARRIES -- M11 S9d, 2026-10-15
         (docs/CONTEST_FACTORY_M11_PLAN.md S9d). The S7 treatment for the
         last readers of the session's shape that decided a rule: each was a
         set of exchange kinds, now the contest's own answer, stated per
         class for exactly the contests whose session ran a kind in the set,
         asking Station where the entrant decides it. Pinned for every
         contest at every roster station by uTestExchangeRules, with a
         cross-check against the old sets until S9e deletes the kind.

         THE BASE ANSWERS FALSE TO EACH.

         DOES THE EXCHANGE CARRY A DOMESTIC QTH? uContestReadiness's
         DOMESTIC_QTH_EXCHANGES: the readiness check reports an empty MY
         STATE for it, and LOGSTUFF's improper-domestic-QTH refusal names MY
         COUNTRY as the setting that chose the exchange (ExchangeModeAttribution).
         A ZONE? ZONE_EXCHANGES: the readiness check reports an empty MY
         ZONE. A GRID SQUARE? GRID_EXCHANGES: an empty MY GRID. ALL THREE
         ARE TRANSCRIBED, NOT JUDGED (plan F28): they are sets of RECEIVED
         kinds standing for what the station SENDS, and the grid one is the
         third grid set in the tree, which disagrees with the other two
         (ReceivesGridSquareExchange, and ExchangeTextMayHoldGridSquare --
         uGridShape.GRID_CARRYING_EXCHANGES until M11 S9e part 1). *)
      function ExchangeCarriesDomesticQTH: boolean; virtual;
      function ExchangeCarriesZone: boolean; virtual;
      function ExchangeCarriesGridSquare: boolean; virtual;

      (* MAY A WORD OF THIS CONTEST'S EXCHANGE BE READ AS A GRID SQUARE? --
         M11 S9e part 1 (S9f), 2026-10-15. TREE.LooksLikeAGrid asks it FIRST,
         before any string work, and answers False without looking at the
         text when it is False: the call-history window's beam heading
         (LOGWIND, LOGEDIT), the VHF beam heading in the call window
         (MainUnit), the ADIF tail's GRIDSQUARE (PostUnit) and the external
         logger's (uExternalLogger).

         It was `ContestSession.Exchange in uGridShape.GRID_CARRYING_EXCHANGES`
         (RSTAndOrGrid, Grid2, RSTAndGrid3, Grid, RSTQSONumberAndGridSquare,
         RSTNameAndQTH, RSTAndPOTAPark, RSTAndGrid), and each class states it
         for exactly the contests whose session ran one of those kinds: 18,
         the same at every station. TRANSCRIBED, NOT JUDGED (plan F28): it is
         the FOURTH grid answer in the tree -- it holds BWQP, the General QSO
         and POTA (a name-and-QTH or park exchange whose QTH word may be a
         grid) and not the Cup RF or Grid Loc, which ExchangeCarriesGridSquare
         does. THE BASE ANSWERS False.

         NO STATION DECIDES IT, so LooksLikeAGrid asks the contest's IDENTITY
         (uContestRegistry.ContestIdentity, no station, no rebuild) -- pinned
         station-independent by uTestExchangeKindReaders. A contest that ever
         answers it from Station must move that reader to ActiveContest. *)
      function ExchangeTextMayHoldGridSquare: boolean; virtual;

      (* DOES THE PER-QSO EXCHANGE STRING LEAD WITH THE SERIAL? --
         MainUnit.PerQSOExchString, which writes each QSO of a multi-county or
         multi-park entry its own SRX_STRING (Issue #889), leads with the
         received serial where the sponsor's exchange does (the California,
         Pennsylvania and Virginia parties, as its comment says) and with
         the RST everywhere else. It asked for the QSONumberDomesticQTH and
         QSONumberDomesticOrDXQTH shapes (M11 S9d), which the Ural Cup and the
         Ukraine Championship run too. *)
      function PerQSOExchangeLeadsWithSerial: boolean; virtual;

      (* IS THIS CONTEST RUN IN THIS MODE? -- an IDENTITY question, asked of
         an ADIF record, and of nothing else (M7b batch 2, 2026-10-02).

         ADIF's CONTEST_ID cannot always name one contest: RSGB-ROLO is ADIF's
         id for both RSGB RoPoCo runnings, the CW and the SSB, and TR4W keeps
         them as two ContestTypes. Once the whole record is read, the importer
         asks the contests that share the record's id which of them runs in
         its MODE (uContestRegistry.ContestOfADIFRecordMode); the lowest that
         says yes is the record's contest, and when none does the id's own
         answer stands.

         IT DOES NOT SCORE. A QSO in another mode is not refused, credited or
         zeroed by this -- that would be a band-like rule (UsesBand), and no
         contest has stated one for modes. THE BASE ANSWERS TRUE FOR EVERY
         MODE, so a contest that shares no id is untouched by construction. *)
      function RunsInMode(aMode: ModeType): boolean; virtual;

      (* IS THIS RECEIVED CLASS LEGAL FOR THIS CONTEST?

         NY4I, 2026-09-02, on where the exchange rules go: "Shouldn't this class
         have a function called ValidExchange where we move the exchange rules?
         Basically, anywhere the main program goes through a case statement on
         the contest type."

         LOGSTUFF.ValidClass is that case statement in miniature and shows why
         it has to move. One function holds TWO contest-specific facts -- which
         letters are legal (A-F for ARRL Field Day, I/O/H/M for Winter Field
         Day) and which error to show -- so adding a contest with a class means
         editing a shared routine, and the two Field Days, which NY4I says
         "keep diverging with rule changes each year", diverge inside a single
         `if contest = ...`.

         THE BASE ACCEPTS EVERYTHING, because most contests have no class at
         all and "no rule" is the honest answer for them rather than a special
         case. A contest with a class overrides. Since M5b LOGSTUFF.ValidClass
         asks every contest -- ContestIdentity for a classless one -- and its
         own letter loop, which named both Field Days (inventory D1), is
         deleted.

         TR4QT names the equivalent validateReceivedExchange and gives it the
         same shape -- a boolean with the message out by reference, so the
         caller can put the text where it belongs without the rule knowing
         about a UI. *)
      function ValidateClass(const aClass: string;
                             out aErrorMessage: string): boolean; virtual;

      (* WHAT A DX STATION MAY SEND AS ITS QTH.

         The second contest decision inside
         ProcessClassAndDomesticOrDXQTHExchange, and it reads
         `if ((contest = WINTERFIELDDAY) and (TempString = 'MX'))` -- Winter
         Field Day accepts MX where ARRL Field Day does not.

         aResolved is what to STORE, which is not always what was typed: an
         EMPTY exchange resolves to 'DX', because a DX station sending only a
         class is taken to mean DX. Returning a separate value rather than
         editing the input keeps that substitution visible at the call site.

         The base accepts nothing, since a contest with no DX side has no rule
         to state. Only the two Field Days run this exchange type by default;
         since M5b the engine asks EVERY contest (ContestIdentity for a
         classless one) and has no fallback of its own -- the
         `TempString = 'DX'` copy of the Field Day rule that stood in LOGSTUFF
         for a contest with no class (inventory D2) is deleted. *)
      function ValidateDXQTH(const aQTH: string;
                             out aResolved: string;
                             out aErrorMessage: string): boolean; virtual;

      (* THE CONTEST PARSES AND VALIDATES ITS RECEIVED EXCHANGE -- M5b,
         2026-10-02.

         LOGSTUFF.ProcessExchange asks this for every exchange typed or
         re-parsed -- live entry's ParametersOkay, the log-line reader, the
         sender -- after the contest-blind tokenising gate (ParseArray). True
         accepts and False refuses; a refusal that names a reason puts it in
         aErrorMessage, which the engine shows exactly as it shows an
         improper county or a bad ARRL section. An empty message leaves
         whatever the format's parser said.

         THE BASE IS THE PLAIN PARSE IN THE CONTEST'S FORMAT --
         ParseReceivedExchangeFormat, of the contest the session names in
         ExchangeFormatOf, else of this one (M11 S9d; it was
         aSession.ParseShape(aSession.Exchange, ...), the session's kind
         handed to one shared machine). It names no contest. A contest whose
         RULE differs overrides this, and calls inherited, or one of
         aSession.Parsers by name, for what it does not decide itself -- RAC
         takes a VE0 station's serial, LABRE a PY station's state, a state
         party refuses an out-of-state station working another out-of-state
         one (NY4I, design 7.10). A contest whose FORMAT differs overrides
         ParseReceivedExchangeFormat instead.

         AN OVERRIDE APPLIES ITS RULE UNDER THE FORMAT THAT CARRIED IT. Every
         rule that moved here was a branch inside one shape's parser, reached
         only when the session ran that shape; the shape is the class's own
         format now, so no rule tests it (M11 S2 deleted the tests, plan F11;
         S9d the session's kind). *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; virtual;

      (* MAY THIS WORD OF A TYPED EXCHANGE BE A CALLSIGN? -- M5b.

         LOGSTUFF.LooksLikeACallSign decides, from the word's shape, whether a
         call typed into the exchange corrects the call window's. That shape
         test names no contest. A contest whose exchange carries a word that
         looks like a call and is not one says so here: the PCC's 'N/X'.
         The base says nothing against any word. *)
      function MayBeACallsign(const aWord: string): boolean; virtual;

      (* THE INITIAL EXCHANGE A CONTEST KNOWS FROM THE WORKED CALL ALONE --
         M5b; its caller moved when Q50 was ruled (2026-10-15).

         Asked by LOGEDIT.InitialExchangeEntry when nothing else -- the
         callsigns list, then the session's initial-exchange arm -- gave an
         answer, with the call AS TYPED and its CTY.DAT country. True and
         aExchange when the contest has an answer; the base has none. The
         Russian DX contest, the RU3AX Memorial and RDA answer a Russian
         station's oblast (uCallSignRoutines.RussianStationOblast) -- the
         fallback D7's InitialExchangeEntry ran for exactly those three.

         Until Q50 ZoneCont.GetVEInitialExchange asked it, which no shipped
         contest reached. *)
      function InitialExchangeFromCall(const aCall: string;
                                       const aCountryID: string;
                                       out aExchange: string): boolean; virtual;

      (* THE ADIF SRX_STRING -- the worked station's side of the exchange, as
         received. M5b, 2026-10-02: the counterpart of FormatADIFSentExchange.

         The base is what PostUnit's tail always wrote: the received RST in
         front of the typed exchange when the session's exchange carries an
         RST (aExchangeCarriesRST, LOGDUPE's ExchangeInformation.RST), the
         typed exchange as it stands when it does not. The Field Days
         override for a DX station, whose full exchange is its class and
         'DX' (NY4I, design 7.10, Q20). *)
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; virtual;

      (* THE ADIF EXCHANGE BLOCK -- the SRX_STRING, and whatever a contest
         writes beside it, as ADIF text. Asked by PostUnit's tail emitter
         right after STX_STRING, for every QSO. 2026-10-13, when POTA gained
         its class (design Q6).

         THE BASE IS THE SRX_STRING ALONE: FormatADIFReceivedExchange's
         value, in the tag, which is what the tail wrote for every contest it
         did not name. POTA writes its activation (MY_SIG, MY_SIG_INFO and
         MY_POTA_REF, from aMy.MyPark) before it, and a hunter's state or grid
         after it -- the tail's two `ceContest = POTA` tests, moved in the
         order they wrote. A contest that only changes the SRX_STRING
         overrides FormatADIFReceivedExchange instead.

         aExchangeCarriesRST is FormatADIFReceivedExchange's. (It took the
         session's exchange too until M11 S9b; POTA's test of it was always
         true, and no other contest read it.) *)
      function EmitADIFExchangeFields(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aExchangeCarriesRST: boolean): string; virtual;

      (* THE CONTEST FORMATS ITS OWN EXPORT -- M4, 2026-10-01.

         EVERY CONTEST IS ASKED. PostUnit and uADIF ask
         uContestRegistry.ContestIdentity, which answers a classless contest
         with a plain TContestBase, so there is no switch deciding WHETHER a
         contest formats its export: it always does, and FormatsExchange --
         the opt-in that stood here from phase F -- is gone.

         THE COLUMNS ARE THE CLASSES' since M11 S9c: GetCabrilloSentExchange
         and GetCabrilloReceivedExchange, above, name a helper in
         uCabrilloExchange (what an RST-and-serial or a name-and-QTH line
         looks like) and no exchange kind -- as GetADIFSentExchange has since
         S9b. These two are the public, NON-VIRTUAL callers; the sent one
         logs the Error when a contest's column is the marker (Issue #1043),
         because only it knows the contest's name.

         A CONTEST WITH ITS OWN RULE states it in its override, and owns the
         result. One that only adjusts an input (UK/EI's '--' for an absent
         QTH) changes the context and calls the helper itself.

         THE WIDTHS ARE THE CONTRACT. Cabrillo is a column format and these
         strings are what a robot scorer reads, so an override reproduces its
         arm's widths exactly, trailing spaces included. *)
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string;

      (* THE ADIF STX_STRING -- our side of the exchange; GetADIFSentExchange
         is what a contest states. The caller has already decided the QSO is
         a good one.

         TryFormatADIFSentExchange IS THE REPORTING FORM (2026-10-14, plan
         F25/F27, NY4I: "we should report an error as the silent error is not
         good"). A getter that raises, or a contest with no layout, is caught
         HERE: an Error naming the contest, the QSO (call, band, mode, time)
         and the exception is logged, aSent is '' and the answer is False,
         with the reason in aFailure for the caller's once-per-export report.
         The caller leaves STX_STRING out of that record -- a field left out
         is honest, a made-up value is not. It is non-virtual on purpose: a
         contest cannot opt out of being reported.

         FormatADIFSentExchange is the same call for a caller that only wants
         the text ('' on a failure, already logged). *)
      function TryFormatADIFSentExchange(const aMy: TMyStationExchange;
                                         const aQso: ContestExchange;
                                         out aSent: string;
                                         out aFailure: string): boolean;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange): string;

      (* THE CONTEST'S OWN ADIF FIELDS FOR THE WORKED STATION -- M4.

         Asked by PostUnit's tail emitter, for a QSO whose QTHString is not
         empty and is not a grid (a grid has already gone to GRIDSQUARE). What
         it returns is ADIF text, written after CNTY and before the zone: the
         Field Days' ARRL_SECT/CLASS/STATE, Sweepstakes' ARRL_SECT, IARU's
         APP_TR4W_HQ, the RSGB IOTA's IOTA, WAG's DOK, the digital contests'
         GRIDSQUARE.

         TAG SPELLINGS ARE ADIF'S, THE MEANING IS THE CONTEST'S: an override
         calls uADIF.EmitADIFField for the tag and decides what goes in it.

         The base writes nothing -- uADIF.EmitADIFRecord has already written
         the generic QTH, which is all most contests have ever exported. *)
      function EmitADIFContestFields(const aQso: ContestExchange): string; virtual;

      (* THE ADIF FIELDS OF THE WORKED STATION'S EXCHANGE -- 2026-10-17, NY4I:
         "We should not just be exporting all possible fields" and "Shouldn't
         the uADIF exporter be calling the contest class to ask for the
         specific fields it wants to include?"

         Two virtuals, because the two blocks sit apart in the record and the
         record's order is part of the golden corpus's bytes: uADIF.EmitADIFRecord
         asks EmitADIFReportFields where the signal report goes (after the
         timestamps) and EmitADIFReceivedFields where the exchange goes (after
         STATE). Each returns ADIF text and is asked of the contest the QSO was
         logged in (the object carrying the station when the caller has one,
         else the identity object) -- never the live contest.

         THE RST PAIR IS EVERY QSO'S (NY4I, 2026-10-17: "Every QSO"):
         EmitADIFReportFields writes RST_SENT and RST_RCVD for every contest,
         as D7 did, whether or not the class's exchange carries a report.

         EmitADIFReceivedFields WRITES EXACTLY WHAT THE CLASS DECLARES in its
         own ReceivedExchangeFields (ExchangeInformationRecord), field by field:
           QTH            QTH
           Precedence     PRECEDENCE
           Check          CHECK
           Name           NAME
           Power          ADIFPowerTag (RX_PWR; FOC_NUM for the FOC Marathon)
           QSONumber      SRX
           TenTenNum      TEN_TEN
           Age            AGE
         a field the class does not declare is not written, however the
         record happens to be filled (a stray value in the log is not an
         exchange field). An empty or unset value (an empty text, a zero, the
         $FFFF and -1 sentinels) is not written either. Chapter, ClassEI, Kids,
         RandomChars, Zone and ZoneOrSociety have no tag here: the zone is
         PostUnit's CQZ/ITUZ and the class is EmitADIFContestFields', as ever.

         STX -- OUR OWN SENT SERIAL -- IS WRITTEN WHENEVER THE QSO HAS ONE, and
         is in EmitADIFReceivedFields only because its place in the record is
         between SRX and TEN_TEN. It is not a received field and the class's
         received list says nothing about it: the log numbers every QSO, and
         D7 wrote STX for every contest, serial exchange or not (the golden
         corpus's ARRL DX, CQ WW, IARU and Field Day references all carry it
         with an exchange that sends no serial). A contest that wants it
         gated overrides this method.

         A class with a rule of its own overrides either one and says so in the
         override; one that only changes the tag a field goes to (the FOC
         Marathon) states ADIFPowerTag. *)
      function EmitADIFReportFields(const aQso: ContestExchange): string; virtual;
      function EmitADIFReceivedFields(const aQso: ContestExchange): string; virtual;

      (* THE CONTEST INTERPRETS AN IMPORTED ADIF RECORD -- M5a, 2026-10-01.

         The other half of EmitADIFContestFields: export turns the QSO into
         tags, this turns the tags back into the QSO. Asked by
         uADIF.InterpretADIFRecord after the WHOLE record is read, the standard
         tags are already in aExch, the operator and the received RST have
         already been taken care of for every contest, and aTemps holds the raw
         text of every tag whose meaning is the contest's.

         WHAT AN OVERRIDE WRITES is the received exchange: ExchString,
         QTHString, DomesticQTH, the class, the zone, the age -- whatever its
         contest keeps. aExch.ceContest is this contest, because that is how
         it was chosen.

         THE BASE IS THE CLASSLESS FALLBACK, which is the arm
         MainUnit.ApplyContestSpecificADIFTail ended in until M5a: a grid
         exchange takes the grid, a contest with domestic multipliers takes
         the QTH tag (else the letters leading SRX_STRING), anything else
         keeps SRX_STRING as the exchange. It keys on the SESSION's exchange
         and multiplier kind (aSession), for the reason TCabrilloQSOContext
         records: the session's answer is the engine's, and varies per
         station. An override states its contest's own rule and does not call
         inherited unless it wants this fallback for the cases it does not
         handle. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); virtual;

      (* THE CONTEST DESCRIBES THE SESSION IT WANTS -- M7a, 2026-10-02
         (docs/CONTEST_OWNERSHIP_DESIGN.md section 4.2).

         ASKED BY FCONTEST.FoundContest, once per set-up, after the head has
         applied the contest's traits and the operator's statements
         (ApplyContestTraits) and decided whether the station is in a QSO
         party's host state. The contest fills aSession with what it wants
         its session to start from -- the CW messages and memories, the
         settings, the domestic countries, and the engine choices it makes
         PER STATION -- and FCONTEST's ApplySessionDefaults writes them. The
         contest writes no global, and reads only aStation: the identity
         object this is asked of (uContestRegistry.ContestIdentity) carries
         no station of its own.

         A CHOICE THAT DEPENDS ON THE STATION IS STATED BOTH WAYS HERE. The
         traits say what a contest IS, the same for everyone; whether an
         Arizona station is in Arizona changes its exchange, and a single
         trait value could not say so (inventory D8). The class states the
         in-state and the out-of-state branch explicitly, on
         aStation.InHostState.

         THE BASE STATES NOTHING, which is exactly what FoundContest did for
         a contest with no arm. A CLASSLESS contest is asked too (its
         identity is a plain TContestBase) and its arm still runs after, in
         FoundContest's `case`, until it gains a class. Each override was its
         contest's FoundContest arm, moved line for line at M7a. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); virtual;

      (* SET-UP'S DEFAULT CW EXCHANGE MESSAGES -- M11 S9e part 1. FoundContest
         asks it of the ACTIVE contest (its Station is the entrant's) after
         the contest's DescribeSession has been applied. Not virtual: a
         contest states its set in WriteDefaultExchangeMessages. *)
      procedure SetUpDefaultExchangeMessages(aMessages: TExchangeMessageWriters);

      (* THE CQ EXCHANGE A CONTEST OFFERS WHEN THE OPERATOR HAS NONE -- M7a.

         LogCfg.tSetupExchangeNumbers asks it once the whole configuration is
         read, and puts the answer into CQ EXCHANGE (and what follows from
         it) only where that message is still EMPTY -- so this is a default
         in the strict sense, and anything the operator or DescribeSession
         set wins. It is asked then rather than at DescribeSession because
         the station's lines may follow the CONTEST line, and the text is
         built from them.

         THE BASE OFFERS NOTHING (''), which is what LogCfg gave every
         contest it did not name. Each override was its contest's share of
         LogCfg's `case`, moved at M7a. *)
      function CQExchangeDefault(const aStation: TStationContext): string; virtual;

      (* THE REPEAT S&P EXCHANGE A CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
         M7b, 2026-10-02. CQExchangeDefault's sibling, asked by the same
         routine at the same moment and used the same way: LogCfg puts it into
         REPEAT S&P EXCHANGE only where that message is still empty.

         THE BASE OFFERS NOTHING (''), which is what LogCfg gave every contest
         but the four EU Sprints -- the arm that added this. *)
      function RepeatSPExchangeDefault(const aStation: TStationContext): string; virtual;

      (* ------------------------------------------------------------------
         M9a (2026-10-02): THE DISPLAY AND THE REPORTS ASK THE CONTEST.

         Each answer below stood in the unit that renders it, as a test of
         the contest's name. The contest answers with DATA; the dialog, the
         window or the writer renders it, and the contest touches no form,
         canvas or global. Asked of ContestIdentity -- none needs a station
         but CabrilloHeaderLinesBeforeTag, which is handed one.

         EVERY BASE ANSWER IS WHAT THE RENDERING UNIT DID FOR A CONTEST IT DID
         NOT NAME, so a contest that states nothing renders exactly as before.
         ------------------------------------------------------------------ *)

      (* THE NEW CONTEST DIALOG'S PROMPTS FOR THIS CONTEST -- uNewContest's two
         `case SelectedContest of`, one arm per contest, moved line for line.

         THE BASE ASKS A US STATE QSO PARTY'S STATION FOR ITS COUNTY OR STATE,
         in the words that name the party's area (QSOPartyArea since M10 S6,
         so the 7QP's '7th area' too), and asks nothing of any other contest -- the
         head uNewContest ran before its `case`, keyed then on the row's P and
         now on the IsUSQSOParty trait. IN7QPNE's composite class does not
         override it, so it keeps this head. An override calls inherited when its
         contest kept that head (Colorado, Minnesota) and does not when it did
         not (British Columbia, which the dialog named out of it). *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); virtual;

      (* DOES THIS CONTEST REFUSE THIS VALUE FOR ONE OF ITS NEW CONTEST ROWS?
         -- Q104 (NY4I, 2026-10-16). '' accepts it; any other answer is the
         message the dialog shows, and OK stays disabled while it stands.
         aValue is the row's text as typed, trimmed. IN7QPNE is the first: a
         station inside one of its four parties is sent to that party.

         THE BASE ACCEPTS EVERY VALUE, and that is not a rule default: it is
         exactly what the dialog did for every contest before Q104 -- it
         checked only that a row was filled -- and it decides no score. Asked
         of ContestIdentity, like the prompts: a value, no station. *)
      function NewContestValueRefusal(aField: TNewContestField;
                                      const aValue: string): string; virtual;

      (* THE CABRILLO CONTEST: NAME, given the session's contest title and
         name. The base is CabrilloName; General QSO, a log rather than a
         contest, names the title the operator gave it, else the session's
         name (PostUnit's GENERALQSO test, 4.78.3). *)
      function CabrilloContestName(const aContestTitle: string;
                                   const aSessionName: string): string; virtual;

      (* CABRILLO HEADER LINES THIS CONTEST WRITES BEFORE A SUMMARY TAG --
         aTagName without its leading '_' (LOCATION, CLUB, ...), aTagValue the
         text the operator gave it. Each line ends in CRLF; the base writes
         none. Winter Field Day writes ARRL-SECTION and X-EXCHANGE before
         LOCATION. aStation is the station the header is for. *)
      function CabrilloHeaderLinesBeforeTag(const aTagName: string;
                                            const aTagValue: string;
                                            const aStation: TStationContext): string; virtual;

      (* THE CABRILLO MODE COLUMN for one QSO. The base is
         uCabrilloFormat.FormatCabrilloMode without the phone override -- RY or
         DG for digital, else the mode's own spelling (FM is `FM` -- Winter
         Field Day's PH override was deleted at Q54); Delaware writes FM as
         PH and every digital mode as RY. The one-QSO line HamScore uploads
         (uCabrillo) asks this too, so the file and HamScore cannot differ. *)
      function CabrilloModeString(aMode: ModeType;
                                  aExtMode: ExtendedModeType): string; virtual;

      (* THE CANONICAL EXCHANGES A SCORE-REPORTING CLIENT SENDS -- the HamScore
         RTC upload, the UDP contact broadcast and the log's exchange_sent
         column (uExchangeBuilder). TR4W's parser accepts the fields of an
         exchange in any order; a scoreboard wants one spelling of each QSO.

         RECEIVED: the base is the exchange as typed. A contest that knows
         its own fields rebuilds them in its sponsor's order (uCanonicalExchange
         holds the shared pieces); the caller collapses the whitespace.
         SENT: the base rebuilds what was sent from the CQ exchange template --
         '#' our serial, 5NN as 599 -- or, with no template, the typed exchange;
         the RTC sends its serial and grid with no RST. *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; virtual;
      function CanonicalSentExchange(const aQso: ContestExchange;
                                     const aCtx: TCanonicalExchangeContext): string; virtual;

      (* THE type= LABEL OF ONE MULTIPLIER KIND IN THE SCORE-POSTING XML
         (LOGSUBS2's dynamic results), or '' to post no element for it.
         aAllModes says the row is the all-modes one. The base labels every
         kind on every row -- state, country, zone, prefix; WRTC's score
         computer wants HQ and country on the all-modes row only. *)
      function ScorePostingMultiplierType(aKind: RemainingMultiplierType;
                                          aAllModes: boolean): string; virtual;

      (* What the totals window shows differently -- see TTotalsDisplay. *)
      property TotalsDisplay: TTotalsDisplay read GetTotalsDisplay;

      (* How the summary sheet counts -- see TSummarySheetLayout. *)
      property SummarySheet: TSummarySheetLayout read GetSummarySheet;

      (* DOES THE CABRILLO HEADER NEED A LOCATION? The writer refuses to start
         the file without one (TC_LOCATIONFIELDEMPTY) -- ARRL 10 and Winter
         Field Day. The base does not. *)
      property RequiresCabrilloLocation: boolean read GetRequiresCabrilloLocation;

      (* DOES THE HOUR-BY-HOUR REPORT CARRY A RUNNING SCORE COLUMN?
         (PostUnit.PrintHourTotals.) The base does; the Russian cups and
         championships, whose score is not points times multipliers per hour,
         do not. *)
      property ReportsRunningScore: boolean read GetReportsRunningScore;

      (* THE OPERATING AIDS THIS CONTEST ALLOWS -- see TOperatingAid. The base
         allows every one. *)
      property PermittedOperatingAids: TOperatingAids read GetPermittedOperatingAids;

      (* DOES THIS CONTEST EXCHANGE QTCs? The QTC functions menu is offered
         only then -- the two WAE runnings. The base does not. *)
      property OffersQTCs: boolean read GetOffersQTCs;

      (* DOES THIS CONTEST OFFER THE PARK TOOLS? -- Download POTA Parks and
         Repeat POTA Parks (2nd Op) on the menus. MainUnit hides both rows
         otherwise; it tested `Contest <> POTA` until POTA gained its class
         (2026-10-13). The base does not. *)
      property OffersParkTools: boolean read GetOffersParkTools;

      (* IS THIS CONTEST STILL RUN? -- M9b. An inactive contest stays in the
         factory so an old log still opens and scores (NY4I, 2026-10-01), and
         the New Contest drop-down lists it after every active one, marked
         (NY4I, 2026-10-02: "inactive contests go at the bottom of the drop
         down"). The base is active; a class says otherwise only on NY4I's
         word -- SA Sprint and Locust today. *)
      property IsActive: boolean read GetIsActive;

      (* DOES CALL ENTRY SHOW THIS CONTEST'S STATUS? -- M9b. Typing or
         answering a call shows whether it is a new multiplier, which bands it
         is needed on, the station's information and the possible calls.
         General QSO is a log, not a contest, and shows none of them; the base
         shows them all. (MainUnit, LOGEDIT, LOGSUBS2, LOGWIND render it.) *)
      property ShowsContestStatus: boolean read GetShowsContestStatus;

      (* HOW MANY DATES A LOG OF THIS CONTEST MAY SPAN BEFORE THE SUMMARY
         WARNS (TC_TOOMANYCONTESTDATES) -- M9b. 0 means it never warns. The
         base is ten; General QSO, a log kept for as long as the station
         operates, is 0. (PostUnit.CheckForNewContestDate renders it.) *)
      property MaximumContestDates: integer read GetMaximumContestDates;

      (* THE SHORTEST GAP BETWEEN QSOs THAT COUNTS AS A BREAK, IN MINUTES --
         Q60, NY4I 2026-10-15. A gap of at most this many minutes is operating
         time; a longer one is off time. The base is 30, the default DXLog.net
         uses for every contest that states no MIN_OFF_TIME; the CQ WW family
         says 60 (CQWW.txt: MIN_OFF_TIME=60). IARU HF states none, so it is 30.
         (PostUnit.CalculateTotals renders it: the summary sheet's OPERATING
         TIME and the per-band times the CT1BOH window shows.)

         It was read from the CONTEST NAME (`Pos('CQ-WW',
         Settings.Contest.Name)`), so a stated CONTEST NAME changed it; and
         MainUnit kept a second copy, 60 for CQ WW AND IARU HF, in a variable
         nothing has read since D7 (the reader was inside a comment). *)
      property MinimumOffTimeMinutes: integer read GetMinimumOffTimeMinutes;

      (* DOES BAND UP/DOWN STEP ONTO 30, 17 AND 12 M? -- M9b. No contest is
         held there, so the base skips them; General QSO steps through them.
         Settings.Bands.WarcEnabled still has the last word either way.
         (LOGSTUFF's band stepping renders it.) *)
      property BandStepIncludesWARC: boolean read GetBandStepIncludesWARC;

      (* DOES THE EXCHANGE'S POWER FIELD HOLD AN FOC MEMBER NUMBER? -- M9b.
         The FOC Marathon's exchange is RST and member number, carried in the
         power field, so the log shows it under FOC# rather than PWR. The base
         does not. (MainUnit's log columns render it.) *)
      property PowerFieldIsFOCNumber: boolean read GetPowerFieldIsFOCNumber;

      (* THE WARNING CALL ENTRY SHOWS FOR THE RADIO'S FREQUENCY, IN kHz, or ''
         for none -- M9b. A sponsor that confines its contest to part of a
         band says where; WAG's manager asked for the warning (n4af). The base
         has none. MainUnit asks it as a call is typed and shows the answer as
         a notice; the words are the contest's, read when asked so a loaded
         translation reaches the screen. *)
      function CallEntryFrequencyWarning(aFreqKHz: integer): string; virtual;

      (* Hands the contest the station it is operating as.

         PUSHED IN, NOT READ. An earlier version had the base reach into LOGWIND
         for MyCountry, which put the display layer in the dependency graph of
         every contest class -- and, worse, of anything that wanted to ASK a
         contest something. uCabrilloExchange and uADIFExchange are
         dependency-light on purpose and have unit tests that would then have
         needed the program's globals booted.

         So the direction is inverted: uContestFactory reads the globals and
         hands the result down. A contest class now depends on VC, SysUtils,
         the string constants and -- for the tCategoryPower TYPE only, never
         the Settings object -- uSettingsModel, which means a test can
         construct one and ask it to score a QSO without starting TR4W.

         SET BEFORE EVERY SCORE rather than once at construction: MyCountry is
         recomputed whenever MY CALL changes -- from the config, from the log's
         stored settings, from the operator editing it mid-contest -- and a
         contest holding the startup value would score the rest of the log
         against a station that has moved. *)
      (* HOW MANY QTHs MAY ONE ON-AIR EXCHANGE CLAIM?

         THE NAME IS QTH AND NOT COUNTY, BECAUSE THE BASE IS ASKED ABOUT EVERY
         CONTEST. It was ValidateCountyCount, which made CQ WW and the ARRL
         Digital contest answer a question about counties; the thing LOGSTUFF
         actually has in hand at the call site is a count of QTH tokens, and
         that is a question any contest can be asked.

         THE BASE ALWAYS SAYS YES, AND THAT IS BEHAVIOUR-PRESERVING BY
         CONSTRUCTION. TR4W has never counted QTHs for any contest:
         LOGSTUFF.ApplyFirstQTHAndQueueRest queues every valid one the operator
         typed and no site anywhere bounds them. So "no opinion" is not a
         permissive placeholder -- it is an exact statement of what the program
         does, and a contest acquiring a class cannot change it by accident.

         THAT WAS A REAL DEFECT AND THIS IS THE FIX. While the rule lived here,
         the inherited answer read ContestsArray's CountyLineAllowed boolean,
         which is absent from most rows -- so the moment a contest got a class
         of any kind, a two-QTH exchange started being REFUSED for it. Arktika
         Spring hit exactly that.

         VIRTUAL, so a contest that does have a limit can state one.
         TContestStateQSOPartyBase is the only overrider today and the only
         place a county-line limit exists.

         IT TAKES AN INTEGER AND NEVER A LIST, and that is the design rule
         rather than a convenience: a contest that was handed the QTHs would be
         one step from being handed the prior QSOs so it could count them
         itself, and at that point the order in which callers invoke factory
         methods starts changing what a log scores. LOGSTUFF already has the
         count -- it just tokenised the exchange -- so it passes the number and
         asks. *)
      function ValidateQTHCount(aCount: integer;
                                out aErrorMessage: string): boolean; virtual;

      procedure SetStation(const aStation: TStationContext);

      (* THE FINAL SCORE -- STAGE 3, M6 (2026-10-02; design 5 and 7.7).

         ONE FUNCTION, AND EVERY READER OF THE SCORE ASKS IT: LogEdit.TotalScore
         is its only caller, and the score display, the summary sheet, the
         Cabrillo CLAIMED-SCORE, the XML score report and both score-posting
         clients read TotalScore.

            final score = CombineScore(totals) + BonusPoints(totals, view)

         NOT VIRTUAL, for ScoreQSO's reason: a bonus is added once, after the
         sponsor's formula, and no contest can fold one into the other or apply
         it per QSO. A contest's formula is CombineWithMultipliers; its bonuses
         are BonusStations and BonusPoints. *)
      function FinalScore(const aTotals: TScoreTotals;
                          aView: TLoggedQSOView): longint;

      (* THE SPONSOR'S FORMULA, AS A TEMPLATE -- not virtual.

         A SESSION THAT COUNTS NO MULTIPLIER SCORES ITS POINTS. That was the
         first test of LogEdit.TotalScore, ahead of every contest's own rule,
         and it names no contest -- it is the session's answer -- so it is
         stated here, once, and no override can skip it. Otherwise the
         contest's CombineWithMultipliers.

         THE SECOND TEST IS FISTS's OWN SINCE M11 S7 (2026-10-14): "a session
         whose exchange is the FISTS one scores its points" (a D7 note: "Ugly
         fix for FISTS because mults don't work ... too long an exchange")
         named one contest through its exchange shape, and is
         TContestFISTS.CombineWithMultipliers now (plan F12). *)
      function CombineScore(const aTotals: TScoreTotals): longint;

      (* THE BONUSES, ADDED ONCE AFTER THE FORMULA -- never per QSO.

         THE BASE PAYS THE DECLARED BONUS STATIONS over the view (see
         TBonusStation) and nothing else; a contest with none declared adds 0
         and never reads the view. A contest with a rule of its own (North
         Carolina's sweep, Idaho's dormant county) overrides, and adds
         inherited so a declared station is still paid.

         THE VIEW IS READ-ONLY AND IS THE WHOLE LOG, so a bonus is the same
         however the log was reached -- live, reloaded, rescored, edited or
         merged -- which is why it is not decided as each QSO is logged
         (design 7.7). *)
      function BonusPoints(const aTotals: TScoreTotals;
                           aView: TLoggedQSOView): longint; virtual;

      (* ~~TalliesLiveQSO~~ stood here -- "does this live QSO add to the
         session's running tally?", Missouri's peak-hour count, kept only in
         live entry (LOGSUBS2.LogContact) and so lost on every reopen and
         /EXPORT. A defect preserved on purpose at M6 and asked as design
         Q32. NY4I ruled the bonus real and from the log (2026-10-15: "The
         wall clock logged into the log record determines this."), so it is
         Missouri's BonusPoints over the view and the seam is DELETED
         (2026-10-17). No bonus is counted as QSOs are logged any more. *)

      (* The contest's bonus stations -- see TBonusStation. *)
      property BonusStations: TBonusStationList read GetBonusStations;
   protected
      (* THE CONTEST'S OWN PER-QSO RULE -- step 4 of ScoreQSO, and only that.

         Sets aQso.QSOPoints, and the fields the rule it replaced wrote (see
         ScoreQSO); never dupe state, which is decided elsewhere.

         PROTECTED SINCE M3. It is asked only through ScoreQSO, so it is
         never asked about a QSO on a band the contest does not use, nor about
         one an operator's QSO POINTS ... override has already scored, and it
         always receives QSOPoints = 0. A contest states its bands once, in
         UsesBand, and never repeats that rule here. An override in a
         descendant is declared protected too: a public redeclaration would
         reopen the bypass.

         The base scores nothing. That is deliberate rather than a placeholder:
         the legacy NoQSOPointMethod (the point method, deleted as a concept
         at M10 S4) meant exactly this, so a contest that does not score is
         not a special case. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); virtual;

      (* THE SPONSOR'S FORMULA WHEN THE SESSION COUNTS MULTIPLIERS -- step 2
         of CombineScore, and only that (M6).

         THE BASE IS LogEdit.TotalScore'S GENERAL CASE, unchanged: the points
         times the sum of every multiplier kind -- on the one band a
         single-band entry scores, else on all bands. A contest whose sponsor
         combines them otherwise overrides: Winter Field Day, WAE's weighted
         multipliers, the Russian cups' points-plus-N-per-multiplier, the Ural
         Cup. Protected, as CalculateQSOPoints is. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; virtual;

      (* MECHANISM FOR THE FORMULAS, not rules: the QSO points plus the QTC
         points, and the general case's multiplier sum. *)
      function ContestPoints(const aTotals: TScoreTotals): longint;
      function SummedMultipliers(const aTotals: TScoreTotals): longint;

      (* WHICH LOGGED CONTACTS A BONUS STATION'S CONTACT MAY BE.

         The base takes every QSO in the view, dupes included -- exactly the
         QSOs the log's loader handed Missouri's bonus check. A contest whose
         sponsor wants valid contacts only says so (the Salmon Run). *)
      function CountsTowardBonus(const aQso: ContestExchange): boolean; virtual;

      (* WHICH MODES A OncePerMode BONUS IS PAID IN -- aMode is CW, Digital or
         Phone (FM is phone). The base pays every mode. *)
      function CreditsBonusMode(aMode: ModeType): boolean; virtual;

      (* MECHANISM: was aCall worked in the view, in aMode (CW, Digital or
         Phone) or in any mode when aAnyMode, by a contact CountsTowardBonus
         accepts? An exact comparison with the logged callsign. *)
      function BonusStationWorked(aView: TLoggedQSOView;
                                  const aCall: string;
                                  aAnyMode: boolean;
                                  aMode: ModeType): boolean;

      (* THE PARSE, WHICH IS MECHANISM AND NOT A RULE.

         A Field-Day-shaped class is a transmitter COUNT followed by one
         CATEGORY letter -- "2A", "1O", "10F". Splitting digits from letters and
         checking there is exactly one of the latter is the same work whoever
         asks; WHICH letters are legal, and what to say when they are not, is
         the contest's.

         So the loop lives here once and the rule arrives as two parameters.
         Duplicating this into every contest with a class would be duplicating
         the part that CANNOT differ, which is the opposite of the split that
         makes the two Field Days independent. *)
      function ValidateCountAndLetterClass(const aClass: string;
                                           const aValidLetters: string;
                                           const aBadClassMessage: string;
                                           out aErrorMessage: string): boolean;

      (* Mechanism for ValidateDXQTH: 'DX' and empty always pass, plus whatever
         else the contest allows. *)
      function ValidateDXQTHAllowing(const aQTH: string;
                                     const aAlsoAllowed: string;
                                     out aResolved: string;
                                     out aErrorMessage: string): boolean;

      (* THE GRID SQUARE IS REQUIRED -- Q115 (NY4I, 2026-10-18: "The contest
         class should be stating what is required. Some contests could allow
         just rst but most require more data.").

         MECHANISM, called by a class's own ParseReceivedExchange after
         `inherited`, with what the format's parse answered. A parse that
         accepted with no grid is refused with SExchangeGridRequired; a
         refusal already made passes through untouched, its message with it.

         "No grid" is an empty DomesticQTH: the RST-and/or-grid parse clears
         it first and writes the grid there, so a grid in it is this parse's
         and never a stale one -- which QTHString, cleared only by live entry,
         cannot promise. A contest whose format keeps its grid elsewhere does
         not call this. The base states no requirement. *)
      function RequireReceivedGrid(aAccepted: boolean;
                                   const aExch: ContestExchange;
                                   var aErrorMessage: string): boolean;
   end;

   TContestClass = class of TContestBase;

(* A TContestIdList from literals -- what an override of
   GetFormerADIFContestIds returns: `Result := ContestIdList(['MST']);`.

   ONE COPY OF THE CONSTRUCTION, so no override writes SetLength on its own
   unassigned result -- which FPC rightly warns about, once per class. *)
function ContestIdList(const aIds: array of string): TContestIdList;

(* DOES A QSO ON aBand EARN CREDIT -- points or multipliers -- IN aContest?

   aContest is the active contest's object, or nil for a contest that has no
   class yet; nil answers True, which is today's behaviour for every classless
   contest. This is the ONE place that rule is written, and the two seams that
   decide credit (see TContestBase.UsesBand) both call it, so the points and
   the multipliers cannot disagree about which QSOs count. *)
function ContestCreditsBand(aContest: TContestBase; aBand: BandType): boolean;

(* THE BANDS OF A NEED-MULTIPLIER MASK THE CONTEST CREDITS -- M8, design 7.4:
   "off-band should not impact need multiplier".

   aBandMask is the hint's shape (LOGEDIT's GetMultArray): bit Ord(b) set
   means a multiplier is still needed on band b. Every real band the contest
   does not use (ContestCreditsBand) is cleared. The AllBands bit is KEPT --
   it is the any-band key of a contest whose multipliers are not counted per
   band, not a band, so whether to show it is the caller's band question
   (the band the operator is on). nil credits every band, so the mask comes
   back unchanged for a classless contest and for every contest that states
   no bands. *)
function CreditedBands(aContest: TContestBase; aBandMask: Cardinal): Cardinal;

(* DOES aQso EARN A MULTIPLIER OF aKind IN aContest AT ALL? -- see
   TContestBase.CountsAsMultiplier. nil answers True: a classless contest's
   multipliers are the sheet's alone, as they always were. The one way the
   sheet asks, as ContestCreditsBand is for the band. *)
function ContestCountsMultiplier(aContest: TContestBase; const aQso: ContestExchange;
                                 aKind: RemainingMultiplierType): boolean;

(* MAY aContest'S ENTRANT CREDIT aQso'S WORKED STATION? -- see
   TContestBase.CreditsWorkedStation (Q107). nil answers True: a classless
   contest has no host area. The one way the sheet asks, as
   ContestCreditsBand is for the band. *)
function ContestCreditsWorkedStation(aContest: TContestBase;
                                     const aQso: ContestExchange): boolean;

(* THE HOST-AREA RULE -- THE ONE PREDICATE, Q107 (NY4I, 2026-10-16) and
   design 7.10 (2026-10-02): "In QSO parties, out of state stations usually
   only log the state county" -- "true for qso parties in general" (Q29).

   An entrant inside the host area works everyone (True). An entrant outside
   it credits a QSO only when the worked station's received QTH, aWorkedQTH
   (the record's QTHString, as typed or imported), is known to the session's
   domestic table -- which, outside the host area, is the host's county file
   and nothing else. A nil table knows nothing.

   CALLED FROM BOTH SIDES with the same arguments' sources: a contest's
   ParseReceivedExchange refusal hands it aSession.IsDomesticQTH, its
   CreditsWorkedStation hands it Station.IsDomesticQTH -- the same engine
   function (LOGDUPE.DomesticTableKnowsQTH) -- so a QSO refused when typed is
   exactly a QSO that scores 0 when logged another way. *)
function HostAreaRuleCredits(aEntrantInHostArea: boolean;
                             const aWorkedQTH: string;
                             aIsHostQTH: TDomesticQTHTest): boolean;

(* IS THIS DOMESTIC MULTIPLIER A PARTY'S "DX"? -- THE ONE TEST, Q84 (NY4I,
   2026-10-15: "ignore case") and Q49 (2026-10-16).

   A QSO party whose rule is "a DX station is not a multiplier" -- Indiana,
   New York, British Columbia -- asks this of the QSO's domestic multiplier
   (DomMultQTH, the value the session's .dom mapped the QTH to). The files
   spell it as they please: Indiana's says `DX = DX`, IN7QPNE's `dx = dx`,
   British Columbia's `dx=DX`. The RULE ignores case, not the files, so all
   three match 'DX', 'dx' and 'Dx' alike. Until Q84 each tested its own
   spelling with `<>`: BC tested 'dx' against a file that maps to 'DX', so its
   rule never fired (Q49), and Indiana's 'DX' missed IN7QPNE's 'dx'. *)
function DomesticMultiplierIsDX(const aMultiplier: string): boolean;

(* THE PREFIX MULTIPLIER KEY aQso EARNS IN aContest -- see
   TContestBase.PrefixMultiplierKey. nil answers False, leaving the prefix as
   it was: the classless DUMMYCONTEST runs NoPrefixMults. *)
function ContestPrefixMultiplierKey(aContest: TContestBase; const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean;

(* DOES aContest HAVE A PREFIX MULTIPLIER AT ITS STATION? -- see
   TContestBase.HasPrefixMultiplier. nil answers False: the classless
   DUMMYCONTEST ran NoPrefixMults. LOGEDIT.DoingPrefixMults asks it of the
   active contest. *)
function ContestHasPrefixMultiplier(aContest: TContestBase): boolean;

(* THE DX MULTIPLIER KEY aQso EARNS IN aContest -- see
   TContestBase.DXMultiplierKey. nil answers False, leaving the DX QTH as it
   was: the classless DUMMYCONTEST runs NoDXMults. *)
function ContestDXMultiplierKey(aContest: TContestBase; const aQso: ContestExchange;
                                out aKey: DXMultiplierString): boolean;

(* DOES aContest HAVE A DX MULTIPLIER AT ITS STATION? -- see
   TContestBase.HasDXMultiplier. nil answers False: the classless
   DUMMYCONTEST ran NoDXMults. LOGEDIT.DoingDXMults asks it of the active
   contest; a caller already holding the object asks it here. *)
function ContestHasDXMultiplier(aContest: TContestBase): boolean;

(* THE CTY COUNTRY LIST aContest COUNTS -- see TContestBase.CountryMode. nil
   answers CQCountryMode, as NoDXMults did. *)
function ContestCountryMode(aContest: TContestBase): CountryModeType;

(* DOES THE REMAINING-MULTS WINDOW LIST THIS COUNTRY FOR aContest? -- see
   TContestBase.ListsRemainingDXCountry. nil answers True: no filter. *)
function ContestListsRemainingDXCountry(aContest: TContestBase;
                                        const aCountryID: DXMultiplierString;
                                        aContinent: ContinentType): boolean;

(* DOES aContest HAVE A ZONE MULTIPLIER AT ITS STATION? -- see
   TContestBase.HasZoneMultiplier. nil answers False: the classless
   DUMMYCONTEST ran NoZoneMults. LOGEDIT.DoingZoneMults asks it of the
   active contest; a caller already holding the object asks it here. *)
function ContestHasZoneMultiplier(aContest: TContestBase): boolean;

(* HOW MANY ZONES aContest's ZONE MULTIPLIER HAS -- see
   TContestBase.ZoneMultiplierCount. nil answers 0: the classless
   DUMMYCONTEST ran NoZoneMults. *)
function ContestZoneMultiplierCount(aContest: TContestBase): integer;

(* WHICH ZONE LIST aContest's ZONE MULTIPLIER COUNTS -- see
   TContestBase.ZoneMultiplierZones. nil answers zmzNotCQOrITU. *)
function ContestZoneMultiplierZones(aContest: TContestBase): TZoneMultiplierZones;

(* DOES aContest NUMBER ITS ZONES FROM ZERO? -- see
   TContestBase.NumbersZonesFromZero. nil answers False. *)
function ContestNumbersZonesFromZero(aContest: TContestBase): boolean;

(* WHAT A RECEIVED DOMESTIC QTH MEANS IN aContest -- see
   TContestBase.DomesticMultiplierFromQTH. nil answers dqaLookUpDomesticFile
   and writes nothing: the classless DUMMYCONTEST runs NoDomesticMults, which
   GetDomQTH answers before it asks. *)
function ContestDomesticMultiplierFromQTH(aContest: TContestBase;
                                          const aText: Str20;
                                          var aMultiplier: Str10;
                                          var aQTH: Str10;
                                          var aFound: boolean): TDomesticQTHAnswer;

(* WHAT THE NEED-MULTIPLIER HINT SHOWS FOR aText IN aContest -- see
   TContestBase.DomesticMultiplierHint. nil answers the text itself. *)
function ContestDomesticMultiplierHint(aContest: TContestBase; const aText: Str14): string;

(* THE FOUR YES/NO DOMESTIC ANSWERS OF aContest -- see TContestBase.
   HasGridSquareMultiplier, HasGridFieldMultiplier,
   DomesticQTHReplacesDXMultiplier and DomesticQTHIsNeverAGrid. nil answers
   False to each. *)
function ContestHasGridSquareMultiplier(aContest: TContestBase): boolean;
function ContestHasGridFieldMultiplier(aContest: TContestBase): boolean;
function ContestDomesticQTHReplacesDXMultiplier(aContest: TContestBase): boolean;
function ContestDomesticQTHIsNeverAGrid(aContest: TContestBase): boolean;

(* IS aContest's DOMESTIC QTH LOOKED UP IN ITS DOMESTIC FILE? -- see
   TContestBase.UsesDomesticFile. nil answers False: the classless
   DUMMYCONTEST ran NoDomesticMults. *)
function ContestUsesDomesticFile(aContest: TContestBase): boolean;

(* DOES aContest HAVE A DOMESTIC MULTIPLIER AT ITS STATION? -- see
   TContestBase.HasDomesticMultiplier. nil answers False: the classless
   DUMMYCONTEST ran NoDomesticMults. LOGEDIT.DoingDomesticMults asks it of
   the active contest; a caller already holding the object asks it here. *)
function ContestHasDomesticMultiplier(aContest: TContestBase): boolean;

(* THREE OF THE EXCHANGE RULES OF aContest -- see TContestBase.
   StripsRoverCountyFromCall, LogsSeveralQTHsFromOneEntry and
   AcceptsBlankExchange (M11 S7). nil answers False to each: the classless
   DUMMYCONTEST ran UnknownExchange, which none of the old compares named.
   MainUnit and LOGSTUFF ask them of the open contest. *)
function ContestStripsRoverCountyFromCall(aContest: TContestBase): boolean;
function ContestLogsSeveralQTHsFromOneEntry(aContest: TContestBase): boolean;
function ContestAcceptsBlankExchange(aContest: TContestBase): boolean;

(* aContest's TContestBase.DupeKeyQualifier for aQso, and its
   DupeKeyIncludesReceivedQTH; nil (the classless DUMMYCONTEST) answers ''
   and False -- the call alone. *)
function ContestDupeKeyQualifier(aContest: TContestBase; const aQso: ContestExchange): string;
function ContestDupeKeyIncludesReceivedQTH(aContest: TContestBase): boolean;

(* WHAT aContest's EXCHANGE CARRIES, AND HOW ITS PER-QSO STRING LEADS -- see
   TContestBase.ExchangeCarriesDomesticQTH and its neighbours (M11 S9d). nil
   answers False to each: the classless DUMMYCONTEST ran UnknownExchange,
   which none of the old sets held. *)
function ContestExchangeCarriesDomesticQTH(aContest: TContestBase): boolean;
function ContestExchangeCarriesZone(aContest: TContestBase): boolean;
function ContestExchangeCarriesGridSquare(aContest: TContestBase): boolean;
function ContestPerQSOExchangeLeadsWithSerial(aContest: TContestBase): boolean;

(* THE FIELDS aContest's RECEIVED EXCHANGE CARRIES -- see
   TContestBase.ReceivedExchangeFields (M11 S9a). nil marks nothing: the
   classless DUMMYCONTEST ran UnknownExchange, which had no arm. Start-up
   (uProgramMain) asks it of the open contest. *)
function ContestReceivedExchangeFields(aContest: TContestBase): ExchangeInformationRecord;

(* DOES aContest'S RECEIVED EXCHANGE CARRY A GRID SQUARE? -- see
   TContestBase.ReceivesGridSquareExchange (M11 S9b). nil answers False: the
   classless DUMMYCONTEST ran UnknownExchange. The ADIF import asks it of the
   open contest. *)
function ContestReceivesGridSquareExchange(aContest: TContestBase): boolean;

(* MAY A WORD OF aContest's EXCHANGE BE A GRID SQUARE? -- see
   TContestBase.ExchangeTextMayHoldGridSquare (M11 S9e part 1). nil answers
   False: the classless DUMMYCONTEST ran UnknownExchange, outside the old
   set. *)
function ContestExchangeTextMayHoldGridSquare(aContest: TContestBase): boolean;

(* SET-UP'S DEFAULT CW EXCHANGE MESSAGES FOR aContest -- see
   TContestBase.SetUpDefaultExchangeMessages (M11 S9e part 1). nil writes
   nothing: the classless DUMMYCONTEST ran UnknownExchange, which the old
   `case` had no arm for. *)
procedure ContestSetUpDefaultExchangeMessages(aContest: TContestBase;
                                              aMessages: TExchangeMessageWriters);

(* THE ZONE A CALL-HISTORY (TRMASTER) ENTRY OFFERS AS THE INITIAL EXCHANGE --
   M11 S5. LOGEDIT.InitialExchangeEntry's ZoneInitialExchange arm asks it
   once CD.GetEntry has found the call, with the zone list the contest's
   multiplier counts and the entry's two zone fields.

   THE OLD RULE, EXACTLY (it read `ContestSession.ZoneMult = ITUZones`): a
   contest counting ITU zones offers the entry's ITU zone, and when the entry
   has none offers NOTHING from it -- no fall back to the CQ field; the arm
   goes on to CTY.DAT's zone, in the CTY zone mode. Every other contest
   offers the entry's CQ zone when it has one. True with aZone set when the
   entry decides; False, aZone empty, when CTY.DAT does. Pinned in
   uTestZoneMultiplier. *)
function InitialZoneFromCallHistory(aZones: TZoneMultiplierZones;
                                    const aCQZone: ShortString;
                                    const aITUZone: ShortString;
                                    out aZone: ShortString): boolean;

(* THE FOUR `QSO POINTS ...` OVERRIDES, APPLIED -- the one statement of their
   rule. True, with aQso.QSOPoints set, when one of them matches this QSO;
   False, with aQso untouched, when none does.

   TWO CALLERS, ONE RULE: TContestBase.ScoreQSO for a contest with a class, and
   LOGSTUFF.CalculateQSOPoints for the classless DUMMYCONTEST, which since M10
   S3 scores the overrides and then 0 (the legacy case is deleted). Before M3 the rule was written once, in LOGSTUFF; moving it into
   ScoreQSO as a copy would have been two definitions free to drift.

   First match wins, in the engine's order: domestic CW, DX CW, domestic phone,
   DX phone. "Domestic" is a non-empty DomesticQTH. *)
function ApplyQSOPointOverride(const aOverrides: TQSOPointOverrides;
                               var aQso: ContestExchange): boolean;

(* DOES A LOGGED RECORD COUNT TOWARD THE TOTALS? -- M6, the one statement of
   it. A QSO record, not deleted, with a band and a mode, and not an X-QSO:
   what MainUnit.LoadinLog adds to the sheet and the counters, and so what the
   view a bonus rule reads holds. LoadinLog asks this too, so the totals and
   the view cannot disagree about which QSOs exist. So does the summary
   sheet (POSTUNIT.CalculateTotals, Q51: "x-qso never counts as worked"). *)
function QSOCountsTowardTotals(const aQso: ContestExchange): boolean;

(* aQso EARNS NO MULTIPLIER: its four flags -- domestic, DX, prefix, zone --
   cleared. The one statement of "no multiplier on this record", for the
   three engine sites that said it in four assignments: LOGDUPE.SetMultFlags
   (before it decides the flags), the rescore's actClearMults and its X-QSO
   arm (MainUnit.tUpdateLog, through ClearXQSOScoring). *)
procedure ClearMultiplierFlags(var aQso: ContestExchange);

(* WHAT A RESCORED X-QSO KEEPS OF ITS SCORING: nothing (Q51, NY4I: "x-qso
   never counts as worked ... simply so we do not leave it out of the log").
   Its points 0, no dupe mark and no multiplier flag.

   THE FLAGS ARE THE FINDING (CONTEST_OWNERSHIP_DESIGN.md 8.2v): the rescore
   zeroed the points and the dupe and left the stored flags as they were, so
   every reader of a record's DXMult/ZoneMult -- HamScore's CountMultipliers,
   the UDP and score-posting multiplier fields -- could report a multiplier
   for a flagged X-QSO. The record keeps everything else, the QTH it was
   worked with included. *)
procedure ClearXQSOScoring(var aQso: ContestExchange);

(* THE MODE A BONUS IS COUNTED IN: FM is phone, as the engine's totals count
   it; every other mode is itself. *)
function BonusModeOf(aMode: ModeType): ModeType;

(* THE CONTEST YEAR OF A LOG -- Q35 (NY4I, 2026-10-16: "you have to handle
   reviewing an old contest as you need to know which list of counties to
   use"). The ONE statement of it, for any rule that changes from year to
   year; Idaho's dormant-county table is the first reader.

      1. aTotals.LogStartTime's year, when the log records a start;
      2. else the year of the EARLIEST dated QSO in aView;
      3. else 0 -- the log says nothing about its year (no start, and no QSO
         with a date). A caller treats 0 as "unknown" and reports it.

   NEVER THE CLOCK: "a logged QSO reads its record", so the answer is the
   same live, after a reload, a rescore or an /EXPORT, and in 2029.

   THE EARLIEST, NOT THE FIRST IN LOG ORDER: an import or a merge can put an
   older QSO after a newer one, and the contest started with the older. For
   an ordinary log the two are the same QSO. A QSO with no date (tree.pas
   writes a zero month and day for "no time") is skipped. *)
function LogContestYear(const aTotals: TScoreTotals; aView: TLoggedQSOView): integer;

implementation

uses
   SysUtils,
   (* ContestId -- the contest's stored name, which the name fallbacks
      answer (Q108 S2). *)
   uContestRegistry,
   (* TC_IMPROPERTRANSMITTERCOUNT -- the one message that is NOT contest
      specific: every class-carrying contest counts transmitters the same way. *)
   uTR4WStrings,
   (* SExchangeGridRequired -- RequireReceivedGrid's refusal (Q115). *)
   uAppStrings,
   (* THE SHARED EXCHANGE ARMS the base's export defaults call -- M4. Both
      units name this one in their interface for the record types, so the
      reference back is from the implementation, which Pascal allows. They
      name no contest, and depend on VC, SysUtils and Log4D only. *)
   uCabrilloExchange,
   uADIFExchange,
   (* The Error a contest with no Cabrillo layout logs (Issue #1043). *)
   Log4D,
   (* FormatCabrilloMode -- the base's Cabrillo mode column (M9a). A leaf: VC
      and SysUtils only. *)
   uCabrilloFormat,
   (* CanonicalFromCQTemplate -- the base's canonical sent exchange (M9a). A
      leaf: VC, SysUtils and StrUtils only. *)
   uCanonicalExchange,
   (* ExchangeFieldsNone -- the base's received-exchange field list (M11
      S9a). A leaf: VC and SysUtils only. *)
   uExchangeFields,
   (* ResolveSRXString -- the received-exchange half of the ADIF SRX_STRING
      the base's FormatADIFReceivedExchange writes (M5b). The Field Day
      classes already reach uADIF the same way, from their implementation. *)
   uADIF;

var
   logger: TLogLogger;

function ContestIdList(const aIds: array of string): TContestIdList;
var
   i: integer;
begin
   Result := nil;
   SetLength(Result, Length(aIds));
   for i := 0 to High(aIds) do
      begin
      Result[i] := aIds[i];
      end;
end;

constructor TContestBase.Create(aContest: TContestHandle);
begin
   inherited Create;
   FContest := aContest;
   FId := ContestId(aContest);
end;

procedure TContestBase.SetStation(const aStation: TStationContext);
begin
   FStation := aStation;
end;

function TContestBase.IsContestOfQso(const aQso: ContestExchange): boolean;
begin
   Result := FContest = aQso.ceContest;
end;

function TContestBase.GetDisplayName: string;
begin
   Result := FId;
end;

(* THE NEUTRAL DEFAULTS -- M10 S6, 2026-10-14.

   No getter below reads ContestsArray, ContestsBooleanArray or QSOParties.
   Each answers a constant, and the constants ARE DUMMYCONTEST's row: blank
   names (so the enum's spelling, which is what the old two-step gave for a
   blank field), no calendar ids, no e-mail, no domestic file,
   NoInitialExchange, NoDomesticMults, P 0, UnknownExchange, a flag word
   of 0 (the row's NoDXMults and NoZoneMults went with their kinds at
   M11 S4 and S5). DUMMYCONTEST -- the one contest with no class
   -- therefore answers exactly what it did, and every registered contest
   states its own values (M10 S5); Test_MovedRowValuesStillMatchTheArray
   holds each class to its row until plan S8 deletes the tables. *)

function TContestBase.GetCabrilloName: string;
begin
   (* The enum's spelling -- what PostUnit wrote for a blank CABName, and
      DUMMYCONTEST's is blank. See the note on the declaration. *)
   Result := FId;
end;

function TContestBase.GetADIFContestId: string;
begin
   (* The same default as CabrilloName -- see the note on the declaration. *)
   Result := FId;
end;

function TContestBase.GetFormerADIFContestIds: TContestIdList;
begin
   (* No former ids. ContestsArray has no column for them and must not grow
      one -- the array is being retired, not extended. nil IS the empty
      dynamic array; SetLength on an unassigned result draws a warning. *)
   Result := nil;
end;

function TContestBase.GetWA7BNMId: integer;
begin
   (* No calendar entry: 0 disables the calendar menu item. *)
   Result := 0;
end;

function TContestBase.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestBase.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestBase.GetFriendlyName: string;
begin
   (* Same default as CabrilloName: the array's own note said "If blank, use
      ContestTypeSA[ct]". *)
   Result := FId;
end;

function TContestBase.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestBase.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestBase.GetExchangeKind: ExchangeType;
begin
   Result := UnknownExchange;
end;

function TContestBase.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   (* Nothing -- see the declaration. *)
   Result := ExchangeFieldsNone;
end;

function TContestBase.GetIsUSQSOParty: boolean;
begin
   (* The row's P was 0: not a QSO party. *)
   Result := False;
end;

function TContestBase.GetHostState: string;
begin
   (* No host: every party states its own (M10 S5). *)
   Result := '';
end;

function TContestBase.GetCabrilloQSOLineFormat: string;
begin
   Result := CabrilloQSOLineFormatDefault;
end;

function TContestBase.GetFlags: TContestFlags;
begin
   (* The empty set -- DUMMYCONTEST's word is 0. Every registered contest
      states its own set (M10 S5). *)
   Result := [];
end;

function TContestBase.GetQSOByBand: boolean;
begin
   Result := cfQSOByBand in Flags;
end;

function TContestBase.GetQSOByMode: boolean;
begin
   Result := cfQSOByMode in Flags;
end;

function TContestBase.GetMultByBand: boolean;
begin
   Result := cfMultByBand in Flags;
end;

function TContestBase.GetMultByMode: boolean;
begin
   Result := cfMultByMode in Flags;
end;

function TContestBase.GetVHFBandsEnabled: boolean;
begin
   Result := cfVHFBandsEnabled in Flags;
end;

function TContestBase.GetCountsDomesticCountries: boolean;
begin
   Result := cfCountsDomesticCountries in Flags;
end;

function TContestBase.GetZoneMode: ZoneModeType;
begin
   (* See the declaration: the member present means CQ zones, absent ITU. *)
   if cfCQZoneMode in Flags then
      begin
      Result := CQZoneMode;
      end
   else
      begin
      Result := ITUZoneMode;
      end;
end;

function TContestBase.GetErmakSpecification: boolean;
begin
   Result := cfErmakSpecification in Flags;
end;

function TContestBase.GetRTCCapable: boolean;
begin
   Result := cfRTCCapable in Flags;
end;

function TContestBase.GetInStateDomesticFileName: string;
begin
   (* Not a QSO party: no in-state file. Every party states its own. *)
   Result := '';
end;

function TContestBase.ValidateQTHCount(aCount: integer;
                                      out aErrorMessage: string): boolean;
begin
   (* NO OPINION, AND THAT IS THE WHOLE IMPLEMENTATION. See the declaration:
      accepting every count is an exact statement of what TR4W does for every
      contest, so a contest joining the factory cannot tighten this by
      inheriting something. A limit has to be stated to exist. *)
   aErrorMessage := '';
   Result := True;
end;

function ContestCreditsBand(aContest: TContestBase; aBand: BandType): boolean;
begin
   if aContest = nil then
      begin
      Result := True;
      end
   else
      begin
      Result := aContest.UsesBand(aBand);
      end;
end;

function CreditedBands(aContest: TContestBase; aBandMask: Cardinal): Cardinal;
var
   b: BandType;
begin
   Result := aBandMask;
   for b := Low(BandType) to BandLight do
      begin
      if not ContestCreditsBand(aContest, b) then
         begin
         Result := Result and not (Cardinal(1) shl Ord(b));
         end;
      end;
end;

function ContestCountsMultiplier(aContest: TContestBase; const aQso: ContestExchange;
                                 aKind: RemainingMultiplierType): boolean;
begin
   if aContest = nil then
      begin
      Result := True;
      end
   else
      begin
      Result := aContest.CountsAsMultiplier(aQso, aKind);
      end;
end;

function ContestCreditsWorkedStation(aContest: TContestBase;
                                     const aQso: ContestExchange): boolean;
begin
   if aContest = nil then
      begin
      Result := True;
      end
   else
      begin
      Result := aContest.CreditsWorkedStation(aQso);
      end;
end;

function HostAreaRuleCredits(aEntrantInHostArea: boolean;
                             const aWorkedQTH: string;
                             aIsHostQTH: TDomesticQTHTest): boolean;
begin
   if aEntrantInHostArea then
      begin
      Result := True;
      end
   else if Assigned(aIsHostQTH) then
      begin
      Result := aIsHostQTH(aWorkedQTH);
      end
   else
      begin
      Result := False;
      end;
end;

function DomesticMultiplierIsDX(const aMultiplier: string): boolean;
begin
   (* UnicodeSameText, not SameText: SysUtils' SameText takes AnsiString, and
      `string` is UnicodeString here -- the registry's compare for the same
      reason. *)
   Result := UnicodeSameText(aMultiplier, 'DX');
end;

function ContestPrefixMultiplierKey(aContest: TContestBase; const aQso: ContestExchange;
                                   out aKey: PrefixMultiplierString): boolean;
begin
   if aContest = nil then
      begin
      aKey := '';
      Result := False;
      end
   else
      begin
      Result := aContest.PrefixMultiplierKey(aQso, aKey);
      end;
end;

function ContestHasPrefixMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.HasPrefixMultiplier;
      end;
end;

function ContestDXMultiplierKey(aContest: TContestBase; const aQso: ContestExchange;
                                out aKey: DXMultiplierString): boolean;
begin
   if aContest = nil then
      begin
      aKey := '';
      Result := False;
      end
   else
      begin
      Result := aContest.DXMultiplierKey(aQso, aKey);
      end;
end;

function ContestHasDXMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.HasDXMultiplier;
      end;
end;

function ContestCountryMode(aContest: TContestBase): CountryModeType;
begin
   if aContest = nil then
      begin
      Result := CQCountryMode;
      end
   else
      begin
      Result := aContest.CountryMode;
      end;
end;

function ContestListsRemainingDXCountry(aContest: TContestBase;
                                        const aCountryID: DXMultiplierString;
                                        aContinent: ContinentType): boolean;
begin
   if aContest = nil then
      begin
      Result := True;
      end
   else
      begin
      Result := aContest.ListsRemainingDXCountry(aCountryID, aContinent);
      end;
end;

function ContestHasZoneMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.HasZoneMultiplier;
      end;
end;

function ContestZoneMultiplierCount(aContest: TContestBase): integer;
begin
   if aContest = nil then
      begin
      Result := 0;
      end
   else
      begin
      Result := aContest.ZoneMultiplierCount;
      end;
end;

function ContestZoneMultiplierZones(aContest: TContestBase): TZoneMultiplierZones;
begin
   if aContest = nil then
      begin
      Result := zmzNotCQOrITU;
      end
   else
      begin
      Result := aContest.ZoneMultiplierZones;
      end;
end;

function ContestNumbersZonesFromZero(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.NumbersZonesFromZero;
      end;
end;

function ContestDomesticMultiplierFromQTH(aContest: TContestBase;
                                          const aText: Str20;
                                          var aMultiplier: Str10;
                                          var aQTH: Str10;
                                          var aFound: boolean): TDomesticQTHAnswer;
begin
   if aContest = nil then
      begin
      Result := dqaLookUpDomesticFile;
      end
   else
      begin
      Result := aContest.DomesticMultiplierFromQTH(aText, aMultiplier, aQTH, aFound);
      end;
end;

function ContestDomesticMultiplierHint(aContest: TContestBase; const aText: Str14): string;
begin
   if aContest = nil then
      begin
      Result := string(aText);
      end
   else
      begin
      Result := aContest.DomesticMultiplierHint(aText);
      end;
end;

function ContestHasGridSquareMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.HasGridSquareMultiplier;
      end;
end;

function ContestHasGridFieldMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.HasGridFieldMultiplier;
      end;
end;

function ContestDomesticQTHReplacesDXMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.DomesticQTHReplacesDXMultiplier;
      end;
end;

function ContestDomesticQTHIsNeverAGrid(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.DomesticQTHIsNeverAGrid;
      end;
end;

function ContestUsesDomesticFile(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.UsesDomesticFile;
      end;
end;

function ContestHasDomesticMultiplier(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.HasDomesticMultiplier;
      end;
end;

function ContestStripsRoverCountyFromCall(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.StripsRoverCountyFromCall;
      end;
end;

function ContestLogsSeveralQTHsFromOneEntry(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.LogsSeveralQTHsFromOneEntry;
      end;
end;

function ContestAcceptsBlankExchange(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.AcceptsBlankExchange;
      end;
end;

function ContestDupeKeyQualifier(aContest: TContestBase; const aQso: ContestExchange): string;
begin
   if aContest = nil then
      begin
      Result := '';
      end
   else
      begin
      Result := aContest.DupeKeyQualifier(aQso);
      end;
end;

function ContestDupeKeyIncludesReceivedQTH(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.DupeKeyIncludesReceivedQTH;
      end;
end;

function ContestExchangeCarriesDomesticQTH(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.ExchangeCarriesDomesticQTH;
      end;
end;

function ContestExchangeCarriesZone(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.ExchangeCarriesZone;
      end;
end;

function ContestExchangeCarriesGridSquare(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.ExchangeCarriesGridSquare;
      end;
end;

function ContestPerQSOExchangeLeadsWithSerial(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.PerQSOExchangeLeadsWithSerial;
      end;
end;

function ContestReceivedExchangeFields(aContest: TContestBase): ExchangeInformationRecord;
begin
   if aContest = nil then
      begin
      Result := ExchangeFieldsNone;
      end
   else
      begin
      Result := aContest.ReceivedExchangeFields;
      end;
end;

function ContestReceivesGridSquareExchange(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.ReceivesGridSquareExchange;
      end;
end;

function ContestExchangeTextMayHoldGridSquare(aContest: TContestBase): boolean;
begin
   if aContest = nil then
      begin
      Result := False;
      end
   else
      begin
      Result := aContest.ExchangeTextMayHoldGridSquare;
      end;
end;

procedure ContestSetUpDefaultExchangeMessages(aContest: TContestBase;
                                              aMessages: TExchangeMessageWriters);
begin
   if aContest <> nil then
      begin
      aContest.SetUpDefaultExchangeMessages(aMessages);
      end;
end;

function InitialZoneFromCallHistory(aZones: TZoneMultiplierZones;
                                    const aCQZone: ShortString;
                                    const aITUZone: ShortString;
                                    out aZone: ShortString): boolean;
begin
   aZone := '';
   Result := False;
   if aZones = zmzITUZones then
      begin
      if aITUZone <> '' then
         begin
         aZone := aITUZone;
         Result := True;
         end;
      end
   else if aCQZone <> '' then
      begin
      aZone := aCQZone;
      Result := True;
      end;
end;

function ApplyQSOPointOverride(const aOverrides: TQSOPointOverrides;
                               var aQso: ContestExchange): boolean;

   function Apply(const aOverride: TQSOPointOverride;
                  aMode: ModeType;
                  aDomestic: boolean): boolean;
   begin
      Result := (aOverride.Stated)                    and
                (aQso.Mode = aMode)                   and
                ((Length(aQso.DomesticQTH) > 0) = aDomestic);
      if Result then
         begin
         aQso.QSOPoints := aOverride.Points;
         end;
   end;

begin
   (* AN EXPLICIT CHAIN, NOT `a or b or c`: Apply writes the points, so the
      first match must stop the rest, and that should not hang on the
      compiler's short-circuit switch. *)
   Result := Apply(aOverrides.DomesticCW, CW, True);
   if not Result then
      begin
      Result := Apply(aOverrides.DXCW, CW, False);
      end;
   if not Result then
      begin
      Result := Apply(aOverrides.DomesticPhone, Phone, True);
      end;
   if not Result then
      begin
      Result := Apply(aOverrides.DXPhone, Phone, False);
      end;
end;

procedure TContestBase.ScoreQSO(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 0;

   (* THROUGH ContestCreditsBand, so the points and LOGDUPE.SetMultFlags's
      multipliers ask the one function that states the band rule. *)
   if not ContestCreditsBand(Self, aQso.Band) then
      begin
      Exit;
      end;

   (* THE HOST-AREA RULE, Q107 -- before the overrides, as the band rule is.
      See CreditsWorkedStation. *)
   if not CreditsWorkedStation(aQso) then
      begin
      Exit;
      end;

   if ApplyQSOPointOverride(FStation.PointOverrides, aQso) then
      begin
      Exit;
      end;

   CalculateQSOPoints(aQso);
end;

procedure TContestBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 0;
end;

(* ------------------------------------------------------------------------ *)
(* STAGE 3 -- THE FINAL SCORE (M6)                                          *)
(* ------------------------------------------------------------------------ *)

procedure TLoggedQSOList.Add(const aQso: ContestExchange);
begin
   if FCount >= Length(FQSOs) then
      begin
      SetLength(FQSOs, FCount * 2 + 16);
      end;
   FQSOs[FCount] := aQso;
   inc(FCount);
end;

procedure TLoggedQSOList.Clear;
begin
   FCount := 0;
end;

function TLoggedQSOList.Count: integer;
begin
   Result := FCount;
end;

function TLoggedQSOList.QSO(aIndex: integer): ContestExchange;
begin
   Result := FQSOs[aIndex];
end;

function QSOCountsTowardTotals(const aQso: ContestExchange): boolean;
begin
   Result := (aQso.ceRecordKind = rkQSO)  and
             (not aQso.ceQSO_Deleted)     and
             (aQso.Band <> NoBand)        and
             (aQso.Mode <> NoMode)        and
             (not aQso.ceXQSO);
end;

procedure ClearMultiplierFlags(var aQso: ContestExchange);
begin
   aQso.DomesticMult := False;
   aQso.DXMult := False;
   aQso.PrefixMult := False;
   aQso.ZoneMult := False;
end;

procedure ClearXQSOScoring(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 0;
   aQso.ceDupe := False;
   ClearMultiplierFlags(aQso);
end;

function BonusModeOf(aMode: ModeType): ModeType;
begin
   if aMode = FM then
      begin
      Result := Phone;
      end
   else
      begin
      Result := aMode;
      end;
end;

function LogContestYear(const aTotals: TScoreTotals; aView: TLoggedQSOView): integer;
var
   year, month, day: word;
   i: integer;
   qso: ContestExchange;
   key, earliest: longint;
begin
   if aTotals.LogStartTime > 0 then
      begin
      DecodeDate(aTotals.LogStartTime, year, month, day);
      Result := year;
      Exit;
      end;

   Result := 0;
   if aView = nil then
      begin
      Exit;
      end;

   (* qtYear IS THE YEAR MINUS 2000 (uLogBinaryFile.QSOTimeToUnixUTC says
      why), so year-month-day packs into one comparable number. *)
   earliest := 0;
   for i := 0 to aView.Count - 1 do
      begin
      qso := aView.QSO(i);
      if (qso.tSysTime.qtMonth = 0) or
         (qso.tSysTime.qtDay = 0) then
         begin
         Continue;
         end;
      key := (2000 + longint(qso.tSysTime.qtYear)) * 10000 +
             longint(qso.tSysTime.qtMonth) * 100 +
             longint(qso.tSysTime.qtDay);
      if (earliest = 0) or
         (key < earliest) then
         begin
         earliest := key;
         end;
      end;

   if earliest <> 0 then
      begin
      Result := earliest div 10000;
      end;
end;

function TContestBase.FinalScore(const aTotals: TScoreTotals;
                                 aView: TLoggedQSOView): longint;
begin
   Result := CombineScore(aTotals) + BonusPoints(aTotals, aView);
end;

function TContestBase.CombineScore(const aTotals: TScoreTotals): longint;
begin
   (* LogEdit.TotalScore's first test -- see the declaration. Its second
      is FISTS's own CombineWithMultipliers since M11 S7. *)
   if not aTotals.SessionCountsMultipliers then
      begin
      Result := ContestPoints(aTotals);
      Exit;
      end;

   Result := CombineWithMultipliers(aTotals);
end;

function TContestBase.ContestPoints(const aTotals: TScoreTotals): longint;
begin
   Result := aTotals.QSOPoints + aTotals.QTCPoints;
end;

function TContestBase.SummedMultipliers(const aTotals: TScoreTotals): longint;
var
   m: RemainingMultiplierType;
begin
   (* THE SCORED BAND'S ROW: the one band a single-band entry scores, else
      AllBands -- TotalScore's two arms, which differed only in that index.
      EVERY KIND, rmNoRemMultDisplay included, as TotalScore summed them; the
      sheet never counts that one, so it adds 0. *)
   Result := 0;
   for m := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
      begin
      Result := Result + aTotals.Mults[aTotals.ScoredBand, Both, m];
      end;
end;

function TContestBase.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals) * SummedMultipliers(aTotals);
end;

function TContestBase.GetBonusStations: TBonusStationList;
begin
   (* None. nil IS the empty dynamic array. *)
   Result := nil;
end;

function TContestBase.CountsTowardBonus(const aQso: ContestExchange): boolean;
begin
   Result := True;
end;

function TContestBase.CreditsBonusMode(aMode: ModeType): boolean;
begin
   Result := True;
end;

function TContestBase.BonusStationWorked(aView: TLoggedQSOView;
                                         const aCall: string;
                                         aAnyMode: boolean;
                                         aMode: ModeType): boolean;
var
   i: integer;
   qso: ContestExchange;
begin
   Result := False;
   for i := 0 to aView.Count - 1 do
      begin
      qso := aView.QSO(i);
      if (string(qso.Callsign) = aCall)                       and
         (aAnyMode or (BonusModeOf(qso.Mode) = aMode))        and
         CountsTowardBonus(qso)                               then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function TContestBase.BonusPoints(const aTotals: TScoreTotals;
                                  aView: TLoggedQSOView): longint;
const
   (* THE THREE MODES A OncePerMode BONUS CAN BE PAID IN. FM counts as
      phone (BonusModeOf), so it is not a fourth. *)
   BONUS_MODES: array[0..2] of ModeType = (CW, Digital, Phone);
var
   stations: TBonusStationList;
   i, m: integer;
begin
   Result := 0;
   stations := BonusStations;
   (* A CONTEST WITH NO BONUS STATION NEVER TOUCHES THE VIEW. *)
   for i := 0 to High(stations) do
      begin
      if stations[i].OncePerMode then
         begin
         for m := Low(BONUS_MODES) to High(BONUS_MODES) do
            begin
            if CreditsBonusMode(BONUS_MODES[m])                                    and
               BonusStationWorked(aView, stations[i].Call, False, BONUS_MODES[m])  then
               begin
               Result := Result + stations[i].Points;
               end;
            end;
         end
      else if BonusStationWorked(aView, stations[i].Call, True, CW) then
         begin
         Result := Result + stations[i].Points;
         end;
      end;
end;

function TContestBase.GetMarksDupes: boolean;
begin
   (* Every contest marks dupes unless it says otherwise -- see the
      declaration. *)
   Result := True;
end;

function TContestBase.UsesBand(aBand: BandType): boolean;
begin
   (* Every band, as before -- see the declaration. Not a permissive
      placeholder: it is an exact statement of what TR4W did for every contest
      until a contest stated its own bands. *)
   Result := True;
end;

function TContestBase.CountsAsMultiplier(const aQso: ContestExchange;
                                         aKind: RemainingMultiplierType): boolean;
begin
   (* The sheet decides, as it did for every contest SetMultFlags did not
      name -- see the declaration. *)
   Result := True;
end;

function TContestBase.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   (* No host area: every worked station is credited -- see the declaration. *)
   Result := True;
end;

function TContestBase.DomesticMultiplierFromCall(const aCall: string;
                                                 const aLookups: TMultiplierHintLookups): string;
begin
   (* No opinion, as GetMultArray had for every contest it did not name. *)
   Result := '';
end;

function TContestBase.PrefixMultiplierKey(const aQso: ContestExchange;
                                          out aKey: PrefixMultiplierString): boolean;
begin
   (* No prefix multiplier -- see the declaration. *)
   aKey := '';
   Result := False;
end;

function TContestBase.HasPrefixMultiplier: boolean;
begin
   (* No prefix multiplier -- see the declaration. *)
   Result := False;
end;

function TContestBase.DXMultiplierKey(const aQso: ContestExchange;
                                      out aKey: DXMultiplierString): boolean;
begin
   (* No DX multiplier -- see the declaration. *)
   aKey := '';
   Result := False;
end;

function TContestBase.HasDXMultiplier: boolean;
begin
   (* No DX multiplier -- see the declaration. *)
   Result := False;
end;

function TContestBase.CountryMode: CountryModeType;
begin
   (* The CQ list -- see the declaration. *)
   Result := CQCountryMode;
end;

function TContestBase.ListsRemainingDXCountry(const aCountryID: DXMultiplierString;
                                              aContinent: ContinentType): boolean;
begin
   (* No filter -- see the declaration. *)
   Result := True;
end;

function TContestBase.HasZoneMultiplier: boolean;
begin
   (* No zone multiplier -- see the declaration. *)
   Result := False;
end;

function TContestBase.ZoneMultiplierCount: integer;
begin
   (* No zone multiplier -- see the declaration. *)
   Result := 0;
end;

function TContestBase.ZoneMultiplierZones: TZoneMultiplierZones;
begin
   Result := zmzNotCQOrITU;
end;

function TContestBase.NumbersZonesFromZero: boolean;
begin
   Result := False;
end;

function TContestBase.DomesticMultiplierFromQTH(const aText: Str20;
                                                var aMultiplier: Str10;
                                                var aQTH: Str10;
                                                var aFound: boolean): TDomesticQTHAnswer;
begin
   (* The domestic file, writing nothing -- see the declaration. *)
   Result := dqaLookUpDomesticFile;
end;

function TContestBase.DomesticMultiplierHint(const aText: Str14): string;
begin
   (* The text itself -- see the declaration. *)
   Result := string(aText);
end;

function TContestBase.HasGridSquareMultiplier: boolean;
begin
   Result := False;
end;

function TContestBase.HasGridFieldMultiplier: boolean;
begin
   Result := False;
end;

function TContestBase.DomesticQTHReplacesDXMultiplier: boolean;
begin
   Result := False;
end;

function TContestBase.DomesticQTHIsNeverAGrid: boolean;
begin
   Result := False;
end;

function TContestBase.UsesDomesticFile: boolean;
begin
   (* No domestic file -- see the declaration. *)
   Result := False;
end;

function TContestBase.HasDomesticMultiplier: boolean;
begin
   (* The contest's own statements, composed -- see the declaration. *)
   Result := UsesDomesticFile                or
             HasGridSquareMultiplier         or
             HasGridFieldMultiplier          or
             DomesticQTHReplacesDXMultiplier or
             DomesticQTHIsNeverAGrid;
end;

function TContestBase.StripsRoverCountyFromCall: boolean;
begin
   (* No rover county -- see the declaration. *)
   Result := False;
end;

function TContestBase.SplitsRoverCallOnExport: boolean;
begin
   (* Not a QSO party: the slash call is the call -- see the declaration. *)
   Result := False;
end;

function TContestBase.DupeKeyIncludesReceivedQTH: boolean;
begin
   (* The call alone is the dupe key -- see the declaration. *)
   Result := False;
end;

function TContestBase.DupeKeyQualifier(const aQso: ContestExchange): string;
begin
   Result := '';
   if not DupeKeyIncludesReceivedQTH then
      begin
      Exit;
      end;
   Result := UpperCase(Trim(string(aQso.DomesticQTH)));
   if Result = '' then
      begin
      Result := UpperCase(Trim(string(aQso.QTHString)));
      end;
end;

function TContestBase.ADIFCountyState(const aQso: ContestExchange): string;
begin
   (* Not a QSO party: no county -- see the declaration. *)
   Result := '';
end;

function TContestBase.ADIFWorkedStationState(const aQso: ContestExchange): string;
begin
   (* Not a QSO party: no ADIF STATE -- see the declaration. *)
   Result := '';
end;

function TContestBase.WritesADIFCounty: boolean;
begin
   (* Not a party with an ADIF county enumeration -- see the declaration. *)
   Result := False;
end;

function TContestBase.LogsSeveralQTHsFromOneEntry: boolean;
begin
   (* One QTH an entry -- see the declaration. *)
   Result := False;
end;

function TContestBase.AcceptsBlankExchange: boolean;
begin
   (* An exchange is required -- see the declaration. *)
   Result := False;
end;

function TContestBase.ExchangeCarriesDomesticQTH: boolean;
begin
   (* None -- see the declaration. *)
   Result := False;
end;

function TContestBase.ExchangeCarriesZone: boolean;
begin
   (* None -- see the declaration. *)
   Result := False;
end;

function TContestBase.ExchangeCarriesGridSquare: boolean;
begin
   (* None -- see the declaration. *)
   Result := False;
end;

function TContestBase.ExchangeTextMayHoldGridSquare: boolean;
begin
   (* None -- see the declaration. *)
   Result := False;
end;

function TContestBase.PerQSOExchangeLeadsWithSerial: boolean;
begin
   (* The RST leads -- see the declaration. *)
   Result := False;
end;

function TContestBase.SendsStateAfterZone: boolean;
begin
   (* The zone alone -- see the declaration. *)
   Result := False;
end;

function TContestBase.RunsInMode(aMode: ModeType): boolean;
begin
   (* Every mode -- see the declaration. *)
   Result := True;
end;

function TContestBase.ValidateClass(const aClass: string;
                                    out aErrorMessage: string): boolean;
begin
   (* Most contests have no class. Accepting anything is what "this contest has
      no such rule" means -- not a permissive default somebody forgot to
      tighten. *)
   aErrorMessage := '';
   Result := True;
end;

(* A QSO AS A LOG LINE NAMES IT: call, band, mode and the UTC time. One
   spelling for every export Error this unit logs. *)
function DescribeQSOForLog(const aQso: ContestExchange): string;
begin
   Result := Format('%s %s %s %.4d-%.2d-%.2d %.2d%.2dZ',
      [string(aQso.Callsign), ADIFBANDSTRINGSARRAY[aQso.Band],
       ADIFModeString[aQso.Mode], aQso.tSysTime.qtYear + 2000,
       aQso.tSysTime.qtMonth, aQso.tSysTime.qtDay, aQso.tSysTime.qtHour,
       aQso.tSysTime.qtMinute]);
end;

(* THE CONTEST'S TWO CABRILLO COLUMNS -- see the declarations.

   Only the sent half reports a column with no layout, so it is logged once
   per QSO line, not twice -- as the machine did (Issue #1043). *)
function TContestBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
begin
   Result := GetCabrilloSentExchange(aMy, aQso, aCtx);
   if Result = CabrilloExchangeErrorMarker then
      begin
      logger.Error(Format(
        'FormatCabrilloSentExchange: contest "%s" states no Cabrillo exchange layout -- ' +
        'wrote ERROR marker to the Cabrillo line for QSO %s. See Issue #1043, plan F26.',
        [FId, DescribeQSOForLog(aQso)]));
      end;
end;

function TContestBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := GetCabrilloReceivedExchange(aMy, aQso, aCtx);
end;

function TContestBase.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string;
begin
   (* Nothing it could be wrong about -- see the declaration. *)
   Result := CabrilloSentNotHandled(aMy, aQso, aCtx);
end;

function TContestBase.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                  const aQso: ContestExchange;
                                                  const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNotHandled(aMy, aQso, aCtx);
end;

function TContestBase.TryFormatADIFSentExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                out aSent: string;
                                                out aFailure: string): boolean;
begin
   aSent := '';
   aFailure := '';
   try
      aSent := GetADIFSentExchange(aMy, aQso);
      Result := True;
   except
      on E: Exception do
         begin
         Result := False;
         aSent := '';
         aFailure := E.ClassName + ': ' + E.Message;
         logger.Error(Format(
            'ADIF STX_STRING not built for contest "%s", QSO %s -- left out of the record. %s',
            [FId, DescribeQSOForLog(aQso), aFailure]));
         end;
   end;
end;

function TContestBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
var
   failure: string;
begin
   TryFormatADIFSentExchange(aMy, aQso, Result, failure);
end;

function TContestBase.GetADIFSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange): string;
begin
   (* The base states no layout -- see the declaration. *)
   Result := ADIFSentNotImplemented(aMy, aQso);
end;

function TContestBase.GetReceivesGridSquareExchange: boolean;
begin
   Result := False;
end;

function TContestBase.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   (* Nothing beyond the generic QTH uADIF has already written. *)
   Result := '';
end;

function TContestBase.EmitADIFReportFields(const aQso: ContestExchange): string;
begin
   (* The RST pair, for EVERY QSO -- NY4I, 2026-10-17: "Every QSO". It is a
      QSO attribute, as in D7, not a field of the contest's exchange. *)
   Result := EmitADIFField('RST_SENT', IntToStr(aQso.RSTSent)) +
             EmitADIFField('RST_RCVD', IntToStr(aQso.RSTReceived));
end;

function TContestBase.EmitADIFReceivedFields(const aQso: ContestExchange): string;
var
   declared: ExchangeInformationRecord;
begin
   (* The class's own statement of its exchange, asked once -- see the
      declaration for the field-to-tag table. The order is the record's
      order since D7: QTH, PRECEDENCE, CHECK, NAME, power, SRX, STX, TEN_TEN,
      AGE. *)
   declared := ReceivedExchangeFields;
   Result := '';

   if declared.QTH and
      (aQso.QTHString <> '') then
      begin
      Result := Result + EmitADIFField('QTH', string(aQso.QTHString));
      end;

   if declared.Precedence and
      (aQso.Precedence <> #0) then
      begin
      Result := Result + EmitADIFField('PRECEDENCE', string(aQso.Precedence));
      end;
   if declared.Check and
      (aQso.Check <> 0) then
      begin
      Result := Result + EmitADIFField('CHECK', PadInt(aQso.Check, 2));
      end;

   if declared.Name and
      (aQso.Name <> '') then
      begin
      Result := Result + EmitADIFField('NAME', string(aQso.Name));
      end;

   (* WHICH TAG THE POWER FIELD GOES TO IS THE CONTEST'S: it holds the FOC
      membership number for the FOC Marathon, a power for everything else. *)
   if declared.Power and
      (aQso.Power <> '') then
      begin
      Result := Result + EmitADIFField(ADIFPowerTag, string(aQso.Power));
      end;

   (* SRX / STX, the numeric serials. Two "unset" sentinels are in use:
        $FFFF (65535) -- set by uADIF.InitContestExchangeForParse for records
                         built from imported ADIF
        -1            -- left in place by live-entry and binary-log paths for
                         contests that don't use a serial (Field Day on the SRX
                         side: ExchString carries class and section)
      Without the > 0 guard a Field Day record would write <SRX:5>000-1,
      because PadInt(-1, 5) is the text "000-1". *)
   if declared.QSONumber and
      (aQso.NumberReceived > 0) and
      (aQso.NumberReceived <> $FFFF) then
      begin
      Result := Result + EmitADIFField('SRX', PadInt(aQso.NumberReceived, 5));
      end;

   (* STX is OURS, not a received field -- see the declaration. *)
   if (aQso.NumberSent > 0) and
      (aQso.NumberSent <> $FFFF) then
      begin
      Result := Result + EmitADIFField('STX', PadInt(aQso.NumberSent, 5));
      end;

   (* A 10-10 number is never 0, so a zero is as unset as the $FFFF the parse
      leaves for a non-member: the old test wrote <TEN_TEN:5>00000 for any
      path that left the field 0. *)
   if declared.TenTenNum and
      (aQso.TenTenNum <> $FFFF) and
      (aQso.TenTenNum <> 0) then
      begin
      Result := Result + EmitADIFField('TEN_TEN', PadInt(aQso.TenTenNum, 5));
      end;

   if declared.Age and
      (aQso.Age <> 0) then
      begin
      Result := Result + EmitADIFField('AGE', PadInt(aQso.Age, 3));
      end;
end;

procedure TContestBase.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                       const aSession: TADIFImportSession;
                                       var aExch: ContestExchange);
var
   j: integer;
begin
   (* THE CLASSLESS FALLBACK, transcribed from the `else` of
      MainUnit.ApplyContestSpecificADIFTail. The first test is the open
      contest's grid-square answers (its multiplier, since M11 S6 part 1b;
      its exchange, since S9b -- which were the session's exchange kinds),
      and the last is the open contest's multiplier flag, so none of it
      names a contest. *)
   if aSession.CountsGridSquares                            or
      aSession.ReceivesGridSquare                           then
      begin
      aExch.QTHString   := ShortString(aTemps.GridSquare);
      aExch.DomesticQTH := ShortString(aTemps.GridSquare);
      aExch.ExchString  := ShortString(IntToStr(aExch.RSTReceived) + ' ' +
                                       aTemps.GridSquare);
      end
   else if aSession.DoingDomesticMults then
      begin
      if aExch.QTHString <> '' then
         begin
         (* The ADIF QTH tag carries the county or state code unambiguously
            for state QSO parties. Prefer it when present: the alpha-prefix
            of SRX_STRING below was already unreliable, and now fails
            outright because SRX_STRING is normalised to include a leading
            RST ("59 MON") on export. *)
         aExch.DomesticQTH := aExch.QTHString;
         end
      else
         begin
         (* Legacy fallback for an import that lacks a QTH tag: the ALPHA
            prefix of SRX_STRING. *)
         j := 1;
         while (j <= Length(aTemps.SRX_String)) and
               not (aTemps.SRX_String[j] in ['0'..'9']) do
            begin
            Inc(j);
            end;
         aExch.DomesticQTH := ShortString(Copy(aTemps.SRX_String, 1, j - 1));
         end;
      end
   else
      begin
      aExch.ExchString := ShortString(aTemps.SRX_String);
      end;
end;

function TContestBase.ParseReceivedExchange(const aText: string;
                                            const aSession: TReceivedExchangeSession;
                                            var aExch: ContestExchange;
                                            out aErrorMessage: string): boolean;
var
   formatOwner: TContestBase;
begin
   (* The plain parse in the contest's format -- see the declaration. *)
   aErrorMessage := '';
   formatOwner := aSession.ExchangeFormatOf;
   if formatOwner = nil then
      begin
      formatOwner := Self;
      end;
   Result := formatOwner.ParseReceivedExchangeFormat(aText, aSession.Parsers, aExch);
end;

function TContestBase.ParseReceivedExchangeFormat(const aText: string;
                                                  aParsers: TExchangeParsers;
                                                  var aExch: ContestExchange): boolean;
begin
   (* No format: what the machine gave UnknownExchange -- see the
      declaration. *)
   Result := False;
end;

procedure TContestBase.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   (* None: the old `case` had no arm for most shapes -- see the
      declaration. *)
end;

procedure TContestBase.SetUpDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   WriteDefaultExchangeMessages(aMessages);
end;

function TContestBase.MayBeACallsign(const aWord: string): boolean;
begin
   Result := True;
end;

function TContestBase.InitialExchangeFromCall(const aCall: string;
                                              const aCountryID: string;
                                              out aExchange: string): boolean;
begin
   aExchange := '';
   Result := False;
end;

function TContestBase.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                 aExchangeCarriesRST: boolean): string;
begin
   (* PostUnit's SRX_STRING arm, moved -- see the declaration. *)
   if aExchangeCarriesRST then
      begin
      Result := ResolveSRXString(aQso);
      end
   else
      begin
      Result := string(aQso.ExchString);
      end;
end;

function TContestBase.EmitADIFExchangeFields(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             aExchangeCarriesRST: boolean): string;
begin
   (* PostUnit's SRX_STRING line, moved -- see the declaration. *)
   Result := EmitADIFField('SRX_STRING',
      FormatADIFReceivedExchange(aQso, aExchangeCarriesRST));
end;

function TContestBase.GetADIFPowerTag: string;
begin
   Result := 'RX_PWR';
end;

function TContestBase.GetWritesADIFContestId: boolean;
begin
   Result := True;
end;

function TContestBase.ValidateDXQTH(const aQTH: string;
                                    out aResolved: string;
                                    out aErrorMessage: string): boolean;
begin
   aResolved := aQTH;
   aErrorMessage := '';
   Result := False;
end;

(* The two answers every Field-Day-shaped contest gives, with the extras it
  allows passed in. 'DX' and an empty exchange are common to both runnings;
  Winter Field Day adds 'MX'. *)
function TContestBase.ValidateDXQTHAllowing(const aQTH: string;
                                            const aAlsoAllowed: string;
                                            out aResolved: string;
                                            out aErrorMessage: string): boolean;
begin
   aErrorMessage := '';
   Result := True;

   if (aQTH = 'DX') or (aQTH = '') then
      begin
      (* An empty exchange from a DX station means DX -- the class alone. *)
      aResolved := 'DX';
      Exit;
      end;

   if (aAlsoAllowed <> '') and (aQTH = aAlsoAllowed) then
      begin
      aResolved := aQTH;
      Exit;
      end;

   aResolved := aQTH;
   aErrorMessage := TC_ARRLFIELDDAYIMPROPERDXEXCHANGE;
   Result := False;
end;

function TContestBase.RequireReceivedGrid(aAccepted: boolean;
                                          const aExch: ContestExchange;
                                          var aErrorMessage: string): boolean;
begin
   (* See the declaration. *)
   Result := aAccepted;
   if aAccepted and (aExch.DomesticQTH = '') then
      begin
      aErrorMessage := SExchangeGridRequired;
      Result := False;
      end;
end;

function TContestBase.ValidateCountAndLetterClass(const aClass: string;
                                                  const aValidLetters: string;
                                                  const aBadClassMessage: string;
                                                  out aErrorMessage: string): boolean;
var
   i: integer;
   (* THE COUNT AS A NUMBER, not a string to convert back.

      The legacy loop builds "2" as text and then StrToIntDefs it, which is a
      round trip through a string for a value it just read a digit at a time --
      and a narrowing conversion at the end, because the RTL's StrToIntDef here
      takes an AnsiString. Accumulating is shorter, has no conversion, and the
      digit COUNT is kept separately so an empty class can still be told from
      a class of "0". *)
   count: integer;
   countDigits: integer;
   category: string;
   categorySet: boolean;
begin
   Result := False;
   aErrorMessage := '';
   count := 0;
   countDigits := 0;
   category := '';
   categorySet := False;

   for i := 1 to Length(aClass) do
      begin
      if aClass[i] in ['0'..'9'] then
         begin
         inc(countDigits);
         (* Capped so a long run of digits cannot overflow into a value that
            happens to land back inside 1..99. Anything past two digits is
            already invalid. *)
         if countDigits <= 3 then
            begin
            count := count * 10 + (Ord(aClass[i]) - Ord('0'));
            end
         else
            begin
            count := 1000;
            end;
         end
      else if Pos(UpCase(aClass[i]), aValidLetters) > 0 then
         begin
         (* A SECOND letter empties the category rather than appending, so "2AB"
            fails on the length test below. Reproduced from the legacy loop,
            where it reads as a break with sCategory cleared. *)
         if categorySet then
            begin
            category := '';
            Break;
            end
         else
            begin
            categorySet := True;
            category := category + aClass[i];
            end;
         end
      else
         begin
         (* Anything else at all -- a letter this contest does not use, or
            punctuation. Empties the category so the message below is the
            contest's own, rather than a generic one. *)
         category := '';
         Break;
         end;
      end;

   if (countDigits = 0) or (not (count in [1..99])) then
      begin
      aErrorMessage := TC_IMPROPERTRANSMITTERCOUNT;
      end
   else if Length(category) <> 1 then
      begin
      aErrorMessage := aBadClassMessage;
      end
   else
      begin
      Result := True;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* SET-UP -- M7a                                                            *)
(* ------------------------------------------------------------------------ *)

procedure TContestBase.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   (* Nothing: see the declaration. *)
end;

function TContestBase.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := '';
end;

function TContestBase.RepeatSPExchangeDefault(const aStation: TStationContext): string;
begin
   Result := '';
end;

(* ------------------------------------------------------------------------ *)
(* THE DISPLAY AND THE REPORTS -- M9a                                        *)
(* ------------------------------------------------------------------------ *)

function TContestBase.GetQSOPartyArea: string;
begin
   (* Not a QSO party: no area. Every one of the 22 parties answers for
      itself (M10 S5). The free function QSOPartyAreaName that read the
      QSOParties entry is deleted (M10 S6). *)
   Result := '';
end;

function TContestBase.NewContestValueRefusal(aField: TNewContestField;
                                             const aValue: string): string;
begin
   (* Every value accepted -- see the declaration. *)
   Result := '';
end;

procedure TContestBase.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
var
   area: string;
begin
   (* uNewContest's head, keyed on the trait: a US state QSO party asks for
      the county or the state, in words that name the host twice -- see the
      declaration. *)
   if IsUSQSOParty then
      begin
      area := QSOPartyArea;
      aPrompts.AskFieldWithComment(Format(TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX,
                                          [area, area]),
                                   ncfMyState);
      end;
end;

function TContestBase.CabrilloContestName(const aContestTitle: string;
                                          const aSessionName: string): string;
begin
   Result := CabrilloName;
end;

function TContestBase.CabrilloHeaderLinesBeforeTag(const aTagName: string;
                                                   const aTagValue: string;
                                                   const aStation: TStationContext): string;
begin
   Result := '';
end;

function TContestBase.CabrilloModeString(aMode: ModeType;
                                         aExtMode: ExtendedModeType): string;
begin
   Result := FormatCabrilloMode(aMode, aExtMode, False);
end;

function TContestBase.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   (* The exchange as the operator typed it -- what uExchangeBuilder sent for
      a contest it did not name, "no worse, and avoids fabricating fields". *)
   Result := Trim(string(aQso.ExchString));
end;

function TContestBase.CanonicalSentExchange(const aQso: ContestExchange;
                                            const aCtx: TCanonicalExchangeContext): string;
begin
   Result := CanonicalFromCQTemplate(aQso, aCtx.CQExchangeTemplate);
end;

function TContestBase.ScorePostingMultiplierType(aKind: RemainingMultiplierType;
                                                 aAllModes: boolean): string;
const
   (* LOGSUBS2's GetScoresMults, the labels every contest but WRTC posted. *)
   LABELS: array[RemainingMultiplierType] of string =
      ('', 'state', 'country', 'zone', 'prefix');
begin
   Result := LABELS[aKind];
end;

function TContestBase.GetTotalsDisplay: TTotalsDisplay;
begin
   (* What uTotal showed for every contest it did not name. *)
   Result.ShowsModeShares := False;
   Result.DomesticMultsCaption := TC_DOMMULTS;
   Result.DomesticMultsCaptionCW := 'CW Dom';
   Result.DomesticMultsCaptionPhone := 'Ph Dom';
end;

function TContestBase.GetSummarySheet: TSummarySheetLayout;
begin
   Result.MultiplierPerBandModeRow := False;
   Result.ClaimedScoreIsQSOPoints := False;
end;

function TContestBase.GetRequiresCabrilloLocation: boolean;
begin
   Result := False;
end;

function TContestBase.GetReportsRunningScore: boolean;
begin
   Result := True;
end;

function TContestBase.GetPermittedOperatingAids: TOperatingAids;
begin
   Result := [oaSuperCheckPartial, oaDXCluster, oaScorePosting];
end;

function TContestBase.GetOffersQTCs: boolean;
begin
   Result := False;
end;

function TContestBase.GetOffersParkTools: boolean;
begin
   Result := False;
end;

function TContestBase.GetIsActive: boolean;
begin
   Result := True;
end;

function TContestBase.GetShowsContestStatus: boolean;
begin
   Result := True;
end;

function TContestBase.GetMaximumContestDates: integer;
begin
   Result := 10;
end;

function TContestBase.GetMinimumOffTimeMinutes: integer;
begin
   Result := 30;
end;

function TContestBase.GetBandStepIncludesWARC: boolean;
begin
   Result := False;
end;

function TContestBase.GetPowerFieldIsFOCNumber: boolean;
begin
   Result := False;
end;

function TContestBase.CallEntryFrequencyWarning(aFreqKHz: integer): string;
begin
   Result := '';
end;

procedure TNewContestPrompts.AddChoice(aKind: TNewContestPromptKind;
                                       aField: TNewContestField;
                                       const aText: string);
var
   n: integer;
begin
   n := Length(FOnChoice);
   SetLength(FOnChoice, n + 1);
   FOnChoice[n].Kind := aKind;
   FOnChoice[n].Field := aField;
   FOnChoice[n].Text := aText;
end;

procedure TNewContestPrompts.AskField(aField: TNewContestField);
begin
   AddChoice(npkField, aField, '');
end;

procedure TNewContestPrompts.AskFieldWithComment(const aComment: string;
                                                 aField: TNewContestField);
begin
   AddChoice(npkFieldWithComment, aField, aComment);
end;

procedure TNewContestPrompts.OfferIAmIn(const aRegion: string);
begin
   (* The field is not read for a box; ncfMyState is its zero. *)
   AddChoice(npkIAmIn, ncfMyState, aRegion);
end;

procedure TNewContestPrompts.OfferIAmInCaption(const aCaption: string);
begin
   AddChoice(npkIAmInCaption, ncfMyState, aCaption);
end;

procedure TNewContestPrompts.AskFieldWithCommentWhenInside(const aComment: string;
                                                           aField: TNewContestField);
var
   n: integer;
begin
   n := Length(FWhenInside);
   SetLength(FWhenInside, n + 1);
   FWhenInside[n].Kind := npkFieldWithComment;
   FWhenInside[n].Field := aField;
   FWhenInside[n].Text := aComment;
end;

function TNewContestPrompts.ChoiceCount: integer;
begin
   Result := Length(FOnChoice);
end;

function TNewContestPrompts.Choice(aIndex: integer): TNewContestPrompt;
begin
   Result := FOnChoice[aIndex];
end;

function TNewContestPrompts.InsideCount: integer;
begin
   Result := Length(FWhenInside);
end;

function TNewContestPrompts.Inside(aIndex: integer): TNewContestPrompt;
begin
   Result := FWhenInside[aIndex];
end;

procedure TSessionDefaults.Stated(aValue: TSessionValue);
begin
   Include(FStated, aValue);
end;

function TSessionDefaults.IsStated(aValue: TSessionValue): boolean;
begin
   Result := aValue in FStated;
end;

procedure TSessionDefaults.SetExchange(aValue: ExchangeType);
begin
   FExchange := aValue;
   Stated(svExchange);
end;

procedure TSessionDefaults.SetBand(aValue: BandType);
begin
   FBand := aValue;
   Stated(svBand);
end;

procedure TSessionDefaults.SetMode(aValue: ModeType);
begin
   FMode := aValue;
   Stated(svMode);
end;

procedure TSessionDefaults.SetDomesticMultByBand(aValue: TAdditionalMultByBand);
begin
   FDomesticMultByBand := aValue;
   Stated(svDomesticMultByBand);
end;

procedure TSessionDefaults.SetInitialExchange(aValue: InitialExchangeType);
begin
   FInitialExchange := aValue;
   Stated(svInitialExchange);
end;

procedure TSessionDefaults.SetDXMultLimit(aValue: integer);
begin
   FDXMultLimit := aValue;
   Stated(svDXMultLimit);
end;

procedure TSessionDefaults.SetDXCCMultByBand(aValue: TAdditionalMultByBand);
begin
   FDXCCMultByBand := aValue;
   Stated(svDXCCMultByBand);
end;

procedure TSessionDefaults.SetMinitourDuration(aValue: TTourDuration);
begin
   FMinitourDuration := aValue;
   Stated(svMinitourDuration);
end;

procedure TSessionDefaults.SetContactsPerPage(aValue: TContactsPerPage);
begin
   FContactsPerPage := aValue;
   Stated(svContactsPerPage);
end;

function TSessionDefaults.GetFlag(aIndex: integer): boolean;
begin
   Result := FFlags[TSessionValue(aIndex)];
end;

procedure TSessionDefaults.SetFlag(aIndex: integer; aValue: boolean);
begin
   FFlags[TSessionValue(aIndex)] := aValue;
   Stated(TSessionValue(aIndex));
end;

function TSessionDefaults.GetText(aIndex: integer): string;
begin
   Result := FTexts[TSessionValue(aIndex)];
end;

procedure TSessionDefaults.SetText(aIndex: integer; const aValue: string);
begin
   FTexts[TSessionValue(aIndex)] := aValue;
   Stated(TSessionValue(aIndex));
end;

procedure TSessionDefaults.UseRSTQSONumberExchangeMemories;
begin
   Stated(svRSTQSONumberExchangeMemories);
end;

procedure TSessionDefaults.UseOperatorNameSet;
begin
   Stated(svOperatorNameSet);
end;

procedure TSessionDefaults.AddDomesticCountry(const aID: string);
var
   n: integer;
begin
   n := Length(FDomesticCountries);
   SetLength(FDomesticCountries, n + 1);
   FDomesticCountries[n] := aID;
end;

procedure TSessionDefaults.AddDomesticCountries(const aIDs: array of string);
var
   i: integer;
begin
   for i := Low(aIDs) to High(aIDs) do
      begin
      AddDomesticCountry(aIDs[i]);
      end;
end;

function TSessionDefaults.DomesticCountryCount: integer;
begin
   Result := Length(FDomesticCountries);
end;

function TSessionDefaults.DomesticCountry(aIndex: integer): string;
begin
   Result := FDomesticCountries[aIndex];
end;

procedure TSessionDefaults.AddMemory(aBank: TSessionMemoryBank; aMode: ModeType;
                                     aKey: TSessionMemoryKey; const aText: string);
var
   n: integer;
begin
   n := Length(FMemories);
   SetLength(FMemories, n + 1);
   FMemories[n].Bank := aBank;
   FMemories[n].Mode := aMode;
   FMemories[n].Key := aKey;
   FMemories[n].Text := aText;
end;

procedure TSessionDefaults.SetCQMemory(aMode: ModeType; aKey: TSessionMemoryKey;
                                       const aText: string);
begin
   AddMemory(smbCQ, aMode, aKey, aText);
end;

procedure TSessionDefaults.SetExchangeMemory(aMode: ModeType; aKey: TSessionMemoryKey;
                                             const aText: string);
begin
   AddMemory(smbExchange, aMode, aKey, aText);
end;

procedure TSessionDefaults.SetExchangeCaptionMemory(aMode: ModeType;
                                                    aKey: TSessionMemoryKey;
                                                    const aText: string);
begin
   AddMemory(smbExchangeCaption, aMode, aKey, aText);
end;

function TSessionDefaults.MemoryCount: integer;
begin
   Result := Length(FMemories);
end;

function TSessionDefaults.Memory(aIndex: integer): TSessionMemory;
begin
   Result := FMemories[aIndex];
end;

initialization
   logger := TLogLogger.GetLogger('uContestBase');

end.
