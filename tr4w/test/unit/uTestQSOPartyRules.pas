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

(* WHAT A QSO PARTY'S TESTS ASK ABOUT ITS MULTIPLIERS AND ITS DUPES -- #88
  round 3 (2026-10-26). Shared by the party test units that round wrote
  (Indiana, Michigan, Ohio, Tennessee, Texas, Virginia, the Salmon Run,
  North Carolina, the 7QP, Delaware and IN7QPNE), so the questions are asked
  one way and cannot drift. Each answer comes from the REAL thing: the
  shipped in-state .dom through the real loader (uTestShippedDom), the
  class's own CountsAsMultiplier, and the dupe path LogContact takes
  (VisibleLog.QSOIsADupe, AddQSOToDupeSheets).

  EACH TAKES A HANDLE TOO (2026-10-26, the North Dakota QSO Party): a
  contest registered by its id has no ContestType member. The handle form
  is the one body; the ContestType form is it through ContestHandleOf. *)
unit uTestQSOPartyRules;

{$I ..\..\src\tr4w.inc}

interface

uses
   (* TStrings -- ShippedCountyKeys. *)
   Classes,
   VC,
   (* TDomQTHTable -- CountyTable's type. *)
   LogDom;

(* THE MULTIPLIER aContest's IN-STATE FILE GIVES aAlias -- upper case, ''
   when the file does not know it. The file is the class's own
   InStateDomesticFileName, loaded with its INCLUDEs. *)
function InStateMultiplierOf(aContest: ContestType; const aAlias: string): string; overload;
function InStateMultiplierOf(aContest: TContestHandle; const aAlias: string): string; overload;

(* DOES aContest COUNT aMultiplier (a QSO's DomMultQTH) AS A MULTIPLIER OF
   aKind for an entrant in its host state (aInState) or outside it? The
   class's own CountsAsMultiplier, through the nil-safe seam SetMultFlags
   asks. *)
function CountsForEntrant(aContest: ContestType; aInState: boolean;
                          const aMultiplier: string;
                          aKind: RemainingMultiplierType): boolean; overload;
function CountsForEntrant(aContest: TContestHandle; aInState: boolean;
                          const aMultiplier: string;
                          aKind: RemainingMultiplierType): boolean; overload;

(* A ROVER'S BARE CALL, WORKED IN aFirstQTH ON 20 m CW, THEN IN aSecondQTH,
   THEN IN aFirstQTH AGAIN, all on 20 m CW, through the dupe path LogContact
   takes, with fresh dupe sheets and aContest the session's contest. The
   answers: is the new county a dupe, is the first county again a dupe.
   The record carries the QTH as the parse leaves it (QTHString and the
   resolved DomesticQTH). *)
procedure RoverDupeAnswers(aContest: ContestType;
                           const aCall: string;
                           const aFirstQTH: string;
                           const aSecondQTH: string;
                           out aNewCountyIsDupe: boolean;
                           out aSameCountyIsDupe: boolean); overload;
procedure RoverDupeAnswers(aContest: TContestHandle;
                           const aCall: string;
                           const aFirstQTH: string;
                           const aSecondQTH: string;
                           out aNewCountyIsDupe: boolean;
                           out aSameCountyIsDupe: boolean); overload;

(* THE HOST'S SHIPPED COUNTY FILE, THROUGH THE REAL LOADER -- as an
   out-of-state entrant's session loads it (aCountiesAreMultipliers True,
   FCONTEST's MultipliersIsCounties) or as an in-state entrant reads the
   same file (False) -- with a multiplier sheet of its own, so the load
   touches nothing another test reads. While it is loaded, CountyTable is
   the table and CountyFileKnowsQTH the TDomesticQTHTest a party's host-area
   rule and the rover strip are handed (FindAlias, the table's exact
   lookup). Pair every LoadCountyTable with FreeCountyTable in a finally; a
   second load before the free raises.

   LIFTED 2026-10-26 (the Quebec QSO Party, #128) from the North Dakota,
   Oklahoma, New Mexico and Ontario tests, which carried it word for word but
   for the file name; Quebec would have been the fifth copy. *)
procedure LoadCountyTable(const aCountyFileName: string; aCountiesAreMultipliers: boolean);
procedure FreeCountyTable;
function CountyTable: TDomQTHTable;
function CountyFileKnowsQTH(const aQTH: string): boolean;

(* An entered QSO through ParametersOkay and the real dupe/multiplier
   sheets. Returns whether the accepted QSO was a dupe. Shared by all party
   tests; the no-submode overload preserves the radio-derived default. *)
function EnterPartyQSO(const aCall, aExch: string; aBand: BandType;
   aMode: ModeType; aExtMode: ExtendedModeType;
   out aAccepted: boolean; var aRX: ContestExchange): boolean; overload;
function EnterPartyQSO(const aCall, aExch: string; aBand: BandType;
   aMode: ModeType; out aAccepted: boolean;
   var aRX: ContestExchange): boolean; overload;

(* THE CABRILLO RECEIVED COLUMN OF aRX AS THE WRITER BUILDS IT -- review H4
   and M5 follow-up, 2026-11-16: HisQTH from PostUnit.CabrilloReceivedQTH
   (LITERAL DOMESTIC QTH off, restored after), RST 599, the column of
   ActiveContest(aContest) -- the object that holds the session's station --
   upper-cased as PostUnit upper-cases it. A party test asks this rather than
   hand-setting HisQTH: a hand-set HisQTH hid the empty column of a typed DX
   country. *)
function PartyReceivedCabrilloColumn(aContest: TContestHandle;
   const aRX: ContestExchange): string;

type
   THostStateCodes = array of string;

(* THE CODES A STATE PARTY'S HostState NAMES -- blank-separated, upper-cased,
   empty words dropped: 'GA' gives one, 'AB SK MB' (the Canadian Prairies,
   issue 117) three. The registry walks that hold every party's host
   (uTestContestFactory, uTestContestExport) read it one way. *)
function HostStateCodes(const aHostState: string): THostStateCodes;

(* IS aCode ONE OF ADIF'S PRIMARY SUBDIVISIONS FOR A NORTH AMERICAN QSO
   PARTY'S HOST -- the USA, Alaska, Hawaii or Canada? *)
function IsADIFHostStateCode(const aCode: string): boolean;

(* IS EVERY CODE OF aHostState A CANADIAN PROVINCE OR TERRITORY? -- a
   Canadian host writes no ADIF CNTY. False for an empty host. *)
function HostIsCanadian(const aHostState: string): boolean;

(* THE KEYS OF aFileName in the tree's target/dom (uTestContestObjects.
   ShippedDomDir) LONGER THAN TWO LETTERS -- what the party base takes for a
   county; INCLUDE lines and a missing file give none. aKeys is cleared. *)
procedure ShippedCountyKeys(const aFileName: string; aKeys: TStrings);

implementation

uses
   SysUtils, LogWind, LogStuff, MainUnit,
   uSettingsModel,
   uMults,
   uCallsigns,
   uContestBase,
   uContestRegistry,
   (* ActiveContest -- PartyReceivedCabrilloColumn's object with the station. *)
   uContestFactory,
   LogEdit,
   (* Contest, the session's contest. *)
   PostUnit,
   uTestContestObjects,
   uTestShippedDom,
   (* IsADIFPrimarySubdivision -- IsADIFHostStateCode, HostIsCanadian. *)
   uADIF,
   (* DomFileLineKey -- ShippedCountyKeys. *)
   uDomFileKeys;

function InStateMultiplierOf(aContest: ContestType; const aAlias: string): string;
begin
   Result := InStateMultiplierOf(ContestHandleOf(aContest), aAlias);
end;

function InStateMultiplierOf(aContest: TContestHandle; const aAlias: string): string;
var
   savedSheet: TMultsObject;
   savedCounties: boolean;
   table: TDomQTHTable;
begin
   (* AS uTestContestMissouriQP LOADS ITS FILE: a sheet and the county flag
      of its own, so the load touches nothing another test reads. *)
   savedSheet := mo;
   savedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := False;
   table := TDomQTHTable.Create;
   try
      LoadShippedDomFollowingIncludes(table,
                                      ContestIdentity(aContest).InStateDomesticFileName + '.dom',
                                      True, 0);
      Result := MultiplierOf(table, aAlias);
   finally
      table.Free;
      mo.Free;
      mo := savedSheet;
      MultipliersIsCounties := savedCounties;
   end;
end;

function CountsForEntrant(aContest: ContestType; aInState: boolean;
                          const aMultiplier: string;
                          aKind: RemainingMultiplierType): boolean;
begin
   Result := CountsForEntrant(ContestHandleOf(aContest), aInState, aMultiplier, aKind);
end;

function CountsForEntrant(aContest: TContestHandle; aInState: boolean;
                          const aMultiplier: string;
                          aKind: RemainingMultiplierType): boolean;
var
   station: TStationContext;
   contestObject: TContestBase;
   qso: ContestExchange;
begin
   station := WithHostAreaTable(NoStation);
   station.InHostState := aInState;
   contestObject := Make(aContest, station);
   try
      qso := Default(ContestExchange);
      qso.ceRecordKind := rkQSO;
      qso.Callsign := 'K9ABC';
      qso.Band := Band20;
      qso.Mode := CW;
      qso.ExtMode := eCW;
      qso.QTHString := ShortString(aMultiplier);
      qso.DomesticQTH := ShortString(aMultiplier);
      qso.DomMultQTH := ShortString(aMultiplier);
      Result := ContestCountsMultiplier(contestObject, qso, aKind);
   finally
      contestObject.Free;
   end;
end;

procedure RoverDupeAnswers(aContest: ContestType;
                           const aCall: string;
                           const aFirstQTH: string;
                           const aSecondQTH: string;
                           out aNewCountyIsDupe: boolean;
                           out aSameCountyIsDupe: boolean);
begin
   RoverDupeAnswers(ContestHandleOf(aContest), aCall, aFirstQTH, aSecondQTH,
                    aNewCountyIsDupe, aSameCountyIsDupe);
end;

procedure RoverDupeAnswers(aContest: TContestHandle;
                           const aCall: string;
                           const aFirstQTH: string;
                           const aSecondQTH: string;
                           out aNewCountyIsDupe: boolean;
                           out aSameCountyIsDupe: boolean);
var
   savedContest: TContestHandle;
   savedByBand: boolean;
   savedByMode: boolean;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;

   function Worked(const aQTH: string): ContestExchange;
   begin
      Result := Default(ContestExchange);
      Result.ceRecordKind := rkQSO;
      Result.ceContest := Contest;
      Result.Callsign := CallString(aCall);
      Result.Band := Band20;
      Result.Mode := CW;
      Result.ExtMode := eCW;
      Result.QTHString := ShortString(aQTH);
      Result.DomesticQTH := ShortString(aQTH);
   end;

begin
   savedContest := Contest;
   savedByBand := Settings.Qso.ByBand;
   savedByMode := Settings.Qso.ByMode;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;
   try
      Contest := aContest;
      Settings.Qso.ByBand := ContestIdentity(aContest).QSOByBand;
      Settings.Qso.ByMode := ContestIdentity(aContest).QSOByMode;

      (* THE FIRST COUNTY, LOGGED. *)
      AddQSOToDupeSheets(Worked(aFirstQTH), False);

      (* THE NEW COUNTY: asked, then logged. *)
      aNewCountyIsDupe := VisibleLog.QSOIsADupe(Worked(aSecondQTH));
      AddQSOToDupeSheets(Worked(aSecondQTH), False);

      (* THE FIRST COUNTY AGAIN. *)
      aSameCountyIsDupe := VisibleLog.QSOIsADupe(Worked(aFirstQTH));
   finally
      QualifiedDupes.Free;
      QualifiedDupes := savedQualified;
      CallsignsList.Free;
      CallsignsList := savedList;
      Settings.Qso.ByMode := savedByMode;
      Settings.Qso.ByBand := savedByBand;
      Contest := savedContest;
   end;
end;

(* THE LOADED COUNTY FILE -- see the declaration. *)
var
   GCountyTable: TDomQTHTable;
   GSavedSheet: TMultsObject;
   GSavedCounties: boolean;

procedure LoadCountyTable(const aCountyFileName: string; aCountiesAreMultipliers: boolean);
begin
   if GCountyTable <> nil then
      begin
      raise Exception.Create('LoadCountyTable(' + aCountyFileName
                             + ') while a county table is loaded: FreeCountyTable first');
      end;
   GSavedSheet := mo;
   GSavedCounties := MultipliersIsCounties;
   mo := TMultsObject.Create;
   MultipliersIsCounties := aCountiesAreMultipliers;
   GCountyTable := TDomQTHTable.Create;
   try
      LoadShippedDomFollowingIncludes(GCountyTable, aCountyFileName, True, 0);
   except
      (* A missing file must not leave the sheet swapped: the caller's
         finally is not yet entered. *)
      FreeCountyTable;
      raise;
   end;
end;

procedure FreeCountyTable;
begin
   GCountyTable.Free;
   GCountyTable := nil;
   mo.Free;
   mo := GSavedSheet;
   MultipliersIsCounties := GSavedCounties;
end;

function CountyTable: TDomQTHTable;
begin
   Result := GCountyTable;
end;

(* FindAlias is the table's exact lookup; its keys are stored upper-cased. *)
function CountyFileKnowsQTH(const aQTH: string): boolean;
var
   entry: TDomQTHEntry;
begin
   Result := (GCountyTable <> nil) and
             GCountyTable.FindAlias(UpperCase(Trim(aQTH)), entry);
end;

function EnterPartyQSO(const aCall, aExch: string; aBand: BandType;
   aMode: ModeType; aExtMode: ExtendedModeType;
   out aAccepted: boolean; var aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   aRX.ExtMode := aExtMode;
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

function EnterPartyQSO(const aCall, aExch: string; aBand: BandType;
   aMode: ModeType; out aAccepted: boolean;
   var aRX: ContestExchange): boolean;
begin
   Result := EnterPartyQSO(aCall, aExch, aBand, aMode, eNoMode, aAccepted, aRX);
end;

function PartyReceivedCabrilloColumn(aContest: TContestHandle;
   const aRX: ContestExchange): string;
var
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   savedLiteral: boolean;
begin
   savedLiteral := Settings.Contest.LiteralDomesticQth;
   try
      Settings.Contest.LiteralDomesticQth := False;
      my := Default(TMyStationExchange);
      ctx := Default(TCabrilloQSOContext);
      ctx.RSTSent := '599';
      ctx.RSTReceived := '599';
      ctx.HisQTH := CabrilloReceivedQTH(True, aRX);
      Result := UpperCase(ActiveContest(aContest).FormatCabrilloReceivedExchange(my, aRX, ctx));
   finally
      Settings.Contest.LiteralDomesticQth := savedLiteral;
   end;
end;

function HostStateCodes(const aHostState: string): THostStateCodes;
var
   rest: string;
   code: string;
   p: integer;
begin
   Result := nil;
   rest := UpperCase(Trim(aHostState)) + ' ';
   while rest <> '' do
      begin
      p := Pos(' ', rest);
      code := Copy(rest, 1, p - 1);
      rest := Copy(rest, p + 1, Length(rest));
      if code <> '' then
         begin
         SetLength(Result, Length(Result) + 1);
         Result[High(Result)] := code;
         end;
      end;
end;

function IsADIFHostStateCode(const aCode: string): boolean;
begin
   Result := (Length(aCode) = 2) and
             (IsADIFPrimarySubdivision('K', aCode)   or
              IsADIFPrimarySubdivision('KL', aCode)  or
              IsADIFPrimarySubdivision('KH6', aCode) or
              IsADIFPrimarySubdivision('VE', aCode));
end;

function HostIsCanadian(const aHostState: string): boolean;
var
   codes: THostStateCodes;
   i: integer;
begin
   codes := HostStateCodes(aHostState);
   Result := Length(codes) > 0;
   for i := 0 to High(codes) do
      begin
      if not IsADIFPrimarySubdivision('VE', codes[i]) then
         begin
         Result := False;
         end;
      end;
end;

procedure ShippedCountyKeys(const aFileName: string; aKeys: TStrings);
var
   lines: TStringList;
   key: string;
   i: integer;
begin
   aKeys.Clear;
   if not FileExists(ShippedDomDir + aFileName) then
      begin
      Exit;
      end;
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ShippedDomDir + aFileName));
      for i := 0 to lines.Count - 1 do
         begin
         key := DomFileLineKey(string(lines[i]));
         if Length(key) > 2 then
            begin
            aKeys.Add(AnsiString(key));
            end;
         end;
   finally
      lines.Free;
   end;
end;

end.
