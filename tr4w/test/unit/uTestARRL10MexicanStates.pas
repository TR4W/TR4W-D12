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

(* THE ARRL 10 METER CONTEST'S MEXICAN STATES -- issue 167, NY4I
  2026-11-19: "for a contest with the Mexican state in the exchange, we need
  to expand our definition of state. Check DXLog's ARRL_10.txt."

  THE SPONSOR (ARRL 10 Meter rules v2.0, 2026, 4.2 and 5.2.2): W/VE AND
  MEXICAN stations send their state or province, and the Mexican states are
  multipliers. The ARRL's 10-meter page links dxxe.org's list of the 32
  states, which DXLog's ARRL_10.txt copies: AGS BAC BCS CAM CHI CHH CMX COA
  COL DGO EMX GTO GRO HGO JAL MIC MOR NAY NLE OAX PUE QRO QUI SLP SIN SON TAB
  TAM TLX VER YUC ZAC.

  WHAT WAS ALREADY THERE: arrl10.dom includes MEXICO.DOM, and the contest's
  domestic list has XE, so 31 of the 32 were taken. WHAT WAS NOT: Mexico
  City. The Distrito Federal (DF) became Ciudad de Mexico (CMX) in January
  2016, and mexico.dom still read `DFE = DFE,DF` -- a typed CMX was refused,
  and a DF contact went into the Cabrillo file as DFE, which is on no list.
  Its line is `CMX = CMX,DFE,DF` now: the multiplier is the sponsor's CMX,
  and the two old spellings are the same multiplier.

  Through the real engine (MainUnit.ParametersOkay, arrl10.dom and its
  INCLUDEs loaded), an XE station worked by a US entrant. *)
unit uTestARRL10MexicanStates;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TARRL10MexicanStatesTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_EveryMexicanStateOfTheSponsorsListIsTaken;
      procedure Test_MexicoCityIsCMXHoweverItIsTyped;
   end;

implementation

uses
   SysUtils,
   (* ContestExchange, ContestType *)
   VC,
   (* ExchangeErrorMessage *)
   LogStuff,
   (* Enter, SetUpSession, RestoreSession, LoadCountryFile -- last, so its
      names win. *)
   uTestEngineEntry;

const
   (* The sponsor's list (dxxe.org, linked from the ARRL's 10-meter page),
      as DXLog's ARRL_10.txt spells it. *)
   MEXICAN_STATES: array[0..31] of string = (
      'AGS', 'BAC', 'BCS', 'CAM', 'CHI', 'CHH', 'CMX', 'COA',
      'COL', 'DGO', 'EMX', 'GTO', 'GRO', 'HGO', 'JAL', 'MIC',
      'MOR', 'NAY', 'NLE', 'OAX', 'PUE', 'QRO', 'QUI', 'SLP',
      'SIN', 'SON', 'TAB', 'TAM', 'TLX', 'VER', 'YUC', 'ZAC');

procedure SetUpARRL10;
begin
   SetUpSession(ARRL10, ['K', 'VE', 'KH6', 'KL', 'XE'], 'arrl10.dom');
end;

procedure TARRL10MexicanStatesTests.Test_EveryMexicanStateOfTheSponsorsListIsTaken;
var
   rx: ContestExchange;
   state: string;
   who: string;
begin
   BeginTest('Test_EveryMexicanStateOfTheSponsorsListIsTaken');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpARRL10;
   try
      for state in MEXICAN_STATES do
         begin
         who := 'XE1ABC 599 ' + state;
         CheckTrue(Enter('XE1ABC', '599 ' + state, rx),
                   who + ' is taken: ' + string(ExchangeErrorMessage));
         CheckEquals(state, string(rx.DomesticQTH), who + ': the state');
         CheckEquals(state, string(rx.DomMultQTH), who + ': the multiplier');
         end;
   finally
      RestoreSession;
   end;
end;

procedure TARRL10MexicanStatesTests.Test_MexicoCityIsCMXHoweverItIsTyped;
var
   rx: ContestExchange;

   procedure MexicoCity(const aTyped: string);
   var
      who: string;
   begin
      who := 'XE1ABC 599 ' + aTyped;
      CheckTrue(Enter('XE1ABC', '599 ' + aTyped, rx),
                who + ' is taken: ' + string(ExchangeErrorMessage));
      CheckEquals(aTyped, string(rx.QTHString), who + ': QTHString is what was typed');
      CheckEquals('CMX', string(rx.DomesticQTH), who + ': Mexico City is CMX');
      CheckEquals('CMX', string(rx.DomMultQTH), who + ': one multiplier, CMX');
   end;

begin
   BeginTest('Test_MexicoCityIsCMXHoweverItIsTyped');
   CheckTrue(LoadCountryFile, 'cty.dat loads');
   SetUpARRL10;
   try
      MexicoCity('CMX');
      MexicoCity('DF');
      MexicoCity('DFE');
   finally
      RestoreSession;
   end;
end;

procedure TARRL10MexicanStatesTests.RunAllTests;
begin
   Test_EveryMexicanStateOfTheSponsorsListIsTaken;
   Test_MexicoCityIsCMXHoweverItIsTyped;
end;

end.
