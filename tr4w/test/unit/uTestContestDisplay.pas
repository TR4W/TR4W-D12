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
   VC,
   uContestBase,
   uContestRegistry,
   uTR4WStrings,
   uSettingsModel,
   (* SentMyState, ApplyContestSentState, ClearContestSentState -- 7.11. *)
   FCONTEST,
   (* BuildRxExchangeText / BuildSentExchangeText -- the real dispatchers. *)
   uExchangeBuilder,
   uTestContestObjects;

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

(* THE QSO-PARTY HEAD AS THE DIALOG COMPUTED IT: the row's P indexes the
  QSOParties table, and British Columbia was named out of it. *)
function ExpectedHead(aContest: ContestType): string;
var
   state: string;
begin
   Result := '';
   if (ContestsArray[aContest].P = 0) or (aContest = BCQP) then
      begin
      Exit;
      end;
   state := QSOParties[ContestsArray[aContest].P].StateName;
   Result := StepComment(Format(TC_ENTERYOURCOUNTYORSTATEPOROVINCEDX, [state, state]),
                         ncfMyState);
end;

(* GENERATED from the dialog's two `case` statements at 69828f2a -- see the
  unit header. The three classless contests (POTA, RSGB 1.8, the UA4W
  Championship) are absent: their arms are still the dialog's. *)
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
         CheckEquals(Ord(c in [ARRL10, WINTERFIELDDAY]), Ord(obj.RequiresCabrilloLocation),
                     string(ContestTypeSA[c]) + ': needs a LOCATION');
         if c <> WINTERFIELDDAY then
            begin
            CheckEquals('', obj.CabrilloHeaderLinesBeforeTag('LOCATION', 'FL', station),
                        string(ContestTypeSA[c]) + ': no lines before LOCATION');
            CheckEquals('FM', obj.CabrilloModeString(FM, eFM),
                        string(ContestTypeSA[c]) + ': FM is FM');
            end;
         if c <> GENERALQSO then
            begin
            CheckEquals(obj.CabrilloName, obj.CabrilloContestName('A TITLE', 'A NAME'),
                        string(ContestTypeSA[c]) + ': the CONTEST: name is the Cabrillo name');
            end;
         (* The base column, every contest: digital RY or DG, CW, phone. *)
         CheckEquals('RY', obj.CabrilloModeString(Digital, eRTTY), string(ContestTypeSA[c]) + ' RTTY');
         CheckEquals('RY', obj.CabrilloModeString(Digital, eNoMode), string(ContestTypeSA[c]) + ' digital');
         CheckEquals('DG', obj.CabrilloModeString(Digital, eFT8), string(ContestTypeSA[c]) + ' FT8');
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
      CheckEquals('PH', obj.CabrilloModeString(FM, eFM), 'Winter Field Day writes FM as PH');
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
function CanonicalQSO(aContest: ContestType): ContestExchange;
begin
   FillChar(Result, SizeOf(Result), 0);
   Result.ceContest := aContest;
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
   c: ContestType;
   i: integer;
   obj: TContestBase;
   session: TSessionDefaults;
   saved: string;
   who: string;

   (* What one contest's set-up does to MY STATE, and what it sends. *)
   procedure SetUpFor(aContest: ContestType; const aStation: TStationContext;
                   out aSent: string; out aStated: boolean);
   begin
      Settings.My.State := aStation.MyState;
      ClearContestSentState;
      obj := Make(aContest);
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
      for c := Low(ContestType) to High(ContestType) do
         begin
         for i := Low(stations) to High(stations) do
            begin
            who := string(ContestTypeSA[c]) + ' for ' + stations[i].MyCall;
            SetUpFor(c, stations[i], sent, stated);
            CheckEquals(stations[i].MyState, Settings.My.State, who + ': MY STATE is untouched');
            if not stated then
               begin
               CheckEquals(stations[i].MyState, sent, who + ': sends MY STATE');
               end;
            end;
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
      class to keep in step. *)
   TIdentityCracker = class(TContestBase);
   TIdentityGetter = function: string of object;
   TIdentityGetterKind = (igDisplay, igCabrillo, igADIF);

function GetterCode(aObj: TContestBase; aKind: TIdentityGetterKind): CodePointer;
var
   getter: TIdentityGetter;
begin
   getter := nil;
   case aKind of
      igDisplay:
         begin
         getter := TIdentityCracker(aObj).GetDisplayName;
         end;
      igCabrillo:
         begin
         getter := TIdentityCracker(aObj).GetCabrilloName;
         end;
      igADIF:
         begin
         getter := TIdentityCracker(aObj).GetADIFContestId;
         end;
   end;
   Result := TMethod(getter).Code;
end;

(* THE CONTESTS WHOSE DISPLAY NAME IS STILL THEIR ENUM SPELLING -- their row
  has no FriendlyName, so there was no human name to state. A RATCHET: a
  contest given a human name leaves this list, and a new contest may not join
  it. Design Q57 asks NY4I for the names. *)
const
   ENUM_SPELLED_DISPLAY_NAMES: array[0..46] of ContestType = (
      ALLJA, ALRS_UA1DZ_CUP, APSPRINT, ARCI, BWQP, CUPRFCW, CUPRFDIG, CUPRFSSB,
      CUPURAL, EUDX, EUROPEANVHF, EUSPRINT_SPRING_CW, FOCMARATHON, GRIDLOC,
      INTERNETSPRINT, IRTS, JALONGPREFECT, JTDX, KVP, MINITEST, MWC, OLDNEWYEAR,
      OZCR_O, OZCR_Z, OZHCRVHF, PCC, QCWAGOLDEN, R9W_UW9WK_MEMORIAL, RADIOMEMORY,
      RADIOVHFFD, RADIOYOC, REGION1FIELDDAY, REGION1FIELDDAY_RCC_CW,
      REGION1FIELDDAY_RCC_SSB, RFASCHAMPIONSHIPCW, RFCHAMPIONSHIPCW,
      RFCHAMPIONSHIPSSB, SASPRINT, SOUTHAMERICANWW, TOEC, UCG, UKEI,
      UKRAINECHAMPIONSHIP, WWL, XMAS, YOUTHCHAMPIONSHIPRF, YUDX);

function IsEnumSpelledDisplayName(aContest: ContestType): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(ENUM_SPELLED_DISPLAY_NAMES) to High(ENUM_SPELLED_DISPLAY_NAMES) do
      begin
      if ENUM_SPELLED_DISPLAY_NAMES[i] = aContest then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

procedure TContestDisplayTests.Test_EveryClassStatesItsIdentity;
var
   c: ContestType;
   cls: TContestClass;
   obj, parent: TContestBase;
   kind: TIdentityGetterKind;
   who: string;
   classes: integer;
const
   KIND_NAMES: array[TIdentityGetterKind] of string =
      ('DisplayName', 'CabrilloName', 'ADIFContestId');
begin
   BeginTest('Test_EveryClassStatesItsIdentity');
   classes := 0;
   for c := Low(ContestType) to High(ContestType) do
      begin
      cls := ContestClassFor(c);
      if cls = nil then
         begin
         Continue;
         end;
      inc(classes);
      who := string(ContestTypeSA[c]) + ' (' + cls.ClassName + ')';
      obj := cls.Create(c);
      parent := TContestClass(cls.ClassParent).Create(c);
      try
         (* STATED IN THE CLASS ITSELF: the getter is not the one its parent
            supplies -- a family base stating a name for its members would
            give two contests one name. *)
         for kind := Low(TIdentityGetterKind) to High(TIdentityGetterKind) do
            begin
            CheckTrue(GetterCode(obj, kind) <> GetterCode(parent, kind),
                      who + ' states its ' + KIND_NAMES[kind]);
            end;

         CheckTrue(obj.DisplayName <> '', who + ': a display name');
         (* THE HUMAN NAME: the friendly name where the contest has one. *)
         if obj.FriendlyName <> string(ContestTypeSA[c]) then
            begin
            CheckEquals(obj.FriendlyName, obj.DisplayName, who + ': display name is the friendly name');
            end;
         CheckEquals(Ord(IsEnumSpelledDisplayName(c)),
                     Ord(obj.DisplayName = string(ContestTypeSA[c])),
                     who + ': display name is the enum spelling only where listed');
      finally
         parent.Free;
         obj.Free;
         end;
      end;
   CheckEquals(RegisteredContestCount, classes, 'every registered class was asked');

   (* THE CHECK CAN FAIL -- a negative control. The ARRL DX family base states
      no display name, so it answers with TContestBase's getter, and the
      comparison above must see them as the same. *)
   cls := TContestClass(ContestClassFor(ARRLDXCW).ClassParent);
   obj := cls.Create(ARRLDXCW);
   parent := TContestBase.Create(ARRLDXCW);
   try
      CheckTrue(GetterCode(obj, igDisplay) = GetterCode(parent, igDisplay),
                'a class that states no display name is seen not to');
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
   Test_HourTotalsRunningScore;
   Test_OperatingAidsAndScorePosting;
   Test_QTCMenu;
   Test_CanonicalReceivedExchanges;
   Test_CanonicalSentExchanges;
   Test_SetUpNeverWritesMyState;
   Test_EveryClassStatesItsIdentity;
end;

end.
