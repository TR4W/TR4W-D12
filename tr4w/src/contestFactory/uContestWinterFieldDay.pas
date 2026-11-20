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

(* WINTER FIELD DAY -- January.

  One point for phone, two for everything else, with FM counted as phone --
  the same rule ARRL Field Day uses THIS YEAR.

  THIS SCORING IS DELIBERATELY NOT SHARED WITH WINTER FIELD DAY, even though
  the two rules are identical today and a base class was written for them and
  then deleted.

  NY4I, 2026-09-02: "I would diverge winter field day and arrl field day. They
  keep diverging with rule changes each year."

  That is an operational argument and it beats the tidiness one. These are two
  contests run by different organisations that revise their rules
  independently, and a shared base makes every future divergence a REFACTOR --
  extract the difference, push it down, re-test both -- at the exact moment
  somebody is trying to make a small change before a contest weekend. Two
  classes that happen to agree cost one duplicated `if` and make next year's
  change a three-line edit to one file that cannot affect the other.

  TR4QT reaches the same conclusion: ARRLFieldDayContest and
  WinterFieldDayContest are separate there too, with no FieldDayBase between
  them, despite scoring identically.

  SO THE DUPLICATION HERE IS INTENDED. It is not an extraction somebody has not
  got round to, and it should not be "fixed" -- the identical code in
  uContestWinterFieldDay is a coincidence of this year's rules, not a shared
  rule.

  WFD ALREADY DIFFERS ELSEWHERE, which is the point: its class letters, its
  bands, its modes and its final score are all its own.

  THE RULES ARE THE SPONSOR'S 2027 RULES, v3 (Winter Field Day Association;
  docs/ContestRules/WinterFieldDay/WFD-2027-Rules-v3.md, reviewed key by key
  2026-11-19):
  - BANDS: "All Amateur bands may be used except 12, 17, 30, and 60 meters"
    (UsesBand; TR4W has no 60 m band).
  - MODES: "All modes, except WSJT modes ... Any mode used must be able to
    fully transmit the exchange intact" -- the WSJT list is "FT2, FST4, FT4,
    FT8, JT4, JT9, JT65, Q65, MSK144, WSPR, FST4W, and Echo". Stated as the
    digital submodes ALLOWED (UsesMode, uContestBase.DigitalSubmodeAllowed;
    NY4I on issue 120: WFD takes the free-form modes, JTTY and JS8Call
    included). FM, C4FM and D-STAR are phone: "If the result is voice, it's
    Phone".
  - POINTS: phone 1, CW and digital 2 (CalculateQSOPoints).
  - SCORE: "Total score = (total QSO points) x (OM+1)", OM being the
    objectives the entrant SELECTS when submitting -- so the log's own
    score is the QSO points (CombineWithMultipliers). *)
