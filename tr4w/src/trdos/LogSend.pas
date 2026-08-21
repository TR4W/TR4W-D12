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
unit LOGSend;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
  uConfigValues,   // Config -- migrated settings
  TF,
utils_text,
  Tree,
  uCallSignRoutines,
  VC,
  Messages,
  Windows,
  LogWind,
  LogDupe,
  LogStuff,
  ZoneCont,
  //Country9,
  LogEdit,
  LogCW,
  LOGDVP,
  LogDom, {Printer,}
  LogK1EA,
//  Help,
  LogGrid, {Crt,}
  LogSCP,
  BeepUnit,
  uWinKey,
  SysUtils
  ;

procedure SendCrypticDVPString(SendString: ShortString);
procedure SendCrypticCWString(SendString: Str160);
procedure SendCrypticDigitalString(SendString: Str160);
procedure SendDVKMessage(Message: Str20);
implementation

uses uTelnet,
  MainUnit;

procedure SendCrypticDVPString(SendString: ShortString);

var
  FileName                              : ShortString;
  QSONumber                             : integer;
begin
  if (not Config.DVKEnable) or (not CWEnabled) then Exit;
//  if not DVPEnabled then Exit;

  while SendString <> '' do
     begin

     FileName := RemoveFirstString(SendString);
     GetRidOfPrecedingSpaces(FileName);
     if DVPMessagesArrayIndex = DVPArraySize then Exit;
     if FileName = '#' then
        begin
        QSONumber := NextSerialToSend;  // Issue #954
        if Config.AutoQSONumberDecrement then
          if (ActiveMainWindow = awCallWindow)
          //if tr4w_CallWindowActive
          and (CallWindowString = '') and (ExchangeWindowString = '') then dec(QSONumber);
        FileName := IntToStr(QSONumber);
        end;

     if FileName = '@' then
       if CallWindowString <> '' then
          begin
          FileName := CallWindowString;
          end;

     if (StringHas(FileName, '.WAV')) or Config.UseRecordedSigns then
        begin
        DVPMessagesArray[DVPMessagesArrayIndex] := FileName;
        inc(DVPMessagesArrayIndex);
        if DVPThreadID = 0 then
           begin
           DVPOn := True;
           tExitFromDVPThread := False;
           DisplayCodeSpeed;
           logger.Debug('Calling tCreateThread from LogSend');
           tCreateThread(@tDVPPlayThreadproc, DVPThreadID);
           logger.Debug('Created DVP thread with threadid of %d',[DVPThreadID] );
           end;
        end;

     end;

end;

procedure SendCrypticCWString(SendString: Str160);

{ Control-A will put the message out on the InactiveRadio and set the flag
  InactiveRadioSendingCW.  It does not change the ActiveRadio any more.

  If you decide to answer someone who responds to CW on the inactive radio,
  you will want to call SwapRadios.  This will now make Control-A messages
  be sent on the new inactive radio (which is probably what you want).   }

var
  CharPointer, NumberCharsBeingSent, CharacterCount, QSONumber: integer;
  Result, Offset                 : integer;
  Key                                   : Char;
  SendChar, TempChar                    : AnsiChar;
  CommandMode, WarningSounded           : boolean;
  TempCall                              : CallString;
  TempString                            : Str80;
  i                                     : integer;
  TempReceivedData                      : ContestExchange;

begin
// For CQ TEST NY4I , this sends the C, then the Q, then T, then E, then S, then T, then NY4I

