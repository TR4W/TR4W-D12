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

  THE MARKER IS PART OF THE ORACLE. Five contests send ADIFMyExchangeErrorMarker
  as STX_STRING today (plan F25), as does the classless DUMMYCONTEST: three
  layouts were never built and the machine's own try/except swallowed the
  failure. They are pinned as they are.

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
      procedure Test_TheBaseSendsTheMarker;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uADIFExchange,
   uTestContestObjects,
   uTestExchangeFields;

type
   TADIFSentHelper = function(const aMy: TMyStationExchange;
                              const aQso: ContestExchange): string;

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
      prefecture -- the one pair whose STX_STRING moves with the station. *)
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

   case aContest of
      DUMMYCONTEST, CUPRFCW, CUPRFSSB, CUPRFDIG, YOUTHCHAMPIONSHIPRF, CQWWRTTY:
         begin
         Result := Pick(aVariant, ADIFMyExchangeErrorMarker,
                     ADIFMyExchangeErrorMarker,
                     ADIFMyExchangeErrorMarker,
                     ADIFMyExchangeErrorMarker);
         end;
      SEVENQP, ALLASIANCW, ALLASIANSSB, ARRL160, ArizonaQsoParty, LABRE, MICHQSOPARTY,
      MOQSOPARTY, NEWENGLANDQSO, NCQSOPARTY, OLDNEWYEAR, SALMONRUN, SOUTHAMERICANWW,
      TEXASQSOPARTY, TOEC, WISCONSINQSOPARTY, NYQP, TENNESSEEQSOPARTY, CQMM, ALRS_UA1DZ_CUP,
      INQSOPARTY, BCQP, YOTA, IN7QPNE, IDAHOQSOPARTY, DELAWAREQSOPARTY:
         begin
         Result := Pick(aVariant, '599 FL     ',
                     '59         ',
                     '599 ABCDEFGHIJKLMNOPQRST',
                     '599 TRC    ');
         end;
      ALLJA, ARCI, COUNTYHUNTER, FISTS, GRIDLOC, JALONGPREFECT, KIDSDAY, NZFIELDDAY, QCWA,
      QCWAGOLDEN, TENTEN, UA4WCHAMPIONSHIP, WWL, XMAS:
         begin
         Result := Pick(aVariant, 'None',
                     'None',
                     'None',
                     'None');
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
         Result := Pick(aVariant, '599 7      ',
                     '59  123    ',
                     '599 4567   ',
                     '599 7      ');
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
         Result := Pick(aVariant, '000007    ',
                     '000123    ',
                     '0004567   ',
                     '000007    ');
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
   CheckHelper('ADIFSentNotImplemented', ADIFSentNotImplemented,
               'None',
               'None',
               'None',
               'None');
   CheckHelper('ADIFSentNotBuilt', ADIFSentNotBuilt,
               ADIFMyExchangeErrorMarker,
               ADIFMyExchangeErrorMarker,
               ADIFMyExchangeErrorMarker,
               ADIFMyExchangeErrorMarker);
end;

(* A CONTEST THAT STATES NOTHING PRINTS THE MARKER -- the base, which the
   classless DUMMYCONTEST runs. *)
procedure TADIFSentExchangeTests.Test_TheBaseSendsTheMarker;
var
   obj: TContestBase;
   v: integer;
begin
   BeginTest('Test_TheBaseSendsTheMarker');
   obj := TContestBase.Create(DUMMYCONTEST);
   try
      for v := 0 to 3 do
         begin
         CheckEquals(ADIFMyExchangeErrorMarker,
                     obj.FormatADIFSentExchange(PinMy(v), PinQso(v)),
                     'the base, input ' + IntToStr(v));
         end;
   finally
      obj.Free;
      end;
end;

procedure TADIFSentExchangeTests.RunAllTests;
begin
   Test_EveryContestSendsItsPinnedSTXString;
   Test_EachHelperPrintsItsLayout;
   Test_TheBaseSendsTheMarker;
end;

end.
