// tr4w.inc -- shared compilation prelude.
//
// Include this FIRST in any unit that needs either rule below.  It is safe to
// include in a unit that needs neither, and safe to include twice.
//
// NOTE: these are // comments deliberately.  A compiler directive written
// inside a { } comment ends that comment at its own closing brace, and this
// file necessarily names directives in prose.
//
// ---------------------------------------------------------------------------
// 1. LANG_ENG normalisation
// ---------------------------------------------------------------------------
// The eight non-English builds pass LANG_<xxx> on the compiler command line
// (FullBuild.ps1 -> /p:ExtraDefines="LANG_RUS;..."), so those symbols are
// visible in every unit.  English is the *absence* of such a symbol.
//
// VC.pas synthesises LANG_ENG for itself, but a define is FILE-SCOPED: no other
// unit can see it.  So a unit that needs to ask "is this the English build?"
// cannot simply test for LANG_ENG -- it has to derive it, and deriving it in
// eleven places is how the answers drift apart.  It is derived here, once.
//
// Why not keep testing the LANG string constant?  Because FPC cannot evaluate
// it.  FPC's compile-time IF resolves Boolean and Integer constants across
// units, but NOT strings: an identifier it cannot resolve degrades to a string
// literal of its own name.  So a test of LANG against 'RUS' silently becomes
// 'LANG' = 'RUS' -- false in every build, in both directions, with no error,
// no warning and no hint, because comparing two strings type-checks fine.
// The LANG_<xxx> symbols are real compiler defines and mean exactly the same
// thing to both compilers.  The LANG constant remains a runtime value.
//
// ---------------------------------------------------------------------------
// 2. FPC compilation mode -- declared per unit, NEVER on the command line
// ---------------------------------------------------------------------------
// The vendored Indy 10.6.3.3 forces Delphi mode on itself unconditionally
// (IdCompilerDefines.inc:539) but its string conditionals follow
// FPC_UNICODESTRINGS (:1521), which a command-line -MdelphiUnicode SETS and
// Indy's own mode reset does NOT clear.  Indy then contradicts itself.
//
// Declaring the mode in the consumer instead keeps our units UTF-16 and leaves
// vendored Indy untouched -- which is the whole reason no Indy source needs
// patching.  This is not theoretical: a unit that falls through to FPC's
// default mode compiles with an 8-bit string, and a PWideChar cast over it then
// reinterprets AnsiString bytes as UTF-16.  That is exactly how uSerialPort
// opened COM13 and got ERROR_INVALID_NAME (123) with no diagnostic anywhere.
//
// The {$IFDEF FPC} guard that used to wrap this is gone (2026-08-29). It existed
// so Delphi would not choke on directives it does not recognise, and Delphi is
// not coming back -- FullBuild-D12-deprecated.ps1 has not worked since the FMX
// twins were deleted in August. A guard for a compiler that cannot build this
// tree is a claim that it might, which is the kind of thing a reader has to
// disprove before they can act.

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

{$IFDEF LANG_RUS}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_SER}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_ESP}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_MNG}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_POL}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_CZE}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_ROM}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_CHN}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_GER}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFDEF LANG_UKR}{$DEFINE _TR4W_LANG_SET}{$ENDIF}
{$IFNDEF _TR4W_LANG_SET}{$DEFINE LANG_ENG}{$ENDIF}
