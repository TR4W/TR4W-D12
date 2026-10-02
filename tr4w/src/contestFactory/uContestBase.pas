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

  WHY THE UNIT IS A CONTEST AND NOT A STRATEGY ENUM. TR4W already decomposes a
  contest into strategy enums -- QSOPointMethodType, ExchangeType, DXMultType,
  PrefixMultType, ZoneMultType -- each dispatched by its own `case`, and it
  would be less work to turn each enum into a class. That is the wrong object
  model for this program:

    A CONTEST IS THE THING THAT EXISTS. An operator selects ARRL-DX-CW, not a
    point method. ContestsArray is already a row per contest; the enums are how
    that row is currently SPELLED, not what it is.

    THE ENUMS DO NOT COMPOSE CLEANLY. CalculateQSOPoints branches on the point
    method and then, inside several arms, on Contest anyway -- because scoring
    depends on things the enum does not carry. Splitting by enum keeps that
    second branch; splitting by contest removes it.

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
         "zone 0" from "no zone set" instead of scoring against a silent 0. *)
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
         as every field here. '' when unset, which both rules test for. *)
      MyState: string;

      (* THE CONTEST TITLE the operator's session carries -- Settings.Contest.
         Title, usually '<year> <name> <call>'.

         Added at M4 for the Batavia FT8 contest, whose legacy arm tests it
         for 'YBDXDI-FT8'. Recorded in the inventory (D7) as a test that
         cannot match with default settings; it is transcribed, not judged. *)
      ContestTitle: string;

      (* THE STATION'S OWN CALLSIGN -- MY CALL.

         Added at M5b (2026-10-02), when the UA4W Championship gained a class:
         its scoring asks which Russian oblast the station's own call is in.
         Same growth rule as every field here. *)
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

      SessionExchange IS THE EXCHANGE THE SESSION RESOLVED, NOT THE CONTEST'S
      ExchangeKind TRAIT, AND THAT IS MEASURED, NOT CHOSEN. Export has always
      keyed on the ActiveExchange global, and FCONTEST.FoundContest's arms set
      it per STATION after the head writes the trait: in the contest matrix
      twelve contests' ActiveExchange differs from their row in some variant
      (ARRL DX and ARRL 160, the 7QP, Arizona, NEQP, Texas, California and
      Salmon Run parties, JIDX, PACC), and an operator's EXCHANGE RECEIVED
      line moves it too. Keying the base's default on the trait would have
      changed those contests' Cabrillo; until M7 moves the arms into the
      contest's DescribeSession, the session's answer is the global, and the
      exporter hands it in as data -- the contest still reads no global. *)
   TCabrilloQSOContext = record
      SessionExchange: ExchangeType;
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

      (* Settings.Contest.Title -- read by the shared arms' 'PGA' test, an
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
      Exchange: ExchangeType;
      DomesticMult: DomesticMultType;
      DoingDomesticMults: boolean;
   end;

   (* THE ENGINE'S PARSE OF ONE EXCHANGE SHAPE -- M5b, 2026-10-02.

      An exchange SHAPE is what an RST-and-serial, a name-and-QTH or a
      class-and-section looks like typed: which word is which, and what the
      domestic-QTH table makes of a QTH. LOGSTUFF holds one parser per shape
      (ParseExchangeShape) and they name no contest. They read the engine's
      tables -- the domestic QTH table, CTY.DAT -- so a contest class cannot
      call them directly; the engine hands this function in, as DATA, and the
      class calls it with the shape it wants. *)
   TExchangeShapeParser = function(aShape: ExchangeType; const aText: string;
                                   var aExch: ContestExchange): boolean;

   (* CTY.DAT's zone for a callsign, in the session's zone list. *)
   TCallZoneLookup = function(const aCall: string): Byte;

   (* Does the session's domestic QTH table know this QTH? The table the
      engine loaded for this contest and this station -- for a state QSO
      party's out-of-state station, the host's county file. *)
   TDomesticQTHTest = function(const aQTH: string): boolean;

   (* What live entry does to give up on the QSO being typed: the call and
      exchange windows are cleared and the cursor goes back to the call. *)
   TEntryAbandon = procedure;

   (* WHAT A CONTEST IS HANDED WITH A TYPED EXCHANGE -- M5b, 2026-10-02.

      The counterpart of TADIFImportSession: the contest reads no global, so
      the engine passes in what it knows about the session, and the two
      engine services a rule needs. A RECORD BECAUSE IT IS AN INTERFACE
      PARAMETER, the exemption CLAUDE.md grants.

      Exchange IS THE SESSION'S EXCHANGE, NOT THE CONTEST'S ExchangeKind
      TRAIT, for the reason TCabrilloQSOContext records: FCONTEST's arms set
      it per station, and an operator's EXCHANGE RECEIVED line moves it.

      CallWindowHasCall says the exchange is being entered against a call in
      the call window -- live entry. SAC's rule acts only then. *)
   TReceivedExchangeSession = record
      Exchange: ExchangeType;
      ParseShape: TExchangeShapeParser;
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
      the reason TCabrilloQSOContext states: FCONTEST's arms and the
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

      (* The session's exchange and DX multiplier kind. *)
      SessionExchange: ExchangeType;
      SessionDXMult: DXMultType;

      (* A COUNT KEPT WHILE THE PROGRAM RUNS, NOT FROM THE LOG -- see
         TContestBase.TalliesLiveQSO, which says why it exists and that it is
         a defect preserved on purpose. 0 after every reload. *)
      LiveSessionTally: longint;
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

   TContestBase = class
   private
      FContest: ContestType;
      FStation: TStationContext;

      (* One bit of this contest's ContestsBooleanArray word -- the defaults of
         the set-up getters below, read in one place. *)
      function RowFlag(aBit: integer): boolean;
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
      function GetPrefixMultiplierType: PrefixMultType; virtual;
      function GetZoneMultiplierType: ZoneMultType; virtual;
      function GetDXMultiplierType: DXMultType; virtual;
      function GetDomesticMultiplierType: DomesticMultType; virtual;
      function GetInitialExchangeKind: InitialExchangeType; virtual;
      function GetExchangeKind: ExchangeType; virtual;
      function GetQSOPointMethod: QSOPointMethodType; virtual;
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
         at all: General QSO says False. uADIF.EmitADIFRecord asks; it used to
         test `ceContest in [POTA, GENERALQSO]`. POTA still has its own test
         there until it has a class (design Q6, which is NY4I's and open). The
         id itself is still answered -- the score-posting clients send it. *)
      function GetWritesADIFContestId: boolean; virtual;

      (* WHAT CONTEST SET-UP READS BESIDES THE ROW -- M2, 2026-10-01.

         FCONTEST.FoundContest's head used to read these straight out of
         ContestsBooleanArray, a word of flag bits per contest. They are facts
         about the contest -- whether a station may be worked once per band or
         per mode, whether a multiplier counts per band or per mode, whether
         the VHF bands are on, which zone list CTY.DAT answers with, whether a
         domestic country counts as a country -- so the contest states them,
         and set-up asks the contest (FCONTEST.ApplyContestTraits).

         EVERY ONE DEFAULTS TO THE ARRAY, as the row accessors above default
         to ContestsArray. A contest states one when it moves; until then the
         answer is the one the head always read. *)
      function GetQSOByBand: boolean; virtual;
      function GetQSOByMode: boolean; virtual;
      function GetMultByBand: boolean; virtual;
      function GetMultByMode: boolean; virtual;
      function GetVHFBandsEnabled: boolean; virtual;
      function GetCountsDomesticCountries: boolean; virtual;

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
         identical in D7's VC.pas for every contest (compared 2026-10-01). *)
      function GetZoneMode: ZoneModeType; virtual;

      (* A QSO PARTY'S OTHER DOMESTIC FILE -- the one an IN-STATE station
         loads. DomesticFileName is the file every other station loads: for a
         state party, the host's counties. '' for a contest that is not a QSO
         party. Default: the QSOParties entry the row's P indexes, which is
         where it is written down today. *)
      function GetInStateDomesticFileName: string; virtual;

      (* DOES THIS CONTEST MARK A REPEATED CONTACT AS A DUPE? -- M3, 2026-10-01.

         A SPONSOR'S DUPE POLICY, AND IT WAS SPELLED AS A POINT METHOD.
         LOGSUBS2 skipped the dupe flag when the global ActiveQSOPointMethod
         was AlwaysOnePointPerQSO, whose only meaning beside OnePointPerQSO is
         VC.pas's own note "Ignores dupes". So the rule was "this contest counts
         every contact", reached through the scoring vocabulary -- and an
         operator's QSO POINT METHOD line reached it too, although it is a
         statement about points.

         THE BASE READS THE ROW, the same answer the global gave with no
         override stated: True unless the row's point method is
         AlwaysOnePointPerQSO. A contest with a class states it (Internet
         Sprint and the Youth Championship of Russia say False). *)
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

      (* WHICH CONTEST THIS INSTANCE IS -- READABLE BY SUBCLASSES, AND NOT TO BE
         BRANCHED ON.

         It exists for diagnostics and for the few places that legitimately need
         to name the contest in a message. A subclass that reads it to decide
         BEHAVIOUR has reintroduced the thing this class removes: state the
         behaviour as an override, or as a trait on the base. *)
      property Contest: ContestType read FContest;

      (* The station, as it was when this contest object was made or last
         refreshed.  Subclasses read this instead of the globals. *)
      property Station: TStationContext read FStation;
   public
      constructor Create(aContest: ContestType); virtual;

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
      property PrefixMultiplierType: PrefixMultType read GetPrefixMultiplierType;
      property ZoneMultiplierType: ZoneMultType read GetZoneMultiplierType;
      property DXMultiplierType: DXMultType read GetDXMultiplierType;
      property DomesticMultiplierType: DomesticMultType read GetDomesticMultiplierType;
      property InitialExchangeKind: InitialExchangeType read GetInitialExchangeKind;
      property ExchangeKind: ExchangeType read GetExchangeKind;
      property QSOPointMethod: QSOPointMethodType read GetQSOPointMethod;
      property IsUSQSOParty: boolean read GetIsUSQSOParty;

      (* ADIF facts -- see the getters. *)
      property ADIFPowerTag: string read GetADIFPowerTag;
      property WritesADIFContestId: boolean read GetWritesADIFContestId;

      (* Set-up's facts -- see the getters. *)
      property QSOByBand: boolean read GetQSOByBand;
      property QSOByMode: boolean read GetQSOByMode;
      property MultByBand: boolean read GetMultByBand;
      property MultByMode: boolean read GetMultByMode;
      property VHFBandsEnabled: boolean read GetVHFBandsEnabled;
      property CountsDomesticCountries: boolean read GetCountsDomesticCountries;
      property ZoneMode: ZoneModeType read GetZoneMode;
      property InStateDomesticFileName: string read GetInStateDomesticFileName;

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

         THEY DEFAULT TO ContestsArray, WHICH IS WHERE THEY LIVE TODAY -- so
         moving a contest into the factory does not oblige it to restate three
         things that are already correct, and a contest with no class still
         answers. A class overrides when the table is wrong or empty for it.
         That is the strangler again: the table is the current answer, the class
         is the eventual one, and they can disagree only where somebody has
         deliberately made them.

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
         CONTEST_ID at all. General QSO says so through WritesADIFContestId
         (M4); POTA, which has no class, is still a `ceContest <> POTA` test
         in uADIF.EmitADIFRecord until design Q6 is answered. Their ids still
         answer here, because the score-posting clients send them. *)
                  
      (* THE REST OF THE ContestsArray ROW.

         NY4I: "we also have to capture the details from the ContestArray such as
         CABName and ADIFName. All that content would be represented or processed
         in the contest class."

         So every field of the row gets an accessor, not only the three
         identifiers, and every one DEFAULTS TO THE ARRAY. That is what makes the
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
         out pointers into a const table. *)
                                                                              
      (* SCORING -- THE ONE PUBLIC ENTRY POINT (M3, 2026-10-01; design 7.7).

         NY4I: "yes one public entry point". Every caller -- the engine's
         LOGSTUFF.CalculateQSOPoints, and through it live entry, the rescore,
         the editable log and the contest matrix; and the unit tests -- scores
         through this, and gets the order below whether or not it knows it:

           1. QSOPoints := 0;
           2. a band the contest does not use (UsesBand) scores 0 -- NY4I,
              2026-10-01, design 7.4 -- and nothing below is asked;
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

         SO IT IS ONE QUESTION, ASKED AT BOTH PLACES CREDIT IS DECIDED -- both
         through ContestCreditsBand below, so neither can forget the classless
         case:
           points       ScoreQSO (LOGSTUFF.CalculateQSOPoints until M3),
                        BEFORE the four QSO POINTS ... overrides, so an
                        operator's override cannot give an off-band QSO
                        points either;
           multipliers  logdupe's DupeAndMultSheet.SetMultFlags, after it has
                        cleared the four flags, so nothing is set and nothing
                        reaches the multiplier sheet.

         THE BASE ANSWERS TRUE FOR EVERY BAND, which is exactly what every
         contest did before this existed. A contest that states its bands
         overrides; one that has not yet is unchanged, and a classless contest
         is unchanged by construction because ContestCreditsBand answers True
         for nil. Each contest's band rule is its own move. Idaho was first. *)
      function UsesBand(aBand: BandType): boolean; virtual;

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
         whatever the shape parser said.

         THE BASE IS TODAY'S SHARED PARSE FOR THE SESSION'S SHAPE:
         aSession.ParseShape(aSession.Exchange, ...). It names no contest. A
         contest whose rule differs overrides, and calls inherited, or
         aSession.ParseShape with another shape, for what it does not decide
         itself -- RAC takes a VE0 station's serial, PCC chooses between a
         serial and a QTH, a state party refuses an out-of-state station
         working another out-of-state one (NY4I, design 7.10).

         AN OVERRIDE APPLIES ITS RULE UNDER THE SHAPE THAT CARRIED IT. Every
         rule that moved here was a branch inside one shape's parser, reached
         only when the session ran that shape; the override tests
         aSession.Exchange for it and otherwise defers. So with no
         EXCHANGE RECEIVED statement nothing moved; with one, the contest's
         branch no longer follows the operator into a shape it was never
         written for. *)
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
         M5b.

         Asked by ZoneCont.GetVEInitialExchange, the routine behind the
         SECTION and QTH initial exchanges, with the call in standard format
         and its CTY.DAT country, BEFORE its own Canadian-province rule. True
         and aExchange when the contest has an answer; the base has none.
         The Russian DX contests answer a Russian station's oblast. *)
      function InitialExchangeFromCall(const aStandardCall: string;
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

      (* THE CONTEST FORMATS ITS OWN EXPORT -- M4, 2026-10-01.

         EVERY CONTEST IS ASKED. PostUnit and uADIF ask
         uContestRegistry.ContestIdentity, which answers a classless contest
         with a plain TContestBase, so there is no switch deciding WHETHER a
         contest formats its export: it always does, and FormatsExchange --
         the opt-in that stood here from phase F -- is gone.

         THE BASE'S ANSWER IS THE SHARED ARM FOR THE SESSION'S EXCHANGE, and
         only that. uCabrilloExchange.FormatCabrilloExchangeOfKind and
         uADIFExchange.FormatADIFExchangeOfKind hold one arm per exchange SHAPE
         -- what an RST-and-serial or a name-and-QTH line looks like -- and
         NOTHING that names a contest: every `if Contest = ...` that stood
         inside those arms is an override on that contest's class now. A base
         that asked which contest it is would be the defect this factory
         exists to remove. The kind is TCabrilloQSOContext.SessionExchange --
         see that record for why it is the session's and not the trait.

         A CONTEST WITH ITS OWN RULE OVERRIDES, and owns the result whatever
         the session's exchange says -- as the classes that formatted their
         own columns before M4 always did. One that only adjusts an input
         (UK/EI's '--' for an absent QTH) changes the context and calls
         inherited, so the shared arm still lays out the line.

         THE WIDTHS ARE THE CONTRACT. Cabrillo is a column format and these
         strings are what a robot scorer reads, so an override reproduces its
         arm's widths exactly, trailing spaces included. *)
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; virtual;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; virtual;

      (* THE ADIF STX_STRING -- our side of the exchange. aSessionExchange as
         for Cabrillo. The caller has already decided the QSO is a good one;
         an exception is the caller's to report (PostUnit writes the marker
         uADIFExchange.ADIFMyExchangeErrorMarker, as it always did). *)
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; virtual;

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

         A SESSION THAT COUNTS NO MULTIPLIER SCORES ITS POINTS, and so does a
         session whose exchange is the FISTS one (a D7 note: "Ugly fix for
         FISTS because mults don't work ... too long an exchange"). Both were
         the first two tests of LogEdit.TotalScore, ahead of every contest's
         own rule, and they name no contest -- they are the session's answer --
         so they are stated here, once, and no override can skip them.
         Otherwise the contest's CombineWithMultipliers. *)
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

      (* DOES THIS LIVE QSO ADD TO THE SESSION'S RUNNING TALLY?

         A PRESERVED DEFECT, AND THE ONE PLACE A BONUS IS STILL COUNTED AS QSOs
         ARE LOGGED. Missouri's legacy score added one point for each 80 or
         40 m QSO logged between 1400 and 1959 UTC, up to 250 -- but counted
         them only in live entry (LOGSUBS2.LogContact). The log's loader never
         did, so the same log scored the tally while it was being worked and
         lost it on every reopen, /EXPORT's CLAIMED-SCORE included. M6 moved
         that score with ZERO change, so the rule is the contest's here, the
         count is still the engine's (TScoreTotals.LiveSessionTally), and the
         defect is unchanged. Design Q32 asks NY4I whether the sponsor has the
         bonus at all; if it stands, it becomes a rule over the view and this
         seam is deleted.

         The base tallies nothing. *)
      function TalliesLiveQSO(const aQso: ContestExchange): boolean; virtual;

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
         NoQSOPointMethod is a real value in QSOPointMethodType and it means
         exactly this, so a contest that does not score is not a special case. *)
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

(* THE FOUR `QSO POINTS ...` OVERRIDES, APPLIED -- the one statement of their
   rule. True, with aQso.QSOPoints set, when one of them matches this QSO;
   False, with aQso untouched, when none does.

   TWO CALLERS, ONE RULE: TContestBase.ScoreQSO for a contest with a class, and
   LOGSTUFF.CalculateQSOPoints for a classless contest until M10 deletes the
   legacy case. Before M3 the rule was written once, in LOGSTUFF; moving it into
   ScoreQSO as a copy would have been two definitions free to drift.

   First match wins, in the engine's order: domestic CW, DX CW, domestic phone,
   DX phone. "Domestic" is a non-empty DomesticQTH. *)
function ApplyQSOPointOverride(const aOverrides: TQSOPointOverrides;
                               var aQso: ContestExchange): boolean;

(* DOES A LOGGED RECORD COUNT TOWARD THE TOTALS? -- M6, the one statement of
   it. A QSO record, not deleted, with a band and a mode, and not an X-QSO:
   what MainUnit.LoadinLog adds to the sheet and the counters, and so what the
   view a bonus rule reads holds. LoadinLog asks this too, so the totals and
   the view cannot disagree about which QSOs exist. *)
function QSOCountsTowardTotals(const aQso: ContestExchange): boolean;

(* THE MODE A BONUS IS COUNTED IN: FM is phone, as the engine's totals count
   it; every other mode is itself. *)
function BonusModeOf(aMode: ModeType): ModeType;

implementation

uses
   SysUtils,
   (* TC_IMPROPERTRANSMITTERCOUNT -- the one message that is NOT contest
      specific: every class-carrying contest counts transmitters the same way. *)
   uTR4WStrings,
   (* THE SHARED EXCHANGE ARMS the base's export defaults call -- M4. Both
      units name this one in their interface for the record types, so the
      reference back is from the implementation, which Pascal allows. They
      name no contest, and depend on VC, SysUtils and Log4D only. *)
   uCabrilloExchange,
   uADIFExchange,
   (* ResolveSRXString -- the received-exchange half of the ADIF SRX_STRING
      the base's FormatADIFReceivedExchange writes (M5b). The Field Day
      classes already reach uADIF the same way, from their implementation. *)
   uADIF;

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

constructor TContestBase.Create(aContest: ContestType);
begin
   inherited Create;
   FContest := aContest;
end;

procedure TContestBase.SetStation(const aStation: TStationContext);
begin
   FStation := aStation;
end;

function TContestBase.GetDisplayName: string;
begin
   Result := string(ContestTypeSA[FContest]);
end;

function TContestBase.GetCabrilloName: string;
begin
   (* PostUnit's rule, not just the field -- see the note on the declaration. *)
   if Length(ContestsArray[FContest].CABName) = 0 then
      begin
      Result := string(ContestTypeSA[FContest]);
      end
   else
      begin
      Result := ContestsArray[FContest].CABName;
      end;
end;

function TContestBase.GetADIFContestId: string;
begin
   (* THE SAME TWO-STEP AS CabrilloName, and the ONE copy of it -- see the
      note on the declaration. *)
   if Length(ContestsArray[FContest].ADIFName) = 0 then
      begin
      Result := string(ContestTypeSA[FContest]);
      end
   else
      begin
      Result := ContestsArray[FContest].ADIFName;
      end;
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
   Result := ContestsArray[FContest].WA7BNM;
end;

function TContestBase.GetSubmissionEmail: string;
begin
   Result := ContestsArray[FContest].Email;
end;

function TContestBase.GetDomesticFileName: string;
begin
   Result := ContestsArray[FContest].DF;
end;

function TContestBase.GetFriendlyName: string;
begin
   (* Same two-step as CabrilloName: the array's own note says "If blank, use
      ContestTypeSA[ct]". *)
   if Length(ContestsArray[FContest].FriendlyName) = 0 then
      begin
      Result := string(ContestTypeSA[FContest]);
      end
   else
      begin
      Result := ContestsArray[FContest].FriendlyName;
      end;
end;

function TContestBase.GetQRZRUId: integer;
begin
   Result := ContestsArray[FContest].QRZRUID;
end;

function TContestBase.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := ContestsArray[FContest].PxM;
end;

function TContestBase.GetZoneMultiplierType: ZoneMultType;
begin
   Result := ContestsArray[FContest].ZnM;
end;

function TContestBase.GetDXMultiplierType: DXMultType;
begin
   Result := ContestsArray[FContest].XM;
end;

function TContestBase.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := ContestsArray[FContest].DM;
end;

function TContestBase.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ContestsArray[FContest].AIE;
end;

function TContestBase.GetExchangeKind: ExchangeType;
begin
   Result := ContestsArray[FContest].AE;
end;

function TContestBase.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ContestsArray[FContest].QP;
end;

function TContestBase.GetIsUSQSOParty: boolean;
begin
   (* The array calls this P and comments it "US QSO Party"; it is a Byte used
      as a flag. *)
   Result := ContestsArray[FContest].P <> 0;
end;

function TContestBase.GetHostState: string;
begin
   (* Derived from ContestsArray's P index, which is the one place this is
      written down -- see VC.USQSOPartyStateName. *)
   Result := USQSOPartyStateName(FContest);
end;

function TContestBase.GetCabrilloQSOLineFormat: string;
begin
   Result := CabrilloQSOLineFormatDefault;
end;

function TContestBase.RowFlag(aBit: integer): boolean;
begin
   Result := (ContestsBooleanArray[FContest] and (1 shl aBit)) <> 0;
end;

function TContestBase.GetQSOByBand: boolean;
begin
   Result := RowFlag(QSO_BY_BAND_BIT);
end;

function TContestBase.GetQSOByMode: boolean;
begin
   Result := RowFlag(QSO_BY_MODE_BIT);
end;

function TContestBase.GetMultByBand: boolean;
begin
   Result := RowFlag(MULT_BY_BAND_BIT);
end;

function TContestBase.GetMultByMode: boolean;
begin
   Result := RowFlag(MULT_BY_MODE_BIT);
end;

function TContestBase.GetVHFBandsEnabled: boolean;
begin
   Result := RowFlag(VHF_BAND_ENABLE_BIT);
end;

function TContestBase.GetCountsDomesticCountries: boolean;
begin
   Result := RowFlag(CDC_BIT);
end;

function TContestBase.GetZoneMode: ZoneModeType;
begin
   (* See the declaration: the bit set means CQ zones, clear means ITU. *)
   if RowFlag(CQ_ZONE_MODE_BIT) then
      begin
      Result := CQZoneMode;
      end
   else
      begin
      Result := ITUZoneMode;
      end;
end;

function TContestBase.GetInStateDomesticFileName: string;
var
   partyIndex: integer;
begin
   (* The same index USQSOPartyStateName reads, bounded the same way. *)
   Result := '';
   partyIndex := ContestsArray[FContest].P;
   if (partyIndex >= 1) and (partyIndex <= QSOPartiesCount) then
      begin
      Result := QSOParties[partyIndex].InsideStateDOMFile;
      end;
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

function TContestBase.FinalScore(const aTotals: TScoreTotals;
                                 aView: TLoggedQSOView): longint;
begin
   Result := CombineScore(aTotals) + BonusPoints(aTotals, aView);
end;

function TContestBase.CombineScore(const aTotals: TScoreTotals): longint;
begin
   (* LogEdit.TotalScore's first two tests, in their order -- see the
      declaration. *)
   if not aTotals.SessionCountsMultipliers then
      begin
      Result := ContestPoints(aTotals);
      Exit;
      end;

   if aTotals.SessionExchange = RSTQTHNameAndFistsNumberOrPowerExchange then
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

function TContestBase.TalliesLiveQSO(const aQso: ContestExchange): boolean;
begin
   Result := False;
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
   (* The row, as the global read it -- see the declaration. *)
   Result := ContestsArray[FContest].QP <> AlwaysOnePointPerQSO;
end;

function TContestBase.UsesBand(aBand: BandType): boolean;
begin
   (* Every band, as before -- see the declaration. Not a permissive
      placeholder: it is an exact statement of what TR4W did for every contest
      until a contest stated its own bands. *)
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

(* THE SHARED ARM FOR THE SESSION'S EXCHANGE -- see the declaration.

   ONE CALL COMPUTES BOTH COLUMNS and each method keeps its half. The arms
   were written as pairs, and splitting forty of them in two to save a Format
   per QSO would be forty chances to change a byte. Only the sent half reports
   an exchange with no arm, so an unhandled kind is logged once per QSO line,
   not twice. *)
function TContestBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange;
                                                 const aCtx: TCabrilloQSOContext): string;
var
   received: string;
begin
   FormatCabrilloExchangeOfKind(aCtx, aQso, aMy, string(ContestTypeSA[FContest]),
                                True, Result, received);
end;

function TContestBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
var
   sent: string;
begin
   FormatCabrilloExchangeOfKind(aCtx, aQso, aMy, string(ContestTypeSA[FContest]),
                                False, sent, Result);
end;

function TContestBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             aSessionExchange: ExchangeType): string;
begin
   Result := FormatADIFExchangeOfKind(aSessionExchange, aQso, aMy);
end;

function TContestBase.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   (* Nothing beyond the generic QTH uADIF has already written. *)
   Result := '';
end;

procedure TContestBase.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                       const aSession: TADIFImportSession;
                                       var aExch: ContestExchange);
var
   j: integer;
begin
   (* THE CLASSLESS FALLBACK, transcribed from the `else` of
      MainUnit.ApplyContestSpecificADIFTail. The first test is a list of
      session kinds and the last two are the session's multiplier flag, so
      none of it names a contest. *)
   if (aSession.DomesticMult = GridSquares)                 or
      (aSession.Exchange = RSTAndOrGridExchange)            or
      (aSession.Exchange = Grid2Exchange)                   or
      (aSession.Exchange = RSTAndGrid3Exchange)             or
      (aSession.Exchange = GridExchange)                    then
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
begin
   (* The shared parse for the session's shape -- see the declaration. *)
   aErrorMessage := '';
   Result := aSession.ParseShape(aSession.Exchange, aText, aExch);
end;

function TContestBase.MayBeACallsign(const aWord: string): boolean;
begin
   Result := True;
end;

function TContestBase.InitialExchangeFromCall(const aStandardCall: string;
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

end.
