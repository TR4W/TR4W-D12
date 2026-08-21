{
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
}
unit uDXSpotParse;
{$I tr4w.inc}

{
  DECODE one DX cluster spot line into a TSpotRecord.  Nothing else.

  WHY THIS UNIT EXISTS.  This code was the first half of uTelnet.ProcessDX,
  which decoded AND applied in one 313-line function: it read the line and went
  on to check the log for a dupe, check the multiplier, add to the band map,
  search the alert list box and beep.  That mixture is why the decoder had
  no test -- linking it meant linking VisibleLog, SpotsList, MainUnit and the
  window layer.  Everything here is a pure function of the line: no globals, no
  I/O, no window handles, so it links into tr4w_unit_tests.exe.  ProcessDX keeps
  the apply half and calls in here for the decode.

  THE COLUMN ARITHMETIC IS UNCHANGED, DELIBERATELY.  Every offset below is
  copied verbatim from ProcessDX.  Those numbers are tuned against what real
  cluster nodes emit and were never covered by a test, so the extraction moved
  them without touching them; behaviour was pinned first (uTestDXSpotParse).

  WHAT HAS CHANGED SINCE, deliberately and each with its own tests:

    * The DX call is now REQUIRED.  A line cut off before the call columns used
      to decode as a success, and the caller would band-map a spot with an empty
      callsign.
    * FSourceCall's length byte is now always written.  It used to be set only
      when the spotter field was unpadded, so on nearly every line the field
      held the right characters and reported a length of zero.
    * The comment's split/QSX grammar is a tokenizer (ParseSplitHint) rather
      than two hand-rolled scans for "QSX " and "UP".  It reads DOWN, LSN,
      LISTENING, SPLIT and RX, MHz and dotted-MHz frequencies, fractional
      offsets, and applies ONE band check to every form.

  The format, measured over 198,979 real "DX de" lines captured from AR-Cluster
  and DXSpider nodes (corpus_test_data/local_test_data/dxcluster):

     0         1         2         3         4         5         6         7
     0123456789012345678901234567890123456789012345678901234567890123456789012345
     DX de W1FM:       3729.8  EA7IXM       PAC0 PAGA L0S 10 MIL EUR0S DE  1713Z

  The frequency is RIGHT-justified so its decimal point lands on column 22 --
  198,977 of those 198,979 lines put it exactly there.  `Offset` below is the
  correction for the rest: a spotter callsign too long for the field shoves the
  frequency right, e.g.

     DX de 3V/KF5EYY-#:14007.0  PA3DZM      CW 20 DB 33 WPM CQ          PA 1941Z

  which puts the point on 23, and the DX call one column further along.  That
  is what the four `Offset :=` tests are compensating for.
}

interface

uses
   VC;

// Decode a complete cluster line.  Returns False -- leaving Spot partly filled
// and NOT usable -- when the line does not decode: an absurd frequency, no DX
// call in the call columns at all, or a DX call that fails IsAGoodCall.
//
// Fills FFrequency, FFreqString, FCall, FSourceCall, FNotes and FQSXFrequency.
// FBand/FMode are left NoBand/NoMode: the band-map band/mode mapping is a
// SETTING (GetBandMapBandModeFromFrequency), not a property of the line, so it
// stays on the apply side.  FDupe, FMult, FSysTime and FMinutesLeft likewise
// depend on the log and the clock, not on the line.
function ParseDXSpotLine(const Line: AnsiString; out Spot: TSpotRecord): boolean;

// Does this line from the node ask for a password?
//
// Lives here, with the other line decoders, because it is the decision that
// puts the operator's PASSWORD on the wire -- not something to bury inside a
// window procedure where it cannot be tested.
//
// Grounded in the 209-file capture corpus rather than in a guess:
//
//  - Matched as a SUBSTRING.  Prompts carry no line terminator, so they arrive
//    joined to whatever followed them (`login: nected to VE7CC-1:` is in the
//    corpus verbatim).  A whole-line test would miss exactly the case this
//    exists for.
//  - The COLON is what separates a prompt from traffic that merely mentions
//    passwords.  The corpus contains `set/password` and "Pse Set password on
//    internet connects with set/password"; neither contains "password:", and
//    neither may cause a send.
//  - English only, and deliberately so.  `login:` and `password:` come from the
//    protocol layer: a Spanish DXSpider node that prints its whole banner in
//    Basque, English and Spanish still prompts in English.  The PROSE forms
//    ("Enter your callsign") are sysop text and DO get translated -- which is
//    why the callsign is sent unprompted and never matched at all.
function LineAsksForPassword(const Line: AnsiString): boolean;

// Does this line ask for the callsign?
//
// `login:` ONLY, deliberately.  It is a protocol token and it survives
// translation -- the Spanish DXSpider node above prints it in English while
// translating everything around it.  The prose forms the corpus also contains
// ("Enter your callsign", 228 lines; "Please enter your call:", 52) are sysop
// banner text that a localised node DOES translate, so matching them would work
// here and fail on somebody else's node.
//
// Nodes that prompt in prose, or do not prompt at all, are covered by a TIMEOUT
// in uTelnet rather than by widening this list.  A timer cannot be wrong about
// a language; a word list can.
function LineAsksForLogin(const Line: AnsiString): boolean;

