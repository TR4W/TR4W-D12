(*
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
 *)

(* THE FOUR IN7QPNE PARTIES STATE THEIR BANDS, AND THE COMPOSITE CREDITS
  THEIR UNION (NY4I, 2026-10-16: "you look at the 4 qso parties to see which
  bands are valid").

    New England   80, 40, 20, 15, 10 m -- no 160, no WARC, no VHF
    7QP           160-10 m, no WARC, no VHF (its VHF flag went with it)
    Indiana       160-10 m, no WARC
    Delaware      160-10 m, no WARC, and 6 m up (uTestContestDelawareQP)
    IN7QPNE       the union: 160-10 m without WARC, and 6 m up -- while a
                  QSO still scores only on its JUDGING party's bands

  Every band of BandType is checked both ways, literally, so a band added to
  the enum later is not credited by accident. *)
unit uTestQSOPartyBands;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, VC;

type
   TBandSet = set of BandType;

   TQSOPartyBandsTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      (* Every BandType, both ways: in aExpected is credited, else not. *)
      procedure CheckBands(aContest: ContestType; const aExpected: TBandSet;
                           const aWhat: string);
      procedure Test_NewEnglandCredits80To10;
      procedure Test_SevenQPCredits160To10;
      procedure Test_IndianaCredits160To10;
      procedure Test_IN7QPNECreditsTheUnion;
      procedure Test_IN7QPNEScoresOnTheJudgingPartysBands;
   end;

implementation

uses
   SysUtils, uContestBase, uContestIN7QPNE,
   uTestContestObjects;

const
   HF_NO_WARC: TBandSet = [Band160, Band80, Band40, Band20, Band15, Band10];
   SIX_METRES_UP: TBandSet = [Band6, Band2, Band222, Band432, Band902, Band1296,
                              Band2304, Band3456, Band5760, Band10G, Band24G,
                              BandLight];

procedure TQSOPartyBandsTests.CheckBands(aContest: ContestType;
                                         const aExpected: TBandSet;
                                         const aWhat: string);
var
   contestObject: TContestBase;
   b: BandType;
begin
   contestObject := Make(aContest);
   try
      for b := Low(BandType) to High(BandType) do
         begin
         CheckEquals(Ord(b in aExpected), Ord(ContestCreditsBand(contestObject, b)),
                     aWhat + ' band ' + IntToStr(Ord(b)));
         end;
   finally
      contestObject.Free;
   end;
end;

procedure TQSOPartyBandsTests.Test_NewEnglandCredits80To10;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_NewEnglandCredits80To10');
   CheckBands(NEWENGLANDQSO, [Band80, Band40, Band20, Band15, Band10], 'New England');
   contestObject := Make(NEWENGLANDQSO);
   try
      CheckFalse(contestObject.UsesBand(Band160), 'New England: no 160 m');
      CheckFalse(contestObject.UsesBand(Band30), 'New England: no 30 m');
      CheckFalse(contestObject.UsesBand(Band6), 'New England: no 6 m');
      CheckTrue(contestObject.UsesBand(Band80), 'New England: 80 m');
      CheckFalse(contestObject.VHFBandsEnabled, 'New England: no VHF flag');
   finally
      contestObject.Free;
   end;
end;

procedure TQSOPartyBandsTests.Test_SevenQPCredits160To10;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_SevenQPCredits160To10');
   CheckBands(SEVENQP, HF_NO_WARC, '7QP');
   contestObject := Make(SEVENQP);
   try
      CheckFalse(contestObject.UsesBand(Band6), '7QP: no 6 m');
      CheckFalse(contestObject.UsesBand(Band30), '7QP: no 30 m');
      CheckTrue(contestObject.UsesBand(Band160), '7QP: 160 m');
      CheckFalse(contestObject.VHFBandsEnabled, '7QP: the VHF flag went with the VHF bands');
   finally
      contestObject.Free;
   end;
end;

procedure TQSOPartyBandsTests.Test_IndianaCredits160To10;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_IndianaCredits160To10');
   CheckBands(INQSOPARTY, HF_NO_WARC, 'Indiana');
   contestObject := Make(INQSOPARTY);
   try
      CheckFalse(contestObject.UsesBand(Band30), 'Indiana: no 30 m');
      CheckFalse(contestObject.UsesBand(Band6), 'Indiana: no 6 m');
      CheckFalse(contestObject.VHFBandsEnabled, 'Indiana: no VHF flag');
   finally
      contestObject.Free;
   end;
end;

procedure TQSOPartyBandsTests.Test_IN7QPNECreditsTheUnion;
var
   contestObject: TContestBase;
begin
   BeginTest('Test_IN7QPNECreditsTheUnion');
   CheckBands(IN7QPNE, HF_NO_WARC + SIX_METRES_UP, 'IN7QPNE');
   contestObject := Make(IN7QPNE);
   try
      CheckFalse(contestObject.UsesBand(Band30), 'IN7QPNE: no 30 m');
      CheckTrue(contestObject.UsesBand(Band6), 'IN7QPNE: 6 m, for Delaware');
      CheckTrue(contestObject.VHFBandsEnabled, 'IN7QPNE: VHF on, for Delaware');
   finally
      contestObject.Free;
   end;
end;

(* THE UNION ADMITS THE BAND; THE JUDGING PARTY SCORES IT. A New England
   county on 160 m is 0 (New England does not use 160), an Indiana county on
   160 m is not; Delaware's 6 m scores, a 7QP county's 6 m does not. *)
procedure TQSOPartyBandsTests.Test_IN7QPNEScoresOnTheJudgingPartysBands;

   function ScoreAt(const aQTH: string; aBand: BandType): integer;
   var
      contestObject: TContestBase;
      station: TStationContext;
      qso: ContestExchange;
   begin
      (* A county of a party, so the host-area rule (Q107) credits it: the
         table knows it, and the record carries it as typed too. *)
      station := WithHostAreaTable(NoStation);
      station.MyState := 'KS';
      contestObject := Make(IN7QPNE, station);
      try
         FillChar(qso, SizeOf(qso), 0);
         qso.Band := aBand;
         qso.Mode := CW;
         qso.QTHString := ShortString(aQTH);
         qso.DomesticQTH := ShortString(aQTH);
         contestObject.ScoreQSO(qso);
         Result := qso.QSOPoints;
      finally
         contestObject.Free;
      end;
   end;

var
   party: TIN7QPNEParty;
begin
   BeginTest('Test_IN7QPNEScoresOnTheJudgingPartysBands');
   CheckTrue(IN7QPNEPartyOfQTH('MEAnd', party), 'MEAnd routes');
   CheckTrue(party = ipNewEngland, 'to New England');
   CheckEquals(0, ScoreAt('MEAnd', Band160), 'New England on 160 m: 0');
   CheckTrue(ScoreAt('MEAnd', Band80) > 0, 'New England on 80 m scores');
   CheckTrue(ScoreAt('INADA', Band160) > 0, 'Indiana on 160 m scores');
   CheckTrue(ScoreAt('NDE', Band6) > 0, 'Delaware on 6 m scores');
   CheckEquals(0, ScoreAt('Azaph', Band6), '7QP on 6 m: 0');
   CheckEquals(0, ScoreAt('NDE', Band30), 'nobody on 30 m');
end;

procedure TQSOPartyBandsTests.RunAllTests;
begin
   Test_NewEnglandCredits80To10;
   Test_SevenQPCredits160To10;
   Test_IndianaCredits160To10;
   Test_IN7QPNECreditsTheUnion;
   Test_IN7QPNEScoresOnTheJudgingPartysBands;
end;

end.
