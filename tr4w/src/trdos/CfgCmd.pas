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
unit CfgCmd;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}

interface

uses {SlowTree,} Tree,

  TF,
  VC,
  utils_text,
  uTelnet,
  LogStuff,

  LogSCP,
  LogCW,
  LogWind,
  LogDupe,
  ZoneCont,
  LogGrid,
  LogDom,
  FCONTEST,
  LOGDVP,
//  Country9,
  LogEdit,
  //LOGDDX,
  LOGWAE,
  LogPack,
  LogK1EA, {DOS, }
//  Help,
  LogNet,
  LogRadio 

  ;

function ProcessConfigInstruction(var FileString: ShortString; var FirstCommand: boolean): boolean;

function ProcessConfigInstructions1(ID: Str80; CMD: ShortString): boolean;
//function ProcessConfigInstructions2(ID: Str80; CMD: ShortString): boolean;
function ProcessConfigInstructions3(ID: Str80; CMD: ShortString): boolean;

procedure SniffOutControlCharacters(var TempString: ShortString);

function ProcessRadioTypeold(CMD: ShortString; RadioPointer: RadioPtr): boolean;
//function ProcessRadioControlPort(CMD: ShortString; RadioPointer: RadioPtr): boolean;
//function ProcessRadioDTR(CMD: ShortString; RadioPointer: RadioPtr): boolean;
//function GetPortFromChar(port: ShortString): PortType;

var
  ConfigFileRead                        : Text;
  ClearDupeSheetCommandGiven            : boolean;
  RunningConfigFile                     : boolean; { True when using Control-V command }

//  tr4w_BoolValue                        : boolean;
  //const

implementation

uses
  uCFG,
  //   Settings_unit,
//  OZCHR,
  uNet,
  uRadioPolling,
  uBandmap,
  MainUnit;

procedure SniffOutControlCharacters(var TempString: ShortString);

var
  NumericString                         : Str20;
  {wli StringLength, }NumericValue, Result: integer;

begin
  if TempString = '' then Exit;

  //wli  StringLength := length(TempString);

  Count := 1;

  while Count <= length(TempString) - 3 do
     begin
     if (TempString[Count] = '<') and (TempString[Count + 3] = '>') then
        begin
        NumericString := UpperCase(Copy(TempString, Count + 1, 2));

        HexToInteger(NumericString, NumericValue, Result);

        if Result = 0 then
           begin
           Delete(TempString, Count, 4);
           Insert(AnsiChar(NumericValue), TempString, Count);
           end;
        end;

     inc(Count);
     end;
end;

function ProcessConfigInstructions1(ID: Str80; CMD: ShortString): boolean;

begin
  ProcessConfigInstructions1 := False;

  if CheckCommand(ID, CMD) then
     begin
     ProcessConfigInstructions1 := True;
     Exit;
     end;



end;
   // Tom commented out to verify nothing call sit
// Removed ProcessConfigInstruction2

function ProcessConfigInstructions3(ID: Str80; CMD: ShortString): boolean;

begin
  ProcessConfigInstructions3 := False; //wli

  if CheckCommand(ID, CMD) then
     begin
     ProcessConfigInstructions3 := True;
     Exit;
     end;





end;

function ProcessConfigInstruction(var FileString: ShortString; var FirstCommand: boolean): boolean;
var
  ID                                    : ShortString;
  CMD                                   : ShortString;
  Position                              : integer;
begin
  if FileString = '' then
     begin
     ProcessConfigInstruction := True;
     Exit;
     end;

  (* THE SAME FOUR MARKERS EnmuCFGFile SKIPS: ; and # are comments, [ is a
    section header, _ an internal marker.  This tested only ; and [, which cost
    nothing while the routine ignored every line anyway -- but now that it
    parses, a # comment would become an unrecognised command and raise the
    caller's modal.  Closing the gap here is part of making the split safe,
    not a separate tidy-up.  Column 1, before any spaces are stripped, exactly
    as the other reader does it. *)
  if FileString[1] in [';', '#', '[', '_'] then
     begin
     ProcessConfigInstruction := True;
     Exit;
     end;



  (* SPLIT THE LINE, WHICH IS THE ONE THING THIS ROUTINE EXISTS TO DO.

    IT DID NOT, FOR AS LONG AS THE HISTORY GOES BACK.  ID and CMD were
    declared and handed straight to CheckCommand without anything ever being
    put in them -- ShortStrings, so not zero-initialised either, which is how
    FPC came to report both.  The operator-facing symptom is that a config
    file executed with ctrl-V or the EXECUTE command DOES NOTHING:
    CheckCommand cannot match a name that was never extracted, so every line
    is ignored.  commands_help_eng.ini describes that feature as working.

    Worse before this: a garbage ID could return False, and
    LogCfg.LoadInSeparateConfigFile turns a False into a modal "invalid
    statement" AND an Exit that abandons the rest of the file.

    THE SPLIT IS EnmuCFGFile'S, COPIED RATHER THAN INVENTED.  LogCfg.pas:1223
    does exactly this to every line of the main config file: trim the line,
    take the name before '=' and the value after it, then trim both.  Reading
    an executed file the same way the config reader reads its own is the only
    definition of "correct" available here.

    NOT COPIED, DELIBERATELY: EnmuCFGFile's cfgCFG-only rules -- the
    MY CALL-must-be-first check and the SPACE/FM value fixups.  Those are facts
    about a contest file, not about a file the operator chose to execute. *)
  GetRidOfPrecedingSpaces(FileString);
  GetRidOfPostcedingSpaces(FileString);

  (* SPLIT IN SHORTSTRING, NOT THROUGH utils_text.PrecedingString.

    EnmuCFGFile calls those helpers, and calling them here too was the first
    version of this fix.  IT FAILED THE BUILD: they take and return `string`,
    which tr4w.inc makes UTF-16, while FileString, ID and CMD are every one a
    ShortString -- so the round trip added TWO narrowing conversions and took
    the count to 1353 against a ceiling of 1351.  That ceiling is a ratchet
    meant to fall, and "raise it by two" is the wrong answer to a conversion
    that did not need to happen.

    Copy() of a ShortString yields a ShortString, so this stays in one type
    and converts nothing.

    THE SEMANTICS ARE PrecedingString's AND PostcedingString's, EXACTLY, and
    the edge cases are the reason they are spelled out rather than assumed:
    the name is taken only when '=' is at position 2 or later, so a line that
    STARTS with '=' yields an empty ID; and a line with no '=' at all yields
    empty for both.  An empty ID then meets the `if ID = ''` test below and
    the line is accepted and ignored -- which is what keeps a junk line from
    raising the caller's modal and abandoning the rest of the file. *)
  Position := Pos('=', FileString);

  if Position >= 2 then
     begin
     ID := Copy(FileString, 1, Position - 1);
     end
  else
     begin
     ID := '';
     end;

  if Position > 0 then
     begin
     CMD := Copy(FileString, Position + 1, Length(FileString) - Position);
     end
  else
     begin
     CMD := '';
     end;

  GetRidOfPrecedingSpaces(ID);
  GetRidOfPrecedingSpaces(CMD);
  GetRidOfPostcedingSpaces(ID);
  GetRidOfPostcedingSpaces(CMD);

  ProcessConfigInstruction := CheckCommand(ID, CMD);

  if ID = '' then
     begin
     ProcessConfigInstruction := True;
     end;
end;

function ProcessRadioTypeold(CMD: ShortString; RadioPointer: RadioPtr): boolean;

begin
end;
end.

