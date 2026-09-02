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
   VC;

type
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

         MyZone is a STRING global, and the scoring arms that want it all do
         `Val(MyZone, MyZoneValue, Result)` and then compare. Doing that per QSO
         in every contest that scores by zone is the sort of repetition that
         eventually disagrees with itself -- and a Val whose error code nobody
         reads is a 0 that looks like zone 0.

         MyZoneValid says whether the conversion worked, so a contest can tell
         "zone 0" from "no zone set" instead of scoring against a silent 0. *)
      MyZone: integer;
      MyZoneValid: boolean;
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

   TContestBase = class
   private
      FContest: ContestType;
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
      function GetFormatsExchange: boolean; virtual;
      function GetCountyLineAllowed: boolean; virtual;

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
      property FormatsExchange: boolean read GetFormatsExchange;
      property CountyLineAllowed: boolean read GetCountyLineAllowed;

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

         THE CABRILLO FALLBACK IS REPRODUCED EXACTLY. PostUnit uses the enum's
         own spelling when CABName is empty, which is most contests -- so the
         default here is that same two-step, not just the field. Returning ''
         for the 150-odd contests with no CABName would put an empty CONTEST:
         line in their headers.

         ADIF IS THE OTHER WAY ROUND AND IS LEFT THAT WAY: an empty ADIFName
         means the contest has no ADIF CONTEST_ID, which is a real answer --
         GetContestByADIFName matches on it -- so this returns '' rather than
         inventing one from the enum. *)
                  
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
                                                                              
      (* SCORING. Sets aQso.QSOPoints, and nothing else -- multipliers and dupe
         state are decided elsewhere and a scorer that changed them would make
         the order of the two calls significant.

         The base scores nothing. That is deliberate rather than a placeholder:
         NoQSOPointMethod is a real value in QSOPointMethodType and it means
         exactly this, so a contest that does not score is not a special case. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); virtual;

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
         case. A contest with a class overrides.

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
         to state -- and, as with ValidateClass, nothing reaches it: only the
         two Field Days use this exchange type. *)
      function ValidateDXQTH(const aQTH: string;
                             out aResolved: string;
                             out aErrorMessage: string): boolean; virtual;

      (* DOES THIS CONTEST FORMAT ITS OWN EXCHANGE COLUMNS?

         False by default, so a contest that has only had its SCORING moved does
         not silently take over its Cabrillo and ADIF output as well. Each
         responsibility arrives when it is actually lifted, and the ones that
         have not are still the legacy case's. *)
      
      (* THE TWO CABRILLO EXCHANGE COLUMNS, and the ADIF sent exchange.

         aHisQTH is the his-QTH PostUnit has already selected (DoingDomesticMults
         / LiteralDomesticQTH / ...), passed in rather than recomputed, because
         choosing it is the exporter's job and formatting it is the contest's.

         Only called when FormatsExchange is True. *)
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange): string; virtual;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aHisQTH: string): string; virtual;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange): string; virtual;

      (* Hands the contest the station it is operating as.

         PUSHED IN, NOT READ. An earlier version had the base reach into LOGWIND
         for MyCountry, which put the display layer in the dependency graph of
         every contest class -- and, worse, of anything that wanted to ASK a
         contest something. uCabrilloExchange and uADIFExchange are
         dependency-light on purpose and have unit tests that would then have
         needed the program's globals booted.

         So the direction is inverted: uContestFactory reads the globals and
         hands the result down. A contest class now depends on VC, SysUtils and
         the string constants, which means a test can construct one and ask it
         to score a QSO without starting TR4W.

         SET BEFORE EVERY SCORE rather than once at construction: MyCountry is
         recomputed whenever MY CALL changes -- from the config, from the log's
         stored settings, from the operator editing it mid-contest -- and a
         contest holding the startup value would score the rest of the log
         against a station that has moved. *)
      procedure SetStation(const aStation: TStationContext);
   protected
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

implementation

uses
   SysUtils,
   (* TC_IMPROPERTRANSMITTERCOUNT -- the one message that is NOT contest
      specific: every class-carrying contest counts transmitters the same way. *)
   uTR4WStrings;

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
      Result := string(ContestsArray[FContest].CABName);
      end;
end;

function TContestBase.GetADIFContestId: string;
begin
   Result := string(ContestsArray[FContest].ADIFName);
end;

function TContestBase.GetWA7BNMId: integer;
begin
   Result := ContestsArray[FContest].WA7BNM;
end;

function TContestBase.GetSubmissionEmail: string;
begin
   Result := string(ContestsArray[FContest].Email);
end;

function TContestBase.GetDomesticFileName: string;
begin
   Result := string(ContestsArray[FContest].DF);
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
      Result := string(ContestsArray[FContest].FriendlyName);
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

function TContestBase.GetCountyLineAllowed: boolean;
begin
   Result := ContestsArray[FContest].CountyLineAllowed;
end;

procedure TContestBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 0;
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

function TContestBase.GetFormatsExchange: boolean;
begin
   Result := False;
end;

function TContestBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := '';
end;

function TContestBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aHisQTH: string): string;
begin
   Result := '';
end;

function TContestBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
begin
   Result := '';
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
