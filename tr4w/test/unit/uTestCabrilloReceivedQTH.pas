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

(* THE RECEIVED QTH ON A CABRILLO QSO LINE, WHEN THE CONTEST SAYS "LITERAL
  DOMESTIC QTH" -- issue #109, 2026-10-26.

  THE DEFECT. Fifteen contests (then) stated LiteralDomesticQTH in DescribeSession,
  and FCONTEST writes that statement into Settings.Contest.LiteralDomesticQth.
  The Cabrillo writer read LOGDOM's old global instead, which nothing had
  written since 2026-09-12, so the received column printed the domestic
  multiplier the QTH RESOLVED to rather than what was logged.

  THE CASES ARE REAL, read from the shipped files rather than invented:
    * NAQP (naqp.dom): a typed ON resolves to "vE3" (the VE call area is the
      multiplier's key, lower-case first letter and all); a typed CT, through
      the INCLUDEd s48.dom, to "Ct".
    * PACC, Dutch entrant (paccpa.dom): a typed GR resolves to "Gr".
  So each test also proves the two strings DIFFER -- a case where they agree
  could not tell the old code from the new.

  UBA DOES NOT CHANGE: every key in uba.dom is its own alias (AAA = AAA, ...),
  so the resolved QTH is the typed text and both readings print the same
  thing. A non-Dutch PACC entrant states no literal QTH, so its column is the
  resolved one before and after.

  THE FLAG IS APPLIED AS FCONTEST APPLIES IT: the contest's DescribeSession
  statement copied into the setting. ApplySessionDefaults itself is FCONTEST's
  implementation and writes dozens of globals; this copies the one value it
  is about. *)
unit uTestCabrilloReceivedQTH;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework,
   VC,              (* ContestType -- ExportedQTH's parameter *)
   uContestBase;

type
   TCabrilloReceivedQTHTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure CheckLiteralQTH(aContest: TContestBase;
                                const aStation: TStationContext;
                                const aWho: string;
                                const aDomFile: string;
                                const aTyped: string);
      function ExportedQTH(aContest: ContestType;
                           const aSessionName: string;
                           aOperatorStatesOff: boolean;
                           out aCountsDomesticMultiplier: boolean): string;
      procedure Test_NAQPWritesTheTypedQTH;
      procedure Test_PACCDutchEntrantWritesTheTypedQTH;
      procedure Test_WithoutTheFlagTheResolvedQTHIsWritten;
      procedure Test_NoContestIsNamedInTheWriter;
      procedure Test_AnOperatorsLiteralOffWinsForTheRFCupsAndLABRE;
   end;

implementation

uses
   SysUtils,
   uSettingsModel,
   uContestRegistry,
   LogDom,
   PostUnit,
   uTestContestObjects,
   uTestContestKindPin,
   uTestShippedDom;

function KansasStation(const aContestName: string): TStationContext;
begin
   Result := MatrixStation('K0AAA', 'K', NorthAmerica, 'KS', 'KS', 'EM17',
                           False, aContestName);
end;

function DutchStation: TStationContext;
begin
   Result := MatrixStation('PA3AAA', 'PA', Europe, '', 'DX', 'JO22',
                           False, 'PACC');
end;

(* The DomQTH aFile gives aTyped -- what live entry stores as DomesticQTH. *)
function ResolvedQTH(const aFile: string; const aTyped: string): string;
var
   table: TDomQTHTable;
   entry: TDomQTHEntry;
begin
   Result := '';
   table := TDomQTHTable.Create;
   try
      LoadShippedDomFollowingIncludes(table, aFile, True, 0);
      if table.FindAlias(aTyped, entry) then
         begin
         Result := string(entry.DomQTH);
         end;
   finally
      table.Free;
      end;
end;

(* aContest at aStation states LITERAL DOMESTIC QTH, the typed text resolves
  to something else in aDomFile, and the Cabrillo column is the typed text. *)
procedure TCabrilloReceivedQTHTests.CheckLiteralQTH(aContest: TContestBase;
                                                     const aStation: TStationContext;
                                                     const aWho: string;
                                                     const aDomFile: string;
                                                     const aTyped: string);
var
   stated: TSessionDefaults;
   qso: ContestExchange;
   resolved: string;
   savedLiteral: boolean;
   savedName: string;
   savedContest: TContestHandle;
begin
   resolved := ResolvedQTH(aDomFile, aTyped);
   CheckTrue(resolved <> '', aWho + ': ' + aDomFile + ' knows ' + aTyped);
   CheckTrue(resolved <> aTyped,
             aWho + ': ' + aTyped + ' resolves to something else (' + resolved +
             ') -- otherwise this case cannot tell the readings apart');

   savedLiteral := Settings.Contest.LiteralDomesticQth;
   savedName := Settings.Contest.Name;
   savedContest := Contest;
   stated := TSessionDefaults.Create;
   try
      aContest.DescribeSession(aStation, stated);
      CheckTrue(stated.IsStated(svLiteralDomesticQTH) and stated.LiteralDomesticQTH,
                aWho + ': the contest states LITERAL DOMESTIC QTH');

      (* AS FCONTEST.ApplySessionDefaults WRITES IT. The writer names no
        contest since 2026-11-20; the name and contest are set so that a
        name test, came one back, could not decide this case. *)
      Settings.Contest.LiteralDomesticQth := stated.LiteralDomesticQTH;
      Settings.Contest.Name := aWho;
      Contest := NoContest;

      qso := Default(ContestExchange);
      qso.QTHString := Str10(aTyped);
      qso.DomesticQTH := Str10(resolved);
      CheckTrue(ContestHasDomesticMultiplier(aContest),
                aWho + ': counts a domestic multiplier');
      CheckEquals(aTyped, CabrilloReceivedQTH(ContestHasDomesticMultiplier(aContest), qso),
                  aWho + ': the Cabrillo column is what was logged, not ' + resolved);
   finally
      stated.Free;
      Settings.Contest.LiteralDomesticQth := savedLiteral;
      Settings.Contest.Name := savedName;
      Contest := savedContest;
      end;
end;

procedure TCabrilloReceivedQTHTests.Test_NAQPWritesTheTypedQTH;
const
   RUNNINGS: array[0..2] of ContestType = (NAQSOCW, NAQSOSSB, NAQSORTTY);
var
   i: integer;
   station: TStationContext;
   obj: TContestBase;
   who: string;
begin
   BeginTest('Test_NAQPWritesTheTypedQTH');
   for i := Low(RUNNINGS) to High(RUNNINGS) do
      begin
      who := ContestId(ContestHandleOf(RUNNINGS[i]));
      station := KansasStation(who);
      obj := MakeContestOrNil(RUNNINGS[i], station);
      try
         CheckLiteralQTH(obj, station, who, 'naqp.dom', 'ON');
         CheckLiteralQTH(obj, station, who, 'naqp.dom', 'CT');
      finally
         obj.Free;
         end;
      end;
end;

procedure TCabrilloReceivedQTHTests.Test_PACCDutchEntrantWritesTheTypedQTH;
var
   station: TStationContext;
   obj: TContestBase;
begin
   BeginTest('Test_PACCDutchEntrantWritesTheTypedQTH');
   station := DutchStation;
   obj := MakeContestOrNil(PACC, station);
   try
      CheckLiteralQTH(obj, station, 'PACC', 'paccpa.dom', 'GR');
   finally
      obj.Free;
      end;
end;

(* D7's other branch, kept: with the flag off, a domestic contest writes the
  multiplier the QTH resolved to, and a contest with no domestic multiplier
  writes what was logged. *)
procedure TCabrilloReceivedQTHTests.Test_WithoutTheFlagTheResolvedQTHIsWritten;
var
   qso: ContestExchange;
   savedLiteral: boolean;
   savedName: string;
   savedContest: TContestHandle;
begin
   BeginTest('Test_WithoutTheFlagTheResolvedQTHIsWritten');
   savedLiteral := Settings.Contest.LiteralDomesticQth;
   savedName := Settings.Contest.Name;
   savedContest := Contest;
   try
      Settings.Contest.LiteralDomesticQth := False;
      Settings.Contest.Name := 'NAQP-CW';
      Contest := NoContest;
      qso := Default(ContestExchange);
      qso.QTHString := 'ON';
      qso.DomesticQTH := 'vE3';
      CheckEquals('vE3', CabrilloReceivedQTH(True, qso),
                  'no flag, a domestic multiplier: the resolved QTH');
      CheckEquals('ON', CabrilloReceivedQTH(False, qso),
                  'no domestic multiplier: what was logged');
   finally
      Settings.Contest.LiteralDomesticQth := savedLiteral;
      Settings.Contest.Name := savedName;
      Contest := savedContest;
      end;
end;

(* THE WRITER'S CHOICE FOR ONE CONTEST, WITH ITS SESSION DEFAULTS APPLIED AS
  FCONTEST APPLIES THEM: the flag starts at its default (off), the contest's
  DescribeSession statement is copied in only when it states one, the
  session's name is aSessionName, and the operator may then state LITERAL
  DOMESTIC QTH = FALSE, as a later .cfg or log line would. The QSO's typed and
  resolved QTHs differ, so the answer says which reading was taken. *)
function TCabrilloReceivedQTHTests.ExportedQTH(aContest: ContestType;
                                               const aSessionName: string;
                                               aOperatorStatesOff: boolean;
                                               out aCountsDomesticMultiplier: boolean): string;
var
   obj: TContestBase;
   station: TStationContext;
   stated: TSessionDefaults;
   qso: ContestExchange;
   savedLiteral: boolean;
   savedName: string;
   savedContest: TContestHandle;
begin
   Result := '';
   aCountsDomesticMultiplier := False;
   savedLiteral := Settings.Contest.LiteralDomesticQth;
   savedName := Settings.Contest.Name;
   savedContest := Contest;
   station := KansasStation(aSessionName);
   obj := MakeContestOrNil(aContest, station);
   stated := TSessionDefaults.Create;
   try
      CheckTrue(obj <> nil, aSessionName + ': the contest has a class');
      if obj = nil then
         begin
         Exit;
         end;
      Settings.Contest.LiteralDomesticQth := False;
      obj.DescribeSession(station, stated);
      if stated.IsStated(svLiteralDomesticQTH) then
         begin
         Settings.Contest.LiteralDomesticQth := stated.LiteralDomesticQTH;
         end;
      Settings.Contest.Name := aSessionName;
      Contest := ContestHandleOf(aContest);
      if aOperatorStatesOff then
         begin
         Settings.Contest.LiteralDomesticQth := False;
         end;

      qso := Default(ContestExchange);
      qso.QTHString := 'TYPED';
      qso.DomesticQTH := 'RSLVD';
      aCountsDomesticMultiplier := ContestHasDomesticMultiplier(obj);
      Result := CabrilloReceivedQTH(aCountsDomesticMultiplier, qso);
   finally
      stated.Free;
      obj.Free;
      Settings.Contest.LiteralDomesticQth := savedLiteral;
      Settings.Contest.Name := savedName;
      Contest := savedContest;
      end;
end;

(* NO CONTEST IS NAMED IN THE WRITER (2026-11-20). CabrilloReceivedQTH forced
  the logged text for the session NAMES 'LABRE' and 'EURASIA' and for
  `Contest in [CUPRFCW, CUPRFSSB]`. With those arms deleted, each contest's
  own answer gives the same column: LABRE and the RF Cups state LITERAL
  DOMESTIC QTH, and the European VHF contest -- which EURASIA is, renamed by
  CONTEST NAME -- counts no domestic multiplier, so the logged text is written
  whatever the flag says. *)
procedure TCabrilloReceivedQTHTests.Test_NoContestIsNamedInTheWriter;
var
   counts: boolean;
begin
   BeginTest('Test_NoContestIsNamedInTheWriter');
   CheckEquals('TYPED', ExportedQTH(LABRE, 'LABRE', False, counts),
               'LABRE: the logged QTH, as the name arm wrote it');
   CheckTrue(counts, 'LABRE counts a domestic multiplier (brazil.dom)');

   CheckEquals('TYPED', ExportedQTH(CUPRFCW, 'CUPRFCW', False, counts),
               'RF Cup CW: the logged QTH, as the enum arm wrote it');
   CheckTrue(counts, 'RF Cup CW counts a domestic multiplier');
   CheckEquals('TYPED', ExportedQTH(CUPRFSSB, 'CUPRFSSB', False, counts),
               'RF Cup SSB: the logged QTH, as the enum arm wrote it');
   CheckTrue(counts, 'RF Cup SSB counts a domestic multiplier');
   CheckEquals('TYPED', ExportedQTH(CUPRFDIG, 'CUPRFDIG', False, counts),
               'RF Cup DIG: the logged QTH (never in the arm; its own statement)');

   CheckEquals('TYPED', ExportedQTH(EUROPEANVHF, 'EURASIA', False, counts),
               'EURASIA: the logged QTH, as the name arm wrote it');
   CheckFalse(counts,
              'European VHF counts no domestic multiplier -- why EURASIA needs no statement');
   CheckEquals('TYPED', ExportedQTH(EUROPEANVHF, 'EUROPEAN VHF', False, counts),
               'European VHF under its own name: the logged QTH, as before');
end;

(* THE ONE CHANGE, AND IT IS THE RULE EVERY OTHER CONTEST ALREADY HAD: an
  operator who states LITERAL DOMESTIC QTH = FALSE after the contest's own
  statement is obeyed. The arms overrode him for LABRE and the RF Cups. *)
procedure TCabrilloReceivedQTHTests.Test_AnOperatorsLiteralOffWinsForTheRFCupsAndLABRE;
var
   counts: boolean;
begin
   BeginTest('Test_AnOperatorsLiteralOffWinsForTheRFCupsAndLABRE');
   CheckEquals('RSLVD', ExportedQTH(CUPRFCW, 'CUPRFCW', True, counts),
               'RF Cup CW, operator off: the resolved multiplier');
   CheckEquals('RSLVD', ExportedQTH(CUPRFSSB, 'CUPRFSSB', True, counts),
               'RF Cup SSB, operator off: the resolved multiplier');
   CheckEquals('RSLVD', ExportedQTH(LABRE, 'LABRE', True, counts),
               'LABRE, operator off: the resolved multiplier');
end;

procedure TCabrilloReceivedQTHTests.RunAllTests;
begin
   Test_NAQPWritesTheTypedQTH;
   Test_PACCDutchEntrantWritesTheTypedQTH;
   Test_WithoutTheFlagTheResolvedQTHIsWritten;
   Test_NoContestIsNamedInTheWriter;
   Test_AnOperatorsLiteralOffWinsForTheRFCupsAndLABRE;
end;

end.
