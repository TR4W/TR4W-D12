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
unit uRadioEditForm;
{$I ..\..\tr4w.inc}

{
  The Radio editor: one radio DEFINITION, edited in isolation.

  A DESIGNED FORM.  The layout lives in uRadioEditForm.fmx and is edited in the
  IDE; this unit holds behaviour.  Split out of uPrefsForm 2026-08-06 to make
  that possible -- a designed form owns a resource named for its unit, so one
  form per unit is not a style preference here, it is what the IDE and the
  form-resource directive require.  The unit it came from held two forms and
  2,336 lines.

  The .fmx was GENERATED from the running code-built form rather than
  hand-authored, so the designed layout started out identical to the one that
  had been tested, to the pixel.  Positions are still absolute; converting them
  to Align/Anchors is a designer job and does not need this file.

  WHAT DELIBERATELY STAYS IN CODE.

  POPULATION.  The port and radio-type combos depend on what is plugged into
  the machine and what the registry holds, neither of which can be expressed in
  a .fmx.  AddComboItem marks the items it creates as not Stored, so a save in
  the designer can never freeze one machine's hardware into the resource.

  CAPTIONS ARE THE DESIGNER'S, in English (NY4I 2026-08-06).  What you type in
  the Object Inspector is what ships in the English build -- there is no code to
  keep in step, and no caption that looks right in the designer and is silently
  replaced at run time.  TranslateForm (uLCLTranslate) then overrides only the
  keys a language table supplies and FALLS THROUGH to the designed text
  otherwise.  Text that changes at run time is a different matter and stays in
  code: 'Searching...' on the Discover button, the CI-V default hint, every
  message box.
}

interface

uses
   SysUtils,
   Classes,
   System.UITypes,
   Controls,
   Forms,
   StdCtrls,
   ExtCtrls,
   ComCtrls,
   uRadioConfigStore,
  uTR4WStrings;

type
   // Reports the editor's outcome.  A callback rather than a modal result,
   // because the editor is modeless -- see the unit header.
   TRadioEditDone = procedure(const aAccepted: boolean) of object;

   // PUBLISHED, and that is a requirement rather than a style choice.  This form
   // is being converted to a designed .fmx, and streaming binds a control to a
   // field only when the field is published and its name matches the component's
   // Name exactly -- hence the designer-idiomatic names with no F prefix, which
   // is also what the IDE will generate for anything dropped on the form later.
   //
   // The event handlers are published for the same reason and a less obvious
   // one: TWriter stores an event as the NAME of a published method, so a
   // private handler is not written to the resource at all.  That failure is
   // silent -- the form opens looking perfect and does nothing when clicked.
   TRadioEditForm = class(TForm)
      lblName: TLabel;
      edtName: TEdit;
      lblType: TLabel;
      cbxType: TComboBox;
      // The TABS are the transport selector -- there is no separate combo.
      // Transport is exclusive, so a combo plus a visible group would be two
      // controls expressing one fact and free to disagree.  Choosing the tab IS
      // choosing the connection, and its parameters are what the tab reveals.
      tbcTransport: TPageControl;
      tabSerial: TTabSheet;
      tabNetwork: TTabSheet;
      tabAdvanced: TTabSheet;
      lblPort: TLabel;
      cbxPort: TComboBox;
      lblBaud: TLabel;
      edtBaud: TEdit;
      // The serial frame as three pickers rather than a typed '8N1'.  It is
      // not only tidier: a free-text frame can be wrong in ways that are
      // invisible until the radio does not answer, and '8N1' vs '8-N-1' vs
      // 'N81' all look reasonable to someone typing quickly.  Three groups can
      // only ever produce a combination the parser accepts.
      //
      // EACH GROUP LIVES IN ITS OWN PANEL, and that is load-bearing rather than
      // decorative.  FMX separated radio buttons by GroupName; the LCL has no
      // GroupName at all and groups by PARENT -- TRadioButton.Checked := True
      // unchecks every SIBLING TRadioButton (lcl/include/radiobutton.inc:107).
      // Parented flat onto tabSerial, all seven would form one group, and
      // RefreshFrom would leave exactly one button lit across all three rows:
      // it sets data bits, then parity (unchecking data bits), then stop bits
      // (unchecking parity).  The panels are BevelOuter=bvNone with an empty
      // caption, so they are invisible -- they exist only to draw the grouping
      // boundary the LCL reads.
      pnlDataBits: TPanel;
      lblDataBits: TLabel;
      optData7, optData8: TRadioButton;
      pnlParity: TPanel;
      lblParity: TLabel;
      optParityNone, optParityOdd, optParityEven: TRadioButton;
      pnlStopBits: TPanel;
      lblStopBits: TLabel;
      optStop1, optStop2: TRadioButton;
      // The CAT port has its own two control lines, same NONE/OFF/ON/CW/PTT
      // vocabulary as the keyer port's.  A rig keyed through its CAT cable uses
      // these; one wired to a separate keying interface uses the keyer port's.
      lblCatRTS: TLabel;
      cbxCatRTS: TComboBox;
      lblCatDTR: TLabel;
      cbxCatDTR: TComboBox;
      lblIP: TLabel;
      edtIP: TEdit;
      lblTCPPort: TLabel;
      edtTCPPort: TEdit;
      lblUser: TLabel;
      edtUser: TEdit;
      lblPassword: TLabel;
      edtPassword: TEdit;
      btnDiscover: TButton;
      lblFound: TLabel;
      cbxFound: TComboBox;
      lblKeyerPort: TLabel;
      cbxKeyerPort: TComboBox;
      // The keyer port has TWO control lines and each is assigned a JOB
      // (NONE/OFF/ON/CW/PTT), which is how one keys CW while the other drives
      // PTT -- as the original TR4W radio dialog offered (NY4I 2026-08-07).
      // Not a DTR-or-RTS choice.
      lblKeyerRTS: TLabel;
      cbxKeyerRTS: TComboBox;
      lblKeyerDTR: TLabel;
      cbxKeyerDTR: TComboBox;
      lblKeyerStopBits: TLabel;
      cbxKeyerStopBits: TComboBox;
      edtCIV: TEdit;
      edtHamLibID: TEdit;
      lblStartup: TLabel;
      edtStartup: TEdit;
      chkPolling: TCheckBox;
      chkUseHamLib: TCheckBox;
      // Radio-scoped settings that used to sit in the flat config-command list,
      // where they read as applying to the station rather than to one rig
      // (NY4I 2026-08-05).  Their CFGCA rows are now csOwned.
      edtFilterByte: TEdit;
      edtDataMode: TEdit;
      lblAutoInfo: TLabel;
      edtAutoInfo: TEdit;
      lblFreqOffset: TLabel;
      edtFreqOffset: TEdit;
      chkWideCW: TCheckBox;
      chkFT1000MPReverse: TCheckBox;
      btnOK: TButton;
      btnCancel: TButton;

      // The labels of the model-only fields, kept so they can be greyed WITH
      // their field (NY4I 2026-08-05).  Disabling the edit alone is invisible:
      // the gating code blanks a disabled field's Text and TextPrompt, so what
      // is left is an empty box that looks exactly like an enabled one, under a
      // caption still drawn in full black.  Greying the caption is what makes
      // "this radio does not have that setting" legible -- and it is the
      // convention every other Windows dialog uses.
      lblCIV: TLabel;
      lblFilterByte: TLabel;
      lblDataMode: TLabel;
      lblHamLibID: TLabel;

      procedure HandleTypeChange(Sender: TObject);
      procedure HandleTransportChange(Sender: TObject);
      procedure HandleDiscover(Sender: TObject);
      procedure HandleFoundSelect(Sender: TObject);
      procedure HandleOK(Sender: TObject);
      procedure HandleCancel(Sender: TObject);
      procedure HandleShow(Sender: TObject);
      procedure HandleClose(Sender: TObject; var Action: TCloseAction);
   private
      // STATE, not controls: nothing here is streamed, so it keeps the F prefix
      // and stays private.
      FRadio: TRadioDefinition;
      // What the radio looked like when the editor opened.  Comparing against
      // this answers "did anything change" exactly, with no dirty flag to keep
      // in step with the control count.
      FSnapshot: TRadioDefinition;
      FOnDone: TRadioEditDone;
      // Advanced is a tab but NOT a transport, so the transport is REMEMBERED
      // rather than read from whichever tab happens to be showing.  Without
      // this, looking at Advanced would silently change the radio's connection.
      FTransport: TRadioTransport;
      // False until the form is fully constructed.  Streaming makes the first
      // TTabSheet active, which fires OnChange while the form is still being
      // read -- so the handler runs before the constructor has decided anything.
      // Guarding each field individually would mean remembering to add a test
      // every time a control joins the form; one flag cannot be forgotten.
      FBuilt: boolean;

      // A SETTER because setting FTransport has an OBLIGATION: every control on
      // the form is enabled, greyed or prompted according to the transport, and
      // UpdateEnabledState is what applies that.  All four write sites honour it
      // today -- by CONVENTION, which is exactly how TPrefsForm's dirty flag was
      // held until a thirteenth site was added and silently broke it
      // (2026-08-08).  The obligation belongs on the write, not on the writer.
      //
      // It deliberately does NOT move tbcTransport: the tab is the VIEW, this is
      // the MODEL, and HandleTransportChange already syncs model from view -- a
      // setter that pushed back to the tab would close that loop on itself.
      procedure SetTransport(const aValue: TRadioTransport);
      property Transport: TRadioTransport read FTransport write SetTransport;

      procedure PopulateTypeCombo;
      procedure PopulatePortCombos;
      procedure SetSerialFrame(const aFormat: string);
      function SerialFrame: string;
      procedure LoadFromRadio;
      function SaveToRadio(out aError: string): boolean;
      function SaveTo(const aTarget: TRadioDefinition; out aError: string): boolean;
      function IsModified: boolean;
      function SelectedRegistryId: string;
      procedure UpdateEnabledState;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure EditRadio(const aRadio: TRadioDefinition; const aOnDone: TRadioEditDone);
   end;

