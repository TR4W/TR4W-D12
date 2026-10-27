(* NETWORK PROTOCOL 2: THE HELLO MESSAGE, ITS JUDGEMENTS AND ITS TABLE.

  uNetHello is sockets-free on purpose, so all of it is reachable here:

    - the record's LAYOUT, because it is the wire (70 bytes, little-endian,
      packed) and TR4WServerPy and tools/netprobe write the same bytes by hand;
    - building one, including the refusals: an id that does not fit is not
      truncated, because a truncated id names another contest;
    - the VERSION judgement, equal versions only, and which end is behind;
    - the per-station table (announce, forget, clear) and the one-notice-per-
      pair latch;
    - the per-station CONTEST judgement, which is the rule the QSO arms apply;
    - the framing: a HELLO is one whole message of its own size, however the
      stream is cut.

  What it cannot reach is the server (it needs Indy and a socket) and the
  uNet arms; those are uTestContestById's, and tools/netprobe's `hello` case
  speaks to both real servers. *)
unit uTestNetHello;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TTestNetHello = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_TheLayoutIsTheWire;
      procedure Test_BuildAndReadBack;
      procedure Test_AnIdThatDoesNotFitIsRefusedNotTruncated;
      procedure Test_OnlyPrintableAsciiIsSent;
      procedure Test_TheVersionJudgement;
      procedure Test_ThePeersTable;
      procedure Test_TheServersOwnHelloIsNotAStation;
      procedure Test_OneNoticePerStationAndContest;
      procedure Test_ThePeerContestJudgement;
      procedure Test_AHelloIsOneWholeMessageHoweverTheStreamIsCut;
      procedure Test_HelloHasItsOwnIdAndSize;
      procedure Test_EveryContestAndThisVersionFitTheHello;
   end;

implementation

uses
   SysUtils, VC, Version, uNetHello, uNetFraming, uComputerID,
   uContestRegistry, uTestRegisteredContests;

type
   (* The 70 bytes of a hello, as an array the tests can index. *)
   THelloWire = array[0..69] of Byte;

(* A hello as the bytes that go on the wire. A value typecast: the record is
  packed, so its bytes ARE the message. *)
procedure WireOf(const aHello: THelloMessage; out aBytes: THelloWire);
begin
   aBytes := THelloWire(aHello);
end;

procedure TTestNetHello.Test_TheLayoutIsTheWire;
var
   h: THelloMessage;
   wire: THelloWire;
   base: PtrUInt;
begin
   BeginTest('Test_TheLayoutIsTheWire');
   h := Default(THelloMessage);
   base := PtrUInt(@h);
   CheckEquals(70, SizeOf(THelloMessage), 'the record is 70 bytes');
   CheckEquals(0,  Integer(PtrUInt(@h.hmID) - base),           'id at 0');
   CheckEquals(2,  Integer(PtrUInt(@h.hmProtocol) - base),     'protocol at 2');
   CheckEquals(4,  Integer(PtrUInt(@h.hmComputerID) - base),   'computer id at 4');
   CheckEquals(5,  Integer(PtrUInt(@h.hmReserved) - base),     'reserved at 5');
   CheckEquals(6,  Integer(PtrUInt(@h.hmAppVersion) - base),   'program version at 6');
   CheckEquals(22, Integer(PtrUInt(@h.hmContestId) - base),    'contest id at 22');
   CheckEquals(16, HELLO_VERSION_CHARS, 'the version field is 16 characters');
   CheckEquals(48, HELLO_CONTEST_CHARS, 'the contest field is 48 characters');
   CheckEquals(2,  NET_PROTOCOL_VERSION, 'this build speaks protocol 2');
   CheckEquals(1150, NET_HELLO_ID, 'the id is 1150');

   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 5, 'ab', 'XY', h), 'built');
   WireOf(h, wire);
   CheckEquals($7E, wire[0], 'id low byte (1150 = $047E, little-endian)');
   CheckEquals($04, wire[1], 'id high byte');
   CheckEquals(2,   wire[2], 'protocol low byte');
   CheckEquals(0,   wire[3], 'protocol high byte');
   CheckEquals(5,   wire[4], 'computer id');
   CheckEquals(0,   wire[5], 'reserved');
   CheckEquals(Ord('a'), wire[6], 'version text starts at 6');
   CheckEquals(Ord('b'), wire[7], 'second character');
   CheckEquals(0,   wire[8], 'then NUL padding');
   CheckEquals(Ord('X'), wire[22], 'contest text starts at 22');
   CheckEquals(Ord('Y'), wire[23], 'second character');
   CheckEquals(0,   wire[24], 'then NUL padding');
   CheckEquals(0,   wire[69], 'to the last byte');
