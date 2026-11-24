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

  THE IMPORT -- issue 265, FIXED 2026-11-10. A QSO imported from ADIF took
  its section as written (TContestARRLSSBase.ApplyADIFImport and both Field
  Days'), with no table lookup, and the rescore trusts the stored
  DomesticQTH: a D7 export of a typed EM carries <ARRL_SECT:2>EM, so the
  import gave a multiplier 'EM' beside 'EMA' and re-exported no ARRL_SECT.
  The import now resolves it through the lookup typed entry runs
  (uContestBase.ImportDomesticQTH, handed LOGDUPE.DomesticQTHAndKeyOf by
  MainUnit.ParseADIFRecord), so an imported alias stores what a typed one
  does. Pinned for every alias, through the ARRL_SECT tag and the QTH tag.

  THE FIELD DAYS' STATE AND THE DXKEEPER HAND-OFF -- issue 266, FIXED the
  same day. Field Day and WFD wrote ADIF STATE from the typed text, so 35
  aliases (WF, SN, NY, HA, LOS, KL, CON ...) wrote none
  (uADIF.ADIFSectionStateOf); the DXKeeper message sent ARRL_SECT as typed
  (EM) or not at all (WF) (uExternalLogger.ExternalLoggerARRLSection).

  THE SAME IMPORT FOR THE OTHER RAW-SRX COPIES -- issue 328, 2026-11-15. CQ
  160, UBA DX, LZ DX, OK/OM DX and Ukrainian DX each stored the RAW
  SRX_STRING (RST and all) where ARRL 160's import, fixed at issue 275,
  resolves it. They call uContestBase.ImportDomesticQTHWords now, and the
  Test_*ImportedQTHIsTheFileQTH cases below pin, through the real engine
  with each contest's shipped .dom, the domestic QTH an imported record
  stores. *)
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
      procedure CheckReceivedColumn(const aRX: ContestExchange; const aWho: string);
      procedure Test_SweepstakesTypedAliasIsTheCanonicalSection;
      procedure Test_SweepstakesAliasAndSectionAreOneMultiplier;
      procedure Test_ARRL160TypedAliasIsTheCanonicalSection;
      procedure Test_EveryArrlsectAliasExportsItsSection;
      procedure Test_ImportedAliasIsTheCanonicalSection;
      procedure Test_EveryArrlsectAliasImportsAsItsSection;
      procedure Test_ImportWithNoLookupKeepsTheTextAsWritten;
      procedure Test_CanonicalSectionImportExportsAsBefore;
      procedure Test_FieldDayStateIsTheResolvedSections;
      procedure Test_FieldDayStateKeepsAnUnresolvedRow;
      procedure Test_DXKeeperSendsTheResolvedSection;
      procedure Test_DXKeeperNonSectionContestSendsNoSection;
      procedure Test_DXKeeperPayloadIsTheExportRecord;
      procedure Test_ARRL160ImportedAliasIsTheCanonicalSection;
      procedure Test_ARRL160RealN1MMAndDXLogRecords;
      procedure Test_QSOPartyImportedAliasIsTheFileQTH;
      procedure Test_CQ160ImportedQTHIsTheFileQTH;
      procedure Test_UBAImportedQTHIsTheFileQTH;
      procedure Test_ZoneOrSerialImportedQTHIsTheFileQTH;
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
   (* ClearContestExchange, DomesticQTHAndKeyOf. *)
   LogDupe,
   LogDom,
   LogEdit,
   (* Sheet, ExchangeErrorMessage. *)
   LogStuff,
   PostUnit,
   (* ParseADIFRecord -- the record path ImportFromADIF takes. *)
   MainUnit,
   (* The DXKeeper hand-off: ExternalLoggerARRLSection, and a logger whose
      transport records (TRecordingLogger) for its built message. *)
   uExternalLoggerBase,
   uExternalLogger,
   uQsoDispatcher,
   uTestExternalLoggerLookup,
   (* TQsoMyFacts -- what ParseADIFRecord reads of OUR station. *)
   uQsoMyFacts,
   (* PartyReceivedCabrilloColumn -- the writer's received column. *)
   uTestQSOPartyRules,
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

(* EVERY ALIAS THE FILE LISTS, upper case, trimmed, in file order -- the right
   side of each `SECTION = alias, alias` line, less '^' entries. ONE reading
   of the file for every walk below. A duplicate alias is listed each time;
   the table keeps the first. *)
procedure ReadArrlsectAliases(aAliases: TStringList);
var
   lines: TStringList;
   items: TStringList;
   i, j, p: integer;
   alias: string;
begin
   aAliases.Clear;
   lines := TStringList.Create;
   items := TStringList.Create;
   try
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
            aAliases.Add(AnsiString(alias));
            end;
         end;
   finally
      items.Free;
      lines.Free;
   end;
end;

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
   aliases: TStringList;
   i: integer;
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
   (* CabrilloReceivedQTH reads the session's LITERAL DOMESTIC QTH (and, until
      2026-11-20, the contest -- the Cup RF arm), so both are stated here, not
      inherited from whichever suite ran before. *)
   savedLiteral := Settings.Contest.LiteralDomesticQth;
   savedContest := Contest;
   Settings.Contest.LiteralDomesticQth := False;
   Contest := ContestHandleOf(ARRLSSCW);
   table := TDomQTHTable.Create;
   aliases := TStringList.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'arrlsect.dom', True, 0);
      ReadArrlsectAliases(aliases);
      for i := 0 to aliases.Count - 1 do
         begin
         alias := string(aliases[i]);
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
      (* THE FILE AS SHIPPED: enough aliases that differ from their section
         that this walk is not vacuous. *)
      CheckTrue(asked > 100, 'arrlsect.dom: aliases walked (' + IntToStr(asked) + ')');
      CheckTrue(differing > 40, 'arrlsect.dom: aliases unlike their section (' +
                                IntToStr(differing) + ')');
   finally
      aliases.Free;
      table.Free;
      Settings.Contest.LiteralDomesticQth := savedLiteral;
      Contest := savedContest;
   end;
end;

(* ---------------------------------------------------------------------------
   THE IMPORT -- issue 265
   --------------------------------------------------------------------------- *)

(* ONE ADIF FIELD, <NAME:length>value and a blank. *)
function AdifTag(const aName, aValue: string): string;
begin
   Result := '<' + aName + ':' + IntToStr(Length(aValue)) + '>' + aValue + ' ';
end;

(* ONE RECORD, as another logger -- or D7 -- writes it: the call, a band, a
   mode, the reports, the tags under test. *)
function AdifRecord(const aCall, aTags: string): string;
begin
   Result := AdifTag('CALL', aCall) + AdifTag('BAND', '20m') + AdifTag('MODE', 'CW') +
             AdifTag('QSO_DATE', '20261105') + AdifTag('TIME_ON', '120000') +
             AdifTag('RST_SENT', '599') + AdifTag('RST_RCVD', '599') + aTags + '<EOR>';
end;

