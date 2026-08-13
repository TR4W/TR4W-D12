program gate_a_async;

// FPC VIABILITY GATE A, part 2 -- ASYNCHRONOUS / UNSOLICITED serial data.
//
// Part 1 proved a request/response CAT round trip (we ask FA;, the radio
// answers).  That is the easy half.  TR4W's radio threads must also cope with
// data the radio sends when NOBODY ASKED -- which is what Elecraft AI2
// (Auto-Info level 2) produces every time the operator touches the VFO.
//
// This opens the K3S, enables AI2, reads for a fixed window while NY4I turns
// the knob, and reports what arrived and how it framed up.
//
// It restores AI0 on the way out.  NY4I's radio config records
// autoInfoLevel: 0 for this rig, so AI0 is the as-found state and the radio
// must be left in it.  The restore runs in a finally block so it happens even
// if the read loop raises.
//
// Usage:  gate_a_async.exe COM15 [seconds]

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

uses
   SysUtils,
   Classes,
   uSerialPort;

var
   port: TSerialPort;
   portName: string;
   window: Integer;
   acc: string;
   chunk: string;
   frames: TStringList;
   i, cut: Integer;
   started: TDateTime;
   elapsedMs: Integer;
   firstFrameMs: Integer;
   prefixes: TStringList;
   p: string;
   maxGapMs, lastMs, gap: Integer;

begin
   portName := ParamStr(1);
   if portName = '' then
      begin
      WriteLn('usage: gate_a_async.exe COM15 [seconds]');
      Halt(2);
      end;

   window := StrToIntDef(ParamStr(2), 20);

   frames := TStringList.Create;
   prefixes := TStringList.Create;
   prefixes.Sorted := True;
   prefixes.Duplicates := dupIgnore;

   port := TSerialPort.Create(portName);
   try
      port.Open(sbr38400, 8, spNone, ssb1);
      WriteLn('opened ', portName, ' @38400 8N1');

      // Drain anything already buffered so the count reflects this window.
      port.ReadString(4096);

      port.WriteString('AI2;');
      WriteLn('AI2 sent -- reading for ', window, ' seconds.');
      WriteLn('TURN THE VFO KNOB NOW.');
      WriteLn;

      try
         acc := '';
         firstFrameMs := -1;
         maxGapMs := 0;
         lastMs := 0;
         started := Now;

         repeat
            chunk := port.ReadString(4096);
            elapsedMs := Round((Now - started) * 24 * 60 * 60 * 1000);

            if chunk <> '' then
               begin
               acc := acc + chunk;

               // Elecraft frames terminate with ';'.  Split on it so we count
               // COMMANDS, not read() calls -- a driver that counts reads is
               // measuring the OS buffer, not the radio.
               cut := Pos(';', acc);
               while cut > 0 do
                  begin
                  p := Copy(acc, 1, cut);
                  acc := Copy(acc, cut + 1, Length(acc));
                  frames.Add(p);

                  if firstFrameMs < 0 then
                     begin
                     firstFrameMs := elapsedMs;
                     end;

                  gap := elapsedMs - lastMs;
                  if (lastMs > 0) and (gap > maxGapMs) then
                     begin
                     maxGapMs := gap;
                     end;
                  lastMs := elapsedMs;

                  if Length(p) >= 2 then
                     begin
                     prefixes.Add(Copy(p, 1, 2));
                     end;

                  cut := Pos(';', acc);
                  end;
               end
            else
               begin
               Sleep(10);
               end;
         until elapsedMs >= window * 1000;
      finally
         // Leave the radio as we found it.
         port.WriteString('AI0;');
         Sleep(150);
         port.ReadString(4096);
      end;

      WriteLn('unsolicited frames : ', frames.Count);
      if frames.Count > 0 then
         begin
         WriteLn('first frame after  : ', firstFrameMs, ' ms');
         WriteLn('largest gap        : ', maxGapMs, ' ms');
         Write  ('command prefixes   : ');
         for i := 0 to prefixes.Count - 1 do
            begin
            Write(prefixes[i], ' ');
            end;
         WriteLn;
         WriteLn;
         WriteLn('sample (first 12):');
         for i := 0 to frames.Count - 1 do
            begin
            if i >= 12 then
               begin
               Break;
               end;
            WriteLn('  ', frames[i]);
            end;
         if frames.Count > 12 then
            begin
            WriteLn('  ... and ', frames.Count - 12, ' more');
            end;
         end;

      WriteLn;
      if acc <> '' then
         begin
         WriteLn('NOTE: ', Length(acc), ' trailing bytes with no terminator: "', acc, '"');
         end;

      port.Close;
      WriteLn('AI0 restored, port closed.');

      if frames.Count = 0 then
         begin
         WriteLn;
         WriteLn('RESULT: FAIL -- no unsolicited data arrived.');
         Halt(1);
         end
      else
         begin
         WriteLn;
         WriteLn('RESULT: PASS -- async CAT stream received and framed under FPC.');
         end;
   finally
      port.Free;
      frames.Free;
      prefixes.Free;
   end;
end.