end;

procedure TTestNetHello.Test_BuildAndReadBack;
var
   h: THelloMessage;
begin
   BeginTest('Test_BuildAndReadBack');
   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 3, '5.0.35', 'ARRL-DX-CW', h), 'built');
   CheckEquals(NET_HELLO_ID, h.hmID, 'carries its own id');
   CheckEquals(NET_PROTOCOL_VERSION, h.hmProtocol, 'the protocol');
   CheckEquals(3, h.hmComputerID, 'the computer id');
   CheckEquals('5.0.35', HelloAppVersion(h), 'the program version reads back');
   CheckEquals('ARRL-DX-CW', HelloContestId(h), 'the contest id reads back');

   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 0, '1.41', '', h), 'the server''s: no contest');
   CheckEquals('', HelloContestId(h), 'an empty contest reads back empty');
   CheckEquals(0, h.hmComputerID, 'and computer id 0 is the server');
end;

procedure TTestNetHello.Test_AnIdThatDoesNotFitIsRefusedNotTruncated;
var
   h: THelloMessage;
   fits, tooLong: string;
begin
   BeginTest('Test_AnIdThatDoesNotFitIsRefusedNotTruncated');
   fits := StringOfChar('A', HELLO_CONTEST_CHARS);
   tooLong := fits + 'B';
   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 1, '5', fits, h),
             'an id of exactly the field''s width fits (no NUL needed)');
   CheckEquals(fits, HelloContestId(h), 'and reads back whole');

   CheckFalse(BuildHello(NET_PROTOCOL_VERSION, 1, '5', tooLong, h),
              'one character more is refused');
   CheckEquals(0, h.hmID, 'the refused record is zeroed, not half-built');
   CheckEquals('', HelloContestId(h), 'with no contest in it');

   CheckFalse(BuildHello(NET_PROTOCOL_VERSION, 1, StringOfChar('9', HELLO_VERSION_CHARS + 1),
                         'X', h), 'a program version too long is refused too');
end;

procedure TTestNetHello.Test_OnlyPrintableAsciiIsSent;
var
   h: THelloMessage;
