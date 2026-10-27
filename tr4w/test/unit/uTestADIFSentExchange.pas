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

(* THE ADIF STX_STRING EVERY CONTEST SENDS, AT EVERY ROSTER STATION -- M11
  S9b, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S9b).

  WHY IT EXISTS. S9b moves the third exchange-shape machine,
  uADIFExchange.FormatADIFExchangeOfKind (the `case` over the session's
  exchange shape that built the MY-exchange of an ADIF record), into the
  classes: each states its STX_STRING (TContestBase.FormatADIFSentExchange)
  by calling a named helper in uADIFExchange. The corpus sees thirteen
  contests' STX_STRING and the matrix none, so this pins ALL of them.

  HOW THE LITERALS WERE MADE. The OLD machine, run for every ContestType at
  the seven roster stations (uTestExchangeFields.TPinStation) with four
  inputs, and the text it returned laid out below grouped by output. NOT
  from the new code: from the program as it stood before S9b, through
  TContestBase.FormatADIFSentExchange(my, qso, <the session's exchange>).
  RUN GREEN AGAINST THE OLD CODE before anything moved (ProgramSent's old
  body is in the plan), then the same tables green against the classes.

  THE FOUR INPUTS:
    0  a full exchange, serial 7        (FL, EL88AA, TOM, zone 5, park K-1234)
    1  an empty one, RST 59, serial 123 (a station with no state: the 'DX'
                                         arms, the zero zone, the serial arms)
    2  OVER-LONG values                 (a 26-character state, a 10-character
                                         grid, a 13-character park: the
                                         machine cut them to 20, 7 and 10 --
                                         uADIFExchange.Clipped...)
    3  a state of TRC                   (the one value an arm tests)

  THE PLACEHOLDERS ARE GONE (2026-10-14, plan F25/F26/F27, NY4I: "F25 was an
  artifact where the ADIF exchange generation had an error ... We should
  report an error as the silent error is not good"). S9b pinned five
  contests, and the classless DUMMYCONTEST, to 'Error generating my
  exchange' (three layouts the machine never built), and fourteen more to
  'None'. Now:
    - the Cup RF CW/SSB/DIG, CQ WW RTTY and the Youth Championship RF pin the
      text their own Cabrillo sent column prints (F25, FIXED);
    - the DUMMYCONTEST and the fourteen contests with no layout pin '' -- the
      field is LEFT OUT and TryFormatADIFSentExchange reports it (F26,
      reported, not fixed: their layouts need the sponsors' rules);
    - Test_AFailureIsReportedNotSwallowed pins the reporting itself.
  Those are the only rows that differ from the S9b literals.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's STX_STRING changed. *)
unit uTestADIFSentExchange;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TADIFSentExchangeTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestSendsItsPinnedSTXString;
      procedure Test_EachHelperPrintsItsLayout;
      procedure Test_TheBaseStatesNoLayoutAndSaysSo;
      procedure Test_AFailureIsReportedNotSwallowed;
      procedure Test_TheFiveF25ContestsSendTheirCabrilloText;
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   Classes,
   SysUtils,
   Log4D,
   VC,
   uContestBase,
   uADIFExchange,
   uTestContestObjects,
   uTestExchangeFields,
   (* TCaptureAppender -- lifted there 2026-10-17 (Q35, its second caller). *)
   uTestLogCapture;

type
   TADIFSentHelper = function(const aMy: TMyStationExchange;
                              const aQso: ContestExchange): string;

   (* A CONTEST WHOSE getter RAISES -- the failure the machine's own
      try/except used to swallow into a placeholder. *)
   TFailingContest = class(TContestBase)
   protected
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;
   end;

function TFailingContest.GetADIFSentExchange(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange): string;
begin
   Result := '';
   raise EConvertError.Create('injected failure');
end;

(* The four inputs -- see the header. *)
function PinMy(aVariant: integer): TMyStationExchange;
begin
   Result := Default(TMyStationExchange);
   case aVariant of
      0:
         begin
         Result.MyState := 'FL';
         Result.MyGrid := 'EL88AA';
         Result.MyName := 'TOM';
         Result.MyZone := '5';
         Result.MyFDClass := '1D';
         Result.MySection := 'WCF';
         Result.MyCheck := '84';
         Result.MyPrec := 'A';
         Result.MyFOCNumber := '1234';
         Result.MyPostalCode := '33701';
         Result.MyPark := 'K-1234';
         end;
      1:
         begin
         (* Everything empty. *)
         end;
      2:
         begin
         Result.MyState := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
         Result.MyGrid := 'EL88AA55JJ';
         Result.MyName := 'TOMASZ-THE-VERY-LONG-NAME';
         Result.MyZone := '12';
         Result.MyFDClass := '1D';
         Result.MySection := 'WCF';
         Result.MyCheck := '84';
         Result.MyPrec := 'A';
         Result.MyFOCNumber := '1234';
         Result.MyPostalCode := 'AB12CD34EF56GH78IJ90KL';
         Result.MyPark := 'K-12345678901';
         end;
      3:
         begin
         Result.MyState := 'TRC';
         Result.MyGrid := 'EL88AA';
         Result.MyName := 'TOM';
         Result.MyZone := '5';
         end;
   end;
end;

function PinQso(aVariant: integer): ContestExchange;
begin
   FillChar(Result, SizeOf(ContestExchange), 0);
   Result.RSTSent := 599;
   Result.NumberSent := 7;
   if aVariant = 1 then
      begin
      Result.RSTSent := 59;
      Result.NumberSent := 123;
      end;
   if aVariant = 2 then
      begin
      Result.NumberSent := 4567;
      end;
end;

(* WHAT THE PROGRAM ANSWERS -- PostUnit asks the contest's identity for the
   string. BEFORE THE MOVE the call carried the session's exchange as a third
   argument, resolved the way start-up resolves it: the trait, and the
   contest's DescribeSession over it (uTestContestKindPin.Kinds) -- the run
   that made the literals. *)
function ProgramSent(aContest: ContestType; const aStation: TStationContext;
                     aVariant: integer): string;
var
   obj: TContestBase;
begin
   obj := Make(aContest, aStation);
   try
      Result := obj.FormatADIFSentExchange(PinMy(aVariant), PinQso(aVariant));
   finally
      obj.Free;
      end;
end;

(* One of the four literals, by variant. *)
function Pick(aVariant: integer; const a0, a1, a2, a3: string): string;
begin
   case aVariant of
      0: Result := a0;
      1: Result := a1;
      2: Result := a2;
   else
      Result := a3;
   end;
end;

(* THE PINNED STX_STRING, laid out from the old machine's output. *)
function PinnedSent(aContest: ContestType; aStation: TPinStation;
                    aVariant: integer): string;
begin
   (* THE JIDX: a Japanese entrant receives a zone, anyone else a
      prefecture -- the one pair whose STX_STRING moves with the station.
      PACC moves with it too since Q22 (2026-10-16); its rows are below. *)
   if aContest in [JIDXCW, JIDXSSB] then
      begin
      if aStation = psJA then
         begin
         Result := Pick(aVariant, '599 05     ', '59  00     ', '599 12     ', '599 05     ');
         end
      else
         begin
         Result := Pick(aVariant, '599 5      ', '59  0      ', '599 12     ', '599 5      ');
         end;
      Exit;
      end;

   (* A DX ENTRANT'S STX_STRING SAYS WHAT WAS SENT: "DX" (2026-10-27, NY4I).
      The ADIF STX_STRING is the information transmitted, and these contests'
      Cabrillo sent column (CabrilloSentRSTStateOrDX, uTestCabrilloColumns)
      writes DX for a station with no state; ADIFSentRSTState wrote nothing.
      Only input 1 (no state) differs from the plain RST-and-state rows below.
      The stations that send DX are the Cabrillo pin's own: the five parties
      that send their state in the host area and DX elsewhere (the host
      station sends nothing), ARRL 160 (W/VE send nothing), and the rest at
      every station. *)
   if (aVariant = 1) and
      ((aContest in [ALRS_UA1DZ_CUP, BCQP, IN7QPNE, INQSOPARTY, MICHQSOPARTY, MOQSOPARTY,
                     NCQSOPARTY, NYQP, TENNESSEEQSOPARTY, TOEC, WISCONSINQSOPARTY]) or
       ((aContest in [SEVENQP, ArizonaQsoParty, NEWENGLANDQSO, SALMONRUN, TEXASQSOPARTY]) and
        (aStation in [psUS, psVE, psDX, psPA, psKH6, psJA])) or
       ((aContest = ARRL160) and
        (aStation in [psDX, psPA, psJA]))) then
      begin
      Result := '59  DX     ';
      Exit;
      end;

   case aContest of
      (* F25, FIXED 2026-10-14 (NY4I: "F25 was an artifact ... we should
         report an error as the silent error is not good"). These five WERE
         pinned to the placeholder 'Error generating my exchange'. Each now
         pins the text its own Cabrillo sent column prints. *)
      CUPRFCW, CUPRFSSB, CUPRFDIG:
         begin
         (* '%.*d %-6.4s ' of the serial and MY STATE, the grid the Cup RF
            sends (cut to four). *)
         Result := Pick(aVariant, '007 FL     ',
                     '123        ',
                     '4567 ABCD   ',
                     '007 TRC    ');
         end;
      CQWWRTTY:
         begin
         (* '%-3d %.2u %-4s' of the RST, the zone and the state or 'DX'. *)
         Result := Pick(aVariant, '599 05 FL  ',
                     '59  00 DX  ',
                     '599 12 ABCDEFGHIJKLMNOPQRST',
                     '599 05 TRC ');
         end;
      YOUTHCHAMPIONSHIPRF:
         begin
         (* '%-2s %.*d ' of the state and the serial. *)
         Result := Pick(aVariant, 'FL 007 ',
                     '   123 ',
                     'ABCDEFGHIJKLMNOPQRST 4567 ',
                     'TRC 007 ');
         end;
      (* F25/F26, 2026-10-14: NO PLACEHOLDER. The classless DUMMYCONTEST and
         the fourteen contests below state no layout, so the field is
         LEFT OUT ('') and the failure is reported -- it was 'Error
         generating my exchange' for the base and 'None' for the fourteen. *)
      DUMMYCONTEST:
         begin
         Result := '';
         end;
      SEVENQP, ALLASIANCW, ALLASIANSSB, ARRL160, ArizonaQsoParty, LABRE, MICHQSOPARTY,
      MOQSOPARTY, NEWENGLANDQSO, NCQSOPARTY, OLDNEWYEAR, SALMONRUN, SOUTHAMERICANWW,
      TEXASQSOPARTY, TOEC, WISCONSINQSOPARTY, NYQP, TENNESSEEQSOPARTY, CQMM, ALRS_UA1DZ_CUP,
      INQSOPARTY, BCQP, YOTA, IN7QPNE, IDAHOQSOPARTY, DELAWAREQSOPARTY, NEBRASKAQSO:
         begin
         Result := Pick(aVariant, '599 FL     ',
                     '59         ',
                     '599 ABCDEFGHIJKLMNOPQRST',
                     '599 TRC    ');
         end;
      ALLJA, ARCI, COUNTYHUNTER, FISTS, GRIDLOC, JALONGPREFECT, KIDSDAY, NZFIELDDAY, QCWA,
      QCWAGOLDEN, TENTEN, UA4WCHAMPIONSHIP, WWL, XMAS:
         begin
         Result := '';   (* was 'None' -- plan F26, NY4I 2026-10-14 *)
         end;
      APSPRINT, BALTIC, CQM, CQWPXCW, CQWPXSSB, CQWPXRTTY, MARCONIMEMORIAL, MINITEST, MINI80,
      MINI40, OCEANIADXCW, OCEANIADXSSB, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW,
      REGION1FIELDDAY_RCC_SSB, SACCW, YBDX, SACSSB, UCG, DARCWAEDCCW, DARCWAEDCSSB, SASPRINT,
      MWC:
         begin
         Result := Pick(aVariant, '599   7 ',
                     '59  123 ',
                     '599 4567 ',
                     '599   7 ');
         end;
      ARI_DX, ARRL10, CIS, HADX, YUDX, HELVETIA, OKDX, CANADA_WINTER, RDA, RUSSIANDX, SPDX,
      UKRAINIAN, DARCXMAS, WAG, YODX, RU3AXMEMORIAL, ARKTIKA_SPRING, UNDX, KINGOFSPAINCW,
      KINGOFSPAINSSB, REFCW, REFSSB, CANADA_DAY, ARRL_RTTY_ROUNDUP, OKOMSSB:
         begin
         Result := Pick(aVariant, '599 FL     ',
                     '59   123   ',
                     '599 ABCDEFGHIJKLMNOPQRST',
                     '599 TRC    ');
         end;
      ARRLDIGI, MAKROTHEN, BATAVIA_FT8, WWDIGI:
         begin
         Result := Pick(aVariant, 'EL88AA',
                     '',
                     'EL88AA5',
                     'EL88AA');
         end;
      ARRLDXCW, ARRLDXSSB, FLORIDAQSOPARTY:
         begin
         Result := Pick(aVariant, '599 FL     ',
                     '59         ',
                     '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                     '599 TRC    ');
         end;
      ARRLSSCW, ARRLSSSSB:
         begin
         Result := Pick(aVariant, '7    A 84 WCF ',
                     '123        ',
                     '4567 A 84 WCF ',
                     '7          ');
         end;
      ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, CQVHF, STEWPERRY:
         begin
         Result := Pick(aVariant, '599 EL88AA ',
                     '59         ',
                     '599 EL88AA5',
                     '599 EL88AA ');
         end;
      BWQP:
         begin
         Result := Pick(aVariant, '599 TOM   FL     ',
                     '59               ',
                     '599 TOMASZ-THE-VERY-LONG ABCDEFGHIJKLMNOPQRST',
                     '599 TOM   TRC    ');
         end;
      CALQSOPARTY, CUPURAL, UKRAINECHAMPIONSHIP, PAQSOPARTY, VAQP:
         begin
         Result := Pick(aVariant, 'FL   7     ',
                     '     123   ',
                     'ABCDEFGHIJKLMNOPQRST 4567  ',
                     'TRC  7     ');
         end;
      CQ160CW, CQ160SSB, CROATIAN, GAGARINCUP, KCJ, LZDX, OZCR_O, OZCR_Z, WWPMC, WRTC, BSCI,
      IRTS, EUDX:
         begin
         Result := Pick(aVariant, '599 FL     ',
                     '59  0      ',
                     '599 ABCDEFGHIJKLMNOPQRST',
                     '599 TRC    ');
         end;
      CQWWCW, CQWWSSB, EUROPEANHFC, GACWWWSACW, JTDX, KVP, WWIH:
         begin
         Result := Pick(aVariant, '599 05     ',
                     '59  00     ',
                     '599 12     ',
                     '599 05     ');
         end;
      EUSPRINT_SPRING_CW, CWOPEN, EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW, EUSPRINT_AUTUMN_SSB,
      MST:
         begin
         Result := Pick(aVariant, '7   TOM    ',
                     '123        ',
                     '4567 TOMASZ-THE-VERY-LONG',
                     '7   TOM    ');
         end;
      EUROPEANVHF, TESLA, RADIOVHFFD, OZHCRVHF, RTC:
         begin
         Result := Pick(aVariant, '599 7    EL88AA ',
                     '59  123         ',
                     '599 4567 EL88AA5',
                     '599 7    EL88AA ');
         end;
      ARRLFIELDDAY, WINTERFIELDDAY:
         begin
         Result := Pick(aVariant, '1D  WCF     ',
                     '            ',
                     '1D  WCF     ',
                     '            ');
         end;
      FOCMARATHON:
         begin
         Result := Pick(aVariant, '599 1234   ',
                     '59         ',
                     '599 1234   ',
                     '599        ');
         end;
      GENERALQSO:
         begin
         Result := Pick(aVariant, '599 TOM   FL     ',
                     '59               ',
                     '599 TOMASZ-THE-VERY-LONG-NAME ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                     '599 TOM   TRC    ');
         end;
      UKEI, IOTA, NRAUBALTICCW, NRAUBALTICSSB, OHIOQSOPARTY, RSGB18, UBACW, UBASSB, DARC10M,
      CQIR:
         begin
         Result := Pick(aVariant, '599 7    FL     ',
                     '59  123         ',
                     '599 4567 ABCDEFGHIJKLMNOPQRST ',
                     '599 7TRC   ');
         end;
      IARU:
         begin
         Result := Pick(aVariant, '599 FL     ',
                     '59  0      ',
                     '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                     '599 TRC    ');
         end;
      INTERNETSPRINT, SPRINTSSB, NASPRINTRTTY, NCCCSPRINT:
         begin
         Result := Pick(aVariant, '7    TOM     FL      ',
                     '123          DX      ',
                     '4567 TOMASZ-THE-VERY-LONG ABCDEFGHIJKLMNOPQRST',
                     '7    TOM     TRC     ');
         end;
      MINNQSOPARTY, NAQSOCW, NAQSOSSB, NAQSORTTY, LQP, COLORADOQSOPARTY, CWOPS, SST:
         begin
         Result := Pick(aVariant, '  TOM        FL  ',
                     '                 ',
                     '  TOMASZ-THE-VERY-LONG ABCDEFGHIJKLMNOPQRST',
                     '  TOM        TRC ');
         end;
      NASPRINTCW:
         begin
         Result := Pick(aVariant, '7    TOM     FL      ',
                     '123          DX      ',
                     '4567 TOMASZ-THE-VERY-LONG-NAME ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                     '7    TOM     TRC     ');
         end;
      PACC:
         begin
         if aStation = psPA then
            begin
            (* A DUTCH ENTRANT SENDS RST AND ITS PROVINCE, or RST and the
               serial when MY STATE is empty -- Q22 (NY4I, 2026-10-16,
               docs/CONTEST_FACTORY_OPEN_QUESTIONS.md), D7's
               RSTAndQSONumberOrDomesticQTHExchange arm. It was the serial
               below at every station until then: the defect. Changed by
               hand. *)
            Result := Pick(aVariant, '599 FL     ',
                        '59   123   ',
                        '599 ABCDEFGHIJKLMNOPQRST',
                        '599 TRC    ');
            end
         else
            begin
            Result := Pick(aVariant, '599 7      ',
                        '59  123    ',
                        '599 4567   ',
                        '599 7      ');
            end;
         end;
      POTA:
         begin
         Result := Pick(aVariant, 'K-1234',
                     '',
                     'K-12345678',
                     '');
         end;
      RAEM:
         begin
         Result := Pick(aVariant, 'FL',
                     '',
                     'ABCDEFGHIJKLMNOPQRST',
                     'TRC');
         end;
      RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, R9W_UW9WK_MEMORIAL:
         begin
         Result := Pick(aVariant, '  FL      7 ',
                     '      123 ',
                     '  ABCDEFGHIJKLMNOPQRST    4567 ',
                     '  TRC      7 ');
         end;
      RFASCHAMPIONSHIPCW:
         begin
         Result := Pick(aVariant, 'FL    7    ',
                     '    123    ',
                     'ABCDEFGHIJKLMNOPQRST 4567    ',
                     'TRC   7    ');
         end;
      RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB:
         begin
         Result := Pick(aVariant, '599           ',
                     '59            ',
                     '599           ',
                     '599           ');
         end;
      PCC:
         begin
         Result := Pick(aVariant, '599    7   ',
                     '59   123   ',
                     '599  4567   ',
                     '599    7   ');
         end;
      RADIOMEMORY:
         begin
         Result := Pick(aVariant, '599 FL              ',
                     '59                  ',
                     '599 ABCDEFGHIJKLMNOPQRST',
                     '599 TRC             ');
         end;
      RADIOYOC:
         begin
         (* Q136 (2026-10-22): the age (MY STATE) and the serial -- the
            Youth Championship RF's helper and rows. *)
         Result := Pick(aVariant, 'FL 007 ',
                     '   123 ',
                     'ABCDEFGHIJKLMNOPQRST 4567 ',
                     'TRC 007 ');
         end;
   else
      begin
      Result := '<not pinned>';
      end;
   end;
end;

procedure TADIFSentExchangeTests.Test_EveryContestSendsItsPinnedSTXString;
var
   s: TPinStation;
   c: ContestType;
   v: integer;
   checked: integer;
begin
   BeginTest('Test_EveryContestSendsItsPinnedSTXString');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         for v := 0 to 3 do
            begin
            CheckEquals(PinnedSent(c, s, v),
                        ProgramSent(c, PinStation(s, c), v),
                        string(ContestTypeSA[c]) + ' at ' + PinStationCall(s) +
                        ', input ' + IntToStr(v) + ': STX_STRING');
            Inc(checked);
            end;
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) * 4, checked,
               'contest x station x input STX_STRINGs pinned');
end;

(* EVERY HELPER, BY NAME -- its layout at the four inputs, literally. *)
procedure TADIFSentExchangeTests.Test_EachHelperPrintsItsLayout;

   procedure CheckHelper(const aName: string; aHelper: TADIFSentHelper;
                         const a0, a1, a2, a3: string);
   var
      v: integer;
   begin
      for v := 0 to 3 do
         begin
         CheckEquals(Pick(v, a0, a1, a2, a3), aHelper(PinMy(v), PinQso(v)),
                     aName + ', input ' + IntToStr(v));
         end;
   end;

begin
   BeginTest('Test_EachHelperPrintsItsLayout');
   CheckHelper('ADIFSentGrid', ADIFSentGrid,
               'EL88AA',
               '',
               'EL88AA5',
               'EL88AA');
   CheckHelper('ADIFSentState', ADIFSentState,
               'FL',
               '',
               'ABCDEFGHIJKLMNOPQRST',
               'TRC');
   CheckHelper('ADIFSentPark', ADIFSentPark,
               'K-1234',
               '',
               'K-12345678',
               '');
   CheckHelper('ADIFSentRSTState', ADIFSentRSTState,
               '599 FL     ',
               '59         ',
               '599 ABCDEFGHIJKLMNOPQRST',
               '599 TRC    ');
   CheckHelper('ADIFSentRSTStateOrDX', ADIFSentRSTStateOrDX,
               '599 FL     ',
               '59  DX     ',
               '599 ABCDEFGHIJKLMNOPQRST',
               '599 TRC    ');
   CheckHelper('ADIFSentRSTGrid', ADIFSentRSTGrid,
               '599 EL88AA ',
               '59         ',
               '599 EL88AA5',
               '599 EL88AA ');
   CheckHelper('ADIFSentRSTNameQTH', ADIFSentRSTNameQTH,
               '599 TOM   FL     ',
               '59               ',
               '599 TOMASZ-THE-VERY-LONG ABCDEFGHIJKLMNOPQRST',
               '599 TOM   TRC    ');
   CheckHelper('ADIFSentRSTAgeSK', ADIFSentRSTAgeSK,
               '599 FL              ',
               '59                  ',
               '599 ABCDEFGHIJKLMNOPQRST',
               '599 TRC             ');
   CheckHelper('ADIFSentRSTQSONumberGrid', ADIFSentRSTQSONumberGrid,
               '599 7    EL88AA ',
               '59  123         ',
               '599 4567 EL88AA5',
               '599 7    EL88AA ');
   CheckHelper('ADIFSentRSTQSONumber', ADIFSentRSTQSONumber,
               '599   7 ',
               '59  123 ',
               '599 4567 ',
               '599   7 ');
   CheckHelper('ADIFSentRSTQSONumberState', ADIFSentRSTQSONumberState,
               '599 7    FL     ',
               '59  123         ',
               '599 4567 ABCDEFGHIJKLMNOPQRST ',
               '599 7TRC   ');
   CheckHelper('ADIFSentRSTPrefecture', ADIFSentRSTPrefecture,
               '599 5      ',
               '59  0      ',
               '599 12     ',
               '599 5      ');
   CheckHelper('ADIFSentRSTZone', ADIFSentRSTZone,
               '599 05     ',
               '59  00     ',
               '599 12     ',
               '599 05     ');
   CheckHelper('ADIFSentRSTZoneOrState', ADIFSentRSTZoneOrState,
               '599 FL     ',
               '59  0      ',
               '599 ABCDEFGHIJKLMNOPQRST',
               '599 TRC    ');
   CheckHelper('ADIFSentRSTStateOrQSONumber', ADIFSentRSTStateOrQSONumber,
               '599 FL     ',
               '59   123   ',
               '599 ABCDEFGHIJKLMNOPQRST',
               '599 TRC    ');
   CheckHelper('ADIFSentRSTPostalCode', ADIFSentRSTPostalCode,
               '599           ',
               '59            ',
               '599           ',
               '599           ');
   CheckHelper('ADIFSentQSONumberName', ADIFSentQSONumberName,
               '7   TOM    ',
               '123        ',
               '4567 TOMASZ-THE-VERY-LONG',
               '7   TOM    ');
   CheckHelper('ADIFSentQSONumberNameState', ADIFSentQSONumberNameState,
               '7    TOM     FL      ',
               '123          DX      ',
               '4567 TOMASZ-THE-VERY-LONG ABCDEFGHIJKLMNOPQRST',
               '7    TOM     TRC     ');
   CheckHelper('ADIFSentNameState', ADIFSentNameState,
               '  TOM        FL  ',
               '                 ',
               '  TOMASZ-THE-VERY-LONG ABCDEFGHIJKLMNOPQRST',
               '  TOM        TRC ');
   CheckHelper('ADIFSentStateThenQSONumber', ADIFSentStateThenQSONumber,
               'FL   7     ',
               '     123   ',
               'ABCDEFGHIJKLMNOPQRST 4567  ',
               'TRC  7     ');
   CheckHelper('ADIFSentStateAndQSONumberSum', ADIFSentStateAndQSONumberSum,
               'FL    7    ',
               '    123    ',
               'ABCDEFGHIJKLMNOPQRST 4567    ',
               'TRC   7    ');
   CheckHelper('ADIFSentIndentedStateAndQSONumber', ADIFSentIndentedStateAndQSONumber,
               '  FL      7 ',
               '      123 ',
               '  ABCDEFGHIJKLMNOPQRST    4567 ',
               '  TRC      7 ');
   CheckHelper('ADIFSentQSONumberPreviousQSONumber', ADIFSentQSONumberPreviousQSONumber,
               '000007    ',
               '000123    ',
               '0004567   ',
               '000007    ');
   (* F25, FIXED 2026-10-14 (NY4I) -- the three layouts the machine never
      built. The Cabrillo sent column's text, at the four inputs. *)
   CheckHelper('ADIFSentQSONumberStateShort', ADIFSentQSONumberStateShort,
               '007 FL     ',
               '123        ',
               '4567 ABCD   ',
               '007 TRC    ');
   CheckHelper('ADIFSentRSTZoneStateDX', ADIFSentRSTZoneStateDX,
               '599 05 FL  ',
               '59  00 DX  ',
               '599 12 ABCDEFGHIJKLMNOPQRST',
               '599 05 TRC ');
   CheckHelper('ADIFSentStateQSONumber2', ADIFSentStateQSONumber2,
               'FL 007 ',
               '   123 ',
               'ABCDEFGHIJKLMNOPQRST 4567 ',
               'TRC 007 ');
end;

(* A CONTEST THAT STATES NO LAYOUT -- the base, which the classless
   DUMMYCONTEST runs, and the helper the fourteen call by name. It used to
   answer 'Error generating my exchange' (the base) and 'None' (the
   fourteen). Both are gone: the helper RAISES, the caller reports it, and
   the field is left out (F25/F26, NY4I 2026-10-14). *)
procedure TADIFSentExchangeTests.Test_TheBaseStatesNoLayoutAndSaysSo;
var
   obj: TContestBase;
   sent, failure: string;
   v: integer;
   raised: boolean;
begin
   BeginTest('Test_TheBaseStatesNoLayoutAndSaysSo');
   raised := False;
   try
      ADIFSentNotImplemented(PinMy(0), PinQso(0));
   except
      on E: EADIFExchangeNotImplemented do
         begin
         raised := True;
         end;
   end;
   CheckTrue(raised, 'ADIFSentNotImplemented raises EADIFExchangeNotImplemented');

   obj := TContestBase.Create(NoContest);
   try
      for v := 0 to 3 do
         begin
         CheckFalse(obj.TryFormatADIFSentExchange(PinMy(v), PinQso(v), sent, failure),
                    'the base reports a failure, input ' + IntToStr(v));
         CheckEquals('', sent, 'and answers no text, input ' + IntToStr(v));
         CheckTrue(Pos('EADIFExchangeNotImplemented', failure) > 0,
                   'and names why: ' + failure);
         CheckEquals('', obj.FormatADIFSentExchange(PinMy(v), PinQso(v)),
                     'FormatADIFSentExchange answers the same, input ' + IntToStr(v));
         end;
   finally
      obj.Free;
      end;
end;

(* THE REPORTING ITSELF (NY4I 2026-10-14: "we should report an error as the
   silent error is not good"). A getter that raises is not swallowed into a
   made-up value: Try answers False with the reason, the text is '', and an
   Error is WRITTEN that names the contest and the QSO (call, band, mode,
   time). A getter that works answers True and writes nothing. *)
procedure TADIFSentExchangeTests.Test_AFailureIsReportedNotSwallowed;
var
   failing, good: TContestBase;
   capture: TCaptureAppender;
   keep: ILogAppender;
   lg: TLogLogger;
   savedLevel: TLogLevel;
   sent, failure, line: string;
   qso: ContestExchange;
begin
   BeginTest('Test_AFailureIsReportedNotSwallowed');
   qso := PinQso(0);
   qso.Callsign := 'W1AW';
   qso.Band := Band20;
   qso.Mode := CW;
   qso.tSysTime.qtYear := 26;
   qso.tSysTime.qtMonth := 1;
   qso.tSysTime.qtDay := 15;
   qso.tSysTime.qtHour := 12;
   qso.tSysTime.qtMinute := 1;

   capture := TCaptureAppender.Create('capture');
   keep := capture;
   lg := TLogLogger.GetLogger('uContestBase');
   savedLevel := lg.Level;
   lg.Level := Log4D.Error;
   lg.AddAppender(keep);
   failing := TFailingContest.Create(ContestHandleOf(CQWWRTTY));
   good := Make(CUPRFCW, PinStation(psUS, CUPRFCW));
   try
      CheckFalse(failing.TryFormatADIFSentExchange(PinMy(0), qso, sent, failure),
                 'a getter that raises is a reported failure');
      CheckEquals('', sent, 'and no text stands in for the exchange');
      CheckTrue(Pos('EConvertError', failure) > 0, 'the class is named: ' + failure);
      CheckTrue(Pos('injected failure', failure) > 0, 'the message is named: ' + failure);
      CheckEquals('', failing.FormatADIFSentExchange(PinMy(0), qso),
                  'FormatADIFSentExchange answers no text either');

      CheckTrue(capture.Lines.Count >= 1, 'an Error was written, not swallowed');
      line := capture.Lines.Text;
      CheckTrue(Pos('CQ-WW-RTTY', line) > 0, 'it names the contest: ' + line);
      CheckTrue(Pos('W1AW', line) > 0, 'it names the call: ' + line);
      CheckTrue(Pos('20m', line) > 0, 'it names the band: ' + line);
      CheckTrue(Pos('CW', line) > 0, 'it names the mode: ' + line);
      CheckTrue(Pos('2026-01-15 1201', line) > 0, 'it names the time: ' + line);
      CheckTrue(Pos('injected failure', line) > 0, 'it carries the reason: ' + line);

      capture.Lines.Clear;
      CheckTrue(good.TryFormatADIFSentExchange(PinMy(0), qso, sent, failure),
                'a contest that builds its string is not a failure');
      CheckEquals('007 FL     ', sent, 'and its text is the text');
      CheckEquals('', failure, 'with no reason');
      CheckEquals(0, capture.Lines.Count, 'and nothing is written');
   finally
      lg.RemoveAppender(keep);
      lg.Level := savedLevel;
      keep := nil;
      failing.Free;
      good.Free;
      end;
end;

(* F25: THE FIVE CONTESTS EXPORT WHAT THEIR CABRILLO SENT COLUMN PRINTS.
   Variant 2 is left out on purpose: the ADIF export cuts a state to the
   machine's twenty characters and the Cabrillo column does not, so the
   26-character state differs (the pinned literals above say how). *)
procedure TADIFSentExchangeTests.Test_TheFiveF25ContestsSendTheirCabrilloText;
const
   FIVE: array[0..4] of ContestType =
      (CUPRFCW, CUPRFSSB, CUPRFDIG, CQWWRTTY, YOUTHCHAMPIONSHIPRF);
var
   i, v: integer;
   obj: TContestBase;
   ctx: TCabrilloQSOContext;
   qso: ContestExchange;
begin
   BeginTest('Test_TheFiveF25ContestsSendTheirCabrilloText');
   for i := Low(FIVE) to High(FIVE) do
      begin
      obj := Make(FIVE[i], PinStation(psUS, FIVE[i]));
      try
         for v := 0 to 3 do
            begin
            if v <> 2 then
               begin
               qso := PinQso(v);
               ctx := Default(TCabrilloQSOContext);
               ctx.RSTSent := IntToStr(qso.RSTSent);
               CheckEquals(obj.FormatCabrilloSentExchange(PinMy(v), qso, ctx),
                           obj.FormatADIFSentExchange(PinMy(v), qso),
                           string(ContestTypeSA[FIVE[i]]) +
                           ': STX_STRING is the Cabrillo sent column, input ' +
                           IntToStr(v));
               end;
            end;
      finally
         obj.Free;
         end;
      end;
end;

procedure TADIFSentExchangeTests.RunAllTests;
begin
   Test_EveryContestSendsItsPinnedSTXString;
   Test_EachHelperPrintsItsLayout;
   Test_TheBaseStatesNoLayoutAndSaysSo;
   Test_AFailureIsReportedNotSwallowed;
   Test_TheFiveF25ContestsSendTheirCabrilloText;
end;

end.
