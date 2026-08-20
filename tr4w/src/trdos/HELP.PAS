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
unit Help;

{
  NOT COMPILED BY ANYTHING, measured 2026-08-20.

  This unit is in no program's uses clause -- not tr4w.dpr, not the unit tests,
  not tr4wserver, not the bench harnesses -- and every `uses Help` elsewhere in
  the tree is inside a comment (CfgCmd, FCONTEST, LogCfg, LOGDDX, LogSend,
  LOGSTUFF, LOGSUBS1, LOGSUBS2, LOGWAE, PostUnit). FPC compiles only what a
  program's uses graph reaches, so nothing here has been built into TR4W for
  some time.

  READ THAT BEFORE TRUSTING ANYTHING BELOW, and before using a green build as
  evidence about this file. The usual proof -- "deleting something that is
  called does not compile" -- DOES NOT APPLY HERE. The build stays green
  whatever this file says, because the compiler never opens it.

  2026-08-20: NY4I deleted the commented-out bodies by hand, leaving 27 routines
  as empty shells; those 27, their interface declarations and the one call
  between them (ShowNextPage -> LoadNextPage, which did nothing) were then
  removed. 3675 -> ~975 lines.

  WHAT IS LEFT IS NOT SCAFFOLDING. Fifteen routines still have real bodies, and
  several are FEATURES rather than plumbing -- TellMeMyGrid, SunriseSunset,
  DisplayCountryInformation, Inductance, UUDecode, Bin64Decode, AddReminder,
  CheckForName, and the QTC and log-paging helpers. They are unreachable today,
  which is not the same as unwanted. Deciding which have a modern equivalent
  (uDistance, uCTYDAT) and which quietly stopped being available is open work,
  and the unit is kept until that is answered rather than deleted on the
  strength of "nothing calls it".
}
{$I ..\tr4w.inc}

{$O+}
{$F+}
{$IMPORTEDDATA OFF}
interface

uses

  VC,

  Country9,
  Windows,
  Messages,
  LogSCP,
  LogK1EA,
  Tree,
  LogGrid,
  LogWind,
  LogNet,
  LogRadio,
   uConfigValues;

type
  HelpSubject = (NoSubject);

  //  TabModeType = (NormalTabMode, ControlFTabMode);

var
  Config.ConfirmEditChanges               : boolean = True;
  //  TabMode                               : TabModeType = NormalTabMode;
  UserNameString                   : Str40;
  VideoGameLength                  : integer;

var
  QTCFileName                      : string; //    = 'QTC.DAT';
  QTCListFileName                  : string; //    = 'QTCLIST.DAT';

procedure AddReminder;
procedure Bin64Decode;
procedure CheckForName;
procedure DisplayCountryInformation(FileName: Str80; Call: CallString);

  CursorX: integer; CursorY: integer;
  var DataChanged: boolean);

procedure Inductance;


procedure SaveQTCDataFile;
procedure SunriseSunset;
procedure TellMeMyGrid;
procedure UUDecode;

implementation

uses LogCfg,
  MainUnit;

const
  PageBufferSize                   = BigWindowRX * (BigWindowRY - BigWindowLY + 2);
  MaxBuffers                       = 100;

type
  PageBuffer = record
    List: array[0..PageBufferSize - 1] of Char;
    NumberChars: integer;
  end;

  PageBufferPointer = ^PageBuffer;

var
  DisplayedBuffer                  : integer;
  FirstBuffer                      : integer;
  LogFileRead                      : Text;
  NumberBuffers                    : integer;
  TextBuffer                       : array[0..MaxBuffers - 1] of PageBufferPointer;

procedure TellMeMyGrid;

var
  LatString, LonString             : Str40;
  Result                           : integer;
  Lat, Lon                         : REAL;

