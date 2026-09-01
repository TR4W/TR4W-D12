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

procedure TComputerIDTests.RunAllTests;
begin
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
