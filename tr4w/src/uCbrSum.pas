{
 Copyright Dmitriy Gulyaev UA4WLI 2015.

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
 }
unit uCbrSum;
{$I tr4w.inc}
{$IMPORTEDDATA OFF}

(*
  THE CABRILLO HEADER'S TAG TABLE, and the seam to the window that edits it.

  The Win32 dialog that used to live here -- CreateCabrilloDlgProc, a
  CreateModalDialog template and forty-two controls built in WM_INITDIALOG --
  is GONE, replaced by ui\lcl\uCabrilloSummaryForm.  What stays is what the
  dialog was a view of: the twenty-one header tags, whether each is a list or
  free text, whether it persists, and the category values each list offers.

  READING THE WINDOW FROM ELSEWHERE.  PostUnit needs the operator's answers
  while an export runs, and it used to get them with GetDlgItemTextA against a
  global HWND and a control id it computed itself as Ord(tag) + 200.  That is
  the trap CLAUDE.md records for uServerLogForm -- a control written from a unit
  with no other relationship to the window -- and it also meant the interactive
  path and headless /EXPORT read the header through two different pieces of
  code, which had already drifted once.  CabrilloTagText answers both: the live
  window when it is open, the header store when it is not.
*)

interface

uses
  VC,             { tCertificate }
  uSettingsModel, { the Cabrillo category enums and their spelling tables }
  PostUnit;    { StationCategory, TimeCategory, OverlayCategory, ... }

type
  { WHAT OK DOES.  Parameterless because each of the three exports takes its
    inputs from this window and the log, never from an argument -- the callers
    used to pass integer(@CreateCabrilloFile) in an lParam and the dialog called
    it back through an untyped Pointer. }
  TCabrilloSummaryAction = procedure;

  CabrilloTags =
    (
    ctCategoryAssisted,
    ctCategoryBand,
    ctCategoryMode,
    ctCategoryOperator,
    ctCategoryPower,
    ctCategoryStation,
    ctCategoryTime,
    ctCategoryTransmitter,
    ctCategoryOverlay,
    ctCertificate,
    ctOperators,
    ctClub,
    ctLocation,
    ctName,
    ctAddress,
    ctAddressCity,
    ctAddressStateProvince,
    ctAddressPostalcode,
    ctAddressCountry,
    ctEmail,
    ctSoapbox
//    ctRig,
//    ctAntennas
    );

  TCabrilloTagRecord = record
    ctrTag: string;
    ctrCFG: boolean; //do not used
    ctrSave: boolean;

    { Does this tag offer a list of values? }
    ctrList: boolean;

    { IS THAT LIST A SUGGESTION RATHER THAN THE WHOLE SET?

      Cabrillo v3 gives each category a fixed set of legal values, and for most
      of them that is the end of it.  CATEGORY-TRANSMITTER is different in
      practice: sponsors commonly ask for a value that is not in the published
      list (NY4I, 2026-09-01), so a closed drop-down cannot express what the
      sponsor asked for, and a plain edit throws away the five values that are
      right most of the time.

      ctrOpen makes the row an EDITABLE combo -- seeded with the official list,
      accepting anything typed.  The cost is typos, and that is the deliberate
      trade: a log the sponsor rejects for a typo beats a log that cannot state
      what the sponsor asked for at all.

      Only CATEGORY-TRANSMITTER is open today.  Opening another is this one
      word -- CATEGORY-STATION, CATEGORY-OVERLAY and CATEGORY-TIME are the
      likely next candidates and are left closed until someone hits one. }
    ctrOpen: boolean;
  end;

(* THE VALUES A CABRILLO CATEGORY TAG OFFERS.

  WAS A TABLE OF POINTERS -- `cvrStart: PAnsiChar` plus a count -- which the
  summary dialog walked with a ^PAnsiChar and Inc(). NY4I, 2026-09-13: "we
  don't need pointers."

  A FUNCTION, NOT A CONST TABLE, because the answer now comes from arrays of
  string that live in two different units, and a const record cannot hold a
  dynamic array. It is also the honest shape: a tag either offers a list or it
  does not, and the empty result says which without a bounds test at the call
  site.

  THE SIX THAT ARE SETTINGS COME FROM THE SETTINGS TABLES, so the dialog, the
  drop-down and the refusal read one vocabulary. The other three are Cabrillo
  header vocabularies with no setting behind them and come from PostUnit.

  EVERY CATEGORY LIST ENDS IN '' -- "no category stated" (NY4I, 2026-10-29:
  none of the CATEGORY-* fields is required). For the five settings it is the
  *UNSET member's own spelling; for the four PostUnit lists it is added here,
  so PostUnit's const arrays and their Number* counts are untouched. LAST, so
  a drop-down's positions still match the enum's ordinals. *)
