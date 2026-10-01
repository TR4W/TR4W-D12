unit uTestADIFRegression;
{$I ..\..\src\tr4w.inc}

{
  Targeted regression tests for ADIF bugs fixed during the 4.147.x cycle.
  These complement the broader uTestADIF / uTestADIFFixtures suites by pinning
  the specific defects so they cannot silently return.

  All three exercise uADIF's pure, MainUnit-free entry points
  (ImportADIFFromString, EmitADIFRecord), so no trdos/UI linkage is needed.
}

interface

uses
   SysUtils, VC, uADIF, uTR4WTestFramework;

type
   TADIFRegressionTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_Import_CQZField_PopulatesZone;
      procedure Test_Import_NoModeField_StaysNoMode;
      procedure Test_Emit_ContestID_FallbackForMajors;
      procedure Test_Import_ContestID_OldAndNewSpellings;
      procedure Test_Import_ContestID_BlankMatchesNothing;
      procedure Test_Emit_ContestID_WritesOnlyTheNewSpelling;
      procedure Test_ContestID_EveryContestReimportsItsOwnExport;
   end;

implementation

procedure TADIFRegressionTests.Test_Import_CQZField_PopulatesZone;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_Import_CQZField_PopulatesZone');
   // v4.147.04: the import field-name table had 'CQ_Z' instead of 'CQZ', so
   // TR4W's own <CQZ:N> export never re-imported the CQ zone -- silent data
   // loss on every CQ-zone contest.  Import must now land CQZ into exch.Zone.
   CheckEquals(1, ImportADIFFromString(
      '<CALL:4>KG1S <BAND:3>20m <CQZ:2>14 <EOR>', records),
      'one record parsed');
   CheckEquals(14, Integer(records[0].Zone), 'CQZ field populated exch.Zone');
end;

procedure TADIFRegressionTests.Test_Import_NoModeField_StaysNoMode;
var
   records : TContestExchangeArray;
begin
   BeginTest('Test_Import_NoModeField_StaysNoMode');
   // v4.147.04: FillChar zero-init left Mode = first enum (CW), so an imported
   // record lacking a <MODE> field silently became CW.  InitContestExchangeForParse
   // now sets Mode := NoMode explicitly; a MODE-less record must stay NoMode.
   CheckEquals(1, ImportADIFFromString(
      '<CALL:4>KG1S <BAND:3>20m <EOR>', records),
      'one record parsed');
   CheckEquals(Integer(NoMode), Integer(records[0].Mode),
               'no MODE field -> NoMode, not CW');
end;

procedure TADIFRegressionTests.Test_Emit_ContestID_FallbackForMajors;
var
   rec : ContestExchange;
   s   : string;
begin
   BeginTest('Test_Emit_ContestID_FallbackForMajors');
   // v4.147.13 (#887 follow-up): EmitADIFRecord dropped CONTEST_ID for the
   // ~156 contests whose ContestsArray[].ADIFName is empty (CQ-WW, CQ-WPX,
   // ARRL-DX, ...).  It must fall back to the parallel ContestTypeSA[] string,
   // which is the standard ADIF Contest_ID for the majors.
   FillChar(rec, SizeOf(rec), 0);
   rec.ceContest := CQWWCW;
   rec.Band      := Band20;
   rec.Callsign  := 'KG1S';
   s := EmitADIFRecord(rec);
   CheckTrue(Pos('<CONTEST_ID', s) > 0,
             'CONTEST_ID emitted for CQ-WW-CW (not dropped)');
   CheckTrue(Pos('CQ-WW-CW', s) > 0,
             'CONTEST_ID value falls back to ContestTypeSA');
end;

(* THE CONTEST_ID RENAMES OF 2026-09-29 -- NY4I: "Yes support old spellings."

   Several contests changed the id ADIF export writes. An operator's existing
   files carry the OLD id, so import must resolve both; export must write only
   the new one. Each row below is (what a file carries, the contest it must
   land on).

   THE OLD SPELLINGS ARE OF TWO KINDS, and both are pinned. Some were the row's
   ADIFName ('MST', 'North Carolina QSO Party', the Mini-Tests' trailing
   space). Others were never an ADIFName at all: the row was blank, and export
   fell back to the enum's spelling ('SALMON RUN', 'EUROPEAN HFC', ...). The
   second kind never resolved on import before -- this is where it starts to.

   THROUGH ImportADIFFromString, NOT THE LOOKUP ALONE, so the assertion covers
   the lexer's handling of a value with a trailing space and the caller's use
   of the found flag. *)
