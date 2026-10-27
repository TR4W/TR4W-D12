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

(* THE STATE-PARTY BASE'S SHARED HELPERS, tested on the base itself.

  SentLocation and LocationOrOwnCountry (2026-10-26): a DX entrant sends its
  own country where its sponsor says so -- lifted from the North Dakota QSO
  Party when the Oklahoma QSO Party became its second user. They are
  PROTECTED helpers a party calls, so the test reaches them through a probe
  class that states only the abstract host state and is never registered (no
  registry walk sees it). Each user's own test pins the outcome through its
  CQ exchange, Cabrillo and ADIF columns; this one pins the rule itself,
  once, so a change to it is seen here by name.

  ReportNoTableForYear (2026-10-26): a year-table rule's once-per-year
  Error, lifted from the Idaho and Nebraska QSO Parties when the New Mexico
  QSO Party became its third user. Each user's own test pins its outcome
  through its BonusPoints; this pins the latch and the two messages.

  DXCCKeyExceptUSACanadaHawaiiAlaska and DXCCCountryMode (2026-10-26): the
  DXCC multiplier key and list seven parties carried word for word, lifted
  when the Ontario QSO Party became the seventh. Each party's test pins
  which of its entrants count; this pins the key and the list. *)
unit uTestContestStateQSOPartyBase;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestStateQSOPartyBaseTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_ADXEntrantSendsItsOwnCountry;
      procedure Test_AYearWithNoTableIsReportedOncePerYear;
      procedure Test_ADXCCKeyIsEveryCountryButKVEKH6KL;
   end;

implementation

uses
   SysUtils,
   Log4D,
   VC,
   uContestBase,
   uContestStateQSOPartyBase,
   uTestContestObjects,
   uTestLogCapture;

type
   (* A PARTY WITH NOTHING OF ITS OWN BUT A HOST STATE (abstract on the base)
      and a display name for the report's text, exposing the protected
      helpers. Never registered. *)
   TSentLocationProbe = class(TContestStateQSOPartyBase)
   protected
      function GetHostState: string; override;
      function GetDisplayName: string; override;
   public
      function Location(const aLocation: string; const aCountry: CallString): string;
      function Sent(const aMy: TMyStationExchange): TMyStationExchange;
      procedure Report(aLogger: TLogLogger; aYear: integer);
      function DXKey(aCounts: boolean; const aCountryID: string; out aKey: string): boolean;
      function DXMode(aCounts: boolean): CountryModeType;
   end;

function TSentLocationProbe.DXKey(aCounts: boolean; const aCountryID: string; out aKey: string): boolean;
var
   qso: ContestExchange;
   key: DXMultiplierString;
begin
   qso := Default(ContestExchange);
   qso.QTH.CountryID := ShortString(aCountryID);
   key := 'JUNK';
   Result := DXCCKeyExceptUSACanadaHawaiiAlaska(aCounts, qso, key);
   aKey := string(key);
end;

function TSentLocationProbe.DXMode(aCounts: boolean): CountryModeType;
begin
   Result := DXCCCountryMode(aCounts);
end;

function TSentLocationProbe.GetHostState: string;
begin
   Result := 'XX';
end;

function TSentLocationProbe.GetDisplayName: string;
begin
   Result := 'Probe QSO Party';
end;

procedure TSentLocationProbe.Report(aLogger: TLogLogger; aYear: integer);
begin
   ReportNoTableForYear(aLogger, aYear, 'probe table', 'the probe bonus', 'probe.example');
end;

function TSentLocationProbe.Location(const aLocation: string; const aCountry: CallString): string;
begin
   Result := LocationOrOwnCountry(aLocation, aCountry);
end;

function TSentLocationProbe.Sent(const aMy: TMyStationExchange): TMyStationExchange;
begin
   Result := SentLocation(aMy);
end;

function StationOf(const aMyState: string; const aCountry: string): TStationContext;
begin
   Result := NoStation;
   Result.MyState := aMyState;
   Result.MyCountry := CallString(aCountry);
