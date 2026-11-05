unit uTestLogPack;
{$I ..\..\src\tr4w.inc}

(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 *)

(* THE TNC PACKET OBJECT, THE PARTS THAT HAVE NO SERIAL PORT IN THEM.
  Pointer audit item 6.6 (docs/POINTER_AUDIT.md), Issue 89, 2026-11-05.

  WHY IT EXISTS. logpack.PacketObject was an old-style `object` held by value
  in the global Packet. NY4I's ruling: TNC packet over a serial port is a
  supported option, so the object is converted to a class, not deleted. This
  unit pins what the object does WITHOUT a port -- the Control-U spot memory
  (a ring of eleven cells with a start and an end), removing a spot from it,
  and the display line buffer (a ring of thirteen lines) -- so the
  conversion can be shown to change nothing.

  It was written and run GREEN against the old-style object first, and only
  then was the type converted; the expected values are the ring arithmetic
  read from the code, not regenerated to clear a failure.

  It works on the global Packet and calls Init first, which is how it reads
  the same under a value object and a class. *)

interface

uses
   SysUtils, uTR4WTestFramework, VC, Tree, LogPack;

type
   TLogPackTests = class(TTestCase)
   private
      procedure ResetPacket;
      function Spot(const aCall: string; aMode: SpotModeType): DXSpotType;
      procedure PushNormal(const aCall: string);
      function MemoryCalls(aFrom, aTo: integer): string;
   protected
      procedure Test_Init_ClearsTheRings;
      procedure Test_NormalSpot_GoesToTheFront;
      procedure Test_ShDxSpot_GoesToTheBack;
      procedure Test_MemoryRing_WrapsAndDropsTheOldestEnd;
      procedure Test_DeletePacketSpot_AtTheStart;
      procedure Test_DeletePacketSpot_InTheMiddle;
      procedure Test_DisplayLine_CompleteLinesAreBuffered;
      procedure Test_DisplayLine_IncompleteLineIsKept;
      procedure Test_DisplayLine_BellsAndLeadingBreaksAreDropped;
      procedure Test_DisplayLine_RingOfThirteenWraps;
      procedure Test_NetworkMessage_StoresNothing;
      procedure Test_SerialPortDefault_IsNoPort;
   public
      procedure RunAllTests; override;
   end;

implementation

procedure TLogPackTests.ResetPacket;
begin
   Packet.Init;
   Packet.PacketLogFileName := '';
   Packet.PacketSerialPort := NoPort;
end;

function TLogPackTests.Spot(const aCall: string; aMode: SpotModeType): DXSpotType;
begin
   Result.Call := aCall;
   Result.Frequency := 14025000;
   Result.QSXFrequency := 0;
   Result.TimeString := '1830Z';
   Result.SpotMode := aMode;
end;

procedure TLogPackTests.PushNormal(const aCall: string);
begin
   Packet.PushPacketMemory(Spot(aCall, NormalSpot));
end;

function TLogPackTests.MemoryCalls(aFrom, aTo: integer): string;
var
   i: integer;
begin
   Result := '';
   for i := aFrom to aTo do
      begin
      if Result <> '' then
         begin
         Result := Result + ',';
         end;
      Result := Result + string(Packet.PacketMemory[i].Call);
      end;
end;

procedure TLogPackTests.Test_Init_ClearsTheRings;
begin
   BeginTest('Test_Init_ClearsTheRings');
   Packet.PacketMemoryStart := 5;
   Packet.PacketMemoryEnd := 7;
   Packet.PacketDisplayBufferStart := 3;
   Packet.PacketDisplayBufferEnd := 4;
   Packet.PacketInputFileName := 'x';
   Packet.PacketInputFileOpen := True;
   Packet.Init;
   CheckEquals(0, Packet.PacketMemoryStart, 'memory start');
   CheckEquals(0, Packet.PacketMemoryEnd, 'memory end');
   CheckEquals(0, Packet.PacketDisplayBufferStart, 'display start');
   CheckEquals(0, Packet.PacketDisplayBufferEnd, 'display end');
   CheckEquals('', string(Packet.PacketInputFileName), 'input file name');
   CheckFalse(Packet.PacketInputFileOpen, 'input file open');
   CheckEquals(1, PacketInputFileDelay, 'input file delay');
