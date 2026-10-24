(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (TEST)

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

(* THE NEW ENGLAND QSO PARTY'S 2026-10-23 RULES -- the sponsor's text
  (neqp.org/rules and the neqp.org FAQ), which overrides D7 where it is
  stated outright. Each assertion is written from the sponsor's sentence,
  never read back out of the class:

    * "two points per CW (includes digital modes) QSO", one per phone QSO;
    * "DXCC countries (not USA) as multipliers" -- no cap;
    * "Canadian provinces (14 -- VO1/VO2 are separate)";
    * "states(50) (Count DC as MD)";
    * "digital QSOs are considered the same as CW" for dupes;
    * "Mobiles that change counties are considered to be new stations",
      and "County line QSOs should be logged as two separate QSOs" --
      through the real engine, at both kinds of entrant.

  NEW BEHAVIOUR, SO THE MATRIX'S FROZEN RECORD CANNOT JUDGE IT. The two .dom
  rules go through the REAL loader (TDomQTHTable over the shipped
  neqsow1.dom and the files it includes -- the includes followed by the
  test, LoadShippedDomFollowingIncludes says why), and the dupe rule through the
  real dupe sheet (TCallsignsList). *)
unit uTestContestNewEnglandQP;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestNewEnglandQPTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NEQPDigitalScoresAsCW;
      procedure Test_NEQPHasNoDXMultiplierCap;
      procedure Test_NEQPVO1AndVO2AreTwoProvinces;
      procedure Test_NEQPCountsDCAsMaryland;
      procedure Test_NEQPDigitalIsADupeOfCW;
      procedure Test_EveryOtherContestKeepsEachModeItsOwnDupeMode;
      procedure Test_NEQPRoverInANewCountyIsANewStation;
   private
      procedure CheckRoverRule(aInNewEngland: boolean);
   end;

implementation

uses
   (* Settings.Qso -- before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uADIF,
   uPendingCounties,
   (* ExistingDataFile -- a shipped file, whatever case it is spelled in. *)
   uAppPaths,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   uTestRegisteredContests,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit;

(* ---------------------------------------------------------------------------
   HELPERS
   --------------------------------------------------------------------------- *)

(* An entrant in New England (MY STATE ME) or outside it (KS). Outside, the
   host-area table knows every QTH, so a points test is not about that
   rule (uTestContestObjects.WithHostAreaTable). *)
function Entrant(aInNewEngland: boolean): TStationContext;
begin
   Result := WithHostAreaTable(NoStation);
   if aInNewEngland then
      begin
      Result.MyState := 'ME';
      end
   else
      begin
      Result.MyState := 'KS';
      end;
end;

function PointsFor(aInNewEngland: boolean; aMode: ModeType): integer;
var
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   contestObject := Make(NEWENGLANDQSO, Entrant(aInNewEngland));
   try
      qso := Default(ContestExchange);
      qso.Band := Band20;
      qso.Mode := aMode;
      qso.QTHString := 'MEAND';
      qso.DomesticQTH := 'MEAnd';
      qso.QSOPoints := 99;
      contestObject.ScoreQSO(qso);
      Result := qso.QSOPoints;
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   LOADING A SHIPPED .dom, ITS INCLUDEs FOLLOWED BY THE TEST

   THE LOADER CANNOT FOLLOW AN INCLUDE FILE FROM HERE. EnumDOMFILE resolves
   one through uAppPaths.ShippedDomFilePath, which is DataDir's dom folder --
   the working directory on Windows, but /usr/share/tr4w/ or the binary's
   own directory (tr4w/test/unit, which has no dom folder) on Linux. So on
   Linux the include is missing, the loader queues its modal "could not
   find this file" warning, and the first later test that pumps messages
   blocks for ever under xvfb (the v5.0.31 release run). uTestContestGeorgiaQP
   records the same limit ("Its INCLUDEs cannot be followed here").

   So the test follows them itself, and the REAL loader still reads every
   line of every real file: each file is cut at its INCLUDE FILE lines into
   segments, each segment is written to a temp copy and read by
   ReadDomQTHFile, and each named file is loaded the same way, in the
   file's order -- depth first, exactly where the loader would have
   re-entered. Only the first segment of the top-level file is read as a
   top-level file (it clears the table, as LoadInDomQTHFile's one call to
   ReadDomQTHFile(..., False) does); every other one is read as included.
   No temp copy holds an INCLUDE line, so the loader never resolves a path
   itself, and every file is proved to exist BEFORE it is read -- a missing
   one fails here with its path, instead of queuing the warning.
   --------------------------------------------------------------------------- *)

const
   DOM_INCLUDE_KEYWORD = 'INCLUDE FILE';

   (* neqsow1.dom's INCLUDE FILE lines, in its order: "states(50)" and
      "Canadian provinces (14 -- VO1/VO2 are separate)". *)
   NEW_ENGLAND_ENTRANT_INCLUDES = 'S50.DOM P14.DOM';

(* The file an INCLUDE FILE line names, read as EnumDOMFILE reads it (leading
   blanks dropped, the keyword case-sensitive); '' for any other line. *)
function DomIncludeName(const aLine: string): string;
var
   trimmed: string;
begin
   Result := '';
   trimmed := TrimLeft(aLine);
   if Copy(trimmed, 1, Length(DOM_INCLUDE_KEYWORD)) = DOM_INCLUDE_KEYWORD then
      begin
      Result := Trim(Copy(trimmed, Length(DOM_INCLUDE_KEYWORD) + 2, 200));
      end;
end;

(* One segment of aFileName, through the real loader, from a temp copy. The
   copy starts with a line naming its source -- no '=', so not an entry --
   which also keeps it from being empty: EnumerateLinesInFile refuses an
   empty file, and the loader would queue the warning for it. *)
procedure LoadDomSegment(aTable: TDomQTHTable; aSegment: TStringList;
                         const aFileName: string; aTopLevel: boolean);
var
   path: string;
begin
   aSegment.Insert(0, 'TEST COPY OF ' + UpperCase(aFileName) + ', INCLUDES REMOVED');
   path := GetTempFileName(GetTempDir, 'tr4wdom');
   try
      aSegment.SaveToFile(AnsiString(path));
      if not aTable.ReadDomQTHFile(path, not aTopLevel) then
         begin
         raise Exception.Create('the loader refused a segment of ' + aFileName + ': ' + path);
         end;
   finally
      SysUtils.DeleteFile(path);
   end;
   aSegment.Clear;
end;

(* aFileName (a name in the shipped dom folder, in any case) into aTable,
   as the loader would, its INCLUDEs followed as above. Answers the file's
   OWN INCLUDE FILE names, upper-cased, in its order, blank-separated. *)
function LoadShippedDomFollowingIncludes(aTable: TDomQTHTable;
                                         const aFileName: string;
                                         aTopLevel: boolean;
                                         aDepth: integer): string;
var
   path: string;
   included: string;
   lines: TStringList;
   segment: TStringList;
   firstSegment: boolean;
   i: integer;
begin
   Result := '';
   if aDepth > 8 then
      begin
      raise Exception.Create('INCLUDE FILE nests too deep at ' + aFileName);
      end;
   (* THE SAME FILE, WHATEVER CASE IT IS SPELLED IN: the .dom says P14.DOM,
      and on Linux the shipped file is p14.dom. *)
   path := ExistingDataFile(ShippedDomDir + aFileName);
   if not FileExists(path) then
      begin
      raise Exception.Create('a shipped .dom is missing, so the loader would queue its '
                             + '"could not find" warning: ' + path);
      end;
   lines := TStringList.Create;
   segment := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(path));
      firstSegment := aTopLevel;
      for i := 0 to lines.Count - 1 do
         begin
         included := DomIncludeName(lines[i]);
         if included = '' then
            begin
            segment.Add(lines[i]);
            end
         else
            begin
            LoadDomSegment(aTable, segment, aFileName, firstSegment);
            firstSegment := False;
            if Result <> '' then
               begin
               Result := Result + ' ';
               end;
            Result := Result + UpperCase(included);
            LoadShippedDomFollowingIncludes(aTable, included, False, aDepth + 1);
            end;
         end;
      LoadDomSegment(aTable, segment, aFileName, firstSegment);
   finally
      segment.Free;
      lines.Free;
   end;
