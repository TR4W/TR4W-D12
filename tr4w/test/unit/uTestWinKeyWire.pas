unit uTestWinKeyWire;
{$I ..\..\src\tr4w.inc}

(*
  THE BYTES TR4W PUTS ON A WINKEYER'S SERIAL LINE, PINNED WITHOUT A KEYER.

  Written for P12 (docs/POINTER_AUDIT.md, 2026-10-18) BEFORE wkWriteRaw and
  wkSendAdminCommand lost their untyped buffers, and green against them:

    the LOAD DEFAULTS value list   wkOpen sends it as one 16-byte write. It
                                   used to go out as the record's memory image
                                   -- so its order WAS its field order, and a
                                   reordered or widened field would have keyed
                                   the wrong speed, weight or pin set with
                                   nothing to say so
    the admin commands             two raw bytes each, $00 + sub-command.
                                   These went out as 00 00 (CALIBRATE) under
                                   Delphi 12 when they were character literals;
                                   see the note on the constants in uWinKey

  Nothing here opens a port. What reaches the device past these bytes is the
  serial transport's job, and the bench's.
*)

interface

uses
   SysUtils, uTR4WTestFramework;

type
   TWinKeyWireTests = class(TTestCase)
   protected
      procedure Test_ValueListIsSixteenBytesInFieldOrder;
      procedure Test_AdminCommandsAreTheirTwoBytes;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uWinKey;

(* WHAT wkOpen WRITES FOR A VALUE LIST. Before P12 this read the record's
  memory image, which is what wkOpen sent then; it now asks the encoder wkOpen
  sends from. The expected bytes below did not change. *)
function ValueListWireBytes(const aList: TwkValueList): TBytes;
var
   wire: TwkValueListWire;
   i: integer;
begin
   wire := wkValueListBytes(aList);
   SetLength(Result, Length(wire));
   for i := 0 to High(wire) do
      begin
      Result[i] := wire[i];
      end;
end;

procedure TWinKeyWireTests.Test_ValueListIsSixteenBytesInFieldOrder;
var
   list: TwkValueList;
   wire: TBytes;
   i: integer;
begin
   BeginTest('Test_ValueListIsSixteenBytesInFieldOrder');
   (* Every field a different value, so a swapped pair cannot pass. The order
     is the WinKeyer 2 datasheet's LOAD DEFAULTS order, which is the record's. *)
   list.vlCommandCode       := 1;
   list.vlModeRegister      := 2;
   list.vlSpeedinWPM        := 3;
   list.vlSidetoneFrequency := TWKSidetoneFrequency(4);
   list.vlWeight            := 5;
   list.vlLeadInTime        := 6;
   list.vlTailTime          := 7;
   list.vlMinWPM            := 8;
   list.vlWPMRange          := 9;
   list.vl1stExtension      := 10;
   list.vlKeyCompensation   := 11;
   list.vlFarnsworthWPM     := 12;
   list.vlPaddleSWPoint     := 13;
   list.vlDitDahRatio       := 14;
   list.vlPinConfiguration  := 15;
   list.vlDontcare          := 16;

   wire := ValueListWireBytes(list);
   CheckEquals(16, Length(wire), 'the value list is sixteen bytes on the wire');
   for i := 0 to 15 do
      begin
      CheckEquals(i + 1, wire[i], Format('byte %d', [i]));
      end;
end;

procedure TWinKeyWireTests.Test_AdminCommandsAreTheirTwoBytes;
   procedure CheckCommand(const aCommand: array of Byte; const aSub: Byte;
                          const aName: string);
   begin
      CheckEquals(2, Length(aCommand), aName + ' is two bytes');
      CheckEquals(0, aCommand[0], aName + ' starts with the admin prefix $00');
      CheckEquals(aSub, aCommand[1], aName + ' sub-command');
   end;
begin
   BeginTest('Test_AdminCommandsAreTheirTwoBytes');
   CheckCommand(wkCALIBRATE,  $00, 'CALIBRATE');
   CheckCommand(wkRESET,      $01, 'RESET');
   CheckCommand(wkHOSTOPEN,   $02, 'HOST OPEN');
   CheckCommand(wkHOSTCLOSE,  $03, 'HOST CLOSE');
   CheckCommand(wkECHOTEST,   $04, 'ECHO TEST');
   CheckCommand(wkGETVALUES,  $07, 'GET VALUES');
   CheckCommand(wkSETWK1MODE, $0A, 'SET WK1 MODE');
   CheckCommand(wkSETWK2MODE, $0B, 'SET WK2 MODE');
end;

procedure TWinKeyWireTests.RunAllTests;
begin
   Test_ValueListIsSixteenBytesInFieldOrder;
   Test_AdminCommandsAreTheirTwoBytes;
end;

end.