end;

procedure TLogPackTests.Test_NormalSpot_GoesToTheFront;
begin
   BeginTest('Test_NormalSpot_GoesToTheFront');
   ResetPacket;
   PushNormal('K1AAA');
   CheckEquals(10, Packet.PacketMemoryStart, 'first push wraps start to the last cell');
   CheckEquals(0, Packet.PacketMemoryEnd, 'end does not move');
   PushNormal('K1BBB');
   PushNormal('K1CCC');
   CheckEquals(8, Packet.PacketMemoryStart, 'third push');
   CheckEquals('K1CCC,K1BBB,K1AAA', MemoryCalls(8, 10), 'newest first');
   CheckEquals('14025000', IntToStr(Packet.PacketMemory[8].Frequency), 'frequency');
   CheckEquals('1830Z', string(Packet.PacketMemory[8].Time), 'time');
end;

procedure TLogPackTests.Test_ShDxSpot_GoesToTheBack;
begin
   BeginTest('Test_ShDxSpot_GoesToTheBack');
   ResetPacket;
   Packet.PushPacketMemory(Spot('K1AAA', SHDXSpot));
   Packet.PushPacketMemory(Spot('K1BBB', SHDXSpot));
   CheckEquals(0, Packet.PacketMemoryStart, 'start stays');
   CheckEquals(2, Packet.PacketMemoryEnd, 'end advances');
   CheckEquals('K1AAA,K1BBB', MemoryCalls(0, 1), 'oldest first');
end;

procedure TLogPackTests.Test_MemoryRing_WrapsAndDropsTheOldestEnd;
var
   i: integer;
begin
   BeginTest('Test_MemoryRing_WrapsAndDropsTheOldestEnd');
   ResetPacket;
   for i := 1 to 11 do
      begin
      PushNormal('K1' + Chr(Ord('A') + i - 1) + 'XX');
      end;
   CheckEquals(0, Packet.PacketMemoryStart, 'start after eleven');
   CheckEquals(10, Packet.PacketMemoryEnd, 'start met end, so end backed up');
   PushNormal('K1LXX');
   CheckEquals(10, Packet.PacketMemoryStart, 'twelfth push wraps start');
   CheckEquals(9, Packet.PacketMemoryEnd, 'end backs up again');
   CheckEquals('K1LXX', string(Packet.PacketMemory[10].Call), 'newest in the cell');
end;

procedure TLogPackTests.Test_DeletePacketSpot_AtTheStart;
begin
   BeginTest('Test_DeletePacketSpot_AtTheStart');
   ResetPacket;
   PushNormal('K1AAA');
   PushNormal('K1BBB');
   Packet.DeletePacketSpot(Packet.PacketMemoryStart);
   CheckEquals(10, Packet.PacketMemoryStart, 'start moved past the deleted cell');
   CheckEquals('K1AAA', string(Packet.PacketMemory[Packet.PacketMemoryStart].Call), 'what remains');
end;

procedure TLogPackTests.Test_DeletePacketSpot_InTheMiddle;
begin
   BeginTest('Test_DeletePacketSpot_InTheMiddle');
   ResetPacket;
   PushNormal('K1AAA');
   PushNormal('K1BBB');
   PushNormal('K1CCC');
   Packet.DeletePacketSpot(9);
   CheckEquals(8, Packet.PacketMemoryStart, 'start');
   CheckEquals(10, Packet.PacketMemoryEnd, 'end backed up by one');
   CheckEquals('K1CCC,K1AAA', MemoryCalls(8, 9), 'B is gone, A closed up');
end;

procedure TLogPackTests.Test_DisplayLine_CompleteLinesAreBuffered;
var
   line: string;