end;

(* aTable, the multiplier sheet and MultipliersIsCounties as a New England
   entrant's session loads them: neqsow1.dom, through the real loader, with
   its INCLUDEs. Answers neqsow1.dom's own INCLUDE FILE names, for the caller
   to hold to NEW_ENGLAND_ENTRANT_INCLUDES. The caller saved and restores the
   sheet and the flag. *)
function LoadNewEnglandEntrantTable(aTable: TDomQTHTable): string;
begin
   MultipliersIsCounties := False;
   Result := LoadShippedDomFollowingIncludes(aTable, 'neqsow1.dom', True, 0);
end;

function MultiplierOf(aTable: TDomQTHTable; const aAlias: string): string;
var
   entry: TDomQTHEntry;
begin
   Result := '';
   if aTable.FindAlias(aAlias, entry) then
      begin
      Result := UpperCase(string(entry.Multiplier));
      end;
end;

function QTHOf(aTable: TDomQTHTable; const aAlias: string): string;
var
   entry: TDomQTHEntry;
begin
   Result := '';
   if aTable.FindAlias(aAlias, entry) then
      begin
      Result := UpperCase(string(entry.DomQTH));
      end;
end;

(* ---------------------------------------------------------------------------
   POINTS
   --------------------------------------------------------------------------- *)

