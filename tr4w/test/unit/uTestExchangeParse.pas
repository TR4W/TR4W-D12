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

(* HOW EVERY CONTEST PARSES A TYPED EXCHANGE, AT EVERY ROSTER STATION --
  M11 S9d, 2026-10-15 (docs/CONTEST_FACTORY_M11_PLAN.md S9d).

  WHY IT EXISTS. S9d moves the last exchange-shape machine,
  LOGSTUFF.ParseExchangeShape (the `case` over the session's exchange shape
  that chose the engine's parser for a typed exchange), into the classes:
  each states the parser it calls. The contest matrix's parse section runs
  the REAL parsers for every contest at three stations; this pins what the
  classes decide -- which parser, and every rule around it -- for every
  ContestType at the seven roster stations (uTestExchangeFields.TPinStation).

  THE ENGINE'S PARSERS ARE A STUB HERE, and that is the point. They read the
  engine's tables (the domestic QTH table, CTY.DAT) and cannot link into this
  binary. The stub records WHICH parser was asked and does something
  deterministic with the text (PinBehaviour): it accepts unless the text is
  empty or holds a '!', puts the last word in the QTH, the word count in the
  received number and a five-letter last word in the domestic QTH. What a
  class does around it -- refuse first, refuse after, choose another parser,
  fill a zone, copy a QTH -- shows in the outcome.

  THE BATTERY: eleven texts x six worked stations (sixty-six rows), each
  parsed afresh. The texts: empty, RST and serial, a lone serial, a lone
  word, RST and state, a whole Sweepstakes exchange, the same in swapped
  order, RST and a county key, garbage, an over-long exchange, a lone RST.
  The worked stations: W1AW, a VE0, a PY, a UA live and not live, a G.

  HOW THE LITERALS WERE MADE. The program as it stood before S9d -- each
  contest's ParseReceivedExchange handed the session's exchange
  (uTestContestKindPin.Kinds) and a stub of ParseExchangeShape that named
  the parser its arm called (LegacyHelper below) -- run for every row, and
  each row's outcome matched against the codes below. PinnedHelper is the
  parser a plain exchange reaches; PinnedCodes says, row by row, what the
  class did with it. RUN GREEN AGAINST THE OLD CODE before anything moved,
  then the same tables green against the classes.

  NEVER REGENERATE IT TO CLEAR A FAILURE -- the uTestContestKindPin rule. A
  failure means a contest parses differently. *)
unit uTestExchangeParse;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TExchangeParseTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryContestParsesItsPinnedOutcomes;
      procedure Test_PinnedHelperIsTheSessionShapes;
      procedure Test_EveryContestStatesWhatItsExchangeCarries;
      procedure Test_CarriesAgreeWithTheSessionShape;
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   Classes,
   SysUtils,
   VC,
   uContestBase,
   uContestIN7QPNE,
   uAppStrings,
   uTR4WStrings,
   uTestContestObjects,
   uTestContestKindPin,
   uTestExchangeFields,
   uTestExchangeParserStub;

const
   TEXTS = 11;
   CALLS = 6;
   ROWS = TEXTS * CALLS;

   BATTERY_TEXT: array[0..TEXTS - 1] of string = (
      '',
      '599 123',
      '123',
      'ARRL',
      '599 CT',
      '123 A 99 CT',
      'CT 99 A 123',
      '599 INMAR',
      '!!! ###',
      '599 123 ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ CT',
      '599'
   );

type
   TWorkedRow = record
      Call: string;
      Country: string;
      Live: boolean;
   end;

const
   BATTERY_CALL: array[0..CALLS - 1] of TWorkedRow = (
      (Call: 'W1AW';   Country: 'K';  Live: True),
      (Call: 'VE0ABC'; Country: 'VE'; Live: True),
      (Call: 'PY2ABC'; Country: 'PY'; Live: True),
      (Call: 'UA3ABC'; Country: 'UA'; Live: True),
      (Call: 'UA3ABC'; Country: 'UA'; Live: False),
      (Call: 'G3ABC';  Country: 'G';  Live: True)
   );

   (* The stub's domestic QTH table. *)
   DOMESTIC_KEYS = ',CT,INMAR,';

(* ---------------------------------------------------------------------------
   THE STUBBED ENGINE
   --------------------------------------------------------------------------- *)

var
   GTrace: string;
   GRowText: string;
   GZoneAsked: string;
   GAbandoned: integer;

(* The stub's parse, given the parser asked for -- see the header. *)
function PinBehaviour(const aHelper: string; const aText: string;
                      var aExch: ContestExchange): boolean;
var
   words: TStringList;
   last: string;
begin
   if GTrace <> '' then
      begin
      GTrace := GTrace + '+';
      end;
   GTrace := GTrace + aHelper;
   if aText <> GRowText then
      begin
      GTrace := GTrace + '<' + aText + '>';
      end;

   words := TStringList.Create;
   try
      words.Delimiter := ' ';
      words.StrictDelimiter := True;
      words.DelimitedText := Trim(aText);
      last := '';
      if words.Count > 0 then
         begin
         last := words[words.Count - 1];
         end;
      aExch.NumberReceived := words.Count;
      (* The cast is the stub's word going into the width the record holds. *)
      aExch.QTHString := ShortString(last);
      if Length(last) = 5 then
         begin
         aExch.DomesticQTH := ShortString(last);
         end;
   finally
      words.Free;
   end;
   Result := (aText <> '') and (Pos('!', aText) = 0);
end;

function PinZoneOfCall(const aCall: string): Byte;
begin
   GZoneAsked := aCall;
   Result := 8;
end;

function PinIsDomesticQTH(const aQTH: string): boolean;
begin
   Result := Pos(',' + UpperCase(aQTH) + ',', DOMESTIC_KEYS) > 0;
end;

procedure PinAbandonEntry;
begin
   inc(GAbandoned);
end;

(* THE PARSER THE OLD MACHINE'S ARM CALLED, by the helper name S9d gave it --
  LOGSTUFF.ParseExchangeShape frozen, arm for arm. '' for a shape with no arm,
  which called nothing and answered False. The five unreached arms are named
  for completeness; RSTAndFOCNumberExchange's arm called the power parser. *)
function LegacyHelper(aShape: ExchangeType): string;
begin
   case aShape of
      AgeAndQSONumberExchange: Result := 'ParseAgeAndQSONumber';
      QSONumberAndAgeExchange: Result := 'ParseQSONumberAndAge';
      CheckAndChapterOrQTHExchange: Result := 'ParseCheckAndChapterOrQTH';
      ClassDomesticOrDXQTHExchange: Result := 'ParseClassDomesticOrDXQTH';
      KidsDayExchange: Result := 'ParseKidsDay';
      NameAndDomesticOrDXQTHExchange: Result := 'ParseNameAndDomesticOrDXQTH';
      NameQTHAndPossibleTenTenNumber: Result := 'ParseNameQTHAndPossibleTenTenNumber';
      NameAndPossibleGridSquareExchange: Result := 'ParseNameAndPossibleGridSquare';
      NZFieldDayExchange: Result := 'ParseNZFieldDay';
      GridExchange: Result := 'ParseGrid';
      Grid2Exchange: Result := 'ParseGrid2';
      RSTAndGrid3Exchange: Result := 'ParseRSTAndGrid3';
      QSONumberAndPreviousQSONumber: Result := 'ParseQSONumberAndPreviousQSONumber';
      QSONumberAndGeoCoordinates: Result := 'ParseQSONumberAndGeoCoordinates';
      QSONumberAndCoordinatesSum: Result := 'ParseQSONumberAndCoordinatesSum';
      QSONumberAndZone: Result := 'ParseQSONumberAndZone';
      QSONumberAndNameExchange: Result := 'ParseQSONumberAndName';
      QSONumberAndGridSquare: Result := 'ParseQSONumberAndGridSquare';
      QSONumberAndPossibleDomesticQTHExchange: Result := 'ParseQSONumberAndPossibleDomesticQTH';
      QSONumberDomesticOrDXQTHExchange: Result := 'ParseQSONumberDomesticOrDXQTH';
      QSONumberDomesticQTHExchange: Result := 'ParseQSONumberDomesticQTH';
      QSONumberNameChapterAndQTHExchange: Result := 'ParseQSONumberNameChapterAndQTH';
      QSONumberNameDomesticOrDXQTHExchange: Result := 'ParseQSONumberNameDomesticOrDXQTH';
      QSONumberPrecedenceCheckDomesticQTHExchange: Result := 'ParseQSONumberPrecedenceCheckDomesticQTH';
      RSTAgeExchange: Result := 'ParseRSTAge';
      RSTALLJAPrefectureAndPrecedenceExchange: Result := 'ParseRSTALLJAPrefectureAndPrecedence';
      RSTAndContinentExchange: Result := 'ParseRSTAndContinent';
      RSTAndFOCNumberExchange: Result := 'ParseRSTPower';
      RSTAndGridExchange: Result := 'ParseRSTAndGrid';
      RSTAndOrGridExchange: Result := 'ParseRSTAndOrGrid';
      RSTAndPOTAPark: Result := 'ParseRSTAndPOTAPark';
      RSTAndQSONumberOrDomesticQTHExchange: Result := 'ParseRSTAndQSONumberOrDomesticQTH';
      RSTAndPostalCodeExchange: Result := 'ParseRSTAndPostalCode';
      RSTDomesticOrDXQTHExchange: Result := 'ParseRSTDomesticOrDXQTH';
      RSTDomesticQTHExchange: Result := 'ParseRSTDomesticQTH';
      RSTDomesticQTHOrQSONumberExchange: Result := 'ParseRSTDomesticQTHOrQSONumber';
      RSTNameAndQTHExchange: Result := 'ParseRSTNameAndQTH';
      RSTPossibleDomesticQTHAndPower: Result := 'ParseRSTPossibleDomesticQTHAndPower';
      RSTPowerExchange: Result := 'ParseRSTPower';
      RSTPrefectureExchange: Result := 'ParseRSTPrefecture';
      RSTQSONumberExchange: Result := 'ParseRSTQSONumber';
      RSTQSONumberAndDomesticQTHExchange: Result := 'ParseRSTQSONumberAndDomesticQTH';
      RSTQSONumberAndGridSquareExchange: Result := 'ParseRSTQSONumberAndGridSquare';
      RSTQSONumberAndPossibleDomesticQTHExchange: Result := 'ParseRSTQSONumberAndPossibleDomesticQTH';
      RSTQSONumberAndRandomCharactersExchange: Result := 'ParseRSTQSONumberAndRandomCharacters';
      RSTQSONumberOrDomesticQTHExchange: Result := 'ParseRSTQSONumberOrDomesticQTH';
      RSTQTHNameAndFistsNumberOrPowerExchange: Result := 'ParseRSTQTHNameAndFistsNumberOrPower';
      RSTQTHExchange: Result := 'ParseRSTQTH';
      RSTZoneAndPossibleDomesticQTHExchange: Result := 'ParseRSTZoneAndPossibleDomesticQTH';
      RSTZoneExchange: Result := 'ParseRSTZone';
      RSTZoneOrSocietyExchange: Result := 'ParseRSTZoneOrSociety';
      RSTLongJAPrefectureExchange: Result := 'ParseRSTLongJAPrefecture';
      RSTAgeAndPossibleSK: Result := 'ParseRSTAgeAndPossibleSK';
      RSTZoneOrDomesticQTH: Result := 'ParseRSTZoneOrDomesticQTH';
      RSTAndQSONumberOrFrenchDepartmentExchange: Result := 'ParseRSTAndQSONumberOrFrenchDepartment';
      RSTAndGridSquareOrRDAExchange: Result := 'ParseRSTAndGridSquareOrRDA';
   else
      begin
      (* No arm: UnknownExchange, NoExchangeReceived, RSTAndDOMESTICQTH,
         RSTAndSerialNumberAndGridandPossibleMemberNumber,
         RSTNameAndPossibleFOCNumber. *)
      Result := '';
      end;
   end;
end;

(* ---------------------------------------------------------------------------
   THE SEAM -- the one routine that knows how the engine hands a contest its
   parsers, and the only one that changed between the old run and the new.

   Before S9d it read:
      session.Exchange := Kinds(aContest, aStation).Exchange;
      session.ParseShape := @OldStubParseShape;
   where OldStubParseShape answered PinBehaviour(LegacyHelper(aShape), ...),
   or False, naming nothing, for a shape with no arm.
   --------------------------------------------------------------------------- *)

function ProgramParse(aContestObject: TContestBase; aContest: ContestType;
                      const aStation: TStationContext; aLive: boolean;
                      const aText: string; var aExch: ContestExchange;
                      out aMessage: string): boolean;
var
   session: TReceivedExchangeSession;
begin
   session.Parsers := StubExchangeParsers(@PinBehaviour);
   session.ExchangeFormatOf := nil;
   session.ZoneOfCall := @PinZoneOfCall;
   session.IsDomesticQTH := @PinIsDomesticQTH;
   session.CallWindowHasCall := aLive;
   session.AbandonEntry := @PinAbandonEntry;
   Result := aContestObject.ParseReceivedExchange(aText, session, aExch, aMessage);
end;

(* ---------------------------------------------------------------------------
   ONE ROW, AND WHAT IT LOOKS LIKE
   --------------------------------------------------------------------------- *)

function RowExchange(aRow: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.Callsign := ShortString(BATTERY_CALL[aRow mod CALLS].Call);
   Result.QTH.CountryID := ShortString(BATTERY_CALL[aRow mod CALLS].Country);
   Result.Zone := DUMMYZONE;
end;

function RowText(aRow: integer): string;
begin
   Result := BATTERY_TEXT[aRow div CALLS];
end;

function OutcomeText(aOk: boolean; const aMessage: string;
                     const aExch: ContestExchange): string;
begin
   Result := 'trace=' + GTrace +
             ' ok=' + BoolToStr(aOk, 'T', 'F') +
             ' msg=' + aMessage +
             ' qth=' + string(aExch.QTHString) +
             ' dom=' + string(aExch.DomesticQTH) +
             ' zone=' + IntToStr(aExch.Zone) +
             ' nr=' + IntToStr(aExch.NumberReceived) +
             ' zask=' + GZoneAsked +
             ' ab=' + IntToStr(GAbandoned);
end;

procedure ResetRow(aRow: integer);
begin
   GTrace := '';
   GRowText := RowText(aRow);
   GZoneAsked := '';
   GAbandoned := 0;
end;

(* What the program does with row aRow. *)
function ActualOutcome(aContestObject: TContestBase; aContest: ContestType;
                       const aStation: TStationContext; aRow: integer): string;
var
   exch: ContestExchange;
   msg: string;
   ok: boolean;
begin
   ResetRow(aRow);
   exch := RowExchange(aRow);
   msg := '';
   ok := ProgramParse(aContestObject, aContest, aStation,
                      BATTERY_CALL[aRow mod CALLS].Live, RowText(aRow), exch, msg);
   Result := OutcomeText(ok, msg, exch);
end;

(* ---------------------------------------------------------------------------
   THE CODES -- what a class did with a row, one character each
   --------------------------------------------------------------------------- *)

const
   (* Every code, in the order a row is matched against them. *)
   ALL_CODES = '.-qdnouazc2rie';

(* What code aCode says the program did with row aRow, given the parser a
   plain exchange reaches (aHelper) and the contest's host state.

     .  the plain parse: aHelper, its answer, nothing added
     -  nothing parsed: refused, no message
     q  the plain parse through ParseRSTQSONumber instead
     d  the plain parse through ParseRSTDomesticQTH instead
     n  the plain parse, and a missing precedence named (Sweepstakes)
     o  the plain parse accepted, then refused out of state (a state party)
     u  nothing parsed: refused with TC_INVALID (UK/EI)
     a  nothing parsed: the live entry abandoned (SAC)
     z  the plain parse, and the zone filled from the call (IARU)
     c  the plain parse, and the QTH copied to the domestic QTH (UA4W)
     2  the plain parse twice: the composite's, then its party's (IN7QPNE)
     r  the composite's parse, then refused: no party (IN7QPNE)
     i  both parses, then Indiana's out-of-state refusal (IN7QPNE)
     e  both parses, then Delaware's out-of-state refusal (IN7QPNE) *)
function ExpectedOutcome(aCode: char; const aHelper: string;
                         const aHostState: string; aRow: integer): string;
var
   exch: ContestExchange;
   ok: boolean;
   msg: string;
   call: string;
begin
   ResetRow(aRow);
   exch := RowExchange(aRow);
   call := BATTERY_CALL[aRow mod CALLS].Call;
   ok := False;
   msg := '';
   case aCode of
      '.':
         begin
         ok := PinBehaviour(aHelper, RowText(aRow), exch);
         end;
      '-':
         begin
         end;
      'q':
         begin
         ok := PinBehaviour('ParseRSTQSONumber', RowText(aRow), exch);
         end;
      'd':
         begin
         ok := PinBehaviour('ParseRSTDomesticQTH', RowText(aRow), exch);
         end;
      'n':
         begin
         ok := PinBehaviour(aHelper, RowText(aRow), exch);
         msg := SExchangeNoPrecedence;
         end;
      'o':
         begin
         PinBehaviour(aHelper, RowText(aRow), exch);
         ok := False;
         msg := Format(SExchangeOutOfStateWorksHostOnly, [aHostState]);
         end;
      'p', 'w':
         begin
         (* A MULTI-STATE PARTY'S OUT-OF-AREA STATION -- Q107: as 'o', naming
            the 7th area ('p') or New England ('w'), which have no HostState. *)
         PinBehaviour(aHelper, RowText(aRow), exch);
         ok := False;
         if aCode = 'p' then
            begin
            msg := Format(SExchangeOutOfStateWorksHostOnly, ['7th area']);
            end
         else
            begin
            msg := Format(SExchangeOutOfStateWorksHostOnly, ['New England']);
            end;
         end;
      'u':
         begin
         msg := string(TC_INVALID);
         end;
      'a':
         begin
         GAbandoned := 1;
         end;
      'z':
         begin
         ok := PinBehaviour(aHelper, RowText(aRow), exch);
         exch.Zone := 8;
         GZoneAsked := call;
         end;
      'c':
         begin
         ok := PinBehaviour(aHelper, RowText(aRow), exch);
         exch.DomesticQTH := exch.QTHString;
         end;
      '2':
         begin
         PinBehaviour(aHelper, RowText(aRow), exch);
         exch := RowExchange(aRow);
         ok := PinBehaviour(aHelper, RowText(aRow), exch);
         end;
      'r':
         begin
         PinBehaviour(aHelper, RowText(aRow), exch);
         ok := False;
         msg := Format(SExchangeOutOfStateWorksHostOnly, [IN7QPNEPartyAreas]);
         end;
      'i', 'e':
         begin
         PinBehaviour(aHelper, RowText(aRow), exch);
         exch := RowExchange(aRow);
         PinBehaviour(aHelper, RowText(aRow), exch);
         ok := False;
         if aCode = 'i' then
            begin
            msg := Format(SExchangeOutOfStateWorksHostOnly, ['IN']);
            end
         else
            begin
            msg := Format(SExchangeOutOfStateWorksHostOnly, ['DE']);
            end;
         end;
   else
      begin
      msg := '<unknown code ' + aCode + '>';
      end;
   end;
   Result := OutcomeText(ok, msg, exch);
end;

(* ---------------------------------------------------------------------------
   THE PINNED TABLES
   --------------------------------------------------------------------------- *)

(* THE PARSER A PLAIN EXCHANGE REACHES, per contest and station. '' for a
   contest that names none: the classless DUMMYCONTEST, and the two that
   choose by the text (Arktika Spring, the PCC). *)
function PinnedHelper(aContest: ContestType; aStation: TPinStation): string;

begin

   Result := '<not pinned>';

   case aContest of

      (* No parser of its own: the classless contest, and the two that

         choose one by the text (Arktika Spring, the PCC). *)

      DUMMYCONTEST, ARKTIKA_SPRING, PCC:

         begin

         Result := '';

         end;



      ARRL160:

         begin

         if aStation in [psDX, psPA, psJA] then

            begin

            Result := 'ParseRSTDomesticQTH';

            end

         else

            begin

            Result := 'ParseRSTDomesticOrDXQTH';

            end;

         end;



      ARRLDXCW, ARRLDXSSB:

         begin

         if aStation in [psUS, psVE, psHost] then

            begin

            Result := 'ParseRSTPower';

            end

         else

            begin

            Result := 'ParseRSTDomesticQTH';

            end;

         end;



      CALQSOPARTY:

         begin

         if aStation = psHost then

            begin

            Result := 'ParseQSONumberDomesticOrDXQTH';

            end

         else

            begin

            Result := 'ParseQSONumberDomesticQTH';

            end;

         end;



      JIDXCW, JIDXSSB:

         begin

         if aStation = psJA then

            begin

            Result := 'ParseRSTZone';

            end

         else

            begin

            Result := 'ParseRSTPrefecture';

            end;

         end;



      PACC:

         begin

         if aStation = psPA then

            begin

            Result := 'ParseRSTAndQSONumberOrDomesticQTH';

            end

         else

            begin

            Result := 'ParseRSTDomesticQTH';

            end;

         end;



      SEVENQP, ArizonaQsoParty, NEWENGLANDQSO, SALMONRUN, TEXASQSOPARTY:

         begin

         if aStation = psHost then

            begin

            Result := 'ParseRSTDomesticOrDXQTH';

            end

         else

            begin

            Result := 'ParseRSTDomesticQTH';

            end;

         end;



      YOUTHCHAMPIONSHIPRF:

         begin

         Result := 'ParseAgeAndQSONumber';

         end;



      ARRLFIELDDAY, WINTERFIELDDAY:

         begin

         Result := 'ParseClassDomesticOrDXQTH';

         end;



      MAKROTHEN, BATAVIA_FT8:

         begin

         Result := 'ParseGrid';

         end;



      ARRLDIGI, WWDIGI:

         begin

         Result := 'ParseGrid2';

         end;



      KIDSDAY:

         begin

         Result := 'ParseKidsDay';

         end;



      NZFIELDDAY:

         begin

         Result := 'ParseNZFieldDay';

         end;



      MINNQSOPARTY, NAQSOCW, NAQSOSSB, NAQSORTTY, LQP, COLORADOQSOPARTY, CWOPS, SST:

         begin

         Result := 'ParseNameAndDomesticOrDXQTH';

         end;



      GRIDLOC:

         begin

         Result := 'ParseNameAndPossibleGridSquare';

         end;



      TENTEN:

         begin

         Result := 'ParseNameQTHAndPossibleTenTenNumber';

         end;



      RFASCHAMPIONSHIPCW:

         begin

         Result := 'ParseQSONumberAndCoordinatesSum';

         end;



      RAEM:

         begin

         Result := 'ParseQSONumberAndGeoCoordinates';

         end;



      CUPRFCW, CUPRFSSB, CUPRFDIG:

         begin

         Result := 'ParseQSONumberAndGridSquare';

         end;



      EUSPRINT_SPRING_CW, CWOPEN, EUSPRINT_SPRING_SSB, EUSPRINT_AUTUMN_CW,

      EUSPRINT_AUTUMN_SSB, MST:

         begin

         Result := 'ParseQSONumberAndName';

         end;



      CQIR:

         begin

         Result := 'ParseQSONumberAndPossibleDomesticQTH';

         end;



      RADIOYOC:

         begin

         Result := 'ParseQSONumberAndPreviousQSONumber';

         end;



      RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, R9W_UW9WK_MEMORIAL:

         begin

         Result := 'ParseQSONumberAndZone';

         end;



      VAQP:

         begin

         Result := 'ParseQSONumberDomesticOrDXQTH';

         end;



      CUPURAL, UKRAINECHAMPIONSHIP, PAQSOPARTY:

         begin

         Result := 'ParseQSONumberDomesticQTH';

         end;



      QCWA, QCWAGOLDEN:

         begin

         Result := 'ParseQSONumberNameChapterAndQTH';

         end;



      INTERNETSPRINT, NASPRINTCW, SPRINTSSB, NASPRINTRTTY, NCCCSPRINT:

         begin

         Result := 'ParseQSONumberNameDomesticOrDXQTH';

         end;



      ARRLSSCW, ARRLSSSSB:

         begin

         Result := 'ParseQSONumberPrecedenceCheckDomesticQTH';

         end;



      ALLJA:

         begin

         Result := 'ParseRSTALLJAPrefectureAndPrecedence';

         end;



      ALLASIANCW, ALLASIANSSB, YOTA:

         begin

         Result := 'ParseRSTAge';

         end;



      RADIOMEMORY:

         begin

         Result := 'ParseRSTAgeAndPossibleSK';

         end;



      SOUTHAMERICANWW, CQMM:

         begin

         Result := 'ParseRSTAndContinent';

         end;



      WWL:

         begin

         Result := 'ParseRSTAndGrid';

         end;



      UA4WCHAMPIONSHIP:

         begin

         Result := 'ParseRSTAndGridSquareOrRDA';

         end;



      ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, CQVHF, STEWPERRY:

         begin

         Result := 'ParseRSTAndOrGrid';

         end;



      POTA:

         begin

         Result := 'ParseRSTAndPOTAPark';

         end;



      RSGB_ROPOCO_CW, RSGB_ROPOCO_SSB:

         begin

         Result := 'ParseRSTAndPostalCode';

         end;



      ARI_DX, OKDX, CANADA_WINTER, UKRAINIAN, DARCXMAS, WAG, YODX, CANADA_DAY, OKOMSSB:

         begin

         Result := 'ParseRSTAndQSONumberOrDomesticQTH';

         end;



      REFCW, REFSSB:

         begin

         Result := 'ParseRSTAndQSONumberOrFrenchDepartment';

         end;



      FLORIDAQSOPARTY, LABRE, IDAHOQSOPARTY, DELAWAREQSOPARTY, NEBRASKAQSO:

         begin

         Result := 'ParseRSTDomesticOrDXQTH';

         end;



      MICHQSOPARTY, MOQSOPARTY, NCQSOPARTY, TOEC, WISCONSINQSOPARTY, NYQP,

      TENNESSEEQSOPARTY, ALRS_UA1DZ_CUP, INQSOPARTY, BCQP, IN7QPNE:

         begin

         Result := 'ParseRSTDomesticQTH';

         end;



      ARRL10, CIS, HADX, YUDX, HELVETIA, RDA, RUSSIANDX, SPDX, RU3AXMEMORIAL, UNDX,

      KINGOFSPAINCW, KINGOFSPAINSSB, ARRL_RTTY_ROUNDUP:

         begin

         Result := 'ParseRSTDomesticQTHOrQSONumber';

         end;



      JALONGPREFECT:

         begin

         Result := 'ParseRSTLongJAPrefecture';

         end;



      BWQP, GENERALQSO:

         begin

         Result := 'ParseRSTNameAndQTH';

         end;



      ARCI:

         begin

         Result := 'ParseRSTPossibleDomesticQTHAndPower';

         end;



      FOCMARATHON, OLDNEWYEAR:

         begin

         Result := 'ParseRSTPower';

         end;



      APSPRINT, BALTIC, CQM, CQWPXCW, CQWPXSSB, CQWPXRTTY, MARCONIMEMORIAL, MINITEST,

      MINI80, MINI40, OCEANIADXCW, OCEANIADXSSB, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW,

      REGION1FIELDDAY_RCC_SSB, SACCW, YBDX, SACSSB, UCG, DARCWAEDCCW, DARCWAEDCSSB,

      SASPRINT, MWC:

         begin

         Result := 'ParseRSTQSONumber';

         end;



      NRAUBALTICCW, NRAUBALTICSSB, OHIOQSOPARTY:

         begin

         Result := 'ParseRSTQSONumberAndDomesticQTH';

         end;



      EUROPEANVHF, TESLA, RADIOVHFFD, OZHCRVHF, RTC:

         begin

         Result := 'ParseRSTQSONumberAndGridSquare';

         end;



      UKEI, IOTA, RSGB18, UBACW, UBASSB, DARC10M:

         begin

         Result := 'ParseRSTQSONumberAndPossibleDomesticQTH';

         end;



      XMAS:

         begin

         Result := 'ParseRSTQSONumberAndRandomCharacters';

         end;



      COUNTYHUNTER:

         begin

         Result := 'ParseRSTQTH';

         end;



      FISTS:

         begin

         Result := 'ParseRSTQTHNameAndFistsNumberOrPower';

         end;



      CQWWCW, CQWWSSB, EUROPEANHFC, GACWWWSACW, JTDX, KVP, WWIH:

         begin

         Result := 'ParseRSTZone';

         end;



      CQWWRTTY:

         begin

         Result := 'ParseRSTZoneAndPossibleDomesticQTH';

         end;



      CQ160CW, CQ160SSB, CROATIAN, GAGARINCUP, KCJ, LZDX, IRTS, EUDX:

         begin

         Result := 'ParseRSTZoneOrDomesticQTH';

         end;



      IARU, OZCR_O, OZCR_Z, WWPMC, WRTC, BSCI:

         begin

         Result := 'ParseRSTZoneOrSociety';

         end;

   end;

end;




const
   (* THE ROWS, as the codes below lay them out: six worked stations per
      text, the texts in BATTERY_TEXT's order --
        0-5   ''              6-11  '599 123'       12-17 '123'
        18-23 'ARRL'          24-29 '599 CT'        30-35 '123 A 99 CT'
        36-41 'CT 99 A 123'   42-47 '599 INMAR'     48-53 '!!! ###'
        54-59 over-long       60-65 '599'
      and within each six W1AW, VE0ABC, PY2ABC, UA3ABC live, UA3ABC not
      live, G3ABC. *)

   (* A STATE PARTY'S OUT-OF-STATE STATION (design 7.10): an accepted
      exchange whose QTH the domestic table does not know is refused. Not at
      the host-state station, which works everyone. *)
   CODES_OUT_OF_STATE  = '......oooooooooooooooooo............oooooo..................oooooo';

   (* THE SAME RULE IN THE TWO MULTI-STATE PARTIES -- Q107 (NY4I,
      2026-10-16): outside the 7th area ('p') or New England ('w') an accepted
      exchange whose QTH the domestic table does not know is refused, through
      the same predicate (uContestBase.HostAreaRuleCredits). Before Q107 both
      were all '.'. *)
   CODES_SEVENQP_OUT_OF_AREA = '......pppppppppppppppppp............pppppp..................pppppp';
   CODES_NEQP_OUT_OF_AREA    = '......wwwwwwwwwwwwwwwwww............wwwwww..................wwwwww';

   (* Sweepstakes: a refused exchange with no precedence says so. *)
   CODES_SWEEPSTAKES   = 'nnnnnn..........................................nnnnnn............';

   (* UK/EI: a UK station sending one word is refused before any parse. *)
   CODES_UKEI          = '.................u.....u.........................................u';

   (* IARU: a member society's one word gets the zone from the call. *)
   CODES_IARU          = 'zzzzzz............zzzzzz..........................................';

   (* LABRE: a PY station sends a state. *)
   CODES_LABRE         = '..d.....d.....d.....d.....d.....d.....d.....d.....d.....d.....d...';

   (* RAC: a VE0 station sends a serial. *)
   CODES_RAC           = '.q.....q.....q.....q.....q.....q.....q.....q.....q.....q.....q....';

   (* SAC: a Russian station in live entry is abandoned, unparsed. *)
   CODES_SAC           = '...a.....a.....a.....a.....a.....a.....a.....a.....a.....a.....a..';

   (* The UA4W Championship: an accepted QTH is the domestic QTH. *)
   CODES_UA4W          = '......cccccccccccccccccccccccccccccccccccc............cccccccccccc';

   (* Arktika Spring: digits and blanks are a serial, anything else a QTH. *)
   CODES_ARKTIKA       = 'ddddddqqqqqqqqqqqqddddddddddddddddddddddddddddddddddddddddddqqqqqq';

   (* The PCC: digits alone are a serial, anything else a QTH. *)
   CODES_PCC           = 'ddddddddddddqqqqqqddddddddddddddddddddddddddddddddddddddddddqqqqqq';

   (* IN7QPNE: an accepted exchange is parsed again for the party its
      county names (the stub's INMAR, Indiana's), else refused -- no roster
      station is in a party. *)
   CODES_IN7QPNE       = '......rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr222222......rrrrrrrrrrrr';

(* WHAT THE CLASS DID WITH EACH ROW -- see ExpectedOutcome. Every row '.'
   unless listed. *)
function PinnedCodes(aContest: ContestType; aStation: TPinStation): string;
begin
   Result := StringOfChar('.', ROWS);
   case aContest of
      (* The classless contest parses nothing. *)
      DUMMYCONTEST:
         begin
         Result := StringOfChar('-', ROWS);
         end;

      ArizonaQsoParty, BCQP, CALQSOPARTY, COLORADOQSOPARTY, DELAWAREQSOPARTY, NEBRASKAQSO,
      FLORIDAQSOPARTY, IDAHOQSOPARTY, INQSOPARTY, MICHQSOPARTY, MINNQSOPARTY,
      MOQSOPARTY, NCQSOPARTY, NYQP, OHIOQSOPARTY, PAQSOPARTY, SALMONRUN,
      TENNESSEEQSOPARTY, TEXASQSOPARTY, VAQP, WISCONSINQSOPARTY:
         begin
         if aStation <> psHost then
            begin
            Result := CODES_OUT_OF_STATE;
            end;
         end;

      (* In area: the 7QP's host station is set-up's in-state answer, NEQP's
         is MY STATE in New England -- the roster's psHost is K1AAA in MA,
         inside New England and outside the 7th area's MY STATE but marked in
         state, so it is in area for both. *)
      SEVENQP:
         begin
         if aStation <> psHost then
            begin
            Result := CODES_SEVENQP_OUT_OF_AREA;
            end;
         end;

      NEWENGLANDQSO:
         begin
         if aStation <> psHost then
            begin
            Result := CODES_NEQP_OUT_OF_AREA;
            end;
         end;

      ARRLSSCW, ARRLSSSSB:
         begin
         Result := CODES_SWEEPSTAKES;
         end;

      UKEI:
         begin
         Result := CODES_UKEI;
         end;

      IARU:
         begin
         Result := CODES_IARU;
         end;

      LABRE:
         begin
         Result := CODES_LABRE;
         end;

      CANADA_DAY, CANADA_WINTER:
         begin
         Result := CODES_RAC;
         end;

      SACCW, SACSSB:
         begin
         Result := CODES_SAC;
         end;

      UA4WCHAMPIONSHIP:
         begin
         Result := CODES_UA4W;
         end;

      ARKTIKA_SPRING:
         begin
         Result := CODES_ARKTIKA;
         end;

      PCC:
         begin
         Result := CODES_PCC;
         end;

      IN7QPNE:
         begin
         Result := CODES_IN7QPNE;
         end;
   end;
end;

(* ---------------------------------------------------------------------------
   THE TESTS
   --------------------------------------------------------------------------- *)

function MakeProgramContest(aContest: ContestType;
                            const aStation: TStationContext): TContestBase;
begin
   (* The engine asks ExchangeContest: the active object, else the identity
      -- never nil. For the classless DUMMYCONTEST that is the plain base. *)
   Result := MakeContestOrNil(aContest, aStation);
   if Result = nil then
      begin
      Result := TContestBase.Create(ContestHandleOf(aContest));
      Result.SetStation(aStation);
      end;
end;

function Who(aContest: ContestType; aStation: TPinStation; aRow: integer): string;
begin
   Result := string(ContestTypeSA[aContest]) + ' at ' + PinStationCall(aStation) +
             ' row ' + IntToStr(aRow) + ' "' + RowText(aRow) + '" from ' +
             BATTERY_CALL[aRow mod CALLS].Call;
end;

procedure TExchangeParseTests.Test_EveryContestParsesItsPinnedOutcomes;
var
   c: ContestType;
   s: TPinStation;
   station: TStationContext;
   obj: TContestBase;
   codes: string;
   helper: string;
   row: integer;
   checked: integer;
begin
   BeginTest('Test_EveryContestParsesItsPinnedOutcomes');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         codes := PinnedCodes(c, s);
         helper := PinnedHelper(c, s);
         CheckEquals(ROWS, Length(codes), string(ContestTypeSA[c]) + ' codes pinned');
         obj := MakeProgramContest(c, station);
         try
            for row := 0 to ROWS - 1 do
               begin
               CheckEquals(ExpectedOutcome(codes[row + 1], helper, obj.HostState, row),
                           ActualOutcome(obj, c, station, row),
                           Who(c, s, row));
               Inc(checked);
               end;
         finally
            obj.Free;
         end;
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) * ROWS, checked,
               'contest x station x row parses pinned');
end;

(* THE CROSS-CHECK: the parser a plain exchange reaches is the one the old
   machine's arm called for the session's shape, for every ContestType at
   every roster station that names one. Until S9e deletes the shape. *)
procedure TExchangeParseTests.Test_PinnedHelperIsTheSessionShapes;
var
   c: ContestType;
   s: TPinStation;
   checked: integer;
begin
   BeginTest('Test_PinnedHelperIsTheSessionShapes');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         if PinnedHelper(c, s) = '' then
            begin
            Continue;
            end;
         CheckEquals(LegacyHelper(Kinds(c, PinStation(s, c)).Exchange), PinnedHelper(c, s),
                     string(ContestTypeSA[c]) + ' at ' + PinStationCall(s) +
                     ': the parser its session shape''s arm called');
         Inc(checked);
         end;
      end;
   CheckTrue(checked > 0, 'helpers cross-checked');
end;

(* ---------------------------------------------------------------------------
   WHAT THE EXCHANGE CARRIES -- the four readers of the session's shape S9d
   moved beside the parser: TContestBase.ExchangeCarriesDomesticQTH,
   ExchangeCarriesZone, ExchangeCarriesGridSquare (the readiness check, and
   the domestic one LOGSTUFF's improper-QTH refusal) and
   PerQSOExchangeLeadsWithSerial (MainUnit.PerQSOExchString). The S7 method:
   literals laid out from the old sets on the session shape Kinds resolves,
   RUN GREEN AGAINST THE OLD CODE (ProgramCarries answered the frozen set
   then), then the same tables green against the classes.
   --------------------------------------------------------------------------- *)

type
   TExchangeCarry = (ecDomesticQTH, ecZone, ecGridSquare, ecSerialFirst);

const
   CARRY_NAMES: array[TExchangeCarry] of string = (
      'carries a domestic QTH', 'carries a zone', 'carries a grid square',
      'leads its per-QSO string with the serial'
   );

   (* THE CONTESTS THAT ANSWER EACH AT EVERY STATION. The station branches
      are PinnedCarries'. *)
   CARRIES_DOMESTIC_QTH_EVERYWHERE = [
      SEVENQP, ARI_DX, ARRL10, ARRL160, ARRLSSCW, ARRLSSSSB, ArizonaQsoParty,
      CIS, CALQSOPARTY, CQ160CW, CQ160SSB, CROATIAN, CUPURAL, ARRLFIELDDAY,
      FLORIDAQSOPARTY, GAGARINCUP, HADX, YUDX, UKEI, HELVETIA, INTERNETSPRINT,
      IOTA, KCJ, LABRE, LZDX, MICHQSOPARTY, MINNQSOPARTY, MOQSOPARTY, NAQSOCW,
      NAQSOSSB, NAQSORTTY, NASPRINTCW, SPRINTSSB, NASPRINTRTTY, NCCCSPRINT,
      NEWENGLANDQSO, NCQSOPARTY, NRAUBALTICCW, NRAUBALTICSSB, OHIOQSOPARTY,
      OKDX, PACC, CANADA_WINTER, RDA, RSGB18, RUSSIANDX, SALMONRUN, SPDX,
      TEXASQSOPARTY, TOEC, UBACW, UBASSB, UKRAINECHAMPIONSHIP, UKRAINIAN,
      DARCXMAS, WAG, WISCONSINQSOPARTY, YODX, RU3AXMEMORIAL, LQP,
      ARKTIKA_SPRING, UNDX, NYQP, KINGOFSPAINCW, KINGOFSPAINSSB,
      TENNESSEEQSOPARTY, COLORADOQSOPARTY, PCC, DARC10M, CWOPS, CANADA_DAY,
      CQWWRTTY, ARRL_RTTY_ROUNDUP, CQIR, ALRS_UA1DZ_CUP, WINTERFIELDDAY,
      PAQSOPARTY, INQSOPARTY, OKOMSSB, IRTS, EUDX, BCQP, VAQP, IN7QPNE, SST,
      IDAHOQSOPARTY, DELAWAREQSOPARTY, NEBRASKAQSO];

   CARRIES_ZONE_EVERYWHERE = [
      CQ160CW, CQ160SSB, CQWWCW, CQWWSSB, CROATIAN, EUROPEANHFC, GACWWWSACW,
      GAGARINCUP, IARU, JTDX, KCJ, KVP, LZDX, OZCR_O, OZCR_Z,
      RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB, WWPMC, WRTC, R9W_UW9WK_MEMORIAL,
      BSCI, CQWWRTTY, WWIH, IRTS, EUDX];

   CARRIES_GRID_SQUARE_EVERYWHERE = [
      ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN, ARRLVHFSEP, CQVHF, CUPRFCW, CUPRFSSB,
      CUPRFDIG, EUROPEANVHF, TESLA, GRIDLOC, RADIOVHFFD, STEWPERRY,
      UA4WCHAMPIONSHIP, WWL, OZHCRVHF, MAKROTHEN, BATAVIA_FT8, WWDIGI, RTC];

   SERIAL_FIRST_EVERYWHERE = [CALQSOPARTY, CUPURAL, UKRAINECHAMPIONSHIP,
                              PAQSOPARTY, VAQP];

(* THE OLD SETS, FROZEN -- uContestReadiness's DOMESTIC_QTH_EXCHANGES,
   ZONE_EXCHANGES and GRID_EXCHANGES, and MainUnit.PerQSOExchString's two
   labels, as they stood before S9d. *)
function LegacyCarries(aCarry: TExchangeCarry; aShape: ExchangeType): boolean;
begin
   case aCarry of
      ecDomesticQTH:
         begin
         Result := aShape in [ClassDomesticOrDXQTHExchange,
                              NameAndDomesticOrDXQTHExchange,
                              QSONumberAndPossibleDomesticQTHExchange,
                              QSONumberDomesticOrDXQTHExchange,
                              QSONumberDomesticQTHExchange,
                              QSONumberNameDomesticOrDXQTHExchange,
                              QSONumberPrecedenceCheckDomesticQTHExchange,
                              RSTAndDOMESTICQTH,
                              RSTAndQSONumberOrDomesticQTHExchange,
                              RSTDomesticOrDXQTHExchange,
                              RSTDomesticQTHExchange,
                              RSTDomesticQTHOrQSONumberExchange,
                              RSTQSONumberAndDomesticQTHExchange,
                              RSTQSONumberAndPossibleDomesticQTHExchange,
                              RSTQSONumberOrDomesticQTHExchange,
                              RSTZoneAndPossibleDomesticQTHExchange,
                              RSTZoneOrDomesticQTH];
         end;
      ecZone:
         begin
         Result := aShape in [QSONumberAndZone,
                              RSTZoneAndPossibleDomesticQTHExchange,
                              RSTZoneExchange,
                              RSTZoneOrSocietyExchange,
                              RSTZoneOrDomesticQTH];
         end;
      ecGridSquare:
         begin
         Result := aShape in [GridExchange,
                              Grid2Exchange,
                              RSTAndGrid3Exchange,
                              RSTAndGridExchange,
                              RSTAndOrGridExchange,
                              QSONumberAndGridSquare,
                              RSTQSONumberAndGridSquareExchange,
                              NameAndPossibleGridSquareExchange,
                              RSTAndSerialNumberAndGridandPossibleMemberNumber,
                              RSTAndGridSquareOrRDAExchange];
         end;
   else
      begin
      Result := aShape in [QSONumberDomesticQTHExchange,
                           QSONumberDomesticOrDXQTHExchange];
      end;
   end;
end;

(* WHAT THE PROGRAM ANSWERS -- what uProgramMain's readiness check, LOGSTUFF's
   refusal and MainUnit.PerQSOExchString ask of the open contest, through the
   nil-safe Contest... functions. BEFORE THE MOVE it returned the frozen set
   on the session shape Kinds resolves -- the run that made the literals:
      Result := LegacyCarries(aCarry, Kinds(aContest, aStation).Exchange); *)
function ProgramCarries(aCarry: TExchangeCarry; aContest: ContestType;
                        const aStation: TStationContext): boolean;
var
   obj: TContestBase;
begin
   obj := MakeContestOrNil(aContest, aStation);
   try
      case aCarry of
         ecDomesticQTH:
            begin
            Result := ContestExchangeCarriesDomesticQTH(obj);
            end;
         ecZone:
            begin
            Result := ContestExchangeCarriesZone(obj);
            end;
         ecGridSquare:
            begin
            Result := ContestExchangeCarriesGridSquare(obj);
            end;
      else
         begin
         Result := ContestPerQSOExchangeLeadsWithSerial(obj);
         end;
      end;
   finally
      obj.Free;
   end;
end;

(* THE PINNED ANSWER: the sets above, and the station branches -- each the
   test the contest's DescribeSession chooses its exchange by. *)
function PinnedCarries(aCarry: TExchangeCarry; aContest: ContestType;
                       aStation: TPinStation): boolean;
begin
   case aCarry of
      ecDomesticQTH:
         begin
         (* The ARRL DX: a W or VE entrant sends power; anyone else a state. *)
         Result := (aContest in CARRIES_DOMESTIC_QTH_EVERYWHERE) or
                   ((aContest in [ARRLDXCW, ARRLDXSSB]) and
                    not (aStation in [psUS, psVE, psHost]));
         end;
      ecZone:
         begin
         (* The JIDX: a Japanese entrant receives a zone. *)
         Result := (aContest in CARRIES_ZONE_EVERYWHERE) or
                   ((aContest in [JIDXCW, JIDXSSB]) and (aStation = psJA));
         end;
      ecGridSquare:
         begin
         Result := aContest in CARRIES_GRID_SQUARE_EVERYWHERE;
         end;
   else
      begin
      Result := aContest in SERIAL_FIRST_EVERYWHERE;
      end;
   end;
end;

procedure TExchangeParseTests.Test_EveryContestStatesWhatItsExchangeCarries;
var
   e: TExchangeCarry;
   s: TPinStation;
   c: ContestType;
begin
   BeginTest('Test_EveryContestStatesWhatItsExchangeCarries');
   (* THE LEGACY CONTESTS, FROZEN: PinnedCarries, contest by contest, at every
      roster station. The table of how many contests answered each at each
      station is deleted (Q108 S1): it was counted from the sets and branches
      PinnedCarries reads, so it restated them and moved by hand with every
      contest added (Nebraska's domestic QTH raised a whole row). A contest
      that gains or loses an answer fails here by name. *)
   for e := Low(TExchangeCarry) to High(TExchangeCarry) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         for c := Low(ContestType) to High(ContestType) do
            begin
            CheckEquals(BoolToStr(PinnedCarries(e, c, s), True),
                        BoolToStr(ProgramCarries(e, c, PinStation(s, c)), True),
                        string(ContestTypeSA[c]) + ' at ' + PinStationCall(s) + ' ' +
                        CARRY_NAMES[e]);
            end;
         end;
      end;
end;

(* THE CROSS-CHECK: the program's answer against the frozen set on the
   session shape, for every ContestType at every roster station. Until S9e
   deletes the shape. *)
procedure TExchangeParseTests.Test_CarriesAgreeWithTheSessionShape;
var
   e: TExchangeCarry;
   s: TPinStation;
   c: ContestType;
   station: TStationContext;
   checked: integer;
begin
   BeginTest('Test_CarriesAgreeWithTheSessionShape');
   checked := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      for s := Low(TPinStation) to High(TPinStation) do
         begin
         station := PinStation(s, c);
         for e := Low(TExchangeCarry) to High(TExchangeCarry) do
            begin
            CheckEquals(BoolToStr(LegacyCarries(e, Kinds(c, station).Exchange), True),
                        BoolToStr(ProgramCarries(e, c, station), True),
                        string(ContestTypeSA[c]) + ' at ' + PinStationCall(s) + ' ' +
                        CARRY_NAMES[e] + ' as its session shape did');
            Inc(checked);
            end;
         end;
      end;
   CheckEquals((Ord(High(ContestType)) + 1) * (Ord(High(TPinStation)) + 1) *
               (Ord(High(TExchangeCarry)) + 1), checked,
               'contest x station x answer compared');
end;

procedure TExchangeParseTests.RunAllTests;
begin
   Test_EveryContestParsesItsPinnedOutcomes;
   Test_PinnedHelperIsTheSessionShapes;
   Test_EveryContestStatesWhatItsExchangeCarries;
   Test_CarriesAgreeWithTheSessionShape;
end;

end.
