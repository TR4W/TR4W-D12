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

(* A SECTION TYPED AS AN ALIAS -- issue 13, 2026-11-10.

  THE CLAIM: in an ARRL-section contest a typed `EM` is stored and exported
  as `EM`, where arrlsect.dom says the section is EMA (`EMA = EM,EMA`).

  WHAT D7 DID: PostUnit wrote ADIF ARRL_SECT from the QSO's QTHString for
  Sweepstakes and ARRL 160 -- the text as typed -- so a typed EM went out as
  <ARRL_SECT:2>EM, which is not a section ADIF knows.

  WHAT THIS TREE DOES, measured here through the real engine
  (MainUnit.ParametersOkay, arrlsect.dom loaded):
    * QTHString stays what was typed ('EM'). That is by design -- it is the
      operator's literal value (Q45), the field LITERAL DOMESTIC QTH writes;
    * DomesticQTH and DomMultQTH are the file's LEFT side, 'EMA', so a typed
      EM and a typed EMA are ONE multiplier;
    * ADIF ARRL_SECT is EMA (uADIF.ADIFSectionOf: the typed text only when
      ADIF knows it as a section, else the resolved DomesticQTH -- since
      0428208e, 2026-10-23);
    * the Cabrillo received column is the resolved DomesticQTH
      (PostUnit.CabrilloReceivedQTH, the contests state no LITERAL DOMESTIC
      QTH), which the writer upper-cases before it writes the line -- so a
      key the file spells 'WcF' goes out WCF.

  THE GOLDEN CORPUS CANNOT SEE ANY OF THIS: in its Sweepstakes log every
  received section was typed as its canonical name.

  STILL OPEN, pinned below so a change is a decision: a QSO IMPORTED from
  ADIF takes its section as written (TContestARRLSSBase.ApplyADIFImport), with
  no table lookup, and the rescore trusts the stored DomesticQTH. A D7 export
  of a typed EM carries <ARRL_SECT:2>EM, so importing it gives a multiplier
  'EM' beside 'EMA' and re-exports no ARRL_SECT at all. *)
unit uTestARRLSectionAlias;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework,
   (* ContestExchange. *)
   VC;

type
   TARRLSectionAliasTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure CheckOutputs(const aRX: ContestExchange; const aWho: string;
                             const aSection: string);
      procedure Test_SweepstakesTypedAliasIsTheCanonicalSection;
      procedure Test_SweepstakesAliasAndSectionAreOneMultiplier;
      procedure Test_ARRL160TypedAliasIsTheCanonicalSection;
      procedure Test_EveryArrlsectAliasExportsItsSection;
      procedure Test_ImportedAliasIsStoredAsWritten_Open;
   end;

implementation