(* "Count one point per phone QSO, and two points per CW (includes digital
   modes) QSO." FM is phone. The same at both kinds of entrant. *)
procedure TContestNewEnglandQPTests.Test_NEQPDigitalScoresAsCW;
var
   inside: boolean;
   who: string;
begin
   BeginTest('Test_NEQPDigitalScoresAsCW');
   for inside := False to True do
      begin
      if inside then
         begin
         who := 'a New England entrant';
         end
      else
         begin
         who := 'an entrant outside New England';
         end;
      CheckEquals(2, PointsFor(inside, CW), who + ': CW is 2');
      CheckEquals(2, PointsFor(inside, Digital), who + ': digital is 2, as CW');
      CheckEquals(1, PointsFor(inside, Phone), who + ': phone is 1');
      CheckEquals(1, PointsFor(inside, FM), who + ': FM is phone, 1');
      end;
end;

(* ---------------------------------------------------------------------------
   THE DX MULTIPLIER
   --------------------------------------------------------------------------- *)

(* "DXCC countries (not USA) as multipliers" -- no limit. D7's arm stated
   20; the session states none now, at either kind of entrant. *)
procedure TContestNewEnglandQPTests.Test_NEQPHasNoDXMultiplierCap;
var
   inside: boolean;
   contestObject: TContestBase;
   session: TSessionDefaults;
begin
   BeginTest('Test_NEQPHasNoDXMultiplierCap');
   for inside := False to True do
      begin
      contestObject := Make(NEWENGLANDQSO);
      session := TSessionDefaults.Create;
      try
         contestObject.DescribeSession(Entrant(inside), session);
         CheckFalse(session.IsStated(svDXMultLimit),
                    'no DX multiplier limit (in New England: ' + BoolToStr(inside, True) + ')');
      finally
         session.Free;
         contestObject.Free;
      end;
      end;
end;

(* ---------------------------------------------------------------------------
   THE NEW ENGLAND ENTRANT'S DOMESTIC FILE
   --------------------------------------------------------------------------- *)

(* "Canadian provinces (14 -- VO1/VO2 are separate)": VO1 and VO2 are two
   multipliers, through the real loader and P14.DOM. And the sheet holds the
   rules' multipliers exactly: the 50 states and the 14 provinces -- the New
   England counties count as their states, and DC as Maryland, so neither
   adds one. *)
procedure TContestNewEnglandQPTests.Test_NEQPVO1AndVO2AreTwoProvinces;
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   BeginTest('Test_NEQPVO1AndVO2AreTwoProvinces');
   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   table := TDomQTHTable.Create;
   try
      CheckEquals(NEW_ENGLAND_ENTRANT_INCLUDES, LoadNewEnglandEntrantTable(table),
                  'neqsow1.dom includes the 50 states, then the 14 provinces');
      CheckEquals('NF', MultiplierOf(table, 'VO1'), 'VO1 is Newfoundland');
      CheckEquals('LB', MultiplierOf(table, 'VO2'), 'VO2 is Labrador');
      CheckTrue(MultiplierOf(table, 'VO1') <> MultiplierOf(table, 'VO2'),
                'VO1 and VO2 are separate multipliers');
      CheckEquals('ON', MultiplierOf(table, 'ON'), 'the other provinces are there');
      CheckEquals('ME', MultiplierOf(table, 'MEAND'), 'a New England county counts as its state');
      CheckEquals(50 + 14, mo.DomList.Count, 'the 50 states and the 14 provinces, and nothing else');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

