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

(* THE LAST THREE READERS OF THE SESSION'S EXCHANGE KIND OUTSIDE THE INITIAL
  EXCHANGE, AT EVERY ROSTER STATION -- M11 S9e part 1, 2026-10-15
  (docs/CONTEST_FACTORY_M11_PLAN.md S9e part 1).

  WHAT MOVED. Three engine sites asked `ContestSession.Exchange`:
  - MainUnit.SetColumnsWidth: the log's Precedence and Check columns, for the
    Sweepstakes shape (plan F15/F15a). They ask the contest's received-field
    list now (uExchangeFields.ExchangeFieldsShowPrecedenceColumn /
    ...ShowCheckColumn).
  - FCONTEST.FoundContest's closing `case`: which default CW exchange
    messages set-up writes (plan F30). Each contest calls the engine's
    writer for its set by name (TContestBase.WriteDefaultExchangeMessages,
    on a TExchangeMessageWriters).
  - TREE.LooksLikeAGrid: whether a word may be a grid square at all (S9f,
    uGridShape.GRID_CARRYING_EXCHANGES). The contest answers
    ExchangeTextMayHoldGridSquare.

  HOW THE LITERALS WERE MADE. The OLD tests, frozen below (LegacyMessages,
  LegacyColumns, LegacyGrid), run over every ContestType at the seven roster
  stations on the session shape uTestContestKindPin.Kinds resolves -- the
  trait and DescribeSession over it, exactly what set-up wrote -- dumped to a
  file and laid out grouped by answer. RUN GREEN AGAINST THE OLD CODE (the
  program's answer then WAS the frozen test), then the move, then the same
  tables green against the classes.

  THE CROSS-CHECKS STAY UNTIL S9e part 2 DELETES THE KIND: every ContestType
  at every roster station, the class's answer against the frozen test.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest's columns, messages or grid reading changed. *)
unit uTestExchangeKindReaders;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TExchangeKindReadersTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestShowsItsPinnedColumns;
      procedure Test_EveryContestWritesItsPinnedExchangeMessages;
      procedure Test_EveryContestStatesItsPinnedGridReading;
      procedure Test_AnswersAgreeWithTheSessionShape;
      procedure Test_TheGridReadingDependsOnNoStation;
   end;

implementation

uses
   SysUtils,
   VC,
   uContestBase,
   uContestRegistry,
   uExchangeFields,
   uTestContestObjects,
   uTestContestKindPin,
   uTestExchangeFields;

function Who(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + PinStationCall(aStation);
end;

(* ---------------------------------------------------------------------
   THE OLD TESTS, FROZEN.
   --------------------------------------------------------------------- *)

(* MainUnit.SetColumnsWidth, both columns: `ContestSession.Exchange =
   QSONumberPrecedenceCheckDomesticQTHExchange`. *)
function LegacyColumns(aContest: ContestType; const aStation: TStationContext): boolean;
begin
   Result := Kinds(aContest, aStation).Exchange = QSONumberPrecedenceCheckDomesticQTHExchange;
end;

(* FCONTEST.FoundContest's closing `case`, arm for arm, as the name of the
   set it wrote: '' for none. The JIDX's zone-message refusal was its
   DescribeSession's SuppressZoneExchangeMessages, stated unconditionally by
   both runnings; the state after the zone, the contest's
   SendsStateAfterZone. *)
function LegacyMessages(aContest: ContestType; const aStation: TStationContext): string;
var
   suppressed: boolean;
   suffix: string;
begin
   suppressed := aContest in [JIDXCW, JIDXSSB];
   if ContestIdentity(aContest).SendsStateAfterZone then
      begin
      suffix := '+state';
      end
   else
      begin
      suffix := '';
      end;
   Result := '';
   case Kinds(aContest, aStation).Exchange of
      NameAndDomesticOrDXQTHExchange:
         begin
         Result := 'NameAndState';
         end;
      RSTQSONumberExchange:
         begin
         Result := 'RSTQSONumber';
         end;
      RSTDomesticQTHExchange,
      RSTAndContinentExchange,
      RSTAndQSONumberOrFrenchDepartmentExchange,
      RSTAndQSONumberOrDomesticQTHExchange,
      RSTDomesticQTHOrQSONumberExchange:
         begin
         Result := 'RSTStateOrQSONumber';
         end;
      RSTZoneAndPossibleDomesticQTHExchange, RSTZoneExchange:
         begin
         if not suppressed then
            begin
            Result := 'RSTZone' + suffix;
            end;
         end;
      RSTZoneOrSocietyExchange:
         begin
         Result := 'RSTStateOrZone' + suffix;
         end;
   end;
end;

(* TREE.LooksLikeAGrid's first question, and the set it asked about --
   uGridShape.GRID_CARRYING_EXCHANGES as it stood, deleted from the program
   at M11 S9e part 1. *)
const
   GRID_CARRYING_EXCHANGES = [RSTAndOrGridExchange,
                              Grid2Exchange,
                              RSTAndGrid3Exchange,
                              GridExchange,
                              RSTQSONumberAndGridSquareExchange,
                              RSTNameAndQTHExchange,
                              RSTAndPOTAPark,
                              RSTAndGridExchange];

function LegacyGrid(aContest: ContestType; const aStation: TStationContext): boolean;
begin
   Result := Kinds(aContest, aStation).Exchange in GRID_CARRYING_EXCHANGES;
end;

(* ---------------------------------------------------------------------
   WHAT THE PROGRAM ANSWERS. BEFORE THE MOVE each was the frozen test above
   -- the run that made the literals; the old bodies are quoted in each
   comment.
   --------------------------------------------------------------------- *)

(* WHAT THE ENGINE'S WRITERS WERE ASKED FOR, as the name of the set -- a
   stand-in for FCONTEST's TEngineExchangeMessageWriters, whose bodies are
   the old arms (the matrix's memory lines are their oracle). Several calls
   would be joined with ',': none writes more than one. *)
type
   TRecordingMessageWriters = class(TExchangeMessageWriters)
   public
      Text: string;
      procedure Note(const aSet: string);
      procedure WriteNameAndState; override;
      procedure WriteRSTQSONumber; override;
      procedure WriteRSTStateOrQSONumber; override;
      procedure WriteRSTZone(aStateAfterZone: boolean); override;
      procedure WriteRSTStateOrZone(aStateAfterZone: boolean); override;
   end;

procedure TRecordingMessageWriters.Note(const aSet: string);
begin
   if Text <> '' then
      begin
      Text := Text + ',';
      end;
   Text := Text + aSet;
end;

procedure TRecordingMessageWriters.WriteNameAndState;
begin
   Note('NameAndState');
end;

procedure TRecordingMessageWriters.WriteRSTQSONumber;
begin
   Note('RSTQSONumber');
end;

procedure TRecordingMessageWriters.WriteRSTStateOrQSONumber;
begin
   Note('RSTStateOrQSONumber');
end;

procedure TRecordingMessageWriters.WriteRSTZone(aStateAfterZone: boolean);
begin
   if aStateAfterZone then
      begin
      Note('RSTZone+state');
      end
   else
      begin
      Note('RSTZone');
      end;
end;

procedure TRecordingMessageWriters.WriteRSTStateOrZone(aStateAfterZone: boolean);
begin
   if aStateAfterZone then
      begin
      Note('RSTStateOrZone+state');
      end
   else
      begin
      Note('RSTStateOrZone');
      end;
end;

(* What start-up assigns to LOGDUPE.ExchangeInformation -- the active
   contest's field list -- through what MainUnit.SetColumnsWidth asks of it.
   OLD: LegacyColumns. *)
function ProgramFields(aContest: ContestType; const aStation: TStationContext): ExchangeInformationRecord;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      Result := ContestReceivedExchangeFields(obj);
   finally
      obj.Free;
      end;
end;

function ProgramPrecedenceColumn(aContest: ContestType; const aStation: TStationContext): boolean;
begin
   Result := ExchangeFieldsShowPrecedenceColumn(ProgramFields(aContest, aStation));
end;

function ProgramCheckColumn(aContest: ContestType; const aStation: TStationContext): boolean;
begin
   Result := ExchangeFieldsShowCheckColumn(ProgramFields(aContest, aStation));
end;

(* What FoundContest hands the ACTIVE contest at its foot, through the
   nil-safe ContestSetUpDefaultExchangeMessages. OLD: LegacyMessages. *)
function ProgramMessages(aContest: ContestType; const aStation: TStationContext): string;
var
   obj: TContestBase;
   writers: TRecordingMessageWriters;
begin
   obj := MakeContestOrNil(aContest, aStation);
   writers := TRecordingMessageWriters.Create;
   try
      ContestSetUpDefaultExchangeMessages(obj, writers);
      Result := writers.Text;
   finally
      writers.Free;
      obj.Free;
      end;
end;

(* What TREE.LooksLikeAGrid asks: the contest's IDENTITY, which has no
   station -- so aStation is not used, and Test_TheGridReadingDependsOnNoStation
   is what makes that safe. OLD: LegacyGrid. *)
function ProgramGrid(aContest: ContestType; const aStation: TStationContext): boolean;
begin
   Result := ContestIdentity(aContest).ExchangeTextMayHoldGridSquare;
end;

(* ---------------------------------------------------------------------
   THE PINNED ANSWERS.
   --------------------------------------------------------------------- *)

(* The Sweepstakes pair, at every station; no other contest shows either. *)
function PinnedColumns(aContest: ContestType): boolean;
begin
   Result := aContest in [ARRLSSCW, ARRLSSSSB];
end;

function PinnedMessages(aContest: ContestType; aStation: TPinStation): string;
begin
   (* ARRL 160: an entrant in an ARRL section country (W, VE, KH6) receives
      its section or DX and gets none; anyone else the state-or-serial. *)
   if aContest = ARRL160 then
      begin
      if aStation in [psDX, psPA, psJA] then
         begin
         Result := 'RSTStateOrQSONumber';
         end
      else
         begin
         Result := '';
         end;
      Exit;
      end;

   (* THE ARRL DX: a W or VE entrant sends power and gets none; anyone else
      (KH6 included) the state-or-serial. *)
   if aContest in [ARRLDXCW, ARRLDXSSB] then
      begin
      if aStation in [psUS, psVE, psHost] then
         begin
         Result := '';
         end
      else
         begin
         Result := 'RSTStateOrQSONumber';
         end;
      Exit;
      end;

   (* FIVE PARTIES: inside the host state none; outside it the
      state-or-serial. *)
   if aContest in [SEVENQP, ArizonaQsoParty, NEWENGLANDQSO, SALMONRUN,
                   TEXASQSOPARTY] then
      begin
      if aStation = psHost then
         begin
         Result := '';
         end
      else
         begin
         Result := 'RSTStateOrQSONumber';
         end;
      Exit;
      end;

   (* EVERY OTHER CONTEST, the same at every station. The JIDX writes none
      at either of its shapes: a Japanese entrant's zone messages were
      refused, anyone else's prefecture shape had no arm. *)
   case aContest of
      MINNQSOPARTY, NAQSOCW, NAQSOSSB, NAQSORTTY, LQP, COLORADOQSOPARTY,
      CWOPS, SST:
         begin
         Result := 'NameAndState';
         end;
      APSPRINT, BALTIC, CQM, CQWPXCW, CQWPXSSB, CQWPXRTTY, MARCONIMEMORIAL,
      MINITEST, MINI80, MINI40, OCEANIADXCW, OCEANIADXSSB, REGION1FIELDDAY,
      REGION1FIELDDAY_RCC_CW, REGION1FIELDDAY_RCC_SSB, SACCW, YBDX, SACSSB,
      UCG, DARCWAEDCCW, DARCWAEDCSSB, SASPRINT, MWC:
         begin
         Result := 'RSTQSONumber';
         end;
      ARI_DX, ARRL10, CIS, HADX, YUDX, HELVETIA, MICHQSOPARTY, MOQSOPARTY,
      NCQSOPARTY, OKDX, PACC, CANADA_WINTER, RDA, RUSSIANDX,
      SOUTHAMERICANWW, SPDX, TOEC, UKRAINIAN, DARCXMAS, WAG,
      WISCONSINQSOPARTY, YODX, RU3AXMEMORIAL, ARKTIKA_SPRING, UNDX, NYQP,
      KINGOFSPAINCW, KINGOFSPAINSSB, TENNESSEEQSOPARTY, PCC, REFCW, REFSSB,
      CQMM, CANADA_DAY, ARRL_RTTY_ROUNDUP, ALRS_UA1DZ_CUP, INQSOPARTY,
      OKOMSSB, BCQP, IN7QPNE:
         begin
         Result := 'RSTStateOrQSONumber';
         end;
      IARU, OZCR_O, OZCR_Z, WWPMC, WRTC, BSCI:
         begin
         Result := 'RSTStateOrZone';
         end;
      CQWWCW, CQWWSSB, EUROPEANHFC, GACWWWSACW, JTDX, KVP, WWIH:
         begin
         Result := 'RSTZone';
         end;
      CQWWRTTY:
         begin
         Result := 'RSTZone+state';
         end;
   else
      begin
      Result := '';
      end;
   end;
end;

(* The 18 contests whose exchange word may be a grid, at every station. *)
function PinnedGrid(aContest: ContestType): boolean;
begin
   Result := aContest in [ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, BWQP,
                          CQVHF, EUROPEANVHF, TESLA, GENERALQSO, POTA,
                          RADIOVHFFD, STEWPERRY, WWL, OZHCRVHF, MAKROTHEN,
                          BATAVIA_FT8, WWDIGI, RTC];
end;

(* ---------------------------------------------------------------------
   THE TESTS.
   --------------------------------------------------------------------- *)

procedure TExchangeKindReadersTests.Test_EveryContestShowsItsPinnedColumns;
var
   c: ContestType;
   s: TPinStation;
   station: TStationContext;
   shown: integer;
begin
   BeginTest('Test_EveryContestShowsItsPinnedColumns');
   shown := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         CheckTrue(PinnedColumns(c) = ProgramPrecedenceColumn(c, station),
                     Who(c, s) + ' Precedence column');
         CheckTrue(PinnedColumns(c) = ProgramCheckColumn(c, station),
                     Who(c, s) + ' Check column');
         if ProgramCheckColumn(c, station) then
            begin
            Inc(shown);
            end;
         end;
      end;
   (* Two contests at seven stations. *)
   CheckEquals(14, shown, 'contest x station pairs showing the Sweepstakes columns');
end;

procedure TExchangeKindReadersTests.Test_EveryContestWritesItsPinnedExchangeMessages;
var
   c: ContestType;
   s: TPinStation;
   writing: integer;
   checked: integer;
begin
   BeginTest('Test_EveryContestWritesItsPinnedExchangeMessages');
   writing := 0;
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         CheckEquals(PinnedMessages(c, s), ProgramMessages(c, PinStation(s, c)),
                     Who(c, s) + ' default exchange messages');
         Inc(checked);
         end;
      if PinnedMessages(c, psDX) <> '' then
         begin
         Inc(writing);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station message sets pinned');
   (* 93 contests write a set at some station, and every one of them writes
      it at the German station -- the station-dependent ones included. *)
   CheckEquals(93, writing, 'contests writing a set at the DX station');
end;

procedure TExchangeKindReadersTests.Test_EveryContestStatesItsPinnedGridReading;
var
   c: ContestType;
   s: TPinStation;
   reading: integer;
begin
   BeginTest('Test_EveryContestStatesItsPinnedGridReading');
   reading := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         CheckTrue(PinnedGrid(c) = ProgramGrid(c, PinStation(s, c)),
                     Who(c, s) + ' exchange word may be a grid');
         end;
      if PinnedGrid(c) then
         begin
         Inc(reading);
         end;
      end;
   CheckEquals(18, reading, 'contests whose exchange word may be a grid');
end;

(* THE CROSS-CHECKS: the program's answers against the frozen tests on the
   session shape, for every ContestType at every roster station. Until S9e
   part 2 deletes the shape. *)
procedure TExchangeKindReadersTests.Test_AnswersAgreeWithTheSessionShape;
var
   c: ContestType;
   s: TPinStation;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_AnswersAgreeWithTheSessionShape');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         CheckTrue(LegacyColumns(c, station) = ProgramPrecedenceColumn(c, station),
                     Who(c, s) + ' Precedence column as the shape showed it');
         CheckTrue(LegacyColumns(c, station) = ProgramCheckColumn(c, station),
                     Who(c, s) + ' Check column as the shape showed it');
         CheckEquals(LegacyMessages(c, station), ProgramMessages(c, station),
                     Who(c, s) + ' messages as the shape chose them');
         CheckTrue(LegacyGrid(c, station) = ProgramGrid(c, station),
                     Who(c, s) + ' grid reading as the shape allowed it');
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station answers compared');
end;

(* LooksLikeAGrid asks the contest's identity, not ActiveContest: safe only
   while no contest answers it from Station. Every ContestType at every
   roster station, the station-bearing object (what ActiveContest would
   hand) against the identity. *)
procedure TExchangeKindReadersTests.Test_TheGridReadingDependsOnNoStation;
var
   c: ContestType;
   s: TPinStation;
   obj: TContestBase;
   checked: integer;
begin
   BeginTest('Test_TheGridReadingDependsOnNoStation');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         obj := MakeContestOrNil(c, PinStation(s, c));
         try
            CheckTrue(ContestExchangeTextMayHoldGridSquare(obj) =
                      ContestIdentity(c).ExchangeTextMayHoldGridSquare,
                      Who(c, s) + ' grid reading is the identity''s');
         finally
            obj.Free;
            end;
         Inc(checked);
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1), checked,
               'contest x station grid readings compared with the identity');
end;

procedure TExchangeKindReadersTests.RunAllTests;
begin
   Test_EveryContestShowsItsPinnedColumns;
   Test_EveryContestWritesItsPinnedExchangeMessages;
   Test_EveryContestStatesItsPinnedGridReading;
   Test_AnswersAgreeWithTheSessionShape;
   Test_TheGridReadingDependsOnNoStation;
end;

end.
