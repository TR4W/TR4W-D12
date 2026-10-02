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

(* ARRL FIELD DAY -- June.

  One point for phone, two for everything else, with FM counted as phone.

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

  WHAT IS DELIBERATELY ABSENT: the Class D restriction. Two commented-out blocks
  in the legacy arm zero the points when both stations are Class D, with a note
  reading "Removed this restriction as it continues for 2022 and perhaps beyond"
  (issue 575). It is off, and moving code into a class is not the moment to turn
  a rule back on. *)
unit uContestARRLFieldDay;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRLFieldDay = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetIsUSQSOParty: boolean; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
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

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I: "All that content would be represented or processed in the
         contest class."

         Every one of these currently returns what the array holds, so this
         changes no behaviour -- it moves the ANSWER, so that reading this one
         file tells you what ARRL Field Day is without cross-referencing a
         200-row table by enum position. When the array goes, these are already
         the definition.

         The array row this replaces, verbatim:

           Email: 'fieldday@arrl.org';  DF: 'arrlsect';  WA7BNM: 57;
           QRZRUID: 0;  Pxm: NoPrefixMults;  ZnM: NoZoneMults;
           AIE: NoInitialExchange;  {DM: NoDomesticMults;}  P: 0;
           AE: ClassDomesticOrDXQTHExchange;  XM: ARRLDXCC;
           QP: ARRLFieldDayQSOPointMethod;  ADIFName: 'ARRL-FIELD-DAY';
           CABName: 'ARRL-FD';  FriendlyName: 'ARRL Field Day'

         XM WAS WRONG and is NoDXMults in both the row and this class since
         2026-10-01 -- see GetDXMultiplierType.

         NOTE DM IS COMMENTED OUT IN THE ARRAY. Its value therefore comes from
         whatever the record initialises to, not from NoDomesticMults being
         chosen -- so DomesticMultiplierType is deliberately NOT overridden
         here. Stating a value would be inventing one, and Field Day's sections
         ARE its domestic multipliers, so the right answer is not obviously
         "none". Left reading the array until somebody establishes what it
         should be. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;

      (* A DX STATION'S SRX_STRING IS ITS CLASS AND 'DX' -- M5b, NY4I
         2026-10-02 (design 7.10, Q20): "SRX_STRING is the full received
         exchange, 1D DX." Whatever was typed -- the class alone resolves to
         DX -- the record says what the DX station sent. Every other QSO is
         the base's. *)
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;
   end;

implementation

uses
   SysUtils, uTR4WStrings, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   (* STATE from the worked station's section -- a leaf, lifted at M4. *)
   uARRLSections;

procedure TContestARRLFieldDay.CalculateQSOPoints(var aQso: ContestExchange);
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

(* A through F -- ARRL Field Day class letters.

   The COUNT-then-LETTER parsing is TContestBase's -- it is mechanism, and
   identical for any contest with a class. What is this contest's is the
   letter set and the message. *)
function TContestARRLFieldDay.ValidateClass(const aClass: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateCountAndLetterClass(aClass, 'ABCDEF',
                                         TC_IMPROPERARRLFIELDDAYCLASS, aErrorMessage);
end;

(* DX and nothing else. A DX station sends its class and the word DX. *)
function TContestARRLFieldDay.ValidateDXQTH(const aQTH: string;
                          out aResolved: string;
                          out aErrorMessage: string): boolean;
begin
   Result := ValidateDXQTHAllowing(aQTH, '', aResolved, aErrorMessage);
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
function TContestARRLFieldDay.FormatCabrilloSentExchange(const aMy: TMyStationExchange;
                                                         const aQso: ContestExchange;
                                                         const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s ', [aMy.MyFDClass, aMy.MySection]);
end;

function TContestARRLFieldDay.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                             const aQso: ContestExchange;
                                                             const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %-7s', [string(aQso.ceClass), string(aQso.QTHString)]);
end;

(* THE WORKED STATION'S ADIF FIELDS -- M4, 2026-10-01: the arm postunit's
   EmitContestSpecificTailForExport kept for ARRLFIELDDAY and WINTERFIELDDAY,
   moved here, and copied into uContestWinterFieldDay (design 1.4: the two Field Days diverge,
   so each owns its copy).

   DX IS NEVER AN ARRL SECTION. NY4I, 2026-10-01: a DX station sends its
   class and 'DX'; that goes in the section POSITION of the Cabrillo line
   (FormatCabrilloReceivedExchange writes QTHString there) but never into
   ADIF ARRL_SECT -- "be explicit about the source and never call DX an ARRL
   section". So a QSO whose QTH is 'DX' writes no ARRL_SECT, no STATE and no
   DXCC.

   IT WRITES ITS CLASS, SINCE M5b. NY4I, 2026-10-02 (design 7.10, Q20):
   "CLASS is whatever was logged (usually 1D); ARRL_SECT is never written for
   DX" -- "class and section are different". The arm wrote no CLASS for a DX
   station, although a DX station sends one.

   DXCC 291 and 1 are hard-coded as the arm had them (ny4i): a K section is
   in the US and a VE section in Canada. *)
function TContestARRLFieldDay.EmitADIFContestFields(const aQso: ContestExchange): string;
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

function TContestARRLFieldDay.FormatADIFSentExchange(const aMy: TMyStationExchange;
                                                     const aQso: ContestExchange;
                                                     aSessionExchange: ExchangeType): string;
begin
   Result := Format('%-3s %-7s ', [aMy.MyFDClass, aMy.MySection]);
end;

function TContestARRLFieldDay.GetDisplayName: string;
begin
   Result := 'ARRL Field Day';
end;

function TContestARRLFieldDay.GetCabrilloName: string;
begin
   (* The CONTEST: line of a submitted log. Not the same string as the ADIF id
      below, which is the trap the identifiers exist to make visible. *)
   Result := 'ARRL-FD';
end;

function TContestARRLFieldDay.GetADIFContestId: string;
begin
   Result := 'ARRL-FIELD-DAY';
end;

function TContestARRLFieldDay.GetWA7BNMId: integer;
begin
   Result := 57;
end;

function TContestARRLFieldDay.GetSubmissionEmail: string;
begin
   Result := 'fieldday@arrl.org';
end;

function TContestARRLFieldDay.GetDomesticFileName: string;
begin
   (* domrrlsect.dom -- the ARRL/RAC section list, an INSTALLED RESOURCE.
      A <logstem>.DOM beside the log still overrides it; see LogCfg. *)
   Result := 'arrlsect';
end;

function TContestARRLFieldDay.GetFriendlyName: string;
begin
   Result := 'ARRL Field Day';
end;

function TContestARRLFieldDay.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARRLFieldDay.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARRLFieldDay.GetDXMultiplierType: DXMultType;
begin
   (* NONE. RULED BY NY4I, 2026-10-01 (design Q1): ARRL Field Day has no
      multipliers at all. A DX station may be worked -- it sends a class and
      DX -- but it is not a multiplier.

      THIS USED TO SAY ARRLDXCC, transcribed from the row, while FCONTEST's
      Field Day arm set NoDXMults; the class lost silently because nothing
      read it (inventory D8). Corrected, together with the row, BEFORE M2
      made the class the source set-up reads, so Field Day's effective value
      did not move. *)
   Result := NoDXMults;
end;

function TContestARRLFieldDay.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARRLFieldDay.GetExchangeKind: ExchangeType;
begin
   Result := ClassDomesticOrDXQTHExchange;
end;

function TContestARRLFieldDay.GetIsUSQSOParty: boolean;
begin
   Result := False;
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

   DX IS NOT A SECTION, ON THE WAY IN EITHER -- M5b, design Q25. NY4I: "never
   call DX an ARRL section"; Field Day has no multipliers at all (Q1). A QTH
   of 'DX' -- in <QTH>, or in an ARRL_SECT another logger wrote -- stays the
   QSO's QTH, where Cabrillo puts it in the section position, and is never
   made its domestic QTH. That is exactly what the live parse does: a DX
   station's 'DX' is QTHString and DomesticQTH stays empty. Until M5b the
   import alone made it a section. *)
procedure TContestARRLFieldDay.ApplyADIFImport(const aTemps: TADIFRecordTemps;
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

function TContestARRLFieldDay.FormatADIFReceivedExchange(const aQso: ContestExchange;
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

initialization
   RegisterContest(ARRLFIELDDAY, TContestARRLFieldDay);

end.
