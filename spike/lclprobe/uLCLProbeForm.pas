unit uLCLProbeForm;

{
  LCL PROBE -- pins the .fmx -> .lfm type and property mapping against the REAL
  Lazarus toolchain, before a converter is written against it.

  WHY.  The five designed FMX forms hold 467 control instances, and nine types
  account for 449 of them.  Every one of those nine exists in the LCL under the
  SAME NAME, and the properties that matter map one-to-one:

      Size.Width  -> Width     Position.X -> Left     Text -> Caption / Text
      Size.Height -> Height    Position.Y -> Top      TabOrder, Tag unchanged
      Size.PlatformDefault, FormFactor.*, DesignerMasterStyle -> dropped

  That makes the port a CONVERTER rather than a designer marathon -- but only if
  a hand-generated .lfm actually compiles and streams.  This form is that claim,
  written by hand exactly as a converter would emit it, and built by lazbuild.

  It deliberately covers the four AWKWARD cases alongside the easy nine, because
  those are where a converter has to make a decision rather than a substitution:

      TLayout       (22) -- FMX's invisible grouping container.  No LCL twin;
                            the candidates are TPanel with BevelOuter = bvNone,
                            or dropping it and re-parenting its children.
      TTabControl   (1)  -- LCL has TPageControl / TTabSheet, not TTabItem.
      TTreeView     (1)  -- LCL's TTreeView holds TTreeNode built in CODE, not
      TTreeViewItem (27)    streamed as 27 design-time child objects.
      TComboEdit    (1)  -- no LCL equivalent; TComboBox with Style csDropDown.

  What this form asserts is only what a converter can rely on.  The awkward four
  are represented by their PROPOSED substitutes so the probe reports whether the
  substitute behaves, not whether the FMX original does.
}

{$mode objfpc}{$H+}

interface

uses
   Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls;

type
   TLCLProbeForm = class(TForm)
      // --- the nine that map by name -------------------------------------
      lblAddress:   TLabel;
      lblSized:     TLabel;
      edtAddress:   TEdit;
      chkEnabled:   TCheckBox;
      btnOK:        TButton;
      cboMode:      TComboBox;
      radA:         TRadioButton;
      radB:         TRadioButton;
      lstItems:     TListBox;
      grpBox:       TGroupBox;

      // --- the awkward four, as their proposed substitutes ----------------
      pnlLayout:    TPanel;        // stands in for FMX TLayout
      pgcTabs:      TPageControl;  // stands in for FMX TTabControl
      tabOne:       TTabSheet;     // stands in for FMX TTabItem
      trvTree:      TTreeView;     // TTreeViewItem children built in code
      cboEditable:  TComboBox;     // stands in for FMX TComboEdit

      procedure btnOKClick(Sender: TObject);
   end;

// Returns a one-line-per-check report of what actually streamed.
function ProbeReport(aForm: TLCLProbeForm): TStringList;

implementation

{$R *.lfm}

procedure TLCLProbeForm.btnOKClick(Sender: TObject);
begin
   // Present only so the .lfm can carry OnClick = btnOKClick and prove that an
   // event name survives the conversion unchanged -- Lint-FormEvents gates that
   // both ways on the FMX side and must keep working on the LCL side.
   Close;
end;

function ProbeReport(aForm: TLCLProbeForm): TStringList;

   procedure Chk(aList: TStringList; const aName: string; aOK: boolean; const aDetail: string);
   begin
      if aOK then
         begin
         aList.Add(Format('  OK    %-16s %s', [aName, aDetail]));
         end
      else
         begin
         aList.Add(Format('  FAIL  %-16s %s', [aName, aDetail]));
         end;
   end;

