{ Checks every property named in a .lfm against the LCL's own RTTI.

  WHY THIS EXISTS.  The FMX -> LCL port carries form resources across two
  component libraries whose properties only mostly overlap, and the failure
  mode is punishing: LCL form streaming aborts at the FIRST bad property, so a
  file with five defects reveals them one build-run-crash cycle at a time.
  Worse, the IDE's own "Fix LFM" dialog offers to REMOVE what it cannot
  resolve, which silently discards meaning -- TRadioButton.GroupName is the
  live example, since LCL groups radio buttons by PARENT and dropping the
  property fuses three independent groups into one.

  WHY RTTI RATHER THAN READING stdctrls.pp.  A published property can be
  inherited through several ancestors, so "is it in this class's published
  block" is the wrong question and grep answers it wrongly.  GetPropInfo walks
  the chain the same way the streaming system does, which makes this tool
  agree with the loader by construction rather than by care.

  The class list below is not a guess: it is every class named by an `object`
  line across the four .lfm files (regenerate with the grep in the header of
  spike/fpc-run-menu.ps1's sibling audit).  A class that is not registered is
  REPORTED, never skipped -- an unknown class silently passing would defeat
  the whole point. }
program lintlfm;

{$MODE DELPHI}{$H+}

uses
   // Interfaces supplies the widgetset's WSRegister* symbols. Linking Forms
   // without it fails at link time with 50 undefined WSRegisterXxx -- the LCL
   // is split into interface and widgetset halves and both must be present
   // even for a tool that never opens a window.
   Interfaces,
   SysUtils,
   Classes,
   TypInfo,
   Forms,
   Controls,
   StdCtrls,
   ComCtrls,
   ExtCtrls,
   Spin,       // TSpinEdit -- Auto-CQ's delay field
   Grids,      // TStringGrid -- the band plan and the beacon monitor
   Buttons;    // TSpeedButton -- the beacon monitor's push-like radio group

var
   gFiles:  integer = 0;
   gProps:  integer = 0;
   gValues: integer = 0;
   gBad:    integer = 0;

// The form classes in the .lfm files are the project's own descendants of
// TForm.  We cannot link the project here, so they are checked AS TForm --
// correct for every property a designer writes, because a designed property
// must be published, and none of these forms publishes anything of its own.
//
// WHICH CLASS GETS THAT TREATMENT IS DECIDED BY POSITION, NOT BY NAME.  This
// used to be a hardcoded list -- TPrefsForm, TRadioEditForm, TfrmKeyerEdit,
// TfrmUDPDestinationEdit -- and the fifth form added (TfrmAltD, Phase 4a)
// failed the lint on its first run for no reason but not being on it.  Phase 4
// converts roughly twenty more; a list that must be edited once per form is a
// list that will be forgotten, and the failure it produces looks exactly like a
// real defect.
//
// The ROOT object of an .lfm for a form IS the form class, so an unresolvable
// name at stack depth 1 is checked as TForm.  Nested objects keep the strict
// treatment: an unknown class inside the tree is still reported, which is what
// catches a mistyped control class.
function ResolveClass(const aName: string; const aIsRoot: boolean): TPersistentClass;
begin
   Result := GetClass(aName);

   if (Result = nil) and aIsRoot then
      begin
      Result := TForm;
      end;
end;

// 'Font.Height' streams by asking the object for 'Font' and then recursing, so
// only the ROOT name is a property of this class.  Checking the whole dotted
// string would report every legitimate sub-property as missing.
function RootOf(const aProp: string): string;
var
   dot: integer;
begin
   dot := Pos('.', aProp);
   if dot > 0 then
      begin
      Result := Copy(aProp, 1, dot - 1);
      end
   else
      begin
      Result := aProp;
      end;
end;

// Enum and set VALUES.  Every LCL enum member carries a prefix (alLeft,
// bvNone, bsSingle, csDropDown, poScreenCenter); the FMX spellings are bare
// (Left, Client).  GetEnumValue returns -1 for a name the type does not have,
// which is exactly the test the streaming loader applies.
//
// Deliberately silent on every other kind.  Strings, numbers and method names
// cannot be judged here -- a method name would need the form's own RTTI, which
// this tool does not link -- and a checker that guessed at them would produce
// false positives on correct files, which is how a linter gets ignored.
procedure CheckValue(const aPath: string; aLine: integer;
                     const aClass, aProp, aValue: string;
                     aInfo: PPropInfo);

   procedure Bad(const aWhat: string);
   begin
      WriteLn(Format('%s(%d): %s.%s = %s -- %s',
                     [ExtractFileName(aPath), aLine, aClass, aProp,
                      aValue, aWhat]));
      Inc(gBad);
   end;

var
   kind:    TTypeKind;
   inner:   string;
   member:  string;
   comma:   integer;
   baseTI:  PTypeInfo;
begin
   if aValue = '' then
      begin
      Exit;
      end;

   kind := aInfo^.PropType^.Kind;

   if kind = tkEnumeration then
      begin
      // Booleans are tkEnumeration in FPC and True/False ARE members of the
      // type, so they validate without a special case.
      Inc(gValues);
      if GetEnumValue(aInfo^.PropType, aValue) < 0 then
         begin
         Bad(Format('not a member of %s', [aInfo^.PropType^.Name]));
         end;
      Exit;
      end;

   if kind = tkSet then
      begin
      // "[biSystemMenu, biMinimize]", or "[]" for the empty set.  A set that
      // spans lines is skipped rather than half-parsed -- see the note above
      // about false positives.
      if (Length(aValue) < 2) or (aValue[1] <> '[') or
         (aValue[Length(aValue)] <> ']') then
         begin
         Exit;
         end;

      baseTI := GetTypeData(aInfo^.PropType)^.CompType;
      inner  := Trim(Copy(aValue, 2, Length(aValue) - 2));

      while inner <> '' do
         begin
         comma := Pos(',', inner);
         if comma > 0 then
            begin
            member := Trim(Copy(inner, 1, comma - 1));
            inner  := Trim(Copy(inner, comma + 1, MaxInt));
            end
         else
            begin
            member := inner;
            inner  := '';
            end;

         if member <> '' then
            begin
            Inc(gValues);
            if GetEnumValue(baseTI, member) < 0 then
               begin
               Bad(Format('%s is not a member of %s', [member, baseTI^.Name]));
               end;
            end;
         end;
      end;
end;

procedure CheckFile(const aPath: string);
var
   lines:    TStringList;
   stack:    TStringList;   // class name per nesting level
   i, eq:    integer;
   raw, s:   string;
   propName: string;
   propValue: string;
   info:     PPropInfo;
   objName:  string;
   clsName:  string;
   cls:      TPersistentClass;
begin
   lines := TStringList.Create;
   stack := TStringList.Create;
   try
      lines.LoadFromFile(aPath);
      Inc(gFiles);

      for i := 0 to lines.Count - 1 do
         begin
         raw := lines[i];
         s   := Trim(raw);

         if s = '' then
            begin
            Continue;
            end;

         // "object Name: TClass" opens a scope; "end" closes the innermost.
         if (Pos('object ', s) = 1) or (Pos('inline ', s) = 1) then
            begin
            objName := Copy(s, Pos(' ', s) + 1, MaxInt);
            clsName := Trim(Copy(objName, Pos(':', objName) + 1, MaxInt));
            stack.Add(clsName);
            Continue;
            end;

         if s = 'end' then
            begin
            if stack.Count > 0 then
               begin
               stack.Delete(stack.Count - 1);
               end;
            Continue;
            end;

         if stack.Count = 0 then
            begin
            Continue;
            end;

         // A property line is "Name = value".  Collection items, binary blobs
         // and continuation lines are not, and are skipped rather than guessed
         // at: a false positive here would be worse than a miss, because it
         // would train the reader to ignore the tool.
         eq := Pos(' = ', s);
         if eq <= 1 then
            begin
            Continue;
            end;

         propValue := Trim(Copy(s, eq + 3, MaxInt));
         propName  := RootOf(Copy(s, 1, eq - 1));
         if (propName = '') or not (propName[1] in ['A'..'Z', 'a'..'z', '_']) then
            begin
            Continue;
            end;

         clsName := stack[stack.Count - 1];
         cls     := ResolveClass(clsName, stack.Count = 1);

         if cls = nil then
            begin
            WriteLn(Format('%s(%d): UNKNOWN CLASS %s -- cannot check %s',
                           [ExtractFileName(aPath), i + 1, clsName, propName]));
            Inc(gBad);
            Continue;
            end;

         Inc(gProps);

         info := GetPropInfo(cls.ClassInfo, propName);

         if info = nil then
            begin
            WriteLn(Format('%s(%d): %s has no published %s',
                           [ExtractFileName(aPath), i + 1, clsName, propName]));
            Inc(gBad);
            Continue;
            end;

         // The NAME being real is only half of it.  "Align = Left" names a
         // published property and gives it FMX's spelling of the value, and
         // that was the very first defect this port hit -- so checking names
         // alone would have declared the file clean and left the crash in
         // place.  Only dotted-free enum and set properties are checked, which
         // is where the FMX/LCL spellings actually differ.
         if Pos('.', Copy(s, 1, eq - 1)) = 0 then
            begin
            CheckValue(aPath, i + 1, clsName, propName, propValue, info);
            end;
         end;
   finally
      stack.Free;
      lines.Free;
   end;
end;

var
   n: integer;

begin
   // THE CLASSES THIS TOOL CAN RESOLVE BY NAME.
   //
   // GetClass answers from the RegisterClass table, and the LCL does not
   // register its controls -- linking ExtCtrls is not enough, the class has to
   // be named here. So this IS a list, and unlike the form-class list removed
   // above it cannot be replaced by a positional rule: an unresolvable control
   // name in the middle of a tree is exactly the typo (TEditt, TLabell) this
   // lint should fail on, so it must keep failing closed.
   //
   // What it CAN do is not fail on legitimate controls, which means listing
   // generously rather than reactively. TImage was missing and the first form
   // to use one failed the build for no better reason (2026-08-18) -- the same
   // shape of defect as the hardcoded form-class list.
   //
   // Everything below comes from a unit this program already links, so widening
   // the list costs nothing. If a form uses a control that is not here, the
   // failure names it and the fix is one identifier.
   RegisterClasses([TForm, TPanel, TLabel, TButton, TCheckBox, TEdit,
                    TComboBox, TListBox, TGroupBox, TTreeView, TPageControl,
                    TTabSheet, TRadioButton,
                    // StdCtrls
                    TMemo, TStaticText, TScrollBar,
                    // ExtCtrls
                    TImage, TShape, TBevel, TRadioGroup, TCheckGroup,
                    TSplitter, TScrollBox, TTimer, TPaintBox,
                    // ComCtrls
                    TListView, TProgressBar, TTrackBar, TStatusBar, TToolBar,
                    TUpDown,
                    // Spin
                    TSpinEdit, TFloatSpinEdit,
                    // Grids
                    TStringGrid, TDrawGrid,
                    // Buttons
                    TSpeedButton, TBitBtn]);

   if ParamCount = 0 then
      begin
      WriteLn('usage: lintlfm <file.lfm> [file.lfm ...]');
      Halt(2);
      end;

   for n := 1 to ParamCount do
      begin
      CheckFile(ParamStr(n));
      end;

   WriteLn;
   WriteLn(Format('lintlfm: %d file(s), %d properties and %d enum/set values checked, %d unstreamable.',
                  [gFiles, gProps, gValues, gBad]));

   if gBad > 0 then
      begin
      Halt(1);
      end;
end.
