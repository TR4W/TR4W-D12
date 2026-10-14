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
  FCONTEST.ApplySessionDefaults writes that over it. 27 contests run with a
  session kind that differs from their trait in at least one station variant
  (plan 1.4) -- KCJ, for one, has the trait NoInitialExchange and always runs
  ZoneInitialExchange. So a reader that asked ContestIdentity(Contest) instead
  of this object would silently change those contests.

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
      (rg -i "\.Write(InitialExchange|PrefixMult|ZoneMult|DXMult|DomesticMult)")
      -- FCONTEST and the tests are the only legitimate ones. Named Write*,
      not Set*, because TSessionDefaults (what a contest STATES) already has
      a SetInitialExchange (and SetPrefixMult, SetZoneMult, SetDXMult,
      SetDomesticMult), and "who writes
      the session" must be one search.
    * THREADS. The writer runs on the main thread. Every reader measured at
      S9a for all six kinds runs on the main thread too: the call window,
      the sheet, the display, the exporters (headless /EXPORT runs on the
      main thread), uScoreTotals (gated by LOGEDIT.TotalScore's OnMainThread,
      so the posting clients' worker threads never reach it), and uWSJTX
      (QueueAsyncCall). So no lock is taken, as none was for the globals this
      replaces. If a worker thread ever does read it, the guarantee is the
      global's: each kind is an enum held in its own field, read and written
      whole, so a reader sees the old value or the new one, never a torn one
      -- but it may see a mixture of two contests' kinds during a set-up. A
      reader that needs them coherent must run on the main thread.
    * A LEAF. It uses VC alone, so every TRDOS unit can use it without a cycle.
      No virtual, no allocation: a read is a function call and a field read,
      cheap enough for the per-row repaint ActiveExchange will bring (S9f).

  ---------------------------------------------------------------------------
  WHAT IS HERE, AND WHAT IS STILL A GLOBAL
  ---------------------------------------------------------------------------
  Moved one kind per commit, the fewest readers first (plan S9a-f):

    InitialExchange    S9a   was LOGWIND.ActiveInitialExchange
    PrefixMult         S9b   was LOGDUPE.ActivePrefixMult
    ZoneMult           S9c   was LOGWIND.ActiveZoneMult
    DXMult             S9d   was VC.ActiveDXMult
    DomesticMult       S9e   was LOGDOM.ActiveDomesticMult

  Still a global until its stage: ActiveExchange (LOGWIND). The kind ENUMS
  outlive M10: they are the engine's vocabulary until their arms move into
  the classes at M11 (design 8.2s). *)
unit uContestSession;

{$I tr4w.inc}

interface

uses
   VC;

type
   TContestSession = class
   private
      FInitialExchange: InitialExchangeType;
      FPrefixMult: PrefixMultType;
      FZoneMult: ZoneMultType;
      FDXMult: DXMultType;
      FDomesticMult: DomesticMultType;
   public
      (* The initial exchange the call window pre-fills from -- the kind
        LOGEDIT.InitialExchangeEntry asks. A fresh session holds
        NoInitialExchange, the zero the global it replaces started from. *)
      property InitialExchange: InitialExchangeType read FInitialExchange;

      (* The prefix multiplier the sheet keeps (LOGDUPE's mult flags, the log
        grid's prefix column, LogCfg's DoingPrefixMults). A fresh session holds
        NoPrefixMults, the zero LOGDUPE.ActivePrefixMult started from. *)
      property PrefixMult: PrefixMultType read FPrefixMult;

      (* The zone multiplier the session runs -- the sheet, the parsers, the
        ADIF CQZ/ITUZ choice and POSTUNIT.ZoneSentForThisContest (which zone
        the station sends, CQ or ITU). A fresh session holds NoZoneMults, the
        zero LOGWIND.ActiveZoneMult started from. *)
      property ZoneMult: ZoneMultType read FZoneMult;

      (* The DX multiplier the session runs -- the sheet's DX mult flags, the
        remaining-countries list (uMults), the log grid's and Edit QSO's DX
        column, the score's "counts multipliers", and the CTY country list
        the CONTEST setting's effect derives from it (uSettingsEffects, plan
        F5). A fresh session holds NoDXMults, the zero VC.ActiveDXMult
        started from. *)
      property DXMult: DXMultType read FDXMult;

      (* The domestic multiplier the session runs -- how LOGDOM reads a
        domestic QTH, the sheet's domestic mult flags, the grid-square rover
        rules, the exporters, uWSJTX's grid hint and the factory's
        IsNewMultiplierAnywhere service. A fresh session holds
        NoDomesticMults, the zero LOGDOM.ActiveDomesticMult started from. *)
      property DomesticMult: DomesticMultType read FDomesticMult;

      (* THE WRITERS -- FCONTEST's set-up path, and tests. See the header. *)
      procedure WriteInitialExchange(aKind: InitialExchangeType);
      procedure WritePrefixMult(aKind: PrefixMultType);
      procedure WriteZoneMult(aKind: ZoneMultType);
      procedure WriteDXMult(aKind: DXMultType);
      procedure WriteDomesticMult(aKind: DomesticMultType);
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

procedure TContestSession.WritePrefixMult(aKind: PrefixMultType);
begin
   FPrefixMult := aKind;
end;

procedure TContestSession.WriteZoneMult(aKind: ZoneMultType);
begin
   FZoneMult := aKind;
end;

procedure TContestSession.WriteDXMult(aKind: DXMultType);
begin
   FDXMult := aKind;
end;

procedure TContestSession.WriteDomesticMult(aKind: DomesticMultType);
begin
   FDomesticMult := aKind;
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
