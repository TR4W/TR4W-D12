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

(* THE TWO CABRILLO EXCHANGE COLUMNS EVERY CONTEST WRITES, AT EVERY ROSTER
  STATION -- M11 S9c, 2026-10-14 (docs/CONTEST_FACTORY_M11_PLAN.md S9c).

  WHY IT EXISTS. S9c moves the fourth exchange-shape machine,
  uCabrilloExchange.FormatCabrilloExchangeOfKind (the `case` over the
  session's exchange shape that built the sent and received columns of a
  QSO: line), into the classes: each states its two columns by calling named
  helpers in uCabrilloExchange. The corpus sees thirteen contests' columns
  and the matrix a handful, so this pins ALL of them.

  HOW THE LITERALS WERE MADE. The OLD machine, run for every ContestType at
  the seven roster stations (uTestExchangeFields.TPinStation) with eight
  inputs, and the text it returned laid out below grouped by output (43
  groups; four move with the station). NOT from the new code: from the
  program as it stood before S9c, through the contest's
  FormatCabrilloSentExchange / FormatCabrilloReceivedExchange with the
  session's exchange in the context (uTestContestKindPin.Kinds). RUN GREEN
  AGAINST THE OLD CODE before anything moved, then the same tables green
  against the classes.

  THE EIGHT INPUTS (station, QSO and exporter context together):
    0  a full exchange     (FL, EL88AA, TOM, zone 5; his GA, BOB, serial 12)
    1  an empty one        (RST 59/58, serial 123 sent, nothing else)
    2  OVER-LONG values    (a 26-character state, a 10-character grid, long
                            names and a postal code; the first record)
    3  a state of TRC      (the one value two arms test)
    4  a contest title PGA (the other)
    5  negative serials    (-5 sent, -1 received; an all-digit state)
    6  no his-QTH selected (but a QTH on the QSO; no state; the first record)
    7  no QTH on the QSO   (but a DX QTH and a selected his-QTH)

  THE MARKER IS PART OF THE ORACLE. Fifteen registered contests (ALL JA,
  ARCI, County Hunter, FISTS, Grid Loc, JA Long Prefecture, Kids Day, NZ
  Field Day, POTA, QCWA, QCWA Golden, TEN-TEN, the UA4W Championship, WWL,
  Xmas) and the classless DUMMYCONTEST write CabrilloExchangeErrorMarker in
  both columns, because the machine never had an arm for their shape. They
  are pinned as they are.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's Cabrillo line changed. *)
unit uTestCabrilloColumns;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TCabrilloColumnsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestWritesItsPinnedColumns;
      procedure Test_EachHelperWritesItsColumn;
      procedure Test_TheBaseWritesTheMarker;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uCabrilloExchange,
   uTestContestObjects,
   uTestExchangeFields;

const
   VARIANTS = 8;

type
   TColumnHelper = function(const aMy: TMyStationExchange;
                            const aQso: ContestExchange;
                            const aCtx: TCabrilloQSOContext): string;

(* The eight inputs -- see the header. *)
function PinMy(aVariant: integer): TMyStationExchange;
begin
   Result := Default(TMyStationExchange);
   case aVariant of
      0, 4:
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
         Result.MyFOCNumber := '1234567890';
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
      5:
         begin
         Result.MyState := '99';
         Result.MyGrid := 'EL88AA';
         Result.MyName := 'TOM';
         Result.MyZone := '5';
         Result.MyFDClass := '1D';
         Result.MySection := 'WCF';
         Result.MyCheck := '84';
         Result.MyPrec := 'A';
         Result.MyFOCNumber := '1234';
         end;
      6:
         begin
         Result.MyZone := '9';
         Result.MyName := 'TOM';
         Result.MyGrid := 'EL88AA';
         Result.MyPostalCode := '33701';
         end;
      7:
         begin
         Result.MyState := 'FL';
         Result.MyZone := '5';
         Result.MyName := 'TOM';
         Result.MyGrid := 'EL88AA';
         end;
   end;
end;

function PinQso(aVariant: integer): ContestExchange;
begin
   FillChar(Result, SizeOf(ContestExchange), 0);
   Result.RSTSent := 599;
   Result.RSTReceived := 579;
   Result.NumberSent := 7;
   Result.NumberReceived := 12;
   Result.Zone := 14;
   Result.Age := 33;
   Result.Name := 'BOB';
   Result.QTHString := 'GA';
   Result.DXQTH := 'DL';
   Result.DomMultQTH := 'GA';
   Result.Power := '100';
   Result.ceClass := '2A';
   Result.Precedence := 'B';
   Result.Check := 77;
   case aVariant of
      1:
         begin
         Result.RSTSent := 59;
         Result.RSTReceived := 58;
         Result.NumberSent := 123;
         Result.NumberReceived := 0;
         Result.Zone := 0;
         Result.Age := 0;
         Result.Name := '';
         Result.QTHString := '';
         Result.DXQTH := '';
         Result.DomMultQTH := '';
         Result.Power := '';
         Result.ceClass := '';
         Result.Precedence := #0;
         Result.Check := 0;
         end;
      2:
         begin
         Result.NumberSent := 4567;
         Result.NumberReceived := 4567;
         Result.Zone := 40;
         Result.Age := 99;
         Result.Name := 'TOMASZ-THE';
         Result.QTHString := 'ABCDEFGHIJ';
         Result.DXQTH := 'ABCDEF';
         Result.Power := '123456';
         end;
      3:
         begin
         Result.QTHString := 'TRC';
         end;
      5:
         begin
         Result.NumberSent := -5;
         Result.NumberReceived := -1;
         end;
      6:
         begin
         Result.QTHString := 'XY';
         Result.DXQTH := 'ZZ';
         Result.DomMultQTH := '';
         end;
      7:
         begin
         Result.QTHString := '';
         Result.DXQTH := 'ZZ';
         Result.DomMultQTH := '';
         end;
   end;
end;

function PinCtx(aVariant: integer): TCabrilloQSOContext;
begin
   Result := Default(TCabrilloQSOContext);
   Result.RSTSent := '599';
   Result.RSTReceived := '579';
   Result.HisQTH := 'GA';
   Result.PreviousQTH := 'PQ12';
   Result.PreviousNumberReceived := 321;
   Result.RecordNumber := 2;
   Result.ContestTitle := '';
   case aVariant of
      1:
         begin
         Result.RSTSent := '59';
         Result.RSTReceived := '58';
         Result.HisQTH := '';
         Result.PreviousQTH := '';
         Result.PreviousNumberReceived := 0;
         end;
      2:
         begin
         Result.HisQTH := 'ABCDEFGHIJ';
         Result.PreviousQTH := 'ABCDEFGHIJ';
         Result.PreviousNumberReceived := 4567;
         Result.RecordNumber := 1;
         end;
      3:
         begin
         Result.HisQTH := 'TRC';
         end;
      4:
         begin
         Result.ContestTitle := 'PGA';
         end;
      5:
         begin
         Result.PreviousNumberReceived := -3;
         end;
      6:
         begin
         Result.HisQTH := '';
         Result.RecordNumber := 1;
         end;
      7:
         begin
         Result.HisQTH := 'GA';
         end;
   end;
end;

(* WHAT THE PROGRAM ANSWERS -- PostUnit asks the contest object that holds the
   station for the two columns. BEFORE THE MOVE the context carried the
   session's exchange, resolved the way start-up resolves it: the trait, and
   the contest's DescribeSession over it (uTestContestKindPin.Kinds) -- the
   run that made the literals. *)
procedure ProgramColumns(aContest: ContestType; const aStation: TStationContext;
                         aVariant: integer; out aSent, aRec: string);
var
   obj: TContestBase;
   ctx: TCabrilloQSOContext;
begin
   ctx := PinCtx(aVariant);
   obj := Make(aContest, aStation);
   try
      aSent := obj.FormatCabrilloSentExchange(PinMy(aVariant), PinQso(aVariant), ctx);
      aRec := obj.FormatCabrilloReceivedExchange(PinMy(aVariant), PinQso(aVariant), ctx);
   finally
      obj.Free;
      end;
end;

(* The eight literals of one group, by variant. *)
procedure Take(aVariant: integer; const aSents, aRecs: array of string;
               out aSent, aRec: string);
begin
   aSent := aSents[aVariant];
   aRec := aRecs[aVariant];
end;

(* THE PINNED COLUMNS, laid out from the old machine's output. *)
procedure PinnedColumns(aContest: ContestType; aStation: TPinStation;
                        aVariant: integer; out aSent, aRec: string);
begin
   aSent := '<not pinned>';
   aRec := '<not pinned>';
   case aContest of
      DUMMYCONTEST, ALLJA, ARCI, COUNTYHUNTER, FISTS, GRIDLOC, JALONGPREFECT,
      KIDSDAY, NZFIELDDAY, POTA, QCWA, QCWAGOLDEN, TENTEN, UA4WCHAMPIONSHIP, WWL,
      XMAS:
         begin
         Take(aVariant,
              ['ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED'],
              ['ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED',
               'ERROR EXCHANGE NOT HANDLED'],
              aSent, aRec);
         end;
      SEVENQP, ArizonaQsoParty, NEWENGLANDQSO, SALMONRUN, TEXASQSOPARTY:
         begin
         if aStation in [psUS, psVE, psDX, psPA, psKH6, psJA] then
            begin
            Take(aVariant,
                 ['599 FL     ',
                  '59  DX     ',
                  '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                  '599 TRC    ',
                  '599 FL     ',
                  '599 99     ',
                  '599 DX     ',
                  '599 FL     '],
                 ['579 GA     ',
                  '58  DX     ',
                  '579 ABCDEFGHIJ',
                  '579 TRC    ',
                  '579 GA     ',
                  '579 GA     ',
                  '579        ',
                  '579 DX     '],
                 aSent, aRec);
            end
         else
            begin
            Take(aVariant,
                 ['599 FL     ',
                  '59         ',
                  '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                  '599 TRC    ',
                  '599 FL     ',
                  '599 99     ',
                  '599        ',
                  '599 FL     '],
                 ['579 GA     ',
                  '58  DX     ',
                  '579 ABCDEFGHIJ',
                  '579 TRC    ',
                  '579 GA     ',
                  '579 GA     ',
                  '579        ',
                  '579 ZZ     '],
                 aSent, aRec);
            end;
         end;
      ALLASIANCW, ALLASIANSSB, YOTA:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59         ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599        ',
               '599 FL     '],
              ['579 33     ',
               '58  0      ',
               '579 99     ',
               '579 33     ',
               '579 33     ',
               '579 33     ',
               '579 33     ',
               '579 33     '],
              aSent, aRec);
         end;
      APSPRINT, BALTIC, CQM, CQWPXCW, CQWPXSSB, CQWPXRTTY, MARCONIMEMORIAL,
      MINITEST, MINI80, MINI40, OCEANIADXCW, OCEANIADXSSB, REGION1FIELDDAY,
      REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB, SACCW, YBDX, SACSSB, UCG,
      DARCWAEDCCW, DARCWAEDCSSB, SASPRINT, MWC:
         begin
         Take(aVariant,
              ['599 007 ',
               '59  123 ',
               '599 4567 ',
               '599 007 ',
               '599 007 ',
               '599 -05 ',
               '599 007 ',
               '599 007 '],
              ['579 012',
               '58  000',
               '579 4567',
               '579 012',
               '579 012',
               '579 4294967295',
               '579 012',
               '579 012'],
              aSent, aRec);
         end;
      ARI_DX, ARRL10, CIS, HADX, YUDX, HELVETIA, OKDX, CANADA_WINTER, RDA,
      RUSSIANDX, SPDX, UKRAINIAN, DARCXMAS, WAG, YODX, RU3AXMEMORIAL,
      ARKTIKA_SPRING, UNDX, KINGOFSPAINCW, KINGOFSPAINSSB, REFCW, REFSSB,
      CANADA_DAY, ARRL_RTTY_ROUNDUP, OKOMSSB:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59   0123   ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599  0007   ',
               '599 FL     '],
              ['579 GA ',
               '58  000',
               '579 ABCDEFGHIJ',
               '579 TRC',
               '579 GA ',
               '579 GA ',
               '579    ',
               '579 012'],
              aSent, aRec);
         end;
      ARRLDIGI, MAKROTHEN, BATAVIA_FT8:
         begin
         Take(aVariant,
              ['EL88AA     ',
               '           ',
               'EL88AA55JJ ',
               'EL88AA     ',
               'EL88AA     ',
               'EL88AA     ',
               'EL88AA     ',
               'EL88AA     '],
              ['GA         ',
               '           ',
               'ABCDEFGHIJ ',
               'TRC        ',
               'GA         ',
               'GA         ',
               '           ',
               'GA         '],
              aSent, aRec);
         end;
      ARRL160:
         begin
         if aStation in [psUS, psVE, psHost, psKH6] then
            begin
            Take(aVariant,
                 ['599 FL     ',
                  '59         ',
                  '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                  '599 TRC    ',
                  '599 FL     ',
                  '599 99     ',
                  '599        ',
                  '599 FL     '],
                 ['579 GA     ',
                  '58  DX     ',
                  '579 ABCDEFGHIJ',
                  '579 TRC    ',
                  '579 GA     ',
                  '579 GA     ',
                  '579        ',
                  '579 ZZ     '],
                 aSent, aRec);
            end
         else
            begin
            Take(aVariant,
                 ['599 FL     ',
                  '59  DX     ',
                  '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                  '599 TRC    ',
                  '599 FL     ',
                  '599 99     ',
                  '599 DX     ',
                  '599 FL     '],
                 ['579 GA     ',
                  '58  DX     ',
                  '579 ABCDEFGHIJ',
                  '579 TRC    ',
                  '579 GA     ',
                  '579 GA     ',
                  '579        ',
                  '579 DX     '],
                 aSent, aRec);
            end;
         end;
      ARRLDXCW, ARRLDXSSB, OLDNEWYEAR:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59         ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599        ',
               '599 FL     '],
              ['579 100    ',
               '58         ',
               '579 123456 ',
               '579 100    ',
               '579 100    ',
               '579 100    ',
               '579 100    ',
               '579 100    '],
              aSent, aRec);
         end;
      ARRLSSCW, ARRLSSSSB:
         begin
         Take(aVariant,
              ['7    A 84 WCF ',
               '123        ',
               '4567 A 84 WCF ',
               '7          ',
               '7    A 84 WCF ',
               '-5   A 84 WCF ',
               '7          ',
               '7          '],
              ['12   B 77 GA ',
               '0      00    ',
               '4567 B 77 ABCDEFGHIJ',
               '12   B 77 TRC',
               '12   B 77 GA ',
               '0    B 77 GA ',
               '12   B 77    ',
               '12   B 77 GA '],
              aSent, aRec);
         end;
      ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, CQVHF, STEWPERRY:
         begin
         Take(aVariant,
              ['599 EL88AA ',
               '59         ',
               '599 EL88AA55JJ',
               '599 EL88AA ',
               '599 EL88AA ',
               '599 EL88AA ',
               '599 EL88AA ',
               '599 EL88AA '],
              ['579 GA     ',
               '58         ',
               '579 ABCDEFGHIJ',
               '579 TRC    ',
               '579 GA     ',
               '579 GA     ',
               '579        ',
               '579 GA     '],
              aSent, aRec);
         end;
      BWQP, GENERALQSO:
         begin
         Take(aVariant,
              ['599 TOM   FL     ',
               '59               ',
               '599 TOMASZ-THE-VERY-LONG-NAME ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TOM   TRC    ',
               '599 TOM   FL     ',
               '599 TOM   99     ',
               '599 TOM          ',
               '599 TOM   FL     '],
              ['579 BOB   GA     ',
               '58               ',
               '579 TOMASZ-THE ABCDEFGHIJ',
               '579 BOB   TRC    ',
               '579 BOB   GA     ',
               '579 BOB   GA     ',
               '579 BOB          ',
               '579 BOB   GA     '],
              aSent, aRec);
         end;
      CALQSOPARTY:
         begin
         Take(aVariant,
              ['7    FL    ',
               '123        ',
               '4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '7    TRC   ',
               '7    FL    ',
               '-5   99    ',
               '7          ',
               '7    FL    '],
              ['0012 GA    ',
               '0000 DX    ',
               '4567 ABCDEFGHIJ',
               '0012 TRC   ',
               '0012 GA    ',
               '4294967295 GA    ',
               '0012 DX    ',
               '0012 DX    '],
              aSent, aRec);
         end;
      CQ160CW, CQ160SSB, CROATIAN, GAGARINCUP, IARU, KCJ, LZDX, OZCR_O, OZCR_Z,
      WWPMC, WRTC, BSCI, IRTS, EUDX:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59  0      ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599 9      ',
               '599 FL     '],
              ['579 GA     ',
               '58  0      ',
               '579 ABCDEFGHIJ',
               '579 TRC    ',
               '579 GA     ',
               '579 GA     ',
               '579        ',
               '579 14     '],
              aSent, aRec);
         end;
      CQWWCW, CQWWSSB, EUROPEANHFC, GACWWWSACW, JTDX, KVP, WWIH:
         begin
         Take(aVariant,
              ['599 05     ',
               '59  00     ',
               '599 12     ',
               '599 05     ',
               '599 05     ',
               '599 05     ',
               '599 09     ',
               '599 05     '],
              ['579 14     ',
               '58  00     ',
               '579 40     ',
               '579 14     ',
               '579 14     ',
               '579 14     ',
               '579 14     ',
               '579 14     '],
              aSent, aRec);
         end;
      CUPRFCW, CUPRFSSB, CUPRFDIG:
         begin
         Take(aVariant,
              ['007 FL     ',
               '123        ',
               '4567 ABCD   ',
               '007 TRC    ',
               '007 FL     ',
               '-05 99     ',
               '007        ',
               '007 FL     '],
              ['0012 GA    ',
               '0000       ',
               '4567 ABCDEFGHIJ',
               '0012 TRC   ',
               '0012 GA    ',
               '4294967295 GA    ',
               '0012       ',
               '0012 GA    '],
              aSent, aRec);
         end;
      CUPURAL, UKRAINECHAMPIONSHIP:
         begin
         Take(aVariant,
              ['FL   0007  ',
               '     0123  ',
               'ABCDEFGHIJKLMNOPQRSTUVWXYZ 4567  ',
               'TRC  0007  ',
               'FL   0007  ',
               '99   -0005 ',
               '     0007  ',
               'FL   0007  '],
              ['GA   0012  ',
               '     0000  ',
               'ABCDEFGHIJ 4567  ',
               'TRC  0012  ',
               'GA   0012  ',
               'GA   4294967295',
               '     0012  ',
               'GA   0012  '],
              aSent, aRec);
         end;
      EUSPRINT_SPRING_CW, CWOPEN, EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW,
      EUSPRINT_AUTUMN_SSB, MST:
         begin
         Take(aVariant,
              ['7   TOM    ',
               '123        ',
               '4567 TOMASZ-THE-VERY-LONG-NAME',
               '7   TOM    ',
               '7   TOM    ',
               '-5  TOM    ',
               '7   TOM    ',
               '7   TOM    '],
              ['12  BOB    ',
               '0          ',
               '4567 TOMASZ-THE',
               '12  BOB    ',
               '12  BOB    ',
               '4294967295 BOB    ',
               '12  BOB    ',
               '12  BOB    '],
              aSent, aRec);
         end;
      EUROPEANVHF, TESLA, RADIOVHFFD, OZHCRVHF, RTC:
         begin
         Take(aVariant,
              ['599 0007 EL88AA ',
               '59  0123        ',
               '599 4567 EL88AA55JJ',
               '599 0007 EL88AA ',
               '599 0007 EL88AA ',
               '599 -0005 EL88AA ',
               '599 0007 EL88AA ',
               '599 0007 EL88AA '],
              ['579 0012 GA     ',
               '58  0000        ',
               '579 4567 ABCDEFGHIJ',
               '579 0012 TRC    ',
               '579 0012 GA     ',
               '579 4294967295 GA     ',
               '579 0012        ',
               '579 0012 GA     '],
              aSent, aRec);
         end;
      ARRLFIELDDAY, WINTERFIELDDAY:
         begin
         Take(aVariant,
              ['1D  WCF     ',
               '            ',
               '1D  WCF     ',
               '            ',
               '1D  WCF     ',
               '1D  WCF     ',
               '            ',
               '            '],
              ['2A  GA     ',
               '           ',
               '2A  ABCDEFGHIJ',
               '2A  TRC    ',
               '2A  GA     ',
               '2A  GA     ',
               '2A  XY     ',
               '2A         '],
              aSent, aRec);
         end;
      FOCMARATHON:
         begin
         Take(aVariant,
              ['599 1234   ',
               '59         ',
               '599 1234567890',
               '599        ',
               '599 1234   ',
               '599 1234   ',
               '599        ',
               '599        '],
              ['579 100    ',
               '58         ',
               '579 123456 ',
               '579 100    ',
               '579 100    ',
               '579 100    ',
               '579 100    ',
               '579 100    '],
              aSent, aRec);
         end;
      FLORIDAQSOPARTY:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59         ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599        ',
               '599 FL     '],
              ['579 GA     ',
               '58  DX     ',
               '579 ABCDEFGHIJ',
               '579 TRC    ',
               '579 GA     ',
               '579 GA     ',
               '579        ',
               '579        '],
              aSent, aRec);
         end;
      UKEI:
         begin
         Take(aVariant,
              ['599 0007     FL      ',
               '59  0123             ',
               '599 4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ      ',
               '599 7TRC   ',
               '599 007FL     ',
               '599 -0005     99      ',
               '599 0007             ',
               '599 0007     FL      '],
              ['579 0012   GA',
               '58  0000   --',
               '579 4567 ABCDEFGHIJ',
               '579   12TRC     ',
               '579  012GA',
               '579 -0001   GA',
               '579 0012     ',
               '579 0012   --'],
              aSent, aRec);
         end;
      INTERNETSPRINT, NASPRINTCW, SPRINTSSB, NASPRINTRTTY, NCCCSPRINT:
         begin
         Take(aVariant,
              ['7    TOM     FL      ',
               '123          DX      ',
               '4567 TOMASZ-THE-VERY-LONG-NAME ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '7    TOM     TRC     ',
               '7    TOM     FL      ',
               '-5   TOM     99      ',
               '7    TOM     DX      ',
               '7    TOM     FL      '],
              ['12   BOB   GA  ',
               '0          DX  ',
               '4567 TOMASZ-THE ABCDEFGHIJ',
               '12   BOB   TRC ',
               '12   BOB   GA  ',
               '4294967295 BOB   GA  ',
               '12   BOB       ',
               '12   BOB   DX  '],
              aSent, aRec);
         end;
      IOTA:
         begin
         Take(aVariant,
              ['599 0007     FL      ',
               '59  0123             ',
               '599 4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ      ',
               '599 7TRC   ',
               '599 007FL     ',
               '599 -0005     99      ',
               '599 0007             ',
               '599 0007     FL      '],
              ['579 0012   GA',
               '58  0000 ------',
               '579 4567 ABCDEFGHIJ',
               '579   12TRC     ',
               '579  012GA',
               '579 -0001   GA',
               '579 0012 ------',
               '579 0012   GA'],
              aSent, aRec);
         end;
      JIDXCW, JIDXSSB:
         begin
         if aStation in [psUS, psVE, psDX, psHost, psPA, psKH6] then
            begin
            Take(aVariant,
                 ['599 5      ',
                  '59  0      ',
                  '599 12     ',
                  '599 5      ',
                  '599 5      ',
                  '599 5      ',
                  '599 9      ',
                  '599 5      '],
                 ['579 GA     ',
                  '58         ',
                  '579 ABCDEFGHIJ',
                  '579 TRC    ',
                  '579 GA     ',
                  '579 GA     ',
                  '579        ',
                  '579 GA     '],
                 aSent, aRec);
            end
         else
            begin
            Take(aVariant,
                 ['599 05     ',
                  '59  00     ',
                  '599 12     ',
                  '599 05     ',
                  '599 05     ',
                  '599 05     ',
                  '599 09     ',
                  '599 05     '],
                 ['579 14     ',
                  '58  00     ',
                  '579 40     ',
                  '579 14     ',
                  '579 14     ',
                  '579 14     ',
                  '579 14     ',
                  '579 14     '],
                 aSent, aRec);
            end;
         end;
      LABRE, IDAHOQSOPARTY, DELAWAREQSOPARTY:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59         ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599        ',
               '599 FL     '],
              ['579 GA     ',
               '58  DX     ',
               '579 ABCDEFGHIJ',
               '579 TRC    ',
               '579 GA     ',
               '579 GA     ',
               '579        ',
               '579 ZZ     '],
              aSent, aRec);
         end;
      MICHQSOPARTY, MOQSOPARTY, NCQSOPARTY, TOEC, WISCONSINQSOPARTY, NYQP,
      TENNESSEEQSOPARTY, ALRS_UA1DZ_CUP, INQSOPARTY, BCQP, IN7QPNE:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59  DX     ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599 DX     ',
               '599 FL     '],
              ['579 GA     ',
               '58  DX     ',
               '579 ABCDEFGHIJ',
               '579 TRC    ',
               '579 GA     ',
               '579 GA     ',
               '579        ',
               '579 DX     '],
              aSent, aRec);
         end;
      MINNQSOPARTY, NAQSOCW, NAQSOSSB, NAQSORTTY, LQP, COLORADOQSOPARTY, CWOPS, SST:
         begin
         Take(aVariant,
              ['  TOM        FL  ',
               '                 ',
               '  TOMASZ-THE-VERY-LONG-NAME ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '  TOM        TRC ',
               '  TOM        FL  ',
               '  TOM        99  ',
               '  TOM            ',
               '  TOM        FL  '],
              ['  BOB        GA  ',
               '                 ',
               '  TOMASZ-THE ABCDEFGHIJ',
               '  BOB        TRC ',
               '  BOB        GA  ',
               '  BOB        GA  ',
               '  BOB            ',
               '  BOB        GA  '],
              aSent, aRec);
         end;
      NRAUBALTICCW, NRAUBALTICSSB, OHIOQSOPARTY, RSGB18, UBACW, UBASSB, CQIR:
         begin
         Take(aVariant,
              ['599 0007     FL      ',
               '59  0123             ',
               '599 4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ      ',
               '599 7TRC   ',
               '599 007FL     ',
               '599 -0005     99      ',
               '599 0007             ',
               '599 0007     FL      '],
              ['579 0012   GA',
               '58  0000     ',
               '579 4567 ABCDEFGHIJ',
               '579   12TRC     ',
               '579  012GA',
               '579 -0001   GA',
               '579 0012     ',
               '579 0012   GA'],
              aSent, aRec);
         end;
      PACC:
         begin
         if aStation in [psUS, psVE, psDX, psHost, psKH6, psJA] then
            begin
            Take(aVariant,
                 ['599 7      ',
                  '59  123    ',
                  '599 4567   ',
                  '599 7      ',
                  '599 7      ',
                  '599 -5     ',
                  '599 7      ',
                  '599 7      '],
                 ['579 GA     ',
                  '58  DX     ',
                  '579 ABCDEFGHIJ',
                  '579 TRC    ',
                  '579 GA     ',
                  '579 GA     ',
                  '579        ',
                  '579 DX     '],
                 aSent, aRec);
            end
         else
            begin
            Take(aVariant,
                 ['599 7      ',
                  '59  123    ',
                  '599 4567   ',
                  '599 7      ',
                  '599 7      ',
                  '599 -5     ',
                  '599 7      ',
                  '599 7      '],
                 ['579 GA ',
                  '58  000',
                  '579 ABCDEFGHIJ',
                  '579 TRC',
                  '579 GA ',
                  '579 GA ',
                  '579    ',
                  '579 012'],
                 aSent, aRec);
            end;
         end;
      RAEM:
         begin
         Take(aVariant,
              ['0007 FL      ',
               '0123         ',
               '4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ ',
               '0007 TRC     ',
               '0007 FL      ',
               '-0005 99      ',
               '0007         ',
               '0007 FL      '],
              ['0012 GA     ',
               '0000        ',
               '4567 ABCDEFGHIJ',
               '0012 TRC    ',
               '0012 GA     ',
               '4294967295 GA     ',
               '0012        ',
               '0012 GA     '],
              aSent, aRec);
         end;
      RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, R9W_UW9WK_MEMORIAL:
         begin
         Take(aVariant,
              ['  FL    0007 ',
               '      0123 ',
               '  ABCDEFGHIJKLMNOPQRSTUVWXYZ    4567 ',
               '  TRC    0007 ',
               '  FL    0007 ',
               '  99    -0005 ',
               '      0007 ',
               '  FL    0007 '],
              ['  14     012',
               '  0      000',
               '  40     4567',
               '  14     012',
               '  14     012',
               '  14     -001',
               '  14     012',
               '  14     012'],
              aSent, aRec);
         end;
      RFASCHAMPIONSHIPCW:
         begin
         Take(aVariant,
              ['FL  0007    ',
               '    0123    ',
               'ABCDEFGHIJKLMNOPQRSTUVWXYZ 4567    ',
               'TRC 0007    ',
               'FL  0007    ',
               '99  -0005    ',
               '    0007    ',
               'FL  0007    '],
              ['GA  0012',
               '    0000',
               'ABCDEFGHIJ 4567',
               'TRC 0012',
               'GA  0012',
               'GA  4294967295',
               '    0012',
               'GA  0012'],
              aSent, aRec);
         end;
      RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB:
         begin
         Take(aVariant,
              ['599 PQ12      ',
               '59            ',
               '599 AB12CD34EF56GH78IJ90KL',
               '599 PQ12      ',
               '599 PQ12      ',
               '599 PQ12      ',
               '599 33701     ',
               '599 PQ12      '],
              ['579 GA        ',
               '58            ',
               '579 ABCDEFGHIJ',
               '579 TRC       ',
               '579 GA        ',
               '579 GA        ',
               '579 XY        ',
               '579           '],
              aSent, aRec);
         end;
      SOUTHAMERICANWW, CQMM:
         begin
         Take(aVariant,
              ['599 FL     ',
               '59         ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC    ',
               '599 FL     ',
               '599 99     ',
               '599        ',
               '599 FL     '],
              ['579 GA     ',
               '58         ',
               '579 ABCDEFGHIJ',
               '579 TRC    ',
               '579 GA     ',
               '579 GA     ',
               '579 XY     ',
               '579        '],
              aSent, aRec);
         end;
      YOUTHCHAMPIONSHIPRF:
         begin
         Take(aVariant,
              ['FL 007 ',
               '   123 ',
               'ABCDEFGHIJKLMNOPQRSTUVWXYZ 4567 ',
               'TRC 007 ',
               'FL 007 ',
               '99 -05 ',
               '   007 ',
               'FL 007 '],
              [' 33  0012',
               ' 0   0000',
               ' 99  4567',
               ' 33  0012',
               ' 33  0012',
               ' 33  -001',
               ' 33  0012',
               ' 33  0012'],
              aSent, aRec);
         end;
      PCC:
         begin
         Take(aVariant,
              ['599  0007   ',
               '59   0123   ',
               '599  4567   ',
               '599  0007   ',
               '599  0007   ',
               '599  4294967291/M   ',
               '599  0007   ',
               '599  0007   '],
              ['579 GA ',
               '58  000',
               '579 ABCDEFGHIJ',
               '579 TRC',
               '579 GA ',
               '579 GA ',
               '579    ',
               '579 012'],
              aSent, aRec);
         end;
      RADIOMEMORY:
         begin
         Take(aVariant,
              ['599 FL              ',
               '59                  ',
               '599 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 TRC             ',
               '599 FL              ',
               '599 99              ',
               '599                 ',
               '599 FL              '],
              ['579 33 GA',
               '58  0 ',
               '579 99 ABCDEFGHIJ',
               '579 33 TRC',
               '579 33 GA',
               '579 33 GA',
               '579 33 ',
               '579 33 GA'],
              aSent, aRec);
         end;
      DARC10M:
         begin
         Take(aVariant,
              ['599 0007     FL      ',
               '59  0123             ',
               '599 4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ      ',
               '599 7TRC   ',
               '599 007FL     ',
               '599 -0005     99      ',
               '599 0007             ',
               '599 0007     FL      '],
              ['579 0012  GA',
               '58  0000    ',
               '579 4567 ABCDEFGHIJ',
               '579 0012 TRC',
               '579 0012  GA',
               '579 -0001  GA',
               '579 0012    ',
               '579 0012  GA'],
              aSent, aRec);
         end;
      CQWWRTTY:
         begin
         Take(aVariant,
              ['599 05 FL  ',
               '59  00 DX  ',
               '599 12 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '599 05 TRC ',
               '599 05 FL  ',
               '599 05 99  ',
               '599 09 DX  ',
               '599 05 FL  '],
              ['579 14 GA ',
               '58  00 DX ',
               '579 40 ABCDEFGHIJ',
               '579 14 TRC',
               '579 14 GA ',
               '579 14 GA ',
               '579 14    ',
               '579 14 DX '],
              aSent, aRec);
         end;
      RADIOYOC:
         begin
         Take(aVariant,
              ['3210007   ',
               '0000123   ',
               '45674567   ',
               '3210007   ',
               '3210007   ',
               '4294967293-0005  ',
               '3210007   ',
               '3210007   '],
              ['00000012',
               '00000000',
               '00040567',
               '00000012',
               '00000012',
               '0000-0001',
               '00000012',
               '00000012'],
              aSent, aRec);
         end;
      PAQSOPARTY, VAQP:
         begin
         Take(aVariant,
              ['7    FL    ',
               '123        ',
               '4567 ABCDEFGHIJKLMNOPQRSTUVWXYZ',
               '7    TRC   ',
               '7    FL    ',
               '-5   99    ',
               '7          ',
               '7    FL    '],
              ['0012 GA    ',
               '0000       ',
               '4567 ABCDEFGHIJ',
               '0012 TRC   ',
               '0012 GA    ',
               '4294967295 GA    ',
               '0012       ',
               '0012 GA    '],
              aSent, aRec);
         end;
      WWDIGI:
         begin
         Take(aVariant,
              ['EL88AA     ',
               '           ',
               'EL88AA55JJ ',
               'EL88AA     ',
               'EL88AA     ',
               'EL88AA     ',
               'EL88AA     ',
               'EL88AA     '],
              ['GA         ',
               '           ',
               'ABCDEFGHIJ ',
               'TRC        ',
               'GA         ',
               'GA         ',
               'XY         ',
               '           '],
              aSent, aRec);
         end;
   end;
