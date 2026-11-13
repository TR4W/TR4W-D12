unit uTestEmptyExchangeNotice;
{$I ..\..\src\tr4w.inc}

(*
  ISSUE 292: ENTER IN CQ MODE ON AN EMPTY EXCHANGE SAYS WHY NOTHING WAS LOGGED.

  ParametersOkay refuses an empty exchange silently, and must go on doing so:
  the first Enter of a QSO, and LOG WITH SINGLE ENTER's logging attempt on that
  same Enter, reach it with an empty exchange as ordinary flow.  So the message
  is decided in ReturnInCQOpMode, by MainUnit.EmptyExchangeEnterNeedsNotice,
  and that rule is pinned here with plain calls:

  - only a SECOND Enter speaks: the call AND the exchange were both already
    sent when it arrived (the first Enter after CW auto-send has sent the call
    has sent no exchange yet, so it stays silent);
  - only an empty exchange speaks, and spaces are empty;
  - a contest that accepts a blank exchange never speaks.  Which contests do is
    pinned contest by contest in uTestExchangeRules; here one of each kind is
    asked through the real classes, so the rule and the contest answer are
    joined the way ReturnInCQOpMode joins them.

  NOT pinned here: that ReturnInCQOpMode calls it (a UI path with no harness),
  and search and pounce, which never reaches it (issue 292 leaves S&P open).
*)

interface

uses
   uTR4WTestFramework;

type
   TEmptyExchangeNoticeTests = class(TTestCase)
   protected
      procedure Test_OnlyASecondEnterSpeaks;
      procedure Test_OnlyAnEmptyExchangeSpeaks;
      procedure Test_AContestThatAcceptsBlankNeverSpeaks;
      procedure Test_TheContestAnswersThroughItsClass;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,                   (* CWOPEN, GENERALQSO *)
   MainUnit,             (* EmptyExchangeEnterNeedsNotice *)
   uContestBase,         (* ContestAcceptsBlankExchange *)
   uTestContestObjects;  (* MakeContestOrNil, NoStation *)

procedure TEmptyExchangeNoticeTests.Test_OnlyASecondEnterSpeaks;
begin
   BeginTest('Test_OnlyASecondEnterSpeaks');
   CheckTrue(EmptyExchangeEnterNeedsNotice(True, True, '', False),
             'call and exchange already sent: the second Enter is told');
   CheckFalse(EmptyExchangeEnterNeedsNotice(False, False, '', False),
              'the first Enter sends the call and stays silent');
   CheckFalse(EmptyExchangeEnterNeedsNotice(True, False, '', False),
              'call sent by CW auto-send, exchange not yet: silent');
   CheckFalse(EmptyExchangeEnterNeedsNotice(False, True, '', False),
              'an exchange flag without the call: silent');
end;

procedure TEmptyExchangeNoticeTests.Test_OnlyAnEmptyExchangeSpeaks;
begin
   BeginTest('Test_OnlyAnEmptyExchangeSpeaks');
   CheckTrue(EmptyExchangeEnterNeedsNotice(True, True, '   ', False),
             'spaces are an empty exchange');
   CheckFalse(EmptyExchangeEnterNeedsNotice(True, True, 'TOM', False),
              'a partial exchange is the parser''s to judge, not this rule''s');
   CheckFalse(EmptyExchangeEnterNeedsNotice(True, True, ' 5NN FL ', False),
              'a full exchange is not empty');
end;

procedure TEmptyExchangeNoticeTests.Test_AContestThatAcceptsBlankNeverSpeaks;
begin
   BeginTest('Test_AContestThatAcceptsBlankNeverSpeaks');
   CheckFalse(EmptyExchangeEnterNeedsNotice(True, True, '', True),
              'a blank exchange is a loggable one there');
end;

procedure TEmptyExchangeNoticeTests.Test_TheContestAnswersThroughItsClass;

   function SecondEnterSpeaksIn(aContest: ContestType): boolean;
   var
      obj: TContestBase;
   begin
      obj := MakeContestOrNil(aContest, NoStation);
      try
         CheckTrue(obj <> nil, 'the contest has a class');
         Result := EmptyExchangeEnterNeedsNotice(True, True, '',
                                                 ContestAcceptsBlankExchange(obj));
      finally
         obj.Free;
      end;
   end;

begin
   BeginTest('Test_TheContestAnswersThroughItsClass');
   (* CW Open is where NY4I met it, 2026-11-11. *)
   CheckTrue(SecondEnterSpeaksIn(CWOPEN),
             'CW Open: an empty exchange on the second Enter is reported');
   CheckFalse(SecondEnterSpeaksIn(GENERALQSO),
              'General QSO accepts a blank exchange: nothing is reported');
end;

procedure TEmptyExchangeNoticeTests.RunAllTests;
begin
   Test_OnlyASecondEnterSpeaks;
   Test_OnlyAnEmptyExchangeSpeaks;
   Test_AContestThatAcceptsBlankNeverSpeaks;
   Test_TheContestAnswersThroughItsClass;
end;

end.