begin
   BeginTest('Test_OnlyPrintableAsciiIsSent');
   CheckFalse(BuildHello(NET_PROTOCOL_VERSION, 1, '5', 'CONTEST' + #200, h),
              'a byte above 126 is refused');
   CheckFalse(BuildHello(NET_PROTOCOL_VERSION, 1, '5', 'CON' + #9 + 'TEST', h),
              'a control character is refused');
   CheckFalse(BuildHello(NET_PROTOCOL_VERSION, 1, '5', 'CONTEST' + #0, h),
              'and so is a NUL, which would end the text early');
   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 1, '5', 'A B~', h),
             'a blank and a tilde are printable');
end;

procedure TTestNetHello.Test_TheVersionJudgement;
begin
   BeginTest('Test_TheVersionJudgement');
   CheckTrue(JudgeProtocol(2, 2) = pvSame, 'equal versions may talk');
   CheckTrue(JudgeProtocol(2, 1) = pvTheirsOlder, 'a V1 peer is behind');
   CheckTrue(JudgeProtocol(2, 3) = pvTheirsNewer, 'a later one is ahead');
   CheckTrue(JudgeProtocol(2, 0) = pvTheirsOlder, 'zero is older than any version');
   CheckTrue(JudgeProtocol(1, 2) = pvTheirsNewer, 'and it is symmetric: from the other end');
   CheckTrue(JudgeProtocol(NET_PROTOCOL_VERSION, NET_PROTOCOL_VERSION) = pvSame,
             'this build talks to itself');
end;

procedure TTestNetHello.Test_ThePeersTable;
var
   peers: TNetPeers;
   h: THelloMessage;
begin
   BeginTest('Test_ThePeersTable');
   peers := TNetPeers.Create;
   try
      CheckFalse(peers.Knows(2), 'nobody is known to begin with');
      CheckEquals('', peers.ContestIdOf(2), 'with no contest');

      BuildHello(NET_PROTOCOL_VERSION, 2, '5.0.35', 'CQ-WW-CW', h);
      CheckTrue(peers.Announce(h), 'B announces');
      CheckTrue(peers.Knows(2), 'B is known');
      CheckEquals('CQ-WW-CW', peers.ContestIdOf(2), 'with its contest');
      CheckEquals('5.0.35', peers.AppVersionOf(2), 'its program version');
      CheckEquals(NET_PROTOCOL_VERSION, peers.ProtocolOf(2), 'and its protocol');
      CheckFalse(peers.Knows(3), 'C is still not known');

      BuildHello(NET_PROTOCOL_VERSION, 2, '5.0.36', 'ARRL-DX-CW', h);
      CheckTrue(peers.Announce(h), 'B announces again');
      CheckEquals('ARRL-DX-CW', peers.ContestIdOf(2), 'the latest announcement wins');
      CheckEquals('5.0.36', peers.AppVersionOf(2), 'including the version');

      BuildHello(NET_PROTOCOL_VERSION, 26, '5', 'X', h);
      CheckTrue(peers.Announce(h), 'station Z, the last, is in range');
      CheckTrue(peers.Knows(26), 'and known');

      peers.Forget(2);
      CheckFalse(peers.Knows(2), 'a station that left is forgotten');
      CheckEquals('', peers.ContestIdOf(2), 'with its contest');
      CheckTrue(peers.Knows(26), 'the others are not');

      peers.Forget(0);
      peers.Forget(27);
      peers.Forget(-5);
      CheckTrue(peers.Knows(26), 'forgetting an id outside 1..26 touches nothing');

      peers.Clear;
      CheckFalse(peers.Knows(26), 'a new link starts empty');
   finally
      peers.Free;
   end;
end;

procedure TTestNetHello.Test_TheServersOwnHelloIsNotAStation;
var
   peers: TNetPeers;
   h: THelloMessage;
   k: integer;
begin
   BeginTest('Test_TheServersOwnHelloIsNotAStation');
   peers := TNetPeers.Create;
   try
      BuildHello(NET_PROTOCOL_VERSION, 0, '1.41', '', h);
      CheckFalse(peers.Announce(h), 'computer id 0 is the server, not a row');
      BuildHello(NET_PROTOCOL_VERSION, 27, '5', 'X', h);
      CheckFalse(peers.Announce(h), '27 is out of range');
      BuildHello(NET_PROTOCOL_VERSION, 255, '5', 'X', h);
      CheckFalse(peers.Announce(h), 'and so is 255');
      for k := FIRST_COMPUTER_ID to LAST_COMPUTER_ID do
         begin
         CheckFalse(peers.Knows(k), 'nobody became known: ' + IntToStr(k));
         end;
   finally
      peers.Free;
   end;
end;

procedure TTestNetHello.Test_OneNoticePerStationAndContest;
var
   peers: TNetPeers;
begin
   BeginTest('Test_OneNoticePerStationAndContest');
   peers := TNetPeers.Create;
   try
      CheckTrue(peers.FirstNotice(2, 'CQ-WW-CW'), 'the first time is a notice');
      CheckFalse(peers.FirstNotice(2, 'CQ-WW-CW'), 'the second is not');
      CheckFalse(peers.FirstNotice(2, 'cq-ww-cw'), 'whatever the case');
      CheckTrue(peers.FirstNotice(3, 'CQ-WW-CW'), 'another station is its own');
      CheckTrue(peers.FirstNotice(2, 'CQ-WW-SSB'), 'and so is another contest');

      peers.ForgetNotices;
      CheckTrue(peers.FirstNotice(2, 'CQ-WW-CW'), 'a new link may notice again');

      peers.FirstNotice(4, 'X');
      peers.Clear;
      CheckTrue(peers.FirstNotice(4, 'X'), 'and Clear forgets the notices too');
   finally
      peers.Free;
   end;
end;

procedure TTestNetHello.Test_ThePeerContestJudgement;
var
   peers: TNetPeers;
   h: THelloMessage;
begin
   BeginTest('Test_ThePeerContestJudgement');
   peers := TNetPeers.Create;
   try
      CheckTrue(JudgePeerContest(peers, 2, 'ARRL-DX-CW') = pcNoHello,
                'a station that said nothing is not on our contest');

      BuildHello(NET_PROTOCOL_VERSION, 2, '5', 'ARRL-DX-CW', h);
      peers.Announce(h);
      CheckTrue(JudgePeerContest(peers, 2, 'ARRL-DX-CW') = pcSame, 'the same id');
      CheckTrue(JudgePeerContest(peers, 2, 'arrl-dx-cw') = pcSame, 'whatever the case');
      CheckTrue(JudgePeerContest(peers, 2, 'ARRL-DX-SSB') = pcOther, 'another id');
      CheckTrue(JudgePeerContest(peers, 2, '') = pcOther, 'against no contest of ours');
      CheckTrue(JudgePeerContest(peers, 3, 'ARRL-DX-CW') = pcNoHello,
                'and the next station is still silent');
      CheckTrue(JudgePeerContest(peers, 0, 'ARRL-DX-CW') = pcNoHello, 'sender 0 is nobody');
      CheckTrue(JudgePeerContest(peers, 99, 'ARRL-DX-CW') = pcNoHello, 'nor is 99');

      (* A station that announced an empty contest (a station with none chosen
        sends the id of "no contest", but a damaged one may send nothing at
        all): it matches only an empty id, never a real one. *)
      BuildHello(NET_PROTOCOL_VERSION, 4, '5', '', h);
      peers.Announce(h);
      CheckTrue(JudgePeerContest(peers, 4, 'ARRL-DX-CW') = pcOther, 'empty is not a contest');
   finally
      peers.Free;
   end;
end;

(* The HELLO inside a stream, cut at every byte: never a message before byte 70,
  and the 70th byte completes it. Followed by a server message to prove the next
  message begins exactly where the HELLO ends. *)
procedure TTestNetHello.Test_AHelloIsOneWholeMessageHoweverTheStreamIsCut;
var
   h: THelloMessage;
   stream: array of Byte;
   wire: THelloWire;
   walk: TNetWalkResult;
   bad: word;
   cut, i: integer;
   whole: integer;
begin
   BeginTest('Test_AHelloIsOneWholeMessageHoweverTheStreamIsCut');
   BuildHello(NET_PROTOCOL_VERSION, 2, '5.0.35', 'ARRL-DX-CW', h);
   WireOf(h, wire);

   SetLength(stream, SizeOf(THelloMessage) + SizeOf(TServerMessage));
   for i := 0 to High(wire) do
      begin
      stream[i] := wire[i];
      end;
   stream[SizeOf(THelloMessage)]     := Lo(Word(NET_SERVERMESSAGE_ID));
   stream[SizeOf(THelloMessage) + 1] := Hi(Word(NET_SERVERMESSAGE_ID));

   for cut := 2 to SizeOf(THelloMessage) - 1 do
      begin
      whole := NetWholeBytes(stream, cut, False, walk, bad);
      CheckEquals(0, whole, 'cut at ' + IntToStr(cut) + ': nothing is whole yet');
      CheckTrue(walk = nwPartial, 'cut at ' + IntToStr(cut) + ': a partial message, not an unknown one');
      end;

   whole := NetWholeBytes(stream, SizeOf(THelloMessage), False, walk, bad);
   CheckEquals(SizeOf(THelloMessage), whole, 'all 70 bytes are one message');
   CheckTrue(walk = nwComplete, 'ending exactly on the boundary');

   whole := NetWholeBytes(stream, Length(stream), False, walk, bad);
   CheckEquals(SizeOf(THelloMessage) + SizeOf(TServerMessage), whole,
               'the server message after it is whole too');
end;

(* The server refuses a link whose first message is anything but HELLO. The
  rule needs a socket, but its two inputs are here: HELLO has an id of its own,
  and no other message (a 4.x station's COMPUTERID, say) has that id. *)
procedure TTestNetHello.Test_HelloHasItsOwnIdAndSize;
begin
   BeginTest('Test_HelloHasItsOwnIdAndSize');
   CheckTrue(NET_HELLO_ID <> NET_COMPUTERID_ID, 'HELLO is not COMPUTERID');
   CheckEquals(70, NetMessageSize(NET_HELLO_ID), 'and the framing table sizes it');
   CheckEquals(0, NetMessageSize(NET_HELLO_ID + 1), 'the id beside it is still unknown');
   CheckEquals(4, NetMessageSize(NET_COMPUTERID_ID), 'COMPUTERID is still 4 bytes');
end;

(* EVERY CONTEST CAN ANNOUNCE ITSELF. SendHello refuses an id that does not
  fit rather than truncate it, so a contest whose id is longer than the field,
  or not printable ASCII, could never join a network -- and nothing else would
  say so until a station tried. This walks the registry, so a new contest is
  checked the day it registers. The program version travels in the same
  message and is checked with it. *)
procedure TTestNetHello.Test_EveryContestAndThisVersionFitTheHello;
var
   contests: TContestHandleList;
   h: THelloMessage;
   id: string;
   i: integer;
begin
   BeginTest('Test_EveryContestAndThisVersionFitTheHello');
   (* ContestsToWalk raises when the factory is not linked, so this walk
     cannot pass by walking nothing. *)
   ContestsToWalk;
   contests := KnownContests;
   CheckTrue(Length(contests) > 0, 'the registry knows some contests');
   for i := 0 to High(contests) do
      begin
      (* ContestId is exactly what uNet.SendHello announces. *)
      id := ContestId(contests[i]);
      CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 1, TR4W_CURRENTVERSION_NUMBER, id, h),
                'contest "' + id + '" must fit the HELLO message (' +
                IntToStr(HELLO_CONTEST_CHARS) + ' printable ASCII characters ' +
                'at most), or it can never join a multi-op network');
      CheckEquals(id, HelloContestId(h), 'contest "' + id + '" reads back whole');
      end;

   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, 1, TR4W_CURRENTVERSION_NUMBER, '', h),
             'the program version fits the HELLO message');
   CheckEquals(TR4W_CURRENTVERSION_NUMBER, HelloAppVersion(h),
               'and reads back whole');
end;

procedure TTestNetHello.RunAllTests;
begin
   Test_TheLayoutIsTheWire;
   Test_BuildAndReadBack;
   Test_AnIdThatDoesNotFitIsRefusedNotTruncated;
   Test_OnlyPrintableAsciiIsSent;
   Test_TheVersionJudgement;
   Test_ThePeersTable;
   Test_TheServersOwnHelloIsNotAStation;
   Test_OneNoticePerStationAndContest;
   Test_ThePeerContestJudgement;
   Test_AHelloIsOneWholeMessageHoweverTheStreamIsCut;
   Test_HelloHasItsOwnIdAndSize;
   Test_EveryContestAndThisVersionFitTheHello;
end;

end.
