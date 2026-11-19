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
 Public License along with TR4W in GPL_License.TXT.
 If not, ref: http://www.gnu.org/licenses/gpl-3.0.txt
}
unit uTestK4Discovery;
{$I ..\..\src\tr4w.inc}

(* THE K4 DISCOVERY REPLY PARSER, against the two datagrams NY4I's LAN sent on
  2026-11-19 (captured with a 'findk4' broadcast to UDP 9100):

     from 192.168.73.159:9100   k4z:0:192.168.73.159 192.168.73.110:199
     from 192.168.73.108:9100   k4:NY4I:192.168.73.108:278

  THE FIRST IS THE DEFECT. A K4 Zero puts two space-separated addresses in the
  address field. The parser took the whole field as one address, so the setup
  wizard's "Found" drop-down held a single item reading
  "192.168.73.159 192.168.73.110" and the IP field was filled with it -- two
  addresses, neither usable. The radio is the one that sent the datagram. *)

interface

uses
   uTR4WTestFramework;

type
   TK4DiscoveryTests = class(TTestCase)
   public
      procedure RunAllTests; override;

   private
      procedure Test_TheK4ZeroReplyKeepsItsOwnAddress;
      procedure Test_TheK4DReplyWithANameInTheIndexField;
      procedure Test_TheSenderIsTheRadioWhenTheReplyNamesIt;
      procedure Test_CommasAndSemicolonsSeparateToo;
      procedure Test_MalformedRepliesAreRefused;
   end;

implementation

uses
   uK4Discovery;

procedure TK4DiscoveryTests.RunAllTests;
begin
   Test_TheK4ZeroReplyKeepsItsOwnAddress;
   Test_TheK4DReplyWithANameInTheIndexField;
   Test_TheSenderIsTheRadioWhenTheReplyNamesIt;
   Test_CommasAndSemicolonsSeparateToo;
   Test_MalformedRepliesAreRefused;
end;

procedure TK4DiscoveryTests.Test_TheK4ZeroReplyKeepsItsOwnAddress;
var
   radio: TK4DiscoveredRadio;
begin
   BeginTest('Test_TheK4ZeroReplyKeepsItsOwnAddress');

   CheckTrue(TK4Discovery.ParseResponse('k4z:0:192.168.73.159 192.168.73.110:199', radio),
             'the K4 Zero reply parses');
   CheckEquals('k4z', radio.RigType, 'it is a K4 Zero');
   CheckEquals('192.168.73.159', radio.IPAddress,
               'the radio is the FIRST address, not the whole field');
   CheckEquals('192.168.73.110', radio.OtherAddresses,
               'the second address is kept apart, never offered as the radio');
   CheckEquals('199', radio.SerialNumber, 'the serial is unaffected');
end;

procedure TK4DiscoveryTests.Test_TheK4DReplyWithANameInTheIndexField;
var
   radio: TK4DiscoveredRadio;
begin
   BeginTest('Test_TheK4DReplyWithANameInTheIndexField');

   CheckTrue(TK4Discovery.ParseResponse('k4:NY4I:192.168.73.108:278', radio),
             'a K4 puts a name where the index goes, and still parses');
   CheckEquals('k4', radio.RigType, 'a K4');
   CheckEquals(0, radio.RigIndex, 'a non-numeric index reads as 0');
   CheckEquals('192.168.73.108', radio.IPAddress, 'one address, as before');
   CheckEquals('', radio.OtherAddresses, 'nothing else listed');
   CheckEquals('278', radio.SerialNumber, 'serial 278');
end;

procedure TK4DiscoveryTests.Test_TheSenderIsTheRadioWhenTheReplyNamesIt;
var
   radio: TK4DiscoveredRadio;
begin
   BeginTest('Test_TheSenderIsTheRadioWhenTheReplyNamesIt');

   CheckTrue(TK4Discovery.ParseResponse('k4z:0:192.168.73.159 192.168.73.110:199', radio),
             'parse');

   TK4Discovery.PreferSender(radio, '192.168.73.159');
   CheckEquals('192.168.73.159', radio.IPAddress, 'the sender is already first');
   CheckEquals('192.168.73.110', radio.OtherAddresses, 'and nothing moved');

   TK4Discovery.PreferSender(radio, '10.9.9.9');
   CheckEquals('192.168.73.159', radio.IPAddress,
               'a sender the reply does not name changes nothing');

   TK4Discovery.PreferSender(radio, '');
   CheckEquals('192.168.73.159', radio.IPAddress, 'no sender known changes nothing');

   TK4Discovery.PreferSender(radio, '192.168.73.110');
   CheckEquals('192.168.73.110', radio.IPAddress,
               'a sender the reply names as the second address IS the radio');
   CheckEquals('192.168.73.159', radio.OtherAddresses,
               'and the former first address becomes the other');
end;

procedure TK4DiscoveryTests.Test_CommasAndSemicolonsSeparateToo;
var
   radio: TK4DiscoveredRadio;
begin
   BeginTest('Test_CommasAndSemicolonsSeparateToo');

   CheckTrue(TK4Discovery.ParseResponse('k4:0:10.0.0.1,10.0.0.2;10.0.0.3:5', radio),
             'a comma and a semicolon separate addresses as a space does');
   CheckEquals('10.0.0.1', radio.IPAddress, 'first');
   CheckEquals('10.0.0.2 10.0.0.3', radio.OtherAddresses, 'the rest, in order');
end;

procedure TK4DiscoveryTests.Test_MalformedRepliesAreRefused;
var
   radio: TK4DiscoveredRadio;
begin
   BeginTest('Test_MalformedRepliesAreRefused');

   CheckFalse(TK4Discovery.ParseResponse('foo:0:1.2.3.4:1', radio), 'not a K4 reply');
   CheckFalse(TK4Discovery.ParseResponse('k4:0::278', radio), 'no address at all');
   CheckFalse(TK4Discovery.ParseResponse('k4:0:  :278', radio), 'only spaces for an address');
   CheckFalse(TK4Discovery.ParseResponse('k4:0:1.2.3.4:5:6', radio), 'a fifth field is malformed');
   CheckFalse(TK4Discovery.ParseResponse('k4:0:1.2.3.4', radio), 'too few fields');
end;

end.
