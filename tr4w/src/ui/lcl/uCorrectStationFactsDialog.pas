unit uCorrectStationFactsDialog;
{$I ..\..\tr4w.inc}

(*
  TOOLS -> CORRECT STATION FACTS (issue 223, NY4I 2026-11-22).

  A wrong MY ZONE (or grid, or section ...) found after QSOs were logged: one
  of our station's values set on every logged QSO, or on those from log
  record n on. NY4I's rulings: only the my_* station facts (never the
  contact's own data); the confirmation says it changes ALL PRIOR CONTACTS
  and that the log is BACKED UP FIRST; every changed QSO counts as an edit
  everywhere (Club Log / WRL, the multi-op server, UDP); the audit is one
  line in tr4w.log; a Tools command of its own that ends in a rescore.

  THIS UNIT IS ONLY THE QUESTIONS, natively: InputCombo for the fact,
  InputQuery for the value and the first record, QuestionDlg for the
  confirmation (Cancel is the default and the Esc answer). The rules are
  uStationFactRecord's (STATION_FACT_BULK_CORRECTABLE, StationFactBulkProblem),
  the write is uLogStore.LogStoreCorrectStationFacts (backup, one transaction,
  committed outcome), and what follows the commit is
  uEditQSO.AnnounceStationCorrection (rescore, then each row as an edit).

  Every LCL string crosses through LclText: the LCL's string is UTF-8
  AnsiString, this program's is UnicodeString.
*)

interface

(* The Tools menu item. Main thread. Refused, with a message, while the log is
  read-only or unusable. *)
procedure ShowCorrectStationFacts;

implementation

