{
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
}
unit uRadioYaesuFT891;

{
  Yaesu FT-891 -- the other rtYaesu3 radio, migrated from
  uRadioPolling.pFT891_FT991.

  Same 28-byte IF;/OI; and the same field offsets as the FT-991.  ONE difference,
  and it runs through three places:

  THE FT-891 HAS NO FT COMMAND AT ALL.  Split is ST instead:

                       FT-991 (and rtYaesu4)     FT-891
      read split       FT;                       ST;
      split on         FT3;                      ST1;
      split off        FT2;                      ST0;

  That is from the legacy source, not inference: pFT891_FT991 branches on the
  model to send ST; with the comment "891 does not have an FT command", and
  LOGRADIO's PutRadioIntoSplit/OutOfSplit give the FT-891 its own ST1;/ST0; arm
  separate from the FT3;/FT2; one.  This unit is what that branch becomes once the
  radio owns its own behaviour instead of the poller testing which model it is.

  So three overrides: PollRadioState (ask ST; not FT;), ProcessMessage (understand
  the ST reply), and Split (send ST).

  MODE MAP: inherits the Type3 meaning of 'E' (C4FM) from the shared table by
  setting FModeCharE, matching the legacy parser, which uses one map for both
  rtYaesu3 radios.  NOTE the doubt: the FT-891 is an HF/6m radio with no System
  Fusion, so it should never emit 'E' at all, and the legacy mapping looks like it
  was inherited from the FT-991 rather than established for this radio.  Kept as
  legacy has it -- changing a code the radio never sends would be churn, and if it
  DOES send 'E' for something else, only the manual or hardware can say what.

  ****  NOT BENCH-VALIDATED -- keep on the tester list  ****

  BENCH NOTES:
    - Split in every direction: set at the radio and seen at startup, and toggled
      from TR4W both ways.  ST is the whole reason this unit exists, so it is
      where a mistake would be.
    - Confirm ST; is answered as "ST" + digit.  The legacy poller reads a 4-byte
      reply and looks at the third character, which this driver matches, but it
      never validates the echo the way it does for IF/OI.
    - Whether 'E' ever appears in an IF response (see above).
}

interface

uses uFactoryRadioBase, uRadioYaesuASCII, uRadioRegistry, StrUtils, SysUtils, VC;

type
  TFT891Radio = class(TYaesuSerial)
  public
    constructor Create; reintroduce;
    procedure ProcessMessage(sMessage: string); override;
    procedure PollRadioState; override;
    procedure Split(splitOn: boolean); override;
  end;

implementation

constructor TFT891Radio.Create;
begin
   inherited Create;
   radioModel := 'Yaesu FT-891';
   FCapabilities.Flags := [rcReadVFOB, rcReadRIT, rcReadSplit, rcReadTXStatus];
   FCapabilities.CWSpeedMin := FCWSpeedMin;
   FCapabilities.CWSpeedMax := FCWSpeedMax;
   FModeCharE := rmFM;      // Type3 map, as legacy has it -- see the header
end;

procedure TFT891Radio.PollRadioState;
begin
   // ST; where the rest of the family asks FT;.  Sending FT; here would get no
   // answer at all, and split would silently never update.
   Self.SendToRadio('IF;OI;ST;TX;');
end;

procedure TFT891Radio.ProcessMessage(sMessage: string);
begin
   // Handle ST ourselves, then hand everything else to the shared dispatcher.
   // Deliberately NOT a copy of the base method: IF/OI/TX/FA/FB stay in one
   // place, so a fix there reaches this radio too.
   if (Length(sMessage) >= 3) and
      SameText(AnsiLeftStr(sMessage, 2), 'ST') then
      begin
      UpdateLastValidResponse;
      Self.SetSplitOn(sMessage[3] <> '0');
      Exit;
      end;

   inherited ProcessMessage(sMessage);
end;

procedure TFT891Radio.Split(splitOn: boolean);
begin
   if splitOn then
      begin
      Self.SendToRadio('ST1;');
      end
   else
      begin
      Self.SendToRadio('ST0;');
      end;
end;

initialization
  RegisterRadio(FT891,
     function: TFactoryRadioBase begin Result := TFT891Radio.Create end,
     'Yaesu FT-891', [rlSerial], 0, False,
     SerialParams(4800, 8, PARITY_NONE, 2)
     );

end.
