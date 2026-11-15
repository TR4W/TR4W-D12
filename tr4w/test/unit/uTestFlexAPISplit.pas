unit uTestFlexAPISplit;
{$I ..\..\src\tr4w.inc}

(*
  Issue 259: split by the '-' key on a Flex (SmartSDR API) with slice 1
  receiving -- the Flex half of issue 38.

  The driver mapped VFO A to slice 0 and VFO B to slice 1 and never read which
  slice the operator was working with.  The '-' entry therefore tuned slice 1
  (the slice being received on) to the TX frequency and Split(True) forced
  slice 0 active, yanking receive onto VFO A.

  The driver now tracks the active slice from the radio's own active=1 push,
  answers SplitTransmitVFO with the other VFO, and splits through
  SplitTransmittingOn.  These tests pin:
    - slice 0 receiving: exactly the commands sent before (the regression pin);
    - slice 1 receiving: TX goes to slice 0 and slice 1 stays active;
    - slice 1 receiving: a plain Split(True) keeps its old commands;
    - split off with slice 1 receiving returns TX to slice 1;
    - split is reported as "TX slice is not the active slice";
    - a key inside a longer key is not read as the key.

  NO TRANSPORT: the probe overrides SendToRadio(s) and drops the C<seq>|
  prefix, so this proves what the DRIVER emits, never what a radio accepts.
  That half is docs/BENCH_QUEUE.md.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioFlexAPI, VC, LogRadio;

type
   TFlexAPISplitTests = class(TTestCase)
   protected
      procedure Test_ActiveSliceIsTheReceiveVFO;
      procedure Test_Slice0Receiving_EntrySplitIsUnchanged;
      procedure Test_Slice0Receiving_SplitOffIsUnchanged;
      procedure Test_Slice1Receiving_EntrySplitTransmitsOnSlice0;
      procedure Test_Slice1Receiving_GenericSplitOnIsUnchanged;
      procedure Test_Slice1Receiving_SplitOffReturnsTXToSlice1;
      procedure Test_SplitIsTXSliceNotActiveSlice;
      procedure Test_Slice1Removed_ReceivesOnA;
      procedure Test_KeyInsideALongerKeyIsNotTheKey;
      procedure Test_EntryPath_Slice1Receiving_TunesSlice0;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TFlexAPIProbe = class(TFlexAPI)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
   end;

(* Each command as '<command>;', without the C<seq>| prefix: the sequence
  number depends on how many commands came before, which is not what these
  tests are about. *)
procedure TFlexAPIProbe.SendToRadio(s: string);
begin
   sent := sent + Copy(s, Pos('|', s) + 1, Length(s)) + ';';
end;

const
   SLICE0_ACTIVE = 'S1|slice 0 in_use=1 RF_frequency=14.025000 mode=CW tx=1 active=1 pan=0x40000000';
   SLICE1_PRESENT = 'S1|slice 1 in_use=1 RF_frequency=14.030000 mode=CW tx=0 active=0';
   SLICE1_ACTIVE = 'S1|slice 1 active=1';
   SLICE0_INACTIVE = 'S1|slice 0 active=0';

(* A Flex whose slices were reported by the radio itself -- through the real
  status parser, not SetActiveVFO -- with the capture emptied. *)
function NewFlex(slice1Receiving: boolean): TFlexAPIProbe;
begin
   Result := TFlexAPIProbe.Create;
   Result.ProcessMsg(SLICE0_ACTIVE);
   Result.ProcessMsg(SLICE1_PRESENT);
   if slice1Receiving then
      begin
      Result.ProcessMsg(SLICE0_INACTIVE);
      Result.ProcessMsg(SLICE1_ACTIVE);
      end;
   Result.sent := '';
end;

procedure TFlexAPISplitTests.Test_ActiveSliceIsTheReceiveVFO;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex: the active=1 slice is the receive VFO, and split TX is the other');
   r := NewFlex(False);
   try
      CheckEquals(Ord(nrVFOA), Ord(r.GetActiveVFO), 'slice 0 active -> receiving on A');
      CheckEquals(Ord(nrVFOB), Ord(r.SplitTransmitVFO), 'slice 0 active -> transmit on B');
      r.ProcessMsg(SLICE1_ACTIVE);
      CheckEquals(Ord(nrVFOB), Ord(r.GetActiveVFO), 'slice 1 active -> receiving on B');
      CheckEquals(Ord(nrVFOA), Ord(r.SplitTransmitVFO), 'slice 1 active -> transmit on A');
      r.ProcessMsg('S1|slice 0 active=1');
      CheckEquals(Ord(nrVFOA), Ord(r.GetActiveVFO), 'back to slice 0');
      (* A 0 alone moves nothing: the order of the two pushes is not promised. *)
      r.ProcessMsg(SLICE0_INACTIVE);
      CheckEquals(Ord(nrVFOA), Ord(r.GetActiveVFO), 'active=0 on its own does not move the receive VFO');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_Slice0Receiving_EntrySplitIsUnchanged;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex, slice 0 receiving: the entry''s split sends exactly the old commands');
   r := NewFlex(False);
   try
      r.SplitTransmittingOn(r.SplitTransmitVFO);
      CheckEquals('slice set 1 tx=1;slice set 0 tx=0;slice set 0 active=1;', r.sent,
                  'slice 0 receiving must be unchanged');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_Slice0Receiving_SplitOffIsUnchanged;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex, slice 0 receiving: Split(False) sends exactly the old commands');
   r := NewFlex(False);
   try
      r.Split(False);
      CheckEquals('slice set 0 tx=1;slice set 1 tx=0;', r.sent, 'slice 0 receiving must be unchanged');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_Slice1Receiving_EntrySplitTransmitsOnSlice0;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex, slice 1 receiving: the entry''s split transmits on slice 0 and keeps slice 1 active');
   r := NewFlex(True);
   try
      r.SplitTransmittingOn(r.SplitTransmitVFO);
      CheckEquals('slice set 0 tx=1;slice set 1 tx=0;slice set 1 active=1;', r.sent,
                  'TX to slice 0, receive stays on slice 1');
      CheckTrue(Pos('slice set 0 active=1', r.sent) = 0,
                'forcing slice 0 active pulls receive onto the TX frequency: the issue 259 defect');
      CheckTrue(r.IsSplitEnabled, 'TX on A while B receives is split');
   finally
      r.Free;
   end;
end;

(* The band map's QSX, WSJT-X and the TCI server write B and call Split(True).
  Following the receive slice there would transmit on slice 0 -- for a QSX
  click, the DX's own frequency. *)
procedure TFlexAPISplitTests.Test_Slice1Receiving_GenericSplitOnIsUnchanged;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex, slice 1 receiving: a plain Split(True) keeps its old commands');
   r := NewFlex(True);
   try
      r.Split(True);
      CheckEquals('slice set 1 tx=1;slice set 0 tx=0;slice set 0 active=1;', r.sent,
                  'band map / WSJT-X / TCI wrote B: TX stays on slice 1');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_Slice1Receiving_SplitOffReturnsTXToSlice1;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex, slice 1 receiving: Split(False) puts TX back on slice 1');
   r := NewFlex(True);
   try
      r.SplitTransmittingOn(nrVFOA);
      r.sent := '';
      r.Split(False);
      CheckEquals('slice set 1 tx=1;slice set 0 tx=0;', r.sent, 'split off = transmit on the receive slice');
      CheckFalse(r.IsSplitEnabled, 'TX on the receive slice is not split');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_SplitIsTXSliceNotActiveSlice;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex: split is reported when the TX slice is not the active slice');
   r := NewFlex(False);
   try
      CheckFalse(r.IsSplitEnabled, 'slice 0 transmits and receives: no split');
      r.ProcessMsg('S1|slice 0 tx=0');
      r.ProcessMsg('S1|slice 1 tx=1');
      CheckTrue(r.IsSplitEnabled, 'slice 1 transmits, slice 0 receives: split (as before)');
      r.ProcessMsg(SLICE1_ACTIVE);
      CheckFalse(r.IsSplitEnabled, 'slice 1 transmits and receives: no split');
      r.ProcessMsg('S1|slice 1 tx=0');
      CheckTrue(r.IsSplitEnabled, 'slice 0 transmits, slice 1 receives: split -- reported as off before issue 259');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_Slice1Removed_ReceivesOnA;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex: slice 1 removed while receiving -> receive VFO back to A');
   r := NewFlex(True);
   try
      r.ProcessMsg('S1|slice 1 in_use=0');
      CheckEquals(Ord(nrVFOA), Ord(r.GetActiveVFO), 'a removed slice cannot be receiving');
      CheckEquals(Ord(nrVFOB), Ord(r.SplitTransmitVFO), 'and split TX is B again');
   finally
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.Test_KeyInsideALongerKeyIsNotTheKey;
var
   r: TFlexAPIProbe;
begin
   BeginTest('Flex: fm_tone_mode= is not mode=, and x_active= is not active=');
   r := NewFlex(False);
   try
      (* Synthetic values: a real fm_tone_mode is OFF or a tone, which the
        mode map would ignore anyway, so USB is used to make a misread visible. *)
      r.ProcessMsg('S1|slice 1 fm_tone_mode=USB dax_active=1');
      CheckEquals(Ord(nrVFOA), Ord(r.GetActiveVFO), 'dax_active=1 must not make slice 1 active');
      CheckEquals(Ord(rmCW), Ord(r.mode[nrVFOB]), 'fm_tone_mode= must not be read as the slice mode');
   finally
      r.Free;
   end;
end;

(* The entry path as tr4w_alt_n_transmit_frequency drives it.  Radio1 is
  borrowed and restored, as uTestKenwoodLANSplit does. *)
procedure TFlexAPISplitTests.Test_EntryPath_Slice1Receiving_TunesSlice0;
var
   r: TFlexAPIProbe;
   savedFactory: TFactoryRadioBase;
   savedCommanded: integer;
   letter: char;
begin
   BeginTest('Entry path, Flex slice 1 receiving: slice 0 is tuned, then TX moves to it');
   r := NewFlex(True);
   savedFactory := Radio1.tFactoryObject;
   savedCommanded := Radio1.tCommandedQSYFreq;
   try
      Radio1.tFactoryObject := r;
      letter := Radio1.SplitTransmitVFOLetter;
      CheckEquals('A', string(letter), 'the TX letter is A while slice 1 receives');
      Radio1.SetRadioFreq(14025000, CW, letter);
      Radio1.PutRadioIntoSplitTransmittingOn(letter);
      CheckEquals(1, Pos('slice tune 0 14.025000;', r.sent), 'slice 0 is tuned first -- got ' + r.sent);
      CheckTrue(Pos('slice tune 1', r.sent) = 0, 'the receive slice must not be retuned -- got ' + r.sent);
      CheckTrue(Pos('slice set 0 tx=1;slice set 1 tx=0;slice set 1 active=1;', r.sent) > 0,
                'then TX to slice 0 with slice 1 still active -- got ' + r.sent);
   finally
      Radio1.tFactoryObject := savedFactory;
      Radio1.tCommandedQSYFreq := savedCommanded;
      r.Free;
   end;
end;

procedure TFlexAPISplitTests.RunAllTests;
begin
   Test_ActiveSliceIsTheReceiveVFO;
   Test_Slice0Receiving_EntrySplitIsUnchanged;
   Test_Slice0Receiving_SplitOffIsUnchanged;
   Test_Slice1Receiving_EntrySplitTransmitsOnSlice0;
   Test_Slice1Receiving_GenericSplitOnIsUnchanged;
   Test_Slice1Receiving_SplitOffReturnsTXToSlice1;
   Test_SplitIsTXSliceNotActiveSlice;
   Test_Slice1Removed_ReceivesOnA;
   Test_KeyInsideALongerKeyIsNotTheKey;
   Test_EntryPath_Slice1Receiving_TunesSlice0;
end;

end.
