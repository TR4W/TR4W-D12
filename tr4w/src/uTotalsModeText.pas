unit uTotalsModeText;

(* BOTH MODES IN ONE TOTALS CELL -- issue 55, NY4I's option (a), 2026-11-22.

  The main window's totals grid is four rows (uMainLayout.TOTALS_ROWS). Where a
  contest counts multipliers BY MODE (Settings.Mult.ByMode -- ARRL 10 Meter,
  most QSO parties), the grid used to show the multipliers of the ACTIVE mode
  only ('Ph Dom', 'Ph DX'): CW and SSB QSO rows plus both modes' domestic and
  DX multipliers are six values for four rows. Now one cell carries every
  shown mode, in the QSO rows' order (CW, phone, digital):

     CW/Ph Dom      12/6
     CW/Ph DX        3/2

  WHICH modes are shown is uTotal's question (ChooseTotalsMultModes): the
  active mode, plus every other credited mode with QSOs, folded by the
  multiplier sheet's slot. This unit only words the answer.

  THE RULES:
  - One count is exactly what the cell always showed: '' for 0, else the
    number. So a contest that shows one mode is unchanged, byte for byte.
  - Several counts: '' when every one is 0 (as one zero is blank); otherwise
    EVERY count, zeros included ('0/6', '12/0'), because the position is what
    says which mode a number belongs to.
  - The caption joins the mode tags ('CW/Ph') in front of what the contest's
    per-mode captions share after their own tag: 'CW Dom' and 'Ph Dom' share
    'Dom'. When the two captions do not follow the 'CW x' / 'Ph x' shape, the
    contest's all-modes caption is used instead -- never a guessed word.

  THE TAGS ARE LITERALS, as the per-mode captions beside them are ('CW Dom',
  'Ph Dom' in uContestBase.GetTotalsDisplay): mode abbreviations, not prose.

  NO LCL: the cell's width is fitted by the cell (TElementPanel.FitCaption,
  font shrink to its floor, a logged report when it shrinks).
  uTestTotalsModeText pins every rule here and measures '123/456' in the
  narrowest All-column cell through that same fit. *)

{$I tr4w.inc}

interface

const
   (* Between two modes' numbers and between two modes' tags. *)
   TOTALS_MODE_SEPARATOR = '/';

   (* The mode tags, in the order the QSO rows above the multipliers use. *)
   TOTALS_TAG_CW      = 'CW';
   TOTALS_TAG_PHONE   = 'Ph';
   TOTALS_TAG_DIGITAL = 'Dig';

(* The cell text for one multiplier row: one count per shown mode, in order.
  See the rules above. An empty list is ''. *)
function TotalsModeCountsText(const aCounts: array of integer): string;

(* The row label for several shown modes: the joined tags, a space, and the
  word aCWCaption and aPhoneCaption share after 'CW ' and 'Ph '. aFallback
  (the contest's all-modes caption) when they share none, or when either
  does not start with its tag and a space. *)
function TotalsByModeCaption(const aTags: array of string;
                             const aCWCaption, aPhoneCaption, aFallback: string): string;

implementation

uses
   SysUtils;

function TotalsModeCountsText(const aCounts: array of integer): string;
var
   i: integer;
   anyCounted: boolean;
begin
   Result := '';

   anyCounted := False;
   for i := Low(aCounts) to High(aCounts) do
      begin
      if aCounts[i] <> 0 then
         begin
         anyCounted := True;
         end;
      end;

   if not anyCounted then
      begin
      Exit;
      end;

   for i := Low(aCounts) to High(aCounts) do
      begin
      if i > Low(aCounts) then
         begin
         Result := Result + TOTALS_MODE_SEPARATOR;
         end;
      Result := Result + IntToStr(aCounts[i]);
      end;
end;

(* What aCaption says after aTag and one space; '' when it does not start so,
  or says nothing after it. *)
function WordAfterTag(const aCaption, aTag: string): string;
var
   lead: string;
begin
   Result := '';
   lead := aTag + ' ';
   if (Length(aCaption) > Length(lead)) and
      (Copy(aCaption, 1, Length(lead)) = lead) then
      begin
      Result := Copy(aCaption, Length(lead) + 1, MaxInt);
      end;
end;

function TotalsByModeCaption(const aTags: array of string;
                             const aCWCaption, aPhoneCaption, aFallback: string): string;
var
   i: integer;
   shared: string;
   tags: string;
begin
   shared := WordAfterTag(aCWCaption, TOTALS_TAG_CW);

   if (shared = '') or
      (WordAfterTag(aPhoneCaption, TOTALS_TAG_PHONE) <> shared) or
      (Length(aTags) = 0) then
      begin
      Result := aFallback;
      Exit;
      end;

   tags := '';
   for i := Low(aTags) to High(aTags) do
      begin
      if i > Low(aTags) then
         begin
         tags := tags + TOTALS_MODE_SEPARATOR;
         end;
      tags := tags + aTags[i];
      end;

   Result := tags + ' ' + shared;
end;

end.
