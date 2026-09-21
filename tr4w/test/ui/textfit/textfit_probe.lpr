program textfit_probe;

(* DOES EVERY FIXED-WIDTH CAPTION FIT -- ON THIS PLATFORM, IN THIS FONT?

  THE DEFECT THIS COMES FROM. NY4I, macOS, 5.0.19: "save and close button is
  exceeding its border". The Preferences OK button is 85px wide and reads
  "Save and clo". Measured here the same evening, in the form's own font:

      caption 'Save and close'   Windows i386   text  77px, preferred 103px
                                 macOS aarch64  text  85px, preferred 107px

  85px of text in an 85px button is not tight, it is CLIPPED -- a cocoa push
  button insets its title inside the bezel, so the glyphs had less than 85px
  before they were drawn. Windows' 77px fitted, which is why it shipped.

  WHY A SEPARATE PROGRAM, and not src/ui/lcl/uTextFitAudit.pas.

  uTextFitAudit measures forms that are OPEN, from inside the running program,
  and it is the truthful instrument: real form, real font, real language. It
  has one limitation that no work inside it removes -- a form that has never
  been constructed has no controls to measure, so it sees only the windows an
  operator has opened. On a headless CI box nobody opens anything.

  This measures from the .lfm INVENTORY instead (extract_captions.py), so every
  designed form is covered whether or not it can be shown, at the cost of
  rebuilding each control standalone rather than reading the real one. The two
  are complements, not copies. WHEN THEY DISAGREE, uTextFitAudit IS RIGHT: it
  is looking at the actual window.

  WHAT IT REPORTS, and why there are two kinds.

      CLIP   the glyphs alone are wider than the box. Visible today, in
             English, on this platform. A live defect.
      snug   the glyphs fit but the widget set would have chosen a wider
             control. No bezel to spare, so this is the one that clips first
             when the caption grows -- which is what a translation is.

  BUILDING IT. Nothing in the build compiles this; it is a measuring tool, run
  by hand on the platform whose answer you want.

    Windows
      fpc -Mdelphi -Twin32 -Pi386 ^
          -FuC:\Lazarus\lcl\units\i386-win32 ^
          -FuC:\Lazarus\lcl\units\i386-win32\win32 ^
          -FuC:\Lazarus\components\lazutils\lib\i386-win32 ^
          -FuC:\Lazarus\packager\units\i386-win32 textfit_probe.lpr

    macOS (fpcupdeluxe; -XR because mac-ci's fpc.cfg is never read, and
    -k-framework UserNotifications because cocoawsextctrls references it)
      L=$HOME/fpcupdeluxe/lazarus
      fpc -Mdelphi -Paarch64 -Tdarwin -XR"$(xcrun --show-sdk-path)" \
          -k-framework -kUserNotifications \
          -Fu$L/lcl/units/aarch64-darwin \
          -Fu$L/lcl/units/aarch64-darwin/cocoa \
          -Fu$L/components/lazutils/lib/aarch64-darwin \
          -Fu$L/packager/units/aarch64-darwin textfit_probe.lpr

  IT SHOWS A WINDOW, briefly, and must. AutoSize and GetPreferredSize are
  DEFERRED while a control's form is not realised -- measured 2026-09-21, the
  first version of this reported the designed width back for every control and
  looked like a clean bill of health. That is the same shape of false negative
  uTextFitAudit's own header records, arrived at from the other direction.

  RUNNING IT
      python extract_captions.py captions.tsv
      ./textfit_probe captions.tsv
*)

{$MODE Delphi}
{$codepage UTF8}

uses
{$IFDEF UNIX}
   cthreads, cwstring,
{$ENDIF}
   Interfaces, Forms, Graphics, Controls, StdCtrls, Buttons, ExtCtrls,
   SysUtils, Classes;

var
   GForm:  TForm;
   GSnug:  integer = 0;
   GClip:  integer = 0;
   GTotal: integer = 0;

function MakeControl(const aClass: string): TControl;
(* The .lfm names a class; build one of those so the widget set answers about
   the real thing. An unrecognised class falls back to a label, which measures
   glyphs and nothing else -- the conservative answer. *)
begin
   if aClass = 'TButton' then
      begin
      Result := TButton.Create(GForm);
      end
   else if aClass = 'TBitBtn' then
      begin
      Result := TBitBtn.Create(GForm);
      end
   else if aClass = 'TCheckBox' then
      begin
      Result := TCheckBox.Create(GForm);
      end
   else if aClass = 'TRadioButton' then
      begin
      Result := TRadioButton.Create(GForm);
      end
   else if aClass = 'TGroupBox' then
      begin
      Result := TGroupBox.Create(GForm);
      end
   else if aClass = 'TSpeedButton' then
      begin
      Result := TSpeedButton.Create(GForm);
      end
   else if aClass = 'TRadioGroup' then
      begin
      Result := TRadioGroup.Create(GForm);
      end
   else if aClass = 'TCheckGroup' then
      begin
      Result := TCheckGroup.Create(GForm);
      end
   else if aClass = 'TPanel' then
      begin
      Result := TPanel.Create(GForm);
      end
   else
      begin
      Result := TLabel.Create(GForm);
      end;
   Result.Parent := GForm;
