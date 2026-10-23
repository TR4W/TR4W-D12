unit uExchangeBuilder;
{$I tr4w.inc}

(*
  Shared exchange string builders for RTC / HamScore / N1MM-style UDP
  ContactInfo broadcasts, and the log's exchange_sent column.

  The TR4W exchange parser is intentionally forgiving about field order --
  for a grid contest you can type either "EL88 1234" or "1234 EL88" and
  parse both correctly into NumberReceived / QTHString.  But scoring
  consumers (HamScore RTC, external loggers) want a canonical form so
  that the same QSO doesn't appear two different ways depending on what
  the operator typed.

  THE CONTEST BUILDS ITS OWN CANONICAL FORM -- M9a, 2026-10-02. This unit
  held a `case RXData.ceContest of` naming fourteen contests' field orders
  and an `if ceContest = RTC` for the sent side; each is that contest's
  TContestBase.CanonicalReceivedExchange / CanonicalSentExchange now, and
  the shared pieces (whitespace, the default RST, the CQ-template rebuild)
  are the leaf uCanonicalExchange. What is left here is what a contest may
  not do itself: read the session's settings, and ask the QSO's contest
  (ContestIdentity -- the QSO's own, as the `case` keyed on it).

  "Future: when the contest factory grows an RTC exchange template field per
  contest, these dispatchers move there and the case statement disappears" --
  that is what M9a did. Output is plain text; XML escaping is the caller's
  job.
*)

interface

uses
  VC,
  uQsoMyFacts;   // TQsoMyFacts -- a stored QSO's own station

// Plain-text builders (no XML escaping).
function BuildSentExchangeText(const RXData: ContestExchange): string;
function BuildRxExchangeText  (const RXData: ContestExchange): string;

(* WHAT A STORED QSO SENT, as HamScore's one-QSO line says it (issue 95, Q13).

  THE RECORD WINS, as it does for the final Cabrillo/ADIF (NY4I, 2026-10-23:
  "HamScore should follow the edited serial"). The sent exchange is rebuilt
  from the QSO's own fields -- its serial above all -- and from where the
  station was for that QSO: the grid is the row's (uContestBase.
  MyStationExchangeOfQSO, the overlay PostUnit applies), never today's for a
  row that recorded its station. The text is the same canonical spelling
  BuildSentExchangeText makes, so a QSO whose station did not change reads
  exactly as it did when logged.

  exchange_sent is NOT the source for a row logged here: it is captured once,
  at log time, and is insert-only, so after an edit of the sent serial it is
  stale. It is the source only where the text cannot be rebuilt -- a row
  imported (or stamped) from a file, whose STX_STRING is what the file says was
  sent (uQsoMyFacts.RecordedSentExchange, the rule the ADIF writer uses).

  A row that never captured its station (NotCapturedMyFacts) is built from the
  session, as before (NY4I, ruling A); so is the just-logged QSO, where the
  session IS what is being recorded. The CQ exchange template is the one input
  with no per-QSO copy but exchange_sent, and is today's. *)
function BuildSentExchangeTextOf(const RXData: ContestExchange;
                                 const aFacts: TQsoMyFacts;
                                 const aRecordedSent: AnsiString): string;

implementation

uses
  (* LogCW went with the CQ exchange template, 2026-09-12: that global was
    the only symbol this unit took from it. *)
  uSettingsModel,      // the CQ exchange template, and Settings.My.ResolvedGrid
  uContestBase,        // TCanonicalExchangeContext
  uContestRegistry,    // ContestIdentity -- the QSO's contest
  uCanonicalExchange;  // CollapseWhitespace

(* THE ONE BUILDER: the session's CQ template and a grid HANDED IN. *)
function BuildSentExchangeWithGrid(const RXData: ContestExchange;
                                   const aGrid: string): string;
var
   ctx: TCanonicalExchangeContext;
begin
   (* THE SESSION'S VALUES, HANDED IN -- the contest reads no global. The
      template is CQ EXCHANGE CW as it stands; the RTC builds from MY GRID
      instead, with no RST (its HamScore organizer, 2026-05). *)
   ctx.CQExchangeTemplate := string(Settings.Messages.CqExchangeCw);
   ctx.MyGrid := aGrid;
   Result := ContestIdentity(RXData.ceContest).CanonicalSentExchange(RXData, ctx);
end;

function BuildSentExchangeText(const RXData: ContestExchange): string;
begin
   Result := BuildSentExchangeWithGrid(RXData, Settings.My.ResolvedGrid);
end;

function BuildSentExchangeTextOf(const RXData: ContestExchange;
                                 const aFacts: TQsoMyFacts;
                                 const aRecordedSent: AnsiString): string;
var
   session, my: TMyStationExchange;
begin
   (* AN IMPORTED ROW SENT WHAT ITS FILE SAYS -- the rule the ADIF writer
      applies; a logged row returns '' and is rebuilt. *)
   if Length(RecordedSentExchange(aFacts, aRecordedSent)) > 0 then
      begin
      Result := string(RecordedSentExchange(aFacts, aRecordedSent));
      Exit;
      end;

   (* THE STATION AS IT WAS FOR THIS QSO: the session's, overlaid by what the
      row recorded -- the same function the final export asks. Only the grid
      is read here. *)
   session := Default(TMyStationExchange);
   session.MyGrid := Settings.My.ResolvedGrid;
   my := MyStationExchangeOfQSO(session, aFacts, False, False);
   Result := BuildSentExchangeWithGrid(RXData, my.MyGrid);
end;

function BuildRxExchangeText(const RXData: ContestExchange): string;
begin
   (* COLLAPSED HERE, FOR EVERY CONTEST, as the `case` collapsed every arm
      and its `else`. *)
   Result := CollapseWhitespace(
                ContestIdentity(RXData.ceContest).CanonicalReceivedExchange(RXData));
end;

end.