begin
  WriteLn('Okay, I will tell you the grid of a given lat/lon.');

  repeat
    WriteLn;
    LatString := GetResponse('Enter lat (minus is south - none to quit) : ');
    if LatString = '' then Exit;
    Val(LatString, Lat, Result);
    if Result <> 0 then Exit;

    LonString := GetResponse('Enter lon (minus is east) : ');
    if LonString = '' then Exit;
    Val(LonString, Lon, Result);
    if Result <> 0 then Exit;

    WriteLn('Grid is ', ConvertLatLonToGrid(Lat, Lon));
  until False;
end;

procedure UUDecode;

var
  Mode                             : Str80;
  OutFileName, InputfileName       : Str80;
  CharacterPointer                 : integer;
  FileRead                         : Text;
  FileWrite                        : file;
  FileString                       : string;
  Key                              : Char;
  OutputByte1, OutputByte2, OutputByte3: Byte;

begin
  if ParamStr(2) = '' then
     begin
     InputfileName := GetResponse('Enter file to uudecode : ')
     end
  else
     begin
     InputfileName := ParamStr(2);
     end;

  if InputfileName = '' then Exit;

  if not OpenFileForRead(FileRead, InputfileName) then Exit;

  if not Eof(FileRead) then
     begin
     ReadLn(FileRead, FileString);
     end;

  while UpperCase(Copy(FileString, 1, 6)) <> 'BEGIN ' do
     begin
     ReadLn(FileRead, FileString);

     if Eof(FileRead) then
        begin
        Close(FileRead);
        Exit;
        end;
     end;

  { We have found the begin statement }

  FileString := UpperCase(FileString);
  FileString := PostcedingString(FileString, 'BEGIN ');
  Mode := RemoveFirstString(FileString);
  OutFileName := RemoveFirstString(FileString);

  if OutFileName = '' then
     begin
     Close(FileRead);
     Exit;
     end;

  { See if output file exists, and if so, make sure overwrite is okay }

  WriteLn('Output file = ', OutFileName);

  if FileExists(OutFileName) then
     begin
     repeat
       Key := UpCase(GetKey(OutFileName + ' already exists.  Overwrite? (Y/N/) : '));

       if (Key = EscapeKey) or (Key = 'N') then
          begin
          Close(FileRead);
          Exit;
          end;

     until Key = 'Y';
     WriteLn;
     end
  else
     begin
     WriteLn('Output file = ', OutFileName);
     end;

  { Open output file }

  Assign(FileWrite, OutFileName);
  ReWrite(FileWrite, 1);

  while not Eof(FileRead) do
     begin
     ReadLn(FileRead, FileString);

     if (FileString = '') or (UpperCase(FileString) = 'END') then Continue;

     if not (FileString[1] in [' ', '`']) then
        begin
        Delete(FileString, 1, 1); { Get rid of length character }

        for CharacterPointer := 1 to length(FileString) do
           begin
           if not (FileString[CharacterPointer] in [' '..'`']) then
              begin
              Close(FileRead);
              Close(FileWrite);
              //                   ReportError ('Illegal character found!!');
              WriteLn(FileString);
              Exit;
              end;

           if FileString[CharacterPointer] = '`' then
              begin
              FileString[CharacterPointer] := ' ';
              end;
           end;

        { We have legal characters - process 4 bytes at a time }

        while FileString <> '' do
           begin

           { Suppressed space at end of line protetion }

           while length(FileString) < 4 do
              begin
              FileString := FileString + ' ';
              end;

           OutputByte1 := ((Ord(FileString[1]) - 32) shl 2) + ((Ord(FileString[2]) - 32) shr 4);
           OutputByte2 := ((Ord(FileString[2]) - 32) shl 4) + ((Ord(FileString[3]) - 32) shr 2);
           OutputByte3 := ((Ord(FileString[3]) - 32) shl 6) + ((Ord(FileString[4]) - 32));

           BlockWrite(FileWrite, OutputByte1, 1);
           BlockWrite(FileWrite, OutputByte2, 1);
           BlockWrite(FileWrite, OutputByte3, 1);

           Delete(FileString, 1, 4);
           end;
        end;
     end;

  Close(FileWrite);
  Close(FileRead);
