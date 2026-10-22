unit uTestUDPDatagrams;
{$I ..\..\src\tr4w.inc}

(*
   WHAT AN N1MM-FORMAT LISTENER ACTUALLY RECEIVES, END TO END.

   uTestUDPContactXml checks the contact string BuildUDPContact returns, and
   uTestUDPBroadcaster checks the routing with dummy payloads.  Nothing joined
   the two: a message could be built right and sent on the wrong stream, or sent
   when the stream was off, and every test would still pass.  This suite
   installs a recording transport in the REAL broadcaster singleton, drives the
   real entry points in LOGSUBS2, and asserts on each datagram that reached the
   wire -- where it went, its root element and the tags a listener reads.

   THE ENTRY POINTS DRIVEN:  LogContactToUDP, LogEditedContactToUDP,
   SendDeletedContactToUDP, LookupInfoToUDP, and for the score PostScoreToUDP
   (the send half of SendScoreToUDP -- the other half, CalculateTotals, reads
   the SQLite log, which a unit test must not open).  SendScoreToUDP itself is
   driven only where it must send NOTHING, since that is decided before the
   log is touched.

   <contestnr> IS PINNED FOR A LEGACY CONTEST AT ITS ORIGINAL VALUE, Ord of the
   contest enum, and Q108 S4 (2026-10-17) did NOT move it: a contest with no
   legacy number gets a DERIVED number instead, pinned for the unit-test
   fixture in Test_AContestWithNoLegacyNumberGetsADerivedContestnr.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TUDPDatagramTests = class(TTestCase)
   private
      procedure Has(const aXml, aFragment: string);
      procedure Test_ContactIsOnTheContactStream;
      procedure Test_EditedContactIsAContactReplace;
      procedure Test_DeletedContactIsAContactDelete;
      procedure Test_AContestWithNoLegacyNumberGetsADerivedContestnr;
      procedure Test_LookupGoesToTheLookupStream;
      procedure Test_ScoreIsADynamicResults;
      procedure Test_ScoreTotalRowWithTwoModesIsPerMode;
      procedure Test_WRTCScoreIsSentWithItsMultipliers;
      procedure Test_AStreamNobodyListensToSendsNothing;
      procedure Test_TheMasterSwitchSilencesEveryMessage;
      procedure Test_ScoreEntryPointSendsNothingWhenOff;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   uContestTestFixture, (* TEST_FIXTURE_CONTEST_ID -- a contest with no legacy number *)
   VC,
   uSettingsModel,
   uUDPBroadcastConfig,
   uUDPBroadcaster,
   uMults,
   LogDupe,
   PostUnit,
   logsubs2;

const
   CONTACT_ADDRESS = '10.1.1.1';
   CONTACT_PORT    = 12061;
   SCORE_ADDRESS   = '10.1.1.2';
   SCORE_PORT      = 12062;
   LOOKUP_ADDRESS  = '10.1.1.3';
   LOOKUP_PORT     = 12063;

type
   TDatagram = record
      Address: string;
      Port: integer;
      Payload: AnsiString;
   end;

var
   (* The capture list.  Several datagrams per action is possible (one
      destination per listener), so this is a list and not "the last one". *)
   gSent: array of TDatagram;

   gSavedCall: string;
   gSavedComputer: string;
   gSavedContest: TContestHandle;
   gSavedTotals: QSOTotalArray;
   gSavedPoints: QSOTotalArray;
   gSavedMults: array[BandType, CW..Both, RemainingMultiplierType] of Word;
   gSavedConfig: TUDPBroadcastConfig;

procedure RecordSend(const aAddress: string; const aPort: integer;
                     const aPayload: AnsiString);
var
   n: integer;
begin
   n := Length(gSent);
   SetLength(gSent, n + 1);
   gSent[n].Address := aAddress;
   gSent[n].Port    := aPort;
   gSent[n].Payload := aPayload;
end;

procedure ResetCapture;
begin
   SetLength(gSent, 0);
end;

(* The text between <aTag> and </aTag>, or '' when the tag is not there. *)
function TagValue(const aXml: string; const aTag: string): string;
var
   p, q: integer;
begin
   Result := '';
   p := Pos('<' + aTag + '>', aXml);
   if p = 0 then
      begin
      Exit;
      end;
   p := p + Length(aTag) + 2;
   q := Pos('</' + aTag + '>', aXml);
   if q > p then
      begin
      Result := Copy(aXml, p, q - p);
      end;
end;

(* The name of the root element: the first tag after the XML declaration. *)
function RootOf(const aXml: string): string;
var
   p, q: integer;
begin
   Result := '';
   p := Pos('?>', aXml);
   if p = 0 then
      begin
      Exit;
      end;
   p := Pos('<', Copy(aXml, p + 2, Length(aXml)));
   if p = 0 then
      begin
      Exit;
      end;
   p := Pos('?>', aXml) + 2 + p;
   q := p;
   while (q <= Length(aXml)) and (aXml[q] <> '>') do
      begin
      Inc(q);
      end;
   Result := Copy(aXml, p, q - p);
end;

(* The test configuration: contact, score and lookup each have a listener of
  their own on their own address and port, so a message on the wrong stream
  lands somewhere that names the mistake. *)
procedure ConfigureAllStreams(aMasterOn: boolean);
var
   c: TUDPBroadcastConfig;
begin
   c := TUDPBroadcastConfig.Create;
   try
      c.AddDestination(CONTACT_ADDRESS, CONTACT_PORT, [usContact]);
      c.AddDestination(SCORE_ADDRESS,   SCORE_PORT,   [usScore]);
      c.AddDestination(LOOKUP_ADDRESS,  LOOKUP_PORT,  [usLookup]);
      c.Enabled := aMasterOn;
      UDPBroadcaster.Configure(c);
   finally
      c.Free;
   end;
end;

function SampleQSO: ContestExchange;
begin
   FillChar(Result, SizeOf(ContestExchange), 0);
   Result.ceContest := ContestHandleOf(CQWWCW);
   Result.Callsign  := 'W1AW';
   Result.Band      := Band20;
   Result.Mode      := CW;
   Result.Frequency := 14025000;
   Result.id        := 'GUID-0001';
   Result.tSysTime.qtYear   := 26;
   Result.tSysTime.qtMonth  := 10;
   Result.tSysTime.qtDay    := 16;
   Result.tSysTime.qtHour   := 12;
   Result.tSysTime.qtMinute := 34;
   Result.tSysTime.qtSecond := 56;
end;

procedure TUDPDatagramTests.Has(const aXml, aFragment: string);
begin
   CheckTrue(Pos(aFragment, aXml) > 0,
             'expected ' + aFragment + ' in: ' + aXml);
end;

procedure TUDPDatagramTests.Test_ContactIsOnTheContactStream;
var
   xml: string;
begin
   BeginTest('a logged contact is ONE contactinfo datagram, on the contact stream');
   ConfigureAllStreams(True);
   ResetCapture;
   LogContactToUDP(SampleQSO);

   CheckEquals(1, Length(gSent), 'exactly one datagram');
   CheckEquals(CONTACT_ADDRESS, gSent[0].Address, 'to the contact listener');
   CheckEquals(CONTACT_PORT, gSent[0].Port, 'on the contact port');

   xml := string(gSent[0].Payload);
   CheckEquals('contactinfo', RootOf(xml), 'root element');
   CheckEquals('TR4W', TagValue(xml, 'app'), 'app');
   CheckEquals('NY4I', TagValue(xml, 'mycall'), 'mycall is the station call');
   CheckEquals('W1AW', TagValue(xml, 'call'), 'call is the worked call');
   CheckEquals('14', TagValue(xml, 'band'), 'band in MHz');
   CheckEquals('CW', TagValue(xml, 'mode'), 'mode');
   CheckEquals('CQ-WW-CW', TagValue(xml, 'contestname'), 'contestname');
   CheckEquals('2026-10-16 12:34:56', TagValue(xml, 'timestamp'), 'timestamp');
   CheckEquals('GUID-0001', TagValue(xml, 'ID'), 'ID');
   (* No radio is interfaced here, so the frequency is the band's default and
     not the QSO's own Frequency field: 14000 kHz, in 10 Hz units. *)
   CheckEquals('1400000', TagValue(xml, 'rxfreq'), 'rxfreq');
   CheckEquals('1400000', TagValue(xml, 'txfreq'), 'txfreq');
   (* PINNED: Ord of the contest enum -- a legacy contest's number, which Q108
     S4 left exactly as it was. *)
   CheckEquals(IntToStr(Ord(CQWWCW)), TagValue(xml, 'contestnr'), 'contestnr');
   CheckEquals(Settings.Computer.Name, TagValue(xml, 'StationName'), 'StationName');
   CheckEquals('W1AW', TagValue(xml, 'oldcall'), 'oldcall');
   CheckEquals('2026-10-16 12:34:56', TagValue(xml, 'oldtimestamp'), 'oldtimestamp');
   CheckEquals('</contactinfo>' + sLineBreak,
               Copy(xml, Length(xml) - Length('</contactinfo>' + sLineBreak) + 1,
                    Length(xml)),
               'the root closes the message');
end;

procedure TUDPDatagramTests.Test_EditedContactIsAContactReplace;
var
   xml: string;
begin
   BeginTest('an edited contact is a contactreplace on the contact stream');
   ConfigureAllStreams(True);
   ResetCapture;
   LogEditedContactToUDP(SampleQSO);

   CheckEquals(1, Length(gSent), 'exactly one datagram');
   CheckEquals(CONTACT_ADDRESS, gSent[0].Address, 'to the contact listener');
   CheckEquals(CONTACT_PORT, gSent[0].Port, 'on the contact port');
   xml := string(gSent[0].Payload);
   CheckEquals('contactreplace', RootOf(xml), 'root element');
   CheckEquals('NY4I', TagValue(xml, 'mycall'), 'mycall');
   CheckEquals('W1AW', TagValue(xml, 'call'), 'call');
   CheckEquals('14', TagValue(xml, 'band'), 'band');
   CheckEquals('CW', TagValue(xml, 'mode'), 'mode');
   CheckEquals('CQ-WW-CW', TagValue(xml, 'contestname'), 'contestname');
   CheckEquals('GUID-0001', TagValue(xml, 'ID'),
               'ID is what lets the listener replace the right row');
end;

procedure TUDPDatagramTests.Test_DeletedContactIsAContactDelete;
var
   xml: string;
begin
   // The one message built inline in SendDeletedContactToUDP rather than by
   // BuildUDPContact, and so the one no other suite covered.
   BeginTest('a deleted contact is a contactdelete naming the row to remove');
   ConfigureAllStreams(True);
   ResetCapture;
   SendDeletedContactToUDP(SampleQSO);

   CheckEquals(1, Length(gSent), 'exactly one datagram');
   CheckEquals(CONTACT_ADDRESS, gSent[0].Address, 'to the contact listener');
   CheckEquals(CONTACT_PORT, gSent[0].Port, 'on the contact port');
   xml := string(gSent[0].Payload);
   CheckEquals('contactdelete', RootOf(xml), 'root element');
   CheckEquals('TR4W', TagValue(xml, 'app'), 'app');
   CheckEquals('2026-10-16 12:34:56', TagValue(xml, 'timestamp'), 'timestamp');
   CheckEquals('W1AW', TagValue(xml, 'call'), 'call');
   CheckEquals('GUID-0001', TagValue(xml, 'ID'), 'ID names the row to delete');
   CheckEquals(IntToStr(Ord(CQWWCW)), TagValue(xml, 'contestnr'), 'contestnr (pinned, as above)');
   CheckEquals(Settings.Computer.Name, TagValue(xml, 'StationName'), 'StationName');
   CheckEquals(0, Pos('<mycall>', xml), 'a delete carries no contact body');
   CheckTrue(Pos('</contactdelete>', xml) > 0, 'and it is closed');
end;

(* Q108 S4. A contest registered by id has no legacy number, so its
  <contestnr> is the registry's DERIVED number: 256 + CRC32(its id) mod
  (2^31 - 256). The literal below is that arithmetic done independently
  (Python zlib.crc32(b'TR4W-TEST-FIXTURE') = 1862706810, + 256 = 1862707066)
  and is what a listener of today's build receives for it. It changes only if
  the id or the rule does -- the point of deriving from the id and from nothing
  assigned at the seal. All four messages that carry <contestnr> say the same. *)
procedure TUDPDatagramTests.Test_AContestWithNoLegacyNumberGetsADerivedContestnr;
const
   FIXTURE_CONTESTNR = '1862707066';
var
   h: TContestHandle;
   q: ContestExchange;
   xml: string;
begin
   BeginTest('a contest with no legacy number broadcasts the derived <contestnr>');
   CheckTrue(FindContestById(TEST_FIXTURE_CONTEST_ID, h), 'the fixture is registered');
   q := SampleQSO;
   q.ceContest := h;
   ConfigureAllStreams(True);

   ResetCapture;
   LogContactToUDP(q);
   CheckEquals(1, Length(gSent), 'a contactinfo');
   xml := string(gSent[0].Payload);
   CheckEquals(FIXTURE_CONTESTNR, TagValue(xml, 'contestnr'), 'contactinfo');

   ResetCapture;
   LogEditedContactToUDP(q);
   CheckEquals(1, Length(gSent), 'a contactreplace');
   CheckEquals(FIXTURE_CONTESTNR, TagValue(string(gSent[0].Payload), 'contestnr'),
               'contactreplace');

   ResetCapture;
   SendDeletedContactToUDP(q);
   CheckEquals(1, Length(gSent), 'a contactdelete');
   CheckEquals(FIXTURE_CONTESTNR, TagValue(string(gSent[0].Payload), 'contestnr'),
               'contactdelete');

   ResetCapture;
   LookupInfoToUDP(q);
   CheckEquals(1, Length(gSent), 'a lookupinfo');
   CheckEquals(FIXTURE_CONTESTNR, TagValue(string(gSent[0].Payload), 'contestnr'),
               'lookupinfo');

   CheckTrue(StrToInt(FIXTURE_CONTESTNR) > High(Byte),
             'and it is never a byte value, so it cannot be mistaken for a legacy number');
end;

procedure TUDPDatagramTests.Test_LookupGoesToTheLookupStream;
var
   xml: string;
begin
   BeginTest('a lookup is a lookupinfo on the LOOKUP stream, not the contact stream');
   ConfigureAllStreams(True);
   ResetCapture;
   LookupInfoToUDP(SampleQSO);

   CheckEquals(1, Length(gSent), 'exactly one datagram');
   CheckEquals(LOOKUP_ADDRESS, gSent[0].Address, 'to the lookup listener');
   CheckEquals(LOOKUP_PORT, gSent[0].Port, 'on the lookup port');
   xml := string(gSent[0].Payload);
   CheckEquals('lookupinfo', RootOf(xml), 'root element');
   CheckEquals('W1AW', TagValue(xml, 'call'), 'call');
   CheckEquals('NY4I', TagValue(xml, 'mycall'), 'mycall');
end;

procedure SetScoreGlobals;
begin
   Contest := ContestHandleOf(CQWWCW);
   FillChar(QSOTotals, SizeOf(QSOTotals), 0);
   FillChar(QSOPointTotals, SizeOf(QSOPointTotals), 0);
   FillChar(mo.MTotals, SizeOf(mo.MTotals), 0);
   QSOTotals[Band20, CW] := 5;
   QSOTotals[AllBands, CW] := 5;
   (* Q109: the ALL row is sent now, so the all-modes cells are set as the
     loader sets them: a QSO adds to its mode AND to Both. *)
   QSOTotals[Band20, Both] := 5;
   QSOTotals[AllBands, Both] := 5;
   QSOPointTotals[Band20, Both] := 10;
   QSOPointTotals[AllBands, Both] := 10;
   mo.MTotals[Band20, Both, rmDomestic] := 2;
   mo.MTotals[Band20, Both, rmDX]       := 3;
   mo.MTotals[AllBands, Both, rmDomestic] := 2;
   mo.MTotals[AllBands, Both, rmDX]       := 3;
   mo.MTotals[Band20, CW, rmDomestic] := 2;
   mo.MTotals[Band20, CW, rmDX]       := 3;
   mo.MTotals[Band20, CW, rmZone]     := 4;
   mo.MTotals[Band20, CW, rmPrefix]   := 1;
   mo.MTotals[AllBands, CW, rmDomestic] := 2;
   mo.MTotals[AllBands, CW, rmDX]       := 3;
   mo.MTotals[AllBands, CW, rmZone]     := 4;
   mo.MTotals[AllBands, CW, rmPrefix]   := 1;
end;

procedure TUDPDatagramTests.Test_ScoreIsADynamicResults;
var
   xml: string;
   pBreak, pBreakEnd, pScore: integer;
begin
   BeginTest('the score is a dynamicresults on the SCORE stream, in the D7 structure');
   ConfigureAllStreams(True);
   SetScoreGlobals;
   ResetCapture;
   PostScoreToUDP(4321);

   CheckEquals(1, Length(gSent), 'exactly one datagram');
   CheckEquals(SCORE_ADDRESS, gSent[0].Address, 'to the score listener');
   CheckEquals(SCORE_PORT, gSent[0].Port, 'on the score port');
   xml := string(gSent[0].Payload);
   CheckEquals('dynamicresults', RootOf(xml), 'root element');
   CheckEquals('TR4W', TagValue(xml, 'soft'), 'soft');
   CheckTrue(TagValue(xml, 'version') <> '', 'version is present');
   CheckEquals('CQ-WW-CW', TagValue(xml, 'contest'), 'contest is the ADIF contest id');
   CheckEquals('NY4I', TagValue(xml, 'call'), 'call is the station call');
   CheckEquals(' ', TagValue(xml, 'club'), 'club (a single space, as D7 sent)');
   Has(xml, '<class ops="' +
      tCategoryOperatorSA[Settings.Contest.CategoryOperator] + '" mode="' +
      tCategoryModeSA[Settings.Contest.CategoryMode] + '" power="' +
      tCategoryPowerSA[Settings.Contest.CategoryPower] + '" bands="' +
      tCategoryBandSA[Settings.Contest.CategoryBand] + '" transmitter="' +
      tCategoryTransmitterSA[Settings.Contest.CategoryTransmitter] +
      '" assisted="' + tCategoryAssistedSA[Settings.Contest.CategoryAssisted] +
      '"></class>');
   CheckEquals('4321', TagValue(xml, 'score'), 'score is the total passed in');
   CheckTrue(TagValue(xml, 'timestamp') <> '', 'timestamp is present');

   // The breakdown, per band and mode, then the TOTAL row.
   Has(xml, '<qso band="20" mode="CW">5</qso>');
   Has(xml, '<mult band="20" mode="CW" type="state">2</mult>');
   Has(xml, '<mult band="20" mode="CW" type="country">3</mult>');
   Has(xml, '<mult band="20" mode="CW" type="zone">4</mult>');
   Has(xml, '<mult band="20" mode="CW" type="prefix">1</mult>');
   Has(xml, '<qso band="total" mode="CW">5</qso>');
   Has(xml, '<mult band="total" mode="CW" type="state">2</mult>');
   Has(xml, '<mult band="total" mode="CW" type="prefix">1</mult>');

   pBreak    := Pos('<breakdown>', xml);
   pBreakEnd := Pos('</breakdown>', xml);
   pScore    := Pos('<score>', xml);
   CheckTrue((pBreak > 0) and (pBreak < Pos('<qso band="20"', xml)) and
             (Pos('<qso band="total"', xml) < pBreakEnd) and
             (pBreakEnd < pScore),
             'the rows sit inside <breakdown>, which comes before <score>');
   (* Q109 (deliberate edit, 2026-10-16): this used to pin 'no <point> rows'
     (D7-identical -- the mode loop stopped at Phone).  The ALL row of the
     sample at the head of BuildScoreUDPXml is sent now, with values. *)
   Has(xml, '<qso band="total" mode="ALL">5</qso>');
   Has(xml, '<mult band="total" mode="ALL" type="state">2</mult>');
   Has(xml, '<mult band="total" mode="ALL" type="country">3</mult>');
   Has(xml, '<point band="20" mode="ALL">10</point>');
   Has(xml, '<point band="total" mode="ALL">10</point>');
end;

procedure TUDPDatagramTests.Test_ScoreTotalRowWithTwoModesIsPerMode;
var
   xml: string;
begin
   (* Q109 (deliberate edit, 2026-10-16).  This was the KNOWN-DEFECT test: the
     "total" row took its count from one running sum reused for every mode, so
     CW 5 on 20 m plus Phone 3 on 15 m read 8 and 13.  The correct values are
     the per-mode totals, 5 and 3, and the ALL total is 8. *)
   BeginTest('Q109: each total row is its own mode''s bands summed');
   ConfigureAllStreams(True);
   SetScoreGlobals;
   QSOTotals[Band15, Phone]   := 3;
   QSOTotals[AllBands, Phone] := 3;
   QSOTotals[Band15, Both]    := 3;
   QSOTotals[AllBands, Both]  := 8;
   QSOTotals[Band20, Both]    := 5;
   ResetCapture;
   PostScoreToUDP(1);
   xml := string(gSent[0].Payload);
   Has(xml, '<qso band="15" mode="PH">3</qso>');
   Has(xml, '<qso band="total" mode="CW">5</qso>');
   Has(xml, '<qso band="total" mode="PH">3</qso>');
   Has(xml, '<qso band="total" mode="ALL">8</qso>');
   CheckEquals(0, Pos('mode="CW">8<', xml), 'the CW total is not inflated');
   CheckEquals(0, Pos('mode="PH">13<', xml), 'the PH total is not inflated');
end;

procedure TUDPDatagramTests.Test_WRTCScoreIsSentWithItsMultipliers;
var
   xml: string;
begin
   (* Q109, NY4I 2026-10-16: "dynamicresults is perfectly fine for wrtc. That
     was its original purpose."  WRTC forbids ONLINE score posting; this local
     message is what its aggregators read, so it is sent, and it carries WRTC's
     two multiplier kinds -- HQ and country -- on the ALL-modes rows and no
     others.  Nothing here asks the contest for a posting permission. *)
   BeginTest('Q109: WRTC''s UDP score IS sent, with HQ and country mults and points');
   ConfigureAllStreams(True);
   SetScoreGlobals;
   Contest := ContestHandleOf(WRTC);
   ResetCapture;
   PostScoreToUDP(77);

   CheckEquals(1, Length(gSent), 'the UDP score is sent for WRTC');
   CheckEquals(SCORE_ADDRESS, gSent[0].Address, 'to the score listener');
   xml := string(gSent[0].Payload);
   CheckEquals('dynamicresults', RootOf(xml), 'root element');
   CheckEquals('77', TagValue(xml, 'score'), 'score');
   Has(xml, '<mult band="20" mode="ALL" type="HQ">2</mult>');
   Has(xml, '<mult band="20" mode="ALL" type="country">3</mult>');
   Has(xml, '<mult band="total" mode="ALL" type="HQ">2</mult>');
   Has(xml, '<mult band="total" mode="ALL" type="country">3</mult>');
   Has(xml, '<point band="total" mode="ALL">10</point>');
   CheckEquals(0, Pos('type="zone"', xml), 'WRTC posts no zone multiplier');
   CheckEquals(0, Pos('type="prefix"', xml), 'WRTC posts no prefix multiplier');
   CheckEquals(0, Pos('mode="CW" type=', xml), 'and no multiplier on a single-mode row');
end;

procedure TUDPDatagramTests.Test_AStreamNobodyListensToSendsNothing;
var
   c: TUDPBroadcastConfig;
begin
   BeginTest('a stream with no destination sends nothing; the others still do');
   c := TUDPBroadcastConfig.Create;
   try
      c.AddDestination(CONTACT_ADDRESS, CONTACT_PORT, [usContact]);
      UDPBroadcaster.Configure(c);
   finally
      c.Free;
   end;
   SetScoreGlobals;
   ResetCapture;
   LookupInfoToUDP(SampleQSO);
   PostScoreToUDP(1);
   CheckEquals(0, Length(gSent), 'lookup and score have no listener: nothing is sent');

   LogContactToUDP(SampleQSO);
   CheckEquals(1, Length(gSent), 'the contact stream, which has one, still sends');
end;

procedure TUDPDatagramTests.Test_TheMasterSwitchSilencesEveryMessage;
begin
   BeginTest('with the master switch off no message type reaches the wire');
   ConfigureAllStreams(False);
   SetScoreGlobals;
   ResetCapture;
   LogContactToUDP(SampleQSO);
   LogEditedContactToUDP(SampleQSO);
   SendDeletedContactToUDP(SampleQSO);
   LookupInfoToUDP(SampleQSO);
   PostScoreToUDP(1);
   CheckEquals(0, Length(gSent), 'nothing is sent while broadcasting is off');
end;

procedure TUDPDatagramTests.Test_ScoreEntryPointSendsNothingWhenOff;
var
   c: TUDPBroadcastConfig;
begin
   // SendScoreToUDP decides BEFORE it reads the log, so this is the one place
   // the real entry point can be driven without opening the database.
   BeginTest('SendScoreToUDP does nothing, and reads no log, when the score stream is off');
   ConfigureAllStreams(False);
   ResetCapture;
   SendScoreToUDP;
   CheckEquals(0, Length(gSent), 'master switch off');

   c := TUDPBroadcastConfig.Create;
   try
      c.AddDestination(CONTACT_ADDRESS, CONTACT_PORT, [usContact]);
      UDPBroadcaster.Configure(c);
   finally
      c.Free;
   end;
   SendScoreToUDP;
   CheckEquals(0, Length(gSent), 'no score listener');
end;

procedure TUDPDatagramTests.RunAllTests;
begin
   gSavedCall     := Settings.My.Call;
   gSavedComputer := Settings.Computer.Name;
   gSavedContest  := Contest;
   gSavedTotals   := QSOTotals;
   Move(QSOPointTotals, gSavedPoints, SizeOf(gSavedPoints));
   Move(mo.MTotals, gSavedMults, SizeOf(gSavedMults));
   gSavedConfig   := UDPBroadcaster.Snapshot;
   try
      Settings.My.Call := 'NY4I';
      UDPBroadcaster.SetTransport(RecordSend);

      Test_ContactIsOnTheContactStream;
      Test_EditedContactIsAContactReplace;
      Test_DeletedContactIsAContactDelete;
      Test_AContestWithNoLegacyNumberGetsADerivedContestnr;
      Test_LookupGoesToTheLookupStream;
      Test_ScoreIsADynamicResults;
      Test_ScoreTotalRowWithTwoModesIsPerMode;
      Test_WRTCScoreIsSentWithItsMultipliers;
      Test_AStreamNobodyListensToSendsNothing;
      Test_TheMasterSwitchSilencesEveryMessage;
      Test_ScoreEntryPointSendsNothingWhenOff;
   finally
      UDPBroadcaster.SetTransport(nil);
      UDPBroadcaster.Configure(gSavedConfig);
      FreeAndNil(gSavedConfig);
      Move(gSavedMults, mo.MTotals, SizeOf(gSavedMults));
      QSOTotals := gSavedTotals;
      Move(gSavedPoints, QSOPointTotals, SizeOf(QSOPointTotals));
      Contest := gSavedContest;
      Settings.Computer.Name := gSavedComputer;
      Settings.My.Call := gSavedCall;
      SetLength(gSent, 0);
   end;
end;

end.