unit uContestWinterFieldDay;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestWinterFieldDay = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetSchedule: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;

      (* STATED AT M10 S5, transcribed from the rows the base read until
         then (ContestsArray, QSOParties, ContestsBooleanArray). The
         flags: see TContestBase.GetFlags. *)
      function GetWA7BNMId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      function GetFlags: TContestFlags; override;
      (* THE POINTS -- see the implementation. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* THE FINAL SCORE -- see the implementation. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      (* THE BANDS AND MODES IT CREDITS -- see the implementation, and
         TContestBase.UsesBand / UsesMode (Q98 S1). *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
   public
      function ValidateClass(const aClass: string;
                             out aErrorMessage: string): boolean; override;
      function ValidateDXQTH(const aQTH: string;
                             out aResolved: string;
                             out aErrorMessage: string): boolean; override;

      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;

      (* THE WORKED STATION'S ADIF FIELDS -- see the implementation. *)
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;

      (* A DX STATION'S SRX_STRING IS ITS CLASS AND 'DX' -- M5b, NY4I
         2026-10-02 (design 7.10, Q20), as for ARRL Field Day; this class owns
         its own copy (design 1.4). *)
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   protected
      (* THE CABRILLO HEADER -- M9a. The summary sheet's one-multiplier-per-
         band-and-mode row went with that multiplier (2027 rules, 2026-11-19):
         the base layout. *)
      function GetRequiresCabrilloLocation: boolean; override;
   public
      (* THE CANONICAL RECEIVED EXCHANGE -- see
         TContestBase.CanonicalReceivedExchange (M9a). *)
      function CanonicalReceivedExchange(const aQso: ContestExchange): string; override;
      (* THE CABRILLO HEADER -- M9a.

         THE MODE COLUMN IS THE BASE'S (Q54, NY4I 2026-10-16): FM is a valid
         Cabrillo mode and the WFD rules list it, so an FM contact is written
         `FM`, not `PH`. The override that wrote PH (D7's PostUnit test,
         moved here at M9a) is deleted. Scoring is unchanged -- an FM contact
         still scores as phone in CalculateQSOPoints; that is the points
         rule, not the mode column. *)
      function CabrilloHeaderLinesBeforeTag(const aTagName: string;
                                            const aTagValue: string;
                                            const aStation: TStationContext): string; override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE CTY COUNTRY LIST -- see TContestBase.CountryMode (M11 S4). *)
      function CountryMode: CountryModeType; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   public
      (* WHAT THE EXCHANGE CARRIES -- see TContestBase.ExchangeCarriesDomesticQTH
         and its neighbours (M11 S9d). *)
      function ExchangeCarriesDomesticQTH: boolean; override;
   end;

implementation

uses
   uCabrilloExchange,
   uExchangeFields,
   SysUtils, uTR4WStrings, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's; ADIFSectionStateOf,
      STATE from the worked station's resolved section (issue 266). *)
   uADIF,
   uCanonicalExchange,
   (* WINTER_FIELD_DAY_CLASS_LETTERS -- named once, the Station page reads it too. *)
   uStationFieldCheck;

(* ONE POINT FOR PHONE (FM INCLUDED), TWO OTHERWISE.

   (The DX multiplier this comment described -- DXCC without the ARRL
   sections, M7a -- is gone: Q38, see HasDXMultiplier.) *)
procedure TContestWinterFieldDay.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Mode in [Phone, FM] then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

(* THE QSO POINTS, AND NOTHING ELSE -- the 2027 rules (v3): "Total score =
   (total QSO points) x (OM+1)". OM, the objective multiplier, is the sum of
   the objectives the entrant SELECTS on the sponsor's submission form ("When
   you submit your log, we will ask you to select your completed
   objectives"); most of them (alternative power, away from home, new
   antennas, the SSTV image, a cross-band repeater, Winlink, the bulletin,
   six continuous hours) are not in the log at all, so the log's own score is
   the points with OM 0 -- the "+1 ... for participating".

   UNTIL 2026-11-19 this was D7's formula (LOGEDIT.PAS's Winter Field Day
   arm, moved here at M6): the points times one multiplier per band and mode
   worked, times two for a LOW entry and five for a QRP one. That was an
   earlier year's rule; the 2027 rules have neither a band-mode multiplier
   nor a power factor. *)
function TContestWinterFieldDay.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
begin
   Result := ContestPoints(aTotals);
end;

(* "ALL AMATEUR BANDS MAY BE USED EXCEPT 12, 17, 30, AND 60 METERS" (2027
   rules). TR4W has no 60 m band. Light is credited as every other band
   is: whether TR4W's light band is an amateur band the rule means is not
   settled here (Iowa, under the same wording, leaves it out). AllBands and
   NoBand are not bands a QSO is logged on. *)
function TContestWinterFieldDay.UsesBand(aBand: BandType): boolean;
begin
   Result := (aBand in [Band160..BandLight]) and
             not (aBand in [Band30, Band17, Band12]);
end;