implementation

{$R *.lfm}

uses
   Windows,
   StrUtils,
   Generics.Collections,
   Generics.Defaults,
   uHostedFormWindows,
   Dialogs,
   uLCLFormHelpers,
   uLCLTranslate,
   uRadioConfigApply,
   uRadioRegistry,
   uCAT,
   ComPortEnumerator,
   VC,
   MainUnit;

{ ---------------------------------------------------------------------------
  TDiscoverThread -- network radio discovery, off the UI thread.

  Was an anonymous thread with an anonymous TThread.Queue callback nested inside
  it.  FPC has neither, so both became real types: the worker below, and
  TDiscoverDone, which carries the result back to the main thread.

  The division of labour is the point and is unchanged: NOTHING here touches a
  control.  Discovery happens on the worker; every control assignment happens in
  TDiscoverDone.Apply, which only ever runs via TThread.Queue.  That is the same
  contract the radio and cluster threads keep, and the reason TR4W's own message
  loop can host a toolkit at all -- Queue drains through the loop's
  fall-through DispatchMessage.
--------------------------------------------------------------------------- }

type
   // Hands the finished list back to the form on the MAIN thread.
   TDiscoverDone = class
   private
      FForm:  TRadioEditForm;
      FFound: TStringList;
   public
      constructor Create(aForm: TRadioEditForm; aFound: TStringList);
      destructor Destroy; override;
      procedure Apply;
   end;

   TDiscoverThread = class(TThread)
   private
      FForm:  TRadioEditForm;
      FModel: InterfacedRadioType;
   protected
      procedure Execute; override;
   public
      constructor Create(aForm: TRadioEditForm; const aModel: InterfacedRadioType);
   end;

constructor TDiscoverDone.Create(aForm: TRadioEditForm; aFound: TStringList);
begin
   inherited Create;
   FForm  := aForm;
   FFound := aFound;
end;

destructor TDiscoverDone.Destroy;
begin
   FreeAndNil(FFound);
   inherited Destroy;
end;

procedure TDiscoverDone.Apply;
var
   i: integer;
