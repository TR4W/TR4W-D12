program tr4wconvert;

(*
  TR4WCONVERT -- carry an operator's old configuration into the files TR4W
  reads, as a SEPARATE ACT rather than as part of starting the program.

  NY4I, 2026-09-12: *"we needed a much clearer demarcation between the current
  program/contest settings and the import of old files. If it is getting too
  complicated, I am not adverse to a standalone conversion utility."*

  Usage:

      tr4wconvert                       report on settings\tr4w.json beside this
                                        binary, then ASK whether to apply
      tr4wconvert --apply               do it, without asking
      tr4wconvert --report-only         report and never ask, never write
      tr4wconvert --settings <path>     a particular settings file
      tr4wconvert --ini <path>          DEPRECATED -- that legacy ini, not the
                                        default one
      tr4wconvert --no-ini              do not read any ini at all
      tr4wconvert --all                 list every command, not just the
                                        interesting ones

  IT READS THE LEGACY INI BY DEFAULT, WITH NO FLAG. NY4I, 2026-09-20: "the only
  reason tr4wconvert exists is to convert an ini file to json so I am not sure
  why you not always read the ini (or need an option to tell it the existensial
  reason for its being)." He is right, and it had become the whole remaining
  purpose: the OTHER thing this converted -- the legacy `commands` bucket inside
  tr4w.json -- is imported and collapsed by the program itself at startup now
  (LoadSettingsForStartup, CollapseLegacySettingHomes), so an operator upgrading
  from 4.x who ran plain `tr4wconvert` converted the one file it exists for only
  if they happened to know a flag.

  So with no --ini it looks for tr4w.ini IN THE SAME DIRECTORY AS THE SETTINGS
  FILE IN USE -- which --settings moves too, so the pair always travel together.
  --ini names a different one; --no-ini reads none.

  --ini IS DEPRECATED (NY4I, 2026-09-20: "yes to #1"). It still WORKS, and
  deliberately so -- the installer message and any script an operator has
  written may name it, and silently breaking those is worse than the clutter.
  It says DEPRECATED in the usage text and in the header line so nothing new
  starts using it, and it can go once nothing points at it.

  AND THE HEADER ALWAYS PRINTS AN ini LINE, in every case. "It found nothing"
  and "it never looked" must not look the same, and before this they both looked
  like an absent line.

  IT REPORTS FIRST AND THEN ASKS -- ONE RUN, NOT TWO. NY4I, 2026-09-20: "i
  think it would be cleaner to have the user run it once, they ask them if they
  want to apply the changes." An operator still sees exactly what would
  happen before it happens; they simply do not have to remember a second command
  to make it happen.

  THE ANSWER DEFAULTS TO NO, AND THE PROMPT SAYS SO IN WORDS. NY4I: "Default to
  N and spell out that No is the default so they must type Yes". Enter is No,
  an unrecognised answer is No, and only an explicit yes writes anything. This
  is a question about an operator's own station configuration after an upgrade,
  so the accident-proof direction is "did nothing".

  IT ONLY ASKS WHEN STDIN IS A TERMINAL. Piped, redirected or run with no
  console it reports, says why it did not ask, and writes nothing -- a prompt
  there would block forever or read EOF. --apply is how a script applies.

  THE SEQUENCE IS INSTALL, CONVERT, THEN START TR4W. NY4I, 2026-09-20: "the
  only reason tr4wconvert should run is if the tr4w.json does not exist so how
  could we have a settings conflict?" So the PRIMARY path is a settings file
  that is not there yet, and this CREATES it from the model's defaults plus the
  ini. It used to refuse, which is why the installer had to tell an operator to
  start TR4W and close it again first -- a step that existed only to work around
  this tool's own precondition.

  IT STILL CONVERTS ONTO AN EXISTING SETTINGS FILE, because starting TR4W
  before converting is an ordinary mistake and refusing would strand an
  operator with no way to bring 4.x across. The report and the Yes-prompt are
  what protect them, and an all-defaults file is exactly what an ini should
  overwrite.

  EXIT CODES: 0 when it ran -- INCLUDING when the operator answered No, because
  declining is a successful run and not an error -- 1 when the settings file
  could not be read, and 2 when one or more values were REFUSED. That last one
  so a script can tell "converted cleanly" from "converted, but the old file
  held something the program will not accept".

  WHAT IT DOES NOT DO YET, stated so nobody assumes otherwise: contest settings.
  Those belong in the contest database and uLogStore.CaptureConfiguration
  already writes them; this reports them as the contest's and leaves them.
*)

