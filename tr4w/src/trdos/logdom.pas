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
  Generics.Collections,   // TObjectDictionary -- the domestic table
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

  (* ONE ALIAS OF A DOMESTIC FILE: what a received text that equals the alias
    resolves to. The alias itself is the table's key.

    THE FIELDS ARE string[10], as PrefixRec's were, ON PURPOSE: a .dom name
    longer than ten characters is truncated when it is stored (286 aliases in
    the shipped files are), and every lookup has always answered with the
    truncated text. *)
  TDomQTHEntry = class
  public
    DomQTH: Str10;
    Multiplier: Str10;
  end;

  RemainingDomMultRec = record
    ID: string[11];
    Name: string[19];
  end;

//  RemainingDomMultArrayType = array[0..MaxNumberRemainingDomQTHs] of RemainingDomMultRec {string[7 + 8]};
//  RemainingDomMultArrayPtr = ^RemainingDomMultArrayType;

  (* THE SESSION'S DOMESTIC TABLE -- every alias of the loaded .dom file (and
    the files it INCLUDEs), keyed by the alias. 2026-10-16.

    IT WAS AN OLD-STYLE object HOLDING 36 HAND-BUILT LINKED LISTS, bucketed by
    the alias's first character, with New/Dispose. Emptying them before a
    second load read through nil at the end of every list (D7's loop, line
    for line), so loading a .dom into a table that already held one was an
    access violation -- reached by nothing only because the one load runs
    once per process into an empty table. The table owns a dictionary now:
    a reload is Clear, and there is no pointer to walk.

    THE LOOKUP IS WHAT IT WAS, which is why a dictionary is enough:
      * a match is EXACT equality of the (uppercased) received text with an
        alias -- never a prefix, never case-folded here;
      * equal texts share a first character, so the per-character buckets
        never changed an answer; they only partitioned the walk;
      * among duplicate aliases the FIRST ADDED wins -- the walk stopped at
        the first match -- so a later duplicate is not stored;
      * an alias is stored only when it starts with 0-9 or A-Z (the buckets'
        RecordPointerIndex refused every other first character);
      * an EMPTY alias is not stored and an empty text finds nothing. Under
        the lists both chose a bucket from a STALE byte (Str20[1] of an
        empty string), so neither had a defined answer; eudx.dom's 26
        " = " lines are the shipped instances. *)
  TDomQTHTable = class
  private
    FEntries: TObjectDictionary<string, TDomQTHEntry>;
  public
    NumberRemainingMults: integer;

    constructor Create;
    destructor Destroy; override;

    procedure AddNewPrefixRecord(Prefix: Str20; DomQTH: Str20; Multiplier: Str20);
    (* THE ALIAS EQUAL TO aText, or False -- the file half of GetDomQTH,
      which also asks the contest first. The entry stays the table's. *)
    function FindAlias(const aText: string; out aEntry: TDomQTHEntry): boolean;
    (* HasPrefix and RemovePrefix are the tests' -- a test that puts one
      alias in the live table takes it out again. *)
    function HasPrefix(const aPrefix: string): boolean;
    procedure RemovePrefix(const aPrefix: string);

    function GetDomQTH(InputString: Str20; var Multiplier: Str10; var QTH: Str10): boolean;
    function LoadInDomQTHFile(const FileName: string): boolean;
    function ReadDomQTHFile(const FileName: string; IncludedFile: boolean): boolean;
  end;

procedure EnumDOMFILE(FileString: PShortString);

(* IS THIS .dom LINE AN INCLUDE THE READER WILL NOT FOLLOW? -- #88 round 3
  (2026-10-26). The reader follows exactly `INCLUDE FILE <name>` (upper
  case, leading blanks allowed). A line whose first word is INCLUDE in any
  case and which is not that is skipped -- it holds no `=`, so it is no entry
  either -- and nc.dom's `INCLUDE S50.DOM` lived that way since D7, so no NC
  entrant could log a US state. EnumDOMFILE warns on such a line, and
  Lint-DomCoverage fails a shipped file that holds one. Public so a test
  asks it directly. *)
function DomLineIsAnUnfollowedInclude(const aLine: string): boolean;

(* The const section held one live entry, RemainingMultDisplayModeTypeSA,
  which moved to uSettingsModel with its type on 2026-09-13. The only other
  line in it was already commented out. *)
//  ExternalLogTypeSA                     : array[ExternalLogType] of PChar( = ('None', 'DXKeeper', 'ACLog', 'HRD');

var
  (* ActiveDomesticMult MOVED -- M10 S9e, 2026-10-14, to
    uContestSession.ContestSession.DomesticMult, and was DELETED with the
    domestic kind at M11 S6 part 2: each contest states its domestic rules
    (TContestBase.DomesticMultiplierFromQTH, HasDomesticMultiplier). *)
  (* Created in this unit's initialization, freed in its finalization. *)
  DomQTHTable                           : TDomQTHTable;
  (* LiteralDomesticQTH WAS HERE -- deleted for issue #109 (2026-10-26).
    Settings.Contest.LiteralDomesticQth replaced it on 2026-09-12 and nothing
    wrote this global after that, while the Cabrillo writer and the contest
    matrix still read it. *)
  MultipliersIsCounties                 : boolean;
implementation

uses
  ZoneCont,
  LogWind,
  MainUnit, LogSCP, {KK1L: DEBUG}
  (* Contest, the active contest's type -- asked of the factory below. *)
  PostUnit,
  (* ContestDomesticMultiplierFromQTH, TDomesticQTHAnswer -- GetDomQTH asks
    the contest what a received QTH means (M11 S6). *)
  uContestBase,
  uContestFactory,
  (* The unit's own logger -- an INCLUDE the reader will not follow is
    reported, never skipped in silence (#88 round 3). *)
  Log4D,
  (* Where an INCLUDE FILE is looked for, the nesting bound, and the report
    when one cannot be followed (#138). *)
  uDomInclude;

var
  (* THE TABLE A .dom IS BEING READ INTO. EnumDOMFILE is a line callback
    with no context (TF.EnumerateLinesInFile), so ReadDomQTHFile names its
    own table here for the duration of the read. It wrote to the global
    DomQTHTable before, whatever object the read was called on -- the same
    object in the program, which is why nothing saw it. nil between reads. *)
  GLoadTarget: TDomQTHTable = nil;
  (* AND THE FILE, for the same reason -- so a warning names it. '' between
    reads. *)
  GLoadFileName: string = '';
  (* HOW MANY READS ARE OPEN -- 1 inside a top-level file, 2 inside a file it
    includes. EnumDOMFILE refuses an include past MAX_DOM_INCLUDE_DEPTH, so
    a file that includes itself ends (#138). 0 between reads. *)
  GLoadDepth: integer = 0;
  domLogger: TLogLogger;

function DomLineIsAnUnfollowedInclude(const aLine: string): boolean;
var
  firstWord: string;
  blank: integer;
  i: integer;
begin
  (* LEADING BLANKS AND TABS ARE THE READER'S: GetRidOfPrecedingSpaces. *)
  i := 1;
  while (i <= Length(aLine)) and ((aLine[i] = ' ') or (aLine[i] = #9)) do
     begin
     Inc(i);
     end;
  firstWord := Copy(aLine, i, Length(aLine));
  (* EnumDOMFILE's own test, character for character: the twelve letters,
    case-sensitive. *)
  if Copy(firstWord, 1, Length('INCLUDE FILE')) = 'INCLUDE FILE' then
     begin
     Result := False;
     Exit;
     end;
  blank := Pos(' ', firstWord);
  if blank > 0 then
     begin
     firstWord := Copy(firstWord, 1, blank - 1);
     end;
  Result := UpperCase(firstWord) = 'INCLUDE';
end;

constructor TDomQTHTable.Create;
begin
  inherited Create;
  FEntries := TObjectDictionary<string, TDomQTHEntry>.Create([doOwnsValues]);
end;

destructor TDomQTHTable.Destroy;
begin
  FEntries.Free;
  inherited Destroy;
end;

procedure TDomQTHTable.AddNewPrefixRecord(Prefix: Str20; DomQTH: Str20; Multiplier: Str20);

var
  StoredPrefix                          : Str10;
  Entry                                 : TDomQTHEntry;

begin
  (* THE RULES OF THE OLD BUCKETS -- see the class's declaration. *)
  if Length(Prefix) = 0 then
     begin
     Exit;
     end;

  if not (Prefix[1] in ['0'..'9', 'A'..'Z']) then
     begin
     Exit;
     end;

  (* Truncated to ten, as PrefixRec.Prefix was. *)
  StoredPrefix := Prefix;

  if FEntries.ContainsKey(string(StoredPrefix)) then
     begin
     Exit;
     end;

  Entry := TDomQTHEntry.Create;
  Entry.DomQTH := DomQTH;
  Entry.Multiplier := Multiplier;
  FEntries.Add(string(StoredPrefix), Entry);
end;

function TDomQTHTable.FindAlias(const aText: string; out aEntry: TDomQTHEntry): boolean;
begin
  Result := FEntries.TryGetValue(aText, aEntry);
end;

function TDomQTHTable.HasPrefix(const aPrefix: string): boolean;
begin
  Result := FEntries.ContainsKey(aPrefix);
end;

procedure TDomQTHTable.RemovePrefix(const aPrefix: string);
begin
  FEntries.Remove(aPrefix);
end;

function TDomQTHTable.LoadInDomQTHFile(const FileName: string): boolean;

begin

  LoadInDomQTHFile := False;

//  if ActiveDomQTHFile = FileName then
//  begin
//    LoadInDomQTHFile := True;
//    Exit;
//  end;

  //{WLI}    Directory := FindDirectory (FileName);

  if not ReadDomQTHFile(FileName, False) then
     begin
     //    ActiveDomQTHFile := '';
         Exit;
     end;

  LoadInDomQTHFile := True;
//  ActiveDomQTHFile := FileName;
end;

function TDomQTHTable.GetDomQTH(InputString: Str20;
  var Multiplier: Str10;
  var QTH: Str10): boolean;

(* Returns TRUE if found *)

var
  Entry                                 : TDomQTHEntry;
  found                                 : boolean;
  contestRules                          : TContestBase;

begin

  FillChar(Multiplier, SizeOf(Multiplier), 0); //  Multiplier := '';
  FillChar(QTH, SizeOf(QTH), 0); //    QTH := '';
   GetDomQTH := False;

  strU(InputString);

  (* ONE ActiveContest FOR THE WHOLE LOOKUP -- M11 S6 part 2. The
    no-domestic exit asks the contest (HasDomesticMultiplier; it was the
    session's DoingDomesticMults, a field read) and so does the rule below,
    on the same object. A domestic contest makes the one fetch it made
    since part 1, moved up to here; a contest with no domestic multiplier
    now makes one where the field read cost nothing -- per domestic-QTH
    lookup in live entry, not per rescored QSO (the rescore reaches this
    only for a slash call under a QSO-party exchange). The callers
    (FoundDomesticQTH's, live entry and the parse shapes) hold no contest
    object to hand down. *)
  contestRules := ActiveContest(Contest);
  if not ContestHasDomesticMultiplier(contestRules) then
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
    lookup keeps unless it knows the text. *)
  found := False;
  if ContestDomesticMultiplierFromQTH(contestRules, InputString,
                                      Multiplier, QTH, found) = dqaDecided then
     begin
     GetDomQTH := found;
     Exit;
     end;
  GetDomQTH := found;

  (* THE FILE: the alias EQUAL to the text, or nothing -- see the class's
    declaration for why this is the bucket walk's answer. *)
  if FindAlias(string(InputString), Entry) then
     begin
     QTH := Entry.DomQTH;
     Multiplier := Entry.Multiplier;
     GetDomQTH := True;
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

function TDomQTHTable.ReadDomQTHFile(const FileName: string; IncludedFile: boolean): boolean;

var
  PreviousTarget                        : TDomQTHTable;
  PreviousFileName                      : string;
  Enumerated                            : boolean;

begin
  ReadDomQTHFile := False;

  (* A TOP-LEVEL FILE REPLACES THE TABLE; an INCLUDEd one adds to it. *)
  if not IncludedFile then
     begin
     NumberRemainingMults := 0;
     FEntries.Clear;
     end;

  (* THE LINES GO INTO THIS TABLE -- see GLoadTarget. Restored after, so an
    INCLUDE FILE (which re-enters here for the same table) leaves it set. *)
  PreviousTarget := GLoadTarget;
  PreviousFileName := GLoadFileName;
  GLoadTarget := Self;
  GLoadFileName := FileName;
  Inc(GLoadDepth);
  try
     Enumerated := EnumerateLinesInFile(FileName, EnumDOMFILE, False);
  finally
     Dec(GLoadDepth);
     GLoadTarget := PreviousTarget;
     GLoadFileName := PreviousFileName;
  end;

  if not Enumerated then
     begin
     (* THE ONLY SETTING THAT NAMES A TOP-LEVEL .DOM IS DOMESTIC FILENAME, so
       the attribution is not a guess -- see TF.UnableToFindFileMessage. An
       INCLUDEd file was named by a LINE, not by the setting: its caller,
       FollowDomInclude, reports it with the file and the line (#138). *)
     if not IncludedFile then
        begin
        UnableToFindFileMessage(FileName, 'DOMESTIC FILENAME');
        end;
     Exit;
     end;

  //  NumberRemainingMults:=NumberRemainingMults;
  ReadDomQTHFile := True;
end;

(* FOLLOW ONE `INCLUDE FILE <name>` LINE OF THE FILE BEING READ -- or say why
  not. Issue #138, 2026-10-27.

  WHERE: beside the file that holds the line, then the shipped dom folder
  (uDomInclude.ResolveDomInclude). D7 built '%sDOM\%s' from the program
  directory, and the conversion that replaced its sprintf (c51dcc1d) had
  dropped the backslash; uAppPaths.ShippedDomFilePath composed it after that,
  against the WORKING directory -- the same place as the including file for
  every shipped .dom, which is why only a file read from elsewhere saw it.

  A FILE THAT CANNOT BE READ IS REPORTED, NAMING THE FILE THAT NAMES IT, THE
  LINE AND EVERY PATH TRIED, and the rest of the file loads, as D7's loader
  went on. It was reported as "could not find" plus "the name came from the
  DOMESTIC FILENAME setting", which was wrong -- a line named it -- and in
  the unit-test binary that report was a modal with nobody to dismiss it,
  which hung the suite. The LogDom Error is unconditional; showwarning
  decides whether an operator is there to see the dialog (interactive: yes,
  as a missing DOMESTIC FILENAME already is; /EXPORT, /RESCORE, /MATRIX and
  the tests: logged only).

  A LINE PAST MAX_DOM_INCLUDE_DEPTH IS REPORTED AND NOT FOLLOWED, so an
  include circle ends instead of exhausting the stack. *)
procedure FollowDomInclude(const aLine, aName: string);
var
  path                                  : string;
  tried                                 : string;
  report                                : string;
begin
  report := '';
  if GLoadDepth >= MAX_DOM_INCLUDE_DEPTH then
     begin
     report := DomIncludeTooDeepText(GLoadFileName, aLine);
     end
  else
     begin
     path := ResolveDomInclude(GLoadFileName, aName, tried);
     if (path = '') or (not GLoadTarget.ReadDomQTHFile(path, True)) then
        begin
        if path <> '' then
           begin
           tried := path;
           end;
        report := DomIncludeNotReadText(GLoadFileName, aLine, tried);
        end;
     end;

  if report <> '' then
     begin
     domLogger.Error(DomIncludeLogLine(report));
     showwarning(report);
     end;
end;

procedure EnumDOMFILE(FileString: PShortString);
const incfile                           = 'INCLUDE FILE';
label
  AlreadyInList;

var
  DomQTHString, DomQTHName, Multiplier, TempString: ShortString; {: Str40;}
  DomName                               : Str40;
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
     FollowDomInclude(string(FileString^), string(TempString));
     end
  else if DomLineIsAnUnfollowedInclude(string(FileString^)) then
     begin
     (* REPORTED, NOT FOLLOWED: only `INCLUDE FILE <name>` is an include,
       and guessing at another spelling would make the file's meaning
       depend on this reader's leniency. See DomLineIsAnUnfollowedInclude. *)
     domLogger.Warn('[LogDom] ' + GLoadFileName + ': "' + string(FileString^) +
                    '" is not followed -- only INCLUDE FILE <name> includes a file');
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
           GLoadTarget.AddNewPrefixRecord(DomQTHString, DomQTHName, Multiplier)
           end
        else
           begin
           if length(DomQTHString) > tRemMultsColumnWidth then
              begin
              tRemMultsColumnWidth := length(DomName);
              end;
           mo.DomList.AltName[MultIndex] := Copy(DomQTHString, 2, 32);
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

initialization
  domLogger := TLogLogger.GetLogger('LogDom');
  (* BEFORE ANY READER: the one load is LogCfg.SetUpGlobalsAndInitialize, at
    run time, long after every unit's initialization. *)
  DomQTHTable := TDomQTHTable.Create;

finalization
  (* Not FreeAndNil: SysUtils is not in this unit's uses, and adding it
    would shadow utils_text's UpperCase, which EnumDOMFILE calls. *)
  DomQTHTable.Free;
  DomQTHTable := nil;

end.
