unit uSubmitSequence;

(* ONE OPERATOR ENTRY, ALL OF ITS LEGS, ONE WRITE -- THE ORDER, AND NOTHING
  ELSE (issues 347 and 348; docs/LOG_COMMIT_BEFORE_PUBLISH_PLAN.md sections
  2a, 2b and 5b, plan commit 3).

  WHY A LEAF. LogContact and TryLogContact cannot be called from the unit
  tests, and the ORDER they must keep is the whole fix: nothing leaves the
  station before the log has committed, and an entry of several legs (a county
  line, several parks, a rover boundary) is written in ONE transaction, all of
  it or none. So the order lives here, behind method-pointer seams, and the
  tests drive it with recording stubs. The program supplies the steps; this
  unit decides only WHEN each one runs.

  THE STEPS, per leg i of n:
     Prepare(i)   parse-time work as today, and BUILD (never post) what the leg
                  will publish. Reads the score sheets as they stand, so it must
                  see every earlier leg scored. False refuses the whole entry.
     Score(i)     the score state the log can rebuild (LoadinLog): totals,
                  sheets, dupe sheets.
     Write(n)     the one store call, the one transaction. True only when it
                  has COMMITTED (uLogStore.LogStoreAppendLiveQSOs).
     Release(i)   after the commit only: post what Prepare built, refresh what
                  shows the log. Takes ownership of what it posts.
     Discard(i)   a prepared leg that will never be released: free what
                  Prepare built, post nothing.
     Rebuild      the score state rebuilt from the log, after a refusal that
                  had scored a leg the log does not hold.

  THE ORDER (plan 2b, "score lazily"):
     Prepare(0); then for i = 1..n-1: Score(i-1), Prepare(i); then Write(n).
     Written:  Score(n-1), then Release(0) .. Release(n-1), in order.
     Refused:  Discard of every prepared leg, in order; then Rebuild ONLY IF a
               leg was scored -- never for a single leg, which scores nothing
               before its commit, exactly as a one-row entry always has.

  So a one-leg entry is Prepare(0), Write(1), Score(0), Release(0) -- and on a
  refusal Prepare(0), Write(1), Discard(0): no score state touched, nothing to
  rebuild.

  THE LAST LEG IS SCORED BEFORE ANY LEG IS RELEASED. Every release then sees
  the entry's final score, so the first status or score packet it sends
  already carries the whole entry. (Decided here, 2026-11-22: the plan says
  only "the last leg scored after the write".)

  WHEN A STEP RAISES:
     Prepare, Score (before the write) or Write: every prepared leg is
        discarded, Rebuild runs if a leg was scored, and the exception goes on.
     Score of the last leg, or a Release (after the write): the rows ARE
        committed, so there is nothing to rebuild. Every leg not yet released
        is discarded and the exception goes on. The leg whose Release raised
        is NOT discarded: it may already have posted what it held, and a
        message the dispatcher owns must not be freed twice.
     Discard: the legs after it are not discarded, Rebuild still runs (it is
        in a finally), and the exception goes on.

  A leaf: RTL only -- no Forms, no logger, no globals. Legs are indices; what
  a leg IS belongs to the caller. *)

{$I ..\tr4w.inc}

interface

uses
   SysUtils;

type
   ESubmitSequenceError = class(Exception);

   TSubmitPrepare = function(aLeg: integer): boolean of object;
   TSubmitLegStep = procedure(aLeg: integer) of object;
   TSubmitWrite = function(aLegCount: integer): boolean of object;
   TSubmitRebuild = procedure of object;

   TSubmitSequence = class(TObject)
   private
      FOnPrepare: TSubmitPrepare;
      FOnScore: TSubmitLegStep;
      FOnWrite: TSubmitWrite;
      FOnRelease: TSubmitLegStep;
      FOnDiscard: TSubmitLegStep;
      FOnRebuild: TSubmitRebuild;
      (* Per leg, for the run in progress. *)
      FPrepared: array of boolean;
      FScored: array of boolean;
      FReleased: array of boolean;
      FRebuilt: boolean;
      procedure CheckSeams;
      function AnyScored: boolean;
      (* Discard every prepared leg not released, in order. *)
      procedure DiscardUnreleased;
      (* A refusal, or a failure before the write: discard, then rebuild if a
        leg was scored. *)
      procedure Abandon;
   public
      (* Drives one entry of aLegCount legs. True only when Write answered
        True -- the entry is in the log -- and every leg was released. False
        when Prepare or Write refused; nothing was released. A count below
        1 is False and calls nothing. Raises ESubmitSequenceError when a seam
        is not assigned, and passes on whatever a step raises (see the
        header for what is cleaned up first). *)
      function Run(aLegCount: integer): boolean;

      (* True when the last Run called Rebuild. *)
      property Rebuilt: boolean read FRebuilt;

      property OnPrepare: TSubmitPrepare read FOnPrepare write FOnPrepare;
      property OnScore: TSubmitLegStep read FOnScore write FOnScore;
      property OnWrite: TSubmitWrite read FOnWrite write FOnWrite;
      property OnRelease: TSubmitLegStep read FOnRelease write FOnRelease;
      property OnDiscard: TSubmitLegStep read FOnDiscard write FOnDiscard;
      property OnRebuild: TSubmitRebuild read FOnRebuild write FOnRebuild;
   end;

