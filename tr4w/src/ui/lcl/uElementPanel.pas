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

(* A MAIN-WINDOW STATUS PANEL THAT LOOKS AFTER ITSELF.

  WHY THIS EXISTS AT ALL, WHICH IS THE INTERESTING PART.

  Every readout on the main window used to be written through one funnel --
  SetMainWindowText(mweClock, s) -- and NY4I's done-criterion for this phase,
  recorded in Lint-Win32Dialogs, is that it stop: "before we call this done,
  the above SetMainWindowText will be moved to something like edLocator.Text
  := ..".

  THE FUNNEL WAS CARRYING TWO THINGS THAT A PLAIN PROPERTY ASSIGNMENT WOULD
  DROP, and NY4I asked the right question before it went: "if it does is the
  cross-thread write a concern?"

    1. IT REPORTED OFF-THREAD WRITES. A cross-thread LCL control write does
       not reliably crash -- it corrupts, intermittently, under load, which
       for this program means during a contest. An audit on 2026-08-30 found
       ELEVEN such call sites; ten were marshalled then and the eleventh (the
       on-air clock, on the radio polling thread) on 2026-09-04. There are
       none today, and that is exactly why the DETECTOR matters: the next one
       would otherwise arrive in silence.

    2. IT FITTED THE CAPTION. TWindows[] gives every element a width as a
       DOS-era CHARACTER count, and some values need more room than their row
       allows -- the radio name is four units wide and "7100-18V" is eight
       characters, so it ran into the border.

  RealSetText IS VIRTUAL (lcl/controls.pp:1513), so a descendant sees EVERY
  caption assignment -- including a direct `pnlRadioOne.Caption := s`. Both
  behaviours move onto the control, and the funnel can go without taking them
  with it.

  THE CAPTION FIT IS AN INTERIM. Stage 3 of the designer work gives these
  controls anchors and autosize, and a control sized by its content cannot be
  too small for it. Until then this shrinks. *)
unit uElementPanel;

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

interface

uses
   Classes, Controls, ExtCtrls, Graphics;

