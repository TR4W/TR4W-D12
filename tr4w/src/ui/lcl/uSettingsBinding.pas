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
{$I ..\..\tr4w.inc}

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
   Controls,
   StdCtrls,
   uSettingsRegistry;

type
   { One control tied to one setting key. }
   TSettingBinding = class(TObject)
   private
      FKey: string;
      FCheck: TCheckBox;
      FEdit: TEdit;
      FCombo: TComboBox;

      { WHAT THE CONTROL SHOWED WHEN THE PAGE LOADED, in the same spelling Save
        would send.  Empty FLoadedValid means "never loaded", and then Save
        writes unconditionally -- the old behaviour, which is the safe default
        for a control filled by something other than Load. }
      FLoadedText: string;
      FLoadedValid: boolean;

      { The control's value as text, whichever of the three it holds. }
      function ControlText: string;
   public
      constructor Create(const aKey: string);

      { Control -> setting.  False means the setting REFUSED the value, with
        aError saying why; the setting keeps what it had. }
      function Save(out aError: string): boolean;

      { Setting -> control.  Also fills a combo's items from the setting's
        allowed values, so the offered list cannot drift from the accepted one. }
      procedure Load;

      { WHICHEVER control this binding holds, as the common ancestor.

        For the search box: a hit must be able to focus the actual control, not
        merely open the page it sits on -- the difference between "here is the
        section, go hunting" and "here it is". }
      function Control: TWinControl;

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

      { Read-only access, for building the search index: the binding knows the
        key, the registry knows the caption and the legacy name, and the
        control's parent panel knows which section it is in. }
      function Item(const aIndex: integer): TSettingBinding;
   end;

implementation

uses
   MainUnit;   // logger

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
      FCheck.Checked := SameText(s.AsText, 'TRUE');
      FLoadedText  := ControlText;
      FLoadedValid := True;
      Exit;
      end;

   if FEdit <> nil then
      begin
      FEdit.Text := s.AsText;
      FLoadedText  := ControlText;
      FLoadedValid := True;
      Exit;
      end;

   if FCombo <> nil then
      begin
      // FILLED FROM THE SETTING, never from the designer.  A populated combo
      // bakes itself into the .fmx resource, so a hand-entered list becomes a
      // permanent second copy that keeps working while it drifts from what the
      // setting will actually accept.
      allowed := s.AllowedValues;
      // BeginUpdate/EndUpdate live on the ITEMS in the LCL, not on the combo:
      // FMX's TComboBox is a list control that owns its items, the LCL's wraps
      // a TStrings.  Same guarantee -- one repaint, not one per item.
      FCombo.Items.BeginUpdate;
      try
         FCombo.Items.Clear;
         for v in allowed do
            begin
            FCombo.Items.Add(v);
            end;
      finally
         FCombo.Items.EndUpdate;
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

   FLoadedText  := ControlText;
   FLoadedValid := True;
end;

function TSettingBinding.ControlText: string;
begin
   Result := '';
   if FCheck <> nil then
      begin
      if FCheck.Checked then
         begin
         Result := 'TRUE';
         end
      else
         begin
         Result := 'FALSE';
         end;
      Exit;
      end;
   if FEdit <> nil then
      begin
      Result := FEdit.Text;
      Exit;
      end;
   if (FCombo <> nil) and (FCombo.ItemIndex >= 0) then
      begin
      Result := FCombo.Items[FCombo.ItemIndex];
      end;
end;

{ SAVE WHAT THE OPERATOR CHANGED, NOT EVERY CONTROL ON THE PAGE.

  Saving unconditionally means opening Preferences and pressing Save writes all
  ~230 settings back, and for a setting whose LIVE value has legitimately moved
  away from its stored one since startup that is destructive: the write re-
  applies the stored value over the running one.

  NY4I hit it twice on the bench, 2026-08-24.  He turned the band map's All
  bands and All modes filters off from its own right-click menu, then opened
  Preferences to raise the display limit -- and saving switched both filters
  back on.  CODE SPEED is the same class and worse: the operator changes it by
  keystroke all contest long, so a Preferences save for an unrelated setting
  would snap the keyer back to the configured default mid-run.

  So the stored value is a STARTUP DEFAULT, the global is the live value, and
  the two are allowed to differ.  Editing a field is an explicit instruction and
  still takes effect at once; leaving it alone now means exactly that.

  NY4I's model, 2026-08-24: "If run-time setting IsDirty then update run-time
  setting else leave the run time setting alone."

  Compared against what LOAD put in the control, not against the setting's
  current value -- the setting may have moved underneath us, and that is
  precisely the case this must not treat as an edit. }
function TSettingBinding.Save(out aError: string): boolean;
var
   s: TSettingBase;
begin
   aError := '';
   Result := True;

   if FLoadedValid and (ControlText = FLoadedText) then
      begin
      Exit;
      end;

   s := FindSetting(FKey);
   if s = nil then
      begin
      logger.Error('[SettingBinding] no setting called "%s"', [FKey]);
      Exit;
      end;

   if FCheck <> nil then
      begin
      if FCheck.Checked then
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

{ ------------------------------------------------- enumeration and access - }

function TSettingBinding.Control: TWinControl;
begin
   // Exactly one of the three is ever set -- Bind is the only writer.
   if FCheck <> nil then
      begin
      Result := FCheck;
      end
   else if FEdit <> nil then
      begin
      Result := FEdit;
      end
   else
      begin
      Result := FCombo;
      end;
end;

function TSettingBindings.Item(const aIndex: integer): TSettingBinding;
begin
   Result := FItems[aIndex];
end;

end.