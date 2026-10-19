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

  Q108 S4 (2026-10-17) IS HERE TOO: the multi-op refusal and the broadcast
  number. ContestCanUseMultiOp is the one predicate and NetCarriesContest the
  one logging wrapper every uNet door calls; the doors that need a socket
  (connect's second door, the send and the two receives) cannot be driven
  from a unit test, so Test_EveryMultiOpDoorIsWired reads uNet.pas for each
  call -- the wiring is also a BENCH_QUEUE item. The <contestnr> on the wire
  is uTestUDPDatagrams'. The .TRW import's refusal of such a handle is
  uTestLogImport's. *)
unit uTestContestById;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

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
      procedure Test_AContestWithNoLegacyNumberCannotUseMultiOp;
      procedure Test_TheBroadcastNumberIsTheLegacyNumberOrDerivedFromTheId;
      procedure Test_NetCarriesContestAsksTheOnePredicate;
      procedure Test_APeerCannotMoveThisStationOntoSuchAContest;
      procedure Test_ConnectingIsRefusedWithNoAttemptMade;
      procedure Test_ChangingContestWithNoLinkDropsNothing;
      procedure Test_EveryMultiOpDoorIsWired;
      procedure Test_APeerOnOurContestIsAccepted;
      procedure Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest;
      procedure Test_ThePeerContestGateIsAheadOfEveryLoggingCall;
   end;

implementation

uses
   SysUtils, Classes,
   VC, TF, uContestBase, uContestRegistry, uContestNames, uContestChoices,
   uSettingsModel,
   uCFG,                  (* registers the CONTEST setting's vocabulary *)
   uCRC32,                (* the broadcast number's independent arithmetic *)
   PostUnit,              (* Contest -- the active contest *)
   uNet,                  (* the doors *)
   uAppStrings,           (* SContestNotOnMultiOp *)
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
   CheckTrue(ContestOf(ContestIdentity(FixtureHandle)) = DUMMYCONTEST,
             'and no enum-keyed pin can name it');
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

(* THE ONE PREDICATE. Exactly the contests with a legacy number can use the V1
  multi-op packet -- walked over every KNOWN contest, so a contest added later
  is held to it without an edit -- and the refusal text is non-empty exactly
  where the predicate says no. *)
procedure TContestByIdTests.Test_AContestWithNoLegacyNumberCannotUseMultiOp;
var
   h: TContestHandle;
   known: TContestHandleList;
   k, n: integer;
   text: string;
begin
   BeginTest('Test_AContestWithNoLegacyNumberCannotUseMultiOp');
   h := FixtureHandle;
   CheckFalse(ContestCanUseMultiOp(h), 'the fixture cannot use multi-op');
   CheckTrue(ContestCanUseMultiOp(ContestHandleOf(ARRLDXCW)), 'a legacy contest can');
   CheckTrue(ContestCanUseMultiOp(NoContest),
             'no contest chosen is not carrying one, so a station with none may connect');
   CheckFalse(ContestCanUseMultiOp(TContestHandle.FromByte(255)),
              'a byte that names no contest is no legacy number either');

   known := KnownContests;
   for k := 0 to High(known) do
      begin
      CheckTrue(ContestCanUseMultiOp(known[k]) = ContestLegacyNumber(known[k], n),
                ContestId(known[k]) + ': can use multi-op exactly when it has a legacy number');
      CheckTrue(ContestCanUseMultiOp(known[k]) = (MultiOpRefusalText(known[k]) = ''),
                ContestId(known[k]) + ': the refusal text is empty exactly when it can');
      end;

   text := MultiOpRefusalText(h);
   CheckTrue(Pos(ContestIdentity(h).DisplayName, text) > 0,
             'the message names the contest by its display name: ' + text);
   CheckEquals(Format(SContestNotOnMultiOp, [ContestIdentity(h).DisplayName]), text,
               'and it is the one translatable resourcestring, formatted');
   CheckEquals('', MultiOpRefusalText(ContestHandleOf(ARRLDXCW)), 'a legacy contest has none');
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
   CheckEquals(Integer(256 + Int64(GetCRC32(id[1], Length(id))) mod (Int64(2147483648) - 256)),
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

(* The wrapper every door calls: the predicate's answer, and nothing else. *)
procedure TContestByIdTests.Test_NetCarriesContestAsksTheOnePredicate;
var
   h: TContestHandle;
   known: TContestHandleList;
   k: integer;
begin
   BeginTest('Test_NetCarriesContestAsksTheOnePredicate');
   h := FixtureHandle;
   CheckFalse(NetCarriesContest(h, 'the test'), 'the fixture is turned away');
   CheckTrue(NetCarriesContest(ContestHandleOf(ARRLDXCW), 'the test'), 'a legacy contest is carried');
   CheckTrue(NetCarriesContest(NoContest, 'the test'), 'no contest is carried');
   known := KnownContests;
   for k := 0 to High(known) do
      begin
      CheckTrue(NetCarriesContest(known[k], 'the test') = ContestCanUseMultiOp(known[k]),
                ContestId(known[k]) + ': the wrapper never disagrees with the predicate');
      end;
end;

(* A peer's CONTEST command naming a contest that cannot travel is refused with
  the message and NOT applied; everything else is left to ApplyPeerCommand. *)
procedure TContestByIdTests.Test_APeerCannotMoveThisStationOntoSuchAContest;
var
   h: TContestHandle;
   text: string;
begin
   BeginTest('Test_APeerCannotMoveThisStationOntoSuchAContest');
   h := FixtureHandle;
   text := MultiOpRefusalText(h);
   CheckTrue(text <> '', 'there is a message to give');
   CheckEquals(text, PeerContestRefusal('CONTEST', TEST_FIXTURE_CONTEST_ID),
               'the CONTEST command naming it is refused with that message');
   CheckEquals(text, PeerContestRefusal(' contest ', '  ' + LowerCase(TEST_FIXTURE_CONTEST_ID) + ' '),
               'whatever the case and the blanks, as the name resolver reads it');
   CheckEquals('', PeerContestRefusal('CONTEST', 'ARRL-DX-CW'), 'a legacy contest is followed');
   CheckEquals('', PeerContestRefusal('CONTEST', 'NEQP'), 'and so is a legacy alias');
   CheckEquals('', PeerContestRefusal('CONTEST', 'NO SUCH CONTEST ANYWHERE'),
               'a name this build cannot resolve is not judged here');
   CheckEquals('', PeerContestRefusal('CONTEST NAME', TEST_FIXTURE_CONTEST_ID),
               'CONTEST NAME is a different setting');
   CheckEquals('', PeerContestRefusal('BAND', TEST_FIXTURE_CONTEST_ID),
               'only the command that selects the contest is asked');
   CheckEquals('', PeerContestRefusal('', ''), 'an empty parameter is nothing');
end;

(* The first connect door: with the fixture selected, TryConnectToNetwork makes
  NO attempt -- no thread. (If the guard were missing this would start a real
  connect thread, which is why the test is the failing direction only.) The
  warning is shown through showwarning, silenced here as in a batch export. *)
procedure TContestByIdTests.Test_ConnectingIsRefusedWithNoAttemptMade;
var
   savedContest: TContestHandle;
   savedSilent: boolean;
begin
   BeginTest('Test_ConnectingIsRefusedWithNoAttemptMade');
   savedContest := Contest;
   savedSilent := tSilentExport;
   tSilentExport := True;
   try
      Contest := FixtureHandle;
      CheckFalse(NetIsConnected, 'there is no link to begin with');
      TryConnectToNetwork;
      CheckFalse(ThreadStarted(NetThreadID), 'no connect thread was started');
      CheckFalse(NetIsConnected, 'and nothing connected');
      TryConnectToNetwork;
      CheckFalse(ThreadStarted(NetThreadID), 'the timer''s retry makes no attempt either');
   finally
      Contest := savedContest;
      tSilentExport := savedSilent;
   end;
end;

(* The switch door, as far as a unit test reaches it: with no link up, choosing
  the contest drops nothing, says nothing and changes nothing. The branch that
  drops a live link needs a socket -- BENCH_QUEUE. *)
procedure TContestByIdTests.Test_ChangingContestWithNoLinkDropsNothing;
var
   savedContest: TContestHandle;
begin
   BeginTest('Test_ChangingContestWithNoLinkDropsNothing');
   savedContest := Contest;
   try
      Contest := FixtureHandle;
      NetContestChanged(Contest);
      CheckTrue(Contest = FixtureHandle, 'the contest stays what the operator chose');
      CheckFalse(NetIsConnected, 'and there is still no link');
      NetContestChanged(ContestHandleOf(ARRLDXCW));
   finally
      Contest := savedContest;
   end;
end;

(* THE DOORS A UNIT TEST CANNOT DRIVE (they need a socket) are checked by their
  CALL SITES: each door string below is the aDoor argument of a
  NetCarriesContest call in uNet.pas, so deleting a guard fails this test. It
  is a source read, like Test_TheFixtureIsNotInTheApplication, and no
  substitute for the two-station bench test in BENCH_QUEUE. *)
procedure TContestByIdTests.Test_EveryMultiOpDoorIsWired;
const
   DOORS: array[0..6] of string = (
      'NetCarriesContest(Contest, ''TryConnectToNetwork'')',
      'NetCarriesContest(Contest, ''ConnectToTR4WServer'')',
      '''send of a QSO packet''',
      '''receive of a NET_QSOINFO packet''',
      '''receive of a NET_EDITEDQSO packet''',
      '''a peer''''s CONTEST command''',
      '''a switch of contest while connected''');
var
   unitText, effectsText, root: string;
   k: integer;

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
   BeginTest('Test_EveryMultiOpDoorIsWired');
   root := ExtractFilePath(ParamStr(0)) + '..' + PathDelim + '..' + PathDelim +
           'src' + PathDelim;
   unitText := Slurp('uNet.pas');
   effectsText := Slurp('uSettingsEffects.pas');
   for k := Low(DOORS) to High(DOORS) do
      begin
      CheckTrue(Pos(DOORS[k], unitText) > 0, 'uNet.pas has the door ' + DOORS[k]);
      end;
   CheckTrue(Pos('ContestCanUseMultiOp(Contest)', unitText) > 0,
             'TryConnectToNetwork asks the predicate before it starts a thread');
   CheckTrue(Pos('PeerContestRefusal(', unitText) > 0,
             'the NET_PARAMETER arm asks PeerContestRefusal');
   CheckTrue(Pos('NetContestChanged(Contest)', effectsText) > 0,
             'the CONTEST setting''s effect (the only call of FoundContest) calls NetContestChanged');
end;

var
   GNoticeTexts: TStringList = nil;

procedure RecordNotice(const aText: string);
begin
   GNoticeTexts.Add(aText);
end;

(* Q110 (NY4I 2026-10-18: "Peers have to be on the same contest and that is a
  flagged error to be reported"). The judge, on its own: a record in OUR
  contest passes and raises nothing. The LogContact that follows it in the real
  arm needs a booted contest session, so the pass-through is read from the
  source in Test_ThePeerContestGateIsAheadOfEveryLoggingCall. *)
procedure TContestByIdTests.Test_APeerOnOurContestIsAccepted;
var
   savedContest: TContestHandle;
   rec: ContestExchange;
begin
   BeginTest('Test_APeerOnOurContestIsAccepted');
   savedContest := Contest;
   ForgetPeerContestNotices;
   try
      Contest := ContestHandleOf(ARRLDXCW);
      rec := Default(ContestExchange);
      rec.ceContest := ContestHandleOf(ARRLDXCW);
      rec.ceComputerID := 'B';
      CheckTrue(PeerRecordInOurContest(rec, 'the test'), 'the same contest is accepted');
      CheckEquals(0, PeerContestNoticeCount, 'and nothing is reported');
   finally
      Contest := savedContest;
      ForgetPeerContestNotices;
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
   desync: boolean;
   pkt: NetQSOInformationPtr;

   procedure Feed(aMessage: Word; aPeer: AnsiChar; aPeerContest: ContestType);
   var
      used: integer;
   begin
      pkt := NetQSOInformationPtr(@NetBuffer[1]);
      pkt^ := Default(TNetQSOInformation);
      pkt^.qiID := aMessage;
      pkt^.qiComputerID := 2;              (* not this station's id *)
      pkt^.qiInformation.ceContest := ContestHandleOf(aPeerContest);
      pkt^.qiInformation.ceRecordKind := rkQSO;
      pkt^.qiInformation.ceComputerID := aPeer;
      pkt^.qiInformation.Callsign := 'K1ABC';
      used := ConsumeNetBuffer(SizeOf(TNetQSOInformation), desync);
      CheckEquals(SizeOf(TNetQSOInformation), used, 'the whole packet was consumed');
      CheckFalse(desync, 'and the stream stayed on a message boundary');
   end;

begin
   BeginTest('Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest');
   savedContest := Contest;
   savedID := NetQSOInfoToSend.qiComputerID;
   ForgetPeerContestNotices;
   GNoticeTexts := TStringList.Create;
   PeerContestNoticeSink := RecordNotice;
   try
      Contest := ContestHandleOf(ARRLDXCW);
      NetQSOInfoToSend.qiComputerID := 1;

      Feed(NET_QSOINFO_ID, 'B', CQWWCW);
      CheckEquals(1, PeerContestNoticeCount, 'the first mismatched QSO raises the notice');
      CheckEquals(1, GNoticeTexts.Count, 'one notice reached the operator');
      CheckTrue(Pos('Station B', GNoticeTexts[0]) = 1, 'and it names the peer');
      Feed(NET_QSOINFO_ID, 'B', CQWWCW);
      CheckEquals(1, PeerContestNoticeCount, 'a second one from the same peer does not');
      Feed(NET_EDITEDQSO_ID, 'B', CQWWCW);
      CheckEquals(1, PeerContestNoticeCount, 'nor does that peer''s edit: one latch for both arms');
      Feed(NET_QSOINFO_ID, 'C', CQWWCW);
      CheckEquals(2, PeerContestNoticeCount, 'another peer is its own notice');
      Feed(NET_QSOINFO_ID, 'B', ARRLDXSSB);
      CheckEquals(3, PeerContestNoticeCount, 'and so is the same peer on a third contest');

      ForgetPeerContestNotices;
      CheckEquals(0, PeerContestNoticeCount, 'a new link starts the count over');
      Feed(NET_QSOINFO_ID, 'B', CQWWCW);
      CheckEquals(1, PeerContestNoticeCount, 'and the notice can be raised again');
      CheckEquals(4, GNoticeTexts.Count, 'four notices reached the operator in all');
   finally
      PeerContestNoticeSink := nil;
      GNoticeTexts.Free;
      GNoticeTexts := nil;
      Contest := savedContest;
      NetQSOInfoToSend.qiComputerID := savedID;
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
   Test_AContestWithNoLegacyNumberCannotUseMultiOp;
   Test_TheBroadcastNumberIsTheLegacyNumberOrDerivedFromTheId;
   Test_NetCarriesContestAsksTheOnePredicate;
   Test_APeerCannotMoveThisStationOntoSuchAContest;
   Test_ConnectingIsRefusedWithNoAttemptMade;
   Test_ChangingContestWithNoLinkDropsNothing;
   Test_EveryMultiOpDoorIsWired;
   Test_APeerOnOurContestIsAccepted;
   Test_APeerOnAnotherContestIsRefusedAndReportedOncePerContest;
   Test_ThePeerContestGateIsAheadOfEveryLoggingCall;
end;

end.
