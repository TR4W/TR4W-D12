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
unit LogDom;
{$I ..\tr4w.inc}

{$IMPORTEDDATA OFF}
interface

uses
utils_text,
  VC,
  TF,
  uMults,
  Tree;

//const
//  MaxNumberRemainingDomQTHs             = 3072 - 1; //2999;

type

  (* RemainingMultDisplayModeType MOVED to uSettingsModel, 2026-09-13. *)
 // ExternalLogType = (NoExternalLogger, DXKeeper, ACLog, HRD);

  PrefixRecPtr = ^PrefixRec;

  PrefixRec = record
    Prefix: string[10];
    DomQTH: string[10];
    Multiplier: string[10];
    NextRecord: PrefixRecPtr;
  end;

  RemainingDomMultRec = record
    ID: string[11];
    Name: string[19];
  end;

//  RemainingDomMultArrayType = array[0..MaxNumberRemainingDomQTHs] of RemainingDomMultRec {string[7 + 8]};
//  RemainingDomMultArrayPtr = ^RemainingDomMultArrayType;

  DomQTHTableObject = object

//   {?}ActiveDomQTHFile: ShortString;
    FirstPrefixRecord: array[1..37] of PrefixRecPtr; {KK1L: 6.72 36 from 26. Allows for numbers in DOM}
    LastPrefixRecord: array[1..37] of PrefixRecPtr; {KK1L: 6.72 36 from 26. Allows for numbers in DOM}
    NumberRemainingMults: integer;
//    RemainingDomMults: RemainingDomMultArrayPtr;

    procedure AddNewPrefixRecord(Prefix: Str20; DomQTH: Str20; Multiplier: Str20);

//    function GetDomMultInteger(InputString: Str20): integer;
//    function GetDomMultName(DomMultInteger: integer): Str20;

    function GetDomQTH(InputString: Str20; var Multiplier: Str10; var QTH: Str10): boolean;
    function GetStandardDomesticQTH(InputString: Str20): Str20;
//    procedure EnumDOMFILE(FileString: PShortString);
    function LoadInDomQTHFile(const FileName: string): boolean;
    function ReadDomQTHFile(const FileName: string; IncludedFile: boolean): boolean;
    function RecordPointerIndex(FirstLetter: AnsiChar): integer;
  end;

procedure EnumDOMFILE(FileString: PShortString);
(* The const section held one live entry, RemainingMultDisplayModeTypeSA,
  which moved to uSettingsModel with its type on 2026-09-13. The only other
  line in it was already commented out. *)
//  ExternalLogTypeSA                     : array[ExternalLogType] of PChar( = ('None', 'DXKeeper', 'ACLog', 'HRD');

var
  (* ActiveDomesticMult MOVED -- M10 S9e, 2026-10-14. It is
    uContestSession.ContestSession.DomesticMult, written only by FCONTEST's
    set-up path. *)
  DomQTHTable                           : DomQTHTableObject;
  LiteralDomesticQTH                    : boolean; //QTHString (if true) or DomesticQTH {if false}
  MultipliersIsCounties                 : boolean;
implementation