end;

procedure Bin64Decode;

var
  n                                : integer;
  t                                : array[0..255] of Byte;
  InputFile, OutputFile            : Str40;
  FileRead                         : Text;
  FileWrite                        : file;
  FileString                       : string;
  NumberBytes                      : LONGINT;
  ByteValue                        : integer;
  CharSet                          : Str80;
  SaveByte                         : Byte;
  Started                          : boolean;
  LeftOverChars                    : Str20;

begin
  if ParamStr(2) = '' then
     begin
     InputFile := GetResponse('Enter file to decode : ')
     end
  else
     begin
     InputFile := ParamStr(2);
     end;

  if InputFile = '' then Exit;

  CharSet := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

  for n := 0 to 255 do
     begin
     t[n] := 0;
     end;
  for n := 0 to 63 do
     begin
     t[Ord(CharSet[n + 1])] := n;
     end;

  NumberBytes := 0;
  OutputFile := '';

  if OpenFileForRead(FileRead, InputFile) then
     begin
     while not Eof(FileRead) do
        begin
        ReadLn(FileRead, FileString);
        FileString := UpperCase(FileString);
        WriteLn(FileString);

        if StringHas(FileString, 'NAME=') then
           begin
           OutputFile := PostcedingString(FileString, 'NAME=');

           if OutputFile[1] = '"' then
              begin
              Delete(OutputFile, 1, 1);
              end;

           if StringHas(OutputFile, '"') then
              begin
              OutputFile := PrecedingString(OutputFile, '"')
              end
           else
              begin
              OutputFile := PrecedingString(OutputFile, ';');
              end;

           WriteLn('Output file command found = ', OutputFile);
           end;

        if (StringHas(FileString, 'CONTENT-TRANSFER-ENCOD') and
          StringHas(FileString, 'BASE64')) then
           begin
           ReadLn(FileRead, FileString);

           FileString := UpperCase(FileString);

           if StringHas(FileString, 'NAME=') then
              begin
              OutputFile := PostcedingString(FileString, 'NAME=');

              if OutputFile[1] = '"' then
                 begin
                 Delete(OutputFile, 1, 1);
                 end;

              if StringHas(OutputFile, '"') then
                 begin
                 OutputFile := PrecedingString(OutputFile, '"')
                 end
              else
                 begin
                 OutputFile := PrecedingString(OutputFile, ';');
                 end;

              WriteLn('Output file command found = ', OutputFile);
              end;

           if OutputFile = '' then
              begin
              OutputFile := GetResponse('Output file name = ');

              if OutputFile = '' then
                 begin
                 Close(FileRead);
                 Exit;
                 end;
              end;

           Assign(FileWrite, OutputFile);
           ReWrite(FileWrite, 1);

           Started := False;
           LeftOverChars := '';

           while not Eof(FileRead) do
              begin
              ReadLn(FileRead, FileString);

              GetRidOfPrecedingSpaces(FileString);
              GetRidOfPostcedingSpaces(FileString);

              if Started and (FileString = '') then
                 begin
                 Close(FileWrite);
                 Close(FileRead);
                 WriteLn(NumberBytes, ' bytes saved to ', OutputFile);
                 Exit;
                 end;

              if (length(FileString) > 40) and (not StringHas(FileString, '=')) then
                 begin
                 Started := True;
                 end;

              if Started then
                 begin
                 FileString := LeftOverChars + FileString;

                 while length(FileString) >= 4 do
                    begin
                    ByteValue := t[Ord(FileString[1])];

                    { Push six bits to the left }

                    ByteValue := ByteValue * 64;

                    { Fill in next six bits }

                    ByteValue := ByteValue + t[Ord(FileString[2])];

                    { Four more shifts to get first byte in hi byte }

                    ByteValue := ByteValue * 16;

                    { Save first byte }

                    SaveByte := Hi(ByteValue);
                    BlockWrite(FileWrite, SaveByte, 1);

                    { Push two more places to make room for six bits }

                    ByteValue := ByteValue * 4;

                    { Get next 6 bits }

                    ByteValue := ByteValue + t[Ord(FileString[3])];

                    { Push 6 times to make second byte }

                    ByteValue := ByteValue * 64;

                    { Save second byte }

                    SaveByte := Hi(ByteValue);
                    BlockWrite(FileWrite, SaveByte, 1);

                    { Get last 6 bits and you have the byte in Lo }

                    ByteValue := ByteValue + t[Ord(FileString[4])];

                    { Save third byte }

                    SaveByte := Lo(ByteValue);
                    BlockWrite(FileWrite, SaveByte, 1);

                    { Delete the bits we have processed }

                    Delete(FileString, 1, 4);
                    NumberBytes := NumberBytes + 3;
                    end;

                 LeftOverChars := FileString;
                 end;
              end;
           Close(FileWrite);
           end;
        end;
     Close(FileRead);
     WriteLn(NumberBytes, ' bytes saved to ', OutputFile);
     end;