uses
   (* Settings. Nothing here names a type it shares with VC. *)
   uSettingsModel,
   Classes,
   SysUtils,
   (* mo -- the multiplier sheet's store. *)
   uMults,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   (* ADIFSectionOf, NeutralADIFImportSession. *)
   uADIF,
   (* IsADIFARRLSection -- ADIF's own section list. *)
   uARRLSections,
   uTestContestObjects,
   uTestShippedDom,
   LogDupe,
   LogDom,
   LogEdit,
   (* Sheet, ExchangeErrorMessage. *)
   LogStuff,
   PostUnit,
   MainUnit,
   (* Enter, SetUpSession, RestoreSession, LoadCountryFile. LAST, so its
      names win. *)
   uTestEngineEntry;

(* WHAT THE THREE OUTPUTS SAY FOR ONE ENTERED QSO -- the ADIF contest tail,
   the ADIF section alone, and the Cabrillo received QTH as the writer puts
   it on the line (CabrilloReceivedQTH, then UpperCase of the whole column:
   PostUnit's CABRILLO_HISEX). LITERAL DOMESTIC QTH is off, as the
   ARRL-section contests leave it. *)
procedure TARRLSectionAliasTests.CheckOutputs(const aRX: ContestExchange;
                                              const aWho: string;
                                              const aSection: string);
var
   contestRules: TContestBase;
   savedLiteral: boolean;
begin
   contestRules := ActiveContest(Contest);
   (* EmitADIFField's layout: the tag, then one blank before the next. *)
   CheckEquals('<ARRL_SECT:' + IntToStr(Length(aSection)) + '>' + aSection + ' ',
               contestRules.EmitADIFContestFields(aRX),
               aWho + ': the ADIF contest tail');
   CheckEquals(aSection, ADIFSectionOf(aRX), aWho + ': ADIF ARRL_SECT');

   savedLiteral := Settings.Contest.LiteralDomesticQth;
   try
      Settings.Contest.LiteralDomesticQth := False;
      CheckTrue(ContestHasDomesticMultiplier(contestRules),
                aWho + ': counts a domestic multiplier');
      CheckEquals(aSection,
                  UpperCase(CabrilloReceivedQTH(ContestHasDomesticMultiplier(contestRules), aRX)),
                  aWho + ': the Cabrillo received QTH');
   finally
      Settings.Contest.LiteralDomesticQth := savedLiteral;
   end;
end;

(* ---------------------------------------------------------------------------
   SWEEPSTAKES -- typed through live entry
   --------------------------------------------------------------------------- *)

procedure TARRLSectionAliasTests.Test_SweepstakesTypedAliasIsTheCanonicalSection;
var
   rx: ContestExchange;
   accepted: boolean;

   (* aTyped is entered; aKey is the file's left side (DomesticQTH, as the
      file spells it); aSection is ADIF's and Cabrillo's spelling of it. *)
   procedure CheckAlias(const aTyped: string; const aKey: string; const aSection: string);
   var
      who: string;
   begin
      who := '123 A 99 ' + aTyped;
      accepted := Enter('W1AW', who, rx);
      CheckTrue(accepted, who + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aTyped, string(rx.QTHString), who + ': QTHString is what was typed');
      CheckEquals(aKey, string(rx.DomesticQTH), who + ': DomesticQTH is the file''s section');
      CheckEquals(aKey, string(rx.DomMultQTH), who + ': the multiplier is the file''s section');
      CheckOutputs(rx, who, aSection);
   end;

begin
   BeginTest('Test_SweepstakesTypedAliasIsTheCanonicalSection');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* THE ISSUE'S CASE, and its canonical spelling as the control. *)
      CheckAlias('EM', 'EMA', 'EMA');
      CheckAlias('EMA', 'EMA', 'EMA');
      (* A KEY THE FILE SPELLS IN MIXED CASE: 'WcF = WC, WF, WCF'. *)
      CheckAlias('WF', 'WcF', 'WCF');
      CheckAlias('EN', 'ENy', 'ENY');
      (* AN ALIAS THAT SHARES NO LETTERS' ORDER WITH ITS SECTION:
         'MDC = MD, MARY, DC, MDC'. *)
      CheckAlias('DC', 'MDC', 'MDC');

      (* THE OTHER RUNNING: the rule is the family's. *)
      Contest := ContestHandleOf(ARRLSSSSB);
      ReleaseActiveContest;
      CheckAlias('EM', 'EMA', 'EMA');
   finally
      RestoreSession;
   end;
end;

(* A TYPED EM AND A TYPED EMA COUNT ONCE -- the sheet keys on DomMultQTH,
   which is EMA for both. A different section after them is still new, so
   the second answer is not vacuous. *)
procedure TARRLSectionAliasTests.Test_SweepstakesAliasAndSectionAreOneMultiplier;
var
   first: ContestExchange;
   second: ContestExchange;
   other: ContestExchange;
begin
   BeginTest('Test_SweepstakesAliasAndSectionAreOneMultiplier');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   mo.ClearAllMults;
   try
      CheckTrue(Enter('W1AW', '123 A 99 EM', first), '123 A 99 EM is taken');
      Sheet.SetMultFlags(first);
      CheckTrue(first.DomesticMult, 'EM: the first EMA is a new multiplier');
      Sheet.AddQSOToSheets(@first, False);

      CheckTrue(Enter('K1ABC', '145 B 72 EMA', second), '145 B 72 EMA is taken');
      Sheet.SetMultFlags(second);
      CheckFalse(second.DomesticMult, 'EMA after EM: the same multiplier, not new');

      CheckTrue(Enter('K1XYZ', '146 B 72 WMA', other), '146 B 72 WMA is taken');
      Sheet.SetMultFlags(other);
      CheckTrue(other.DomesticMult, 'WMA after EMA: a different section is new');
   finally
      mo.ClearAllMults;
      RestoreSession;
   end;
end;

(* ---------------------------------------------------------------------------
   ARRL 160 -- a W/VE entrant, typed through live entry
   --------------------------------------------------------------------------- *)

procedure TARRLSectionAliasTests.Test_ARRL160TypedAliasIsTheCanonicalSection;
var
   rx: ContestExchange;
   accepted: boolean;
begin
   BeginTest('Test_ARRL160TypedAliasIsTheCanonicalSection');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRL160, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* The matrix's rst.state row, '599 CT', with the issue's section. *)
      accepted := Enter('W1AW', '599 EM', rx);
      CheckTrue(accepted, '599 EM is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('EM', string(rx.QTHString), '599 EM: QTHString is what was typed');
      CheckEquals('EMA', string(rx.DomesticQTH), '599 EM: DomesticQTH is the file''s section');
      CheckEquals('EMA', string(rx.DomMultQTH), '599 EM: the multiplier is the file''s section');
      (* ARRL 160 writes ARRL_SECT only for a W/VE QSO. *)
      CheckEquals('K', string(rx.QTH.CountryID), '599 EM: W1AW is a K QSO');
      CheckOutputs(rx, '599 EM', 'EMA');

      accepted := Enter('W1AW', '599 WF', rx);
      CheckTrue(accepted, '599 WF is taken: ' + string(ExchangeErrorMessage));
      CheckEquals('WcF', string(rx.DomesticQTH), '599 WF: DomesticQTH is the file''s section');
      CheckOutputs(rx, '599 WF', 'WCF');
   finally
      RestoreSession;
   end;
end;

(* ---------------------------------------------------------------------------
   EVERY ALIAS OF arrlsect.dom -- at the table, not through the parser
   --------------------------------------------------------------------------- *)

(* For each alias the file lists, a QSO as live entry leaves it (QTHString
   typed, DomesticQTH the file's section) exports that section, in ADIF's
   spelling, and Cabrillo agrees. This is what would catch an alias that is
   ITSELF a different ADIF section -- ADIFSectionOf takes the typed text first
   when ADIF knows it. Not through ParametersOkay: VE7, KP4 or KL would meet
   the call correction and the Sweepstakes word readings, which are not this
   question. *)
procedure TARRLSectionAliasTests.Test_EveryArrlsectAliasExportsItsSection;
var
   table: TDomQTHTable;
   entry: TDomQTHEntry;
   lines: TStringList;
   items: TStringList;
   i, j, p: integer;
   alias: string;
   section: string;
   qso: ContestExchange;
   asked: integer;
   differing: integer;
   savedLiteral: boolean;
   savedContest: TContestHandle;
begin
   BeginTest('Test_EveryArrlsectAliasExportsItsSection');
   asked := 0;
   differing := 0;
   (* CabrilloReceivedQTH reads the session's LITERAL DOMESTIC QTH and the
      contest (the Cup RF arm), so both are stated here, not inherited from
      whichever suite ran before. *)
   savedLiteral := Settings.Contest.LiteralDomesticQth;
   savedContest := Contest;
   Settings.Contest.LiteralDomesticQth := False;
   Contest := ContestHandleOf(ARRLSSCW);
   table := TDomQTHTable.Create;
   lines := TStringList.Create;
   items := TStringList.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'arrlsect.dom', True, 0);
      lines.LoadFromFile(AnsiString(ShippedDomDir + 'arrlsect.dom'));
      items.Delimiter := ',';
      items.StrictDelimiter := True;
      for i := 0 to lines.Count - 1 do
         begin
         p := Pos('=', string(lines[i]));
         if p = 0 then
            begin
            Continue;
            end;
         items.DelimitedText := AnsiString(Copy(string(lines[i]), p + 1, MaxInt));
         for j := 0 to items.Count - 1 do
            begin
            alias := UpperCase(Trim(string(items[j])));
            if (alias = '') or (alias[1] = '^') then
               begin
               Continue;
               end;
            CheckTrue(table.FindAlias(alias, entry), 'arrlsect.dom knows its alias ' + alias);
            if not table.FindAlias(alias, entry) then
               begin
               Continue;
               end;
            Inc(asked);
            section := UpperCase(string(entry.DomQTH));
            if section <> alias then
               begin
               Inc(differing);
               end;
            CheckTrue(IsADIFARRLSection(section),
                      alias + ': its section ' + section + ' is one ADIF knows');

            qso := Default(ContestExchange);
            qso.QTHString := Str10(alias);
            qso.DomesticQTH := entry.DomQTH;
            qso.DomMultQTH := entry.Multiplier;
            CheckEquals(section, ADIFSectionOf(qso), alias + ': ADIF ARRL_SECT');
            CheckEquals(section, UpperCase(CabrilloReceivedQTH(True, qso)),
                        alias + ': the Cabrillo received QTH');
            end;
         end;
      (* THE FILE AS SHIPPED: enough aliases that differ from their section
         that this walk is not vacuous. *)
      CheckTrue(asked > 100, 'arrlsect.dom: aliases walked (' + IntToStr(asked) + ')');
      CheckTrue(differing > 40, 'arrlsect.dom: aliases unlike their section (' +
                                IntToStr(differing) + ')');
   finally
      items.Free;
      lines.Free;
      table.Free;
      Settings.Contest.LiteralDomesticQth := savedLiteral;
      Contest := savedContest;
   end;
end;

(* ---------------------------------------------------------------------------
   THE IMPORT -- OPEN, pinned as it stands
   --------------------------------------------------------------------------- *)

(* AN ADIF RECORD WRITTEN WITH AN ALIAS KEEPS IT -- TContestARRLSSBase.
   ApplyADIFImport copies ARRL_SECT into DomesticQTH and QTHString with no
   lookup, and the rescore (MainUnit.RecomputeQSOScoring -> SetMultFlags)
   trusts DomesticQTH. D7 wrote <ARRL_SECT:2>EM for a typed EM, so such a
   file exists. Pinned so that resolving it is a decision (issue 13 report):
   the multiplier is 'EM', not 'EMA', and the re-export writes NO ARRL_SECT,
   because ADIF knows neither EM nor the stored DomesticQTH. *)
procedure TARRLSectionAliasTests.Test_ImportedAliasIsStoredAsWritten_Open;
var
   temps: TADIFRecordTemps;
   qso: ContestExchange;
begin
   BeginTest('Test_ImportedAliasIsStoredAsWritten_Open');
   temps := Default(TADIFRecordTemps);
   temps.ARRL_Sect := 'EM';
   qso := Default(ContestExchange);
   ContestIdentity(ContestHandleOf(ARRLSSCW)).ApplyADIFImport(temps,
      NeutralADIFImportSession, qso);
   CheckEquals('EM', string(qso.QTHString), 'import: QTHString as written');
   CheckEquals('EM', string(qso.DomesticQTH),
               'import: DomesticQTH as written, NOT resolved to EMA (open)');
   CheckEquals('', ADIFSectionOf(qso),
               'import: so the re-export writes no ARRL_SECT (open)');
end;

procedure TARRLSectionAliasTests.RunAllTests;
begin
   Test_SweepstakesTypedAliasIsTheCanonicalSection;
   Test_SweepstakesAliasAndSectionAreOneMultiplier;
   Test_ARRL160TypedAliasIsTheCanonicalSection;
   Test_EveryArrlsectAliasExportsItsSection;
   Test_ImportedAliasIsStoredAsWritten_Open;
end;

end.