begin
   try
      // THE ARRIVAL IS LOGGED, not just the departure. Without this there is no
      // way to distinguish "the worker never came back" from "it came back and
      // the controls did not update" -- which is precisely the ambiguity the
      // second-discovery report left open.
      logger.Debug('[RadioEdit] Discovery DONE -- %d address(es) back on the main thread',
                   [FFound.Count]);

      // Restore the cursor FIRST. Everything below can raise or block on a modal
      // ShowMessage, and an hourglass left spinning over a dialog that is waiting
      // for the operator is worse than no hourglass at all.
      Screen.Cursor := crDefault;

      FForm.btnDiscover.Caption := TC_RADIOEDIT_DISCOVER;
      FForm.btnDiscover.Enabled := True;

      for i := 0 to FFound.Count - 1 do
         begin
         AddComboItem(FForm.cbxFound, FFound[i], FFound[i]);
         end;

      logger.Debug('[RadioEdit] Discovery populated cbxFound: %d item(s)',
                   [FForm.cbxFound.Items.Count]);

      if FFound.Count = 0 then
         begin
         ShowMessage(TC_RADIOEDIT_NONEFOUND);
         end
      else
         begin
         { ALWAYS SELECT SOMETHING, and that is the fix for a real complaint:
           "the drop-down of discovered radios does not populate -- if I click
           the arrow the IPs appear, but only if I click."

           They were always there. A TComboBox with ItemIndex = -1 renders its
           closed edit area BLANK no matter how many items it holds, so a
           successful two-radio discovery was indistinguishable from a failed
           one until the operator opened the list on spec.

           The old code only selected when EXACTLY ONE radio answered -- the
           reasoning being that two is a choice the operator should make. That
           reasoning is sound and the presentation was wrong: showing the first
           result does not prevent choosing the second, it just stops the window
           claiming nothing was found. What is displayed and what edtIP holds
           now always agree, which is the property that matters when the next
           thing the operator does is press Save. }
         FForm.cbxFound.ItemIndex := 0;
         FForm.edtIP.Text := FFound[0];

         if FFound.Count > 1 then
            begin
            logger.Debug('[RadioEdit] %d radios answered; selected the first (%s) -- ' +
                         'the others are in the drop-down',
                         [FFound.Count, FFound[0]]);
            end;
         end;
   except
      // A FAILURE HERE USED TO BE INVISIBLE. This runs from TThread.Queue, so an
      // exception unwinds into the message loop with nothing to attribute it to,
      // and the symptom is exactly what was reported: the button never comes
      // back and the drop-down stays empty. Now it says which stage failed, and
      // the cursor and the button are restored rather than left mid-flight.
      on E: Exception do
         begin
         Screen.Cursor := crDefault;
         FForm.btnDiscover.Caption := TC_RADIOEDIT_DISCOVER;
         FForm.btnDiscover.Enabled := True;
         logger.Error('[RadioEdit] Discovery FAILED while updating the form: %s: %s',
                      [E.ClassName, E.Message]);
         end;
   end;

   // Frees the list too, and runs whether or not the UI work raised -- the
   // except above swallows anything from the form update, so control always
   // reaches here. The anonymous version freed the list inside the queued block
   // and again in an except handler; one owner with one destructor is easier to
   // be sure of.
   Free;
end;

constructor TDiscoverThread.Create(aForm: TRadioEditForm; const aModel: InterfacedRadioType);
begin
   inherited Create(True);
   FreeOnTerminate := True;
   FForm  := aForm;
   FModel := aModel;
   Start;
end;

procedure TDiscoverThread.Execute;
var
   found: TStringList;
   done:  TDiscoverDone;
begin
   found := TStringList.Create;
   try
      try
         logger.Debug('[RadioEdit] Discovery worker running');
         DiscoverNetworkRadios(FModel, found);
         logger.Debug('[RadioEdit] Discovery worker finished -- %d address(es)',
                      [found.Count]);
      except
         // A discovery failure is not worth taking the program down for; it
         // comes back as "nothing answered", which is what the operator sees
         // anyway when the radio is off.
         on E: Exception do
            begin
            logger.Warn('[Preferences] Discovery failed: %s', [E.Message]);
            end;
      end;
   except
      FreeAndNil(found);
      raise;
   end;

   // Ownership of `found` passes to TDiscoverDone, which frees it after the UI
   // has read it -- on the main thread.
   done := TDiscoverDone.Create(FForm, found);

   { SYNCHRONIZE, NOT QUEUE -- and this is a fix, not a preference.
     Diagnosed 2026-08-14 from a discovery that found two radios and then never
     updated the form: the log showed "worker finished -- 2 address(es)" and no
     "DONE ... back on the main thread" at all.

     TThread.Queue stamps every entry with the CALLING thread's id --
     `queueentry^.ThreadID := GetCurrentThreadID` in InternalQueue -- even when
     the thread argument is nil, as it is here. TThread.Destroy then calls
     RemoveQueuedEvents(Self), and that matches on
     `entry^.ThreadID = aThread.ThreadID` (FPC 3.2.2 classes.inc:603).

     So: Queue is the last statement in Execute, the thread terminates
     immediately after, FreeOnTerminate frees it, and IT DELETES ITS OWN QUEUED
     CALLBACK. Whether the callback survives is a race against the main thread
     draining the queue in the intervening microseconds -- which is exactly the
     "worked once, then stopped working" shape that was reported.

     Synchronize is immune by construction: those entries carry a SyncEvent, and
     the same RemoveQueuedEvents skips anything with one (classes.inc:601). It
     also blocks this worker until the main thread has run Apply, so the thread
     cannot reach Destroy before delivery. The worker is about to exit anyway, so
     the block costs nothing.

     NOT solved by clearing FreeOnTerminate: that only moves the destruction, and
     something still has to free the thread eventually. The lifetime coupling is
     the bug; Synchronize removes it. }
   TThread.Synchronize(nil, done.Apply);
end;



