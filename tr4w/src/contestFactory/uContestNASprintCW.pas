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

(* North American Sprint - CW.

  OnePointPerQSO. A sprint's character is its QSY rule and its exchange, not its scoring. *)
unit uContestNASprintCW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestFixedPoints;

type
   TContestNASprintCW = class(TContestFixedPoints)
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

constructor TContestNASprintCW.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(1, 1);
end;

function TContestNASprintCW.GetDisplayName: string;
begin
   Result := 'North American Sprint - CW';
end;

(* THE EXCHANGE IS SERIAL, NAME AND STATE-OR-DX.

   'DX' IS SUBSTITUTED ON BOTH SIDES when there is no state, which is the
   Sprint's way of saying "outside North America" -- an empty column would be
   read by a scorer as a missing field rather than as a legitimate answer.

   THE WIDTHS ARE DELIBERATELY ASYMMETRIC and this is not a typo: sent is
   `%-4d %-7s %-8s` and received is `%-4u %-5s %-4s`. Both carry the 4.88.3
   marker in the legacy source, so they were set to those numbers together and
   on purpose.

   THE SHARED ARM STAYS: SSB-SPRINT uses the same body and has no class yet, so
   QSONumberNameDomesticOrDXQTHExchange is still live. *)
function TContestNASprintCW.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestNASprintCW.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aRSTSent: string): string;
begin
   if aMy.MyState = '' then
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, 'DX']);
      end
   else
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, aMy.MyState]);
      end;
end;

function TContestNASprintCW.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aRSTReceived: string;
                                                const aHisQTH: string): string;
begin
   (* Tested on aQso.QTHString and formatted from aHisQTH, matching the
      legacy arm exactly. *)
   if aQso.QTHString = '' then
      begin
      Result := Format('%-4u %-5s %-4s', [aQso.NumberReceived, string(aQso.Name), 'DX']);
      end
   else
      begin
      Result := Format('%-4u %-5s %-4s', [aQso.NumberReceived, string(aQso.Name), aHisQTH]);
      end;
end;

function TContestNASprintCW.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange): string;
begin
   if aMy.MyState = '' then
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, 'DX']);
      end
   else
      begin
      Result := Format('%-4d %-7s %-8s', [aQso.NumberSent, aMy.MyName, aMy.MyState]);
      end;
end;

initialization
   RegisterContest(NASPRINTCW, TContestNASprintCW);

end.