end;

procedure SetControlText(aControl: TControl; const aText: string);
(* Caption is published on four unrelated branches of the hierarchy, which is
   why this is a chain of class tests rather than a property assignment. *)
begin
   if aControl is TCustomLabel then
      begin
      TCustomLabel(aControl).Caption := aText;
      end
   else if aControl is TButtonControl then
      begin
      TButtonControl(aControl).Caption := aText;
      end
   else if aControl is TCustomGroupBox then
      begin
      TCustomGroupBox(aControl).Caption := aText;
      end
   else if aControl is TSpeedButton then
      begin
      TSpeedButton(aControl).Caption := aText;
      end
   else if aControl is TCustomPanel then
      begin
      TCustomPanel(aControl).Caption := aText;
      end;
end;

procedure Measure(const aForm, aName, aClass: string;
                  aWidth, aFontHeight: integer; const aFontName: string;
                  aBold: boolean; const aCaption: string);
var
   c:      TControl;
   needs:  integer;
   glyphs: integer;
   pw, ph: integer;
begin
   c := MakeControl(aClass);
   try
      c.SetBounds(0, 0, aWidth, 25);
      if aFontName <> '' then
         begin
         c.Font.Name := aFontName;
         end;
      if aFontHeight <> 0 then
         begin
         c.Font.Height := aFontHeight;
         end;
      if aBold then
         begin
         c.Font.Style := [fsBold];
         end;
      SetControlText(c, aCaption);
      Inc(GTotal);

      (* THE GLYPHS THEMSELVES, in the control's own font. This is what clips. *)
      GForm.Canvas.Font.Assign(c.Font);
      glyphs := GForm.Canvas.TextWidth(aCaption);

      (* WHAT THE WIDGET SET WOULD CHOOSE, bezel and indicator included. *)
      pw := 0;
      ph := 0;
      if c is TWinControl then
         begin
         TWinControl(c).HandleNeeded;
         end;
      c.GetPreferredSize(pw, ph);
      needs := pw;
      if needs < glyphs then
         begin
         needs := glyphs;
         end;

      if glyphs > aWidth then
         begin
         Inc(GClip);
         WriteLn(Format('CLIP %4d  %-22s %-24s %-13s has=%4d text=%4d pref=%4d  "%s"',
                        [glyphs - aWidth, aForm, aName, aClass, aWidth, glyphs,
                         pw, aCaption]));
         end
      else if needs > aWidth then
         begin
         Inc(GSnug);
         WriteLn(Format('snug %4d  %-22s %-24s %-13s has=%4d text=%4d pref=%4d  "%s"',
                        [needs - aWidth, aForm, aName, aClass, aWidth, glyphs,
                         pw, aCaption]));
         end;
   finally
      c.Free;
   end;
end;

procedure SplitTabs(const aLine: string; out aFields: TStringArray);
(* TStringList.DelimitedText is not usable here: it still honours quote
   characters with StrictDelimiter set, and a caption may contain one. *)
var
   i, n, start: integer;
begin
   n := 1;
   for i := 1 to Length(aLine) do
      begin
      if aLine[i] = #9 then
         begin
         Inc(n);
         end;
      end;
   SetLength(aFields, n);
   n     := 0;
   start := 1;
   for i := 1 to Length(aLine) + 1 do
      begin
      if (i > Length(aLine)) or (aLine[i] = #9) then
         begin
         aFields[n] := Copy(aLine, start, i - start);
         Inc(n);
         start := i + 1;
         end;
      end;
end;

var
   lines:  TStringList;
   fields: TStringArray;
   i:      integer;
begin
   if ParamStr(1) = '' then
      begin
      WriteLn('usage: textfit_probe <captions.tsv>   (see extract_captions.py)');
      Halt(2);
      end;

   Application.Initialize;
   GForm := TForm.Create(nil);
   try
      GForm.SetBounds(0, 0, 900, 700);
      (* REALISED, not merely constructed -- see the header. *)
      GForm.Show;
      Application.ProcessMessages;

      lines := TStringList.Create;
      try
         lines.LoadFromFile(ParamStr(1));
         WriteLn('kind over  form                   control                  class         ',
                 '  has  text  pref  caption');
         for i := 0 to lines.Count - 1 do
            begin
            SplitTabs(lines[i], fields);
            if Length(fields) < 8 then
               begin
               Continue;
               end;
            Measure(fields[0], fields[1], fields[2], StrToIntDef(fields[3], 0),
                    StrToIntDef(fields[4], 0), fields[5], fields[6] = '1',
                    fields[7]);
            end;
      finally
         lines.Free;
      end;

      WriteLn('');
      WriteLn(Format('%d fixed-width caption(s) measured: %d CLIP, %d snug',
                     [GTotal, GClip, GSnug]));
   finally
      GForm.Free;
   end;
end.
