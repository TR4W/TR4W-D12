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
  CONTEST. FoundContest has just chosen ActiveExchange, ActiveDomesticMult and
  the rest; those ARE the statement of what this contest asks the operator to
  send. A hand-typed list of "ARRL DX needs MY COUNTRY" would be a second
  definition of every contest, free to drift from FCONTEST -- which is the
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
   Classes,
   VC;   // ExchangeType, DomesticMultType

(* EVERY EXCHANGE THAT SENDS THE OPERATOR'S OWN DOMESTIC QTH.

  Taken from the arms of FCONTEST's `case ActiveExchange of` that call
  SetUpRSTMyStateExchange, plus the handlers in LOGSTUFF that compare a
  received QTH against the domestic table. Exported so a reader can see the
  rule rather than infer it from the function below. *)
const
   DOMESTIC_QTH_EXCHANGES: set of ExchangeType =
      [ClassDomesticOrDXQTHExchange,
       NameAndDomesticOrDXQTHExchange,
       QSONumberAndPossibleDomesticQTHExchange,
       QSONumberDomesticOrDXQTHExchange,
       QSONumberDomesticQTHExchange,
       QSONumberNameDomesticOrDXQTHExchange,
       QSONumberPrecedenceCheckDomesticQTHExchange,
       RSTAndDOMESTICQTH,
       RSTAndQSONumberOrDomesticQTHExchange,
       RSTDomesticOrDXQTHExchange,
       RSTDomesticQTHExchange,
       RSTDomesticQTHOrQSONumberExchange,
       RSTQSONumberAndDomesticQTHExchange,
       RSTQSONumberAndPossibleDomesticQTHExchange,
       RSTQSONumberOrDomesticQTHExchange,
       RSTZoneAndPossibleDomesticQTHExchange,
       RSTZoneOrDomesticQTH];

   (* The exchanges whose SENT half is the operator's CQ or ITU zone --
     SetUpRSTMyZoneExchange's arms in FCONTEST. *)
   ZONE_EXCHANGES: set of ExchangeType =
      [QSONumberAndZone,
       RSTZoneAndPossibleDomesticQTHExchange,
       RSTZoneExchange,
       RSTZoneOrSocietyExchange,
       RSTZoneOrDomesticQTH];

   (* The exchanges whose sent half is the operator's Maidenhead locator. *)
   GRID_EXCHANGES: set of ExchangeType =
      [GridExchange,
       Grid2Exchange,
       RSTAndGrid3Exchange,
       RSTAndGridExchange,
       RSTAndOrGridExchange,
       QSONumberAndGridSquare,
       RSTQSONumberAndGridSquareExchange,
       NameAndPossibleGridSquareExchange,
       RSTAndSerialNumberAndGridandPossibleMemberNumber,
       RSTAndGridSquareOrRDAExchange];

(* THE RULES, AS A PURE FUNCTION.

  Appends one line per gap. Each line says what is missing AND what TR4W will
  do instead, because "MY COUNTRY is empty" on its own does not tell an
  operator that their exchange is about to change shape.

  aContestActive is False for DUMMYCONTEST -- no contest is set up, so there
  is nothing to be ready for and nothing is reported. *)
procedure CollectContestSettingsGaps(const aContestActive: boolean;
                                     const aExchange: ExchangeType;
                                     const aDomesticMult: DomesticMultType;
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
function ExchangeModeAttribution(const aExchange: ExchangeType;
                                 const aCountry: string;
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
   uAppStrings;

procedure CollectContestSettingsGaps(const aContestActive: boolean;
                                     const aExchange: ExchangeType;
                                     const aDomesticMult: DomesticMultType;
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
   if (aExchange in DOMESTIC_QTH_EXCHANGES) and (Trim(aState) = '') then
      begin
      aGaps.Add(SReadinessMyStateMissing);
      end;

   if (aExchange in ZONE_EXCHANGES) and (Trim(aZone) = '') then
      begin
      aGaps.Add(SReadinessMyZoneMissing);
      end;

   if (aExchange in GRID_EXCHANGES) and (Trim(aGrid) = '') then
      begin
      aGaps.Add(SReadinessMyGridMissing);
      end;

   (* A DOMESTIC-FILE CONTEST WITH NO FILE NAMED. DomesticFile is the one
     DomesticMultType that reads a .DOM, so this is the whole of the rule. *)
   if (aDomesticMult = DomesticFile) and (Trim(aDomesticFile) = '') then
      begin
      aGaps.Add(SReadinessDomesticFileMissing);
      end;
end;

function ExchangeModeAttribution(const aExchange: ExchangeType;
                                 const aCountry: string;
                                 const aBrief: boolean): string;
begin
   Result := '';

   if aExchange in DOMESTIC_QTH_EXCHANGES then
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
