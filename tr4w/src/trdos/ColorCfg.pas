{
 Copyright Larry Tyree, N6TR, 2011,2012,2013,2014,2015.

 This file is part of TR4W    (TRDOS)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W.  If not, see
 <http: www.gnu.org/licenses/>.
 }
unit ColorCfg;
{$I ..\tr4w.inc}

interface

uses
  VC,
  Tree,
  LogWind;

{ This file contains the configuration commands for setting the
  different window colors.  There is one complete set for the color
  mode and another for monochrome.  Setting the DISPLAY MODE option
  will select the one you want.  This allows you to set up your
  favorite colors when using a color monitor, but keep the setting you
  may like best when you use your monochrome laptop.

  As with the LOGCFG.PAS file, the ID is the first part of the configuration
  command and CMD is what you put after the equal sign.  An example:

  Color Color Alarm Window = Yellow

  This command will set the character color in the Alarm Window to Yellow
  if you are in the color display mode.

  The possible colors are:

  Black, Blue, Green, Cyan, Red, Magenta, Brown, LightGray, DarkGray, Yellow,
  LightBlue, LightGreen, LightCyan, LightRed, LightMagenta, and White.

  }
function ValidColorCommand(CMD: Str80; ID: Str80): boolean;
implementation

function ValidColorCommand(CMD: Str80; ID: Str80): boolean;

begin
  ValidColorCommand := False;
  if not ((StringHas(CMD, 'COLOR')) or (StringHas(CMD, 'BACKGROUND'))) then Exit;
  if not StringHas(CMD, 'WINDOW') then Exit;
  ValidColorCommand := True;

  if CMD = 'ALARM WINDOW COLOR' then
     begin
     ColorColors.AlarmWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'ALARM WINDOW BACKGROUND' then
     begin
     ColorColors.AlarmWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'BAND MAP WINDOW COLOR' then
     begin
     ColorColors.BandMapWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'BAND MAP WINDOW BACKGROUND' then
     begin
     ColorColors.BandMapWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'BAND MODE WINDOW COLOR' then
     begin
     ColorColors.BandModeWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'BAND MODE WINDOW BACKGROUND' then
     begin
     ColorColors.BandModeWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'BEAM HEADING WINDOW COLOR' then
     begin
     ColorColors.BeamHeadingWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'BEAM HEADING WINDOW BACKGROUND' then
     begin
     ColorColors.BeamHeadingWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'BIG WINDOW COLOR' then
     begin
     ColorColors.BigWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'BIG WINDOW BACKGROUND' then
     begin
     ColorColors.BigWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'CALL WINDOW COLOR' then
     begin
     ColorColors.CallWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'CALL WINDOW BACKGROUND' then
     begin
     ColorColors.CallWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'CLOCK WINDOW COLOR' then
     begin
     ColorColors.ClockWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'CLOCK WINDOW BACKGROUND' then
     begin
     ColorColors.ClockWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'CODE SPEED WINDOW COLOR' then
     begin
     ColorColors.CodeSpeedWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'CODE SPEED WINDOW BACKGROUND' then
     begin
     ColorColors.CodeSpeedWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'CONTEST TITLE WINDOW COLOR' then
     begin
     ColorColors.ContestTitleWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'CONTEST TITLE WINDOW BACKGROUND' then
     begin
     ColorColors.ContestTitleWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'DATE WINDOW COLOR' then
     begin
     ColorColors.DateWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'DATE WINDOW BACKGROUND' then
     begin
     ColorColors.DateWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'DUPE INFO WINDOW COLOR' then
     begin
     ColorColors.DupeInfoWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'DUPE INFO WINDOW BACKGROUND' then
     begin
     ColorColors.DupeInfoWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'DUPESHEET WINDOW COLOR' then
     begin
     ColorColors.DupeSheetWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'DUPESHEET WINDOW BACKGROUND' then
     begin
     ColorColors.DupeSheetWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'EDITABLE LOG WINDOW COLOR' then
     begin
     ColorColors.EditableLogWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'EDITABLE LOG WINDOW BACKGROUND' then
     begin
     ColorColors.EditableLogWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'EXCHANGE WINDOW COLOR' then
     begin
     ColorColors.ExchangeWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'EXCHANGE WINDOW BACKGROUND' then
     begin
     ColorColors.ExchangeWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'EXCHANGE WINDOW S&P BACKGROUND' then
     begin
     ColorColors.ExchangeSAndPWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'FREE MEMORY WINDOW COLOR' then
     begin
     ColorColors.FreeMemoryWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'FREE MEMORY WINDOW BACKGROUND' then
     begin
     ColorColors.FreeMemoryWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'FUNCTION KEY WINDOW COLOR' then
     begin
     ColorColors.FunctionKeyWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'FUNCTION KEY WINDOW BACKGROUND' then
     begin
     ColorColors.FunctionKeyWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'INSERT WINDOW COLOR' then
     begin
     ColorColors.InsertWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'INSERT WINDOW BACKGROUND' then
     begin
     ColorColors.InsertWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'MULTIPLIER INFORMATION WINDOW COLOR' then
     begin
     ColorColors.MultiplierInformationWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'MULTIPLIER INFORMATION WINDOW BACKGROUND' then
     begin
     ColorColors.MultiplierInformationWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'NAME PERCENTAGE WINDOW COLOR' then
     begin
     ColorColors.NamePercentageWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'NAME PERCENTAGE WINDOW BACKGROUND' then
     begin
     ColorColors.NamePercentageWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'NAME SENT WINDOW COLOR' then
     begin
     ColorColors.NameSentWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'NAME SENT WINDOW BACKGROUND' then
     begin
     ColorColors.NameSentWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'POSSIBLE CALL WINDOW COLOR' then
     begin
     ColorColors.PossibleCallWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'POSSIBLE CALL WINDOW BACKGROUND' then
     begin
     ColorColors.PossibleCallWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'POSSIBLE CALL WINDOW DUPE COLOR' then
     begin
     ColorColors.PossibleCallWindowDupeColor := GetColorInteger(ID);
     end;

  if CMD = 'POSSIBLE CALL WINDOW DUPE BACKGROUND' then
     begin
     ColorColors.PossibleCallWindowDupeBackground := GetColorInteger(ID);
     end;

  if CMD = 'QSO INFORMATION WINDOW COLOR' then
     begin
     ColorColors.QSOInformationWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'QSO INFORMATION WINDOW BACKGROUND' then
     begin
     ColorColors.QSOInformationWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'QSO NUMBER WINDOW COLOR' then
     begin
     ColorColors.QSONumberWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'QSO NUMBER WINDOW BACKGROUND' then
     begin
     ColorColors.QSONumberWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'QTC NUMBER WINDOW COLOR' then
     begin
     ColorColors.QTCNumberWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'QTC NUMBER WINDOW BACKGROUND' then
     begin
     ColorColors.QTCNumberWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'QUICK COMMAND WINDOW COLOR' then
     begin
     ColorColors.QuickCommandWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'QUICK COMMAND WINDOW BACKGROUND' then
     begin
     ColorColors.QuickCommandWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'RADIO WINDOW COLOR' then {KK1L: 6.73}
     begin
     ColorColors.RadioOneWindowColor := GetColorInteger(ID);
     ColorColors.RadioTwoWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'RADIO WINDOW BACKGROUND' then {KK1L: 6.73}
     begin
     ColorColors.RadioOneWindowBackground := GetColorInteger(ID);
     ColorColors.RadioTwoWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'RADIO ONE WINDOW COLOR' then {KK1L: 6.73}
     begin
     ColorColors.RadioOneWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'RADIO ONE WINDOW BACKGROUND' then {KK1L: 6.73}
     begin
     ColorColors.RadioOneWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'RADIO TWO WINDOW COLOR' then {KK1L: 6.73}
     begin
     ColorColors.RadioTwoWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'RADIO TWO WINDOW BACKGROUND' then {KK1L: 6.73}
     begin
     ColorColors.RadioTwoWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'RATE WINDOW COLOR' then
     begin
     ColorColors.RateWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'RATE WINDOW BACKGROUND' then
     begin
     ColorColors.RateWindowBackground := GetColorInteger(ID);
     end;

