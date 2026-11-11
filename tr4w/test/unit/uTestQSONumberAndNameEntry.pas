unit uTestQSONumberAndNameEntry;
{$I ..\..\src\tr4w.inc}

(* A SERIAL-AND-NAME EXCHANGE NAMES EVERY REFUSAL -- 2026-11-11.

   CW Open (and the other contests whose format is
   LOGSTUFF.ProcessQSONumberAndNameExchange) receives a serial and a name. The
   parser refused a name typed alone, a serial typed alone and an empty entry
   with no ExchangeErrorMessage, and MainUnit.ParametersOkay shows an error
   only when that message is set -- so Enter appeared to do nothing.

   Pinned here: serial only -> SExchangeNoNameFound; name only ->
   TC_NOQSONUMBERFOUND; nothing -> TC_NOTENOUGHINFOINEXCHANGE; a serial too
   large for the number -> TC_NOQSONUMBERFOUND; a good entry, either order,
   accepted with no message. And one row through the real engine
   (ProcessExchange under CW Open), so the message is seen to survive the
   tokenising gate and the contest's dispatch on the Enter path. *)

interface

uses
   uTR4WTestFramework,
   VC;

type
   TQSONumberAndNameEntryTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      function NameEntry(const aText: string; out aRX: ContestExchange): boolean;
      procedure Refused(const aText: string; const aMessage: string);
      procedure Test_EveryRefusalNamesItsReason;
      procedure Test_AGoodEntryIsAcceptedWithNoMessage;
      procedure Test_CWOpenShowsTheReasonThroughTheEngine;
   end;

implementation

uses
   SysUtils,
   uTR4WStrings,
   uAppStrings,
   uContestBase,
   uContestFactory,
   uContestRegistry,
   LogWind,
   (* Contest -- the active contest's handle. *)
   PostUnit,
   LOGSTUFF;

function TQSONumberAndNameEntryTests.NameEntry(const aText: string;
   out aRX: ContestExchange): boolean;
begin
   aRX := Default(ContestExchange);
   ExchangeErrorMessage := '';
   ExchangeErrorToken := '';
   Result := ProcessQSONumberAndNameExchange(ShortString(aText), aRX);
end;

procedure TQSONumberAndNameEntryTests.Refused(const aText: string; const aMessage: string);
var
   rx: ContestExchange;
   ok: boolean;
   what: string;
begin
   what := '"' + aText + '"';
   ok := NameEntry(aText, rx);
   CheckFalse(ok, what + ' is refused');
   CheckEquals(aMessage, ExchangeErrorMessage, what + ' message');
   CheckEquals('', string(ExchangeErrorToken), what + ' names no token');
end;

procedure TQSONumberAndNameEntryTests.Test_EveryRefusalNamesItsReason;
begin
   BeginTest('Test_EveryRefusalNamesItsReason');
   try
      Refused('123', SExchangeNoNameFound);
      Refused('123 456', SExchangeNoNameFound);
      Refused('TOM', string(TC_NOQSONUMBERFOUND));
      Refused('TOM DICK', string(TC_NOQSONUMBERFOUND));
      Refused('', string(TC_NOTENOUGHINFOINEXCHANGE));
      Refused('99999999999 TOM', string(TC_NOQSONUMBERFOUND));
   finally
      ExchangeErrorMessage := '';
      end;
end;

procedure TQSONumberAndNameEntryTests.Test_AGoodEntryIsAcceptedWithNoMessage;
var
   rx: ContestExchange;
   ok: boolean;
begin
   BeginTest('Test_AGoodEntryIsAcceptedWithNoMessage');
   try
      ok := NameEntry('123 TOM', rx);
      CheckTrue(ok, '"123 TOM" is accepted: ' + ExchangeErrorMessage);
      CheckEquals('', ExchangeErrorMessage, '"123 TOM" no message');
      CheckEquals('TOM', string(rx.Name), '"123 TOM" name');
      CheckEquals(123, Integer(rx.NumberReceived), '"123 TOM" serial');

      ok := NameEntry('TOM 45', rx);
      CheckTrue(ok, '"TOM 45" is accepted: ' + ExchangeErrorMessage);
      CheckEquals('', ExchangeErrorMessage, '"TOM 45" no message');
      CheckEquals('TOM', string(rx.Name), '"TOM 45" name');
      CheckEquals(45, Integer(rx.NumberReceived), '"TOM 45" serial');
   finally
      ExchangeErrorMessage := '';
      end;
end;

(* THE ENTER PATH: ProcessExchange, the contest's ParseReceivedExchange, the
   engine's parsers -- under CW Open. *)
procedure TQSONumberAndNameEntryTests.Test_CWOpenShowsTheReasonThroughTheEngine;
var
   rx: ContestExchange;
   ok: boolean;
   savedContest: TContestHandle;
   savedCallWindow: CallString;
begin
   BeginTest('Test_CWOpenShowsTheReasonThroughTheEngine');
   savedContest := Contest;
   savedCallWindow := CallWindowString;
   try
      CallWindowString := 'W1AW';
      Contest := ContestHandleOf(CWOPEN);
      ReleaseActiveContest;

      rx := Default(ContestExchange);
      ExchangeErrorMessage := '';
      ok := ProcessExchange('TOM', rx);
      CheckFalse(ok, 'CW Open: a name alone is refused');
      CheckEquals(string(TC_NOQSONUMBERFOUND), ExchangeErrorMessage,
                  'CW Open: a name alone says the serial is missing');

      rx := Default(ContestExchange);
      ExchangeErrorMessage := '';
      ok := ProcessExchange('123', rx);
      CheckFalse(ok, 'CW Open: a serial alone is refused');
      CheckEquals(SExchangeNoNameFound, ExchangeErrorMessage,
                  'CW Open: a serial alone says the name is missing');

      rx := Default(ContestExchange);
      ExchangeErrorMessage := '';
      ok := ProcessExchange('123 TOM', rx);
      CheckTrue(ok, 'CW Open: 123 TOM is accepted: ' + ExchangeErrorMessage);
      CheckEquals('', ExchangeErrorMessage, 'CW Open: 123 TOM no message');
      CheckEquals('TOM', string(rx.Name), 'CW Open: the name');
      CheckEquals(123, Integer(rx.NumberReceived), 'CW Open: the serial');
   finally
      Contest := savedContest;
      ReleaseActiveContest;
      CallWindowString := savedCallWindow;
      ExchangeErrorMessage := '';
      end;
end;

procedure TQSONumberAndNameEntryTests.RunAllTests;
begin
   Test_EveryRefusalNamesItsReason;
   Test_AGoodEntryIsAcceptedWithNoMessage;
   Test_CWOpenShowsTheReasonThroughTheEngine;
end;

end.
