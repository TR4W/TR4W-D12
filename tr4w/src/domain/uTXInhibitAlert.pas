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

(* WHEN TO TELL THE OPERATOR THAT A KEY-UP IS NOT RADIATING -- issue #97.

  In CQ WW SSB 2026 a K4 was left in TX TEST mode: it keyed, the amplifier
  keyed, no RF went out, and nothing in TR4W said so.  The radio now reports
  the condition (phase 1, LogRadio.RadioTXInhibited).  This unit is the
  DECISION about it, and nothing else:

    * an alert exists only while the station is KEYED and the radio is
      inhibited -- nothing is shown while receiving, so it never nags;
    * it is raised at once when TR4W keys (trigger 1), without waiting for the
      radio to report TX, and also when the radio reports TX on its own
      (trigger 2: a footswitch or a mic PTT TR4W never saw);
    * it is WARNED ONCE PER KEY-UP -- one log line, one optional beep -- no
      matter how many pieces a message is sent in or how often the status is
      re-read;
    * it ends on unkey or when the condition clears.

  ONE INSTANCE PER RADIO SLOT, owned by the view (uTXInhibitView), which feeds
  it events and presents what it says.  No LCL, no radio record, no thread:
  every input is a parameter, so the whole rule is unit tested here.

  WHEN A KEY-UP TR4W STARTED ENDS.  The radio's own TX report is the clock: a
  key-up TR4W started stays a key-up until the radio has been SEEN transmitting
  and then seen receiving -- the same "saw TX" latch CW-by-CAT uses, for the
  same reason (an RX report can land between TR4W keying and the radio keying,
  and must not end a key-up that has not begun).  TR4W dropping PTT ends it
  too.  A radio that never reports TX at all would leave it open, so the view
  arms a one-shot wait and calls ProgramKeyExpired. *)
unit uTXInhibitAlert;

{$I ..\tr4w.inc}

interface

