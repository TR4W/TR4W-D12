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
          Every ContestType but the first (DUMMYCONTEST, ordinal 0, which is
          "no contest"), one per line, separated by '|':
              ordinal  identifier  .cfg spelling  P  DF  host state
          The script reads it to know what to run. It is THE ENUM ITERATED,
          so no contest is named anywhere -- here or in the script.

      tr4w.exe <work>\<stem>.cfg /MATRIX <out-file> <requested-ordinal>
          The contest the .cfg selects, booted by the ordinary startup path,
          captured, then Halt. Positioned where /EXPORT is, for the same
          reason: the config, the log and the contest are all set up by then.

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

    identity   requested vs selected ContestType, the class (or none)
    setup      the seven Active* values, the CTY modes, every engine global
               FoundContest writes, the domestic country list, the county-line
               answer, the CW memories it writes, and EVERY SETTING WHOSE VALUE
               DIFFERS FROM A FRESHLY CONSTRUCTED SETTINGS OBJECT -- so a
               Settings.* write by any arm is caught without this file having
               to list it
    scoring    per synthetic QSO, the fields /RESCORE recomputes, through
               MainUnit.RecomputeQSOScoring -- the rescore's own body, not a
               copy of it
    export     the QSOs appended to the scratch log, then the REAL exporters
               (ExportToADIF, CreateCabrilloFile): the Cabrillo CONTEST: and
               QSO: lines, and every ADIF record after <EOH>

  M5 EXTENSION POINT -- NOT CAPTURED YET. Parsing (ProcessExchange over a typed
  exchange) and ADIF import interpretation are not exercised: the synthetic
  QSOs carry their exchange fields already filled, the way a STORED QSO does.
  Add a "parse" section beside "scoring" when M5 starts, freeze it BEFORE the
  first arm moves, and say so in docs/ADDING_A_CONTEST.md section 4.

  NOT CAPTURED, deliberately: Cabrillo header lines other than CONTEST: (they
  carry the build version and the totals, which belong to M6/M9), and the
  other identity readers (HamScore, WA7BNM, QRZ.RU), which produce no file.

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

(* tr4w.exe <cfg> /MATRIX <out-file> <requested-ordinal>. Returns the process
  exit code: 0 written, 1 misused, 2 the record could not be written. A
  contest whose capture RAISES still exits 0 -- the record says what raised,
  and that is the behaviour being frozen. *)
function RunContestMatrix(const aOutFile: string;
                          const aRequested: string): integer;

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
   uContestFactory,
   uContestStateQSOPartyBase,
   uLogStore,
   uCrashLog,     (* EarlyTrace -- /MATRIXLIST runs before tr4w.log is configured *)
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