end;

(* A STATION THAT STATES A LOCATION SENDS IT AS STATED; ONE THAT STATES NONE
   SENDS ITS OWN COUNTRY. "Stated" is "not blank": a MY STATE of spaces is
   none. The stated text is passed through untouched -- not trimmed, not
   upper-cased -- because the column helpers format it. SentLocation changes
   MY STATE and nothing else in the sent exchange, and asks the object's
   Station for the country. *)
procedure TContestStateQSOPartyBaseTests.Test_ADXEntrantSendsItsOwnCountry;
var
   probe: TSentLocationProbe;
   my: TMyStationExchange;
   sent: TMyStationExchange;
begin
   BeginTest('Test_ADXEntrantSendsItsOwnCountry');
   probe := TSentLocationProbe.Create(NoContest);
   try
      CheckEquals('MUS', probe.Location('MUS', 'K'), 'a county is sent as stated');
      CheckEquals('MN', probe.Location('MN', 'K'), 'a state is sent as stated');
      CheckEquals('ON', probe.Location('ON', 'VE'), 'a province is sent as stated');
      CheckEquals('DL', probe.Location('', 'DL'), 'none stated: the own country');
      CheckEquals('DL', probe.Location('   ', 'DL'), 'blanks are none');
      CheckEquals('KP4', probe.Location('', 'KP4'),
                  'a US possession sends its prefix too ("DX stations (including KH2/KP4)")');
      CheckEquals('MN', probe.Location('MN', 'DL'),
                  'a stated location is never replaced by the country');
      CheckEquals(' mn', probe.Location(' mn', 'K'), 'passed through untouched');
      CheckEquals('', probe.Location('', ''), 'nothing stated and no country: nothing');

      (* THE EXPORT FORM: MY STATE filled from the object's Station. *)
      probe.SetStation(StationOf('', 'DL'));
      my := Default(TMyStationExchange);
      my.MyState := '';
      my.MyGrid := 'JO62';
      my.MyName := 'HANS';
      sent := probe.Sent(my);
      CheckEquals('DL', sent.MyState, 'a DX entrant''s sent MY STATE is its country');
      CheckEquals('JO62', sent.MyGrid, 'nothing else changes: the grid');
      CheckEquals('HANS', sent.MyName, 'nor the name');

      my.MyState := 'MUS';
      sent := probe.Sent(my);
      CheckEquals('MUS', sent.MyState, 'a stated MY STATE is kept, whatever the station''s country');

      probe.SetStation(StationOf('MUS', 'K'));
      my.MyState := '';
      sent := probe.Sent(my);
      CheckEquals('K', sent.MyState,
                  'the EXCHANGE''s MY STATE decides, the station''s country fills it');
   finally
      probe.Free;
   end;
end;

(* A YEAR-TABLE RULE WITH NO TABLE FOR THE LOG'S YEAR SAYS SO, ONCE PER YEAR
   PER OBJECT: one Error naming the contest, the year, what is left out of
   the score, where the table comes from and the unit to add it to; asked
   again for that year, nothing; another year, another line; year 0 (a log
   with no year) its own text. A second object has its own latch. Written to
   the logger the caller hands in. *)
procedure TContestStateQSOPartyBaseTests.Test_AYearWithNoTableIsReportedOncePerYear;
var
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   probe: TSentLocationProbe;
   other: TSentLocationProbe;
begin
   BeginTest('Test_AYearWithNoTableIsReportedOncePerYear');
   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('uTestContestStateQSOPartyBase.Probe');
   savedLevel := lg.Level;
   lg.Level := Log4D.Error;
   lg.AddAppender(keep);
   probe := TSentLocationProbe.Create(NoContest);
   other := TSentLocationProbe.Create(NoContest);
   try
      probe.Report(lg, 2031);
      CheckEquals(1, capture.Lines.Count, 'a year with no table is reported');
      (* A substring: the appender's layout may frame the message. *)
      CheckTrue(Pos('Probe QSO Party: TR4W has no probe table for the 2031 contest, so the probe bonus ' +
                    'is NOT in the score. Each year''s probe table is the sponsor''s (probe.example) ' +
                    'and is added to uTestContestStateQSOPartyBase.', capture.Line(0)) > 0,
                'the contest, the year, the rule, the source and the unit: ' + capture.Line(0));

      probe.Report(lg, 2031);
      probe.Report(lg, 2031);
      CheckEquals(1, capture.Lines.Count, 'once per year, however often the score is asked');

      probe.Report(lg, 2032);
      CheckEquals(2, capture.Lines.Count, 'another year is reported again');
      CheckTrue(Pos('2032', capture.Line(1)) > 0, 'naming it: ' + capture.Line(1));

      probe.Report(lg, 0);
      CheckEquals(3, capture.Lines.Count, 'a log with no year is reported');
      CheckTrue(Pos('Probe QSO Party: the log records no contest year (no start time and no dated QSO), ' +
                    'so the probe bonus cannot be decided and is NOT in the score.', capture.Line(2)) > 0,
                'as such: ' + capture.Line(2));

      other.Report(lg, 2031);
      CheckEquals(4, capture.Lines.Count, 'a second object has its own latch');
   finally
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      other.Free;
      probe.Free;
   end;
end;

(* THE DXCC KEY SEVEN PARTIES SHARE (Delaware, Florida, Nebraska, New Mexico,
   Oklahoma, Texas, Ontario): where the party counts one, the worked
   station's CTY country, unless it is the USA, Canada, Hawaii or Alaska --
   those are states and provinces in these parties; US possessions (KP4,
   KH2) and every other country are DX. Where it counts none, no key and an
   empty one written over whatever was there. The list is DXCC (ARRL) where
   it counts, the CQ list where not. Each party's own test pins who counts. *)
procedure TContestStateQSOPartyBaseTests.Test_ADXCCKeyIsEveryCountryButKVEKH6KL;
var
   probe: TSentLocationProbe;
   key: string;
begin
   BeginTest('Test_ADXCCKeyIsEveryCountryButKVEKH6KL');
   probe := TSentLocationProbe.Create(NoContest);
   try
      CheckTrue(probe.DXKey(True, 'DL', key), 'Germany is a DX multiplier');
      CheckEquals('DL', key, 'keyed by its CTY country');
      CheckTrue(probe.DXKey(True, 'JA', key), 'Japan is');
      CheckEquals('JA', key, 'keyed JA');
      CheckTrue(probe.DXKey(True, 'KP4', key), 'Puerto Rico is DX, not a state');
      CheckEquals('KP4', key, 'keyed KP4');
      CheckTrue(probe.DXKey(True, 'KH2', key), 'and Guam');
      CheckTrue(probe.DXKey(True, 'XE', key), 'and Mexico');
      CheckFalse(probe.DXKey(True, 'K', key), 'the USA is no DX multiplier');
      CheckEquals('', key, 'and the key is written empty');
      CheckFalse(probe.DXKey(True, 'VE', key), 'nor Canada');
      CheckEquals('', key, 'empty');
      CheckFalse(probe.DXKey(True, 'KH6', key), 'nor Hawaii');
      CheckFalse(probe.DXKey(True, 'KL', key), 'nor Alaska');
      CheckFalse(probe.DXKey(False, 'DL', key), 'a party that counts none: no key for Germany');
      CheckEquals('', key, 'and the key is written empty');
      CheckTrue(probe.DXMode(True) = ARRLCountryMode, 'counted on the DXCC (ARRL) list');
      CheckTrue(probe.DXMode(False) = CQCountryMode, 'the CQ list where none is counted');
   finally
      probe.Free;
   end;
end;

procedure TContestStateQSOPartyBaseTests.RunAllTests;
begin
   Test_ADXEntrantSendsItsOwnCountry;
   Test_AYearWithNoTableIsReportedOncePerYear;
   Test_ADXCCKeyIsEveryCountryButKVEKH6KL;
end;

end.
