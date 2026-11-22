unit uTestSubmitSequence;

(* ONE ENTRY, ITS LEGS, ONE WRITE -- THE ORDER (issues 347 and 348, plan
  commit 3, section 5b) -- src/domain/uSubmitSequence.pas.

  The program's steps are replaced by a recorder: each call appends a token
  to one line, so a test states the WHOLE order it expects and any step out of
  place fails it.

     P<i>   Prepare(i)      S<i>   Score(i)      W<n>   Write(n)
     R<i>   Release(i)      F<i>   Discard(i)    B      Rebuild

  What is pinned: a leg is prepared only after the leg before it is scored;
  nothing is released unless the write answered True; the last leg is scored
  after the write and before any release; a refusal discards every prepared
  leg and rebuilds only when a leg was scored (never for one leg); and the
  clean-up when a step raises, before and after the write. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSubmitSequenceTests = class(TTestCase)
   protected
      procedure TestOneLegWrittenIsPrepareWriteScoreRelease;
      procedure TestOneLegRefusedDiscardsAndNeverRebuilds;
      procedure TestThreeLegsWrittenScoreLazilyAndReleaseInOrder;
      procedure TestThreeLegsRefusedDiscardEveryLegThenRebuild;
      procedure TestALegRefusedAtPrepareStopsBeforeTheWrite;
      procedure TestTheThirdLegFailingBeforeTheWriteRebuilds;
      procedure TestAPrepareThatRaisesCleansUpAndRebuilds;
      procedure TestAWriteThatRaisesCleansUp;
      procedure TestAReleaseThatRaisesRebuildsNothing;
      procedure TestNoLegsCallsNothing;
      procedure TestAMissingStepIsRefused;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uSubmitSequence;

type
   (* THE RECORDER. Each knob is -1 (or True for WriteAnswer) when unused. *)
   TSubmitRecorder = class(TObject)
   public
      Trace: string;
      RefusePrepareAt: integer;
      RaisePrepareAt: integer;
      RaiseReleaseAt: integer;
      WriteAnswer: boolean;
      WriteRaises: boolean;
      constructor Create;
      procedure Add(const aToken: string);
      function Prepare(aLeg: integer): boolean;
      procedure Score(aLeg: integer);
      function WriteEntry(aLegCount: integer): boolean;
      procedure Release(aLeg: integer);
      procedure Discard(aLeg: integer);
      procedure Rebuild;
      (* A sequence wired to every step of this recorder. *)
      function NewSequence: TSubmitSequence;
   end;

constructor TSubmitRecorder.Create;
begin
   inherited Create;
   Trace := '';
   RefusePrepareAt := -1;
   RaisePrepareAt := -1;
   RaiseReleaseAt := -1;
   WriteAnswer := True;
   WriteRaises := False;
end;

procedure TSubmitRecorder.Add(const aToken: string);
begin
   if Trace <> '' then
      begin
      Trace := Trace + ' ';
      end;
   Trace := Trace + aToken;
end;

function TSubmitRecorder.Prepare(aLeg: integer): boolean;
begin
   Add('P' + IntToStr(aLeg));
   if aLeg = RaisePrepareAt then
      begin
      raise Exception.Create('prepare raised');
      end;
   Result := aLeg <> RefusePrepareAt;
end;

procedure TSubmitRecorder.Score(aLeg: integer);
begin
   Add('S' + IntToStr(aLeg));
end;

function TSubmitRecorder.WriteEntry(aLegCount: integer): boolean;
begin
   Add('W' + IntToStr(aLegCount));
   if WriteRaises then
      begin
      raise Exception.Create('write raised');
      end;
   Result := WriteAnswer;
end;

procedure TSubmitRecorder.Release(aLeg: integer);
begin
   Add('R' + IntToStr(aLeg));
   if aLeg = RaiseReleaseAt then
      begin
      raise Exception.Create('release raised');
      end;
end;

procedure TSubmitRecorder.Discard(aLeg: integer);
begin
   Add('F' + IntToStr(aLeg));
end;

procedure TSubmitRecorder.Rebuild;
begin
   Add('B');
end;

function TSubmitRecorder.NewSequence: TSubmitSequence;
begin
   Result := TSubmitSequence.Create;
   Result.OnPrepare := Prepare;
   Result.OnScore := Score;
   Result.OnWrite := WriteEntry;
   Result.OnRelease := Release;
   Result.OnDiscard := Discard;
   Result.OnRebuild := Rebuild;
end;

(* Runs aLegs legs on a fresh sequence over aRecorder; the exception's
  message, or '' when none escaped. *)
function RunCatching(aRecorder: TSubmitRecorder; aLegs: integer;
                     out aResult: boolean; out aRebuilt: boolean): string;
var
   sequence: TSubmitSequence;
begin
   Result := '';
   aResult := False;
   aRebuilt := False;
   sequence := aRecorder.NewSequence;
   try
      try
         aResult := sequence.Run(aLegs);
      except
         on E: Exception do
            begin
            Result := E.Message;
            end;
      end;
      aRebuilt := sequence.Rebuilt;
   finally
      sequence.Free;
   end;
end;

procedure TSubmitSequenceTests.TestOneLegWrittenIsPrepareWriteScoreRelease;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('one leg, written: prepare, write, score, release -- nothing scored before the commit');
   rec := TSubmitRecorder.Create;
   try
      CheckEquals('', RunCatching(rec, 1, ok, rebuilt), 'nothing raised');
      CheckTrue(ok, 'the entry is reported written');
      CheckFalse(rebuilt, 'and nothing was rebuilt');
      CheckEquals('P0 W1 S0 R0', rec.Trace, 'the order');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestOneLegRefusedDiscardsAndNeverRebuilds;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('one leg, refused: the leg is discarded, never released, and NOTHING is rebuilt');
   rec := TSubmitRecorder.Create;
   try
      rec.WriteAnswer := False;
      CheckEquals('', RunCatching(rec, 1, ok, rebuilt), 'nothing raised');
      CheckFalse(ok, 'the entry is reported refused');
      CheckFalse(rebuilt, 'and a single leg never rebuilds');
      CheckEquals('P0 W1 F0', rec.Trace, 'the order');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestThreeLegsWrittenScoreLazilyAndReleaseInOrder;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('three legs, written: each leg prepared after the one before is scored; ' +
             'the last scored after the write; released in order');
   rec := TSubmitRecorder.Create;
   try
      CheckEquals('', RunCatching(rec, 3, ok, rebuilt), 'nothing raised');
      CheckTrue(ok, 'the entry is reported written');
      CheckFalse(rebuilt, 'and nothing was rebuilt');
      CheckEquals('P0 S0 P1 S1 P2 W3 S2 R0 R1 R2', rec.Trace, 'the order');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestThreeLegsRefusedDiscardEveryLegThenRebuild;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('three legs, refused: no leg released, every leg discarded in order, THEN one rebuild');
   rec := TSubmitRecorder.Create;
   try
      rec.WriteAnswer := False;
      CheckEquals('', RunCatching(rec, 3, ok, rebuilt), 'nothing raised');
      CheckFalse(ok, 'the entry is reported refused');
      CheckTrue(rebuilt, 'legs 0 and 1 were scored, so the score state is rebuilt');
      CheckEquals('P0 S0 P1 S1 P2 W3 F0 F1 F2 B', rec.Trace, 'the order');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestALegRefusedAtPrepareStopsBeforeTheWrite;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('a leg refused at prepare: no write, the legs before it discarded, a rebuild for the scored one');
   rec := TSubmitRecorder.Create;
   try
      rec.RefusePrepareAt := 1;
      CheckEquals('', RunCatching(rec, 3, ok, rebuilt), 'nothing raised');
      CheckFalse(ok, 'the entry is reported refused');
      CheckTrue(rebuilt, 'leg 0 was scored, so the score state is rebuilt');
      CheckEquals('P0 S0 P1 F0 B', rec.Trace,
                  'the refused leg holds nothing to discard; the write never runs');
   finally
      rec.Free;
   end;

   rec := TSubmitRecorder.Create;
   try
      rec.RefusePrepareAt := 0;
      CheckEquals('', RunCatching(rec, 1, ok, rebuilt), 'nothing raised');
      CheckFalse(ok, 'a single leg refused at prepare is refused');
      CheckFalse(rebuilt, 'with nothing scored and nothing rebuilt');
      CheckEquals('P0', rec.Trace, 'and nothing else called');
   finally
      rec.Free;
   end;
end;

(* ISSUE 348 (plan commit 5): the LAST leg of three fails before the write --
  its build or its prepare (TLiveQSOSubmission builds a further leg inside
  Prepare). Legs 0 and 1 are on the sheets by then, and none is in the log:
  both are discarded, the write never runs, and the rebuild runs once, last. *)
procedure TSubmitSequenceTests.TestTheThirdLegFailingBeforeTheWriteRebuilds;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('the third leg of three refused or raising before the write: ' +
             'no write, legs 0 and 1 discarded, ONE rebuild after them');
   rec := TSubmitRecorder.Create;
   try
      rec.RefusePrepareAt := 2;
      CheckEquals('', RunCatching(rec, 3, ok, rebuilt), 'nothing raised');
      CheckFalse(ok, 'the entry is reported refused');
      CheckTrue(rebuilt, 'two legs were scored, so the score state is rebuilt');
      CheckEquals('P0 S0 P1 S1 P2 F0 F1 B', rec.Trace, 'refused at its prepare');
   finally
      rec.Free;
   end;

   rec := TSubmitRecorder.Create;
   try
      rec.RaisePrepareAt := 2;
      CheckEquals('prepare raised', RunCatching(rec, 3, ok, rebuilt), 'the exception reaches the caller');
      CheckFalse(ok, 'nothing is reported written');
      CheckTrue(rebuilt, 'and the score state is rebuilt');
      CheckEquals('P0 S0 P1 S1 P2 F0 F1 B', rec.Trace, 'raised in its build or prepare');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestAPrepareThatRaisesCleansUpAndRebuilds;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('a prepare that raises: the prepared legs discarded, a rebuild, and the exception goes on');
   rec := TSubmitRecorder.Create;
   try
      rec.RaisePrepareAt := 1;
      CheckEquals('prepare raised', RunCatching(rec, 3, ok, rebuilt), 'the exception reaches the caller');
      CheckFalse(ok, 'nothing is reported written');
      CheckTrue(rebuilt, 'leg 0 was scored, so the score state is rebuilt');
      CheckEquals('P0 S0 P1 F0 B', rec.Trace, 'the order');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestAWriteThatRaisesCleansUp;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('a write that raises: treated as a refusal, and the exception goes on');
   rec := TSubmitRecorder.Create;
   try
      rec.WriteRaises := True;
      CheckEquals('write raised', RunCatching(rec, 2, ok, rebuilt), 'the exception reaches the caller');
      CheckFalse(ok, 'nothing is reported written');
      CheckTrue(rebuilt, 'leg 0 was scored, so the score state is rebuilt');
      CheckEquals('P0 S0 P1 W2 F0 F1 B', rec.Trace, 'the order');
   finally
      rec.Free;
   end;

   rec := TSubmitRecorder.Create;
   try
      rec.WriteRaises := True;
      CheckEquals('write raised', RunCatching(rec, 1, ok, rebuilt), 'one leg: the exception reaches the caller');
      CheckFalse(rebuilt, 'and one leg never rebuilds');
      CheckEquals('P0 W1 F0', rec.Trace, 'the order');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestAReleaseThatRaisesRebuildsNothing;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('a release that raises after the commit: the rest discarded, NOTHING rebuilt -- the rows are in the log');
   rec := TSubmitRecorder.Create;
   try
      rec.RaiseReleaseAt := 1;
      CheckEquals('release raised', RunCatching(rec, 3, ok, rebuilt), 'the exception reaches the caller');
      CheckFalse(rebuilt, 'no rebuild: the entry IS committed');
      CheckEquals('P0 S0 P1 S1 P2 W3 S2 R0 R1 F2', rec.Trace,
                  'leg 1 raised in its release and is not discarded (it may have posted); leg 2 is');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestNoLegsCallsNothing;
var
   rec: TSubmitRecorder;
   ok, rebuilt: boolean;
begin
   BeginTest('no legs: False, and no step is called');
   rec := TSubmitRecorder.Create;
   try
      CheckEquals('', RunCatching(rec, 0, ok, rebuilt), 'nothing raised');
      CheckFalse(ok, 'nothing written');
      CheckEquals('', rec.Trace, 'nothing called');
   finally
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.TestAMissingStepIsRefused;
var
   rec: TSubmitRecorder;
   sequence: TSubmitSequence;
   raised: boolean;
begin
   BeginTest('a sequence with a step unassigned refuses to run, before calling anything');
   rec := TSubmitRecorder.Create;
   sequence := rec.NewSequence;
   try
      sequence.OnRebuild := nil;
      raised := False;
      try
         sequence.Run(1);
      except
         on ESubmitSequenceError do
            begin
            raised := True;
            end;
      end;
      CheckTrue(raised, 'ESubmitSequenceError, even for one leg, which would never rebuild');
      CheckEquals('', rec.Trace, 'and no step was called');
   finally
      sequence.Free;
      rec.Free;
   end;
end;

procedure TSubmitSequenceTests.RunAllTests;
begin
   TestOneLegWrittenIsPrepareWriteScoreRelease;
   TestOneLegRefusedDiscardsAndNeverRebuilds;
   TestThreeLegsWrittenScoreLazilyAndReleaseInOrder;
   TestThreeLegsRefusedDiscardEveryLegThenRebuild;
   TestALegRefusedAtPrepareStopsBeforeTheWrite;
   TestTheThirdLegFailingBeforeTheWriteRebuilds;
   TestAPrepareThatRaisesCleansUpAndRebuilds;
   TestAWriteThatRaisesCleansUp;
   TestAReleaseThatRaisesRebuildsNothing;
   TestNoLegsCallsNothing;
   TestAMissingStepIsRefused;
end;

end.