// Why doesn't it send the whole thing.  I know..it is because it processed each character. The call is a single character  (\)
// So, it's more efficient to use \ than NY4I
// I wonder if this could be improved to buffer the characters? // 4.44.5

  // Issue #1040: key CW only when this is genuinely a CW send (CW mode with CW
  // enabled) OR an MMTTY/RTTY send (DigitalModeEnable=True -> we want to drive
  // MMTTY).  Any other state -- notably Digital mode with DigitalModeEnable=
  // False (e.g. FT8 via WSJT-X, where the external app transmits) -- must NOT
  // key CW when a call is typed / DE / exchange / a function key fires.
  // DigitalModeEnable is what makes Digital a real (RTTY) mode here (see the
  // mode-cycle in LOGSUBS2 and the DIG status text in JCtrl1).
  if not (((ActiveMode = CW) and CWEnabled) or
          DigitalModeEnable)                then
     begin
     if (ActiveMode = CW) and (not CWEnabled) then
        begin
        logger.warn('Attempting SendCrypticCWString with CWEnabled = false');
        end;
     Exit;
     end;
  if length(SendString) = 0 then
     begin
     Exit;
     end;
  //SetSpeed(DisplayedCodeSpeed); //ny4i This seems superflous. The speed should be set already


  //SetPTT;

  NumberCharsBeingSent := 0;

  CommandMode := False;
  DebugMsg('CrypticCWString = [' + SendString + ']');
  //    FOR CharacterCount := 1 TO Length (SendString) DO
  CharacterCount := 1;
  repeat
    begin
       SendChar := SendString[CharacterCount];
      if CommandMode then
         begin
         case SendChar of
           '@':
             if StringHas(CallWindowString, '?') then
                begin
                AddStringToBuffer(' ' + CallWindowString, Config.CWTone);
                end;

         else AddStringToBuffer(ControlLeftBracket + SendChar, Config.CWTone);
         end;
         CommandMode := False;
         Continue;
         end;

       case SendChar of
            '+':
            begin                              // n4af 4.53.2
              if PrevNr = '' then
                 begin
                 PrevNr := '000';
                 end;
        //       while length(PrevNr) < 3  do
        //       PrevNr := '0' + PrevNr;
               AddStringToBuffer(PrevNr,Config.CWTone);
            end;                                    // end 4.52.

        '#':
          begin
            QSONumber := NextSerialToSend;  // Issue #954

            if TailEnding then
               begin
               inc(QSONumber);
               end;

            if Config.AutoQSONumberDecrement then
              //              if (ActiveWindow = CallWindow) and
