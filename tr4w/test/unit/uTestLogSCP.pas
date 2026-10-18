unit uTestLogSCP;
{$I ..\..\src\tr4w.inc}

(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 *)

(* THE SUPER CHECK PARTIAL ANSWERS, OVER THE SHIPPED-FORMAT FIXTURE.
  Pointer audit packet P7 (docs/POINTER_AUDIT.md 2.2, 6.4, 7.5), 2026-10-17.

  WHY IT EXISTS. logscp.pas read a TRMASTER.DTA cell into a buffer that had
  TWO allocators for one pointer (New in the "post" mode, GetMem in the
  running program's mode) and a pointer-handing routine, and ran on every
  keystroke of a callsign. P7 moves the cell into a native container owned
  by an object. The contest matrix sees only the initial-exchange path, so
  this unit pins what the matrix cannot: the partial-call results (the
  possible-call list and the one-at-a-time partial walk), the entry lookup
  for several cells, a miss, the 'JA' pair, and the operator-name walk.

  THE FIXTURE IS tr4w/test/contest-matrix/MATRIX-TRMASTER.DTA -- the file
  the matrix itself reads, built from trmaster-fixture.txt (nine calls). It
  is the real TRMASTER.DTA format, and it does not change when the shipped
  file is refreshed.

  HOW THE LITERALS WERE MADE. Run against the UNCHANGED logscp.pas first
  (pointer buffers), green, and only then was the buffer converted. They are
  not regenerated to clear a failure.

  BOTH MODES. The running program sets CellBuffer.MaximumMemoryToUse to
  40000 * 4 (logstuff); a tool leaves the unit's own 3 * BufferArraySize
  ("post" mode). The two took different branches of the old allocator, so
  every check runs under both.

  F22 (2026-10-14) is held here too: LOGSCP.BestTwoLetters read an
  uninitialised slot for the 'JA' pair, so whether JA1ABC was found depended
  on the call looked up BEFORE it. Test_JAPair_NeverDependsOnThePreviousCall
  looks it up after each of the other calls. *)

interface

uses
   SysUtils, Classes, uTR4WTestFramework, VC, LogSCP, uSettingsModel;

type
   TBodyProc = procedure of object;

   TLogSCPTests = class(TTestCase)
   private
      FSavedFile       : FileNameType;
      FSavedExists     : boolean;
      FSavedDisabled   : boolean;
      FSavedMode       : PossibleCallActionType;
      FSavedMemory     : LongInt;
      function FixturePath: string;
      procedure OpenFixture(aMemory: LongInt);
      procedure CloseFixture;
      procedure RunInBothModes(aBody: TBodyProc);
      procedure CheckEntry(const aCall, aName, aQTH, aSection, aCheck, aGrid,
         aCQ, aITU: string);
      function PossibleCalls(const aCall: string): string;
      function PartialWalk(const aPartial: string): string;

      procedure BodyEntries;
      procedure BodyEveryField;
      procedure BodyMiss;
      procedure BodyJAPair;
      procedure BodyJAAfterEveryOther;
      procedure BodyPossibleCalls;
      procedure BodyPartialWalk;
      procedure BodyOperatorNames;
      procedure BodyAlternatingCells;
   protected
      procedure Test_Entries_AcrossCells;
      procedure Test_Entry_EveryField;
      procedure Test_Entry_Miss;
      procedure Test_JAPair_Found;
      procedure Test_JAPair_NeverDependsOnThePreviousCall;
      procedure Test_PossibleCalls_List;
      procedure Test_PartialWalk_OneAtATime;
      procedure Test_OperatorNames;
      procedure Test_AlternatingCells_ReloadCorrectly;
      procedure Test_LookupLoop_Timing;
   public
      procedure RunAllTests; override;
   end;

implementation

const
   TR_MODE_MEMORY   = 40000 * ua4wliscpconst;   (* what logstuff sets at run time *)
   POST_MODE_MEMORY = 3 * BufferArraySize;      (* the unit's own default *)

function TLogSCPTests.FixturePath: string;
begin
   Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
      'contest-matrix' + PathDelim + 'MATRIX-TRMASTER.DTA');
end;

procedure TLogSCPTests.OpenFixture(aMemory: LongInt);
var
   path: string;
   i   : integer;
begin
   FSavedFile     := CD.ActiveFilename;
   FSavedExists   := CD.MasterFileExists;
   FSavedDisabled := CD.SCPDisabledByApplication;
   FSavedMode     := Settings.Scp.PossibleCallMode;
   FSavedMemory   := CD.CellBuffer.MaximumMemoryToUse;

   (* Let go of whatever file an earlier test left open, so the lookup opens
     the fixture and not the shipped TRMASTER.DTA. *)
   CD.SCPDisableAndDeAllocateFileBuffer;
   CD.SCPDisabledByApplication := False;
   CD.CellBuffer.GoAway;
   CD.LastCallRecord.Call := '';
   CD.InitialPartialCall  := '';

   path := FixturePath;
   Check(FileExists(path), 'the matrix fixture is there: ' + path);
   for i := 0 to High(CD.ActiveFilename) do
      begin
      CD.ActiveFilename[i] := #0;
      end;
   for i := 1 to Length(path) do
      begin
      CD.ActiveFilename[i - 1] := path[i];
      end;
   CD.MasterFileExists := True;
   CD.CellBuffer.MaximumMemoryToUse := aMemory;
   Settings.Scp.PossibleCallMode := AnyCall;
end;

procedure TLogSCPTests.CloseFixture;
begin
   CD.SCPDisableAndDeAllocateFileBuffer;
   CD.CellBuffer.GoAway;
   CD.LastCallRecord.Call := '';
   CD.InitialPartialCall  := '';

   CD.ActiveFilename          := FSavedFile;
   CD.MasterFileExists        := FSavedExists;
   CD.SCPDisabledByApplication := FSavedDisabled;
   CD.CellBuffer.MaximumMemoryToUse := FSavedMemory;
   Settings.Scp.PossibleCallMode := FSavedMode;
end;

procedure TLogSCPTests.RunInBothModes(aBody: TBodyProc);
begin
   OpenFixture(TR_MODE_MEMORY);
   try
      aBody;
   finally
      CloseFixture;
   end;

   OpenFixture(POST_MODE_MEMORY);
   try
      aBody;
   finally
      CloseFixture;
   end;
end;

procedure TLogSCPTests.CheckEntry(const aCall, aName, aQTH, aSection, aCheck,
   aGrid, aCQ, aITU: string);
var
   data: DataBaseEntryRecord;
begin
   Check(CD.GetEntry(aCall, data), aCall + ' is found');
   CheckEquals(aCall, string(data.Call), aCall + ' call');
   CheckEquals(aName, string(data.mName), aCall + ' name');
   CheckEquals(aQTH, string(data.QTH), aCall + ' QTH');
   CheckEquals(aSection, string(data.Section), aCall + ' section');
   CheckEquals(aCheck, string(data.Check), aCall + ' check');
   CheckEquals(aGrid, string(data.Grid), aCall + ' grid');
   CheckEquals(aCQ, string(data.CQZone), aCall + ' CQ zone');
   CheckEquals(aITU, string(data.ITUZone), aCall + ' ITU zone');
end;

function TLogSCPTests.PossibleCalls(const aCall: string): string;
var
   i: integer;
begin
   CD.GeneratePossibleCallList(aCall);
   Result := '';
   for i := 0 to PossibleCallList.NumberPossibleCalls - 1 do
      begin
      if Result <> '' then
         begin
         Result := Result + ',';
         end;
      Result := Result + string(PossibleCallList.List[i].Call);
      end;
end;

function TLogSCPTests.PartialWalk(const aPartial: string): string;
var
   call: CallString;
begin
   Result := '';
   if not CD.PartialCallSetup(aPartial) then
      begin
      Result := '<no setup>';
      Exit;
      end;
   repeat
      CD.GetNextPartialCall(call);
      if call <> '' then
         begin
         if Result <> '' then
            begin
            Result := Result + ',';
            end;
         Result := Result + string(call);
         end;
   until call = '';
end;

(* ---------------------------------------------------------------- bodies *)

procedure TLogSCPTests.BodyEntries;
begin
   (* Different calls land in different two-letter cells, so each GetEntry
     reloads the cell buffer. *)
   CheckEntry('W1AW',   'HIRAM', 'CT', 'CT',  '14', 'FN31', '5',  '8');
   CheckEntry('K4ABC',  'BOB',   'FL', 'NFL', '85', 'EL89', '5',  '8');
   CheckEntry('VE3ABC', 'ANN',   'ON', 'ONE', '72', 'FN03', '4',  '4');
   CheckEntry('DL1ABC', 'HANS',   '',  '',    '',  'JO62', '14', '28');
   CheckEntry('UA9ABC', 'IVAN',   '',  '',    '',  'MO06', '18', '31');
   CheckEntry('VK2ABC', 'BRUCE',  '',  '',    '',  '',     '',   '');
   CheckEntry('ON4ABC', 'JEAN',   '',  '',    '',  'JO20', '',   '');
end;

procedure TLogSCPTests.BodyEveryField;
var
   data: DataBaseEntryRecord;
begin
   Check(CD.GetEntry('K9ABC', data), 'K9ABC is found');
   CheckEquals('ZED',    string(data.mName),   'name');
   CheckEquals('IL',     string(data.QTH),     'QTH');
   CheckEquals('IL',     string(data.Section), 'section');
   CheckEquals('90',     string(data.Check),   'check');
   CheckEquals('EN52',   string(data.Grid),    'grid');
   CheckEquals('4',      string(data.CQZone),  'CQ zone');
   CheckEquals('8',      string(data.ITUZone), 'ITU zone');
   CheckEquals('1234',   string(data.FOC),     'FOC');
   CheckEquals('WB9ABC', string(data.OldCall), 'old call');
   CheckEquals('5678',   string(data.TENTEN),  'ten-ten');
   CheckEquals('U1',     string(data.User1),   'user 1');
   CheckEquals('U2',     string(data.User2),   'user 2');
   CheckEquals('U3',     string(data.User3),   'user 3');
   CheckEquals('U4',     string(data.User4),   'user 4');
   CheckEquals('U5',     string(data.User5),   'user 5');
end;

procedure TLogSCPTests.BodyMiss;
var
   data: DataBaseEntryRecord;
begin
   CheckFalse(CD.GetEntry('ZZ9ZZZ', data), 'a call in no cell is a miss');
   CheckEquals('', string(data.Call), 'a miss leaves the record empty');

   (* A call that shares a cell with a stored one but is not stored. *)
   CheckFalse(CD.GetEntry('K9ABD', data), 'a near call is a miss');
   CheckEquals('', string(data.mName), 'a near miss leaves no name');

   (* And a hit still works after the misses. *)
   Check(CD.GetEntry('W1AW', data), 'W1AW is found after the misses');
   CheckEquals('HIRAM', string(data.mName), 'W1AW name after the misses');
end;

procedure TLogSCPTests.BodyJAPair;
begin
   CheckEntry('JA1ABC', 'TARO', '', '', '', 'PM95', '25', '45');
end;

procedure TLogSCPTests.BodyJAAfterEveryOther;
var
   data  : DataBaseEntryRecord;
   others: array[0..7] of string;
   i     : integer;
begin
   others[0] := 'W1AW';
   others[1] := 'K4ABC';
   others[2] := 'VE3ABC';
   others[3] := 'DL1ABC';
   others[4] := 'VK2ABC';
   others[5] := 'UA9ABC';
   others[6] := 'ON4ABC';
   others[7] := 'K9ABC';
   for i := 0 to High(others) do
      begin
      Check(CD.GetEntry(others[i], data), others[i] + ' is found');
      CD.LastCallRecord.Call := '';
      Check(CD.GetEntry('JA1ABC', data), 'JA1ABC is found after ' + others[i]);
      CheckEquals('TARO', string(data.mName), 'JA1ABC name after ' + others[i]);
      CD.LastCallRecord.Call := '';
      end;
end;

procedure TLogSCPTests.BodyPossibleCalls;
begin
   CheckEquals('ON4ABC', PossibleCalls('ON4ABC'), 'ON4ABC');
   CheckEquals('', PossibleCalls('ZZ9ZZZ'), 'a call near nothing');
   CheckEquals('K4ABC,K9ABC', PossibleCalls('K9ABC'), 'K9ABC: two cells, merged and sorted');
   CheckEquals('K4ABC,K9ABC', PossibleCalls('K9ABC'), 'K9ABC again');
   CheckEquals('DL1ABC', PossibleCalls('DL1ABC'), 'DL1ABC');
   CheckEquals('K4ABC', PossibleCalls('K4ABD'), 'K4ABD is one off K4ABC');
   CheckEquals('K4ABC', PossibleCalls('K4ABCD'), 'K4ABCD');
   CheckEquals('K9ABC', PossibleCalls('K9AB'), 'K9AB');
   CheckEquals('VE3ABC', PossibleCalls('VE3ABD'), 'VE3ABD');
   CheckEquals('VK2ABC', PossibleCalls('VK2ABD'), 'VK2ABD');
   CheckEquals('UA9ABC', PossibleCalls('UA9ABD'), 'UA9ABD');
   CheckEquals('W1AW', PossibleCalls('W1AX'), 'W1AX');
   CheckEquals('', PossibleCalls('JA1ABD'), 'JA1ABD: nothing is similar enough');
end;

procedure TLogSCPTests.BodyPartialWalk;
begin
   CheckEquals('', PartialWalk('ZZ9'), 'a partial in no cell');
   CheckEquals('K9ABC', PartialWalk('K9A'), 'K9A');
   CheckEquals('DL1ABC,JA1ABC,K4ABC,K9ABC,ON4ABC,UA9ABC,VE3ABC,VK2ABC',
      PartialWalk('AB'), 'AB: a cell with eight calls, in file order');
   CheckEquals('DL1ABC,JA1ABC,K4ABC,K9ABC,ON4ABC,UA9ABC,VE3ABC,VK2ABC',
      PartialWalk('ABC'), 'ABC');
   CheckEquals('DL1ABC,JA1ABC', PartialWalk('1AB'), '1AB: two calls');
   CheckEquals('JA1ABC', PartialWalk('JA1'), 'JA1: the JA pair is skipped, the call is not');
   CheckEquals('W1AW', PartialWalk('W1'), 'W1');
   CheckEquals('VE3ABC', PartialWalk('VE3'), 'VE3');
   CheckEquals('DL1ABC', PartialWalk('DL1ABC'), 'DL1ABC');
   CheckEquals('ON4ABC', PartialWalk('ON4'), 'ON4');
   CheckEquals('UA9ABC', PartialWalk('UA9A'), 'UA9A');
   CheckEquals('K9ABC', PartialWalk('K9ABC'), 'K9ABC');

   (* The walk rewinds: asking again for the cell already held gives the
     same list, with no file read in between. *)
   CheckEquals('DL1ABC,JA1ABC,K4ABC,K9ABC,ON4ABC,UA9ABC,VE3ABC,VK2ABC',
      PartialWalk('ABC'), 'ABC again');
   CheckEquals('DL1ABC,JA1ABC,K4ABC,K9ABC,ON4ABC,UA9ABC,VE3ABC,VK2ABC',
      PartialWalk('ABC'), 'ABC a third time');
end;

procedure TLogSCPTests.BodyOperatorNames;
var
   names: TStringList;
begin
   names := TStringList.Create;
   try
      names.Sorted     := True;
      names.Duplicates := dupIgnore;
      CD.BuildOperatorNameSet(names);
      CheckEquals('ANN,BOB,BRUCE,HANS,HIRAM,IVAN,JEAN,TARO,ZED',
         names.CommaText, 'every operator name in the file, once, sorted');
   finally
      names.Free;
   end;
end;

procedure TLogSCPTests.BodyAlternatingCells;
var
   data: DataBaseEntryRecord;
   i   : integer;
begin
   for i := 1 to 20 do
      begin
      CD.LastCallRecord.Call := '';
      Check(CD.GetEntry('W1AW', data), 'W1AW, pass ' + IntToStr(i));
      CheckEquals('HIRAM', string(data.mName), 'W1AW name, pass ' + IntToStr(i));
      CD.LastCallRecord.Call := '';
      Check(CD.GetEntry('K9ABC', data), 'K9ABC, pass ' + IntToStr(i));
      CheckEquals('ZED', string(data.mName), 'K9ABC name, pass ' + IntToStr(i));
      CD.LastCallRecord.Call := '';
      Check(CD.GetEntry('JA1ABC', data), 'JA1ABC, pass ' + IntToStr(i));
      CheckEquals('TARO', string(data.mName), 'JA1ABC name, pass ' + IntToStr(i));
      end;
end;

(* ----------------------------------------------------------------- tests *)

procedure TLogSCPTests.Test_Entries_AcrossCells;
begin
   BeginTest('Test_Entries_AcrossCells');
   RunInBothModes(BodyEntries);
end;

procedure TLogSCPTests.Test_Entry_EveryField;
begin
   BeginTest('Test_Entry_EveryField');
   RunInBothModes(BodyEveryField);
end;

procedure TLogSCPTests.Test_Entry_Miss;
begin
   BeginTest('Test_Entry_Miss');
   RunInBothModes(BodyMiss);
end;

procedure TLogSCPTests.Test_JAPair_Found;
begin
   BeginTest('Test_JAPair_Found');
   RunInBothModes(BodyJAPair);
end;

procedure TLogSCPTests.Test_JAPair_NeverDependsOnThePreviousCall;
begin
   BeginTest('Test_JAPair_NeverDependsOnThePreviousCall');
   RunInBothModes(BodyJAAfterEveryOther);
end;

procedure TLogSCPTests.Test_PossibleCalls_List;
begin
   BeginTest('Test_PossibleCalls_List');
   RunInBothModes(BodyPossibleCalls);
end;

procedure TLogSCPTests.Test_PartialWalk_OneAtATime;
begin
   BeginTest('Test_PartialWalk_OneAtATime');
   RunInBothModes(BodyPartialWalk);
end;

procedure TLogSCPTests.Test_OperatorNames;
begin
   BeginTest('Test_OperatorNames');
   RunInBothModes(BodyOperatorNames);
end;

procedure TLogSCPTests.Test_AlternatingCells_ReloadCorrectly;
begin
   BeginTest('Test_AlternatingCells_ReloadCorrectly');
   RunInBothModes(BodyAlternatingCells);
end;

procedure TLogSCPTests.Test_LookupLoop_Timing;
const
   ITERATIONS = 50000;
var
   i      : integer;
   started: QWord;
   elapsed: QWord;
   calls  : array[0..4] of string;
   total  : integer;
begin
   BeginTest('Test_LookupLoop_Timing');
   (* Not an assertion -- a measurement, printed, so a before/after of the
     buffer conversion is a number and not an impression. It does assert the
     total, so the loop cannot be optimised into doing nothing. *)
   calls[0] := 'W1AW';
   calls[1] := 'K9ABC';
   calls[2] := 'JA1ABC';
   calls[3] := 'VE3ABC';
   calls[4] := 'DL1ABC';
   OpenFixture(TR_MODE_MEMORY);
   try
      total   := 0;
      started := GetTickCount64;
      for i := 1 to ITERATIONS do
         begin
         CD.GeneratePossibleCallList(calls[i mod 5]);
         total := total + PossibleCallList.NumberPossibleCalls;
         end;
      elapsed := GetTickCount64 - started;
      WriteLn(Format('SCP lookup loop: %d GeneratePossibleCallList in %d ms ' +
         '(total %d)', [ITERATIONS, elapsed, total]));
      Check(total >= 0, 'the loop ran');
   finally
      CloseFixture;
   end;
end;

procedure TLogSCPTests.RunAllTests;
begin
   Test_Entries_AcrossCells;
   Test_Entry_EveryField;
   Test_Entry_Miss;
   Test_JAPair_Found;
   Test_JAPair_NeverDependsOnThePreviousCall;
   Test_PossibleCalls_List;
   Test_PartialWalk_OneAtATime;
   Test_OperatorNames;
   Test_AlternatingCells_ReloadCorrectly;
   Test_LookupLoop_Timing;
end;

end.