function CategoryValuesFor(const aTag: CabrilloTags): TArray<string>;

(* IS THIS ONE OF THE NINE CATEGORY-* TAGS? Their header line is written even
  when the value is blank; every other tag's is left out when blank. *)
function CabrilloTagIsCategory(const aTag: CabrilloTags): boolean;

(* ONE HEADER LINE, CR LF ENDED, OR '' FOR "WRITE NOTHING".

  A value gives 'TAG: value'. A BLANK CATEGORY gives the bare tag and colon --
  'CATEGORY-OVERLAY:', no trailing space -- because the operator chose "no
  category" and the sponsor still reads the line (NY4I, 2026-10-29). Any other
  blank tag (CLUB, EMAIL, ...) gives '', as it always has. OPERATORS is not
  written through this: PostUnit continues it over several lines. *)
function CabrilloHeaderTagLine(const aTag: CabrilloTags;
                               const aValue: string): string;

const
 // 4.72.8 allow most tags to save to tr4w.ini in settings, allowing preload
  CabrilloTagsArray                     : array[CabrilloTags] of TCabrilloTagRecord =
    (
{(*}
    // NONE OF THE FIVE CATEGORIES BELOW IS SAVED HERE (Q61, as M9b did for
    // POWER): each is ONE contest-scoped setting, Settings.Contest.Category*,
    // whose home is the contest database -- see CabrilloTagText. MODE was
    // the one still copied into settings\tr4w.json; a '_CATEGORY-MODE' left
    // there is inert.
    (ctrTag: '_CATEGORY-ASSISTED';      ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-BAND';          ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-MODE';          ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-OPERATOR';      ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-POWER';         ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-STATION';       ctrCFG:False; ctrSave: True; ctrList: True; ctrOpen: False), // Issue #976: now a drop-down
    (ctrTag: '_CATEGORY-TIME';          ctrCFG:True;  ctrSave: True; ctrList: True; ctrOpen: False),  // Issue #976: persist + restore selection
    // Cabrillo v3 publishes ONE/TWO/LIMITED/UNLIMITED/SWL here, and sponsors
    // routinely ask for something else -- so this is the one EDITABLE list:
    // seeded with the official five, accepting anything typed (NY4I,
    // 2026-09-01).  It was a plain edit, which offered the operator nothing.
    (ctrTag: '_CATEGORY-TRANSMITTER';   ctrCFG:False; ctrSave: True; ctrList: True;  ctrOpen: True),
    (ctrTag: '_CATEGORY-OVERLAY';       ctrCFG:True;  ctrSave: True; ctrList:  True; ctrOpen: False),  // Issue #976: persist + restore selection
    (ctrTag: '_CERTIFICATE';            ctrCFG:True;  ctrSave: True; ctrList: False; ctrOpen: False),
    (ctrTag: '_OPERATORS';              ctrCFG:True;  ctrSave: False; ctrList: False; ctrOpen: False), // derived from the log, not stored
    (ctrTag: '_CLUB';                   ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_LOCATION';               ctrCFG:True;  ctrSave: True; ctrList: False; ctrOpen: False),
    (ctrTag: '_NAME';                   ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_ADDRESS';                ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_ADDRESS-CITY';           ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_ADDRESS-STATE-PROVINCE'; ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_ADDRESS-POSTALCODE';     ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_ADDRESS-COUNTRY';        ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_EMAIL';                  ctrCFG:False; ctrSave: True;  ctrList: False; ctrOpen: False),
    (ctrTag: '_SOAPBOX';                ctrCFG:True;  ctrSave: False; ctrList: False; ctrOpen: False)
//    (ctrTag: '_RIG';                    ctrCFG:False; ctrSave: True;  ctrList: False),
//    (ctrTag: '_ANTENNAS';               ctrCFG:False; ctrSave: True;  ctrList: False)
{*)}
    );

// Open the station-information window.  aOnAccept is what OK runs -- the
// Cabrillo writer, the summary sheet or the EDI export -- or nil when the
// window is opened on its own to edit the header (Issue #914).
//
// THE SEAM.  The caller does not know what this is, only that the window opens.
// When the Win32 dialog became an LCL form this body changed and no call site
// did.
procedure ShowCreateCabrillo(const aOnAccept: TCabrilloSummaryAction);

// One header tag's current value: from the window when it is open, from
// settings\tr4w.json when it is not.
//
// THE FALLBACK IS THE WHOLE POINT.  Headless /EXPORT never opens the window,
// and reading a control id off a zero HWND returned empty -- which aborted
// every Winter Field Day and ARRL10 batch export on the LOCATION guard, in
// silence.  PostUnit grew a private version of this fork to fix that; it is
// here now so there is one.
function CabrilloTagText(const aTag: CabrilloTags): string;

// A list tag's selected index, or -1.  Only meaningful while the window is
// open: the store holds text, not positions.
function CabrilloTagItemIndex(const aTag: CabrilloTags): integer;

function CabrilloSummaryIsOpen: boolean;

// Bring the window forward, if it is up.
procedure FocusCabrilloSummaryWindow;

implementation

uses
  uCabrilloHeader,          { the header store, settings\tr4w.json }
  uOperatorList,            (* OperatorListFromLog -- the OPERATORS answer *)
  uCabrilloSummaryForm;

(* ONE HELPER, because the six settings tables and the three PostUnit ones are
  the same shape once they are strings: copy the table into the result. *)
function ValuesOf(const aTable: array of string): TArray<string>;
var
   i: integer;
begin
   SetLength(Result, Length(aTable));
   for i := 0 to High(aTable) do
      begin
      Result[i] := aTable[i];
      end;
end;

(* A PostUnit header vocabulary with the blank "no category" choice after it.
  The five setting tables carry theirs already, as the *UNSET spelling. *)
function ValuesWithBlank(const aTable: array of string): TArray<string>;
begin
   Result := ValuesOf(aTable);
   SetLength(Result, Length(Result) + 1);
   Result[High(Result)] := '';
end;

function CategoryValuesFor(const aTag: CabrilloTags): TArray<string>;
begin
   (* NOT EVERY LISTED TAG HAS ONE. The old table stopped at ctCategoryOverlay
     and the caller had to bounds-test before indexing it; an empty result
     says the same thing without that. *)
   Result := nil;

   case aTag of
      ctCategoryAssisted:    Result := ValuesOf(tCategoryAssistedSA);
      ctCategoryBand:        Result := ValuesOf(tCategoryBandSA);
      ctCategoryMode:        Result := ValuesOf(tCategoryModeSA);
      ctCategoryOperator:    Result := ValuesOf(tCategoryOperatorSA);
      ctCategoryPower:       Result := ValuesOf(tCategoryPowerSA);
      (* THE TRANSMITTER LIST CAME FROM PostUnit, NOT FROM THE SETTINGS TABLE,
        and it still does. The two are identical today -- ONE, TWO, LIMITED,
        UNLIMITED, SWL, then the blank -- but they are separate statements of
        the vocabulary and merging them is a decision about the Cabrillo
        header, not a side effect of removing a pointer. *)
      ctCategoryTransmitter: Result := ValuesWithBlank(TransmitterCategory);
      ctCategoryStation:     Result := ValuesWithBlank(StationCategory);
      ctCategoryTime:        Result := ValuesWithBlank(TimeCategory);
      ctCategoryOverlay:     Result := ValuesWithBlank(OverlayCategory);
   end;
end;

function CabrilloTagIsCategory(const aTag: CabrilloTags): boolean;
begin
   Result := aTag in [ctCategoryAssisted..ctCategoryOverlay];
end;

function CabrilloHeaderTagLine(const aTag: CabrilloTags;
                               const aValue: string): string;
var
   tagName: string;
begin
   (* THE TAG WITHOUT ITS LEADING '_', which marks each entry in
     CabrilloTagsArray. *)
   tagName := Copy(CabrilloTagsArray[aTag].ctrTag, 2, MaxInt);

   if aValue <> '' then
      begin
      Result := tagName + ': ' + aValue + #13#10;
      end
   else if CabrilloTagIsCategory(aTag) then
      begin
      Result := tagName + ':' + #13#10;
      end
   else
      begin
      Result := '';
      end;
end;

// Both header sections live in settings\tr4w.json: [REPORT] moved 2026-08-16
// because it was the last thing keeping tr4w.ini load-bearing -- delete the ini
// and every Winter Field Day / ARRL10 export aborted in silence -- and
// [ERMAKREPORT] followed on 2026-08-17 (NY4I: "Nothing should use the INI file
// again").
//
// The section is not a fork in the storage any more, only an argument:
// uCabrilloHeader treats the two alike.

procedure ShowCreateCabrillo(const aOnAccept: TCabrilloSummaryAction);
begin
   ShowCabrilloSummary(aOnAccept);
end;

function CabrilloSummaryIsOpen: boolean;
begin
   Result := CabrilloSummaryOpen;
end;

procedure FocusCabrilloSummaryWindow;
begin
   FocusCabrilloSummary;
end;

function CabrilloTagText(const aTag: CabrilloTags): string;
var
   section: string;
begin
   (* OPERATORS IS THE LOG'S, NEVER A TYPED OR STORED VALUE -- NY4I, CQ WW SSB
     2026. The Cabrillo header already overrode the saved field, but the 3830
     report and the summary sheet printed it, so a multi-op log said 'NY4I'.
     One routine now (uOperatorList): contacts only, most first. It reads the
     log, so call this when no other reader has the log source open. *)
   if aTag = ctOperators then
      begin
      Result := OperatorListFromLog;
      Exit;
      end;

   if CabrilloSummaryOpen then
      begin
      Result := CabrilloSummary.TagText(aTag);
      Exit;
      end;

   (* CATEGORY-POWER IS THE SETTING, NOT A HEADER-STORE COPY -- M9b, design
     7.6 (NY4I: the last touch point wins). It had two stores: this one's
     '_CATEGORY-POWER', written by the summary window, and
     Settings.Contest.CategoryPower, written by the New Contest dialog and read
     by scoring. They disagreed in the golden corpus -- arrl_digi's log says
     LOW, its Cabrillo header said HIGH -- so a Winter Field Day header could
     declare one power while the score used another. The window now writes
     the setting, and everything that reads the header reads the setting. A
     '_CATEGORY-POWER' left in settings\tr4w.json is inert. *)
   (* AND ASSISTED, BAND, MODE AND OPERATOR THE SAME WAY -- Q61 (NY4I,
     2026-10-16: "Yes."). Each had the two-store shape POWER had: the window
     started from the setting, then wrote MODE to the header store and the
     other three nowhere, so a headless /EXPORT -- which never opens the
     window -- read a stale MODE and NO assisted, band or operator line at
     all (SQLITE_LOG_SCHEMA_PLAN.md 12c). One value each now, a contest-scoped
     setting whose home is the contest database. *)
   case aTag of
      ctCategoryAssisted:
         begin
         Result := tCategoryAssistedSA[Settings.Contest.CategoryAssisted];
         Exit;
         end;
      ctCategoryBand:
         begin
         Result := tCategoryBandSA[Settings.Contest.CategoryBand];
         Exit;
         end;
      ctCategoryMode:
         begin
         Result := tCategoryModeSA[Settings.Contest.CategoryMode];
         Exit;
         end;
      ctCategoryOperator:
         begin
         Result := tCategoryOperatorSA[Settings.Contest.CategoryOperator];
         Exit;
         end;
      ctCategoryPower:
         begin
         Result := tCategoryPowerSA[Settings.Contest.CategoryPower];
         Exit;
         end;
   end;

   if ErmakSpecification then
      begin
      section := ERMAKSECTION;
      end
   else
      begin
      section := CABRILLOSECTION;
      end;

   Result := HeaderValue(section, CabrilloTagsArray[aTag].ctrTag);
end;

function CabrilloTagItemIndex(const aTag: CabrilloTags): integer;
begin
   if CabrilloSummaryOpen then
      begin
      Result := CabrilloSummary.TagItemIndex(aTag);
      end
   else
      begin
      Result := -1;
      end;
end;

end.