(* "states(50) (Count DC as MD)": a received DC is the Maryland multiplier,
   and stays DC as the QTH -- so ADIF writes the worked station's own state,
   DC. *)
procedure TContestNewEnglandQPTests.Test_NEQPCountsDCAsMaryland;
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
   lines: TStringList;
   dcLine: integer;
   s50Line: integer;
   i: integer;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   BeginTest('Test_NEQPCountsDCAsMaryland');

   (* THE FILE SAYS SO, BEFORE S50: the first entry added for an alias wins,
      so DC's line must come before the states' file is included. *)
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'neqsow1.dom'));
      dcLine := -1;
      s50Line := -1;
      for i := 0 to lines.Count - 1 do
         begin
         if (dcLine < 0) and (Trim(lines[i]) = 'Dc > Md = DC') then
            begin
            dcLine := i;
            end;
         if (s50Line < 0) and (UpperCase(DomIncludeName(lines[i])) = 'S50.DOM') then
            begin
            s50Line := i;
            end;
         end;
      CheckTrue(dcLine >= 0, 'neqsow1.dom holds Dc > Md = DC');
      CheckTrue(s50Line >= 0, 'neqsow1.dom includes S50.DOM');
      CheckTrue(dcLine < s50Line, 'DC is mapped to MD before S50.DOM is included');
   finally
      lines.Free;
   end;

   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   table := TDomQTHTable.Create;
   try
      CheckEquals(NEW_ENGLAND_ENTRANT_INCLUDES, LoadNewEnglandEntrantTable(table),
                  'neqsow1.dom includes the 50 states, then the 14 provinces');
      CheckEquals('MD', MultiplierOf(table, 'DC'), 'DC counts as Maryland');
      CheckEquals('MD', MultiplierOf(table, 'MD'), 'and so does Maryland');
      CheckEquals('DC', QTHOf(table, 'DC'), 'the QTH stays DC');
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;

   contestObject := Make(NEWENGLANDQSO, Entrant(True));
   try
      qso := Default(ContestExchange);
      qso.QTHString := 'DC';
      qso.DomesticQTH := 'Dc';
      qso.DomMultQTH := 'Md';
      qso.QTH.CountryID := 'K';
      CheckEquals('DC', contestObject.ADIFWorkedStationState(qso),
                  'ADIF STATE is the station''s own, DC');
      qso.QTHString := 'VO1';
      qso.DomesticQTH := 'Nf';
      qso.DomMultQTH := 'Nf';
      qso.QTH.CountryID := 'VE';
      CheckEquals('NL', contestObject.ADIFWorkedStationState(qso),
                  'VO1 is ADIF''s NL -- ADIF has no NF');
      qso.QTHString := 'VO2';
      qso.DomesticQTH := 'Lb';
      qso.DomMultQTH := 'Lb';
      CheckEquals('NL', contestObject.ADIFWorkedStationState(qso),
                  'VO2 is ADIF''s NL -- ADIF has no LB');
   finally
      contestObject.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   DUPES
   --------------------------------------------------------------------------- *)

(* "the same station can be contacted on CW and SSB on each band for QSO
   points (digital QSOs are considered the same as CW)" -- through the real
   dupe sheet, counted by band and by mode as the contest's flags say. And
   the control: with no contest, digital and CW are separate, as they always
   were. *)
procedure TContestNewEnglandQPTests.Test_NEQPDigitalIsADupeOfCW;
var
   list: TCallsignsList;
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
   index: integer;
