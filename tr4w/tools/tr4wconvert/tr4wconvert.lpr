program tr4wconvert;

(*
  TR4WCONVERT -- carry an operator's old configuration into the files TR4W
  reads, as a SEPARATE ACT rather than as part of starting the program.

  NY4I, 2026-09-12: *"we needed a much clearer demarcation between the current
  program/contest settings and the import of old files. If it is getting too
  complicated, I am not adverse to a standalone conversion utility."*

  Usage:

      tr4wconvert                       report on settings\tr4w.json beside this
                                        binary, and change nothing
      tr4wconvert --apply               do it
      tr4wconvert --settings <path>     a particular settings file
      tr4wconvert --ini <path>          also read a legacy tr4w.ini
      tr4wconvert --all                 list every command, not just the
                                        interesting ones

  IT REPORTS BY DEFAULT AND CHANGES NOTHING. An operator should be able to see
  what would happen before it happens, and a conversion that has already run is
  worth being able to re-check.

  EXIT CODES: 0 when it ran, 1 when the settings file could not be read, and 2
  when one or more values were REFUSED -- that last one so a script can tell
  "converted cleanly" from "converted, but the old file held something the
  program will not accept".

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
{$ENDIF}
   SysUtils,
   Classes,
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
   GApply: boolean = False;
   GShowAll: boolean = False;


procedure Usage;
begin
   WriteLn('tr4wconvert -- carry an old TR4W configuration into settings\tr4w.json');
   WriteLn;
   WriteLn('  --settings <path>   the settings file (default: settings\tr4w.json');
   WriteLn('                      beside this program)');
   WriteLn('  --ini <path>        also read a legacy tr4w.ini');
   WriteLn('  --apply             write the result; without it nothing is changed');
   WriteLn('  --all               list every command, not just the interesting ones');
   WriteLn('  --help              this');
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
      else if SameText(arg, '--ini') and (i < ParamCount) then
         begin
         Inc(i);
         GIniFile := ParamStr(i);
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


(* The settings file beside this binary, which is where TR4W keeps its own. *)
function DefaultSettingsFile: string;
begin
   Result := ExtractFilePath(ParamStr(0)) + 'settings' + PathDelim + 'tr4w.json';
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


var
   settings: TR4WSettings;
   entries: TConvertReport;
   err: string;
   refused: integer;
begin
   ExitCode := 0;
   if not ParseCommandLine then
      begin
      Exit;
      end;

   if GSettingsFile = '' then
      begin
      GSettingsFile := DefaultSettingsFile;
      end;

   WriteLn('tr4wconvert');
   WriteLn('  settings : ', GSettingsFile);
   if GIniFile <> '' then
      begin
      WriteLn('  ini      : ', GIniFile);
      end;
   if GApply then
      begin
      WriteLn('  mode     : APPLY -- the settings file will be written');
      end
   else
      begin
      WriteLn('  mode     : report only -- nothing will be written');
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

      WriteLn;
      WriteLn(Format('  %d converted, %d already current, %d refused,',
                     [CountOutcome(entries, coConverted),
                      CountOutcome(entries, coSameAlready), refused]));
      WriteLn(Format('  %d with no old value, %d left to the contest database.',
                     [CountOutcome(entries, coNoLegacyValue),
                      CountOutcome(entries, coContestScoped)]));

      if not GApply then
         begin
         WriteLn;
         WriteLn('  Nothing was written. Run again with --apply to do it.');
         end;

      if refused > 0 then
         begin
         (* A DISTINCT CODE, because "it ran" and "it ran and your old file
           held something this program will not accept" are different answers
           and only one of them needs a human. *)
         ExitCode := 2;
         end;
   finally
      settings.Free;
   end;
end.
