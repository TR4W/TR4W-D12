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

(* THE ENGINE'S PARSERS, STUBBED -- M11 S9d, 2026-10-15.

  A contest calls the engine's parser for its format by name
  (uContestBase.TExchangeParsers). The real ones are LOGSTUFF's and read the
  engine's tables, so they cannot link into this binary; the tests hand this
  stub instead. Every method does one thing: hands its own NAME, the text and
  the exchange to the behaviour the test installed, and answers what it says.
  So a test sees WHICH parser a contest asked for, by the name a reader of the
  class sees, and decides what that parser "did".

  ONE STUB, SHARED. Until S9d uTestContestParse, uTestContestDelawareQP and
  uTestContestIN7QPNE each held a private copy of a function stub of the old
  machine (StubParseShape), and uTestExchangeParse would have been the
  fourth. Each now installs its own behaviour here.

  The instance is this unit's and lives for the run; StubExchangeParsers
  installs a behaviour and hands it back. Main thread only, as the tests
  are. *)
unit uTestExchangeParserStub;

{$I ..\..\src\tr4w.inc}

interface

uses
   VC,
   uContestBase;

type
   (* What a stubbed parser does: aHelper is the parser asked for, by its
      method name ('ParseRSTZone'). *)
   TStubParseBehaviour = function(const aHelper: string; const aText: string;
                                  var aExch: ContestExchange): boolean;

(* The stub, with aBehaviour installed. Not to be freed by the caller. *)
function StubExchangeParsers(aBehaviour: TStubParseBehaviour): TExchangeParsers;

implementation

uses
   SysUtils;

type
   TStubExchangeParsers = class(TExchangeParsers)
   private
      FBehaviour: TStubParseBehaviour;
      function Answer(const aHelper: string; const aText: string;
                      var aExch: ContestExchange): boolean;
   public
      function ParseAgeAndQSONumber(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseClassDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseGrid(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseGrid2(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseKidsDay(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseNZFieldDay(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseNameAndDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseNameAndPossibleGridSquare(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseNameQTHAndPossibleTenTenNumber(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndCoordinatesSum(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndGeoCoordinates(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndGridSquare(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndName(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndPreviousQSONumber(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberAndZone(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberNameChapterAndQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberNameDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseQSONumberPrecedenceCheckDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTALLJAPrefectureAndPrecedence(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAge(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAgeAndPossibleSK(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndContinent(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndGrid(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndGridSquareOrRDA(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndOrGrid(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndPOTAPark(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndPostalCode(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndQSONumberOrDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTAndQSONumberOrFrenchDepartment(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTDomesticQTHOrQSONumber(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTLongJAPrefecture(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTNameAndQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTPossibleDomesticQTHAndPower(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTPower(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTPrefecture(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQSONumber(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQSONumberAndDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQSONumberAndGridSquare(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQSONumberAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQSONumberAndRandomCharacters(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTQTHNameAndFistsNumberOrPower(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTZone(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTZoneAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTZoneOrDomesticQTH(const aText: string; var aExch: ContestExchange): boolean; override;
      function ParseRSTZoneOrSociety(const aText: string; var aExch: ContestExchange): boolean; override;
   end;

var
   GStub: TStubExchangeParsers;

function StubExchangeParsers(aBehaviour: TStubParseBehaviour): TExchangeParsers;
begin
   if GStub = nil then
      begin
      GStub := TStubExchangeParsers.Create;
      end;
   GStub.FBehaviour := aBehaviour;
   Result := GStub;
end;

function TStubExchangeParsers.Answer(const aHelper: string; const aText: string;
                                     var aExch: ContestExchange): boolean;
begin
   if not Assigned(FBehaviour) then
      begin
      raise Exception.Create('uTestExchangeParserStub: no behaviour installed');
      end;
   Result := FBehaviour(aHelper, aText, aExch);
end;

function TStubExchangeParsers.ParseAgeAndQSONumber(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseAgeAndQSONumber', aText, aExch);
end;

function TStubExchangeParsers.ParseClassDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseClassDomesticOrDXQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseGrid(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseGrid', aText, aExch);
end;

function TStubExchangeParsers.ParseGrid2(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseGrid2', aText, aExch);
end;

function TStubExchangeParsers.ParseKidsDay(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseKidsDay', aText, aExch);
end;

function TStubExchangeParsers.ParseNZFieldDay(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseNZFieldDay', aText, aExch);
end;

function TStubExchangeParsers.ParseNameAndDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseNameAndDomesticOrDXQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseNameAndPossibleGridSquare(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseNameAndPossibleGridSquare', aText, aExch);
end;

function TStubExchangeParsers.ParseNameQTHAndPossibleTenTenNumber(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseNameQTHAndPossibleTenTenNumber', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndCoordinatesSum(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndCoordinatesSum', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndGeoCoordinates(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndGeoCoordinates', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndGridSquare(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndGridSquare', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndName(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndName', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndPossibleDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndPreviousQSONumber(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndPreviousQSONumber', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberAndZone(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberAndZone', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberDomesticOrDXQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberNameChapterAndQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberNameChapterAndQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberNameDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberNameDomesticOrDXQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseQSONumberPrecedenceCheckDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseQSONumberPrecedenceCheckDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTALLJAPrefectureAndPrecedence(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTALLJAPrefectureAndPrecedence', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAge(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAge', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAgeAndPossibleSK(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAgeAndPossibleSK', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndContinent(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndContinent', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndGrid(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndGrid', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndGridSquareOrRDA(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndGridSquareOrRDA', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndOrGrid(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndOrGrid', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndPOTAPark(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndPOTAPark', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndPostalCode(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndPostalCode', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndQSONumberOrDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndQSONumberOrDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTAndQSONumberOrFrenchDepartment(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTAndQSONumberOrFrenchDepartment', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTDomesticOrDXQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTDomesticOrDXQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTDomesticQTHOrQSONumber(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTDomesticQTHOrQSONumber', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTLongJAPrefecture(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTLongJAPrefecture', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTNameAndQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTNameAndQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTPossibleDomesticQTHAndPower(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTPossibleDomesticQTHAndPower', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTPower(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTPower', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTPrefecture(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTPrefecture', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQSONumber(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQSONumber', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQSONumberAndDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQSONumberAndDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQSONumberAndGridSquare(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQSONumberAndGridSquare', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQSONumberAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQSONumberAndPossibleDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQSONumberAndRandomCharacters(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQSONumberAndRandomCharacters', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTQTHNameAndFistsNumberOrPower(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTQTHNameAndFistsNumberOrPower', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTZone(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTZone', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTZoneAndPossibleDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTZoneAndPossibleDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTZoneOrDomesticQTH(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTZoneOrDomesticQTH', aText, aExch);
end;

function TStubExchangeParsers.ParseRSTZoneOrSociety(const aText: string; var aExch: ContestExchange): boolean;
begin
   Result := Answer('ParseRSTZoneOrSociety', aText, aExch);
end;

initialization

finalization
   FreeAndNil(GStub);

end.
