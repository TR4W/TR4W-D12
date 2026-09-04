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

   TElementPanel = class(TPanel)
   private
      FBaseFontHeight: integer;
      procedure FitCaption;
   protected
      procedure RealSetText(const aValue: TCaption); override;
   public
      (* THE HEIGHT THE CAPTION WOULD LIKE TO BE, which is not always the
        height it gets. FitCaption always measures from here, so a panel that
        shrank for a long value returns to the common size when a short one
        arrives -- without it, a panel could only ever get smaller.

        Zero means "no font has been chosen yet" and nothing is fitted. *)
      property BaseFontHeight: integer read FBaseFontHeight write FBaseFontHeight;
   end;

var
   (* Set by uMainForm to uCrashLog's reporter. See TElementOffThreadReport. *)
   ElementOffThreadReport: TElementOffThreadReport = nil;

implementation

uses
   SysUtils;

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
end;

procedure TElementPanel.FitCaption;
var
   avail:  integer;
   height: integer;
begin
   if (Caption = '') or (FBaseFontHeight <= 0) then
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

   height := FBaseFontHeight;
   while height > MIN_FONT_HEIGHT do
      begin
      GMeasure.Canvas.Font.Height := -height;
      if GMeasure.Canvas.TextWidth(Caption) <= avail then
         begin
         Break;
         end;
      Dec(height);
      end;

   if Font.Height <> -height then
      begin
      Font.Height := -height;
      end;
end;

initialization
   (* THE STREAMING LOADER RESOLVES A CLASS BY NAME, and uMainForm.lfm names
     this one 43 times. Without the registration the form fails to load at the
     FIRST of them, with the window half built. *)
   RegisterClass(TElementPanel);

finalization
   GMeasure.Free;

end.
