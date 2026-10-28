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

(* A CONTEST REGISTERED BY ITS STRING ID -- Q108 S3, 2026-10-17
  (docs/CONTEST_OWNERSHIP_DESIGN.md 8.2u).

  Through the unit-test program's own fixture (uContestTestFixture), which
  has no ContestType member: its handle is above the legacy range, assigned
  at the seal; the name resolver, the New Contest choices and the CONTEST
  vocabulary find it; the registry walks see it; an id that is a legacy
  spelling, a legacy alias or a duplicate is refused; a registration after
  the seal raises; and the fixture is not in the application.

  Q108 S4 (2026-10-17) IS HERE TOO: the broadcast number. Its multi-op
  refusal (ContestCanUseMultiOp and six doors in uNet) was REPLACED on
  2026-10-27 by network protocol 2: every contest travels the link, stations
  agree on it by the ID STRING in their HELLO (uNetHello), a received QSO is
  judged by what its SENDER announced, and an accepted record is stamped with
  this station's own handle. The tests for that are below, through the real
  uNet arms where a unit test can reach them (the HELLO and the server
  messages) and PeerRecordInOurContest where it cannot (the QSO arm logs
  through a booted contest session); the wiring a socket would be needed to
  drive is read from the source and is also a BENCH_QUEUE item. The
  <contestnr> on the wire is uTestUDPDatagrams'. The .TRW import's refusal of
  such a handle is uTestLogImport's. *)
unit uTestContestById;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework, VC;

type
   TContestByIdTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_TheFixtureHasAHandleAboveTheLegacyRange;
      procedure Test_KnownContestsListTheLegacyOnesThenTheByIdOnes;
      procedure Test_TheNameResolverFindsIt;
      procedure Test_TheRegistryWalkSeesIt;
      procedure Test_TheChoicesAndTheContestVocabularyOfferIt;
      procedure Test_AnIdIsRefusedForTheRightReasons;
      procedure Test_ARegistrationAfterTheSealRaises;
      procedure Test_TheFixtureIsNotInTheApplication;
      procedure Test_TheBroadcastNumberIsTheLegacyNumberOrDerivedFromTheId;
      procedure Test_NoDoorRefusesAContestAnyMore;
      procedure Test_AByIdContestPeerIsAcceptedAndRestamped;
      procedure Test_ALegacyContestPeerIsJudgedByItsAnnouncementNotItsByte;
      procedure Test_TheIdComparisonIgnoresCase;
      procedure Test_AStationThatNeverSaidHelloIsRefused;
      procedure Test_AStationThatLeftIsForgotten;
      procedure Test_AReAnnouncedContestIsJudgedByTheLatest;
      procedure Test_ChangingContestWithNoLinkSendsNothing;
      procedure Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest;
      procedure Test_ThePeerContestGateIsAheadOfEveryLoggingCall;
   private
      (* A PEER'S HELLO, or the server's (aStation 0), through the real arm. *)
      procedure FeedHello(const aStation: Byte; const aContestId: string);
      (* A QSO or an edit from aSender, through the real arm. *)
      procedure FeedQSO(const aMessage: Word; const aSender: Byte;
                        const aLoggedBy: AnsiChar; const aByte: TContestHandle);
   end;

implementation

uses
   SysUtils, Classes,
   TF, uContestBase, uContestRegistry, uContestNames, uContestChoices,
   uSettingsModel,
   uCFG,                  (* registers the CONTEST setting's vocabulary *)
   uCRC32,                (* the broadcast number's independent arithmetic *)
   PostUnit,              (* Contest -- the active contest *)
   uNet,                  (* the arms, the peers, the judge *)
   uNetHello,             (* the HELLO a station announces itself with *)
   uTestRegisteredContests,
   uContestTestFixture;

(* The fixture's handle, or NoContest when the id does not resolve (a
  failure the first test reports). *)
function FixtureHandle: TContestHandle;
begin
   if not FindContestById(TEST_FIXTURE_CONTEST_ID, Result) then
      begin
      Result := NoContest;
      end;
end;

procedure TContestByIdTests.Test_TheFixtureHasAHandleAboveTheLegacyRange;
var
   h: TContestHandle;
   n: integer;
   obj: TContestBase;
begin
   BeginTest('Test_TheFixtureHasAHandleAboveTheLegacyRange');
   CheckTrue(FindContestById(TEST_FIXTURE_CONTEST_ID, h), 'the fixture''s id finds a contest');
   CheckTrue(h.ToByte >= FirstByIdContestHandle.ToByte,
             'its handle is above the legacy range');
   CheckEquals(Ord(High(ContestType)) + 1, FirstByIdContestHandle.ToByte,
               'which starts one above the last legacy number');
   CheckFalse(ContestLegacyNumber(h, n), 'it has no legacy number');
   CheckEquals(0, n, 'and the number is zeroed');
   CheckTrue(LegacyContestOf(h) = DUMMYCONTEST, 'so no rule site''s member compare matches it');
   CheckEquals(TEST_FIXTURE_CONTEST_ID, ContestId(h), 'its id is the one it registered');
   CheckTrue(IsKnownContest(h), 'it is a known contest');
   CheckTrue(ContestClassFor(h) = TContestTestFixture, 'its class is the fixture''s');

   obj := ContestIdentity(h);
   CheckTrue(obj is TContestTestFixture, 'its identity object is the fixture''s class');
   CheckEquals(1, Pos(TEST_FIXTURE_CONTEST_ID + ' (', ContestWho(obj)), 'a message names it by its id');
   CheckTrue(HandleOf(obj) = h, 'and the handle');
   CheckTrue(ContestIdentity(h) = obj, 'one identity object per contest');
end;

procedure TContestByIdTests.Test_KnownContestsListTheLegacyOnesThenTheByIdOnes;
var
   known: TContestHandleList;
   k, n, byId: integer;
begin
   BeginTest('Test_KnownContestsListTheLegacyOnesThenTheByIdOnes');
   known := KnownContests;
   CheckTrue(Length(known) > Ord(High(ContestType)) + 1,
             'more contests are known than the legacy ones');
   byId := 0;
   for k := 0 to High(known) do
      begin
      if k <= Ord(High(ContestType)) then
         begin
         CheckEquals(k, known[k].ToByte, 'legacy contest ' + IntToStr(k) + ' in handle order');
         end
      else
         begin
         inc(byId);
         CheckFalse(ContestLegacyNumber(known[k], n), ContestId(known[k]) + ': no legacy number');
         CheckTrue(known[k].ToByte > known[k - 1].ToByte, ContestId(known[k]) + ': in handle order');
         (* HANDLES ARE ASSIGNED IN ID ORDER, so the same set of contests gives
            the same handles in every program. *)
         if k > Ord(High(ContestType)) + 1 then
            begin
            CheckTrue(CompareText(ContestId(known[k - 1]), ContestId(known[k])) < 0,
                      ContestId(known[k]) + ': handles follow id order');
            end;
         CheckEquals(FirstByIdContestHandle.ToByte + byId - 1, known[k].ToByte,
                     ContestId(known[k]) + ': handles are dense from the first by-id one');
         end;
      end;
   CheckTrue(byId >= 1, 'the fixture is among them');
end;

procedure TContestByIdTests.Test_TheNameResolverFindsIt;
var
   h: TContestHandle;
begin
   BeginTest('Test_TheNameResolverFindsIt');
   CheckTrue(TryContestFromName(TEST_FIXTURE_CONTEST_ID, h) and (h = FixtureHandle),
             'its id resolves');
   CheckTrue(TryContestFromName('  ' + LowerCase(TEST_FIXTURE_CONTEST_ID) + ' ', h) and
             (h = FixtureHandle),
             'whatever the case and the surrounding blanks');
   CheckTrue(ContestFromName(TEST_FIXTURE_CONTEST_ID) = FixtureHandle,
             'ContestFromName agrees');
   CheckEquals(TEST_FIXTURE_CONTEST_ID, CurrentContestSpelling(TEST_FIXTURE_CONTEST_ID),
               'a current id is stored as written');
end;

procedure TContestByIdTests.Test_TheRegistryWalkSeesIt;
var
   contests: TContestIdentityList;
   k, seen: integer;
   member: ContestType;
begin
   BeginTest('Test_TheRegistryWalkSeesIt');
   contests := ContestsToWalk;
   seen := 0;
   for k := 0 to High(contests) do
      begin
      if contests[k] is TContestTestFixture then
         begin
         inc(seen);
         CheckTrue(contests[k] = ContestIdentity(FixtureHandle),
                   'the walk hands out the shared identity object');
         end;
      end;
   CheckEquals(1, seen, 'every invariant that walks the registry meets the fixture once');
   CheckFalse(TryLegacyContestOf(ContestIdentity(FixtureHandle), member),
              'and no enum-keyed pin can name it');
   CheckEquals(Ord(DUMMYCONTEST), Ord(member), 'its legacy member is "no contest"');
end;

procedure TContestByIdTests.Test_TheChoicesAndTheContestVocabularyOfferIt;
var
   choices: TContestChoices;
   offered: TArray<string>;
   k, seen: integer;
begin
   BeginTest('Test_TheChoicesAndTheContestVocabularyOfferIt');
   choices := TContestChoices.Create;
   try
      CheckTrue(choices.IndexOf(FixtureHandle) >= 0, 'the New Contest drop-down offers it');
   finally
      choices.Free;
   end;

   offered := Settings.AllowedValuesForCommand('CONTEST');
   seen := 0;
   for k := 0 to High(offered) do
      begin
      if offered[k] = TEST_FIXTURE_CONTEST_ID then
         begin
         inc(seen);
         end;
      end;
   CheckEquals(1, seen, 'the CONTEST setting accepts its id, once');
end;

procedure TContestByIdTests.Test_AnIdIsRefusedForTheRightReasons;

   procedure Refused(const aId, aWhy: string);
   begin
      CheckTrue(ContestIdRefusal(aId) <> '', '''' + aId + ''' is refused: ' + aWhy);
   end;

begin
   BeginTest('Test_AnIdIsRefusedForTheRightReasons');
   Refused('', 'empty');
   Refused(' NEW CONTEST', 'a leading blank');
   Refused('NEW CONTEST ', 'a trailing blank');
   Refused('NEW' + #9 + 'CONTEST', 'a control character');
   Refused('NEW ' + #$00E9 + ' CONTEST', 'not printable ASCII');
   Refused('ARRL-DX-CW', 'a legacy contest''s stored name');
   Refused('arrl-dx-cw', 'whatever the case');
   Refused('DUMMY CONTEST', 'NoContest''s stored name too');
   Refused('NEQP', 'a legacy alias (New England''s old name)');
   Refused(TEST_FIXTURE_CONTEST_ID, 'already registered by id');
   Refused(LowerCase(TEST_FIXTURE_CONTEST_ID), 'already registered, whatever the case');
   CheckEquals('', ContestIdRefusal('A NEW CONTEST NOBODY HAS'), 'a fresh id is accepted');
   CheckEquals('', ContestIdRefusal('NEW-CONTEST_2'), 'hyphens, digits and underscores are fine');
end;

procedure TContestByIdTests.Test_ARegistrationAfterTheSealRaises;

   function RaisesById(const aId: string; aCls: TContestClass): string;
   begin
      Result := '';
      try
         RegisterContestById(aId, aCls);
      except
         on E: Exception do
            begin
            Result := E.Message;
            end;
      end;
   end;

var
   msg: string;
   h: TContestHandle;
begin
   BeginTest('Test_ARegistrationAfterTheSealRaises');
   (* The registry has been asked many questions by now, so it is sealed. *)
   CheckTrue(IsKnownContest(FixtureHandle), 'the registry has answered, so it is sealed');

   msg := RaisesById('A NEW CONTEST NOBODY HAS', TContestTestFixture);
   CheckTrue(Pos('sealed', msg) > 0, 'a fresh id after the seal raises, saying so: ' + msg);
   CheckFalse(FindContestById('A NEW CONTEST NOBODY HAS', h), 'and registers nothing');

   msg := RaisesById('ARRL-DX-CW', TContestTestFixture);
   CheckTrue(Pos('legacy contest', msg) > 0, 'a legacy spelling raises with its reason: ' + msg);

   msg := RaisesById('NEW CONTEST WITH NO CLASS', nil);
   CheckTrue(Pos('nil class', msg) > 0, 'a nil class raises: ' + msg);

   (* A LEGACY REGISTRATION AFTER THE SEAL RAISES TOO. DUMMYCONTEST is the one
      member with no class, so only the seal can refuse it. *)
   msg := '';
   try
      RegisterContest(DUMMYCONTEST, TContestTestFixture);
   except
      on E: Exception do
         begin
         msg := E.Message;
         end;
   end;
   CheckTrue(Pos('sealed', msg) > 0, 'a legacy registration after the seal raises: ' + msg);
   CheckTrue(ContestClassFor(NoContest) = nil, 'and NoContest still has no class');
end;

(* THE APPLICATION'S PROGRAM FILE NAMES NO TEST FIXTURE. Lint-ContestUnitsLinked
  holds the same from the build; this is the unit-test half the design asks
  for, read from the tree beside this test program (tr4w/test/unit). The
  contest matrix asks the running application's own registry. *)
procedure TContestByIdTests.Test_TheFixtureIsNotInTheApplication;
var
   lpr: TStringList;
   path: string;
begin
   BeginTest('Test_TheFixtureIsNotInTheApplication');
   path := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' +
                          PathDelim + 'tr4w.lpr');
   CheckTrue(FileExists(path), 'tr4w.lpr is beside the tests: ' + path);
   if not FileExists(path) then
      begin
      Exit;
      end;
   lpr := TStringList.Create;
   try
      lpr.LoadFromFile(AnsiString(path));
      CheckTrue(Pos('UCONTESTREGISTRY', UpperCase(lpr.Text)) > 0,
                'the file read is the application (it links the registry)');
      CheckEquals(0, Pos('UCONTESTTESTFIXTURE', UpperCase(lpr.Text)),
                  'the application does not name the test fixture''s unit');
   finally
      lpr.Free;
   end;
end;

(* <contestnr>: a legacy contest's is its legacy number (the broadcast is
  byte-identical to before S4), every other is 256 + CRC32(id) mod (2^31 - 256).
  The fixture's literal is zlib.crc32(b'TR4W-TEST-FIXTURE') + 256 done outside
  this program. No two known contests share a number, and a derived one is never
  a byte value. *)
procedure TContestByIdTests.Test_TheBroadcastNumberIsTheLegacyNumberOrDerivedFromTheId;
var
   h: TContestHandle;
   id: AnsiString;
   known: TContestHandleList;
   numbers: array of integer;
   k, j, n: integer;
begin
   BeginTest('Test_TheBroadcastNumberIsTheLegacyNumberOrDerivedFromTheId');
   h := FixtureHandle;
   CheckEquals(1862707066, ContestBroadcastNumber(h), 'the fixture''s derived number, as a literal');
   id := AnsiString(TEST_FIXTURE_CONTEST_ID);
   CheckEquals(Integer(256 + Int64(GetCRC32(BytesOf(id))) mod (Int64(2147483648) - 256)),
               ContestBroadcastNumber(h),
               'and it is 256 + CRC32(id) mod (2^31 - 256)');
   CheckEquals(ContestBroadcastNumber(h), ContestBroadcastNumber(h), 'stable between calls');

   known := KnownContests;
   SetLength(numbers, Length(known));
   for k := 0 to High(known) do
      begin
      numbers[k] := ContestBroadcastNumber(known[k]);
      if ContestLegacyNumber(known[k], n) then
         begin
         CheckEquals(n, numbers[k], ContestId(known[k]) + ': a legacy contest broadcasts its legacy number');
         end
      else
         begin
         CheckTrue(numbers[k] > High(Byte), ContestId(known[k]) + ': a derived number is never a byte value');
         CheckTrue(numbers[k] <= High(Integer), ContestId(known[k]) + ': it fits a signed 32-bit integer');
         end;
      end;
   for k := 0 to High(numbers) do
      begin
      for j := k + 1 to High(numbers) do
         begin
         CheckTrue(numbers[k] <> numbers[j],
                   ContestId(known[k]) + ' and ' + ContestId(known[j]) + ' share <contestnr> ' +
                   IntToStr(numbers[k]));
         end;
      end;
end;

var
   GNoticeTexts: TStringList = nil;

procedure RecordNotice(const aText: string);
begin
   GNoticeTexts.Add(aText);
end;

procedure TContestByIdTests.FeedHello(const aStation: Byte; const aContestId: string);
var
   hello: THelloMessage;
   desync: boolean;
begin
   CheckTrue(BuildHello(NET_PROTOCOL_VERSION, aStation, '5.0.99', aContestId, hello),
             'the hello for "' + aContestId + '" can be built');
   THelloMessagePtr(@NetBuffer[1])^ := hello;
   CheckEquals(SizeOf(THelloMessage), ConsumeNetBuffer(SizeOf(THelloMessage), desync),
               'the whole hello was consumed');
   CheckFalse(desync, 'and the stream stayed on a message boundary');
end;

procedure TContestByIdTests.FeedQSO(const aMessage: Word; const aSender: Byte;
                                    const aLoggedBy: AnsiChar;
                                    const aByte: TContestHandle);
var
   pkt: NetQSOInformationPtr;
   desync: boolean;
begin
   pkt := NetQSOInformationPtr(@NetBuffer[1]);
   pkt^ := Default(TNetQSOInformation);
   pkt^.qiID := aMessage;
   pkt^.qiComputerID := 2;              (* not this station's id *)
   pkt^.qiSenderID := aSender;
   pkt^.qiInformation.ceContest := aByte;
   pkt^.qiInformation.ceRecordKind := rkQSO;
   pkt^.qiInformation.ceComputerID := aLoggedBy;
   pkt^.qiInformation.Callsign := 'K1ABC';
   CheckEquals(SizeOf(TNetQSOInformation),
               ConsumeNetBuffer(SizeOf(TNetQSOInformation), desync),
               'the whole packet was consumed');
   CheckFalse(desync, 'and the stream stayed on a message boundary');
end;

(* NO DOOR IS LEFT. The guards Q108 S4 put on six doors are gone with their
  predicate, their text and the resourcestring; what stands in their place is
  the announcement, so the connect path says HELLO before anything else and
  every packet names its sender. Source reads, like the others: the connect and
  send paths need a socket. *)
procedure TContestByIdTests.Test_NoDoorRefusesAContestAnyMore;
var
   root, netText, effectsText, registryText, stringsText: string;
   helloAt: integer;

   function Slurp(const aRelative: string): string;
   var
      lines: TStringList;
      path: string;
   begin
      path := ExpandFileName(root + aRelative);
      CheckTrue(FileExists(path), 'the source is beside the tests: ' + path);
      Result := '';
      if not FileExists(path) then
         begin
         Exit;
         end;
      lines := TStringList.Create;
      try
         lines.LoadFromFile(AnsiString(path));
         Result := lines.Text;
      finally
         lines.Free;
      end;
   end;

begin
   BeginTest('Test_NoDoorRefusesAContestAnyMore');
   root := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           'src' + PathDelim;
   netText := Slurp('uNet.pas');
   effectsText := Slurp('uSettingsEffects.pas');
   registryText := Slurp('contestFactory' + PathDelim + 'uContestRegistry.pas');
   stringsText := Slurp('uAppStrings.pas');

   CheckEquals(0, Pos('ContestCanUseMultiOp(', netText), 'uNet asks no predicate');
   CheckEquals(0, Pos('NetCarriesContest(', netText), 'uNet has no guard wrapper');
   CheckEquals(0, Pos('PeerContestRefusal(', netText), 'and does not refuse a peer''s CONTEST');
   CheckEquals(0, Pos('MultiOpRefusalText(', netText), 'nor show a refusal');
   CheckEquals(0, Pos('function ContestCanUseMultiOp', registryText), 'the predicate is gone');
   CheckEquals(0, Pos('function MultiOpRefusalText', registryText), 'and so is its text');
   CheckEquals(0, Pos('SContestNotOnMultiOp =', stringsText), 'and the resourcestring');

   CheckTrue(Pos('NetQSOInfoToSend.qiSenderID := Ord(WireComputerID)', netText) > 0,
             'every packet SendRecordToServer builds (and the restock) names its sender');
   helloAt := Pos('if not SendHello then', netText);
   CheckTrue(helloAt > 0, 'the connect path announces itself');
   CheckTrue((helloAt > 0) and
             (Pos('SendFullStationStatus;', Copy(netText, helloAt, MaxInt)) > 0),
             'and does it before the first station status');
   CheckEquals(0, Pos('ComputerNetID', netText),
               'COMPUTERID is no longer sent: the HELLO carries the id');
   CheckTrue(Pos('NetContestChanged;', effectsText) > 0,
             'the CONTEST setting''s effect (the only call of FoundContest) re-announces');
end;

(* A BY-ID CONTEST'S PEER. The fixture's handle is a byte assigned at the seal
  that no other build shares; the peer announces the contest by its ID and the
  record's own byte is whatever its build made of it. The record is accepted
  and STAMPED with this station's own handle. *)
procedure TContestByIdTests.Test_AByIdContestPeerIsAcceptedAndRestamped;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
begin
   BeginTest('Test_AByIdContestPeerIsAcceptedAndRestamped');
   savedContest := Contest;
   NetPeers.Clear;
   ForgetPeerContestNotices;
   try
      Contest := FixtureHandle;
      CheckTrue(Contest.ToByte >= FirstByIdContestHandle.ToByte, 'this station is on a by-id contest');
      FeedHello(2, TEST_FIXTURE_CONTEST_ID);

      rec := Default(ContestExchange);
      rec.ceContest := TContestHandle.FromByte(77);   (* what the peer's build called it *)
      CheckTrue(PeerRecordInOurContest(rec, 2, 'the test'),
                'a peer that announced our by-id contest is accepted');
      CheckTrue(rec.ceContest = Contest, 'and the record carries THIS station''s handle');
      CheckEquals(0, PeerContestNoticeCount, 'nothing is reported');
   finally
      Contest := savedContest;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

(* THE BYTE IS NEVER READ, in either direction: the wrong byte under the right
  announcement is accepted; the right byte under another announcement is not. *)
procedure TContestByIdTests.Test_ALegacyContestPeerIsJudgedByItsAnnouncementNotItsByte;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
   ours, theirs: TContestHandle;
begin
   BeginTest('Test_ALegacyContestPeerIsJudgedByItsAnnouncementNotItsByte');
   savedContest := Contest;
   ours := ContestHandleOf(ARRLDXCW);
   theirs := ContestHandleOf(CQWWCW);
   NetPeers.Clear;
   ForgetPeerContestNotices;
   GNoticeTexts := TStringList.Create;
   PeerContestNoticeSink := RecordNotice;
   try
      Contest := ours;
      FeedHello(2, ContestId(ours));
      FeedHello(3, ContestId(theirs));

      rec := Default(ContestExchange);
      rec.ceContest := theirs;
      CheckTrue(PeerRecordInOurContest(rec, 2, 'the test'),
                'B announced our contest: accepted although the byte says another');
      CheckTrue(rec.ceContest = ours, 'and the byte is replaced by ours');

      rec := Default(ContestExchange);
      rec.ceContest := ours;
      CheckFalse(PeerRecordInOurContest(rec, 3, 'the test'),
                 'C announced another contest: refused although the byte says ours');
      CheckTrue(rec.ceContest = ours, 'a refused record is left as it came');
      CheckEquals(1, PeerContestNoticeCount, 'and the operator is told once');
      CheckEquals(1, GNoticeTexts.Count, 'one notice reached the operator');
      CheckTrue(Pos('Station C', GNoticeTexts[0]) = 1, 'naming the station: ' + GNoticeTexts[0]);
   finally
      PeerContestNoticeSink := nil;
      GNoticeTexts.Free;
      GNoticeTexts := nil;
      Contest := savedContest;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

procedure TContestByIdTests.Test_TheIdComparisonIgnoresCase;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
begin
   BeginTest('Test_TheIdComparisonIgnoresCase');
   savedContest := Contest;
   NetPeers.Clear;
   try
      Contest := FixtureHandle;
      FeedHello(2, LowerCase(TEST_FIXTURE_CONTEST_ID));
      rec := Default(ContestExchange);
      CheckTrue(PeerRecordInOurContest(rec, 2, 'the test'),
                'the name resolver ignores case, so the judge does too');
   finally
      Contest := savedContest;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

(* NOTHING SAYS WHAT IT IS RUNNING: refused and logged, with no notice (it is not
  a contest mismatch, it is a station outside the protocol). The sender byte can
  also be absent (0) or out of range. *)
procedure TContestByIdTests.Test_AStationThatNeverSaidHelloIsRefused;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
   k: integer;
const
   SILENT_SENDERS: array[0..5] of integer = (0, 1, 3, 26, 27, 255);
begin
   BeginTest('Test_AStationThatNeverSaidHelloIsRefused');
   savedContest := Contest;
   NetPeers.Clear;
   ForgetPeerContestNotices;
   try
      Contest := ContestHandleOf(ARRLDXCW);
      FeedHello(2, ContestId(Contest));
      for k := Low(SILENT_SENDERS) to High(SILENT_SENDERS) do
         begin
         rec := Default(ContestExchange);
         rec.ceContest := Contest;
         CheckFalse(PeerRecordInOurContest(rec, SILENT_SENDERS[k], 'the test'),
                    'sender ' + IntToStr(SILENT_SENDERS[k]) + ' announced nothing: refused');
         end;
      CheckEquals(0, PeerContestNoticeCount, 'and it is a log line, not an operator notice');
      rec := Default(ContestExchange);
      CheckTrue(PeerRecordInOurContest(rec, 2, 'the test'), 'while B, who did, is still accepted');
   finally
      Contest := savedContest;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

(* The server's "that station left" (SM_DISCONECT_CLIENT, its ordinal) empties
  the station's announcement, through the real arm. *)
procedure TContestByIdTests.Test_AStationThatLeftIsForgotten;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
   msg: TServerMessagePtr;
   desync: boolean;
begin
   BeginTest('Test_AStationThatLeftIsForgotten');
   savedContest := Contest;
   NetPeers.Clear;
   try
      Contest := ContestHandleOf(ARRLDXCW);
      FeedHello(2, ContestId(Contest));
      CheckTrue(NetPeers.Knows(2), 'B is known');

      msg := TServerMessagePtr(@NetBuffer[1]);
      msg^ := Default(TServerMessage);
      msg^.smID := NET_SERVERMESSAGE_ID;
      msg^.smMessage := SM_DISCONECT_CLIENT_MESSAGE;
      msg^.smParam := 2;
      CheckEquals(SizeOf(TServerMessage), ConsumeNetBuffer(SizeOf(TServerMessage), desync),
                  'the message was consumed');
      CheckFalse(NetPeers.Knows(2), 'B is forgotten when it leaves');
      rec := Default(ContestExchange);
      CheckFalse(PeerRecordInOurContest(rec, 2, 'the test'), 'and its QSOs are no longer vouched for');
   finally
      Contest := savedContest;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

(* A CONTEST CHANGE IS A SECOND HELLO. The latest announcement is the one that
  counts, in both directions. *)
procedure TContestByIdTests.Test_AReAnnouncedContestIsJudgedByTheLatest;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
begin
   BeginTest('Test_AReAnnouncedContestIsJudgedByTheLatest');
   savedContest := Contest;
   NetPeers.Clear;
   ForgetPeerContestNotices;
   PeerContestNoticeSink := nil;
   try
      Contest := ContestHandleOf(ARRLDXCW);
      FeedHello(2, ContestId(ContestHandleOf(CQWWCW)));
      FeedHello(2, ContestId(Contest));
      rec := Default(ContestExchange);
      CheckTrue(PeerRecordInOurContest(rec, 2, 'the test'),
                'B moved onto our contest: accepted');
      FeedHello(2, TEST_FIXTURE_CONTEST_ID);
      CheckEquals(TEST_FIXTURE_CONTEST_ID, NetPeers.ContestIdOf(2), 'B''s announcement is the latest');
   finally
      Contest := savedContest;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

(* The switch, as far as a unit test reaches it: with no link up, choosing a
  contest announces nothing and changes nothing. The re-announcement itself needs
  a socket -- BENCH_QUEUE. *)
procedure TContestByIdTests.Test_ChangingContestWithNoLinkSendsNothing;
var
   savedContest: TContestHandle;
begin
   BeginTest('Test_ChangingContestWithNoLinkSendsNothing');
   savedContest := Contest;
   try
      Contest := FixtureHandle;
      NetContestChanged;
      CheckTrue(Contest = FixtureHandle, 'the contest stays what the operator chose');
      CheckFalse(NetIsConnected, 'and there is still no link');
   finally
      Contest := savedContest;
   end;
end;

(* The real NET_QSOINFO and NET_EDITEDQSO arms, fed through NetBuffer. Had the
  gate been missing, the QSO arm would call LogContact in a session with no
  contest booted -- the test would not pass quietly. What the test reads is the
  report: one notice per (peer, contest), however many QSOs, and a second peer
  or a second contest is its own. *)
procedure TContestByIdTests.Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest;
var
   savedContest: TContestHandle;
   savedID: Cardinal;
   cqwwHandle, ssbHandle: TContestHandle;
begin
   BeginTest('Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest');
   savedContest := Contest;
   savedID := NetQSOInfoToSend.qiComputerID;
   cqwwHandle := ContestHandleOf(CQWWCW);
   ssbHandle := ContestHandleOf(ARRLDXSSB);
   NetPeers.Clear;
   ForgetPeerContestNotices;
   GNoticeTexts := TStringList.Create;
   PeerContestNoticeSink := RecordNotice;
   try
      Contest := ContestHandleOf(ARRLDXCW);
      NetQSOInfoToSend.qiComputerID := 1;
      FeedHello(2, ContestId(cqwwHandle));
      FeedHello(3, ContestId(cqwwHandle));

      (* ceComputerID 'Z' is who LOGGED the QSO; the sender byte is who SENT it,
        and it is the sender the notice names. *)
      FeedQSO(NET_QSOINFO_ID, 2, 'Z', ContestHandleOf(ARRLDXCW));
      CheckEquals(1, PeerContestNoticeCount, 'the first mismatched QSO raises the notice');
      CheckEquals(1, GNoticeTexts.Count, 'one notice reached the operator');
      CheckTrue(Pos('Station B', GNoticeTexts[0]) = 1, 'and it names the sender: ' + GNoticeTexts[0]);
      FeedQSO(NET_QSOINFO_ID, 2, 'Z', cqwwHandle);
      CheckEquals(1, PeerContestNoticeCount, 'a second one from the same peer does not');
      FeedQSO(NET_EDITEDQSO_ID, 2, 'Z', cqwwHandle);
      CheckEquals(1, PeerContestNoticeCount, 'nor does that peer''s edit: one latch for both arms');
      FeedQSO(NET_QSOINFO_ID, 3, 'Z', cqwwHandle);
      CheckEquals(2, PeerContestNoticeCount, 'another peer is its own notice');
      FeedHello(2, ContestId(ssbHandle));
      FeedQSO(NET_QSOINFO_ID, 2, 'Z', cqwwHandle);
      CheckEquals(3, PeerContestNoticeCount, 'and so is the same peer on a third contest');

      ForgetPeerContestNotices;
      CheckEquals(0, PeerContestNoticeCount, 'a new link starts the count over');
      FeedQSO(NET_QSOINFO_ID, 2, 'Z', cqwwHandle);
      CheckEquals(1, PeerContestNoticeCount, 'and the notice can be raised again');
      CheckEquals(4, GNoticeTexts.Count, 'four notices reached the operator in all');
   finally
      PeerContestNoticeSink := nil;
      GNoticeTexts.Free;
      GNoticeTexts := nil;
      Contest := savedContest;
      NetQSOInfoToSend.qiComputerID := savedID;
      NetPeers.Clear;
      ForgetPeerContestNotices;
   end;
end;

(* The arm itself: in uNet.pas, each judge call stands before the logging call
  it guards, so deleting or moving it fails here even though a unit test cannot
  drive LogContact. *)
procedure TContestByIdTests.Test_ThePeerContestGateIsAheadOfEveryLoggingCall;
var
   lines: TStringList;
   text: string;
   gate, log: integer;
begin
   BeginTest('Test_ThePeerContestGateIsAheadOfEveryLoggingCall');
   lines := TStringList.Create;
   try
      lines.LoadFromFile(AnsiString(ExpandFileName(ExtractFilePath(ParamStr(0)) +
         '..' + PathDelim + '..' + PathDelim + 'src' + PathDelim + 'uNet.pas')));
      text := lines.Text;
   finally
      lines.Free;
   end;
   gate := Pos('''NET_QSOINFO'')', text);
   log := Pos('LogContact(NetQSOInfoPtr', text);
   CheckTrue((gate > 0) and (log > gate), 'NET_QSOINFO: the gate stands before LogContact');
   gate := Pos('''NET_EDITEDQSO'')', text);
   log := Pos('FindAndUpdateQSOInLog(NetQSOInfoPtr', text);
   CheckTrue((gate > 0) and (log > gate), 'NET_EDITEDQSO: the gate stands before the update');
end;

procedure TContestByIdTests.RunAllTests;
begin
   Test_TheFixtureHasAHandleAboveTheLegacyRange;
   Test_KnownContestsListTheLegacyOnesThenTheByIdOnes;
   Test_TheNameResolverFindsIt;
   Test_TheRegistryWalkSeesIt;
   Test_TheChoicesAndTheContestVocabularyOfferIt;
   Test_AnIdIsRefusedForTheRightReasons;
   Test_ARegistrationAfterTheSealRaises;
   Test_TheFixtureIsNotInTheApplication;
   Test_TheBroadcastNumberIsTheLegacyNumberOrDerivedFromTheId;
   Test_NoDoorRefusesAContestAnyMore;
   Test_AByIdContestPeerIsAcceptedAndRestamped;
   Test_ALegacyContestPeerIsJudgedByItsAnnouncementNotItsByte;
   Test_TheIdComparisonIgnoresCase;
   Test_AStationThatNeverSaidHelloIsRefused;
   Test_AStationThatLeftIsForgotten;
   Test_AReAnnouncedContestIsJudgedByTheLatest;
   Test_ChangingContestWithNoLinkSendsNothing;
   Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest;
   Test_ThePeerContestGateIsAheadOfEveryLoggingCall;
end;

end.