end;

procedure LastQTCSent(var Call: CallString; var Time: Str20; var QSONumber: integer);

var
  TempString, LastFirstString, LastSecondString: string;
  FileString                       : string;
  FileRead                         : Text;

begin
  NumberQTCBooksSent := 0;

  if OpenFileForRead(FileRead, QTCFileName) then
     begin
     while not Eof(FileRead) do
        begin
        ReadLn(FileRead, FileString);

        GetRidOfPostcedingSpaces(FileString);

        if FileString = '' then Continue;

        if Copy(FileString, 1, 3) = 'QTC' then
           begin
           inc(NumberQTCBooksSent);
           LastFirstString := '';
           LastSecondString := '';
           Continue;
           end;

        TempString := Copy(FileString, 1, 40);

        if (Copy(TempString, 1, 3) = ' 1:') or
          (Copy(TempString, 1, 3) = ' 2:') or
          (Copy(TempString, 1, 3) = ' 3:') or
          (Copy(TempString, 1, 3) = ' 4:') or
          (Copy(TempString, 1, 3) = ' 5:') then
           begin
           RemoveFirstString(TempString);
           LastFirstString := TempString;
           end;

        TempString := Copy(FileString, 41, 30);

        if (Copy(TempString, 1, 3) = ' 6:') or
          (Copy(TempString, 1, 3) = ' 7:') or
          (Copy(TempString, 1, 3) = ' 8:') or
          (Copy(TempString, 1, 3) = ' 9:') or
          (Copy(TempString, 1, 3) = '10:') then
           begin
           RemoveFirstString(TempString);
           LastSecondString := TempString;
           end;
        end;

     Close(FileRead);

     if LastSecondString <> '' then
        begin
        Time := RemoveFirstString(LastSecondString);
        Call := RemoveFirstString(LastSecondString);
        QSONumber := RemoveFirstLongInteger(LastSecondString);
        end
     else
        begin
        Time := RemoveFirstString(LastFirstString);
        Call := RemoveFirstString(LastFirstString);
        QSONumber := RemoveFirstLongInteger(LastFirstString);
        end;

     Insert(':', Time, 3);

     Exit;
     end;

  Call := '';
  Time := '';
  QSONumber := 0;
end;

function GetLogEntryQSONumberReceived(FileString: Str80): integer;

var
  Exchange                         : string;
  QSONumber, Result1               : integer;

