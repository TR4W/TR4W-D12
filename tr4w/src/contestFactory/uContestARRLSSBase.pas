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

(* ARRL SWEEPSTAKES -- what CW and Phone share.

  TWO POINTS A QSO, EITHER MODE. Sweepstakes puts all of its difficulty in the
  exchange -- serial, precedence, check, section, in one string -- and none of
  it in the scoring.

  A BASE FOR TWO NUMBERS LOOKS LIKE CEREMONY AND IS NOT. TR4QT has ARRLSSBase
  for the same pair, and the reason shows the moment anything beyond scoring
  moves in: the exchange parser, the section list, the "you may work a station
  once per contest regardless of band" rule. Those belong to Sweepstakes, not to
  the CW running of it, and they will land here. Writing SetPoints(2, 2) twice
  in two unrelated classes would leave nowhere for them to go. *)
unit uContestARRLSSBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase, uContestFixedPoints;

type
   TContestARRLSSBase = class(TContestFixedPoints)
   protected
      function GetFormatsExchange: boolean; override;

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
   SysUtils;

constructor TContestARRLSSBase.Create(aContest: ContestType);
begin
   inherited Create(aContest);
   SetPoints(2, 2);
end;

(* THE SWEEPSTAKES EXCHANGE: SERIAL, PRECEDENCE, CHECK, SECTION.

   FOUR FIELDS AND NONE OF THEM RST -- Sweepstakes is the contest that does not
   send a signal report at all, which is why aRSTSent and aRSTReceived are
   accepted and deliberately unused here. The base passes them to every contest;
   this one has nowhere to put them.

   `%.2u` ON THE RECEIVED CHECK IS LOAD-BEARING. A check is the last two digits
   of the year first licensed, so 1959 sends "59" and 2007 sends "07" -- and
   `%u` would print that as "7". The sent side is a string and carries its own
   zero.

   nrReceived = -1 BECOMES 0, reproduced from the legacy arm. -1 is the
   "no serial" sentinel and `%-4d` would print it as "-1", four columns of
   nonsense in a field a scorer parses as a number.

   THE SHARED ARM STAYS. QSONumberPrecedenceCheckDomesticQTHExchange has
   QSONumberAndNameExchange falling into it in both exporters, so other contests
   reach this body; only Sweepstakes has been lifted out of it. *)
function TContestARRLSSBase.GetFormatsExchange: boolean;
begin
   Result := True;
end;

function TContestARRLSSBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                            const aQso: ContestExchange;
                                            const aRSTSent: string): string;
begin
   Result := Format('%-4d %s %s %-3s ',
                    [aQso.NumberSent, aMy.MyPrec, aMy.MyCheck, aMy.MySection]);
end;

function TContestARRLSSBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                const aQso: ContestExchange;
                                                const aRSTReceived: string;
                                                const aHisQTH: string): string;
begin
   (* THE SECTION COMES FROM aHisQTH, which is what the exporter resolved for
      this QSO -- the legacy arm formats csQTHString here, not rx.QTHString. *)
   if aQso.NumberReceived = -1 then
      begin
      Result := Format('%-4d %s %.2u %-3s',
                       [0, string(aQso.Precedence), aQso.Check, aHisQTH]);
      end
   else
      begin
      Result := Format('%-4d %s %.2u %-3s',
                       [aQso.NumberReceived, string(aQso.Precedence), aQso.Check, aHisQTH]);
      end;
end;

function TContestARRLSSBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                        const aQso: ContestExchange): string;
begin
   Result := Format('%-4d %s %s %-3s ',
                    [aQso.NumberSent, aMy.MyPrec, aMy.MyCheck, aMy.MySection]);
end;

end.