// The "1713Z" stamp at the end of the line, as minutes since midnight UTC.
// Returns False when column 74 is not 'Z', which is how ProcessDX decides the
// line carries no usable time and falls back to the current clock.  Split out
// rather than folded into ParseDXSpotLine because the caller has to combine it
// with today's date from the UTC global to get a comparable timestamp.
function ParseDXSpotTimeUTC(const Line: AnsiString; out MinuteOfDay: integer): boolean;

// Read a split / QSX hint out of a spot's COMMENT field.
//
// Returns True and the DX station's receive frequency in Hz when the comment
// states one unambiguously; False when it says nothing, or says something the
// grammar refuses to guess at.  `BaseFrequencyHz` is the spot's own transmit
// frequency, which the relative forms ("UP 5") are measured from.
//
// Exported so it can be tested against a comment directly rather than through a
// 75-column line, and so other spot sources (WSJT-X, the band map, a future
// non-AK1A cluster) can reuse one implementation of this grammar.
//
// GRAMMAR -- case-insensitive, first recognised hint wins:
//
//   introducer  QSX | LISTENING | LISTENS | LISTEN | LSTN | LSN | RX | SPLIT
//               | SPLT | SPL
//   direction   UP | DOWN | DWN | DN
//
//   <introducer> <number>              absolute frequency, or -- exactly as the
//                                      original decoder did -- an UP offset when
//                                      the value is under 10 kHz ("QSX 5")
//   <introducer> <direction> <number>  offset in the named direction
//   <direction> <number>               offset ("UP 5", "UP5", "DOWN 2")
//   <direction> | SPLIT                AUTO SPLIT: 1 kHz up on CW, 5 kHz on
//                                      phone, nothing on digital or an unknown
//                                      mode
//
// Numbers may be kHz ("7275.10", "7082"), MHz ("14.030"), or MHz written with
// dotted grouping ("21.290.000").  A range takes its LOW end ("UP 5-10" = 5).
//
// `BandPlanMode` is the fallback mode for the AUTO SPLIT default; a mode named
// in the comment itself ("CW", "USB", "FT8") overrides it.
//
// WHAT IT DELIBERATELY REFUSES.  "NOT SPLIT" is not a split.  A bare "QSX" or
// "LISTENING" -- an introducer whose frequency is simply missing -- is not
// turned into a guess, unlike a bare direction, where the AUTO SPLIT convention
// gives a real answer.  And any result landing outside every amateur band is
// dropped rather than reported.
function ParseSplitHint(const Comment: AnsiString; BaseFrequencyHz: integer;
                        BandPlanMode: ModeType;
                        out QSXFrequencyHz: integer): boolean;

implementation

uses
   Windows,
   SysUtils,            // LowerCase -- the RTL, not a TF shim
   uBandLookup,         // CalculateBandMode -- tree.pas forwards to this unit
   uCallSignRoutines;   // IsAGoodCall

const
   // The token, in one place.  Lower case because the test lower-cases the line
   // first; nodes are inconsistent about capitalising it.
   CLUSTER_PASSWORD_TOKEN = 'password:';
   CLUSTER_LOGIN_TOKEN    = 'login:';

type
   // The line, NUL-filled, so a read past its end sees a terminator exactly as
   // it did when this walked the NUL-terminated receive buffer.  1024 is far
   // beyond any real cluster line (~80-120 chars).
   TDXLineBuf = array[0..1023] of AnsiChar;

function LineAsksForPassword(const Line: AnsiString): boolean;
begin
   Result := Pos(CLUSTER_PASSWORD_TOKEN, LowerCase(string(Line))) > 0;
end;

function LineAsksForLogin(const Line: AnsiString): boolean;
var
   lower: string;
begin
   lower := LowerCase(string(Line));

   // NOT when the same line also asks for a password.  A prompt can arrive
   // smeared into the line before it, so `login: ... password:` in one delivery
   // is possible -- and answering the LOGIN half of that would send the callsign
   // where the password was wanted.  The later prompt is the live one.
   Result := (Pos(CLUSTER_LOGIN_TOKEN, lower) > 0)
             and (Pos(CLUSTER_PASSWORD_TOKEN, lower) = 0);
end;

procedure LineToBuf(const Line: AnsiString; var Buf: TDXLineBuf);
var
   copyLen: integer;
begin
   Windows.ZeroMemory(@Buf, SizeOf(Buf));
   copyLen := Length(Line);
   if copyLen > SizeOf(Buf) - 1 then
      begin
      copyLen := SizeOf(Buf) - 1;
      end;
   if copyLen > 0 then
      begin
      Move(Line[1], Buf[0], copyLen);
      end;
end;

