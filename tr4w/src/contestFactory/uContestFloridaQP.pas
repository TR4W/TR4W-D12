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

(* Florida QSO Party.

  OnePhoneTwoCW: CW is worth double. Written as two numbers rather than a mode test, because DIGITAL scores the phone value here -- which is what the legacy 'if Mode = CW then 2 else 1' does and what a CW-versus-not model would get wrong. *)
unit uContestFloridaQP;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestStateQSOPartyBase;

type
   TContestFloridaQP = class(TContestStateQSOPartyBase)
   protected
      function GetFormatsExchange: boolean; override;

      (* THE STATE WHOSE COUNTIES THIS CONTEST'S EXCHANGE NAMES.

         Stated, not derived. The inherited getter would reach ContestsArray's
         P index and arrive at the same 'FL' -- but the base makes it abstract
         for state parties precisely so that answer is never an accident, and
         three separate places in this tree used to hand-type it. *)
      function GetHostState: string; override;

      (* TWO, FROM THE PUBLISHED RULES: "Florida stations on a county line
         (maximum of two counties) may be claimed as a separate QSO and
         multiplier from each county."

         THIS IS NEW BEHAVIOUR AND WAS CHOSEN, NOT MOVED. TR4W has never
         enforced any limit -- LOGSTUFF.ApplyFirstQTHAndQueueRest queues every
         valid county the operator typed -- and NY4I, 2026-09-28: "It has not
         enforced a limit. It relied upon participants not being given more
         than the ones allowed. But knowing and setting a limit makes our edit
         checking of the exchange more robust."

         So Florida is the first contest whose exchange is actually bounded,
         and it is bounded because its number is KNOWN. Michigan's is not, and
         is deliberately left unlimited rather than inferred from this one. *)
      function GetCountyLineCountiesMax: integer; override;
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
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

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
   SysUtils, uContestFixedPoints, uContestRegistry;

constructor TContestFloridaQP.Create(aContest: ContestType);
begin
   inherited Create(aContest);
end;

(* OnePhoneTwoCW, AND THE RULE IS CALLED RATHER THAN INHERITED.

   THIS CLASS USED TO DESCEND FROM TContestFixedPoints, which is a mechanism
   base for "a number per mode" -- and mechanism is all it ever gave: three
   integers and a case. Being a state QSO party is the stronger classification
   and there is only one base class to spend, so the scoring arrives as a call
   to the same routine TContestFixedPoints itself now calls. No behaviour moved
   and nothing is duplicated.

   THE THIRD NUMBER MATTERS AND IS NOT A GUESS: the legacy arm is
   `if Mode = CW then 2 else 1`, so DIGITAL scores the PHONE value. Passing 1
   for it is reproducing the arm, not rounding it off -- the corpus log for this
   contest contains a 6 m digital QSO, and a CW-versus-not model would have
   scored it the same by luck while being wrong in principle. *)
procedure TContestFloridaQP.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 1, 1);
end;

function TContestFloridaQP.GetDisplayName: string;
begin
   Result := 'Florida QSO Party';
end;

function TContestFloridaQP.GetHostState: string;
begin
   Result := 'FL';
end;

function TContestFloridaQP.GetCountyLineCountiesMax: integer;
begin
   Result := 2;
end;

(* THE EXCHANGE IS RST AND A COUNTY, OR RST AND A COUNTRY PREFIX.

   THE RECEIVED SIDE CARRIES THE ONE RULE THAT IS ACTUALLY FLORIDA'S, and it was
   sitting in a shared arm as two `if Contest = FLORIDAQSOPARTY` tests. A
   station outside Florida is identified by its DXCC PREFIX rather than by the
   DXQTH text every other contest on that arm uses, and the test is made twice
   because a non-Florida station reaches it two ways: with no QTH string at all,
   or with the literal 'DX'.

   THAT IS EXACTLY THE SHAPE THIS FACTORY EXISTS TO REMOVE -- a contest's rule
   written where the contest's name has to be asked for. It is expressed here as
   behaviour instead.

   THE LEGACY TESTS STAY IN PLACE, deliberately. RSTDomesticOrDXQTHExchange is
   still reached by Florida under /NOFACTORY, which is how test-contest-factory
   compares the two paths -- deleting them would make the A/B meaningless. They
   become removable when the legacy exporter does. *)
function TContestFloridaQP.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestFloridaQP.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aRSTSent: string): string;
begin
   Result := Format('%-3s %-7s', [aRSTSent, aMy.MyState]);
end;

function TContestFloridaQP.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aRSTReceived: string;
                                                const aHisQTH: string): string;
begin
   (* Reproduces the legacy decision tree exactly.  aHisQTH is what the
      exporter resolved from rx.QTHString, so the '' and 'DX' cases below are
      the same two the legacy arm tests. *)
   if aQso.QTHString = '' then
      begin
      if aQso.DXQTH = '' then
         begin
         Result := Format('%-3s %-7s', [aRSTReceived, 'DX']);
         end
      else
         begin
         Result := Format('%-3s %-7s', [aRSTReceived, string(aQso.QTH.Prefix)]);
         end;
      end
   else if aQso.QTHString = 'DX' then
      begin
      Result := Format('%-3s %-7s', [aRSTReceived, string(aQso.QTH.Prefix)]);
      end
   else
      begin
      Result := Format('%-3s %-7s', [aRSTReceived, aHisQTH]);
      end;
end;

function TContestFloridaQP.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange): string;
begin
   Result := Format('%-3d %-7s', [aQso.RSTSent, aMy.MyState]);
end;

initialization
   RegisterContest(FLORIDAQSOPARTY, TContestFloridaQP);

end.
