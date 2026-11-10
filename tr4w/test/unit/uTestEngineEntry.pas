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

(* AN EXCHANGE THROUGH THE REAL ENGINE, AS AN OPERATOR ENTERS IT -- the
  session set-up a test needs to call MainUnit.ParametersOkay with a shipped
  .dom loaded.

  LIFTED, UNCHANGED, out of uTestExchangeWordOrder (2026-11-10, issue 13)
  when uTestARRLSectionAlias became its second user. One copy, so a change to
  what a parse reads is made once.

  NOT REENTRANT: one saved set, as before. Every SetUpSession is paired with
  a RestoreSession in a finally, and they do not nest.

  uTestFieldDaySectionRefusal keeps its own copy on purpose: it switches the
  contest inside a loop and loads the file through LoadInDomQTHFile without
  following INCLUDEs, so it is not the same set-up.

  A UNIT THAT USES THIS PUTS IT LAST in its uses clause, so these names win
  over anything of the same name in the engine units. *)
unit uTestEngineEntry;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC;

(* ONE EXCHANGE, AS AN OPERATOR ENTERS IT -- ParametersOkay alone; no QSO is
   logged. 20 m CW, 14.025 MHz. *)
function Enter(const aCall: string; const aExch: string; var aRX: ContestExchange): boolean;

(* THE SESSION AS FoundContest SETS aContest UP, for what a parse reads: the
   contest, its domestic countries, its domestic file in the table and named
   in the setting, and a station in the USA. *)
procedure SetUpSession(aContest: ContestType; const aCountries: array of string;
                       const aDomFile: string);

(* Everything SetUpSession saved, put back. *)
procedure RestoreSession;

(* target\cty.dat, beside the test binary's tree. *)
function LoadCountryFile: boolean;

implementation

uses
   (* Settings. Nothing here names a type it shares with VC. *)
   uSettingsModel,
   Classes,
   SysUtils,
   uCallsigns,
   uCTYDAT,
   uContestFactory,
   uContestRegistry,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   LogDupe,
   LogDom,
   LogWind,
   LogStuff,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   MainUnit;

var
   (* What each test saves and puts back: the engine state ParametersOkay
      reads. One set, because the tests run one after another. *)
   savedContest: TContestHandle;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedMyCountry: string;
   savedDomesticFilename: string;

function Enter(const aCall: string; const aExch: string; var aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   ActiveMode := CW;
   CallWindowString := CallString(aCall);
   ExchangeErrorMessage := '';
   Result := ParametersOkay(CallString(aCall), Str40(aExch), Band20, CW,
                            14025000, aRX);
end;

procedure SetUpSession(aContest: ContestType; const aCountries: array of string;
                       const aDomFile: string);
var
   i: integer;
begin
   savedContest := Contest;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;

   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;

   DomesticCountries.Clear;
   for i := Low(aCountries) to High(aCountries) do
      begin
      DomesticCountries.Add(CallString(aCountries[i]));
      end;
   LoadShippedDomFollowingIncludes(DomQTHTable, aDomFile, True, 0);
   Settings.Contest.DomesticFilename := aDomFile;
   Settings.My.DeriveCountry('K');

   Contest := ContestHandleOf(aContest);
   ReleaseActiveContest;
end;

procedure RestoreSession;
var
   i: integer;
begin
   DomesticCountries.Clear;
   for i := 0 to savedCountries.Count - 1 do
      begin
      DomesticCountries.Add(CallString(savedCountries[i]));
      end;
   savedCountries.Free;
   QualifiedDupes.Free;
   QualifiedDupes := savedQualified;
   CallsignsList.Free;
   CallsignsList := savedList;
   DomQTHTable.Free;
   DomQTHTable := savedTable;
   CallWindowString := savedCallWindow;
   ActiveMode := savedActiveMode;
   Settings.Contest.DomesticFilename := savedDomesticFilename;
   Settings.My.DeriveCountry(savedMyCountry);
   ExchangeErrorMessage := '';
   ExchangeErrorToken := '';
   Contest := savedContest;
   ReleaseActiveContest;
end;

function LoadCountryFile: boolean;
var
   ctyPath: string;
begin
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   Result := ctyLoadInCountryFile(ctyPath, False, False, True);
end;

end.
