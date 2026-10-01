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
   end;

implementation

uses
   SysUtils, uTR4WStrings, uContestRegistry,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   (* STATE from the worked station's section -- a leaf, lifted at M4. *)
   uARRLSections;

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
   section". So a QSO whose QTH is 'DX' writes NONE of these fields: no
   ARRL_SECT, no STATE, no DXCC and no CLASS. The CLASS half of that is what
   the arm always did and is recorded as a question for NY4I (design 8.2e): a
   DX station does send a class.

   DXCC 291 and 1 are hard-coded as the arm had them (ny4i): a K section is
   in the US and a VE section in Canada. *)
function TContestWinterFieldDay.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := '';
   if aQso.QTHString = 'DX' then
      begin
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

initialization
   RegisterContest(WINTERFIELDDAY, TContestWinterFieldDay);

end.
