unit uTestCTYDAT;
{$I ..\..\src\tr4w.inc}

{
  Tests for uCTYDAT callsign -> DXCC entity lookup (Issue #1033,
  pre-migration roadmap item 2).

  These pin the country-database lookup that ~109k lines of contest code
  rely on for country, continent and zone assignment, so it survives the
  Delphi 12 Unicode / 64-bit phases unchanged.

  Test data: the real, git-tracked cty.dat shipped in tr4w\target\.
  It is resolved relative to the test EXE (test\unit\ -> ..\..\target\)
  and loaded once via ctyLoadInCountryFile -- the same call the app makes
  at startup (tr4w.lpr) -- so the tests exercise the actual
  load -> shell-sort -> index -> binary-search pipeline, not a mock.

  Asserted values were verified directly against the country header lines
  in tr4w\target\cty.dat (name : CQ : ITU : Continent : ... : primaryPrefix):
      United States      NA  K    CQ 05  ITU 08
      England            EU  G    CQ 14  ITU 27
      Japan              AS  JA   CQ 25
      Fed. Rep. Germany  EU  DL
      Argentina          SA  LU
      Australia          OC  VK
      South Africa       AF  ZS

  Conventions (docs/tr4w-migration-strategy.md): cast enums/Bytes to
  Integer before CheckEquals; keep each method focused on one entity.

  Note: uCTYDAT was decoupled from MainUnit (own Log4D logger) as part of
  this issue so it could be linked into the dependency-light test EXE.
}

interface

uses
   uTR4WTestFramework;

type
   TCTYDATTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      FLoaded: Boolean;

      // Loads cty.dat once (idempotent). Asserts the load succeeded.
      procedure EnsureCtyLoaded;
      // Asserts a callsign resolves to the expected continent + DXCC id.
      procedure CheckEntity(const Call: string; ExpectCont: Integer;
                            const ExpectID, Ctx: string);

      procedure Test_LoadCtyDat;
      procedure Test_UnitedStates_W1AW;
      procedure Test_England_G3;
      procedure Test_Japan_JA1;
      procedure Test_Germany_DL1;
      procedure Test_Argentina_LU1;
      procedure Test_Australia_VK2;
      procedure Test_SouthAfrica_ZS6;
      procedure Test_Zones_W1_England_Japan;
      procedure Test_UnknownCountryIndex;

      (* THE CHARACTERISATION NET.

        One record per callsign in fixtures\ctydat_characterisation.txt --
        1684 of them -- comparing EVERY public lookup at once. It exists so
        uCTYDAT can be rewritten without changing what it answers.

        The tests above assert what the right answer IS for nine entities.
        This one asserts that the answer DOES NOT MOVE, for 1573 real
        callsigns out of the golden-corpus logs plus 111 hand-picked edge
        cases. The two are different jobs and both are wanted: a rewrite that
        is merely self-consistent passes the first kind and fails this. *)
      procedure Test_Characterisation;

      (* THE RULES, ASSERTED BY NAME.

        The characterisation file pins these too, but as one line among 1684 --
        a failure there says "W1AW/4 moved" and not "the portable-suffix rule
        broke". These say which RULE broke, which is what someone reading a red
        build needs. *)
      procedure Test_Rule_USCallAreasShareOneCountry;
      procedure Test_Rule_CanadianDistrictsChangeZone;
      procedure Test_Rule_RussianDistrictsChangeCountry;
      procedure Test_Rule_KG4TwoCharacterSuffixIsGuantanamo;
      procedure Test_Rule_PortableSuffixRetargets;
      procedure Test_Rule_PortablePrefixWins;
      procedure Test_Rule_MaritimeMobileHasNoEntity;
      procedure Test_Rule_LookupIsCaseSensitive;
      procedure Test_Rule_GarbageAndBoundariesAreUnknown;
      procedure Test_Rule_USTerritoriesAreSeparateEntities;
      procedure Test_Rule_DuplicatePrefixPicksTheSpecificEntity;
      procedure Test_Rule_ExactCallBeatsPrefixOverride;
      procedure Test_RemainingMultsSection;
      procedure Test_BangLineMergesEntities;
      procedure Test_ReloadReplacesRatherThanAppends;
   end;

implementation

uses
   SysUtils, VC, uCTYDAT;

// ---------------------------------------------------------------------------
// Load helper -- loads the shipped cty.dat once, relative to the test EXE.
// ---------------------------------------------------------------------------

procedure TCTYDATTests.EnsureCtyLoaded;
var
   path: string;