constructor TRadioEditForm.Create(AOwner: TComponent);
begin
   // Create, NOT CreateNew.  The inherited constructor finds the resource named
   // for this class and streams uRadioEditForm.fmx into it -- every control,
   // its position and size, and the event bindings.  A missing or misnamed
   // resource raises here, which is a loud answer rather than a subtle one.
   //
   // SIZE AND BORDER ARE NOW PROPERTIES IN THE DESIGNER, and the reasoning that
   // put them where they are does not survive in the .fmx, so it is recorded
   // here.  The form is a FIXED SIZE (BorderStyle Single, no maximize): every
   // control sits at a fixed position and width, so a resize only adds
   // whitespace, and offering a maximize button on a form that cannot use the
   // space is a promise the dialog does not keep.  The footer buttons are
   // anchored [akRight, akBottom] anyway -- they were once placed from
   // ClientWidth/ClientHeight without anchors and stranded in mid-air on
   // resize (NY4I, 2026-08-05) -- so this can be flipped to Sizeable if the
   // content ever earns it.  Size was set through ClientWidth/ClientHeight, not
   // Width/Height: in FMX, Height includes the caption bar and borders, which
   // is how the OK and Cancel buttons went missing on NY4I's first look.
   inherited Create(AOwner);

   // English lives in the .fmx; TranslateForm overrides only what a language
   // table supplies and leaves the designed text alone otherwise.  Today no
   // lookup is assigned, so this is a no-op and the designer is the UI.
   TranslateForm(Self);

   // ASSIGNED HERE AS WELL AS IN THE RESOURCE, deliberately.  Both are bound by
   // name in the .fmx, but losing them is not a visible fault: the form would
   // still open and still look right, having silently stopped registering its
   // window handle with the coexistence layer -- and keyboard handling is what
   // that registration exists for.  Re-assigning the same handlers costs
   // nothing and makes a designer accident survivable.
   OnShow  := HandleShow;
   OnClose := HandleClose;

   // Every control exists the moment streaming finishes, so the guard that
   // BuildControls needed is satisfied earlier now -- but it is still needed.
   // Streaming activates the first tab, which fires HandleTransportChange while
   // the form is only part-way through being read.
   FBuilt := True;

   PopulateTypeCombo;
   PopulatePortCombos;
end;

procedure TRadioEditForm.PopulateTypeCombo;
var
   ids: TArray<string>;
   // A TStringList rather than TList<string>, and NOT for tidiness: the sort
   // below used TComparer<string>.Construct with an ANONYMOUS METHOD, and FPC
   // 3.2.2 has no anonymous methods at all.  TStringList with CaseSensitive
   // False sorts by AnsiCompareText, which is exactly what that comparator did,
   // so the ordering is unchanged and the closure simply disappears.
   labels: TStringList;
   i: integer;
