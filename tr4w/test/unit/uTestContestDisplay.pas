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

(* WHAT A CONTEST TELLS THE DISPLAY AND THE REPORTS -- milestone M9a,
  2026-10-02 (docs/CONTEST_OWNERSHIP_DESIGN.md section 8.2m).

  NO AUTOMATED ORACLE SEES MOST OF THIS. The golden corpus sees the Cabrillo
  header and mode column (the Winter Field Day set, the General QSO set);
  the contest matrix sees set-up, so it sees MY STATE no longer being
  written. Nothing sees the New Contest dialog, the totals window, the
  summary sheet, the hour-by-hour report, the score-posting XML, the
  HamScore canonical exchanges or the WRTC menus. So the moves are pinned
  here, against the arms they replaced:

    * THE NEW CONTEST PROMPTS, FOR EVERY CONTEST. ExpectedOnChoice and
      ExpectedWhenTicked below were GENERATED from the two `case
      SelectedContest of` statements as they stood at 69828f2a, by a parse of
      that source -- not from the classes -- and the party head is computed
      here from the row's P and the QSOParties table, as the dialog computed
      it. Every contest's prompts must render to exactly that.
    * THE OTHER SEAMS, contest by contest, and every other contest's base
      answer as a ratchet: a contest that starts answering differently fails.
    * DESIGN 7.11: SET-UP NEVER WRITES MY STATE, for every contest and three
      kinds of station; the state SENT is the contest's.
    * NY4I's RULING: EVERY CONTEST CLASS STATES ITS DISPLAY NAME, CABRILLO NAME
      AND ADIF ID ITSELF, and its display name is its human name. *)
unit uTestContestDisplay;

{$I ..\..\src\tr4w.inc}

interface

uses
   uTR4WTestFramework;

type
   TContestDisplayTests = class(TTestCase)
   public
      procedure RunAllTests; override;
   private
      procedure Test_NewContestPromptsAreTheDialogsArms;
      procedure Test_TotalsDisplay;
      procedure Test_SummarySheet;
      procedure Test_CabrilloHeaderAndMode;
      procedure Test_WinterFieldDayFMIsWrittenFMAndScoredAsPhone;
      procedure Test_HamScoreLineAsksTheContestForTheMode;
      procedure Test_HamScoreStoredQsoReadsItsRecord;
      procedure Test_HamScoreStoredQsoGridIsTheFinalExportsGrid;
      procedure Test_HamScoreStoredQsoFollowsAnEditedSerial;
      procedure Test_HourTotalsRunningScore;
      procedure Test_OperatingAidsAndScorePosting;
      procedure Test_QTCMenu;
      procedure Test_CanonicalReceivedExchanges;
      procedure Test_CanonicalSentExchanges;
      procedure Test_SetUpNeverWritesMyState;
      procedure Test_EveryClassStatesItsIdentity;
   end;

implementation