begin
   if FLoaded then
      begin
      Exit;
      end;

   // test\unit\tr4w_unit_tests.exe -> ..\..\target\cty.dat
   (* PathDelim -- see the note in uTestLogBinaryFile. *)
   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
           PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(FileExists(path), 'cty.dat present at ' + path);
   if not FileExists(path) then
      begin
      Exit;
      end;

   // (CheckDupe=False, LoadRemainingMults=False) -- the country/continent/
   // zone tables come from the main parse; remaining-mults data is not
   // needed for entity lookups and avoids extra file dependencies.
   (* ReplaceTable, so a reload REPLACES the table rather than appending to
     it. Without it every reload in this suite added another ~693 entities to
     an array[0..999] and the third one wrote off the end -- which is how that
     defect was found. *)
   CheckTrue(ctyLoadInCountryFile(path, False, False, {ReplaceTable} True),
             'ctyLoadInCountryFile succeeded');
   FLoaded := True;
end;

procedure TCTYDATTests.CheckEntity(const Call: string; ExpectCont: Integer;
                                   const ExpectID, Ctx: string);
begin
   CheckEquals(ExpectCont, Integer(ctyGetContinent(Call)), Ctx + ' continent');
   CheckEquals(ExpectID, Trim(ctyGetCountryID(Call)), Ctx + ' DXCC id');
end;

// ---------------------------------------------------------------------------
// Load + sanity
// ---------------------------------------------------------------------------

procedure TCTYDATTests.Test_LoadCtyDat;
begin
   BeginTest('Test_LoadCtyDat');
   EnsureCtyLoaded;
   // The shipped cty.dat lists ~340 DXCC entities; a low bound proves the
   // parse populated the country table without hard-coding the exact count.
   CheckTrue(ctyGetTotalCountries > 300, 'country table populated (> 300)');
end;

// ---------------------------------------------------------------------------
// Continent + DXCC-id spot checks, one representative call per continent
// ---------------------------------------------------------------------------

procedure TCTYDATTests.Test_UnitedStates_W1AW;
begin
   BeginTest('Test_UnitedStates_W1AW');
   EnsureCtyLoaded;
   CheckEntity('W1AW', Integer(NorthAmerica), 'K', 'W1AW (USA)');
end;

procedure TCTYDATTests.Test_England_G3;
begin
   BeginTest('Test_England_G3');
   EnsureCtyLoaded;
   CheckEntity('G3ABC', Integer(Europe), 'G', 'G3ABC (England)');
end;

procedure TCTYDATTests.Test_Japan_JA1;
begin
   BeginTest('Test_Japan_JA1');
   EnsureCtyLoaded;
   CheckEntity('JA1ABC', Integer(Asia), 'JA', 'JA1ABC (Japan)');
end;

procedure TCTYDATTests.Test_Germany_DL1;
begin
   BeginTest('Test_Germany_DL1');
   EnsureCtyLoaded;
   CheckEntity('DL1ABC', Integer(Europe), 'DL', 'DL1ABC (Germany)');
end;

procedure TCTYDATTests.Test_Argentina_LU1;
begin
   BeginTest('Test_Argentina_LU1');
   EnsureCtyLoaded;
   CheckEntity('LU1ABC', Integer(SouthAmerica), 'LU', 'LU1ABC (Argentina)');
end;

procedure TCTYDATTests.Test_Australia_VK2;
begin
   BeginTest('Test_Australia_VK2');
   EnsureCtyLoaded;
   CheckEntity('VK2ABC', Integer(Oceania), 'VK', 'VK2ABC (Australia)');
end;

procedure TCTYDATTests.Test_SouthAfrica_ZS6;
begin
   BeginTest('Test_SouthAfrica_ZS6');
   EnsureCtyLoaded;
   CheckEntity('ZS6ABC', Integer(Africa), 'ZS', 'ZS6ABC (South Africa)');
end;

// ---------------------------------------------------------------------------
// CQ / ITU zone spot checks (uniform-zone entities only, to avoid
// dependence on per-prefix zone overrides).
// ---------------------------------------------------------------------------

procedure TCTYDATTests.Test_Zones_W1_England_Japan;
begin
   BeginTest('Test_Zones_W1_England_Japan');
   EnsureCtyLoaded;

   // New England (W1): CQ 5 / ITU 8
   CheckEquals(5, Integer(ctyGetCQZone('W1AW')),  'W1AW CQ zone');
   CheckEquals(8, Integer(ctyGetITUZone('W1AW')), 'W1AW ITU zone');

   // England: CQ 14 / ITU 27
   CheckEquals(14, Integer(ctyGetCQZone('G3ABC')),  'G3ABC CQ zone');
   CheckEquals(27, Integer(ctyGetITUZone('G3ABC')), 'G3ABC ITU zone');

   // Japan CQ 25 (ITU zone varies across the country, so not asserted)
   CheckEquals(25, Integer(ctyGetCQZone('JA1ABC')), 'JA1ABC CQ zone');
end;

// ---------------------------------------------------------------------------
// Negative / edge: the UNKNOWN_COUNTRY sentinel maps to nothing.
// Pure index getters -- deterministic, no lookup needed.
// ---------------------------------------------------------------------------

