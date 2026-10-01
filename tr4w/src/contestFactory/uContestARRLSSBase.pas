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
  the CW running of it, and they will land here. Writing the two points twice
  in two unrelated classes would leave nowhere for them to go.

  ON TContestBase SINCE M3 (2026-10-01). It descended from TContestFixedPoints,
  a mechanism base that retired then (CONTEST_OWNERSHIP_DESIGN.md 1.5): the
  rule is stated here, as the family's, with FixedModePoints as the helper.
  The legacy arm is TwoPointsPerQSO -- 2 on every mode, digital included. *)
unit uContestARRLSSBase;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLSSBase = class(TContestBase)
   protected
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

   public
      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
   end;

implementation

uses
   SysUtils, uContestFixedPoints,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF;

procedure TContestARRLSSBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 2, 2, 2);
end;

(* THE SWEEPSTAKES EXCHANGE: SERIAL, PRECEDENCE, CHECK, SECTION.

   FOUR FIELDS AND NONE OF THEM RST -- Sweepstakes is the contest that does not
   send a signal report at all, which is why aCtx.RSTSent and aCtx.RSTReceived are
   accepted and deliberately unused here. The base passes them to every contest;
   this one has nowhere to put them.

   `%.2u` ON THE RECEIVED CHECK IS LOAD-BEARING. A check is the last two digits
   of the year first licensed, so 1959 sends "59" and 2007 sends "07" -- and
   `%u` would print that as "7". The sent side is a string and carries its own
   zero.

   nrReceived = -1 BECOMES 0, reproduced from the legacy arm. -1 is the
   "no serial" sentinel and `%-4d` would print it as "-1", four columns of
   nonsense in a field a scorer parses as a number.

   THE SHARED ARM IS GONE (M4, 2026-10-01; inventory D4). Only Sweepstakes
   runs QSONumberPrecedenceCheckDomesticQTHExchange, and it formats its own;
   QSONumberAndNameExchange, which an older note here said fell into that arm,
   has an arm of its own in both exporters. *)
function TContestARRLSSBase.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-4d %s %s %-3s ',
                    [aQso.NumberSent, aMy.MyPrec, aMy.MyCheck, aMy.MySection]);
end;

(* THE RECEIVED PRECEDENCE COLUMN -- AND NEVER A NUL. Defect #4 of the M0
   matrix (design 8.2a), FIXED AT M4, 2026-10-01.

   The precedence is one AnsiChar, and a QSO that has none holds #0 there --
   the parser never filled it. string(#0) is not an empty string, it is a
   one-character string holding a NUL, and the Cabrillo line carried that
   byte straight into a file a robot scorer reads. A NUL in a text file is
   at best a stray character and at worst the end of the line, depending on
   the reader.

   WHAT TO WRITE INSTEAD IS A BLANK, ONE COLUMN WIDE. The Cabrillo
   Sweepstakes template has no "absent" spelling for a precedence -- a log
   without one is a broken QSO, not a different format -- so this writes the
   least that is still a well-formed line: the column stays one character
   wide, and every later column lands where it would have. Whether a QSO
   with no precedence should be exported at all, or marked X-QSO, is a
   sponsor question recorded for NY4I (design 8.2e); it is not answered by
   inventing a letter. *)
function PrecedenceColumn(aPrecedence: AnsiChar): string;
begin
   if aPrecedence = #0 then
      begin
      Result := ' ';
      end
   else
      begin
      Result := string(aPrecedence);
      end;
end;

function TContestARRLSSBase.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
begin
   (* THE SECTION COMES FROM aCtx.HisQTH, which is what the exporter resolved for
      this QSO -- the legacy arm formats csQTHString here, not rx.QTHString. *)
   if aQso.NumberReceived = -1 then
      begin
      Result := Format('%-4d %s %.2u %-3s',
                       [0, PrecedenceColumn(aQso.Precedence), aQso.Check, aCtx.HisQTH]);
      end
   else
      begin
      Result := Format('%-4d %s %.2u %-3s',
                       [aQso.NumberReceived, PrecedenceColumn(aQso.Precedence), aQso.Check,
                        aCtx.HisQTH]);
      end;
end;

function TContestARRLSSBase.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                   const aQso: ContestExchange;
                                                   aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-4d %s %s %-3s ',
                    [aQso.NumberSent, aMy.MyPrec, aMy.MyCheck, aMy.MySection]);
end;

(* THE WORKED STATION'S SECTION GOES TO ADIF ARRL_SECT -- M4, 2026-10-01,
   the Sweepstakes arm of postunit's EmitContestSpecificTailForExport, moved
   here. A DX station's 'DX' is not a section and writes nothing, as the arm
   had it. *)
function TContestARRLSSBase.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := '';
   if aQso.QTHString <> 'DX' then
      begin
      Result := EmitADIFField('ARRL_SECT', string(aQso.QTHString));
      end;
end;

end.
