unit uTestTXInhibit;
{$I ..\..\src\tr4w.inc}

(*
  ISSUE #97, PHASE 1: THE RADIO REPORTS "TX INHIBITED", AND THE STATUS CARRIES IT.

  In CQ WW SSB 2026 a K4 was left in TX TEST mode (TS1;): it keyed, the TX icon
  flashed, the amplifier keyed, and no RF went out.  Nothing in TR4W said so.

  What is pinned here, all without a transport:
  - the K4 parses TS0 / TS1 into the generic condition, with the radio's own
    words as the reason, and leaves it alone on a value it does not document;
  - interleaved with other replies, in the order a reading thread delivers
    them, the condition follows the TS replies and nothing else;
  - a radio that has NOT declared rcReportsTXInhibit cannot raise it -- the
    base refuses the ON, guarded on the trait and never on the model;
  - over the whole registry, the K4 is the one radio that declares it;
  - the condition rides the status record: TS1 then TS0 is two changes that
    RadioStatusDiffers sees, and RadioTXInhibited -- the read phase 2 uses --
    reports it from the settled status;
  - a new link forgets what the last one said.

  The split-across-reads case and the connect-time TS; need a socket and live
  in uTestRadioSocketNoRead, beside the #SPN; tests they mirror.
*)

interface

uses
   uTR4WTestFramework;

type
   TTXInhibitTests = class(TTestCase)
   protected
      procedure Test_TS1_RaisesTheConditionWithTheRadiosWords;
      procedure Test_TS0_ClearsIt;
      procedure Test_UndocumentedValue_LeavesTheStateAlone;
      procedure Test_MixedWithOtherReplies_FollowsOnlyTS;
      procedure Test_RadioWithoutTheTrait_CannotRaiseIt;
      procedure Test_OnlyTheK4DeclaresTheTrait;
      procedure Test_TS1ThenTS0_IsTwoStatusChanges;
      procedure Test_RadioTXInhibited_ReadsTheSettledStatus;
      procedure Test_ReasonComparesContentNotStaleBytes;
      procedure Test_ConnectForgetsTheLastSession;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils, uFactoryRadioBase, uRadioRegistry, uRadioElecraftK4, VC, LogRadio;

type
   (* A K4 that has NOT declared the trait.  Everything else is the shipped
     driver, so its parser really does call SetTXInhibited -- exactly the shape
     of a driver that parses a condition its constructor does not admit to. *)
   TK4WithoutTheTrait = class(TK4Radio)
   public
      constructor Create;
   end;

constructor TK4WithoutTheTrait.Create;
begin
   inherited Create;
   FCapabilities.Flags := FCapabilities.Flags - [rcReportsTXInhibit];
end;

const
   K4_REASON = 'TX test mode';

