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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;

      (* AN EXCHANGE WITH NO PRECEDENCE IS REFUSED, AND SAYS SO -- M5b.

         NY4I, 2026-10-02 (design 7.10, Q19): "A sweepstakes entry should
         not have been logged without a precedence." The shape parser
         already refused such an exchange -- it accepts only when serial,
         precedence, check and section are all present -- but SILENTLY, so
         the operator saw a QSO that did not log and no reason. The
         precedence now names itself, the way an improper section does. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   SysUtils, uContestFixedPoints,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   (* ScanSweepstakesExchange -- the engine's own reading of the words. *)
   uExchangeTokens,
   uAppStrings,
   uTR4WStrings;

(* THE ENGINE'S PARSE FIRST, then the refusal's reason.

   ONLY WHEN THE SHAPE IS SWEEPSTAKES', the one that carries a precedence,
   and only when the parse refused. The precedence is looked for with
   uExchangeTokens.ScanSweepstakesExchange -- the same word reading the shape
   parser applies -- so this says "no precedence" exactly when the parser
   found none. An exchange refused for another reason (no check, a bad
   section) keeps whatever the parser said. *)
function TContestARRLSSBase.ParseReceivedExchange(const aText: string;
                                                  const aSession: TReceivedExchangeSession;
                                                  var aExch: ContestExchange;
                                                  out aErrorMessage: string): boolean;
var
   fields: TSweepstakesFields;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   if Result then
      begin
      Exit;
      end;
   if aSession.Exchange <> QSONumberPrecedenceCheckDomesticQTHExchange then
      begin
      Exit;
      end;

   ScanSweepstakesExchange(aText, fields);
   if fields.Prec = Chr(0) then
      begin
      aErrorMessage := SExchangeNoPrecedence;
      end;
end;

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

(* THE SECTION, FROM ARRL_SECT -- BUT AN ABSENT TAG IS NOT AN EMPTY SECTION.
   D7 writes ARRL_SECT for Sweepstakes and does not write it for Winter Field
   Day -- that log carries the section in <QTH> alone. Assigning it
   unconditionally ERASED a section the generic import had already read
   correctly, on 1310 of the 1316 QSOs in the corpus's winter_fd set. So
   ARRL_SECT wins when it is present, because it is the unambiguous field;
   otherwise whatever <QTH> supplied stands, and the domestic multiplier is
   taken from it. *)
procedure TContestARRLSSBase.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                             const aSession: TADIFImportSession;
                                             var aExch: ContestExchange);
begin
   if aTemps.ARRL_Sect <> '' then
      begin
      aExch.DomesticQTH := ShortString(aTemps.ARRL_Sect);
      aExch.QTHString   := ShortString(aTemps.ARRL_Sect);
      end
   else if aExch.QTHString <> '' then
      begin
      aExch.DomesticQTH := aExch.QTHString;
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named ARRLSSCW, ARRLSSSSB, one contest in two
   modes, so the family base holds it once. *)
procedure TContestARRLSSBase.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountries(DomesticCountriesARRLSections);

   aSession.CQExchangeCW := '_# ' + aStation.MyPrec + '  ' + aStation.MyCall
                            + '  ' + aStation.MyCheck + ' ' + aStation.MySection;
   aSession.SPExchangeCW := 'NR # ' + aStation.MyPrec + ' ' + aStation.MyCall
                            + ' ' + aStation.MyCheck + ' ' + aStation.MySection;
   aSession.RepeatSPExchangeCW := aSession.SPExchangeCW;
   aSession.QSLCW := '73 ' + aStation.MyCall + ' SS>';
   aSession.QSOBeforeCW := 'SRI QSO ' + aStation.MyCall + ' SS';
   aSession.QuickQSLCW1 := 'TU>';
   aSession.CallOkNowCW := '} R';

   aSession.SetCQMemory(CW, smkF1, 'SS ' + aStation.MyCall + ' SS>');
   aSession.SetCQMemory(CW, smkF2, 'CQ^SS ' + aStation.MyCall + ' ' + aStation.MyCall + ' SS>');
   aSession.SetCQMemory(CW, smkF3, 'CQ^SS CQ^SS ' + aStation.MyCall + ' ' + aStation.MyCall + ' SS>');
   aSession.SetCQMemory(CW, smkF7, '  CQ^SS ' + aStation.MyCall + ' SS');
   aSession.SetCQMemory(CW, smkF8, '  CQ^SS CQ^SS ' + aStation.MyCall + ' ' + aStation.MyCall + ' SS');

   (* The arm set Alt-F1 to 'CQ^SS \ SS' first and overwrote it with this. *)
   aSession.SetCQMemory(CW, smkAltF1, 'SS ' + aStation.MyCall + ' SS');
   aSession.SetCQMemory(CW, smkAltF2, 'CQ^SS cq^ss ' + aStation.MyCall + ' ' + aStation.MyCall + ' SS');
   aSession.SetCQMemory(CW, smkAltF3, 'CQ^SS cq^ss ' + aStation.MyCall + ' ' + aStation.MyCall + ' SS');

   aSession.SetExchangeMemory(CW, smkF3, 'NR #');
   aSession.SetExchangeMemory(CW, smkF4, aStation.MyPrec);
   aSession.SetExchangeMemory(CW, smkF5, aStation.MyCheck);
   aSession.SetExchangeMemory(CW, smkF6, aStation.MySection);
   aSession.SetExchangeMemory(CW, smkF7, '  CQ^SS ' + aStation.MyCall + ' SS');
   aSession.SetExchangeMemory(CW, smkF8, '  CQ^SS CQ^SS ' + aStation.MyCall + ' SS');

   aSession.SetExchangeMemory(CW, smkAltF3, 'NR?');
   aSession.SetExchangeMemory(CW, smkAltF4, 'PREC?');
   aSession.SetExchangeMemory(CW, smkAltF5, 'CK?');
   aSession.SetExchangeMemory(CW, smkAltF6, 'SEC?');
   (* The arm set Alt-F7 twice, to this value both times. *)
   aSession.SetExchangeMemory(CW, smkAltF7, ' CQ^SS CQ^SS ' + aStation.MyCall + ' ' + aStation.MyCall + ' SS');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   ARRLSSCW and ARRLSSSSB ran the same arms; they are
   one family under one rule, so the prompts are the family's. *)
procedure TContestARRLSSBase.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURPRECEDENCECHECKSECTION, ncfMyPrec);
   aPrompts.AskField(ncfMyCheck);
   aPrompts.AskField(ncfMySection);
end;

end.
