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
 }unit LOGMENU;
{$I ..\tr4w.inc}

{$O+}
{$F+}
{$IMPORTEDDATA OFF}
interface

uses
  VC,
  LogWind,
  FCONTEST,
  Tree;

//PROCEDURE MakeListOfAvailableContestFiles;
{WLI}
//FUNCTION SelectAvailableLog: Str20;  { Returns null if no log selected }

implementation
uses MainUnit;

type
  AvailableFileArray = array[0..100] of Str20;
  AvailableFileArrayPtr = ^AvailableFileArray;

var
  ConfigFiles                 : AvailableFileArrayPtr;
  NumberConfigFiles           : integer;

procedure CheckForOldLogCfgFile;

{ This procedure will look for a LOGCFG.DAT file.  If one is found, it will
  ask the user if he would like to rename it to the appropriate .CFG file. }

var
  FileRead                    : Text;
  FileString                  : Str160;
  ID, CMD                     : shortstring {Str80};
  Key                         : Char;

begin
  if FileExists('LOGCFG.DAT') then
     begin
     {        ClrScr;
              TextColor (Yellow);
              WriteLnCenter ('LOGCFG.DAT FILE CONVERSION');
              WriteLn;
              TextColor (Cyan);

              WriteLn ('You are seeing this message because the file LOGCFG.DAT has been found in');
              WriteLn ('the active directory.  TR Log now uses configuration files that have unique');
              WriteLn ('names for each of the 60+ contests it knows how to operate.  This allows you');
              WriteLn ('to keep all of your files for various contests in one directory.');
              WriteLn;
              WriteLn ('You are about to see a list of the different configuration files that exist');
              WriteLn ('in the active directory.  One of these will be LOGCFG which you can select');
              WriteLn ('as the active contest, and it will run just like before.');
              WriteLn;
              WriteLn ('However, if you would like to have your LOGCFG.DAT file and corresponding log');
              WriteLn ('files renamed to the new convention, I can do that for you.');
              WriteLn;
      }
   repeat
     Key := UpCase(GetKey('Would you like you files updated to the new method? (Y/N) : '));
     if (Key = EscapeKey) or (Key = 'N') then Exit;
   until Key = 'Y';
   WriteLn;

     //{WLI}        TextColor (Cyan);

   if OpenFileForRead(FileRead, 'LOGCFG.DAT') then
      begin
      while not Eof(FileRead) do
         begin
         ReadLn(FileRead, FileString);

         FileString := UpperCase(FileString);

         ID := UpperCase(PrecedingString(FileString, '='));
         CMD := PostcedingString(FileString, '=');

         GetRidOfPrecedingSpaces(ID);
         GetRidOfPrecedingSpaces(CMD);
         GetRidOfPostcedingSpaces(ID);
         GetRidOfPostcedingSpaces(CMD);

         if ID = 'CONTEST' then
           if FoundContest(CMD) then
              begin
              Close(FileRead);

  //            WriteLn('Renaming LOGCFG.DAT to ', LogConfigFileName);
  //            RenameFile('LOGCFG.DAT', LogConfigFileName);
                      {
                                if FileExists('LOG.DAT') then
                                begin
                                  WriteLn('Renaming LOG.DAT to ', LogFileName);
                                  RenameFile('LOG.DAT', LogFileName);
                                end;

                                if FileExists('LOG.TMP') then
                                begin
                                  WriteLn('Renaming LOG.TMP to ', LogTempFileName);
                                  RenameFile('LOG.TMP', LogTempFileName);
                                end;
                    }
              if FileExists('RESTART.BIN') then
                 begin
                 //              WriteLn('Renaming RESTART.BIN to ', LogRestartFileName);
                 //              RenameFile('RESTART.BIN', LogRestartFileName);
                 end;

                      {                        TextColor (Cyan);
                                            WriteLn;
                                            WriteLn ('Process completed - press any key to continue.');
                    }
                      //{WLI}                        REPEAT UNTIL KeyPressed;
                      //{WLI}                        WHILE KeyPressed DO ReadKey;
              Exit;
              end
           else
              begin
              Close(FileRead);
              ShowMessage('I found a contest name I do no understand in your LOGCFG.DAT file.');
                      //{WLI}                        WaitForKeyPressed;
              Exit;
              end;
         end;

      Close(FileRead);

      ShowMessage('I did not fine a contest name in your LOGCFG.DAT file.');
          //{WLI}            WaitForKeyPressed;
      end;
     end;
end;
{
procedure MakeListOfAvailableContestFiles;

var
  DirInfo                     : TSearchRec;

begin
  New(ConfigFiles);

  NumberConfigFiles := 0;

  FindFirst('*.cfg', faArchive, DirInfo);

  while IORESULT  = 0 do
  begin
    ConfigFiles^[NumberConfigFiles] := PrecedingString(DirInfo.Name, '.');
    inc(NumberConfigFiles);
    FindNext(DirInfo);
  end;

  if FileExists('LOGCFG.DAT') then
  begin
    ConfigFiles^[NumberConfigFiles] := ('LOGCFG');
    inc(NumberConfigFiles);
  end;
end;
}

procedure InverseVideo(Entry: integer; StartY: integer; NumberRows: integer; Contest: Str20);

var
  Row, col                    : integer;

begin
  while length(Contest) < 20 do
     begin
     Contest := Contest + ' ';
     end;

  //  NoCursor;
  col := (Entry div NumberRows) * 20 + 1;
  Row := (Entry mod NumberRows);
  {    GoToXY (Col, Row + StartY);

      TextBackGround (White);
      TextColor (Black);
      Write (Contest);
     }
end;

procedure NormalVideo(Entry: integer; StartY: integer; NumberRows: integer; Contest: Str20);

var
  Row, col                    : integer;

begin
  while length(Contest) < 20 do
     begin
     Contest := Contest + ' ';
     end;

  col := (Entry div NumberRows) * 20 + 1;
  Row := (Entry mod NumberRows);

  //  NoCursor;
   {    GoToXY (Col, Row + StartY);

       TextBackGround (Black);
       TextColor (Yellow);
       Write (Contest);
      }
end;

procedure DeleteOrMoveLog(RootName: Str20);

var
  Key                         : Char;
  DestFileName                : Str80;

begin
end;

begin
end.