//  if CMD = 'RTTY WINDOW COLOR' then
//    ColorColors.RTTYWindowColor := GetColorInteger(ID);

//  if CMD = 'RTTY WINDOW BACKGROUND' then
//    ColorColors.RTTYWindowBackground := GetColorInteger(ID);

//  if CMD = 'RTTY INVERSE WINDOW COLOR' then
//    ColorColors.RTTYInverseWindowColor := GetColorInteger(ID);

//  if CMD = 'RTTY INVERSE WINDOW BACKGROUND' then
//    ColorColors.RTTYInverseWindowBackground := GetColorInteger(ID);

  if CMD = 'REMAINING MULTS WINDOW SUBDUE COLOR' then
     begin
     ColorColors.RemainingMultsWindowSubdue := GetColorInteger(ID);
     end;

  if CMD = 'REMAINING MULTS WINDOW COLOR' then
     begin
     ColorColors.RemainingMultsWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'REMAINING MULTS WINDOW BACKGROUND' then
     begin
     ColorColors.RemainingMultsWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'TOTAL WINDOW COLOR' then
     begin
     ColorColors.TotalWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'TOTAL WINDOW BACKGROUND' then
     begin
     ColorColors.TotalWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'TOTAL SCORE WINDOW COLOR' then
     begin
     ColorColors.TotalScoreWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'TOTAL SCORE WINDOW BACKGROUND' then
     begin
     ColorColors.TotalScoreWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'USER INFO WINDOW COLOR' then
     begin
     ColorColors.UserInfoWindowColor := GetColorInteger(ID);
     end;

  if CMD = 'USER INFO WINDOW BACKGROUND' then
     begin
     ColorColors.UserInfoWindowBackground := GetColorInteger(ID);
     end;

  if CMD = 'WHOLE SCREEN WINDOW COLOR' then
     begin
     ColorColors.WholeScreenColor := GetColorInteger(ID);
     end;

  if CMD = 'WHOLE SCREEN WINDOW BACKGROUND' then
     begin
     ColorColors.WholeScreenBackground := GetColorInteger(ID);
     end;

  if CMD = 'SCP WINDOW DUPE COLOR' then
     begin
     SCPDupeColor := GetColorInteger(ID);
     end;

  if CMD = 'SCP WINDOW DUPE BACKGROUND' then
     begin
     SCPDupeBackground := GetColorInteger(ID);
     end;
end;

end.