begin
   BeginTest('Test_NEQPDigitalIsADupeOfCW');
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   list := nil;
   try
      Settings.Qso.ByBand := True;
      Settings.Qso.ByMode := True;
      Contest := ContestHandleOf(NEWENGLANDQSO);

      list := TCallsignsList.Create;
      list.AddCallsign('W1AW', Digital, Band20, False);
      CheckTrue(list.CallsignIsDupe('W1AW', Band20, CW, index), 'NEQP: CW after digital is a dupe');
      CheckTrue(list.CallsignIsDupe('W1AW', Band20, Digital, index), 'NEQP: digital again is a dupe');
      CheckFalse(list.CallsignIsDupe('W1AW', Band20, Phone, index), 'NEQP: phone is another QSO');
      CheckFalse(list.CallsignIsDupe('W1AW', Band40, CW, index), 'NEQP: another band is another QSO');
      list.Free;

      list := TCallsignsList.Create;
      list.AddCallsign('W1AW', CW, Band20, False);
      CheckTrue(list.CallsignIsDupe('W1AW', Band20, Digital, index), 'NEQP: digital after CW is a dupe');
      CheckFalse(list.CallsignIsDupe('W1AW', Band20, FM, index), 'NEQP: FM is phone, another QSO');
      list.Free;

      CheckTrue(ContestDupeModeOf(ContestIdentity(NEWENGLANDQSO), Both) = Both, 'Both is a key');
      CheckTrue(ContestDupeModeOf(ContestIdentity(NEWENGLANDQSO), NoMode) = NoMode, 'NoMode is a key');
      CheckTrue(ContestDupeModeOf(nil, Digital) = Digital, 'no contest: digital is its own');

      (* THE CONTROL: no contest, so the base's rule. *)
      Contest := NoContest;
      list := TCallsignsList.Create;
      list.AddCallsign('W1AW', Digital, Band20, False);
      CheckFalse(list.CallsignIsDupe('W1AW', Band20, CW, index), 'no contest: CW after digital is new');
   finally
      list.Free;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
   end;
end;

(* THE RATCHET: every registered contest keeps each mode its own dupe mode,
   but the ones whose sponsor groups modes, listed by id. A contest that
   states DupeModeOf joins the list from the sponsor's text. *)
procedure TContestNewEnglandQPTests.Test_EveryOtherContestKeepsEachModeItsOwnDupeMode;
const
   (* "digital QSOs are considered the same as CW" -- the neqp.org FAQ. *)
   DIGITAL_IS_CW_FOR_DUPES = ' NEWEQP ';
var
   contests: TContestIdentityList;
   k: integer;
   m: ModeType;
   id: string;
   expected: ModeType;
begin
   BeginTest('Test_EveryOtherContestKeepsEachModeItsOwnDupeMode');
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      id := ContestId(HandleOf(contests[k]));
      for m := Low(ModeType) to High(ModeType) do
         begin
         expected := m;
         if (m = Digital) and (Pos(' ' + id + ' ', DIGITAL_IS_CW_FOR_DUPES) > 0) then
            begin
            expected := CW;
            end;
         CheckTrue(ContestDupeModeOf(contests[k], m) = expected,
                   ContestWho(contests[k]) + ': the dupe mode of mode ' + IntToStr(Ord(m)));
         end;
      end;
end;

(* ---------------------------------------------------------------------------
   ROVERS -- THROUGH THE REAL ENGINE
   --------------------------------------------------------------------------- *)

(* "Mobiles that change counties are considered to be new stations" and
   "can be worked for both multiplier and QSO Point credit"; "County line
   QSOs should be logged as two separate QSOs" (2026-10-23).

   AS LogContact DOES IT: ParametersOkay, the dupe question
   (VisibleLog.QSOIsADupe), the multiplier flags and both dupe sheets
   (AddQSOToDupeSheets), over the shipped county file this entrant loads --
   NEQSOW1 in New England (its counties count as their states), NEQSO
   outside (each county its own multiplier). The rover signs its BARE call,
   so only the received county can tell its QSOs apart. *)
procedure TContestNewEnglandQPTests.CheckRoverRule(aInNewEngland: boolean);
var
   savedContest: TContestHandle;
   savedQsoByBand: boolean;
   savedQsoByMode: boolean;
   savedMultByBand: boolean;
   savedMultByMode: boolean;
   savedDomesticByBand: TAdditionalMultByBand;
   savedInHostState: boolean;
   savedCounties: boolean;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedSheet: TMultsObject;
   savedCountries: TStringList;
   savedMyState: string;
   who: string;
   myState: string;
   domFile: string;
   ctyPath: string;
   rx: ContestExchange;
   accepted: boolean;
   dupe: boolean;
   i: integer;

   (* ONE QSO, AS AN OPERATOR ENTERS IT -- uTestContestGeorgiaQP's shape:
      ParametersOkay, then what LogContact does with the record it accepts.
      Returns whether it was a dupe. *)
   function Enter(const aCall: string; const aExch: string; aBand: BandType;
                  aMode: ModeType; out aAccepted: boolean;
                  var aRX: ContestExchange): boolean;
   begin
      aRX := Default(ContestExchange);
      ActiveMode := aMode;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      aAccepted := ParametersOkay(CallString(aCall), Str40(aExch), aBand, aMode,
                                  14025000, aRX);
      aRX.ceRecordKind := rkQSO;
      aRX.ceContest := Contest;
      Result := False;
      if aAccepted then
         begin
         Result := VisibleLog.QSOIsADupe(aRX);
         if Result then
            begin
            aRX.ceDupe := True;
            aRX.QSOPoints := 0;
            end;
         Sheet.SetMultFlags(aRX);
         Sheet.AddQSOToSheets(@aRX, False);
         AddQSOToDupeSheets(aRX, False);
         end;
   end;

begin
   if aInNewEngland then
      begin
      who := 'in New England: ';
      myState := 'ME';
      domFile := 'neqsow1.dom';
      end
   else
      begin
      who := 'outside New England: ';
      myState := 'KS';
      domFile := 'neqso.dom';
      end;

   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), who + 'cty.dat loads');

   savedContest := Contest;
   savedQsoByBand := Settings.Qso.ByBand;
   savedQsoByMode := Settings.Qso.ByMode;
   savedMultByBand := Settings.Mult.ByBand;
   savedMultByMode := Settings.Mult.ByMode;
   savedDomesticByBand := DomesticMultByBand;
   savedInHostState := StationInHostState;
   savedCounties := MultipliersIsCounties;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedSheet := mo;
   savedMyState := Settings.My.State;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;
   mo := TMultsObject.Create;
   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      (* AS FoundContest SETS IT UP: K, VE, KH6 and KL domestic, the
         entrant's county file (its INCLUDEs followed by the test -- see
         LoadShippedDomFollowingIncludes), and the class's flags -- QSOs by
         band and mode, multipliers once per contest. *)
      DomesticCountries.Clear;
      Add_KVEKH6KL;
      MultipliersIsCounties := False;
      StationInHostState := False;
      if aInNewEngland then
         begin
         CheckEquals(NEW_ENGLAND_ENTRANT_INCLUDES, LoadNewEnglandEntrantTable(DomQTHTable),
                     who + domFile + ' loads, with the states and the provinces');
         end
      else
         begin
         CheckEquals('', LoadShippedDomFollowingIncludes(DomQTHTable, domFile, True, 0),
                     who + domFile + ' loads, and includes nothing');
         end;
      Settings.My.State := myState;
      ClearContestSentState;
      Contest := ContestHandleOf(NEWENGLANDQSO);
      ReleaseActiveContest;
      CheckEquals(myState, SentMyState, who + 'precondition: MY STATE is the entrant''s');
      CheckTrue(ActiveContest(Contest).HasDXMultiplier = aInNewEngland,
                who + 'precondition: the class sees this entrant');
      Settings.Qso.ByBand := ContestIdentity(NEWENGLANDQSO).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(NEWENGLANDQSO).QSOByMode;
      Settings.Mult.ByBand := ContestIdentity(NEWENGLANDQSO).MultByBand;
      Settings.Mult.ByMode := ContestIdentity(NEWENGLANDQSO).MultByMode;
      DomesticMultByBand := dmbbDefauld;
      mo.ClearAllMults;

      (* A ROVER IN ANDROSCOGGIN, ITS BARE CALL. *)
      dupe := Enter('K1AR', '599 MEAND', Band20, CW, accepted, rx);
      CheckTrue(accepted, who + '599 MEAND is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, who + 'the first QSO is not a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), who + 'CW scores 2');
      CheckTrue(rx.DomesticMult, who + 'Androscoggin (or Maine) is a new multiplier');

      (* THE SAME ROVER IN CUMBERLAND: a new station. *)
      dupe := Enter('K1AR', '599 MECUM', Band20, CW, accepted, rx);
      CheckTrue(accepted, who + '599 MECUM is taken: ' + string(ExchangeErrorMessage));
      CheckFalse(dupe, who + 'the rover from a new county, same band and mode, is NOT a dupe');
      CheckEquals(2, Integer(rx.QSOPoints), who + 'and scores');
      if aInNewEngland then
         begin
         CheckFalse(rx.DomesticMult, who + 'but Maine is no new multiplier -- counted once');
         end
      else
         begin
         CheckTrue(rx.DomesticMult, who + 'and Cumberland is a new multiplier');
         end;

      (* THE SAME CALL, COUNTY, BAND AND MODE: a dupe. *)
      dupe := Enter('K1AR', '599 MEAND', Band20, CW, accepted, rx);
      CheckTrue(dupe, who + 'Androscoggin again on 20 m CW IS a dupe');
      CheckEquals(0, Integer(rx.QSOPoints), who + 'and scores 0');

      (* ANOTHER BAND: a new QSO, but no multiplier again -- once per contest. *)
      dupe := Enter('K1AR', '599 MEAND', Band40, CW, accepted, rx);
      CheckFalse(dupe, who + 'Androscoggin on 40 m is not a dupe');
      CheckFalse(rx.DomesticMult, who + 'and is no new multiplier -- once per contest');

      (* A COUNTY LINE, outside New England: one entry, two QSOs. Inside New
         England the exchange carries one QTH, so it is two entries -- the
         Cumberland QSO above. *)
      if not aInNewEngland then
         begin
         ClearPendingCounties;
         dupe := Enter('W1XX', '599 MEAND/MECUM', Band15, CW, accepted, rx);
         CheckTrue(accepted, who + 'a county line is taken: ' + string(ExchangeErrorMessage));
         CheckFalse(dupe, who + 'its first county is not a dupe');
         CheckEquals('MEAND', UpperCase(string(rx.QTHString)), who + 'the first county is this QSO');
         CheckEquals(1, PendingCountiesCount, who + 'the second is queued');
         CheckEquals('MECUM', UpperCase(DequeuePendingCounty), who + 'Cumberland');
         dupe := Enter('W1XX', '599 MECUM', Band15, CW, accepted, rx);
         CheckFalse(dupe, who + 'the second county of the line is its own QSO, not a dupe');
         CheckEquals(2, Integer(rx.QSOPoints), who + 'and scores');
         ClearPendingCounties;
         end;
   finally
      DomesticCountries.Clear;
      for i := 0 to savedCountries.Count - 1 do
         begin
         DomesticCountries.Add(CallString(savedCountries[i]));
         end;
      savedCountries.Free;
      ClearPendingCounties;
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      DomQTHTable.Free;
      DomQTHTable := savedTable;
      mo.Free;
      mo := savedSheet;
      CallWindowString := savedCallWindow;
      ActiveMode := savedActiveMode;
      MultipliersIsCounties := savedCounties;
      StationInHostState := savedInHostState;
      DomesticMultByBand := savedDomesticByBand;
      Settings.Mult.ByMode := savedMultByMode;
      Settings.Mult.ByBand := savedMultByBand;
      Settings.Qso.ByMode := savedQsoByMode;
      Settings.Qso.ByBand := savedQsoByBand;
      Settings.My.State := savedMyState;
      ClearContestSentState;
      ExchangeErrorMessage := '';
      Contest := savedContest;
      ReleaseActiveContest;
   end;
end;

procedure TContestNewEnglandQPTests.Test_NEQPRoverInANewCountyIsANewStation;
begin
   BeginTest('Test_NEQPRoverInANewCountyIsANewStation');
   CheckTrue(ContestDupeKeyIncludesReceivedQTH(ContestIdentity(NEWENGLANDQSO)),
             'the received QTH is part of New England''s dupe key');
   CheckRoverRule(True);
   CheckRoverRule(False);
end;

procedure TContestNewEnglandQPTests.RunAllTests;
begin
   Test_NEQPDigitalScoresAsCW;
   Test_NEQPHasNoDXMultiplierCap;
   Test_NEQPVO1AndVO2AreTwoProvinces;
   Test_NEQPCountsDCAsMaryland;
   Test_NEQPDigitalIsADupeOfCW;
   Test_EveryOtherContestKeepsEachModeItsOwnDupeMode;
   Test_NEQPRoverInANewCountyIsANewStation;
end;

end.