type
   (* WHAT THE PTT INDICATOR MEANS, as a role rather than a colour -- the view
     picks the colour (docs\COLOR_ROLES_DESIGN.md).  tirInhibited wins over
     tirTransmitting: an inhibited key-up is the one the operator must not
     mistake for an ordinary one. *)
   TTXIndicatorRole = (tirIdle, tirTransmitting, tirInhibited);

   TTXInhibitAlert = class(TObject)
   private
      FProgramKeyed: boolean;     (* TR4W keyed, and the key-up is not over *)
      FRadioTX: boolean;          (* the radio's last TX report *)
      FSawRadioTX: boolean;       (* seen transmitting during this key-up *)
      FInhibited: boolean;        (* the radio's last condition report *)
      FReason: string;
      FShowing: boolean;
      FWarningDue: boolean;       (* a key-up began showing; not yet taken *)
      FBeepEnabled: boolean;
      procedure Settle;
      function  GetAwaitingRadioTX: boolean;
      function  GetStatusText: string;
   public
      (* TRIGGER 1: TR4W is keying this radio now. *)
      procedure ProgramKeyed;
      (* TR4W dropped PTT on this radio. *)
      procedure ProgramUnkeyed;
      (* The one-shot wait ran out and the radio never reported TX: the key-up
        TR4W started is over, as far as this alert can tell. *)
      procedure ProgramKeyExpired;
      (* TRIGGER 2, and every other fact: what the radio's settled status says
        now.  aInhibited must already be False for a radio whose link is down
        -- the view decides that, because only it can see the link. *)
      procedure RadioReport(const aRadioTX, aInhibited: boolean;
                            const aReason: string);
      (* TRUE ONCE PER KEY-UP: the moment the alert began showing.  Taking it
        clears it, so a key-up that is re-read a hundred times logs once.
        aBeep is whether that warning should also beep (the setting). *)
      function  TakeKeyUpWarning(out aBeep: boolean): boolean;

      (* The alert is up: keyed AND inhibited. *)
      property Showing: boolean read FShowing;
      (* The radio's words, while Showing. *)
      property Reason: string read FReason;
      (* What the radio's status panel says while Showing. *)
      property StatusText: string read GetStatusText;
      (* TR4W keyed and the radio has not yet been seen transmitting -- the
        view's cue to arm the one-shot wait. *)
      property AwaitingRadioTX: boolean read GetAwaitingRadioTX;
      (* A key-up TR4W started is in progress (confirmed by the radio or not).
        The view lets further starts of the same key-up through without a
        review while this holds. *)
      property ProgramKeyUp: boolean read FProgramKeyed;
      (* Settings.Ptt.TxInhibitBeep, handed in by the view. *)
      property BeepEnabled: boolean read FBeepEnabled write FBeepEnabled;
   end;

(* THE PTT INDICATOR'S ROLE.  aPTTOn is the indicator's own PTT state;
  aInhibitAlert is whether any radio's alert is Showing. *)
function PTTIndicatorRole(const aPTTOn, aInhibitAlert: boolean): TTXIndicatorRole;

(* THE STATUS SENTENCE FROM A FORMAT AND THE RADIO'S WORDS -- and it cannot
  raise.  aFormat is STXInhibitedStatus, a TRANSLATABLE format string, and
  unreviewed translations ship (Make-LanguageRes embeds fuzzy entries), so a
  bad one -- a %d where the %s belongs -- would raise EConvertError on the
  keying path.  A format that will not take the reason falls back to the
  English sentence. *)
function TXInhibitedStatusText(const aFormat, aReason: string): string;

implementation

uses
   SysUtils,
   uAppStrings;    (* STXInhibitedStatus *)

function PTTIndicatorRole(const aPTTOn, aInhibitAlert: boolean): TTXIndicatorRole;
begin
   if aInhibitAlert then
      begin
      Result := tirInhibited;
      end
   else if aPTTOn then
      begin
      Result := tirTransmitting;
      end
   else
      begin
      Result := tirIdle;
      end;
end;

const
   (* The English of STXInhibitedStatus, for a translation that cannot be used.
     Kept in step by uTestTXInhibitAlert, which compares the two. *)
   TX_INHIBITED_STATUS_ENGLISH = 'TX INHIBITED: ';

function TXInhibitedStatusText(const aFormat, aReason: string): string;
begin
   try
      (* UnicodeFormat, not Format: FPC 3.2.2's SysUtils.Format takes an
        AnsiString format, so a native string would be narrowed on the way in. *)
      Result := UnicodeFormat(aFormat, [aReason]);
   except
      on E: Exception do
         begin
         Result := TX_INHIBITED_STATUS_ENGLISH + aReason;
         end;
   end;
end;

procedure TTXInhibitAlert.Settle;
var
   keyed: boolean;
begin
   keyed := FRadioTX or FProgramKeyed;

   if keyed and FInhibited then
      begin
      if not FShowing then
         begin
         FShowing := True;
         FWarningDue := True;
         end;
      end
   else
      begin
      FShowing := False;
      end;
end;

procedure TTXInhibitAlert.ProgramKeyed;
begin
   FProgramKeyed := True;
   Settle;
end;

procedure TTXInhibitAlert.ProgramUnkeyed;
begin
   FProgramKeyed := False;
   Settle;
end;

procedure TTXInhibitAlert.ProgramKeyExpired;
begin
   (* Only a key-up the radio never confirmed.  One it has been seen
     transmitting ends on its RX report, which is the better clock. *)
   if not FSawRadioTX then
      begin
      FProgramKeyed := False;
      end;
   Settle;
end;

procedure TTXInhibitAlert.RadioReport(const aRadioTX, aInhibited: boolean;
                                      const aReason: string);
begin
   if aRadioTX then
      begin
      FSawRadioTX := True;
      end
   else if FSawRadioTX then
      begin
      (* SEEN TRANSMITTING, NOW RECEIVING: the key-up is over, whoever began
        it.  An RX before any TX sighting is not an unkey -- the radio may not
        have keyed yet. *)
      FSawRadioTX := False;
      FProgramKeyed := False;
      end;

   FRadioTX := aRadioTX;
   FInhibited := aInhibited;
   if aInhibited then
      begin
      FReason := aReason;
      end
   else
      begin
      FReason := '';
      end;

   Settle;
end;

function TTXInhibitAlert.TakeKeyUpWarning(out aBeep: boolean): boolean;
begin
   Result := FWarningDue;
   FWarningDue := False;
   aBeep := Result and FBeepEnabled;
end;

function TTXInhibitAlert.GetAwaitingRadioTX: boolean;
begin
   Result := FProgramKeyed and (not FSawRadioTX);
end;

function TTXInhibitAlert.GetStatusText: string;
begin
   Result := '';
   if FShowing then
      begin
      Result := TXInhibitedStatusText(STXInhibitedStatus, FReason);
      end;
end;

end.
