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

(* THE WORDS OF AN EXCHANGE IN ANOTHER ORDER -- 2026-11-04.

  Three issues brought over from the D7 tracker, each about an operator
  typing the exchange's words in an order the parser did not expect:

  * #174 (TR4W#460) -- Sweepstakes: the precedence BEFORE the serial, in one
    word ('80 WCF U123' as well as '80 WCF 123U').
  * #170 (TR4W#417) -- NA Sprint: the state first ('FL TOM 4'). Reported in
    D7 as a QTH of 'FLM' and no domestic QTH; the parser has since lost its
    pointers. This pins what it does now.
  * #169 (TR4W#416) -- NAQP: the state and the name in either order
    ('FL TOM' as well as 'TOM FL').

  THROUGH THE REAL ENGINE, as uTestFieldDaySectionRefusal does: ParametersOkay,
  with the shipped domestic file in the table and the domestic countries the
  contest's DescribeSession states. Not in uTestExchangeParse, whose parsers
  are a stub on purpose -- these defects live inside the engine's parsers,
  which a stub cannot reach.

  EVERY ENTRY THAT WAS TAKEN BEFORE IS PINNED BESIDE THE NEW ONE, with the
  same fields, so a reading that changes for a good entry fails here. *)
unit uTestExchangeWordOrder;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TExchangeWordOrderTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_SweepstakesPrecedenceBeforeTheSerial;
      procedure Test_SprintStateBeforeTheName;
      procedure Test_NAQPStateAndNameInEitherOrder;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   (* mo -- the multiplier sheet's store. *)
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit;

var
   (* What each test saves and puts back: the engine state ParametersOkay
      reads. One set, because the three tests run one after another. *)
   savedContest: TContestHandle;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedMyCountry: string;
   savedDomesticFilename: string;

(* ONE EXCHANGE, AS AN OPERATOR ENTERS IT -- ParametersOkay alone; no QSO is
   logged. *)
function Enter(const aCall: string; const aExch: string; var aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   ActiveMode := CW;
   CallWindowString := CallString(aCall);
   ExchangeErrorMessage := '';
   Result := ParametersOkay(CallString(aCall), Str40(aExch), Band20, CW,
                            14025000, aRX);
end;

(* THE SESSION AS FoundContest SETS aContest UP, for what a parse reads: the
   contest, its domestic countries, its domestic file in the table and named
   in the setting, and a station in the USA. *)
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

(* ---------------------------------------------------------------------------
   #174 -- SWEEPSTAKES
   --------------------------------------------------------------------------- *)

procedure TExchangeWordOrderTests.Test_SweepstakesPrecedenceBeforeTheSerial;
var
   rx: ContestExchange;
   accepted: boolean;

   procedure CheckTaken(const aExch: string; aNumber: integer; aPrec: AnsiChar;
                        aCheck: integer; const aSection: string);
   begin
      accepted := Enter('W1AW', aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aNumber, Integer(rx.NumberReceived), aExch + ': the serial');
      CheckEquals(string(aPrec), string(rx.Precedence), aExch + ': the precedence');
      CheckEquals(aCheck, Integer(rx.Check), aExch + ': the check');
      CheckEquals(aSection, string(rx.QTHString), aExch + ': the section');
   end;

begin
   BeginTest('Test_SweepstakesPrecedenceBeforeTheSerial');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* THE ORDERS TAKEN BEFORE, unchanged. *)
      CheckTaken('80 WCF 123U', 123, 'U', 80, 'WCF');
      CheckTaken('123 U 80 WCF', 123, 'U', 80, 'WCF');
      CheckTaken('123U 80WCF', 123, 'U', 80, 'WCF');

      (* 'U80WCF 123' IS REFUSED THROUGH LIVE ENTRY, before and after
         #174, though the word reader takes 'A99CT 123'
         (uTestContestParse.Test_SweepstakesWordReading). Pinned so the
         mismatch is seen; the word goes in the callsign. *)
      accepted := Enter('W1AW', 'U80WCF 123', rx);
      CheckFalse(accepted, 'U80WCF 123: refused through live entry');
      CheckEquals('U80WCF', string(rx.Callsign), 'U80WCF 123: the packed word is read as a callsign');

      (* THE ISSUE'S ENTRY: the precedence first, joined to the serial. *)
      CheckTaken('80 WCF U123', 123, 'U', 80, 'WCF');
      CheckTaken('U123 80 WCF', 123, 'U', 80, 'WCF');
      CheckTaken('80 WCF A5', 5, 'A', 80, 'WCF');
      CheckTaken('80 WCF Q1234', 1234, 'Q', 80, 'WCF');
   finally
      RestoreSession;
   end;
end;

(* ---------------------------------------------------------------------------
   #170 -- NA SPRINT
   --------------------------------------------------------------------------- *)

procedure TExchangeWordOrderTests.Test_SprintStateBeforeTheName;
var
   rx: ContestExchange;
   accepted: boolean;

   procedure CheckTaken(const aExch: string; aNumber: integer;
                        const aName: string; const aQTH: string);
   begin
      accepted := Enter('N4AF', aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aNumber, Integer(rx.NumberReceived), aExch + ': the serial');
      CheckEquals(aName, string(rx.Name), aExch + ': the name');
      CheckEquals(aQTH, string(rx.QTHString), aExch + ': the QTH, and nothing of the name in it');
      CheckEquals(aQTH, UpperCase(string(rx.DomMultQTH)), aExch + ': the multiplier');
      CheckTrue(rx.DomesticQTH <> '', aExch + ': the domestic QTH is set');

      (* AND IT IS A DOMESTIC MULTIPLIER -- the issue's "Domestic Exchange is
         not set" -- on an empty sheet, as LogContact would ask. *)
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      mo.ClearAllMults;
      Sheet.SetMultFlags(rx);
      CheckTrue(rx.DomesticMult, aExch + ': a new domestic multiplier');
   end;

begin
   BeginTest('Test_SprintStateBeforeTheName');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   (* NASprintCW.DescribeSession: K and VE, then KL; its file is naqp. *)
   SetUpSession(NASPRINTCW, ['K', 'VE', 'KL'], 'naqp.dom');
   try
      (* THE REPORTER'S CONTROL: "ALAN FL 3 ... showed up ok". *)
      CheckTaken('ALAN FL 3', 3, 'ALAN', 'FL');
      CheckTaken('3 ALAN FL', 3, 'ALAN', 'FL');
      (* THE REPORTED ENTRY: "FL TOM 4 ... showed as FLM". *)
      CheckTaken('FL TOM 4', 4, 'TOM', 'FL');
      CheckTaken('4 FL TOM', 4, 'TOM', 'FL');
   finally
      mo.ClearAllMults;
      RestoreSession;
   end;
end;

(* ---------------------------------------------------------------------------
   #169 -- NAQP
   --------------------------------------------------------------------------- *)

procedure TExchangeWordOrderTests.Test_NAQPStateAndNameInEitherOrder;
var
   rx: ContestExchange;
   accepted: boolean;

   procedure CheckTaken(const aCall: string; const aExch: string;
                        const aName: string; const aQTH: string);
   begin
      accepted := Enter(aCall, aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aName, string(rx.Name), aExch + ': the name');
      CheckEquals(aQTH, string(rx.QTHString), aExch + ': the QTH');
   end;

begin
   BeginTest('Test_NAQPStateAndNameInEitherOrder');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   (* NAQPCW.DescribeSession: K, VE, KH6, KL; its file is naqp. *)
   SetUpSession(NAQSOCW, DomesticCountriesKVEKH6KL, 'naqp.dom');
   try
      (* THE NAME FIRST, as always. *)
      CheckTaken('N4AF', 'TOM FL', 'TOM', 'FL');
      CheckEquals('FL', UpperCase(string(rx.DomMultQTH)), 'TOM FL: the multiplier');

      (* THE STATE FIRST -- the issue. *)
      CheckTaken('N4AF', 'FL TOM', 'TOM', 'FL');
      CheckEquals('FL', UpperCase(string(rx.DomMultQTH)), 'FL TOM: the multiplier');
      CheckTrue(rx.DomesticQTH <> '', 'FL TOM: the domestic QTH is set');
      CheckTaken('N4AF', 'ON BOB', 'BOB', 'ON');

      (* A NAME THAT IS ALSO A QTH ("Del in DE or Cal in CA"): where both
         readings are a QTH, the name is first, as it always was. Only where
         the name-first reading has no QTH is the other order tried. *)
      CheckTaken('N4AF', 'DE CA', 'DE', 'CA');
      CheckTaken('N4AF', 'CA DE', 'CA', 'DE');
      CheckTaken('N4AF', 'DE TOM', 'TOM', 'DE');
      CheckTaken('N4AF', 'AL WI', 'AL', 'WI');

      (* A DX STATION HAS NO QTH TO JUDGE, so its words are read name first
         whatever they are -- unchanged. *)
      CheckTaken('DL1AAA', 'HANS', 'HANS', '');
      CheckTaken('DL1AAA', 'FL TOM', 'FL', 'TOM');

      (* STILL REFUSED. *)
      accepted := Enter('N4AF', 'TOM XX', rx);
      CheckFalse(accepted, 'TOM XX: no QTH either way');
      CheckEquals('XX', string(rx.QTHString), 'TOM XX: the refusal is the second word''s, as before');
      accepted := Enter('N4AF', 'XX TOM', rx);
      CheckFalse(accepted, 'XX TOM: no QTH either way');
      CheckEquals('TOM', string(rx.QTHString), 'XX TOM: the refusal is the second word''s, as before');
      accepted := Enter('N4AF', 'FL', rx);
      CheckFalse(accepted, 'FL alone: a QTH and no name');
      (* A NAME IS LETTERS: a QTH and a number is no name and a state --
         the contest matrix's 'CT 123' and 'CT 2A' rows, refused before. *)
      accepted := Enter('N4AF', 'CT 123', rx);
      CheckFalse(accepted, 'CT 123: 123 is no name');
      CheckEquals('123', string(rx.QTHString), 'CT 123: refused for the second word, as before');
      accepted := Enter('N4AF', 'CT 2A', rx);
      CheckFalse(accepted, 'CT 2A: 2A is no name');
      accepted := Enter('N4AF', 'FL TOM BOB', rx);
      CheckFalse(accepted, 'FL TOM BOB: a third word is a corrected name, and TOM is no QTH');
   finally
      RestoreSession;
   end;
end;

procedure TExchangeWordOrderTests.RunAllTests;
begin
   Test_SweepstakesPrecedenceBeforeTheSerial;
   Test_SprintStateBeforeTheName;
   Test_NAQPStateAndNameInEitherOrder;
end;

end.
