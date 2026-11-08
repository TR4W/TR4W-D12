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

(* THE WORDS OF AN EXCHANGE IN ANOTHER ORDER -- 2026-11-04.

  Three issues brought over from the D7 tracker, each about an operator
  typing the exchange's words in an order the parser did not expect:

  * #174 (TR4W#460) -- Sweepstakes: the precedence BEFORE the serial, in one
    word ('80 WCF U123' as well as '80 WCF 123U').
  * #170 (TR4W#417) -- NA Sprint: the state first ('FL TOM 4'). Reported in
    D7 as a QTH of 'FLM' and no domestic QTH; the parser has since lost its
    pointers. This pins what it does now.
  * #169 (TR4W#416) -- NAQP: the state and the name in either order
    ('FL TOM' as well as 'TOM FL').

  THROUGH THE REAL ENGINE, as uTestFieldDaySectionRefusal does: ParametersOkay,
  with the shipped domestic file in the table and the domestic countries the
  contest's DescribeSession states. Not in uTestExchangeParse, whose parsers
  are a stub on purpose -- these defects live inside the engine's parsers,
  which a stub cannot reach.

  EVERY ENTRY THAT WAS TAKEN BEFORE IS PINNED BESIDE THE NEW ONE, with the
  same fields, so a reading that changes for a good entry fails here. *)
unit uTestExchangeWordOrder;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TExchangeWordOrderTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_SweepstakesPrecedenceBeforeTheSerial;
      procedure Test_SweepstakesAmbiguousSerialIsRefused;
      procedure Test_SweepstakesReferenceModelIsAnchored;
      procedure Test_SweepstakesEveryOrdering;
      procedure Test_SprintStateBeforeTheName;
      procedure Test_NAQPStateAndNameInEitherOrder;
      procedure Test_SweepstakesMultiplierHintIsTheSection;
      procedure Test_ALLJARememberedExchangeHasNoNul;
   end;

implementation