begin
  Exchange := GetLogEntryExchangeString(FileString);
  GetRidOfPrecedingSpaces(Exchange);
  Exchange := PostcedingString(Exchange, ' ');
  GetRidOfPrecedingSpaces(Exchange);
  Exchange := PostcedingString(Exchange, ' ');
  GetRidOfPrecedingSpaces(Exchange);
  GetRidOfPostcedingSpaces(Exchange);
  Val(Exchange, QSONumber, Result1);

  if Result1 = 0 then
     begin
     GetLogEntryQSONumberReceived := QSONumber
     end
  else
     begin
     GetLogEntryQSONumberReceived := 0;
     end;
end;


procedure SaveQTCDataFile;

var
  FileWrite                        : Text;
  TempString                       : Str80;
  Station                          : integer;

begin
  if NumberQTCStations > 0 then
    if OpenFileForWrite(FileWrite, QTCListFileName) then
       begin
       for Station := 0 to NumberQTCStations - 1 do
          begin
          WriteLn(FileWrite, BigExpandedString(QTCDataArray^[Station].Call));
          WriteLn(FileWrite, QTCDataArray^[Station].NumberQTCs);
          end;
       Close(FileWrite);
       end;
end;

procedure AddReminder;

var
  TimeString, DayString, DateString, ReminderString: string;
  Result                           : integer;
  FileWrite                        : Text;

begin
  if NumberReminderRecords >= MaximumReminderRecords then
     begin
     //    SaveSetAndClearActiveWindow(QuickCommandWindow);
     QuickDisplay('Sorry, you have used up all your reminders!!');
     //    Delay(2000);
     //    RemoveAndRestorePreviousWindow;
     Exit;
     end;

  TimeString := QuickEditResponse('Enter time for reminder (XX:XX) : ', 12);
  if (TimeString = EscapeKey) or (Copy(TimeString, 3, 1) <> ':') then Exit;
  Delete(TimeString, 3, 1);

  if not StringIsAllNumbers(TimeString) then Exit;
  if length(TimeString) <> 4 then Exit;

  DateString := UpperCase(QuickEditResponse('Enter day or date : ', 12));
  if (DateString = '') or (DateString = EscapeKey) then Exit;

  if NumberReminderRecords = 0 then
     begin
     New(Reminders);
     end;

  Reminders^[NumberReminderRecords].DateString := '';
  Reminders^[NumberReminderRecords].DayString := '';
  Reminders^[NumberReminderRecords].Alarm := False;

  Val(TimeString, Reminders^[NumberReminderRecords].Time, Result);

  if StringHas(UpperCase(DateString), 'ALARM') then
     begin
     Reminders^[NumberReminderRecords].Alarm := True;
     DateString := BracketedString(DateString, '', 'ALARM');
     end;

  GetRidOfPostcedingSpaces(DateString);
  su(DateString);

  if StringHas(DateString, '-') then
     begin
     case length(DateString) of
       8: if (DateString[2] <> '-') or (DateString[6] <> '-') then
             begin
             //          SaveSetAndClearActiveWindow(QuickCommandWindow);
             QuickDisplay('Invalid date!!');
             //          Delay(1000);
             //          RestorePreviousWindow;
             Exit;
             end
         else
            begin
            DateString := '0' + DateString;
            end;

       9: if (DateString[3] <> '-') or (DateString[7] <> '-') then
             begin
             //          SaveSetAndClearActiveWindow(QuickCommandWindow);
             QuickDisplay('Invalid date!!');
             //          Delay(1000);
             //          RestorePreviousWindow;
             Exit;
             end;

       else
         begin
           //        SaveSetAndClearActiveWindow(QuickCommandWindow);
           QuickDisplay('Invalid date!!');
           //        Delay(1000);
           //        RestorePreviousWindow;
           Exit;
         end;
     end; { of case }

     Reminders^[NumberReminderRecords].DateString := DateString;
     end
  else
     begin
     if Copy(DateString, 1, 2) = 'MO' then
        begin
        DateString := 'MONDAY';
        end;
     if Copy(DateString, 1, 2) = 'TU' then
        begin
        DateString := 'TUESDAY';
        end;
     if Copy(DateString, 1, 2) = 'WE' then
        begin
        DateString := 'WEDNESDAY';
        end;
     if Copy(DateString, 1, 2) = 'TH' then
        begin
        DateString := 'THURSDAY';
        end;
     if Copy(DateString, 1, 2) = 'FR' then
        begin
        DateString := 'FRIDAY';
        end;
     if Copy(DateString, 1, 2) = 'SA' then
        begin
        DateString := 'SATURDAY';
        end;
     if Copy(DateString, 1, 2) = 'SU' then
        begin
        DateString := 'SUNDAY';
        end;

     DayString := Copy(DateString, length(DateString) - 2, 3);

     if (DayString <> 'DAY') and (DateString <> 'ALL') and (DateString <> 'TMW') then
        begin
        //      SaveSetAndClearActiveWindow(QuickCommandWindow);
        QuickDisplay('Invalid date!!');
        //      Delay(1000);
        //      RestorePreviousWindow;
        Exit;
        end;

     if DateString = 'TODAY' then
        begin
        DateString := UpperCase(GetDayString);
        end;
     if DateString = 'TMW' then
        begin
        DateString := UpperCase(GetTomorrowString);
        end;

     Reminders^[NumberReminderRecords].DayString := DateString;
     end;

  ReminderString := QuickEditResponse('Msg = ', 75);
  if (ReminderString = '') or (ReminderString = EscapeKey) then Exit;

  Reminders^[NumberReminderRecords].Message := ReminderString;
  inc(NumberReminderRecords);