//              if tr4w_CallWindowActive and
              if (ActiveMainWindow = awCallWindow) and
                (CallWindowString = '') and (ExchangeWindowString = '') then
                 begin
                 dec(QSONumber);
                 end;

            if length(SendString) >= CharacterCount + 2 then
               begin
               TempChar := SendString[CharacterCount + 1];

               if TempChar = '+' then
                  begin
                  TempChar := SendString[CharacterCount + 2];
                  Val(TempChar, Offset, Result);
                  if Result = 0 then
                     begin
                     QSONumber := QSONumber + Offset;
                     CharacterCount := CharacterCount + 2;
                     end;
                  end;

               if TempChar = '-' then
                  begin
                  TempChar := SendString[CharacterCount + 2];
                  Val(TempChar, Offset, Result);
                  if Result = 0 then
                     begin
                     QSONumber := QSONumber - Offset;
                     CharacterCount := CharacterCount + 2;
                     end;
                  end;
               end;

            TempString := QSONumberString(QSONumber);

            while Config.LeadingZeros > length(TempString) do
               begin
               TempString := Config.LeadingZeroCharacter + TempString;
               end;
              if ShortIntegers then
                 begin
                 for CharPointer := 1 to length(TempString) do
                    begin
                    if TempString[CharPointer] = '0' then
                       begin
                       TempString[CharPointer] := Short0;
                       end;
                    if TempString[CharPointer] = '1' then
                       begin
                       TempString[CharPointer] := Short1;
                       end;
                    if TempString[CharPointer] = '2' then
                       begin
                       TempString[CharPointer] := Short2;
                       end;
                    if TempString[CharPointer] = '9' then
                       begin
                       TempString[CharPointer] := Short9;
                       end;
                    end;
                 end;


            AddStringToBuffer(TempString, Config.CWTone);
          end;

        '_': AddStringToBuffer(' ', Config.CWTone);

        ControlD:
          if CWStillBeingSent then
             begin
             AddStringToBuffer(' ', Config.CWTone);
             end;

        ',':      // n4af 4.56.7
        begin
         TempString := copy(gettimestring,1,2) + copy(gettimestring,4,2);
         STString := TempString;     
         AddStringToBuffer(TempString , Config.CWTone);
        end;

             '.':
             if StString <> '' then
                begin
                AddStringToBuffer(STString, Config.CWTone);     // n4af 04.35.2
                end;

        '*':
          begin //KK1L: 6.72 New character to send Alt-D dupe checked call or call in call window
            if (DupeInfoCall <> '') and (DupeInfoCall <> EscapeKey) then
               begin
               AddStringToBuffer(DupeInfoCall, Config.CWTone)
               end
            else
               begin
               if CallsignUpdateEnable then
                  begin
                  TempString := GetCorrectedCallFromExchangeString(ExchangeWindowString);

                  if TempString <> '' then
                     begin
                     CallWindowString := TempString;
                     CallsignICameBackTo := TempString;
                     end;
                  end;

               if CallWindowString <> '' then
                  begin
                  AddStringToBuffer(CallWindowString, Config.CWTone);
                  end;
               end;
          end;

        '@':
          begin
            if CallsignUpdateEnable then
               begin
               TempString := ExchangeWindowString;
               TempString := GetCorrectedCallFromExchangeString(TempString);

               if TempString <> '' then
                  begin
                  CallWindowString := TempString;
                  CallsignICameBackTo := TempString;
                  end;
               end;

            if CallWindowString <> '' then
               begin
               AddStringToBuffer(CallWindowString, Config.CWTone);
               end;
          end;

        '$':
          if Config.SayHiEnable and (Rate < Config.SayHiRateCutOff) then
             begin
             SayHello(CallWindowString);
             end;
        '%':
          if Config.SayHiEnable and (Rate < Config.SayHiRateCutOff) then
             begin
             SayName(CallWindowString);
             end;

        ':':
          begin
            RITEnable := False;
            ProcessMenu(menu_ctrl_sendkeyboardinput);
            RITEnable := True;
          end;
  
        '~': SendSalutation(CallWindowString);
        '\': AddStringToBuffer(MyCall, Config.CWTone);
        '&': AddStringToBuffer(MyState, Config.CWTone);

        '|':
          begin
            TempString := ExchangeWindowString;
            GetRidOfPrecedingSpaces(TempString);
            GetRidOfPostcedingSpaces(TempString);
            Windows.ZeroMemory(@TempReceivedData, SizeOf(TempReceivedData));
            ProcessExchange(TempString, TempReceivedData);
            if TempReceivedData.Name <> '' then
               begin
               AddStringToBuffer(TempReceivedData.Name + ' ', Config.CWTone);
               end;
          end;

        '[':
          begin
            WarningSounded := False;

            //            QuickDisplay('WAITING FOR YOU ENTER STRENGTH OF RST (Single digit)!!');
            //            AddStringToBuffer('5', Config.CWTone);
            if Config.WaitForStrength then
               begin
               i := QuickEditInteger(TC_WAITINGFORYOUENTERSTRENGTHOFRST, 1)
               end
            else
               begin
               i := 9;
               end;



            if i = -1 then
               begin
               FlushCWBufferAndClearPTT;
               Exit;
               end;

            Key := IntToStr(i)[1];
            if i = 9 then
               begin
               AddStringToBuffer('5NN', Config.CWTone)
               end
            else
               begin
               AddStringToBuffer('5' + Key + 'N', Config.CWTone);
               end;
            ReceivedData.RSTSent := 509 + i * 10;

            LastRSTSent := ReceivedData.RSTSent;
          end;

        ']': AddStringToBuffer(IntToStr(LastRSTSent), Config.CWTone);

        '{': AddStringToBuffer(ReceivedData.Callsign, Config.CWTone);

        '}':
          if StringHas(ReceivedData.Callsign, '/') or
            ((length(ReceivedData.Callsign) = 4) and Config.SendCompleteFourLetterCall) or
            StringHas(CallsignICameBackTo, '/') then
             begin
             AddStringToBuffer(ReceivedData.Callsign, Config.CWTone)
             end
          else
            if GetPrefix(ReceivedData.Callsign) =
              GetPrefix(CallsignICameBackTo) then
               begin
               TempString := GetSuffix(ReceivedData.Callsign);
               if length(TempString) = 1 then
                  begin
                  TempString := Copy(ReceivedData.Callsign, length(ReceivedData.Callsign) - 1, 2);
                  end;
               AddStringToBuffer(TempString, Config.CWTone);
               end
            else
              if GetSuffix(ReceivedData.Callsign) =
                GetSuffix(CallsignICameBackTo) then
                 begin
                 AddStringToBuffer(GetPrefix(ReceivedData.Callsign), Config.CWTone)
                 end
              else
                 begin
                 AddStringToBuffer(ReceivedData.Callsign, Config.CWTone);
                 end;

        ')': AddStringToBuffer(VisibleLog.LastEntry(False, letCallsign), Config.CWTone);

        '(':
          if TotalContacts = 0 then
             begin
             if MyName <> '' then
                begin
                AddStringToBuffer(MyName, Config.CWTone)
                end
             else
                begin
                AddStringToBuffer(MyPostalCode, Config.CWTone);
                end;
             end
          else
             begin

             AddStringToBuffer(VisibleLog.LastEntry(False, letQTHString), Config.CWTone);

             end;

        ControlW: AddStringToBuffer(VisibleLog.LastName(4), Config.CWTone);

        ControlR:
          begin
            ReceivedData.RandomCharsSent := '';

            repeat
              ReceivedData.RandomCharsSent :=
                ReceivedData.RandomCharsSent +
                CHR(Random(25) + Ord('A'));
            until length(ReceivedData.RandomCharsSent) = 5;

            AddStringToBuffer(ReceivedData.RandomCharsSent, Config.CWTone);

            //                      SaveSetAndClearActiveWindow (DupeInfoWindow);
            //                      Write ('Sent = ', ReceivedData.RandomCharsSent);
            //                      RestorePreviousWindow;
          end;

        ControlT: AddStringToBuffer(ReceivedData.RandomCharsSent, Config.CWTone);

        ControlU:
          begin
            TempCall := GetCorrectedCallFromExchangeString(ExchangeWindowString);

            if TempCall <> '' then
               begin
               CallsignICameBackTo := TempString
               end
            else
               begin
               CallsignICameBackTo := CallWindowString;
               end;

            ShowStationInformation(@CallsignICameBackTo);
          end;

        ControlLeftBracket: CommandMode := True;

      else AddStringToBuffer(SendChar, Config.CWTone);
      end;
      inc(CharacterCount);

    end;
  until CharacterCount = length(SendString) + 1;

  InactiveRigCallingCQ := False;
   if (IsCWByCATActive)  then
      begin
      AddStringToBuffer(CWByCATBufferTerminator,Config.CWTone); // Flushes the buffer when the $242 is passed to SendCW - by only By CAT
      end;

