program MacLclAxControl;

{$mode objfpc}{$H+}

uses
   Interfaces, Forms, Classes, Controls, StdCtrls, ComCtrls, ExtCtrls;

type
   TFixtureForm = class(TForm)
   public
      constructor Create(AOwner: TComponent); override;
   end;

var
   FixtureForm: TFixtureForm;

function AddButton(AOwner: TComponent; AParent: TWinControl;
   const ACaption: string; ATop: Integer): TButton;
begin
   Result := TButton.Create(AOwner);
   Result.Parent := AParent;
   Result.Caption := ACaption;
   Result.SetBounds(12, ATop, 190, 30);
end;

constructor TFixtureForm.Create(AOwner: TComponent);
var
   Pages: TPageControl;
   FirstPage: TTabSheet;
   SecondPage: TTabSheet;
   LeftPanel: TPanel;
   HiddenPanel: TPanel;
   Divider: TSplitter;
   Status: TStatusBar;
begin
   inherited CreateNew(AOwner);
   Caption := 'LCL AX container control: ' + ParamStr(1);
   SetBounds(400, 300, 720, 420);

   Status := TStatusBar.Create(Self);
   Status.Parent := Self;
   Status.Align := alBottom;
   Status.Height := 42;
   AddButton(Self, Status, 'Status action', 4);

   LeftPanel := TPanel.Create(Self);
   LeftPanel.Parent := Self;
   LeftPanel.Align := alLeft;
   LeftPanel.Width := 220;
   AddButton(Self, LeftPanel, 'Panel action', 18);

   Divider := TSplitter.Create(Self);
   Divider.Parent := Self;
   Divider.Align := alLeft;
   Divider.Left := LeftPanel.Width;
   Divider.Width := 8;

   Pages := TPageControl.Create(Self);
   Pages.Parent := Self;
   Pages.Align := alClient;
   FirstPage := TTabSheet.Create(Self);
   FirstPage.PageControl := Pages;
   FirstPage.Caption := 'First';
   AddButton(Self, FirstPage, 'First page action', 18);
   SecondPage := TTabSheet.Create(Self);
   SecondPage.PageControl := Pages;
   SecondPage.Caption := 'Second';
   AddButton(Self, SecondPage, 'Second page action', 18);
   AddButton(Self, FirstPage, 'Hidden button sentinel', 70).Visible := False;
   AddButton(Self, SecondPage, 'Hidden button sentinel', 70).Visible := False;
   HiddenPanel := TPanel.Create(Self);
   HiddenPanel.Parent := Self;
   HiddenPanel.SetBounds(20, 200, 220, 80);
   AddButton(Self, HiddenPanel, 'Hidden panel sentinel', 12);
   HiddenPanel.Visible := False;

   if ParamStr(1) = 'second' then
      begin
      Pages.ActivePage := SecondPage;
      end
   else
      begin
      Pages.ActivePage := FirstPage;
      end;
end;

begin
   Application.Initialize;
   Application.CreateForm(TFixtureForm, FixtureForm);
   Application.Run;
end.