uses
   SysUtils,
   StrUtils,         (* ExtractWord -- the words of a Cabrillo line *)
   VC,
   uQsoMyFacts,      (* a stored QSO's own station -- issue 95 *)
   uLogSource,       (* ExportCallFor -- the final export's answer for our call *)
   uContestBase,
   uContestRegistry,
   uTR4WStrings,
   uAppStrings,      (* SNewContestIN7QPNECountyOrState -- Q87 *)
   uSettingsModel,
   (* SentMyState, ApplyContestSentState, ClearContestSentState -- 7.11. *)
   FCONTEST,
   (* BuildRxExchangeText / BuildSentExchangeText -- the real dispatchers. *)
   uExchangeBuilder,
   (* BuildSingleQsoCabrilloLine -- HamScore's one-QSO line (Q54). *)
   uCabrillo,
   uTestContestObjects,
   (* ContestsToWalk, ContestWho, ClassStatesItself -- Q108 S1. *)
   uTestRegisteredContests;

(* ------------------------------------------------------------------------ *)
(* THE NEW CONTEST PROMPTS                                                   *)
(* ------------------------------------------------------------------------ *)

(* ONE STEP, AS TEXT -- what the dialog would have done, comparable. *)
function StepField(aField: TNewContestField): string;
begin
   Result := 'row ' + IntToStr(Ord(aField)) + ';';
end;

function StepComment(const aText: string; aField: TNewContestField): string;
begin
   Result := 'row ' + IntToStr(Ord(aField)) + ' comment "' + aText + '";';
end;

function StepBox(const aRegion: string): string;
begin
   Result := 'box in "' + aRegion + '";';
end;

function StepCaption(const aCaption: string): string;
begin
   Result := 'box "' + aCaption + '";';
end;

function Rendered(const aStep: TNewContestPrompt): string;
begin
   Result := '';
   case aStep.Kind of
      npkField:
         begin
         Result := StepField(aStep.Field);
         end;
      npkFieldWithComment:
         begin
         Result := StepComment(aStep.Text, aStep.Field);
         end;
      npkIAmIn:
         begin
         Result := StepBox(aStep.Text);
         end;
      npkIAmInCaption:
         begin
         Result := StepCaption(aStep.Text);
         end;
   end;
end;

(* THE QSO-PARTY HEAD AS THE DIALOG COMPUTED IT: the row's P indexed the
  QSOParties table, and British Columbia was named out of it.

  A LITERAL SINCE M10 S8, which deleted both tables. Each area below is the
  StateName of the QSOParties entry the contest's row indexed, printed from
  the tables by a program linking VC before they were deleted: the 22 rows
  with P <> 0, less British Columbia, which this has always left out. *)
function ExpectedHead(aContest: ContestType): string;
var
   state: string;
begin
   Result := '';
   case aContest of
      SEVENQP:
         begin
         state := '7th area';
         end;
      ArizonaQsoParty:
         begin
         state := 'AZ';
         end;
      CALQSOPARTY:
         begin
         state := 'CA';
         end;
      FLORIDAQSOPARTY:
         begin
         state := 'FL';
         end;
      MICHQSOPARTY:
         begin
         state := 'MI';
         end;
      MINNQSOPARTY:
         begin
         state := 'MN';
         end;
      MOQSOPARTY:
         begin
         state := 'MO';
         end;
      NCQSOPARTY:
         begin
         state := 'NC';
         end;
      OHIOQSOPARTY:
         begin
         state := 'OH';
         end;
      SALMONRUN:
         begin
         state := 'WA';
         end;
      TEXASQSOPARTY:
         begin
         state := 'TX';
         end;
      WISCONSINQSOPARTY:
         begin
         state := 'WI';
         end;
      NYQP:
         begin
         state := 'NY';
         end;
      TENNESSEEQSOPARTY:
         begin
         state := 'TN';
         end;
      COLORADOQSOPARTY:
         begin
         state := 'CO';
         end;
      PAQSOPARTY:
         begin
         state := 'PA';
         end;
      INQSOPARTY:
         begin
         state := 'IN';
         end;
      VAQP:
         begin
         state := 'VA';
         end;
      IN7QPNE:
         begin
         (* Its own words since Q87 (2026-10-14), not the area twice. *)
         Result := StepComment(SNewContestIN7QPNECountyOrState, ncfMyState);
         Exit;
         end;
      IDAHOQSOPARTY:
         begin
         state := 'ID';
         end;
      DELAWAREQSOPARTY:
         begin
         state := 'DE';
         end;
      NEBRASKAQSO:
         begin
         state := 'NE';
         end;
   else
      begin
      Exit;
      end;
   end;
   Result := StepComment(Format(TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX, [state, state]),
                         ncfMyState);
end;

(* GENERATED from the dialog's two `case` statements at 69828f2a -- see the
  unit header. POTA's two arms were added by hand when it gained its class
  (2026-10-13), and RSGB 1.8's and the UA4W Championship's when they gained
  theirs (2026-10-14), each copied from ClasslessPrompts as it stood before
  that routine was deleted. *)
function ExpectedOnChoice(aContest: ContestType): string;
begin
   Result := '';
   case aContest of
      ALLASIANCW:
         begin
         Result := StepComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
         end;
      ALLASIANSSB:
         begin
         Result := StepComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
         end;
      ALRS_UA1DZ_CUP:
         begin
         Result := StepComment(TC_ENTERYOURRDAIDORGRID, ncfMyState);
         end;
      ARI_DX:
         begin
         Result := StepBox(TC_ITALY);
         end;
      ARKTIKA_SPRING:
         begin
         Result := StepBox(TC_ARKTIKACLUB);
         end;
      ARRL10:
         begin
         Result := StepBox(TC_NORTHAMERICA);
         end;
      ARRL160:
         begin
         Result := StepBox(TC_NORTHAMERICA);
         end;
      ARRLDIGI:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      ARRLDXCW:
         begin
         Result := StepComment(TC_ENTERYOURQTHORPOWER, ncfMyState);
         end;
      ARRLDXSSB:
         begin
         Result := StepComment(TC_ENTERYOURQTHORPOWER, ncfMyState);
         end;
      ARRLFIELDDAY:
         begin
         Result := StepField(ncfMyFDClass) + StepField(ncfMySection);
         end;
      ARRLSSCW:
         begin
         Result := StepComment(TC_ENTERYOURPRECEDENCECHECKSECTION, ncfMyPrec) + StepField(ncfMyCheck) + StepField(ncfMySection);
         end;
      ARRLSSSSB:
         begin
         Result := StepComment(TC_ENTERYOURPRECEDENCECHECKSECTION, ncfMyPrec) + StepField(ncfMyCheck) + StepField(ncfMySection);
         end;
      ARRLVHFJAN:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      ARRLVHFJUN:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      ARRLVHFSEP:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      ARRL_RTTY_ROUNDUP:
         begin
         Result := StepBox(TC_NORTHAMERICA);
         end;
      BATAVIA_FT8:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      BCQP:
         begin
         Result := StepComment(TC_ENTERYOURISTRICTIFINVE7, ncfMyState);
         end;
      BSCI:
         begin
         Result := StepBox(TC_HQ_OR_MEMBER);
         end;
      CANADA_DAY:
         begin
         Result := StepBox(TC_CANADA);
         end;
      CANADA_WINTER:
         begin
         Result := StepBox(TC_CANADA);
         end;
      CIS:
         begin
         Result := StepBox(TC_CIS);
         end;
      COLORADOQSOPARTY:
         begin
         Result := StepField(ncfMyName);
         end;
      CQ160CW:
         begin
         Result := StepBox(TC_NORTHAMERICA);
         end;
      CQ160SSB:
         begin
         Result := StepBox(TC_NORTHAMERICA);
         end;
      CQIR:
         begin
         Result := StepBox(TC_IRELAND);
         end;
      CQMM:
         begin
         Result := StepComment(TC_ENTERYOURCONTINENT, ncfMyState);
         end;
      CQVHF:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      CQWWRTTY:
         begin
         Result := StepBox(TC_NORTHAMERICA);
         end;
      CUPRFCW:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      CUPRFDIG:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      CUPRFSSB:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      CUPURAL:
         begin
         Result := StepComment(TC_ENTERFIRSTTWOLETTERSOFYOURGRID, ncfMyState);
         end;
      CWOPEN:
         begin
         Result := StepComment(TC_ENTERYOURNAME, ncfMyName);
         end;
      CWOPS:
         begin
         Result := StepField(ncfMyName) + StepComment(TC_ENTERYOURNAMEANDQTH, ncfMyState);
         end;
      DARC10M:
         begin
         Result := StepBox(TC_GERMANY);
         end;
      DARCXMAS:
         begin
         Result := StepBox(TC_GERMANY);
         end;
      EUDX:
         begin
         Result := StepBox(TC_EUDX);
         end;
      EUROPEANHFC:
         begin
         Result := StepComment(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, ncfMyZone);
         end;
      EUROPEANVHF:
         begin
         Result := StepComment(TC_ENTERYOURSIXDIGITGRIDSQUARE, ncfMyGrid);
         end;
      EUSPRINT_AUTUMN_CW:
         begin
         Result := StepComment(TC_ENTERYOURNAME, ncfMyName);
         end;
      EUSPRINT_AUTUMN_SSB:
         begin
         Result := StepComment(TC_ENTERYOURNAME, ncfMyName);
         end;
      EUSPRINT_SPRING_CW:
         begin
         Result := StepComment(TC_ENTERYOURNAME, ncfMyName);
         end;
      EUSPRINT_SPRING_SSB:
         begin
         Result := StepComment(TC_ENTERYOURNAME, ncfMyName);
         end;
      FOCMARATHON:
         begin
         Result := StepComment(TC_ENTERYOURFOCNUMBER, ncfMyFOC);
         end;
      GAGARINCUP:
         begin
         Result := StepBox(TC_GC);
         end;
      HADX:
         begin
         Result := StepBox(TC_HUNGARY);
         end;
      HELVETIA:
         begin
         Result := StepBox(TC_SWITZERLAND);
         end;
      IARU:
         begin
         Result := StepBox(TC_HQ_OR_MEMBER);
         end;
      IOTA:
         begin
         Result := StepCaption(TC_ISLANDSTATION);
         end;
      IRTS:
         begin
         Result := StepBox(TC_IRTS);
         end;
      JIDXCW:
         begin
         Result := StepBox(TC_JAPAN);
         end;
      JIDXSSB:
         begin
         Result := StepBox(TC_JAPAN);
         end;
      KCJ:
         begin
         Result := StepComment(TC_PREF_OR_CQZONE, ncfMyState);
         end;
      KINGOFSPAINCW:
         begin
         Result := StepBox(TC_SPAIN);
         end;
      KINGOFSPAINSSB:
         begin
         Result := StepBox(TC_SPAIN);
         end;
      KVP:
         begin
         Result := StepComment(TC_ENTERTHELASTTWODIGITSOFTHEYEAR, ncfMyZone);
         end;
      LABRE:
         begin
         Result := StepComment(TC_LABRE, ncfMyState);
         end;
      LQP:
         begin
         Result := StepField(ncfMyName) + StepComment(TC_ENTERYOURNAMEANDQTH, ncfMyState);
         end;
      LZDX:
         begin
         Result := StepBox(TC_BULGARIA);
         end;
      MAKROTHEN:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      MINNQSOPARTY:
         begin
         Result := StepField(ncfMyName);
         end;
      MST:
         begin
         Result := StepComment(TC_ENTERYOURNAME, ncfMyName);
         end;
      NAQSOCW:
         begin
         Result := StepComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState) + StepField(ncfMyName);
         end;
      NAQSORTTY:
         begin
         Result := StepComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState) + StepField(ncfMyName);
         end;
      NAQSOSSB:
         begin
         Result := StepComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState) + StepField(ncfMyName);
         end;
      NASPRINTCW:
         begin
         Result := StepComment(TC_ENTERYOURQTHANDTHENAME, ncfMyState) + StepField(ncfMyName);
         end;
      NASPRINTRTTY:
         begin
         Result := StepComment(TC_ENTERYOURQTHANDTHENAME, ncfMyState) + StepField(ncfMyName);
         end;
      NCCCSPRINT:
         begin
         Result := StepField(ncfMyName) + StepComment(TC_ENTERYOURNAMEANDQTH, ncfMyState);
         end;
      NEWENGLANDQSO:
         begin
         Result := StepBox(TC_NEWENGLAND);
         end;
      NRAUBALTICCW:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      NRAUBALTICSSB:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      NZFIELDDAY:
         begin
         Result := StepComment(TC_ENTERYOURBRANCHNUMBER, ncfMyZone);
         end;
      OKDX:
         begin
         Result := StepBox(TC_CZECHREPUBLICORINSLOVAKIA);
         end;
      OKOMSSB:
         begin
         Result := StepBox(TC_CZECHREPUBLICORINSLOVAKIA);
         end;
      OLDNEWYEAR:
         begin
         Result := StepComment(TC_ENTERSUMOFYOURAGEANDAMOUNT, ncfMyQTH);
         end;
      OZCR_O:
         begin
         Result := StepComment(TC_OZCR, ncfMyState);
         end;
      OZHCRVHF:
         begin
         Result := StepComment(TC_ENTERYOURSIXDIGITGRIDSQUARE, ncfMyGrid);
         end;
      PACC:
         begin
         Result := StepBox(TC_NETHERLANDS);
         end;
      PCC:
         begin
         Result := StepBox(TC_ARKTIKACLUB);
         end;
      POTA:
         begin
         Result := StepCaption('Activator');
         end;
      R9W_UW9WK_MEMORIAL:
         begin
         Result := StepComment(TC_STATIONCLASS, ncfMyState);
         end;
      RADIOMEMORY:
         begin
         Result := StepComment(TC_AGECALLSIGNAGE, ncfMyQTH);
         end;
      RADIOVHFFD:
         begin
         Result := StepComment(TC_ENTERYOURSIXDIGITGRIDSQUARE, ncfMyGrid);
         end;
      RADIOYOC:
         begin
         (* Q136 (2026-10-22): the age it sends, in MY STATE. *)
         Result := StepComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
         end;
      RAEM:
         begin
         Result := StepComment(TC_ENTERYOURGEOGRAPHICALCOORDINATES, ncfMyQTH);
         end;
      RDA:
         begin
         Result := StepBox(TC_RUSSIA);
         end;
      REFCW:
         begin
         Result := StepBox(TC_FRANCE);
         end;
      REFSSB:
         begin
         Result := StepBox(TC_FRANCE);
         end;
      RFASCHAMPIONSHIPCW:
         begin
         Result := StepComment(TC_RFAS, ncfMyQTH);
         end;
      RFCHAMPIONSHIPCW:
         begin
         Result := StepComment(TC_ENTERYOURZONE, ncfMyState);
         end;
      RFCHAMPIONSHIPSSB:
         begin
         Result := StepComment(TC_ENTERYOURZONE, ncfMyState);
         end;
      RSGB18:
         begin
         Result := StepBox(TC_UK);
         end;
      RSGB_ROPOCO_CW:
         begin
         Result := StepComment(TC_ENTERYOURPOSTCODE, ncfMyPostalCode);
         end;
      RSGB_ROPOCO_SSB:
         begin
         Result := StepComment(TC_ENTERYOURPOSTCODE, ncfMyPostalCode);
         end;
      RTC:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      RU3AXMEMORIAL:
         begin
         Result := StepBox(TC_RUSSIA);
         end;
      RUSSIANDX:
         begin
         Result := StepBox(TC_RUSSIA);
         end;
      SPDX:
         begin
         Result := StepBox(TC_POLAND);
         end;
      SPRINTSSB:
         begin
         Result := StepComment(TC_ENTERYOURQTHANDTHENAME, ncfMyState) + StepField(ncfMyName);
         end;
      SST:
         begin
         Result := StepComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState) + StepField(ncfMyName);
         end;
      STEWPERRY:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      TESLA:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      UA4WCHAMPIONSHIP:
         begin
         (* The translated constant since 2026-10-17 (Q71, NY4I "Da"); it was
            the fixed literal 'Enter your RDA (for Russian stations) or four
            digit grid square:'. *)
         Result := StepComment(TC_ENTERYOURRDAIDORGRID, ncfMyQTH);
         end;
      UBACW:
         begin
         Result := StepBox(TC_BELGIUM);
         end;
      UBASSB:
         begin
         Result := StepBox(TC_BELGIUM);
         end;
      UKEI:
         begin
         Result := StepBox(TC_UKEI);
         end;
      UKRAINECHAMPIONSHIP:
         begin
         Result := StepComment(TC_ENTERYOUROBLASTID, ncfMyState);
         end;
      UKRAINIAN:
         begin
         Result := StepBox(TC_UKRAINE);
         end;
      UNDX:
         begin
         Result := StepBox(TC_KAZAKHSTAN);
         end;
      WAG:
         begin
         Result := StepBox(TC_GERMANY);
         end;
      WINTERFIELDDAY:
         begin
         Result := StepField(ncfMyFDClass) + StepField(ncfMySection);
         end;
      WWDIGI:
         begin
         Result := StepComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
         end;
      WWPMC:
         begin
         Result := StepBox('PMC');
         end;
      YODX:
         begin
         Result := StepBox(TC_ROMANIA);
         end;
      YOTA:
         begin
         Result := StepComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
         end;
      YOUTHCHAMPIONSHIPRF:
         begin
         Result := StepComment(TC_ENTERYOURAGEINMYSTATEFIELD, ncfMyState);
         end;
      YUDX:
         begin
         Result := StepBox(TC_YUGOSLAVIA);
         end;
   end;
end;

function ExpectedWhenTicked(aContest: ContestType): string;
begin
   Result := '';
   case aContest of
      ALRS_UA1DZ_CUP:
         begin
         Result := StepComment(TC_ENTERYOURRDAIDORGRID, ncfMyState);
         end;
      ARI_DX:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      ARKTIKA_SPRING:
         begin
         Result := StepComment(TC_ENTERYOURMEMBERSHIPNUMBER, ncfMyState);
         end;
      ARRL10:
         begin
         Result := StepComment(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
         end;
      ARRL160:
         begin
         Result := StepComment(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
         end;
      ARRLDXCW:
         begin
         Result := StepComment(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
         end;
      ARRL_RTTY_ROUNDUP:
         begin
         Result := StepComment(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
         end;
      BSCI:
         begin
         Result := StepComment('', ncfMyState);
         end;
      CANADA_DAY:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      CANADA_WINTER:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      CIS:
         begin
         Result := StepComment(TC_ENTERYOUROBLASTID, ncfMyState);
         end;
      CQ160CW:
         begin
         Result := StepComment(TC_ENTERSTATEFORUSPROVINCEFORCANADA, ncfMyState);
         end;
      CQ160SSB:
         begin
         Result := StepComment(TC_ENTERSTATEFORUSPROVINCEFORCANADA, ncfMyState);
         end;
      CQIR:
         begin
         Result := StepComment(TC_ENTERYOURCOUNTYCODE, ncfMyState);
         end;
      CQWWRTTY:
         begin
         Result := StepComment(TC_ENTERSTATEFORUSPROVINCEFORCANADA, ncfMyState);
         end;
      DARC10M:
         begin
         Result := StepComment(TC_ENTERYOURDOK, ncfMyState);
         end;
      DARCXMAS:
         begin
         Result := StepComment(TC_ENTERYOURDOK, ncfMyState);
         end;
      EUDX:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      GAGARINCUP:
         begin
         Result := StepComment(TC_GAGARIN, ncfMyState);
         end;
      HADX:
         begin
         Result := StepComment(TC_ENTERYOURCOUNTYCODE, ncfMyState);
         end;
      HELVETIA:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      IARU:
         begin
         Result := StepComment('', ncfMyState);
         end;
      IOTA:
         begin
         Result := StepComment(TC_ENTERYOURIOTAREFERENCEDESIGNATOR, ncfMyState);
         end;
      IRTS:
         begin
         Result := StepComment(TC_ENTERYOURCOUNTYCODE, ncfMyState);
         end;
      JIDXCW:
         begin
         Result := StepComment(TC_PREFECTURE, ncfMyState);
         end;
      JIDXSSB:
         begin
         Result := StepComment(TC_PREFECTURE, ncfMyState);
         end;
      KINGOFSPAINCW:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      KINGOFSPAINSSB:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      LZDX:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      NEWENGLANDQSO:
         begin
         Result := StepComment(TC_NEWENGLANDSTATEABREVIATION, ncfMyState);
         end;
      OKDX:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      OKOMSSB:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      PACC:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      PCC:
         begin
         Result := StepComment(TC_ENTERYOURMEMBERSHIPNUMBER, ncfMyState);
         end;
      POTA:
         begin
         Result := StepComment(TC_ENTERYOURPARKREFERENCEDESIGNATOR, ncfMyPark);
         end;
      RDA:
         begin
         Result := StepComment(TC_ENTERYOURRDAID, ncfMyState);
         end;
      REFCW:
         begin
         Result := StepComment(TC_DEPARTMENT, ncfMyState);
         end;
      REFSSB:
         begin
         Result := StepComment(TC_DEPARTMENT, ncfMyState);
         end;
      RSGB18:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      RU3AXMEMORIAL:
         begin
         Result := StepComment(TC_ENTERYOUROBLASTID, ncfMyState);
         end;
      RUSSIANDX:
         begin
         Result := StepComment(TC_ENTERYOUROBLASTID, ncfMyState);
         end;
      SPDX:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      UBACW:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      UBASSB:
         begin
         Result := StepComment(TC_ENTERYOURPROVINCEID, ncfMyState);
         end;
      UKEI:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTCODE, ncfMyState);
         end;
      UKRAINIAN:
         begin
         Result := StepComment(TC_ENTERYOUROBLASTID, ncfMyState);
         end;
      UNDX:
         begin
         Result := StepComment(TC_ENTERYOUROBLASTID, ncfMyState);
         end;
      WAG:
         begin
         Result := StepComment(TC_ENTERYOURDOK, ncfMyState);
         end;
      WWPMC:
         begin
         Result := StepComment(TC_ENTERYOURCITYIDENTIFIER, ncfMyState);
         end;
      YODX:
         begin
         Result := StepComment(TC_ENTERYOURDISTRICTABBREVIATION, ncfMyState);
         end;
      YUDX:
         begin
         Result := StepComment(TC_ENTERYOURCOUNTYCODE, ncfMyState);
         end;
   end;
end;

(* What a contest's prompts render to at one of the two moments. *)
function RenderedPrompts(aContest: ContestType; aTicked: boolean): string;
var
   obj: TContestBase;
   prompts: TNewContestPrompts;
   i: integer;
begin
   Result := '';
   obj := Make(aContest);
   prompts := TNewContestPrompts.Create;
   try
      obj.DescribeNewContestPrompts(prompts);
      if aTicked then
         begin
         for i := 0 to prompts.InsideCount - 1 do
            begin
            Result := Result + Rendered(prompts.Inside(i));
            end;
         end
      else
         begin
         for i := 0 to prompts.ChoiceCount - 1 do
            begin
            Result := Result + Rendered(prompts.Choice(i));
            end;
         end;
   finally
      prompts.Free;
      obj.Free;
      end;
end;

(* EVERY CONTEST -- class or not -- prompts exactly as the dialog's arms did:
  the party head, then the arm, on choosing; the arm on ticking the box. *)
procedure TContestDisplayTests.Test_NewContestPromptsAreTheDialogsArms;
var
   c: ContestType;
   who: string;
begin
   BeginTest('Test_NewContestPromptsAreTheDialogsArms');
   for c := Low(ContestType) to High(ContestType) do
      begin
      who := string(ContestTypeSA[c]);
      CheckEquals(ExpectedHead(c) + ExpectedOnChoice(c), RenderedPrompts(c, False),
                  who + ' on choosing');
      CheckEquals(ExpectedWhenTicked(c), RenderedPrompts(c, True),
                  who + ' on ticking the box');
      end;

   (* Two the parse could get wrong, written out by hand. *)
   CheckEquals(StepComment(TC_ENTERYOURNAMEANDSTATE, ncfMyState) + StepField(ncfMyName),
               RenderedPrompts(NAQSOCW, False), 'NAQP: the state row first, then the name');
   CheckEquals(StepComment(Format(TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX, ['CO', 'CO']), ncfMyState) +
               StepField(ncfMyName),
               RenderedPrompts(COLORADOQSOPARTY, False), 'Colorado: the head, then the name');
   CheckEquals(StepComment(Format(TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX, ['7th area', '7th area']),
                           ncfMyState),
               RenderedPrompts(SEVENQP, False), '7QP: its own words for its area');
   CheckEquals(StepComment(TC_ENTERYOURISTRICTIFINVE7, ncfMyState),
               RenderedPrompts(BCQP, False), 'British Columbia: no head');
end;

(* ------------------------------------------------------------------------ *)
(* THE TOTALS WINDOW, THE SUMMARY SHEET, THE HOUR TOTALS                     *)
(* ------------------------------------------------------------------------ *)

procedure TContestDisplayTests.Test_TotalsDisplay;
var
   c: ContestType;
   obj: TContestBase;
   d: TTotalsDisplay;
begin
   BeginTest('Test_TotalsDisplay');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         d := obj.TotalsDisplay;
         case c of
            IARU:
               begin
               CheckEquals(TC_HQMULTS, d.DomesticMultsCaption, 'IARU: HQ multipliers');
               CheckEquals('CW HQ', d.DomesticMultsCaptionCW, 'IARU on CW');
               CheckEquals('Ph HQ', d.DomesticMultsCaptionPhone, 'IARU on phone');
               CheckFalse(d.ShowsModeShares, 'IARU shows QSO rows');
               end;
            RUSSIANDX, RU3AXMEMORIAL:
               begin
               CheckEquals(TC_OBLASTS, d.DomesticMultsCaption, string(ContestTypeSA[c]) + ': oblasts');
               CheckEquals('CW Dom', d.DomesticMultsCaptionCW, string(ContestTypeSA[c]) + ' on CW');
               CheckEquals('Ph Dom', d.DomesticMultsCaptionPhone, string(ContestTypeSA[c]) + ' on phone');
               CheckFalse(d.ShowsModeShares, string(ContestTypeSA[c]) + ' shows QSO rows');
               end;
            OZCR_O:
               begin
               CheckTrue(d.ShowsModeShares, 'the OZCHR teams show mode shares');
               CheckEquals(TC_DOMMULTS, d.DomesticMultsCaption, 'OZCHR teams: the usual label');
               end;
         else
            begin
            CheckFalse(d.ShowsModeShares, string(ContestTypeSA[c]) + ' shows QSO rows');
            CheckEquals(TC_DOMMULTS, d.DomesticMultsCaption, string(ContestTypeSA[c]) + ' label');
            CheckEquals('CW Dom', d.DomesticMultsCaptionCW, string(ContestTypeSA[c]) + ' CW label');
            CheckEquals('Ph Dom', d.DomesticMultsCaptionPhone, string(ContestTypeSA[c]) + ' phone label');
            end;
         end;
      finally
         obj.Free;
         end;
      end;
end;

procedure TContestDisplayTests.Test_SummarySheet;
var
   c: ContestType;
   obj: TContestBase;
   s: TSummarySheetLayout;
begin
   BeginTest('Test_SummarySheet');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         s := obj.SummarySheet;
         CheckEquals(Ord(c = WINTERFIELDDAY), Ord(s.MultiplierPerBandModeRow),
                     string(ContestTypeSA[c]) + ': one multiplier per band/mode row');
         CheckEquals(Ord(c = ARRLFIELDDAY), Ord(s.ClaimedScoreIsQSOPoints),
                     string(ContestTypeSA[c]) + ': claims the QSO points');
      finally
         obj.Free;
         end;
      end;
end;

procedure TContestDisplayTests.Test_HourTotalsRunningScore;
var
   c: ContestType;
   obj: TContestBase;
begin
   BeginTest('Test_HourTotalsRunningScore');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         CheckEquals(Ord(not (c in [CUPRFCW, CUPRFSSB, RU3AXMEMORIAL, CUPURAL,
                                    UKRAINECHAMPIONSHIP, RFCHAMPIONSHIPCW,
                                    RFCHAMPIONSHIPSSB])),
                     Ord(obj.ReportsRunningScore),
                     string(ContestTypeSA[c]) + ': the hour report''s score column');
      finally
         obj.Free;
         end;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* THE CABRILLO HEADER AND MODE COLUMN                                       *)
(* ------------------------------------------------------------------------ *)

procedure TContestDisplayTests.Test_CabrilloHeaderAndMode;
var
   c: ContestType;
   obj: TContestBase;
   station: TStationContext;
begin
   BeginTest('Test_CabrilloHeaderAndMode');
   station := NoStation;
   station.MyFDClass := '2O';
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         CheckEquals(Ord(c in [ARRL10, WINTERFIELDDAY, DELAWAREQSOPARTY]),
                     Ord(obj.RequiresCabrilloLocation),
                     string(ContestTypeSA[c]) + ': needs a LOCATION');
         if c <> WINTERFIELDDAY then
            begin
            CheckEquals('', obj.CabrilloHeaderLinesBeforeTag('LOCATION', 'FL', station),
                        string(ContestTypeSA[c]) + ': no lines before LOCATION');
            end;
         (* FM AS PHONE AND EVERY DIGITAL MODE AS RY: the Delaware QSO Party
            alone (uTestContestDelawareQP). Winter Field Day wrote FM as PH
            until Q54 (NY4I, 2026-10-16) and writes FM now, as every other
            contest does. *)
         if c <> DELAWAREQSOPARTY then
            begin
            CheckEquals('FM', obj.CabrilloModeString(FM, eFM),
                        string(ContestTypeSA[c]) + ': FM is FM');
            end;
         if c <> DELAWAREQSOPARTY then
            begin
            CheckEquals('DG', obj.CabrilloModeString(Digital, eFT8), string(ContestTypeSA[c]) + ' FT8');
            end;
         if c <> GENERALQSO then
            begin
            CheckEquals(obj.CabrilloName, obj.CabrilloContestName('A TITLE', 'A NAME'),
                        string(ContestTypeSA[c]) + ': the CONTEST: name is the Cabrillo name');
            end;
         (* The base column, every contest: digital RY or DG, CW, phone. *)
         CheckEquals('RY', obj.CabrilloModeString(Digital, eRTTY), string(ContestTypeSA[c]) + ' RTTY');
         CheckEquals('RY', obj.CabrilloModeString(Digital, eNoMode), string(ContestTypeSA[c]) + ' digital');
         CheckEquals('CW', obj.CabrilloModeString(CW, eCW), string(ContestTypeSA[c]) + ' CW');
         CheckEquals('PH', obj.CabrilloModeString(Phone, eUSB), string(ContestTypeSA[c]) + ' phone');
      finally
         obj.Free;
         end;
      end;

   obj := Make(WINTERFIELDDAY);
   try
      CheckEquals('ARRL-SECTION: FL'#13#10'X-EXCHANGE: 2O'#13#10,
                  obj.CabrilloHeaderLinesBeforeTag('LOCATION', 'FL', station),
                  'Winter Field Day: section and class before LOCATION');
      CheckEquals('', obj.CabrilloHeaderLinesBeforeTag('CLUB', 'FL', station),
                  'and before no other tag');
      (* Q54: FM IS WRITTEN FM, NOT PH -- FM is a valid Cabrillo mode and the
         WFD rules list it. Named here as well as in the loop above, so a
         restored override fails on a line that says why. *)
      CheckEquals('FM', obj.CabrilloModeString(FM, eFM), 'Winter Field Day writes FM as FM (Q54)');
   finally
      obj.Free;
      end;

   obj := Make(GENERALQSO);
   try
      CheckEquals('A TITLE', obj.CabrilloContestName('A TITLE', 'A NAME'), 'General QSO: the title');
      CheckEquals('A NAME', obj.CabrilloContestName('', 'A NAME'), 'else the session name');
      CheckEquals(obj.CabrilloName, obj.CabrilloContestName('', ''), 'else the Cabrillo name');
   finally
      obj.Free;
      end;
end;

(* ONE FM QSO FOR aContest on 2 m -- a band every contest here credits. *)
function FMQSO(aContest: ContestType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := ContestHandleOf(aContest);
   Result.Callsign := 'W1AW';
   Result.Band := Band2;
   Result.Mode := FM;
   Result.ExtMode := eFM;
   Result.QSOPoints := 99;
end;

(* Q54 (NY4I, 2026-10-16): THE MODE COLUMN SAYS FM, THE POINTS SAY PHONE.
   Deleting the PH override changed what the Cabrillo line writes; it must
   not change the score, which counts FM as phone (1 point, CW and digital
   2) -- that rule lives in CalculateQSOPoints, not the mode column. *)
procedure TContestDisplayTests.Test_WinterFieldDayFMIsWrittenFMAndScoredAsPhone;
var
   obj: TContestBase;
   q: ContestExchange;
begin
   BeginTest('Test_WinterFieldDayFMIsWrittenFMAndScoredAsPhone');
   obj := Make(WINTERFIELDDAY);
   try
      CheckEquals('FM', obj.CabrilloModeString(FM, eFM), 'FM is written FM');
      q := FMQSO(WINTERFIELDDAY);
      obj.ScoreQSO(q);
      CheckEquals(1, q.QSOPoints, 'an FM contact scores as phone, 1 point');
      q := FMQSO(WINTERFIELDDAY);
      q.Mode := CW;
      q.ExtMode := eCW;
      obj.ScoreQSO(q);
      CheckEquals(2, q.QSOPoints, 'and CW still scores 2');
   finally
      obj.Free;
      end;
end;

(* HAMSCORE'S ONE-QSO LINE ASKS THE QSO'S CONTEST FOR THE MODE (Q54) -- the
   same CabrilloModeString the Cabrillo file writes, so the two cannot drift.
   Delaware is the proof that it ASKS: it alone writes FM as PH, so a line
   built from the base helper would say FM where the contest says PH. *)
procedure TContestDisplayTests.Test_HamScoreLineAsksTheContestForTheMode;
var
   line: string;
begin
   BeginTest('Test_HamScoreLineAsksTheContestForTheMode');
   line := string(BuildSingleQsoCabrilloLine(FMQSO(WINTERFIELDDAY)));
   CheckTrue(Pos(' FM ', line) > 0, 'Winter Field Day FM goes to HamScore as FM: ' + line);
   CheckTrue(Pos(' PH ', line) = 0, 'and not as PH: ' + line);

   line := string(BuildSingleQsoCabrilloLine(FMQSO(DELAWAREQSOPARTY)));
   CheckTrue(Pos(' PH ', line) > 0, 'Delaware FM goes to HamScore as PH, its file''s spelling: ' + line);
   CheckTrue(Pos(' FM ', line) = 0, 'and not as FM: ' + line);
end;

(* ISSUE 95 (R6 of the Codex review; NY4I's ruling Q13: a logged QSO reads its
   record, never live state). HamScore's one-QSO line is also built when Edit
   QSO or the Tools resync re-emits a STORED QSO, possibly after MY CALL, the
   grid or the CQ exchange has changed. It then says what the record says, by
   the routines the final Cabrillo writer asks.

   THE WORDS OF THE LINE, 1-BASED: QSO:, freq, mode, date, time, OUR CALL (6),
   then the sent exchange, then his call and what he sent. *)
function CanonicalQSO(aContest: ContestType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := ContestHandleOf(aContest);
   Result.Callsign := 'W1AW';
   Result.Mode := CW;
   Result.RSTReceived := 0;
   Result.NumberReceived := 123;
   Result.NumberSent := 7;
   Result.Zone := 5;
   Result.QTHString := ' CT ';
   Result.Power := '100';
   Result.Age := 40;
   Result.Name := ' JOE ';
   Result.ceClass := '2A';
   Result.ExchString := '  raw   exch ';
end;

function LineWord(const aLine: string; aWord: integer): string;
begin
   Result := ExtractWord(aWord, aLine, [' ']);
end;

(* A QSO that can be written as a line: a band for the frequency column and a
   mode the contest can spell. *)
function StoredQSO(aContest: ContestType): ContestExchange;
begin
   Result := CanonicalQSO(aContest);
   Result.Band := Band20;
   Result.ExtMode := eCW;
end;

(* A ROW THAT RECORDED THE STATION, as the log stores one logged here. *)
function LoggedFacts(const aCall, aGrid: string): TQsoMyFacts;
begin
   Result := NotCapturedMyFacts;
   Result.Source := mfsLogged;
   Result.Call := AnsiString(aCall);
   Result.Grid := AnsiString(aGrid);
end;

procedure TContestDisplayTests.Test_HamScoreStoredQsoReadsItsRecord;
var
   savedCall, savedTemplate, savedGrid: string;
   q: ContestExchange;
   facts: TQsoMyFacts;
   recordedSent: AnsiString;
   atLogTime, reEmitted, legacy, imported: string;
begin
   BeginTest('Test_HamScoreStoredQsoReadsItsRecord');
   savedCall := Settings.My.Call;
   savedTemplate := Settings.Messages.CqExchangeCw;
   savedGrid := Settings.My.Grid;
   try
      q := StoredQSO(CQWWCW);

      (* A: the station as the QSO was logged. The store captures the facts
         and BuildSentExchangeText's output at that moment. *)
      Settings.My.Call := 'N0AAA';
      Settings.My.Grid := 'EL88';
      Settings.Messages.CqExchangeCw := '5nn #';
      facts := LoggedFacts('N0AAA', 'EL88');
      recordedSent := AnsiString(BuildSentExchangeText(q));
      CheckEquals('599 7', string(recordedSent), 'A sent 599 and serial 7');

      (* THE JUST-LOGGED PATH: the record and the session are equal at that
         moment, so the line is what it was before the fix -- whether the
         exchange is handed in or built from the session. *)
      atLogTime := string(BuildSingleQsoCabrilloLine(q, facts, ''));
      CheckEquals(atLogTime, string(BuildSingleQsoCabrilloLine(q, facts, recordedSent)),
                  'just logged: the recorded sent exchange is the session''s');
      CheckEquals(atLogTime, string(BuildSingleQsoCabrilloLine(q)),
                  'just logged: and the one-argument form is the same line');
      CheckEquals('N0AAA', LineWord(atLogTime, 6), 'just logged: our call');
      CheckEquals('599', LineWord(atLogTime, 7), 'just logged: RST sent');
      CheckEquals('7', LineWord(atLogTime, 8), 'just logged: serial sent');

      (* B: the operator changes MY CALL and the grid. (The CQ exchange
         template is changed further down: it is a session setting, not a
         fact the QSO recorded, so a stored QSO follows today's -- NY4I,
         2026-10-23: the sent exchange is rebuilt from the record.) *)
      Settings.My.Call := 'K9BBB';
      Settings.My.Grid := 'FN42';

      (* A STORED QSO RE-EMITTED: Edit QSO, or the Tools -> HamScore resync. *)
      reEmitted := string(BuildSingleQsoCabrilloLine(q, facts, recordedSent));
      CheckEquals(atLogTime, reEmitted, 'the re-emitted line is the one logged');
      CheckEquals(ExportCallFor(facts), LineWord(reEmitted, 6),
                  'our call is the one the final export writes for the row');
      CheckEquals('N0AAA', LineWord(reEmitted, 6), 'A''s call, not today''s');
      CheckEquals(0, Pos('K9BBB', reEmitted), 'today''s MY CALL is nowhere in it');

      (* A ROW THAT NEVER CAPTURED ITS STATION (written before schema 3) FALLS
         BACK TO THE SESSION, exactly as the final export does (ruling A). *)
      Settings.Messages.CqExchangeCw := 'TEST #';
      legacy := string(BuildSingleQsoCabrilloLine(q, NotCapturedMyFacts, ''));
      CheckEquals(ExportCallFor(NotCapturedMyFacts), LineWord(legacy, 6),
                  'a legacy row''s call is the final export''s fallback');
      CheckEquals('K9BBB', LineWord(legacy, 6), 'which is the session''s call');
      CheckEquals('TEST', LineWord(legacy, 7), 'and the session''s CQ exchange');
      CheckEquals('7', LineWord(legacy, 8), 'filled with the QSO''s serial');

      (* AN IMPORTED ROW SENT WHAT ITS FILE SAYS, verbatim. *)
      facts := LoggedFacts('W1IMP/P', 'DM79');
      facts.Source := mfsImported;
      imported := string(BuildSingleQsoCabrilloLine(q, facts, 'IMPORTED 55'));
      CheckEquals('W1IMP/P', LineWord(imported, 6), 'an imported row''s own call');
      CheckEquals('IMPORTED', LineWord(imported, 7), 'and its file''s sent exchange');
      CheckEquals('55', LineWord(imported, 8), 'to the end');
   finally
      Settings.My.Call := savedCall;
      Settings.Messages.CqExchangeCw := savedTemplate;
      Settings.My.Grid := savedGrid;
      end;
end;

(* AN EDITED SENT SERIAL SHOWS (NY4I, 2026-10-23: "HamScore should follow the
   edited serial"). exchange_sent is captured once at log time and is
   insert-only, so it still says serial 7 after the operator corrects it to 12;
   the re-emitted line is built from the record, as the final export is. RTC's
   Cabrillo sent column carries the serial and the grid, so the two can be
   compared on both. *)
procedure TContestDisplayTests.Test_HamScoreStoredQsoFollowsAnEditedSerial;
var
   savedGrid, savedTemplate: string;
   q: ContestExchange;
   facts: TQsoMyFacts;
   staleSent: AnsiString;
   session, my: TMyStationExchange;
   justLogged, edited, exportSent: string;
begin
   BeginTest('Test_HamScoreStoredQsoFollowsAnEditedSerial');
   savedGrid := Settings.My.Grid;
   savedTemplate := Settings.Messages.CqExchangeCw;
   try
      Settings.My.Grid := 'EL88';
      Settings.Messages.CqExchangeCw := '5nn #';

      (* RTC: serial and grid. *)
      q := StoredQSO(RTC);
      facts := LoggedFacts('N0AAA', 'EL88');
      staleSent := AnsiString(BuildSentExchangeText(q));
      justLogged := string(BuildSingleQsoCabrilloLine(q, facts, staleSent));
      CheckTrue(Pos(' 7 EL88 ', justLogged) > 0, 'just logged: serial 7: ' + justLogged);
      CheckEquals(justLogged, string(BuildSingleQsoCabrilloLine(q, facts, '')),
                  'just logged: the same line without a stored text');

      q.NumberSent := 12;
      edited := string(BuildSingleQsoCabrilloLine(q, facts, staleSent));
      CheckTrue(Pos(' 12 EL88 ', edited) > 0,
                'the edited serial shows: ' + edited);
      CheckEquals(0, Pos(' 7 ', edited), 'and the old one is gone: ' + edited);

      session := Default(TMyStationExchange);
      session.MyGrid := 'EL88';
      my := MyStationExchangeOfQSO(session, facts, True, False);
      exportSent := ContestIdentity(q.ceContest).FormatCabrilloSentExchange(
                       my, q, Default(TCabrilloQSOContext));
      CheckTrue(Pos('12', exportSent) > 0,
                'the final export sends the same serial: ' + exportSent);

      (* A template contest: the serial comes through the CQ template. *)
      q := StoredQSO(CQWWCW);
      facts := LoggedFacts('N0AAA', 'EL88');
      staleSent := AnsiString(BuildSentExchangeText(q));
      q.NumberSent := 12;
      edited := string(BuildSingleQsoCabrilloLine(q, facts, staleSent));
      CheckEquals('599', LineWord(edited, 7), 'CQ WW: RST');
      CheckEquals('12', LineWord(edited, 8), 'CQ WW: the edited serial');

      (* AN IMPORTED ROW CANNOT BE REBUILT: its file's text is what it sent. *)
      facts.Source := mfsImported;
      edited := string(BuildSingleQsoCabrilloLine(q, facts, 'IMPORTED 55'));
      CheckEquals('IMPORTED', LineWord(edited, 7), 'imported: the file''s text');
   finally
      Settings.My.Grid := savedGrid;
      Settings.Messages.CqExchangeCw := savedTemplate;
      end;
end;

(* The grid, which is the station-dependent half of an RTC exchange: the
   re-emitted line and the final export's sent column come from the same
   record, so both say A's grid. *)
procedure TContestDisplayTests.Test_HamScoreStoredQsoGridIsTheFinalExportsGrid;
var
   savedGrid: string;
   q: ContestExchange;
   facts: TQsoMyFacts;
   recordedSent: AnsiString;
   session, my: TMyStationExchange;
   reEmitted, exportSent: string;
begin
   BeginTest('Test_HamScoreStoredQsoGridIsTheFinalExportsGrid');
   savedGrid := Settings.My.Grid;
   try
      q := StoredQSO(RTC);
      Settings.My.Grid := 'EL88';
      facts := LoggedFacts('N0AAA', 'EL88');
      recordedSent := AnsiString(BuildSentExchangeText(q));
      CheckEquals('7 EL88', string(recordedSent), 'A sent its serial and grid');

      Settings.My.Grid := 'FN42';
      reEmitted := string(BuildSingleQsoCabrilloLine(q, facts, recordedSent));
      CheckTrue(Pos(' 7 EL88 ', reEmitted) > 0,
                'the re-emitted line sends A''s grid: ' + reEmitted);
      CheckEquals(0, Pos('FN42', reEmitted), 'not today''s grid: ' + reEmitted);

      (* THE FINAL EXPORT'S SENT COLUMN for the same row: today's station,
         overlaid by what the row recorded (CurrentMyStationExchange). *)
      session := Default(TMyStationExchange);
      session.MyGrid := 'FN42';
      my := MyStationExchangeOfQSO(session, facts, True, False);
      exportSent := ContestIdentity(q.ceContest).FormatCabrilloSentExchange(
                       my, q, Default(TCabrilloQSOContext));
      CheckTrue(Pos('EL88', exportSent) > 0,
                'the final export sends A''s grid too: ' + exportSent);
      CheckEquals(0, Pos('FN42', exportSent), 'and not today''s: ' + exportSent);
   finally
      Settings.My.Grid := savedGrid;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* WRTC, WAE                                                                 *)
(* ------------------------------------------------------------------------ *)

procedure TContestDisplayTests.Test_OperatingAidsAndScorePosting;
const
   BASE_LABELS: array[RemainingMultiplierType] of string =
      ('', 'state', 'country', 'zone', 'prefix');
var
   c: ContestType;
   obj: TContestBase;
   m: RemainingMultiplierType;
begin
   BeginTest('Test_OperatingAidsAndScorePosting');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         if c = WRTC then
            begin
            CheckTrue(obj.PermittedOperatingAids = [], 'WRTC allows no aid');
            for m := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
               begin
               CheckEquals('', obj.ScorePostingMultiplierType(m, False),
                           'WRTC posts no multiplier on a mode row');
               end;
            CheckEquals('HQ', obj.ScorePostingMultiplierType(rmDomestic, True), 'WRTC: HQ');
            CheckEquals('country', obj.ScorePostingMultiplierType(rmDX, True), 'WRTC: country');
            CheckEquals('', obj.ScorePostingMultiplierType(rmZone, True), 'WRTC: no zone');
            CheckEquals('', obj.ScorePostingMultiplierType(rmPrefix, True), 'WRTC: no prefix');
            end
         else if c = IN7QPNE then
            begin
            (* NOT POSTED ANYWHERE (design 7.14, 2026-10-14): Super Check
               Partial and the cluster stay, score posting goes. Nothing is
               posted, so its labels are never asked. *)
            CheckTrue(obj.PermittedOperatingAids = [oaSuperCheckPartial, oaDXCluster],
                      'IN7QPNE allows every aid but score posting');
            end
         else
            begin
            CheckTrue(obj.PermittedOperatingAids = [oaSuperCheckPartial, oaDXCluster, oaScorePosting],
                      string(ContestTypeSA[c]) + ' allows every aid');
            for m := Low(RemainingMultiplierType) to High(RemainingMultiplierType) do
               begin
               CheckEquals(BASE_LABELS[m], obj.ScorePostingMultiplierType(m, False),
                           string(ContestTypeSA[c]) + ' labels');
               CheckEquals(BASE_LABELS[m], obj.ScorePostingMultiplierType(m, True),
                           string(ContestTypeSA[c]) + ' labels, all modes');
               end;
            end;
      finally
         obj.Free;
         end;
      end;
end;

procedure TContestDisplayTests.Test_QTCMenu;
var
   c: ContestType;
   obj: TContestBase;
begin
   BeginTest('Test_QTCMenu');
   for c := Low(ContestType) to High(ContestType) do
      begin
      obj := Make(c);
      try
         CheckEquals(Ord(c in [DARCWAEDCCW..DARCWAEDCSSB]), Ord(obj.OffersQTCs),
                     string(ContestTypeSA[c]) + ': the QTC menu');
      finally
         obj.Free;
         end;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* THE CANONICAL EXCHANGES -- through the real dispatchers                   *)
(* ------------------------------------------------------------------------ *)

(* ONE QSO WITH EVERY FIELD A CANONICAL FORM READS, each distinct, spaces
  around the text fields so the trimming shows. *)
procedure TContestDisplayTests.Test_CanonicalReceivedExchanges;
var
   c: ContestType;
   q: ContestExchange;
   expected: string;
begin
   BeginTest('Test_CanonicalReceivedExchanges');
   for c := Low(ContestType) to High(ContestType) do
      begin
      q := CanonicalQSO(c);
      case c of
         CQWPXCW, CQWPXSSB, DARCWAEDCCW:
            begin
            expected := '599 123';
            end;
         CQWWCW, CQWWSSB, IARU:
            begin
            expected := '599 5';
            end;
         CQ160CW, ARRLDXCW, ARRLDXSSB:
            begin
            expected := '599 CT';
            end;
         ALLASIANCW, ALLASIANSSB:
            begin
            expected := '599 40';
            end;
         CWOPS, SST, NAQSOCW, NAQSOSSB, NAQSORTTY:
            begin
            expected := 'JOE CT';
            end;
         CWOPEN:
            begin
            expected := '123 JOE';
            end;
         RTC:
            begin
            expected := '123 CT';
            end;
         ARRLFIELDDAY, WINTERFIELDDAY:
            begin
            expected := '2A CT';
            end;
      else
         begin
         (* The exchange as typed, collapsed -- every contest the builder
            did not name. *)
         expected := 'raw exch';
         end;
      end;
      CheckEquals(expected, BuildRxExchangeText(q), string(ContestTypeSA[c]) + ' received');
      end;

   (* ARRL DX's DX side: no state, so the power. *)
   q := CanonicalQSO(ARRLDXCW);
   q.QTHString := '';
   CheckEquals('599 100', BuildRxExchangeText(q), 'ARRL DX from a DX station: RST and power');
   (* An explicit RST, and phone's default. *)
   q := CanonicalQSO(CQWWSSB);
   q.Mode := Phone;
   CheckEquals('59 5', BuildRxExchangeText(q), 'CQ WW on phone: 59 by default');
   q.RSTReceived := 57;
   CheckEquals('57 5', BuildRxExchangeText(q), 'CQ WW: the RST received');
end;

procedure TContestDisplayTests.Test_CanonicalSentExchanges;
var
   c: ContestType;
   q: ContestExchange;
   savedTemplate: string;
   savedGrid: string;
begin
   BeginTest('Test_CanonicalSentExchanges');
   savedTemplate := Settings.Messages.CqExchangeCw;
   savedGrid := Settings.My.Grid;
   try
      Settings.My.Grid := ' FN42 ';
      Settings.Messages.CqExchangeCw := ' 5nn  # ';
      for c := Low(ContestType) to High(ContestType) do
         begin
         q := CanonicalQSO(c);
         if c = RTC then
            begin
            CheckEquals('7 FN42', BuildSentExchangeText(q), 'RTC: serial and grid, no RST');
            end
         else
            begin
            CheckEquals('599 7', BuildSentExchangeText(q),
                        string(ContestTypeSA[c]) + ': the template, filled');
            end;
         end;

      (* No template: the exchange as typed, trimmed and NOT collapsed. *)
      Settings.Messages.CqExchangeCw := '';
      CheckEquals('raw   exch', BuildSentExchangeText(CanonicalQSO(CQWWCW)),
                  'no template: the typed exchange');
      CheckEquals('7 FN42', BuildSentExchangeText(CanonicalQSO(RTC)),
                  'RTC reads no template');
   finally
      Settings.Messages.CqExchangeCw := savedTemplate;
      Settings.My.Grid := savedGrid;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* DESIGN 7.11 -- SET-UP NEVER WRITES MY STATE                               *)
(* ------------------------------------------------------------------------ *)

function Station(const aCall, aCountry, aState, aGrid: string): TStationContext;
begin
   Result := NoStation;
   Result.MyCall := aCall;
   Result.MyCountry := CallString(aCountry);
   Result.MyState := aState;
   Result.MyGrid := aGrid;
end;

procedure TContestDisplayTests.Test_SetUpNeverWritesMyState;
var
   stations: array[0..2] of TStationContext;
   contests: TContestIdentityList;
   k, i: integer;
   obj: TContestBase;
   session: TSessionDefaults;
   saved: string;
   who: string;

   (* What one contest's set-up does to MY STATE, and what it sends. aObj is
      a contest object of the test's own, and is freed here. *)
   procedure SetUpWith(aObj: TContestBase; const aStation: TStationContext;
                       out aSent: string; out aStated: boolean);
   begin
      Settings.My.State := aStation.MyState;
      ClearContestSentState;
      obj := aObj;
      session := TSessionDefaults.Create;
      try
         obj.DescribeSession(aStation, session);
         ApplyContestSentState(session);
         aStated := session.IsStated(svSentState);
      finally
         session.Free;
         obj.Free;
         end;
      aSent := SentMyState;
   end;

   procedure SetUpFor(aContest: ContestType; const aStation: TStationContext;
                      out aSent: string; out aStated: boolean);
   begin
      SetUpWith(Make(aContest), aStation, aSent, aStated);
   end;

var
   sent: string;
   stated: boolean;
begin
   BeginTest('Test_SetUpNeverWritesMyState');
   stations[0] := Station('K0AAA', 'K', 'KS', 'EM17');
   stations[1] := Station('VE3AAA', 'VE', 'ON', 'FN03');
   stations[2] := Station('DL1AAA', 'DL', '', 'JO62');
   saved := Settings.My.State;
   try
      (* AN INVARIANT, SO IT WALKS THE REGISTRY (Q108 S1): no contest's set-up
         writes MY STATE, and one that states no SentState sends MY STATE. *)
      contests := ContestsToWalk;
      for k := 0 to High(contests) do
         begin
         for i := Low(stations) to High(stations) do
            begin
            who := ContestWho(contests[k]) + ' for ' + stations[i].MyCall;
            SetUpWith(NewContestLike(contests[k], NoStation), stations[i], sent, stated);
            CheckEquals(stations[i].MyState, Settings.My.State, who + ': MY STATE is untouched');
            if not stated then
               begin
               CheckEquals(stations[i].MyState, sent, who + ': sends MY STATE');
               end;
            end;
         end;
      (* AND "NO CONTEST", WHICH HAS NO CLASS: the base states nothing. *)
      for i := Low(stations) to High(stations) do
         begin
         SetUpFor(DUMMYCONTEST, stations[i], sent, stated);
         CheckEquals(stations[i].MyState, Settings.My.State, 'no contest: MY STATE is untouched');
         CheckTrue((not stated) and (sent = stations[i].MyState), 'no contest: sends MY STATE');
         end;

      (* THE SEVEN THAT STATE ONE, side by side. *)
      SetUpFor(CANADA_DAY, stations[0], sent, stated);
      CheckTrue(stated and (sent = ''), 'Canada Day: a K station sends no state');
      CheckEquals('KS', Settings.My.State, 'and keeps its MY STATE');
      SetUpFor(CANADA_DAY, stations[1], sent, stated);
      CheckTrue((not stated) and (sent = 'ON'), 'Canada Day: a VE station sends its province');
      SetUpFor(CANADA_WINTER, stations[0], sent, stated);
      CheckTrue(stated and (sent = ''), 'Canada Winter: a K station sends no state');
      SetUpFor(RUSSIANDX, stations[0], sent, stated);
      CheckTrue(stated and (sent = ''), 'Russian DX: a K station sends no oblast');
      SetUpFor(RU3AXMEMORIAL, stations[1], sent, stated);
      CheckTrue(stated and (sent = ''), 'RU3AX Memorial: a VE station sends no oblast');
      SetUpFor(CUPRFCW, stations[0], sent, stated);
      CheckTrue(stated and (sent = 'EM17'), 'Cup RF CW: the grid is sent');
      CheckEquals('KS', Settings.My.State, 'and MY STATE stays KS');
      SetUpFor(CUPRFSSB, stations[1], sent, stated);
      CheckTrue(stated and (sent = 'FN03'), 'Cup RF SSB: the grid is sent');
      SetUpFor(CUPRFDIG, stations[2], sent, stated);
      CheckTrue(stated and (sent = 'JO62'), 'Cup RF digital: the grid is sent');

      (* THE NEXT SET-UP STARTS FROM MY STATE. *)
      ClearContestSentState;
      CheckEquals(Settings.My.State, SentMyState, 'cleared: MY STATE is sent');
   finally
      ClearContestSentState;
      Settings.My.State := saved;
      end;
end;

(* ------------------------------------------------------------------------ *)
(* NY4I: EVERY CLASS STATES ITS IDENTITY                                     *)
(* ------------------------------------------------------------------------ *)

type
   (* THE PROTECTED GETTERS, REACHED THE WAY A DESCENDANT REACHES THEM -- the
      only way to ask WHICH CLASS SUPPLIES a getter without a flag in every
      class to keep in step. The comparison itself is
      uTestRegisteredContests.ClassStatesItself (Q108 S1). *)
   TIdentityCracker = class(TContestBase);
   TIdentityGetter = function: string of object;

function DisplayNameCode(aObj: TContestBase): CodePointer;
var
   getter: TIdentityGetter;
begin
   getter := TIdentityCracker(aObj).GetDisplayName;
   Result := TMethod(getter).Code;
end;

function CabrilloNameCode(aObj: TContestBase): CodePointer;
var
   getter: TIdentityGetter;
begin
   getter := TIdentityCracker(aObj).GetCabrilloName;
   Result := TMethod(getter).Code;
end;

function ADIFContestIdCode(aObj: TContestBase): CodePointer;
var
   getter: TIdentityGetter;
begin
   getter := TIdentityCracker(aObj).GetADIFContestId;
   Result := TMethod(getter).Code;
end;

(* THE CONTESTS WHOSE DISPLAY NAME IS STILL THEIR ENUM SPELLING -- their row
  had no FriendlyName, so there was no human name to state. A RATCHET: a
  contest given a human name leaves this list, and a new contest may not join
  it.

  DESIGN Q53 (NY4I, 2026-10-16; docs/Q53_CONTEST_NAMES.csv) named 24 of them
  on 2026-10-17 and they left. What stays: the 17 for which no name was found
  -- NY4I: they keep their internal name, which each class states --, MINITEST
  (to be retired, Q10) and SOUTHAMERICANWW (Q102), and the six not in Q53's
  CSV (ARCI, GRIDLOC, JALONGPREFECT, QCWAGOLDEN, WWL, XMAS). *)
const
   ENUM_SPELLED_DISPLAY_NAMES: array[0..24] of ContestType = (
      APSPRINT, ARCI, GRIDLOC, JALONGPREFECT, MINITEST, OZCR_O, OZCR_Z,
      OZHCRVHF, QCWAGOLDEN, R9W_UW9WK_MEMORIAL, RADIOMEMORY, RADIOVHFFD,
      RADIOYOC, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW,
      REGION1FIELDDAY_RCC_SSB, RFCHAMPIONSHIPCW, RFCHAMPIONSHIPSSB,
      SOUTHAMERICANWW, UCG, UKEI, UKRAINECHAMPIONSHIP, WWL, XMAS,
      YOUTHCHAMPIONSHIPRF);

(* Asked of the walked object (issue #96): a contest registered by its id is
  no legacy member, so it is never on the list. *)
function IsEnumSpelledDisplayName(aContest: TContestBase): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(ENUM_SPELLED_DISPLAY_NAMES) to High(ENUM_SPELLED_DISPLAY_NAMES) do
      begin
      if IsLegacyContest(aContest, ENUM_SPELLED_DISPLAY_NAMES[i]) then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure TContestDisplayTests.Test_EveryClassStatesItsIdentity;
const
   KIND_NAMES: array[0..2] of string = ('DisplayName', 'CabrilloName', 'ADIFContestId');
var
   contests: TContestIdentityList;
   codeOf: array[0..2] of TContestMethodCode;
   k, kind: integer;
   obj, parent: TContestBase;
   who: string;
begin
   BeginTest('Test_EveryClassStatesItsIdentity');
   codeOf[0] := DisplayNameCode;
   codeOf[1] := CabrilloNameCode;
   codeOf[2] := ADIFContestIdCode;

   (* EVERY REGISTERED CONTEST, by the registry (Q108 S1), so a contest
      registered by its id is asked too. *)
   contests := ContestsToWalk;
   for k := 0 to High(contests) do
      begin
      obj := contests[k];
      who := ContestWho(obj);
      (* STATED IN THE CLASS ITSELF: the getter is not the one its parent
         supplies -- a family base stating a name for its members would give
         two contests one name. *)
      for kind := Low(codeOf) to High(codeOf) do
         begin
         CheckTrue(ClassStatesItself(obj, codeOf[kind]), who + ' states its ' + KIND_NAMES[kind]);
         end;

      CheckTrue(obj.DisplayName <> '', who + ': a display name');
      (* THE HUMAN NAME: the friendly name where the contest has one. *)
      (* THE CONTEST'S OWN ID, never ContestTypeSA of its legacy member: a
        contest registered by its id has none, and was compared with
        "DUMMY CONTEST" until issue #96. For a legacy contest the id IS the
        enum spelling. *)
      if obj.FriendlyName <> ContestId(HandleOf(obj)) then
         begin
         CheckEquals(obj.FriendlyName, obj.DisplayName, who + ': display name is the friendly name');
         end;
      CheckEquals(Ord(IsEnumSpelledDisplayName(obj)),
                  Ord(obj.DisplayName = ContestId(HandleOf(obj))),
                  who + ': display name is the enum spelling only where listed');
      end;

   (* THE CHECK CAN FAIL -- a negative control. The ARRL DX family base states
      no display name, so it answers with TContestBase's getter, and the
      comparison above must see them as the same. *)
   obj := TContestClass(ContestClassFor(ARRLDXCW).ClassParent).Create(ContestHandleOf(ARRLDXCW));
   parent := TContestBase.Create(ContestHandleOf(ARRLDXCW));
   try
      CheckFalse(ClassStatesItself(obj, DisplayNameCode),
                 'a class that states no display name is seen not to');
      CheckFalse(ClassOverridesTheBase(obj, DisplayNameCode),
                 'and is seen to run the base''s getter');
      CheckTrue(DisplayNameCode(obj) = DisplayNameCode(parent),
                'the same code as a plain TContestBase');
   finally
      parent.Free;
      obj.Free;
      end;
end;

procedure TContestDisplayTests.RunAllTests;
begin
   Test_NewContestPromptsAreTheDialogsArms;
   Test_TotalsDisplay;
   Test_SummarySheet;
   Test_CabrilloHeaderAndMode;
   Test_WinterFieldDayFMIsWrittenFMAndScoredAsPhone;
   Test_HamScoreLineAsksTheContestForTheMode;
   Test_HamScoreStoredQsoReadsItsRecord;
   Test_HamScoreStoredQsoGridIsTheFinalExportsGrid;
   Test_HamScoreStoredQsoFollowsAnEditedSerial;
   Test_HourTotalsRunningScore;
   Test_OperatingAidsAndScorePosting;
   Test_QTCMenu;
   Test_CanonicalReceivedExchanges;
   Test_CanonicalSentExchanges;
   Test_SetUpNeverWritesMyState;
   Test_EveryClassStatesItsIdentity;
end;

end.