end;

procedure TCabrilloColumnsTests.Test_EveryContestWritesItsPinnedColumns;
var
   s: TPinStation;
   c: ContestType;
   v: integer;
   checked: integer;
   wantSent, wantRec, gotSent, gotRec: string;
begin
   BeginTest('Test_EveryContestWritesItsPinnedColumns');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         for v := 0 to VARIANTS - 1 do
            begin
            PinnedColumns(c, s, v, wantSent, wantRec);
            ProgramColumns(c, PinStation(s, c), v, gotSent, gotRec);
            CheckEquals(wantSent, gotSent,
                        string(ContestTypeSA[c]) + ' at ' + PinStationCall(s) +
                        ', input ' + IntToStr(v) + ': sent column');
            CheckEquals(wantRec, gotRec,
                        string(ContestTypeSA[c]) + ' at ' + PinStationCall(s) +
                        ', input ' + IntToStr(v) + ': received column');
            Inc(checked);
            end;
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) * VARIANTS, checked,
               'contest x station x input column pairs pinned');
end;

(* EVERY HELPER, BY NAME -- its column at the eight inputs, against the
   literals of a contest that calls it (taken from the table above, so the
   helper and the pin cannot drift apart). *)
procedure TCabrilloColumnsTests.Test_EachHelperWritesItsColumn;

   procedure CheckHelper(const aName: string; aHelper: TColumnHelper;
                         aContest: ContestType; aStation: TPinStation; aSentColumn: boolean);
   var
      v: integer;
      wantSent, wantRec, want: string;
   begin
      for v := 0 to VARIANTS - 1 do
         begin
         PinnedColumns(aContest, aStation, v, wantSent, wantRec);
         if aSentColumn then
            begin
            want := wantSent;
            end
         else
            begin
            want := wantRec;
            end;
         CheckEquals(want, aHelper(PinMy(v), PinQso(v), PinCtx(v)),
                     aName + ', input ' + IntToStr(v));
         end;
   end;

