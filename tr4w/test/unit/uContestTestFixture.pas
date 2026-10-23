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

(* A CONTEST THAT EXISTS ONLY IN THE UNIT-TEST PROGRAM -- Q108 S3, 2026-10-17
  (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u).

  IT REGISTERS BY ITS STRING ID AND HAS NO ContestType MEMBER, which is the
  whole point: it is the first contest the registry knows that the frozen
  enum does not, so the seal, the handle above the legacy range, the name
  resolver, the New Contest choices, the CONTEST vocabulary and every
  registry walk of S1 meet one in the unit tests -- and must pass. S4's
  refusals and broadcast number are proved through it too.

  NEVER LINKED INTO THE APPLICATION. It lives under tr4w/test/unit, which no
  program but the test one names; Lint-ContestUnitsLinked fails the build if
  tr4w.lpr ever lists it, uTestContestById.Test_TheFixtureIsNotInTheApplication
  reads tr4w.lpr for it, and the contest matrix refuses a run whose
  application lists its id. IT IS ALSO THE SUBJECT OF S4's TESTS: a contest
  with no legacy number is refused at every multi-op door and gets a derived
  <contestnr> (uTestContestById, uTestUDPDatagrams). A real contest may
  register by id since S4 (2026-10-17).

  ITS RULES ARE A SIMPLE SERIAL-NUMBER CONTEST'S (RST + serial, one point a
  QSO, every band), stated in full as any contest states them -- a contest
  rule has no inherited default, and uTestContestStatesItsRules walks this
  class too. *)
unit uContestTestFixture;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC, uContestBase;

const
   (* ITS ID. A test reads it from here; nothing else spells it. *)
   TEST_FIXTURE_CONTEST_ID = 'TR4W-TEST-FIXTURE';

type
   TContestTestFixture = class(TContestBase)
   protected
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;
      function ParseReceivedExchangeFormat(const aText: string;
                                           aParsers: TExchangeParsers;
                                           var aExch: ContestExchange): boolean; override;
      procedure WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters); override;
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* ITS BANDS AND MODES -- a contest that registers by id states both
         from its first commit (Q98 S1, Test_EveryContestStatesItsBandsAndModes):
         160-10 m without WARC, CW and phone. *)
      function UsesBand(aBand: BandType): boolean; override;
      function UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry, uContestFixedPoints;

procedure TContestTestFixture.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestTestFixture.GetDisplayName: string;
begin
   Result := 'TR4W Test Fixture (unit tests only)';
end;

function TContestTestFixture.GetCabrilloName: string;
begin
   Result := TEST_FIXTURE_CONTEST_ID;
end;

function TContestTestFixture.GetADIFContestId: string;
begin
   Result := TEST_FIXTURE_CONTEST_ID;
end;

function TContestTestFixture.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestTestFixture.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestTestFixture.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestTestFixture.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestTestFixture.GetFriendlyName: string;
begin
   Result := 'TR4W Test Fixture (unit tests only)';
end;

function TContestTestFixture.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestTestFixture.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberExchange;
end;

function TContestTestFixture.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumber;
end;

function TContestTestFixture.ParseReceivedExchangeFormat(const aText: string;
                                                         aParsers: TExchangeParsers;
                                                         var aExch: ContestExchange): boolean;
begin
   Result := aParsers.ParseRSTQSONumber(aText, aExch);
end;

procedure TContestTestFixture.WriteDefaultExchangeMessages(aMessages: TExchangeMessageWriters);
begin
   aMessages.WriteRSTQSONumber;
end;

function TContestTestFixture.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                 const aQso: ContestExchange): string;
begin
   Result := ADIFSentRSTQSONumber(aMy, aQso);
end;

function TContestTestFixture.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentRSTQSONumber(aMy, aQso, aCtx);
end;

function TContestTestFixture.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedRSTQSONumber(aMy, aQso, aCtx);
end;

function TContestTestFixture.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfMultByBand];
end;

function TContestTestFixture.GetIsUSQSOParty: boolean;
begin
   Result := False;
end;

function TContestTestFixture.UsesBand(aBand: BandType): boolean;
begin
   Result := aBand in [Band160, Band80, Band40, Band20, Band15, Band10];
end;

function TContestTestFixture.UsesMode(aMode: ModeType; aExtMode: ExtendedModeType): boolean;
begin
   Result := aMode in [CW, Phone];
end;

initialization
   RegisterContestById(TEST_FIXTURE_CONTEST_ID, TContestTestFixture);

end.
