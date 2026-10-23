(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE CONTEST MATRIX -- milestone M0 of docs/CONTEST_OWNERSHIP_DESIGN.md.

  A FROZEN RECORD OF WHAT THE PROGRAM DOES TODAY, PER ContestType, which every
  later milestone is checked against: M1 (identity), M2 (setup), M3 (scoring),
  M4 (export), and M5 (parse and import) once its capture is added. The golden
  corpus covers thirteen registered contests and is blind to setup, per-QSO
  points and parsing; this covers every ContestType and sees all three.

  IT ASSERTS "SAME AS BEFORE", NEVER "CORRECT". The frozen files are this
  program's own output. A defect present when they were frozen is pinned by
  them exactly as faithfully as a correct rule is -- which is the point: a
  move that changes behaviour shows up, and whether the change is a fix or a
  regression is a separate, human question.

  ---------------------------------------------------------------------------
  TWO SWITCHES, ONE HARNESS
  ---------------------------------------------------------------------------

      tr4w.exe /MATRIXLIST <out-file>
          Every contest the registry knows but NoContest ("no contest"), one
          per line, separated by '|':
              record-name  id  class-unit  P  DF  host state
          The script reads it to know what to run. It is THE REGISTRY
          ITERATED (KnownContests), so no contest is named anywhere -- here or
          in the script -- and a contest registered by its id (Q108 S3) is
          run like any other. The record name is MatrixRecordName(id), the
          ONE place the frozen file's name is derived; the class's unit lets
          the script refuse an application whose registry holds a contest
          from outside src/contestFactory (the unit tests' fixture, say).

      tr4w.exe <work>\<stem>.cfg /MATRIX <out-file> <requested-id>
          The contest the .cfg selects, booted by the ordinary startup path,
          captured, then Halt. Positioned where /EXPORT is, for the same
          reason: the config, the log and the contest are all set up by then.
          The requested contest is named by its ID (Q108 S3; it was the
          legacy ordinal), so a contest with no legacy number can be asked
          for.

  ONE CONTEST PER PROCESS, AND THAT IS NOT A CONVENIENCE. FoundContest is not
  idempotent: it ADDS to the domestic country list (only ReadInConfigFile
  clears it), and its arms set Settings.Bands.WarcEnabled, MultipliersIsCounties,
  DXMultLimit, tAllowDupeQSOs and a dozen more that no other arm resets. A
  harness looping over contests in one process would record each contest
  polluted by every contest before it, so the record would depend on the
  enum's ORDER. A fresh process per contest is also simply what an operator
  does: open a contest. It costs about a third of a second.

  NO FACTORY BYPASS. Whatever path a contest takes today -- its class, or the
  legacy arm -- is the path this runs. /NOFACTORY was deleted on purpose
  (2026-09-29) and nothing here brings it back.

  ---------------------------------------------------------------------------
  WHAT ONE RECORD CONTAINS
  ---------------------------------------------------------------------------

    identity   requested vs selected contest -- its id and its legacy number,
               if it has one -- and the class (or none)
    setup      the session's kinds (six Active* at M0; four since M11 S3
               and S4 deleted the prefix and DX kinds), the doing.* flags,
               the CTY modes, every engine global
               FoundContest writes, the domestic country list, the county-line
               answer, the CW memories it writes, and EVERY SETTING WHOSE VALUE
               DIFFERS FROM A FRESHLY CONSTRUCTED SETTINGS OBJECT -- so a
               Settings.* write by any arm is caught without this file having
               to list it
    scoring    per synthetic QSO, the fields /RESCORE recomputes, through
               MainUnit.RecomputeQSOScoring -- the rescore's own body, not a
               copy of it. Since Q107, for an entrant OUTSIDE a contest's
               host area only, one more QSO (37) whose QTH is a key of the
               contest's own domestic file -- see HOST_QSO
    export     the QSOs appended to the scratch log, then the REAL exporters
               (ExportToADIF, CreateCabrilloFile): the Cabrillo CONTEST: and
               QSO: lines, and every ADIF record after <EOH>

    import     (M5a) ADIF records read back through the real import path
               (MainUnit.ParseADIFRecord, the routine ImportFromADIF and the
               WSJT-X reader call): the records the export above just wrote,
               plus synthetic FOREIGN-LOGGER records carrying the
               contest-dependent tags. Every ContestExchange field the import
               set is recorded.

    parse      (M5b) TYPED exchanges through the path live entry takes
               (MainUnit.ParametersOkay, which TryLogContact calls on Enter):
               one fixed list of exchange texts for every contest, recording
               whether each was accepted, the message and token a refusal
               shows, the counties a county line queued, and every
               ContestExchange field the parse set. Appended after import and
               frozen before the first parse arm moved, so every section
               above it kept its bytes.

    totals     (M6) the log the scoring section wrote, RELOADED through the
               path opening a contest takes (MainUnit.LoadinLog -- what
               /EXPORT's start runs), then the totals the program computes
               from it: the QSO points, the QTCs, the QSO and multiplier
               counts by band and mode, LogEdit.TotalScore -- the one score
               every display and export reads -- and the CLAIMED-SCORE: line
               of a Cabrillo file written after the reload. Appended LAST and
               frozen before the first total-score rule moved.

    keys       (M11 S0c) BETWEEN parse AND totals: the exchange fields
               the contest states (SetUpExchangeInformation chose them until
               M11 S9a) and the zone count
               (MaxNumberOfZones), then MORE SYNTHETIC QSOs -- calls chosen so
               every live arm of SetPrefix and GetDXQTH meets a call it acts
               on (ON, YB, JT, Scandinavia, UA9/UA0, a Gagarin Cup station,
               I/IS0, the Black Sea, 9A, KL7, HB9, OK) -- scored exactly as
               the scoring section scores, and then more typed exchanges
               through the parse path, carrying the QTH texts GetDomQTH's
               arms read (IOTA, DOK, a six-character grid, a grid field, a
               short RDA). THESE QSOs ARE SCORED BUT NOT LOGGED, so the
               export, import and totals sections do not see them and kept
               every byte.

    initialexchange
               (M11 S0c) LAST, after totals: InitialExchangeEntry for a fixed
               list of calls, four times -- with no call-history file, with
               the matrix's own (MATRIX-TRMASTER.DTA, never the shipped one),
               with that file AND the logged history a reload puts in the
               callsigns list, and with all that AND a custom initial
               exchange string. See CaptureInitialExchange for why each pass
               needs what it does (plan findings F17 and F18).

  NOT CAPTURED, deliberately: Cabrillo header lines other than CONTEST: and,
  since M6, CLAIMED-SCORE: (the rest carry the build version or the
  operator's categories, which belong to M9), and the other identity readers
  (HamScore, WA7BNM, QRZ.RU), which produce no file.

  ---------------------------------------------------------------------------
  DETERMINISM
  ---------------------------------------------------------------------------
  No clock (the QSO times are fixed; CONTEST TITLE, the one clock-derived
  setting, is omitted), no machine paths (the log directory and the data
  directory are replaced by <LOGDIR> and <DATADIR>), and no developer settings:
  the script passes the matrix's own tracked settings fixture through
  --settings, which also moves the writable data directory away from any
  downloaded CTY.DAT, so the SHIPPED country file answers. *)
unit uContestMatrix;

{$I tr4w.inc}

interface

(* tr4w.exe /MATRIXLIST <out-file>. Returns the process exit code. *)
function RunContestMatrixList(const aOutFile: string): integer;

(* tr4w.exe <cfg> /MATRIX <out-file> <requested-id>. Returns the process
  exit code: 0 written, 1 misused, 2 the record could not be written. A
  contest whose capture RAISES still exits 0 -- the record says what raised,
  and that is the behaviour being frozen. *)
function RunContestMatrix(const aOutFile: string;
                          const aRequested: string): integer;

(* THE NAME OF A CONTEST'S FROZEN RECORD, from its id: the id with every blank
  written '_' (tr4w/test/contest-matrix/frozen/<name>.matrix). ONE RULE for
  every contest, legacy or registered by id -- Q108 S3. '' when the id cannot
  be a portable file name (a character a file system or the '|'-separated
  list refuses), which /MATRIXLIST refuses as a whole. *)
function MatrixRecordName(const aId: string): string;

implementation

uses
   SysUtils,
   Classes,
   TypInfo,
   VC,
   Tree,
   utils_text,
   uCTYDAT,
   LogWind,
   LogDupe,
   LogDom,
   LogCW,
   ZoneCont,
   PostUnit,
   uSettingsModel,
   uContestBase,
   uExchangeFields,
   uContestFactory,
   uContestRegistry,
   uContestStateQSOPartyBase,
   uContestSession,   (* the session's resolved kinds (M10 S9a) *)
   uLogStore,
   uCrashLog,     (* EarlyTrace -- /MATRIXLIST runs before tr4w.log is configured *)
   (* THE parse SECTION (M5b): the call-window text, the error a refusal
     shows, the county-line queue, and the domestic file's keys. *)
   LogStuff,
   uPendingCounties,
   uPOTAParks,
   uDomFileKeys,
   uAppPaths,
   (* THE totals SECTION (M6): the multiplier totals, and the one score
     function every display and export reads. *)
   uMults,
   LogEdit,
   (* THE initialexchange SECTION (M11 S0c): the call-history database. *)
   LogSCP,
   MainUnit;

type
   (* ONE SYNTHETIC QSO. A full QSO carries every exchange field at once, so
     each contest finds something to read whatever its exchange is; a sparse
     one carries the RST alone, which is what a contest does with an exchange
     it did not get. *)
   TMatrixQSO = record
      Call: string;
      Band: BandType;
      Mode: ModeType;
      Ext: ExtendedModeType;
      FreqHz: longint;
      QTH: string;
      Zone: byte;
      Sparse: boolean;
   end;

const
   (* THE QSO MATRIX. Fixed, and its order is part of the record.

     Modes: CW, phone, FM and two digital kinds (RTTY and FT8, which export
     differently). Bands: 160, 80, 40, 30 (WARC), 20, 15, 10, 6 and 2. Calls:
     US, Canada, Mexico (North America but not W/VE), England and Germany
     (the DX station variant is DL, so DL1ABC is its own country), Japan,
     Brazil, Australia, South Africa and Hawaii -- every continent, and the
     domestic, same-country and DX cases for each station variant.

     CHANGING THIS LIST CHANGES EVERY FROZEN RECORD. That is a re-freeze with a
     reason, like any other. *)
   MATRIX_QSOS: array[1..17] of TMatrixQSO =
      (
      (Call: 'W1AW';   Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: 'CT'; Zone: 5;  Sparse: False),
      (Call: 'W1AW';   Band: Band20;  Mode: Phone;   Ext: eUSB;  FreqHz: 14250000;  QTH: 'CT'; Zone: 5;  Sparse: False),
      (Call: 'W1AW';   Band: Band2;   Mode: FM;      Ext: eFM;   FreqHz: 146520000; QTH: 'CT'; Zone: 5;  Sparse: False),
      (Call: 'W1AW';   Band: Band40;  Mode: Digital; Ext: eRTTY; FreqHz: 7080000;   QTH: 'CT'; Zone: 5;  Sparse: False),
      (Call: 'W1AW';   Band: Band20;  Mode: Digital; Ext: eFT8;  FreqHz: 14074000;  QTH: 'CT'; Zone: 5;  Sparse: False),
      (Call: 'K4ABC';  Band: Band160; Mode: CW;      Ext: eCW;   FreqHz: 1830000;   QTH: 'FL'; Zone: 5;  Sparse: False),
      (Call: 'VE3ABC'; Band: Band15;  Mode: Phone;   Ext: eUSB;  FreqHz: 21300000;  QTH: 'ON'; Zone: 4;  Sparse: False),
      (Call: 'XE1ABC'; Band: Band10;  Mode: CW;      Ext: eCW;   FreqHz: 28025000;  QTH: '';   Zone: 6;  Sparse: False),
      (Call: 'G3ABC';  Band: Band30;  Mode: CW;      Ext: eCW;   FreqHz: 10110000;  QTH: '';   Zone: 14; Sparse: False),
      (Call: 'DL1ABC'; Band: Band40;  Mode: Phone;   Ext: eLSB;  FreqHz: 7150000;   QTH: '';   Zone: 14; Sparse: False),
      (Call: 'JA1ABC'; Band: Band15;  Mode: CW;      Ext: eCW;   FreqHz: 21025000;  QTH: '';   Zone: 25; Sparse: False),
      (Call: 'PY2ABC'; Band: Band6;   Mode: Phone;   Ext: eUSB;  FreqHz: 50150000;  QTH: '';   Zone: 11; Sparse: False),
      (Call: 'VK2ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 30; Sparse: False),
      (Call: 'ZS6ABC'; Band: Band10;  Mode: Phone;   Ext: eUSB;  FreqHz: 28400000;  QTH: '';   Zone: 38; Sparse: False),
      (Call: 'KH6ABC'; Band: Band20;  Mode: Phone;   Ext: eUSB;  FreqHz: 14250000;  QTH: 'HI'; Zone: 31; Sparse: False),
      (Call: 'W1AW';   Band: Band80;  Mode: CW;      Ext: eCW;   FreqHz: 3530000;   QTH: '';   Zone: 0;  Sparse: True),
      (Call: 'G3ABC';  Band: Band20;  Mode: Phone;   Ext: eUSB;  FreqHz: 14250000;  QTH: '';   Zone: 0;  Sparse: True)
      );

   (* THE ONE SETTING WHOSE VALUE COMES FROM THE CLOCK. SetContestTitle builds
     it from GetYearString, so a record frozen in December would differ in
     January. Its inputs -- CONTEST NAME and MY CALL -- are both recorded. *)
   CLOCK_DERIVED_SETTING = 'CONTEST TITLE';

   (* Every record line ends this way, on every platform, so the frozen bytes
     do not depend on where they were written. *)
   MATRIX_LINE_BREAK = #13#10;

(* THE AnsiString CASTS AT EVERY TStringList AND RTL BOUNDARY ARE DELIBERATE.
  Classes and the SysUtils overloads used here take AnsiString while this
  tree's string is UnicodeString. Everything crossing is ASCII by
  construction -- enum names, the fixed QSO table, the fixture's values,
  paths under the build tree -- so each conversion is lossless, and saying
  so explicitly keeps it off the narrowing ratchet, which counts the
  conversions nobody thought about. *)
var
   GOut: TStringList;
   GLogDir: string;
   GDataDir: string;
   (* THE ADIF FILE CaptureExport WROTE, for the import capture to read back.
     '' when the export wrote none. *)
   GExportedAdif: string;


(* THE COMPILER'S OWN NAME FOR AN ENUMERATED VALUE.

  NOT THE PROGRAM'S SPELLING TABLES, and the reason is a measured defect:
  QSOPointMethodArray was out of step with QSOPointMethodType from position 38
  onward (it was deleted at M10 S2) (docs/CONTEST_OWNERSHIP_DESIGN.md section 7.2), so spelling a point
  method through it would print the WRONG NAME for 46 of them. RTTI cannot
  disagree with the enum, because it is the enum. *)
function EnumText(aInfo: PTypeInfo; aOrdinal: integer): string;
var
   data: PTypeData;
begin
   (* AN ORDINAL OUTSIDE ITS TYPE IS RECORDED AS ONE, not handed to
     GetEnumName -- which does not check, and walks on into whichever type's
     names follow in the RTTI. A value a cast has pushed out of range is a
     finding in itself, so it is said plainly. *)
   data := GetTypeData(aInfo);
   if (aOrdinal < data^.MinValue) or (aOrdinal > data^.MaxValue) then
      begin
      Result := Format('<out of range: %d>', [aOrdinal]);
      Exit;
      end;
   Result := GetEnumName(aInfo, aOrdinal);
end;

function BoolText(aValue: boolean): string;
begin
   if aValue then
      begin
      Result := 'TRUE';
      end
   else
      begin
      Result := 'FALSE';
      end;
end;

(* A VALUE WITH THE MACHINE TAKEN OUT OF IT. The scratch directory and the
  install's data directory are the only two paths a value can carry, and both
  differ between clones. *)
function Portable(const aValue: string): string;
begin
   Result := aValue;
   if GLogDir <> '' then
      begin
      Result := UnicodeStringReplace(Result, GLogDir, '<LOGDIR>' + PathDelim,
                                     [rfReplaceAll, rfIgnoreCase]);
      end;
   if GDataDir <> '' then
      begin
      Result := UnicodeStringReplace(Result, GDataDir, '<DATADIR>' + PathDelim,
                                     [rfReplaceAll, rfIgnoreCase]);
      end;
end;

(* A CONTROL CHARACTER IS WRITTEN AS <#hh>, so the record stays a text file
  that git can diff. Lossless and deliberate: ARRL Sweepstakes exports a NUL
  for a QSO with no precedence (Precedence is an AnsiChar, #0 when empty), and
  that byte is a defect the record must keep -- spelled, not raw. *)
function Visible(const aLine: string): string;
var
   i: integer;
begin
   Result := '';
   for i := 1 to Length(aLine) do
      begin
      if Ord(aLine[i]) < 32 then
         begin
         Result := Result + Format('<#%.2x>', [Ord(aLine[i])]);
         end
      else
         begin
         Result := Result + aLine[i];
         end;
      end;
end;

procedure Emit(const aLine: string);
begin
   GOut.Add(AnsiString(Visible(Portable(aLine))));
end;

procedure EmitField(const aName, aValue: string);
begin
   Emit(aName + ' = ' + aValue);
end;

procedure EmitRaised(const aWhere: string; E: Exception);
begin
   (* THE CLASS, NOT THE MESSAGE. An access violation's message carries an
     address, which moves between builds; the class does not. The message
     still reaches tr4w.log for whoever has to diagnose it. *)
   Emit('RAISED in ' + aWhere + ': ' + E.ClassName);
   (* WITH ITS BACKTRACE, into tr4w.log. A frozen RAISED line is a defect
     somebody will chase, and the record alone cannot say where it was.
     Called inside the except block, which is the only place the frames are
     still valid. *)
   LogCaughtException('[Matrix] ' + aWhere, E);
end;


function MatrixRecordName(const aId: string): string;
var
   i: integer;
begin
   Result := '';
   if aId = '' then
      begin
      Exit;
      end;
   for i := 1 to Length(aId) do
      begin
      if (Ord(aId[i]) < 32) or (Ord(aId[i]) > 126) or
         (Pos(aId[i], '\/:*?"<>|') > 0) then
         begin
         Result := '';
         Exit;
         end;
      if aId[i] = ' ' then
         begin
         Result := Result + '_';
         end
      else
         begin
         Result := Result + aId[i];
         end;
      end;
end;

(* A CONTEST AS A RECORD SPELLS IT INSIDE AN EXCHANGE: its enum member's name
  when it has a legacy number -- what every record has always printed -- and
  its id when it was registered by id and has no member to print. *)
function ContestText(aContest: TContestHandle): string;
var
   n: integer;
begin
   if ContestLegacyNumber(aContest, n) then
      begin
      Result := EnumText(TypeInfo(ContestType), n);
      end
   else if ContestId(aContest) <> '' then
      begin
      Result := ContestId(aContest);
      end
   else
      begin
      (* A byte that names no contest is said plainly, as it always was. *)
      Result := EnumText(TypeInfo(ContestType), aContest.ToByte);
      end;
end;

(* THE IDENTITY LINES' VALUE (Q108 S3): the id, then the legacy number in
  brackets, or that there is none. *)
function IdentityText(aContest: TContestHandle): string;
var
   n: integer;
begin
   if ContestLegacyNumber(aContest, n) then
      begin
      Result := ContestId(aContest) + ' (legacy number ' + IntToStr(n) + ')';
      end
   else
      begin
      Result := ContestId(aContest) + ' (no legacy number)';
      end;
end;


(* ------------------------------------------------------------------------ *)
(* /MATRIXLIST                                                              *)
(* ------------------------------------------------------------------------ *)

function RunContestMatrixList(const aOutFile: string): integer;
var
   list: TStringList;
   names: TStringList;
   known: TContestHandleList;
   k: integer;
   identity: TContestBase;
   hostState: string;
   partyFlag: string;
   recordName: string;
   classUnit: string;
begin
   if aOutFile = '' then
      begin
      EarlyTrace('[Matrix] usage: tr4w.exe /MATRIXLIST <out-file>');
      Result := 1;
      Exit;
      end;

   list := TStringList.Create;
   names := TStringList.Create;
   try
      list.LineBreak := MATRIX_LINE_BREAK;
      names.Sorted := True;
      names.CaseSensitive := False;

      (* EVERY KNOWN CONTEST BUT NoContest, IN HANDLE ORDER -- every legacy
        number from 1 up, the order the enum walk this replaced visited,
        then (Q108 S3) every contest registered by id. NoContest is
        DUMMYCONTEST, "no contest" -- FoundContest itself treats it as
        not-a-contest and it cannot be opened. *)
      known := KnownContests;
      for k := 0 to High(known) do
         begin
         if known[k] = NoContest then
            begin
            Continue;
            end;

         (* THE RECORD'S FILE NAME, AND IT MUST BE ONE. An id no file system
           can hold, or two ids that become the same file name (the
           case-insensitive file systems this runs on included), would make
           a record overwrite another or fail to be written -- refused
           here, whole, before anything is run. *)
         recordName := MatrixRecordName(ContestId(known[k]));
         if recordName = '' then
            begin
            EarlyTrace('[Matrix] the id ''' + ContestId(known[k]) +
                       ''' cannot be a record''s file name');
            Result := 1;
            Exit;
            end;
         if names.IndexOf(AnsiString(recordName)) >= 0 then
            begin
            EarlyTrace('[Matrix] two contests share the record name ''' +
                       recordName + '''');
            Result := 1;
            Exit;
            end;
         names.Add(AnsiString(recordName));

         (* EVERY FIELD IS ASKED OF THE CONTEST (M10 S6). The fourth field
           was the row's party index P and is now 1 or 0 -- whether the
           contest is a QSO party. matrix-lib.sh only ever tested it against
           "0", and IsUSQSOParty is P <> 0 for every contest
           (Test_MovedRowValuesStillMatchTheArray), so the variants run and
           the records they produce are unchanged. The sixth is the party's
           area, which is the QSOParties StateName this read. *)
         identity := ContestIdentity(known[k]);
         hostState := identity.QSOPartyArea;
         if identity.IsUSQSOParty then
            begin
            partyFlag := '1';
            end
         else
            begin
            partyFlag := '0';
            end;
         (* THE UNIT THAT REGISTERED IT: the class's unit, so the script can
           refuse an application whose registry holds a contest that does
           not live in src/contestFactory -- the unit tests' fixture above
           all. '' for a contest with no class. *)
         if ContestClassFor(known[k]) <> nil then
            begin
            classUnit := string(ContestClassFor(known[k]).UnitName);
            end
         else
            begin
            classUnit := '';
            end;

         (* '|', NOT A TAB. A shell reading with IFS=tab collapses two
           adjacent tabs into one, so an EMPTY field -- Colorado's DF -- moved
           every field after it one place left. '|' is not whitespace to the
           shell, and MatrixRecordName refuses an id holding one. *)
         list.Add(AnsiString(recordName + '|' +
                  ContestId(known[k]) + '|' +
                  classUnit + '|' +
                  partyFlag + '|' +
                  identity.DomesticFileName + '|' +
                  hostState));
         end;

      try
         list.SaveToFile(AnsiString(aOutFile));
         Result := 0;
      except
         on E: Exception do
            begin
            EarlyTrace('[Matrix] could not write ' + aOutFile + ': ' + E.Message);
            Result := 2;
            end;
      end;
   finally
      names.Free;
      list.Free;
   end;
end;


(* ------------------------------------------------------------------------ *)
(* /MATRIX -- identity and setup                                            *)
(* ------------------------------------------------------------------------ *)

procedure CaptureIdentity(const aRequested: string);
var
   klass: TContestBase;
   requested: TContestHandle;
   found: boolean;
begin
   Emit('== identity');
   (* THE REQUEST IS AN ID (Q108 S3), resolved as the registry resolves one
     -- exactly, case aside, never through an alias, so a legacy name cannot
     stand in for the contest it now means. *)
   found := FindContestById(aRequested, requested);
   if found then
      begin
      EmitField('contest.requested', IdentityText(requested));
      end
   else
      begin
      EmitField('contest.requested', aRequested + ' (no such contest)');
      end;

   (* SELECTED IS WHAT THE .cfg's CONTEST LINE ACTUALLY CHOSE. A spelling that
     two contests shared would select the first, so the second would be
     unreachable from a .cfg -- a difference between these two lines is that
     finding. *)
   EmitField('contest.selected', IdentityText(Contest));
   if (not found) or (Contest <> requested) then
      begin
      Emit('SELECTION MISMATCH: the .cfg spelling did not select the requested contest');
      end;

   klass := ActiveContest(Contest);
   if klass = nil then
      begin
      EmitField('contest.class', '(none -- the legacy engine)');
      end
   else
      begin
      EmitField('contest.class', klass.ClassName);
      end;
end;

procedure CaptureDomesticCountries;
var
   i: integer;
   line: string;
begin
   line := '';
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      line := line + ' ' + DomesticCountries.IDs[i];
      end;
   EmitField('domestic.countries', Trim(line));
end;

procedure CaptureCountyLine;
var
   klass: TContestBase;
begin
   (* WHAT EACH READER ASKS TODAY. The ADIF importer asks
     ContestAllowsCountyLineOnImport, and this line asks the SAME function, so
     it names what the importer does rather than where the answer lives --
     it was `countyline.row.allowed` until M10 S1 (2026-10-14), and S7 (the
     same day) repointed that function from the row to the class, moving this
     line for exactly the six contests the two disagreed on. ValidateQTHCount asks a
     state-party class for its maximum. *)
   EmitField('countyline.import.allowed', BoolText(ContestAllowsCountyLineOnImport(Contest)));
   klass := ActiveContest(Contest);
   if (klass <> nil) and (klass is TContestStateQSOPartyBase) then
      begin
      if TContestStateQSOPartyBase(klass).CountyLineCountiesMax = CountyLineCountiesUnlimited then
         begin
         EmitField('countyline.class.max', 'unlimited');
         end
      else
         begin
         EmitField('countyline.class.max',
                   IntToStr(TContestStateQSOPartyBase(klass).CountyLineCountiesMax));
         end;
      end
   else
      begin
      EmitField('countyline.class.max', '(no state-party class)');
      end;
end;

procedure CaptureMemories;
begin
   (* THE MEMORIES FoundContest's ARMS AND ITS EXCHANGE SET-UP WRITE -- CQ F1
     to F3 and the exchange F3 to F5, Alt-F3 and Alt-F4. All CW: no arm sets
     a phone memory. *)
   EmitField('memory.cw.cq.F1', string(GetCQMemoryString(CW, F1)));
   EmitField('memory.cw.cq.F2', string(GetCQMemoryString(CW, F2)));
   EmitField('memory.cw.cq.F3', string(GetCQMemoryString(CW, F3)));
   EmitField('memory.cw.ex.F3', string(GetEXMemoryString(CW, F3)));
   EmitField('memory.cw.ex.F4', string(GetEXMemoryString(CW, F4)));
   EmitField('memory.cw.ex.F5', string(GetEXMemoryString(CW, F5)));
   EmitField('memory.cw.ex.AltF3', string(GetEXMemoryString(CW, AltF3)));
   EmitField('memory.cw.ex.AltF4', string(GetEXMemoryString(CW, AltF4)));
end;

(* EVERY SETTING THE RUN CHANGED FROM ITS COMPILED DEFAULT.

  Compared against a settings object built fresh, rather than against a list
  of the settings FoundContest is known to write: a list would have to be kept
  in step with 104 arms, and the first arm nobody remembered would be a move
  this record could not see. What shows here is the matrix's own fixture, the
  station lines of the .cfg, and whatever contest set-up wrote -- the first
  two are the same for every contest of a variant, so a difference between two
  records of one variant is contest set-up. *)
procedure CaptureChangedSettings;
var
   fresh: TR4WSettings;
   names: TStringList;
   i: integer;
   live, compiledDefault: string;
begin
   fresh := TR4WSettings.Create;
   names := Settings.CommandNames;
   try
      for i := 0 to names.Count - 1 do
         begin
         if SameText(names[i], CLOCK_DERIVED_SETTING) then
            begin
            Continue;
            end;
         (* A STATION FACT IS RECORDED AS THIS CONTEST HAS IT -- design 7.12.
           The .cfg's MY STATE / MY GRID / ... lines are this contest's
           overrides now and never reach the station's property, so the
           property alone would no longer show them. The override, when one
           was stated, is the value that was in force -- exactly what this
           line recorded when the .cfg wrote the station's setting. *)
         if not Settings.TryGetContestOverride(names[i], live) then
            begin
            if not Settings.TryGetByCommand(names[i], live) then
               begin
               Continue;
               end;
            end;
         if not fresh.TryGetByCommand(names[i], compiledDefault) then
            begin
            compiledDefault := '';
            end;
         if live <> compiledDefault then
            begin
            EmitField('setting.' + names[i], live);
            end;
         end;
   finally
      names.Free;
      fresh.Free;
   end;
end;

procedure CaptureSetup;
begin
   Emit('== setup');
   (* NO active.qsopointmethod LINE since M10 S1 (2026-10-14): every contest
     the matrix runs is scored by its class, which never reads
     ActiveQSOPointMethod, and M10 S4 deleted the point method as a concept.
     Dropped in a re-freeze of its own, before anything moves. *)
   EmitField('active.exchange', EnumText(TypeInfo(ExchangeType), Ord(ContestSession.Exchange)));
   EmitField('active.initialexchange', EnumText(TypeInfo(InitialExchangeType), Ord(ContestSession.InitialExchange)));
   (* NO active.dxmult LINE since M11 S4 part 2 (2026-10-14): the DX kind is
     deleted. Whether the contest has a DX multiplier is still the second
     doing.* flag, now the contest's own answer (LOGEDIT.DoingDXMults). *)
   (* NO active.zonemult LINE since M11 S5 part 2 (2026-10-14): the zone
     kind is deleted. Whether the contest has a zone multiplier is still the
     fourth doing.* flag, now the contest's own answer (LOGEDIT.DoingZoneMults). *)
   (* NO active.prefixmult LINE since M11 S3 part 2 (2026-10-14): the prefix
     kind is deleted. Whether the contest has a prefix multiplier is still the
     third doing.* flag, now the contest's own answer (LOGEDIT.DoingPrefixMults). *)
   EmitField('doing.domestic/dx/prefix/zone',
             BoolText(DoingDomesticMults) + ' ' + BoolText(DoingDXMults) + ' ' +
             BoolText(DoingPrefixMults) + ' ' + BoolText(DoingZoneMults));
   EmitField('cty.countrymode', EnumText(TypeInfo(CountryModeType), Ord(CTY.ctyCountryMode)));
   EmitField('cty.zonemode', EnumText(TypeInfo(ZoneModeType), Ord(CTY.ctyZoneMode)));
   EmitField('my.continent', EnumText(TypeInfo(ContinentType), Ord(MyContinent)));
   EmitField('dxmultlimit', IntToStr(DXMultLimit));
   EmitField('dxccmultbyband', EnumText(TypeInfo(TAdditionalMultByBand), Ord(DXCCMultByBand)));
   EmitField('multipliersarecounties', BoolText(MultipliersIsCounties));
   EmitField('nomultmarinemobile', BoolText(NoMultMarineMobile));
   EmitField('literaldomesticqth', BoolText(LiteralDomesticQTH));
   EmitField('allowdupeqsos', BoolText(tAllowDupeQSOs));
   EmitField('activeband', EnumText(TypeInfo(BandType), Ord(ActiveBand)));
   EmitField('activemode', EnumText(TypeInfo(ModeType), Ord(ActiveMode)));
   CaptureDomesticCountries;
   CaptureCountyLine;
   CaptureMemories;
   CaptureChangedSettings;
end;


(* ------------------------------------------------------------------------ *)
(* /MATRIX -- scoring and export                                            *)
(* ------------------------------------------------------------------------ *)

(* A STORED QSO, AS THE LOG WOULD HOLD IT.

  THE DOMESTIC QTH IS FILLED ONLY WHEN THE CONTEST RESOLVES DOMESTIC QTHs --
  DoingDomesticMults, the engine's own flag. A contest that does not would
  never have stored one, and the four QSO POINTS overrides and several legacy
  arms test DomesticQTH for emptiness, so filling it everywhere would score
  QSOs no operator could have logged. QTHString, the literal received text,
  is always filled. That is the closest a pre-filled record comes to what
  ProcessExchange leaves; running ProcessExchange itself is the M5 capture. *)
procedure BuildQSO(aIndex: integer; const aSpec: TMatrixQSO; out aRX: ContestExchange);
begin
   FillChar(aRX, SizeOf(aRX), 0);
   aRX.ceRecordKind := rkQSO;
   aRX.ceContest := Contest;
   aRX.tSysTime.qtYear := 26;
   aRX.tSysTime.qtMonth := 1;
   aRX.tSysTime.qtDay := 15;
   aRX.tSysTime.qtHour := 12;
   aRX.tSysTime.qtMinute := aIndex;
   aRX.tSysTime.qtSecond := 0;
   aRX.Band := aSpec.Band;
   aRX.Mode := aSpec.Mode;
   aRX.ExtMode := aSpec.Ext;
   aRX.Frequency := aSpec.FreqHz;
   (* The casts are deliberate narrowings of ASCII literals from the table
     above, bounded by construction -- see CLAUDE.md on ShortString(). *)
   aRX.Callsign := ShortString(aSpec.Call);
   (* THE LOOKUP A LOGGED QSO GOT WHEN IT WAS ENTERED. Live entry
     (ParametersOkay) and ADIF import (ParseADIFRecord) both run exactly this,
     so a stored QSO always carries its country, zone and continent -- and
     the rescore only repeats the lookup for contests with prefix, zone or DX
     multipliers. A record without it is one the program never stores, and
     scoring it measured the harness: REF's arm reads QTH.CountryID[1]. *)
   ctyLocateCallStripRover(aRX.Callsign, aRX.QTH);
   (* A FIXED ID, so APP_TR4W_ID is the same on every run. Thirty-two hex
     digits, the shape the exporter writes. *)
   aRX.id := ShortString(Format('%.32d', [aIndex]));
   aRX.NumberSent := aIndex;

   if aSpec.Mode = Phone then
      begin
      aRX.RSTSent := 59;
      aRX.RSTReceived := 59;
      end
   else
      begin
      aRX.RSTSent := 599;
      aRX.RSTReceived := 599;
      end;

   if aSpec.Sparse then
      begin
      Exit;
      end;

   aRX.NumberReceived := 100 + aIndex;
   aRX.QTHString := ShortString(aSpec.QTH);
   if DoingDomesticMults then
      begin
      aRX.DomesticQTH := ShortString(aSpec.QTH);
      aRX.DomMultQTH := ShortString(aSpec.QTH);
      end;
   aRX.Zone := aSpec.Zone;
   aRX.Name := 'JOE';
   aRX.Power := '100';
   aRX.ceClass := '2A';
   aRX.Check := 99;
   aRX.Precedence := 'A';
   aRX.Age := 40;
   aRX.Chapter := '1';
end;

function ScoreLine(aIndex: integer; const aSpec: TMatrixQSO;
                   const aRX: ContestExchange): string;
var
   shape: string;
begin
   if aSpec.Sparse then
      begin
      shape := 'sparse';
      end
   else
      begin
      shape := 'full';
      end;

   (* EVERY FIELD THE RESCORE PATH CAN WRITE, not only the points: thirteen
     legacy arms write InhibitMults, DomMultQTH, DomesticMult, ZoneMult, Prefix
     or DXQTH, and a class replacing one must write the same fields. *)
   Result := Format('qso %.2d %s %s %s/%s %s | pts=%d inhibit=%s ' +
                    'mult.dom/dx/pfx/zone=%s/%s/%s/%s cty=%s qthzone=%d cont=%s ' +
                    'qthpfx=%s pfx=%s dxqth=%s dommultqth=%s domqth=%s zone=%d',
                    [aIndex, string(aRX.Callsign),
                     EnumText(TypeInfo(BandType), Ord(aRX.Band)),
                     EnumText(TypeInfo(ModeType), Ord(aRX.Mode)),
                     EnumText(TypeInfo(ExtendedModeType), Ord(aRX.ExtMode)),
                     shape,
                     aRX.QSOPoints, BoolText(aRX.InhibitMults),
                     BoolText(aRX.DomesticMult), BoolText(aRX.DXMult),
                     BoolText(aRX.PrefixMult), BoolText(aRX.ZoneMult),
                     string(aRX.QTH.CountryID), aRX.QTH.Zone,
                     EnumText(TypeInfo(ContinentType), Ord(aRX.QTH.Continent)),
                     string(aRX.QTH.Prefix), string(aRX.Prefix),
                     string(aRX.DXQTH), string(aRX.DomMultQTH),
                     string(aRX.DomesticQTH), aRX.Zone]);
end;

const
   (* THE BANDS A KEY OR HOST-AREA QSO MOVES TO, in order (Q98 stage S0,
     docs/CONTEST_OWNERSHIP_DESIGN.md 8.2v). *)
   MATRIX_CREDITED_BAND_PREFERENCE: array[1..8] of BandType =
      (Band20, Band40, Band15, Band10, Band80, Band160, Band6, Band2);

type
   (* ONE MODE A MOVED QSO MAY TAKE -- the mode and the submode it is logged
     with, the spellings the base QSOs use. *)
   TMatrixModeChoice = record
      Mode: ModeType;
      Ext: ExtendedModeType;
   end;

const
   (* THE MODES A KEY OR HOST-AREA QSO MOVES TO, in order (Q98 stage S1, the
     mode half of S0's band preference). *)
   MATRIX_CREDITED_MODE_PREFERENCE: array[1..5] of TMatrixModeChoice =
      (
      (Mode: CW;      Ext: eCW),
      (Mode: Phone;   Ext: eUSB),
      (Mode: FM;      Ext: eFM),
      (Mode: Digital; Ext: eRTTY),
      (Mode: Digital; Ext: eFT8)
      );

(* THE FIXED FREQUENCY OF A MOVED QSO: the CW or the phone end of aBand, the
  values the base QSOs use where one of them is on that band. Phone and FM
  take the phone end; every other mode the CW end -- only CW and phone QSOs
  are moved today (see CreditedMatrixQSO). *)
function PickHz(aPhone: boolean; aPhoneHz, aCWHz: longint): longint;
begin
   if aPhone then
      begin
      Result := aPhoneHz;
      end
   else
      begin
      Result := aCWHz;
      end;
end;

function MatrixBandFrequencyHz(aBand: BandType; aMode: ModeType): longint;
var
   isPhone: boolean;
begin
   isPhone := aMode in [Phone, FM];
   case aBand of
      Band160:
         begin
         Result := PickHz(isPhone, 1850000, 1830000);
         end;
      Band80:
         begin
         Result := PickHz(isPhone, 3800000, 3530000);
         end;
      Band40:
         begin
         Result := PickHz(isPhone, 7150000, 7025000);
         end;
      Band20:
         begin
         Result := PickHz(isPhone, 14250000, 14025000);
         end;
      Band15:
         begin
         Result := PickHz(isPhone, 21300000, 21025000);
         end;
      Band10:
         begin
         Result := PickHz(isPhone, 28400000, 28025000);
         end;
      Band6:
         begin
         Result := PickHz(isPhone, 50150000, 50090000);
         end;
      Band2:
         begin
         Result := PickHz(isPhone, 146520000, 144050000);
         end;
   else
      begin
      Result := 0;
      end;
   end;
end;

(* aSpec ON A BAND THE CONTEST CREDITS (Q98 stage S0, 8.2v).

  THE keys SECTION (18-36) AND THE HOST-AREA QSO (37) EXIST TO REACH KEY
  DERIVATION AND THE HOST-AREA RULE, NOT TO TEST THE BAND RULE -- the 17
  base QSOs are that test, and they never move. An off-band QSO stops at
  ScoreQSO's and SetMultFlags' band exits before any key is derived, so a
  key QSO the contest does not credit pins nothing: the four 160 m
  contests' keys sections had exercised no multiplier key at all. And every
  contest that states its bands later would have lost its keys the same
  way, in silence.

  So: aSpec as it is when the contest credits its band (every record that
  credits 20/40/15 m keeps its bytes), else aSpec moved to the first
  credited band of MATRIX_CREDITED_BAND_PREFERENCE at that band's fixed
  frequency; unchanged when the contest credits none of them. Asked of the
  contest the scoring path asks (ActiveContest), through the same
  ContestCreditsBand.

  THE MODE HALF (Q98 S1): aSpec in a mode the contest does not credit
  (ContestCreditsMode) moves to the first credited mode of
  MATRIX_CREDITED_MODE_PREFERENCE, the same way, and its frequency follows.
  The mode is decided first, so a QSO moved in both takes the frequency of
  its new mode on its new band. *)
function CreditedMatrixQSO(aContest: TContestBase; const aSpec: TMatrixQSO): TMatrixQSO;
var
   i: integer;
   moved: boolean;
begin
   Result := aSpec;
   moved := False;

   if not ContestCreditsMode(aContest, Result.Mode, Result.Ext) then
      begin
      for i := Low(MATRIX_CREDITED_MODE_PREFERENCE) to High(MATRIX_CREDITED_MODE_PREFERENCE) do
         begin
         if ContestCreditsMode(aContest, MATRIX_CREDITED_MODE_PREFERENCE[i].Mode,
                                         MATRIX_CREDITED_MODE_PREFERENCE[i].Ext) then
            begin
            Result.Mode := MATRIX_CREDITED_MODE_PREFERENCE[i].Mode;
            Result.Ext := MATRIX_CREDITED_MODE_PREFERENCE[i].Ext;
            moved := True;
            Break;
            end;
         end;
      end;

   if not ContestCreditsBand(aContest, Result.Band) then
      begin
      for i := Low(MATRIX_CREDITED_BAND_PREFERENCE) to High(MATRIX_CREDITED_BAND_PREFERENCE) do
         begin
         if ContestCreditsBand(aContest, MATRIX_CREDITED_BAND_PREFERENCE[i]) then
            begin
            Result.Band := MATRIX_CREDITED_BAND_PREFERENCE[i];
            moved := True;
            Break;
            end;
         end;
      end;

   if moved then
      begin
      Result.FreqHz := MatrixBandFrequencyHz(Result.Band, Result.Mode);
      end;
end;

procedure SessionDomesticFileKeys(out aFirst, aSecond: string); forward;

const
   (* THE HOST-AREA QSO (Q107, 2026-10-16) -- a station INSIDE the contest's
     host area, for an entrant OUTSIDE it.

     Since Q107 an out-of-area entrant of a QSO party credits only a worked
     station whose QTH the session's domestic table knows, and not one of the
     17 above sends such a QTH -- so every out-of-area record scored 0 and
     out-of-area scoring was seen by the unit tests alone. This QSO gives it
     a QTH the table knows: one of the first two keys of the file that table
     was loaded from (SessionDomesticFileKeys), read by the same line reader
     parse.keys uses.

     LOGGED ONLY WHERE THE RULE APPLIES, and asked of the contest, never
     listed: HostAreaQSO adds it when the active contest refuses to credit a
     worked station that sent NO QTH (ContestCreditsWorkedStation) -- which is
     exactly an entrant outside a host area. A contest with no host area, and
     an entrant inside one, credit that station, log nothing more and keep
     every byte of their records.

     NUMBERED AFTER THE keys SECTION'S QSOs (18 to 36), so no two lines of a
     record share a number, and timed after every logged QSO. The call is not
     in either QSO table, so it is no dupe of one. CHANGING THIS QSO CHANGES
     EVERY RECORD THAT LOGS IT. *)
   HOST_QSO_INDEX = 37;
   HOST_QSO: TMatrixQSO =
      (Call: 'K9HQP'; Band: Band20; Mode: CW; Ext: eCW; FreqHz: 14025000; QTH: ''; Zone: 4; Sparse: False);

type
   THostQSOAnswer = (hqaNoHostArea, hqaFound, hqaNoKeyCredited);

(* THE HOST-AREA QSO FOR THIS CONTEST AND STATION, if it has one -- see
  HOST_QSO. aSpec is HOST_QSO carrying the first key of the domestic file
  that the contest credits; the record it builds is what is asked, so the
  answer is the scoring path's own. *)
function HostAreaQSO(out aSpec: TMatrixQSO): THostQSOAnswer;
var
   rx: ContestExchange;
   keys: array[1..2] of string;
   i: integer;
begin
   (* ON A BAND THE CONTEST CREDITS (Q98 S0) -- see CreditedMatrixQSO. *)
   aSpec := CreditedMatrixQSO(ActiveContest(Contest), HOST_QSO);
   BuildQSO(HOST_QSO_INDEX, aSpec, rx);
   if ContestCreditsWorkedStation(ActiveContest(Contest), rx) then
      begin
      Result := hqaNoHostArea;
      Exit;
      end;

   Result := hqaNoKeyCredited;
   SessionDomesticFileKeys(keys[1], keys[2]);
   for i := Low(keys) to High(keys) do
      begin
      if keys[i] = '' then
         begin
         Continue;
         end;
      aSpec.QTH := keys[i];
      BuildQSO(HOST_QSO_INDEX, aSpec, rx);
      if ContestCreditsWorkedStation(ActiveContest(Contest), rx) then
         begin
         Result := hqaFound;
         Exit;
         end;
      end;
end;

(* SCORE ONE QSO, THEN PUT IT IN THE LOG FOR THE EXPORTERS. *)
procedure ScoreAndLogOne(aIndex: integer; const aSpec: TMatrixQSO);
var
   rx: ContestExchange;
begin
   try
      BuildQSO(aIndex, aSpec, rx);
      RecomputeQSOScoring(rx);
      Emit(ScoreLine(aIndex, aSpec, rx));
      if not LogStoreAppendQSO(rx) then
         begin
         Emit(Format('qso %.2d NOT APPENDED to the log -- the export below lacks it', [aIndex]));
         end;
   except
      on E: Exception do
         begin
         EmitRaised(Format('qso %.2d', [aIndex]), E);
         end;
   end;
end;

(* SCORE EACH QSO, THEN PUT IT IN THE LOG FOR THE EXPORTERS.

  EACH QSO IS SCORED AGAINST AN EMPTY SHEET -- nothing is added to the dupe or
  multiplier sheets -- so every QSO is scored as the first of its kind and no
  record depends on the ones before it. The mult flags therefore read "would
  be a new multiplier". The host-area QSO, where there is one, comes last. *)
procedure CaptureScoringAndLog;
var
   i: integer;
   hostSpec: TMatrixQSO;
begin
   Emit('== scoring');
   for i := Low(MATRIX_QSOS) to High(MATRIX_QSOS) do
      begin
      ScoreAndLogOne(i, MATRIX_QSOS[i]);
      end;

   try
      case HostAreaQSO(hostSpec) of
         hqaFound:
            begin
            ScoreAndLogOne(HOST_QSO_INDEX, hostSpec);
            end;
         hqaNoKeyCredited:
            begin
            Emit(Format('qso %.2d NOT LOGGED -- the entrant is outside a host ' +
                        'area and the domestic table credits neither of its ' +
                        'file''s first two keys', [HOST_QSO_INDEX]));
            end;
         hqaNoHostArea:
            begin
            (* Nothing: the record is what it was before Q107's QSO. *)
            end;
      end;
   except
      on E: Exception do
         begin
         EmitRaised(Format('qso %.2d', [HOST_QSO_INDEX]), E);
         end;
   end;
end;

(* THE LINES OF AN EXPORTED FILE THAT THIS RECORD KEEPS. *)
procedure EmitExportedLines(const aTitle, aFile: string; aAdif: boolean);
var
   lines: TStringList;
   i: integer;
   pastHeader: boolean;
   s: string;
begin
   Emit('== ' + aTitle);
   if not FileExists(aFile) then
      begin
      Emit('(no file written)');
      Exit;
      end;

   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(aFile));
      pastHeader := False;
      for i := 0 to lines.Count - 1 do
         begin
         (* VERBATIM, trailing blanks included: a Cabrillo column that changes
           width at the end of a line is still a change. *)
         s := lines[i];
         if aAdif then
            begin
            (* EVERYTHING AFTER <EOH>. The header carries the build version and
              the time of the export. *)
            if pastHeader then
               begin
               if Trim(s) <> '' then
                  begin
                  Emit(s);
                  end;
               end
            else
               begin
               pastHeader := Pos('<EOH>', UpperCase(s)) > 0;
               end;
            end
         else
            begin
            (* THE CONTEST'S IDENTITY AND THE QSO LINES. Every other header line
              is the operator's category, the build or the totals. *)
            if (Pos('CONTEST:', s) = 1) or (Pos('QSO:', s) = 1) or
               (Pos('X-QSO:', s) = 1) then
               begin
               Emit(s);
               end;
            end;
         end;
   finally
      lines.Free;
   end;
end;

procedure CaptureExport;
var
   adifFile: string;
   cabrilloFile: string;
begin
   adifFile := '';
   cabrilloFile := '';

   try
      ExportToADIF;
      adifFile := CharBufferText(tReportsFilename);
   except
      on E: Exception do
         begin
         Emit('== export.adif');
         EmitRaised('ExportToADIF', E);
         end;
   end;
   if adifFile <> '' then
      begin
      EmitExportedLines('export.adif', adifFile, True);
      end;
   GExportedAdif := adifFile;

   try
      CreateCabrilloFile;
      cabrilloFile := CharBufferText(tReportsFilename);
   except
      on E: Exception do
         begin
         Emit('== export.cabrillo');
         EmitRaised('CreateCabrilloFile', E);
         end;
   end;
   if cabrilloFile <> '' then
      begin
      EmitExportedLines('export.cabrillo', cabrilloFile, False);
      end;
end;

(* ------------------------------------------------------------------------ *)
(* /MATRIX -- import (M5a)                                                  *)
(* ------------------------------------------------------------------------ *)

(* EVERY FIELD THE IMPORT PATH CAN SET, as name=value parts. Two exchanges are
  described by the same routine, so the parts line up by position and a field
  the import set is the part that differs from a CLEARED exchange -- which is
  how a record stays short without this file listing what each contest
  writes. *)
procedure DescribeExchange(const aRX: ContestExchange; aParts: TStringList);

   procedure Part(const aName, aValue: string);
   begin
      aParts.Add(AnsiString(aName + '=' + aValue));
   end;

   (* A NUL IS "NOT SET", and a one-character field is written as the character. *)
   function CharText(aChar: AnsiChar): string;
   begin
      if Ord(aChar) = 0 then
         begin
         Result := '';
         end
      else
         begin
         Result := string(aChar);
         end;
   end;

begin
   Part('contest', ContestText(aRX.ceContest));
   Part('call', string(aRX.Callsign));
   Part('band', EnumText(TypeInfo(BandType), Ord(aRX.Band)));
   Part('mode', EnumText(TypeInfo(ModeType), Ord(aRX.Mode)) + '/' +
                EnumText(TypeInfo(ExtendedModeType), Ord(aRX.ExtMode)));
   Part('freq', IntToStr(aRX.Frequency));
   Part('time', Format('%.2d%.2d%.2d %.2d%.2d%.2d',
                       [aRX.tSysTime.qtYear, aRX.tSysTime.qtMonth, aRX.tSysTime.qtDay,
                        aRX.tSysTime.qtHour, aRX.tSysTime.qtMinute, aRX.tSysTime.qtSecond]));
   Part('rst.sent', IntToStr(aRX.RSTSent));
   Part('rst.rcvd', IntToStr(aRX.RSTReceived));
   Part('nr.sent', IntToStr(aRX.NumberSent));
   Part('nr.rcvd', IntToStr(aRX.NumberReceived));
   Part('tenten', IntToStr(aRX.TenTenNum));
   Part('zone', IntToStr(aRX.Zone));
   Part('qth', string(aRX.QTHString));
   Part('domqth', string(aRX.DomesticQTH));
   Part('dommultqth', string(aRX.DomMultQTH));
   Part('exch', string(aRX.ExchString));
   Part('class', string(aRX.ceClass));
   Part('check', IntToStr(aRX.Check));
   Part('prec', CharText(aRX.Precedence));
   Part('name', string(aRX.Name));
   Part('power', string(aRX.Power));
   Part('age', IntToStr(aRX.Age));
   Part('chapter', string(aRX.Chapter));
   Part('operator', CharBufferText(aRX.ceOperator));
   Part('id', string(aRX.id));
   Part('xqso', BoolText(aRX.ceXQSO));
   Part('cty', string(aRX.QTH.CountryID) + '/' + IntToStr(aRX.QTH.Zone) + '/' +
               EnumText(TypeInfo(ContinentType), Ord(aRX.QTH.Continent)) + '/' +
               string(aRX.QTH.Prefix));
   Part('prefix', string(aRX.Prefix));
   Part('dxqth', string(aRX.DXQTH));
end;

(* ONE RECORD THROUGH THE PATH ImportFromADIF TAKES: a cleared exchange (which
  carries the SESSION's contest), then MainUnit.ParseADIFRecord. The result is
  every field that moved off a cleared exchange. *)
procedure ImportOne(const aLabel, aAdif: string);
var
   rx: ContestExchange;
   blank: ContestExchange;
   parts: TStringList;
   blankParts: TStringList;
   ok: boolean;
   i: integer;
   line: string;
begin
   parts := TStringList.Create;
   blankParts := TStringList.Create;
   try
      try
         ClearContestExchange(blank);
         DescribeExchange(blank, blankParts);
         ClearContestExchange(rx);
         ok := ParseADIFRecord(aAdif, rx);
         DescribeExchange(rx, parts);
         line := '';
         for i := 0 to parts.Count - 1 do
            begin
            if parts[i] <> blankParts[i] then
               begin
               line := line + ' ' + string(parts[i]);
               end;
            end;
         Emit('imp ' + aLabel + ' | parsed=' + BoolText(ok) + line);
      except
         on E: Exception do
            begin
            EmitRaised('import ' + aLabel, E);
            end;
      end;
   finally
      parts.Free;
      blankParts.Free;
   end;
end;

(* ONE ADIF FIELD, as another logger writes it: <NAME:length>value *)
function AdifTag(const aName, aValue: string): string;
begin
   Result := '<' + aName + ':' + IntToStr(Length(aValue)) + '>' + aValue + ' ';
end;

(* THE FRONT OF EVERY SYNTHETIC RECORD: who, when, where and the reports. *)
function AdifHead(const aCall, aBand, aMode, aRST: string): string;
begin
   Result := AdifTag('CALL', aCall) + AdifTag('QSO_DATE', '20260115') +
             AdifTag('TIME_ON', '121800') + AdifTag('BAND', aBand) +
             AdifTag('MODE', aMode) + AdifTag('RST_SENT', aRST) +
             AdifTag('RST_RCVD', aRST);
end;

(* THE RECORDS THE EXPORT JUST WROTE, read back. This is the round trip the
  corpus's test-adif-roundtrip.sh makes for thirteen contests, here for every
  one and every station variant. *)
procedure ImportExportedRecords;
var
   lines: TStringList;
   i, n: integer;
   pastHeader: boolean;
begin
   if (GExportedAdif = '') or (not FileExists(GExportedAdif)) then
      begin
      Emit('(no exported ADIF to read back)');
      Exit;
      end;

   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(GExportedAdif));
      pastHeader := False;
      n := 0;
      for i := 0 to lines.Count - 1 do
         begin
         if not pastHeader then
            begin
            pastHeader := Pos('<EOH>', UpperCase(lines[i])) > 0;
            Continue;
            end;
         if Trim(lines[i]) = '' then
            begin
            Continue;
            end;
         inc(n);
         ImportOne(Format('export.%.2d', [n]), string(lines[i]));
         end;
   finally
      lines.Free;
   end;
end;

(* SYNTHETIC FOREIGN-LOGGER RECORDS -- what an operator imports from N1MM,
  DXLog or a D7 TR4W, which this program did not write and whose shape its
  exporter does not dictate. One record per contest-dependent tag family, so
  a contest that reads a tag finds it.

  EVERY CASE CARRIES THE SESSION CONTEST'S OWN CONTEST_ID, except where its
  name says otherwise: the contest that interprets a record is the one its
  CONTEST_ID names, and the matrix runs one contest per process, so that is
  how each contest is asked about each tag.

  THE N1MM CASES ARE THE ORDER TEST. APP_N1MM_EXCHANGE1 means a class for the
  Field Days and a power for the FOC Marathon, and ADIF fixes no field order.
  Each pair puts the tag BEFORE and AFTER CONTEST_ID, and the .fd and .foc
  pairs name a contest that is not the session's: a record is only misread
  when the contest in force at the tag is not the contest the record names.
  The ids are literals -- foreign data, not this unit naming a contest. *)
procedure ImportSyntheticRecords;
var
   ownId: string;
   own: string;
   cw: string;
   phone: string;

   procedure Run(const aLabel, aBody: string);
   begin
      ImportOne(aLabel, aBody + '<EOR>');
   end;

begin
   ownId := ContestIdentity(Contest).ADIFContestId;
   own := AdifTag('CONTEST_ID', ownId);
   cw := AdifHead('W1AW', '20m', 'CW', '599');
   phone := AdifHead('W1AW', '20m', 'SSB', '59') + AdifTag('SUBMODE', 'USB') +
            AdifTag('FREQ', '14.250');

   Run('srx.rst+alpha', cw + own + AdifTag('SRX_STRING', '599 CT') + AdifTag('STATE', 'CT'));
   Run('srx.alpha', cw + own + AdifTag('SRX_STRING', 'CT') + AdifTag('STATE', 'CT'));
   Run('srx.rst+number', cw + own + AdifTag('SRX_STRING', '599 8'));
   Run('srx.number.phone', phone + own + AdifTag('SRX_STRING', '59 123') + AdifTag('SRX', '123'));
   Run('srx.none', cw + own + AdifTag('QTH', 'CT'));
   Run('section.arrl_sect', cw + own + AdifTag('ARRL_SECT', 'CT') + AdifTag('CLASS', '2A') +
                            AdifTag('SRX_STRING', '2A CT') + AdifTag('QTH', 'CT'));
   Run('section.qth-only', cw + own + AdifTag('CLASS', '1H') + AdifTag('SRX_STRING', '1H EWA') +
                           AdifTag('QTH', 'EWA'));
   Run('section.dx', AdifHead('DL1ABC', '40m', 'CW', '599') + own + AdifTag('CLASS', '1D') +
                     AdifTag('SRX_STRING', '1D DX') + AdifTag('QTH', 'DX'));
   Run('province', AdifHead('VE3ABC', '15m', 'SSB', '59') + own + AdifTag('VE_PROV', 'ON') +
                   AdifTag('SRX_STRING', '59 ON'));
   Run('county', cw + own + AdifTag('QTH', 'MON') + AdifTag('CNTY', 'MON') +
                 AdifTag('STATE', 'PA') + AdifTag('SRX_STRING', '59 MON'));
   Run('grid.srx', cw + own + AdifTag('GRIDSQUARE', 'FN31') + AdifTag('SRX_STRING', '599 FN31'));
   Run('grid.only', AdifHead('DL1ABC', '20m', 'FT8', '-05') + own + AdifTag('GRIDSQUARE', 'JO62'));
   Run('pota.ref', cw + own + AdifTag('SIG', 'POTA') + AdifTag('SIG_INFO', 'K-0001') +
                   AdifTag('POTA_REF', 'K-0001') + AdifTag('STATE', 'PA'));
   Run('pota.sig', cw + own + AdifTag('SIG', 'POTA') + AdifTag('SIG_INFO', 'K-0002'));
   Run('pota.state', cw + own + AdifTag('STATE', 'PA'));

   Run('n1mm.own.before', cw + AdifTag('APP_N1MM_EXCHANGE1', '3A') + own);
   Run('n1mm.own.after', cw + own + AdifTag('APP_N1MM_EXCHANGE1', '3A'));
   Run('n1mm.fd.before', cw + AdifTag('APP_N1MM_EXCHANGE1', '3A') +
                         AdifTag('CONTEST_ID', 'ARRL-FIELD-DAY'));
   Run('n1mm.fd.after', cw + AdifTag('CONTEST_ID', 'ARRL-FIELD-DAY') +
                        AdifTag('APP_N1MM_EXCHANGE1', '3A'));
   Run('n1mm.foc.before', cw + AdifTag('APP_N1MM_EXCHANGE1', '100') +
                          AdifTag('CONTEST_ID', 'FOC MARATHON'));
   Run('n1mm.foc.after', cw + AdifTag('CONTEST_ID', 'FOC MARATHON') +
                         AdifTag('APP_N1MM_EXCHANGE1', '100'));
   Run('n1mm.no-contest-id', cw + AdifTag('APP_N1MM_EXCHANGE1', '3A'));

   Run('foc', cw + own + AdifTag('FOC_NUM', '1234') + AdifTag('RX_PWR', '100') +
              AdifTag('SRX_STRING', '599 1234'));
   Run('zone.cqz', cw + own + AdifTag('CQZ', '5') + AdifTag('SRX_STRING', '599 5'));
   Run('zone.cqz+ituz', cw + own + AdifTag('CQZ', '5') + AdifTag('ITUZ', '28') +
                        AdifTag('SRX_STRING', '599 28'));
   Run('society', cw + own + AdifTag('APP_TR4W_HQ', 'DARC') + AdifTag('DOK', 'A01') +
                  AdifTag('IOTA', 'EU-005') + AdifTag('SRX_STRING', '59 DARC'));
   Run('n1mm.hq', cw + own + AdifTag('APP_N1MM_HQ', 'RSGB') + AdifTag('SRX_STRING', '59 RSGB'));
   Run('fields', cw + own + AdifTag('SRX', '45') + AdifTag('STX', '12') + AdifTag('CHECK', '99') +
                 AdifTag('PRECEDENCE', 'A') + AdifTag('NAME', 'JOE') +
                 AdifTag('TEN_TEN', '1234') + AdifTag('QTH', 'XYZ') +
                 AdifTag('RX_PWR', '100') + AdifTag('SRX_STRING', '45 XYZ'));
   Run('name+age', cw + own + AdifTag('NAME', 'JOE') + AdifTag('QTH', '45') +
                   AdifTag('SRX_STRING', 'JOE 45'));
   Run('name+state', cw + own + AdifTag('NAME', 'JOE') + AdifTag('STATE', 'PA') +
                     AdifTag('SRX_STRING', 'JOE PA'));
   Run('rtty.us', AdifHead('K4ABC', '40m', 'RTTY', '599') + own + AdifTag('STATE', 'FL') +
                  AdifTag('SRX_STRING', '599 FL'));
   Run('rtty.dx', AdifHead('DL1ABC', '40m', 'RTTY', '599') + own + AdifTag('SRX', '45') +
                  AdifTag('SRX_STRING', '599 45'));
   Run('no-contest-id', cw + AdifTag('SRX_STRING', '599 CT') + AdifTag('STATE', 'CT'));
   Run('operator', cw + own + AdifTag('OPERATOR', 'K0XYZ') + AdifTag('SRX_STRING', '599 CT'));
   Run('xqso+id', cw + own + AdifTag('APP_TR4W_CLAIMEDQSO', '0') +
                  AdifTag('APP_TR4W_ID', '0123456789ABCDEF0123456789ABCDEF'));
   Run('wsjtx', AdifHead('DL1ABC', '20m', 'FT8', '-05') + AdifTag('PROGRAMID', 'WSJT-X') +
                own + AdifTag('RST_SENT', '+05') + AdifTag('GRIDSQUARE', 'JO62'));
   Run('rover', cw + own + AdifTag('APP_TR4W_ROVERCALL', 'KG1S/MON') +
                AdifTag('QTH', 'MON') + AdifTag('SRX_STRING', '59 MON'));
end;

procedure CaptureImport;
begin
   Emit('== import');
   ImportExportedRecords;
   ImportSyntheticRecords;
end;

(* ------------------------------------------------------------------------ *)
(* /MATRIX -- parse (M5b)                                                   *)
(* ------------------------------------------------------------------------ *)

type
   (* ONE TYPED EXCHANGE, as the operator enters it: the call in the call
     window, the text in the exchange window, the band and mode in force. *)
   TMatrixParseCase = record
      Name: string;
      Call: string;
      Band: BandType;
      Mode: ModeType;
      FreqHz: longint;
      Exch: string;
   end;

const
   (* THE TYPED EXCHANGES. Fixed, and their order is part of the record.

     ONE LIST FOR EVERY CONTEST, so nothing here names a contest. It holds
     every exchange SHAPE the program parses -- serials, states, zones,
     names, powers, ages, grids, continents, societies, classes and sections,
     Sweepstakes' four fields, counties, prefectures, oblasts, departments,
     postcodes and parks -- each well-formed, and then the malformed and edge
     cases: missing fields, extra fields, the wrong order, a section or a
     county that does not exist, DX, a serial with letters, Sweepstakes with
     no precedence, and an out-of-state station's own state sent to a QSO
     party. A contest refuses most of them; WHICH it refuses, and with what
     message, is what this section records.

     <K1> AND <K2> ARE THE FIRST TWO KEYS OF THE CONTEST'S OWN DOMESTIC FILE
     -- for a QSO party, two of its counties -- so a county exchange is one
     the contest could accept; a contest with no file gets CT and MA.

     CHANGING THIS LIST CHANGES EVERY parse SECTION. A re-freeze with a
     reason, like any other. *)
   MATRIX_PARSE_CASES: array[1..66] of TMatrixParseCase =
      (
      (Name: 'empty';             Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: ''),
      (Name: 'rst';               Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599'),
      (Name: 'serial';            Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123'),
      (Name: 'rst.serial';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123'),
      (Name: 'cut.serial';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '5NN TT7'),
      (Name: 'serial.letters';    Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 12A'),
      (Name: 'state';             Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'CT'),
      (Name: 'rst.state';         Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 CT'),
      (Name: 'serial.state';      Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 CT'),
      (Name: 'rst.serial.state';  Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123 CT'),
      (Name: 'state.serial';      Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'CT 123'),
      (Name: 'phone.rs.state';    Call: 'W1AW';   Band: Band20; Mode: Phone; FreqHz: 14250000; Exch: '59 CT'),
      (Name: 'extra.fields';      Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123 CT XYZ 45'),
      (Name: 'call.in.exchange';  Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 CT K1ABC'),
      (Name: 'zone';              Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '5'),
      (Name: 'rst.zone';          Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 5'),
      (Name: 'zone.state';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 5 CT'),
      (Name: 'society';           Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'ARRL'),
      (Name: 'rst.society';       Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 ARRL'),
      (Name: 'name.state';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'JOE CT'),
      (Name: 'serial.name.state'; Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 JOE CT'),
      (Name: 'name.serial';       Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'JOE 123'),
      (Name: 'name.state.tenten'; Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'JOE CT 1234'),
      (Name: 'name.age.state';    Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'JOE 10 CT'),
      (Name: 'power.letters';     Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 KW'),
      (Name: 'power.number';      Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 100'),
      (Name: 'age';               Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 45'),
      (Name: 'grid';              Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'FN31'),
      (Name: 'rst.grid';          Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 FN31'),
      (Name: 'serial.grid';       Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123 FN31'),
      (Name: 'continent';         Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 NA'),
      (Name: 'fd.class.section';  Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '2A CT'),
      (Name: 'fd.section.class';  Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'CT 2A'),
      (Name: 'fd.bad.class';      Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '2Z CT'),
      (Name: 'fd.bad.section';    Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '2A XYZ'),
      (Name: 'fd.class.only';     Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '2A'),
      (Name: 'fd.dx';             Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '1D DX'),
      (Name: 'fd.dx.class.only';  Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '1D'),
      (Name: 'fd.dx.mx';          Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '1D MX'),
      (Name: 'ss.full';           Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 A 99 CT'),
      (Name: 'ss.packed';         Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123A 99CT'),
      (Name: 'ss.no.precedence';  Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 99 CT'),
      (Name: 'ss.wrong.order';    Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: 'CT 99 A 123'),
      (Name: 'ss.no.check';       Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 A CT'),
      (Name: 'ss.bad.section';    Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 A 99 XYZ'),
      (Name: 'county';            Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '<K1>'),
      (Name: 'rst.county';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 <K1>'),
      (Name: 'serial.county';     Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123 <K1>'),
      (Name: 'county.line';       Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 <K1>/<K2>'),
      (Name: 'county.bad';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 ZZZ'),
      (Name: 'oos.state';         Call: 'K4ABC';  Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '599 GA'),
      (Name: 'oos.serial.state';  Call: 'K4ABC';  Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '123 GA'),
      (Name: 've.province';       Call: 'VE3ABC'; Band: Band15; Mode: Phone; FreqHz: 21300000; Exch: '59 ON'),
      (Name: 've0.serial';        Call: 'VE0ABC'; Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123'),
      (Name: 'dx.dx';             Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '599 DX'),
      (Name: 'dx.serial';         Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '599 001'),
      (Name: 'dx.zone';           Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '599 14'),
      (Name: 'dx.name.country';   Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: 'HANS DL'),
      (Name: 'uk.serial.only';    Call: 'G3ABC';  Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '123'),
      (Name: 'uk.serial.district';Call: 'G3ABC';  Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123 LN'),
      (Name: 'ja.prefecture';     Call: 'JA1ABC'; Band: Band15; Mode: CW;    FreqHz: 21025000; Exch: '599 13'),
      (Name: 'ru.oblast';         Call: 'UA3ABC'; Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 MO'),
      (Name: 'ru.serial';         Call: 'UA3ABC'; Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123'),
      (Name: 'ru.rda';            Call: 'UA3ABC'; Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 MO12'),
      (Name: 'py.state';          Call: 'PY2ABC'; Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 SP'),
      (Name: 'f.department';      Call: 'F5ABC';  Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 75')
      );

(* THE FIRST TWO KEYS OF THE .dom FILE AT aPath, '' for each it lacks. The
  reader is uDomFileKeys -- the rule FoundMyStateInDomFile applies -- so a
  key here is one a table loaded from that file knows. *)
procedure DomFileFirstKeys(const aPath: string; out aFirst, aSecond: string);
var
   lines: TStringList;
   i: integer;
   key: string;
begin
   aFirst := '';
   aSecond := '';
   if (aPath <> '') and FileExists(aPath) then
      begin
      lines := TStringList.Create;
      try
         lines.LoadFromFile(AnsiString(aPath));
         for i := 0 to lines.Count - 1 do
            begin
            key := DomFileLineKey(string(lines[i]));
            if key = '' then
               begin
               Continue;
               end;
            if aFirst = '' then
               begin
               aFirst := key;
               end
            else
               begin
               aSecond := key;
               Break;
               end;
            end;
      finally
         lines.Free;
      end;
      end;
end;

(* THE FIRST TWO KEYS OF THE CONTEST'S DOMESTIC FILE, for <K1> and <K2> --
  the file its IDENTITY names, so a contest with none gets CT and MA. *)
procedure DomesticFileKeys(out aFirst, aSecond: string);
var
   path: string;
begin
   path := '';
   if ContestIdentity(Contest).DomesticFileName <> '' then
      begin
      path := ShippedDomFilePath(ContestIdentity(Contest).DomesticFileName + '.dom');
      end;
   DomFileFirstKeys(path, aFirst, aSecond);
   if aFirst = '' then
      begin
      aFirst := 'CT';
      end;
   if aSecond = '' then
      begin
      aSecond := 'MA';
      end;
end;

(* THE FIRST TWO KEYS OF THE FILE THE SESSION'S DOMESTIC TABLE WAS LOADED
  FROM -- DOMESTIC FILENAME, as LogCfg.SetUpGlobalsAndInitialize resolves it
  through ShippedDomFilePath (the matrix's log directory holds no override
  .dom). NOT the identity's file: a contest whose set-up chooses its file by
  the entrant names none there (New England: NEQSO or NEQSOW1), and the
  host-area rule asks THIS table. No stand-in: '' where there is no key. *)
procedure SessionDomesticFileKeys(out aFirst, aSecond: string);
var
   name: string;
   path: string;
begin
   name := Settings.Contest.DomesticFilename;
   path := '';
   if name <> '' then
      begin
      if ExtractFileExt(name) = '' then
         begin
         name := name + '.dom';
         end;
      path := ShippedDomFilePath(name);
      end;
   DomFileFirstKeys(path, aFirst, aSecond);
end;

(* ONE TYPED EXCHANGE THROUGH THE PATH LIVE ENTRY TAKES.

  TryLogContact calls MainUnit.ParametersOkay with the call window's text, the
  exchange window's text, the band and mode in force and ReceivedData; that is
  the routine that accepts an exchange or refuses it, parses it
  (LOGSTUFF.ProcessExchange) and scores it. This calls it the same way, with
  the call in the call window as an operator would have it, on a cleared
  exchange. The record is whether it was accepted, the message and token a
  refusal shows, the counties a county line queued, and every field that
  moved off the cleared exchange -- the QSO's time and id excepted, which
  ParametersOkay takes from the clock and a GUID. *)
procedure ParseOne(const aCase: TMatrixParseCase; const aFirst, aSecond: string);
var
   rx: ContestExchange;
   blank: ContestExchange;
   parts: TStringList;
   blankParts: TStringList;
   ok: boolean;
   i: integer;
   line: string;
   exch: string;
   pending: string;
   savedBand: BandType;
   savedMode: ModeType;
begin
   exch := UnicodeStringReplace(aCase.Exch, '<K1>', aFirst, [rfReplaceAll]);
   exch := UnicodeStringReplace(exch, '<K2>', aSecond, [rfReplaceAll]);

   parts := TStringList.Create;
   blankParts := TStringList.Create;
   savedBand := ActiveBand;
   savedMode := ActiveMode;
   try
      try
         ClearPendingCounties;
         ClearPendingParks;
         ActiveBand := aCase.Band;
         ActiveMode := aCase.Mode;
         (* The casts are deliberate narrowings of ASCII literals from the
           table above, bounded by construction. *)
         CallWindowString := ShortString(aCase.Call);

         ClearContestExchange(blank);
         DescribeExchange(blank, blankParts);
         ClearContestExchange(rx);
         ok := ParametersOkay(ShortString(aCase.Call), ShortString(exch),
                              aCase.Band, aCase.Mode, aCase.FreqHz, rx);

         pending := '';
         while HasPendingCounties do
            begin
            pending := pending + ' ' + DequeuePendingCounty;
            end;

         DescribeExchange(rx, parts);
         line := '';
         for i := 0 to parts.Count - 1 do
            begin
            (* THE CLOCK AND THE GUID are not the parse's, and would make the
              record differ on every run. *)
            if (Pos('time=', string(parts[i])) = 1) or (Pos('id=', string(parts[i])) = 1) then
               begin
               Continue;
               end;
            if parts[i] <> blankParts[i] then
               begin
               line := line + ' ' + string(parts[i]);
               end;
            end;

         (* NO POINTS. ParametersOkay scores the QSO it accepts, but the
           points are the scoring section's to record, on QSOs whose time is
           fixed: here the QSO carries the clock's time, and one legacy arm
           (ALRS-UA1DZ's grid distance, on a QTH that is not a grid) scored a
           different number on every run. Every field the PARSE set is below,
           and the points follow from those. *)
         Emit(Format('parse %s %s %s/%s "%s" | ok=%s err="%s" token="%s" pending="%s"',
                     [aCase.Name, aCase.Call,
                      EnumText(TypeInfo(BandType), Ord(aCase.Band)),
                      EnumText(TypeInfo(ModeType), Ord(aCase.Mode)),
                      exch, BoolText(ok), ExchangeErrorMessage,
                      string(ExchangeErrorToken), Trim(pending)]) + line);
      except
         on E: Exception do
            begin
            EmitRaised('parse ' + aCase.Name, E);
            end;
      end;
   finally
      CallWindowString := '';
      ActiveBand := savedBand;
      ActiveMode := savedMode;
      ClearPendingCounties;
      ClearPendingParks;
      parts.Free;
      blankParts.Free;
   end;
end;

procedure CaptureParse;
var
   i: integer;
   first, second: string;
begin
   Emit('== parse');
   DomesticFileKeys(first, second);
   EmitField('parse.keys', first + ' ' + second);
   for i := Low(MATRIX_PARSE_CASES) to High(MATRIX_PARSE_CASES) do
      begin
      ParseOne(MATRIX_PARSE_CASES[i], first, second);
      end;
end;

(* ------------------------------------------------------------------------ *)
(* /MATRIX -- keys (M11 S0c)                                                *)
(* ------------------------------------------------------------------------ *)

const
   (* THE KEY QSOs -- calls the 17 above never reach. M11 moves the bodies of
     SetPrefix and GetDXQTH into the classes (plan stages S3 and S4), and an
     arm that never meets a call it acts on is pinned only on its "not mine"
     branch. Each of these is one of those calls:

       ON4ABC                 Belgium -- UBA's prefixes and its European list
       YB1ABC                 Indonesia -- the YB DX districts
       JT1ABC                 Mongolia -- JT DX's prefixes and its no-JT list
       SM5ABC LA1ABC OH2ABC   Scandinavia -- the SAC districts; OH0 is the
       OH0ABC OX3ABC          one that district rule treats apart
       UA9ABC UA0ABC          Asiatic Russia -- WAE's call regions, and the
                              PACC split (reachable only from a PA entrant,
                              which the matrix does not run)
       RK1G                   on the Gagarin Cup's own station list
       I1ABC IS0ABC           Italy and Sardinia -- ARI's no-I list
       LZ1ABC UR5ABC          the Black Sea countries
       9A2ABC                 Croatia
       KL7ABC                 Alaska -- the two lists that exclude KL7
       HB9ABC OK1ABC          Switzerland and the Czech Republic

     Every call resolves through the shipped CTY.DAT, and BuildQSO gives it
     the same lookup and fields it gives the 17 above. The record numbers them
     on from the last of those (18, 19, ...).

     CHANGING THIS LIST CHANGES EVERY keys SECTION. A re-freeze with a
     reason, like any other. *)
   MATRIX_KEY_QSOS: array[1..19] of TMatrixQSO =
      (
      (Call: 'ON4ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 14; Sparse: False),
      (Call: 'YB1ABC'; Band: Band15;  Mode: CW;      Ext: eCW;   FreqHz: 21025000;  QTH: '';   Zone: 28; Sparse: False),
      (Call: 'JT1ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 23; Sparse: False),
      (Call: 'SM5ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 14; Sparse: False),
      (Call: 'LA1ABC'; Band: Band40;  Mode: CW;      Ext: eCW;   FreqHz: 7025000;   QTH: '';   Zone: 14; Sparse: False),
      (Call: 'OH2ABC'; Band: Band20;  Mode: Phone;   Ext: eUSB;  FreqHz: 14250000;  QTH: '';   Zone: 15; Sparse: False),
      (Call: 'OH0ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 15; Sparse: False),
      (Call: 'OX3ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 40; Sparse: False),
      (Call: 'UA9ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 17; Sparse: False),
      (Call: 'UA0ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 18; Sparse: False),
      (Call: 'RK1G';   Band: Band40;  Mode: CW;      Ext: eCW;   FreqHz: 7025000;   QTH: '';   Zone: 16; Sparse: False),
      (Call: 'I1ABC';  Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 15; Sparse: False),
      (Call: 'IS0ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 15; Sparse: False),
      (Call: 'LZ1ABC'; Band: Band40;  Mode: CW;      Ext: eCW;   FreqHz: 7025000;   QTH: '';   Zone: 20; Sparse: False),
      (Call: 'UR5ABC'; Band: Band40;  Mode: CW;      Ext: eCW;   FreqHz: 7025000;   QTH: '';   Zone: 16; Sparse: False),
      (Call: '9A2ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 15; Sparse: False),
      (Call: 'KL7ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 1;  Sparse: False),
      (Call: 'HB9ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 14; Sparse: False),
      (Call: 'OK1ABC'; Band: Band20;  Mode: CW;      Ext: eCW;   FreqHz: 14025000;  QTH: '';   Zone: 15; Sparse: False)
      );

   (* THE KEY EXCHANGES -- QTH texts GetDomQTH's arms read that the 66 above
     do not carry: an IOTA reference three ways (the arm takes two letters
     and up to three digits, so the dashed form is the one it refuses), a DOK
     alone and after a serial, a six-character grid square (the square arm's
     second length), a two-letter grid field (which the field arm refuses --
     it reads four characters), and an RDA district one digit short.

     CHANGING THIS LIST CHANGES EVERY keys SECTION. *)
   MATRIX_KEY_PARSE_CASES: array[1..8] of TMatrixParseCase =
      (
      (Name: 'iota';              Call: 'G3ABC';  Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123 EU005'),
      (Name: 'iota.dash';         Call: 'G3ABC';  Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 123 EU-005'),
      (Name: 'iota.short';        Call: 'G3ABC';  Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 EU5'),
      (Name: 'dok';               Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '599 A01'),
      (Name: 'serial.dok';        Call: 'DL1ABC'; Band: Band40; Mode: CW;    FreqHz: 7025000;  Exch: '599 123 A01'),
      (Name: 'grid6';             Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 FN31PR'),
      (Name: 'grid.field';        Call: 'W1AW';   Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 FN'),
      (Name: 'rda.short';         Call: 'UA3ABC'; Band: Band20; Mode: CW;    FreqHz: 14025000; Exch: '599 MO1')
      );

(* THE KEY FUNCTIONS' INPUTS AND OUTPUTS, appended for M11 (plan S0c).

  BETWEEN parse AND totals, and NOTHING HERE IS LOGGED: the QSOs are scored
  through RecomputeQSOScoring -- SetPrefix, GetDXQTH, the sheet's flags and
  the class's points, as the scoring section scores -- and never appended to
  the log, so the export, the import read-back and the totals reload describe
  exactly the log they described before this section existed. Each is scored
  against the same untouched sheet the scoring section used, and on a band
  the contest credits (Q98 S0, CreditedMatrixQSO) -- the record's line names
  the band it was scored on. *)
procedure CaptureKeys;
var
   i: integer;
   n: integer;
   rx: ContestExchange;
   spec: TMatrixQSO;
   first, second: string;
   contestRules: TContestBase;
begin
   Emit('== keys');
   (* ONE ActiveContest FOR THE BAND QUESTION -- it rebuilds the station on
     every call, and the answer cannot change within this section. *)
   contestRules := ActiveContest(Contest);
   (* THE FIELDS THE CONTEST STATED (TContestBase.ReceivedExchangeFields,
     M11 S9a), by name, in the record's own order -- start-up assigns
     LOGDUPE.ExchangeInformation once (uProgramMain), and the log-string
     parses, the age message and the ADIF export read it. It was
     SetUpExchangeInformation's. *)
   EmitField('exchange.fields', ExchangeFieldsText(ExchangeInformation));
   (* SET WHEN THE SESSION COUNTS ZONES (SetUpRemainingMultiplierArrays,
     which LoadinLog runs); otherwise the global's start-up value. *)
   EmitField('zones.max', IntToStr(MaxNumberOfZones));

   for i := Low(MATRIX_KEY_QSOS) to High(MATRIX_KEY_QSOS) do
      begin
      n := High(MATRIX_QSOS) + i;
      try
         (* ON A BAND THE CONTEST CREDITS (Q98 S0) -- see CreditedMatrixQSO. *)
         spec := CreditedMatrixQSO(contestRules, MATRIX_KEY_QSOS[i]);
         BuildQSO(n, spec, rx);
         RecomputeQSOScoring(rx);
         Emit(ScoreLine(n, spec, rx));
      except
         on E: Exception do
            begin
            EmitRaised(Format('qso %.2d', [n]), E);
            end;
      end;
      end;

   DomesticFileKeys(first, second);
   for i := Low(MATRIX_KEY_PARSE_CASES) to High(MATRIX_KEY_PARSE_CASES) do
      begin
      ParseOne(MATRIX_KEY_PARSE_CASES[i], first, second);
      end;
end;

(* ------------------------------------------------------------------------ *)
(* /MATRIX -- totals (M6)                                                   *)
(* ------------------------------------------------------------------------ *)

(* THE CLAIMED-SCORE: LINE OF THE CABRILLO FILE, as written. '' when the
  writer produced no file or no such line. *)
function CabrilloClaimedScoreLine(const aFile: string): string;
var
   lines: TStringList;
   i: integer;
begin
   Result := '';
   if (aFile = '') or (not FileExists(aFile)) then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(aFile));
      for i := 0 to lines.Count - 1 do
         begin
         if Pos('CLAIMED-SCORE:', string(lines[i])) = 1 then
            begin
            Result := string(lines[i]);
            Exit;
            end;
         end;
   finally
      lines.Free;
   end;
end;

(* THE TOTALS THE PROGRAM COMPUTES FROM THE LOG THE SCORING SECTION WROTE.

  THE LOG IS RELOADED FIRST, through MainUnit.LoadinLog -- the routine that
  opens a contest's log, and the one /EXPORT's start has run before it writes
  a CLAIMED-SCORE. The scoring section appended its QSOs to the store without
  passing through live entry, so until the reload the sheet and the counters
  still describe the log as it was at start-up: empty. After it, they are what
  an operator who reopened this log would see.

  ONLY NON-ZERO CELLS of the QSO and multiplier tables are written, so a
  record stays readable. The multiplier counts are the four kinds the sheet
  keeps, in the order domestic/dx/zone/prefix. *)
procedure CaptureTotals;
var
   b: BandType;
   m: ModeType;
   cabrilloFile: string;
begin
   Emit('== totals');
   LoadinLog;

   EmitField('totals.qsopoints', IntToStr(TotalQSOPoints));
   EmitField('totals.qtcs', IntToStr(TotalNumberQTCsProcessed));
   EmitField('totals.singleband', EnumText(TypeInfo(BandType), Ord(SingleBand)));

   for b := Low(BandType) to High(BandType) do
      begin
      for m := CW to Both do
         begin
         if QSOTotals[b, m] <> 0 then
            begin
            EmitField(Format('totals.qsos %s %s',
                             [EnumText(TypeInfo(BandType), Ord(b)),
                              EnumText(TypeInfo(ModeType), Ord(m))]),
                      IntToStr(QSOTotals[b, m]));
            end;
         end;
      end;

   for b := Low(BandType) to High(BandType) do
      begin
      for m := CW to Both do
         begin
         if (mo.MTotals[b, m, rmDomestic] <> 0) or
            (mo.MTotals[b, m, rmDX] <> 0)       or
            (mo.MTotals[b, m, rmZone] <> 0)     or
            (mo.MTotals[b, m, rmPrefix] <> 0)   then
            begin
            EmitField(Format('totals.mults %s %s',
                             [EnumText(TypeInfo(BandType), Ord(b)),
                              EnumText(TypeInfo(ModeType), Ord(m))]),
                      Format('dom=%d dx=%d zone=%d pfx=%d',
                             [mo.MTotals[b, m, rmDomestic], mo.MTotals[b, m, rmDX],
                              mo.MTotals[b, m, rmZone], mo.MTotals[b, m, rmPrefix]]));
            end;
         end;
      end;

   EmitField('totals.totalscore', IntToStr(TotalScore));

   cabrilloFile := '';
   try
      CreateCabrilloFile;
      cabrilloFile := CharBufferText(tReportsFilename);
   except
      on E: Exception do
         begin
         EmitRaised('totals CreateCabrilloFile', E);
         end;
   end;
   EmitField('totals.cabrillo', CabrilloClaimedScoreLine(cabrilloFile));
end;

(* ------------------------------------------------------------------------ *)
(* /MATRIX -- initialexchange (M11 S0c)                                     *)
(* ------------------------------------------------------------------------ *)

const
   (* THE MATRIX'S OWN CALL-HISTORY FILE, as matrix-lib.sh copies it into the
     run directory. Not named TRMASTER.DTA, so FCONTEST's own resolution
     never finds it. *)
   MATRIX_TRMASTER_FILE = 'MATRIX-TRMASTER.DTA';

   (* CALLS ASKED ABOUT WHICH NEITHER QSO TABLE CARRIES: a Russian call
     (the oblast rules), an R3 special-event call (the OZ-CR exception), and
     a call the matrix's call-history file knows that no QSO logs. *)
   MATRIX_EXTRA_PROBE_CALLS: array[1..3] of string = ('UA3ABC', 'R35AB', 'K9ABC');

   (* EVERY COMMAND THE CUSTOM ARM READS, in its own order. Nothing the
     matrix runs states a CUSTOM INITIAL EXCHANGE STRING, so without this the
     Custom arm meets only an empty one. *)
   MATRIX_CUSTOM_INITIAL_EXCHANGE =
      'CQZONE ITUZONE NAME QTH SECTION USER1 USER2 USER3 USER4 USER5 GRID FOC CHECK OLDCALL TENTEN';

(* ONE InitialExchangeEntry, text or what it raised. The value is quoted
  in the record, spaces included: a leading space is how the routine tells
  the window where the cursor goes. *)
function ProbeInitialExchange(const aCall: string): string;
begin
   try
      Result := string(InitialExchangeEntry(ShortString(aCall)));
   except
      on E: Exception do
         begin
         Result := '<RAISED ' + E.ClassName + '>';
         LogCaughtException('[Matrix] initialexchange ' + aCall, E);
         end;
   end;
end;

(* WHAT THE ENTRY WINDOW WOULD BE OFFERED FOR A CALL -- InitialExchangeEntry,
  the routine typing a call runs (LOGEDIT), under three conditions:

    none      no call-history file and no logged history. THE PROGRAM ALONE
              CANNOT GIVE MORE THAN THIS HEADLESS: CD.MasterFileExists is set
              in uProgramMain AFTER the /MATRIX halt (plan F17), so the
              shipped TRMASTER.DTA is never opened. The one exception is a
              contest whose set-up builds the operator-name set
              (InitOperatorNameSet sets the flag itself); the flag is
              recorded as the program left it, then cleared for this pass.
    trmaster  the matrix's OWN call-history file (MATRIX-TRMASTER.DTA, see
              make-trmaster-fixture.py), opened here and only here -- the
              assignment uProgramMain makes, aimed at a file that changes
              only when someone means it to. Never the shipped file, which
              is refreshed monthly and would move every record.
    logged    that file AND the logged QSOs' history. LoadinLog adds a QSO's
              initial exchange to the callsigns list only while
              IntitialExLoaded is False, and start-up's load of the empty
              log latched it (plan F18), so the totals reload added none.
              The latch is cleared and the log loaded again -- what opening
              a non-empty log does at start-up.
    custom    all of that AND a CUSTOM INITIAL EXCHANGE STRING naming every
              command the Custom arm reads (restored afterwards). Only a
              session whose initial exchange is Custom reads the string; for
              every other this column repeats the one before it.

  LAST, after totals, because each pass changes what the next one sees and
  none may reach a section before it. The calls are the scoring section's
  (each once, in order), the keys section's, then three more. *)
procedure CaptureInitialExchange;
var
   calls: TStringList;
   none, trm, logged, custom: TStringList;
   i: integer;
   fixture: string;
   fixtureOpened: boolean;
   savedCustom: string;

   procedure AddCall(const aCall: string);
   begin
      if calls.IndexOf(AnsiString(aCall)) < 0 then
         begin
         calls.Add(AnsiString(aCall));
         end;
   end;

   procedure Probe(aInto: TStringList);
   var
      j: integer;
   begin
      for j := 0 to calls.Count - 1 do
         begin
         aInto.Add(AnsiString(ProbeInitialExchange(string(calls[j]))));
         end;
   end;

begin
   Emit('== initialexchange');

   calls := TStringList.Create;
   none := TStringList.Create;
   trm := TStringList.Create;
   logged := TStringList.Create;
   custom := TStringList.Create;
   try
      for i := Low(MATRIX_QSOS) to High(MATRIX_QSOS) do
         begin
         AddCall(MATRIX_QSOS[i].Call);
         end;
      for i := Low(MATRIX_KEY_QSOS) to High(MATRIX_KEY_QSOS) do
         begin
         AddCall(MATRIX_KEY_QSOS[i].Call);
         end;
      for i := Low(MATRIX_EXTRA_PROBE_CALLS) to High(MATRIX_EXTRA_PROBE_CALLS) do
         begin
         AddCall(MATRIX_EXTRA_PROBE_CALLS[i]);
         end;

      EmitField('initialexchange.trmaster.program', BoolText(CD.MasterFileExists));
      (* AN INDEX ALREADY READ CANNOT BE SWAPPED: LoadInIndexArray answers
        from it for ever after. Nothing the matrix runs reads one before this
        point; if something ever does, the record says so rather than
        describing a file it did not read. *)
      EmitField('initialexchange.trmaster.indexopen', BoolText(CD.TRMasterFileOpen));

      CD.MasterFileExists := False;
      Probe(none);

      fixture := IncludeTrailingPathDelimiter(GLogDir) + MATRIX_TRMASTER_FILE;
      fixtureOpened := (not CD.TRMasterFileOpen) and FileExists(fixture);
      if fixtureOpened then
         begin
         SetCharBuffer(CD.ActiveFilename, fixture);
         CD.MasterFileExists := True;
         CD.ClearDataEntry(CD.LastCallRecord);
         end;
      EmitField('initialexchange.trmaster.fixture', BoolText(fixtureOpened));
      Probe(trm);

      try
         IntitialExLoaded := False;
         LoadinLog;
      except
         on E: Exception do
            begin
            EmitRaised('initialexchange LoadinLog', E);
            end;
      end;
      Probe(logged);

      savedCustom := Settings.Contest.CustomInitialExchangeString;
      try
         Settings.Contest.CustomInitialExchangeString := MATRIX_CUSTOM_INITIAL_EXCHANGE;
         Probe(custom);
      finally
         Settings.Contest.CustomInitialExchangeString := savedCustom;
      end;

      for i := 0 to calls.Count - 1 do
         begin
         Emit(Format('iex %s | none="%s" trmaster="%s" logged="%s" custom="%s"',
                     [string(calls[i]), string(none[i]), string(trm[i]),
                      string(logged[i]), string(custom[i])]));
         end;
   finally
      calls.Free;
      none.Free;
      trm.Free;
      logged.Free;
      custom.Free;
   end;
end;

function RunContestMatrix(const aOutFile: string;
                          const aRequested: string): integer;
begin
   if (aOutFile = '') or (aRequested = '') then
      begin
      logger.Error('[Matrix] usage: tr4w.exe <cfg> /MATRIX <out-file> <contest id>');
      Result := 1;
      Exit;
      end;

   GLogDir := CharBufferText(TR4W_LOG_PATH_NAME);
   GDataDir := CharBufferText(TR4W_PATH_NAME);

   GOut := TStringList.Create;
   try
      GOut.LineBreak := MATRIX_LINE_BREAK;

      (* EACH SECTION CATCHES ITS OWN FAILURE, so a contest that raises in one
        place is still recorded in the others -- and the record says it
        raised, which is the behaviour being frozen. *)
      try
         CaptureIdentity(aRequested);
      except
         on E: Exception do
            begin
            EmitRaised('identity', E);
            end;
      end;

      try
         CaptureSetup;
      except
         on E: Exception do
            begin
            EmitRaised('setup', E);
            end;
      end;

      CaptureScoringAndLog;
      CaptureExport;

      try
         CaptureImport;
      except
         on E: Exception do
            begin
            EmitRaised('import', E);
            end;
      end;

      (* AFTER import, so every section before it is byte-for-byte what it
        was before this one existed (M5b's freeze appended it). *)
      try
         CaptureParse;
      except
         on E: Exception do
            begin
            EmitRaised('parse', E);
            end;
      end;

      (* M11 S0c: AFTER parse and BEFORE totals. It logs nothing, so totals
        reloads the same log and keeps its bytes; every section above it is
        untouched. *)
      try
         CaptureKeys;
      except
         on E: Exception do
            begin
            EmitRaised('keys', E);
            end;
      end;

      (* M6's freeze appended it, and every section above it kept its bytes.
        It reloads the log, so nothing may follow it that expects the session
        as the sections above left it. *)
      try
         CaptureTotals;
      except
         on E: Exception do
            begin
            EmitRaised('totals', E);
            end;
      end;

      (* M11 S0c: LAST of all. It opens a call-history file and reloads the
        log with history, both of which would reach any section after it. *)
      try
         CaptureInitialExchange;
      except
         on E: Exception do
            begin
            EmitRaised('initialexchange', E);
            end;
      end;

      try
         GOut.SaveToFile(AnsiString(aOutFile));
         Result := 0;
      except
         on E: Exception do
            begin
            logger.Error('[Matrix] could not write %s: %s', [aOutFile, E.Message]);
            Result := 2;
            end;
      end;
   finally
      FreeAndNil(GOut);
   end;
end;

end.
