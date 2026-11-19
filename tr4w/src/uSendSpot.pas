{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 }
unit uSendSpot;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  uNet,
  LogStuff,
  LogK1EA,
  LogWind,
  LogRadio,
  LogEdit,
  PostUnit;

{
  THE SEND-SPOT SEAM.  The dialog itself is now an LCL form --
  src\ui\lcl\uSendSpotForm.pas -- and this unit is the entry point only.

  DELETED here, not wrapped (Phase 4a): SendSpotDlgProc, its CreateStatic /
  CreateEdit loop, the BN_CLICKED arm that mirrored the tick into the comment
  field, and the pointer-built spot string.  A LANG_RUS-only help arm went with
  them: it answered control id 110, which no arm of this dialog ever created.
}

// the Send Spot dialog.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
//
// Phase 4a, 2026-08-18: that is exactly what happened, and no call site moved.
procedure ShowSendSpot;

(* THE ONE WAY A SPOT LEAVES THE PROGRAM (issue 188): the Send Spot dialog and
  the self-spot (uSelfSpot) both post through it, so they cannot drift.

  Byte-for-byte as the dialog's pointer version built it: 'DX', then each field
  with exactly one leading space whether or not the field is empty. Up the
  cluster link when it is connected, else through the TR4W network's
  spot-via-network record. Returns False -- and sends nothing -- when neither
  is up; the dialog ignores that, as it always has, and a self-spot reports it. *)
function SendDXSpot(const aCall, aFreqText, aComment: string): boolean;

implementation

uses
  uTelnet,       // TelnetIsConnected, SendViaTelnetSocket
  uSendSpotForm;

function SendDXSpot(const aCall, aFreqText, aComment: string): boolean;
var
  spot: AnsiString;
begin
   spot := AnsiString('DX' +
                      ' ' + aCall +
                      ' ' + aFreqText +
                      ' ' + aComment);

   if TelnetIsConnected then
      begin
      SendViaTelnetSocket(spot);
      Result := True;
      end
   else
      if NetIsConnected then
         begin
         // uNet builds the fixed 46-byte record, sets its id and bounds the copy.
         SendSpotViaNetworkToNet(spot);
         Result := True;
         end
      else
         begin
         Result := False;
         end;
end;

procedure ShowSendSpot;
begin
   uSendSpotForm.ShowSendSpot;
end;

end.
