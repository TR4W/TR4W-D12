unit uWRLLogbookSuggest;
{$I tr4w.inc}
(*
  THE DEFAULT NAME OF A NEW WRL LOGBOOK, FROM THE OPEN CONTEST (issue 358).

  The pure naming rule is uExternalLoggerActions.WRLDefaultLogbookName; this
  unit only gathers its three inputs from the program's state, which is why it
  is separate: those reads are main-thread reads (the contest, the log) and a
  test of the rule needs none of them.

    year        the log's contest year, as uLogFileFacts reports it (the
                contest row's start time, else the earliest QSO, else the day
                it was created), the current year when no log answers;
    contest id  the open contest's ADIF CONTEST_ID (ContestIdentity);
    modes       the modes the contest credits (UsesMode, asked with no submode):
                CW, SSB for phone, DIGI for digital. A contest that credits all
                three, or states nothing (the base answers True for every mode),
                names itself MIXED.

  MAIN THREAD ONLY: it reads the contest handle and opens the log read-only.
*)

interface

(* The suggested name, always usable: it never raises and never returns ''. *)
function SuggestedWRLLogbookName: string;

(* The station call the new logbook records as its defaultCallSign: MY CALL, the
   call being operated. '' when none is set (the field is then left out). *)
function SuggestedWRLCallSign: string;

implementation

uses
   SysUtils, DateUtils, VC, PostUnit, uContestRegistry, uContestBase,
   uLogStore, uLogFileFacts, uExternalLoggerActions, uSettingsModel;

function SuggestedWRLCallSign: string;
begin
   Result := Trim(Settings.My.Call);
end;

function SuggestedWRLLogbookName: string;
var
   facts: TLogFileFacts;
   why, adifId: string;
   year: integer;
   modes: array of string;
   contest: TContestBase;
begin
   year := 0;
   adifId := '';
   modes := nil;
   try
      facts := ReadLogFileFacts(LogStoreFileName, why);
      if facts <> nil then
         begin
         try
            year := facts.ContestYear;
         finally
            facts.Free;
         end;
         end;
      contest := ContestIdentity(PostUnit.Contest);
      adifId := contest.ADIFContestId;
      SetLength(modes, 0);
      if contest.UsesMode(VC.CW, VC.eNoMode) then
         begin
         SetLength(modes, Length(modes) + 1);
         modes[High(modes)] := 'CW';
         end;
      if contest.UsesMode(VC.Phone, VC.eNoMode) then
         begin
         SetLength(modes, Length(modes) + 1);
         modes[High(modes)] := 'SSB';
         end;
      if contest.UsesMode(VC.Digital, VC.eNoMode) then
         begin
         SetLength(modes, Length(modes) + 1);
         modes[High(modes)] := 'DIGI';
         end;
   except
      on E: Exception do
         begin
         (* A suggestion is a convenience: whatever could not be read is
            simply left out of the name, which the operator edits anyway. *)
         end;
   end;
   if year <= 0 then
      begin
      year := YearOf(Now);
      end;
   Result := WRLDefaultLogbookName(year, adifId, modes);
end;

end.