end;

procedure CheckForName;

var
  FileRead, FileWrite              : Text;
  Directory, CityString, AddressString: Str80;

begin
  Directory := FindDirectory('name.dat');

  if Directory = '' then
     begin
     Directory := FindDirectory('TR.EXE');
     end;

  if OpenFileForRead(FileRead, Directory + '\name.dat') then
     begin
     ReadLn(FileRead, UserNameString);
     WriteLn('TR Program registered to ', UserNameString);
     Close(FileRead);
     end
  else
     begin
     Directory := FindDirectory('TR.OVR');

     UserNameString := GetResponse('Please enter your name and call : ');

     if UserNameString = '' then
        begin
        halt;
        end;

     OpenFileForWrite(FileWrite, Directory + '\name.dat');
     WriteLn(FileWrite, UserNameString);
     WriteLn(FileWrite, AddressString);
     WriteLn(FileWrite, CityString);
     Close(FileWrite);
     end;
end;


procedure LoadPageBuffer(BufferNumber: integer);

{ This procedure will load up the PageBuffer with one screen full of text
  from the file indicated by FileRead.  If the end of the file is found,
  the rest of the PageBuffer will be blank. }

var
  Result, NumberLines              : integer;
  FileChar                         : Char;
  TempString                       : Str80;

begin
  TextBuffer[BufferNumber]^.NumberChars := 0;
  NumberLines := 0;

  while not Eof(LogFileRead) do
     begin
     Read(LogFileRead, FileChar);

     if FileChar = LineFeed then
        begin
        inc(NumberLines);
        if NumberLines >= BigWindowRY - BigWindowLY + 1 then
           begin
           Exit;
           end;
        end;

     TextBuffer[BufferNumber]^.List[TextBuffer[BufferNumber]^.NumberChars] := FileChar;
     inc(TextBuffer[BufferNumber]^.NumberChars);
     end;
end;

procedure DisplayBuffer(BufferNumber: integer);

var
  Address                          : integer;

begin
 

  if TextBuffer[BufferNumber]^.NumberChars > 0 then
     begin
     for Address := 0 to TextBuffer[BufferNumber]^.NumberChars - 1 do
        begin
        Write(TextBuffer[BufferNumber]^.List[Address]);
        end;
     end;

  DisplayedBuffer := BufferNumber;
