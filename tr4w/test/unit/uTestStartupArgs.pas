unit uTestStartupArgs;

(* THE COMMAND LINE'S RULES (uStartupArgs).  What is pinned is what hung a
  script overnight on 2026-11-26: a switch the shell rewrote, a headless job
  left off the headless list, and a switch that moves the positions the jobs are
  read from.  That a dialog really ends an --unattended run needs a running
  program: tr4w/test/Test-Unattended.ps1. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TStartupArgsTests = class(TTestCase)
   protected
      procedure TestTheLineThatWaitedAllNight;
      procedure TestEveryHeadlessJobIsAJob;
      procedure TestAJobAtTheWrongPositionIsNotOne;
      procedure TestUnattendedMovesNoPosition;
      procedure TestSettingsAndLanguageMoveNoPosition;
      procedure TestImportLogIsHeadless;
      procedure TestImportFile;
      procedure TestAnOrdinaryStartIsNeither;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uStartupArgs;

procedure TStartupArgsTests.TestTheLineThatWaitedAllNight;
begin
   BeginTest('TestTheLineThatWaitedAllNight');
   CheckTrue(ArgumentsRequestUnattended(
                ['C:/Program Files/Git/IMPORTLOG', 'a.trw', 'a.db',
                 '--unattended']),
             '--unattended still arrives beside a rewritten switch');
   CheckFalse(ArgumentsNameAHeadlessJob(
                 ['C:/Program Files/Git/IMPORTLOG', 'a.trw', 'a.db',
                  '--unattended']),
              'the rewritten switch is no job, so the run is refused');
end;

procedure TStartupArgsTests.TestEveryHeadlessJobIsAJob;
begin
   BeginTest('TestEveryHeadlessJobIsAJob');
   CheckTrue(ArgumentsNameAHeadlessJob(['/IMPORTLOG', 'a.trw']), '/IMPORTLOG');
   CheckTrue(ArgumentsNameAHeadlessJob(['/MATRIXLIST', 'out']), '/MATRIXLIST');
   CheckTrue(ArgumentsNameAHeadlessJob(['/FIELDCHECK']), '/FIELDCHECK');
   CheckTrue(ArgumentsNameAHeadlessJob(['a.db', '/EXPORT']), '/EXPORT');
   CheckTrue(ArgumentsNameAHeadlessJob(['a.db', '/RESCORE']), '/RESCORE');
   CheckTrue(ArgumentsNameAHeadlessJob(['a.db', '/MATRIX', 'o', 'id']),
             '/MATRIX');
   CheckTrue(ArgumentsNameAHeadlessJob(['a.cfg', '/IMPORT', 'a.adi']),
             '/IMPORT');
   CheckTrue(ArgumentsNameAHeadlessJob(['a.db', '/export']), 'any case');
end;

procedure TStartupArgsTests.TestAJobAtTheWrongPositionIsNotOne;
begin
   BeginTest('TestAJobAtTheWrongPositionIsNotOne');
   CheckFalse(ArgumentsNameAHeadlessJob(['/EXPORT']),
              '/EXPORT with no contest is not read as the job');
   CheckFalse(ArgumentsNameAHeadlessJob(['a.db', '/IMPORTLOG']),
              '/IMPORTLOG is read first only');
   CheckFalse(ArgumentsNameAHeadlessJob(['a.cfg', '/IMPORT']),
              '/IMPORT names no file');
end;

procedure TStartupArgsTests.TestUnattendedMovesNoPosition;
begin
   BeginTest('TestUnattendedMovesNoPosition');
   CheckEquals('/IMPORTLOG',
               PositionalArgumentOf(['--unattended', '/IMPORTLOG', 'a.trw'], 1),
               'written first');
   CheckEquals('',
               PositionalArgumentOf(['/IMPORTLOG', 'a.trw', '--unattended'], 3),
               'written last, it is not taken for the target database');
   CheckEquals('/EXPORT',
               PositionalArgumentOf(['a.db', '--unattended', '/EXPORT'], 2),
               'written between the contest and the job');
end;

procedure TStartupArgsTests.TestSettingsAndLanguageMoveNoPosition;
begin
   BeginTest('TestSettingsAndLanguageMoveNoPosition');
   CheckEquals('/EXPORT',
               PositionalArgumentOf(['--settings', 'x.json', 'a.db', '/EXPORT'],
                                    2),
               '--settings takes its value with it');
   CheckEquals('/EXPORT',
               PositionalArgumentOf(['--lang=es', 'a.db', '-l', 'de',
                                     '/EXPORT'], 2),
               'both language spellings');
   CheckEquals('id',
               PositionalArgumentOf(['a.db', '/MATRIX', 'o', 'id',
                                     '--settings', 'x.json'], 4),
               'the matrix line as the script writes it');
end;

procedure TStartupArgsTests.TestImportLogIsHeadless;
begin
   BeginTest('TestImportLogIsHeadless');
   CheckTrue(ArgumentsHaveHeadlessSwitch(['/IMPORTLOG', 'a.trw']),
             'so a second instance exits instead of showing a warning');
end;

procedure TStartupArgsTests.TestImportFile;
begin
   BeginTest('TestImportFile');
   CheckEquals('a.adi', ImportFileOf(['a.cfg', '/IMPORT', 'a.adi']), 'plain');
   CheckEquals('a.adi',
               ImportFileOf(['a.cfg', '/IMPORT', '--unattended', 'a.adi']),
               '--unattended is not taken for the file');
   CheckEquals('', ImportFileOf(['a.db', '/EXPORT']), 'no import asked');
end;

procedure TStartupArgsTests.TestAnOrdinaryStartIsNeither;
begin
   BeginTest('TestAnOrdinaryStartIsNeither');
   CheckFalse(ArgumentsHaveHeadlessSwitch(['a.db', '--lang', 'es']), 'headless');
   CheckFalse(ArgumentsRequestUnattended(['a.db']), 'unattended');
   CheckFalse(ArgumentsNameAHeadlessJob(['a.db']), 'job');
end;

procedure TStartupArgsTests.RunAllTests;
begin
   TestTheLineThatWaitedAllNight;
   TestEveryHeadlessJobIsAJob;
   TestAJobAtTheWrongPositionIsNotOne;
   TestUnattendedMovesNoPosition;
   TestSettingsAndLanguageMoveNoPosition;
   TestImportLogIsHeadless;
   TestImportFile;
   TestAnOrdinaryStartIsNeither;
end;

end.