procedure TCTYDATTests.Test_UnknownCountryIndex;
begin
   BeginTest('Test_UnknownCountryIndex');
   EnsureCtyLoaded;
   CheckEquals(Integer(UnknownContinent),
               Integer(ctyGetContinentByIndex(UNKNOWN_COUNTRY)),
               'UNKNOWN_COUNTRY -> UnknownContinent');
   CheckEquals('', Trim(ctyGetCountryIdByIndex(UNKNOWN_COUNTRY)),
               'UNKNOWN_COUNTRY -> empty DXCC id');
end;

// ---------------------------------------------------------------------------
// Suite entry point
// ---------------------------------------------------------------------------


// ---------------------------------------------------------------------------
// THE RULES
//
// Each of these states one behaviour of the country lookup in its own test, so
// a red build names the rule rather than a callsign.  The numbers come from
// the shipped cty.dat and are asserted RELATIVELY wherever the absolute value
// is an artifact of that file -- two calls resolving to the SAME country is a
// rule; country 183 being the USA is a fact about one file.
// ---------------------------------------------------------------------------

procedure TCTYDATTests.Test_Rule_USCallAreasShareOneCountry;
var
   k1: Word;
begin
   BeginTest('every US call area is ONE country, with its own zone');
   EnsureCtyLoaded;
   k1 := ctyGetCountry('K1ABC');
   CheckEquals(k1, ctyGetCountry('K2ABC'), 'K2');
   CheckEquals(k1, ctyGetCountry('K4ABC'), 'K4');
   CheckEquals(k1, ctyGetCountry('K6ABC'), 'K6');
   CheckEquals(k1, ctyGetCountry('K0ABC'), 'K0');
   CheckEquals(k1, ctyGetCountry('W6ABC'), 'W6');
   CheckEquals(k1, ctyGetCountry('N0ABC'), 'N0');
   CheckEquals(k1, ctyGetCountry('AA1ABC'), 'AA1');

   // ...but the ZONE differs across the country, which is the whole reason
   // the per-call lookup exists rather than a per-country default.
   Check(ctyGetCQZone('K1ABC') <> ctyGetCQZone('K6ABC'),
         'CQ zone differs between the east and west coasts');
end;

procedure TCTYDATTests.Test_Rule_CanadianDistrictsChangeZone;
var
   ve: Word;
begin
   BeginTest('Canadian districts are one country across many zones');
   EnsureCtyLoaded;
   ve := ctyGetCountry('VE1ABC');
   CheckEquals(ve, ctyGetCountry('VE3ABC'), 'VE3');
   CheckEquals(ve, ctyGetCountry('VE7ABC'), 'VE7');
   Check(ctyGetCQZone('VE1ABC') <> ctyGetCQZone('VE7ABC'),
         'VE1 and VE7 are in different CQ zones');
end;

procedure TCTYDATTests.Test_Rule_RussianDistrictsChangeCountry;
begin
   (* THE OPPOSITE OF THE US RULE, and the one most likely to be broken by a
     rewrite that treats the digit as decoration: in Russia the district digit
     selects a different DXCC ENTITY and a different CONTINENT. *)
   BeginTest('a Russian district digit selects a different entity');
   EnsureCtyLoaded;
   Check(ctyGetCountry('UA1ABC') <> ctyGetCountry('UA9ABC'),
         'UA1 and UA9 are different countries');
   CheckEquals(Ord(Europe), Ord(ctyGetContinent('UA1ABC')), 'UA1 is Europe');
   CheckEquals(Ord(Asia),   Ord(ctyGetContinent('UA9ABC')), 'UA9 is Asia');
end;

procedure TCTYDATTests.Test_Rule_KG4TwoCharacterSuffixIsGuantanamo;
begin
   (* A REAL DXCC RULE AND A GENUINE TRAP. KG4 + exactly two characters is
     Guantanamo Bay; KG4 + anything else is an ordinary US call. A prefix
     match alone gets this wrong, and the answer changes the multiplier. *)
   BeginTest('KG4 with a two-character suffix is Guantanamo, otherwise USA');
   EnsureCtyLoaded;
   Check(ctyGetCountry('KG4AB') <> ctyGetCountry('KG4ABC'),
         'KG4AB and KG4ABC are different entities');
   CheckEquals(ctyGetCountry('K1ABC'), ctyGetCountry('KG4ABC'),
               'KG4ABC is an ordinary US call');
   CheckEquals('KG4', ctyGetCountryID('KG4AB'), 'KG4AB is Guantanamo');
end;

procedure TCTYDATTests.Test_Rule_PortableSuffixRetargets;
begin
   (* W1AW/4 is a Connecticut station operating in the fourth call area. The
     COUNTRY does not change -- it is still the USA -- but the resolved prefix
     follows the suffix, which is what the band map and the mult tracker show. *)
   BeginTest('a portable suffix retargets within the same country');
   EnsureCtyLoaded;
   CheckEquals(ctyGetCountry('W1AW'), ctyGetCountry('W1AW/4'),
               'W1AW/4 is still the USA');
   CheckEquals(ctyGetCountry('K1ABC'), ctyGetCountry('K1ABC/P'),
               '/P does not move the country');
   CheckEquals(ctyGetCountry('G3XYZ'), ctyGetCountry('G3XYZ/P'),
               'a G /P is still England');
