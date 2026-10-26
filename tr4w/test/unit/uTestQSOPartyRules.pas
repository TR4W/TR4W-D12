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
   VC;

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

implementation

uses
   SysUtils,
   uSettingsModel,
   uMults,
   uCallsigns,
   uContestBase,
   uContestRegistry,
   LogDom,
   LogEdit,
   (* Contest, the session's contest. *)
   PostUnit,
   uTestContestObjects,
   uTestShippedDom;

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

end.