procedure TADIFRegressionTests.Test_Import_ContestID_OldAndNewSpellings;

   procedure CheckResolves(const aId: string; aExpected: ContestType);
   var
      records : TContestExchangeArray;
      adif    : string;
   begin
      adif := '<CALL:4>KG1S <BAND:3>20m <CONTEST_ID:' + IntToStr(Length(aId)) +
              '>' + aId + ' <EOR>';
      CheckEquals(1, ImportADIFFromString(adif, records),
                  'one record parsed for [' + aId + ']');
      if Length(records) <> 1 then
         begin
         Exit;
         end;
      CheckEquals(Ord(aExpected), Ord(records[0].ceContest),
                  'CONTEST_ID [' + aId + '] -> ' + ContestTypeSA[aExpected]);
   end;

begin
   BeginTest('Test_Import_ContestID_OldAndNewSpellings');

   (* The new ids. *)
   CheckResolves('ICWC-MST', MST);
   CheckResolves('EU-HF', EUROPEANHFC);
   CheckResolves('AP-SPRINT', APSPRINT);
   CheckResolves('WA-QSO-PARTY', SALMONRUN);
   CheckResolves('MINITEST-40', MINI40);
   CheckResolves('MINITEST-80', MINI80);
   CheckResolves('NC-QSO-PARTY', NCQSOPARTY);
   CheckResolves('JW-FD', NZFIELDDAY);
   CheckResolves('CA-QSO-PARTY', CALQSOPARTY);
   CheckResolves('OH-QSO-PARTY', OHIOQSOPARTY);
   CheckResolves('NY-QSO-PARTY', NYQP);
   CheckResolves('BC-QSO-PARTY', BCQP);

   (* The former row values. *)
   CheckResolves('MST', MST);
   CheckResolves('North Carolina QSO Party', NCQSOPARTY);
   CheckResolves('MINITEST-40 ', MINI40);
   CheckResolves('MINITEST-80 ', MINI80);

   (* The former export fallbacks -- the enum's spelling, written while the
      row's ADIFName was blank. AP Sprint's and New York's fallback was already
      the id they have now, which is why they appear only above. *)
   CheckResolves('EUROPEAN HFC', EUROPEANHFC);
   CheckResolves('SALMON RUN', SALMONRUN);
   CheckResolves('CALIFORNIA QSO PARTY', CALQSOPARTY);
   CheckResolves('OHIO QSO PARTY', OHIOQSOPARTY);
   CheckResolves('BCQP', BCQP);
end;

(* A BLANK CONTEST_ID IDENTIFIES NO CONTEST.

   The lookup used to return the first contest whose ADIFName was blank, and
   its caller accepted that as a match -- so an empty value "found" a contest.
   A blank ADIFName means "this contest has no id"; it can never be one.

   THE CACHE IS EXERCISED ON PURPOSE: a hit for 'MST' first, then the blank,
   then 'MST' again. A single-entry cache that answered the blank from its
   initial or previous state is exactly the shape the old one had. *)
procedure TADIFRegressionTests.Test_Import_ContestID_BlankMatchesNothing;
var
   c : ContestType;
begin
   BeginTest('Test_Import_ContestID_BlankMatchesNothing');

   CheckTrue(GetContestByADIFName('MST', c), 'MST resolves');
   CheckEquals(Ord(MST), Ord(c), 'MST -> MST');

   CheckFalse(GetContestByADIFName('', c), 'an empty id matches nothing');
   CheckEquals(Ord(Low(ContestType)), Ord(c),
               'no match leaves the first contest, not a blank row''s');

   CheckFalse(GetContestByADIFName('   ', c), 'an all-blank id matches nothing');
   CheckFalse(GetContestByADIFName('NOT-A-CONTEST', c),
              'an unknown id matches nothing');

   CheckTrue(GetContestByADIFName('MST', c), 'MST still resolves after a miss');
   CheckEquals(Ord(MST), Ord(c), 'MST -> MST, second time');
end;

(* EXPORT WRITES ONLY THE NEW SPELLING -- the other half of the ruling. Each
   expectation carries its own length prefix, so a trailing space coming back
   (MINITEST-40 was 12 characters) fails on the prefix as well as the text. *)
procedure TADIFRegressionTests.Test_Emit_ContestID_WritesOnlyTheNewSpelling;

   procedure CheckEmits(aContest: ContestType; const aField: string);
   var
      rec : ContestExchange;
      s   : string;
   begin
      FillChar(rec, SizeOf(rec), 0);
      rec.ceContest := aContest;
      rec.Band      := Band20;
      rec.Callsign  := 'KG1S';
      s := EmitADIFRecord(rec);
      CheckTrue(Pos(aField, s) > 0,
                ContestTypeSA[aContest] + ' emits ' + aField + ' -- got: ' + s);
   end;

