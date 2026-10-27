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
  once, so a change to it is seen here by name. *)
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
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestStateQSOPartyBase,
   uTestContestObjects;

type
   (* A PARTY WITH NOTHING OF ITS OWN BUT A HOST STATE (abstract on the base),
      exposing the two protected helpers. Never registered. *)
   TSentLocationProbe = class(TContestStateQSOPartyBase)
   protected
      function GetHostState: string; override;
   public
      function Location(const aLocation: string; const aCountry: CallString): string;
      function Sent(const aMy: TMyStationExchange): TMyStationExchange;
   end;

function TSentLocationProbe.GetHostState: string;
begin
   Result := 'XX';
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

procedure TContestStateQSOPartyBaseTests.RunAllTests;
begin
   Test_ADXEntrantSendsItsOwnCountry;
end;

end.
