{
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
}
unit uTestComputerID;
{$I ..\..\src\tr4w.inc}

(*
  THE MULTI-OP STATION-ID RULE.

  Two failure directions, and BOTH are silent in a contest:

    accepting a duplicate    two stations collapse into one StatusArray row on
                             every client, and each starts claiming some of the
                             other's QSOs -- which is the defect this rule was
                             added to stop;

    refusing a legitimate    a station that drops and reconnects re-announces
                             the id it already had.  Refuse that and the
                             operator is locked out of his own network by the
                             fix.

  So the whole 1..26 range is walked rather than a couple of examples poked at.
*)

interface

uses
   uTR4WTestFramework;

type
   TComputerIDTests = class(TTestCase)
   protected
      procedure TestFreeIDIsAccepted;
      procedure TestTakenIDIsRefused;
      procedure TestReannouncingOwnIDIsAccepted;
      procedure TestZeroIsOutOfRange;
      procedure TestPastZIsOutOfRange;
      procedure TestEveryIDInRangeIsJudgedWhenFree;
      procedure TestEveryIDInRangeIsRefusedWhenTaken;
      procedure TestFullNetworkRefusesEveryone;
      procedure TestLetterRoundTrip;
      procedure TestLetterOfAnIllegalIDIsAQuestionMark;
      procedure TestOrdinalOfANonLetterIsZero;
      procedure TestTheSameAddressIsTheSameStation;
      procedure TestADifferentOrEmptyAddressIsAnotherStation;
      procedure TestASecondTakeoverInsideTheWindowIsAFlap;
      procedure TestADifferentVersionHostOrContestIsAnotherStation;
      procedure TestAnOwnLetterOrOutOfRangeNeverReachesTheTakeover;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   SysUtils,
   uComputerID;

{ 'A' is ordinal 1 -- the conversion the client does before sending. }
function Ord1(const aLetter: AnsiChar): AnsiChar;
begin
   Result := ComputerIDOrdinal(aLetter);
end;

procedure TComputerIDTests.TestFreeIDIsAccepted;
begin
   CheckEquals(Ord(cidAccept), Ord(JudgeComputerID(Ord1('C'), [1, 2])),
               'C is free when only A and B are taken');
end;

procedure TComputerIDTests.TestTakenIDIsRefused;
begin
   CheckEquals(Ord(cidInUse), Ord(JudgeComputerID(Ord1('B'), [1, 2])),
               'B is taken');
end;

procedure TComputerIDTests.TestReannouncingOwnIDIsAccepted;
begin
   { THE RECONNECT CASE, and the reason the caller must exclude the asking
     station from the set it passes.  A station that drops and comes back
     announces the same letter; if the server counted the station's own stale
     slot as "taken", the fix would lock the operator out of his own network. }
   CheckEquals(Ord(cidAccept), Ord(JudgeComputerID(Ord1('A'), [2, 3])),
               'A reconnecting, with its own slot excluded from the taken set');
end;