{ ---------------------------------------------------------------------------
  The split / QSX comment grammar.

  WHY A TOKENIZER RATHER THAN MORE OFFSET TESTS.  What was here compared four
  bytes at a fixed position for "QSX ", then separately walked the comment
  looking for a "UP" with a space in front of it.  Every additional spelling --
  DOWN, LSN, SPLIT, "QSX UP 5" -- would have been another hand-rolled scan with
  its own boundary bug, which is exactly how "UP7" and "UP10" came to be
  silently dropped while UP1..UP5 worked.  Reading the comment into words once,
  and then stating the grammar over those words, is the same amount of code and
  admits new spellings without new scanning.

  THE VOCABULARY IS MEASURED, NOT IMAGINED.  Every keyword below was counted in
  the 198,979 captured "DX de" lines in corpus_test_data/local_test_data/dxcluster:
  QSX 548, UP 436, SPLIT 19, LISTENING 14, LSN 3, LSTN 1, DOWN 2.

  NOTE ON "R" AND "RX".  The brief asked for RX/R receive hints.  RX is
  accepted; bare **R is not**, on the evidence: all 13 "R" and all 11 "RX"
  occurrences in the capture are noise -- FT8 signal reports ("R-17"), "RX
  ONLY", "P.R.".  A bare R would turn every FT8 report into a bogus QSX.  RX is
  kept only because the band check below makes it harmless: "RX -15" reads as
  15 kHz, which is in no band, so nothing is emitted.
  --------------------------------------------------------------------------- }

const
   MAXCOMMENTTOKENS = 32;

   // The largest number that will be read as a split OFFSET rather than
   // discarded.  HF splits run a few kHz; 50 is already generous for the
   // biggest pileup.  Above it, a number after a direction word is far more
   // likely to be a signal report, a "73", or a truncated frequency.
   MAXSPLITOFFSETKHZ = 50;

type
   TCommentTokenKind = (ctWord, ctNumber);

   TCommentToken = record
      Kind: TCommentTokenKind;
      Text: AnsiString;         // words are upper-cased; numbers are digits + '.'
      // True when this token started immediately after the previous one, with no
      // separator between them.  "DM33UP" is three GLUED tokens; "5 UP" is two
      // that are not.  The distinction is load-bearing: without it the grid
      // square DM33UP ends in a token spelled UP, and a routine 6 m grid comment
      // becomes a split instruction.  See KeywordIsWholeWord.
      Glued: boolean;
   end;

   TCommentTokens = array[0..MAXCOMMENTTOKENS - 1] of TCommentToken;

   // What a keyword means once synonyms are folded together.
   //
   // skSplit is separated from skIntroducer for one reason: "SPLIT" on its own
   // is a complete statement to an operator (see AutoSplitOffsetHz), where a
   // bare "QSX" is just a missing frequency.
   TSplitKeyword = (skNone, skIntroducer, skSplit, skUp, skDown);

// Break a comment into WORDS (letters) and NUMBERS (digits and '.').  Anything
// else separates.
//
// A '-' separates, which is what makes a range read as its LOW end for free:
// "UP 5-10" tokenizes to UP, 5, 10 and the grammar takes the first number after
// the direction.  It also keeps "R-17" from reading as one token.
function TokenizeComment(const S: AnsiString; var Toks: TCommentTokens): integer;
var
   i: integer;
   c: AnsiChar;
   prevEnd: integer;   // index just past the previous token, for Glued
begin
   Result := 0;
   i := 1;
   prevEnd := -1;
   while (i <= Length(S)) and (Result < MAXCOMMENTTOKENS) do
      begin
      c := UpCase(S[i]);
      if c in ['A'..'Z'] then
         begin
         Toks[Result].Kind := ctWord;
         Toks[Result].Glued := (i = prevEnd);
         Toks[Result].Text := '';
         while (i <= Length(S)) and (UpCase(S[i]) in ['A'..'Z']) do
            begin
            Toks[Result].Text := Toks[Result].Text + UpCase(S[i]);
            Inc(i);
            end;
         prevEnd := i;
         Inc(Result);
         end
      else if c in ['0'..'9'] then
         begin
         Toks[Result].Kind := ctNumber;
         Toks[Result].Glued := (i = prevEnd);
         Toks[Result].Text := '';
         while (i <= Length(S)) and (S[i] in ['0'..'9', '.']) do
            begin
            Toks[Result].Text := Toks[Result].Text + S[i];
            Inc(i);
            end;
         prevEnd := i;
         // A trailing point is punctuation, not a decimal: "UP 5." is 5.
         while (Length(Toks[Result].Text) > 0) and
               (Toks[Result].Text[Length(Toks[Result].Text)] = '.') do
            begin
            SetLength(Toks[Result].Text, Length(Toks[Result].Text) - 1);
            end;
         Inc(Result);
         end
      else
         begin
         Inc(i);
         end;
      end;
end;

function KeywordOf(const W: AnsiString): TSplitKeyword;
begin
   if (W = 'QSX') or (W = 'LISTENING') or (W = 'LISTENS') or (W = 'LISTEN') or
      (W = 'LSTN') or (W = 'LSN') or (W = 'RX') then
      begin
      Result := skIntroducer;
      end
   else if (W = 'SPLIT') or (W = 'SPLT') or (W = 'SPL') then
      begin
      Result := skSplit;
      end
   else if W = 'UP' then
      begin
      Result := skUp;
      end
   // "DN" is NOT here, and that is a measurement, not an oversight.  Every one
   // of its occurrences in the 198,979-line capture is a Maidenhead grid square
   // -- DN70, DN27, DN30, DN13 ... -- because letters and digits tokenize
   // separately.  Accepting it as "down" turned ordinary 6 m grid comments into
   // splits: "DN70MQ<>BL01XI" became "70 kHz down".
   else if (W = 'DOWN') or (W = 'DWN') then
      begin
      Result := skDown;
      end
   else
      begin
      Result := skNone;
      end;