// if IsCWByCATActive then backtoinactiveradioafterqso;
end;


procedure SendCrypticDigitalString(SendString: Str160);

{ Control-A will put the message out on the InactiveRadio and set the flag
  InactiveRadioSendingCW.  It does not change the ActiveRadio any more.

  If you decide to answer someone who responds to CW on the inactive radio,
  you will want to call SwapRadios.  This will now make Control-A messages
  be sent on the new inactive radio (which is probably what you want).   }

//var
//  CharPointer, NumberCharsBeingSent, CharacterCount, QSONumber: integer;
//  RESULT, Entry, Offset                 : integer;
//  Key, SendChar, TempChar               : Char;
//  TempCall                              : CallString;
//  WarningSounded                        : boolean;
//  TempString                            : str80;

begin
end;

procedure SendDVKMessage(Message: Str20);

begin
{
  Message := UpperCase(Message);

  if (Message = 'DVK0') or DVKMessagePlaying then //KK1L: 6.71 If already playing then stop it first
  begin
    StartDVK(0);
    DVKPlaying := False;
  end;

  if Message = 'DVK1' then
  begin
    StartDVK(1);
    DVKStamp;
  end;

  if Message = 'DVK2' then
  begin
    StartDVK(2);
    DVKStamp;
  end;

  if Message = 'DVK3' then
  begin
    StartDVK(3);
    DVKStamp;
  end;

  if Message = 'DVK4' then
  begin
    StartDVK(4);
    DVKStamp;
  end;

  if Message = 'DVK5' then //KK1L: 6.71
  begin
    StartDVK(5);
    DVKStamp;
  end;

  if Message = 'DVK6' then //KK1L: 6.71
  begin
    StartDVK(6);
    DVKStamp;
  end;
}
end;

begin
end.