end;

procedure TCTYDATTests.Test_Rule_PortablePrefixWins;
begin
   (* VE3/K1ABC is an American operating FROM Canada.  The country is the
     PREFIX's, not the home call's -- getting this backwards would credit the
     wrong multiplier on every guest operation. *)
   BeginTest('a portable prefix decides the country, not the home call');
   EnsureCtyLoaded;
   CheckEquals(ctyGetCountry('VE3ABC'), ctyGetCountry('VE3/K1ABC'),
               'VE3/K1ABC is Canada');
   Check(ctyGetCountry('VE3/K1ABC') <> ctyGetCountry('K1ABC'),
         'and NOT the USA');
   CheckEquals(ctyGetCountry('F5ABC'), ctyGetCountry('F/DL1ABC'),
               'F/DL1ABC is France');
end;

procedure TCTYDATTests.Test_Rule_MaritimeMobileHasNoEntity;
begin
   (* /MM is at sea: no DXCC entity, no zone, no continent.  It must not
     fall back to the home call's country, or a maritime contact would be
     credited as a multiplier it is not. *)
   BeginTest('/MM resolves to no entity at all');
   EnsureCtyLoaded;
   CheckEquals(65535, ctyGetCountry('K1ABC/MM'), 'K1ABC/MM has no country');
   CheckEquals(65535, ctyGetCountry('G3XYZ/MM'), 'G3XYZ/MM has no country');
   CheckEquals(255, ctyGetCQZone('K1ABC/MM'), 'and no CQ zone');
   CheckEquals(Ord(UnknownContinent), Ord(ctyGetContinent('K1ABC/MM')),
               'and no continent');
end;

procedure TCTYDATTests.Test_Rule_LookupIsCaseSensitive;
begin
   (* THE LOOKUP IS CASE-SENSITIVE AND THE CALLER MUST UPPERCASE FIRST.

     This is characterised, not endorsed. 'w1aw' resolves to NOTHING today,
     so every caller in the program is uppercasing before it gets here, and a
     rewrite that quietly started accepting lower case would hide the day one
     of them stops. If that is ever made case-insensitive it is a deliberate
     change with its own commit -- and this test is where it gets updated. *)
   BeginTest('the lookup is case-sensitive (characterised, not endorsed)');
   EnsureCtyLoaded;
   Check(ctyGetCountry('W1AW') <> 65535, 'upper case resolves');
   CheckEquals(65535, ctyGetCountry('w1aw'), 'lower case does NOT');
   CheckEquals(65535, ctyGetCountry('ja1abc'), 'nor a lower-case JA');
end;

procedure TCTYDATTests.Test_Rule_GarbageAndBoundariesAreUnknown;
begin
   (* A contest logger is typed into at speed. Every one of these is something
     an operator can produce with a slip, and none of them may resolve to a
     country or crash the lookup. *)
   BeginTest('garbage, empty and boundary inputs resolve to nothing');
   EnsureCtyLoaded;
   CheckEquals(65535, ctyGetCountry(''), 'empty');
   CheckEquals(65535, ctyGetCountry('X'), 'one letter');
   CheckEquals(65535, ctyGetCountry('1'), 'one digit');
   CheckEquals(65535, ctyGetCountry('123'), 'digits only');
   (* 'Q' IS THE ONE LETTER NO AMATEUR PREFIX STARTS WITH -- ITU reserves
     the Q block for Q-codes -- which is what makes QQQQQQ genuinely
     unallocated rather than merely unlikely. *)
   CheckEquals(65535, ctyGetCountry('QQQQQQ'), 'an unallocated prefix block');
   CheckEquals(65535, ctyGetCountry('/'), 'a lone slash');
   CheckEquals(65535, ctyGetCountry('//'), 'two slashes');
   CheckEquals(65535, ctyGetCountry('W1AW/'), 'a trailing slash');
   CheckEquals(65535, ctyGetCountry('/W1AW'), 'a leading slash');
   CheckEquals(65535, ctyGetCountry('-'), 'the dash sentinel');

   (* AND THE OTHER HALF OF THE RULE, which the first draft of this test got
     wrong: nonsense that STARTS WITH A REAL BLOCK still resolves, and must.
     ITU allocates ZV-ZZ to Brazil, so ZZZZZZ is Brazil -- the lookup matches
     the longest PREFIX, it does not validate the callsign. AB likewise is a
     real US block. Asserting these resolve is what keeps a rewrite from
     'fixing' garbage handling by rejecting legitimate prefixes. *)
   Check(ctyGetCountry('ZZZZZZ') <> 65535, 'ZZZZZZ is in Brazil'+chr(39)+'s block');
   CheckEquals('PY', ctyGetCountryID('ZZZZZZ'), 'ZV-ZZ is Brazil');
   CheckEquals(ctyGetCountry('K1ABC'), ctyGetCountry('AB'), 'AB is a US block');