uses
   Classes, SysUtils, Controls, Dialogs, LCLType,
   Forms,               (* TModalResult *)
   utils_text,          (* LclText, ValChecked *)
   uAppStrings,
   uAppPaths,           (* BackupDir -- where the backup first goes *)
   uSettingsModel,      (* TStationFact, Settings.My.Resolved -- the value offered *)
   uStationFactRecord,  (* the whitelist, the value rule, the captions *)
   uLogStore,           (* the plan, the correction, the log's state *)
   uEditQSO,            (* AnnounceStationCorrection -- after the commit *)
   VC,
   PostUnit,            (* Contest, the open log's *)
   uContestRegistry;    (* ContestIdentity -- its own narrower rule *)

(* A message box, its text through LclText. *)
procedure Say(const aText: string);
begin
   ShowMessage(LclText(aText));
end;

(* THE FACT: the bulk-correctable ones, by caption. False on Cancel. *)
function AskFact(out aFact: TStationFact): boolean;
var
   captions: TStringList;
   facts: array of TStationFact;
   fact: TStationFact;
   chosen: integer;
begin
   Result := False;
   aFact := Low(TStationFact);
   captions := TStringList.Create;
   try
      SetLength(facts, 0);
      for fact := Low(TStationFact) to High(TStationFact) do
         begin
         if STATION_FACT_BULK_CORRECTABLE[fact] then
            begin
            captions.Add(LclText(StationFactCaption(fact)));
            SetLength(facts, Length(facts) + 1);
            facts[High(facts)] := fact;
            end;
         end;
      chosen := InputCombo(LclText(SStationCorrectionTitle),
                           LclText(SStationCorrectionChooseFact), captions);
      if (chosen >= 0) and (chosen <= High(facts)) then
         begin
         aFact := facts[chosen];
         Result := True;
         end;
   finally
      captions.Free;
   end;
end;

(* THE VALUE, offered as the setting holds it now. False on Cancel. *)
function AskValue(aFact: TStationFact; out aValue: string): boolean;
var
   typed: AnsiString;
begin
   aValue := '';
   typed := LclText(Settings.My.Resolved(aFact));
   Result := InputQuery(LclText(SStationCorrectionTitle),
                        LclText(UnicodeFormat(SStationCorrectionValuePrompt,
                                              [StationFactCaption(aFact)])),
                        typed);
   if Result then
      begin
      aValue := Trim(UTF8Decode(typed));
      end;
end;

(* THE FIRST LOG RECORD, 1-based as the operator counts. False on Cancel or
  a value that is no record number (said). *)
function AskFirstRecord(out aRecord: integer): boolean;
var
   typed: AnsiString;
   value: Longint;
   code: integer;
begin
   aRecord := 1;
   typed := '1';
   Result := InputQuery(LclText(SStationCorrectionTitle),
                        LclText(SStationCorrectionFromPrompt), typed);
   if not Result then
      begin
      Exit;
      end;
   value := 0;
   ValChecked(Trim(UTF8Decode(typed)), value, code);
   if (code <> 0) or (value < 1) then
      begin
      Say(SStationCorrectionBadFrom);
      Result := False;
      Exit;
      end;
   aRecord := value;
end;

(* How many of the planned rows are a peer's. *)
function PeerRows(aResult: TStationCorrectionResult): integer;
var
   i: integer;
begin
   Result := 0;
   for i := 0 to aResult.Plan.Count - 1 do
      begin
      if aResult.Plan.Peer[i] then
         begin
         Inc(Result);
         end;
      end;
end;

procedure ShowCorrectStationFacts;
var
   correction: TStationFactCorrection;
   value: string;
   problem: string;
   firstRecord: integer;
   scope: string;
   plan: TStationCorrectionResult;
   done: TStationCorrectionResult;
   answer: TModalResult;
begin
   (* Asked before any question: a read-only log takes no correction. *)
   if LogStoreIsReadOnly then
      begin
      Say(SStationCorrectionReadOnly);
      Exit;
      end;
   if not LogStoreIsUsable then
      begin
      Say(SStationCorrectionFailed);
      Exit;
      end;

   correction.OldText := '';
   correction.Count := 0;
   if not AskFact(correction.Fact) then
      begin
      Exit;
      end;
   if not AskValue(correction.Fact, value) then
      begin
      Exit;
      end;
   problem := StationFactBulkProblem(correction.Fact, value);
   if problem = '' then
      begin
      (* The open contest's narrower rule (the ALL JA's power class letters). *)
      problem := ContestIdentity(Contest).StationFactProblem(correction.Fact, value);
      end;
   if problem <> '' then
      begin
      Say(problem);
      Exit;
      end;
   correction.NewText := UTF8Encode(value);
   if not AskFirstRecord(firstRecord) then
      begin
      Exit;
      end;
   if firstRecord = 1 then
      begin
      scope := SStationCorrectionScopeAll;
      end
   else
      begin
      scope := UnicodeFormat(SStationCorrectionScopeFrom, [firstRecord]);
      end;

   (* WHAT WOULD CHANGE -- read only, so the question can name the count. *)
   plan := LogStorePlanStationCorrection(correction, firstRecord - 1);
   try
      if not plan.Ok then
         begin
         Say(plan.Reason);
         Exit;
         end;
      if plan.RowsChanged = 0 then
         begin
         Say(SStationCorrectionNothing);
         Exit;
         end;

      (* THE EXPLICIT CONFIRMATION. Cancel is the default AND the Esc answer;
         only the named button changes anything. Compared by modal result,
         never by button position (GTK orders them the other way). *)
      answer := QuestionDlg(LclText(SStationCorrectionTitle),
                            LclText(UnicodeFormat(SStationCorrectionConfirm,
                               [plan.FactCaption, plan.NewValue, plan.RowsChanged,
                                scope, plan.OldValues, plan.Plan.Imported,
                                plan.Plan.NotCaptured, plan.Plan.PerPlace,
                                PeerRows(plan)])),
                            mtWarning,
                            [mrOk,     LclText(SStationCorrectionChangeButton),
                             mrCancel, LclText(SStationCorrectionCancelButton),
                             'IsDefault', 'IsCancel'], 0);
      if answer <> mrOk then
         begin
         Exit;
         end;
   finally
      plan.Free;
   end;

   (* THE CHANGE: backup, one transaction, committed -- or nothing. *)
   done := LogStoreCorrectStationFacts(correction, firstRecord - 1, BackupDir);
   try
      if not done.Ok then
         begin
         Say(done.Reason);
         Exit;
         end;
      if done.RowsChanged = 0 then
         begin
         Say(SStationCorrectionNothing);
         Exit;
         end;

      (* COMMITTED: only now is anyone told. *)
      AnnounceStationCorrection(done.Plan.RowIds, done.Plan.RecordIndexes,
                                done.Plan.Peer);
      Say(UnicodeFormat(SStationCorrectionDone,
                        [done.FactCaption, done.NewValue, done.RowsChanged,
                         done.BackupPath]));
   finally
      done.Free;
   end;
end;

end.
