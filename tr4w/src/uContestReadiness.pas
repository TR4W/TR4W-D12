{
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
}
unit uContestReadiness;
{$I tr4w.inc}

(*
  DOES THIS CONTEST HAVE WHAT IT NEEDS -- asked once, after it is set up.

  NY4I, 2026-09-20, after losing a bench session to it: "I would think we
  should have some sort of initialization check that we are missing a key
  piece of information in MY COUNTRY."

  WHAT WENT WRONG. He ran a fresh install, started ARRL DX SSB, worked an
  Italian station and typed K for a kilowatt. TR4W refused it: "Improper
  domestic QTH". MY COUNTRY was empty, so FCONTEST had put a Florida station
  on the DX side of the contest and was demanding a state from everyone. The
  failure was SILENT until a perfectly good exchange was rejected mid-contest,
  and nothing on screen or in the log connected the refusal to the setting
  that caused it.

  DERIVED FROM THE CONTEST'S OWN CONFIGURATION, NEVER FROM A TABLE INDEXED BY
  CONTEST. FoundContest has just chosen ActiveExchange, the session's
  DomesticMult (uContestSession) and the rest; those ARE the statement of
  what this contest asks the operator to send. A hand-typed list of "ARRL
  DX needs MY COUNTRY" would be a second definition of every contest, free
  to drift from FCONTEST -- which is the
  shape this tree has spent a year deleting (CLAUDE.md: the radio tables, the
  config array). Every rule below reads the live configuration.

  IT IS NOT A NAG. It fires only when the contest now open genuinely lacks
  something it will use, which is rare by construction: MY COUNTRY is derived
  from MY CALL for everybody who has a callsign, and the exchange settings are
  asked for by the New Contest dialog.

  THE CORE IS A PURE FUNCTION, deliberately. CollectContestSettingsGaps takes
  the configuration as parameters rather than reading the globals, so the
  unit-test binary can exercise every rule -- it links VC but not the TRDOS
  engine, and "scoring and exchange parsing are not unit-covered" is the
  standing caveat this works around rather than accepts.
*)

interface

uses
   Classes;