end;

// Is this keyword token a word in its own right, rather than the tail of a
// longer alphanumeric run?
//
// Grid squares are why this exists.  "DM33UP" tokenizes to DM, 33, UP, and that
// trailing UP must not be read as a direction; "FN31RX" likewise.  A keyword
// counts when it starts a run, or when the run is exactly <number><DIRECTION> --
// which is the real and common "5UP".
//
// Only a DIRECTION may be glued to its number.  "5UP" is a form people write;
// "5QSX" is not, and allowing it read the VHF comment "3RX 4 ANT DIR" as
// "receive on 4" and moved the operator 4 kHz.
function KeywordIsWholeWord(const Toks: TCommentTokens; Index: integer;
                            Kind: TSplitKeyword): boolean;
begin
   if not Toks[Index].Glued then
      begin
      Result := True;
      Exit;
      end;
   Result := (Kind in [skUp, skDown]) and
             (Index > 0) and (Toks[Index - 1].Kind = ctNumber) and
             (not Toks[Index - 1].Glued);
end;

// Does this word turn a following "UP" into ordinary English rather than a split
// instruction?
//
// All of these are in the capture, one occurrence each: MESSED UP, COMING UP,
// WARMING UP, GOING UP, PILE UP, WHATS UP.  The -ING / -ED test covers the
// phrasal verbs as a class instead of chasing them one at a time (and catches
// "WAMING UP", which is how one of them was actually spelled).
//
// It is consulted ONLY for the AUTO SPLIT default.  A comment that states a
// distance -- even "PILE UP 5" -- is still taken at its word, so this can cost
// nothing but a guess.
function WordMakesUpEnglish(const W: AnsiString): boolean;
var
   n: integer;
begin
   Result := (W = 'PILE') or (W = 'WHATS');
   if Result then
      begin
      Exit;
      end;
   n := Length(W);
   Result := ((n >= 5) and (Copy(W, n - 2, 3) = 'ING')) or
             ((n >= 5) and (Copy(W, n - 1, 2) = 'ED'));
end;

// Words that may stand between an introducer and its frequency: "LISTENING ON
// 7227.00", "QSX AT 14205".  Without this the number is never reached and the
// comment falls through to a guess -- which is what happened to "LISTENING ON
// 7227.00 SPLIT LSB": it answered 5 kHz up while the frequency sat in the text.
function IsFillerWord(const W: AnsiString): boolean;
begin
   Result := (W = 'ON') or (W = 'AT') or (W = 'TO');
end;

// Split a number token into its integer part and its fraction digits, with the
// DOT COUNT, which is what tells the three written forms apart:
//
//   7275.10      one dot,  integer part >= 1000  -> kHz
//   14.030       one dot,  integer part <  1000  -> MHz
//   21.290.000   two dots                        -> MHz, dotted grouping,
//                                                   so the groups after the
//                                                   first are one fraction
//
// Returns False on a token with no digits, or one long enough to be a typo
// rather than a frequency.
function SplitNumber(const T: AnsiString; out IntPart: integer;
                     out Frac: AnsiString; out Dots: integer): boolean;
var
   i: integer;
   digits: AnsiString;
begin
   Result := False;
   IntPart := 0;
   Frac := '';
   Dots := 0;
   digits := '';

   for i := 1 to Length(T) do
      begin
      if T[i] = '.' then
         begin
         Inc(Dots);
         end
      else if T[i] in ['0'..'9'] then
         begin
         if Dots = 0 then
            begin
            digits := digits + T[i];
            end
         else
            begin
            Frac := Frac + T[i];
            end;
         end;
      end;

   // 9 integer digits is already 100x any amateur frequency in kHz; anything
   // longer is not a frequency and must not be allowed to overflow below.
   if (digits = '') or (Length(digits) > 9) then
      begin
      Exit;
      end;

   for i := 1 to Length(digits) do
      begin
      IntPart := IntPart * 10 + (Ord(digits[i]) - Ord('0'));
      end;
   Result := True;
end;

// Scale a fraction to `Places` digits: '5' with 3 places is 500, '9015' with 3
// places is 901 (extra digits are dropped, not rounded -- the original decoder
// truncated too).
function ScaleFraction(const Frac: AnsiString; Places: integer): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 1 to Places do
      begin
      Result := Result * 10;
      if i <= Length(Frac) then
         begin
         Result := Result + (Ord(Frac[i]) - Ord('0'));
         end;
      end;
end;

// A number token read as an ABSOLUTE frequency, in Hz.  Returns False when the
// token is not a frequency at all.
function AbsoluteHz(const T: AnsiString; out Hz: integer): boolean;
var
   IntPart, Dots: integer;
   Frac: AnsiString;
