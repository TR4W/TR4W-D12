{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
unit uNewContest;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}
interface

uses
  TF,
  VC,
  (* LCLType, not Windows (2026-09-08): only TYPES and constants were
    wanted here, and LCLType declares them -- on Windows AS the Windows
    declarations, so no signature moves. *)
  LCLType,
  System.UITypes,     (* TModalResult -- TakenLogOutcome reads the question's answer *)
  uContestBase,       // TNewContestField, TNewContestPrompts -- M9a
  Tree,
  LogDupe,
  LogGrid,
  PostUnit,
  uGradient,
  uCallSignRoutines,
  utils_file,
  Messages
  ,
  uTR4WStrings,
  utils_text,
  LCLStrConsts,
  uNewContestForm;     // TfrmNewContest -- the designed form this unit drives
(* ~~InitialCommands~~ IS GONE -- M9a, 2026-10-02. The fields the dialog may
  ask for are uContestBase.TNewContestField now, because a contest names them
  (TContestBase.DescribeNewContestPrompts) and a contest class may not reach
  into this unit. Same members, same order. *)

{ GONE WITH THE DIALOG PROCEDURE (2026-08-28): NewContestDlgProc itself,
  NewSelectContestListBoxProc -- a list box SUBCLASSED to catch Enter -- and
  ChangeDir and StartContestFromListbox, which existed to drive DlgDirListA
  and DlgDirSelectExA around a filesystem the brief says this dialog should
  not be browsing. See TfrmNewContest.PopulateFiles. }
type
   (* WHAT OK ON A NEW CONTEST CAME TO (issue 276). nloCreate: a new log, its
     choices queued. nloOpenExisting: a log for that contest, date and callsign
     already existed and the operator chose to open it -- nothing queued.
     nloCancel: back to the dialog -- nothing queued, no file. *)
   TNewLogOutcome = (nloCreate, nloOpenExisting, nloCancel);

procedure BeginNewContest;
procedure ClearFields;
(* Queues what the form holds and answers the new contest's log file in aFile.
  It writes no global: the startup caller puts the answer in TR4W_CFG_FILENAME,
  and File > Open Log must not, because the running contest's writers read
  that name (issue 228).

  WHEN THE NAME IS TAKEN IT ASKS (issue 276): create a new log under the next
  free numbered name (uLogNaming.FirstFreeLogFileName), open the existing one
  (aFile is that log), or cancel (aFile is ''). It never overwrites or deletes
  a file. Only nloCreate leaves anything queued.

  aOpenContest is RunNewContestDialog's: the files the running contest was
  opened from. When the taken name IS one of them, Open existing is not
  offered -- it could only answer "already open" (2026-11-11). *)
function SaveNewContest(out aFile: string;
                        const aOpenContest: array of string): TNewLogOutcome;

(* Is aFile one of the files the running contest was opened from? The same
  comparison File > Open Log makes (uOpenLogRelaunch.IsSameLogFile). An empty
  aOpenContest -- startup -- answers False. *)
function IsOneOfOpenContestFiles(const aFile: string;
                                 const aOpenContest: array of string): boolean;

(* THE TAKEN-NAME QUESTION'S ANSWER, read by modal result (never by button
  position): mrYes is Create new log, mrNo is Open existing log, anything
  else -- Cancel, Escape, closing the box -- is Cancel. When the taken log is
  the one open (aTakenIsOpen) Open existing is never the answer, whatever
  arrives: that button is not offered, and opening the open log does nothing
  visible. *)
function TakenLogOutcome(aAnswer: TModalResult;
                         aTakenIsOpen: boolean): TNewLogOutcome;
procedure DisplayCheckBox(Text: string);
(* aRowLabel: the row's label when the contest names one, else '' for the
  field's command name. The command queued is the field's either way. *)
procedure SetCommentAndEnableEditControl(comment: string; EditControl: TNewContestField;
                                         const aRowLabel: string = '');
procedure DisplayInitialCommand(Command: TNewContestField; const aRowLabel: string = '');
//procedure FillMyStateComboBox;


// the open-configuration / new-contest dialog shown at startup.
//
// THE SEAM for the Win32-to-LCL migration (Phase 1, 2026-08-17): the caller
// no longer knows this is a Win32 modal dialog, only that the window opens.
// When the dialog becomes an LCL form, this body changes and nothing else
// does. Deliberately here, in the unit that owns the DlgProc, rather than at
// the call site.
procedure ShowNewContest;

(* THE DIALOG, FOR ANY CALLER -- issue 228. Shows it modally in aMode and
  answers what the operator chose, with the file in aFile ('' and nccNone
  for Cancel). It writes NO global and ends nothing: ShowNewContest turns the
  answer into startup's TR4W_CFG_FILENAME, and File > Open Log into a restart.

  aOpenContest names the files the running contest was opened from (its log,
  and the file it was started on); the Last Contest button is hidden when it
  names one of them, because choosing it could only answer "already open".
  At startup there is none. For nccCreate the choices are queued in
  uNewContestCommands, exactly as at startup.

  OK ON A NEW CONTEST CAN ANSWER nccOpenSelected (issue 276): when its log
  name is taken and the operator chooses Open existing log, the answer is that
  log, as if its row had been chosen, with nothing queued. Cancel on that
  question shows the dialog again. When the taken log is one of aOpenContest
  Open existing is not offered, so this never answers the open log
  (2026-11-11). *)
function RunNewContestDialog(aMode: TNewContestDialogMode;
                             const aOpenContest: array of string;
                             out aFile: string): TNewContestChoice;

