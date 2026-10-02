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
  VC;

// Plain-text builders (no XML escaping).
function BuildSentExchangeText(const RXData: ContestExchange): string;
function BuildRxExchangeText  (const RXData: ContestExchange): string;

implementation

uses
  (* LogCW went with the CQ exchange template, 2026-09-12: that global was
    the only symbol this unit took from it. *)
  uSettingsModel,      // the CQ exchange template, and Settings.My.Grid
  uContestBase,        // TCanonicalExchangeContext
  uContestRegistry,    // ContestIdentity -- the QSO's contest
  uCanonicalExchange;  // CollapseWhitespace

function BuildSentExchangeText(const RXData: ContestExchange): string;
var
   ctx: TCanonicalExchangeContext;
begin
   (* THE SESSION'S VALUES, HANDED IN -- the contest reads no global. The
      template is CQ EXCHANGE CW as it stands; the RTC builds from MY GRID
      instead, with no RST (its HamScore organizer, 2026-05). *)
   ctx.CQExchangeTemplate := string(Settings.Messages.CqExchangeCw);
   ctx.MyGrid := Settings.My.Grid;
   Result := ContestIdentity(RXData.ceContest).CanonicalSentExchange(RXData, ctx);
end;

function BuildRxExchangeText(const RXData: ContestExchange): string;
begin
   (* COLLAPSED HERE, FOR EVERY CONTEST, as the `case` collapsed every arm
      and its `else`. *)
   Result := CollapseWhitespace(
                ContestIdentity(RXData.ceContest).CanonicalReceivedExchange(RXData));
end;

end.