{$MODE DELPHI}
(* THE SAME STRING MODEL AS EVERY OTHER UNIT. Without this the
  program file compiles with String = AnsiString and cannot pass a
  var parameter to anything it links. *)
{$MODESWITCH UnicodeStrings}
{$APPTYPE CONSOLE}

uses
{$IFDEF UNIX}
   cthreads,
   termio,
{$ENDIF}
{$IFDEF WINDOWS}
   Windows,
{$ENDIF}
   SysUtils,
   Classes,
   uAppPaths           in '..\..\src\uAppPaths.pas',
   uSettingsModel      in '..\..\src\uSettingsModel.pas',
   uSettingsConvert    in '..\..\src\uSettingsConvert.pas',
   uRadioConfigStore   in '..\..\src\uRadioConfigStore.pas',
   uKeyerConfigStore   in '..\..\src\uKeyerConfigStore.pas',
   uWindowLayoutStore  in '..\..\src\uWindowLayoutStore.pas',
   uUDPBroadcastConfig in '..\..\src\uUDPBroadcastConfig.pas',
   uTR4WConfigFile     in '..\..\src\uTR4WConfigFile.pas';

var
   GSettingsFile: string = '';
   GIniFile: string = '';
   GIniWasNamed: boolean = False;   (* --ini was given, so the path is the operator's *)
   GNoIni: boolean = False;
   GApply: boolean = False;
   GReportOnly: boolean = False;
   GShowAll: boolean = False;


procedure Usage;
begin
   WriteLn('tr4wconvert -- carry an old TR4W configuration into settings\tr4w.json');
   WriteLn;
   WriteLn('  --settings <path>   the settings file. With no --settings it uses a');
   WriteLn('                      settings folder beside this program if there is');
   WriteLn('                      one, and otherwise this platform''s own settings');
   WriteLn('                      location -- the same one TR4W reads');
   WriteLn('  --ini <path>        DEPRECATED -- a particular legacy ini, instead of');
   WriteLn('                      the one found beside the settings file');
   WriteLn('  --no-ini            do not read any ini at all');
   WriteLn('  --apply             write the result without asking (the scripted way)');
   WriteLn('  --report-only       report and never ask, never write');
   WriteLn('  --all               list every command, not just the interesting ones');
   WriteLn('  --help              this');
   WriteLn;
   WriteLn('With no --ini it reads tr4w.ini from the same directory as the settings');
   WriteLn('file, if there is one -- converting that file is what this program is for.');
   WriteLn;
   WriteLn('With none of those, it reports and then asks whether to apply.');
   WriteLn('The answer defaults to No. It only asks when run from a terminal.');
   WriteLn;
   WriteLn('Run this BEFORE starting TR4W for the first time: it creates the');
   WriteLn('settings file the program will then read.');
end;


(* IS STDIN A TERMINAL -- i.e. is there anybody there to answer a question?
  Without this the no-argument run would block forever behind a pipe, or read
  EOF and have to guess what that meant.

  NEITHER THE RTL NOR THE LCL HAS A CROSS-PLATFORM ANSWER, so this is two raw
  calls with the platform's own name for the question. Both are already
  declared by units FPC ships -- termio and Windows -- so neither is a new DLL
  binding.

  On Unix, termio.IsATTY IS the RTL facility for exactly this and returns 1 for
  a terminal.

  On Windows, GetConsoleMode is the test rather than GetFileType: it succeeds
  only for a real console input handle and fails for a pipe, a file or no
  handle at all, which is precisely the distinction being drawn. *)
function StdInIsTerminal: boolean;
{$IFDEF WINDOWS}
var
   h: THandle;
   mode: DWORD;
{$ENDIF}
begin
{$IFDEF WINDOWS}
   h := GetStdHandle(STD_INPUT_HANDLE);
   if (h = 0) or (h = INVALID_HANDLE_VALUE) then
      begin
      Result := False;
      end
   else
      begin
      Result := GetConsoleMode(h, mode);
      end;
{$ELSE}
   Result := IsATTY(Input) = 1;
{$ENDIF}
end;


(* NO IS THE DEFAULT AND THE PROMPT SAYS SO IN WORDS, not merely by writing the
  N in capitals -- that convention is not something an operator should have to
  know. Enter is No; anything unrecognised is No; only an explicit yes writes. *)
function OperatorSaysYes(aChangeCount: integer): boolean;
var
   answer: string;
begin
   WriteLn;
   WriteLn(Format('  Apply these %d change(s) to the settings file? The default is No.',
                  [aChangeCount]));
   WriteLn('  Type Yes and press Enter to apply. Anything else -- including just');
   WriteLn('  pressing Enter -- leaves everything exactly as it is.');
   Write('  Apply? [No] ');
   answer := '';
   ReadLn(answer);
   answer := LowerCase(Trim(answer));
   Result := (answer = 'yes') or (answer = 'y');
end;


function ParseCommandLine: boolean;
var
   i: integer;
   arg: string;
begin
   Result := True;
   i := 1;
   while i <= ParamCount do
      begin
      arg := ParamStr(i);
      if SameText(arg, '--apply') then
         begin
         GApply := True;
         end
      else if SameText(arg, '--report-only') or SameText(arg, '--dry-run') then
         begin
         GReportOnly := True;
         end
      else if SameText(arg, '--all') then
         begin
         GShowAll := True;
         end
      else if SameText(arg, '--help') or SameText(arg, '-h') then
         begin
         Usage;
         Result := False;
         Exit;
         end
      else if SameText(arg, '--settings') and (i < ParamCount) then
         begin
         Inc(i);
         GSettingsFile := ParamStr(i);
         end
      else if SameText(arg, '--no-ini') then
         begin
         GNoIni := True;
         end
      else if SameText(arg, '--ini') and (i < ParamCount) then
         begin
         Inc(i);
         GIniFile := ParamStr(i);
         GIniWasNamed := True;
         end
      else
         begin
         WriteLn('tr4wconvert: unrecognised argument "', arg, '"');
         WriteLn;
         Usage;
         Result := False;
         Exit;
         end;
      Inc(i);
      end;
end;


(* WHICH SETTINGS FILE -- AND IT MUST BE THE ONE THE PROGRAM READS.

  This is a correctness question, not a convenience one: a converter that
  writes a DIFFERENT file from the one TR4W reads reports success and changes
  nothing the operator can see, and the blame lands on the conversion rather
  than on the path.

  It used to be ExtractFilePath(ParamStr(0)) + settings\tr4w.json, which is a
  second, hand-written copy of a rule uAppPaths already owns -- and uAppPaths
  is the authority, per platform: the working directory on Windows,
  ~/Library/Application Support/TR4W on macOS, $XDG_CONFIG_HOME/tr4w on Linux.
  A copy of a path rule is a copy that drifts, and the drift is silent.

  THE ORDER, and NY4I's addition is the middle one (2026-09-20: "Settings go
  where they default to on each platform. If we have the target directory, it
  can go in settings like d7 did on linux"):

     1. --settings <path>                      the operator named it
     2. <dir of this binary>\settings\         a portable target-style
                                               directory, when it is there
     3. uAppPaths.SettingsFilePath             this platform's own location

  2 comes before 3 because a portable directory is an explicit statement by
  whoever laid it out, and because on Windows the two agree anyway whenever the
  program is started the way it ships.

  uAppPaths CREATES the directory it names, which is what the program wants at
  startup and is a side effect worth knowing about here. *)
type
   TSettingsOrigin = (soNamed, soPortable, soPlatform);

var
   GSettingsOrigin: TSettingsOrigin = soPlatform;


function PortableSettingsDir: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + 'settings' + PathDelim;
end;


function DefaultSettingsFile(out aOrigin: TSettingsOrigin): string;
begin
   if DirectoryExists(PortableSettingsDir) then
      begin
      aOrigin := soPortable;
      Result := PortableSettingsDir + 'tr4w.json';
      end
   else
      begin
      aOrigin := soPlatform;
      Result := SettingsFilePath('tr4w.json');
      end;
end;


(* CREATING OR UPDATING -- and the operator is told which.

  The intended sequence is install, convert, then start TR4W, so the normal
  case is that there is no settings file yet and this makes one (NY4I,
  2026-09-20). An operator who starts TR4W first -- a perfectly ordinary
  mistake -- gets a settings file full of defaults instead, and converting onto
  that still has to work or they are stranded with no way to bring 4.x across.
  The two situations read differently because the second one is the one where
  something already there could change. *)
procedure ReportStateLine;
begin
   if FileExists(GSettingsFile) then
      begin
      WriteLn('  state    : that file exists -- these changes would UPDATE it');
      end
   else
      begin
      WriteLn('  state    : no settings file yet -- this would CREATE it, which is');
      WriteLn('             the normal case: convert first, then start TR4W');
      end;
end;


(* The settings line, which says WHICH file and WHY it is that one. *)
procedure ReportSettingsLine;
begin
   case GSettingsOrigin of
      soNamed:
         begin
         WriteLn('  settings : ', GSettingsFile, '  (you named it with --settings)');
         end;
      soPortable:
         begin
         WriteLn('  settings : ', GSettingsFile,
                 '  (a settings folder beside tr4wconvert)');
         end;
   else
      begin
      WriteLn('  settings : ', GSettingsFile,
              '  (this platform''s settings location)');
      end;
   end;
end;


(* THE LEGACY INI THAT BELONGS TO THAT SETTINGS FILE -- beside it, because that
  is where TR4W's own has always sat and because --settings then moves the pair
  together rather than leaving the ini pointing at some other station's. *)
function DefaultIniFile(const aSettingsFile: string): string;
begin
   Result := ExtractFilePath(aSettingsFile) + 'tr4w.ini';
end;


(* THE ini HEADER LINE, WHICH IS PRINTED IN EVERY CASE.

  Four answers, and they must read differently: it used the one you named, it
  used the one it found, there was none to find, or you told it not to look.
  An absent line said all four at once. *)
procedure ReportIniLine;
begin
   if GNoIni then
      begin
      if FileExists(DefaultIniFile(GSettingsFile)) then
         begin
         WriteLn('  ini      : IGNORED (--no-ini). ',
                 DefaultIniFile(GSettingsFile), ' is present and was not read.');
         end
      else
         begin
         WriteLn('  ini      : none -- --no-ini, and there is none there anyway.');
         end;
      end
   else if GIniWasNamed then
      begin
      if FileExists(GIniFile) then
         begin
         WriteLn('  ini      : ', GIniFile, '  (you named it with --ini)');
         end
      else
         begin
         WriteLn('  ini      : ', GIniFile,
                 '  -- NOT FOUND, so nothing was read from it');
         end;
      WriteLn('             --ini is deprecated: with no flag at all it reads the');
      WriteLn('             tr4w.ini beside the settings file.');
      end
   else if GIniFile <> '' then
      begin
      WriteLn('  ini      : ', GIniFile, '  (found beside the settings file)');
      end
   else
      begin
      WriteLn('  ini      : none -- no tr4w.ini beside the settings file');
      WriteLn('             (looked for ', DefaultIniFile(GSettingsFile), ')');
      end;
end;


procedure PrintReport(const aReport: TConvertReport);
var
   i: integer;
   e: TConvertEntry;
   shown: integer;
begin
   shown := 0;
   for i := 0 to High(aReport) do
      begin
      e := aReport[i];
      (* The quiet outcomes are hidden unless asked for. A run that converted
        four values and left two hundred alone should SAY four things. *)
      if (not GShowAll)
         and (e.Outcome in [coNoLegacyValue, coContestScoped, coSameAlready]) then
         begin
         Continue;
         end;
      WriteLn(Format('  %-12s %-34s %s',
                     [ConvertOutcomeName(e.Outcome), e.Command, e.NewValue]));
      Inc(shown);
      end;
   if shown = 0 then
      begin
      WriteLn('  (nothing to report -- add --all to see every command)');
      end;
end;


(* THE SAME CONVERSION AGAIN, THIS TIME WRITING.

  A second, clean settings object rather than saving the one the dry run
  populated: the dry run's object has already been mutated by every value the
  report describes, so saving it would write values this run never re-read from
  disk. Running the one conversion path a second time keeps "what was reported"
  and "what was written" produced by the same code. It costs one more read of a
  small JSON file. *)
procedure ApplyNow;
var
   settings: TR4WSettings;
   entries: TConvertReport;
   err: string;
begin
   settings := TR4WSettings.Create;
   try
      if not ConvertStationSettings(GSettingsFile, GIniFile, True,
                                    settings, entries, err) then
         begin
         WriteLn;
         WriteLn('FAILED: ', err);
         ExitCode := 1;
         Exit;
         end;

      WriteLn;
      WriteLn(Format('  Applied. %d value(s) written to %s',
                     [CountOutcome(entries, coConverted), GSettingsFile]));
   finally
      settings.Free;
   end;
end;


var
   settings: TR4WSettings;
   entries: TConvertReport;
   err: string;
   refused: integer;
   converted: integer;
begin
   ExitCode := 0;
   if not ParseCommandLine then
      begin
      Exit;
      end;

   if GSettingsFile = '' then
      begin
      GSettingsFile := DefaultSettingsFile(GSettingsOrigin);
      end
   else
      begin
      GSettingsOrigin := soNamed;
      end;

   (* THE DEFAULT INI IS RESOLVED HERE, after --settings has had its say, and
     only if it is actually there: a path that names nothing would be handled
     the same way downstream, but the header could no longer tell the two
     "no ini" answers apart. *)
   if GNoIni then
      begin
      GIniFile := '';
      end
   else if (GIniFile = '') and FileExists(DefaultIniFile(GSettingsFile)) then
      begin
      GIniFile := DefaultIniFile(GSettingsFile);
      end;

   WriteLn('tr4wconvert');
   ReportSettingsLine;
   ReportStateLine;
   ReportIniLine;
   if GApply then
      begin
      WriteLn('  mode     : APPLY -- the settings file will be written');
      end
   else if GReportOnly then
      begin
      WriteLn('  mode     : report only -- nothing will be written');
      end
   else if StdInIsTerminal then
      begin
      WriteLn('  mode     : report, then ask whether to apply');
      end
   else
      begin
      WriteLn('  mode     : report only -- not a terminal, so nothing will be asked');
      end;
   WriteLn;

   settings := TR4WSettings.Create;
   try
      if not ConvertStationSettings(GSettingsFile, GIniFile, GApply,
                                    settings, entries, err) then
         begin
         WriteLn('FAILED: ', err);
         ExitCode := 1;
         Exit;
         end;

      PrintReport(entries);
      refused := CountOutcome(entries, coRefused);
      converted := CountOutcome(entries, coConverted);

      WriteLn;
      WriteLn(Format('  %d converted, %d already current, %d refused,',
                     [converted, CountOutcome(entries, coSameAlready), refused]));
      WriteLn(Format('  %d with no old value, %d left to the contest database.',
                     [CountOutcome(entries, coNoLegacyValue),
                      CountOutcome(entries, coContestScoped)]));

      if refused > 0 then
         begin
         (* A DISTINCT CODE, because "it ran" and "it ran and your old file
           held something this program will not accept" are different answers
           and only one of them needs a human. *)
         ExitCode := 2;
         end;

      if GApply then
         begin
         WriteLn;
         if converted > 0 then
            begin
            WriteLn(Format('  Applied. %d value(s) written to %s',
                           [converted, GSettingsFile]));
            end
         else
            begin
            WriteLn('  Nothing needed changing. The settings file was left alone.');
            end;
         end
      else if converted = 0 then
         begin
         WriteLn;
         if GIniFile = '' then
            begin
            (* NOTHING TO CONVERT FROM, which is a perfectly sensible outcome
              and must not read like a failure -- a 5.x installation with no
              4.x history lands here. *)
            WriteLn('  There is no old configuration to convert -- no ini was read and');
            WriteLn('  nothing else held an old value. Nothing was written.');
            end
         else
            begin
            WriteLn('  There is nothing to apply -- your settings already hold everything');
            WriteLn('  the old configuration had. Nothing was written.');
            end;
         end
      else if GReportOnly then
         begin
         WriteLn;
         WriteLn('  Nothing was written (--report-only). Run tr4wconvert again without');
         WriteLn('  it to be asked, or tr4wconvert --apply to apply these changes.');
         end
      else if not StdInIsTerminal then
         begin
         (* THE CASE THAT MUST NOT HANG. Piped, redirected or with no console
           there is nobody to answer, so it says so and writes nothing. *)
         WriteLn;
         WriteLn('  Nothing was written. You were not asked because this is not a');
         WriteLn('  terminal; a script applies these changes with tr4wconvert --apply.');
         end
      else if OperatorSaysYes(converted) then
         begin
         ApplyNow;
         end
      else
         begin
         WriteLn;
         WriteLn('  Nothing was written -- your settings are exactly as they were.');
         WriteLn('  To apply them later, run tr4wconvert again and answer Yes.');
         end;
   finally
      settings.Free;
   end;
end.
