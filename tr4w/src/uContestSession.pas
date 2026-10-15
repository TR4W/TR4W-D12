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

(* WHAT THE SESSION RUNS WITH -- the resolved KINDS of the contest being
  worked. M10 S9a, 2026-10-14 (docs/CONTEST_FACTORY_M10_PLAN.md 2.1 and S9a-f;
  docs/CONTEST_OWNERSHIP_DESIGN.md 8.2s).

  ---------------------------------------------------------------------------
  WHY A SESSION AND NOT THE CONTEST'S IDENTITY
  ---------------------------------------------------------------------------
  A kind here is what set-up RESOLVED, not what the contest's class states as
  its trait: FCONTEST.ApplyContestTraits writes the trait, then the contest's
  own DescribeSession may state another value for this station, and
  FCONTEST.ApplySessionDefaults writes that over it. Contests whose session
  kind differs from their trait at some station are many -- 24 at the
  contest matrix's stations after M11 S2 (M11 plan 1.3) -- and JIDX, for one,
  has the trait NoInitialExchange and runs ZoneInitialExchange at a JA
  station. So a reader that asked ContestIdentity(Contest) instead of this
  object would silently change those contests. (KCJ was the example here
  until M11 S2 made its trait the value it always ran.)

  ---------------------------------------------------------------------------
  THE CONTRACT
  ---------------------------------------------------------------------------
    * ONE INSTANCE, CREATED ONCE, NEVER REPLACED. It is built in this unit's
      initialization and freed in its finalization, and nothing else creates
      or frees one. A new contest re-WRITES its fields; it never swaps the
      object -- so a reference to it cannot dangle, which a free-and-recreate
      per contest would have made possible.
    * ONE WRITER: FCONTEST's set-up path -- ApplyContestTraits and, after
      it, ApplySessionDefaults, inside FoundContest -- through the Write*
      methods.
      Tests use the same methods. No reader writes, and the properties are
      read-only so a stray `:=` does not compile. Nothing enforces the writer
      beyond that: count the Write* callers
      (rg -i "\.Write(InitialExchange|Exchange)")
      -- FCONTEST and the tests are the only legitimate ones. Named Write*,
      not Set*, because TSessionDefaults (what a contest STATES) already has
      a SetInitialExchange (and SetExchange), and "who
      writes the session" must be one search.
    * THREADS. The writer runs on the main thread. Every reader measured at
      S9a for all six kinds runs on the main thread too: the call window,
      the sheet, the display, the exporters (headless /EXPORT runs on the
      main thread), uScoreTotals (gated by LOGEDIT.TotalScore's OnMainThread,
      so the posting clients' worker threads never reach it), and uWSJTX's
      CQ decode, status, clear and logged-ADIF
      messages (all handed to the main thread by QueueAsyncCall; until
      2026-10-14 they ran on Indy's listener thread, a race). So no lock is taken, as none was for the globals this
      replaces. If a worker thread ever does read it, the guarantee is the
      global's: each kind is an enum held in its own field, read and written
      whole, so a reader sees the old value or the new one, never a torn one
      -- but it may see a mixture of two contests' kinds during a set-up. A
      reader that needs them coherent must run on the main thread.
    * A LEAF. It uses VC alone, so every TRDOS unit can use it without a cycle.
      No virtual, no allocation: a read is a function call and a field read,
      cheap enough for the per-row repaint read of Exchange
      (TREE.LooksLikeAGrid, S9f).

  ---------------------------------------------------------------------------
  WHAT IS HERE, AND WHAT IS STILL A GLOBAL
  ---------------------------------------------------------------------------
  Moved one kind per commit, the fewest readers first (plan S9a-f):

    InitialExchange    S9a   was LOGWIND.ActiveInitialExchange
    PrefixMult         S9b   was LOGDUPE.ActivePrefixMult; DELETED at M11 S3
    ZoneMult           S9c   was LOGWIND.ActiveZoneMult; DELETED at M11 S5
    DXMult             S9d   was VC.ActiveDXMult; DELETED at M11 S4
    DomesticMult       S9e   was LOGDOM.ActiveDomesticMult; DELETED at M11 S6
    Exchange           S9f   was LOGWIND.ActiveExchange

  All six came here, and two remain -- the prefix kind left at M11 S3,
  the DX kind at M11 S4, the zone kind at M11 S5 and the domestic kind at M11
  S6; no kind global is left, and no MULTIPLIER kind at all. The kind ENUMS outlive M10: they
  are the engine's vocabulary until their arms move into the classes at M11
  (design 8.2s).

    Doing*Mults        M11 S2  were the LOGDUPE globals LogCfg derived once
                               at start-up; computed from the kinds now (F9)
    DoingPrefixMults   M11 S3  LEFT with the prefix kind: the contest answers
                               it (LOGEDIT.DoingPrefixMults, asking
                               TContestBase.HasPrefixMultiplier)
    DoingDXMults       M11 S4  LEFT with the DX kind: the contest answers it
                               (LOGEDIT.DoingDXMults, asking
                               TContestBase.HasDXMultiplier)
    DoingZoneMults     M11 S5  LEFT with the zone kind: the contest answers
                               it (LOGEDIT.DoingZoneMults, asking
                               TContestBase.HasZoneMultiplier)
    DoingDomesticMults M11 S6  LEFT with the domestic kind: the contest
                               answers it (LOGEDIT.DoingDomesticMults, asking
                               TContestBase.HasDomesticMultiplier)
  *)
unit uContestSession;

{$I tr4w.inc}

interface

uses
   VC;

type
   TContestSession = class
   private
      FInitialExchange: InitialExchangeType;
      FExchange: ExchangeType;
   public
      (* The initial exchange the call window pre-fills from -- the kind
        LOGEDIT.InitialExchangeEntry asks. A fresh session holds
        NoInitialExchange, the zero the global it replaces started from. *)
      property InitialExchange: InitialExchangeType read FInitialExchange;

      (* The received exchange the session parses -- ProcessExchange's shape,
        the call window, the log grid's columns, the exporters, the sheet's
        exchange information and TREE.LooksLikeAGrid (once per log row per
        repaint). A fresh session holds UnknownExchange, the ordinal zero
        LOGWIND.ActiveExchange started from -- its `= NoExchangeReceived`
        initializer was commented out, so NoExchangeReceived it never was
        (uLogRepository's open-without-a-contest note relies on that zero). *)
      property Exchange: ExchangeType read FExchange;

      (* NO Doing*Mults ANSWER IS LEFT HERE -- M11 S6 part 2, 2026-10-14. They
        were LOGDUPE globals derived once at start-up (plan F9), then (M11
        S2) answers computed from the kinds above; each left with its kind,
        the last, DoingDomesticMults, at M11 S6. All four are the contest's
        own answers now (LOGEDIT.Doing*Mults), live against the station. *)

      (* THE WRITERS -- FCONTEST's set-up path, and tests. See the header. *)
      procedure WriteInitialExchange(aKind: InitialExchangeType);
      procedure WriteExchange(aKind: ExchangeType);
   end;

(* The one session. Never nil between this unit's initialization and its
   finalization, and always the same object. *)
function ContestSession: TContestSession;

implementation

var
   TheSession: TContestSession = nil;

procedure TContestSession.WriteInitialExchange(aKind: InitialExchangeType);
begin
   FInitialExchange := aKind;
end;

procedure TContestSession.WriteExchange(aKind: ExchangeType);
begin
   FExchange := aKind;
end;

function ContestSession: TContestSession;
begin
   Result := TheSession;
end;

initialization
   TheSession := TContestSession.Create;

finalization
   TheSession.Free;
   TheSession := nil;

end.