(* "ALL MODES, EXCEPT WSJT MODES, MAY BE USED. Any mode used must be able to
   fully transmit the exchange intact" (2027 rules). The WSJT modes it names
   are FT2, FST4, FT4, FT8, JT4, JT9, JT65, Q65, MSK144, WSPR, FST4W and
   Echo. CW is CW and MCW; FM (with C4FM, D-STAR) is phone, "if the result
   is voice"; the digital group is "PSK, RTTY, Olivia, Packet, SSTV, ATV,
   JS8Call, and all other amateur radio data and image modes" but the WSJT
   ones.

   THE DIGITAL SUBMODES ARE STATED AS THOSE ALLOWED (issue 122's seam): every
   digital submode TR4W can name that is not a WSJT mode -- RTTY (normal and
   reversed), PSK31/63 and reversed PSK, MFSK, JS8 and JTTY. JTTY is WSJT-X
   3.3's free-text keyboard mode: the sponsor's WSJT list does not name it,
   and NY4I ruled on issue 120 that Winter Field Day takes it, as it takes
   JS8Call, because it passes the full exchange. So FT8, FT4, JT65, FST4 and
   FST4W -- and any submode appended later (FT2) until a ruling names it --
   are automatic X-QSOs. *)
function TContestWinterFieldDay.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   case aMode of
      CW, Phone, FM:
         begin
         Result := True;
         end;
      Digital:
         begin
         Result := DigitalSubmodeAllowed(aExtMode,
                      RTTY_SUBMODES + [ePSK31, ePSK63, ePSK_R, eMFSK, eJS8, eJTTY]);
         end;
      else
         begin
         Result := False;
         end;
      end;
end;

(* I, O, H and M -- Indoor, Outdoor, Home and Mobile. A DIFFERENT set from ARRL Field Day, which is the clearest evidence that these two belong in separate classes.

   The COUNT-then-LETTER parsing is TContestBase's -- it is mechanism, and
   identical for any contest with a class. What is this contest's is the
   letter set and the message. *)
function TContestWinterFieldDay.ValidateClass(const aClass: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateCountAndLetterClass(aClass, WINTER_FIELD_DAY_CLASS_LETTERS,
                                         TC_IMPROPERWINTERFIELDDAYCLASS, aErrorMessage);
end;

(* DX, or MX. Winter Field Day accepts MX where ARRL Field Day does not -- the second place these two differ today, after the class letters. *)
function TContestWinterFieldDay.ValidateDXQTH(const aQTH: string;
                          out aResolved: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateDXQTHAllowing(aQTH, 'MX', aResolved, aErrorMessage);
end;

(* THE EXCHANGE IS CLASS AND SECTION, both ways round.

   Widths are the legacy arms' exactly -- '%-3s %-7s' with a TRAILING SPACE on
   the sent side and none on the received. Cabrillo is a column format and a
   width is not cosmetic: a submitted log with the columns a character out is a
   log a robot scorer reads wrongly.

   THE RECEIVED QTH IS THE QSO'S OWN, not the his-QTH the exporter selected.
   The legacy arm said so with an `if Contest in [ARRLFIELDDAY, WINTERFIELDDAY]`
   that overwrote csQTHString just before use (issue 407) -- one more contest
   test, now expressed by simply not using the parameter. That branch was
   DELETED 2026-09-29, and at M4 (2026-10-01) the shared
   ClassDomesticOrDXQTHExchange arm went too: only the two Field Days run this
   exchange, and both format their own (inventory D4). *)
function TContestWinterFieldDay.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s ', [aMy.MyFDClass, aMy.MySection]);
end;

function TContestWinterFieldDay.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                            const aQso: ContestExchange;
                                                            const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [string(aQso.ceClass), string(aQso.QTHString)]);
end;

(* THE WORKED STATION'S ADIF FIELDS -- M4, 2026-10-01: the arm postunit's
   EmitContestSpecificTailForExport kept for ARRLFIELDDAY and WINTERFIELDDAY,
   moved here, and copied into uContestARRLFieldDay (design 1.4: the two Field Days diverge,
   so each owns its copy).

   DX IS NEVER AN ARRL SECTION. NY4I, 2026-10-01: a DX station sends its
   class and 'DX'; that goes in the section POSITION of the Cabrillo line
   (FormatCabrilloReceivedExchange writes QTHString there) but never into
   ADIF ARRL_SECT -- "be explicit about the source and never call DX an ARRL
   section". So a QSO whose QTH is 'DX' writes no ARRL_SECT, no STATE and no
   DXCC.

   IT WRITES ITS CLASS, SINCE M5b. NY4I, 2026-10-02 (design 7.10, Q20):
   "CLASS is whatever was logged (usually 1D); ARRL_SECT is never written for
   DX". The arm wrote no CLASS for a DX station, although one sends a class.

   DXCC 291 and 1 are hard-coded as the arm had them (ny4i): a K section is
   in the US and a VE section in Canada. *)
function TContestWinterFieldDay.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := '';
   if aQso.QTHString = 'DX' then
      begin
      Result := EmitADIFField('CLASS', string(aQso.ceClass));
      Exit;
      end;

   (* STATE is the RESOLVED section's (uADIF.ADIFSectionStateOf, issue 266). *)
   if aQso.QTH.CountryID = 'K' then
      begin
      Result := Result + EmitADIFField('DXCC', ADIFWorkedStationDXCC(aQso));
      Result := Result + EmitADIFField('STATE', ADIFSectionStateOf(aQso));
      end
   else if aQso.QTH.CountryID = 'VE' then
      begin
      Result := Result + EmitADIFField('DXCC', ADIFWorkedStationDXCC(aQso));
      Result := Result + EmitADIFField('STATE', ADIFSectionStateOf(aQso));
      end;
   (* Only a section ADIF's enumeration has (ADIFSectionOf). *)
   Result := Result + EmitADIFField('ARRL_SECT', ADIFSectionOf(aQso));
   Result := Result + EmitADIFField('CLASS', string(aQso.ceClass));
end;

function TContestWinterFieldDay.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                    const aQso: ContestExchange): string;
begin
   Result := Format('%-3s %-7s ', [aMy.MyFDClass, aMy.MySection]);
end;

function TContestWinterFieldDay.GetDisplayName: string;
begin
   Result := 'Winter Field Day';
end;

(* WHEN IT RUNS -- Q99 (docs/CONTEST_SCHEDULES.csv, applied 2026-11-17).
   VERIFIED against the sponsor's rule text (NY4I, 2026-11-17): the 4th full
   weekend of January, Saturday 1600 UTC to Sunday 21:59 UTC. *)
function TContestWinterFieldDay.GetSchedule: string;
begin
   Result := '4th full weekend of January at 16:00 UTC for 30h';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestWinterFieldDay.GetCabrilloName: string;
begin
   Result := 'WFD';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestWinterFieldDay.GetADIFContestId: string;
begin
   Result := 'WFD';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestWinterFieldDay.GetFriendlyName: string;
begin
   Result := 'Winter Field Day';
end;

function TContestWinterFieldDay.GetWA7BNMId: integer;
begin
   Result := 421;
end;

function TContestWinterFieldDay.GetSubmissionEmail: string;
begin
   Result := 'wfda@winterfieldday.com';
end;

function TContestWinterFieldDay.GetDomesticFileName: string;
begin
   Result := 'arrlsect';
end;

function TContestWinterFieldDay.GetExchangeKind: ExchangeType;
begin
   Result := ClassDomesticOrDXQTHExchange;
end;

function TContestWinterFieldDay.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsClassQTH;
end;

function TContestWinterFieldDay.ParseReceivedExchangeFormat(const aText: string;
                                                            aParsers: TExchangeParsers;
                                                            var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseClassDomesticOrDXQTH(aText, aExch);
end;

function TContestWinterFieldDay.ExchangeCarriesDomesticQTH: boolean;
begin
   Result := True;
end;

function TContestWinterFieldDay.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode, cfVHFBandsEnabled];
end;

(* THE SECTION, FROM ARRL_SECT -- BUT AN ABSENT TAG IS NOT AN EMPTY SECTION.
   D7 writes ARRL_SECT for Sweepstakes and does not write it for Winter Field
   Day -- that log carries the section in <QTH> alone. Assigning it
   unconditionally ERASED a section the generic import had already read
   correctly, on 1310 of the 1316 QSOs in the corpus's winter_fd set. So
   ARRL_SECT wins when it is present, because it is the unambiguous field;
   otherwise whatever <QTH> supplied stands, and the domestic multiplier is
   taken from it.

   N1MM WRITES THE CLASS IN APP_N1MM_EXCHANGE1 instead of the standard CLASS
   tag. It is read HERE, after the whole record, so the order the two tags
   arrive in no longer decides anything: the standard CLASS wins when the
   record has it, and N1MM's tag fills in a record that has none. (Until M5a
   whichever tag came LAST won, and the N1MM tag was read only when it came
   after CONTEST_ID.)

   DX IS NOT A SECTION, ON THE WAY IN EITHER -- M5b, design Q25, as for ARRL
   Field Day: a QTH of 'DX', in <QTH> or in another logger's ARRL_SECT, stays
   the QSO's QTH and is never made its domestic QTH -- what the live parse
   does. Until M5b the import alone made it a section.

   A SECTION IS RESOLVED, NOT COPIED (issue 265, 2026-11-10) -- see
   uContestBase.ImportDomesticQTH: an alias ('NY', 'MD') is stored as the
   file's section ('NLi', 'MDC'), as typed entry stores it. *)
procedure TContestWinterFieldDay.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                             const aSession: TADIFImportSession;
                                             var aExch: ContestExchange);
begin
   if UpperCase(Trim(aTemps.ARRL_Sect)) = 'DX' then
      begin
      aExch.QTHString := 'DX';
      end
   else if aTemps.ARRL_Sect <> '' then
      begin
      aExch.QTHString := ShortString(aTemps.ARRL_Sect);
      ImportDomesticQTH(aSession, aTemps.ARRL_Sect, aExch);
      end
   else if UpperCase(Trim(string(aExch.QTHString))) = 'DX' then
      begin
      aExch.QTHString := 'DX';
      end
   else if aExch.QTHString <> '' then
      begin
      ImportDomesticQTH(aSession, string(aExch.QTHString), aExch);
      end;

   if (aExch.ceClass = '') and (aTemps.N1MM_Exchange1 <> '') then
      begin
      aExch.ceClass := ShortString(UpperCase(aTemps.N1MM_Exchange1));
      end;
end;

function TContestWinterFieldDay.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                           aExchangeCarriesRST: boolean): string;
begin
   if aQso.QTHString = 'DX' then
      begin
      Result := Trim(string(aQso.ceClass) + ' DX');
      end
   else
      begin
      Result := inherited FormatADIFReceivedExchange(aQso, aExchangeCarriesRST);
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestWinterFieldDay.DescribeSession(const aStation: TStationContext;
                                                 aSession: TSessionDefaults);
begin
   aSession.WARCEnabled := False;
   aSession.SetCQMemory(CW, smkF1, 'CQ^WFD \ \ TEST');
   aSession.SetCQMemory(CW, smkF2, 'CQ^WFD CQ^WFD \ \ TEST');
   aSession.CQExchangeCW := ' ' + aStation.MyFDClass + ' ' + aStation.MySection;
   aSession.SPExchangeCW := aStation.MyFDClass + ' ' + aStation.MySection;
   aSession.QSLCW := '73 \ WFD';

   (* THE DX MULTIPLIER IS THE CLASS'S -- see HasDXMultiplier and
      DXMultiplierKey (the DX kind is deleted, M11 S4 part 2). It was
      restated here, to overwrite a DX MULTIPLIER line written before the
      CONTEST line; that setting retired at M10 S2, so the restatement went
      at M11 S2 (plan 1.3). *)
   aSession.AddDomesticCountries(DomesticCountriesARRLSections);
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLFIELDDAY.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestWinterFieldDay.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskField(ncfMyFDClass);
   aPrompts.AskField(ncfMySection);
end;

(* THE CABRILLO FILE IS NOT STARTED WITHOUT A LOCATION -- PostUnit's guard,
   which named ARRL 10 and this contest (M9a). The section comes from it. *)
function TContestWinterFieldDay.GetRequiresCabrilloLocation: boolean;
begin
   Result := True;
end;

(* THE SECTION AND THE CLASS, BEFORE THE LOCATION LINE -- PostUnit's
   WINTERFIELDDAY test in the header writer, moved here at M9a: the sponsor's
   robot reads ARRL-SECTION (the location) and X-EXCHANGE (MY FD CLASS). *)
function TContestWinterFieldDay.CabrilloHeaderLinesBeforeTag(const aTagName: string;
                                                             const aTagValue: string;
                                                             const aStation: TStationContext): string;
begin
   Result := '';
   if aTagName = 'LOCATION' then
      begin
      Result := 'ARRL-SECTION: ' + aTagValue + #13#10 +
                'X-EXCHANGE: ' + aStation.MyFDClass + #13#10;
      end;
end;

(* THE CANONICAL RECEIVED EXCHANGE -- uExchangeBuilder's arm for this
   contest, moved here at M9a (2026-10-02): the class and the section (or
   DX). The arm named ARRLFIELDDAY and WINTERFIELDDAY; each holds its own
   copy (design 1.4). See TContestBase.CanonicalReceivedExchange; the
   caller collapses the whitespace. *)
function TContestWinterFieldDay.CanonicalReceivedExchange(const aQso: ContestExchange): string;
begin
   Result := Trim(string(aQso.ceClass)) + ' ' + Trim(string(aQso.QTHString));
end;

(* NO DX MULTIPLIER, AT ANY STATION -- Q38, NY4I 2026-10-15: "Winter FD does
   not count DXCC multipliers or at least it did not in D7." D7 TRACKED them
   -- FCONTEST.PAS:414 set ActiveDXMult := ARRLDXCCWithNoARRLSections, so the
   multiplier sheet and the remaining-multiplier window counted DXCC
   countries -- but never SCORED them: the score is points x band-modes x
   the power factor (CombineWithMultipliers). The ruling removes the tracking
   too, as Field Day has none (Q1). This said True, the trait the class
   stated (`ARRLDXCCWithNoARRLSections`) until the kind was deleted at M11 S4
   part 2; its DXMultiplierKey (every country but the ARRL section ones) went
   with it, so the base answers "no key". No score moves; the multiplier
   displays do. *)
function TContestWinterFieldDay.HasDXMultiplier: boolean;
begin
   Result := False;
end;

(* THE CTY COUNTRY LIST -- M11 S4, 2026-10-14, moved from uSettingsEffects.
   DXCC only, at every station. *)
function TContestWinterFieldDay.CountryMode: CountryModeType;
begin
   Result := ARRLCountryMode;
end;


(* THE DOMESTIC QTH IS LOOKED UP IN THIS CONTEST'S DOMESTIC FILE, at every
   station -- M11 S6 part 1b, 2026-10-14. It was the session's
   `= DomesticFile` (the trait); see TContestBase.UsesDomesticFile. *)
function TContestWinterFieldDay.UsesDomesticFile: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(WINTERFIELDDAY, TContestWinterFieldDay);

end.