uses
   (* cpHIGH. Before VC, so VC's names win where they overlap. *)
   uSettingsModel,
   Classes,
   SysUtils,
   VC,
   (* mo -- the multiplier sheet's store. *)
   uMults,
   uCallsigns,
   uCTYDAT,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   (* ContestSession -- the exchange kind GetInitialExchange... reads. *)
   uContestSession,
   (* DomesticCountries -- the engine's domestic-country list. *)
   ZoneCont,
   uTestContestObjects,
   (* A shipped .dom through the real loader, its INCLUDEs followed. *)
   uTestShippedDom,
   (* SExchangeNoPrecedence -- the Sweepstakes refusal's text. *)
   uAppStrings,
   LogDupe,
   LogDom,
   LogEdit,
   LogWind,
   LogStuff,
   PostUnit,
   FCONTEST,
   MainUnit;

var
   (* What each test saves and puts back: the engine state ParametersOkay
      reads. One set, because the three tests run one after another. *)
   savedContest: TContestHandle;
   savedActiveMode: ModeType;
   savedCallWindow: CallString;
   savedTable: TDomQTHTable;
   savedList: TCallsignsList;
   savedQualified: TQualifiedDupeSheet;
   savedCountries: TStringList;
   savedMyCountry: string;
   savedDomesticFilename: string;

(* ONE EXCHANGE, AS AN OPERATOR ENTERS IT -- ParametersOkay alone; no QSO is
   logged. *)
function Enter(const aCall: string; const aExch: string; var aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   ActiveMode := CW;
   CallWindowString := CallString(aCall);
   ExchangeErrorMessage := '';
   Result := ParametersOkay(CallString(aCall), Str40(aExch), Band20, CW,
                            14025000, aRX);
end;

(* THE SESSION AS FoundContest SETS aContest UP, for what a parse reads: the
   contest, its domestic countries, its domestic file in the table and named
   in the setting, and a station in the USA. *)
procedure SetUpSession(aContest: ContestType; const aCountries: array of string;
                       const aDomFile: string);
var
   i: integer;
begin
   savedContest := Contest;
   savedActiveMode := ActiveMode;
   savedCallWindow := CallWindowString;
   savedTable := DomQTHTable;
   savedList := CallsignsList;
   savedQualified := QualifiedDupes;
   savedMyCountry := Settings.My.Country;
   savedDomesticFilename := Settings.Contest.DomesticFilename;
   savedCountries := TStringList.Create;
   for i := 0 to DomesticCountries.Count - 1 do
      begin
      savedCountries.Add(DomesticCountries.IDs[i]);
      end;

   DomQTHTable := TDomQTHTable.Create;
   CallsignsList := TCallsignsList.Create;
   QualifiedDupes := TQualifiedDupeSheet.Create;

   DomesticCountries.Clear;
   for i := Low(aCountries) to High(aCountries) do
      begin
      DomesticCountries.Add(CallString(aCountries[i]));
      end;
   LoadShippedDomFollowingIncludes(DomQTHTable, aDomFile, True, 0);
   Settings.Contest.DomesticFilename := aDomFile;
   Settings.My.DeriveCountry('K');

   Contest := ContestHandleOf(aContest);
   ReleaseActiveContest;
end;

procedure RestoreSession;
var
   i: integer;
begin
   DomesticCountries.Clear;
   for i := 0 to savedCountries.Count - 1 do
      begin
      DomesticCountries.Add(CallString(savedCountries[i]));
      end;
   savedCountries.Free;
   QualifiedDupes.Free;
   QualifiedDupes := savedQualified;
   CallsignsList.Free;
   CallsignsList := savedList;
   DomQTHTable.Free;
   DomQTHTable := savedTable;
   CallWindowString := savedCallWindow;
   ActiveMode := savedActiveMode;
   Settings.Contest.DomesticFilename := savedDomesticFilename;
   Settings.My.DeriveCountry(savedMyCountry);
   ExchangeErrorMessage := '';
   ExchangeErrorToken := '';
   Contest := savedContest;
   ReleaseActiveContest;
end;

function LoadCountryFile: boolean;
var
   ctyPath: string;
begin
   ctyPath := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
              PathDelim + 'target' + PathDelim + 'cty.dat';
   Result := ctyLoadInCountryFile(ctyPath, False, False, True);
end;

(* ---------------------------------------------------------------------------
   #174 -- SWEEPSTAKES
   --------------------------------------------------------------------------- *)

procedure TExchangeWordOrderTests.Test_SweepstakesPrecedenceBeforeTheSerial;
var
   rx: ContestExchange;
   accepted: boolean;

   procedure CheckTaken(const aExch: string; aNumber: integer; aPrec: AnsiChar;
                        aCheck: integer; const aSection: string);
   begin
      accepted := Enter('W1AW', aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aNumber, Integer(rx.NumberReceived), aExch + ': the serial');
      CheckEquals(string(aPrec), string(rx.Precedence), aExch + ': the precedence');
      CheckEquals(aCheck, Integer(rx.Check), aExch + ': the check');
      CheckEquals(aSection, string(rx.QTHString), aExch + ': the section');
   end;

begin
   BeginTest('Test_SweepstakesPrecedenceBeforeTheSerial');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* THE ORDERS TAKEN BEFORE, unchanged. *)
      CheckTaken('80 WCF 123U', 123, 'U', 80, 'WCF');
      CheckTaken('123 U 80 WCF', 123, 'U', 80, 'WCF');
      CheckTaken('123U 80WCF', 123, 'U', 80, 'WCF');

      (* 'U80WCF 123' IS REFUSED THROUGH LIVE ENTRY: the call correction
         would take U80WCF as the call, and since 2026-11-04 the operator is
         asked instead (Test_SweepstakesAmbiguousSerialIsRefused pins the
         message). The word is still what the call field holds. *)
      accepted := Enter('W1AW', 'U80WCF 123', rx);
      CheckFalse(accepted, 'U80WCF 123: refused through live entry');
      CheckEquals('U80WCF', string(rx.Callsign), 'U80WCF 123: the packed word is read as a callsign');

      (* THE ISSUE'S ENTRY: the precedence first, joined to the serial. *)
      CheckTaken('80 WCF U123', 123, 'U', 80, 'WCF');
      CheckTaken('U123 80 WCF', 123, 'U', 80, 'WCF');
      CheckTaken('80 WCF A5', 5, 'A', 80, 'WCF');
      CheckTaken('80 WCF Q1234', 1234, 'Q', 80, 'WCF');
   finally
      RestoreSession;
   end;
end;

(* A TWO-DIGIT SERIAL BESIDE A TWO-DIGIT CHECK, WITH THE PRECEDENCE A WORD OF
   ITS OWN -- NY4I, 2026-11-04 (#174 follow-up): "in our free-form parsing,
   you cannot tell. I would enter that as 43M W1AW 31 CT". Refused through
   live entry, with the numbers as typed in the message; every way of
   telling the two apart is still taken, and reads as it did. *)
procedure TExchangeWordOrderTests.Test_SweepstakesAmbiguousSerialIsRefused;
var
   rx: ContestExchange;
   accepted: boolean;
   savedCallsignUpdate: boolean;

   procedure CheckTaken(const aExch: string; aNumber: integer; aPrec: AnsiChar;
                        aCheck: integer; const aSection: string);
   begin
      accepted := Enter('W1AW', aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aNumber, Integer(rx.NumberReceived), aExch + ': the serial');
      CheckEquals(string(aPrec), string(rx.Precedence), aExch + ': the precedence');
      CheckEquals(aCheck, Integer(rx.Check), aExch + ': the check');
      CheckEquals(aSection, string(rx.QTHString), aExch + ': the section');
   end;

   procedure CheckRefused(const aExch: string; const aMessage: string);
   begin
      accepted := Enter('W1AW', aExch, rx);
      CheckFalse(accepted, aExch + ': refused');
      CheckEquals(aMessage, string(ExchangeErrorMessage), aExch + ': the message');
   end;

begin
   BeginTest('Test_SweepstakesAmbiguousSerialIsRefused');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   try
      (* AMBIGUOUS: NY4I's example, and the same words in other orders. *)
      CheckRefused('43 M W1AW 31 CT', 'Ambiguous exchange - enter 43M or 31M to resolve');
      CheckRefused('31 W1AW CT M 43', 'Ambiguous exchange - enter 31M or 43M to resolve');
      CheckRefused('M 43 W1AW 31 CT', 'Ambiguous exchange - enter 43M or 31M to resolve');

      (* RESOLVED BY JOINING THE SERIAL AND THE PRECEDENCE. *)
      CheckTaken('43M W1AW 31 CT', 43, 'M', 31, 'CT');
      CheckTaken('U123 W1AW 31 CT', 123, 'U', 31, 'CT');
      (* RESOLVED BY A SERIAL THAT IS NOT TWO DIGITS: it can only be the
         serial, so the lone two-digit word is the check. *)
      CheckTaken('31 W1AW CT M 430', 430, 'M', 31, 'CT');
      CheckTaken('31 W1AW CT M 232', 232, 'M', 31, 'CT');
      CheckTaken('12 W1AW CT M 4', 4, 'M', 12, 'CT');
      (* A CHECK JOINED TO THE SECTION WITH A NUMBER TYPED AFTER IT IS
         AMBIGUOUS -- NY4I, 2026-11-04: "a 99ct 32 would be ambiguous". *)
      CheckRefused('A 99CT 32', 'Ambiguous exchange - enter 99A or 32A to resolve');
      CheckRefused('43 M 22 31CT', 'Ambiguous exchange - enter 43M or 22M to resolve');
      (* BUT A NUMBER TYPED BEFORE THE CHECK AND SECTION READS IN THE BASE
         ORDER -- serial, precedence, call, check, section (NY4I's bench,
         2026-11-04: these must log as they did before clause (b)). *)
      CheckTaken('43 M W1AW 31CT', 43, 'M', 31, 'CT');
      CheckTaken('42 M W1AW 31CT', 42, 'M', 31, 'CT');
      CheckTaken('32 A 99CT', 32, 'A', 99, 'CT');
      CheckTaken('A 32 99CT', 32, 'A', 99, 'CT');
      CheckTaken('43 M 43MI', 43, 'M', 43, 'MI');

      (* A PRECEDENCE JOINED TO DIGITS IS ALWAYS THE PRECEDENCE AND THE
         SERIAL -- NY4I, 2026-11-04: "a check would NEVER be entered with
         the precedence next to it without a space. The only thing we accept
         without a space is the <serial><precedence>." Two digits included;
         they were the precedence and the CHECK until this ruling. *)
      CheckTaken('80 WCF U12', 12, 'U', 80, 'WCF');
      CheckTaken('U12 W1AW 80 CT', 12, 'U', 80, 'CT');
      CheckTaken('A99 W1AW 31 CT', 99, 'A', 31, 'CT');
      CheckTaken('M43 W1AW 31 CT', 43, 'M', 31, 'CT');
      (* Unchanged by the ruling. *)
      CheckTaken('43M W1AW 31 CT', 43, 'M', 31, 'CT');
      CheckTaken('U123 W1AW 31 CT', 123, 'U', 31, 'CT');

      (* A PRECEDENCE, DIGITS AND A SECTION IN ONE WORD IS ALWAYS THE
         PRECEDENCE, THE SERIAL AND THE SECTION -- NY4I, 2026-11-04: "the
         rule was a number next to a prec. was the serial, so a99ct would
         always be serial number 99, so the lone 5 would have to be a
         mal-sent check"; "check will always be two digits".

         WITH CALLSIGN UPDATE ENABLE ON (the default) the call correction
         runs FIRST and would take 'A99CT' as the QSO's call; the entry is
         refused and the operator asked instead ("we can ask"). *)
      CheckRefused('A99CT 123', 'Ambiguous entry - A99CT may be a callsign or an exchange. ' +
                   'For the exchange, enter 99A CT; for the call, type it in the call window');
      CheckRefused('A99CT 32', 'Ambiguous entry - A99CT may be a callsign or an exchange. ' +
                   'For the exchange, enter 99A CT; for the call, type it in the call window');
      CheckRefused('U80WCF 123', 'Ambiguous entry - U80WCF may be a callsign or an exchange. ' +
                   'For the exchange, enter 80U WCF; for the call, type it in the call window');
      (* THE ASKED-FOR SPELLING RESOLVES AS THE GRAMMAR READ THE WORD. *)
      CheckTaken('99A CT 32', 99, 'A', 32, 'CT');
      CheckEquals('W1AW', string(rx.Callsign), '99A CT 32: the call is the call window''s');
      (* A REAL CALL IS STILL TAKEN: the correction takes the LAST word that
         looks like a call, and only that one. *)
      CheckTaken('A99CT 32 W1AW', 99, 'A', 32, 'CT');
      CheckEquals('W1AW', string(rx.Callsign), 'A99CT 32 W1AW: the typed call');
      (* THE SHAPE ALONE DOES NOT ASK: XYZ is no section, so A9XYZ is a call
         (A9 is Bahrain) and is taken as one, as before. *)
      accepted := Enter('W1AW', '43M 31 CT A9XYZ', rx);
      CheckEquals('A9XYZ', string(rx.Callsign), 'A9XYZ: taken as the call');
      CheckTrue(accepted, '43M 31 CT A9XYZ: logged against the corrected call');

      (* WITH IT OFF, the grammar reads them as ruled. *)
      savedCallsignUpdate := Settings.CallWindow.CallsignUpdateEnable;
      Settings.CallWindow.CallsignUpdateEnable := False;
      try
         CheckTaken('A99CT 32', 99, 'A', 32, 'CT');
         CheckEquals('W1AW', string(rx.Callsign), 'A99CT 32: the call is the call window''s');
         CheckTaken('32 A99CT', 99, 'A', 32, 'CT');
         (* A NUMBER THAT IS NOT TWO DIGITS IS A MAL-SENT CHECK, said so. *)
         CheckRefused('A99CT 123', 'Check must be two digits (123)');
         CheckRefused('123 A99CT', 'Check must be two digits (123)');
         CheckRefused('A99CT 5', 'Check must be two digits (5)');
         CheckRefused('U80WCF 123', 'Check must be two digits (123)');
         (* ALONE: serial 99 and no check -- refused, and since issue #174's
            bench (2026-11-04) it says so ('123 A CT' the same). *)
         CheckRefused('A99CT', 'Missing check (two digits)');
         CheckRefused('123 A CT', 'Missing check (two digits)');
         (* NO SECTION -- issue #174: 'A99 32' was refused with no message. *)
         CheckRefused('A99 32', 'Missing section');
         (* WITH THE CALL TYPED LAST, the call is read as the section. *)
         CheckRefused('A99CT 32 W1AW', '');
         (* A PRECEDENCE, A CHECK AND A99CT: the engine stops at the first
            complete reading, last first -- A99CT gives serial 99, the bare
            99 the check; 123 is never reached. *)
         CheckTaken('123 A 99 A99CT', 99, 'A', 99, 'CT');
      finally
         Settings.CallWindow.CallsignUpdateEnable := savedCallsignUpdate;
      end;
   finally
      RestoreSession;
   end;
end;

(* ---------------------------------------------------------------------------
   SWEEPSTAKES IN EVERY ORDER -- NY4I, 2026-11-04: "our test cases need to
   generate every possible scenario (positionally that is)", and "since the
   callsign update is grabbed before the contest class we need a good test
   case that combines callsign update too".

   A REFERENCE MODEL, WRITTEN FROM THE RULINGS, NOT FROM THE PARSER. It calls
   no uExchangeTokens or LOGSTUFF routine. Two stages, as the program runs:

   1. CALLSIGN UPDATE ON: the call correction scans the words LAST FIRST and
      takes the first that looks like a call -- letters and digits, at least
      two letter/digit changes, ending in a letter, not starting with two
      digits (read from LOGSTUFF.LooksLikeACallSign). If that word is also an
      exchange word -- a precedence, digits, then a SECTION -- the entry is
      refused and the operator asked ("we can ask"). Otherwise the word is
      the QSO's call and leaves the exchange.

   2. THE GRAMMAR on what is left:
      - a number touching a precedence ('43M', 'M43', 'U12', 'A99CT') is the
        serial ("a number next to a prec. was the serial");
      - a check is exactly two digits ("check will always be two digits");
        a lone number that is not two digits, beside a joined serial, is a
        mal-sent check, said so;
      - a bare one-, three- or four-digit number is the serial (it cannot be
        a check);
      - with a STANDALONE precedence, two bare two-digit numbers -- or one,
        with a check+section word typed BEFORE it -- are ambiguous, and the
        numbers are named in typed order (the base order, serial precedence
        call check section, reads a number typed before a check+section
        word as the serial);
      - otherwise the one bare two-digit number is the serial beside a
        check+section word, the check beside any other serial.

   ONE RULE HERE HAS NO RULING YET, and is written as the parser behaves so
   the run can be green; it is the order-dependent case reported to NY4I:
      - of the words that can be a section (a section, a check+section
        word's letters, a joined word's letters, a callsign left in the
        exchange), the LATER TYPED is the section -- so with CALLSIGN UPDATE
        off a call typed after the section becomes the section, and the
        entry is refused with no message.
   --------------------------------------------------------------------------- *)

const
   MODEL_SECTIONS: array[0..5] of string = ('CT', 'WCF', 'AB', 'SB', 'MI', 'ORG');
   MODEL_PRECEDENCES = 'ABQUMS';

function ModelIsDigits(const s: string): boolean;
var
   i: integer;
begin
   Result := s <> '';
   for i := 1 to Length(s) do
      begin
      if not ((s[i] >= '0') and (s[i] <= '9')) then
         begin
         Result := False;
         end;
      end;
end;

function ModelIsLetters(const s: string): boolean;
var
   i: integer;
begin
   Result := s <> '';
   for i := 1 to Length(s) do
      begin
      if not ((s[i] >= 'A') and (s[i] <= 'Z')) then
         begin
         Result := False;
         end;
      end;
end;

function ModelIsPrecedence(const s: string): boolean;
begin
   Result := (Length(s) = 1) and (Pos(s, MODEL_PRECEDENCES) > 0);
end;

function ModelIsSection(const s: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(MODEL_SECTIONS) to High(MODEL_SECTIONS) do
      begin
      if MODEL_SECTIONS[i] = s then
         begin
         Result := True;
         end;
      end;
end;

function ModelLooksLikeCall(const w: string): boolean;
var
   i, changes: integer;
   isDigit, wasDigit: boolean;
begin
   Result := False;
   if (Length(w) < 2) or not (ModelIsLetters(Copy(w, Length(w), 1))) then
      begin
      Exit;
      end;
   if ModelIsDigits(Copy(w, 1, 2)) then
      begin
      Exit;
      end;
   changes := 0;
   wasDigit := ModelIsDigits(Copy(w, 1, 1));
   for i := 1 to Length(w) do
      begin
      if not (ModelIsDigits(Copy(w, i, 1)) or ModelIsLetters(Copy(w, i, 1))) then
         begin
         Exit;
         end;
      isDigit := ModelIsDigits(Copy(w, i, 1));
      if (i > 1) and (isDigit <> wasDigit) then
         begin
         inc(changes);
         end;
      wasDigit := isDigit;
      end;
   Result := changes >= 2;
end;

(* A NUMBER JOINED TO A PRECEDENCE: '43M', 'M43' / 'U123', 'A99CT'. *)
function ModelJoined(const w: string; out aSerial, aSection: string; out aPrec: string): boolean;
var
   i: integer;
begin
   Result := False;
   aSerial := '';
   aSection := '';
   aPrec := '';
   if (Length(w) >= 2) and ModelIsPrecedence(Copy(w, Length(w), 1)) and
      ModelIsDigits(Copy(w, 1, Length(w) - 1)) and (Length(w) - 1 <= 4) then
      begin
      aSerial := Copy(w, 1, Length(w) - 1);
      aPrec := Copy(w, Length(w), 1);
      Result := True;
      Exit;
      end;
   if (Length(w) >= 2) and ModelIsPrecedence(Copy(w, 1, 1)) and ModelIsDigits(Copy(w, 2, 1)) then
      begin
      i := 2;
      while (i <= Length(w)) and ModelIsDigits(Copy(w, i, 1)) do
         begin
         inc(i);
         end;
      aSerial := Copy(w, 2, i - 2);
      aSection := Copy(w, i, Length(w) - i + 1);
      aPrec := Copy(w, 1, 1);
      Result := (Length(aSerial) <= 4) and ((aSection = '') or ModelIsLetters(aSection));
      end;
end;

(* A CHECK JOINED TO ITS SECTION: '31CT'. *)
function ModelCheckSection(const w: string; out aCheck, aSection: string): boolean;
begin
   aCheck := Copy(w, 1, 2);
   aSection := Copy(w, 3, Length(w) - 2);
   Result := (Length(w) > 2) and ModelIsDigits(aCheck) and
             not ModelIsDigits(Copy(w, 3, 1)) and ModelIsLetters(aSection);
end;

(* WHAT THE REFERENCE MODEL SAYS AN ENTRY DOES, as one comparable line. *)
function ModelReading(const aWindowCall: string; const aWords: array of string;
                      aCallsignUpdate: boolean): string;
var
   words: array of string;
   count, i, taken: integer;
   call, serial, prec, check, section, badCheck, message: string;
   js, jsec, jp, cc, csec: string;
   bare2, bareOther, checkSections: array of integer;   (* word positions *)
   hasJoined, ambiguous: boolean;
   candidate1, candidate2: string;
   sectionAt: integer;
begin
   (* STAGE 1: THE CALL CORRECTION. *)
   SetLength(words, Length(aWords));
   for i := 0 to High(aWords) do
      begin
      words[i] := aWords[i];
      end;
   count := Length(words);
   call := aWindowCall;
   if aCallsignUpdate then
      begin
      taken := -1;
      for i := count - 1 downto 0 do
         begin
         if (taken < 0) and ModelLooksLikeCall(words[i]) then
            begin
            taken := i;
            end;
         end;
      if taken >= 0 then
         begin
         call := words[taken];
         if ModelJoined(words[taken], js, jsec, jp) and (jsec <> '') and ModelIsSection(jsec) then
            begin
            Result := 'NO call=' + call + ' msg=' +
                      UnicodeFormat(SExchangeCallOrExchange, [words[taken], js + jp + ' ' + jsec]);
            Exit;
            end;
         for i := taken to count - 2 do
            begin
            words[i] := words[i + 1];
            end;
         dec(count);
         end;
      end;

   (* STAGE 2: THE GRAMMAR. *)
   serial := '';
   prec := '';
   check := '';
   section := '';
   badCheck := '';
   hasJoined := False;
   sectionAt := -1;
   SetLength(bare2, 0);
   SetLength(bareOther, 0);
   SetLength(checkSections, 0);
   for i := 0 to count - 1 do
      begin
      if ModelIsPrecedence(words[i]) then
         begin
         prec := words[i];
         end
      else if ModelJoined(words[i], js, jsec, jp) then
         begin
         hasJoined := True;
         serial := js;
         prec := jp;
         if jsec <> '' then
            begin
            section := jsec;
            sectionAt := i;
            end;
         end
      else if ModelIsDigits(words[i]) then
         begin
         if Length(words[i]) = 2 then
            begin
            SetLength(bare2, Length(bare2) + 1);
            bare2[High(bare2)] := i;
            end
         else if Length(words[i]) <= 4 then
            begin
            SetLength(bareOther, Length(bareOther) + 1);
            bareOther[High(bareOther)] := i;
            end;
         end
      else if ModelCheckSection(words[i], cc, csec) then
         begin
         SetLength(checkSections, Length(checkSections) + 1);
         checkSections[High(checkSections)] := i;
         check := cc;
         section := csec;
         sectionAt := i;
         end
      else
         begin
         (* A section, or a call left in the exchange: the later typed is
            the section (the rule owed a ruling, above). *)
         section := words[i];
         sectionAt := i;
         end;
      end;

   (* THE AMBIGUITY: a standalone precedence, no joined number, no bare
      number that is not two digits. *)
   ambiguous := False;
   candidate1 := '';
   candidate2 := '';
   if (not hasJoined) and (Length(bareOther) = 0) and (prec <> '') then
      begin
      if Length(bare2) = 2 then
         begin
         ambiguous := True;
         candidate1 := words[bare2[0]];
         candidate2 := words[bare2[1]];
         end
      else if (Length(bare2) = 1) and (Length(checkSections) = 1) and
              (checkSections[0] < bare2[0]) then
         begin
         ambiguous := True;
         candidate1 := Copy(words[checkSections[0]], 1, 2);
         candidate2 := words[bare2[0]];
         end;
      end;
   if ambiguous then
      begin
      Result := 'NO call=' + call + ' msg=' +
                UnicodeFormat(SExchangeAmbiguousSerial, [candidate1 + prec, candidate2 + prec]);
      Exit;
      end;

   (* THE SERIAL AND THE CHECK. *)
   if not hasJoined then
      begin
      if Length(bareOther) > 0 then
         begin
         serial := words[bareOther[0]];
         end
      else if Length(bare2) = 1 then
         begin
         serial := words[bare2[0]];
         end;
      end
   else if Length(bareOther) > 0 then
      begin
      badCheck := words[bareOther[0]];
      end;
   if (check = '') and (Length(bare2) = 1) and (serial <> words[bare2[0]]) then
      begin
      check := words[bare2[0]];
      end;
   if check <> '' then
      begin
      badCheck := '';
      end;

   if (serial <> '') and (prec <> '') and (check <> '') and ModelIsSection(section) then
      begin
      Result := 'OK call=' + call + ' n=' + serial + ' p=' + prec + ' c=' + check + ' s=' + section;
      end
   else
      begin
      if prec = '' then
         begin
         message := SExchangeNoPrecedence;
         end
      else if badCheck <> '' then
         begin
         message := UnicodeFormat(SExchangeCheckNotTwoDigits, [badCheck]);
         end
      else if check = '' then
         begin
         message := SExchangeNoCheck;
         end
      else if section = '' then
         begin
         message := SExchangeNoSection;
         end
      else
         begin
         message := '';
         end;
      Result := 'NO call=' + call + ' msg=' + message;
      end;
end;

function TwoDigits(aValue: integer): string;
begin
   Result := IntToStr(aValue);
   if Length(Result) < 2 then
      begin
      Result := '0' + Result;
      end;
end;

(* WHAT THE PROGRAM DOES WITH IT, through the real entry path. *)
function ProgramReading(const aWindowCall: string; const aEntry: string): string;
var
   rx: ContestExchange;
begin
   if Enter(aWindowCall, aEntry, rx) then
      begin
      Result := 'OK call=' + string(rx.Callsign) + ' n=' + IntToStr(rx.NumberReceived) +
                ' p=' + string(rx.Precedence) + ' c=' + TwoDigits(Integer(rx.Check)) +
                ' s=' + string(rx.QTHString);
      end
   else
      begin
      Result := 'NO call=' + string(rx.Callsign) + ' msg=' + string(ExchangeErrorMessage);
      end;
end;

type
   TWordList = array of string;

(* The words of a test entry: single blanks between them, as written. *)
function SplitWords(const aText: string): TWordList;
var
   rest: string;
   at: integer;
begin
   SetLength(Result, 0);
   rest := aText;
   while rest <> '' do
      begin
      at := Pos(' ', rest);
      SetLength(Result, Length(Result) + 1);
      if at = 0 then
         begin
         Result[High(Result)] := rest;
         rest := '';
         end
      else
         begin
         Result[High(Result)] := Copy(rest, 1, at - 1);
         Delete(rest, 1, at);
         end;
      end;
end;

(* THE MODEL, ANCHORED: hand-written readings from the rulings, so a model
   that drifts from NY4I's words fails here before the sweep trusts it. *)
procedure TExchangeWordOrderTests.Test_SweepstakesReferenceModelIsAnchored;

   procedure Pin(const aWindow, aEntry: string; aUpdate: boolean; const aExpected: string);
   begin
      CheckEquals(aExpected, ModelReading(aWindow, SplitWords(aEntry), aUpdate),
                  'model: ' + aEntry);
   end;

const
   ASK = 'Ambiguous entry - A99CT may be a callsign or an exchange. For the exchange, ' +
         'enter 99A CT; for the call, type it in the call window';
begin
   BeginTest('Test_SweepstakesReferenceModelIsAnchored');
   Pin('W1AW', '43 M W1AW 31 CT', True, 'NO call=W1AW msg=Ambiguous exchange - enter 43M or 31M to resolve');
   Pin('W1AW', '43M W1AW 31 CT', True, 'OK call=W1AW n=43 p=M c=31 s=CT');
   Pin('W1AW', '42 M W1AW 31CT', True, 'OK call=W1AW n=42 p=M c=31 s=CT');
   Pin('W1AW', 'A 99CT 32', False, 'NO call=W1AW msg=Ambiguous exchange - enter 99A or 32A to resolve');
   Pin('W1AW', '32 A 99CT', False, 'OK call=W1AW n=32 p=A c=99 s=CT');
   Pin('W1AW', 'A99CT 32', False, 'OK call=W1AW n=99 p=A c=32 s=CT');
   Pin('W1AW', 'A99CT 32', True, 'NO call=A99CT msg=' + ASK);
   Pin('W1AW', 'A99CT 123', False, 'NO call=W1AW msg=Check must be two digits (123)');
   Pin('W1AW', 'A99CT 5', False, 'NO call=W1AW msg=Check must be two digits (5)');
   Pin('W1AW', '31 W1AW CT M 232', True, 'OK call=W1AW n=232 p=M c=31 s=CT');
   Pin('W1AW', '12 W1AW CT M 4', True, 'OK call=W1AW n=4 p=M c=12 s=CT');
   Pin('W1AW', '80 WCF U12', False, 'OK call=W1AW n=12 p=U c=80 s=WCF');
   Pin('K1ABC', 'U12 W1AW 80 CT', True, 'OK call=W1AW n=12 p=U c=80 s=CT');
   Pin('W1AW', 'U12 80 CT W1AW', False, 'NO call=W1AW msg=');
   (* Issue #174, 2026-11-04 bench: a missing section or check says so. *)
   Pin('W1AW', 'A99 32', True, 'NO call=W1AW msg=Missing section');
   Pin('W1AW', '123 A CT', False, 'NO call=W1AW msg=Missing check (two digits)');
end;

(* EVERY ORDERING OF EVERY TOKEN SET, both runnings, CALLSIGN UPDATE on and
   off, against the model. The first 20 disagreements are reported. *)
procedure TExchangeWordOrderTests.Test_SweepstakesEveryOrdering;
const
   TOKEN_SETS: array[0..26] of string = (
      '43 M W1AW 31 CT',
      '43M W1AW 31 CT',
      'M43 W1AW 31 CT',
      '43M W1AW 31CT',
      '43 M W1AW 31CT',
      'A99CT W1AW 32',
      'A99CT 32',
      'A99CT 123',
      'A99CT 5',
      'A99 W1AW 31 CT',
      'A 99CT 32',
      '123 A W1AW 99 CT',
      'U12 W1AW 80 CT',
      '80 WCF U12',
      '232 M 31 CT W1AW',
      '4 M 12 CT',
      '43 M 22 31CT',
      '43 M 43MI',
      'U80WCF 123',
      'U80WCF 32 W1AW',
      '43M W1AW 31 AB',
      '43M 31SB W1AW',
      'U12 80 ORG',
      '12 A 31MI',
      '43M 31 CT A9XYZ',
      (* Issue #174: no section, no check. *)
      'A99 32',
      '123 A CT');
var
   setIndex, i, disagreements, orderings, contestIndex: integer;
   words: TWordList;
   orders: TStringList;
   used: array of boolean;
   chosen: array of string;
   entry, expected, actual, window: string;
   hasCall, update: boolean;
   updateIndex: integer;
   savedCallsignUpdate: boolean;
   contests: array[0..1] of ContestType;
   report: TStringList;
   reportPath: string;

   procedure Permute(aDepth: integer);
   var
      k: integer;
      line: string;
   begin
      if aDepth = Length(words) then
         begin
         line := chosen[0];
         for k := 1 to High(chosen) do
            begin
            line := line + ' ' + chosen[k];
            end;
         orders.Add(line);
         Exit;
         end;
      for k := 0 to High(words) do
         begin
         if not used[k] then
            begin
            used[k] := True;
            chosen[aDepth] := words[k];
            Permute(aDepth + 1);
            used[k] := False;
            end;
         end;
   end;

   procedure RunOne(const aWindow: string);
   begin
      expected := ModelReading(aWindow, SplitWords(entry), update);
      actual := ProgramReading(aWindow, entry);
      if report <> nil then
         begin
         report.Add(string(ContestTypeSA[contests[contestIndex]]) + ' update=' +
                    BoolToStr(update, True) + ' window=' + aWindow + ' [' + entry + '] ' + actual);
         end;
      if expected <> actual then
         begin
         inc(disagreements);
         if disagreements <= 20 then
            begin
            CheckEquals(expected, actual, string(ContestTypeSA[contests[contestIndex]]) +
                        ' update=' + BoolToStr(update, True) + ' window=' + aWindow +
                        ' [' + entry + ']');
            end;
         end;
   end;

begin
   BeginTest('Test_SweepstakesEveryOrdering');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   contests[0] := ARRLSSCW;
   contests[1] := ARRLSSSSB;
   disagreements := 0;
   orderings := 0;
   (* A DIAGNOSTIC: every reading, for a report, when asked for. *)
   report := nil;
   reportPath := GetEnvironmentVariable('TR4W_SS_ORDERING_REPORT');
   if reportPath <> '' then
      begin
      report := TStringList.Create;
      end;
   orders := TStringList.Create;
   try
      orders.Sorted := True;
      orders.Duplicates := dupIgnore;
      for contestIndex := 0 to 1 do
         begin
         SetUpSession(contests[contestIndex], DomesticCountriesARRLSections, 'arrlsect.dom');
         savedCallsignUpdate := Settings.CallWindow.CallsignUpdateEnable;
         try
            for setIndex := Low(TOKEN_SETS) to High(TOKEN_SETS) do
               begin
               words := SplitWords(TOKEN_SETS[setIndex]);
               SetLength(used, Length(words));
               SetLength(chosen, Length(words));
               for i := 0 to High(used) do
                  begin
                  used[i] := False;
                  end;
               orders.Clear;
               Permute(0);
               hasCall := False;
               for i := 0 to High(words) do
                  begin
                  if ModelLooksLikeCall(words[i]) then
                     begin
                     hasCall := True;
                     end;
                  end;
               for i := 0 to orders.Count - 1 do
                  begin
                  entry := orders[i];
                  inc(orderings);
                  for updateIndex := 0 to 1 do
                     begin
                     update := updateIndex = 0;
                     if update or hasCall then
                        begin
                        Settings.CallWindow.CallsignUpdateEnable := update;
                        (* (1) the same call in the window, (2) another. *)
                        RunOne('W1AW');
                        if Pos('W1AW', entry) > 0 then
                           begin
                           RunOne('K1ABC');
                           end;
                        end;
                     end;
                  end;
               end;
         finally
            Settings.CallWindow.CallsignUpdateEnable := savedCallsignUpdate;
            RestoreSession;
         end;
         end;
      CheckEquals(0, disagreements, IntToStr(disagreements) + ' disagreement(s) over ' +
                  IntToStr(orderings) + ' ordering(s)');
      if report <> nil then
         begin
         report.SaveToFile(reportPath);
         end;
   finally
      orders.Free;
      report.Free;
   end;
end;

(* ---------------------------------------------------------------------------
   #170 -- NA SPRINT
   --------------------------------------------------------------------------- *)

procedure TExchangeWordOrderTests.Test_SprintStateBeforeTheName;
var
   rx: ContestExchange;
   accepted: boolean;

   procedure CheckTaken(const aExch: string; aNumber: integer;
                        const aName: string; const aQTH: string);
   begin
      accepted := Enter('N4AF', aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aNumber, Integer(rx.NumberReceived), aExch + ': the serial');
      CheckEquals(aName, string(rx.Name), aExch + ': the name');
      CheckEquals(aQTH, string(rx.QTHString), aExch + ': the QTH, and nothing of the name in it');
      CheckEquals(aQTH, UpperCase(string(rx.DomMultQTH)), aExch + ': the multiplier');
      CheckTrue(rx.DomesticQTH <> '', aExch + ': the domestic QTH is set');

      (* AND IT IS A DOMESTIC MULTIPLIER -- the issue's "Domestic Exchange is
         not set" -- on an empty sheet, as LogContact would ask. *)
      rx.ceRecordKind := rkQSO;
      rx.ceContest := Contest;
      mo.ClearAllMults;
      Sheet.SetMultFlags(rx);
      CheckTrue(rx.DomesticMult, aExch + ': a new domestic multiplier');
   end;

begin
   BeginTest('Test_SprintStateBeforeTheName');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   (* NASprintCW.DescribeSession: K and VE, then KL; its file is naqp. *)
   SetUpSession(NASPRINTCW, ['K', 'VE', 'KL'], 'naqp.dom');
   try
      (* THE REPORTER'S CONTROL: "ALAN FL 3 ... showed up ok". *)
      CheckTaken('ALAN FL 3', 3, 'ALAN', 'FL');
      CheckTaken('3 ALAN FL', 3, 'ALAN', 'FL');
      (* THE REPORTED ENTRY: "FL TOM 4 ... showed as FLM". *)
      CheckTaken('FL TOM 4', 4, 'TOM', 'FL');
      CheckTaken('4 FL TOM', 4, 'TOM', 'FL');
   finally
      mo.ClearAllMults;
      RestoreSession;
   end;
end;

(* ---------------------------------------------------------------------------
   #169 -- NAQP
   --------------------------------------------------------------------------- *)

procedure TExchangeWordOrderTests.Test_NAQPStateAndNameInEitherOrder;
var
   rx: ContestExchange;
   accepted: boolean;

   procedure CheckTaken(const aCall: string; const aExch: string;
                        const aName: string; const aQTH: string);
   begin
      accepted := Enter(aCall, aExch, rx);
      CheckTrue(accepted, aExch + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aName, string(rx.Name), aExch + ': the name');
      CheckEquals(aQTH, string(rx.QTHString), aExch + ': the QTH');
   end;

begin
   BeginTest('Test_NAQPStateAndNameInEitherOrder');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   (* NAQPCW.DescribeSession: K, VE, KH6, KL; its file is naqp. *)
   SetUpSession(NAQSOCW, DomesticCountriesKVEKH6KL, 'naqp.dom');
   try
      (* THE NAME FIRST, as always. *)
      CheckTaken('N4AF', 'TOM FL', 'TOM', 'FL');
      CheckEquals('FL', UpperCase(string(rx.DomMultQTH)), 'TOM FL: the multiplier');

      (* THE STATE FIRST -- the issue. *)
      CheckTaken('N4AF', 'FL TOM', 'TOM', 'FL');
      CheckEquals('FL', UpperCase(string(rx.DomMultQTH)), 'FL TOM: the multiplier');
      CheckTrue(rx.DomesticQTH <> '', 'FL TOM: the domestic QTH is set');
      CheckTaken('N4AF', 'ON BOB', 'BOB', 'ON');

      (* A NAME THAT IS ALSO A QTH ("Del in DE or Cal in CA"): where both
         readings are a QTH, the name is first, as it always was. Only where
         the name-first reading has no QTH is the other order tried. *)
      CheckTaken('N4AF', 'DE CA', 'DE', 'CA');
      CheckTaken('N4AF', 'CA DE', 'CA', 'DE');
      CheckTaken('N4AF', 'DE TOM', 'TOM', 'DE');
      CheckTaken('N4AF', 'AL WI', 'AL', 'WI');

      (* A DX STATION HAS NO QTH TO JUDGE, so its words are read name first
         whatever they are -- unchanged. *)
      CheckTaken('DL1AAA', 'HANS', 'HANS', '');
      CheckTaken('DL1AAA', 'FL TOM', 'FL', 'TOM');

      (* STILL REFUSED. *)
      accepted := Enter('N4AF', 'TOM XX', rx);
      CheckFalse(accepted, 'TOM XX: no QTH either way');
      CheckEquals('XX', string(rx.QTHString), 'TOM XX: the refusal is the second word''s, as before');
      accepted := Enter('N4AF', 'XX TOM', rx);
      CheckFalse(accepted, 'XX TOM: no QTH either way');
      CheckEquals('TOM', string(rx.QTHString), 'XX TOM: the refusal is the second word''s, as before');
      accepted := Enter('N4AF', 'FL', rx);
      CheckFalse(accepted, 'FL alone: a QTH and no name');
      (* A NAME IS LETTERS: a QTH and a number is no name and a state --
         the contest matrix's 'CT 123' and 'CT 2A' rows, refused before. *)
      accepted := Enter('N4AF', 'CT 123', rx);
      CheckFalse(accepted, 'CT 123: 123 is no name');
      CheckEquals('123', string(rx.QTHString), 'CT 123: refused for the second word, as before');
      accepted := Enter('N4AF', 'CT 2A', rx);
      CheckFalse(accepted, 'CT 2A: 2A is no name');
      accepted := Enter('N4AF', 'FL TOM BOB', rx);
      CheckFalse(accepted, 'FL TOM BOB: a third word is a corrected name, and TOM is no QTH');
   finally
      RestoreSession;
   end;
end;

(* THE MULTIPLIER IS THE SECTION, NEVER THE CHECK -- NY4I bench, ARRL SS SSB,
   2026-11-04. After W7ST (33M 18 UT) was logged the "Mult needs for" header
   read '18 UT'. The QSO itself was right: this pins that the parse and the
   sheet hold the section alone, that the remembered exchange the header is
   built from is check + section (as it should be, for the prefill), and that
   the contest's hint answers the section from it. *)
procedure TExchangeWordOrderTests.Test_SweepstakesMultiplierHintIsTheSection;
var
   rx: ContestExchange;
   accepted: boolean;
   savedFields: ExchangeInformationRecord;
   remembered: string;

   procedure CheckHint(const aText: string; const aExpected: string);
   var
      hint: string;
      i: integer;
   begin
      hint := ContestDomesticMultiplierHint(ActiveContest(Contest), Str14(aText));
      CheckEquals(aExpected, hint, 'the hint for ' + aText);
      for i := 1 to Length(hint) do
         begin
         CheckFalse(hint[i] in ['0'..'9'], 'the hint for ' + aText + ' holds no digit of the check');
         end;
   end;

begin
   BeginTest('Test_SweepstakesMultiplierHintIsTheSection');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpSession(ARRLSSCW, DomesticCountriesARRLSections, 'arrlsect.dom');
   savedFields := ExchangeInformation;
   try
      (* THE ENTRY AS NY4I TYPED IT, through live entry. *)
      accepted := Enter('W7ST', '33M 18 UT', rx);
      CheckTrue(accepted, '33M 18 UT is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(18, Integer(rx.Check), 'the check');
      CheckEquals('UT', string(rx.QTHString), 'the section');
      (* arrlsect.dom spells it 'Ut = UT': the left side is the multiplier. *)
      CheckEquals('UT', UpperCase(string(rx.DomesticQTH)), 'the domestic QTH is the section alone');
      CheckEquals('UT', UpperCase(string(rx.DomMultQTH)), 'the domestic multiplier is the section alone');

      (* THE SHEET'S FILL leaves it so -- what the Mults window counts. *)
      mo.ClearAllMults;
      Sheet.SetMultFlags(rx);
      CheckEquals('UT', UpperCase(string(rx.DomMultQTH)), 'after SetMultFlags, still the section alone');
      mo.ClearAllMults;

      (* THE REMEMBERED EXCHANGE is check + section, as uProgramMain's field
         list makes it -- the prefill when W7ST is worked again. *)
      ExchangeInformation := ContestReceivedExchangeFields(ActiveContest(Contest));
      remembered := GetInitialExchangeStringFromContestExchange(rx);
      CheckEquals('18 UT', remembered, 'the remembered exchange');

      (* WHAT THE HEADER IS HANDED: the section's MULTIPLIER KEY, as the
         list spells it (issue 207) -- the header upper-cases it to show. *)
      CheckEquals('Ut', DomStringParse(Str14(remembered)), 'DomStringParse of the remembered exchange');
      CheckHint('18 UT', 'UT');
      (* A check of 07 is remembered as '7' (IntToStr). *)
      CheckHint('7 UT', 'UT');
      CheckHint('59 WCF', 'WCF');
      (* NO SECTION, NO HINT -- ShowNeedsForCall then shows no header. *)
      CheckHint('18', '');
      CheckHint('', '');
      (* A WORD NO SECTION FILE HAS: the hint reads the SHAPE, as every hint
         does; the check still never reaches it. *)
      CheckHint('18 ZZ', 'ZZ');

      (* BOTH RUNNINGS: the rule is the family's. *)
      Contest := ContestHandleOf(ARRLSSSSB);
      ReleaseActiveContest;
      CheckHint('18 UT', 'UT');
      CheckHint('32 IN', 'IN');
   finally
      ExchangeInformation := savedFields;
      RestoreSession;
   end;
end;

(* ISSUE 210 -- ALL JA's remembered exchange for a QSO logged with no
   precedence began with a NUL (and a space). The text is only the prefill
   a repeat call is offered; it is never written to ADIF or Cabrillo. *)
procedure TExchangeWordOrderTests.Test_ALLJARememberedExchangeHasNoNul;
var
   rx: ContestExchange;
   savedKind: ExchangeType;
begin
   BeginTest('Test_ALLJARememberedExchangeHasNoNul');
   savedKind := ContestSession.Exchange;
   ContestSession.WriteExchange(RSTALLJAPrefectureAndPrecedenceExchange);
   try
      rx := Default(ContestExchange);
      rx.QTHString := '01';

      rx.Precedence := #0;
      CheckEquals('01', string(GetInitialExchangeStringFromContestExchange(rx)),
                  'no precedence: the prefecture alone, no NUL and no space');

      rx.Precedence := 'A';
      CheckEquals('A 01', string(GetInitialExchangeStringFromContestExchange(rx)),
                  'a precedence is still put first');
   finally
      ContestSession.WriteExchange(savedKind);
   end;
end;

procedure TExchangeWordOrderTests.RunAllTests;
begin
   Test_ALLJARememberedExchangeHasNoNul;
   Test_SweepstakesMultiplierHintIsTheSection;
   Test_SweepstakesPrecedenceBeforeTheSerial;
   Test_SweepstakesAmbiguousSerialIsRefused;
   Test_SweepstakesReferenceModelIsAnchored;
   Test_SweepstakesEveryOrdering;
   Test_SprintStateBeforeTheName;
   Test_NAQPStateAndNameInEitherOrder;
end;

end.
