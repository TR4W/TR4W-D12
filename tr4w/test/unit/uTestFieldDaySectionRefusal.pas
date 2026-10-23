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

(* THE FIELD DAYS' "Invalid ARRL Section", WITH ITS REASON -- 2026-10-23.

  LOGSTUFF.ProcessClassAndDomesticOrDXQTHExchange refused a section the
  domestic file does not know with a hard-coded 'Invalid ARRL Section' and
  nothing more (D7's CHANGES.md said it was to be folded into the localized
  constants). It now goes through RefuseDomesticQTH like every other
  domestic-QTH refusal: the stem is TC_INVALIDARRLSECTION (NY4I's wording,
  kept) and the brief reason is appended -- '(WSX not in arrlsect.dom)',
  '(no QTH)', or '(MY COUNTRY is empty)'. Field Day is not a QSO party, so
  the host-area reason never applies.

  THROUGH THE REAL ENGINE, as uTestContestGeorgiaQP does: ParametersOkay,
  with the shipped arrlsect.dom in the domestic table and the ARRL-section
  domestic countries both Field Days state. Each message is pinned exactly,
  and so is the caret token (issue #1010), which RefuseDomesticQTH must not
  disturb. *)
unit uTestFieldDaySectionRefusal;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TFieldDaySectionRefusalTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_FieldDaysNameTheReasonForABadSection;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   uAppStrings,
   uTR4WStrings,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit;

procedure TFieldDaySectionRefusalTests.Test_FieldDaysNameTheReasonForABadSection;
const
   FIELD_DAYS: array[0..1] of ContestType = (ARRLFIELDDAY, WINTERFIELDDAY);
   (* A class each contest takes: ARRL's letters are A-F, Winter's I/O/H/M. *)
   FIELD_DAY_CLASSES: array[0..1] of string = ('2A', '2O');
var
   savedContest: TContestHandle;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedMyCountry: string;
   savedDomesticFilename: string;
   ctyPath: string;
   rx: ContestExchange;
   accepted: boolean;
   fd: integer;
   i: integer;
   name: string;

   (* ONE EXCHANGE, AS AN OPERATOR ENTERS IT -- ParametersOkay alone; no
      QSO is logged. *)
   function Enter(const aCall: string; const aExch: string): boolean;
   begin
      rx := Default(ContestExchange);
      ActiveMode := CW;
      CallWindowString := CallString(aCall);
      ExchangeErrorMessage := '';
      Result := ParametersOkay(CallString(aCall), Str40(aExch), Band20, CW,
                               14025000, rx);
   end;

begin
   BeginTest('Test_FieldDaysNameTheReasonForABadSection');
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(ctyPath, False, False, True), 'cty.dat loads');

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
   try
      (* AS FoundContest SETS EITHER FIELD DAY UP: the ARRL-section
         countries are domestic (so W1AW reaches the section parser, not the
         DX one), arrlsect.dom is the table, and the setting names it as
         FoundContest writes it -- the contest's DomesticFileName plus the
         extension. *)
      DomesticCountries.Clear;
      for i := Low(DomesticCountriesARRLSections) to High(DomesticCountriesARRLSections) do
         begin
         DomesticCountries.Add(CallString(DomesticCountriesARRLSections[i]));
         end;
      CheckTrue(DomQTHTable.LoadInDomQTHFile(ShippedDomDir + 'arrlsect.dom'),
                'arrlsect.dom loads');

      for fd := Low(FIELD_DAYS) to High(FIELD_DAYS) do
         begin
         Contest := ContestHandleOf(FIELD_DAYS[fd]);
         ReleaseActiveContest;
         name := ContestIdentity(Contest).FriendlyName + ': ';
         CheckEquals('arrlsect', ContestIdentity(Contest).DomesticFileName,
                     name + 'the domestic file is the ARRL section list');
         CheckTrue(ContestUsesDomesticFile(ContestIdentity(Contest)),
                   name + 'it looks the section up in that file');
         CheckFalse(ContestIdentity(Contest).IsUSQSOParty,
                    name + 'not a QSO party, so no host-area reason');
         Settings.Contest.DomesticFilename := 'arrlsect.dom';
         Settings.My.DeriveCountry('K');

         (* THE CONTROL: a real section is taken, so a refusal below is the
            section's and not a broken set-up. Entered FIRST and checked
            after: FPC may build a Check's message argument before it calls
            a function in the same argument list, which showed the previous
            refusal's text here. *)
         accepted := Enter('W1AW', FIELD_DAY_CLASSES[fd] + ' CT');
         CheckTrue(accepted, name + FIELD_DAY_CLASSES[fd] + ' CT is taken: ' +
                             string(ExchangeErrorMessage));

         (* A SECTION THE FILE DOES NOT KNOW. *)
         accepted := Enter('W1AW', FIELD_DAY_CLASSES[fd] + ' WSX');
         CheckFalse(accepted, name + 'a bad section is refused');
         CheckEquals('Invalid ARRL Section (WSX not in arrlsect.dom)',
                     string(ExchangeErrorMessage),
                     name + 'the stem, and the file that does not know it');
         CheckEquals('WSX', string(ExchangeErrorToken),
                     name + 'the caret still goes after the bad section (#1010)');

         (* NOTHING THAT COULD BE A SECTION -- a class alone. *)
         accepted := Enter('W1AW', FIELD_DAY_CLASSES[fd]);
         CheckFalse(accepted, name + 'a class alone is refused');
         CheckEquals('Invalid ARRL Section (no QTH)',
                     string(ExchangeErrorMessage),
                     name + 'as no QTH');

         (* MY COUNTRY EMPTY WINS THE SCREEN, as in every other refusal. *)
         Settings.My.DeriveCountry('');
         accepted := Enter('W1AW', FIELD_DAY_CLASSES[fd] + ' WSX');
         CheckFalse(accepted, name + 'still refused with no MY COUNTRY');
         CheckEquals(TC_INVALIDARRLSECTION + ' ' + SExchangeModeBriefEmptyCountry,
                     string(ExchangeErrorMessage),
                     name + 'and the screen names the empty MY COUNTRY');
         CheckEquals('Invalid ARRL Section (MY COUNTRY is empty)',
                     string(ExchangeErrorMessage),
                     name + 'word for word');
         CheckEquals('WSX', string(ExchangeErrorToken),
                     name + 'and the caret is still the section''s');
         Settings.My.DeriveCountry('K');
         end;
   finally
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
end;

procedure TFieldDaySectionRefusalTests.RunAllTests;
begin
   Test_FieldDaysNameTheReasonForABadSection;
end;

end.
