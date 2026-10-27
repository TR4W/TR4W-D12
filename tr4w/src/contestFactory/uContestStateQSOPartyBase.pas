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

(* SINGLE-STATE QSO PARTIES -- A MECHANISM BASE, AND A DELIBERATELY THIN ONE.

  NY4I, 2026-09-28: "qso parties should be the same base class in there somehow
  as they have many similarities".

  THE NAME CARRIES THE RULE, AND IT IS NOT AN ACCIDENT THAT IT IS LONG. This was
  TContestQSOPartyBase for about an hour, until NY4I ruled on NAQP: "NAQP is not
  really in the same league as a state qso party so no need to derive that from
  the base qso party." He is right, and a class called "QSO party base" would
  have invited exactly that derivation -- reasonably, because the name said so.
  A name that states the boundary is the cheapest guard available.

  WHICH KIND OF BASE THIS IS DECIDES WHAT MAY GO IN IT. ADDING_A_CONTEST.md
  draws the line: a FAMILY base (TContestARRLDXBase) is two runnings of ONE
  contest, where a rule change reaches both by definition. This is the other
  kind -- a shared MECHANISM across contests run by
  different people, and there are of the order of twenty sponsors involved. NY4I
  has already ruled on what that implies, about the two Field Days: "They keep
  diverging with rule changes each year."

  SO THE TEST FOR MEMBERSHIP IS NOT "DO FLORIDA AND MICHIGAN BOTH DO THIS". It
  is "could a sponsor change this next year without it being a different kind of
  contest". Almost everything two state parties appear to share fails that test,
  which is why this class is two members long.

  ---------------------------------------------------------------------------
  WHO BELONGS HERE

  THE SINGLE-STATE PARTIES WITH COUNTY MULTIPLIERS. Thirteen carried
  CountyLineAllowed: True in ContestsArray when this was written (fifteen by
  M10 S8, which deleted the table and kept that set as
  SplitsRoverCallOnExport), and a handful more are single-state with no flag
  set at all (Arizona, British Columbia, New York, Virginia) -- whose correct
  value is simply unknown rather than False. (The rover split is no longer
  that set: since Q90/Q94, 2026-10-14, every party here splits and strips.)

  NOT THE LOCUST QSO PARTY, which this list named until M3 (2026-10-01). It is
  a QSO party by name only: K6VVA's event, P 0 in its row, no host state and no
  counties. It is uContestLocustQP, directly on TContestBase.

  NOT NAQP (CW / SSB / RTTY). It is a QSO party by NAME only: its exchange is a
  name plus a state, province or country, its multipliers are not counties, and
  it has neither an in-state/out-of-state axis nor any county-line concept.
  Nothing this class holds would apply to it. That is a recorded decision, not
  an omission -- see the quotation above.

  NOT THE MULTI-STATE PARTIES, AND THAT ONE IS OPEN RATHER THAN SETTLED. 7QP,
  the New England QSO Party and the combined Indiana / 7th-area / New England /
  Delaware entry DO have county multipliers, so they are much closer to this
  base than NAQP is -- but MainUnit.pas already records why they are held apart:
  the CountyLineAllowed flag "is set to True only for the 13 single-state QSO
  parties (VC.pas). Multi-state QPs (7QP / NEQP / etc.) are deliberately not
  flagged -- they need their own per-state county-line handling, tracked
  separately."

  They are left out because designing for one speculatively is how a mechanism
  base becomes a family base with flags in it. A multi-state party should arrive
  and prove whether it fits.

  M7b (2026-10-02): 7QP and NEQP ARRIVED, AND DID NOT FIT. Each is its own
  class on TContestBase (uContestSevenQP, uContestNewEnglandQP): this base's
  out-of-state refusal and county-line rule assume ONE host state, and neither
  contest has ever been held to them. 7QP's row still makes set-up run the
  party head for it (its IsUSQSOParty), which is what it always did. Whether
  the multi-state parties want a base of their own is a design question in
  docs/CONTEST_OWNERSHIP_DESIGN.md (Q40).

  ---------------------------------------------------------------------------
  WHAT WAS MEASURED, FLORIDA AGAINST MICHIGAN, BEFORE WRITING THIS

    SHARED, AND IDENTICAL IN MECHANISM
      the P index in ContestsArray, giving a host state and a domestic file
      in-state versus out-of-state (FCONTEST.FoundMyStateInDomFile), which
        selects <state>.dom or <state>_cty.dom and sets MultipliersIsCounties
      county-line operation: a contact on a boundary is N separate QSOs
      Add_KVEKH6KL -- K, VE, KH6 and KL count as domestic countries
      TotalScore: points times mults, with no QSO-party arm at all

    NOT SHARED, THOUGH IT LOOKS IT
      THE EXCHANGE. Florida is RSTDomesticOrDXQTHExchange and Michigan is
        RSTDomesticQTHExchange -- different parsers, and the difference is real:
        Florida accepts a DX station's free-text QTH and Michigan does not.
      DX MULTIPLIERS. Florida counts DXCC outside the USA and Canada; Michigan
        counts none.
      QSO POINTS. Both are OnePhoneTwoCW, and that is a coincidence of two
        sponsors: California is three points flat, Texas is TwoPhoneThreeCW and
        North Carolina has a method of its own. Points stay in the class.
      THE CABRILLO RECEIVED COLUMN. Florida identifies a DX station by its DXCC
        PREFIX where every other contest on that arm uses the DXQTH text.
      THE COUNTY LINE ITSELF. Florida allows two counties; Michigan forbids
        simultaneous operation in more than one. Opposite ends of one axis --
        which is why the axis is on the base and the number is in the class.

  ONLY THE FIRST GROUP COULD HAVE COME IN HERE, AND MOST OF IT STILL DID NOT,
  because it is not a RULE a contest object answers -- FoundMyStateInDomFile
  reads a file, Add_KVEKH6KL mutates a global table, and both belong to FCONTEST
  until the setup migration (ADDING_A_CONTEST.md section 6.4). Putting a
  file-reading step behind a contest accessor would make a class that cannot be
  constructed in a test, which is the one property uContestBase was careful to
  buy.

  WHAT IS LEFT IS THE PART THAT IS PURE FACT: which state, and whether a county
  line may be claimed.

  COUNTY LINES ARE NOT A COLLECTION, AND THE DESIGN SURVIVED THE TEST. Florida's
  rules say a county-line contact "may be claimed as a separate QSO and
  multiplier from each county" -- so it is N log entries, not one entry with N
  keys, and TR4W already writes it that way: one row per county sharing the
  transmitted serial number, with ceClearDupeSheet set on the follow-ups so the
  generic dupe check does not blank them. The application owns that queue
  (LOGSTUFF.ApplyFirstQTHAndQueueRest and MainUnit.DrainPendingMultiQSORefs);
  the contest states only HOW MANY counties are legal. Nothing here is ever
  handed a list. *)
