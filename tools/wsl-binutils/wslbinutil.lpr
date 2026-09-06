program wslbinutil;
{
  A CROSS ASSEMBLER AND LINKER THAT ARE ALREADY ON THE MACHINE.

  FPC can build an x86_64-linux cross COMPILER from source with nothing but the
  native Windows compiler -- ppcrossx64.exe drops out of `make crossall` in a
  couple of minutes. What it cannot do is finish the Linux RTL, because the
  startup stubs (prt0.as and friends) are hand-written GNU assembler and have to
  go through a real `as` for the target. That is the only reason the build stops.

  Installing cross binutils means a download, and installing them INTO WSL means
  a password. Neither is necessary: Ubuntu under WSL already ships
  /usr/bin/as and /usr/bin/ld (binutils 2.46), which ARE x86_64-linux binutils.
  This program is the adapter between the two worlds.

  HOW IT IS USED.  Copy it to x86_64-linux-as.exe and x86_64-linux-ld.exe on the
  PATH.  FPC's makefiles invoke those names through CreateProcess -- which will
  not launch a .cmd or .bat, which is why this is a real executable -- and it
  decides which tool to run from its OWN file name.

  WHAT IT ACTUALLY DOES.  Rewrites Windows paths in the arguments to their /mnt
  equivalents (C:/x/y -> /mnt/c/x/y, backslashes to forward) and hands the rest
  to `wsl.exe -d <distro> -- <tool>`.  Nothing else: no quoting cleverness, no
  argument parsing.  The exit code is passed straight back so make sees a real
  failure as a failure.

  THE DISTRO comes from TR4W_WSL_DISTRO if set, else "Ubuntu".

  See docs/CROSS_COMPILING.md.
}

{$MODE OBJFPC}{$H+}

uses
   Classes, SysUtils, Process;

(* C:\foo\bar or C:/foo/bar  ->  /mnt/c/foo/bar.

  Only a leading drive letter counts.  An argument that is not a path is
  returned untouched, and so is one that already looks like a Unix path --
  the compiler passes both kinds. *)
function ToWslPath(const aArg: string): string;
var
   i: integer;
begin
   Result := aArg;

   if (Length(aArg) >= 3) and (aArg[2] = ':') and
      (aArg[3] in ['\', '/']) and
      (UpCase(aArg[1]) in ['A'..'Z']) then
      begin
      Result := '/mnt/' + LowerCase(aArg[1]) + Copy(aArg, 3, MaxInt);
      end;

   for i := 1 to Length(Result) do
      begin
      if Result[i] = '\' then
         begin
         Result[i] := '/';
         end;
      end;
end;

(* THE LINK SCRIPT HAS TO BE TRANSLATED TOO, NOT JUST THE ARGUMENTS.

  ld is passed `-T <script>`, and FPC writes that script with WINDOWS paths
  inside it -- SEARCH_DIR("C:\fpcupdeluxe\...\") and a list of .o files in the
  same form. Rewriting only argv gets as far as assembling and then fails at
  the link with "cannot find C:\...\system.o", which is exactly what happened
  the first time this was tried.

  So a translated COPY is written beside the original and handed to ld instead.
  The original is left alone: FPC wrote it, may read it back, and a tool that
  mutates its caller's files is hard to reason about later.

  The scan is deliberately dumb -- find <letter>:<slash>, take everything up to
  whitespace, a quote, a comma or a close paren -- because that is the shape FPC
  emits, and anything cleverer would be guessing at a format that is not ours. *)
function TranslateLinkScript(const aPath: string): string;
var
   src, dst: TStringList;
   line, acc, tok: string;
   i, p, q: integer;
begin
   Result := aPath;
   if not FileExists(aPath) then
      begin
      Exit;
      end;

   src := TStringList.Create;
   dst := TStringList.Create;
   try
      src.LoadFromFile(aPath);
      for i := 0 to src.Count - 1 do
         begin
         line := src[i];
         acc := '';
         p := 1;
         while p <= Length(line) do
            begin
            if (p + 2 <= Length(line)) and (line[p + 1] = ':') and
               ((line[p + 2] = '\') or (line[p + 2] = '/')) and
               (UpCase(line[p]) in ['A'..'Z']) then
               begin
               q := p;
               while (q <= Length(line)) and
                     (not (line[q] in [' ', #9, '"', ')', ','])) do
                  begin
                  Inc(q);
                  end;
               tok := Copy(line, p, q - p);
               acc := acc + ToWslPath(tok);
               p := q;
               end
            else
               begin
               acc := acc + line[p];
               Inc(p);
               end;
            end;
         dst.Add(acc);
         end;

      Result := aPath + '.wsl';
      dst.SaveToFile(Result);
   finally
      dst.Free;
      src.Free;
   end;
end;

(* The tool to run is this executable's own name with the target prefix
  stripped: x86_64-linux-as.exe -> as. *)
function ToolName: string;
const
   PREFIX = 'x86_64-linux-';
begin
   Result := ChangeFileExt(ExtractFileName(ParamStr(0)), '');
   if Copy(Result, 1, Length(PREFIX)) = PREFIX then
      begin
      Result := Copy(Result, Length(PREFIX) + 1, MaxInt);
      end;
end;

var
   proc:   TProcess;
   i:      integer;
   distro: string;

begin
   distro := GetEnvironmentVariable('TR4W_WSL_DISTRO');
   if distro = '' then
      begin
      distro := 'Ubuntu';
      end;

   proc := TProcess.Create(nil);
   try
      proc.Executable := 'wsl.exe';
      proc.Parameters.Add('-d');
      proc.Parameters.Add(distro);
      proc.Parameters.Add('--');
      proc.Parameters.Add(ToolName);

      i := 1;
      while i <= ParamCount do
         begin
         if (ParamStr(i) = '-T') and (i < ParamCount) then
            begin
            proc.Parameters.Add('-T');
            Inc(i);
            proc.Parameters.Add(ToWslPath(TranslateLinkScript(ParamStr(i))));
            end
         else
            begin
            proc.Parameters.Add(ToWslPath(ParamStr(i)));
            end;
         Inc(i);
         end;

      { Inherit the console so as/ld diagnostics reach the build log, and wait:
        make reads the exit code. }
      proc.Options := [poWaitOnExit];
      proc.Execute;
      ExitCode := proc.ExitStatus;
   finally
      proc.Free;
   end;
end.