type
   (* HOW AN OFF-THREAD WRITE IS REPORTED, WITHOUT THIS UNIT KNOWING HOW.

     The reporting lives in uCrashLog, and a control has no business depending
     on it -- nor could it: uElementPanel is linked by build/lintlfm, a checker
     that links the LCL and nothing else, and pulling uCrashLog in would drag
     the tree behind it. It is injected instead, by uMainForm.

     Unassigned means no report, which is the right answer for a tool that only
     wants to ask the class what it publishes. *)
   TElementOffThreadReport = procedure(const aSite: string;
                                       const aCaller: CodePointer);

   (* WHAT TO DO AFTER A CAPTION CHANGES, beyond drawing it.

     FIVE MAIN-WINDOW COLOURS ARE LIVE RULES rather than fixed properties --
     the WSJT-X indicator, the PTT state and three others -- and they were
     re-evaluated by WriteMainWindowText on every text change, because
     "DrawWindows used to do it on every repaint and nothing does now unless it
     is asked".

     A plain `pnlWSJTX.Caption := s` does not ask, so converting the call sites
     would have dropped it -- silently, with a one-second timer as the only
     backstop. It moves here instead, where every caption write passes.

     Injected for the same reason the report is: this unit must stay linkable
     by a checker that has only the LCL. *)
   TElementCaptionChanged = procedure;

   TElementPanel = class(TPanel)
   private
      FBaseFontHeight: integer;
      (* Set when a caption could not be shrunk far enough to fit; cleared on
        resize so a wider window is measured afresh. See FitCaption. *)
      FOverflowReported: boolean;
      procedure FitCaption;
      procedure ApplyBevel(const aRequested: TPanelBevel);
   protected
      procedure RealSetText(const aValue: TCaption); override;
      (* Re-measure the caption when the panel changes size. *)
      procedure Resize; override;
      (* The neutral background follows the window on macOS. See the body. *)
      procedure SetColor(Value: TColor); override;
      (* The designed BevelOuter arrives here. See ApplyBevel. *)
      procedure Loaded; override;
   public
      (* SUNKEN OR FLAT, ASKED AS A QUESTION ABOUT THE ELEMENT rather than
        answered as a property assignment.

        uMainForm.CreateMainElement translates SS_SUNKEN out of the TWindows[]
        style word; what a sunken element LOOKS like is this class's business,
        and on one platform it is drawn differently. See ApplyBevel. *)
      procedure SetSunken(const aSunken: boolean);
      (* THE HEIGHT THE CAPTION WOULD LIKE TO BE, which is not always the
        height it gets. FitCaption always measures from here, so a panel that
        shrank for a long value returns to the common size when a short one
        arrives -- without it, a panel could only ever get smaller.

        SIGNED, EXACTLY AS TFont.Height IS SIGNED, and that is a correction
        made on 2026-09-09. It used to mean "a positive magnitude, applied as
        a negative height", which worked only as long as every caller used the
        LCL's negative CHARACTER-height convention. The need strips do not:
        they take ApplyMainFontTo, which assigns a POSITIVE CELL height, and
        uMainGrids stored the negation of that -- so BaseFontHeight came out
        NEGATIVE and FitCaption's `<= 0` guard exited on the first line.

        FITTING HAD THEREFORE NEVER RUN FOR ANY NEED PANEL. That is why the
        Resize override alone did not fix NY4I's clipped 'Both:' label: the
        re-measure it added called a routine that returns immediately.

        Carrying the sign means a panel keeps whichever convention its font
        was given and simply gains the shrink. Zero still means "no font has
        been chosen yet" and nothing is fitted. *)
      property BaseFontHeight: integer read FBaseFontHeight write FBaseFontHeight;
   end;

type
   (* A CAPTION THAT WOULD NOT FIT EVEN AT THE SMALLEST FONT.

     Reported rather than logged here so this unit keeps no logger of its own,
     the same arrangement as TElementOffThreadReport above. uMainForm supplies
     the sink.

     aWanted and aAvailable are pixels, and the difference is the whole point:
     "it does not fit" is not actionable, "it needs 214 and has 180" says
     whether the panel is too narrow or the content too long. aFont is named
     because the likely cause is font substitution -- 'Arial' is not installed
     on a typical Linux box. *)
   TElementOverflowReport = procedure(const aPanel, aCaption, aFont: string;
                                      const aWanted, aAvailable: integer);

var
   (* Set by uMainForm to uCrashLog's reporter. See TElementOffThreadReport. *)
   ElementOffThreadReport: TElementOffThreadReport = nil;

   (* Set by uMainForm. See TElementCaptionChanged. *)
   ElementCaptionChanged: TElementCaptionChanged = nil;

   (* Set by uMainForm to a log line. See TElementOverflowReport. *)
   ElementOverflowReport: TElementOverflowReport = nil;

implementation

uses
   SysUtils,
   InterfaceBase;   { WidgetSet -- see the finalization }

const
   (* Below this the text is not worth reading, and a caption that still does
     not fit is better clipped than illegible. *)
   MIN_FONT_HEIGHT = 9;

var
   (* A canvas to measure on.

     NOT THE CONTROL'S OWN. An element is written long before the window is
     shown, and asking an unrealised control to measure is the access
     violation this tree paid for on the View/Edit window (2026-09-04). One
     bitmap for every panel: measuring is not re-entrant here, all of it
     happens on the main thread, and forty-three canvases would be forty-three
     device contexts for no gain. *)
   GMeasure: TBitmap = nil;

procedure TElementPanel.RealSetText(const aValue: TCaption);
begin
   (* THE DETECTOR THE FUNNEL USED TO BE.

     Reported, not blocked: refusing the write would turn a latent corruption
     into a missing readout, and the caller is not expecting a failure. What is
     wanted is the CALLER'S NAME, so whoever added the thread can be told. *)
   (* MainThreadID is the RTL's own, so this needs nothing but Classes -- and
     the question really is "is this the thread the LCL runs on". *)
   if (GetCurrentThreadId <> MainThreadID) and
      Assigned(ElementOffThreadReport) then
      begin
      ElementOffThreadReport('TElementPanel.Caption', get_caller_addr(get_frame));
      end;

   inherited RealSetText(aValue);
   FitCaption;

   (* THE LIVE COLOUR RULES, re-evaluated because the text just changed. *)
   if Assigned(ElementCaptionChanged) then
      begin
      ElementCaptionChanged;
      end;
end;

(* A CAPTION IS MEASURED WHEN IT IS ASSIGNED. IT HAS TO BE MEASURED AGAIN WHEN
  THE PANEL CHANGES SIZE, AND UNTIL 2026-09-09 IT WAS NOT.

  FitCaption ran from RealSetText only, so a panel whose caption was set BEFORE
  its final width kept a font chosen for the wrong width for the rest of the
  session. That is the normal order for the need strips: ConfigureNeedRows
  assigns 'Both:' while the panels are still at their design-time size, and
  PositionMainGrids narrows them to ws * 2 afterwards. Nothing re-measured.

  ON WINDOWS IT FIT ANYWAY, so nothing showed. NY4I, Linux Mint 2026-09-09:
  the label read "oth:". TR4W asks for 'Arial' (VC.pas), which a typical Linux
  box does not have, so fontconfig substitutes a face whose metrics differ from
  every width this program computed -- and the shrink that would have absorbed
  the difference never ran.

  IT ALSO EXPLAINS THE MISSING DIAGNOSTIC. The overflow report fires from
  FitCaption, so a clipped caption that was measured at the wrong width is
  clipped SILENTLY: the log carried no complaint about a panel that was
  visibly cutting a letter off. A check that cannot run is not a check.

  THE COMMENT ABOVE ALREADY CLAIMED THIS EXISTED -- "FOverflowReported is
  cleared when the panel is resized". It was describing an override that was
  never written, which is the worst kind of stale note: it answers the question
  and stops anyone looking. *)
procedure TElementPanel.Resize;
begin
   inherited Resize;

   (* A WIDER PANEL DESERVES A FRESH VERDICT. FitCaption always starts from
     FBaseFontHeight, so the font grows back as well as shrinking. *)
   FOverflowReported := False;
   FitCaption;
end;

(* WHAT A SUNKEN ELEMENT LOOKS LIKE, AND WHY macOS GETS A DIFFERENT ANSWER.

  NY4I, 2026-09-21, comparing TR4W on the Mac against a Qt contest logger side
  by side: "The fields that have rounded corners make the form look strange. It
  is not a continuous flow ... maybe it is simply the rounded corners and the
  gray backgrounds that make it look as a striking departure from what I am
  used to on the windows app."

  NOTHING IN TR4W ASKED FOR A ROUNDED CORNER. The chain is entirely inside the
  widget set, and it is worth writing down because it is not guessable from a
  screenshot:

    BevelOuter <> bvNone
      -> TCustomPanel.PaintBevel calls Canvas.Frame3d
      -> TCocoaWidgetSet.Frame3d, which for a TCustomPanel consults
         CocoaConfigPanel.classicFrame3d -- FALSE by default
      -> TCocoaContext.Frame3dBox, which draws an NSBox (NSBoxSecondary for
         bvLowered)

  An NSBox is a rounded, filled grouping container. It is the right thing for
  the request "draw me a box"; it is the wrong thing for a status readout in a
  dense contest layout, and it accounts for BOTH halves of the complaint -- the
  corners and the grey. The form and its panels both carry clBtnFace, so the
  two cannot differ by colour on their own; whatever is grey on those tiles is
  painted by the bevel.

  TWO ATTEMPTS AT THIS WERE WRONG, AND BOTH ARE WORTH KEEPING.

  REMOVING THE BEVEL WENT TOO FAR. NY4I against Windows 5.0.18 side by side:
  WINDOWS IS NOT BORDERLESS. It has thin square rules around every readout;
  what it lacks is the rounded corner and the fill. Flat lost delineation the
  reference platform has -- the bottom status row ran together into one strip
  and the totals cells stopped tying a number to its band column.

  DRAWING OUR OWN RULE WAS ALSO WRONG, AND THE BRACKET IS THE USEFUL PART.
  Setting BevelColor makes TCustomPanel.PaintBevel take a different
  TCanvas.Frame3d overload -- the one at canvas.inc:1063 that draws with the
  pen and never reaches the widget set. It works exactly as advertised, and
  the result was still wrong at both settings anybody could choose:

      1px $929292   NY4I: "I see no lines at all"
      2px $929292   NY4I: "Frankly, this display is hideous" ...
                          "The lines are much too big as compared to windows"

  There is no width between one and two, and $929292 was already the darkest
  usable system colour on that machine (clWindowFrame $AAAAAA and clSilver
  $C0C0C0 are LIGHTER; the only darker one is black). So the target is not a
  solid stroke of any size.

  WINDOWS DOES NOT DRAW A LINE. IT DRAWS A GROOVE. A sunken bevel there is
  two-tone -- shadow on the top and left, highlight on the bottom and right --
  and it reads as a faint etch because the surface underneath is GREY. We were
  imitating a groove with a solid stroke on WHITE, and no colour or width
  reproduces that.

  SO THE ANSWER IS NOT IN THIS UNIT AT ALL. It is two things landing together,
  and neither is shippable alone:

    1. CocoaConfigPanel.classicFrame3d := True, set once at startup in
       uProgramMain, which makes Cocoa draw a panel bevel as a square
       two-tone etch (TCocoaContext.DrawEdge, cl3DShadow over cl3DHiLight)
       instead of allocating an NSBox.
    2. The neutral surface becomes clForm rather than clBtnFace, which is
       what SetColor below does -- because the etch's highlight edge is
       invisible on white and the whole effect needs a grey to sit on.

  WHICH LEAVES THIS ROUTINE WITH NOTHING PLATFORM-SPECIFIC TO DO, and that is
  the right outcome: the bevel is the bevel on every platform now, and how a
  bevel is DRAWN is the widget set's business. *)
procedure TElementPanel.ApplyBevel(const aRequested: TPanelBevel);
begin
   if BevelOuter <> aRequested then
      begin
      BevelOuter := aRequested;
      end;
end;

(* THE NEUTRAL BACKGROUND IS THE WINDOW'S, NOT THE BUTTON FACE'S -- ON macOS.

  WHY THIS IS NOT A RESTYLE. clBtnFace means "the ordinary surface this
  program is drawn on", and on Windows it IS that: GetSysColor(COLOR_BTNFACE)
  is $F0F0F0, the same grey the main window is painted with, so a neutral
  panel disappears into the form and only the WHITE entry fields stand out.

  ON macOS THE SAME CONSTANT IS WHITE. Measured in the running program on
  2026-09-21, not inferred -- the LCL maps COLOR_BTNFACE to
  NSColor.controlBackgroundColor (cocoautils.pas:898), a CONTENT-area colour:

      clBtnFace = $8000000F -> rgb $FFFFFF        <- the window
      clForm    = $8000001F -> rgb $ECECEC        <- what the window should be
      the entry fields are trWhite = $FFFFFF

  So the callsign and exchange fields were white on white. NY4I: a caret
  floating in empty space with no indication where the field is or how wide.
  That is a usability defect, not a preference, and it is the whole reason
  this substitution exists.

  clForm IS THE RIGHT NAME FOR WHAT WAS WANTED ALL ALONG. It resolves to
  NSColor.windowBackgroundColor -- the surface a macOS window is drawn on,
  which is exactly what COLOR_BTNFACE means on Windows and no longer means
  here.

  ONLY THE NEUTRAL, AND THE TEST IS EXACT. Every element panel is coloured
  from tr4wColorsArray[TWindows[e].mweBackG], and trBtnFace is the value that
  row carries when nothing has been said about it -- it is also the OFF state
  in every live colour rule (RefreshMainWindowElementColors sets trRed,
  trYellow or trLightBlue to say something and falls back to trBtnFace to say
  nothing). A panel that carries a MEANING asks for trWhite, trBlue, trYellow,
  trCyan or trGreen, never for this, so it passes straight through untouched:
  the blue band block, the yellow mult-needs row, the need strips, the WSJT-X
  indicator, the active-radio tint.

  AND VC.pas MAKES THE TEST SAFE. Its startup only overwrites
  tr4wColorsArray[trBtnFace] with a resolved system value INSIDE an
  {$IFDEF WINDOWS}; off Windows the entry keeps its declared literal, which is
  clBtnFace itself. So on the one platform this runs, the neutral request
  arrives here as exactly this constant.

  THE COMPARISON IN SetElementColors NEVER MATCHES AFTERWARDS, which is
  harmless and worth knowing: it tests `Color <> aBack`, reads clForm and is
  handed clBtnFace, so it assigns on every refresh. The assignment lands back
  here, resolves to the same clForm, and TControl.SetColor's own guard makes
  it a no-op. No repaint, no flicker. *)
procedure TElementPanel.SetColor(Value: TColor);
begin
   {$IFDEF DARWIN}
   if Value = clBtnFace then
      begin
      Value := clForm;
      end;
   {$ENDIF}

   inherited SetColor(Value);
end;

procedure TElementPanel.SetSunken(const aSunken: boolean);
begin
   if aSunken then
      begin
      ApplyBevel(bvLowered);
      end
   else
      begin
      ApplyBevel(bvNone);
      end;
end;

(* THE DESIGNED BEVEL NEEDS THE SAME TREATMENT AS THE RUN-TIME ONE, AND MOST OF
  THEM ARRIVE THAT WAY.

  Of the 111 element panels in uMainForm.lfm, only the rows of TWindows[] reach
  CreateMainElement -- and not even all of those, since the loop skips any row
  whose style word is <= 2. The totals grid's cells and headers are panels this
  class owns that no element loop touches; their bevel comes from the .lfm and
  nowhere else.

  Loaded runs after every streamed property has been set, so it sees the
  designed value and is the one place that catches all of them. *)
procedure TElementPanel.Loaded;
begin
   inherited Loaded;
   ApplyBevel(BevelOuter);
end;

procedure TElementPanel.FitCaption;
var
   avail:        integer;
   height:       integer;
   sign:         integer;
   wantedAtBase: integer;
begin
   if (Caption = '') or (FBaseFontHeight = 0) then
      begin
      Exit;
      end;

   (* Less the bevel, so a caption is not judged to fit and then drawn over the
     border it was measured against. *)
   avail := Width - 4;
   if avail <= 0 then
      begin
      Exit;
      end;

   if GMeasure = nil then
      begin
      GMeasure := TBitmap.Create;
      GMeasure.SetSize(1, 1);
      end;

   GMeasure.Canvas.Font.Name  := Font.Name;
   GMeasure.Canvas.Font.Style := Font.Style;

   (* THE MAGNITUDE SHRINKS; THE SIGN IS THE FONT'S OWN. A negative TFont
     height is a character height and a positive one is a cell height, and
     which of the two a panel uses is settled by whoever configured it -- not
     by this routine, whose only job is to make the text fit. *)
   if FBaseFontHeight < 0 then
      begin
      sign := -1;
      end
   else
      begin
      sign := 1;
      end;

   height := Abs(FBaseFontHeight);

   (* THE WIDTH AT FULL SIZE, MEASURED BEFORE ANY SHRINKING, because that is
     the number that says HOW BADLY it did not fit. "It was reduced" is not
     actionable; "it wanted 61 pixels and had 30" says the cell is half the
     size it needs to be and no font choice will rescue it. *)
   GMeasure.Canvas.Font.Height := sign * height;
   wantedAtBase := GMeasure.Canvas.TextWidth(Caption);

   while height > MIN_FONT_HEIGHT do
      begin
      GMeasure.Canvas.Font.Height := sign * height;
      if GMeasure.Canvas.TextWidth(Caption) <= avail then
         begin
         Break;
         end;
      Dec(height);
      end;

   (* SAY WHEN THE SHRINK RAN OUT OF ROOM, because the visible result is text
     touching or crossing the border and nothing else reports it.

     The loop stops at MIN_FONT_HEIGHT whether or not the caption fits, which
     is right -- unreadably small text is not an improvement -- but it means an
     overflow is drawn silently. On Windows that essentially never happened, so
     nobody noticed the gap. On Linux it does: the main window font is 'Arial'
     (VC.pas), which is not installed on a typical Linux box, so fontconfig
     substitutes something with different metrics and every width computed from
     it changes. NY4I, Linux Mint 2026-09-09: text in the needs panel hitting
     the border.

     ONCE PER PANEL, not once per repaint: captions change at contest rates and
     a per-paint message would be a flood. Resize clears FOverflowReported, so
     a panel that is made wider reports again if it still does not fit.

     THAT SENTENCE WAS FALSE UNTIL 2026-09-09 -- it described a Resize override
     that did not exist. See the one below for what it cost.

     This is a DIAGNOSTIC, not the fix. What the fix should be -- a metric
     compatible default font on Linux, or narrower content, or a wider panel --
     depends on which panels report and by how much, and that is exactly what
     was not known. *)
   (* REPORTED ON ANY SHRINK, NOT ONLY AT THE FLOOR -- widened 2026-09-09.

     The floor-only condition answered "is this illegible" and the question
     that actually needed answering was "is this cell the right size". NY4I,
     seeing a need label reduced far enough to fit: "making Both just a tiny
     font is not the right strategy. That looks strange." He is right, and the
     shrink is a MITIGATION for a layout that is wrong -- so the layout has to
     be told, in pixels, every time it happens.

     A caption that fits at full size costs nothing here; only one that had to
     be reduced says anything. Still once per panel until the next resize. *)
   if (height < Abs(FBaseFontHeight)) and (not FOverflowReported) and
      Assigned(ElementOverflowReport) then
      begin
      FOverflowReported := True;
      ElementOverflowReport(Name, Caption, Font.Name, wantedAtBase, avail);
      end;

   if Font.Height <> sign * height then
      begin
      Font.Height := sign * height;
      end;
end;

initialization
   (* THE STREAMING LOADER RESOLVES A CLASS BY NAME, and uMainForm.lfm names
     this one 43 times. Without the registration the form fails to load at the
     FIRST of them, with the window half built. *)
   RegisterClass(TElementPanel);

finalization
   (* ONLY WHILE THERE IS STILL A WIDGETSET TO FREE IT WITH.

     Freeing a TBitmap calls LCLIntf.DeleteObject, which reads the WidgetSet
     global and calls a virtual method on it. If the widgetset has already gone
     that is a null dereference -- and it is not hypothetical: every one of the
     golden corpus's THIRTEEN headless /EXPORT runs died right here, and the
     corpus reported `24 passed, 0 failed` through all of them because it
     compares artifacts and the artifacts are written before the exit
     (2026-09-06; the same thirteen crashes are in the log from 04 September).

     /EXPORT reaches this with a bitmap to free because it still BUILDS the
     main window -- BindMainGrids and PositionMainGrids run just above the
     export -- so a caption gets fitted, and then Halt(0) goes straight to
     FinalizeUnits.

     THE ANSWER IS NOT TO REORDER THE UNITS. Finalization order is reverse
     initialization order: a property of the entire uses graph, 446 lines of it
     in tr4w.lpr, with Interfaces reached through one unit's IMPLEMENTATION
     section. A fix pinned to that ordering holds until somebody adds a unit
     and then fails exactly as quietly as this did.

     THE INVARIANT, which is what generalises: A UNIT-LEVEL GLOBAL HOLDING A
     GDI HANDLE CANNOT ASSUME THE WIDGETSET OUTLIVES IT. So it asks. When the
     widgetset has gone, the handle is left to Windows, which reclaims every
     GDI object a process owns as that process exits. *)
   if WidgetSet <> nil then
      begin
      FreeAndNil(GMeasure);
      end;

end.