begin
   Result := False;
   Hz := 0;
   if not SplitNumber(T, IntPart, Frac, Dots) then
      begin
      Exit;
      end;

   if (Dots >= 2) or ((Dots = 1) and (IntPart < 1000)) then
      begin
      // MHz.  Guard the multiply: 4,000 MHz is already past the top band.
      if IntPart > 4000 then
         begin
         Exit;
         end;
      Hz := IntPart * 1000000 + ScaleFraction(Frac, 6);
      end
   else
      begin
      // kHz.
      if IntPart > 2000000 then
         begin
         Exit;
         end;
      Hz := IntPart * 1000 + ScaleFraction(Frac, 3);
      end;
   Result := Hz > 0;
end;

// A number token read as MHz whatever its shape, for when the comment spells
// the unit out: "QSX UP 18.072 MHZ".  Without this the 18.072 reads as an
// 18 kHz offset and the operator lands 15 kHz away from the DX.
function ForcedMHzHz(const T: AnsiString; out Hz: integer): boolean;
var
   IntPart, Dots: integer;
   Frac: AnsiString;
begin
   Result := False;
   Hz := 0;
   if not SplitNumber(T, IntPart, Frac, Dots) then
      begin
      Exit;
      end;
   if IntPart > 4000 then
      begin
      Exit;
      end;
   Hz := IntPart * 1000000 + ScaleFraction(Frac, 6);
   Result := Hz > 0;
end;

// Does the word after a number spell out MHz?
function UnitIsMHz(const Toks: TCommentTokens; n, Index: integer): boolean;
begin
   Result := (Index + 1 < n) and (Toks[Index + 1].Kind = ctWord) and
             ((Toks[Index + 1].Text = 'MHZ') or (Toks[Index + 1].Text = 'MC'));
end;

// A number token read as an OFFSET, in Hz: "5" is 5 kHz, "5.5" is 5.5 kHz.
//
// Refuses anything over MAXSPLITOFFSETKHZ.  Two real cases need that ceiling,
// and neither is served by guessing:
//
//   "UP 200-205" on 14195 -- 200 kHz up is 14395, outside the band.  Almost
//   certainly the spotter meant 14200-14205 and wrote the last three digits.
//   Ambiguous, so nothing is emitted.  (The old decoder emitted 14395.)
//
//   "59 TU 73 UP LOUD OHIO" -- the postfix form below would read the signal
//   report and the "73" as offsets.  Nobody splits 73 kHz.
function OffsetHz(const T: AnsiString; out Hz: integer): boolean;
var
   IntPart, Dots: integer;
   Frac: AnsiString;
begin
   Result := False;
   Hz := 0;
   if not SplitNumber(T, IntPart, Frac, Dots) then
      begin
      Exit;
      end;
   if (IntPart > MAXSPLITOFFSETKHZ) or (Dots >= 2) then
      begin
      Exit;
      end;
   Hz := IntPart * 1000 + ScaleFraction(Frac, 3);
   Result := Hz > 0;
end;

// The mode a comment states about itself, if it states one.  Returns NoMode
// when it does not.
//
// Worth reading rather than inferring: the spotter usually says the mode
// outright, and says it far more often than anything else -- CW appears 57,296
// times in the capture, USB 21,658, LSB 5,205.  It also beats the band plan
// where the two disagree, which they do in every band segment that carries more
// than one mode.
function ModeStatedInComment(const Toks: TCommentTokens; n: integer): ModeType;
var
   i: integer;
   W: AnsiString;
begin
   Result := NoMode;
   for i := 0 to n - 1 do
      begin
      if Toks[i].Kind <> ctWord then
         begin
         Continue;
         end;
      W := Toks[i].Text;
      if W = 'CW' then
         begin
         Result := CW;
         Exit;
         end;
      if (W = 'SSB') or (W = 'USB') or (W = 'LSB') or (W = 'PHONE') or
         (W = 'AM') then
         begin
         Result := Phone;
         Exit;
         end;
      if W = 'FM' then
         begin
         Result := FM;
         Exit;
         end;
      // "FT8" tokenizes as the word FT plus the number 8 -- letters and digits
      // are separate tokens -- so FT covers FT8 and FT4 both.
      if (W = 'RTTY') or (W = 'PSK') or (W = 'FT') or (W = 'JT') or
         (W = 'MFSK') or (W = 'JS') or (W = 'DIGI') or (W = 'DATA') then
         begin
         Result := Digital;
         Exit;
         end;
      end;
end;

// "AUTO SPLIT": what a bare "UP", "DOWN" or "SPLIT" means when the comment
// names no distance.
//
// This is the convention the radios themselves implement under that name -- one
// key press, 1 kHz up on CW and 5 kHz up on phone -- and it is what an operator
// reading "UP" does.  It is a GUESS, but a conventional one, and it is confined
// to the bare forms: any comment that states a distance is taken at its word.
// On a digital mode, or where the mode is unknown, there is no convention to
// apply and nothing is guessed.
//
// (Direction from NY4I, 2026-08-04.)
function AutoSplitOffsetHz(Mode: ModeType; out Hz: integer): boolean;
begin
   Hz := 0;
   case Mode of
      CW:
         begin
         Hz := 1000;
         end;
      Phone, FM:
         begin
         Hz := 5000;
         end;
   end;
   Result := Hz > 0;