begin
   BeginTest('Test_EachHelperWritesItsColumn');
   CheckHelper('CabrilloSentGrid', CabrilloSentGrid, ARRLDIGI, psUS, True);
   CheckHelper('CabrilloSentRSTNameState', CabrilloSentRSTNameState, BWQP, psUS, True);
   CheckHelper('CabrilloSentQSONumberName', CabrilloSentQSONumberName, CWOPEN, psUS, True);
   CheckHelper('CabrilloSentRSTPostalCode', CabrilloSentRSTPostalCode, RSGB_ROPOCO_CW, psUS, True);
   CheckHelper('CabrilloSentRSTQSONumberGrid', CabrilloSentRSTQSONumberGrid, EUROPEANVHF, psUS, True);
   CheckHelper('CabrilloSentRSTZoneNumber', CabrilloSentRSTZoneNumber, JIDXCW, psUS, True);
   CheckHelper('CabrilloSentNameState', CabrilloSentNameState, NAQSOCW, psUS, True);
   CheckHelper('CabrilloSentQSONumberNameStateDX', CabrilloSentQSONumberNameStateDX, INTERNETSPRINT, psUS, True);
   CheckHelper('CabrilloSentRSTStateWide', CabrilloSentRSTStateWide, RADIOMEMORY, psUS, True);
   CheckHelper('CabrilloSentRSTState', CabrilloSentRSTState, ALLASIANCW, psUS, True);
   CheckHelper('CabrilloSentRSTStateOrDX', CabrilloSentRSTStateOrDX, MICHQSOPARTY, psUS, True);
   CheckHelper('CabrilloSentRSTGrid', CabrilloSentRSTGrid, ARRLVHFJAN, psUS, True);
   CheckHelper('CabrilloSentStateQSONumber2', CabrilloSentStateQSONumber2, YOUTHCHAMPIONSHIPRF, psUS, True);
   CheckHelper('CabrilloSentQSONumberStateShort', CabrilloSentQSONumberStateShort, CUPRFCW, psUS, True);
   CheckHelper('CabrilloSentQSONumberState', CabrilloSentQSONumberState, PAQSOPARTY, psUS, True);
   CheckHelper('CabrilloSentStateQSONumber', CabrilloSentStateQSONumber, CUPURAL, psUS, True);
   CheckHelper('CabrilloSentRSTQSONumberState', CabrilloSentRSTQSONumberState, UBACW, psUS, True);
   CheckHelper('CabrilloSentRSTZoneStateDX', CabrilloSentRSTZoneStateDX, CQWWRTTY, psUS, True);
   CheckHelper('CabrilloSentRSTStateOrZone', CabrilloSentRSTStateOrZone, CQ160CW, psUS, True);
   CheckHelper('CabrilloSentStateQSONumberSum', CabrilloSentStateQSONumberSum, RFASCHAMPIONSHIPCW, psUS, True);
   CheckHelper('CabrilloSentQSONumberGeoState', CabrilloSentQSONumberGeoState, RAEM, psUS, True);
   CheckHelper('CabrilloSentRSTQSONumber', CabrilloSentRSTQSONumber, APSPRINT, psUS, True);
   CheckHelper('CabrilloSentStateZoneQSONumber', CabrilloSentStateZoneQSONumber, RFCHAMPIONSHIPCW, psUS, True);
   CheckHelper('CabrilloSentRSTZone', CabrilloSentRSTZone, EUROPEANHFC, psUS, True);
   CheckHelper('CabrilloSentQSONumberPreviousQSONumber', CabrilloSentQSONumberPreviousQSONumber, RADIOYOC, psUS, True);
   CheckHelper('CabrilloSentRSTStateOrQSONumber', CabrilloSentRSTStateOrQSONumber, ARI_DX, psUS, True);
   CheckHelper('CabrilloSentNotHandled', CabrilloSentNotHandled, ALLJA, psUS, True);

   CheckHelper('CabrilloReceivedGrid', CabrilloReceivedGrid, ARRLDIGI, psUS, False);
   CheckHelper('CabrilloReceivedRSTNameQTH', CabrilloReceivedRSTNameQTH, BWQP, psUS, False);
   CheckHelper('CabrilloReceivedQSONumberName', CabrilloReceivedQSONumberName, CWOPEN, psUS, False);
   CheckHelper('CabrilloReceivedRSTPostalCode', CabrilloReceivedRSTPostalCode, RSGB_ROPOCO_CW, psUS, False);
   CheckHelper('CabrilloReceivedRSTQSONumberGrid', CabrilloReceivedRSTQSONumberGrid, EUROPEANVHF, psUS, False);
   CheckHelper('CabrilloReceivedRSTQTH', CabrilloReceivedRSTQTH, ARRLVHFJAN, psUS, False);
   CheckHelper('CabrilloReceivedNameQTH', CabrilloReceivedNameQTH, NAQSOCW, psUS, False);
   CheckHelper('CabrilloReceivedQSONumberNameQTHDX', CabrilloReceivedQSONumberNameQTHDX, INTERNETSPRINT, psUS, False);
   CheckHelper('CabrilloReceivedRSTAgeQTH', CabrilloReceivedRSTAgeQTH, RADIOMEMORY, psUS, False);
   CheckHelper('CabrilloReceivedRSTAge', CabrilloReceivedRSTAge, ALLASIANCW, psUS, False);
   CheckHelper('CabrilloReceivedAgeQSONumber', CabrilloReceivedAgeQSONumber, YOUTHCHAMPIONSHIPRF, psUS, False);
   CheckHelper('CabrilloReceivedRSTPower', CabrilloReceivedRSTPower, OLDNEWYEAR, psUS, False);
   CheckHelper('CabrilloReceivedQSONumberQTHShort', CabrilloReceivedQSONumberQTHShort, CUPRFCW, psUS, False);
   CheckHelper('CabrilloReceivedQSONumberQTH', CabrilloReceivedQSONumberQTH, PAQSOPARTY, psUS, False);
   CheckHelper('CabrilloReceivedQTHQSONumber', CabrilloReceivedQTHQSONumber, CUPURAL, psUS, False);
   CheckHelper('CabrilloReceivedRSTQSONumberQTH', CabrilloReceivedRSTQSONumberQTH, UBACW, psUS, False);
   CheckHelper('CabrilloReceivedRSTZoneQTHDX', CabrilloReceivedRSTZoneQTHDX, CQWWRTTY, psUS, False);
   CheckHelper('CabrilloReceivedRSTQTHOrZone', CabrilloReceivedRSTQTHOrZone, CQ160CW, psUS, False);
   CheckHelper('CabrilloReceivedQTHQSONumberSum', CabrilloReceivedQTHQSONumberSum, RFASCHAMPIONSHIPCW, psUS, False);
   CheckHelper('CabrilloReceivedQSONumberGeoQTH', CabrilloReceivedQSONumberGeoQTH, RAEM, psUS, False);
   CheckHelper('CabrilloReceivedRSTQSONumber', CabrilloReceivedRSTQSONumber, APSPRINT, psUS, False);
   CheckHelper('CabrilloReceivedRSTContinent', CabrilloReceivedRSTContinent, CQMM, psUS, False);
   CheckHelper('CabrilloReceivedRSTQTHDX', CabrilloReceivedRSTQTHDX, MICHQSOPARTY, psUS, False);
   CheckHelper('CabrilloReceivedRSTQTHOrDXQTH', CabrilloReceivedRSTQTHOrDXQTH, LABRE, psUS, False);
   CheckHelper('CabrilloReceivedZoneQSONumber', CabrilloReceivedZoneQSONumber, RFCHAMPIONSHIPCW, psUS, False);
   CheckHelper('CabrilloReceivedRSTZone', CabrilloReceivedRSTZone, EUROPEANHFC, psUS, False);
   CheckHelper('CabrilloReceivedQSONumberPreviousQSONumber', CabrilloReceivedQSONumberPreviousQSONumber, RADIOYOC, psUS, False);
   CheckHelper('CabrilloReceivedRSTQTHOrQSONumber', CabrilloReceivedRSTQTHOrQSONumber, ARI_DX, psUS, False);
   CheckHelper('CabrilloReceivedNotHandled', CabrilloReceivedNotHandled, ALLJA, psUS, False);
end;

(* A CONTEST THAT STATES NOTHING WRITES THE MARKER IN BOTH COLUMNS -- the base,
   which the classless DUMMYCONTEST runs. *)
procedure TCabrilloColumnsTests.Test_TheBaseWritesTheMarker;
var
   obj: TContestBase;
   v: integer;
begin
   BeginTest('Test_TheBaseWritesTheMarker');
   obj := TContestBase.Create(DUMMYCONTEST);
   try
      for v := 0 to VARIANTS - 1 do
         begin
         CheckEquals(CabrilloExchangeErrorMarker,
                     obj.FormatCabrilloSentExchange(PinMy(v), PinQso(v), PinCtx(v)),
                     'the base, sent, input ' + IntToStr(v));
         CheckEquals(CabrilloExchangeErrorMarker,
                     obj.FormatCabrilloReceivedExchange(PinMy(v), PinQso(v), PinCtx(v)),
                     'the base, received, input ' + IntToStr(v));
         end;
   finally
      obj.Free;
      end;
end;

procedure TCabrilloColumnsTests.RunAllTests;
begin
   Test_EveryContestWritesItsPinnedColumns;
   Test_EachHelperWritesItsColumn;
   Test_TheBaseWritesTheMarker;
end;

end.
