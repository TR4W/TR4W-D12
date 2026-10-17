unit uTestUDPContactXml;
{$I ..\..\src\tr4w.inc}

(*
   THE N1MM-FORMAT CONTACT BROADCAST: THE TAG NAMES ARE THE WIRE FORMAT.

   External listeners (N1MM-format consumers, loggers, scoreboards) find a
   value by its tag name, so renaming a tag silently blinds them.  This was
   not hypothetical: commit c1463660 (2026-09-12, "MY CALL leaves CFGCA")
   renamed the identifier MyCall to Settings.My.Call with a blanket replace
   that also rewrote the STRING LITERAL, so <mycall> became
   <Settings.My.Call> and no listener received the station's callsign.
   Nothing failed to build and nothing failed to run.

   These tests build a real record through BuildUDPContact and assert the
   tag names, so a rename cannot change the wire format unnoticed.
*)

interface

uses
   SysUtils,
   uTR4WTestFramework;

type
   TUDPContactXmlTests = class(TTestCase)
   private
      procedure Test_ContactCarriesTheStationCallUnderMyCall;
      procedure Test_ContactTagNamesAreTheN1MMNames;
      procedure Test_EachRecordTypeIsItsOwnRoot;
   public
      procedure RunAllTests; override;
   end;

implementation

uses
   uContestRegistry,   (* ContestHandleOf -- a legacy contest's handle, Q108 S2 *)
   VC,
   uSettingsModel,
   logsubs2;

function ContactXml(aWhich: UDPType): string;
var
   q: ContestExchange;
begin
   FillChar(q, SizeOf(ContestExchange), 0);
   q.ceContest := ContestHandleOf(CQWWCW);
   q.Callsign := 'W1AW';
   q.Band := Band20;
   q.Mode := CW;
   q.Frequency := 14025000;
   Result := BuildUDPContact(q, aWhich);
end;

procedure TUDPContactXmlTests.Test_ContactCarriesTheStationCallUnderMyCall;
var
   xml: string;
begin
   BeginTest('Test_ContactCarriesTheStationCallUnderMyCall');
   Settings.My.Call := 'NY4I';
   xml := ContactXml(udpContactInfo);
   CheckTrue(Pos('<mycall>NY4I</mycall>', xml) > 0,
             '<mycall> carries the station call: ' + xml);
   CheckEquals(0, Pos('Settings.', xml),
               'no identifier text leaked into the wire format');
end;

procedure TUDPContactXmlTests.Test_ContactTagNamesAreTheN1MMNames;
const
   NAMES: array[0..9] of string =
      ('app', 'contestname', 'contestnr', 'timestamp', 'band', 'rxfreq',
       'mode', 'call', 'exchange1', 'ID');
var
   xml: string;
   i: integer;
begin
   BeginTest('Test_ContactTagNamesAreTheN1MMNames');
   Settings.My.Call := 'NY4I';
   xml := ContactXml(udpContactInfo);
   for i := Low(NAMES) to High(NAMES) do
      begin
      CheckTrue(Pos('<' + NAMES[i] + '>', xml) > 0, 'open tag <' + NAMES[i] + '>');
      CheckTrue(Pos('</' + NAMES[i] + '>', xml) > 0, 'close tag </' + NAMES[i] + '>');
      end;
   CheckTrue(Pos('<call>W1AW</call>', xml) > 0, '<call> carries the worked call');
   CheckTrue(Pos('<band>14</band>', xml) > 0, '<band> carries the band in MHz');
   CheckTrue(Pos('<contestname>CQ-WW-CW</contestname>', xml) > 0,
             '<contestname> carries the contest''s Cabrillo name');
end;

procedure TUDPContactXmlTests.Test_EachRecordTypeIsItsOwnRoot;
begin
   BeginTest('Test_EachRecordTypeIsItsOwnRoot');
   CheckTrue(Pos('<contactinfo>', ContactXml(udpContactInfo)) > 0, 'contactinfo');
   CheckTrue(Pos('<contactreplace>', ContactXml(udpContactReplace)) > 0, 'contactreplace');
   CheckTrue(Pos('<lookupinfo>', ContactXml(udpLookupInfo)) > 0, 'lookupinfo');
end;

procedure TUDPContactXmlTests.RunAllTests;
begin
   Test_ContactCarriesTheStationCallUnderMyCall;
   Test_ContactTagNamesAreTheN1MMNames;
   Test_EachRecordTypeIsItsOwnRoot;
end;

end.