end;


procedure ShowNextPage;

{ This procedure will display the next page and load the next page after
  that into the appropriate buffer.   }

begin
  if NumberBuffers > 1 then { multiple buffers }
     begin
     inc(DisplayedBuffer); { is already loaded }

     if DisplayedBuffer = NumberBuffers then { need to wrap to 0 }
        begin
        DisplayedBuffer := 0;
        end;

     if DisplayedBuffer <> FirstBuffer then
        begin
        DisplayBuffer(DisplayedBuffer)
        end
     else
        begin
        Dec(DisplayedBuffer);
        if DisplayedBuffer < 0 then
           begin
           DisplayedBuffer := NumberBuffers - 1;
           end;
        end;
     end
  else { we are using just one buffer }
    if not Eof(LogFileRead) then
       begin
       LoadPageBuffer(0);
       DisplayBuffer(0);
       end;
end;

procedure ShowPreviousPage;

begin
  if DisplayedBuffer <> FirstBuffer then
     begin
     Dec(DisplayedBuffer);

     if DisplayedBuffer < 0 then { need to wrap }
        begin
        DisplayedBuffer := NumberBuffers - 1;
        end;

     DisplayBuffer(DisplayedBuffer);
     end;
end;


procedure DisplayCountryInformation(FileName: Str80; Call: CallString);

{ This procedure will go search through the file specified and if it
  finds an entry with the country ID for the callsign indicated, it
  will display the data contained after that line, until the next blank
  line if found (up to five lines).  The information will be displayed
  in the editable log window. }

var
  FileRead                         : Text;
  CountryID                        : Str20;
  FileString                       : Str80;
  WhereY                           : integer;
begin
  //  if tr4w_WindowsArray[tr4w_LAST5WINDOW_INDEX].tr4w_WndHandle = 0 then Exit;
  if not OpenFileForRead(FileRead, FileName) then Exit;

  CountryID := CountryTable.GetCountryID(CountryTable.GetCountry(Call, True));

  strU(@CountryID);
  WhereY := 1;
  while not Eof(FileRead) do
     begin
     ReadLn(FileRead, FileString);

     if UpperCase(FileString) = CountryID then
        begin
        //      SaveSetAndClearActiveWindow(EditableLogWindow);

        repeat
          ReadLn(FileRead, FileString);

          if FileString <> '' then
             begin
             //          if WhereX > 1 then WriteLn;
             //          Write(FileString);
             //          SendDlgItemMessage(tr4w_WindowsArray[tr4w_LAST5WINDOW_INDEX].tr4w_WndHandle, 101, LB_ADDSTRING, 0, integer(PAnsiChar(AnsiString(FileString))));
             //          SendMessage(_EditableLogWindow, LB_ADDSTRING, 0, integer(PAnsiChar(AnsiString(FileString))));
             inc(WhereY);
             end;

        until (WhereY = 5) or (FileString = '');

        Close(FileRead);
        //      RestorePreviousWindow;
        Exit;

        end;

     end;

  Close(FileRead);
end;


procedure Inductance;

var
  l, f, c                          : REAL;

begin
  f := GetReal('Enter Frequency of resonance (MHz) : ');

  f := f * f;

  f := f * 0.00003948;

  c := GetReal('Enter Capacitance (pf) or Inductance (uH) : ');

  l := f * c;

  l := 1.0 / l;

  WriteLn(l: 3: 2, ' uH or pf')
end;


procedure SunriseSunset;

var
  Lat, Lon                         : REAL;

begin
  repeat
    Lat := GetReal('Enter Lat (0 to exit) ');
    if Lat = 0 then Exit;
    Lon := GetReal('Enter Lon ');

    WriteLn('Sunrise/Sunset = ', GetSunriseSunsetString(Lat, Lon));
  until False;
end;


begin
end.
