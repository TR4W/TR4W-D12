unit uEntryStatus;

(* WHAT THE ENTRY AREA SAYS ABOUT THE LOG -- the UI refresh proposal's "Save
  and status feedback" (docs/TR4W_UI_REFRESH_PROPOSAL.md), 2026-11-22.

  One panel in the bottom band, pnlEntryStatus (uMainForm), shows one of three
  states:

    eskNone      nothing; the panel is hidden. A committed contact is
                 confirmed by the log grid's new row, NEVER by this panel, so
                 it can never say "saved" before the commit.
    eskRefused   the last Enter was refused (MainUnit.TryLogContact's refused
                 branch, where QSOSaveRefused is set) and the operator has
                 neither saved a contact since nor discarded the entry. It
                 outlives every unrelated notice on the quick-command line:
                 only a save or a discard clears it.
    eskReadOnly  the log is read-only (uLogStore.LogStoreIsReadOnly) and no
                 refusal is showing: the log's condition, between entries,
                 until the store recovers.

  A REFUSAL WINS OVER READ-ONLY: it is about the contact on screen, and the
  store's reason text (LogStoreNotSavedText) already says "read-only" when
  that is why.

  A DISCARD IS BOTH FIELDS BLANK. The exchange field holds a single space as
  a keying state (search and pounce, see lcl-ui.md), so blank means "nothing
  but spaces", not "empty".

  NO LCL AND NO STORE: MainUnit.RefreshEntryStatus reads the store and the
  fields and hands the answers in. uTestEntryStatus pins every rule. *)

{$I tr4w.inc}

interface

type
   TEntryStatusKind = (eskNone, eskRefused, eskReadOnly);

(* Which state the panel shows: a refusal still showing, else read-only, else
  none. *)
function EntryStatusKind(const aRefusalShown, aLogReadOnly: boolean): TEntryStatusKind;

(* Whether a refusal that was showing still shows, now that the fields hold
  aCallText and aExchangeText: True while it was showing and either field
  holds more than blanks. A refusal that was not showing never starts here --
  only the refused save starts one. *)
function RefusalStillShown(const aRefusalShown: boolean;
                           const aCallText, aExchangeText: string): boolean;

(* The panel's first line for aKind; '' for eskNone. *)
function EntryStatusHeadline(const aKind: TEntryStatusKind): string;

(* The panel's whole text: the headline, then the store's reason on the next
  line when there is one. '' for eskNone, whatever aReason holds. *)
function EntryStatusText(const aKind: TEntryStatusKind; const aReason: string): string;

implementation

uses
   SysUtils,
   uAppStrings;

function EntryStatusKind(const aRefusalShown, aLogReadOnly: boolean): TEntryStatusKind;
begin
   if aRefusalShown then
      begin
      Result := eskRefused;
      end
   else if aLogReadOnly then
      begin
      Result := eskReadOnly;
      end
   else
      begin
      Result := eskNone;
      end;
end;

function RefusalStillShown(const aRefusalShown: boolean;
                           const aCallText, aExchangeText: string): boolean;
begin
   Result := aRefusalShown and
             ((Trim(aCallText) <> '') or (Trim(aExchangeText) <> ''));
end;

function EntryStatusHeadline(const aKind: TEntryStatusKind): string;
begin
   case aKind of
      eskRefused:
         begin
         Result := SEntryStatusQsoNotSaved;
         end;
      eskReadOnly:
         begin
         Result := SEntryStatusLogReadOnly;
         end;
      else
         begin
         Result := '';
         end;
   end;
end;

function EntryStatusText(const aKind: TEntryStatusKind; const aReason: string): string;
begin
   Result := EntryStatusHeadline(aKind);
   if (Result <> '') and (Trim(aReason) <> '') then
      begin
      Result := Result + LineEnding + Trim(aReason);
      end;
end;

end.