end;

// Is this a frequency an amateur station could actually be listening on?  The
// original decoder applied this test to QSX and NOT to UP, which is how a real
// captured comment -- "UP 200-205" on 14195 -- produced a QSX of 14395 kHz,
// outside the 20 m band.  One rule, applied to every form.
function IsOnAHamBand(Hz: integer): boolean;
var
   band: BandType;
   mode: ModeType;
begin
   band := NoBand;
   mode := NoMode;
   if Hz <= 0 then
      begin
      Result := False;
      Exit;
      end;
   CalculateBandMode(Cardinal(Hz), band, mode);
   Result := band <> NoBand;
end;

function ParseSplitHint(const Comment: AnsiString; BaseFrequencyHz: integer;
                        BandPlanMode: ModeType;
                        out QSXFrequencyHz: integer): boolean;
var
   Toks: TCommentTokens;
   n, i, pass: integer;
   kw: TSplitKeyword;
   dir: TSplitKeyword;
   numIndex: integer;
   hz: integer;
   mode: ModeType;
   haveHz: boolean;
begin
   Result := False;
   QSXFrequencyHz := 0;

   n := TokenizeComment(Comment, Toks);

   // What the comment says about the mode wins; the band plan is the fallback.
   mode := ModeStatedInComment(Toks, n);
   if mode = NoMode then
      begin
      mode := BandPlanMode;
      end;

   // TWO PASSES, and the order is the point.  A comment that states a frequency
   // or a distance anywhere must beat the AUTO SPLIT convention, wherever the
   // two appear relative to each other: "CW SPLIT QSX 28.027.800" opens with a
   // bare SPLIT, and a single left-to-right pass answered "1 kHz up" while the
   // exact frequency sat four words later.
   for pass := 1 to 2 do
      begin
      i := 0;
      while i < n do
         begin
         hz := 0;
         haveHz := False;
         dir := skNone;
         numIndex := -1;

         if Toks[i].Kind <> ctWord then
            begin
            Inc(i);
            Continue;
            end;

         kw := KeywordOf(Toks[i].Text);

         if (kw <> skNone) and not KeywordIsWholeWord(Toks, i, kw) then
            begin
            kw := skNone;
            end;

         // "NOT SPLIT" / "NO SPLIT" says the opposite of split, and both appear
         // in the capture.  Without this the auto-split default below would turn
         // a denial into a QSX.
         if (kw = skSplit) and (i > 0) and (Toks[i - 1].Kind = ctWord) and
            ((Toks[i - 1].Text = 'NOT') or (Toks[i - 1].Text = 'NO')) then
            begin
            kw := skNone;
            end;

         // "PILE UP" / "COMING UP" / "MESSED UP": ordinary English that ends in
         // the word.  Suppressed for the AUTO SPLIT guess only (pass 2), never
         // for a stated distance.
         if (pass = 2) and (kw = skUp) and (i > 0) and
            (Toks[i - 1].Kind = ctWord) and
            WordMakesUpEnglish(Toks[i - 1].Text) then
            begin
            kw := skNone;
            end;

         if kw in [skIntroducer, skSplit] then
            begin
            // "QSX UP 5" / "LSN UP 5" / "SPLIT DOWN 2": an introducer may name
            // a direction before the number.
            if (i + 1 < n) and (Toks[i + 1].Kind = ctWord) and
               (KeywordOf(Toks[i + 1].Text) in [skUp, skDown]) then
               begin
               dir := KeywordOf(Toks[i + 1].Text);
               numIndex := i + 2;
               end
            else if (i + 1 < n) and (Toks[i + 1].Kind = ctWord) and
                    IsFillerWord(Toks[i + 1].Text) then
               begin
               numIndex := i + 2;      // "LISTENING ON 7227.00"
               end
            else
               begin
               numIndex := i + 1;
               end;
            end
         else if kw in [skUp, skDown] then
            begin
            dir := kw;
            numIndex := i + 1;
            end;

         if (pass = 1) and (numIndex >= 0) and (numIndex < n) and
            (Toks[numIndex].Kind = ctNumber) then
            begin
            if UnitIsMHz(Toks, n, numIndex) then
               begin
               // The comment names the unit, so there is nothing to infer.
               haveHz := ForcedMHzHz(Toks[numIndex].Text, hz);
               end
            else if dir = skNone then
               begin
               // Absolute form.  The one exception is the original decoder's
               // rule, kept because real comments rely on it: a value under
               // 10 kHz after QSX is an offset UP, not a frequency.
               haveHz := AbsoluteHz(Toks[numIndex].Text, hz);
               if haveHz and (hz < 10000) then
                  begin
                  hz := BaseFrequencyHz + hz;
                  end;
               end
            else
               begin
               haveHz := OffsetHz(Toks[numIndex].Text, hz);
               if haveHz then
                  begin
                  if dir = skDown then
                     begin
                     hz := BaseFrequencyHz - hz;
                     end
                  else
                     begin
                     hz := BaseFrequencyHz + hz;
                     end;
                  end
               else
                  begin
                  // Too big to be an offset: somebody wrote the frequency
                  // itself after the direction ("UP 1829.5").
                  haveHz := AbsoluteHz(Toks[numIndex].Text, hz);
                  end;
               end;
            end
         else if (pass = 1) and (dir <> skNone) and (i > 0) and
                 (Toks[i - 1].Kind = ctNumber) then
            begin
            // POSTFIX: "5 UP", "5UP", "LISTENING 5 UP", "2.5 UP".  As common in
            // the capture as the prefix form and just as unambiguous, but the
            // number sits BEFORE the direction.  MAXSPLITOFFSETKHZ is what keeps
            // "59 TU 73 UP" from reading a signal report as an offset.
            haveHz := OffsetHz(Toks[i - 1].Text, hz);
            if haveHz then
               begin
               if dir = skDown then
                  begin
                  hz := BaseFrequencyHz - hz;
                  end
               else
                  begin
                  hz := BaseFrequencyHz + hz;
                  end;
               end;
            end
         else if (pass = 2) and ((dir <> skNone) or (kw = skSplit)) and
                 not ((numIndex >= 0) and (numIndex < n) and
                      (Toks[numIndex].Kind = ctNumber)) then
            begin
            // Nothing in the comment stated a distance: the AUTO SPLIT
            // convention.  A bare SPLIT means up.
            //
            // The guard above matters.  "UP 200-205" DID state a distance -- one
            // pass 1 refused as implausible -- and answering "1 kHz up" there
            // would be pretending the number was never written.  A number that
            // merely PRECEDES the direction is different ("59 TU 73 UP"): it is
            // usually unrelated, so a bare-UP default still applies.
            haveHz := AutoSplitOffsetHz(mode, hz);
            if haveHz then
               begin
               if dir = skDown then
                  begin
                  hz := BaseFrequencyHz - hz;
                  end
               else
                  begin
                  hz := BaseFrequencyHz + hz;
                  end;
               end;
            end;

         if haveHz and IsOnAHamBand(hz) then
            begin
            QSXFrequencyHz := hz;
            Result := True;
            Exit;
            end;

         Inc(i);
         end;
      end;