end;

procedure TCTYDATTests.Test_Rule_USTerritoriesAreSeparateEntities;
var
   k: Word;
begin
   (* Hawaii, Alaska, Guam and Puerto Rico are the USA politically and are
     SEPARATE DXCC entities on the air -- each its own multiplier. *)
   BeginTest('US territories are separate DXCC entities');
   EnsureCtyLoaded;
   k := ctyGetCountry('K1ABC');
   Check(ctyGetCountry('KH6ABC') <> k, 'Hawaii is not the USA');
   Check(ctyGetCountry('KL7ABC') <> k, 'Alaska is not the USA');
   Check(ctyGetCountry('KH2ABC') <> k, 'Guam is not the USA');
   Check(ctyGetCountry('KP4ABC') <> k, 'Puerto Rico is not the USA');
   Check(ctyGetCountry('KH6ABC') <> ctyGetCountry('KL7ABC'),
         'and they are not each other');
end;

// ---------------------------------------------------------------------------
// THE CHARACTERISATION NET
// ---------------------------------------------------------------------------


(* ===========================================================================
  THE SAME CALLSIGN UNDER TWO ENTITIES.

  cty.dat files these callsigns twice -- once under a DXCC country, once under
  a sub-entity whose primary prefix carries a leading asterisk:

      Vienna Intl Ctr  *4U1V  (23)   vs  Austria   OE  (208)
      Shetland Islands *GM/s  (144)  vs  Scotland  GM  (143)

  NY4I's rule, 2026-09-14: the specific one wins, then the less specific. The
  sub-entity is the specific one, so it wins wherever it is allowed to count.

  THIS IS THE CHECK THE CHARACTERISATION FIXTURE CANNOT BE. That fixture runs
  in one country mode and records whatever the program says; it would have
  been just as green while the answers were split four/two by an unstable sort,
  which is exactly the state this test was written to make impossible. Here the
  rule is asserted directly, in both modes, over the whole duplicate set. *)
procedure TCTYDATTests.Test_Rule_DuplicatePrefixPicksTheSpecificEntity;
const
   (* Every callsign cty.dat files under both members of a pair. *)
   VIENNA : array[0..7] of string =
      ('4U0IARU', '4U0R', '4U1A', '4U1VIC', '4U2U', '4UNR', '4Y1A', 'C7A');
   SHETLAND : array[0..4] of string =
      ('GB1DAA', 'GB2ELH', 'GB3LER', 'GB3LER/B', 'GB4LER');
var
   saved : CountryModeType;
   call  : string;
   i     : integer;
begin
   BeginTest('a callsign filed under two entities resolves to the specific one');
   EnsureCtyLoaded;

   saved := CTY.ctyCountryMode;
   try
      (* CQ mode counts DXCC and WAE, so the sub-entity is a country of its
        own and is the answer. *)
      ctySetCountryMode(CQCountryMode);
      for i := Low(VIENNA) to High(VIENNA) do
         begin
         call := VIENNA[i];
         CheckEquals('*4U1V', ctyGetCountryID(call),
                     call + ' is the Vienna Intl Ctr in CQ mode');
         end;
      for i := Low(SHETLAND) to High(SHETLAND) do
         begin
         call := SHETLAND[i];
         CheckEquals('*GM/s', ctyGetCountryID(call),
                     call + ' is Shetland in CQ mode');
         end;

      (* ARRL mode counts DXCC only. The sub-entity is not a DXCC entity, so
        the country it sits inside is the answer. *)
      ctySetCountryMode(ARRLCountryMode);
      for i := Low(VIENNA) to High(VIENNA) do
         begin
         call := VIENNA[i];
         CheckEquals('OE', ctyGetCountryID(call),
                     call + ' is Austria in ARRL mode');
         end;
      for i := Low(SHETLAND) to High(SHETLAND) do
         begin
         call := SHETLAND[i];
         CheckEquals('GM', ctyGetCountryID(call),
                     call + ' is Scotland in ARRL mode');
         end;
   finally
      ctySetCountryMode(saved);
   end;

   (* AND NEITHER MODE MAY BE AMBIGUOUS. Every call in a pair must give the
     same answer as every other call in that pair -- the defect this replaced
     was not a wrong answer, it was two different answers from one rule. *)
   for i := Low(VIENNA) to High(VIENNA) do
      begin
      CheckEquals(ctyGetCountry(VIENNA[0]), ctyGetCountry(VIENNA[i]),
                  VIENNA[i] + ' agrees with the rest of its pair');
      end;
   for i := Low(SHETLAND) to High(SHETLAND) do
      begin
      CheckEquals(ctyGetCountry(SHETLAND[0]), ctyGetCountry(SHETLAND[i]),
                  SHETLAND[i] + ' agrees with the rest of its pair');
      end;
end;

