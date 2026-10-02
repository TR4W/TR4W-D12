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

(* WINTER FIELD DAY -- January.

  One point for phone, two for everything else, with FM counted as phone --
  the same rule ARRL Field Day uses THIS YEAR.

  THIS SCORING IS DELIBERATELY NOT SHARED WITH WINTER FIELD DAY, even though
  the two rules are identical today and a base class was written for them and
  then deleted.

  NY4I, 2026-09-02: "I would diverge winter field day and arrl field day. They
  keep diverging with rule changes each year."

  That is an operational argument and it beats the tidiness one. These are two
  contests run by different organisations that revise their rules
  independently, and a shared base makes every future divergence a REFACTOR --
  extract the difference, push it down, re-test both -- at the exact moment
  somebody is trying to make a small change before a contest weekend. Two
  classes that happen to agree cost one duplicated `if` and make next year's
  change a three-line edit to one file that cannot affect the other.

  TR4QT reaches the same conclusion: ARRLFieldDayContest and
  WinterFieldDayContest are separate there too, with no FieldDayBase between
  them, despite scoring identically.

  SO THE DUPLICATION HERE IS INTENDED. It is not an extraction somebody has not
  got round to, and it should not be "fixed" -- the identical code in
  uContestWinterFieldDay is a coincidence of this year's rules, not a shared
  rule.

  WFD ALREADY DIFFERS ELSEWHERE, which is the point: it disallows FT8 and FT4,
  and its exchange carries a different class format. Those differences are not
  in TR4W yet -- when they arrive they arrive HERE, in a file that ARRL Field
  Day cannot be broken by. *)
unit uContestWinterFieldDay;

{$I tr4w.inc}

interface

uses
   (* cpLOW and cpQRP -- the entrant's CATEGORY-POWER, which multiplies the
      final score (M6). FIRST, so VC's names win where the two overlap, as
      in uContestBase. *)
   uSettingsModel,
   VC, uContestBase;