begin
   // Built from the REGISTRY, not from a hand-kept list: adding a radio unit
   // must make it selectable here with no change to this file.  RegisteredIds
   // covers enum-backed and string-id radios alike, which is what makes TCI
   // appear without a special case.
   ClearComboItems(cbxType);
   ids := RegisteredIds;

   labels := TStringList.Create;
   try
      for i := 0 to High(ids) do
         begin
         labels.Add(DisplayNameId(ids[i]) + #9 + ids[i]);
         end;
      labels.CaseSensitive := False;
      labels.Sort;

      for i := 0 to labels.Count - 1 do
         begin
         AddComboItem(cbxType,
                      Copy(labels[i], 1, Pos(#9, labels[i]) - 1),
                      Copy(labels[i], Pos(#9, labels[i]) + 1, MaxInt));
         end;
   finally
      labels.Free;
   end;
end;

procedure TRadioEditForm.PopulatePortCombos;
var
   enumerator: TComPortEnumerator;
   names: TArray<string>;
   info: TComPortInfo;
   i: integer;
   caption: string;
begin
   ClearComboItems(cbxPort);
   ClearComboItems(cbxKeyerPort);

   AddComboItem(cbxPort,      TC_PREFS_NONE, PORT_NONE);
   AddComboItem(cbxKeyerPort, TC_PREFS_NONE, PORT_NONE);

   enumerator := TComPortEnumerator.Create;
   try
      enumerator.Refresh;
      names := enumerator.PortNames;
      for i := 0 to High(names) do
         begin
         caption := names[i];
         if enumerator.PortByName(names[i], info) and (info.FriendlyName <> '') then
            begin
            caption := names[i] + ' - ' + info.FriendlyName;
            end;
         // The friendly name is shown; the CONFIG VALUE is what travels in the
         // tag.  Storing the displayed text would put 'COM17 - Silicon Labs
         // CP210x' into the ini, which is exactly the corruption the legacy
         // dialog had to be fixed for.
         AddComboItem(cbxPort,      caption, ComNameToPortValue(names[i]));
         AddComboItem(cbxKeyerPort, caption, ComNameToPortValue(names[i]));
         end;
   finally
      enumerator.Free;
   end;
end;

// Drives the three pickers from an '8N1'-style string.  An unparseable or
// empty value falls back to 8N1 -- the near-universal default -- rather than
// leaving nothing selected, because "no data bits chosen" is not a state the
// radio can be in.
procedure TRadioEditForm.SetSerialFrame(const aFormat: string);
var
   dataBits, parity, stopBits: Byte;
begin
   if not TryParseSerialFormat(Trim(aFormat), dataBits, parity, stopBits) then
      begin
      dataBits := 8;
      parity   := PARITY_NONE;
      stopBits := 1;
      end;

   optData7.Checked := (dataBits = 7);
   optData8.Checked := (dataBits = 8);

   optParityNone.Checked := (parity = PARITY_NONE);
   optParityOdd.Checked := (parity = PARITY_ODD);
   optParityEven.Checked := (parity = PARITY_EVEN);

   optStop1.Checked := (stopBits = 1);
   optStop2.Checked := (stopBits = 2);
end;

// The three pickers back into the '8N1' the config command expects.  Composed
// through SerialFormatToString rather than by string concatenation here, so the
// spelling can only ever be the one the parser accepts.
function TRadioEditForm.SerialFrame: string;
var
   dataBits, parity, stopBits: Byte;
begin
   if optData7.Checked then
      begin
      dataBits := 7;
      end
   else
      begin
      dataBits := 8;
      end;

   if optParityOdd.Checked then
      begin
      parity := PARITY_ODD;
      end
   else if optParityEven.Checked then
      begin
      parity := PARITY_EVEN;
      end
   else
      begin
      parity := PARITY_NONE;
      end;

   if optStop2.Checked then
      begin
      stopBits := 2;
      end
   else
      begin
      stopBits := 1;
      end;

   Result := SerialFormatToString(dataBits, parity, stopBits);
end;

procedure TRadioEditForm.EditRadio(const aRadio: TRadioDefinition;
                                   const aOnDone: TRadioEditDone);
begin
   FRadio  := aRadio;
   FOnDone := aOnDone;

   FreeAndNil(FSnapshot);
   if aRadio <> nil then
      begin
      FSnapshot := aRadio.Clone;
      end;
   PopulatePortCombos;   // ports may have changed since the form was built
   LoadFromRadio;
   Show;
   BringToFront;
end;

procedure TRadioEditForm.LoadFromRadio;
begin
   if FRadio = nil then
      begin
      Exit;
      end;

   edtName.Text := FRadio.Name;

   // A NEW radio starts with NOTHING selected, rather than falling back to the
   // first row of an alphabetical list.  A defaulted type is a silent wrong
   // answer: the operator fills in the port, saves, and has an Elecraft K2 they
   // never chose.  It also means the "Choose a radio type" check below can
   // actually fire -- with a fallback selection it never could.
   //
   // There is deliberately no '(none)' row in this list.  In TR4W's vocabulary
   // NONE means "no radio in this slot", which is a different idea and already
   // offered at profile level; a radio DEFINITION with no type is not something
   // worth being able to save, so it is un-selectable rather than
   // selectable-and-invalid.
   if Trim(FRadio.RegistryId) = '' then
      begin
      cbxType.ItemIndex := -1;
      end
   else
      begin
      SelectByTag(cbxType, FRadio.RegistryId);
      end;
   Transport := FRadio.Transport;
   if FTransport = rtNetwork then
      begin
      tbcTransport.ActivePage := tabNetwork;
      end
   else
      begin
      tbcTransport.ActivePage := tabSerial;
      end;

   SelectByTag(cbxPort, FRadio.ControlPort);
   if FRadio.BaudRate > 0 then
      begin
      edtBaud.Text := IntToStr(FRadio.BaudRate);
      end
   else
      begin
      edtBaud.Text := '';
      end;
   SetSerialFrame(FRadio.SerialFormat);

   edtIP.Text       := FRadio.IPAddress;
   if FRadio.TCPPort > 0 then
      begin
      edtTCPPort.Text := IntToStr(FRadio.TCPPort);
      end
   else
      begin
      edtTCPPort.Text := '';
      end;
   edtUser.Text     := FRadio.NetworkUsername;
   edtPassword.Text := FRadio.NetworkPassword;

   SelectByTag(cbxKeyerPort, FRadio.KeyerOutputPort);
   FillRTSDTRCombo(cbxKeyerRTS, FRadio.KeyerRTS);
   FillRTSDTRCombo(cbxKeyerDTR, FRadio.KeyerDTR);
   FillRTSDTRCombo(cbxCatRTS,   FRadio.CatRTS);
   FillRTSDTRCombo(cbxCatDTR,   FRadio.CatDTR);
   FillStopBitsCombo(cbxKeyerStopBits, FRadio.KeyerStopBits);
   // HEX, because that is what the radio's own menu and every Icom manual show
   // (NY4I).  The value is STORED as the decimal the config command expects --
   // only the presentation changes, so nothing downstream has to know.
   if FRadio.ReceiverAddress > 0 then
      begin
      edtCIV.Text := IntToHex(FRadio.ReceiverAddress, 2);
      end
   else
      begin
      edtCIV.Text := '';
      end;
   if FRadio.HamLibID > 0 then
      begin
      edtHamLibID.Text := IntToStr(FRadio.HamLibID);
      end
   else
      begin
      edtHamLibID.Text := '';
      end;
   edtStartup.Text        := FRadio.StartupCommand;
   if FRadio.IcomFilterByte > 0 then
      begin
      edtFilterByte.Text := IntToStr(FRadio.IcomFilterByte);
      end
   else
      begin
      edtFilterByte.Text := '';
      end;
   // Blank means "let the radio decide".  Showing -1 would be showing the
   // operator an implementation detail and inviting them to type one.
   if FRadio.AutoInfoLevel < 0 then
      begin
      edtAutoInfo.Text := '';
      end
   else
      begin
      edtAutoInfo.Text := IntToStr(FRadio.AutoInfoLevel);
      end;

   // BLANK FOR NONE, not '0'. Almost every radio has no transverter, and a box
   // showing 0 reads as a value someone chose; blank plus the hint reads as
   // "nothing here", which is what it is.
   if FRadio.FrequencyAdder <> 0 then
      begin
      edtFreqOffset.Text := IntToStr(FRadio.FrequencyAdder);
      end
   else
      begin
      edtFreqOffset.Text := '';
      end;

   if FRadio.IcomDataModeID > 0 then
      begin
      edtDataMode.Text := IntToStr(FRadio.IcomDataModeID);
      end
   else
      begin
      edtDataMode.Text := '';
      end;
   chkWideCW.Checked      := FRadio.WideCWFilter;
   chkFT1000MPReverse.Checked := FRadio.FT1000MPCWReverse;
   chkUseHamLib.Checked := FRadio.UseHamLib;
   chkPolling.Checked   := FRadio.PollingEnable;

   UpdateEnabledState;
end;

function TRadioEditForm.SelectedRegistryId: string;
begin
   Result := SelectedTag(cbxType);
end;

destructor TRadioEditForm.Destroy;
begin
   FreeAndNil(FSnapshot);
   inherited Destroy;
end;

// True when the controls hold something different from what was loaded.  It
// works by writing the controls into a scratch copy and comparing -- so it can
// never disagree with what OK would actually save, which a hand-maintained
// dirty flag eventually does.
function TRadioEditForm.IsModified: boolean;
var
   scratch: TRadioDefinition;
   err: string;
begin
   Result := False;
   if (FRadio = nil) or (FSnapshot = nil) then
      begin
      Exit;
      end;

   scratch := FRadio.Clone;
   try
      // A scratch copy that will not even validate is certainly not identical
      // to the snapshot, so treat that as modified and let the prompt appear.
      if not SaveTo(scratch, err) then
         begin
         Result := True;
         Exit;
         end;
      Result := not scratch.SameAs(FSnapshot);
   finally
      scratch.Free;
   end;
end;

function TRadioEditForm.SaveToRadio(out aError: string): boolean;
begin
   Result := SaveTo(FRadio, aError);
end;

function TRadioEditForm.SaveTo(const aTarget: TRadioDefinition; out aError: string): boolean;
var
   civ: integer;
begin
   aError := '';
   Result := False;

   if Trim(edtName.Text) = '' then
      begin
      aError := TC_RADIOEDIT_NAMEREQUIRED;
      Exit;
      end;
   if SelectedRegistryId = '' then
      begin
      aError := TC_RADIOEDIT_TYPEREQUIRED;
      Exit;
      end;

   FRadio.Name       := Trim(edtName.Text);
   FRadio.RegistryId := SelectedRegistryId;
   FRadio.Transport  := FTransport;

   FRadio.ControlPort  := SelectedTag(cbxPort);
   FRadio.BaudRate     := StrToIntDef(Trim(edtBaud.Text), 0);
   FRadio.SerialFormat := SerialFrame;

   FRadio.IPAddress       := Trim(edtIP.Text);
   FRadio.TCPPort         := StrToIntDef(Trim(edtTCPPort.Text), 0);
   FRadio.NetworkUsername := Trim(edtUser.Text);
   FRadio.NetworkPassword := edtPassword.Text;   // not trimmed: it is a password

   FRadio.KeyerOutputPort := SelectedTag(cbxKeyerPort);
   FRadio.KeyerRTS        := SelectedTag(cbxKeyerRTS);
   FRadio.KeyerDTR        := SelectedTag(cbxKeyerDTR);
   FRadio.CatRTS          := SelectedTag(cbxCatRTS);
   FRadio.CatDTR          := SelectedTag(cbxCatDTR);
   // 0 = "not stated", so the apply layer can leave the registry/model default
   // alone rather than forcing a value the operator never chose.
   FRadio.KeyerStopBits   := StrToIntDef(SelectedTag(cbxKeyerStopBits), 0);
   if not TryParseHexByte(edtCIV.Text, civ) then
      begin
      aError := TC_RADIOEDIT_BADCIV;
      Exit;
      end;
   FRadio.ReceiverAddress := civ;
   FRadio.HamLibID        := StrToIntDef(Trim(edtHamLibID.Text), 0);
   FRadio.StartupCommand  := Trim(edtStartup.Text);
   FRadio.IcomFilterByte    := StrToIntDef(Trim(edtFilterByte.Text), 0);
   FRadio.IcomDataModeID    := StrToIntDef(Trim(edtDataMode.Text), 0);
   if Trim(edtAutoInfo.Text) = '' then
      begin
      FRadio.AutoInfoLevel := AUTOINFO_RADIO_DEFAULT;
      end
   else
      begin
      FRadio.AutoInfoLevel := StrToIntDef(Trim(edtAutoInfo.Text), AUTOINFO_RADIO_DEFAULT);
      end;
   // Blank or unparseable means no transverter. StrToIntDef with 0 is right
   // here -- 0 IS the "no offset" value, so a typo cannot invent one.
   FRadio.FrequencyAdder    := StrToIntDef(Trim(edtFreqOffset.Text), 0);
   FRadio.WideCWFilter      := chkWideCW.Checked;
   FRadio.FT1000MPCWReverse := chkFT1000MPReverse.Checked;
   FRadio.UseHamLib       := chkUseHamLib.Checked;
   FRadio.PollingEnable   := chkPolling.Checked;

   Result := True;
end;

procedure TRadioEditForm.UpdateEnabledState;
var
   id: string;
   transport: TRadioTransport;
   isIcom: boolean;
   usesCredentials: boolean;
   civDefault: integer;
begin
   // Reached during construction, from the first tab becoming active -- see
   // FBuilt.  Every control this method touches is created AFTER the tab
   // control, so without this it dereferences nil.
   if not FBuilt then
      begin
      Exit;
      end;

   id := SelectedRegistryId;
   transport := FTransport;

   // Grey rather than hide: a field that vanishes makes the operator wonder
   // whether the setting still exists.  The registry knows which links a model
   // actually supports, so a serial-only radio cannot be set to network here.
   // A radio that cannot speak a transport does not get that tab.  The registry
   // is the authority on which links a model supports.
   tabSerial.Enabled  := (id = '') or SupportsSerialId(id);
   tabNetwork.Enabled := (id = '') or SupportsNetworkId(id);

   // Discovery is offered only where the registry says the model announces
   // itself.  Broadcasting for a radio that cannot answer would produce a
   // three-second wait and an empty list, which reads as a fault.
   btnDiscover.Enabled := (id <> '') and RegisteredDiscoverableId(id);

   // CREDENTIALS ARE NOT A PROPERTY OF "BEING A NETWORK RADIO" (NY4I).
   //
   // The Elecraft K4 is reached over TCP 9200 with no login at all, while every
   // network Icom and the two Kenwood LAN radios want a username and a password.
   // The editor offered the fields to all of them, so adding a K4 asked for
   // credentials it can never use -- and an operator who filled them in had no
   // way to learn they were ignored.
   //
   // The registry is the authority, exactly as it is for discovery and CI-V
   // above: RegisteredNetworkCredentialsId, declared by the radio's own unit.
   usesCredentials := (id <> '') and RegisteredNetworkCredentialsId(id);
   edtUser.Enabled     := usesCredentials;
   edtPassword.Enabled := usesCredentials;
   lblUser.Enabled     := usesCredentials;
   lblPassword.Enabled := usesCredentials;
   if not usesCredentials then
      begin
      // Cleared, not just greyed: a value left behind in a disabled box is saved
      // with the radio and reappears if the operator later picks a model that
      // DOES authenticate, silently supplying a credential they never typed for
      // that rig.
      edtUser.Text     := '';
      edtPassword.Text := '';
      end;

   // HamLib ID is the operator's value ONLY for HamLib-any; for every other
   // radio the registry supplies it and typing one here would pin a model the
   // operator never chose.  Same rule the legacy dialog applies.
   edtHamLibID.Enabled := SameText(id, 'HAMLIBANY');
   lblHamLibID.Enabled := edtHamLibID.Enabled;

   // Model-specific settings are enabled only for the models they mean anything
   // to (NY4I).  An Icom filter byte on a Kenwood is not a harmless spare
   // field: it is an invitation to set something that will never be sent, and
   // then to wonder why it had no effect.
   isIcom := IsIcomRadio(id);
   edtFilterByte.Enabled  := isIcom;
   edtDataMode.Enabled    := isIcom;
   lblFilterByte.Enabled := isIcom;
   lblDataMode.Enabled   := isIcom;

   // CI-V is offered only where the REGISTRY says the model has a CI-V address
   // -- its own declared meaning ('0 = not a CI-V radio'), not a brand guess.
   // That is not pedantry: the Ten-Tec Omni VI has an Icom-compatible CI-V
   // interface and declares address 4, so a brand test would have locked it out
   // of the one field it needs.
   // ASK BY ID. This used to be RegisteredCIVAddress(ModelForId(id)), which
   // round-trips through the enum -- and a radio registered with
   // RegisterRadioById has no enum member, so ModelForId answers
   // NoInterfacedRadio, the default came back 0, and the field disabled itself.
   // The IC-7110 is an Icom whose CI-V address the operator could not edit
   // (NY4I, bench, 2026-08-29). Nothing in the registry needs the enum here;
   // the id is the key.
   civDefault := 0;
   if id <> '' then
      begin
      civDefault := RegisteredCIVAddressId(id);
      end;

   edtCIV.Enabled := (civDefault <> 0);
   // Grey the caption with the box.  The gating below blanks a disabled field's
   // Text and TextPrompt, which leaves nothing to render greyed -- so on a K3
   // (registered civAddress 0, correctly disabled) the operator saw an ordinary
   // empty box under a full-black caption and read it as editable.  NY4I, bench,
   // 2026-08-05.
   lblCIV.Enabled := edtCIV.Enabled;
   if not edtCIV.Enabled then
      begin
      edtCIV.Text       := '';
      edtCIV.TextHint := '';
      end
   else
      begin
      // Greyed, and only visible while the box is empty -- so it disappears the
      // moment the operator types their own address, and comes back if they
      // clear it.  Hex, to match the label, the radio's menu and the manual.
      edtCIV.TextHint := Format(TC_RADIOEDIT_DEFAULTHINT,
                                    [IntToHex(civDefault, 2)]);
      end;

   // The FT-1000MP's reversed CW sidebands are a quirk of that one radio.
   chkFT1000MPReverse.Enabled := (ModelForId(id) = FT1000MP);

   // Auto-info is offered only where a driver acts on it.  Today that is the
   // Elecraft serial family; TFactoryRadioBase.ApplyAutoInfoLevel is a no-op
   // everywhere else, and an editable box that changes nothing is exactly the
   // "invitation to set something that will never be sent" the Icom fields
   // above are gated to avoid.
   //
   // HIDDEN, not greyed, on a radio that ignores it (NY4I).  A greyed
   // control still says "this radio has an auto-info setting and you may not
   // touch it", which is a different and wrong statement -- an Icom or a
   // Yaesu has no such concept at all.  The Icom fields above are greyed
   // rather than hidden because they belong to a family the operator may be
   // about to select; this one belongs to a capability the radio either has
   // or does not.
   //
   // THE K4 IS TRANSPORT-DEPENDENT, AND IT IS THE ONLY RADIO THAT IS.  Its
   // driver acts on this setting over SERIAL (default 2, same as its cousins)
   // and deliberately ignores it over NETWORK, where the level is a property
   // of the connection: a K4 network session always starts at AI0 and is put
   // into AI5, and the network path has no poll to fall back on -- so an
   // operator who set 0 there would get a radio that reported nothing at all.
   // Hiding it on the network tab is therefore not tidiness; it is refusing to
   // offer a control whose only effect would be to break the transport that
   // already works.  TK4Radio.ApplyAutoInfoLevel enforces the same rule at the
   // driver, because the UI must not be the only thing standing between an
   // operator and a mute radio.
   edtAutoInfo.Visible := MatchText(id, ['K2', 'K3', 'KX3'])
                       or (MatchText(id, ['K4']) and (transport = rtSerial));
   lblAutoInfo.Visible := edtAutoInfo.Visible;
   if not edtAutoInfo.Visible then
      begin
      edtAutoInfo.Text := '';
      end
   else
      begin
      // Greyed, and only while the box is empty, so it disappears the moment
      // the operator types and returns if they clear it -- the same idiom as
      // the CI-V default hint.
      edtAutoInfo.TextHint := '2';
      end;

   // Blank a disabled field rather than leave a stale value showing: a greyed
   // box with a number in it reads as "set, but locked", which is the opposite
   // of what it means.
   if not edtFilterByte.Enabled then
      begin
      edtFilterByte.Text := '';
      end;
   if not edtDataMode.Enabled then
      begin
      edtDataMode.Text := '';
      end;
   if not chkFT1000MPReverse.Enabled then
      begin
      chkFT1000MPReverse.Checked := False;
      end;
end;

procedure TRadioEditForm.HandleTypeChange(Sender: TObject);
var
   id: string;
   params: TSerialParams;
   model: InterfacedRadioType;
begin
   // NOTHING here may touch FRadio without this guard.  OnChange is wired in
   // BuildControls, and PopulateTypeCombo -- called at the END of that same
   // constructor -- sets ItemIndex, which fires this handler while FRadio is
   // still nil.  The earlier version of this method only touched controls and
   // so survived; adding one FRadio.SerialFormat read turned first-open of the
   // editor into an access violation.
   //
   // The general shape: an event handler wired before its subject exists will
   // be called before its subject exists.
   if FRadio = nil then
      begin
      Exit;
      end;

   id := SelectedRegistryId;
   if id = '' then
      begin
      Exit;
      end;

   // Prefill from the registry, but only into fields the operator has not
   // already filled in: re-picking the same radio must not silently discard a
   // baud rate they chose deliberately.
   params := SerialParamsForId(id);
   if (Trim(edtBaud.Text) = '') and (params.baud > 0) then
      begin
      edtBaud.Text := IntToStr(params.baud);
      end;
   // The frame always has a value now (the pickers cannot be blank), so this
   // adopts the registry's frame whenever the operator has not yet saved one --
   // which is what picking a radio type should do.
   if Trim(FRadio.SerialFormat) = '' then
      begin
      SetSerialFrame(SerialFormatToString(params.dataBits, params.parity, params.stopBits));
      end;
   if (Trim(edtTCPPort.Text) = '') and (RegisteredNetworkPortId(id) > 0) then
      begin
      edtTCPPort.Text := IntToStr(RegisteredNetworkPortId(id));
      end;

   // The CI-V address is deliberately NOT prefilled.  Writing the model default
   // into the box makes it look like an operator choice, and it then stops
   // tracking the registry if that default is ever corrected.  Blank means "use
   // the model default", and UpdateEnabledState shows what that default is as
   // greyed prompt text inside the empty field -- which is what makes blank
   // read as a decision rather than an omission (NY4I).

   // If the radio only speaks one transport, move the selection there rather
   // than leaving an impossible combination on screen.
   if SupportsNetworkId(id) and (not SupportsSerialId(id)) then
      begin
      Transport := rtNetwork;
      tbcTransport.ActivePage := tabNetwork;
      end
   else if SupportsSerialId(id) and (not SupportsNetworkId(id)) then
      begin
      Transport := rtSerial;
      tbcTransport.ActivePage := tabSerial;
      end;

   UpdateEnabledState;
end;

procedure TRadioEditForm.SetTransport(const aValue: TRadioTransport);
begin
   FTransport := aValue;
   UpdateEnabledState;
end;

procedure TRadioEditForm.HandleTransportChange(Sender: TObject);
begin
   // Building the tabs must not decide the radio's transport: the first tab
   // becomes active as a side effect of being parented, long before any radio
   // is loaded.
   if not FBuilt then
      begin
      Exit;
      end;

   // ONLY the two transport tabs change the transport.  Advanced is a tab but
   // not a connection, so opening it must not silently turn a network radio
   // into a serial one -- which is exactly what reading the transport straight
   // off the active tab would do.
   if tbcTransport.ActivePage = tabSerial then
      begin
      Transport := rtSerial;
      end
   else if tbcTransport.ActivePage = tabNetwork then
      begin
      Transport := rtNetwork;
      end;
end;

procedure TRadioEditForm.HandleDiscover(Sender: TObject);
var
   model: InterfacedRadioType;
begin
   model := ModelForId(SelectedRegistryId);
   if model = NoInterfacedRadio then
      begin
      Exit;
      end;

   // The button stays disabled for the whole search: a second broadcast while
   // the first is still listening would have two sockets on the same port.
   btnDiscover.Enabled := False;
   btnDiscover.Caption    := TC_RADIOEDIT_SEARCHING;
   ClearComboItems(cbxFound);

   // AN HOURGLASS, because a three-second wait with a greyed button and nothing
   // else moving reads as a hung dialog. Safe to set from here even though TR4W
   // owns the message loop: discovery runs on a WORKER, so the loop keeps
   // turning and the WM_SETCURSOR that applies this actually arrives. Restored
   // in TDiscoverDone.Apply -- including the nothing-found path, which is
   // exactly when an operator is most likely to still be waiting.
   Screen.Cursor := crHourGlass;

   // SAY SO IN THE LOG. The second discovery on a form was reported as not
   // populating the drop-down and not showing it had finished, and nothing in
   // this path said anything -- so there was no way to tell a discovery that
   // never returned from one that returned and failed to reach the controls.
   logger.Debug('[RadioEdit] Discovery START model=%d', [Ord(model)]);

   // OFF THE MAIN THREAD.  DiscoverNetworkRadios broadcasts and then waits out
   // its timeout -- about three seconds -- and doing that on the main thread
   // would freeze not just this window but TR4W's whole message loop, which is
   // also servicing the radios and the cluster.
   //
   // The completion comes back through TThread.Queue.  That is the mechanism
   // the FMX coexistence spike existed to prove: nothing in TR4W calls
   // CheckSynchronize, and Queue works only because Forms hooks
   // WakeMainThread and that message reaches FMX through the main loop's
   // fall-through DispatchMessage.
   // A named thread class rather than TThread.CreateAnonymousThread: FPC 3.2.2
   // has no anonymous methods.  The shape is unchanged -- discovery runs off
   // the UI thread and the result is handed back through TThread.Queue so the
   // controls are only ever touched on the main thread.
   TDiscoverThread.Create(Self, model);
end;

procedure TRadioEditForm.HandleFoundSelect(Sender: TObject);
begin
   if not FBuilt then
      begin
      Exit;
      end;
   if SelectedTag(cbxFound) <> '' then
      begin
      edtIP.Text := SelectedTag(cbxFound);
      end;
end;

procedure TRadioEditForm.HandleOK(Sender: TObject);
var
   err: string;
begin
   // AN AUTO-INFO LEVEL THE OPERATOR TYPED IS A NON-STANDARD CONFIGURATION,
   // AND IT AFFECTS OPERATING (NY4I).
   //
   // Blank means "let the radio decide", which is the supported answer and
   // says nothing.  Anything typed overrides a default the driver chose from
   // measured behaviour -- including 0, which turns the radio back to being
   // polled for everything and costs several hundred milliseconds on an
   // unkey.  The operator is told once, on the way out, rather than being
   // stopped: this is their radio and they may have a reason.
   if edtAutoInfo.Visible and (Trim(edtAutoInfo.Text) <> '') then
      begin
      if MessageDlg(TC_RADIOEDIT_AUTOINFOWARN,
                    TMsgDlgType.mtWarning, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0) <> mrYes then
         begin
         Exit;
         end;
      end;

   if not SaveToRadio(err) then
      begin
      ShowMessage(err);
      Exit;
      end;
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(True);
      end;
end;

procedure TRadioEditForm.HandleCancel(Sender: TObject);
begin
   Hide;
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

procedure TRadioEditForm.HandleShow(Sender: TObject);
begin
   RegisterHostedFormHandle(Self.Handle);
end;

procedure TRadioEditForm.HandleClose(Sender: TObject; var Action: TCloseAction);
begin
   UnregisterHostedFormHandle(Self.Handle);
   Action := caHide;
   // Closing with the window button means Cancel: the operator did not accept.
   if Assigned(FOnDone) then
      begin
      FOnDone(False);
      end;
end;

end.
