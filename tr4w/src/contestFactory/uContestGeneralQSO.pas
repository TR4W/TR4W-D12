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

(* General QSO.

  OnePointPerQSO -- the plainest rule there is, and the default for 31 contests. GENERAL QSO is TR4W's everyday non-contest logging mode, so this is the one that runs when nothing else does. *)
unit uContestGeneralQSO;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestFixedPoints;

type
   TContestGeneralQSO = class(TContestFixedPoints)
   protected
      function GetFormatsExchange: boolean; override;
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
   public
      constructor Create(aContest: ContestType); override;

      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aRSTSent: string): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aRSTReceived: string;
                                              const aHisQTH: string): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry;

constructor TContestGeneralQSO.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(1, 1);
end;

function TContestGeneralQSO.GetDisplayName: string;
begin
   Result := 'General QSO';
end;

(* THE EXCHANGE IS RST, A NAME AND A QTH -- the plain ragchew-style log.

   SYMMETRIC, which is rare enough here to be worth saying: both sides use the
   same three widths, because General QSO has no rule about who sends what. It
   is the fallback contest, so there is nothing contest-specific to encode.

   THE SHARED ARM STAYS: RSTNameAndQTHExchange serves other contests that have
   no class. *)
function TContestGeneralQSO.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestGeneralQSO.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aRSTSent: string): string;
begin
   Result := Format('%-3s %-5s %-7s', [aRSTSent, aMy.MyName, aMy.MyState]);
end;

function TContestGeneralQSO.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aRSTReceived: string;
                                                const aHisQTH: string): string;
begin
   Result := Format('%-3s %-5s %-7s', [aRSTReceived, string(aQso.Name), aHisQTH]);
end;

function TContestGeneralQSO.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange): string;
begin
   Result := Format('%-3d %-5s %-7s', [aQso.RSTSent, aMy.MyName, aMy.MyState]);
end;

initialization
   RegisterContest(GENERALQSO, TContestGeneralQSO);

end.