begin
   BeginTest('Test_Emit_ContestID_WritesOnlyTheNewSpelling');
   CheckEmits(MST, '<CONTEST_ID:8>ICWC-MST ');
   CheckEmits(EUROPEANHFC, '<CONTEST_ID:5>EU-HF ');
   CheckEmits(APSPRINT, '<CONTEST_ID:9>AP-SPRINT ');
   CheckEmits(SALMONRUN, '<CONTEST_ID:12>WA-QSO-PARTY ');
   CheckEmits(MINI40, '<CONTEST_ID:11>MINITEST-40 ');
   CheckEmits(MINI80, '<CONTEST_ID:11>MINITEST-80 ');
   CheckEmits(NCQSOPARTY, '<CONTEST_ID:12>NC-QSO-PARTY ');
   CheckEmits(NZFIELDDAY, '<CONTEST_ID:5>JW-FD ');
end;

(* TR4W READS BACK EVERY CONTEST_ID IT WRITES -- inventory D9, closed by M1
   (2026-10-01).

   Until M1, export wrote "ADIFName, else the enum's spelling" while import
   matched the class's ADIFContestId, which was '' for a blank ADIFName. So a
   file TR4W exported for 139 contests -- CQ WW, CQ WPX, ARRL DX, Sweepstakes,
   IARU among them -- never resolved back to its contest. Both sides now ask
   the same getter.

   THROUGH THE REAL EMITTER AND THE REAL IMPORTER, for every ContestType, so
   the assertion covers the lexer and the cache as well as the lookup.

   THE EXCEPTIONS, each asserted rather than skipped:
     DUMMYCONTEST     "no contest". Not exported for, never selectable.
     POTA, GENERALQSO export writes NO CONTEST_ID at all, so there is nothing
                      to read back -- asserted absent.
     RSGB_ROPOCO_SSB  shares 'RSGB-ROLO' with the CW running, the one current
                      id two rows hold, so it reads back as CW. Import has
                      always resolved it so; telling them apart needs the
                      MODE, which is M5's import work, not an id. *)
procedure TADIFRegressionTests.Test_ContestID_EveryContestReimportsItsOwnExport;
var
   c        : ContestType;
   rec      : ContestExchange;
   s        : string;
   records  : TContestExchangeArray;
   who      : string;
   expected : ContestType;
   resolved : integer;
begin
   BeginTest('Test_ContestID_EveryContestReimportsItsOwnExport');
   CheckEquals(Ord(DUMMYCONTEST), Ord(Low(ContestType)),
               'DUMMYCONTEST is the first ContestType');

   resolved := 0;
   for c := Succ(Low(ContestType)) to High(ContestType) do
      begin
      who := string(ContestTypeSA[c]);

      FillChar(rec, SizeOf(rec), 0);
      rec.ceContest := c;
      rec.Band      := Band20;
      rec.Callsign  := 'KG1S';
      s := EmitADIFRecord(rec) + '<EOR>';

      if c in [POTA, GENERALQSO] then
         begin
         CheckTrue(Pos('<CONTEST_ID', s) = 0,
                   who + ' writes no CONTEST_ID -- got: ' + s);
         Continue;
         end;

      CheckTrue(Pos('<CONTEST_ID', s) > 0, who + ' writes a CONTEST_ID');
      CheckEquals(1, ImportADIFFromString(s, records),
                  who + ': one record read back');
      if Length(records) <> 1 then
         begin
         Continue;
         end;

      expected := c;
      if c = RSGB_ROPOCO_SSB then
         begin
         expected := RSGB_ROPOCO_CW;
         end;
      CheckEquals(Ord(expected), Ord(records[0].ceContest),
                  who + ' read back as ' +
                  string(ContestTypeSA[records[0].ceContest]) + ' -- wrote: ' + s);
      if records[0].ceContest = c then
         begin
         inc(resolved);
         end;
      end;

   (* A FLOOR, so the loop cannot pass by checking nothing: every contest but
      the four exceptions above round-trips to itself. *)
   CheckEquals(Ord(High(ContestType)) + 1 - 4, resolved,
               'contests whose own export reads back to them');
end;

procedure TADIFRegressionTests.RunAllTests;
begin
   Test_Import_CQZField_PopulatesZone;
   Test_Import_NoModeField_StaysNoMode;
   Test_Emit_ContestID_FallbackForMajors;
   Test_Import_ContestID_OldAndNewSpellings;
   Test_Import_ContestID_BlankMatchesNothing;
   Test_Emit_ContestID_WritesOnlyTheNewSpelling;
   Test_ContestID_EveryContestReimportsItsOwnExport;
end;

end.
