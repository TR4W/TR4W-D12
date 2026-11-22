unit uTestSentExchangeDisplay;

(* THE EXCHANGE THE OPERATOR IS ABOUT TO SEND -- issue 355.

  - The leaf (uSentExchangeDisplay): the squeeze of an exported string, the
    Sweepstakes line, and whether the label shows.
  - The contest class (TContestBase.SentExchangeDisplayText): the default is
    the contest's own ADIF STX_STRING getter, squeezed, so the display and
    the export are one statement; Sweepstakes states the on-air order with
    the call; a contest with no sent layout answers '' and logs nothing.

  Every expected string is derived from the getter's Format spec, quoted
  beside each check. *)

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TSentExchangeDisplayTests = class(TTestCase)
   protected
      procedure Test_TheSqueezeTrimsAndCollapsesBlanks;
      procedure Test_TheSweepstakesLineIsNumberPrecCallCheckSection;
      procedure Test_AnUnsetSweepstakesPartIsLeftOut;
      procedure Test_TheLabelShowsOnlyWithText;
      procedure Test_SweepstakesClassStatesTheOnAirLine;
      procedure Test_RSTAndSerialComesFromTheExportGetter;
      procedure Test_RSTAndZoneComesFromTheExportGetter;
      procedure Test_RSTAndStateComesFromTheExportGetter;
      procedure Test_AContestWithNoSentLayoutShowsNothing;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   VC,
   uContestBase,
   uContestRegistry,
   uSentExchangeDisplay;

(* A probe for the next contact: serial, RST, CW on 20 m. *)
function Probe(const aSerial, aRST: integer): ContestExchange;
begin
   Result := Default(ContestExchange);
   Result.NumberSent := aSerial;
   Result.RSTSent := aRST;
   Result.Mode := CW;
   Result.Band := Band20;
end;

function Station: TMyStationExchange;
begin
   Result := Default(TMyStationExchange);
   Result.MyPrec := 'U';
   Result.MyCheck := '99';
   Result.MySection := 'CT';
   Result.MyZone := '5';
   Result.MyState := 'SP';
end;

procedure TSentExchangeDisplayTests.Test_TheSqueezeTrimsAndCollapsesBlanks;
begin
   BeginTest('Test_TheSqueezeTrimsAndCollapsesBlanks');
   CheckEquals('599 05', SqueezedExchangeText('599 05     '), 'trailing column padding goes');
   CheckEquals('123 U 99 CT', SqueezedExchangeText('  123  U 99 CT  '), 'runs become one space');
   CheckEquals('599 SP', SqueezedExchangeText('599'#9'SP'), 'a tab is a blank');
   CheckEquals('', SqueezedExchangeText('    '), 'blanks only is nothing');
   CheckEquals('', SqueezedExchangeText(''), 'nothing stays nothing');
end;

procedure TSentExchangeDisplayTests.Test_TheSweepstakesLineIsNumberPrecCallCheckSection;
begin
   BeginTest('Test_TheSweepstakesLineIsNumberPrecCallCheckSection');
   CheckEquals('#123 U K1ABC 99 CT', SweepstakesSentDisplayText(123, 'U', 'K1ABC', '99', 'CT'),
               'NY4I''s order: number, precedence, call, check, section');
   CheckEquals('#1 A NY4I 72 WCF', SweepstakesSentDisplayText(1, 'A', 'NY4I', '72', 'WCF'),
               'the first contact');
end;

procedure TSentExchangeDisplayTests.Test_AnUnsetSweepstakesPartIsLeftOut;
begin
   BeginTest('Test_AnUnsetSweepstakesPartIsLeftOut');
   CheckEquals('#123 K1ABC 99 CT', SweepstakesSentDisplayText(123, '', 'K1ABC', '99', 'CT'),
               'no precedence: no gap');
   CheckEquals('U K1ABC 99 CT', SweepstakesSentDisplayText(0, 'U', 'K1ABC', '99', 'CT'),
               'serial 0 is not a number the program sends');
   CheckEquals('', SweepstakesSentDisplayText(0, '', '', '', ''), 'nothing set: nothing');
end;

procedure TSentExchangeDisplayTests.Test_TheLabelShowsOnlyWithText;
begin
   BeginTest('Test_TheLabelShowsOnlyWithText');
   CheckTrue(SentExchangeShown('599 05'), 'a text shows');
   CheckFalse(SentExchangeShown(''), 'no text hides');
   CheckFalse(SentExchangeShown('   '), 'blanks hide');
end;

procedure TSentExchangeDisplayTests.Test_SweepstakesClassStatesTheOnAirLine;
begin
   BeginTest('Test_SweepstakesClassStatesTheOnAirLine');
   (* The ADIF STX_STRING is '%-4d %s %s %-3s ' -- no call; the display puts
      MY CALL between precedence and check. *)
   CheckEquals('#123 U K1ABC 99 CT',
               ContestIdentity(ARRLSSCW).SentExchangeDisplayText('K1ABC', Station, Probe(123, 599)),
               'Sweepstakes CW');
end;

procedure TSentExchangeDisplayTests.Test_RSTAndSerialComesFromTheExportGetter;
begin
   BeginTest('Test_RSTAndSerialComesFromTheExportGetter');
   (* CQ WPX: '%-3d %03d ' -- '599 123 ' squeezed. *)
   CheckEquals('599 123',
               ContestIdentity(CQWPXCW).SentExchangeDisplayText('K1ABC', Station, Probe(123, 599)),
               'CQ WPX CW: RST and serial');
end;

procedure TSentExchangeDisplayTests.Test_RSTAndZoneComesFromTheExportGetter;
begin
   BeginTest('Test_RSTAndZoneComesFromTheExportGetter');
   (* CQ WW: '%-3d %-7.2d' over zone 5 -- '599 05     ' squeezed. *)
   CheckEquals('599 05',
               ContestIdentity(CQWWCW).SentExchangeDisplayText('K1ABC', Station, Probe(123, 599)),
               'CQ WW CW: RST and zone');
end;

procedure TSentExchangeDisplayTests.Test_RSTAndStateComesFromTheExportGetter;
begin
   BeginTest('Test_RSTAndStateComesFromTheExportGetter');
   (* CQMM: ADIFSentRSTState, '%-3d %-7s' -- '599 SP     ' squeezed. *)
   CheckEquals('599 SP',
               ContestIdentity(CQMM).SentExchangeDisplayText('K1ABC', Station, Probe(123, 599)),
               'CQMM: RST and state');
end;

procedure TSentExchangeDisplayTests.Test_AContestWithNoSentLayoutShowsNothing;
begin
   BeginTest('Test_AContestWithNoSentLayoutShowsNothing');
   (* ARCI's getter is ADIFSentNotImplemented, which raises; the display
      answers '' and the label hides. *)
   CheckEquals('',
               ContestIdentity(ARCI).SentExchangeDisplayText('K1ABC', Station, Probe(123, 599)),
               'ARCI: no layout, no line');
end;

procedure TSentExchangeDisplayTests.RunAllTests;
begin
   Test_TheSqueezeTrimsAndCollapsesBlanks;
   Test_TheSweepstakesLineIsNumberPrecCallCheckSection;
   Test_AnUnsetSweepstakesPartIsLeftOut;
   Test_TheLabelShowsOnlyWithText;
   Test_SweepstakesClassStatesTheOnAirLine;
   Test_RSTAndSerialComesFromTheExportGetter;
   Test_RSTAndZoneComesFromTheExportGetter;
   Test_RSTAndStateComesFromTheExportGetter;
   Test_AContestWithNoSentLayoutShowsNothing;
end;

end.
