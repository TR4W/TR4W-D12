unit uRegex;

// One regular-expression call for both compilers.
//
// TR4W uses regular expressions in exactly one place -- the five callsign,
// GUID and POTA-park validators in LOGSTUFF -- and each of them asks the same
// question: does this subject match this pattern?  Nothing captures groups,
// nothing replaces, nothing iterates matches.  So the whole portable surface
// is one function.
//
// ---------------------------------------------------------------------------
// Why this unit exists at all
// ---------------------------------------------------------------------------
// LOGSTUFF used TPerlRegEx, which links the vendored PCRE library in
// tr4w\Include\pcre as twenty Borland-format .obj files.  FPC's linker cannot
// read them ("Illegal COFF Magic"), and that was the LAST thing standing
// between the tree compiling under FPC and the test suite running under it.
// FPC ships its own engine (TRegExpr, unit RegExpr), so the fix is to name the
// operation once and let each compiler bring its own engine.
//
// Delphi keeps TPerlRegEx deliberately.  The point of the FPC work is to find
// out whether FPC computes the same answers, and that question is meaningless
// if the Delphi side moves at the same time.
//
// ---------------------------------------------------------------------------
// The one dialect difference, and how it was settled
// ---------------------------------------------------------------------------
// PCRE and TRegExpr agree on everything these patterns use -- character
// classes, bounded repetition, anchors, non-capturing groups -- with ONE
// exception.  IsValidCallsign was written with a POSSESSIVE quantifier:
//
//     ^(?:\w{1,2}\d\/|\d\w\/|\w{1,2}\/)?+\w+[0-9]+\w+\/?\w*\s*$
//                                      ^^ possessive: never backtrack
//
// TRegExpr rejects that outright at compile time ("nested *?+"), so the pattern
// had to lose the `+`.  That is a semantic change on paper, so it was MEASURED
// rather than argued:
//
//   1. 67,681 unique real callsigns were collected from the golden-master
//      corpus and TRMASTER.DTA (610 of them containing '/', which is the only
//      branch the possessive quantifier can affect).
//   2. The shipping Delphi/PCRE engine was run over all of them with BOTH
//      spellings: 0 differences.
//   3. FPC's TRegExpr was then run over the same 67,681 subjects for all five
//      patterns and compared against the Delphi answers line by line:
//      0 differences.
//
// The probe lives in spike\rxprobe.  test\unit\uTestRegexValidators.pas pins a
// representative subset permanently, so a future engine change cannot move
// these answers unnoticed.
//
// ---------------------------------------------------------------------------
// A note on cost, not addressed here
// ---------------------------------------------------------------------------
// Every call compiles its pattern from scratch, because that is what the five
// validators already did.  IsValidCallsign runs per typed callsign and per
// WSJT-X decode, so caching the compiled expressions is worth doing -- but it
// is a change in behaviour-under-load, not in behaviour, and it does not belong
// in the same commit as a compiler port.

{$I ..\tr4w.inc}

interface

// True if aSubject matches aPattern.
//
// An engine failure -- a pattern this engine cannot compile, or one it aborts
// on for a particular subject -- is caught, LOGGED AT ERROR, and answered
// False.  Both halves of that matter:
//
//   Not swallowed silently, because every pattern in TR4W is a literal
//   constant, so a failure here is a programming error and a validator that
//   quietly answers "no" to everything is a very hard bug to find.
//
//   Not allowed to escape either, because these validators run on operator
//   input -- a typed callsign, an ADIF field from someone else's file -- and
//   TR4W's message loop has no useful place to catch an exception thrown from
//   inside a keystroke.  This is not hypothetical: TRegExpr aborts with
//   'loop without loop entry' on a repeated group it cannot backtrack into,
//   which is what forced RX_GUID's (...){3} to be written out longhand.
function RegexMatches(const aPattern, aSubject: string): boolean;

implementation

uses
   SysUtils,
   Log4D,
{$IFDEF FPC}
   RegExpr;
{$ELSE}
   PerlRegEx;
{$ENDIF}

var
   // Own logger rather than MainUnit's global: this unit is linked by the
   // standalone test executable, which does not assign that global.
   logger: TLogLogger;

{$IFDEF FPC}

function RegexMatches(const aPattern, aSubject: string): boolean;
var
   rx: TRegExpr;
begin
   Result := False;

   // FPC's RegExpr unit is compiled 8-bit, so its Expression and Exec take an
   // AnsiString.  The conversion is stated rather than left implicit: these
   // patterns and subjects are ASCII by definition (callsigns, hex digits,
   // park references), so it is lossless -- but an implicit narrowing at a
   // library boundary is exactly the shape of bug this project has paid for.
   rx := TRegExpr.Create;
   try
      try
         rx.Expression := AnsiString(aPattern);
         Result := rx.Exec(AnsiString(aSubject));
      except
         on E: Exception do
            begin
            Result := False;
            logger.Error('[Regex] %s on pattern <%s> subject <%s>',
                         [E.Message, aPattern, aSubject]);
            end;
      end;
   finally
      rx.Free;
   end;
end;

{$ELSE}

function RegexMatches(const aPattern, aSubject: string): boolean;
var
   rx: TPerlRegEx;
begin
   Result := False;

   rx := TPerlRegEx.Create;
   try
      try
         rx.RegEx   := UTF8Encode(aPattern);
         rx.Subject := UTF8Encode(aSubject);

         // MatchAgain, not Match, because that is what the five validators
         // called.  On a freshly created object there is no previous match to
         // continue from, so it searches from the start -- which is what every
         // one of these anchored patterns wants.
         Result := rx.MatchAgain;
      except
         on E: Exception do
            begin
            Result := False;
            logger.Error('[Regex] %s on pattern <%s> subject <%s>',
                         [E.Message, aPattern, aSubject]);
            end;
      end;
   finally
      rx.Free;
   end;
end;

{$ENDIF}

initialization
   logger := TLogLogger.GetLogger('TR4WDebugLog.Regex');

end.
