{
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
}
unit uSettingsBinding;

{
  BINDS A CONTROL TO A SETTING, so a panel declares WHAT it edits and never how.

  THE PROBLEM THIS SOLVES.  Every panel so far carries a hand-written
  LoadXPanel/SaveXPanel pair: read this command into that edit, trim it, put it
  back, remember it is a boolean, remember it needs a drop-down.  Thirty
  settings is sixty lines of that, each line a place to mistype a command name
  or forget a Trim -- and the compiler cannot check any of it.  With a binding,
  a panel says:

      Bind(chkSayHi,     'operating.cw.sayHi');
      Bind(cbxLeadZeros, 'operating.cw.leadingZeros');

  and load, save, validation, allow-lists and the drop-down-or-text-box decision
  all follow from the setting itself.

  THE LEGACY BRIDGE, and why it is one class rather than thirty closures.
  Most settings still live in CFGCA, whose crAddress is an untyped pointer that
  is sometimes not even an address -- the design NY4I objected to and the source
  of the SCP MINIMUM LETTERS access violation.  It cannot all be converted at
  once, so TLegacySetting adapts one CFGCA row to the registry's interface:
  reading through CFGCommandValueAsString, writing through CheckCommand so the
  row's bounds and crA hook still run.

  The point is CONTAINMENT.  That indirection now exists in exactly one class,
  behind the same interface as every other setting.  A panel cannot tell a
  legacy setting from a modern one, so when a row graduates -- to a typed
  closure over its global, or to a self-storing setting with no global at all --
  its registration changes and NOT ONE LINE of the panel does.

  ON ORDERING.  A binding does not read the control at construction; it reads it
  when told to.  Streaming a form fires OnChange for controls whose panel is not
  built yet, so anything that acted on construction would act on a half-formed
  form -- the same trap SelectFirstSection documents.
}

interface

uses
   SysUtils,
   Generics.Collections,
   FMX.StdCtrls,
   FMX.Edit,
   FMX.ListBox,
   uSettingsRegistry;

type
   { One control tied to one setting key. }
   TSettingBinding = class(TObject)
   private
      FKey: string;
      FCheck: TCheckBox;
      FEdit: TEdit;
      FCombo: TComboBox;
   public
      constructor Create(const aKey: string);

      { Control -> setting.  False means the setting REFUSED the value, with
        aError saying why; the setting keeps what it had. }
      function Save(out aError: string): boolean;

      { Setting -> control.  Also fills a combo's items from the setting's
        allowed values, so the offered list cannot drift from the accepted one. }
      procedure Load;

      property Key: string read FKey;
   end;

   { The bindings for one form.  Owns them; free it with the form. }
   TSettingBindings = class(TObject)
   private
      FItems: TObjectList<TSettingBinding>;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Bind(const aControl: TCheckBox; const aKey: string); overload;
      procedure Bind(const aControl: TEdit; const aKey: string); overload;
      procedure Bind(const aControl: TComboBox; const aKey: string); overload;

      procedure LoadAll;

      { Saves every binding.  Returns False if ANY was refused, with aErrors
        listing each -- reported together rather than one dialog per field,
        which is what makes a panel of thirty settings usable. }
      function SaveAll(out aErrors: string): boolean;

      function Count: integer;
   end;

{ Registers a CFGCA row as a setting under a modern key.

  aKey is the JSON/store key ('operating.cw.sayHi'); aCommand is the CFGCA row
  ('SAY HI ENABLE').  The two are deliberately different: the key is ours and
  stable, the command is the legacy spelling and will eventually go. }
function RegisterLegacySetting(const aKey, aCommand, aCaption: string): TSettingBase;

implementation

uses
   uCFG,
   MainUnit;   // logger

type
   { A CFGCA row wearing the registry's interface.  See the unit header for why
     this is one class rather than a closure per row. }
   TLegacySetting = class(TSettingBase)
   private
      FCommand: string;
   public
      constructor Create(const aKey, aCommand, aCaption: string);
      function AsText: string; override;
      function TrySetText(const aText: string; out aError: string): boolean; override;
      function AllowedValues: TArray<string>; override;
      property Command: string read FCommand;
   end;

{ ---------------------------------------------------------- TLegacySetting - }

constructor TLegacySetting.Create(const aKey, aCommand, aCaption: string);
var
   idx: integer;
begin
   inherited Create(aKey, aCaption);
   FCommand := aCommand;

   idx := FindCFGCommand(aCommand);
   if idx < 0 then
      begin
      // Loud at registration.  A mistyped command name would otherwise present
      // as a control that reads blank and silently discards what is typed into
      // it -- and it would do so only when that panel is opened.
      raise Exception.CreateFmt('Setting "%s": no CFGCA command called "%s"',
                                [aKey, aCommand]);
      end;

   // crJ:1 is the table's way of saying "restart required".  Lifting it here
   // means a UI can say so without every panel hard-coding which of its fields
   // are which.
   NeedsRestart := (CFGCA[idx].crJ = 1);
end;

function TLegacySetting.AsText: string;
begin
   Result := CFGCommandValueAsString(FCommand);
end;

function TLegacySetting.AllowedValues: TArray<string>;
begin
   // Only ckArray rows answer this today.  ckList rows have a spelling list
   // too, but it lives in a different array reached through a different index,
   // and those are being converted to TEnumSetting rather than taught here --
   // adding a second lookup would be extending the design we are leaving.
   Result := CFGCommandAllowedValues(FCommand);
end;

