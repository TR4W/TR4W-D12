(*
  Streams every .lfm through the LCL's REAL loader and reports what it says.

  WHY THIS EXISTS, and it is a shipped regression rather than a theory.
  5.0.20 and 5.0.21 could not open Preferences at all:

     EReadError: Error reading btnOK.AnchorSideRight.Side: Invalid value
     for property

  because the .lfm named `asrLeft`, which is a CONSTANT in controls.pp
  (asrLeft = asrTop) and not a member of TAnchorSideReference. An .lfm streams
  an enum BY NAME, so the loader had no such name to find.

  Lint-LFMProperties passed that commit -- 46 files, 0 unstreamable -- and the
  layout was "verified" by rebuilding the button row in code and running that,
  which never opened the .lfm at all. Two green checks, neither of which had
  asked the loader anything.

  SO THIS ASKS THE LOADER. ObjectTextToBinary + TReader is the same code path
  the program runs when it constructs a form, so a pass here means the bytes
  stream. Two deliberate substitutions, each of which affects nothing the
  loader validates:

    - THE ROOT IS A PLAIN TForm. The form classes live in units that drag in
      most of the program (uPrefsForm alone reaches the radio and keyer
      stores), and a designed property must be PUBLISHED, so it is inherited
      from TForm or TControl in every case. TReader honours an instance passed
      to ReadRootComponent and never consults the root's class name.
    - EVENT NAMES RESOLVE TO NIL, via OnFindMethod with Error := False. The
      method address needs the form's own RTTI, which is the thing we are not
      linking. Lint-FormEvents is what checks those names exist.

  Everything else is the genuine article: the same TReader, the same
  GetEnumValue, the same component classes, the same property RTTI.

  Build and run it through Test-LFMLoad.ps1, which finds the toolchain the way
  every other script here does.
*)
program lfmload;

{$MODE DELPHI}{$H+}

uses
   (* Interfaces supplies the widgetset half of the LCL. Linking Forms without
      it fails at link time on ~50 undefined WSRegisterXxx, even for a tool
      that never shows a window. *)
   Interfaces,
   SysUtils,
   Classes,
   Forms,
   Controls,
   StdCtrls,
   ComCtrls,
   ExtCtrls,
   Spin,
   Grids,
   Buttons,
   Menus,
   Dialogs,
   DateTimePicker,
   uElementPanel;

var
   gFiles: integer = 0;
   gBad:   integer = 0;

type
   (* TReader's two escape hatches, as an object so they can be methods. *)
   TLoaderHooks = class
      Missing: TStringList;
      constructor Create;
      destructor Destroy; override;
      procedure FindMethod(Reader: TReader; const aMethodName: string;
                           var aAddress: Pointer; var aError: boolean);
      procedure FindComponentClass(Reader: TReader; const aClassName: string;
                                   var aComponentClass: TComponentClass);
   end;

constructor TLoaderHooks.Create;
begin
   inherited Create;
   Missing := TStringList.Create;
   Missing.Duplicates := dupIgnore;
   Missing.Sorted     := True;
end;

destructor TLoaderHooks.Destroy;
begin
   Missing.Free;
   inherited Destroy;
end;

(* An event name cannot be resolved without the form's own RTTI. Saying so is
   honest; failing on it would make this tool unusable for the one question it
   exists to answer. Lint-FormEvents owns that question. *)
procedure TLoaderHooks.FindMethod(Reader: TReader; const aMethodName: string;
                                  var aAddress: Pointer; var aError: boolean);
begin
   aAddress := nil;
   aError   := False;
end;

(* A class the loader cannot resolve is RECORDED, not silently skipped -- an
   unknown class means the check did not happen for everything inside it. *)
procedure TLoaderHooks.FindComponentClass(Reader: TReader; const aClassName: string;
                                          var aComponentClass: TComponentClass);
begin
   if aComponentClass = nil then
      begin
      Missing.Add(aClassName);
      end;
end;

function LoadOne(const aPath: string): boolean;
var
   text:   TMemoryStream;
   bin:    TMemoryStream;
   reader: TReader;
   hooks:  TLoaderHooks;
   root:   TForm;
   n:      integer;
begin
   Result := True;
   Inc(gFiles);

   text  := TMemoryStream.Create;
   bin   := TMemoryStream.Create;
   hooks := TLoaderHooks.Create;
   root  := nil;
   reader := nil;
   try
      try
         text.LoadFromFile(aPath);
         text.Position := 0;
         ObjectTextToBinary(text, bin);
         bin.Position := 0;

         (* CreateNew, not Create: Create would go looking for a resource of
            its own. *)
         root := TForm.CreateNew(nil, 1);

         reader := TReader.Create(bin, 4096);
         reader.OnFindMethod         := hooks.FindMethod;
         reader.OnFindComponentClass := hooks.FindComponentClass;
         reader.ReadRootComponent(root);

         for n := 0 to hooks.Missing.Count - 1 do
            begin
            WriteLn(Format('%s: UNKNOWN CLASS %s -- nothing inside it was checked',
                           [ExtractFileName(aPath), hooks.Missing[n]]));
            Result := False;
            end;
      except
         on e: Exception do
            begin
            WriteLn(Format('%s: %s: %s',
                           [ExtractFileName(aPath), e.ClassName, e.Message]));
            Result := False;
            end;
      end;
   finally
      reader.Free;
      root.Free;
      hooks.Free;
      bin.Free;
      text.Free;
   end;

   if not Result then
      begin
      Inc(gBad);
      end;
end;

var
   n: integer;

begin
   (* GetClass answers from the RegisterClass table and the LCL does not
      register its own controls. This list is lintlfm's, for the same reason
      and with the same rule: list generously, because a legitimate control
      that is missing here looks exactly like a real defect. *)
   RegisterClasses([TForm, TPanel, TLabel, TButton, TCheckBox, TEdit,
                    TComboBox, TListBox, TGroupBox, TTreeView, TPageControl,
                    TTabSheet, TRadioButton,
                    TMemo, TStaticText, TScrollBar,
                    TImage, TShape, TBevel, TRadioGroup, TCheckGroup,
                    TSplitter, TScrollBox, TTimer, TPaintBox,
                    TOpenDialog,
                    TListView, TProgressBar, TTrackBar, TStatusBar, TToolBar,
                    TUpDown,
                    TSpinEdit, TFloatSpinEdit,
                    TElementPanel,
                    TStringGrid, TDrawGrid,
                    TSpeedButton, TBitBtn,
                    TPopupMenu, TMenuItem, TMainMenu,
                    TDateTimePicker]);

   if ParamCount = 0 then
      begin
      WriteLn('usage: lfmload <file.lfm> [file.lfm ...]');
      Halt(2);
      end;

   Application.Initialize;

   for n := 1 to ParamCount do
      begin
      LoadOne(ParamStr(n));
      end;

   WriteLn;
   WriteLn(Format('lfmload: %d form(s) streamed by the real LCL loader, %d failed.',
                  [gFiles, gBad]));

   if gBad > 0 then
      begin
      Halt(1);
      end;
end.