(* The K4 through the registry, so the construction path is the application's. *)
function NewK4: TFactoryRadioBase;
begin
   Result := uRadioRegistry.CreateInstance(K4);
end;

function Inhibited(r: TFactoryRadioBase; out aReason: string): boolean;
var
   reason: TTXInhibitReason;
begin
   Result := r.ReadTXInhibit(reason);
   aReason := string(reason);
end;

procedure TTXInhibitTests.Test_TS1_RaisesTheConditionWithTheRadiosWords;
var
   r: TFactoryRadioBase;
   why: string;
begin
   BeginTest('K4: TS1 raises TX inhibited, reason "TX test mode"');
   r := NewK4;
   try
      CheckFalse(Inhibited(r, why), 'precondition: a fresh radio is not inhibited');

      (* As the reading thread hands it over: the terminator already consumed. *)
      r.ProcessMsg('TS1');
      CheckTrue(Inhibited(r, why), 'TS1 must raise TX inhibited');
      CheckEquals(K4_REASON, why, 'the reason is the radio''s own words');

      (* And with the terminator still on, which ProcessMessage also accepts. *)
      r.ProcessMsg('TS0;');
      r.ProcessMsg('TS1;');
      CheckTrue(Inhibited(r, why), 'TS1; (with its terminator) must raise it too');
   finally
      r.Free;
   end;
end;

procedure TTXInhibitTests.Test_TS0_ClearsIt;
var
   r: TFactoryRadioBase;
   why: string;
begin
   BeginTest('K4: TS0 clears TX inhibited and its reason');
   r := NewK4;
   try
      r.ProcessMsg('TS1');
      CheckTrue(Inhibited(r, why), 'precondition: TS1 raised it');

      r.ProcessMsg('TS0');
      CheckFalse(Inhibited(r, why), 'TS0 must clear TX inhibited');
      CheckEquals('', why, 'a cleared condition carries no reason');
   finally
      r.Free;
   end;
end;

procedure TTXInhibitTests.Test_UndocumentedValue_LeavesTheStateAlone;
var
   r: TFactoryRadioBase;
   why: string;
begin
   BeginTest('K4: a TS value other than 0 or 1 changes nothing');
   r := NewK4;
   try
      r.ProcessMsg('TS1');
      r.ProcessMsg('TS7');
      CheckTrue(Inhibited(r, why), 'TS7 must not clear an inhibited radio');

      r.ProcessMsg('TS0');
      r.ProcessMsg('TS');
      CheckFalse(Inhibited(r, why), 'an empty TS must not raise a clear radio');
   finally
      r.Free;
   end;
end;

(* The order a reading thread delivers a burst in, with the TS replies among
  frequency, mode and TX/RX reports.  Only TS may move the condition -- and TX,
  in particular, must not: a radio in test mode still keys. *)
procedure TTXInhibitTests.Test_MixedWithOtherReplies_FollowsOnlyTS;
var
   r: TFactoryRadioBase;
   why: string;
begin
   BeginTest('K4: TS among other replies -- the condition follows TS and nothing else');
   r := NewK4;
   try
      r.ProcessMsg('FA00014025000');
      r.ProcessMsg('TS1');
      r.ProcessMsg('TX');
      r.ProcessMsg('FB00007025000');
      CheckTrue(Inhibited(r, why), 'TS1 in the middle of a burst raised it');
      CheckEquals(14025000, r.frequency[nrVFOA], 'the FA around it was parsed as usual');
      CheckEquals(7025000, r.frequency[nrVFOB], 'and the FB after it');
      CheckTrue(r.IsTransmitting, 'TX is still TX -- test mode keys the radio');

      r.ProcessMsg('RX');
      CheckTrue(Inhibited(r, why), 'RX does not clear TX inhibited');

      r.ProcessMsg('FA00014030000');
      r.ProcessMsg('TS0');
      r.ProcessMsg('FB00007030000');
      CheckFalse(Inhibited(r, why), 'TS0 in the middle of a burst cleared it');
   finally
      r.Free;
   end;
end;

procedure TTXInhibitTests.Test_RadioWithoutTheTrait_CannotRaiseIt;
var
   r: TK4WithoutTheTrait;
   reason: TTXInhibitReason;
begin
   BeginTest('A radio that does not declare rcReportsTXInhibit cannot raise it');
   r := TK4WithoutTheTrait.Create;
   try
      CheckFalse(r.Supports(rcReportsTXInhibit), 'precondition: the trait is not declared');

      r.ProcessMsg('TS1');
      CheckFalse(r.ReadTXInhibit(reason),
                 'the base must refuse an ON from a radio that has not declared the ' +
                 'trait -- otherwise any parser could raise a condition its radio ' +
                 'does not admit to');
      CheckEquals('', string(reason), 'and no reason leaks through');
   finally
      r.Free;
   end;
end;

(* THE REGISTRY WALK.  Every registered radio, enum and string id alike, built
  the way the application builds it.  If the K4 loses the flag, phase 2 goes
  blind in silence; if another radio gains it with no driver behind it, this
  says so and names it. *)
procedure TTXInhibitTests.Test_OnlyTheK4DeclaresTheTrait;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   declared: string;
   checked: integer;
begin
   BeginTest('Registry: the K4 is the one radio that declares rcReportsTXInhibit');
   declared := '';
   checked := 0;
   ids := uRadioRegistry.RegisteredIds;

   for id in ids do
      begin
      r := uRadioRegistry.CreateInstanceId(id);
      if r = nil then
         begin
         Continue;
         end;
      try
         Inc(checked);
         if r.Supports(rcReportsTXInhibit) then
            begin
            declared := declared + uRadioRegistry.DisplayNameId(id) + ' ';
            end;
      finally
         r.Free;
      end;
      end;

   CheckTrue(checked > 0, 'the registry produced no radios to check');
   CheckEquals('Elecraft K4 ', declared,
               'exactly one radio declares rcReportsTXInhibit, and it is the K4 -- ' +
               'the only driver that parses a TX-inhibit report');
end;

(* The polling loop, reduced to the part that matters: capture into the current
  record, compare with the previous one, roll forward.  Same two routines the
  loop calls -- CaptureTXInhibit and RadioStatusDiffers. *)
procedure TTXInhibitTests.Test_TS1ThenTS0_IsTwoStatusChanges;
var
   r: TFactoryRadioBase;
   cur, prev: RadioStatusRecord;
   changes: integer;

   procedure Poll(const aReply: string);
   begin
      r.ProcessMsg(aReply);
      CaptureTXInhibit(cur, r);
      if RadioStatusDiffers(cur, prev) then
         begin
         Inc(changes);
         end;
      prev := cur;
   end;

begin
   BeginTest('Status: TS1 then TS0 is two changes the change detection sees');
   cur := Default(RadioStatusRecord);
   prev := Default(RadioStatusRecord);
   changes := 0;

   r := NewK4;
   try
      Poll('TS1');
      CheckEquals(1, changes, 'TS1 is a change');
      CheckTrue(cur.TXInhibited, 'and the status carries it');
      CheckEquals(K4_REASON, string(cur.TXInhibitReason), 'with the reason');

      Poll('TS1');
      CheckEquals(1, changes, 'a repeated TS1 is not a second change');

      Poll('TS0');
      CheckEquals(2, changes, 'TS0 is the second change');
      CheckFalse(cur.TXInhibited, 'and the status is clear again');

      Poll('TS0');
      CheckEquals(2, changes, 'a repeated TS0 is not a third');
   finally
      r.Free;
   end;
end;

var
   (* A standalone slot, never the program's Radio1/Radio2.  A unit-level
     variable rather than a zeroed local: RadioObject holds managed strings,
     and a global starts out empty with them initialised properly. *)
   gSlot: RadioObject;

procedure TTXInhibitTests.Test_RadioTXInhibited_ReadsTheSettledStatus;
var
   rig: RadioPtr;
   why: string;
begin
   BeginTest('RadioTXInhibited: the program''s read, from the settled status');
   rig := @gSlot;

   CheckFalse(RadioTXInhibited(nil, why), 'a nil slot is not inhibited');
   CheckFalse(RadioTXInhibited(rig, why), 'an empty slot is not inhibited');
   CheckEquals('', why, 'and has no reason');

   (* Only the CURRENT status says so: not settled yet, so not reported. *)
   rig^.CurrentStatus.TXInhibited := True;
   rig^.CurrentStatus.TXInhibitReason := K4_REASON;
   CheckFalse(RadioTXInhibited(rig, why),
              'the read is from the SETTLED status, like PTTStatusChanged''s TXOn');

   BeginStatusPublish(rig);
   rig^.FilteredStatus := rig^.CurrentStatus;
   EndStatusPublish(rig);
   CheckTrue(RadioTXInhibited(rig, why), 'settled: reported');
   CheckEquals(K4_REASON, why, 'with the radio''s words');
end;

(* A ShortString's bytes past its length are not its value.  A reason that was
  once longer leaves them behind; equality must not see them. *)
procedure TTXInhibitTests.Test_ReasonComparesContentNotStaleBytes;
var
   a, b: RadioStatusRecord;
begin
   BeginTest('Status: the reason compares by content, not by stale bytes');
   a := Default(RadioStatusRecord);
   b := Default(RadioStatusRecord);

   a.TXInhibited := True;
   b.TXInhibited := True;
   a.TXInhibitReason := 'TX test mode';
   b.TXInhibitReason := 'a much longer reason text';
   b.TXInhibitReason := 'TX test mode';

   CheckFalse(RadioStatusDiffers(a, b),
              'two records with the same reason must compare equal whatever lies ' +
              'past the reason''s length byte');
end;

procedure TTXInhibitTests.Test_ConnectForgetsTheLastSession;
var
   r: TFactoryRadioBase;
   why: string;
begin
   BeginTest('A new link forgets the last session''s TX inhibit');
   r := NewK4;
   try
      r.ProcessMsg('TS1');
      CheckTrue(Inhibited(r, why), 'precondition: inhibited');

      (* No address: the attempt goes nowhere, but it is a new session. *)
      r.Connect;
      CheckFalse(Inhibited(r, why),
                 'what the last link reported is not a fact about the next one -- ' +
                 'the radio may have left test mode while the link was down');
   finally
      r.Free;
   end;
end;

procedure TTXInhibitTests.RunAllTests;
begin
   Test_TS1_RaisesTheConditionWithTheRadiosWords;
   Test_TS0_ClearsIt;
   Test_UndocumentedValue_LeavesTheStateAlone;
   Test_MixedWithOtherReplies_FollowsOnlyTS;
   Test_RadioWithoutTheTrait_CannotRaiseIt;
   Test_OnlyTheK4DeclaresTheTrait;
   Test_TS1ThenTS0_IsTwoStatusChanges;
   Test_RadioTXInhibited_ReadsTheSettledStatus;
   Test_ReasonComparesContentNotStaleBytes;
   Test_ConnectForgetsTheLastSession;
end;

end.