procedure TComputerIDTests.TestZeroIsOutOfRange;
begin
   { #0 is what clID holds for a client that connected and never announced --
     so it is reachable, not theoretical. }
   CheckEquals(Ord(cidOutOfRange), Ord(JudgeComputerID(#0, [])),
               'ordinal 0 is not a station');
end;

procedure TComputerIDTests.TestPastZIsOutOfRange;
begin
   CheckEquals(Ord(cidOutOfRange), Ord(JudgeComputerID(AnsiChar(27), [])),
               'ordinal 27 would index StatusArray past its end');
   CheckEquals(Ord(cidOutOfRange), Ord(JudgeComputerID(AnsiChar(255), [])),
               'ordinal 255 likewise');
end;

procedure TComputerIDTests.TestEveryIDInRangeIsJudgedWhenFree;
var
   i: integer;
begin
   for i := FIRST_COMPUTER_ID to LAST_COMPUTER_ID do
      begin
      CheckEquals(Ord(cidAccept), Ord(JudgeComputerID(AnsiChar(i), [])),
                  Format('id %d must be free on an empty network', [i]));
      end;
end;

procedure TComputerIDTests.TestEveryIDInRangeIsRefusedWhenTaken;
var
   i: integer;
begin
   for i := FIRST_COMPUTER_ID to LAST_COMPUTER_ID do
      begin
      CheckEquals(Ord(cidInUse), Ord(JudgeComputerID(AnsiChar(i), [i])),
                  Format('id %d must be refused when it is the one taken', [i]));
      end;
end;

procedure TComputerIDTests.TestFullNetworkRefusesEveryone;
var
   all: TComputerIDSet;
   i  : integer;
begin
   all := [];
   for i := FIRST_COMPUTER_ID to LAST_COMPUTER_ID do
      begin
      Include(all, i);
      end;

   for i := FIRST_COMPUTER_ID to LAST_COMPUTER_ID do
      begin
      CheckEquals(Ord(cidInUse), Ord(JudgeComputerID(AnsiChar(i), all)),
                  Format('id %d on a full 26-station network', [i]));
      end;
end;

procedure TComputerIDTests.TestLetterRoundTrip;
var
   c: AnsiChar;
begin
   { THE TWO ENCODINGS ARE INVERSES, which is the whole reason both live in one
     unit: NET_COMPUTERID_ID carries the ordinal and NET_STATIONSTATUS_ID
     carries the letter, and getting one of them backwards would misattribute
     every QSO on the network without failing anything. }
   for c := 'A' to 'Z' do
      begin
      CheckEquals(string(c), string(ComputerIDLetter(ComputerIDOrdinal(c))),
                  'letter -> ordinal -> letter');
      end;
end;

procedure TComputerIDTests.TestLetterOfAnIllegalIDIsAQuestionMark;
begin
   CheckEquals('?', string(ComputerIDLetter(#0)), 'ordinal 0 has no letter');
   CheckEquals('?', string(ComputerIDLetter(AnsiChar(27))), 'ordinal 27 has no letter');
end;

(* THE TAKEOVER RULE, mirroring TestComputerIdTakeover in TR4WServerPy's
  tests/test_server.py. The server unit itself cannot be linked into this
  exe, so the decision (the two functions it calls) is what is pinned here. *)

procedure TComputerIDTests.TestTheSameAddressIsTheSameStation;
begin
   CheckTrue(IsSameStation('10.0.0.5', '10.0.0.5', 'x', 'x', '5.0.99', '5.0.99',
                           'ARRL-FD', 'ARRL-FD'),
             'everything equal');
   CheckTrue(IsSameStation('10.0.0.5', '10.0.0.5', '?', '?', '5.0.99', '5.0.99', '', ''),
             'a holder with no contest yet does not count against it');
   CheckTrue(IsSameStation('10.0.0.5', '10.0.0.5', 'x', 'x', '', '', '', ''),
             'the legacy COMPUTERID path carries no version or contest');
   CheckEquals(Ord(tvTakeOver), Ord(JudgeTakeover(True, 0, 1000)),
               'the first takeover of a letter goes ahead');
end;

procedure TComputerIDTests.TestADifferentOrEmptyAddressIsAnotherStation;
begin
   CheckFalse(IsSameStation('10.0.0.6', '10.0.0.5', 'x', 'x', '5.0.99', '5.0.99', '', ''),
              'a different address');
   CheckFalse(IsSameStation('', '', 'x', 'x', '5.0.99', '5.0.99', '', ''),
              'an empty address is never the same');
   CheckEquals(Ord(tvNotSameStation), Ord(JudgeTakeover(False, 0, 1000)),
               'refused as before');
end;

procedure TComputerIDTests.TestASecondTakeoverInsideTheWindowIsAFlap;
begin
   CheckEquals(30000, ID_TAKEOVER_FLAP_WINDOW_MS, 'the same 30 seconds as the Python server');
   CheckEquals(Ord(tvFlap), Ord(JudgeTakeover(True, 100000, 100000 + 29999)),
               'just inside the window');
   CheckEquals(Ord(tvTakeOver), Ord(JudgeTakeover(True, 100000, 100000 + 30000)),
               'at the window it is accepted again');
   CheckEquals(Ord(tvTakeOver), Ord(JudgeTakeover(True, 100000, 100000 + 31000)),
               'after the window it is accepted');
   CheckEquals(Ord(tvNotSameStation), Ord(JudgeTakeover(False, 100000, 100001)),
               'another station is refused whatever the clock says');
end;

procedure TComputerIDTests.TestADifferentVersionHostOrContestIsAnotherStation;
begin
   CheckFalse(IsSameStation('10.0.0.5', '10.0.0.5', 'x', 'x', '5.0.98', '5.0.99',
                            'ARRL-FD', 'ARRL-FD'), 'another version');
   CheckFalse(IsSameStation('10.0.0.5', '10.0.0.5', 'other', 'x', '5.0.99', '5.0.99',
                            'ARRL-FD', 'ARRL-FD'), 'another host name');
   CheckFalse(IsSameStation('10.0.0.5', '10.0.0.5', 'x', 'x', '5.0.99', '5.0.99',
                            'CQ-WW-CW', 'ARRL-FD'), 'another contest');
end;

procedure TComputerIDTests.TestAnOwnLetterOrOutOfRangeNeverReachesTheTakeover;
begin
   (* The takeover is asked only for cidInUse, and the verdict excludes the
     asking station's own letter and checks the range first. *)
   CheckEquals(Ord(cidAccept), Ord(JudgeComputerID(Ord1('A'), [])),
               'a station re-announcing its own letter: nothing else holds it');
   CheckEquals(Ord(cidOutOfRange), Ord(JudgeComputerID(AnsiChar(27), [1])),
               'an id out of range is refused before anything else');
end;

procedure TComputerIDTests.RunAllTests;
begin
   TestTheSameAddressIsTheSameStation;
   TestADifferentOrEmptyAddressIsAnotherStation;
   TestASecondTakeoverInsideTheWindowIsAFlap;
   TestADifferentVersionHostOrContestIsAnotherStation;
   TestAnOwnLetterOrOutOfRangeNeverReachesTheTakeover;
   TestFreeIDIsAccepted;
   TestTakenIDIsRefused;
   TestReannouncingOwnIDIsAccepted;
   TestZeroIsOutOfRange;
   TestPastZIsOutOfRange;
   TestEveryIDInRangeIsJudgedWhenFree;
   TestEveryIDInRangeIsRefusedWhenTaken;
   TestFullNetworkRefusesEveryone;
   TestLetterRoundTrip;
   TestLetterOfAnIllegalIDIsAQuestionMark;
   TestOrdinalOfANonLetterIsZero;
end;

procedure TComputerIDTests.TestOrdinalOfANonLetterIsZero;
begin
   { Lower case is NOT accepted: COMPUTER ID is a ctAlphaChar setting and the
     rest of the protocol assumes upper case.  Returning 0 makes it fail as
     out-of-range rather than aliasing onto some other station. }
   CheckEquals(0, Ord(ComputerIDOrdinal('a')), 'lower case is not an id');
   CheckEquals(0, Ord(ComputerIDOrdinal('1')), 'a digit is not an id');
   CheckEquals(0, Ord(ComputerIDOrdinal(#0)), 'nul is not an id');
end;

end.
