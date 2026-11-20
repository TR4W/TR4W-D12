unit uTestLiveDataSwap;
{$I ..\..\src\tr4w.inc}

(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.
 *)

(* LIVE RELOAD OF TRMASTER.DTA AND A CALL HISTORY FILE -- 2026-11-20 (NY4I: the
  program must use a downloaded file at once, mid-contest, with a QSO being
  entered).

  THE DESIGN BEING PINNED. Each file is built whole and PRIVATELY, checked, and
  put in service in one step on the main thread:
    * TRMASTER.DTA  -- LOGSCP: TTRMasterSnapshot, CD.ReplaceTRMasterFile. The
      file is read into memory and closed, the flags and the operator-name set
      change with it, and the caches that held the old file's data are cleared.
    * call history  -- LOGDUPE.LoadCallHistoryFile builds a TCallHistorySnapshot
      and TCallsignsList.ReplaceCallHistory swaps the list's call history LAYER.
      The log's and INITIAL.EX's text is a separate layer that outranks it, so
      "a recent QSO's exchange wins" is a lookup order and a swap cannot lose it.

  Everything that reads either runs on the main thread (checked: no thread
  touches CD or CallsignsList), so "no contention" is a property of the
  design, and these tests pin what a lookup SEES around a swap:
    (a) a call logged before the swap still resolves with its logged exchange,
    (b) the swapped-in data is visible at once -- including for a call the old
        file had just served (the one-entry caches),
    (c) a recent QSO's exchange wins over a call history entry before AND after,
    (d) a file that will not load (missing, cut short, wrong content, an index
        pointing outside the file, no usable row) leaves the old one serving,
    (e) lookup, swap, lookup, over and over: never a freed or half-built state
        (the checked heaptrc run of this suite is the other half of that).

  THE SECOND TRMASTER.DTA is the matrix fixture with a name changed in place,
  same length, so no encoder is needed here. THE TEMP FILES are deleted: the
  snapshot holds no file handle, which is what lets a download replace the file
  in use on Windows. *)

interface

uses
   uTR4WTestFramework;

type
   TLiveDataSwapTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TRMaster_SwapShowsNewDataAtOnce;
      procedure Test_TRMaster_LoggedExchangeSurvivesTheSwap;
      procedure Test_TRMaster_FailedLoadLeavesTheOldServing;
      procedure Test_TRMaster_SwapBetweenLookups;
      procedure Test_TRMaster_SwapInTheMiddleOfAPartialWalk;
      procedure Test_TRMaster_NameSetChangesWithTheFile;
      procedure Test_CallHistory_SwapKeepsTheLogAndShowsTheNewFile;
      procedure Test_CallHistory_ARecentQSOWinsBeforeAndAfter;
      procedure Test_CallHistory_FailedLoadLeavesTheLayer;
      procedure Test_CallHistory_SwapBetweenLookups;
      procedure Test_CallHistory_SnapshotAndLayerRules;
   end;

implementation

uses
   Classes,
   SysUtils,
   VC,
   LogSCP,
   LogDupe,
   PostUnit,
   uSettingsModel,
   uCallsigns,
   uCallHistory,
   uContestBase,
   uContestRegistry,
   utils_text;

const
   (* what logstuff sets at run time, as uTestLogSCP's TR_MODE_MEMORY *)
   TR_MODE_MEMORY = 40000 * ua4wliscpconst;

var
   gSavedFile: FileNameType;
   gSavedExists: boolean;
   gSavedDisabled: boolean;
   gSavedMode: PossibleCallActionType;
   gSavedMemory: LongInt;
   gSavedNameSet: TStringList;

   gSavedList: TCallsignsList;
   gSavedContest: TContestHandle;
   gSavedUse: boolean;
   gSavedHistoryName: string;

   gTempFiles: array of string;
   gReplaced: integer;

(* -------------------------------------------------------------- files *)

function MatrixFixturePath: string;
begin
   Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim +
      'contest-matrix' + PathDelim + 'MATRIX-TRMASTER.DTA');
end;

function SampleHistoryPath: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'callhistory_ss_sample.txt';
end;

(* A temp file name that is deleted when the test ends. *)
function TempPath(const aStem: string; const aExtension: string): string;
begin
   Result := string(GetTempDir(False)) + 'tr4w_swap_' + aStem + '_' +
             IntToStr(GetProcessID) + aExtension;
   SetLength(gTempFiles, Length(gTempFiles) + 1);
   gTempFiles[High(gTempFiles)] := Result;
