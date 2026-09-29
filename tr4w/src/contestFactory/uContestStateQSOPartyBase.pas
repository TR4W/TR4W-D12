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
  kind -- TContestFixedPoints' kind -- a shared MECHANISM across contests run by
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
  Virginia, Locust) -- whose correct value is simply unknown rather than False.

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
   uContestBase;

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
   end;

implementation

function TContestStateQSOPartyBase.GetIsUSQSOParty: boolean;
begin
   Result := True;
end;

end.
