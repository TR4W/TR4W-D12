unit uTestLookupTrace;
{$I ..\..\src\tr4w.inc}

(* THE LOOKUP TRACE (2026-11-20): the pure parts of the log lines that say
  where a typed call's name, QTH and exchange came from, and which location
  tier a data file was loaded from. The lines themselves are written by
  LogEdit.LogLookupSources, uProgramMain.ReportDataLocations and the loaders;
  what a unit test can reach is the text builders, the tier rule and the
  exchange layer the trace reports. *)

interface

uses
   uTR4WTestFramework;

type
   TLookupTraceTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_LookupLogLine_NamesCallFieldsAndSource;
      procedure Test_LookupAddField_SkipsEmptyAndJoinsWithComma;
      procedure Test_LookupNothingLine_NamesTheCall;
      procedure Test_DataFileTierFor_DownloadedShippedOther;
      procedure Test_ExchangeLayerOf_LogOutranksHistory;
      procedure Test_ExchangeLayerOf_HistoryAndNone;
   end;

implementation

uses
   SysUtils,
   VC,
   utils_text,
   uAppPaths,
   uCallHistory,
   uCallsigns;

procedure TLookupTraceTests.Test_LookupLogLine_NamesCallFieldsAndSource;
begin
   BeginTest('Test_LookupLogLine_NamesCallFieldsAndSource');
   CheckEquals('[Lookup] N4AF: exchange ''NC'' from call history X.txt',
               LookupLogLine('N4AF', 'exchange ''NC''', 'call history X.txt'),
               'one field');
end;

procedure TLookupTraceTests.Test_LookupAddField_SkipsEmptyAndJoinsWithComma;
var
   what: string;
begin
   BeginTest('Test_LookupAddField_SkipsEmptyAndJoinsWithComma');
   what := '';
   LookupAddField(what, 'name', 'Howie');
   LookupAddField(what, 'QTH', '');
   LookupAddField(what, 'section', 'NC');
   CheckEquals('name ''Howie'', section ''NC''', what, 'empty value adds nothing');

   what := '';
   LookupAddField(what, 'name', '');
   CheckEquals('', what, 'all empty stays empty');
end;

procedure TLookupTraceTests.Test_LookupNothingLine_NamesTheCall;
begin
   BeginTest('Test_LookupNothingLine_NamesTheCall');
   CheckTrue(Pos('[Lookup] K1ABC: nothing known', LookupNothingLine('K1ABC')) = 1,
             'starts with the call');
end;

procedure TLookupTraceTests.Test_DataFileTierFor_DownloadedShippedOther;
begin
   BeginTest('Test_DataFileTierFor_DownloadedShippedOther');
   CheckEquals('downloaded',
               DataFileTierFor('C:\Users\x\AppData\Roaming\TR4W\settings\TRMASTER.DTA',
                               'C:\Users\x\AppData\Roaming\TR4W\settings\',
                               'C:\Program Files\TR4W\'),
               'inside the writable settings directory');
   CheckEquals('shipped',
               DataFileTierFor('C:\Program Files\TR4W\TRMASTER.DTA',
                               'C:\Users\x\AppData\Roaming\TR4W\settings\',
                               'C:\Program Files\TR4W\'),
               'inside the program directory');
   CheckEquals('other',
               DataFileTierFor('D:\Contests\TRMASTER.DTA',
                               'C:\Users\x\AppData\Roaming\TR4W\settings\',
                               'C:\Program Files\TR4W\'),
               'beside the contest');
   (* PORTABLE: the settings directory lies INSIDE the program directory, and
     the downloaded copy must not be called shipped. *)
   CheckEquals('downloaded',
               DataFileTierFor('C:\tr4w\target\settings\CTY.DAT',
                               'C:\tr4w\target\settings\', 'C:\tr4w\target\'),
               'settings inside the program directory');
   CheckEquals('shipped',
               DataFileTierFor('C:\tr4w\target\CTY.DAT',
                               'C:\tr4w\target\settings\', 'C:\tr4w\target\'),
               'program directory beside it');
end;

procedure TLookupTraceTests.Test_ExchangeLayerOf_LogOutranksHistory;
var
   list: TCallsignsList;
   exchange, history: string;
   qsos: Byte;
begin
   BeginTest('Test_ExchangeLayerOf_LogOutranksHistory');
   list := TCallsignsList.Create;
   try
      list.AddCallHistoryExchange('N4AF', 'NC');
      CheckTrue(list.ExchangeLayerOf('N4AF', exchange, qsos, history) = xlCallHistory,
                'history only');
      CheckEquals('NC', exchange, 'history text');

      (* INITIAL.EX states one: it outranks the file, and the file's text is
        reported as hidden. *)
      list.AddIniitialExchange('N4AF', 'VA');
      CheckTrue(list.ExchangeLayerOf('N4AF', exchange, qsos, history) = xlInitialEx,
                'stated, no QSO yet');
      CheckEquals('VA', exchange, 'initial exchange text');
      CheckEquals('NC', history, 'the history layer is still there');

      (* A QSO logged with the call: the log's layer. *)
      list.AddCallsign('N4AF', CW, Band20, True);
      CheckTrue(list.ExchangeLayerOf('N4AF', exchange, qsos, history) = xlLog,
                'worked in this log');
      CheckEquals(1, qsos, 'one QSO');
   finally
      list.Free;
   end;
end;

procedure TLookupTraceTests.Test_ExchangeLayerOf_HistoryAndNone;
var
   list: TCallsignsList;
   exchange, history: string;
   qsos: Byte;
begin
   BeginTest('Test_ExchangeLayerOf_HistoryAndNone');
   list := TCallsignsList.Create;
   try
      CheckTrue(list.ExchangeLayerOf('W1AW', exchange, qsos, history) = xlNone,
                'an unknown call');
      CheckEquals('', exchange, 'no text');
      CheckEquals(0, qsos, 'no QSOs');
   finally
      list.Free;
   end;
end;

procedure TLookupTraceTests.RunAllTests;
begin
   Test_LookupLogLine_NamesCallFieldsAndSource;
   Test_LookupAddField_SkipsEmptyAndJoinsWithComma;
   Test_LookupNothingLine_NamesTheCall;
   Test_DataFileTierFor_DownloadedShippedOther;
   Test_ExchangeLayerOf_LogOutranksHistory;
   Test_ExchangeLayerOf_HistoryAndNone;
end;

end.