end;

procedure DeleteTempFiles;
var
   i: integer;
begin
   for i := 0 to High(gTempFiles) do
      begin
      DeleteFile(AnsiString(gTempFiles[i]));
      end;
   SetLength(gTempFiles, 0);
end;

function ReadBytesFile(const aPath: string): TTRMasterBytes;
var
   stream: TFileStream;
begin
   stream := TFileStream.Create(AnsiString(aPath), fmOpenRead or fmShareDenyNone);
   try
      SetLength(Result, stream.Size);
      if stream.Size > 0 then
         begin
         stream.ReadBuffer(Result[0], stream.Size);
         end;
   finally
      stream.Free;
   end;
end;

procedure WriteBytesFile(const aPath: string; const aData: TTRMasterBytes);
var
   stream: TFileStream;
begin
   stream := TFileStream.Create(AnsiString(aPath), fmCreate);
   try
      if Length(aData) > 0 then
         begin
         stream.WriteBuffer(aData[0], Length(aData));
         end;
   finally
      stream.Free;
   end;
end;

(* EVERY occurrence of aFrom becomes aTo (the same length); gReplaced says how
  many. A call's name is stored once per two-letter cell it sits in, so the
  first hit alone would leave the file saying two things. *)
procedure ReplaceAllBytes(var aData: TTRMasterBytes; const aFrom: AnsiString; const aTo: AnsiString);
var
   i: integer;
   j: integer;
   hit: boolean;
begin
   gReplaced := 0;
   for i := 0 to Length(aData) - Length(aFrom) do
      begin
      hit := True;
      for j := 1 to Length(aFrom) do
         begin
         if aData[i + j - 1] <> Ord(aFrom[j]) then
            begin
            hit := False;
            Break;
            end;
         end;
      if hit then
         begin
         for j := 1 to Length(aTo) do
            begin
            aData[i + j - 1] := Ord(aTo[j]);
            end;
         inc(gReplaced);
         end;
      end;
end;