end;

function ParseDXSpotLine(const Line: AnsiString; out Spot: TSpotRecord): boolean;
var
   LineBuf: TDXLineBuf;
   DX: integer;        // always 0; kept so the offsets below read as they did
   i: integer;
   TempFrequency: integer;
   f: integer;
   Offset: integer;
   CallFound: boolean;
   Comment: AnsiString;
   QSXHz: integer;
   planBand: BandType;
   planMode: ModeType;
begin
   LineToBuf(Line, LineBuf);
   DX := 0;   // the line starts at the start; see the header

   Offset := 0;
   Result := False;

   // Safe: TSpotRecord holds only value types (its callsigns are ShortStrings),
   // so there is nothing here for a wipe to leak.
   Windows.ZeroMemory(@Spot, SizeOf(TSpotRecord));
   Spot.FBand := NoBand;
   Spot.FMode := NoMode;

   if LineBuf[DX + 24] = '.' then
      begin
      Offset := 3; // 4.92.6
      end;
   if LineBuf[DX + 25] = '.' then
      begin
      Offset := 4;
      end;
   if LineBuf[DX + 26] = '.' then
      begin
      Offset := 5;
      end;
   if LineBuf[DX + 23] = '.' then
      begin
      Offset := 1;
      end;

   {Source Callsign}
   for i := DX + 9 to DX + 20 do
      begin
      if ((LineBuf[i] = ' ') or (LineBuf[i] = ':')) then
         begin
         // FIXED (was: the SetLength ran only `if LineBuf[i + 1] <> ' '`, tagged
         // "4.92.6" and identical in the D7 tree).  The character copy was NOT
         // guarded, so on the ordinary blank-padded line -- "W1FM:      ", which
         // is nearly every line -- the spotter's characters landed in the field
         // while its LENGTH BYTE stayed 0 from the wipe above.  FSourceCall then
         // read as '' as a Pascal string, and only as the right callsign through
         // @FSourceCall[1].  It never showed because both readers happen to use
         // the pointer form (uBandmap:688, uTelnet's alert message).
         //
         // The length and the copy are one fact and are now written together:
         // lstrcpynA writes at most n-1 characters plus a NUL, so n-1 characters
         // is exactly the length.
         SetLength(Spot.FSourceCall, i - DX - 6);
         Windows.lstrcpynA(@Spot.FSourceCall[1], @LineBuf[DX + 6], i - DX - 5);
         Break;
         end;
      end;

   for i := DX + 10 to DX + 20 do
      begin
      // if LineBuf[i] = ' ' then if LineBuf[i + 1] <> ' ' then
      // Two nested single-statement ifs collapsed into one condition -- no else
      // on either, so this is the same test, and it satisfies the begin/end rule
      // without adding a pointless nesting level.  4.92.6
      if ((LineBuf[i] = ' ') or (LineBuf[i] = ':')) and
         (LineBuf[i + 1] <> ' ') then
         begin
         Windows.lstrcpynA(@Spot.FFreqString[0], @LineBuf[i + 1],
                           DX + 24 - i + Offset);

         TempFrequency := 0;

         for f := 0 to 12 do
            begin
            if TempFrequency > 2100000 { $ 7FFFFFF} then
               begin
               Exit;
               end;

            if Spot.FFreqString[f] = '.' then
               begin
               // 0010368100 - 009E3464
               // 1778165408 - 69FCA6A0
               // 2147483647   7FFFFFFF
               TempFrequency :=
                  (
                  TempFrequency * 10 +
                  (Ord(Spot.FFreqString[f + 1]) - 48)
                  ) * 100;
               //103 681 190 00
               if (TempFrequency > 1300000000) or (TempFrequency < 0) then
                  begin
                  Exit;
                  end;
               Spot.FFrequency := TempFrequency;
               Break;
               end;
            if Spot.FFreqString[f] = #0 then
               begin
               Break;
               end;
            if Spot.FFreqString[f] in ['0'..'9'] then
               begin
               TempFrequency := TempFrequency * 10 +
                                (Ord(Spot.FFreqString[f]) - 48);
               end;
            end;
         end;
      end;

   {DX}
   if Offset = 4 then
      begin
      Offset := 3; // 4.92.7
      end;
   CallFound := False;
   for i := DX + 27 to DX + 39 do
      begin
      // Nested single-statement ifs collapsed; same test, no else on either. 4.92.7
      if (LineBuf[i] <> ' ') and
         (LineBuf[i + 1] = ' ') then
         begin
         SetLength(Spot.FCall, i - (DX + 25 + Offset));
         Windows.lstrcpynA(@Spot.FCall[1], @LineBuf[DX + 26 + Offset],
                           i - (DX + 24 + Offset));
         if not IsAGoodCall(Spot.FCall) then
            begin
            Exit;
            end;
         CallFound := True;
         Break;
         end;
      end;

   // FIXED: a line cut off before the call columns used to be reported as a
   // SUCCESSFUL decode.  The loop above simply never matched, so IsAGoodCall
   // -- the only validation there is -- was never reached, and the caller went
   // on to dupe-check, band-map and display a spot with an empty callsign and a
   // zero frequency.  One line in the 198,979 captured is truncated like that
   // ("DX de K3LR:  ", a node dropping mid-write), and any short or garbled line
   // does the same.  No call in the call columns is not a spot.
   if not CallFound then
      begin
      Exit;
      end;

   {Note}
   // Always true -- an AnsiChar compared against a 30-space string never equals
   // it.  Kept as written rather than "fixed": the comment says what was meant,
   // the note block below is harmless on a blank comment (it copies spaces),
   // and rewriting the test would change which lines take this path.  ny4i
   if LineBuf[DX + 39 + Offset] <> '                              ' then
      begin
      Windows.lstrcpynA(@Spot.FNotes[0], @LineBuf[DX + 39 + Offset], 31);
      //was 31 but allow for null ny4i

      // The comment is the 30-column field the note was just copied from.  It
      // is read into a string here rather than uppercased in place: the
      // grammar does its own case folding, and mutating the line buffer to
      // help a later scan was a trap waiting for the next reader.
      Comment := '';
      for i := 0 to 29 do
         begin
         if LineBuf[DX + 39 + Offset + i] = #0 then
            begin
            Break;
            end;
         Comment := Comment + LineBuf[DX + 39 + Offset + i];
         end;

      // The band plan's mode for this frequency is the fallback the AUTO SPLIT
      // default needs when the comment names no mode.  It is computed here and
      // NOT stored: FMode is the band map's business (its band/mode mapping is
      // a setting), and that stays on the apply side.
      planBand := NoBand;
      planMode := NoMode;
      CalculateBandMode(Cardinal(Spot.FFrequency), planBand, planMode);

      if ParseSplitHint(Comment, Spot.FFrequency, planMode, QSXHz) then
         begin
         Spot.FQSXFrequency := QSXHz;
         end;
      end;

   Result := True;
end;

function ParseDXSpotTimeUTC(const Line: AnsiString; out MinuteOfDay: integer): boolean;
var
   LineBuf: TDXLineBuf;
   DX: integer;
begin
   LineToBuf(Line, LineBuf);
   DX := 0;

   MinuteOfDay := 0;
   Result := LineBuf[DX + 74] = 'Z';
   if not Result then
      begin
      Exit;
      end;

   // Columns 70..73 are HHMM.  No digit check, exactly as before: a non-digit
   // there yields a nonsense number rather than a rejection.  The 'Z' in the
   // fixed column is the whole validation this format ever had.
   MinuteOfDay := ((Ord(LineBuf[DX + 70]) - $30) * 10 +
                    Ord(LineBuf[DX + 71]) - $30) * 60 +
                  ((Ord(LineBuf[DX + 72]) - $30) * 10 +
                    Ord(LineBuf[DX + 73]) - $30);
end;

end.
