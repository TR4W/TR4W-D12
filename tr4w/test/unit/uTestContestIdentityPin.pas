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

(* EVERY CONTEST'S IDENTITY VALUES, FROZEN AS LITERALS -- M10 S8, 2026-10-14.

  WHY IT EXISTS. Until S8, Test_MovedRowValuesStillMatchTheArray compared
  every class with its row in VC.pas's ContestsArray. S8 deleted the table and
  that test with it, which left these values compared with NOTHING: the
  WA7BNM and QRZ.RU calendar ids, the submission e-mail, the friendly name,
  the display name and the domestic file name. A mistyped or drifted value is
  a legal value of the right type (CLAUDE.md note 9), and no gate reads most
  of them -- the score-posting clients, the calendar menus and the summary
  sheet do.

  HOW IT WAS MADE -- ONCE. The table below was GENERATED at M10 S8 by a
  scratch program linking every registered class, which printed each
  ContestIdentity(c)'s values for every ContestType. Those classes were
  PROVEN equal to the deleted table at that moment: the S0 pin held through
  S7, and the generated values were compared again with ContestsArray at
  9dc93f67 (WA7BNM, QRZRUID, Email, DF, FriendlyName -- 0 differences in
  187 contests).

  IT IS NEVER REGENERATED TO CLEAR A FAILURE. A failure means a class changed
  one of its identity values. If that was deliberate (a sponsor renamed an
  event, a calendar id changed), change the ONE row here in the same commit,
  by hand, and say why. If it was not, the class is wrong. Regenerating the
  table would turn the pin into a copy of whatever the classes say today,
  which is the tautology the S0 pin existed to avoid.

  WHAT IS NOT HERE, because something else already pins it:
    * the ADIF id and the Cabrillo name -- the contest matrix's frozen records
      hold every matrix contest's CONTEST_ID (export.adif) and Cabrillo
      CONTEST: line (export.cabrillo, CabrilloContestName, which is
      CabrilloName for every class but General QSO). The three contests the
      matrix cannot see that way are pinned below by name: DUMMYCONTEST (not
      in the matrix), GENERALQSO (writes no CONTEST_ID, and its Cabrillo line
      is CabrilloContestName's own) and POTA (writes no CONTEST_ID);
    * that every ADIF id resolves to its contest --
      Test_EveryContestResolvesItsOwnADIFId;
    * that every class STATES its names rather than inheriting them --
      uTestContestDisplay.Test_EveryClassStatesItsIdentity.

  THE ARRAY IS INDEXED BY ContestType, so the compiler refuses a table with a
  row missing or extra, and each row carries its ContestTypeSA spelling
  (Token), so a row out of order fails by name rather than silently shifting
  every value after it.

  A FROZEN VALUE CHECK OVER THE LEGACY CONTESTS (Q108 S1, 2026-10-16,
  design 8.2u). It covers every ContestType and never grows: a contest that
  registers by its string id (Q108 S3) has no member, so no row here, and is
  held instead by the registry walks -- Test_EveryClassStatesItsIdentity
  above all. The two counts of 188 that stood at the foot of the test are
  deleted: the array's index already demands a row per member, so a count
  of them guarded nothing the compiler does not. Freezing the member list
  itself is Q108 S3's Lint-FrozenContestNumbers, not a test. *)
unit uTestContestIdentityPin;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestIdentityPinTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestStatesItsIdentityLiterally;
      procedure Test_MatrixBlindContestsStateTheirIds;
      procedure Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestNames,
   uContestRegistry,
   uTestRegisteredContests;

type
   (* A literal row of test data -- the one shape Pascal gives a typed
      constant table. *)
   TIdentityPin = record
      Token: string;
      WA7BNM: integer;
      QRZRUID: integer;
      Email: string;
      Friendly: string;
      Display: string;
      DomesticFile: string;
   end;

const
   (* GENERATED ONCE AT M10 S8 -- see the unit header. Never regenerate it to
      clear a failure. *)
   IDENTITY_PINS: array[ContestType] of TIdentityPin = (
      (* DUMMYCONTEST *)
      (Token: 'DUMMY CONTEST'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'DUMMY CONTEST';
       Display: 'DUMMY CONTEST'; DomesticFile: ''),
      (* SEVENQP *)
      (Token: '7QP'; WA7BNM: 404; QRZRUID: 0; Email: '';
       Friendly: '7th Call Area QSO Party';
       Display: '7th Call Area QSO Party'; DomesticFile: 'seven_cty'),
      (* ALLASIANCW *)
      (Token: 'ALL-ASIAN-DX-CW'; WA7BNM: 47; QRZRUID: 146; Email: '';
       Friendly: 'All Asian DX Contest, CW';
       Display: 'All Asian DX Contest, CW'; DomesticFile: ''),
      (* ALLASIANSSB *)
      (Token: 'ALL-ASIAN-DX-SSB'; WA7BNM: 102; QRZRUID: 146; Email: '';
       (* 'SSB', not 'Phone': JARL's own name (NY4I, 2026-10-15) *)
       Friendly: 'All Asian DX Contest, SSB';
       Display: 'All Asian DX Contest, SSB'; DomesticFile: ''),
      (* ALLJA *)
      (Token: 'ALL JA'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'All JA Contest';
       Display: 'All JA Contest'; DomesticFile: 'allja'),
      (* APSPRINT *)
      (Token: 'AP-SPRINT'; WA7BNM: 0; QRZRUID: 77; Email: '';
       Friendly: 'AP-SPRINT';
       Display: 'AP-SPRINT'; DomesticFile: ''),
      (* ARCI *)
      (Token: 'ARCI'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'ARCI';
       Display: 'ARCI'; DomesticFile: 's50p12'),
      (* ARI_DX *)
      (Token: 'ARI-DX'; WA7BNM: 9; QRZRUID: 85; Email: '';
       Friendly: 'ARI International DX Contest';
       Display: 'ARI International DX Contest'; DomesticFile: 'ari'),
      (* ARRL10 *)
      (Token: 'ARRL-10'; WA7BNM: 199; QRZRUID: 14; Email: '10meter@arrl.org';
       Friendly: 'ARRL 10-Meter Contest';
       Display: 'ARRL 10-Meter Contest'; DomesticFile: 'arrl10'),
      (* ARRLDIGI *)
      (Token: 'ARRL-DIGI'; WA7BNM: 716; QRZRUID: 0; Email: 'contests@arrl.org';
       Friendly: 'ARRL Inter. Digital Contest';
       Display: 'ARRL Inter. Digital Contest'; DomesticFile: ''),
      (* ARRL160 *)
      (Token: 'ARRL-160'; WA7BNM: 194; QRZRUID: 22; Email: '160meter@arrl.org';
       Friendly: 'ARRL 160-Meter Contest';
       Display: 'ARRL 160-Meter Contest'; DomesticFile: 'arrlsect'),
      (* ARRLDXCW *)
      (Token: 'ARRL-DX-CW'; WA7BNM: 256; QRZRUID: 335; Email: 'DXCW@arrl.org';
       Friendly: 'ARRL Inter. DX Contest, CW';
       Display: 'ARRL Inter. DX Contest, CW'; DomesticFile: ''),
      (* ARRLDXSSB *)
      (Token: 'ARRL-DX-SSB'; WA7BNM: 289; QRZRUID: 334; Email: 'DXPhone@arrl.org';
       Friendly: 'ARRL Inter. DX Contest, SSB';
       Display: 'ARRL Inter. DX Contest, SSB'; DomesticFile: ''),
      (* ARRLSSCW *)
      (Token: 'ARRL-SS-CW'; WA7BNM: 177; QRZRUID: 0; Email: 'SSCW@arrl.org';
       Friendly: 'ARRL Sweepstakes Contest, CW';
       Display: 'ARRL Sweepstakes Contest, CW'; DomesticFile: 'arrlsect'),
      (* ARRLSSSSB *)
      (Token: 'ARRL-SS-SSB'; WA7BNM: 178; QRZRUID: 0; Email: 'SSPhone@arrl.org';
       Friendly: 'ARRL Sweepstakes Contest, SSB';
       Display: 'ARRL Sweepstakes Contest, SSB'; DomesticFile: 'arrlsect'),
      (* ARRLVHFJAN *)
      (Token: 'ARRL-VHF-JAN'; WA7BNM: 231; QRZRUID: 0; Email: '';
       Friendly: 'ARRL January VHF Contest';
       Display: 'ARRL January VHF Contest'; DomesticFile: ''),
      (* ARRLVHFJUN *)
      (Token: 'ARRL-VHF-JUN'; WA7BNM: 43; QRZRUID: 0; Email: '';
       Friendly: 'ARRL June VHF Contest';
       Display: 'ARRL June VHF Contest'; DomesticFile: ''),
      (* ARRLVHFSEP *)
      (Token: 'ARRL-VHF-SEP'; WA7BNM: 113; QRZRUID: 0; Email: '';
       Friendly: 'ARRL September VHF Contest';
       Display: 'ARRL September VHF Contest'; DomesticFile: ''),
      (* ArizonaQsoParty *)
      (Token: 'ARIZONA QSO PARTY'; WA7BNM: 482; QRZRUID: 0; Email: 'info@azqp.org';
       Friendly: 'Arizona QSO Party';
       Display: 'Arizona QSO Party'; DomesticFile: 'arizona_cty'),
      (* BALTIC *)
      (Token: 'BALTIC'; WA7BNM: 28; QRZRUID: 161; Email: '';
       Friendly: 'Baltic Contest';
       Display: 'Baltic Contest'; DomesticFile: ''),
      (* BWQP *)
      (Token: 'BWQP'; WA7BNM: 479; QRZRUID: 0; Email: '';
       Friendly: 'Bill Windle QSO Party';
       Display: 'Bill Windle QSO Party'; DomesticFile: ''),
      (* CIS *)
      (Token: 'CIS'; WA7BNM: 197; QRZRUID: 500; Email: '';
       Friendly: 'CIS DX Contest, CW';
       Display: 'CIS DX Contest, CW'; DomesticFile: 'cis'),
      (* CALQSOPARTY *)
      (Token: 'CALIFORNIA QSO PARTY'; WA7BNM: 140; QRZRUID: 0; Email: '';
       Friendly: 'California QSO Party';
       Display: 'California QSO Party'; DomesticFile: 'california_cty'),
      (* COUNTYHUNTER *)
      (Token: 'COUNTY HUNTER'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'General County Hunting Log';
       Display: 'General County Hunting Log'; DomesticFile: ''),
      (* CQ160CW *)
      (Token: 'CQ-160-CW'; WA7BNM: 232; QRZRUID: 311; Email: '160CW@kkn.net';
       Friendly: 'CQ 160-Meter Contest, CW';
       Display: 'CQ 160-Meter Contest, CW'; DomesticFile: 's48p14dc'),
      (* CQ160SSB *)
      (Token: 'CQ-160-SSB'; WA7BNM: 259; QRZRUID: 312; Email: '160SSB@kkn.net';
       Friendly: 'CQ 160-Meter Contest, SSB';
       Display: 'CQ 160-Meter Contest, SSB'; DomesticFile: 's48p14dc'),
      (* CQM *)
      (Token: 'CQ-M'; WA7BNM: 14; QRZRUID: 126; Email: '';
       Friendly: 'CQ-M International DX Contest';
       Display: 'CQ-M International DX Contest'; DomesticFile: ''),
      (* CQVHF *)
      (Token: 'CQ-VHF'; WA7BNM: 73; QRZRUID: 363; Email: '';
       Friendly: 'CQ Worldwide VHF SSB/CW Contest';
       Display: 'CQ Worldwide VHF SSB/CW Contest'; DomesticFile: ''),
      (* CQWPXCW *)
      (Token: 'CQ-WPX-CW'; WA7BNM: 29; QRZRUID: 18; Email: 'cw@cqwpx.com';
       Friendly: 'CQ WW WPX Contest, CW';
       Display: 'CQ WW WPX Contest, CW'; DomesticFile: ''),
      (* CQWPXSSB *)
      (Token: 'CQ-WPX-SSB'; WA7BNM: 291; QRZRUID: 6; Email: 'ssb@cqwpx.com';
       Friendly: 'CQ WW WPX Contest, SSB';
       Display: 'CQ WW WPX Contest, SSB'; DomesticFile: ''),
      (* CQWPXRTTY *)
      (Token: 'CQ-WPX-RTTY'; WA7BNM: 245; QRZRUID: 6; Email: 'rtty@cqwpx.com';
       Friendly: 'CQ WW RTTY WPX Contest';
       Display: 'CQ WW RTTY WPX Contest'; DomesticFile: ''),
      (* CQWWCW *)
      (Token: 'CQ-WW-CW'; WA7BNM: 192; QRZRUID: 5; Email: 'cw@cqww.com';
       Friendly: 'CQ Worldwide DX Contest, CW';
       Display: 'CQ Worldwide DX Contest, CW'; DomesticFile: ''),
      (* CQWWSSB *)
      (Token: 'CQ-WW-SSB'; WA7BNM: 172; QRZRUID: 4; Email: 'ssb@cqww.com';
       Friendly: 'CQ Worldwide DX Contest, SSB';
       Display: 'CQ Worldwide DX Contest, SSB'; DomesticFile: ''),
      (* CROATIAN *)
      (Token: 'CROATIAN'; WA7BNM: 206; QRZRUID: 91; Email: '';
       Friendly: 'Croatian DX Contest';
       Display: 'Croatian DX Contest'; DomesticFile: 'croat'),
      (* CUPRFCW *)
      (Token: 'RF-CUP-CW'; WA7BNM: 0; QRZRUID: 27; Email: '';
       Friendly: 'Russian Cup Contest, CW';
       Display: 'Russian Cup Contest, CW'; DomesticFile: ''),
      (* CUPRFSSB *)
      (Token: 'RF-CUP-SSB'; WA7BNM: 0; QRZRUID: 24; Email: '';
       Friendly: 'Russian Cup Contest, SSB';
       Display: 'Russian Cup Contest, SSB'; DomesticFile: ''),
      (* CUPRFDIG *)
      (Token: 'RF-CUP-DIG'; WA7BNM: 595; QRZRUID: 86; Email: '';
       Friendly: 'Russian Cup Digital Contest';
       Display: 'Russian Cup Digital Contest'; DomesticFile: 'grids'),
      (* CUPURAL *)
      (Token: 'URAL-CUP'; WA7BNM: 0; QRZRUID: 112; Email: '';
       Friendly: 'Ural Cup';
       Display: 'Ural Cup'; DomesticFile: 'grids'),
      (* EUSPRINT_SPRING_CW *)
      (Token: 'EU-SPRINT-SPRING-CW'; WA7BNM: 317; QRZRUID: 216; Email: '';
       Friendly: 'RSGB International Sprint Contest, CW';
       Display: 'RSGB International Sprint Contest, CW'; DomesticFile: ''),
      (* EUROPEANHFC *)
      (Token: 'EUROPEAN HFC'; WA7BNM: 82; QRZRUID: 31; Email: '';
       Friendly: 'European HF Championship';
       Display: 'European HF Championship'; DomesticFile: ''),
      (* EUROPEANVHF *)
      (Token: 'EUROPEAN VHF'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'European VHF';
       Display: 'European VHF'; DomesticFile: ''),
      (* TESLA *)
      (Token: 'HF-TESLA'; WA7BNM: 566; QRZRUID: 0; Email: '';
       Friendly: 'TESLA Memorial HF CW Contest';
       Display: 'TESLA Memorial HF CW Contest'; DomesticFile: ''),
      (* ARRLFIELDDAY *)
      (Token: 'ARRL-FD'; WA7BNM: 57; QRZRUID: 0; Email: 'fieldday@arrl.org';
       Friendly: 'ARRL Field Day';
       Display: 'ARRL Field Day'; DomesticFile: 'arrlsect'),
      (* FISTS *)
      (Token: 'FISTS'; WA7BNM: 251; QRZRUID: 0; Email: '';
       Friendly: 'FISTS Winter Unlimited Sprint';
       Display: 'FISTS Winter Unlimited Sprint'; DomesticFile: 's49p8'),
      (* FOCMARATHON *)
      (Token: 'FOC MARATHON'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'FOC Marathon';
       Display: 'FOC Marathon'; DomesticFile: ''),
      (* FLORIDAQSOPARTY *)
      (Token: 'FLORIDA QSO PARTY'; WA7BNM: 325; QRZRUID: 0; Email: '';
       Friendly: 'Florida QSO Party';
       Display: 'Florida QSO Party'; DomesticFile: 'florida_cty'),
      (* GACWWWSACW *)
      (Token: 'GACW-WWSA-CW'; WA7BNM: 45; QRZRUID: 321; Email: '';
       Friendly: 'GACW WWSA CW DX Contest';
       Display: 'GACW WWSA CW DX Contest'; DomesticFile: ''),
      (* GAGARINCUP *)
      (Token: 'GAGARIN-CUP'; WA7BNM: 367; QRZRUID: 82; Email: '';
       Friendly: 'Yuri Gagarin International DX Contest';
       Display: 'Yuri Gagarin International DX Contest'; DomesticFile: 'GC'),
      (* GENERALQSO *)
      (Token: 'GENERAL QSO'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'General QSO/DX Logging';
       Display: 'General QSO/DX Logging'; DomesticFile: ''),
      (* GRIDLOC *)
      (Token: 'GRID LOC'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'GRID LOC';
       Display: 'GRID LOC'; DomesticFile: ''),
      (* HADX *)
      (Token: 'HA DX'; WA7BNM: 228; QRZRUID: 116; Email: '';
       Friendly: 'Hungarian DX Contest';
       Display: 'Hungarian DX Contest'; DomesticFile: 'hungary'),
      (* YUDX *)
      (Token: 'YUDX'; WA7BNM: 322; QRZRUID: 0; Email: '';
       Friendly: 'YU DX Contest';
       Display: 'YU DX Contest'; DomesticFile: 'yu'),
      (* UKEI *)
      (Token: 'UKEI'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'UKEI';
       Display: 'UKEI'; DomesticFile: 'uk-ei'),
      (* HELVETIA *)
      (Token: 'HELVETIA'; WA7BNM: 326; QRZRUID: 157; Email: '';
       Friendly: 'Helvetia Contest';
       Display: 'Helvetia Contest'; DomesticFile: 'swiss'),
      (* IARU *)
      (Token: 'IARU-HF'; WA7BNM: 67; QRZRUID: 33; Email: 'iaruhf@iaru.org';
       Friendly: 'IARU HF World Championship';
       Display: 'IARU HF World Championship'; DomesticFile: 'iaruhq'),
      (* INTERNETSPRINT *)
      (Token: 'INTERNET SPRINT'; WA7BNM: 18; QRZRUID: 0; Email: '';
       Friendly: 'Internet CW Sprint Contest';
       Display: 'Internet CW Sprint Contest'; DomesticFile: 's49p13'),
      (* IOTA *)
      (Token: 'RSGB-IOTA'; WA7BNM: 75; QRZRUID: 29; Email: '';
       Friendly: 'RSGB IOTA Contest';
       Display: 'RSGB IOTA Contest'; DomesticFile: ''),
      (* JIDXCW *)
      (Token: 'JIDX-CW'; WA7BNM: 314; QRZRUID: 57; Email: '';
       Friendly: 'JIDX CW Contest';
       Display: 'JIDX CW Contest'; DomesticFile: 'jidx'),
      (* JIDXSSB *)
      (Token: 'JIDX-SSB'; WA7BNM: 184; QRZRUID: 57; Email: '';
       Friendly: 'JIDX Phone Contest';
       Display: 'JIDX Phone Contest'; DomesticFile: 'jidx'),
      (* JALONGPREFECT *)
      (Token: 'JA LONG PREFECT'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'JA LONG PREFECT';
       Display: 'JA LONG PREFECT'; DomesticFile: 'jacg3'),
      (* JTDX *)
      (Token: 'MONGOLIAN DX'; WA7BNM: 491; QRZRUID: 0; Email: '';
       Friendly: 'Mongolian DX Contest, CW/SSB';
       Display: 'Mongolian DX Contest, CW/SSB'; DomesticFile: ''),
      (* KCJ *)
      (Token: 'KCJ'; WA7BNM: 89; QRZRUID: 169; Email: '';
       Friendly: 'Keymans Club of Japan Contest';
       Display: 'Keymans Club of Japan Contest'; DomesticFile: 'japref'),
      (* KIDSDAY *)
      (Token: 'KIDS DAY'; WA7BNM: 224; QRZRUID: 0; Email: '';
       Friendly: 'ARRL Kids Day';
       Display: 'ARRL Kids Day'; DomesticFile: ''),
      (* KVP *)
      (Token: 'KVP'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'KV PRVENSTVO ZRS';
       Display: 'KV PRVENSTVO ZRS'; DomesticFile: ''),
      (* LABRE *)
      (Token: 'LABRE'; WA7BNM: 761; QRZRUID: 0; Email: 'logs@labre.org.br';
       Friendly: 'LABRE DX Contest';
       Display: 'LABRE DX Contest'; DomesticFile: 'brazil'),
      (* LZDX *)
      (Token: 'LZ DX'; WA7BNM: 187; QRZRUID: 53; Email: '';
       Friendly: 'LZ DX Contest';
       Display: 'LZ DX Contest'; DomesticFile: 'lz'),
      (* MARCONIMEMORIAL *)
      (Token: 'MARCONI MEMORIAL'; WA7BNM: 56; QRZRUID: 0; Email: 'contest.marconi@arifano.it';
       Friendly: 'Marconi Memorial HF Contest';
       Display: 'Marconi Memorial HF Contest'; DomesticFile: ''),
      (* MINITEST *)
      (Token: 'MINITEST'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'MINITEST';
       Display: 'MINITEST'; DomesticFile: ''),
      (* MINI80 *)
      (Token: 'MINI80'; WA7BNM: 712; QRZRUID: 0; Email: '';
       Friendly: 'Mini-Test 80';
       Display: 'Mini-Test 80'; DomesticFile: ''),
      (* MINI40 *)
      (Token: 'MINI40'; WA7BNM: 711; QRZRUID: 0; Email: '';
       Friendly: 'Mini-Test 40';
       Display: 'Mini-Test 40'; DomesticFile: ''),
      (* MICHQSOPARTY *)
      (Token: 'MICHIGAN QSO PARTY'; WA7BNM: 323; QRZRUID: 0; Email: '';
       Friendly: 'Michigan QSO Party';
       Display: 'Michigan QSO Party'; DomesticFile: 'michigan_cty'),
      (* MINNQSOPARTY *)
      (Token: 'MINNESOTA QSO PARTY'; WA7BNM: 238; QRZRUID: 0; Email: '';
       Friendly: 'Minnesota QSO Party';
       Display: 'Minnesota QSO Party'; DomesticFile: 'minnesota_cty'),
      (* MOQSOPARTY *)
      (Token: 'MISSOURI QSO PARTY'; WA7BNM: 327; QRZRUID: 0; Email: 'moqsoparty@w0ma.org';
       Friendly: 'Missouri QSO Party';
       Display: 'Missouri QSO Party'; DomesticFile: 'missouri_cty'),
      (* NAQSOCW *)
      (Token: 'NAQP-CW'; WA7BNM: 218; QRZRUID: 0; Email: 'cwnaqpmgr@ncjweb.com';
       Friendly: 'North American QSO Party, CW';
       Display: 'North American QSO Party, CW'; DomesticFile: 'naqp'),
      (* NAQSOSSB *)
      (Token: 'NAQP-SSB'; WA7BNM: 229; QRZRUID: 0; Email: 'ssbnaqpmgr@ncjweb.com';
       Friendly: 'North American QSO Party, SSB';
       Display: 'North American QSO Party, SSB'; DomesticFile: 'naqp'),
      (* NAQSORTTY *)
      (Token: 'NAQP-RTTY'; WA7BNM: 263; QRZRUID: 0; Email: 'rttynaqpmgr@ncjweb.com';
       Friendly: 'North American QSO Party, RTTY';
       Display: 'North American QSO Party, RTTY'; DomesticFile: 'naqp'),
      (* NASPRINTCW *)
      (Token: 'NA-SPRINT-CW'; WA7BNM: 253; QRZRUID: 0; Email: 'cwsprint@ncjweb.com';
       Friendly: 'North American Sprint, CW';
       Display: 'North American Sprint, CW'; DomesticFile: 'naqp'),
      (* SPRINTSSB -- the sponsor's name since Q16 (NY4I, 2026-10-16,
         docs/CONTEST_FACTORY_OPEN_QUESTIONS.md); was "North American
         Sprint, SSB". Changed by hand, deliberately. *)
      (Token: 'SSB-SPRINT'; WA7BNM: 242; QRZRUID: 0; Email: '';
       Friendly: 'North American SSB Sprint';
       Display: 'North American SSB Sprint'; DomesticFile: 'naqp'),
      (* NASPRINTRTTY *)
      (Token: 'NA-SPRINT-RTTY'; WA7BNM: 155; QRZRUID: 0; Email: 'rttysprint@ncjweb.com';
       Friendly: 'North American Sprint, RTTY';
       Display: 'North American Sprint, RTTY'; DomesticFile: 's49p8'),
      (* NCCCSPRINT *)
      (Token: 'NCCC-SPRINT'; WA7BNM: 44; QRZRUID: 0; Email: '';
       Friendly: 'NCCC Sprint';
       Display: 'NCCC Sprint'; DomesticFile: 'naqp'),
      (* NEWENGLANDQSO *)
      (Token: 'NEWEQP'; WA7BNM: 10; QRZRUID: 0; Email: '';
       Friendly: 'New England QSO Party';
       Display: 'New England QSO Party'; DomesticFile: ''),
      (* NCQSOPARTY *)
      (Token: 'NC QSO PARTY'; WA7BNM: 265; QRZRUID: 0; Email: '';
       Friendly: 'North Carolina QSO Party';
       Display: 'North Carolina QSO Party'; DomesticFile: 'nc_cty'),
      (* NRAUBALTICCW *)
      (Token: 'NRAU-BALTIC-CW'; WA7BNM: 220; QRZRUID: 0; Email: '';
       Friendly: 'NRAU-Baltic Contest, CW';
       Display: 'NRAU-Baltic Contest, CW'; DomesticFile: 'nrau'),
      (* NRAUBALTICSSB *)
      (Token: 'NRAU-BALTIC-SSB'; WA7BNM: 222; QRZRUID: 0; Email: '';
       Friendly: 'NRAU-Baltic Contest, SSB';
       Display: 'NRAU-Baltic Contest, SSB'; DomesticFile: 'nrau'),
      (* NZFIELDDAY *)
      (Token: 'NZ FIELD DAY'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'Jock White Memorial Field Day';
       Display: 'Jock White Memorial Field Day'; DomesticFile: ''),
      (* OCEANIADXCW *)
      (Token: 'OCEANIA-DX-CW'; WA7BNM: 151; QRZRUID: 72; Email: '';
       Friendly: 'Oceania DX Contest, CW';
       Display: 'Oceania DX Contest, CW'; DomesticFile: ''),
      (* OCEANIADXSSB *)
      (Token: 'OCEANIA-DX-SSB'; WA7BNM: 142; QRZRUID: 73; Email: '';
       Friendly: 'Oceania DX Contest, Phone';
       Display: 'Oceania DX Contest, Phone'; DomesticFile: ''),
      (* OHIOQSOPARTY *)
      (Token: 'OHIO QSO PARTY'; WA7BNM: 100; QRZRUID: 0; Email: '';
       Friendly: 'Ohio QSO Party';
       Display: 'Ohio QSO Party'; DomesticFile: 'ohio_cty'),
      (* OKDX *)
      (Token: 'OK-OM DX CW'; WA7BNM: 185; QRZRUID: 12; Email: '';
       Friendly: 'OK/OM DX Contest, CW';
       Display: 'OK/OM DX Contest, CW'; DomesticFile: 'okom'),
      (* OLDNEWYEAR *)
      (Token: 'RADIO-ONY'; WA7BNM: 554; QRZRUID: 12; Email: '';
       Friendly: 'Old New Year Contest';
       Display: 'Old New Year Contest'; DomesticFile: ''),
      (* OZCR_O *)
      (Token: 'OZCHR-TEAMS'; WA7BNM: 0; QRZRUID: 182; Email: '';
       Friendly: 'OZCHR-TEAMS';
       Display: 'OZCHR-TEAMS'; DomesticFile: ''),
      (* OZCR_Z *)
      (Token: 'OZCHR'; WA7BNM: 0; QRZRUID: 182; Email: '';
       Friendly: 'OZCHR';
       Display: 'OZCHR'; DomesticFile: ''),
      (* PACC *)
      (Token: 'PACC'; WA7BNM: 249; QRZRUID: 66; Email: '';
       Friendly: 'Dutch PACC Contest';
       Display: 'Dutch PACC Contest'; DomesticFile: 'pacc'),
      (* POTA *)
      (Token: 'POTA'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'Parks on the Air(r) Logging';
       Display: 'Parks on the Air(r) Logging'; DomesticFile: ''),
      (* QCWA *)
      (Token: 'QCWA'; WA7BNM: 332; QRZRUID: 0; Email: '';
       Friendly: 'QCWA QSO Party';
       Display: 'QCWA QSO Party'; DomesticFile: ''),
      (* QCWAGOLDEN *)
      (Token: 'QCWA GOLDEN'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'QCWA GOLDEN';
       Display: 'QCWA GOLDEN'; DomesticFile: ''),
      (* CANADA_WINTER *)
      (Token: 'CANADA WINTER'; WA7BNM: 205; QRZRUID: 101; Email: '';
       Friendly: 'RAC Winter Contest';
       Display: 'RAC Winter Contest'; DomesticFile: 'p13'),
      (* RADIOVHFFD *)
      (Token: 'RF-VHF-FD'; WA7BNM: 0; QRZRUID: 180; Email: '';
       Friendly: 'RF-VHF-FD';
       Display: 'RF-VHF-FD'; DomesticFile: ''),
      (* RAEM *)
      (Token: 'RAEM'; WA7BNM: 209; QRZRUID: 88; Email: '';
       Friendly: 'RAEM Contest';
       Display: 'RAEM Contest'; DomesticFile: ''),
      (* RDA *)
      (Token: 'RDAC'; WA7BNM: 94; QRZRUID: 386; Email: '';
       Friendly: 'Russian District Award Contest';
       Display: 'Russian District Award Contest'; DomesticFile: ''),
      (* REGION1FIELDDAY *)
      (Token: 'REGION 1 FIELD DAY'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'REGION 1 FIELD DAY';
       Display: 'REGION 1 FIELD DAY'; DomesticFile: ''),
      (* REGION1FIELDDAY_RCC_CW *)
      (Token: 'REGION 1 FIELD DAY-RCC-CW'; WA7BNM: 0; QRZRUID: 358; Email: '';
       Friendly: 'REGION 1 FIELD DAY-RCC-CW';
       Display: 'REGION 1 FIELD DAY-RCC-CW'; DomesticFile: ''),
      (* REGION1FIELDDAY_RCC_SSB *)
      (Token: 'REGION 1 FIELD DAY-RCC-SSB'; WA7BNM: 0; QRZRUID: 358; Email: '';
       Friendly: 'REGION 1 FIELD DAY-RCC-SSB';
       Display: 'REGION 1 FIELD DAY-RCC-SSB'; DomesticFile: ''),
      (* RFCHAMPIONSHIPCW *)
      (Token: 'RF-CHAMP-CW'; WA7BNM: 0; QRZRUID: 30; Email: 'champ@srr.ru';
       Friendly: 'RF-CHAMP-CW';
       Display: 'RF-CHAMP-CW'; DomesticFile: 'russian'),
      (* RFCHAMPIONSHIPSSB *)
      (Token: 'RF-CHAMP-SSB'; WA7BNM: 0; QRZRUID: 28; Email: 'champ@srr.ru';
       Friendly: 'RF-CHAMP-SSB';
       Display: 'RF-CHAMP-SSB'; DomesticFile: 'russian'),
      (* RFASCHAMPIONSHIPCW *)
      (Token: 'AS-CHAMP'; WA7BNM: 0; QRZRUID: 64; Email: '';
       Friendly: 'Asiatic Russia Championship';
       Display: 'Asiatic Russia Championship'; DomesticFile: ''),
      (* RSGB_ROPOCO_CW *)
      (Token: 'RSGB-ROPOCO-CW'; WA7BNM: 77; QRZRUID: 0; Email: '';
       Friendly: 'RSGB RoLo CW';
       Display: 'RSGB RoLo CW'; DomesticFile: ''),
      (* RSGB_ROPOCO_SSB *)
      (Token: 'RSGB-ROPOCO-SSB'; WA7BNM: 361; QRZRUID: 0; Email: '';
       Friendly: 'RSGB RoLo SSB';
       Display: 'RSGB RoLo SSB'; DomesticFile: ''),
      (* RSGB18 *)
      (Token: 'RSGB-160'; WA7BNM: 252; QRZRUID: 44; Email: '';
       Friendly: 'RSGB 1.8 MHz Contest';
       Display: 'RSGB 1.8 MHz Contest'; DomesticFile: 'rsgb'),
      (* RUSSIANDX -- no e-mail since Q135 (2026-10-22): rule 11.5 of the
         2027 rules takes logs only through ua9qcq.ru's web form. *)
      (Token: 'RDXC'; WA7BNM: 310; QRZRUID: 7; Email: '';
       Friendly: 'Russian DX Contest';
       Display: 'Russian DX Contest'; DomesticFile: 'russian'),
      (* SACCW *)
      (Token: 'SAC-CW'; WA7BNM: 121; QRZRUID: 175; Email: '';
       Friendly: 'Scandinavian Activity Contest, CW';
       Display: 'Scandinavian Activity Contest, CW'; DomesticFile: ''),
      (* YBDX *)
      (Token: 'YBDX'; WA7BNM: 772; QRZRUID: 175; Email: '';
       Friendly: 'YB ORARI DX Contest';
       Display: 'YB ORARI DX Contest'; DomesticFile: ''),
      (* SACSSB *)
      (Token: 'SAC-SSB'; WA7BNM: 131; QRZRUID: 175; Email: '';
       Friendly: 'Scandinavian Activity Contest, SSB';
       Display: 'Scandinavian Activity Contest, SSB'; DomesticFile: ''),
      (* SALMONRUN *)
      (Token: 'SALMON RUN'; WA7BNM: 126; QRZRUID: 0; Email: '';
       Friendly: 'Washington State Salmon Run';
       Display: 'Washington State Salmon Run'; DomesticFile: 'washington_cty'),
      (* SOUTHAMERICANWW *)
      (Token: 'SOUTH AMERICAN WW'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'SOUTH AMERICAN WW';
       Display: 'SOUTH AMERICAN WW'; DomesticFile: ''),
      (* SPDX *)
      (Token: 'SP DX'; WA7BNM: 312; QRZRUID: 127; Email: '';
       Friendly: 'SP DX Contest';
       Display: 'SP DX Contest'; DomesticFile: 'spdx'),
      (* STEWPERRY *)
      (Token: 'STEW-PERRY'; WA7BNM: 207; QRZRUID: 46; Email: '';
       Friendly: 'Stew Perry Topband Challenge';
       Display: 'Stew Perry Topband Challenge'; DomesticFile: ''),
      (* TENTEN *)
      (Token: 'TEN TEN'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'Ten-Ten On Air Activities';
       Display: 'Ten-Ten On Air Activities'; DomesticFile: ''),
      (* TEXASQSOPARTY *)
      (Token: 'TEXAS QSO PARTY'; WA7BNM: 133; QRZRUID: 0; Email: '';
       Friendly: 'Texas QSO Party';
       Display: 'Texas QSO Party'; DomesticFile: 'texas_cty'),
      (* TOEC *)
      (Token: 'TOEC'; WA7BNM: 97; QRZRUID: 163; Email: '';
       Friendly: 'TOEC WW Grid Contest, CW';
       Display: 'TOEC WW Grid Contest, CW'; DomesticFile: ''),
      (* UA4WCHAMPIONSHIP *)
      (Token: 'R4W-CHAMP'; WA7BNM: 0; QRZRUID: 132; Email: 'r4w@narod.ru';
       Friendly: 'Udmurtia Open Championship';
       Display: 'Udmurtia Open Championship'; DomesticFile: ''),
      (* UBACW *)
      (Token: 'UBA-DX-CW'; WA7BNM: 261; QRZRUID: 59; Email: '';
       Friendly: 'UBA DX Contest, CW';
       Display: 'UBA DX Contest, CW'; DomesticFile: 'uba'),
      (* UBASSB *)
      (Token: 'UBA-DX-SSB'; WA7BNM: 235; QRZRUID: 58; Email: '';
       Friendly: 'UBA DX Contest, SSB';
       Display: 'UBA DX Contest, SSB'; DomesticFile: 'uba'),
      (* UCG *)
      (Token: 'UCG'; WA7BNM: 0; QRZRUID: 160; Email: '';
       Friendly: 'UCG';
       Display: 'UCG'; DomesticFile: ''),
      (* UKRAINECHAMPIONSHIP *)
      (Token: 'UKRAINE CHAMPIONSHIP'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'UKRAINE CHAMPIONSHIP';
       Display: 'UKRAINE CHAMPIONSHIP'; DomesticFile: 'ukraine'),
      (* UKRAINIAN *)
      (Token: 'UKRAINIAN'; WA7BNM: 176; QRZRUID: 8; Email: '';
       Friendly: 'Ukrainian DX Contest';
       Display: 'Ukrainian DX Contest'; DomesticFile: 'ukraine'),
      (* DARCWAEDCCW *)
      (Token: 'DARC-WAEDC-CW'; WA7BNM: 85; QRZRUID: 15; Email: '';
       Friendly: 'WAE DX Contest, CW';
       Display: 'WAE DX Contest, CW'; DomesticFile: ''),
      (* DARCWAEDCSSB *)
      (Token: 'DARC-WAEDC-SSB'; WA7BNM: 111; QRZRUID: 16; Email: '';
       Friendly: 'WAE DX Contest, SSB';
       Display: 'WAE DX Contest, SSB'; DomesticFile: ''),
      (* DARCXMAS *)
      (Token: 'DARC-XMAS'; WA7BNM: 210; QRZRUID: 100; Email: '';
       Friendly: 'DARC Christmas Contest';
       Display: 'DARC Christmas Contest'; DomesticFile: ''),
      (* WAG *)
      (Token: 'WAG'; WA7BNM: 163; QRZRUID: 74; Email: '';
       Friendly: 'Worked All Germany Contest';
       Display: 'Worked All Germany Contest'; DomesticFile: ''),
      (* WISCONSINQSOPARTY *)
      (Token: 'WISCONSIN QSO PARTY'; WA7BNM: 330; QRZRUID: 0; Email: '';
       Friendly: 'Wisconsin QSO Party';
       Display: 'Wisconsin QSO Party'; DomesticFile: 'wisconsin_cty'),
      (* WWL *)
      (Token: 'WWL'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'WWL';
       Display: 'WWL'; DomesticFile: ''),
      (* WWPMC *)
      (Token: 'WW PMC'; WA7BNM: 471; QRZRUID: 229; Email: '';
       Friendly: 'WW PMC Contest';
       Display: 'WW PMC Contest'; DomesticFile: 'pmc'),
      (* XMAS *)
      (Token: 'XMAS'; WA7BNM: 0; QRZRUID: 100; Email: '';
       Friendly: 'XMAS';
       Display: 'XMAS'; DomesticFile: ''),
      (* YODX *)
      (Token: 'YO-DX-HF'; WA7BNM: 98; QRZRUID: 328; Email: '';
       Friendly: 'YO DX HF Contest';
       Display: 'YO DX HF Contest'; DomesticFile: 'romania'),
      (* YOUTHCHAMPIONSHIPRF *)
      (Token: 'SRR-JR'; WA7BNM: 0; QRZRUID: 331; Email: '';
       Friendly: 'SRR-JR';
       Display: 'SRR-JR'; DomesticFile: 'russian'),
      (* RU3AXMEMORIAL *)
      (Token: 'RU3AX MEMORIAL'; WA7BNM: 202; QRZRUID: 90; Email: '';
       Friendly: 'Russian 160-Meter DX Contest';
       Display: 'Russian 160-Meter DX Contest'; DomesticFile: 'russian'),
      (* LQP *)
      (Token: 'LOCUST QSO PARTY'; WA7BNM: 446; QRZRUID: 0; Email: '';
       Friendly: 'Locust QSO Party';
       Display: 'Locust QSO Party'; DomesticFile: 'naqp'),
      (* ARKTIKA_SPRING *)
      (Token: 'ARKTIKA-SPRING'; WA7BNM: 0; QRZRUID: 351; Email: '';
       Friendly: 'ARKTIKA-SPRING';
       Display: 'Arktika Spring'; DomesticFile: ''),
      (* UNDX *)
      (Token: 'UN DX'; WA7BNM: 480; QRZRUID: 13; Email: '';
       Friendly: 'UN DX Contest';
       Display: 'UN DX Contest'; DomesticFile: 'kda'),
      (* NYQP *)
      (Token: 'NY-QSO-PARTY'; WA7BNM: 473; QRZRUID: 0; Email: '';
       Friendly: 'New York QSO Party';
       Display: 'New York QSO Party'; DomesticFile: 'newyork_cty'),
      (* KINGOFSPAINCW *)
      (Token: 'KING-OF-SPAIN-CW'; WA7BNM: 23; QRZRUID: 308; Email: '';
       Friendly: 'His Maj. King of Spain Contest, CW';
       Display: 'His Maj. King of Spain Contest, CW'; DomesticFile: 'ea'),
      (* KINGOFSPAINSSB *)
      (Token: 'KING-OF-SPAIN-SSB'; WA7BNM: 59; QRZRUID: 308; Email: '';
       Friendly: 'His Maj. King of Spain Contest, SSB';
       Display: 'His Maj. King of Spain Contest, SSB'; DomesticFile: 'ea'),
      (* WRTC -- its name changed by hand, NY4I 2026-10-16, design Q58 *)
      (Token: 'WRTC'; WA7BNM: 67; QRZRUID: 0; Email: '';
       Friendly: 'World Radiosport Team Championship';
       Display: 'World Radiosport Team Championship'; DomesticFile: 'iaruhq'),
      (* TENNESSEEQSOPARTY *)
      (Token: 'TENNESSEE QSO PARTY'; WA7BNM: 115; QRZRUID: 0; Email: '';
       Friendly: 'Tennessee QSO Party';
       Display: 'Tennessee QSO Party'; DomesticFile: 'tennessee_cty'),
      (* COLORADOQSOPARTY *)
      (Token: 'COLORADO QSO PARTY'; WA7BNM: 431; QRZRUID: 0; Email: '';
       Friendly: 'Colorado QSO Party';
       Display: 'Colorado QSO Party'; DomesticFile: 'colorado_cty'),
      (* R9W_UW9WK_MEMORIAL *)
      (Token: 'R9W-UW9WK-MEMORIAL'; WA7BNM: 0; QRZRUID: 41; Email: '';
       Friendly: 'R9W-UW9WK-MEMORIAL';
       Display: 'R9W-UW9WK-MEMORIAL'; DomesticFile: ''),
      (* PCC *)
      (Token: 'PCC'; WA7BNM: 266; QRZRUID: 35; Email: '';
       Friendly: 'PRO CW Contest';
       Display: 'PRO CW Contest'; DomesticFile: ''),
      (* RADIOMEMORY *)
      (Token: 'RADIO-MEMORY'; WA7BNM: 0; QRZRUID: 83; Email: '';
       Friendly: 'RADIO-MEMORY';
       Display: 'RADIO-MEMORY'; DomesticFile: ''),
      (* DARC10M *)
      (Token: 'DARC-10M'; WA7BNM: 223; QRZRUID: 184; Email: '';
       Friendly: 'DARC 10-Meter Contest';
       Display: 'DARC 10-Meter Contest'; DomesticFile: ''),
      (* REFCW *)
      (Token: 'REF-CW'; WA7BNM: 233; QRZRUID: 67; Email: '';
       Friendly: 'REF Contest, CW';
       Display: 'REF Contest, CW'; DomesticFile: 'ref'),
      (* REFSSB *)
      (Token: 'REF-SSB'; WA7BNM: 260; QRZRUID: 67; Email: '';
       Friendly: 'REF Contest, SSB';
       Display: 'REF Contest, SSB'; DomesticFile: 'ref'),
      (* BSCI *)
      (Token: 'BLACK SEA CUP'; WA7BNM: 470; QRZRUID: 232; Email: '';
       Friendly: 'Black Sea Cup International';
       Display: 'Black Sea Cup International'; DomesticFile: ''),
      (* CQMM *)
      (Token: 'CQMM'; WA7BNM: 21; QRZRUID: 34; Email: '';
       Friendly: 'CQMM DX Contest';
       Display: 'CQMM DX Contest'; DomesticFile: ''),
      (* SASPRINT *)
      (Token: 'SA-SPRINT'; WA7BNM: 604; QRZRUID: 0; Email: 'sa-sprint.com/enviar-log/';
       Friendly: 'SA Sprint Contest';
       Display: 'SA Sprint Contest'; DomesticFile: ''),
      (* CWOPS *)
      (Token: 'CWOPS'; WA7BNM: 498; QRZRUID: 0; Email: '';
       Friendly: 'CWops Test (CWT)';
       Display: 'CWops Test (CWT)'; DomesticFile: ''),
      (* OZHCRVHF *)
      (Token: 'OZHCR-VHF'; WA7BNM: 0; QRZRUID: 203; Email: '';
       Friendly: 'OZHCR-VHF';
       Display: 'OZHCR-VHF'; DomesticFile: ''),
      (* CANADA_DAY *)
      (Token: 'CANADA DAY'; WA7BNM: 60; QRZRUID: 101; Email: '';
       Friendly: 'RAC Canada Day Contest';
       Display: 'RAC Canada Day Contest'; DomesticFile: 'p13'),
      (* CQWWRTTY *)
      (Token: 'CQ-WW-RTTY'; WA7BNM: 130; QRZRUID: 191; Email: 'rtty@cqww.com';
       Friendly: 'CQ Worldwide DX Contest, RTTY';
       Display: 'CQ Worldwide DX Contest, RTTY'; DomesticFile: 's48p14dc'),
      (* CWOPEN *)
      (Token: 'CWOPEN'; WA7BNM: 532; QRZRUID: 0; Email: 'cwo@cwops.org';
       Friendly: 'CWOps CW Open';
       Display: 'CWOps CW Open'; DomesticFile: ''),
      (* MAKROTHEN *)
      (Token: 'MAKROTHEN-RTTY'; WA7BNM: 159; QRZRUID: 515; Email: '';
       Friendly: 'Makrothen RTTY Contest';
       Display: 'Makrothen RTTY Contest'; DomesticFile: ''),
      (* EUSPRINT_SPRING_SSB *)
      (Token: 'EU-SPRINT-SPRING-SSB'; WA7BNM: 316; QRZRUID: 216; Email: '';
       Friendly: 'RSGB International Sprint Contest, SSB';
       Display: 'RSGB International Sprint Contest, SSB'; DomesticFile: ''),
      (* EUSPRINT_AUTUMN_CW *)
      (Token: 'EU-SPRINT-AUTUMN-CW'; WA7BNM: 152; QRZRUID: 216; Email: '';
       Friendly: 'EU Autumn Sprint, CW';
       Display: 'EU Autumn Sprint, CW'; DomesticFile: ''),
      (* EUSPRINT_AUTUMN_SSB *)
      (Token: 'EU-SPRINT-AUTUMN-SSB'; WA7BNM: 143; QRZRUID: 216; Email: '';
       Friendly: 'Eu Autumn Sprint, SSB';
       Display: 'Eu Autumn Sprint, SSB'; DomesticFile: ''),
      (* ARRL_RTTY_ROUNDUP *)
      (Token: 'ARRL-RTTY'; WA7BNM: 217; QRZRUID: 56; Email: 'rttyru@arrl.org';
       Friendly: 'ARRL RTTY Roundup';
       Display: 'ARRL RTTY Roundup'; DomesticFile: 's48p14dc'),
      (* CQIR *)
      (Token: 'CQIR'; WA7BNM: 434; QRZRUID: 0; Email: '';
       Friendly: 'CQIR - Ireland Calling';
       Display: 'CQIR - Ireland Calling'; DomesticFile: 'ireland'),
      (* WWIH *)
      (Token: 'WWIH'; WA7BNM: 552; QRZRUID: 0; Email: '';
       Friendly: 'World Wide Iron Ham Contest';
       Display: 'World Wide Iron Ham Contest'; DomesticFile: ''),
      (* ALRS_UA1DZ_CUP *)
      (Token: 'ALRS-UA1DZ-CUP'; WA7BNM: 697; QRZRUID: 543; Email: '';
       Friendly: 'UA1DZ Memorial Cup';
       Display: 'UA1DZ Memorial Cup'; DomesticFile: 'russian'),
      (* WINTERFIELDDAY *)
      (Token: 'WINTER FIELD DAY'; WA7BNM: 421; QRZRUID: 0; Email: 'wfda@winterfieldday.com';
       Friendly: 'Winter Field Day';
       Display: 'Winter Field Day'; DomesticFile: 'arrlsect'),
      (* RADIOYOC *)
      (Token: 'RADIO-YOC'; WA7BNM: 0; QRZRUID: 119; Email: '';
       Friendly: 'RADIO-YOC';
       Display: 'RADIO-YOC'; DomesticFile: ''),
      (* PAQSOPARTY *)
      (Token: 'PA QSO PARTY'; WA7BNM: 153; QRZRUID: 0; Email: '';
       Friendly: 'Pennsylvania QSO Party';
       Display: 'Pennsylvania QSO Party'; DomesticFile: 'pa_cty'),
      (* INQSOPARTY *)
      (Token: 'IN QSO PARTY'; WA7BNM: 8; QRZRUID: 0; Email: '';
       Friendly: 'Indiana QSO Party';
       Display: 'Indiana QSO Party'; DomesticFile: 'in_cty'),
      (* OKOMSSB *)
      (Token: 'OK-OM DX SSB'; WA7BNM: 567; QRZRUID: 12; Email: '';
       Friendly: 'OK/OM DX Contest, SSB';
       Display: 'OK/OM DX Contest, SSB'; DomesticFile: 'okom'),
      (* BATAVIA_FT8 *)
      (Token: 'BATAVIA-FT8'; WA7BNM: 677; QRZRUID: 0; Email: '';
       Friendly: 'Batavia FT8 Contest';
       Display: 'Batavia FT8 Contest'; DomesticFile: ''),
      (* WWDIGI *)
      (Token: 'WWDIGI'; WA7BNM: 650; QRZRUID: 0; Email: 'director@ww-digi.com';
       Friendly: 'World Wide Digi DX Contest';
       Display: 'World Wide Digi DX Contest'; DomesticFile: ''),
      (* MWC *)
      (Token: 'MWC'; WA7BNM: 683; QRZRUID: 0; Email: 'memorial-ok1wc.cz/index.php?page=logs';
       Friendly: 'OK1WC Memorial (MWC)';
       Display: 'OK1WC Memorial (MWC)'; DomesticFile: 'mwc'),
      (* IRTS *)
      (Token: 'IRTS'; WA7BNM: 756; QRZRUID: 0; Email: 'IRTS.contests@gmail.com';
       Friendly: 'IRTS 80m Counties Contest';
       Display: 'IRTS 80m Counties Contest'; DomesticFile: 'ireland'),
      (* EUDX *)
      (Token: 'EUDX'; WA7BNM: 687; QRZRUID: 0; Email: 'log.eudxc@gmail.com';
       Friendly: 'European Union DX Contest';
       Display: 'European Union DX Contest'; DomesticFile: 'EUDX'),
      (* BCQP *)
      (Token: 'BCQP'; WA7BNM: 269; QRZRUID: 0; Email: '';
       Friendly: 'British Columbia QSO Party';
       Display: 'British Columbia QSO Party'; DomesticFile: 've7_cty'),
      (* VAQP *)
      (Token: 'VAQP'; WA7BNM: 302; QRZRUID: 0; Email: '';
       Friendly: 'Virginia QSO Party';
       Display: 'Virginia QSO Party'; DomesticFile: 'va_cty'),
      (* YOTA *)
      (Token: 'YOTA'; WA7BNM: 696; QRZRUID: 0; Email: '';
       Friendly: 'YOTA Contest';
       Display: 'YOTA Contest'; DomesticFile: 'YOTA'),
      (* IN7QPNE *)
      (Token: 'IN7QPNE'; WA7BNM: 0; QRZRUID: 0; Email: '';
       Friendly: 'Combined Indiana, 7th Call Area, New England and Delaware QSO Party';
       Display: 'Combined Indiana, 7th Call Area, New England and Delaware QSO Party'; DomesticFile: 'in7qpne_cty'),
      (* MST *)
      (Token: 'MST'; WA7BNM: 720; QRZRUID: 0; Email: '';
       Friendly: 'ICWC Medium Speed Test';
       Display: 'ICWC Medium Speed Test'; DomesticFile: ''),
      (* SST *)
      (Token: 'SST'; WA7BNM: 681; QRZRUID: 0; Email: 'k1usn.radioclub.sst@gmail.com';
       Friendly: 'K1USN Slow Speed Test';
       Display: 'K1USN Slow Speed Test'; DomesticFile: 'naqp'),
      (* RTC *)
      (Token: 'RTC'; WA7BNM: 782; QRZRUID: 0; Email: '';
       Friendly: 'Real Time Contest';
       Display: 'Real Time Contest'; DomesticFile: ''),
      (* IDAHOQSOPARTY *)
      (Token: 'IDAHO QSO PARTY'; WA7BNM: 305; QRZRUID: 0; Email: '';
       Friendly: 'Idaho QSO Party';
       Display: 'Idaho QSO Party'; DomesticFile: 'idaho_cty'),
      (* DELAWAREQSOPARTY *)
      (Token: 'DELAWARE QSO PARTY'; WA7BNM: 240; QRZRUID: 0; Email: 'qsoparty@gmail.com';
       Friendly: 'Delaware QSO Party';
       Display: 'Delaware QSO Party'; DomesticFile: 'delaware_cty'),
      (* NEBRASKAQSO -- added by hand, 2026-10-16, from the sponsor (design Q105). *)
      (Token: 'NE-QSO-PARTY'; WA7BNM: 336; QRZRUID: 0; Email: 'nebraskaqsoparty@gmail.com';
       Friendly: 'Nebraska QSO Party';
       Display: 'Nebraska QSO Party'; DomesticFile: 'nebraska_cty')
   );

procedure TContestIdentityPinTests.RunAllTests;
begin
   Test_EveryContestStatesItsIdentityLiterally;
   Test_MatrixBlindContestsStateTheirIds;
   Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName;
end;

procedure TContestIdentityPinTests.Test_EveryContestStatesItsIdentityLiterally;
var
   c: ContestType;
   obj: TContestBase;
   pin: TIdentityPin;
   who: string;
   checked: integer;
begin
   BeginTest('Test_EveryContestStatesItsIdentityLiterally');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      pin := IDENTITY_PINS[c];
      who := string(ContestTypeSA[c]);
      (* THE ROW IS THIS CONTEST'S, before any value is believed. *)
      CheckEquals(pin.Token, who, 'row ' + IntToStr(Ord(c)) + ' is ' + pin.Token);
      obj := ContestIdentity(c);
      CheckTrue(obj <> nil, who + ': ContestIdentity answered nil');
      if obj = nil then
         begin
         Continue;
         end;
      CheckEquals(pin.WA7BNM, obj.WA7BNMId, who + ' WA7BNM calendar id');
      CheckEquals(pin.QRZRUID, obj.QRZRUId, who + ' QRZ.RU calendar id');
      CheckEquals(pin.Email, obj.SubmissionEmail, who + ' submission e-mail');
      CheckEquals(pin.Friendly, obj.FriendlyName, who + ' friendly name');
      CheckEquals(pin.Display, obj.DisplayName, who + ' display name');
      CheckEquals(pin.DomesticFile, obj.DomesticFileName, who + ' domestic file name');
      Inc(checked);
      end;

   (* EVERY ContestType, DUMMYCONTEST included -- derived, never typed. *)
   CheckEquals(Ord(High(ContestType)) + 1, checked, 'every ContestType''s identity was checked');
end;

(* THE THREE CONTESTS WHOSE ADIF ID OR CABRILLO NAME NO MATRIX LINE HOLDS --
  see the unit header. Generated with the table, and never regenerated. *)
procedure TContestIdentityPinTests.Test_MatrixBlindContestsStateTheirIds;
begin
   BeginTest('Test_MatrixBlindContestsStateTheirIds');
   CheckEquals('DUMMY CONTEST', ContestIdentity(DUMMYCONTEST).ADIFContestId, 'DUMMYCONTEST ADIF id');
   CheckEquals('DUMMY CONTEST', ContestIdentity(DUMMYCONTEST).CabrilloName, 'DUMMYCONTEST Cabrillo name');
   CheckEquals('GENERAL QSO', ContestIdentity(GENERALQSO).ADIFContestId, 'General QSO ADIF id');
   CheckEquals('GENERAL QSO', ContestIdentity(GENERALQSO).CabrilloName, 'General QSO Cabrillo name');
   CheckEquals('POTA', ContestIdentity(POTA).ADIFContestId, 'POTA ADIF id');
   CheckEquals('POTA', ContestIdentity(POTA).CabrilloName, 'POTA Cabrillo name');
end;

(* THE CABRILLO RENAMES OF 2026-10-19 -- NY4I: "do the cabrillo renames".

  Eighteen contests wrote a Cabrillo CONTEST: name the sponsor's log robot
  accepted neither as its name nor as an alias, per WA7BNM's detail page
  (docs/UDC_CROSSWALK_FINDINGS.md, "TR4W against WA7BNM"). Each now writes
  WA7BNM's name. Every old name was the contest's ContestTypeSA spelling,
  which is STORED data -- every SQLite log's contest row and every .cfg --
  so the rename must move the Cabrillo name and NOTHING ELSE. This holds
  each of the eighteen to that:
    * CabrilloName is the new name, and so is the CONTEST: line the export
      writes (CabrilloContestName, asked as PostUnit asks it);
    * the stored id is still the old spelling, and the old spelling still
      resolves to this contest through the ONE name resolver;
    * the ADIF CONTEST_ID did not move (export writes it, import matches it).

  NO READ ALIAS IS PINNED because nothing reads one: TR4W has no Cabrillo
  import, and the CabrilloName readers (PostUnit's CONTEST: line and EDI
  fallback, LOGSUBS2's UDP <contestname>) all WRITE it.

  TWO NAMES ARE SHARED ON PURPOSE (SHARED_ON_PURPOSE below): WRTC writes
  IARU-HF as the IARU HF Championship does (WRTC is contested inside it),
  and the RSGB RoLo's CW and SSB runnings both write RSGB-ROLO, the one name
  WA7BNM states for each (refs 77 and 361). Every other registered contest's
  Cabrillo name is its own, walked over the registry below.
  TR4W's XMAS contest is NOT the DARC Christmas contest (NY4I, 2026-10-19):
  it is the SSA Jultest and writes its sponsor's SSA-JULTEST, so the DARC
  contest alone writes WA7BNM's XMAS. *)
procedure TContestIdentityPinTests.Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName;
type
   TCabrilloRename = record
      Contest: ContestType;
      OldName: string;
      NewName: string;
      ADIFId: string;
   end;
const
   RENAMES: array[0..18] of TCabrilloRename = (
      (Contest: CQMM;            OldName: 'CQMM';                 NewName: 'CQMMDX';          ADIFId: 'CQMM'),
      (Contest: CWOPS;           OldName: 'CWOPS';                NewName: 'CW-OPS';          ADIFId: 'CWOPS-CWT'),
      (Contest: UKRAINIAN;       OldName: 'UKRAINIAN';            NewName: 'UKRAINIAN-DX';    ADIFId: 'UKRAINIAN'),
      (Contest: WRTC;            OldName: 'WRTC';                 NewName: 'IARU-HF';         ADIFId: 'WRTC'),
      (Contest: GACWWWSACW;      OldName: 'GACW-WWSA-CW';         NewName: 'WWSA';            ADIFId: 'GACW-WWSA-CW'),
      (Contest: BCQP;            OldName: 'BCQP';                 NewName: 'BC-QSO-PARTY';    ADIFId: 'BC-QSO-PARTY'),
      (Contest: CALQSOPARTY;     OldName: 'CALIFORNIA QSO PARTY'; NewName: 'CA-QSO-PARTY';    ADIFId: 'CA-QSO-PARTY'),
      (Contest: CQVHF;           OldName: 'CQ-VHF';               NewName: 'CQ-VHF-SSBCW';    ADIFId: 'CQ-VHF'),
      (Contest: DARCXMAS;        OldName: 'DARC-XMAS';            NewName: 'XMAS';            ADIFId: 'DARC-XMAS'),
      (Contest: EUDX;            OldName: 'EUDX';                 NewName: 'EUDXC';           ADIFId: 'EUDX'),
      (Contest: MST;             OldName: 'MST';                  NewName: 'ICWC-MST';        ADIFId: 'ICWC-MST'),
      (Contest: IRTS;            OldName: 'IRTS';                 NewName: 'IRTS-80-CONTEST'; ADIFId: 'IRTS'),
      (Contest: MARCONIMEMORIAL; OldName: 'MARCONI MEMORIAL';     NewName: 'MMC-HF-CW';       ADIFId: 'MARCONI MEMORIAL'),
      (Contest: CANADA_DAY;      OldName: 'CANADA DAY';           NewName: 'CANADA-DAY';      ADIFId: 'CANADA DAY'),
      (Contest: CANADA_WINTER;   OldName: 'CANADA WINTER';        NewName: 'CANADA-WINTER';   ADIFId: 'CANADA WINTER'),
      (Contest: RU3AXMEMORIAL;   OldName: 'RU3AX MEMORIAL';       NewName: 'RADIO-160';       ADIFId: 'RU3AX MEMORIAL'),
      (Contest: TEXASQSOPARTY;   OldName: 'TEXAS QSO PARTY';      NewName: 'TXQP';            ADIFId: 'TX-QSO-PARTY'),
      (Contest: YBDX;            OldName: 'YBDX';                 NewName: 'ORARI-DX';        ADIFId: 'YBDX'),
      (* NOT a WA7BNM rename: the SSA Jultest's own name, from its sponsor --
         see TContestXmas.GetCabrilloName. *)
      (Contest: XMAS;            OldName: 'XMAS';                 NewName: 'SSA-JULTEST';     ADIFId: 'XMAS')
   );
var
   i: integer;
   j: integer;
   obj: TContestBase;
   who: string;
   resolved: TContestHandle;
   contests: TContestIdentityList;
   shared: string;

   (* Is the pair (a, b), in either order, one of SHARED_ON_PURPOSE? *)
   function IsSharedOnPurpose(a, b: ContestType): boolean;
   type
      TContestPair = record
         First: ContestType;
         Second: ContestType;
      end;
   const
      SHARED_ON_PURPOSE: array[0..1] of TContestPair = (
         (* WRTC is contested inside the IARU HF Championship. *)
         (First: WRTC;           Second: IARU),
         (* WA7BNM 77 (CW) and 361 (SSB): "Cabrillo name: RSGB-ROLO" for both. *)
         (First: RSGB_ROPOCO_CW; Second: RSGB_ROPOCO_SSB)
      );
   var
      k: integer;
   begin
      Result := False;
      for k := Low(SHARED_ON_PURPOSE) to High(SHARED_ON_PURPOSE) do
         begin
         if ((a = SHARED_ON_PURPOSE[k].First) and (b = SHARED_ON_PURPOSE[k].Second)) or
            ((a = SHARED_ON_PURPOSE[k].Second) and (b = SHARED_ON_PURPOSE[k].First)) then
            begin
            Result := True;
            end;
         end;
   end;

begin
   BeginTest('Test_WA7BNMCabrilloRenamesMoveOnlyTheCabrilloName');
   for i := Low(RENAMES) to High(RENAMES) do
      begin
      who := RENAMES[i].OldName;
      obj := ContestIdentity(RENAMES[i].Contest);
      CheckEquals(RENAMES[i].NewName, obj.CabrilloName, who + ': the Cabrillo name');
      CheckEquals(RENAMES[i].NewName, obj.CabrilloContestName('', ''),
                  who + ': the CONTEST: line the export writes');
      CheckEquals(RENAMES[i].NewName, obj.CabrilloContestName('A TITLE', 'A NAME'),
                  who + ': the CONTEST: line ignores the title and session name');

      CheckEquals(RENAMES[i].OldName, ContestId(ContestHandleOf(RENAMES[i].Contest)),
                  who + ': the stored id is unchanged');
      CheckTrue(TryContestFromName(RENAMES[i].OldName, resolved),
                who + ': the old spelling still resolves');
      CheckTrue(resolved = ContestHandleOf(RENAMES[i].Contest),
                who + ': and resolves to the same contest');
      CheckEquals(RENAMES[i].ADIFId, obj.ADIFContestId, who + ': the ADIF CONTEST_ID is unchanged');
      end;

   (* THE TWO SHARED NAMES, stated from both sides, so an exception below
     that stops being true fails here rather than going stale. *)
   CheckEquals('IARU-HF', ContestIdentity(IARU).CabrilloName, 'IARU HF writes IARU-HF as WRTC now does');
   CheckEquals('RSGB-ROLO', ContestIdentity(RSGB_ROPOCO_CW).CabrilloName, 'the RoLo CW writes RSGB-ROLO');
   CheckEquals('RSGB-ROLO', ContestIdentity(RSGB_ROPOCO_SSB).CabrilloName, 'the RoLo SSB writes RSGB-ROLO');

   (* NO TWO REGISTERED CONTESTS WRITE ONE CABRILLO NAME, but the pairs in
     IsSharedOnPurpose. Two different events must not write the same
     CONTEST: line: the sponsor's robot would take one event's log as the
     other's. Walks the registry, so a contest added later is held too.
     Compared as Cabrillo compares, case-blind. Every pair is listed in one
     failure. *)
   contests := ContestsToWalk;
   shared := '';
   for i := 0 to High(contests) - 1 do
      begin
      for j := i + 1 to High(contests) do
         begin
         if SameText(contests[i].CabrilloName, contests[j].CabrilloName) then
            begin
            if not IsSharedOnPurpose(ContestOf(contests[i]), ContestOf(contests[j])) then
               begin
               shared := shared + ' ' + ContestWho(contests[i]) + ' and ' +
                         ContestWho(contests[j]) + ' both write "' +
                         contests[i].CabrilloName + '";';
               end;
            end;
         end;
      end;
   CheckEquals('', shared, 'two contests write one Cabrillo name');
end;

end.