type
   TContestWinterFieldDay = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      (* ARRL DXCC WITHOUT THE ARRL SECTIONS -- see the implementation. *)
      function GetDXMultiplierType: DXMultType; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;

      (* THE FINAL SCORE -- Issue 301 (NY4I): the points times the band-mode
         multiplier, times two for a LOW entry and five for a QRP one. It was
         LogEdit.TotalScore's Winter Field Day arm; moved at M6. *)
      function CombineWithMultipliers(const aTotals: TScoreTotals): longint; override;
   public
      function ValidateClass(const aClass: string;
                             out aErrorMessage: string): boolean; override;
      function ValidateDXQTH(const aQTH: string;
                             out aResolved: string;
                             out aErrorMessage: string): boolean; override;

      function FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange;
                                          const aCtx: TCabrilloQSOContext): string; override;
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
      function FormatADIFSentExchange(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aSessionExchange: ExchangeType): string; override;

      (* THE WORKED STATION'S ADIF FIELDS -- see the implementation. *)
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;

      (* A DX STATION'S SRX_STRING IS ITS CLASS AND 'DX' -- M5b, NY4I
         2026-10-02 (design 7.10, Q20), as for ARRL Field Day; this class owns
         its own copy (design 1.4). *)
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   SysUtils, uTR4WStrings, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   (* STATE from the worked station's section -- a leaf, lifted at M4. *)
   uARRLSections;

(* THE DX MULTIPLIER IS DXCC WITHOUT THE ARRL SECTIONS -- M7a, 2026-10-02.

   THE ROW SAID ARRLDXCC AND NO SESSION EVER RAN IT. FCONTEST.FoundContest's
   Winter Field Day arm set ARRLDXCCWithNoARRLSections after the head had
   written the row's value, every time, so the row was a value nothing used --
   the shape of inventory D8, as Field Day's was before Q1. When the arm moved
   into DescribeSession the class, the row and the session were made to say
   the one value that is actually in force, as Field Day's were at M2. A
   sponsor rule is not being changed: the multiplier every Winter Field Day
   session has counted is now also what the contest SAYS it counts.
   Test_WinterFieldDayDXMultiplierIsWhatTheSessionRuns pins the three. *)
function TContestWinterFieldDay.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCCWithNoARRLSections;
end;

procedure TContestWinterFieldDay.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.Mode in [Phone, FM] then
      begin
      aQso.QSOPoints := 1;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

(* THE BAND-MODE MULTIPLIER: one for each band from 160 m to 1296 MHz and
   each of digital, CW and phone that has a QSO -- read from the QSO counts,
   which FM already joins to phone. Transcribed from LogEdit.TotalScore, which
   read the same counts from the totals window's copy of them (QTotals); the
   score now reads the counts themselves (TScoreTotals.QSOs), which that copy
   is taken from. The power factor is the entrant's CATEGORY-POWER, the value
   TotalScore read through Settings.Contest.CategoryPower. *)
function TContestWinterFieldDay.CombineWithMultipliers(const aTotals: TScoreTotals): longint;
var
   b: BandType;
   bandModes: longint;
begin
   bandModes := 0;
   for b := Low(BandType) to Band1296 do
      begin
      if aTotals.QSOs[b, Digital] > 0 then
         begin
         inc(bandModes);
         end;
      if aTotals.QSOs[b, CW] > 0 then
         begin
         inc(bandModes);
         end;
      if aTotals.QSOs[b, Phone] > 0 then
         begin
         inc(bandModes);
         end;
      end;

   Result := bandModes * ContestPoints(aTotals);
   if Station.MyPower = cpLOW then
      begin
      Result := Result * 2;
      end
   else if Station.MyPower = cpQRP then
      begin
      Result := Result * 5;
      end;
end;

(* I, O, H and M -- Indoor, Outdoor, Home and Mobile. A DIFFERENT set from ARRL Field Day, which is the clearest evidence that these two belong in separate classes.

   The COUNT-then-LETTER parsing is TContestBase's -- it is mechanism, and
   identical for any contest with a class. What is this contest's is the
   letter set and the message. *)
function TContestWinterFieldDay.ValidateClass(const aClass: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateCountAndLetterClass(aClass, 'IOHM',
                                         TC_IMPROPERWINTERFIELDDAYCLASS, aErrorMessage);
end;

(* DX, or MX. Winter Field Day accepts MX where ARRL Field Day does not -- the second place these two differ today, after the class letters. *)
function TContestWinterFieldDay.ValidateDXQTH(const aQTH: string;
                          out aResolved: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateDXQTHAllowing(aQTH, 'MX', aResolved, aErrorMessage);
end;

(* THE EXCHANGE IS CLASS AND SECTION, both ways round.

   Widths are the legacy arms' exactly -- '%-3s %-7s' with a TRAILING SPACE on
   the sent side and none on the received. Cabrillo is a column format and a
   width is not cosmetic: a submitted log with the columns a character out is a
   log a robot scorer reads wrongly.

   THE RECEIVED QTH IS THE QSO'S OWN, not the his-QTH the exporter selected.
   The legacy arm said so with an `if Contest in [ARRLFIELDDAY, WINTERFIELDDAY]`
   that overwrote csQTHString just before use (issue 407) -- one more contest
   test, now expressed by simply not using the parameter. That branch was
   DELETED 2026-09-29, and at M4 (2026-10-01) the shared
   ClassDomesticOrDXQTHExchange arm went too: only the two Field Days run this
   exchange, and both format their own (inventory D4). *)
function TContestWinterFieldDay.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                           const aQso: ContestExchange;
                                                           const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s ', [aMy.MyFDClass, aMy.MySection]);
end;

function TContestWinterFieldDay.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                               const aQso: ContestExchange;
                                                               const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [string(aQso.ceClass), string(aQso.QTHString)]);
end;

(* THE WORKED STATION'S ADIF FIELDS -- M4, 2026-10-01: the arm postunit's
   EmitContestSpecificTailForExport kept for ARRLFIELDDAY and WINTERFIELDDAY,
   moved here, and copied into uContestARRLFieldDay (design 1.4: the two Field Days diverge,
   so each owns its copy).

   DX IS NEVER AN ARRL SECTION. NY4I, 2026-10-01: a DX station sends its
   class and 'DX'; that goes in the section POSITION of the Cabrillo line
   (FormatCabrilloReceivedExchange writes QTHString there) but never into
   ADIF ARRL_SECT -- "be explicit about the source and never call DX an ARRL
   section". So a QSO whose QTH is 'DX' writes no ARRL_SECT, no STATE and no
   DXCC.

   IT WRITES ITS CLASS, SINCE M5b. NY4I, 2026-10-02 (design 7.10, Q20):
   "CLASS is whatever was logged (usually 1D); ARRL_SECT is never written for
   DX". The arm wrote no CLASS for a DX station, although one sends a class.

   DXCC 291 and 1 are hard-coded as the arm had them (ny4i): a K section is
   in the US and a VE section in Canada. *)
function TContestWinterFieldDay.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := '';
   if aQso.QTHString = 'DX' then
      begin
      Result := EmitADIFField('CLASS', string(aQso.ceClass));
      Exit;
      end;

   if aQso.QTH.CountryID = 'K' then
      begin
      Result := Result + EmitADIFField('DXCC', '291');
      Result := Result + EmitADIFField('STATE',
         StateFromARRLSection(string(aQso.QTHString)));
      end
   else if aQso.QTH.CountryID = 'VE' then
      begin
      Result := Result + EmitADIFField('DXCC', '1');
      Result := Result + EmitADIFField('STATE',
         StateFromARRLSection(string(aQso.QTHString)));
      end;
   Result := Result + EmitADIFField('ARRL_SECT', string(aQso.QTHString));
   Result := Result + EmitADIFField('CLASS', string(aQso.ceClass));
end;

function TContestWinterFieldDay.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                       const aQso: ContestExchange;
                                                       aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-3s %-7s ', [aMy.MyFDClass, aMy.MySection]);
end;

function TContestWinterFieldDay.GetDisplayName: string;
begin
   Result := 'Winter Field Day';
end;

(* THE SECTION, FROM ARRL_SECT -- BUT AN ABSENT TAG IS NOT AN EMPTY SECTION.
   D7 writes ARRL_SECT for Sweepstakes and does not write it for Winter Field
   Day -- that log carries the section in <QTH> alone. Assigning it
   unconditionally ERASED a section the generic import had already read
   correctly, on 1310 of the 1316 QSOs in the corpus's winter_fd set. So
   ARRL_SECT wins when it is present, because it is the unambiguous field;
   otherwise whatever <QTH> supplied stands, and the domestic multiplier is
   taken from it.

   N1MM WRITES THE CLASS IN APP_N1MM_EXCHANGE1 instead of the standard CLASS
   tag. It is read HERE, after the whole record, so the order the two tags
   arrive in no longer decides anything: the standard CLASS wins when the
   record has it, and N1MM's tag fills in a record that has none. (Until M5a
   whichever tag came LAST won, and the N1MM tag was read only when it came
   after CONTEST_ID.)

   DX IS NOT A SECTION, ON THE WAY IN EITHER -- M5b, design Q25, as for ARRL
   Field Day: a QTH of 'DX', in <QTH> or in another logger's ARRL_SECT, stays
   the QSO's QTH and is never made its domestic QTH -- what the live parse
   does. Until M5b the import alone made it a section. *)
procedure TContestWinterFieldDay.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                             const aSession: TADIFImportSession;
                                             var aExch: ContestExchange);
begin
   if UpperCase(Trim(aTemps.ARRL_Sect)) = 'DX' then
      begin
      aExch.QTHString := 'DX';
      end
   else if aTemps.ARRL_Sect <> '' then
      begin
      aExch.DomesticQTH := ShortString(aTemps.ARRL_Sect);
      aExch.QTHString   := ShortString(aTemps.ARRL_Sect);
      end
   else if UpperCase(Trim(string(aExch.QTHString))) = 'DX' then
      begin
      aExch.QTHString := 'DX';
      end
   else if aExch.QTHString <> '' then
      begin
      aExch.DomesticQTH := aExch.QTHString;
      end;

   if (aExch.ceClass = '') and (aTemps.N1MM_Exchange1 <> '') then
      begin
      aExch.ceClass := ShortString(UpperCase(aTemps.N1MM_Exchange1));
      end;
end;

function TContestWinterFieldDay.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                           aExchangeCarriesRST: boolean): string;
begin
   if aQso.QTHString = 'DX' then
      begin
      Result := Trim(string(aQso.ceClass) + ' DX');
      end
   else
      begin
      Result := inherited FormatADIFReceivedExchange(aQso, aExchangeCarriesRST);
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestWinterFieldDay.DescribeSession(const aStation: TStationContext;
                                                 aSession: TSessionDefaults);
begin
   aSession.WARCEnabled := False;
   aSession.SetCQMemory(CW, smkF1, 'CQ^WFD \ \ TEST');
   aSession.SetCQMemory(CW, smkF2, 'CQ^WFD CQ^WFD \ \ TEST');
   aSession.CQExchangeCW := ' ' + aStation.MyFDClass + ' ' + aStation.MySection;
   aSession.SPExchangeCW := aStation.MyFDClass + ' ' + aStation.MySection;
   aSession.QSLCW := '73 \ WFD';

   (* THE SAME VALUE AS THE TRAIT SINCE M7a -- see GetDXMultiplierType. It is
      still stated here because the arm stated it, and so it still overwrites
      a DX MULTIPLIER statement made before the CONTEST line, as it always
      did. *)
   aSession.DXMult := ARRLDXCCWithNoARRLSections;
   aSession.AddDomesticCountries(DomesticCountriesARRLSections);
end;

initialization
   RegisterContest(WINTERFIELDDAY, TContestWinterFieldDay);

end.