uses
  uAppPaths,     // ShippedDomFilePath -- shipped data, whatever case
  ZoneCont,
  LogWind,
  MainUnit, LogSCP, {KK1L: DEBUG}
  uContestSession, (* ContestSession.DoingDomesticMults -- M10 S9e *)
  (* Contest, the active contest's type -- asked of the factory below. *)
  PostUnit,
  (* ContestDomesticMultiplierFromQTH, TDomesticQTHAnswer -- GetDomQTH asks
    the contest what a received QTH means (M11 S6). *)
  uContestBase,
  uContestFactory;

procedure DomQTHTableObject.AddNewPrefixRecord(Prefix: Str20; DomQTH: Str20; Multiplier: Str20);

var
  Index                                 : integer;

begin
  Index := RecordPointerIndex(Prefix[1]);

  if Index <= 0 then Exit;

  if FirstPrefixRecord[Index] = nil then
     begin
     FirstPrefixRecord[Index] := New(PrefixRecPtr);
     FirstPrefixRecord[Index]^.DomQTH := DomQTH;
     FirstPrefixRecord[Index]^.Multiplier := Multiplier;
     FirstPrefixRecord[Index]^.Prefix := Prefix;
     FirstPrefixRecord[Index]^.NextRecord := nil;
     LastPrefixRecord[Index] := FirstPrefixRecord[Index];
     end
  else
     begin
     {?}
         LastPrefixRecord[Index]^.NextRecord := New(PrefixRecPtr);
         LastPrefixRecord[Index] := LastPrefixRecord[Index]^.NextRecord;
         LastPrefixRecord[Index]^.Multiplier := Multiplier;
         LastPrefixRecord[Index]^.DomQTH := DomQTH;
         LastPrefixRecord[Index]^.Prefix := Prefix;
         LastPrefixRecord[Index]^.NextRecord := nil;
     end;

end;

function DomQTHTableObject.LoadInDomQTHFile(const FileName: string): boolean;

begin

  LoadInDomQTHFile := False;

//  if ActiveDomQTHFile = FileName then
//  begin
//    LoadInDomQTHFile := True;
//    Exit;
//  end;

  //{WLI}    Directory := FindDirectory (FileName);

  if not DomQTHTable.ReadDomQTHFile(FileName, False) then
     begin
     //    ActiveDomQTHFile := '';
         Exit;
     end;

  LoadInDomQTHFile := True;
//  ActiveDomQTHFile := FileName;
end;

function DomQTHTableObject.GetStandardDomesticQTH(InputString: Str20): Str20;

var
  CurrentPrefixRecord                   : PrefixRecPtr;
  Index                                 : integer;

begin
  GetStandardDomesticQTH := '';

  strU(InputString);

  Index := RecordPointerIndex(InputString[1]);

  {IF (Index <= 0) OR (Index > 26) THEN Exit;}
  {KK1L: 6.72 NOTE RecordPointerIndex returns 0-36 on its own. 0=0..9=9, A=10..Z=35.}
  {                Why limit this to the numbers 0-9 and letters A-P??              }
  {                BECAUSE the procedure used is in the object NOT the one in COUNTRY9.PAS!!!}
  {                I modified local procedure to match the one in COUNTRY9.PAS so numbers can be used.}
  if (Index <= 0) or (Index > 36) then Exit; {KK1L: 6.72}

  if FirstPrefixRecord[Index] = nil then Exit;

  while InputString <> '' do
     begin
     CurrentPrefixRecord := FirstPrefixRecord[Index];

     repeat
       if CurrentPrefixRecord^.Prefix = InputString then
          begin
          GetStandardDomesticQTH := CurrentPrefixRecord^.DomQTH;
          Exit;
          end;

       if CurrentPrefixRecord <> nil then
          begin
          CurrentPrefixRecord := CurrentPrefixRecord^.NextRecord;
          end;
     until CurrentPrefixRecord = nil;

     Delete(InputString, length(InputString), 1);
     end;

end;

function DomQTHTableObject.GetDomQTH(InputString: Str20;
  var Multiplier: Str10;
  var QTH: Str10): boolean;

{ Returns TRUE if found }

var
  CurrentPrefixRecord                   : PrefixRecPtr;
  Index                                 : integer;
  found                                 : boolean;

begin

  FillChar(Multiplier, SizeOf(Multiplier), 0); //  Multiplier := '';
  FillChar(QTH, SizeOf(QTH), 0); //    QTH := '';
   GetDomQTH := False;

  strU(InputString);

  if not ContestSession.DoingDomesticMults then
     begin
     QTH := InputString;
     GetDomQTH := True;
     Exit;
     end;

  (* THE CONTEST'S RULE -- M11 S6 part 1, 2026-10-14. Six arms stood here,
    `if ContestSession.DomesticMult = ...`, each a shape chosen FOR the
    contest: an RDA district, the text as written, a DOK, an IOTA reference,
    a grid square, a grid field. Each contest whose domestic QTH is one of
    those states its own rule now (TContestBase.DomesticMultiplierFromQTH,
    the shared shapes in uDomesticKey); every other answers that the file
    below is consulted, as DomesticFile and NumericID fell through to it.

    THE IOTA ARM'S FALL-THROUGH IS KEPT. It had no Exit, so a valid
    reference reached the file lookup already found, and a text with no
    known continent reached it not found (plan F6). The answer carries both:
    dqaLookUpDomesticFile with whatever the rule wrote, which the file
    lookup keeps unless it knows the text.

    ONE ActiveContest, AFTER THE NO-DOMESTIC EXIT -- a contest with no
    domestic multiplier pays nothing it did not pay before. The callers
    (FoundDomesticQTH's, live entry and the parse shapes) hold no contest
    object to hand down. *)
  found := False;
  if ContestDomesticMultiplierFromQTH(ActiveContest(Contest), InputString,
                                      Multiplier, QTH, found) = dqaDecided then
     begin
     GetDomQTH := found;
     Exit;
     end;
  GetDomQTH := found;

  Index := RecordPointerIndex(InputString[1]);

  {IF (Index <= 0) OR (Index > 26) THEN Exit;}
  {KK1L: 6.72 NOTE RecordPointerIndex returns 0-36 on its own. 0=0..9=9, A=10..Z=35.}
  {                Why limit this to the numbers 0-9 and letters A-P??              }
  {                BECAUSE the procedure used is in the object NOT the one in COUNTRY9.PAS!!!}
  {                I modified local procedure to match the one in COUNTRY9.PAS so numbers can be used.}

  //  if (Index <= 0) or (Index > 36) then Exit; {KK1L: 6.72}
  if not (Index in [0..36]) then Exit; {KK1L: 6.72}

  if FirstPrefixRecord[Index] = nil then Exit;

//  while InputString <> '' do
  begin
    CurrentPrefixRecord := FirstPrefixRecord[Index];

    repeat
      if CurrentPrefixRecord^.Prefix = InputString then
         begin
         QTH := CurrentPrefixRecord^.DomQTH;
         Multiplier := CurrentPrefixRecord^.Multiplier;
         GetDomQTH := True;
         Exit;
         end;

      if CurrentPrefixRecord <> nil then
         begin
         CurrentPrefixRecord := CurrentPrefixRecord^.NextRecord;
         end;
    until CurrentPrefixRecord = nil;

//    Delete(InputString, length(InputString), 1);
  end;

end;

function DomQTHTableObject.RecordPointerIndex(FirstLetter: AnsiChar): integer;

var
  TempInt, Result1                      : integer;

  {BEGIN
  {IF (FirstLetter >= 'A') AND (FirstLetter <= 'Z') THEN  }
  {    BEGIN                                              }
  {    TempInt := Ord (FirstLetter) - Ord ('A') + 1;      }
  {    RecordPointerIndex := TempInt;                     }
  {    END                                                }
  {ELSE                                                   }
  {    RecordPointerIndex := -1;                          }
  {END;                                                   }
 {KK1L: 6.72 Replaced above to allow use of numbers in the DOM file}
 {           Returns a value of 1 through 36 for 0-9, A-Z.         }
begin
  Val(FirstLetter, TempInt, Result1);

  if Result1 = 0 then
     begin
     RecordPointerIndex := TempInt + 1;
     Exit;
     end
  else
    if FirstLetter in ['A'..'Z'] then
       begin
       TempInt := Ord(FirstLetter) - Ord('A') + 11;
       RecordPointerIndex := TempInt;
       end
    else
       begin
       RecordPointerIndex := -1;
       end;
end;

function GetNextPrefix(var FileString: ShortString {Str160};
  var PrefixString: ShortString {Str20}): boolean;

begin
  GetNextPrefix := False;

  if FileString = '' then
     begin
     PrefixString := '';
     Exit;
     end;

  if StringHas(FileString, ',') then
     begin
     PrefixString := PrecedingString(FileString, ',');
     FileString := PostcedingString(FileString, ',');
     GetRidOfPrecedingSpaces(FileString);
     end
  else
     begin
     PrefixString := FileString;
     FileString := '';
     end;

  if StringHas(PrefixString, '(') then
     begin
     PrefixString := PrecedingString(PrefixString, '(');
     GetRidOfPostcedingSpaces(PrefixString);
     end;

  GetNextPrefix := PrefixString <> '';
end;

function DomQTHTableObject.ReadDomQTHFile(const FileName: string; IncludedFile: boolean): boolean;

label
  AlreadyInList;

var
  RecordPointer          : integer;
  CurrentRecord, NextRecord             : PrefixRecPtr;
const incfile                           = 'INCLUDE FILE';

begin
  ReadDomQTHFile := False;

  if not IncludedFile then
     begin
     NumberRemainingMults := 0;
     end;

//  if RemainingDomMults = nil then New(RemainingDomMults);
//  if not IncludedFile then FillChar(RemainingDomMults^, SizeOf(RemainingDomMultArrayType), 0);

  if not IncludedFile then
     begin
     for RecordPointer := 1 to 36 do //KK1L: 6.72 1-36 from 1-26 to allow for numbers in DOM file
        begin
        if FirstPrefixRecord[RecordPointer] <> nil then
           begin
           CurrentRecord := FirstPrefixRecord[RecordPointer];
           NextRecord := FirstPrefixRecord[RecordPointer]^.NextRecord;

           while CurrentRecord <> nil do
              begin
              Dispose(CurrentRecord);
              CurrentRecord := NextRecord;
              NextRecord := CurrentRecord^.NextRecord;
              end;
           end;

        FirstPrefixRecord[RecordPointer] := nil;
        LastPrefixRecord[RecordPointer] := nil;
        end;
     end;

  if not EnumerateLinesInFile(FileName, EnumDOMFILE, False) then

//  if not OpenFileForRead(FileRead, FileName) then
     begin
     (* THE ONLY SETTING THAT NAMES A .DOM IS DOMESTIC FILENAME, so the
       attribution is not a guess -- see TF.UnableToFindFileMessage. *)
     UnableToFindFileMessage(FileName, 'DOMESTIC FILENAME');
     Exit;
     end;

  //  NumberRemainingMults:=NumberRemainingMults;
  ReadDomQTHFile := True;
end;

procedure EnumDOMFILE(FileString: PShortString);
const incfile                           = 'INCLUDE FILE';
label
  AlreadyInList;

var
  DomQTHString, DomQTHName, Multiplier, TempString: ShortString; {: Str40;}
  DomName                               : Str40;
  TempFileName                          : FileNameType;
  MultIndex                             : integer;
begin
  GetRidOfPrecedingSpaces(FileString^);

  if Copy(FileString^, 1, length(incfile)) = incfile then
     begin
     TempString := Copy(FileString^, length(incfile) + 2, 200);
     (* THE TAIL IS ALREADY IN TempString, on the line above. The sprintf
       re-read it from the ShortString's CHARACTERS -- @FileString^[n] -- and a
       ShortString has no terminator, so that read ran on until it met a zero
       byte belonging to something else. *)
     (* THE dom DIRECTORY, WITH ITS SEPARATOR. D7 built this with
       '%sDOM\%s'; the conversion that replaced the sprintf (c51dcc1d)
       dropped the backslash, so 'INCLUDE FILE S50.DOM' asked for
       <program dir>DOMS50.DOM -- which does not exist, and every .dom that
       includes the states, provinces or Mexico loaded without them. FCONTEST's
       in-state test had the same slip; all three dom readers compose the path
       in one place now, uAppPaths.ShippedDomFilePath. *)
     SetCharBuffer(TempFileName, ShippedDomFilePath(string(TempString)));
     DomQTHTable.ReadDomQTHFile(CharBufferText(TempFileName), True);
     end;
//todo process ;
  if StringHas(FileString^, '=') then
     begin
     TempString := PrecedingString(FileString^, '=');

     GetRidOfPrecedingSpaces(TempString);
     GetRidOfPostcedingSpaces(TempString);

     if StringHas(TempString, '>') then
        begin
        DomQTHName := PrecedingString(TempString, '>');
        Multiplier := PostcedingString(TempString, '>');

        GetRidOfPrecedingSpaces(Multiplier);
        GetRidOfPostcedingSpaces(DomQTHName);

        if MultipliersIsCounties then
           begin
           Multiplier := DomQTHName;
           end;
                // Added in 6.30
  //?

  //        if NumberRemainingMults > 0 then
  //          for RemainingMult := 0 to NumberRemainingMults - 1 do
  //            if RemainingDomMults^[RemainingMult].ID = Multiplier then
  //              goto AlreadyInList;

  //        if NumberRemainingMults < MaxNumberRemainingDomQTHs then
  //        begin
  //          RemainingDomMults^[NumberRemainingMults].ID := Multiplier;
  //          RemainingDomMults^[NumberRemainingMults].Name := Multiplier; //?
  //          inc(NumberRemainingMults);
  //        end;

        AlreadyInList:

        end
     else
        begin

        DomQTHName := TempString;
        Multiplier := TempString;

  //        if DomQTHName <> '' then //wli
  //          if NumberRemainingMults < MaxNumberRemainingDomQTHs then
  //          begin
  //            RemainingDomMults^[NumberRemainingMults].ID := DomQTHName;
  //            RemainingDomMults^[NumberRemainingMults].Name := DomQTHName;
  //            inc(NumberRemainingMults);
  //          end;

        end;

     Multiplier[Ord(Multiplier[0]) + 1] := #0;
     MultIndex := mo.DomList.AddString(Multiplier, NoBand, NoMode, True);

     FileString^ := PostcedingString(FileString^, '=');

     while FileString^ <> '' do
        begin
        if StringHas(FileString^, ',') then
           begin
           DomName := PrecedingString(FileString^, ',')
           end
        else
           begin
           DomName := FileString^;
           end;

        DomQTHString := UpperCase(DomName);

        GetRidOfPrecedingSpaces(DomQTHString);
        GetRidOfPostcedingSpaces(DomQTHString);

        GetRidOfPrecedingSpaces(DomName);
        GetRidOfPostcedingSpaces(DomName);

        if DomQTHString[1] <> '^' then
           begin
           DomQTHTable.AddNewPrefixRecord(DomQTHString, DomQTHName, Multiplier)
           end
        else
           begin
           if length(DomQTHString) > tRemMultsColumnWidth then
              begin
              tRemMultsColumnWidth := length(DomName);
              end;
           mo.DomList.FList[MultIndex].FAltName := Copy(DomQTHString, 2, 32);
   //          RemainingDomMults^[NumberRemainingMults - 1].Name := Copy(DomName, 2, 32);
           end;

        if StringHas(FileString^, ',') then
           begin
           FileString^ := PostcedingString(FileString^, ',')
           end
        else
           begin
           FileString^ := '';
           end;
        end;
     end;

end;

end.