implementation

procedure TSubmitSequence.CheckSeams;
begin
   (* ALL SIX, ALWAYS. A one-leg entry never scores before its write and never
     rebuilds, but a caller that cannot score or rebuild cannot submit a
     second leg either, and finding that out on a county line mid-contest is
     the wrong time. *)
   if (not Assigned(FOnPrepare)) or
      (not Assigned(FOnScore))   or
      (not Assigned(FOnWrite))   or
      (not Assigned(FOnRelease)) or
      (not Assigned(FOnDiscard)) or
      (not Assigned(FOnRebuild)) then
      begin
      raise ESubmitSequenceError.Create(
         'TSubmitSequence.Run: every step (prepare, score, write, release, ' +
         'discard, rebuild) must be assigned.');
      end;
end;

function TSubmitSequence.AnyScored: boolean;
var
   i: integer;
begin
   Result := False;
   for i := 0 to High(FScored) do
      begin
      if FScored[i] then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure TSubmitSequence.DiscardUnreleased;
var
   i: integer;
begin
   for i := 0 to High(FPrepared) do
      begin
      if FPrepared[i] and (not FReleased[i]) then
         begin
         (* Marked first: a Discard that raises is not tried again by a later
           clean-up of the same run. *)
         FPrepared[i] := False;
         FOnDiscard(i);
         end;
      end;
end;

procedure TSubmitSequence.Abandon;
begin
   try
      DiscardUnreleased;
   finally
      if AnyScored then
         begin
         FRebuilt := True;
         FOnRebuild();
         end;
   end;
end;

function TSubmitSequence.Run(aLegCount: integer): boolean;
var
   i: integer;
   written, refused: boolean;
begin
   Result := False;
   FRebuilt := False;
   if aLegCount < 1 then
      begin
      Exit;
      end;
   CheckSeams;

   FPrepared := nil;
   FScored := nil;
   FReleased := nil;
   SetLength(FPrepared, aLegCount);
   SetLength(FScored, aLegCount);
   SetLength(FReleased, aLegCount);
   for i := 0 to aLegCount - 1 do
      begin
      FPrepared[i] := False;
      FScored[i] := False;
      FReleased[i] := False;
      end;

   (* BEFORE THE WRITE: prepare each leg against the sheets as the earlier
     legs left them, scoring each earlier leg just before the next is
     prepared. *)
   (* ABANDON RUNS ONCE, after the try: a refusal only breaks out, so a
     Discard or Rebuild that raises is never followed by a second clean-up. *)
   written := False;
   refused := False;
   try
      for i := 0 to aLegCount - 1 do
         begin
         if i > 0 then
            begin
            FScored[i - 1] := True;
            FOnScore(i - 1);
            end;
         if not FOnPrepare(i) then
            begin
            refused := True;
            Break;
            end;
         FPrepared[i] := True;
         end;
      if not refused then
         begin
         written := FOnWrite(aLegCount);
         end;
   except
      Abandon;
      raise;
   end;

   if refused or (not written) then
      begin
      Abandon;
      Exit;
      end;

   (* AFTER THE COMMIT: the last leg scored, then every leg released in
     order. The rows are in the log, so a failure here rebuilds nothing. *)
   try
      FScored[aLegCount - 1] := True;
      FOnScore(aLegCount - 1);
      for i := 0 to aLegCount - 1 do
         begin
         FReleased[i] := True;
         FOnRelease(i);
         end;
   except
      DiscardUnreleased;
      raise;
   end;
   Result := True;
end;

end.