unit uContestStateQSOPartyBase;

{$I tr4w.inc}

interface

uses
   VC,
   (* TLogLogger -- ReportNoTableForYear writes to its caller's logger. *)
   Log4D,
   uContestBase;

const
   (* NO LIMIT IS ENFORCED ANYWHERE IN TR4W TODAY -- measured, not assumed:
      LOGSTUFF.ApplyFirstQTHAndQueueRest pushes EVERY valid county after the
      first onto uPendingCounties and MainUnit.DrainPendingMultiQSORefs writes
      one QSO for each. Nothing counts them, so "two versus four" is a
      behaviour this program does not have.

      This value is what a QSO party means when it permits county-line
      operation without stating a limit, which is every party until somebody
      characterises one.

      IT LIVES HERE AND NOT ON TContestBase (moved 2026-09-29). It is only
      meaningful to a contest that HAS counties, and a constant reachable from
      the root invites the same mistake the accessors did. *)
   CountyLineCountiesUnlimited = High(integer);

type
   TContestStateQSOPartyBase = class(TContestBase)
   private
      (* ReportNoTableForYear's latch: has this object reported, and for
         which year. One latch per object -- every party that reports has
         ONE year table. Main thread only, as the score is. *)
      FReportedNoTableForYear: boolean;
      FReportedNoTableYear: integer;
   protected
      (* IT IS ONE, AND THE CLASS SAYS SO RATHER THAN THE TABLE SAYING SO.

         The inherited answer read ContestsArray[c].P <> 0 until M10 S6, and P
         was an INDEX into QSOParties -- so "is this a QSO party" was answered
         by a file-name lookup table being non-empty (both tables are deleted,
         M10 S8; the base answers False). A class in this hierarchy IS
         one by construction, which is the whole point of there being a
         hierarchy. *)
      function GetIsUSQSOParty: boolean; override;

      (* EVERY STATE PARTY MUST NAME ITS STATE, AND ABSTRACT IS WHAT ENFORCES
         IT.

         The inherited getter derives the answer from the P index, so a state
         party that forgot to state its state would still get one -- until
         somebody added a contest whose row had not been filled in, at which
         point it would answer '' and the ADIF exporter would quietly emit no
         STATE field. A silently-defaulted accessor reading as a legal empty
         string is CLAUDE.md note 9 exactly.

         Abstract turns that into a compile error instead: a state party that
         does not override this cannot be instantiated. *)
      function GetHostState: string; override; abstract;

      (* THE AREA THE NEW CONTEST PROMPT NAMES IS THE HOST STATE -- M10 S5.

         A FAMILY RULE, not a coincidence: a single-state party's area is its
         state by definition, so stating it a second time in each class would
         be two statements of one fact, free to disagree. British Columbia,
         whose host is not a two-letter state, states its own. *)
      function GetQSOPartyArea: string; override;

      (* THE COUNTY-LINE RULE, AS A COUNT -- AND THE BOOLEAN DERIVED FROM IT.

         IT MOVED HERE FROM TContestBase ON 2026-09-29. NY4I: "Arktika Spring
         is clearly not a qso party so I am not sure why that would be in the
         conversation of two counties", and "Generally qso parties will have
         QSO PARTY or QP in their name (NAQP an exception)." On the root, every
         contest in the program answered a county-line question and three
         classes had written an answer down; two of them have no counties.

         NY4I, 2026-09-28, on the shape itself: "some qso parties allow county
         line operation where you can claim multiple counties and some do not
         so that is a good item to keep in mind too. Some allow 2 counties,
         some like california qso party allow a junction of 4 counties."

         A BOOLEAN CANNOT SAY THAT. Three answers exist -- none, two, and
         California's four-county junction -- and a flag expresses only the
         first distinction, so the wrong answer reads as a legal one. That is
         CLAUDE.md note 9 with a different noun.

         ONE VALUE, TWO READINGS. The count is the stored rule; the boolean is
         computed from it, on NY4I's own sketch ("CountyLineAllowed could be a
         property that returns a boolean where the accessor states return
         FCountyLineCountiesAllowed > 0"). A site that only cares WHETHER reads
         better asking CountyLineAllowed; a site that needs the limit asks for
         the number. Nothing is stored twice, so the two cannot disagree.

         AND THE BOOLEAN IS DELIBERATELY NOT VIRTUAL. If both were virtual a
         descendant could override the boolean to True while the count still
         answered 0, and the two would contradict each other silently. Leaving
         it non-virtual makes the contradiction unrepresentable rather than
         merely discouraged -- so this is a decision, not a missing keyword. *)
      function GetCountyLineCountiesMax: integer; virtual;
      function GetCountyLineAllowed: boolean;

      (* A DX ENTRANT SENDS ITS OWN COUNTRY -- a HELPER a party CALLS, never a
         rule this base applies. Lifted 2026-10-26 from the North Dakota QSO
         Party when the Oklahoma QSO Party became its second user (the rule
         "do not duplicate code": copies drift).

         Some sponsors have a DX station send its DXCC prefix ("DX Stations
         give RST and DX country" -- North Dakota; "DX stations ... send
         signal report and DXCC prefix" -- Oklahoma); others have it send the
         letters DX (Georgia: the StateOrDX export helpers). Which one is
         each sponsor's rule, so nothing here is asked unless a class asks:
         a party whose DX entrant sends "DX" never calls these, and that is
         why they are not virtual and not wired into an export.

         THE ONE STATEMENT: a station that states a location (MY STATE, the
         state the session SENDS -- design 7.11/7.12: an in-state station's
         county, anyone else's state or province) sends it AS STATED; one
         that states none -- a DX entrant -- sends its own country, the
         country FCONTEST derives from MY CALL (Settings.My.Country, which
         CurrentStation hands every contest object as MyCountry).

         LocationOrOwnCountry is the rule over plain values, so the CQ
         exchange (which is handed its station) and the exports (which ask
         the object's Station) say it once. SentLocation is the export form:
         the sent exchange with MY STATE filled in, handed to the column
         helpers unchanged, so the column format stays theirs. Pinned by
         uTestContestStateQSOPartyBase. *)
      class function LocationOrOwnCountry(const aLocation: string;
                                          const aCountry: CallString): string;
      function SentLocation(const aMy: TMyStationExchange): TMyStationExchange;

      (* A RULE THAT CHANGES BY YEAR, ASKED FOR A YEAR IT HAS NO TABLE FOR,
         SAYS SO -- a HELPER a party CALLS, never a rule this base applies.
         Lifted 2026-10-26 from the Idaho QSO Party (its dormant-county
         table, Q35) and the Nebraska QSO Party (its rare-grid list), which
         carried the same latch word for word, when the New Mexico QSO Party
         (its W1AW/5 bonus, "for 2026 only") became the third user.

         THE YEAR IS THE CALLER'S: uContestBase.LogContestYear, the log's
         year and never the clock. This only REPORTS: the caller pays
         nothing for such a year, because there is no table to pay from.

         ONE Error per year per object, however often the score is asked
         (it is asked after every QSO); a different year reports again.
         AN ERROR, NOT A WARNING: Log4D's root level defaults to Error, so a
         Warn would not reach tr4w.log on a default station, and a claimed
         score that leaves out a bonus is worth an operator's attention.
         Written to aLogger -- the caller's unit logger, so the line names
         the contest's unit as it always did.

         Year 0 is a log that says nothing about its year (no start time and
         no dated QSO). aTable names the table ("dormant-county bonus
         table"), aRule what is left out ("the dormant-county bonus for
         BUT"), aSource where each year's table comes from. Pinned by
         uTestContestStateQSOPartyBase. *)
      procedure ReportNoTableForYear(aLogger: TLogLogger;
                                     aYear: integer;
                                     const aTable: string;
                                     const aRule: string;
                                     const aSource: string);
   public
      property CountyLineCountiesMax: integer read GetCountyLineCountiesMax;
      property CountyLineAllowed: boolean read GetCountyLineAllowed;

      (* A /SUFFIX IS A ROVER'S COUNTY IN EVERY STATE PARTY -- stripped live
         AND split on ADIF export. NY4I's ruling on Q94 with Q90,
         2026-10-14: "yes QSO parties allow it but in any contest NY4I/7 or
         VP9/NY4I is a valid call." See TContestBase.StripsRoverCountyFromCall
         and SplitsRoverCallOnExport.

         STATED ONCE, HERE, because the ruling is about what a state QSO
         party IS, not about one sponsor's rules. Before it the two answers
         were per-class transcriptions that disagreed: California, Colorado,
         Minnesota, Ohio and Pennsylvania split but did not strip; Arizona,
         British Columbia, the Salmon Run and New York stripped but did not
         split; Virginia did neither. Every party now does both.

         A ROVER IS STILL NOT A COUNTY LINE (plan S7): CountyLineAllowed,
         which the import's dupe bypass asks, is unchanged and derives from
         nothing here. Pinned by uTestExchangeRules and
         Test_EveryQSOPartySplitsARoverCallOnExport. *)
      function StripsRoverCountyFromCall: boolean; override;
      function SplitsRoverCallOnExport: boolean; override;

      (* A NEW QSO PER COUNTY RECEIVED, IN EVERY STATE PARTY -- Q118. NY4I,
         2026-10-17: "New QSO per county" (for NYQP), then "All state
         parties". The same call on the same band and mode is a new QSO when
         the QTH it sent differs -- a mobile signing its bare call that has
         moved county. Every one of these parties' DXLog definitions says
         DOUBLE_QSO=PER_BAND_MODE_RCVD, or _RECINFO (California, Pennsylvania,
         Virginia, whose QTH follows a serial). STATED ONCE, HERE, for the
         same reason the rover answers above are. The multi-state parties
         (7QP, New England, IN7QPNE) are not on this base and do not answer
         it. See TContestBase.DupeKeyIncludesReceivedQTH. *)
      function DupeKeyIncludesReceivedQTH: boolean; override;

      (* THE WORKED STATION'S ADIF STATE, AND ITS COUNTY AS CNTY -- Q76/Q89
         (NY4I, 2026-10-16). See TContestBase.ADIFCountyState,
         ADIFWorkedStationState and WritesADIFCounty. STATED ONCE, HERE: a
         QTH key that is not two letters is one of this party's counties,
         so the worked station is in the host (HostState -- 'BC' for British
         Columbia, which wrote no STATE until Q89); anything else is judged
         by uADIF.ADIFStateOfPartyQSO. British Columbia overrides
         WritesADIFCounty -- ADIF has no Canadian county enumeration. *)
      function ADIFCountyState(const aQso: ContestExchange): string; override;
      function ADIFWorkedStationState(const aQso: ContestExchange): string; override;
      function WritesADIFCounty: boolean; override;

      (* THE ONLY OVERRIDE OF THE BASE'S VALIDATOR IN THIS TREE.

         TContestBase.ValidateQTHCount always passes, because TR4W has never
         counted QTHs for any contest. A state QSO party is the one kind of
         contest for which a number exists in a rulebook, so it is the one kind
         that may refuse.

         SEMANTICS UNCHANGED FROM THE VERSION THAT LIVED ON THE ROOT: one QTH
         always passes (zero means "no county LINE", not "no county" -- every
         domestic exchange names one), CountyLineCountiesUnlimited accepts any
         number, and a stated maximum refuses more with TC_TOOMANYCOUNTIES.

         A COUNTY-LINE CONTACT IS N SEPARATE QSOs, NOT ONE QSO WITH N KEYS.
         Florida's rules: "Florida stations on a county line (maximum of two
         counties) may be claimed as a separate QSO and multiplier from each
         county." TR4W already writes it that way -- one row per county sharing
         the transmitted serial number, with ceClearDupeSheet set on the
         follow-ups so the generic dupe check does not blank them. *)
      function ValidateQTHCount(aCount: integer;
                                out aErrorMessage: string): boolean; override;

      (* AN OUT-OF-STATE STATION WORKS ONLY THE HOST STATE -- M5b, NY4I's
         ruling of 2026-10-02 (design 7.10):

           "In QSO parties, out of state stations usually only log the state
           county. It's not valid for a fl station to work an Idaho or VE
           station in the NC QSO party." In-state stations work everyone.
           "It's an invalid station so we should refuse to log it and show an
           error like we would with an invalid county."

         THE DEFAULT FOR EVERY SINGLE-STATE PARTY, so it is here; a party
         whose sponsor rules otherwise overrides. None does today -- every
         class's header was read for an exception and none states one.

         WHO IS OUT OF STATE: Station.InHostState, the answer set-up took
         when it chose which domestic file to load. WHO IS HOST STATE: a
         station whose received QTH the session's domestic table knows
         (aSession.IsDomesticQTH) -- for an out-of-state station that table
         is the host's COUNTY file, which holds the host's counties and
         nothing else (Test_EveryPartyCountyFileHoldsOnlyCounties holds that;
         NC's file held the states and provinces until M5b). So an exchange
         the shape accepted whose QTH is not a host county is the DX branch of
         a DomesticOrDX shape -- a station outside the host state -- and is
         refused. A county the shape parser itself refused is refused as it
         always was, with its own message.

         ASKED OF THE TABLE, NOT READ OFF DomesticQTH. The DX branch never
         writes DomesticQTH, so a value left in the record by an earlier
         attempt would read as a host county. And the table's own
         placeholder, 'XXX' -- a QTH not yet copied -- is accepted by the
         table as before: it says nothing about where the station is.

         THE TEST IS uContestBase.HostAreaRuleCredits, and since Q107 it is
         asked of a LOGGED QSO too -- CreditsWorkedStation below. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;

      (* AND A LOGGED QSO IS HELD TO THE SAME RULE -- Q107 (NY4I,
         2026-10-16). An out-of-state entrant's QSO whose received QTH the
         session's table does not know (not a host county) is logged, scores
         0 and earns no multiplier, however it arrived: an ADIF import, a
         network peer, a rescore. The SAME predicate as the refusal above
         (HostAreaRuleCredits), the same QTH text (the record's QTHString)
         and the same table (Station.IsDomesticQTH is the engine function
         the typed session carries), so a QSO refused when typed is exactly
         a QSO that scores 0 when logged another way. Stated ONCE, here,
         for every single-state party. See TContestBase.CreditsWorkedStation. *)
      function CreditsWorkedStation(const aQso: ContestExchange): boolean; override;
   public
      (* THE DOMESTIC FILE -- see TContestBase.UsesDomesticFile (M11 S6). *)
      function UsesDomesticFile: boolean; override;
   end;

implementation

uses
   SysUtils,        (* Format *)
   uTR4WStrings,    (* TC_TOOMANYCOUNTIES *)
   uAppStrings,     (* SExchangeOutOfStateWorksHostOnly *)
   uADIF;           (* ADIFPartyQTHKey, ADIFStateOfPartyQSO -- Q76/Q89 *)

function TContestStateQSOPartyBase.ParseReceivedExchange(const aText: string;
                                                         const aSession: TReceivedExchangeSession;
                                                         var aExch: ContestExchange;
                                                         out aErrorMessage: string): boolean;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if not Result then
      begin
      Exit;
      end;

   if not HostAreaRuleCredits(Station.InHostState,
                              string(aExch.QTHString),
                              aSession.IsDomesticQTH) then
      begin
      Result := False;
      aErrorMessage := Format(SExchangeOutOfStateWorksHostOnly, [HostState]);
      end;
end;

function TContestStateQSOPartyBase.CreditsWorkedStation(const aQso: ContestExchange): boolean;
begin
   (* The refusal's predicate, on the record -- see the declaration. *)
   Result := HostAreaRuleCredits(Station.InHostState,
                                 string(aQso.QTHString),
                                 Station.IsDomesticQTH);
end;

function TContestStateQSOPartyBase.GetIsUSQSOParty: boolean;
begin
   Result := True;
end;

function TContestStateQSOPartyBase.GetQSOPartyArea: string;
begin
   Result := HostState;
end;

function TContestStateQSOPartyBase.GetCountyLineCountiesMax: integer;
begin
   (* UNLIMITED, UNCONDITIONALLY -- AND DELIBERATELY NOT READ FROM
      ContestsArray[c].CountyLineAllowed.

      That field is a BOOLEAN and carries no limit, so the best it could say is
      "allowed, number unknown" -- which is this value -- while its False arm
      would say zero, and zero REFUSES a second QTH. Eleven of the thirteen
      flagged parties have no published number in this tree, and a party
      wrongly capped would reject a valid junction in the middle of a contest,
      failing only for the operator who is right.

      Unlimited is also what the program actually does: nothing counts the
      queued counties. So this describes TR4W today, and a party that KNOWS its
      number overrides -- Florida with two, Michigan with none, both quoting
      their sponsors. *)
   Result := CountyLineCountiesUnlimited;
end;

function TContestStateQSOPartyBase.GetCountyLineAllowed: boolean;
begin
   Result := GetCountyLineCountiesMax > 0;
end;

(* The stated location as stated; the own country when none is stated -- see
   the declaration. *)
class function TContestStateQSOPartyBase.LocationOrOwnCountry(const aLocation: string;
                                                              const aCountry: CallString): string;
begin
   if Trim(aLocation) = '' then
      begin
      Result := string(aCountry);
      end
   else
      begin
      Result := aLocation;
      end;
end;

function TContestStateQSOPartyBase.SentLocation(const aMy: TMyStationExchange): TMyStationExchange;
begin
   Result := aMy;
   Result.MyState := LocationOrOwnCountry(aMy.MyState, Station.MyCountry);
end;

(* Once per year per object -- see the declaration. *)
procedure TContestStateQSOPartyBase.ReportNoTableForYear(aLogger: TLogLogger;
                                                         aYear: integer;
                                                         const aTable: string;
                                                         const aRule: string;
                                                         const aSource: string);
begin
   if FReportedNoTableForYear and
      (FReportedNoTableYear = aYear) then
      begin
      Exit;
      end;
   FReportedNoTableForYear := True;
   FReportedNoTableYear := aYear;

   if aYear = 0 then
      begin
      aLogger.Error(UnicodeFormat(
         '%s: the log records no contest year (no start time and no dated QSO), ' +
         'so %s cannot be decided and is NOT in the score.',
         [DisplayName, aRule]));
      end
   else
      begin
      aLogger.Error(UnicodeFormat(
         '%s: TR4W has no %s for the %d contest, so %s is NOT in the score. ' +
         'Each year''s %s is the sponsor''s (%s) and is added to %s.',
         [DisplayName, aTable, aYear, aRule, aTable, aSource, string(UnitName)]));
      end;
end;

function TContestStateQSOPartyBase.StripsRoverCountyFromCall: boolean;
begin
   (* Every state party -- see the declaration (Q94, 2026-10-14). *)
   Result := True;
end;

function TContestStateQSOPartyBase.SplitsRoverCallOnExport: boolean;
begin
   (* Every state party -- see the declaration (Q90, 2026-10-14). *)
   Result := True;
end;

function TContestStateQSOPartyBase.DupeKeyIncludesReceivedQTH: boolean;
begin
   (* Every state party -- see the declaration (Q118, 2026-10-17). *)
   Result := True;
end;

function TContestStateQSOPartyBase.ADIFCountyState(const aQso: ContestExchange): string;
var
   key: string;
begin
   (* A key that is not two letters is a county of this party -- see the
      declaration (Q76/Q89, 2026-10-16). *)
   key := ADIFPartyQTHKey(aQso);
   if (key <> '') and (Length(key) <> 2) then
      begin
      Result := HostState;
      end
   else
      begin
      Result := '';
      end;
end;

function TContestStateQSOPartyBase.ADIFWorkedStationState(const aQso: ContestExchange): string;
begin
   Result := ADIFStateOfPartyQSO(ADIFCountyState(aQso), aQso);
end;

function TContestStateQSOPartyBase.WritesADIFCounty: boolean;
begin
   (* Every US state party -- see the declaration (Q89, 2026-10-16). *)
   Result := True;
end;

function TContestStateQSOPartyBase.ValidateQTHCount(aCount: integer;
                                        out aErrorMessage: string): boolean;
var
   maxCounties: integer;
begin
   aErrorMessage := '';
   maxCounties := GetCountyLineCountiesMax;

   if maxCounties = CountyLineCountiesUnlimited then
      begin
      Result := True;
      Exit;
      end;

   Result := (aCount <= 1) or (aCount <= maxCounties);

   if not Result then
      begin
      aErrorMessage := Format(TC_TOOMANYCOUNTIES, [maxCounties]);
      end;
end;


(* EVERY STATE QSO PARTY LOOKS ITS DOMESTIC QTH UP IN ITS DOMESTIC FILE -- the
   host's counties, or the states and provinces outside it -- M11 S6 part
   1b, 2026-10-14. Stated ONCE, here, because it is this family's rule:
   all twenty parties' traits said DomesticFile at every station. A party
   whose sponsor changes that overrides it. See
   TContestBase.UsesDomesticFile. *)
function TContestStateQSOPartyBase.UsesDomesticFile: boolean;
begin
   Result := True;
end;

end.