(* WHAT THE EXCHANGE CARRIES IS THE CONTEST'S ANSWER -- M11 S9d, 2026-10-15.

  Three sets of exchange KINDS stood here -- DOMESTIC_QTH_EXCHANGES,
  ZONE_EXCHANGES and GRID_EXCHANGES -- and the caller handed in the
  session's kind. Each is the open contest's answer now
  (TContestBase.ExchangeCarriesDomesticQTH, ExchangeCarriesZone,
  ExchangeCarriesGridSquare), stated per class for exactly the contests
  whose session ran a kind in the set, and the caller hands in the three
  answers. TRANSCRIBED, NOT JUDGED (plan F28): they are RECEIVED kinds
  standing for what the operator SENDS, and the grid set is not the same
  as the tree's other two. *)

(* THE RULES, AS A PURE FUNCTION.

  Appends one line per gap. Each line says what is missing AND what TR4W will
  do instead, because "MY COUNTRY is empty" on its own does not tell an
  operator that their exchange is about to change shape.

  aContestActive is False for DUMMYCONTEST -- no contest is set up, so there
  is nothing to be ready for and nothing is reported. *)
procedure CollectContestSettingsGaps(const aContestActive: boolean;
                                     const aCarriesDomesticQTH: boolean;
                                     const aCarriesZone: boolean;
                                     const aCarriesGridSquare: boolean;
                                     const aUsesDomesticFile: boolean;
                                     const aCall: string;
                                     const aCountry: string;
                                     const aState: string;
                                     const aZone: string;
                                     const aGrid: string;
                                     const aDomesticFile: string;
                                     aGaps: TStrings);

(* WHY THE EXCHANGE IS THE SHAPE IT IS, in one sentence, when a SETTING chose
  it. Empty when nothing settings-driven is responsible.

  Used by the rejection in LOGSTUFF: "Improper domestic QTH" told NY4I nothing,
  and the missing half of it is that a setting put the contest in that mode.

  aBrief PICKS THE CHANNEL, and there are two with different budgets. The log
  and a dialog take the sentence; the on-screen error is a main-window
  element a few words wide, so it gets ' (MY COUNTRY is empty)' -- WITH its
  leading space, so an empty attribution appends nothing at all. *)
function ExchangeModeAttribution(const aCarriesDomesticQTH: boolean;
                                 const aCountry: string;
                                 const aBrief: boolean): string;

type
   (* WHY A DOMESTIC QTH WAS REFUSED -- 2026-10-23. NY4I: "Improper domestic
     QTH is the historical message TR sent but I am open to a clearer message
     as long as it is consistent in other places."

     The historical text stays as the STEM, so the line is still recognisably
     TR's; the reason is appended by the same rule as ExchangeModeAttribution
     (brief for the screen, a sentence for the log). LOGSTUFF decides which
     reason applies (RefuseDomesticQTH); this unit only words it, so the
     wording is pinned without an engine.

       dqrNoQTH         nothing in the exchange could be a QTH;
       dqrNotInList     the text is not in the list this entrant's session
                        loaded (aListName, the DOMESTIC FILENAME -- '' when
                        the contest's QTH is a rule rather than a file);
       dqrHostAreaOnly  the text IS a place the contest knows (its in-state
                        file has it), but this entrant is outside the host
                        area and may work host stations only (aHostArea). *)
   TDomesticQTHRefusal = (dqrNoQTH, dqrNotInList, dqrHostAreaOnly);

(* THE REASON, with a leading space when aBrief (as ExchangeModeAttribution),
  so the caller writes STEM + reason. The full form is a sentence for the
  log and has no leading space. *)
function DomesticQTHRefusalReason(const aRefusal: TDomesticQTHRefusal;
                                  const aQTH: string;
                                  const aListName: string;
                                  const aHostArea: string;
                                  const aBrief: boolean): string;

(* THE GAPS AS ONE BLOCK OF TEXT FOR A DIALOG. Empty when there are none.

  THE UNIT STOPS HERE, AND THAT IS THE POINT. Reading the live globals means
  naming FCONTEST, LOGSTUFF and LOGDOM, and the widget set to show anything --
  which would make this unit unlinkable by the unit-test binary and the rules
  above untestable. uProgramMain does the reading and the showing; it already
  owns the identical MY GRID prompt and already links all of it. *)
function FormatReadinessMessage(aGaps: TStrings): string;

implementation

uses
   SysUtils,
   uAppStrings,
   (* TC_IMPROPERDOMESTICQTH* -- the brief reasons, beside the stem. *)
   uTR4WStrings;

const
   (* THE LOG'S SENTENCES. The log is the developer's channel and is
     English; the screen's brief forms are the translatable ones. *)
   DOMESTIC_QTH_REFUSAL_NO_QTH_LOG      = 'No domestic QTH was found in the exchange.';
   DOMESTIC_QTH_REFUSAL_NOT_IN_FILE_LOG = '%s is not in the domestic file %s.';
   DOMESTIC_QTH_REFUSAL_UNKNOWN_LOG     = '%s is not a domestic QTH this contest recognises.';
   DOMESTIC_QTH_REFUSAL_HOST_AREA_LOG   = '%s is a QTH this contest knows, but a station ' +
                                          'outside %s may work %s stations only ' +
                                          '(the host-area rule).';

procedure CollectContestSettingsGaps(const aContestActive: boolean;
                                     const aCarriesDomesticQTH: boolean;
                                     const aCarriesZone: boolean;
                                     const aCarriesGridSquare: boolean;
                                     const aUsesDomesticFile: boolean;
                                     const aCall: string;
                                     const aCountry: string;
                                     const aState: string;
                                     const aZone: string;
                                     const aGrid: string;
                                     const aDomesticFile: string;
                                     aGaps: TStrings);
begin
   if aGaps = nil then
      begin
      Exit;
      end;

   if not aContestActive then
      begin
      Exit;
      end;

   (* THE CALLSIGN FIRST, because everything else is derived from it and
     because nothing at all works without one. *)
   if Trim(aCall) = '' then
      begin
      aGaps.Add(SReadinessMyCallMissing);
      end;

   (* MY COUNTRY IS ALWAYS IN USE, whatever the contest: it decides whether a
     worked station is domestic, it is the prefix the domestic-country list is
     matched against, and two ARRL contests choose the whole exchange from it.
     An empty value is never right -- it means either there is no callsign or
     CTY.DAT could not place the one there is.

     REPORTED HERE RATHER THAN ONLY WHERE IT BRANCHES, deliberately: an
     operator whose country is empty has a broken contest whichever contest it
     is, and only ever finds out when something is refused. *)
   if Trim(aCountry) = '' then
      begin
      aGaps.Add(SReadinessMyCountryMissing);
      end;

   (* THE OPERATOR'S OWN DOMESTIC QTH. FCONTEST itself tests this -- with an
     empty MY STATE it silently falls back to SetUpRSTQSONumberExchange -- so
     this reports a substitution that already happens rather than predicting
     one. *)
   if aCarriesDomesticQTH and (Trim(aState) = '') then
      begin
      aGaps.Add(SReadinessMyStateMissing);
      end;

   if aCarriesZone and (Trim(aZone) = '') then
      begin
      aGaps.Add(SReadinessMyZoneMissing);
      end;

   if aCarriesGridSquare and (Trim(aGrid) = '') then
      begin
      aGaps.Add(SReadinessMyGridMissing);
      end;

   (* A DOMESTIC-FILE CONTEST WITH NO FILE NAMED. aUsesDomesticFile is the
     contest's own answer (TContestBase.UsesDomesticFile, M11 S6 part 1b) --
     the caller asks the contest; it was the session's DomesticMultType
     compared with DomesticFile, the one kind that reads a .DOM. *)
   if aUsesDomesticFile and (Trim(aDomesticFile) = '') then
      begin
      aGaps.Add(SReadinessDomesticFileMissing);
      end;
end;

function ExchangeModeAttribution(const aCarriesDomesticQTH: boolean;
                                 const aCountry: string;
                                 const aBrief: boolean): string;
begin
   Result := '';

   if aCarriesDomesticQTH then
      begin
      if aBrief then
         begin
         if Trim(aCountry) = '' then
            begin
            Result := ' ' + SExchangeModeBriefEmptyCountry;
            end
         else
            begin
            Result := ' ' + SysUtils.Format(SExchangeModeBriefCountry,
                                            [Trim(aCountry)]);
            end;
         Exit;
         end;

      (* THE ONE SETTING THAT PUTS A CONTEST IN THIS MODE WITHOUT BEING TYPED.

        ARRL DX and ARRL 160 pick between a power/section exchange and a
        domestic-QTH one on MY COUNTRY, and MY COUNTRY is DERIVED. So the
        operator never chose this mode and has nothing on screen that names
        it. Saying which setting decided is the whole of the diagnosis. *)
      if Trim(aCountry) = '' then
         begin
         Result := SExchangeModeFromEmptyCountry;
         end
      else
         begin
         Result := SysUtils.Format(SExchangeModeFromCountry, [Trim(aCountry)]);
         end;
      end;
end;

function DomesticQTHRefusalReason(const aRefusal: TDomesticQTHRefusal;
                                  const aQTH: string;
                                  const aListName: string;
                                  const aHostArea: string;
                                  const aBrief: boolean): string;
var
   qth: string;
   listName: string;
begin
   qth := Trim(aQTH);
   listName := Trim(aListName);
   Result := '';

   case aRefusal of
      dqrNoQTH:
         begin
         if aBrief then
            begin
            Result := ' ' + TC_IMPROPERDOMESTICQTHNOQTH;
            end
         else
            begin
            Result := DOMESTIC_QTH_REFUSAL_NO_QTH_LOG;
            end;
         end;

      dqrNotInList:
         begin
         if listName <> '' then
            begin
            if aBrief then
               begin
               Result := ' ' + SysUtils.Format(TC_IMPROPERDOMESTICQTHNOTINFILE,
                                               [qth, listName]);
               end
            else
               begin
               Result := SysUtils.Format(DOMESTIC_QTH_REFUSAL_NOT_IN_FILE_LOG,
                                         [qth, listName]);
               end;
            end
         else
            begin
            if aBrief then
               begin
               Result := ' ' + SysUtils.Format(TC_IMPROPERDOMESTICQTHUNKNOWN, [qth]);
               end
            else
               begin
               Result := SysUtils.Format(DOMESTIC_QTH_REFUSAL_UNKNOWN_LOG, [qth]);
               end;
            end;
         end;

      dqrHostAreaOnly:
         begin
         if aBrief then
            begin
            Result := ' ' + SysUtils.Format(TC_IMPROPERDOMESTICQTHHOSTONLY,
                                            [qth, aHostArea]);
            end
         else
            begin
            Result := SysUtils.Format(DOMESTIC_QTH_REFUSAL_HOST_AREA_LOG,
                                      [qth, aHostArea, aHostArea]);
            end;
         end;
   end;
end;

function FormatReadinessMessage(aGaps: TStrings): string;
var
   i: integer;
begin
   Result := '';
   if (aGaps = nil) or (aGaps.Count = 0) then
      begin
      Exit;
      end;

   Result := SReadinessHeading + sLineBreak + sLineBreak;
   for i := 0 to aGaps.Count - 1 do
      begin
      Result := Result + '  - ' + aGaps[i] + sLineBreak + sLineBreak;
      end;
   Result := Result + SReadinessFooter;
end;

end.
