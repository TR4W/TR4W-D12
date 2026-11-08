unit uTestKenwoodLANSplit;
{$I ..\..\src\tr4w.inc}

(*
  Issue 38: split by the '-' key with VFO B receiving on a TS-890S.

  The transmit-frequency entry wrote the TX frequency to VFO B and called
  Split(True), and the LAN Kenwood sent FT1; -- correct while A receives, but
  with B receiving it put the TX frequency on the receive VFO and selected B to
  transmit as well: TX = RX = B, no split at all.

  The radio now names its split transmit VFO (TFactoryRadioBase.SplitTransmitVFO,
  base answer B).  The TS-890 answers the VFO it is NOT receiving on, and the
  entry splits through SplitTransmittingOn with that VFO.  These tests pin:
    - A receiving: exactly the bytes sent before (the regression pin);
    - B receiving: TX written to A, FT0; for the entry's split, FT1; for off;
    - B receiving: a plain Split(True), which the band map, WSJT-X and the TCI
      server call after writing B, still sends FT1;;
    - the TS-990, which shares the LAN base, is unchanged with B receiving;
    - over the WHOLE registry, with B made the receive VFO, every radio but the
      TS-890 still answers B -- so the override cannot leak into a family.

  NO TRANSPORT: the probes override SendToRadio and stand the driver in the
  authenticated state, so this proves what the DRIVER emits, never what a radio
  accepts.  That half is docs/BENCH_QUEUE.md.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uFactoryRadioBase, uRadioKenwoodLAN,
   uRadioKenwoodTS890, uRadioKenwoodTS990, uRadioRegistry, VC, LogRadio;

type
   TKenwoodLANSplitTests = class(TTestCase)
   protected
      procedure Test_TS890_AReceiving_SplitOnIsFT1;
      procedure Test_TS890_AReceiving_SplitOffIsFT0;
      procedure Test_TS890_BReceiving_SplitOnIsFT0;
      procedure Test_TS890_BReceiving_GenericSplitOnStaysFT1;
      procedure Test_TS890_BReceiving_SplitOffIsFT1;
      procedure Test_TS890_TransmitVFOFollowsFR;
      procedure Test_TS990_BReceiving_IsUnchanged;
      procedure Test_EntryPath_AReceiving_WritesBThenFT1;
      procedure Test_EntryPath_BReceiving_WritesAThenFT0;
      procedure Test_EntryPath_NoRadio_IsB;
      procedure Test_Registry_OnlyTheTS890FollowsTheReceiveVFO;
   public
      procedure RunAllTests; override;
   end;

implementation

type
   TTS890Probe = class(TKenwoodTS890Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
      procedure StandAuthenticated;
   end;

   TTS990Probe = class(TKenwoodTS990Radio)
   public
      sent: string;
      procedure SendToRadio(s: string); overload; override;
      procedure StandAuthenticated;
   end;

procedure TTS890Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TTS890Probe.StandAuthenticated;
begin
   FAuthState := ksAuthenticated;
end;

procedure TTS990Probe.SendToRadio(s: string);
begin
   sent := sent + s;
end;

procedure TTS990Probe.StandAuthenticated;
begin
   FAuthState := ksAuthenticated;
end;

(* An authenticated TS-890 whose receive VFO has been reported by the radio
  itself -- FR through the real parser, not SetActiveVFO -- with the capture
  emptied so a test sees only what it caused. *)
function NewTS890(const frReply: string): TTS890Probe;
begin
   Result := TTS890Probe.Create;
   Result.StandAuthenticated;
   Result.ProcessMessage(frReply);
   Result.sent := '';
end;

function NewTS990(const frReply: string): TTS990Probe;
begin
   Result := TTS990Probe.Create;
   Result.StandAuthenticated;
   Result.ProcessMessage(frReply);
   Result.sent := '';
end;

procedure TKenwoodLANSplitTests.Test_TS890_AReceiving_SplitOnIsFT1;
var
   r: TTS890Probe;
begin
   BeginTest('TS-890, A receiving: Split(True) sends FT1; exactly as before');
   r := NewTS890('FR0');
   try
      r.Split(True);
      CheckEquals('FT1;', r.sent, 'A receiving must be byte-for-byte unchanged');
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_TS890_AReceiving_SplitOffIsFT0;
var
   r: TTS890Probe;
begin
   BeginTest('TS-890, A receiving: Split(False) sends FT0; exactly as before');
   r := NewTS890('FR0');
   try
      r.Split(False);
      CheckEquals('FT0;', r.sent, 'A receiving must be byte-for-byte unchanged');
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_TS890_BReceiving_SplitOnIsFT0;
var
   r: TTS890Probe;
begin
   BeginTest('TS-890, B receiving: the entry''s split on A sends FT0;');
   r := NewTS890('FR1');
   try
      r.SplitTransmittingOn(r.SplitTransmitVFO);
      CheckEquals('FT0;', r.sent, 'TX must go to the VFO that is not receiving');
      CheckTrue(r.sent <> 'FT1;', 'FT1; with B receiving is TX = RX = B: the issue 38 defect');
   finally
      r.Free;
   end;
end;

(* The OTHER split-on callers -- band map QSX, WSJT-X, the TCI server -- write
  their TX frequency to B and call Split(True).  If Split(True) followed the
  receive VFO, a TS-890 receiving on B would transmit on A: for a QSX click,
  on the DX's own frequency.  So it must stay FT1; until those callers are
  routed through the split TX VFO themselves. *)
procedure TKenwoodLANSplitTests.Test_TS890_BReceiving_GenericSplitOnStaysFT1;
var
   r: TTS890Probe;
begin
   BeginTest('TS-890, B receiving: a plain Split(True) still sends FT1;');
   r := NewTS890('FR1');
   try
      r.Split(True);
      CheckEquals('FT1;', r.sent, 'band map / WSJT-X / TCI wrote TX to B; FT0; would transmit on A');
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_TS890_BReceiving_SplitOffIsFT1;
var
   r: TTS890Probe;
begin
   BeginTest('TS-890, B receiving: Split(False) puts TX back on B (FT1;)');
   r := NewTS890('FR1');
   try
      r.Split(False);
      CheckEquals('FT1;', r.sent, 'split off = transmit on the receive VFO');
      CheckTrue(r.sent <> 'FT0;', 'FT0; with B receiving would turn split ON, not off');
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_TS890_TransmitVFOFollowsFR;
var
   r: TTS890Probe;
begin
   BeginTest('TS-890: the split TX VFO follows each FR the radio reports');
   r := NewTS890('FR0');
   try
      CheckEquals(Ord(nrVFOB), Ord(r.SplitTransmitVFO), 'FR0 -> transmit on B');
      r.ProcessMessage('FR1');
      CheckEquals(Ord(nrVFOA), Ord(r.SplitTransmitVFO), 'FR1 -> transmit on A');
      r.ProcessMessage('FR0');
      CheckEquals(Ord(nrVFOB), Ord(r.SplitTransmitVFO), 'back to FR0 -> transmit on B');
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_TS990_BReceiving_IsUnchanged;
var
   r: TTS990Probe;
begin
   BeginTest('TS-990 (shares the LAN base), B receiving: still FT1; / FT0;');
   r := NewTS990('FR1');
   try
      CheckEquals(Ord(nrVFOB), Ord(r.SplitTransmitVFO), 'the TS-990 keeps the family answer');
      r.Split(True);
      CheckEquals('FT1;', r.sent, 'Split(True) unchanged on the TS-990');
      r.sent := '';
      r.Split(False);
      CheckEquals('FT0;', r.sent, 'Split(False) unchanged on the TS-990');
      r.sent := '';
      r.SplitTransmittingOn(r.SplitTransmitVFO);
      CheckEquals('FT1;', r.sent, 'the entry''s split is FT1; on the TS-990, as before');
   finally
      r.Free;
   end;
end;

(* The entry path as tr4w_alt_n_transmit_frequency drives it: the slot's
  SplitTransmitVFOLetter chooses the VFO, SetRadioFreq writes it, and
  PutRadioIntoSplit sends the split.  Radio1 is borrowed and restored. *)
function DriveEntry(r: TTS890Probe; freq: longint): string;
var
   savedFactory: TFactoryRadioBase;
   savedCommanded: integer;
   letter: char;
begin
   savedFactory := Radio1.tFactoryObject;
   savedCommanded := Radio1.tCommandedQSYFreq;
   try
      Radio1.tFactoryObject := r;
      letter := Radio1.SplitTransmitVFOLetter;
      Radio1.SetRadioFreq(freq, CW, letter);
      Radio1.PutRadioIntoSplitTransmittingOn(letter);
      Result := r.sent;
   finally
      Radio1.tFactoryObject := savedFactory;
      Radio1.tCommandedQSYFreq := savedCommanded;
   end;
end;

function EndsWith(const s, tail: string): boolean;
begin
   Result := (Length(s) >= Length(tail)) and
             (Copy(s, Length(s) - Length(tail) + 1, Length(tail)) = tail);
end;

procedure TKenwoodLANSplitTests.Test_EntryPath_AReceiving_WritesBThenFT1;
var
   r: TTS890Probe;
   wire: string;
begin
   BeginTest('Entry path, TS-890 A receiving: FB<freq>; ... FT1;');
   r := NewTS890('FR0');
   try
      wire := DriveEntry(r, 14025000);
      CheckEquals('FB00014025000;', Copy(wire, 1, 14), 'TX frequency goes to B, as before');
      CheckTrue(EndsWith(wire, 'FT1;'), 'then FT1; -- got ' + wire);
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_EntryPath_BReceiving_WritesAThenFT0;
var
   r: TTS890Probe;
   wire: string;
begin
   BeginTest('Entry path, TS-890 B receiving: FA<freq>; ... FT0;');
   r := NewTS890('FR1');
   try
      wire := DriveEntry(r, 14025000);
      CheckEquals('FA00014025000;', Copy(wire, 1, 14), 'TX frequency goes to A, not the receive VFO');
      CheckTrue(Pos('FB', wire) = 0, 'the receive VFO must not be retuned -- got ' + wire);
      CheckTrue(EndsWith(wire, 'FT0;'), 'then FT0; -- got ' + wire);
   finally
      r.Free;
   end;
end;

procedure TKenwoodLANSplitTests.Test_EntryPath_NoRadio_IsB;
var
   savedFactory: TFactoryRadioBase;
begin
   BeginTest('Entry path, no factory radio in the slot: the letter is B');
   savedFactory := Radio1.tFactoryObject;
   try
      Radio1.tFactoryObject := nil;
      CheckEquals('B', string(Radio1.SplitTransmitVFOLetter), 'an empty slot keeps the old answer');
   finally
      Radio1.tFactoryObject := savedFactory;
   end;
end;

(* EXHAUSTIVE, per CLAUDE.md note 9.  A fresh radio receives on A, where every
  radio -- the TS-890 included -- answers B, so asking a fresh radio proves
  nothing.  Make B the receive VFO first; then the only radio allowed to answer
  A is the one that overrides on purpose. *)
procedure TKenwoodLANSplitTests.Test_Registry_OnlyTheTS890FollowsTheReceiveVFO;
var
   ids: TArray<string>;
   id: string;
   r: TFactoryRadioBase;
   answeredA: string;
   answeredBWithA: string;
   checked: integer;
begin
   BeginTest('Registry: only the TS-890S moves its split TX VFO off B');
   answeredA := '';
   answeredBWithA := '';
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
         if r.SplitTransmitVFO <> nrVFOB then
            begin
            answeredBWithA := answeredBWithA + uRadioRegistry.DisplayNameId(id) + ' ';
            end;
         r.SetActiveVFO(nrVFOB);
         if r.SplitTransmitVFO = nrVFOA then
            begin
            answeredA := answeredA + uRadioRegistry.DisplayNameId(id) + ' ';
            end;
      finally
         r.Free;
      end;
      end;

   CheckTrue(checked > 0, 'the registry produced no radios to check');
   CheckEquals('', answeredBWithA, 'with A receiving every radio must answer B');
   CheckEquals('Kenwood TS-890S ', answeredA,
               'with B receiving only the TS-890S answers A; any other name here changed a radio''s split');
end;

procedure TKenwoodLANSplitTests.RunAllTests;
begin
   Test_TS890_AReceiving_SplitOnIsFT1;
   Test_TS890_AReceiving_SplitOffIsFT0;
   Test_TS890_BReceiving_SplitOnIsFT0;
   Test_TS890_BReceiving_GenericSplitOnStaysFT1;
   Test_TS890_BReceiving_SplitOffIsFT1;
   Test_TS890_TransmitVFOFollowsFR;
   Test_TS990_BReceiving_IsUnchanged;
   Test_EntryPath_AReceiving_WritesBThenFT1;
   Test_EntryPath_BReceiving_WritesAThenFT0;
   Test_EntryPath_NoRadio_IsB;
   Test_Registry_OnlyTheTS890FollowsTheReceiveVFO;
end;

end.
