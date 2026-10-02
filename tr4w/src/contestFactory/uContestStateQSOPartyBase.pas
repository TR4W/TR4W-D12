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

  THE SINGLE-STATE PARTIES WITH COUNTY MULTIPLIERS. Thirteen carry
  CountyLineAllowed: True in ContestsArray today, and a handful more are
  single-state with no flag set at all (Arizona, British Columbia, New York,
  Virginia) -- whose correct value is simply unknown rather than False.

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
   protected
      (* IT IS ONE, AND THE CLASS SAYS SO RATHER THAN THE TABLE SAYING SO.

         The inherited answer reads ContestsArray[c].P <> 0, and P is an INDEX
         into QSOParties -- so "is this a QSO party" is currently answered by a
         file-name lookup table being non-empty. A class in this hierarchy IS
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
   public
      property CountyLineCountiesMax: integer read GetCountyLineCountiesMax;
      property CountyLineAllowed: boolean read GetCountyLineAllowed;

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
         table as before: it says nothing about where the station is. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   end;

implementation

uses
   SysUtils,        (* Format *)
   uTR4WStrings,    (* TC_TOOMANYCOUNTIES *)
   uAppStrings;     (* SExchangeOutOfStateWorksHostOnly *)

function TContestStateQSOPartyBase.ParseReceivedExchange(const aText: string;
                                                         const aSession: TReceivedExchangeSession;
                                                         var aExch: ContestExchange;
                                                         out aErrorMessage: string): boolean;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if (not Result) or Station.InHostState then
      begin
      Exit;
      end;

   if not aSession.IsDomesticQTH(string(aExch.QTHString)) then
      begin
      Result := False;
      aErrorMessage := Format(SExchangeOutOfStateWorksHostOnly, [HostState]);
      end;
end;

function TContestStateQSOPartyBase.GetIsUSQSOParty: boolean;
begin
   Result := True;
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

end.