(* THE SESSION THE ENGINE HANDS AN IMPORT, as far as a section reads it: the
   lookup (MainUnit.ParseADIFRecord's), everything else neutral. *)
function ResolvingImportSession: TADIFImportSession;
begin
   Result := NeutralADIFImportSession;
   Result.ResolveDomesticQTH := @DomesticQTHAndKeyOf;
end;

(* THE ISSUE'S CASE, THROUGH THE PATH ImportFromADIF TAKES -- a cleared
   exchange (the session's contest), then MainUnit.ParseADIFRecord. D7 wrote
   <ARRL_SECT:2>EM for a typed EM; it now imports as a typed EM is entered:
   QTHString as written, DomesticQTH and DomMultQTH the file's EMA -- so it
   re-exports EMA, and an EMA typed after it is the same multiplier. *)
procedure TARRLSectionAliasTests.Test_ImportedAliasIsTheCanonicalSection;
var
   imported: ContestExchange;
   rx: ContestExchange;
   typed: ContestExchange;
begin
   BeginTest('Test_ImportedAliasIsTheCanonicalSection');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   mo.ClearAllMults;
   try
      ClearContestExchange(imported);
      CheckTrue(ParseADIFRecord(AdifRecord('W1AW', AdifTag('ARRL_SECT', 'EM')), imported),
                'ARRL_SECT EM: parsed');
      CheckEquals('EM', string(imported.QTHString), 'ARRL_SECT EM: QTHString as written');
      CheckEquals('EMA', string(imported.DomesticQTH), 'ARRL_SECT EM: DomesticQTH is the file''s section');
      CheckEquals('EMA', string(imported.DomMultQTH), 'ARRL_SECT EM: the multiplier is the file''s section');
      CheckOutputs(imported, 'ARRL_SECT EM', 'EMA');

      (* NO ARRL_SECT: the QTH tag carries it (the winter_fd shape). *)
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1ABC', AdifTag('QTH', 'WF')), rx), 'QTH WF: parsed');
      CheckEquals('WF', string(rx.QTHString), 'QTH WF: QTHString as written');
      CheckEquals('WcF', string(rx.DomesticQTH), 'QTH WF: DomesticQTH as the file spells it');
      CheckOutputs(rx, 'QTH WF', 'WCF');

      (* A TEXT THE TABLE DOES NOT KNOW STAYS AS WRITTEN -- as before: an
         explicit ARRL_SECT is the record's own statement (review M5). *)
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1XYZ', AdifTag('ARRL_SECT', 'XYZ')), rx), 'XYZ: parsed');
      CheckEquals('XYZ', string(rx.DomesticQTH), 'XYZ: unknown, kept as written');
      CheckEquals('', string(rx.DomMultQTH), 'XYZ: and no multiplier is invented');

      (* ONE MULTIPLIER: the imported EM, then a typed EMA. *)
      Sheet.SetMultFlags(imported);
      CheckTrue(imported.DomesticMult, 'imported EM: a new multiplier');
      Sheet.AddQSOToSheets(@imported, False);
      CheckTrue(Enter('K1ABC', '145 B 72 EMA', typed), '145 B 72 EMA is taken');
      Sheet.SetMultFlags(typed);
      CheckFalse(typed.DomesticMult, 'typed EMA after an imported EM: the same multiplier');
   finally
      mo.ClearAllMults;
      RestoreSession;
   end;
end;

(* EVERY ALIAS, BOTH TAGS, EVERY ARRL-SECTION CONTEST WHOSE IMPORT CHANGED --
   both Sweepstakes and both Field Days. For each alias the file lists, the
   record's ARRL_SECT, and on its own its QTH, import as the table's entry:
   DomesticQTH and DomMultQTH the entry's, QTHString as written, the ADIF
   section the entry's. Then the five winter_fd corpus QSOs end to end. *)
procedure TARRLSectionAliasTests.Test_EveryArrlsectAliasImportsAsItsSection;
const
   CONTESTS: array[0 .. 3] of ContestType =
      (ARRLSSCW, ARRLSSSSB, ARRLFIELDDAY, WINTERFIELDDAY);
var
   aliases: TStringList;
   entry: TDomQTHEntry;
   temps: TADIFRecordTemps;
   qso: ContestExchange;
   c, i: integer;
   alias: string;
   who: string;
   asked: integer;

   procedure CheckImported(const aHow: string);
   begin
      who := string(ContestTypeSA[CONTESTS[c]]) + ' ' + aHow + ' ' + alias;
      CheckEquals(alias, string(qso.QTHString), who + ': QTHString as written');
      CheckEquals(string(entry.DomQTH), string(qso.DomesticQTH), who + ': DomesticQTH');
      CheckEquals(string(entry.Multiplier), string(qso.DomMultQTH), who + ': DomMultQTH');
      CheckEquals(UpperCase(string(entry.DomQTH)), ADIFSectionOf(qso), who + ': ADIF ARRL_SECT');
   end;

begin
   BeginTest('Test_EveryArrlsectAliasImportsAsItsSection');
   asked := 0;
   aliases := TStringList.Create;
   try
      ReadArrlsectAliases(aliases);
      for c := Low(CONTESTS) to High(CONTESTS) do
         begin
         SetUpSession(CONTESTS[c], DomesticCountriesARRLSections, 'arrlsect.dom');
         try
            for i := 0 to aliases.Count - 1 do
               begin
               alias := string(aliases[i]);
               if not DomQTHTable.FindAlias(alias, entry) then
                  begin
                  CheckTrue(False, 'the loaded table knows ' + alias);
                  Continue;
                  end;

               temps := Default(TADIFRecordTemps);
               temps.ARRL_Sect := alias;
               qso := Default(ContestExchange);
               ContestIdentity(ContestHandleOf(CONTESTS[c])).ApplyADIFImport(temps,
                  ResolvingImportSession, qso);
               CheckImported('ARRL_SECT');

               temps := Default(TADIFRecordTemps);
               qso := Default(ContestExchange);
               qso.QTHString := Str10(alias);
               ContestIdentity(ContestHandleOf(CONTESTS[c])).ApplyADIFImport(temps,
                  ResolvingImportSession, qso);
               CheckImported('QTH');
               Inc(asked);
               end;
         finally
            RestoreSession;
         end;
         end;
      CheckTrue(asked > 400, 'aliases imported (' + IntToStr(asked) + ')');

      (* THE winter_fd CORPUS's FIVE: D7 wrote them with the alias in QTH and
         ARRL_SECT. Through ParseADIFRecord, so the call's country is looked
         up and the export's K arm runs: the section, and its state where
         uARRLSections knows one (MDC is two states). *)
      CheckTrue(LoadCountryFile, 'cty.dat loads');
      SetUpSession(WINTERFIELDDAY, DomesticCountriesARRLSections, 'arrlsect.dom');
      try
         ClearContestExchange(qso);
         CheckTrue(ParseADIFRecord(AdifRecord('KO1Q', AdifTag('QTH', 'NY') +
                   AdifTag('CLASS', '2M') + AdifTag('ARRL_SECT', 'NY')), qso), 'KO1Q: parsed');
         CheckEquals('NLi', string(qso.DomesticQTH), 'KO1Q NY: DomesticQTH');
         CheckEquals('K', string(qso.QTH.CountryID), 'KO1Q: a K QSO');
         CheckTrue(Pos('<STATE:2>NY <ARRL_SECT:3>NLI ',
                       ContestIdentity(ContestHandleOf(WINTERFIELDDAY)).EmitADIFContestFields(qso)) > 0,
                   'KO1Q NY: STATE NY and ARRL_SECT NLI');

         ClearContestExchange(qso);
         CheckTrue(ParseADIFRecord(AdifRecord('KB0TDW', AdifTag('QTH', 'IO') +
                   AdifTag('ARRL_SECT', 'IO')), qso), 'KB0TDW: parsed');
         CheckTrue(Pos('<STATE:2>IA <ARRL_SECT:2>IA ',
                       ContestIdentity(ContestHandleOf(WINTERFIELDDAY)).EmitADIFContestFields(qso)) > 0,
                   'KB0TDW IO: STATE IA and ARRL_SECT IA');

         ClearContestExchange(qso);
         CheckTrue(ParseADIFRecord(AdifRecord('N3HYM', AdifTag('QTH', 'MD') +
                   AdifTag('ARRL_SECT', 'MD')), qso), 'N3HYM: parsed');
         CheckEquals('MDC', string(qso.DomesticQTH), 'N3HYM MD: DomesticQTH');
         CheckTrue(Pos('<ARRL_SECT:3>MDC ',
                       ContestIdentity(ContestHandleOf(WINTERFIELDDAY)).EmitADIFContestFields(qso)) > 0,
                   'N3HYM MD: ARRL_SECT MDC');
         CheckEquals(0, Pos('<STATE:',
                       ContestIdentity(ContestHandleOf(WINTERFIELDDAY)).EmitADIFContestFields(qso)),
                   'N3HYM MD: MDC names no one state');
      finally
         RestoreSession;
      end;
   finally
      aliases.Free;
   end;
end;

(* A CANONICAL SECTION EXPORTS EXACTLY AS IT DID. The lookup now runs for
   every imported section, not only an alias, so 'CT' is stored 'Ct' and
   DomMultQTH is filled where it was empty. For every section the file
   lists as itself, both tags, all three imports: the whole ADIF record
   (EmitADIFRecord and the contest's own tail, as PostUnit writes them) and
   the Cabrillo received QTH are the same as the same record imported with
   no lookup -- no export writer leaks the file's spelling. *)
procedure TARRLSectionAliasTests.Test_CanonicalSectionImportExportsAsBefore;
const
   CONTESTS: array[0 .. 2] of ContestType = (ARRLSSCW, ARRLFIELDDAY, WINTERFIELDDAY);
var
   aliases: TStringList;
   entry: TDomQTHEntry;
   c, i, t: integer;
   alias: string;
   who: string;
   asked: integer;
   resolved: ContestExchange;
   asWritten: ContestExchange;
   contestRules: TContestBase;

   procedure ImportOne(const aSession: TADIFImportSession; aTag: integer;
                       var aQso: ContestExchange);
   var
      temps: TADIFRecordTemps;
   begin
      temps := Default(TADIFRecordTemps);
      aQso := Default(ContestExchange);
      aQso.ceContest := ContestHandleOf(CONTESTS[c]);
      aQso.Callsign := 'K1ABC';
      aQso.Band := Band20;
      aQso.Mode := CW;
      aQso.QTH.CountryID := 'K';
      aQso.ceClass := '2A';
      if aTag = 0 then
         begin
         temps.ARRL_Sect := alias;
         end
      else
         begin
         aQso.QTHString := Str10(alias);
         end;
      contestRules.ApplyADIFImport(temps, aSession, aQso);
   end;

begin
   BeginTest('Test_CanonicalSectionImportExportsAsBefore');
   asked := 0;
   aliases := TStringList.Create;
   try
      ReadArrlsectAliases(aliases);
      for c := Low(CONTESTS) to High(CONTESTS) do
         begin
         SetUpSession(CONTESTS[c], DomesticCountriesARRLSections, 'arrlsect.dom');
         try
            contestRules := ContestIdentity(ContestHandleOf(CONTESTS[c]));
            for i := 0 to aliases.Count - 1 do
               begin
               alias := string(aliases[i]);
               if not DomQTHTable.FindAlias(alias, entry) then
                  begin
                  CheckTrue(False, 'the loaded table knows ' + alias);
                  Continue;
                  end;
               (* Only a section the file lists as itself. *)
               if UpperCase(string(entry.DomQTH)) <> alias then
                  begin
                  Continue;
                  end;
               for t := 0 to 1 do
                  begin
                  who := string(ContestTypeSA[CONTESTS[c]]) + ' ' + alias + ' tag ' + IntToStr(t);
                  ImportOne(ResolvingImportSession, t, resolved);
                  ImportOne(NeutralADIFImportSession, t, asWritten);
                  CheckEquals(EmitADIFRecord(asWritten) + contestRules.EmitADIFContestFields(asWritten),
                              EmitADIFRecord(resolved) + contestRules.EmitADIFContestFields(resolved),
                              who + ': the ADIF record');
                  CheckEquals(UpperCase(CabrilloReceivedQTH(True, asWritten)),
                              UpperCase(CabrilloReceivedQTH(True, resolved)),
                              who + ': the Cabrillo received QTH');
                  Inc(asked);
                  end;
               end;
         finally
            RestoreSession;
         end;
         end;
      CheckTrue(asked > 200, 'canonical sections compared (' + IntToStr(asked) + ')');
   finally
      aliases.Free;
   end;
end;

(* A SESSION WITH NO LOOKUP KEEPS THE TEXT AS WRITTEN -- the contract of
   NeutralADIFImportSession, which uADIF.ImportADIFFromString passes (no
   contest is open there). Pinned for all three imports, both tags. *)
procedure TARRLSectionAliasTests.Test_ImportWithNoLookupKeepsTheTextAsWritten;
const
   CONTESTS: array[0 .. 2] of ContestType = (ARRLSSCW, ARRLFIELDDAY, WINTERFIELDDAY);
var
   temps: TADIFRecordTemps;
   qso: ContestExchange;
   c: integer;
   who: string;
begin
   BeginTest('Test_ImportWithNoLookupKeepsTheTextAsWritten');
   for c := Low(CONTESTS) to High(CONTESTS) do
      begin
      who := string(ContestTypeSA[CONTESTS[c]]);
      temps := Default(TADIFRecordTemps);
      temps.ARRL_Sect := 'EM';
      qso := Default(ContestExchange);
      ContestIdentity(ContestHandleOf(CONTESTS[c])).ApplyADIFImport(temps,
         NeutralADIFImportSession, qso);
      CheckEquals('EM', string(qso.QTHString), who + ' ARRL_SECT: QTHString');
      CheckEquals('EM', string(qso.DomesticQTH), who + ' ARRL_SECT: DomesticQTH as written');
      CheckEquals('', string(qso.DomMultQTH), who + ' ARRL_SECT: no multiplier');

      temps := Default(TADIFRecordTemps);
      qso := Default(ContestExchange);
      qso.QTHString := 'WF';
      ContestIdentity(ContestHandleOf(CONTESTS[c])).ApplyADIFImport(temps,
         NeutralADIFImportSession, qso);
      CheckEquals('WF', string(qso.DomesticQTH), who + ' QTH: DomesticQTH as written');
      end;
end;

(* ---------------------------------------------------------------------------
   THE FIELD DAYS' ADIF STATE -- issue 266 (1)
   --------------------------------------------------------------------------- *)

(* FOR EVERY ALIAS, a QSO as entry (or now the import) leaves it -- QTHString
   the alias, DomesticQTH the file's section:
     * where the old STATE (the alias's own) was not empty, the new one is
       the SAME -- no alias of the file moves to another state;
     * the aliases that wrote NO STATE and now write one are counted, and
       there are 35 (the issue's measure, re-measured here);
     * both Field Days put it on the line. *)
procedure TARRLSectionAliasTests.Test_FieldDayStateIsTheResolvedSections;
const
   FIELD_DAYS: array[0 .. 1] of ContestType = (ARRLFIELDDAY, WINTERFIELDDAY);
var
   table: TDomQTHTable;
   entry: TDomQTHEntry;
   aliases: TStringList;
   i, c: integer;
   alias: string;
   oldState: string;
   newState: string;
   gained: integer;
   gainedList: string;
   qso: ContestExchange;

   procedure CheckOnTheLine(const aAlias, aDomesticQTH, aState: string);
   var
      fd: integer;
      tail: string;
   begin
      for fd := Low(FIELD_DAYS) to High(FIELD_DAYS) do
         begin
         qso := Default(ContestExchange);
         qso.QTHString := Str10(aAlias);
         qso.DomesticQTH := Str10(aDomesticQTH);
         qso.QTH.CountryID := 'K';
         tail := ContestIdentity(ContestHandleOf(FIELD_DAYS[fd])).EmitADIFContestFields(qso);
         CheckTrue(Pos('<STATE:2>' + aState + ' ', tail) > 0,
                   string(ContestTypeSA[FIELD_DAYS[fd]]) + ' ' + aAlias + ': STATE ' + aState +
                   ' in ' + tail);
         end;
   end;

begin
   BeginTest('Test_FieldDayStateIsTheResolvedSections');
   gained := 0;
   gainedList := '';
   table := TDomQTHTable.Create;
   aliases := TStringList.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'arrlsect.dom', True, 0);
      ReadArrlsectAliases(aliases);
      for i := 0 to aliases.Count - 1 do
         begin
         alias := string(aliases[i]);
         if not table.FindAlias(alias, entry) then
            begin
            CheckTrue(False, 'arrlsect.dom knows its alias ' + alias);
            Continue;
            end;
         qso := Default(ContestExchange);
         qso.QTHString := Str10(alias);
         qso.DomesticQTH := entry.DomQTH;
         oldState := StateFromARRLSection(alias);
         newState := ADIFSectionStateOf(qso);
         if oldState <> '' then
            begin
            CheckEquals(oldState, newState, alias + ': the state it wrote is the state it writes');
            end
         else if newState <> '' then
            begin
            Inc(gained);
            gainedList := gainedList + ' ' + alias + '=' + newState;
            end;
         end;
      (* 35 at issue 266; 50 since issue 275 item 4 gave the one-province
         RAC sections their province (BR, VE7, ALB, ALT, VE6, MAN, VE4, PEI,
         VE5, SAS, PQ, QU, VE2, VO, NFLD). Counted by a model of this loop
         over the shipped arrlsect.dom before the change was made. *)
      CheckEquals(50, gained, 'aliases that now write a STATE:' + gainedList);
   finally
      aliases.Free;
      table.Free;
   end;

   (* THE ISSUE'S EXAMPLES, ON THE LINE, in both Field Days. *)
   CheckOnTheLine('WF', 'WcF', 'FL');
   CheckOnTheLine('WC', 'WcF', 'FL');
   CheckOnTheLine('SN', 'SNj', 'NJ');
   CheckOnTheLine('ST', 'STx', 'TX');
   CheckOnTheLine('NY', 'NLi', 'NY');
   CheckOnTheLine('HA', 'Pac', 'HI');
   CheckOnTheLine('LOS', 'Lax', 'CA');
   CheckOnTheLine('KL', 'Ak', 'AK');
   CheckOnTheLine('CON', 'Ct', 'CT');
   (* And a canonical section, unchanged. *)
   CheckOnTheLine('EMA', 'EMA', 'MA');
   for c := Low(FIELD_DAYS) to High(FIELD_DAYS) do
      begin
      (* DX writes no STATE, still. *)
      qso := Default(ContestExchange);
      qso.QTHString := 'DX';
      CheckEquals(0, Pos('<STATE:',
                  ContestIdentity(ContestHandleOf(FIELD_DAYS[c])).EmitADIFContestFields(qso)),
                  string(ContestTypeSA[FIELD_DAYS[c]]) + ': DX writes no STATE');
      end;
end;

(* A ROW WITH NO RESOLVED SECTION KEEPS THE STATE IT WROTE -- the fallback to
   the QTH as logged. An empty DomesticQTH, or one stored as written before
   issue 265 ('EM' in both), still writes EM's MA; an unresolved 'WF' stored
   in both writes nothing, as before (the fix is the import's, not the
   export's guess). *)
procedure TARRLSectionAliasTests.Test_FieldDayStateKeepsAnUnresolvedRow;
var
   qso: ContestExchange;
begin
   BeginTest('Test_FieldDayStateKeepsAnUnresolvedRow');
   qso := Default(ContestExchange);
   qso.QTHString := 'EM';
   CheckEquals('MA', ADIFSectionStateOf(qso), 'EM, no DomesticQTH: MA from the QTH');

   qso.DomesticQTH := 'EM';
   CheckEquals('MA', ADIFSectionStateOf(qso), 'EM stored as written: MA');

   qso := Default(ContestExchange);
   qso.QTHString := 'WF';
   qso.DomesticQTH := 'WF';
   CheckEquals('', ADIFSectionStateOf(qso), 'WF stored as written: no state, as before');

   qso := Default(ContestExchange);
   CheckEquals('', ADIFSectionStateOf(qso), 'nothing: no state');
end;

(* ---------------------------------------------------------------------------
   THE DXKEEPER HAND-OFF -- issue 266 (2)
   --------------------------------------------------------------------------- *)

(* IN EVERY CONTEST WHOSE QTH IS AN ARRL SECTION the hand-off sends the
   section ADIF export writes: every alias of the file, as the file's
   section. Then the whole message, built by a real DXKeeper logger
   (PrepareOp -- no thread, no socket): a typed EM sends EMA, never EM. *)
procedure TARRLSectionAliasTests.Test_DXKeeperSendsTheResolvedSection;
const
   SECTION_CONTESTS: array[0 .. 4] of ContestType =
      (ARRLSSCW, ARRLSSSSB, ARRLFIELDDAY, WINTERFIELDDAY, ARRL160);
var
   table: TDomQTHTable;
   entry: TDomQTHEntry;
   aliases: TStringList;
   qso: ContestExchange;
   c, i: integer;
   alias: string;
   probe: TRecordingLogger;
   command1: string;
   command2: string;
begin
   BeginTest('Test_DXKeeperSendsTheResolvedSection');
   for c := Low(SECTION_CONTESTS) to High(SECTION_CONTESTS) do
      begin
      CheckTrue(ContestQTHIsAnARRLSection(ContestIdentity(ContestHandleOf(SECTION_CONTESTS[c]))),
                string(ContestTypeSA[SECTION_CONTESTS[c]]) + ': its QTH is an ARRL section');
      end;

   table := TDomQTHTable.Create;
   aliases := TStringList.Create;
   try
      LoadShippedDomFollowingIncludes(table, 'arrlsect.dom', True, 0);
      ReadArrlsectAliases(aliases);
      for c := Low(SECTION_CONTESTS) to High(SECTION_CONTESTS) do
         begin
         for i := 0 to aliases.Count - 1 do
            begin
            alias := string(aliases[i]);
            if not table.FindAlias(alias, entry) then
               begin
               CheckTrue(False, 'arrlsect.dom knows its alias ' + alias);
               Continue;
               end;
            qso := Default(ContestExchange);
            qso.ceContest := ContestHandleOf(SECTION_CONTESTS[c]);
            qso.QTHString := Str10(alias);
            qso.DomesticQTH := entry.DomQTH;
            CheckEquals(UpperCase(string(entry.DomQTH)), ExternalLoggerARRLSection(qso),
                        string(ContestTypeSA[SECTION_CONTESTS[c]]) + ' ' + alias +
                        ': the hand-off''s ARRL_SECT');
            end;
         end;
   finally
      aliases.Free;
      table.Free;
   end;

   (* THE WHOLE MESSAGE. *)
   probe := TRecordingLogger.Create(lt_DxKeeper);
   try
      qso := Default(ContestExchange);
      qso.ceContest := ContestHandleOf(ARRLSSCW);
      qso.Callsign := 'W1AW';
      qso.QTHString := 'EM';
      qso.DomesticQTH := 'EMA';
      probe.PrepareOp(qmNew, qso, NotCapturedMyFacts, '', command1, command2);
      CheckTrue(Pos('<ARRL_SECT:3>EMA ', command1) > 0, 'typed EM: the message carries EMA');
      CheckEquals(0, Pos('<ARRL_SECT:2>', command1), 'typed EM: and never EM');

      qso.QTHString := 'WF';
      qso.DomesticQTH := 'WcF';
      probe.PrepareOp(qmNew, qso, NotCapturedMyFacts, '', command1, command2);
      CheckTrue(Pos('<ARRL_SECT:3>WCF ', command1) > 0, 'typed WF: the message carries WCF (it sent none)');

      qso.QTHString := 'DX';
      qso.DomesticQTH := '';
      probe.PrepareOp(qmNew, qso, NotCapturedMyFacts, '', command1, command2);
      CheckEquals(0, Pos('<ARRL_SECT:', command1), 'DX: no ARRL_SECT');
   finally
      probe.Free;
   end;
end;

(* EVERY OTHER CONTEST SENDS WHAT IT DID: the QTH as logged when
   Tree.LooksLikeASection passes it, nothing else -- and never a domestic key
   read as a section (Wisconsin's county 'Mar' is not Maritime). Whether such
   a contest should send ARRL_SECT at all is NY4I's question; this pins the
   answer that stands. *)
procedure TARRLSectionAliasTests.Test_DXKeeperNonSectionContestSendsNoSection;
var
   qso: ContestExchange;
begin
   BeginTest('Test_DXKeeperNonSectionContestSendsNoSection');
   CheckFalse(ContestQTHIsAnARRLSection(ContestIdentity(ContestHandleOf(NAQSOCW))),
              'NAQP CW: its QTH is no ARRL section');
   CheckFalse(ContestQTHIsAnARRLSection(ContestIdentity(ContestHandleOf(WISCONSINQSOPARTY))),
              'Wisconsin QSO Party: nor is its');

   qso := Default(ContestExchange);
   qso.ceContest := ContestHandleOf(NAQSOCW);
   qso.QTHString := 'OH';
   qso.DomesticQTH := 'OH';
   CheckEquals('', ExternalLoggerARRLSection(qso),
               'NAQP OH: an Ohio QTH, not a section the contest states -- none');
   qso.QTHString := 'CA';
   qso.DomesticQTH := 'CA';
   CheckEquals('', ExternalLoggerARRLSection(qso), 'NAQP CA: none');

   qso := Default(ContestExchange);
   qso.ceContest := ContestHandleOf(WISCONSINQSOPARTY);
   qso.QTHString := 'MAR';
   qso.DomesticQTH := 'Mar';
   CheckEquals('', ExternalLoggerARRLSection(qso), 'Wisconsin county MAR: not Maritime');
end;

(* THE DXKEEPER HAND-OFF CARRIES THE ADIF EXPORT'S RECORD, NOT ITS OWN (NY4I,
   2026-11-24). Same QSO, same facts: the text inside <ExternalLogADIF:n> is
   uADIF.EmitADIFContact with the export's tail emitter -- the exact call the
   export makes -- less the record's closing CR LF, and the framing counts
   exactly what is sent. Run for a section contest, a plain one (NAQP) and ALL
   JA, with the session's station and with a captured one. Equality only: which
   tags a contest writes is the contest's, pinned in its own tests. *)
procedure TARRLSectionAliasTests.Test_DXKeeperPayloadIsTheExportRecord;
const
   PAYLOAD_CONTESTS: array[0 .. 2] of ContestType = (ARRLSSCW, NAQSOCW, ALLJA);
   COMMAND_HEAD = '<command:11>externallog<parameters:';
   BODY_HEAD = '<ExternalLogADIF:';
var
   probe: TRecordingLogger;
   qso: ContestExchange;
   facts: TQsoMyFacts;
   command1, command2, body, expected, lengthText, what: string;
   savedContest: TContestHandle;
   c, k, bodyHeadAt, bodyStart, bodyLength, declared: integer;
begin
   BeginTest('Test_DXKeeperPayloadIsTheExportRecord');
   savedContest := Contest;
   probe := TRecordingLogger.Create(lt_DxKeeper);
   try
      for c := Low(PAYLOAD_CONTESTS) to High(PAYLOAD_CONTESTS) do
         begin
         Contest := ContestHandleOf(PAYLOAD_CONTESTS[c]);
         qso := Default(ContestExchange);
         qso.ceContest := ContestHandleOf(PAYLOAD_CONTESTS[c]);
         qso.Callsign := 'JA8GHG';
         qso.Band := Band20;
         qso.Mode := CW;
         qso.Frequency := 14025000;
         qso.tSysTime.qtYear := 26;
         qso.tSysTime.qtMonth := 11;
         qso.tSysTime.qtDay := 24;
         qso.tSysTime.qtHour := 1;
         qso.tSysTime.qtMinute := 2;
         qso.tSysTime.qtSecond := 3;
         qso.RSTSent := 599;
         qso.RSTReceived := 599;
         qso.QTHString := 'EM';
         qso.DomesticQTH := 'EMA';
         qso.ExchString := '599 EM';
         for k := 0 to 1 do
            begin
            facts := NotCapturedMyFacts;
            if k = 1 then
               begin
               facts.Source := mfsLogged;
               facts.Call := 'W2XYZ';
               facts.Grid := 'FN30';
               facts.State := 'NY';
               end;
            what := string(ContestTypeSA[PAYLOAD_CONTESTS[c]]) + ' facts ' + IntToStr(k);

            command2 := 'untouched';
            CheckTrue(probe.PrepareOp(qmNew, qso, facts, '', command1, command2) = xoSingle,
                      what + ': a new QSO is one command');
            CheckEquals('', command2, what + ': and has no second');

            expected := TrimRight(EmitADIFContact(qso, facts, '',
                                  @EmitContestSpecificTailForExport, ActiveContest(Contest)));

            (* The envelope: the command, the option flags after the record. *)
            CheckEquals(1, Pos(COMMAND_HEAD, command1), what + ': the externallog command');
            bodyHeadAt := Pos(BODY_HEAD, command1);
            CheckTrue(bodyHeadAt > 0, what + ': the ExternalLogADIF field');
            lengthText := Copy(command1, Length(COMMAND_HEAD) + 1,
                               bodyHeadAt - Length(COMMAND_HEAD) - 2);
            declared := StrToIntDef(lengthText, -1);
            CheckEquals(Length(command1) - (bodyHeadAt - 1), declared,
                        what + ': <parameters:n> counts everything after it');
            lengthText := Copy(command1, bodyHeadAt + Length(BODY_HEAD),
                               Pos('>', Copy(command1, bodyHeadAt, MaxInt)) - Length(BODY_HEAD) - 1);
            bodyLength := StrToIntDef(lengthText, -1);
            bodyStart := bodyHeadAt + Length(BODY_HEAD) + Length(lengthText) + 1;
            body := Copy(command1, bodyStart, bodyLength);
            CheckEquals(bodyLength, Length(body), what + ': <ExternalLogADIF:n> is the record''s length');

            CheckEquals(expected, body, what + ': the record IS the export''s record');
            CheckEquals('<EOR>', Copy(body, Length(body) - 4, 5), what + ': ends at <EOR>');
            CheckEquals(0, Pos(#13, command1) + Pos(#10, command1),
                        what + ': no line break anywhere in the command');
            CheckEquals(bodyStart + bodyLength, Pos('<DeduceMissing:', command1),
                        what + ': the option flags follow the record');
            end;
         end;
   finally
      Contest := savedContest;
      probe.Free;
   end;
end;

(* ARRL 160'S IMPORT -- issue 275 item 1. Its own ApplyADIFImport copied the
   raw SRX_STRING into DomesticQTH, so TR4W's own '599 CT' imported as a QTH
   of '599' and a D7 <ARRL_SECT:2>EM as nothing at all. It now resolves the
   section as typed entry does: ARRL_SECT, else QTH, else SRX_STRING less its
   RST. *)
procedure TARRLSectionAliasTests.Test_ARRL160ImportedAliasIsTheCanonicalSection;
var
   rx: ContestExchange;
begin
   BeginTest('Test_ARRL160ImportedAliasIsTheCanonicalSection');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRL160, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('W1AW', AdifTag('ARRL_SECT', 'EM')), rx),
                'ARRL_SECT EM: parsed');
      CheckEquals('EMA', string(rx.DomesticQTH), 'ARRL_SECT EM: DomesticQTH is the file''s section');
      CheckEquals('EMA', string(rx.DomMultQTH), 'ARRL_SECT EM: the multiplier is the file''s section');
      CheckEquals('EM', string(rx.QTHString),
                  'ARRL_SECT EM with no QTH tag: the section is the QTH as written');

      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1ABC', AdifTag('QTH', 'WF')), rx), 'QTH WF: parsed');
      CheckEquals('WcF', string(rx.DomesticQTH), 'QTH WF: DomesticQTH as the file spells it');

      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1XYZ', AdifTag('SRX_STRING', '599 CT')), rx),
                'SRX_STRING 599 CT: parsed');
      CheckEquals('Ct', string(rx.DomesticQTH),
                  'SRX_STRING 599 CT: the section, not the RST (it stored 599)');

      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1XYZ', AdifTag('ARRL_SECT', 'XYZ')), rx), 'XYZ: parsed');
      CheckEquals('XYZ', string(rx.DomesticQTH), 'XYZ: an explicit ARRL_SECT, kept as written');
      CheckEquals('', string(rx.DomMultQTH), 'XYZ: and no multiplier is invented');

      (* REVIEW M5: A QTH DERIVED FROM SRX_STRING follows typed entry's word
         rule. A number word is never the QTH, and the first word the table
         knows is. The matrix's own rows: '599 8' and '123' stored 8 and
         123, '59 DARC' itself. *)
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1XYZ', AdifTag('SRX_STRING', '599 8')), rx), '599 8: parsed');
      CheckEquals('', string(rx.DomesticQTH), '599 8: a number is no QTH (it stored 8)');
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1XYZ', AdifTag('SRX_STRING', '59 DARC')), rx), '59 DARC: parsed');
      CheckEquals('', string(rx.DomesticQTH), '59 DARC: no word the table knows (it stored 59 DARC)');
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K1XYZ', AdifTag('SRX_STRING', '2A CT')), rx), '2A CT: parsed');
      CheckEquals('Ct', string(rx.DomesticQTH), '2A CT: the word the table knows (it stored 2A CT)');
      CheckEquals('Ct', string(rx.DomMultQTH), '2A CT: and its multiplier');
   finally
      RestoreSession;
   end;
end;

(* TWO REAL RECORDS OF ONE QSO, W7SP in Utah worked by NY4I (WCF) -- issue
   275, NY4I 2026-11-16. Byte for byte as N1MM and DXLog.net exported them;
   not rebuilt through AdifRecord, because being real is the point.

   WHAT EACH MUST IMPORT AS: the received section UT (DomesticQTH and the
   multiplier key 'Ut', the left side of arrlsect.dom's `Ut = UT`), RST 599
   received, and the QTH string UT -- the ARRL_SECT branch fills it when the
   record has no QTH tag. Our own section WCF is SENT (STX_STRING, and
   DXLog's MY_ARRL_SECT), never anything received; and no '599' is stored as
   a QTH (the defect issue 275 item 1 fixed). The outputs follow: ADIF and
   Cabrillo say UT, and so does the section the external loggers and the
   N1MM UDP <section> send (ExternalLoggerARRLSection -- the
   ContestQTHIsAnARRLSection predicate, item 3a).

   THE TWO LOGGERS DIFFER IN WHAT THEY SAY OF OUR STATION: N1MM writes no
   MY_ field (STATION_CALLSIGN alone is not one), so its record captures no
   station facts; DXLog states MY_ARRL_SECT WCF. Only DXLog writes
   SRX_STRING, so only it leaves an ExchString.

   THEN THE DXLog RECORD LESS ITS ARRL_SECT -- NY4I: "an import missing
   ARRL_SECT looks in SRX_STRING". Its QTH string is NOT pinned here: that
   branch leaves it as the record left it (no QTH tag, so empty), which is
   reported to NY4I as open, not frozen. *)
procedure TARRLSectionAliasTests.Test_ARRL160RealN1MMAndDXLogRecords;
const
   N1MM_RECORD =
      '<CALL:4>W7SP <QSO_DATE:8>20261116 <TIME_ON:6>054319 <TIME_OFF:6>054319 ' +
      '<ARRL_SECT:2>UT <BAND:4>160M <STATION_CALLSIGN:4>NY4I <FREQ:7>1.80000 ' +
      '<CONTEST_ID:8>ARRL-160 <FREQ_RX:7>1.80000 <MODE:2>CW <RST_RCVD:3>599 ' +
      '<RST_SENT:3>599 <OPERATOR:4>NY4I <CQZ:1>3 <STX_STRING:3>WCF ' +
      '<APP_N1MM_EXCHANGE1:2>UT <APP_N1MM_POINTS:1>2 <PFX:2>W7 <EOR>';
   DXLOG_RECORD =
      '<QSO_DATE:8>20261116 <TIME_ON:6>054750 <TIME_OFF:6>054750 ' +
      '<STATION_CALLSIGN:4>NY4I <FREQ:6>1.8000 <BAND:4>160M <CONTEST_ID:8>ARRL-160 ' +
      '<MODE:2>CW <CALL:4>W7SP <RST_SENT:3>599 <RST_RCVD:3>599 <OPERATOR:4>NY4I ' +
      '<APP_DXLOG_RCVD:2>UT <APP_DXLOG_POINTS:1>2 <MY_GRIDSQUARE:6>EL88PA ' +
      '<MY_NAME:3>TOM <MY_ITU_ZONE:1>8 <MY_CQ_ZONE:1>5 <PFX:2>W7 ' +
      '<MY_ARRL_SECT:3>WCF <ARRL_SECT:2>UT <STX_STRING:3>WCF <SRX_STRING:2>UT <EOR>';
var
   rx: ContestExchange;
   facts: TQsoMyFacts;
   sent: AnsiString;
   noSectionTag: string;

   (* What every reading of this QSO must say, whichever logger wrote it. *)
   procedure CheckReceived(const aWho, aRecord: string);
   begin
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(aRecord, rx, facts, sent), aWho + ': parsed');
      CheckTrue(rx.ceContest = ContestHandleOf(ARRL160), aWho + ': CONTEST_ID ARRL-160 is ARRL 160');
      CheckEquals('W7SP', string(rx.Callsign), aWho + ': the call');
      CheckTrue(rx.Band = Band160, aWho + ': 160 m');
      CheckTrue(rx.Mode = CW, aWho + ': CW');
      CheckEquals('K', string(rx.QTH.CountryID), aWho + ': W7SP is a K QSO');
      CheckEquals(599, integer(rx.RSTReceived), aWho + ': RST received');
      CheckEquals('Ut', string(rx.DomesticQTH), aWho + ': DomesticQTH is the file''s section');
      CheckEquals('Ut', string(rx.DomMultQTH), aWho + ': the multiplier key');
      CheckEquals('UT', ADIFSectionOf(rx), aWho + ': ADIF ARRL_SECT');
      CheckEquals('UT', ExternalLoggerARRLSection(rx),
                  aWho + ': the section the external loggers and N1MM <section> send');
      CheckEquals('WCF', string(sent), aWho + ': WCF is the SENT exchange');
      (* Neither our section nor the report is anything received. *)
      CheckEquals(0, Pos('WCF', UpperCase(string(rx.QTHString) + '|' + string(rx.DomesticQTH) + '|' +
                                          string(rx.DomMultQTH) + '|' + string(rx.ExchString))),
                  aWho + ': WCF is in no received field');
      CheckEquals(0, Pos('599', string(rx.QTHString) + '|' + string(rx.DomesticQTH) + '|' +
                               string(rx.DomMultQTH) + '|' + string(rx.ExchString)),
                  aWho + ': 599 is stored as no QTH');
   end;

begin
   BeginTest('Test_ARRL160RealN1MMAndDXLogRecords');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRL160, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      CheckReceived('N1MM', N1MM_RECORD);
      CheckEquals('UT', string(rx.QTHString), 'N1MM: ARRL_SECT and no QTH tag, so the QTH string is UT');
      CheckEquals('', string(rx.ExchString), 'N1MM: no SRX_STRING, so no received exchange text');
      CheckTrue(facts.Source = mfsNotCaptured, 'N1MM: no MY_ field, so no station facts captured');
      CheckOutputs(rx, 'N1MM', 'UT');

      CheckReceived('DXLog', DXLOG_RECORD);
      CheckEquals('UT', string(rx.QTHString), 'DXLog: ARRL_SECT and no QTH tag, so the QTH string is UT');
      CheckEquals('UT', string(rx.ExchString), 'DXLog: SRX_STRING less nothing (no RST in it)');
      CheckTrue(facts.Source = mfsImported, 'DXLog: its MY_ fields are captured');
      CheckEquals('WCF', string(facts.Section), 'DXLog: MY_ARRL_SECT WCF is OUR section');
      CheckOutputs(rx, 'DXLog', 'UT');

      (* NO ARRL_SECT: the section from SRX_STRING. *)
      noSectionTag := StringReplace(DXLOG_RECORD, '<ARRL_SECT:2>UT ', '', []);
      CheckEquals(0, Pos('<ARRL_SECT:', noSectionTag), 'the variant carries no ARRL_SECT');
      CheckReceived('DXLog less ARRL_SECT', noSectionTag);
      CheckReceivedColumn(rx, 'DXLog less ARRL_SECT');
   finally
      RestoreSession;
   end;
end;

(* ISSUE 333 -- THE CABRILLO RECEIVED COLUMN OF THE RECORD JUST READ, at both
   kinds of entrant. A record with no ARRL_SECT resolves UT into DomesticQTH
   and leaves QTHString empty; the column read QTHString and printed DX for
   W7SP. It reads DomesticQTH now (NY4I: QTHString is a D7 artifact). The
   column as the writer puts it on the line: CabrilloReceivedQTH for HisQTH,
   then UpperCase of the whole column (PostUnit's CABRILLO_HISEX). *)
procedure TARRLSectionAliasTests.CheckReceivedColumn(const aRX: ContestExchange;
                                                     const aWho: string);
var
   station: TStationContext;
   entrant: TContestBase;
   my: TMyStationExchange;
   ctx: TCabrilloQSOContext;
   country: integer;
const
   COUNTRIES: array[0..1] of string = ('K', 'DL');
begin
   CheckEquals('', string(aRX.QTHString), aWho + ': the shape of issue 333 -- no QTH string');
   CheckEquals('Ut', string(aRX.DomesticQTH), aWho + ': and the section in DomesticQTH');
   my := Default(TMyStationExchange);
   ctx := Default(TCabrilloQSOContext);
   ctx.RSTSent := '599';
   ctx.RSTReceived := '599';
   ctx.HisQTH := CabrilloReceivedQTH(True, aRX);
   for country := Low(COUNTRIES) to High(COUNTRIES) do
      begin
      station := NoStation;
      station.MyCountry := CallString(COUNTRIES[country]);
      entrant := Make(ContestHandleOf(ARRL160), station);
      try
         CheckEquals('599 UT     ',
                     UpperCase(entrant.FormatCabrilloReceivedExchange(my, aRX, ctx)),
                     aWho + ': a ' + COUNTRIES[country] + ' entrant''s received column is UT, not DX');
      finally
         entrant.Free;
      end;
      end;
end;

(* THE SHARED QSO-PARTY IMPORT -- issue 275 item 2. The base's domestic arm
   (every party without its own ApplyADIFImport) did DomesticQTH :=
   QTHString, so an alias came in as written. It resolves through the table
   now, as typed entry does: michigan_cty.dom's 'Presq = PRES' stores Presq
   for a QTH of PRES, and an unknown text is kept as written. *)
(* MICHIGAN'S CABRILLO RECEIVED COLUMN FOR aRX, as the writer builds it. *)
function MichiganReceivedColumn(const aRX: ContestExchange): string;
begin
   Result := PartyReceivedCabrilloColumn(ContestHandleOf(MICHQSOPARTY), aRX);
end;

procedure TARRLSectionAliasTests.Test_QSOPartyImportedAliasIsTheFileQTH;
var
   rx: ContestExchange;
begin
   BeginTest('Test_QSOPartyImportedAliasIsTheFileQTH');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(MICHQSOPARTY, DomesticCountriesKVEKH6KL, 'michigan_cty.dom');
   try
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K8ABC', AdifTag('QTH', 'PRES')), rx), 'QTH PRES: parsed');
      CheckEquals('PRES', string(rx.QTHString), 'QTH PRES: QTHString as written');
      CheckEquals('Presq', string(rx.DomesticQTH), 'QTH PRES: DomesticQTH as the file spells it');
      CheckEquals('Presq', string(rx.DomMultQTH), 'QTH PRES: the multiplier key');

      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K8XYZ', AdifTag('QTH', 'ZZZZ')), rx), 'QTH ZZZZ: parsed');
      CheckEquals('ZZZZ', string(rx.DomesticQTH), 'QTH ZZZZ: unknown, kept as written');
      (* AN EXPLICIT QTH TAG IS KEPT, so the Cabrillo line says what was
         received (review M5 follow-up, 2026-11-16: dropping it printed an
         EMPTY column). *)
      CheckEquals('599 ZZZZ   ', MichiganReceivedColumn(rx),
                  'QTH ZZZZ: the received column is what the tag said');

      (* THE SAME UNKNOWN COUNTY DERIVED FROM SRX_STRING: no domestic QTH
         since review M5 (it stored ZZZZ); no QTH string, so the column says
         DX -- as it did before, when the stored ZZZZ was not read because
         the QTH string was empty. *)
      ClearContestExchange(rx);
      CheckTrue(ParseADIFRecord(AdifRecord('K8XYZ', AdifTag('SRX_STRING', '599 ZZZZ')), rx),
                'SRX 599 ZZZZ: parsed');
      CheckEquals('', string(rx.DomesticQTH), 'SRX 599 ZZZZ: no domestic QTH (it stored ZZZZ)');
      CheckEquals('599 DX     ', MichiganReceivedColumn(rx),
                  'SRX 599 ZZZZ: the received column is DX, unchanged');
   finally
      RestoreSession;
   end;
end;

(* ONE IMPORTED RECORD FOR THE SESSION'S CONTEST, through the path
   ImportFromADIF takes (MainUnit.ParseADIFRecord), and its outputs. The
   record is 20 m CW with RST_RCVD 599 (AdifRecord); aTags adds the rest. *)
procedure ImportFor(const aCall, aTags: string; out aDomesticQTH, aKey, aQTH: string);
var
   rx: ContestExchange;
begin
   ClearContestExchange(rx);
   aDomesticQTH := '(not parsed)';
   aKey := '(not parsed)';
   aQTH := '(not parsed)';
   if ParseADIFRecord(AdifRecord(aCall, aTags), rx) then
      begin
      aDomesticQTH := string(rx.DomesticQTH);
      aKey := string(rx.DomMultQTH);
      aQTH := string(rx.QTHString);
      end;
end;

(* CQ 160 -- issue 328. s48p14dc.dom (48 states, DC, 14 provinces) is the
   table; a W/VE station sends RS(T) and a state or province, a DX station
   RS(T) and its zone (RSTZoneOrDomesticQTH). Before: DomesticQTH was the
   raw SRX_STRING -- '599 CT', '599', '599 14'. *)
procedure TARRLSectionAliasTests.Test_CQ160ImportedQTHIsTheFileQTH;
const
   CONTESTS: array[0..1] of ContestType = (CQ160CW, CQ160SSB);
var
   i: integer;
   what: string;
   domesticQTH, key, qth: string;
begin
   BeginTest('Test_CQ160ImportedQTHIsTheFileQTH');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      what := string(ContestTypeSA[CONTESTS[i]]);
      SetUpSession(CONTESTS[i], DomesticCountriesKVE, 's48p14dc.dom');
      try
         ImportFor('W1AW', AdifTag('SRX_STRING', '599 CT'), domesticQTH, key, qth);
         CheckEquals('Ct', domesticQTH, what + ' 599 CT: the file''s state (it stored 599 CT)');
         CheckEquals('Ct', key, what + ' 599 CT: the multiplier key');

         ImportFor('W1AW', AdifTag('SRX_STRING', '59 CT'), domesticQTH, key, qth);
         CheckEquals('Ct', domesticQTH, what + ' 59 CT on a 599 record: the number word is dropped');

         ImportFor('W1AW', AdifTag('SRX_STRING', '599'), domesticQTH, key, qth);
         CheckEquals('', domesticQTH, what + ' 599 alone: no QTH (it stored 599)');
         CheckEquals('', key, what + ' 599 alone: no multiplier');

         ImportFor('VE3ABC', AdifTag('SRX_STRING', '599 VE3'), domesticQTH, key, qth);
         CheckEquals('On', domesticQTH, what + ' 599 VE3: the alias is the province');

         ImportFor('VE3ABC', AdifTag('QTH', 'ON') + AdifTag('SRX_STRING', '599'),
                   domesticQTH, key, qth);
         CheckEquals('On', domesticQTH, what + ' QTH tag ON: the province (it stored 599)');
         CheckEquals('ON', qth, what + ' QTH tag ON: QTHString as written');

         ImportFor('G3ABC', AdifTag('SRX_STRING', '599 14'), domesticQTH, key, qth);
         CheckEquals('', domesticQTH, what + ' 599 14: a DX zone is no QTH (it stored 599 14)');

         ImportFor('DL1ABC', AdifTag('SRX_STRING', '599 DL'), domesticQTH, key, qth);
         CheckEquals('', domesticQTH, what + ' 599 DL: a DX prefix the table does not know, ' +
                     'no domestic QTH (review M5; it was kept as written)');
         CheckEquals('', key, what + ' 599 DL: the table gives it no key');

         ImportFor('W1AW', AdifTag('SRX_STRING', '2A CT'), domesticQTH, key, qth);
         CheckEquals('Ct', domesticQTH, what + ' 2A CT: the word the table knows (review M5; ' +
                     'the whole text was kept as written)');
         CheckEquals('Ct', key, what + ' 2A CT: and its key');
      finally
         RestoreSession;
      end;
      end;
end;

(* UBA DX -- issue 328. RS(T), serial and, from a Belgian station, its
   section (uba.dom, whose keys are their own aliases, so the multiplier
   key is what tells a resolved QTH from one kept as written). *)
procedure TARRLSectionAliasTests.Test_UBAImportedQTHIsTheFileQTH;
const
   CONTESTS: array[0..1] of ContestType = (UBACW, UBASSB);
var
   i: integer;
   what: string;
   domesticQTH, key, qth: string;
begin
   BeginTest('Test_UBAImportedQTHIsTheFileQTH');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   for i := Low(CONTESTS) to High(CONTESTS) do
      begin
      what := string(ContestTypeSA[CONTESTS[i]]);
      SetUpSession(CONTESTS[i], ['ON'], 'uba.dom');
      try
         ImportFor('ON4ABC', AdifTag('SRX_STRING', '599 101 ACC'), domesticQTH, key, qth);
         CheckEquals('ACC', domesticQTH, what + ' 599 101 ACC: the section (it stored 599 101 ACC)');
         CheckEquals('ACC', key, what + ' 599 101 ACC: resolved, so it has its key');

         ImportFor('ON4ABC', AdifTag('SRX_STRING', '599 101'), domesticQTH, key, qth);
         CheckEquals('', domesticQTH, what + ' 599 101: a serial is no QTH (it stored 599 101)');

         ImportFor('W1AW', AdifTag('SRX_STRING', '599'), domesticQTH, key, qth);
         CheckEquals('', domesticQTH, what + ' 599 alone: no QTH (it stored 599)');
      finally
         RestoreSession;
      end;
      end;
end;

(* LZ DX (zone or district), OK/OM DX and Ukrainian DX (serial or QTH) --
   issue 328. A word that is not a number is the domestic QTH, resolved
   through the contest's file; numbers alone go to the QTH string, less the
   RST. Before: the alphabetic test ran on the raw SRX_STRING, so '599 BU'
   was the QTH string '599 BU' and no domestic QTH at all. *)
procedure TARRLSectionAliasTests.Test_ZoneOrSerialImportedQTHIsTheFileQTH;

   procedure CheckOne(aContest: ContestType; const aCountries: array of string;
                      const aDomFile, aCall, aTyped, aFileSpelling: string);
   var
      what: string;
      domesticQTH, key, qth: string;
   begin
      what := string(ContestTypeSA[aContest]);
      SetUpSession(aContest, aCountries, aDomFile);
      try
         ImportFor(aCall, AdifTag('SRX_STRING', '599 ' + aTyped), domesticQTH, key, qth);
         CheckEquals(aFileSpelling, domesticQTH, what + ' 599 ' + aTyped + ': the file''s QTH');
         CheckEquals(aFileSpelling, key, what + ' 599 ' + aTyped + ': its multiplier key');
         CheckEquals('', qth, what + ' 599 ' + aTyped + ': not the QTH string (it was 599 ' + aTyped + ')');

         ImportFor(aCall, AdifTag('SRX_STRING', '599 15'), domesticQTH, key, qth);
         CheckEquals('', domesticQTH, what + ' 599 15: a number is no domestic QTH');
         CheckEquals('15', qth, what + ' 599 15: it is the QTH string, less the RST');

         ImportFor(aCall, AdifTag('QTH', aTyped) + AdifTag('SRX_STRING', '599'),
                   domesticQTH, key, qth);
         CheckEquals(aFileSpelling, domesticQTH, what + ' QTH tag ' + aTyped + ': the file''s QTH');
         CheckEquals(aTyped, qth, what + ' QTH tag ' + aTyped + ': kept (an RST-only SRX_STRING wrote 599)');
      finally
         RestoreSession;
      end;
   end;

begin
   BeginTest('Test_ZoneOrSerialImportedQTHIsTheFileQTH');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   CheckOne(LZDX, ['LZ'], 'lz.dom', 'LZ1ABC', 'BU', 'Bu');
   CheckOne(OKDX, ['OK', 'OM'], 'okom.dom', 'OK1ABC', 'APA', 'Apa');
   CheckOne(UKRAINIAN, ['UR'], 'ukraine.dom', 'UR5ABC', 'CH', 'Ch');
end;

procedure TARRLSectionAliasTests.RunAllTests;
begin
   Test_SweepstakesTypedAliasIsTheCanonicalSection;
   Test_SweepstakesAliasAndSectionAreOneMultiplier;
   Test_ARRL160TypedAliasIsTheCanonicalSection;
   Test_EveryArrlsectAliasExportsItsSection;
   Test_ImportedAliasIsTheCanonicalSection;
   Test_EveryArrlsectAliasImportsAsItsSection;
   Test_ImportWithNoLookupKeepsTheTextAsWritten;
   Test_CanonicalSectionImportExportsAsBefore;
   Test_FieldDayStateIsTheResolvedSections;
   Test_FieldDayStateKeepsAnUnresolvedRow;
   Test_DXKeeperSendsTheResolvedSection;
   Test_DXKeeperNonSectionContestSendsNoSection;
   Test_DXKeeperPayloadIsTheExportRecord;
   Test_ARRL160ImportedAliasIsTheCanonicalSection;
   Test_ARRL160RealN1MMAndDXLogRecords;
   Test_QSOPartyImportedAliasIsTheFileQTH;
   Test_CQ160ImportedQTHIsTheFileQTH;
   Test_UBAImportedQTHIsTheFileQTH;
   Test_ZoneOrSerialImportedQTHIsTheFileQTH;
end;

end.
