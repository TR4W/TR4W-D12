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
  VC,          { tCategoryAssistedSA and the other category enums }
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

  TCategoriesValuesRecord = record
    cvrStart: PAnsiChar;
    cvrCount: integer;
  end;

  TCabrilloTagRecord = record
    ctrTag: PAnsiChar;
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

const

    CategoriesArray                       : array[ctCategoryAssisted..ctCategoryOverlay] of TCategoriesValuesRecord =
   //    CategoriesArray                       : array[0..8] of TCategoriesValuesRecord =
    (
{   ctCategoryAssisted    }(cvrStart: @tCategoryAssistedSA; cvrCount: integer(High(tCategoryAssisted))),
{   ctCategoryBand        }(cvrStart: @tCategoryBandSA; cvrCount: integer(High(tCategoryBand))),
{   ctCategoryMode        }(cvrStart: @tCategoryModeSA; cvrCount: integer(High(tCategoryMode))),
//{   ctCertificate         }(cvrStart: @tCertificateSA; cvrCount: integer(High(tCertificate))),
{   ctCategoryOperator    }(cvrStart: @tCategoryOperatorSA; cvrCount: integer(High(tCategoryOperator))),
{   ctCategoryPower       }(cvrStart: @tCategoryPowerSA; cvrCount: integer(High(tCategoryPower))),
{   ctCategoryStation     }(cvrStart: @StationCategory; cvrCount: NumberStationCategories - 1),
{   ctCategoryTime        }(cvrStart: @TimeCategory; cvrCount: NumberTimeCategories - 1),
{   ctCategoryTransmitter }(cvrStart: @TransmitterCategory; cvrCount: NumberTransmitterCategories - 1),
{   ctCategoryOverlay     }(cvrStart: @OverlayCategory; cvrCount: NumberOverlayCategories - 1)
    );

 // 4.72.8 allow most tags to save to tr4w.ini in settings, allowing preload
  CabrilloTagsArray                     : array[CabrilloTags] of TCabrilloTagRecord =
    (
{(*}
    (ctrTag: '_CATEGORY-ASSISTED';      ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-BAND';          ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-MODE';          ctrCFG:True;  ctrSave: True; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-OPERATOR';      ctrCFG:True;  ctrSave: False; ctrList: True; ctrOpen: False),    // ny4i changed this since we dete3rmine from the log
    (ctrTag: '_CATEGORY-POWER';         ctrCFG:True;  ctrSave: True; ctrList: True; ctrOpen: False),
    (ctrTag: '_CATEGORY-STATION';       ctrCFG:False; ctrSave: True; ctrList: True; ctrOpen: False), // Issue #976: now a drop-down
    (ctrTag: '_CATEGORY-TIME';          ctrCFG:True;  ctrSave: True; ctrList: True; ctrOpen: False),  // Issue #976: persist + restore selection
    // Cabrillo v3 publishes ONE/TWO/LIMITED/UNLIMITED/SWL here, and sponsors
    // routinely ask for something else -- so this is the one EDITABLE list:
    // seeded with the official five, accepting anything typed (NY4I,
    // 2026-09-01).  It was a plain edit, which offered the operator nothing.
    (ctrTag: '_CATEGORY-TRANSMITTER';   ctrCFG:False; ctrSave: True; ctrList: True;  ctrOpen: True),
    (ctrTag: '_CATEGORY-OVERLAY';       ctrCFG:True;  ctrSave: True; ctrList:  True; ctrOpen: False),  // Issue #976: persist + restore selection
    (ctrTag: '_CERTIFICATE';            ctrCFG:True;  ctrSave: True; ctrList: False; ctrOpen: False),
    (ctrTag: '_OPERATORS';              ctrCFG:True;  ctrSave: True; ctrList: False; ctrOpen: False),
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
  uCabrilloSummaryForm;

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
   if CabrilloSummaryOpen then
      begin
      Result := CabrilloSummary.TagText(aTag);
      Exit;
      end;

   if ErmakSpecification then
      begin
      section := string(ERMAKSECTION);
      end
   else
      begin
      section := string(CABRILLOSECTION);
      end;

   Result := HeaderValue(section, string(CabrilloTagsArray[aTag].ctrTag));
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