begin
   Result := TStringList.Create;

   // Every control streamed at all -- a nil here means the .lfm named something
   // the LCL did not create, which is the failure a converter must never cause
   // silently.
   Chk(Result, 'TLabel',       aForm.lblAddress <> nil, 'Caption=' + aForm.lblAddress.Caption);
   Chk(Result, 'TEdit',        aForm.edtAddress <> nil, 'Text=' + aForm.edtAddress.Text);
   Chk(Result, 'TCheckBox',    aForm.chkEnabled <> nil, 'Checked=' + BoolToStr(aForm.chkEnabled.Checked, True));
   Chk(Result, 'TButton',      aForm.btnOK <> nil,      'Caption=' + aForm.btnOK.Caption);
   Chk(Result, 'TComboBox',    aForm.cboMode <> nil,    Format('Items=%d', [aForm.cboMode.Items.Count]));
   Chk(Result, 'TRadioButton', aForm.radA <> nil,       'Caption=' + aForm.radA.Caption);
   Chk(Result, 'TListBox',     aForm.lstItems <> nil,   Format('Items=%d', [aForm.lstItems.Items.Count]));
   Chk(Result, 'TGroupBox',    aForm.grpBox <> nil,     'Caption=' + aForm.grpBox.Caption);
   Chk(Result, 'TPanel',       aForm.pnlLayout <> nil,  '(stands in for TLayout)');
   Chk(Result, 'TPageControl', aForm.pgcTabs <> nil,    Format('Pages=%d', [aForm.pgcTabs.PageCount]));
   Chk(Result, 'TTabSheet',    aForm.tabOne <> nil,     'Caption=' + aForm.tabOne.Caption);
   Chk(Result, 'TTreeView',    aForm.trvTree <> nil,    '(items built in code, not streamed)');

   // The property mapping, checked by VALUE rather than by presence -- a
   // converter that emits Left where it meant Top would still stream cleanly.
   Result.Add('');
   Chk(Result, 'Left',     aForm.lblAddress.Left = 16,    'Position.X 16 -> Left');
   Chk(Result, 'Top',      aForm.lblAddress.Top = 18,     'Position.Y 18 -> Top');
   // THE HAZARD, asserted rather than merely observed.  LCL controls autosize
   // by DEFAULT and FMX ones do not, so a streamed Width/Height is accepted and
   // then overridden.  lblAddress carries no AutoSize, and its 90 becomes
   // whatever fits 'Address'.
   Chk(Result, 'AutoSize hazard', aForm.lblAddress.Width <> 90,
       Format('no AutoSize=False -> 90 became %d (AutoSize=%s)',
              [aForm.lblAddress.Width, BoolToStr(aForm.lblAddress.AutoSize, True)]));

   // THE FIX the converter must emit for all 434 explicitly-sized controls.
   Chk(Result, 'AutoSize fix', aForm.lblSized.Width = 90,
       Format('AutoSize=False -> Width honoured at %d', [aForm.lblSized.Width]));

   // Non-autosizing dimensions come through untouched, which is what makes the
   // hazard insidious: it is not "sizes are ignored", it is only some of them.
   Chk(Result, 'Width(edt)', aForm.edtAddress.Width = 200,
       Format('actual=%d', [aForm.edtAddress.Width]));
   Chk(Result, 'Height(pnl)', aForm.pnlLayout.Height = 60,
       Format('actual=%d AutoSize=%s',
              [aForm.pnlLayout.Height, BoolToStr(aForm.pnlLayout.AutoSize, True)]));
   Chk(Result, 'TabOrder', aForm.edtAddress.TabOrder = 1, 'TabOrder survives');

   // Tag is load-bearing: TPrefsForm dispatches its navigation by Tag and
   // Lint-FormTags gates it, so it has to survive the conversion.
   Chk(Result, 'Tag',      aForm.pnlLayout.Tag = 7,       'Tag 7 survives');

   // An event name reaching its handler is what lets the Pascal stay put.
   Chk(Result, 'OnClick',  Assigned(aForm.btnOK.OnClick), 'OnClick bound to btnOKClick');

   Chk(Result, 'Anchors',  aForm.edtAddress.Anchors <> [], Format('Anchors=%d flags', [Ord(akLeft in aForm.edtAddress.Anchors)]));
end;

end.
