program ctygen;
{$MODE DELPHI}
{$APPTYPE CONSOLE}
(* CHARACTERISATION GENERATOR for uCTYDAT.

  Reads a list of callsigns, runs every public lookup over the SHIPPED
  cty.dat, and writes one pipe-separated record per call. The output is
  frozen as a golden file and compared on every build, so a rewrite of the
  unit has to reproduce what the current one answers, call for call.

  It is a separate program because it only has to run when the golden file is
  regenerated -- deliberately, so regenerating is a decision someone makes
  rather than something a test does silently when it disagrees. *)
uses Interfaces, SysUtils, Classes, VC, uctydat;

var
   calls: TStringList;
   outf: TextFile;
   i: integer;
   c: string;
   qth: QTHRecord;
   ok: boolean;
   id: DXMultiplierString;
   grid: string;
   ctyPath, inPath, outPath: string;

function ContName(k: ContinentType): string;
begin
   case k of
      NorthAmerica: Result := 'NA';
      SouthAmerica: Result := 'SA';
      Europe:       Result := 'EU';
      Africa:       Result := 'AF';
      Asia:         Result := 'AS';
      Oceania:      Result := 'OC';
   else
      Result := '??';
   end;
end;

begin
   if ParamCount < 3 then
      begin
      writeln('usage: ctygen <cty.dat> <calls.txt> <out.txt>');
      Halt(2);
      end;
   ctyPath := ParamStr(1);
   inPath  := ParamStr(2);
   outPath := ParamStr(3);

   if not ctyLoadInCountryFile(PAnsiChar(AnsiString(ctyPath)), False, False) then
      begin
      writeln('FAILED to load ', ctyPath);
      Halt(1);
      end;
   writeln('loaded ', ctyPath, '  countries=', ctyGetTotalCountries,
           '  version=', string(ctyGetVersion));

   calls := TStringList.Create;
   try
      calls.LoadFromFile(inPath);
      AssignFile(outf, outPath);
      Rewrite(outf);
      try
         writeln(outf, '# uCTYDAT characterisation -- GENERATED, do not hand-edit.');
         writeln(outf, '# call|country|id|cq|itu|continent|prefix|standardcall|grid');
         for i := 0 to calls.Count - 1 do
            begin
            c := Trim(calls[i]);
            if (c = '') or (c[1] = '#') then Continue;

            FillChar(qth, SizeOf(qth), 0);
            ok := ctyLocateCall(CallString(c), qth);
            id := '';
            grid := ctyGetGrid(c, id);

            writeln(outf, Format('%s|%d|%s|%d|%d|%s|%s|%s|%s',
               [c,
                ctyGetCountry(c),
                ctyGetCountryID(c),
                ctyGetCQZone(c),
                ctyGetITUZone(c),
                ContName(ctyGetContinent(c)),
                string(qth.Prefix),
                string(qth.StandardCall),
                grid]));
            if not ok then { recorded implicitly by the zeros above } ;
            end;
      finally
         CloseFile(outf);
      end;
      writeln('wrote ', outPath, '  (', calls.Count, ' input lines)');
   finally
      calls.Free;
   end;
end.
