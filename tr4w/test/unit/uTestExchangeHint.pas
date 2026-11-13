unit uTestExchangeHint;
{$I ..\..\src\tr4w.inc}

(*
  ISSUE 296: THE RECEIVED EXCHANGE, IN WORDS.

  uExchangeHint.ExchangeHintText turns the field list a contest marks into a
  phrase -- "serial number and name" for the CW Open -- and
  ContestExchangeHint asks a contest for it. Pinned here:

  - one field is its phrase; two are joined by "and"; more take commas
    before the "and";
  - no field, a field with no phrase of its own (Kids), no contest, and a
    contest that accepts a blank exchange all give NO words, never partial
    or wrong ones;
  - the zone slot reads "license year" / "years licensed" for a contest that
    keeps a received year there (issue 298);
  - real classes answer through the same call: CW Open, General QSO and the
    European HF Championship.

  NOT pinned here: where the words are shown. That is NY4I's choice after a
  trial on screen (issue 296), and no window shows them yet.
*)

interface

uses
   uTR4WTestFramework;

type
   TExchangeHintTests = class(TTestCase)
   protected
      procedure Test_OneFieldIsItsPhrase;
      procedure Test_TwoFieldsAreJoinedByAnd;
      procedure Test_MoreFieldsTakeCommasBeforeTheAnd;
      procedure Test_NoWordsRatherThanWrongWords;
      procedure Test_TheZoneSlotCanHoldAYear;
      procedure Test_TheContestAnswersThroughItsClass;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   VC,                   (* ExchangeInformationRecord, CWOPEN, GENERALQSO *)
   uExchangeFields,      (* ExchangeFieldsNone and the named field sets *)
   uContestBase,         (* TContestBase *)
   uExchangeHint,        (* ExchangeHintText, ContestExchangeHint *)
   uTestContestObjects;  (* MakeContestOrNil, NoStation *)

procedure TExchangeHintTests.Test_OneFieldIsItsPhrase;
begin
   BeginTest('Test_OneFieldIsItsPhrase');
   CheckEquals('serial number',
               ExchangeHintText(ExchangeFieldsQSONumber, rykNone),
               'a serial number alone');
   CheckEquals('QTH',
               ExchangeHintText(ExchangeFieldsQTH, rykNone),
               'a QTH alone');
end;

procedure TExchangeHintTests.Test_TwoFieldsAreJoinedByAnd;
begin
   BeginTest('Test_TwoFieldsAreJoinedByAnd');
   CheckEquals('serial number and name',
               ExchangeHintText(ExchangeFieldsQSONumberName, rykNone),
               'NY4I''s example, the CW Open''s field list');
end;

procedure TExchangeHintTests.Test_MoreFieldsTakeCommasBeforeTheAnd;
begin
   BeginTest('Test_MoreFieldsTakeCommasBeforeTheAnd');
   CheckEquals('signal report, serial number and zone',
               ExchangeHintText(ExchangeFieldsRSTQSONumberZone, rykNone),
               'three fields');
   CheckEquals('serial number, precedence, check and QTH',
               ExchangeHintText(ExchangeFieldsQSONumberPrecedenceCheckQTH, rykNone),
               'the Sweepstakes list, in the fixed order');
end;

procedure TExchangeHintTests.Test_NoWordsRatherThanWrongWords;
var
   kidsAndName: ExchangeInformationRecord;
begin
   BeginTest('Test_NoWordsRatherThanWrongWords');
   CheckEquals('', ExchangeHintText(ExchangeFieldsNone, rykNone),
               'no field: no words');
   CheckEquals('', ExchangeHintText(ExchangeFieldsKids, rykNone),
               'Kids has no phrase of its own: no words');
   kidsAndName := ExchangeFieldsKids;
   kidsAndName.Name := True;
   CheckEquals('', ExchangeHintText(kidsAndName, rykNone),
               'one field without a phrase silences the whole hint, not part of it');
   CheckEquals('', ContestExchangeHint(nil), 'no contest: no words');
end;

procedure TExchangeHintTests.Test_TheZoneSlotCanHoldAYear;
begin
   BeginTest('Test_TheZoneSlotCanHoldAYear');
   CheckEquals('signal report and zone',
               ExchangeHintText(ExchangeFieldsRSTZone, rykNone),
               'a zone is a zone');
   CheckEquals('signal report and license year',
               ExchangeHintText(ExchangeFieldsRSTZone, rykTwoDigitYear),
               'a two-digit year in the zone slot');
   CheckEquals('signal report and license year',
               ExchangeHintText(ExchangeFieldsRSTZone, rykFourDigitYear),
               'a four-digit year in the zone slot');
   CheckEquals('signal report and years licensed',
               ExchangeHintText(ExchangeFieldsRSTZone, rykYearsLicensed),
               'years licensed in the zone slot');
end;

procedure TExchangeHintTests.Test_TheContestAnswersThroughItsClass;

   function HintOf(aContest: ContestType): string;
   var
      obj: TContestBase;
   begin
      obj := MakeContestOrNil(aContest, NoStation);
      try
         CheckTrue(obj <> nil, 'the contest has a class');
         Result := ContestExchangeHint(obj);
      finally
         obj.Free;
      end;
   end;

var
   euhfc: string;
begin
   BeginTest('Test_TheContestAnswersThroughItsClass');
   (* Where NY4I met the empty field, 2026-11-11. *)
   CheckEquals('serial number and name', HintOf(CWOPEN),
               'CW Open');
   CheckEquals('', HintOf(GENERALQSO),
               'General QSO accepts a blank exchange: no words');
   euhfc := HintOf(EUROPEANHFC);
   CheckTrue(Pos('license year', euhfc) > 0,
             'European HF Championship names the year: "' + euhfc + '"');
   CheckTrue(Pos('zone', euhfc) = 0,
             'European HF Championship does not call the year a zone: "' + euhfc + '"');
end;

procedure TExchangeHintTests.RunAllTests;
begin
   Test_OneFieldIsItsPhrase;
   Test_TwoFieldsAreJoinedByAnd;
   Test_MoreFieldsTakeCommasBeforeTheAnd;
   Test_NoWordsRatherThanWrongWords;
   Test_TheZoneSlotCanHoldAYear;
   Test_TheContestAnswersThroughItsClass;
end;

end.