(* The other axis of the same rule, and the one that has nothing to do with
  entities. UA4H is in cty.dat twice under ONE country:

      UA4H[30]     a prefix override, in the UA block
      =UA4H[29]    an exact-callsign exception, also UA

  so the two records differ only in ITU zone, and the specific one -- the
  exception -- is the answer for the callsign UA4H. The shortened-prefix walk
  wants the opposite record, which is why ctyFindCallsign is told which kind
  the caller means rather than guessing. UA4HBM exercises that path: it has its
  own exception, and the prefix behind it is the [30] one. *)
procedure TCTYDATTests.Test_Rule_ExactCallBeatsPrefixOverride;
begin
   BeginTest('an =CALL exception beats a prefix override of the same spelling');
   EnsureCtyLoaded;

   CheckEquals(29, ctyGetITUZone('UA4H'),
               'UA4H takes the =UA4H[29] exception, not the UA4H[30] prefix');
   CheckEquals(29, ctyGetITUZone('UA4HBM'),
               'UA4HBM has an exception of its own');
   CheckEquals(ctyGetCountry('UA4H'), ctyGetCountry('UA4HBM'),
               'both are still Russia -- only the zone differed');
end;


(* ===========================================================================
  THE `REMAINING MULTS` SECTION -- AND A COMMENT THAT SAID IT COULD NOT WORK.

  An operator may append a section to their own cty.dat naming the entities
  the remaining-multiplier windows should list:

      REMAINING MULTS
      T2B

  The loader's branch for it carried a note claiming it was "effectively
  disabled" because StrPos resolved to the WideChar variant and could never
  find the ANSI marker in a byte-mapped file. Nothing tested it, the shipped
  cty.dat has no such section, and so nobody could tell -- which is what makes
  a comment like that expensive: it is a claim about behaviour that reads as
  established fact and costs nothing to leave wrong.

  This is the check. It writes a two-entity country file with the section,
  loads it with LoadRemainingMults set, and asserts what the section is
  supposed to do: ctyCustomRemainingCountryListFound goes True and only the
  named entity is marked VisibleInRM = 2 -- which is what logedit and uMults
  read.

  IT RUNS LAST AND PUTS THE SHIPPED FILE BACK, because it replaces the global
  country table for the duration. *)
procedure TCTYDATTests.Test_RemainingMultsSection;
var
   path : string;
   f    : TextFile;
   i    : integer;
   idxA : integer;
   idxB : integer;
begin
   BeginTest('a REMAINING MULTS section marks the entities it names');

   path := ExtractFilePath(ParamStr(0)) + 'cty_remaining_mults_probe.dat';
   AssignFile(f, path);
   Rewrite(f);
   try
      WriteLn(f, 'Testland A:               14:  27:  EU:   50.00:   -10.00:     0.0:  T1A:');
      WriteLn(f, '    T1A;');
      WriteLn(f, 'Testland B:               14:  27:  EU:   51.00:   -11.00:     0.0:  T2B:');
      WriteLn(f, '    T2B;');
      WriteLn(f, 'REMAINING MULTS');
      WriteLn(f, 'T2B');
   finally
      CloseFile(f);
   end;

   try
      CheckTrue(ctyLoadInCountryFile(path, False, True, {ReplaceTable} True),
                'the probe country file loaded');

      idxA := -1;
      idxB := -1;
      for i := 0 to ctyGetTotalCountries - 1 do
         begin
         if Trim(ctyGetCountryIdByIndex(i)) = 'T1A' then
            begin
            idxA := i;
            end;
         if Trim(ctyGetCountryIdByIndex(i)) = 'T2B' then
            begin
            idxB := i;
            end;
         end;

      Check(idxA >= 0, 'entity T1A is in the table');
      Check(idxB >= 0, 'entity T2B is in the table');
      if (idxA < 0) or (idxB < 0) then
         begin
         Exit;
         end;

      CheckTrue(CTY.ctyCustomRemainingCountryListFound,
                'the REMAINING MULTS section was found -- the assertion the '
                + 'stale "effectively disabled" note was about');
      CheckEquals(2, Integer(CTY.ctyTable[idxB].VisibleInRM),
                  'T2B is named in the section, so it is marked');
      Check(CTY.ctyTable[idxA].VisibleInRM <> 2,
            'T1A is not named, so it is not marked');
   finally
      (* PUT THE REAL TABLE BACK. Everything else in this suite reads it. *)
      FLoaded := False;
      EnsureCtyLoaded;
      if FileExists(path) then
         begin
         DeleteFile(path);
         end;
   end;

   (* And prove the restore worked rather than assuming it. *)
   CheckEquals('K', Trim(ctyGetCountryID('W1AW')),
               'the shipped cty.dat is back in place');
end;