(* THE FILE EACH ANSWER MEANS -- the one mapping both callers use: the
  selected or browsed file, the last contest, the new contest's log; ''
  for nccNone. *)
function NewContestResultFile(aChoice: TNewContestChoice;
                              const aSelectedFile, aLatestFile,
                                    aCreatedFile: string): string;

(* THE DIALOG'S RULES ON A FORM THE CALLER MADE -- what ShowNewContest does
  around ShowModal, split out so a test can drive the real rules on a form
  it never shows (issue 217). Attach makes aForm the dialog and hangs this
  unit's handlers on it; Detach takes them down and forgets the contest's
  state, and does not free the form.

  aDomDir is the folder a contest's county file is read from: '' is the
  shipped dom folder (uAppPaths.ShippedDomFilePath), which is what the
  program passes and what set-up's in-state test reads. A test names the
  tree's target\dom, which is not DataDir off Windows. *)
procedure AttachNewContestForm(aForm: TfrmNewContest; const aDomDir: string = '');
procedure DetachNewContestForm;

(* QUEUES WHAT THE CONTEST'S ROWS HOLD -- SaveNewContest's row loop: every
  row the contest asked for, and every CATEGORY row, as the command it
  stands for and the value it holds. *)
procedure QueueNewContestRows;

implementation
uses
   (* SetCharBuffer / CharBufferText -- a fixed AnsiChar buffer written
     and read through its OWN bounds, replacing StrPCopy and
     PAnsiChar(@buf[0]). *)
  uAppPaths,   // ContestDir -- where an operator's contest files live
  SysUtils,            // Format, Trim, FreeAndNil -- the RTL, not TF shims
  Controls,            // mrOk -- the modal results
  Dialogs,             (* QuestionDlg -- a taken log name, asked natively (issue 276) *)
  uLatestContest,     (* TLatestContest -- the last contest, as its log describes it *)
  MainUnit,
  uRadioConfigApply,   // GetLatestConfigFile -- the last contest, from tr4w.json
  uCFG,
  uSettingsModel,      // Settings -- the destination, never assigned from here
  (* StartupMainCallsign + TR4WConfigFileName: this dialog runs BEFORE the
    settings object is loaded, so the callsign it offers has to come from the
    file. See PrepareForm. *)
  uTR4WConfigFile,
  uNewContestCommands, // the dialog's choices, applied at startup after the station load
  (* The log file name and its rule -- one artifact, one directory. *)
  uLogNaming,                // SetCFGCommandValue -- the one route to a [COMMANDS] value
  (* ContestIdentity -- the chosen contest, asked what to prompt for (M9a). *)
  uContestRegistry,
  uAppStrings,         // SNewContestHostArea* -- issue 217
  uDomFileKeys,        // DOM_EXTENSION -- the county file's name, as set-up builds it
  uNewContestHostArea, // THostAreaPlaces, HostAreaOutsideRefusal -- issue 217
  uOpenLogRelaunch;    (* IsSameLogFile -- is the last contest the open one (issue 228) *)

const

  CSAS                                  = 9;
  InitialCommandsSA2                    : array[1..CSAS] of string = (
    '',
    '',
    // Issue #976: CATEGORY-OVERLAY removed -- it was only a dangling label
    // (no control was ever created for it).  Restore it as a real drop-down
    // when the New Contest dialog is rebuilt in modern Delphi.
    '',
    'CATEGORY-ASSISTED',
    'CATEGORY-BAND',
    'CATEGORY-MODE',
    'CATEGORY-OPERATOR',
    'CATEGORY-POWER',
    'CATEGORY-TRANSMITTER');

  InitialCommandsSA                     : array[TNewContestField] of string =
    (
    'MY CHECK',
    'MY FD CLASS',
    'MY GRID',
    'My FOC NUMBER',
    'MY IOTA',
    'MY NAME',
    'MY PARK',
    'MY PREC',
    'MY QTH',
    'MY SECTION',
    'MY STATE',
    'MY ZONE',
    'MY POSTAL CODE',
    'MY LICENSE YEAR'
    );

var
  NewContestDisplayedCommands           : integer;
  (* WHICH FIELD EACH CONTEST ROW HOLDS -- Q104. DisplayInitialCommand hands
    rows out in order and records the field here, so BeginNewContest can ask
    the contest about a row's value by what it IS, not by its caption. Only
    1..NewContestDisplayedCommands are meaningful. *)
  NewContestRowFields                   : array[1..CSAS] of TNewContestField;
  (* THE CONTEST'S OWN COMMENT for its rows (the prompt text), kept so a
    refusal shown in the same place can be taken down again -- Q104. *)
  NewContestPromptComment               : string;
//  NewContestAllowReturn                 : boolean;
  SelectedContest                       : TContestHandle;
  (* THE CHOSEN CONTEST'S "I AM IN <AREA>" BOX -- issue 217. Active only
    while the contest says its station's QTH depends on it
    (TContestBase.DescribeNewContestHostArea), its row was asked for and its
    county file gave places; otherwise the row stays free entry exactly as
    before. The places are owned here and freed by ForgetHostArea. *)
  HostAreaActive                        : boolean = False;
  HostArea                              : TNewContestHostArea;
  HostAreaRow                           : integer = 0;
  HostAreaPlaces                        : THostAreaPlaces = nil;
  (* Where the county file is read from -- see AttachNewContestForm. *)
  NewContestDomDir                      : string = '';

(* sfFLAG IS DELETED (2026-09-08), AND WITH IT AN EMPTY `const` BLOCK. It was DDL_ARCHIVE or DDL_READWRITE or
    DDL_DIRECTORY -- the flag set for a Win32 DlgDirList -- and NOTHING
    referenced it, checked with the comment-blanking reader. The dialog that
    would have used it is long converted; the constant was the only thing
    keeping this unit on the Windows unit. It was the only member of that
    const section, so the section goes too. *)

(* THE CONTEST-SPECIFIC PROMPTS ARE THE CONTEST'S -- M9a, 2026-10-02.

  Two `case SelectedContest of` statements stood here, ~240 lines of contest
  knowledge -- which contest wants a district code, which wants a DOK, which
  wants an oblast -- built up one contest at a time over years. They were
  lifted verbatim out of NewContestDlgProc in the LCL conversion; at M9a each
  arm moved, line for line, into its contest's class as
  TContestBase.DescribeNewContestPrompts, and this unit RENDERS what the
  contest says (docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2m).

  NOTHING HERE NAMES A CONTEST. The last arms were the classless contests',
  in a ClasslessPrompts that is deleted: POTA's went to TContestPOTA
  (2026-10-13, design Q6), RSGB 1.8 MHz's and the UA4W Championship's to
  their classes (2026-10-14, design Q33 and Q28). *)

(* ONE STEP OF A CONTEST'S PROMPTS, ON THE FORM -- the five presentation
  helpers this unit always had, chosen by the step's kind. *)
procedure RenderPrompt(const aPrompt: TNewContestPrompt);
begin
   case aPrompt.Kind of
      npkField:
         begin
         DisplayInitialCommand(aPrompt.Field, aPrompt.RowLabel);
         end;
      npkFieldWithComment:
         begin
         SetCommentAndEnableEditControl(aPrompt.Text, aPrompt.Field, aPrompt.RowLabel);
         end;
      npkIAmIn:
         begin
         DisplayCheckBox(aPrompt.Text);
         end;
      npkIAmInCaption:
         begin
         frmNewContest.ShowIAmIn(aPrompt.Text);
         end;
   end;
end;

(* WHAT THE CHOSEN CONTEST ASKS FOR AT ONE OF THE TWO MOMENTS -- the
  contest's own steps, in its order. The prompts object is the contest's
  answer; it is freed here. *)
procedure ShowContestPrompts(aTicked: boolean);
var
   prompts: TNewContestPrompts;
   i: integer;
begin
   prompts := TNewContestPrompts.Create;
   try
      ContestIdentity(SelectedContest).DescribeNewContestPrompts(prompts);
      if aTicked then
         begin
         for i := 0 to prompts.InsideCount - 1 do
            begin
            RenderPrompt(prompts.Inside(i));
            end;
         end
      else
         begin
         for i := 0 to prompts.ChoiceCount - 1 do
            begin
            RenderPrompt(prompts.Choice(i));
            end;
         end;
   finally
      prompts.Free;
   end;
end;

(* ---------------------------------------------------------------------------
  THE HOST-AREA BOX -- issue 217 (NY4I, 2026-11-05).

  The contest says whether its station's QTH depends on being in the host
  area; this unit only renders the answer. The box is the designed "I am in"
  check box, and it governs ONE row -- the one the contest's prompts already
  asked for -- so every other row (Colorado's MY NAME, the categories) keeps
  what was typed in it. Ticked, that row is a list of the county file's
  keys; unticked, free entry for a state, a province or DX. The command it
  queues is the same either way: the row's field, MY STATE.
  --------------------------------------------------------------------------- *)

procedure ForgetHostArea;
begin
   HostAreaActive := False;
   HostAreaRow := 0;
   FreeAndNil(HostAreaPlaces);
end;

(* The row the contest asked aField in, or 0 when it asked none. *)
function RowOfField(aField: TNewContestField): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 1 to NewContestDisplayedCommands do
      begin
      if (i <= CSAS) and (NewContestRowFields[i] = aField) then
         begin
         Result := i;
         Exit;
         end;
      end;
end;

(* The governed row as the box says: its label, list or box, and notice. *)
procedure ShowHostAreaMode;
var
   notice: string;
begin
   if frmNewContest.IAmIn then
      begin
      frmNewContest.ShowRowPick(HostAreaRow, SNewContestHostAreaCountyLabel,
                                HostAreaPlaces.Displays, HostAreaPlaces.Keys);
      notice := Format(SNewContestHostAreaInsideNotice, [HostArea.Area]);
      end
   else
      begin
      frmNewContest.ShowRowEntry(HostAreaRow, SNewContestHostAreaStateLabel);
      notice := Format(SNewContestHostAreaOutsideNotice, [HostArea.Area]);
      end;
   frmNewContest.SetComment(notice);
   NewContestPromptComment := notice;
end;

(* After the contest's prompts are up: offer the box, if the contest does. *)
procedure SetUpHostArea;
var
   path: string;
begin
   ForgetHostArea;
   if not ContestIdentity(SelectedContest).DescribeNewContestHostArea(HostArea) then
      begin
      Exit;
      end;

   HostAreaRow := RowOfField(HostArea.Field);
   if HostAreaRow = 0 then
      begin
      Exit;
      end;

   (* THE IN-STATE TEST'S OWN FILE, BY THE SAME PATH -- FCONTEST.
     FoundMyStateInDomFile -- so nothing listed can be judged out of state. *)
   if NewContestDomDir = '' then
      begin
      path := ShippedDomFilePath(HostArea.PlacesFile + string(DOM_EXTENSION));
      end
   else
      begin
      path := ExistingDataFile(IncludeTrailingPathDelimiter(NewContestDomDir) +
                               HostArea.PlacesFile + string(DOM_EXTENSION));
      end;
   HostAreaPlaces := THostAreaPlaces.Create;
   HostAreaPlaces.LoadFromFile(path);
   if HostAreaPlaces.Count = 0 then
      begin
      (* No list to offer: the row stays free entry, as it always was. *)
      logger.Warn('[NewContest] %s offers an in-area choice but %s gives no ' +
                  'places, so its row stays free entry.',
                  [ContestId(SelectedContest), path]);
      ForgetHostArea;
      Exit;
      end;

   HostAreaActive := True;
   frmNewContest.ShowIAmIn(Format(TC_IAMIN, [HostArea.Area]));
   ShowHostAreaMode;
end;

(* The 'I am in <state>' box was ticked or cleared. *)
procedure ApplyIAmIn;
begin
   (* THE HOST-AREA BOX CHANGES ITS ONE ROW, nothing else -- issue 217. The
     rest of this procedure is the other contests' box, unchanged: it clears
     every row and shows what ticking asks for. *)
   if HostAreaActive then
      begin
      ShowHostAreaMode;
      BeginNewContest;
      Exit;
      end;

   ClearFields;
   frmNewContest.SetComment('');
   NewContestPromptComment := '';

   (* Unticked: the prompts are what ticking it ASKS FOR, so there is nothing
     to put up. Was an Exit out of the dialog procedure. *)
   if not frmNewContest.IAmIn then
      begin
      Exit;
      end;

   ShowContestPrompts(True);

   BeginNewContest;
end;

(* The chosen contest changed -- a row was chosen in the contest list, or the
  search hid the one that was (then SelectedContest is NoContest). *)
procedure ApplyContestChoice;
begin
   (* THE LINE'S IDENTITY, not its caption read back through
     GetContestFromString -- the caption is the display name since M9b. *)
   SelectedContest := frmNewContest.SelectedContest;
   ForgetHostArea;
   ClearFields;
   frmNewContest.SetComment('');
   NewContestPromptComment := '';
   frmNewContest.ResetIAmIn;

   (* NO CONTEST IS CHOSEN ANY MORE -- the search box hid the one that was
     (Q103). The previous contest's prompts are cleared above and there is no
     contest to ask for new ones; BeginNewContest disables OK. *)
   if SelectedContest <> NoContest then
      begin
      (* THE QSO-PARTY HEAD IS THE CONTEST'S TOO -- TContestBase asks a US state
        party for its county or state, keyed on the IsUSQSOParty trait, and
        British Columbia, which this named out of the head, says otherwise in
        its own class. *)
      ShowContestPrompts(False);
      SetUpHostArea;
      end;

   BeginNewContest;
end;

{ Anything typed that can change whether OK is legal. In the dialog procedure
  this was BeginNewContest called at the bottom of EVERY WM_COMMAND, which is
  the same rule said once. }
procedure FieldsChanged;
begin
   BeginNewContest;
end;

procedure ClearFields;
begin
  NewContestDisplayedCommands := 0;
  frmNewContest.ClearRows;
end;

{ WHETHER OK IS LEGAL YET. Same four rules, asked of the form instead of of
  control handles: a contest is chosen, the callsign is at least three
  characters and passes IsAGoodCall, and every row this contest asked for has
  been filled in -- and, since Q104, with a value the contest does not refuse
  (TContestBase.NewContestValueRefusal). }
procedure BeginNewContest;
var
  res  : boolean;
  i    : integer;
  Call : string;
  refusal: string;
begin
  res  := frmNewContest.ContestChosen;
  Call := frmNewContest.MyCall;

  if Length(Call) < 3 then
     begin
     res := False;
     end;

  { IsAGoodCall takes the ShortString the contest engine uses. }
  if res and (not IsAGoodCall(CallString(Call))) then
     begin
     res := False;
     end;

  for i := 1 to NewContestDisplayedCommands do
     begin
     if Trim(frmNewContest.RowText(i)) = '' then
        begin
        res := False;
        end;
     end;

  (* A FILLED ROW THE CONTEST REFUSES -- Q104. The refusal replaces the
    prompt's comment while it stands and OK stays disabled; the prompt comes
    back when the value is changed to one the contest accepts. *)
  refusal := '';

  (* AN OUTSIDE ENTRY THE BOX DOES NOT TAKE -- issue 217. Inside, the row is
    a list of the area's places, so only "nothing chosen" is left, and that
    is the empty-row rule above. *)
  if HostAreaActive and
     (not frmNewContest.RowIsPick(HostAreaRow)) then
     begin
     refusal := HostAreaOutsideRefusal(HostAreaPlaces, HostArea.Area,
                                       HostArea.HostStates,
                                       frmNewContest.RowText(HostAreaRow));
     end;

  if frmNewContest.ContestChosen then
     begin
     for i := 1 to NewContestDisplayedCommands do
        begin
        if (i <= CSAS) and (refusal = '') and
           (Trim(frmNewContest.RowText(i)) <> '') then
           begin
           refusal := ContestIdentity(SelectedContest).NewContestValueRefusal(
                         NewContestRowFields[i], Trim(frmNewContest.RowText(i)));
           end;
        end;
     end;
  if refusal <> '' then
     begin
     res := False;
     frmNewContest.SetComment(refusal);
     end
  else
     begin
     frmNewContest.SetComment(NewContestPromptComment);
     end;

  frmNewContest.EnableOK(res);
end;

(* ApplyNewContestCommand MOVED to uNewContestCommands as its ApplyOne, and
  it runs at startup now rather than here -- see that unit for why. *)

(* THE QUESTION WHEN A NEW CONTEST'S LOG NAME IS TAKEN (issue 276). The
  answer is read by MODAL RESULT, never by button position: GTK draws the
  buttons in the other order (see MainUnit.YesOrNo). 'IsDefault' binds to the
  button BEFORE it, so Create new log is the default. Cancel is the LCL's own
  button with its own translated caption; Escape and closing the box are
  Cancel too, so nothing proceeds that the operator did not choose.
  QuestionDlg's custom captions must be UTF-8 ansi strings, hence LclText. *)
function TakenLogOutcome(aAnswer: TModalResult;
                         aTakenIsOpen: boolean): TNewLogOutcome;
begin
   if aAnswer = mrYes then
      begin
      Result := nloCreate;
      end
   else if (aAnswer = mrNo) and (not aTakenIsOpen) then
      begin
      Result := nloOpenExisting;
      end
   else
      begin
      Result := nloCancel;
      end;
end;

function IsOneOfOpenContestFiles(const aFile: string;
                                 const aOpenContest: array of string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(aOpenContest) to High(aOpenContest) do
      begin
      if IsSameLogFile(aFile, aOpenContest[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

(* THE TAKEN LOG IS THE ONE OPEN (2026-11-11). From File > Open Log, a New
  Contest whose name matches the running log used to offer Open existing,
  which reached [OpenLog]'s "already open" arm and showed only a quick line:
  the operator saw nothing happen. So the question says it is the log they
  have open and offers Create new log and Cancel only. *)
function AskAboutATakenLogName(const aExisting, aNumbered: string;
                               aTakenIsOpen: boolean): TNewLogOutcome;
var
   answer: TModalResult;
begin
   if aTakenIsOpen then
      begin
      logger.Info('[NewContest] the log name is taken by the log already open, ' +
                  'so Open existing is not offered: %s', [aExisting]);
      answer := QuestionDlg(LclText(SNewLogNameTakenTitle),
                            LclText(Format(SNewLogNameTakenOpenBody, [aExisting, aNumbered])),
                            mtConfirmation,
                            [mrYes,    LclText(SNewLogCreateNumbered), 'IsDefault',
                             mrCancel, 'IsCancel'], 0);
      end
   else
      begin
      answer := QuestionDlg(LclText(SNewLogNameTakenTitle),
                            LclText(Format(SNewLogNameTakenBody, [aExisting, aNumbered])),
                            mtConfirmation,
                            [mrYes,    LclText(SNewLogCreateNumbered), 'IsDefault',
                             mrNo,     LclText(SNewLogOpenExisting),
                             mrCancel, 'IsCancel'], 0);
      end;
   Result := TakenLogOutcome(answer, aTakenIsOpen);
end;

function SaveNewContest(out aFile: string;
                        const aOpenContest: array of string): TNewLogOutcome;
var
   defaultName, freeName: string;
begin
  (* THE LOG FILE. Named by uLogNaming, where the rule and its tests live; this
    supplies the three facts and nothing else.

    ContestDir, NOT TR4W_PATH_NAME, AND THAT IS THE WHOLE FIX FOR A CLASS OF
    BUG.  TR4W_PATH_NAME is uAppPaths.DataDir -- where SHIPPED, READ-ONLY data
    lives.  Everything about a contest is composed from THIS ONE PATH: FCONTEST
    derives TR4W_LOG_FILENAME, the .RST, the .DOM, the server log and the
    preferred CTY.DAT from the directory of the .cfg, so pointing it at a
    read-only place put every one of them there.

    NY4I hit it on a fresh Debian 13 running the AppImage, which mounts itself
    read-only: the contest log could not be created and QSOs were not saved
    (2026-09-10).  On Windows ContestDir IS the binary's directory, so nothing
    changes there.

    THE ANSWER, NOT TR4W_CFG_FILENAME (issue 228). The caller decides where
    it goes: startup's global, or File > Open Log's restart.

    DECIDED BEFORE ANYTHING IS QUEUED (issue 276). The old question, "Folder
    ... already exists. Overwrite ?", was false twice: the object is a log,
    and Yes and No both opened it, because an existing log is opened and
    never replaced (uLogStore, TLogDatabase.CreateNew). So a second CW Open
    session on the same day could not be created at all. Now a taken name
    offers the next free numbered one, the existing log, or Cancel, and
    nothing is queued until the answer is Create. When the taken log is the
    one OPEN (File > Open Log), only the numbered name or Cancel is offered
    (2026-11-11). *)
   Result := nloCreate;
   defaultName := ContestLogFileName(frmNewContest.ContestName,
                                     Now,
                                     frmNewContest.MyCall);
   freeName := FirstFreeLogFileName(ContestDir, defaultName);
   aFile := ContestDir + freeName;

   if freeName <> defaultName then
      begin
      Result := AskAboutATakenLogName(ContestDir + defaultName, aFile,
                   IsOneOfOpenContestFiles(ContestDir + defaultName, aOpenContest));
      if Result <> nloCreate then
         begin
         (* Nothing of this pass stays queued, whichever it was. *)
         ClearNewContestChoices;
         if Result = nloOpenExisting then
            begin
            aFile := ContestDir + defaultName;
            end
         else
            begin
            aFile := '';
            end;
         Exit;
         end;
      end;

  begin
    (* QUEUED, NOT ASSIGNED AND SAVED HERE. The settings object has not been
      loaded from settings\tr4w.json yet -- that happens after this dialog --
      so MainCallsign always read '' here, and SaveSettings wrote the
      constructor defaults over the operator's whole settings section. See
      uNewContestCommands.

      THE TempBuffer1 / TempBuffer2 COPIES ARE GONE (issue 228): the
      callsign was copied into TempBuffer1 and its slashes deleted, and the
      contest name into TempBuffer2, and nothing read either afterwards --
      the .cfg they were built for has not been written since 66ac1ebe. *)
    ClearNewContestChoices;
    SetNewContestMainCallsign(frmNewContest.MyCall);

    (* ONE FILE, IN ONE DIRECTORY -- no folder per contest.

       NY4I, 2026-09-02: "There is really no reason for a folder for each one
       anymore." It was not arbitrary: a contest used to produce eight files --
       the .CFG, the .TRW, the .RST, an .ADI and a .LOG when exported,
       SERVERLOG.TMP, REMAININGMULTS.TXT and sometimes a .DOM override -- and
       grouping them was the only way to keep a directory legible. With a
       single .db that reason is gone, and a folder holding one file is a level
       of nesting an operator opens for nothing.

       THE POTA SPECIAL CASE GOES WITH IT. It existed to put the DATE in the
       folder name, because two activations of the same park on different days
       would otherwise collide. Every log's name carries its date now, so POTA
       needs no special case -- it was the general rule, arriving early. *)
  end;

  (* THE SETTINGS ARE QUEUED, NOT APPLIED -- AND NOT WRITTEN TO A FILE.

    This built a .cfg line by line and startup read it back AFTER the station
    settings, so the contest's values won. 66ac1ebe took the file out and
    applied the values here instead, which is BEFORE the station settings are
    loaded -- and the load then put the station's values back over them: an
    empty MY CALL on a fresh station, and the station's own call replacing a
    club call on a configured one.

    So they wait in uNewContestCommands, and uProgramMain applies them where
    the .cfg used to be read -- after the station load, with the effects
    subscribed, before the log is created and captures them. Each is still
    marked as the CONTEST'S when it is applied. *)
  QueueNewContestCommand('MY CALL', frmNewContest.MyCall);

  QueueNewContestRows;

  (* CONTEST LAST, AND THAT IS NOT COSMETIC. It was the last line the .cfg
    carried, so it was applied last, and its effect (FoundContest) builds the
    contest's state -- exchange type, multipliers, domestic file -- from the
    values set above it. Applied first, it would build that state from
    whatever the previous contest left behind. The queue keeps this order. *)
  QueueNewContestCommand('CONTEST', frmNewContest.ContestName);

  begin

     // TERMINATE THE LAST LINE (2026-08-16). Every other line this routine
     // writes ends #13#10; this one did not, so every .cfg TR4W creates ended
     // mid-line -- 8 of the 13 golden-corpus fixtures still do.
     //
     // A file whose last line has no terminator is a trap for anything that
     // APPENDS to it: the new text welds onto the CONTEST= line and TR4W then
     // reports "Invalid statement in config file" for a line nobody typed.
     // This same file is written again later through
     // WritePrivateProfileStringA (MainUnit, uEditMessage), and hand-editing
     // is normal for .cfg files, so the append case is not hypothetical.
     //
     // Pre-existing in D7 (uNewContest.pas:660 there), not a port regression.
     // Existing .cfg files are unaffected -- this only changes what is newly
     // written, and TR4W already reads an unterminated last line correctly.
     { The modal form closes itself -- ShowNewContest reads Choice. }
     end;

end;

(* THE COMMAND A ROW STANDS FOR. A row the contest asked for is its field's
  command, recorded when the row was handed out (DisplayInitialCommand); a
  CATEGORY row is its permanent label. Until issue 217 the label was read
  back for both, which was the same text -- but the host-area box labels the
  MY STATE row "MY COUNTY" for a station inside the area, and the command
  must not follow the label. *)
function RowCommand(aRow: integer): string;
begin
   if (aRow <= NewContestDisplayedCommands) and (aRow <= CSAS) then
      begin
      Result := InitialCommandsSA[NewContestRowFields[aRow]];
      end
   else
      begin
      Result := frmNewContest.RowCaption(aRow);
      end;
end;

procedure QueueNewContestRows;
var
   i: integer;
begin
   { A row the contest never asked for is empty and is skipped. }
   (* A CATEGORY ROW IS QUEUED EVEN WHEN BLANK. Its blank item is a choice --
     "no category", the *UNSET member (NY4I, 2026-10-29) -- and skipping it
     would leave the setting's default in force instead. The six are the rows
     InitialCommandsSA2 names; the per-contest rows are not, and a blank one
     is still one the contest never asked for. *)
   for i := 1 to CSAS do
      begin
      if (Trim(frmNewContest.RowText(i)) = '') and
         (InitialCommandsSA2[i] = '') then
         begin
         Continue;
         end;
      QueueNewContestCommand(RowCommand(i), frmNewContest.RowText(i));
      end;
end;

{ The formatting is Format, not TF.Format through a shared PAnsiChar buffer:
  these strings go to an LCL caption, so there is no byte boundary to cross and
  no reason to route them via wsprintfBuffer. }
procedure DisplayCheckBox(Text: string);
begin
  frmNewContest.ShowIAmIn(Format(TC_IAMIN, [Text]));
end;

procedure SetCommentAndEnableEditControl(comment: string; EditControl: TNewContestField;
                                         const aRowLabel: string);
begin
  DisplayInitialCommand(EditControl, aRowLabel);
  frmNewContest.SetComment(comment);
  NewContestPromptComment := comment;
end;

(* ~~EnterCountyOrState~~ IS GONE -- M9a. The QSO-party head it put up is
  TContestBase.DescribeNewContestPrompts now, stated once there. *)

{ Rows are handed out IN ORDER as contests ask for them -- the counter is the
  next free row, not the command's identity. Two contests wanting two fields
  get rows 1 and 2 whichever fields those are. }
(* THE ROW'S LABEL IS THE CONTEST'S WORD WHEN IT GIVES ONE (NY4I,
  2026-11-11: the European HF Championship asked for a licence year beside a
  row labelled MY ZONE). The FIELD is recorded either way, and RowCommand
  queues that -- the label never becomes a command. *)
procedure DisplayInitialCommand(Command: TNewContestField; const aRowLabel: string);
var
   rowLabel: string;
begin
  inc(NewContestDisplayedCommands);
  if NewContestDisplayedCommands <= CSAS then
     begin
     NewContestRowFields[NewContestDisplayedCommands] := Command;
     end;
  if aRowLabel <> '' then
     begin
     rowLabel := aRowLabel;
     end
  else
     begin
     rowLabel := InitialCommandsSA[Command];
     end;
  frmNewContest.EnableRow(NewContestDisplayedCommands, rowLabel);
end;


{ WHAT WM_INITDIALOG DID, minus creating thirty controls by hand. }
procedure PrepareForm(const aOpenContest: array of string);
var
   latest: string;
   (* Handed to the form, which owns it from then on. *)
   describedLatest: TLatestContest;
   myCall: string;
   i     : integer;
begin
   (* The title is NOT set here: the form owns it (HandleShow, through
      uNewContestForm.NewContestFormCaption), and OnShow runs after this, so a
      write here was overwritten -- by a bare TC_OPENCONFIGURATIONFILE that
      dropped the version. One writer. *)
   (* ContestDir, NOT TR4W_PATH_NAME -- the same distinction the .db creation
      site records at length above, missed at the LISTING site. TR4W_PATH_NAME
      is uAppPaths.DataDir, which on macOS is the read-only Contents/Resources
      INSIDE the .app bundle, so Browse opened there and the list came back
      empty: an operator's contests are not, and cannot be, in there (NY4I,
      2026-09-21). On Windows the two are the same directory, which is why
      this survived. *)
   frmNewContest.PopulateFiles(ContestDir);

   (* THE FILE, NOT THE SETTINGS OBJECT -- fixed 2026-09-19.

     THIS PRE-FILL HAD NEVER ONCE FIRED. It read Settings.My.MainCallsign, and
     THIS DIALOG RUNS BEFORE LoadSettingsForStartup: ShowNewContest is called
     from uProgramMain well above the load, so the settings object still holds
     its constructor defaults and the callsign is always ''. So the guard
     skipped the assignment every time, and the box opened empty on a station
     that has had a callsign for years.

     The predecessor it replaced read MAIN CALLSIGN out of tr4w.ini and
     assigned the global, which was worse: on a station whose ini disagreed it
     silently CHANGED the operator's callsign, and on one with no ini it
     blanked it. That is why the rule for anything running this early is read
     the file, never assign Settings, never save -- and StartupMainCallsign is
     the sanctioned way to do it, beside StartupLogLevel and
     StartupUILanguage.

     A FIRST RUN WITH NO FILE STILL OPENS EMPTY: the reader answers '' for an
     absent, blank or unreadable file. *)
   myCall := StartupMainCallsign(TR4WConfigFileName);
   if myCall <> '' then
      begin
      frmNewContest.SetMyCall(myCall);
      end;

   // FROM settings\tr4w.json, not tr4w.ini (NY4I, 2026-08-16). An empty
   // result is the ordinary first-run state and simply hides the button.
   (* THE STORE IS THE ONLY COPY NOW.  TR4W_LATESTCFG_FILENAME was a second
     one, kept in step by hand from here and from uProgramMain -- and this very
     routine already read the STORE rather than the global, which is what gave
     it away. *)
   latest := GetLatestConfigFile;

   (* A RECORDED FILE THAT IS GONE SAYS SO NOW.

     The stored value is an ABSOLUTE path -- uProgramMain records
     TR4W_CFG_FILENAME after ExpandFileName -- so nothing that moves the file
     moves the pointer with it, and a macOS build before 5.0.16 recorded paths
     INSIDE the .app bundle which no longer exist at all.  All that happened
     was that the button vanished, which is why it takes a bench session to
     notice.  One line, once, naming the file. *)
   if (latest <> '') and (not FileExists(latest)) then
      begin
      logger.Warn('[NewContest] the last contest file recorded in the settings ' +
                  'store no longer exists, so the button is hidden: %s', [latest]);
      latest := '';
      end;

   (* THE LAST CONTEST IS THE ONE RUNNING, FROM FILE > OPEN LOG (issue 228).
     It is recorded once, at startup (uProgramMain, SetLatestConfigFile), so
     mid-session it names the contest already open, and the button could only
     answer "already open". Hidden, and said in the log. *)
   if (latest <> '') and IsOneOfOpenContestFiles(latest, aOpenContest) then
      begin
      logger.Info('[NewContest] the last contest is the one open, so its ' +
                  'button is hidden: %s', [latest]);
      latest := '';
      end;

   if latest <> '' then
      begin
      (* NO AMPERSAND INSIDE PARENTHESES.  ON macOS IT COSTS THE WHOLE CAPTION.

        This read ' (Alt+&A):' and NY4I saw a button captioned exactly "Latest
        config file" on a signed 5.0.17 -- which looks like the designer
        placeholder and is not.  A parenthesised ampersand is the macOS
        convention for a CJK accelerator, so the Cocoa widget set DELETES it
        and everything after it: cocoautils.pas, TCocoaStringUtil
        .removeAcceleration, `Result := str.Substring(0, posLeft).Trim` when a
        '(' precedes the '&' and a ')' follows it.  The line break and the file
        name are after the ')', so the path never reached the screen.  Win32
        and GTK only strip the '&', which is why this is macOS-only.

        So the accelerator stays Alt+A -- it is documented in
        docs/keyboard_shortcuts.md -- and the parentheses go.  A translated
        label that contains an UNCLOSED '(' before the '&' would still trip it;
        nothing in the catalogues does, and the guard belongs in a caption lint
        rather than here. *)
      (* WHAT CONTEST, AND WHICH YEAR -- asked of the log itself (NY4I,
        2026-10-19: "make the contest and year more obvious"). A file that
        cannot say -- an old .cfg, a damaged or foreign database -- keeps the
        old caption, the path; the reason goes to the debug log only, because
        nothing is wrong that the operator needs to act on. *)
      describedLatest := TLatestContest.Create(latest);
      if (not describedLatest.Described) and
         logger.IsDebugEnabled then
         begin
         logger.Debug('[NewContest] the last contest file does not describe ' +
                      'itself (%s), so the button shows its path: %s',
                      [describedLatest.Why, latest]);
         end;
      frmNewContest.ShowLatest(TC_LATEST_CONFIG_FILE + ', Alt+&A:', describedLatest);
      end
   else
      begin
      frmNewContest.ShowLatest('', nil);
      end;

   { The six CATEGORY-* rows are labelled once and stay labelled. Rows 1..3 are
     empty in this table because they are named per contest by DisplayInitialCommand. }
   for i := 1 to CSAS do
      begin
      if InitialCommandsSA2[i] <> '' then
         begin
         frmNewContest.SetRowLabel(i, InitialCommandsSA2[i]);
         end;
      end;

   BeginNewContest;   { OK starts disabled unless the form is already valid }
end;

(* ~~OpenSelectedConfig~~ IS GONE (issue 228): it wrote SelectedFile -- a
  FULL path already, the grid can be showing any directory -- into
  TR4W_CFG_FILENAME. NewContestResultFile answers it now, and only the
  startup caller writes the global. *)
function NewContestResultFile(aChoice: TNewContestChoice;
                              const aSelectedFile, aLatestFile,
                                    aCreatedFile: string): string;
begin
   case aChoice of
      nccOpenSelected:
         begin
         Result := aSelectedFile;
         end;
      nccLatest:
         begin
         Result := aLatestFile;
         end;
      nccCreate:
         begin
         Result := aCreatedFile;
         end;
   else
      begin
      Result := '';
      end;
   end;
end;

procedure AttachNewContestForm(aForm: TfrmNewContest; const aDomDir: string = '');
begin
   NewContestDomDir := aDomDir;
   frmNewContest    := aForm;
   SelectedContest  := NoContest;
   ForgetHostArea;
   NewContestDisplayedCommands := 0;
   NewContestPromptComment := '';
   OnContestChanged := ApplyContestChoice;
   OnIAmInChanged   := ApplyIAmIn;
   OnFieldsChanged  := FieldsChanged;
end;

procedure DetachNewContestForm;
begin
   OnContestChanged := nil;
   OnIAmInChanged   := nil;
   OnFieldsChanged  := nil;
   ForgetHostArea;
   NewContestDomDir := '';
   frmNewContest    := nil;
end;

function RunNewContestDialog(aMode: TNewContestDialogMode;
                             const aOpenContest: array of string;
                             out aFile: string): TNewContestChoice;
var
   form: TfrmNewContest;
   created, selected: string;
   showAgain: boolean;
begin
   aFile  := '';
   Result := nccNone;
   AttachNewContestForm(TfrmNewContest.Create(nil));
   try
      frmNewContest.Mode := aMode;
      PrepareForm(aOpenContest);

      (* CANCEL ON A TAKEN LOG NAME SHOWS THE DIALOG AGAIN (issue 276), as the
        operator left it -- the form is still attached and nothing resets it on
        show. SaveNewContest has queued nothing for that answer. OPEN EXISTING
        is answered as if that log's row had been chosen in the grid, so File >
        Open Log reopens it rather than handing over a new contest. *)
      repeat
         showAgain := False;
         if frmNewContest.ShowModal = mrOk then
            begin
            Result   := frmNewContest.Choice;
            selected := frmNewContest.SelectedFile;
            created  := '';
            if Result = nccCreate then
               begin
               case SaveNewContest(created, aOpenContest) of
                  nloOpenExisting:
                     begin
                     Result   := nccOpenSelected;
                     selected := created;
                     end;
                  nloCancel:
                     begin
                     Result    := nccNone;
                     showAgain := True;
                     end;
               end;
               end;
            (* The last contest from the store, not from a global copy of it. *)
            aFile := NewContestResultFile(Result, selected,
                                          GetLatestConfigFile, created);
            end;
      until not showAgain;
   finally
      (* Handlers down BEFORE the form goes, as they always were, so nothing
        the form raises while it is destroyed reaches this unit. *)
      form := frmNewContest;
      DetachNewContestForm;
      form.Free;
   end;
end;

procedure ShowNewContest;
var
   chosen: string;
begin
   if RunNewContestDialog(ncmStartup, [], chosen) = nccNone then
      begin
      { WM_CLOSE set this sentinel and uProgramMain tests it to mean
        "the operator did not choose a contest" -- see the caller. }
      TR4W_CFG_FILENAME[0] := '_';
      end
   else
      begin
      SetCharBuffer(TR4W_CFG_FILENAME, chosen);
      end;
end;
end.

