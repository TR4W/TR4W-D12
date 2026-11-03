unit uMnemonicsLCL;
{$I ..\..\tr4w.inc}

(* KEYBOARD MNEMONICS (Alt+letter) -- THE HALF THAT NEEDS A WIDGET SET.

   STAGE 2 OF THE MNEMONIC PLAN. uMnemonics is the rule and knows nothing about
   forms or widget sets; this unit holds the two things that do:

   1. WHETHER TO WRITE MNEMONIC MARKUP AT ALL on this widget set
      (MnemonicMarkupFor, WidgetSetHonoursMnemonics);
   2. THE TEXT A CAPTION DISPLAYS, with its markup taken out (DisplayedText),
      for the places that put a caption somewhere '&' is not markup -- a window
      title, and a measurement of what a button will paint.

   Stage 3 wires the main menu's submenus (uMenu.ApplyMenuMnemonics); forms
   are not wired yet. ("Mnemonic"
   and not "accelerator" on purpose -- in this tree an accelerator is a
   ShortCut.)

   WHY THE GATE ASKS THE WIDGET SET AND NOT {$IFDEF DARWIN}. The question is
   "does this widget set honour '&'", and the LCL answers it:
   WidgetSet.GetLCLCapability(lcAccelleratorKeys) (interfacebase.pp; the
   misspelling is the LCL's). Cocoa answers LCL_CAPABILITY_NO
   (cocoaint.pas, TCocoaWidgetSet.GetLCLCapability), and every other widget set
   inherits YES from TWidgetSet. An {$IFDEF DARWIN} would answer a different
   question -- which OPERATING SYSTEM -- and be wrong the day a Qt or gtk build
   runs on a Mac. The test is read the way the LCL reads it itself,
   "anything but NO" (wincontrol.inc, TWinControl.SendDialogChar, which is
   where the LCL decides whether Alt+letter reaches a control at all).

   WHY IT MATTERS ON COCOA, and it is not cosmetic. Cocoa strips a caption's
   markup with TCocoaStringUtil.removeAcceleration (cocoautils.pas): it calls
   DeleteAmpersands, and then, when a '(' comes before the accelerator and a
   ')' after it, it returns everything BEFORE THE FIRST '(' and nothing else.
   So the CJK convention uMnemonics applies -- '<save>(&S)...' -- displays as
   '<save>' on a Mac, losing its '...' as well, and a caption with an earlier
   parenthesis loses everything from that one on. Appending '(&X)' there would
   truncate captions, so on a widget set that does not honour mnemonics TR4W
   writes none.

   THE DECISION IS A PURE FUNCTION OF ONE BOOLEAN (MnemonicMarkupFor), so a
   unit test pins both outcomes on any platform. WidgetSetHonoursMnemonics is
   the one line that asks the live widget set, and is deliberately not tested
   against a platform's answer: pinning Windows' answer in the suite would be
   the {$IFDEF} this unit exists to avoid, moved into a test.

   DisplayedText IS Menus.StripHotkey, and why that one. It is the LCL's own
   reading of caption markup: a lone '&' is removed and '&&' becomes one
   literal '&'. LCLProc.RemoveAmpersands agrees on every input; Menus is chosen
   because Forms already uses it, so no unit that has a form pays anything for
   it. Both take the LCL's 8-bit string, which is why this unit's parameters
   are TCaption and not this tree's UTF-16 string: a caption stripped as
   TCaption converts nothing, and a round trip through string would be a
   narrowing conversion counted against the build's ceiling. *)

interface

uses
   Controls;   (* TCaption *)

type
   (* What stage 3 does to a group of captions. *)
   TMnemonicMarkup = (
      mmAssign,       (* run uMnemonics.AssignMnemonics over the group *)
      mmLeaveAlone    (* write no markup; the widget set would not honour it *)
      );

(* THE DECISION. aWidgetSetHonoursMnemonics is the capability; nothing else is
   read. *)
function MnemonicMarkupFor(const aWidgetSetHonoursMnemonics: boolean): TMnemonicMarkup;

(* THE CAPABILITY, asked of the running widget set. Needs a widget set: call it
   after Application.Initialize. *)
function WidgetSetHonoursMnemonics: boolean;

(* The text aCaption puts on screen: every lone '&' removed, '&&' read as one
   '&'. For a window title built from a menu row, and for measuring a caption
   before it is painted. *)
function DisplayedText(const aCaption: TCaption): TCaption;

implementation

uses
   InterfaceBase,   (* WidgetSet, lcAccelleratorKeys, LCL_CAPABILITY_NO *)
   Menus,           (* StripHotkey *)
   uMnemonics;      (* RemoveSuffixGroups -- the CJK '(&X)' form *)

function MnemonicMarkupFor(const aWidgetSetHonoursMnemonics: boolean): TMnemonicMarkup;
begin
   if aWidgetSetHonoursMnemonics then
      begin
      Result := mmAssign;
      end
   else
      begin
      Result := mmLeaveAlone;
      end;
end;

function WidgetSetHonoursMnemonics: boolean;
begin
   Result := WidgetSet.GetLCLCapability(lcAccelleratorKeys) <> LCL_CAPABILITY_NO;
end;

(* THE '(&X)' GROUP GOES FIRST, WHOLE (2026-11-03). A CJK caption carries its
   mnemonic as a suffix -- '<save>(&S)...' -- and StripHotkey alone would title
   that window '<save>(S)...'. The group is markup, not text, so a title shows
   '<save>...'. uMnemonics.RemoveSuffixGroups is the same reading the
   assignment uses; it runs BEFORE StripHotkey because once the '&' is gone the
   group no longer looks like one. It works on this tree's UTF-16 string, so
   the caption goes there and back by explicit conversion. *)
function DisplayedText(const aCaption: TCaption): TCaption;
begin
   Result := StripHotkey(TCaption(RemoveSuffixGroups(string(aCaption))));
end;

end.