(* THE COMPILER'S OWN NAME FOR AN ENUMERATED VALUE.

  NOT THE PROGRAM'S SPELLING TABLES, and the reason is a measured defect:
  QSOPointMethodArray is out of step with QSOPointMethodType from position 38
  onward (docs/CONTEST_OWNERSHIP_DESIGN.md section 7.2), so spelling a point
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


(* ------------------------------------------------------------------------ *)
(* /MATRIXLIST                                                              *)
(* ------------------------------------------------------------------------ *)

function RunContestMatrixList(const aOutFile: string): integer;
var
   list: TStringList;
   c: ContestType;
   hostState: string;
begin
   if aOutFile = '' then
      begin
      EarlyTrace('[Matrix] usage: tr4w.exe /MATRIXLIST <out-file>');
      Result := 1;
      Exit;
      end;

   list := TStringList.Create;
   try
      list.LineBreak := MATRIX_LINE_BREAK;

      (* FROM THE SECOND MEMBER. The first is DUMMYCONTEST, "no contest" --
        FoundContest itself treats it as not-a-contest and it cannot be
        opened. It is ordinal 0 and ordinals are persisted, so it cannot move;
        skipping it by position keeps this unit free of any contest name. *)
      for c := Succ(Low(ContestType)) to High(ContestType) do
         begin
         hostState := '';
         if ContestsArray[c].P <> 0 then
            begin
            hostState := QSOParties[ContestsArray[c].P].StateName;
            end;
         (* '|', NOT A TAB. A shell reading with IFS=tab collapses two
           adjacent tabs into one, so an EMPTY field -- Colorado's DF -- moved
           every field after it one place left. '|' is not whitespace to the
           shell and appears in no spelling. *)
         list.Add(AnsiString(IntToStr(Ord(c)) + '|' +
                  EnumText(TypeInfo(ContestType), Ord(c)) + '|' +
                  ContestTypeSA[c] + '|' +
                  IntToStr(ContestsArray[c].P) + '|' +
                  ContestsArray[c].DF + '|' +
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
      list.Free;
   end;
end;


(* ------------------------------------------------------------------------ *)
(* /MATRIX -- identity and setup                                            *)
(* ------------------------------------------------------------------------ *)

procedure CaptureIdentity(aRequested: integer);
var
   klass: TContestBase;
begin
   Emit('== identity');
   if (aRequested >= Ord(Low(ContestType))) and
      (aRequested <= Ord(High(ContestType))) then
      begin
      EmitField('contest.requested',
                IntToStr(aRequested) + ' ' +
                EnumText(TypeInfo(ContestType), aRequested));
      end
   else
      begin
      EmitField('contest.requested', IntToStr(aRequested) + ' (not a ContestType)');
      end;

   (* SELECTED IS WHAT THE .cfg's CONTEST LINE ACTUALLY CHOSE. A spelling that
     two members share selects the first, so the second is unreachable from a
     .cfg -- a difference between these two lines is that finding. *)
   EmitField('contest.selected',
             IntToStr(Ord(Contest)) + ' ' +
             EnumText(TypeInfo(ContestType), Ord(Contest)));
   if Ord(Contest) <> aRequested then
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
   rec: DomesticCountryRecordPointer;
   line: string;
begin
   line := '';
   rec := FirstDomesticCountryRecord;
   while rec <> nil do
      begin
      line := line + ' ' + string(rec^.CountryID);
      rec := rec^.NextRecord;
      end;
   EmitField('domestic.countries', Trim(line));
end;

procedure CaptureCountyLine;
var
   klass: TContestBase;
begin
   (* WHAT EACH READER ASKS TODAY. The ADIF importer reads the array's flag;
     ValidateQTHCount asks a state-party class for its maximum. Both are
     recorded because M2 and M5 move them. *)
   EmitField('countyline.row.allowed', BoolText(ContestsArray[Contest].CountyLineAllowed));
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
         if not Settings.TryGetByCommand(names[i], live) then
            begin
            Continue;
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
   EmitField('active.qsopointmethod', EnumText(TypeInfo(QSOPointMethodType), Ord(ActiveQSOPointMethod)));
   EmitField('active.exchange', EnumText(TypeInfo(ExchangeType), Ord(ActiveExchange)));
   EmitField('active.initialexchange', EnumText(TypeInfo(InitialExchangeType), Ord(ActiveInitialExchange)));
   EmitField('active.domesticmult', EnumText(TypeInfo(DomesticMultType), Ord(ActiveDomesticMult)));
   EmitField('active.dxmult', EnumText(TypeInfo(DXMultType), Ord(ActiveDXMult)));
   EmitField('active.zonemult', EnumText(TypeInfo(ZoneMultType), Ord(ActiveZoneMult)));
   EmitField('active.prefixmult', EnumText(TypeInfo(PrefixMultType), Ord(ActivePrefixMult)));
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

(* SCORE EACH QSO, THEN PUT IT IN THE LOG FOR THE EXPORTERS.

  EACH QSO IS SCORED AGAINST AN EMPTY SHEET -- nothing is added to the dupe or
  multiplier sheets -- so every QSO is scored as the first of its kind and no
  record depends on the ones before it. The mult flags therefore read "would
  be a new multiplier". *)
procedure CaptureScoringAndLog;
var
   i: integer;
   rx: ContestExchange;
begin
   Emit('== scoring');
   for i := Low(MATRIX_QSOS) to High(MATRIX_QSOS) do
      begin
      try
         BuildQSO(i, MATRIX_QSOS[i], rx);
         RecomputeQSOScoring(rx);
         Emit(ScoreLine(i, MATRIX_QSOS[i], rx));
         if not LogStoreAppendQSO(rx) then
            begin
            Emit(Format('qso %.2d NOT APPENDED to the log -- the export below lacks it', [i]));
            end;
      except
         on E: Exception do
            begin
            EmitRaised(Format('qso %.2d', [i]), E);
            end;
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

function RunContestMatrix(const aOutFile: string;
                          const aRequested: string): integer;
var
   requested: integer;
begin
   requested := StrToIntDef(AnsiString(aRequested), -1);
   if (aOutFile = '') or (requested < 0) then
      begin
      logger.Error('[Matrix] usage: tr4w.exe <cfg> /MATRIX <out-file> <ordinal>');
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
         CaptureIdentity(requested);
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