(* A TRMASTER.DTA like the matrix fixture with aFrom's name changed to aTo. *)
function MakeVariant(const aStem: string; const aFrom: AnsiString; const aTo: AnsiString): string;
var
   data: TTRMasterBytes;
begin
   data := ReadBytesFile(MatrixFixturePath);
   ReplaceAllBytes(data, aFrom, aTo);
   Result := TempPath(aStem, '.dta');
   WriteBytesFile(Result, data);
end;

(* A call history file of aRows, one per line. *)
function WriteHistory(const aStem: string; const aRows: array of string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := TempPath(aStem, '.txt');
   lines := TStringList.Create;
   try
      for i := 0 to High(aRows) do
         begin
         lines.Add(AnsiString(aRows[i]));
         end;
      lines.SaveToFile(AnsiString(Result));
   finally
      lines.Free;
   end;
end;

(* ------------------------------------------------------------- TRMASTER *)

(* SERVE THE MATRIX FIXTURE, as uTestLogSCP.OpenFixture does: let go of what an
  earlier test left, point CD at the fixture, take SCP out of its off states.
  The operator-name set is the test's own until CloseTRMaster. *)
procedure OpenTRMaster;
begin
   gSavedFile     := CD.ActiveFilename;
   gSavedExists   := CD.MasterFileExists;
   gSavedDisabled := CD.SCPDisabledByApplication;
   gSavedMode     := Settings.Scp.PossibleCallMode;
   gSavedMemory   := CD.CellBuffer.MaximumMemoryToUse;
   gSavedNameSet  := OperatorNameSet;
   OperatorNameSet := nil;

   CD.SCPDisableAndDeAllocateFileBuffer;
   CD.SCPDisabledByApplication := False;
   CD.CellBuffer.GoAway;
   CD.LastCallRecord.Call := '';
   CD.InitialPartialCall  := '';

   SetCharBuffer(CD.ActiveFilename, MatrixFixturePath);
   CD.MasterFileExists := True;
   CD.CellBuffer.MaximumMemoryToUse := TR_MODE_MEMORY;
   Settings.Scp.PossibleCallMode := AnyCall;
end;

procedure CloseTRMaster;
begin
   FreeAndNil(OperatorNameSet);
   OperatorNameSet := gSavedNameSet;

   CD.SCPDisableAndDeAllocateFileBuffer;
   CD.CellBuffer.GoAway;
   CD.LastCallRecord.Call := '';
   CD.InitialPartialCall  := '';

   CD.ActiveFilename           := gSavedFile;
   CD.MasterFileExists         := gSavedExists;
   CD.SCPDisabledByApplication := gSavedDisabled;
   CD.CellBuffer.MaximumMemoryToUse := gSavedMemory;
   Settings.Scp.PossibleCallMode := gSavedMode;
   DeleteTempFiles;
end;

(* The name SCP gives a call, '<none>' for a call it does not have. *)
function NameOf(const aCall: string): string;
var
   data: DataBaseEntryRecord;
begin
   if CD.GetEntry(aCall, data) then
      begin
      Result := string(data.mName);
      end
   else
      begin
      Result := '<none>';
      end;
end;

procedure TLiveDataSwapTests.Test_TRMaster_SwapShowsNewDataAtOnce;
var
   why: string;
   variant: string;
begin
   BeginTest('Test_TRMaster_SwapShowsNewDataAtOnce');
   OpenTRMaster;
   try
      variant := MakeVariant('a', 'HIRAM', 'HIRAX');
      Check(gReplaced > 0, 'the variant differs from the fixture');

      CheckEquals('HIRAM', NameOf('W1AW'), 'the old file serves W1AW');
      (* THAT LOOKUP LEFT W1AW IN LastCallRecord, which GetEntry answers from
        before it reads anything: the cache a swap must clear. *)
      CheckTrue(CD.ReplaceTRMasterFile(variant, why), 'the swap: ' + why);

      CheckEquals('HIRAX', NameOf('W1AW'), 'the new name at once, not the cached one');
      CheckEquals('BOB', NameOf('K4ABC'), 'a call the change did not touch');
      CheckEquals(variant, CharBufferText(CD.ActiveFilename), 'the file named is the one in service');
      CheckTrue(CD.TRMasterFileOpen, 'the flags changed with it: open');
      CheckTrue(CD.IndexArrayAllocated, 'index loaded');
      CheckTrue(CD.MasterFileExists, 'file exists');
      CheckTrue(CD.Snapshot <> nil, 'a snapshot is in service');

      (* THE PARTIAL-CALL STATE answers from the new file too. *)
      CD.GeneratePossibleCallList('W1AX');
      CheckEquals(1, PossibleCallList.NumberPossibleCalls, 'one possible call for W1AX');
      CheckEquals('W1AW', string(PossibleCallList.List[0].Call), 'W1AW');
   finally
      CloseTRMaster;
   end;
end;

procedure TLiveDataSwapTests.Test_TRMaster_LoggedExchangeSurvivesTheSwap;
var
   why: string;
   variant: string;
   index: integer;
begin
   BeginTest('Test_TRMaster_LoggedExchangeSurvivesTheSwap');
   OpenTRMaster;
   gSavedList := CallsignsList;
   CallsignsList := TCallsignsList.Create;
   try
      (* A QSO WITH W1AW has just been logged: its remembered exchange, and the
        station in the worked list. *)
      CallsignsList.AddCallsign('W1AW', CW, Band20, True);
      CallsignsList.AddIniitialExchange('W1AW', '14 CT');
      CheckEquals('HIRAM', NameOf('W1AW'), 'SCP knows W1AW');

      variant := MakeVariant('a', 'HIRAM', 'HIRAX');
      CheckTrue(CD.ReplaceTRMasterFile(variant, why), 'the swap: ' + why);

      CheckEquals('14 CT', CallsignsList.GetIniitialExchange('W1AW'),
                  'the logged exchange survives a TRMASTER swap');
      CheckTrue(CallsignsList.FindCallsign('W1AW', index), 'W1AW is still a worked station');
      CheckEquals(1, Integer(CallsignsList.GetQSOs(index)), 'with its QSO');
      CheckEquals('HIRAX', NameOf('W1AW'), 'and SCP gives the new name');
   finally
      CallsignsList.Free;
      CallsignsList := gSavedList;
      CloseTRMaster;
   end;
end;

procedure TLiveDataSwapTests.Test_TRMaster_FailedLoadLeavesTheOldServing;
var
   why: string;
   inService: TTRMasterSnapshot;
   oldFile: string;
   bytes: TTRMasterBytes;
   page: AnsiString;
   i: integer;

   procedure ExpectRefused(const aPath: string; const aWhat: string);
   begin
      why := '';
      CheckFalse(CD.ReplaceTRMasterFile(aPath, why), aWhat + ': refused');
      CheckTrue(why <> '', aWhat + ': says why');
      CheckTrue(CD.Snapshot = inService, aWhat + ': the same snapshot is still in service');
      CheckEquals(oldFile, CharBufferText(CD.ActiveFilename), aWhat + ': the file named is unchanged');
      CD.LastCallRecord.Call := '';
      CheckEquals('HIRAM', NameOf('W1AW'), aWhat + ': the old file still serves');
   end;

begin
   BeginTest('Test_TRMaster_FailedLoadLeavesTheOldServing');
   OpenTRMaster;
   try
      CheckEquals('HIRAM', NameOf('W1AW'), 'the file is loaded');
      inService := CD.Snapshot;
      oldFile := CharBufferText(CD.ActiveFilename);

      ExpectRefused(TempPath('missing', '.dta'), 'a missing file');

      SetLength(bytes, 0);
      WriteBytesFile(TempPath('empty', '.dta'), bytes);
      ExpectRefused(gTempFiles[High(gTempFiles)], 'an empty file');

      bytes := ReadBytesFile(MatrixFixturePath);
      SetLength(bytes, 100);
      WriteBytesFile(TempPath('cut', '.dta'), bytes);
      ExpectRefused(gTempFiles[High(gTempFiles)], 'a file cut inside the index');

      (* THE INDEX ALONE: whole, but every address and the end address point
        past the file. *)
      bytes := ReadBytesFile(MatrixFixturePath);
      SetLength(bytes, 37 * 37 * 4 + 4);
      WriteBytesFile(TempPath('index', '.dta'), bytes);
      ExpectRefused(gTempFiles[High(gTempFiles)], 'an index pointing outside the file');

      (* A WEB PAGE where the file should be -- what a download of the wrong
        thing saves. *)
      page := '';
      for i := 1 to 300 do
         begin
         page := page + '<html><body>Not found</body></html>'#13#10;
         end;
      SetLength(bytes, Length(page));
      Move(page[1], bytes[0], Length(page));
      WriteBytesFile(TempPath('page', '.dta'), bytes);
      ExpectRefused(gTempFiles[High(gTempFiles)], 'a web page');
   finally
      CloseTRMaster;
   end;
end;

procedure TLiveDataSwapTests.Test_TRMaster_SwapBetweenLookups;
var
   why: string;
   fileA: string;
   fileB: string;
   expected: string;
   before: DataBaseEntryRecord;
   i: integer;
begin
   BeginTest('Test_TRMaster_SwapBetweenLookups');
   OpenTRMaster;
   try
      fileA := MakeVariant('a', 'HIRAM', 'HIRAX');
      fileB := MakeVariant('b', 'HIRAM', 'HIRAZ');
      expected := 'HIRAM';
      for i := 1 to 20 do
         begin
         (* LOOKUP ... *)
         CheckEquals(expected, NameOf('W1AW'), 'before swap ' + IntToStr(i));
         CheckEquals('ZED', NameOf('K9ABC'), 'a second cell before swap ' + IntToStr(i));
         CheckEquals(expected, NameOf('W1AW'), 'back to the first cell ' + IntToStr(i));
         CD.GetEntry('W1AW', before);

         (* ... SWAP ... *)
         if Odd(i) then
            begin
            CheckTrue(CD.ReplaceTRMasterFile(fileA, why), 'swap to A ' + IntToStr(i) + ': ' + why);
            expected := 'HIRAX';
            end
         else
            begin
            CheckTrue(CD.ReplaceTRMasterFile(fileB, why), 'swap to B ' + IntToStr(i) + ': ' + why);
            expected := 'HIRAZ';
            end;

         (* ... LOOKUP. *)
         CheckEquals(expected, NameOf('W1AW'), 'after swap ' + IntToStr(i));
         CheckEquals('ZED', NameOf('K9ABC'), 'a second cell after swap ' + IntToStr(i));
         CheckEquals(expected, NameOf('W1AW'), 'and back ' + IntToStr(i));
         (* A RECORD COPIED BEFORE THE SWAP IS A VALUE: the old snapshot's
           memory is gone and the copy is not affected. *)
         CheckTrue(string(before.mName) <> expected, 'the copy taken before still reads the old name ' + IntToStr(i));
         end;
   finally
      CloseTRMaster;
   end;
end;

(* THE ONE SEQUENCE WHERE HALF AN OLD STATE COULD LIVE: a partial-call walk
  is under way (the cell buffer holds the old file's cell and a read position)
  when the file is replaced. The walk must end, not carry on into the old
  bytes, and a new walk must read the new file. *)
procedure TLiveDataSwapTests.Test_TRMaster_SwapInTheMiddleOfAPartialWalk;
var
   why: string;
   variant: string;
   call: CallString;
   count: integer;
begin
   BeginTest('Test_TRMaster_SwapInTheMiddleOfAPartialWalk');
   OpenTRMaster;
   try
      variant := MakeVariant('a', 'HIRAM', 'HIRAX');
      CheckTrue(CD.PartialCallSetup('ABC'), 'a walk is set up');
      CD.GetNextPartialCall(call);
      CheckTrue(call <> '', 'the first call of the walk');

      CheckTrue(CD.ReplaceTRMasterFile(variant, why), 'the swap: ' + why);

      CD.GetNextPartialCall(call);
      CheckEquals('', string(call), 'the walk does not go on into the old file');

      CheckTrue(CD.PartialCallSetup('ABC'), 'a new walk');
      count := 0;
      repeat
         CD.GetNextPartialCall(call);
         if call <> '' then
            begin
            inc(count);
            end;
      until call = '';
      CheckEquals(8, count, 'the new file''s eight calls');
   finally
      CloseTRMaster;
   end;
end;

procedure TLiveDataSwapTests.Test_TRMaster_NameSetChangesWithTheFile;
var
   names: TStringList;
   why: string;
   variant: string;
   heldSet: TStringList;
begin
   BeginTest('Test_TRMaster_NameSetChangesWithTheFile');
   OpenTRMaster;
   try
      (* A CONTEST ASKED FOR THE NAMES: a set built from the file in service. *)
      names := TStringList.Create;
      names.Sorted     := True;
      names.Duplicates := dupIgnore;
      CD.BuildOperatorNameSet(names);
      OperatorNameSet := names;
      CheckTrue(NameInOperatorSet('Hiram'), 'HIRAM is a name');
      CheckFalse(NameInOperatorSet('HIRAX'), 'HIRAX is not');

      variant := MakeVariant('a', 'HIRAM', 'HIRAX');
      CheckTrue(CD.ReplaceTRMasterFile(variant, why), 'the swap: ' + why);
      CheckTrue(NameInOperatorSet('Hirax'), 'the set is the new file''s: HIRAX');
      CheckFalse(NameInOperatorSet('HIRAM'), 'and the old name is gone');
      CheckTrue(NameInOperatorSet('BOB'), 'a name the change did not touch');

      (* A SWAP THAT FAILS LEAVES THE SET AS IT WAS -- the same object. *)
      heldSet := OperatorNameSet;
      CheckFalse(CD.ReplaceTRMasterFile(TempPath('missing', '.dta'), why), 'a missing file');
      CheckTrue(OperatorNameSet = heldSet, 'the name set is the same object');
      CheckTrue(NameInOperatorSet('HIRAX'), 'and still the new file''s');
   finally
      CloseTRMaster;
   end;
end;

(* -------------------------------------------------------- call history *)

procedure OpenHistory;
begin
   gSavedList        := CallsignsList;
   gSavedContest     := Contest;
   gSavedUse         := Settings.Contest.UseCallHistoryFile;
   gSavedHistoryName := Settings.Contest.CallHistoryFilename;
   CallsignsList := TCallsignsList.Create;
   (* SWEEPSTAKES prefills the check then the section: '72 SCV'. *)
   Contest := ContestHandleOf(ARRLSSSSB);
   Settings.Contest.UseCallHistoryFile := True;
end;

procedure CloseHistory;
begin
   CallsignsList.Free;
   CallsignsList := gSavedList;
   Contest := gSavedContest;
   Settings.Contest.UseCallHistoryFile := gSavedUse;
   Settings.Contest.CallHistoryFilename := gSavedHistoryName;
   DeleteTempFiles;
end;

function HistoryRowsA: string;
begin
   Result := WriteHistory('a',
      ['!!Order!!,Call,Sect,State,CK,Exch1,',
       'N6TV,LAX,CA,70,',
       'W9ZZZ,IL,IL,55,',
       'AA1RB,NC,NC,9,']);
end;

function HistoryRowsB: string;
begin
   Result := WriteHistory('b',
      ['!!Order!!,Call,Sect,State,CK,Exch1,',
       'N6TV,EB,CA,65,',
       'W9ZZZ,TX,TX,44,']);
end;

function ListHas(const aCall: string): boolean;
var
   index: integer;
begin
   Result := CallsignsList.FindCallsign(aCall, index);
end;

function QSOsOf(const aCall: string): integer;
var
   index: integer;
begin
   Result := -1;
   if CallsignsList.FindCallsign(aCall, index) then
      begin
      Result := CallsignsList.GetQSOs(index);
      end;
end;

procedure TLiveDataSwapTests.Test_CallHistory_SwapKeepsTheLogAndShowsTheNewFile;
var
   stored: integer;
begin
   BeginTest('Test_CallHistory_SwapKeepsTheLogAndShowsTheNewFile');
   CheckTrue(FileExists(SampleHistoryPath), 'the sample is there: ' + SampleHistoryPath);
   OpenHistory;
   try
      (* INITIAL.EX / THE LOG knew NY4I; then the first load of the sample. *)
      CallsignsList.AddIniitialExchange('NY4I', '80 NFL');
      Settings.Contest.CallHistoryFilename := SampleHistoryPath;
      CheckEquals(7, LoadCallHistoryFile, 'the first load');
      CheckEquals('72 SCV', CallsignsList.GetIniitialExchange('N6TV'), 'the file gives N6TV');

      (* QSOs are logged: N4AF is worked, N6TV is worked and sent 72 LAX. *)
      CallsignsList.AddCallsign('N4AF', CW, Band20, True);
      CallsignsList.AddIniitialExchange('N6TV', '72 LAX');
      CheckEquals(8, CallsignsList.Count, 'eight stations before the swap');

      (* THE DOWNLOAD ARRIVES: a different file, the whole of it. *)
      Settings.Contest.CallHistoryFilename := HistoryRowsA;
      stored := LoadCallHistoryFile;
      CheckEquals(2, stored, 'W9ZZZ and AA1RB stored; N6TV is the log''s');

      (* (a) WHAT THE LOG KNEW *)
      CheckEquals('80 NFL', CallsignsList.GetIniitialExchange('NY4I'), 'INITIAL.EX''s entry stands');
      CheckEquals('72 LAX', CallsignsList.GetIniitialExchange('N6TV'), 'the logged exchange stands');
      CheckFalse(CallsignsList.InitialExchangeIsFromCallHistory('N6TV'), 'and is not the file''s');
      CheckEquals(1, QSOsOf('N4AF'), 'a worked station keeps its QSO');
      CheckEquals('', CallsignsList.GetIniitialExchange('N4AF'), 'its old history text went with the old file');

      (* (b) THE NEW FILE IS VISIBLE AT ONCE *)
      CheckEquals('55 IL', CallsignsList.GetIniitialExchange('W9ZZZ'), 'a call new to the file');
      CheckTrue(CallsignsList.InitialExchangeIsFromCallHistory('W9ZZZ'), 'marked as the file''s');
      CheckEquals('09 NC', CallsignsList.GetIniitialExchange('AA1RB'), 'a call the file changed');

      (* THE OLD FILE'S OWN ENTRIES ARE GONE, and only those. *)
      CheckFalse(ListHas('4U1WB'), '4U1WB was only in the old file');
      CheckFalse(ListHas('AA0A'), 'AA0A');
      CheckFalse(ListHas('KK6L'), 'KK6L');
      CheckFalse(ListHas('K1IEB'), 'K1IEB');
      CheckEquals(5, CallsignsList.Count, 'NY4I, N6TV, N4AF, W9ZZZ, AA1RB');
   finally
      CloseHistory;
   end;
end;

procedure TLiveDataSwapTests.Test_CallHistory_ARecentQSOWinsBeforeAndAfter;
begin
   BeginTest('Test_CallHistory_ARecentQSOWinsBeforeAndAfter');
   OpenHistory;
   try
      Settings.Contest.CallHistoryFilename := SampleHistoryPath;
      CheckTrue(LoadCallHistoryFile > 0, 'the sample loads');
      CheckEquals('72 SCV', CallsignsList.GetIniitialExchange('N6TV'), 'the file''s text');

      (* BEFORE THE SWAP: the QSO just logged outranks the file. *)
      CallsignsList.AddIniitialExchange('N6TV', '72 LAX');
      CheckEquals('72 LAX', CallsignsList.GetIniitialExchange('N6TV'), 'before: the QSO wins');
      CheckFalse(CallsignsList.InitialExchangeIsFromCallHistory('N6TV'), 'before: not the file''s');

      (* AFTER IT: the new file says 70 LAX for N6TV; the QSO still wins. *)
      Settings.Contest.CallHistoryFilename := HistoryRowsA;
      CheckTrue(LoadCallHistoryFile > 0, 'the new file loads');
      CheckEquals('72 LAX', CallsignsList.GetIniitialExchange('N6TV'), 'after: the QSO still wins');
      CheckFalse(CallsignsList.InitialExchangeIsFromCallHistory('N6TV'), 'after: still not the file''s');
      CheckEquals('09 NC', CallsignsList.GetIniitialExchange('AA1RB'), 'a call never logged shows the new file');

      (* A QSO LOGGED AFTER THE SWAP replaces the NEW file's text, and survives
        the next swap even though that file no longer lists the call. *)
      CallsignsList.AddIniitialExchange('W9ZZZ', '55 NY');
      CheckEquals('55 NY', CallsignsList.GetIniitialExchange('W9ZZZ'), 'a QSO after the swap wins');
      Settings.Contest.CallHistoryFilename := SampleHistoryPath;
      CheckTrue(LoadCallHistoryFile > 0, 'back to the sample');
      CheckEquals('55 NY', CallsignsList.GetIniitialExchange('W9ZZZ'), 'and survives a file that drops the call');
      CheckEquals('72 LAX', CallsignsList.GetIniitialExchange('N6TV'), 'N6TV too');
      CheckEquals('08 VA', CallsignsList.GetIniitialExchange('AA1RB'), 'AA1RB is the sample''s again');

      (* THE OLD RULE, KEPT: a QSO logged with an EMPTY exchange replaced the
        file's text with nothing, and still does. *)
      CallsignsList.AddIniitialExchange('AA1RB', '');
      CheckEquals('', CallsignsList.GetIniitialExchange('AA1RB'), 'an empty logged exchange outranks the file');
      Settings.Contest.CallHistoryFilename := HistoryRowsA;
      CheckTrue(LoadCallHistoryFile > 0, 'and a swap');
      CheckEquals('', CallsignsList.GetIniitialExchange('AA1RB'), 'it still does after a swap');
   finally
      CloseHistory;
   end;
end;

procedure TLiveDataSwapTests.Test_CallHistory_FailedLoadLeavesTheLayer;
var
   countBefore: integer;

   procedure ExpectUnchanged(const aWhat: string);
   begin
      CheckEquals(0, LoadCallHistoryFile, aWhat + ': nothing applied');
      CheckEquals('72 SCV', CallsignsList.GetIniitialExchange('N6TV'), aWhat + ': the old text serves');
      CheckEquals('08 VA', CallsignsList.GetIniitialExchange('AA1RB'), aWhat + ': AA1RB');
      CheckEquals(countBefore, CallsignsList.Count, aWhat + ': the same stations');
   end;

begin
   BeginTest('Test_CallHistory_FailedLoadLeavesTheLayer');
   OpenHistory;
   try
      Settings.Contest.CallHistoryFilename := SampleHistoryPath;
      CheckTrue(LoadCallHistoryFile > 0, 'the sample loads');
      countBefore := CallsignsList.Count;

      Settings.Contest.CallHistoryFilename := TempPath('missing', '.txt');
      ExpectUnchanged('a missing file');

      (* A WEB PAGE: rows with a call and nothing the contest prefills. *)
      Settings.Contest.CallHistoryFilename :=
         WriteHistory('page', ['<html><body>Not found</body></html>']);
      ExpectUnchanged('a web page');

      (* A FILE OF COMMENTS ONLY. *)
      Settings.Contest.CallHistoryFilename := WriteHistory('comments', ['# nothing here', '']);
      ExpectUnchanged('a file of comments');

      (* AND A GOOD FILE STILL LOADS AFTER THEM. *)
      Settings.Contest.CallHistoryFilename := HistoryRowsA;
      CheckTrue(LoadCallHistoryFile > 0, 'a good file after the failures');
      CheckEquals('55 IL', CallsignsList.GetIniitialExchange('W9ZZZ'), 'is in service');
   finally
      CloseHistory;
   end;
end;

procedure TLiveDataSwapTests.Test_CallHistory_SwapBetweenLookups;
var
   fileA: string;
   fileB: string;
   i: integer;
begin
   BeginTest('Test_CallHistory_SwapBetweenLookups');
   OpenHistory;
   try
      fileA := HistoryRowsA;
      fileB := HistoryRowsB;
      for i := 1 to 10 do
         begin
         (* LOOKUP, SWAP TO A, LOOKUP *)
         Settings.Contest.CallHistoryFilename := fileA;
         CheckTrue(LoadCallHistoryFile > 0, 'swap to A ' + IntToStr(i));
         CheckEquals('70 LAX', CallsignsList.GetIniitialExchange('N6TV'), 'A: N6TV ' + IntToStr(i));
         CheckEquals('55 IL', CallsignsList.GetIniitialExchange('W9ZZZ'), 'A: W9ZZZ ' + IntToStr(i));
         CheckEquals('09 NC', CallsignsList.GetIniitialExchange('AA1RB'), 'A: AA1RB ' + IntToStr(i));
         CheckEquals(3, CallsignsList.Count, 'A: three stations ' + IntToStr(i));

         (* ... AND TO B: AA1RB is not in B, so it is gone, whole. *)
         Settings.Contest.CallHistoryFilename := fileB;
         CheckTrue(LoadCallHistoryFile > 0, 'swap to B ' + IntToStr(i));
         CheckEquals('65 EB', CallsignsList.GetIniitialExchange('N6TV'), 'B: N6TV ' + IntToStr(i));
         CheckEquals('44 TX', CallsignsList.GetIniitialExchange('W9ZZZ'), 'B: W9ZZZ ' + IntToStr(i));
         CheckFalse(ListHas('AA1RB'), 'B: AA1RB is gone ' + IntToStr(i));
         CheckEquals(2, CallsignsList.Count, 'B: two stations ' + IntToStr(i));
         end;
   finally
      CloseHistory;
   end;
end;

procedure TLiveDataSwapTests.Test_CallHistory_SnapshotAndLayerRules;
var
   snapshot: TCallHistorySnapshot;
   list: TCallsignsList;
begin
   BeginTest('Test_CallHistory_SnapshotAndLayerRules');
   snapshot := TCallHistorySnapshot.Create;
   list := TCallsignsList.Create;
   try
      CheckTrue(snapshot.Add('N6TV', '72 SCV') = charAdded, 'a first row is added');
      CheckTrue(snapshot.Add('n6tv', '99 LAX') = charAlreadyKnown, 'a later row for the call, case-blind, is known');
      CheckTrue(snapshot.Add('K1AR', '11 MA') = charAdded, 'another call');
      CheckEquals(2, snapshot.Count, 'two entries');
      CheckEquals('N6TV', snapshot.Calls[0], 'in the file''s order');
      CheckEquals('72 SCV', snapshot.Exchanges[0], 'the first row stands');

      list.AddIniitialExchange('K1AR', '11 CT');
      CheckEquals(1, list.ReplaceCallHistory(snapshot), 'K1AR is the log''s: one stored');
      CheckEquals('72 SCV', list.GetIniitialExchange('N6TV'), 'N6TV from the layer');
      CheckEquals('11 CT', list.GetIniitialExchange('K1AR'), 'K1AR from the log');

      CheckEquals(0, list.ReplaceCallHistory(nil), 'nil drops the layer and stores nothing');
      CheckEquals('', list.GetIniitialExchange('N6TV'), 'the layer is gone');
      CheckEquals('11 CT', list.GetIniitialExchange('K1AR'), 'the log stays');
      CheckEquals(1, list.Count, 'a history-only station went with it');
   finally
      list.Free;
      snapshot.Free;
   end;
end;

procedure TLiveDataSwapTests.RunAllTests;
begin
   Test_TRMaster_SwapShowsNewDataAtOnce;
   Test_TRMaster_LoggedExchangeSurvivesTheSwap;
   Test_TRMaster_FailedLoadLeavesTheOldServing;
   Test_TRMaster_SwapBetweenLookups;
   Test_TRMaster_SwapInTheMiddleOfAPartialWalk;
   Test_TRMaster_NameSetChangesWithTheFile;
   Test_CallHistory_SwapKeepsTheLogAndShowsTheNewFile;
   Test_CallHistory_ARecentQSOWinsBeforeAndAfter;
   Test_CallHistory_FailedLoadLeavesTheLayer;
   Test_CallHistory_SwapBetweenLookups;
   Test_CallHistory_SnapshotAndLayerRules;
end;

end.