function TLegacySetting.TrySetText(const aText: string; out aError: string): boolean;
begin
   aError := '';

   // Through CheckCommand, not by assignment: it is what enforces crMin/crMax,
   // runs the row's crA hook, and knows which typed global the value belongs
   // in.  Bypassing it is what the SCP MINIMUM LETTERS access violation came
   // from.
   Result := SetCFGCommandValue(FCommand, aText);
   if not Result then
      begin
      aError := Format('%s does not accept "%s"', [FCommand, aText]);
      Exit;
      end;

   if Assigned(OnApply) then
      begin
      OnApply();
      end;
end;

function RegisterLegacySetting(const aKey, aCommand, aCaption: string): TSettingBase;
begin
   Result := RegisterSetting(TLegacySetting.Create(aKey, aCommand, aCaption));
end;

{ --------------------------------------------------------- TSettingBinding - }

constructor TSettingBinding.Create(const aKey: string);
begin
   inherited Create;
   FKey := aKey;
end;

procedure TSettingBinding.Load;
var
   s: TSettingBase;
   allowed: TArray<string>;
   v: string;
   i: integer;
begin
   s := FindSetting(FKey);
   if s = nil then
      begin
      logger.Error('[SettingBinding] no setting called "%s"', [FKey]);
      Exit;
      end;

   if FCheck <> nil then
      begin
      FCheck.IsChecked := SameText(s.AsText, 'TRUE');
      Exit;
      end;

   if FEdit <> nil then
      begin
      FEdit.Text := s.AsText;
      Exit;
      end;

   if FCombo <> nil then
      begin
      // FILLED FROM THE SETTING, never from the designer.  A populated combo
      // bakes itself into the .fmx resource, so a hand-entered list becomes a
      // permanent second copy that keeps working while it drifts from what the
      // setting will actually accept.
      allowed := s.AllowedValues;
      FCombo.BeginUpdate;
      try
         FCombo.Clear;
         for v in allowed do
            begin
            FCombo.Items.Add(v);
            end;
      finally
         FCombo.EndUpdate;
      end;

      i := FCombo.Items.IndexOf(Trim(s.AsText));
      if (i < 0) and (Length(allowed) > 0) then
         begin
         // The stored value is not one this build offers.  Selecting nothing
         // is right: guessing at the first item would quietly rewrite the
         // operator's setting to something they never chose.
         logger.Warn('[SettingBinding] %s holds "%s", which is not one of its values',
                     [FKey, s.AsText]);
         end;
      FCombo.ItemIndex := i;
      end;
end;

function TSettingBinding.Save(out aError: string): boolean;
var
   s: TSettingBase;
begin
   aError := '';
   Result := True;

   s := FindSetting(FKey);
   if s = nil then
      begin
      logger.Error('[SettingBinding] no setting called "%s"', [FKey]);
      Exit;
      end;

   if FCheck <> nil then
      begin
      if FCheck.IsChecked then
         begin
         Result := s.TrySetText('TRUE', aError);
         end
      else
         begin
         Result := s.TrySetText('FALSE', aError);
         end;
      Exit;
      end;

   if FEdit <> nil then
      begin
      // NOT trimmed here.  A setting that wants trimming does it in its own
      // TrySetText, where it knows whether leading spaces are meaningful -- a
      // password's are.  Trimming centrally would silently eat them.
      Result := s.TrySetText(FEdit.Text, aError);
      Exit;
      end;

   if FCombo <> nil then
      begin
      // Nothing selected is not a value.  Writing '' would refuse or, worse,
      // clear a setting the operator never touched.
      if FCombo.ItemIndex >= 0 then
         begin
         Result := s.TrySetText(FCombo.Items[FCombo.ItemIndex], aError);
         end;
      end;
end;

{ -------------------------------------------------------- TSettingBindings - }

constructor TSettingBindings.Create;
begin
   inherited Create;
   FItems := TObjectList<TSettingBinding>.Create(True);
end;

destructor TSettingBindings.Destroy;
begin
   FreeAndNil(FItems);
   inherited Destroy;
end;

procedure TSettingBindings.Bind(const aControl: TCheckBox; const aKey: string);
var
   b: TSettingBinding;
begin
   b := TSettingBinding.Create(aKey);
   b.FCheck := aControl;
   FItems.Add(b);
end;

procedure TSettingBindings.Bind(const aControl: TEdit; const aKey: string);
var
   b: TSettingBinding;
begin
   b := TSettingBinding.Create(aKey);
   b.FEdit := aControl;
   FItems.Add(b);
end;

procedure TSettingBindings.Bind(const aControl: TComboBox; const aKey: string);
var
   b: TSettingBinding;
begin
   b := TSettingBinding.Create(aKey);
   b.FCombo := aControl;
   FItems.Add(b);
end;

procedure TSettingBindings.LoadAll;
var
   b: TSettingBinding;
begin
   for b in FItems do
      begin
      b.Load;
      end;
end;

function TSettingBindings.SaveAll(out aErrors: string): boolean;
var
   b: TSettingBinding;
   err: string;
begin
   Result := True;
   aErrors := '';

   // EVERY binding is attempted, not stopped at the first refusal.  A panel of
   // thirty settings that reported one problem per visit would take thirty
   // visits to fix; the operator gets the whole list at once.  The accepted
   // ones are applied -- a refusal is about that field, not the panel.
   for b in FItems do
      begin
      if not b.Save(err) then
         begin
         Result := False;
         aErrors := aErrors + err + sLineBreak;
         end;
      end;
end;

function TSettingBindings.Count: integer;
begin
   Result := FItems.Count;
end;

end.