begin
   BeginTest('Test_DisplayLine_CompleteLinesAreBuffered');
   ResetPacket;
   line := 'FIRST LINE' + CarriageReturn + LineFeed + 'SECOND' + CarriageReturn + LineFeed;
   Packet.CheckPacketDisplayLine(line);
   CheckEquals('', line, 'everything consumed');
   CheckEquals(0, Packet.PacketDisplayBufferStart, 'start');
   CheckEquals(2, Packet.PacketDisplayBufferEnd, 'end');
   CheckEquals('FIRST LINE', string(Packet.PacketDisplayBuffer[0]), 'line 0');
   CheckEquals('SECOND', string(Packet.PacketDisplayBuffer[1]), 'line 1');
end;

procedure TLogPackTests.Test_DisplayLine_IncompleteLineIsKept;
var
   line: string;
begin
   BeginTest('Test_DisplayLine_IncompleteLineIsKept');
   ResetPacket;
   line := 'DONE' + CarriageReturn + LineFeed + 'PARTIAL';
   Packet.CheckPacketDisplayLine(line);
   CheckEquals('PARTIAL', line, 'the unfinished tail stays for the next read');
   CheckEquals(1, Packet.PacketDisplayBufferEnd, 'one line buffered');
   CheckEquals('DONE', string(Packet.PacketDisplayBuffer[0]), 'line 0');
end;

procedure TLogPackTests.Test_DisplayLine_BellsAndLeadingBreaksAreDropped;
var
   line: string;
begin
   BeginTest('Test_DisplayLine_BellsAndLeadingBreaksAreDropped');
   ResetPacket;
   line := LineFeed + CarriageReturn + 'AB' + ControlG + 'C' + CarriageReturn + LineFeed;
   Packet.CheckPacketDisplayLine(line);
   CheckEquals('', line, 'consumed');
   CheckEquals(1, Packet.PacketDisplayBufferEnd, 'one line');
   CheckEquals('ABC', string(Packet.PacketDisplayBuffer[0]), 'no bell, no leading breaks');
end;

procedure TLogPackTests.Test_DisplayLine_RingOfThirteenWraps;
var
   i   : integer;
   line: string;
begin
   BeginTest('Test_DisplayLine_RingOfThirteenWraps');
   ResetPacket;
   for i := 1 to 13 do
      begin
      line := 'L' + IntToStr(i) + CarriageReturn + LineFeed;
      Packet.CheckPacketDisplayLine(line);
      end;
   CheckEquals(0, Packet.PacketDisplayBufferEnd, 'end wrapped');
   CheckEquals(1, Packet.PacketDisplayBufferStart, 'start pushed past the overwritten cell');
   CheckEquals('L13', string(Packet.PacketDisplayBuffer[12]), 'newest in the last cell');
   CheckEquals('L2', string(Packet.PacketDisplayBuffer[1]), 'oldest kept: the ring holds twelve lines');
end;

procedure TLogPackTests.Test_NetworkMessage_StoresNothing;
begin
   BeginTest('Test_NetworkMessage_StoresNothing');
   ResetPacket;
   Packet.ProcessPacketMessageFromNetWork('DX de K1ABC:  14025.0  K1XYZ  CW  1830Z');
   CheckEquals(0, Packet.PacketMemoryEnd, 'the message path stores nothing');
   CheckEquals(0, Packet.PacketMemoryStart, 'start');
end;

procedure TLogPackTests.Test_SerialPortDefault_IsNoPort;
begin
   BeginTest('Test_SerialPortDefault_IsNoPort');
   ResetPacket;
   CheckTrue(Packet.PacketSerialPort = NoPort, 'no TNC port until configured');
end;

procedure TLogPackTests.RunAllTests;
begin
   Test_Init_ClearsTheRings;
   Test_NormalSpot_GoesToTheFront;
   Test_ShDxSpot_GoesToTheBack;
   Test_MemoryRing_WrapsAndDropsTheOldestEnd;
   Test_DeletePacketSpot_AtTheStart;
   Test_DeletePacketSpot_InTheMiddle;
   Test_DisplayLine_CompleteLinesAreBuffered;
   Test_DisplayLine_IncompleteLineIsKept;
   Test_DisplayLine_BellsAndLeadingBreaksAreDropped;
   Test_DisplayLine_RingOfThirteenWraps;
   Test_NetworkMessage_StoresNothing;
   Test_SerialPortDefault_IsNoPort;
end;

end.