(* ===========================================================================
  A `!` LINE MERGES ONE ENTITY INTO ANOTHER, AND NOTHING HAS EVER TESTED IT.

  cty.dat's country-name field may begin with '!', which asks the loader to
  retire the entity named in the SECOND field and give its prefixes to the one
  named in the first (marker excluded):

      !TL1:TL2:  15:  28:  EU:  ...

  means "prefixes filed under TL2 now belong to TL1, and TL2 stops appearing
  in the remaining-multiplier windows".

  THE SHIPPED cty.dat HAS NO `!` LINES, so this served an operator's own file
  and no oracle in this tree could see it. That is how a comment claiming the
  routine skipped the first letter of a name survived: nothing disagreed.

  It also could not have been written without reading the '!' marker, which is
  the thing the stale comment got wrong -- so the test and the correction are
  the same piece of work. *)
procedure TCTYDATTests.Test_BangLineMergesEntities;
var
   path : string;
   f    : TextFile;
   i    : integer;
   idx1 : integer;
   idx2 : integer;
begin
   BeginTest('a ! line gives one entity''s prefixes to another');

   path := ExtractFilePath(ParamStr(0)) + 'cty_bang_merge_probe.dat';
   AssignFile(f, path);
   Rewrite(f);
   try
      WriteLn(f, 'Testland One:             14:  27:  EU:   50.00:   -10.00:     0.0:  TL1:');
      WriteLn(f, '    TL1;');
      WriteLn(f, 'Testland Two:             14:  27:  EU:   51.00:   -11.00:     0.0:  TL2:');
      WriteLn(f, '    TL2;');
      (* RETIRE TL2 INTO TL1 -- and the COLUMN WHITESPACE IS LOAD-BEARING.
        The parser advances its field start on a space or a tab, never on
        the ':' itself, so a line written without the gaps has its name
        field run on through the next two colons. Two spaces, as the real
        file has. *)
      WriteLn(f, '!TL1:  TL2:');
   finally
      CloseFile(f);
   end;

   try
      CheckTrue(ctyLoadInCountryFile(path, False, False, {ReplaceTable} True),
                'the probe country file loaded');

      idx1 := -1;
      idx2 := -1;
      for i := 0 to ctyGetTotalCountries - 1 do
         begin
         if Trim(ctyGetCountryIdByIndex(i)) = 'TL1' then
            begin
            idx1 := i;
            end;
         if Trim(ctyGetCountryIdByIndex(i)) = 'TL2' then
            begin
            idx2 := i;
            end;
         end;

      Check(idx1 >= 0, 'TL1 is in the table');
      Check(idx2 >= 0, 'TL2 is still in the table -- it is HIDDEN, not deleted');
      if (idx1 < 0) or (idx2 < 0) then
         begin
         Exit;
         end;

      (* A callsign that was TL2's now answers TL1. *)
      CheckEquals('TL1', Trim(ctyGetCountryID('TL2ABC')),
                  'TL2''s prefix was re-pointed at TL1');

      (* And the retired entity is taken out of the remaining-mult windows. *)
      CheckFalse(ctyIsActiveMultiplier(idx2),
                 'the retired entity is no longer an active multiplier');
      CheckTrue(ctyIsActiveMultiplier(idx1),
                'the surviving entity still is');
   finally
      FLoaded := False;
      EnsureCtyLoaded;
      if FileExists(path) then
         begin
         DeleteFile(path);
         end;
   end;

   CheckEquals('K', Trim(ctyGetCountryID('W1AW')),
               'the shipped cty.dat is back in place');
end;


(* ===========================================================================
  A RELOAD REPLACES THE TABLE. IT USED TO APPEND, AND THAT WAS A MEMORY WRITE
  PAST THE END OF AN ARRAY.

  ctyLoadInCountryFile never reset the country table -- the FillChar that
  would have was commented out, and the count was not reset either. The table
  is array[0..MaxCountries - 1], MaxCountries is 1000, and the shipped cty.dat
  carries around 693 entities:

      startup             693 of 1000
      a CTY.DAT download  1386, and the write runs off the end at 1000

  That second load is real: uMainWindowProc calls this routine after a CTY.DAT
  download. Range checking is off in that unit, so it corrupted the rest of
  the CTY record in silence.

  IT WAS FOUND BY TESTS, NOT BY READING. Two probe fixtures that each reload
  the shipped file afterwards pushed the count past 1000 and the suite died
  with an EAccessViolation after the last assertion of the last test -- which
  is what an overrun looks like when nothing checks the bound.

  The append itself is NOT the bug: the r150s and rfobl overlays call this
  same routine to add their entities on top of the main file, and must keep
  appending. So the reset is a parameter the caller states. *)
procedure TCTYDATTests.Test_ReloadReplacesRatherThanAppends;
var
   first  : integer;
   second : integer;
   path   : string;
begin
   BeginTest('loading the country file twice does not grow the table');
   EnsureCtyLoaded;

   first := ctyGetTotalCountries;
   Check(first > 300, 'the shipped file carries a realistic number of entities');

   path := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
           PathDelim + 'target' + PathDelim + 'cty.dat';
   CheckTrue(ctyLoadInCountryFile(path, False, False, {ReplaceTable} True),
             'the same file loads a second time');

   second := ctyGetTotalCountries;
   CheckEquals(first, second,
               'the count is the SAME after a reload -- it used to double');

   (* And the table still answers. A stale half-table would still have the
     right count, so this asks it something. *)
   CheckEquals('K', Trim(ctyGetCountryID('W1AW')), 'W1AW after the reload');
   CheckEquals('G', Trim(ctyGetCountryID('G3ABC')), 'G3ABC after the reload');

   (* WITHOUT ReplaceTable it APPENDS, which is what the overlays need. Proven
     rather than asserted, because the parameter defaulting the wrong way
     would silently break r150s and rfobl. *)
   CheckTrue(ctyLoadInCountryFile(path, True, False), 'an appending load');
   Check(ctyGetTotalCountries > second,
         'an appending load DID add entities -- the overlays depend on it');

   FLoaded := False;
   EnsureCtyLoaded;
   CheckEquals(first, ctyGetTotalCountries, 'and the suite is left as it was');
end;

procedure TCTYDATTests.Test_Characterisation;
var
   f: TextFile;
   path, line, want, got: string;
   call: string;
   bar: integer;
   qth: QTHRecord;
   id: DXMultiplierString;
   n, shown: integer;

   function ContName(k: ContinentType): string;
   begin
      case k of
         NorthAmerica: Result := 'NA';
         SouthAmerica: Result := 'SA';
         Europe:       Result := 'EU';
         Africa:       Result := 'AF';
         Asia:         Result := 'AS';
         Oceania:      Result := 'OC';
      else
         Result := '??';
      end;
   end;

begin
   BeginTest('every public lookup still answers what it answered before');
   EnsureCtyLoaded;

   path := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim +
           'ctydat_characterisation.txt';
   CheckTrue(FileExists(path), 'the characterisation fixture is present');
   if not FileExists(path) then Exit;

   AssignFile(f, path);
   Reset(f);
   n := 0;
   shown := 0;
   try
      while not Eof(f) do
         begin
         ReadLn(f, line);
         if (line = '') or (line[1] = '#') then Continue;

         bar := Pos('|', line);
         if bar <= 1 then Continue;
         call := Copy(line, 1, bar - 1);

         FillChar(qth, SizeOf(qth), 0);
         ctyLocateCall(CallString(call), qth);
         id := '';

         (* ONE ASSERTION PER CALLSIGN, comparing the whole record.  Eight
           separate checks per call would be 13472 assertions and would say no
           more: the message below shows both records, so the differing field
           is visible without the count. *)
         got := Format('%s|%d|%s|%d|%d|%s|%s|%s|%s',
            [call,
             ctyGetCountry(call),
             ctyGetCountryID(call),
             ctyGetCQZone(call),
             ctyGetITUZone(call),
             ContName(ctyGetContinent(call)),
             string(qth.Prefix),
             string(qth.StandardCall),
             ctyGetGrid(call, id)]);
         want := line;

         Inc(n);
         if got <> want then
            begin
            Inc(shown);
            // Cap the noise: after ten, the pattern is established and the
            // rest of the log is unreadable.
            if shown <= 10 then
               begin
               CheckEquals(want, got, 'characterisation moved for ' + call);
               end;
            end
         else
            begin
            CheckEquals(want, got, call);
            end;
         end;
   finally
      CloseFile(f);
   end;

   Check(n > 1500, Format('the fixture carried %d records (expected 1500+)', [n]));
   if shown > 10 then
      begin
      Check(False, Format('%d records differ in total; first 10 shown', [shown]));
      end;
end;

procedure TCTYDATTests.RunAllTests;
begin
   Test_LoadCtyDat;
   Test_UnitedStates_W1AW;
   Test_England_G3;
   Test_Japan_JA1;
   Test_Germany_DL1;
   Test_Argentina_LU1;
   Test_Australia_VK2;
   Test_SouthAfrica_ZS6;
   Test_Zones_W1_England_Japan;
   Test_UnknownCountryIndex;

   Test_Rule_USCallAreasShareOneCountry;
   Test_Rule_CanadianDistrictsChangeZone;
   Test_Rule_RussianDistrictsChangeCountry;
   Test_Rule_KG4TwoCharacterSuffixIsGuantanamo;
   Test_Rule_PortableSuffixRetargets;
   Test_Rule_PortablePrefixWins;
   Test_Rule_MaritimeMobileHasNoEntity;
   Test_Rule_LookupIsCaseSensitive;
   Test_Rule_GarbageAndBoundariesAreUnknown;
   Test_Rule_USTerritoriesAreSeparateEntities;
   Test_Rule_DuplicatePrefixPicksTheSpecificEntity;
   Test_Rule_ExactCallBeatsPrefixOverride;

   // Last: it is the slowest and the least specific.
   Test_Characterisation;

   (* AFTER the characterisation, because it loads a DIFFERENT country
     file over the top of the shipped one and then reloads. Anything that
     ran between the two would be reading a two-entity table. *)
   Test_RemainingMultsSection;
   Test_BangLineMergesEntities;
   Test_ReloadReplacesRatherThanAppends;
end;

end.
