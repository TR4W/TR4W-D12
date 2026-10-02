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

(* THE BATAVIA FT8 CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 677;  QRZRUID: 0;
   Pxm: Prefix;  ZnM: NoZoneMults;  AIE: GridInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: GridExchange;
   XM: CQDXCC;  QP: YBFT8QP;  ADIFName: '';
   CABName: 'BATAVIA';  FriendlyName: 'Batavia FT8 Contest'

  Blank ADIFName is the enum's spelling, 'BATAVIA-FT8'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = BATAVIA_FT8` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS YBFT8QP, transcribed exactly. An Indonesian station (YB to YF,
  uCallSignRoutines.IndonesianCountry): 1 for another Indonesian, 2 otherwise.
  Anyone else: 2 for an Indonesian, 1 for another country, 0 for our own.
  Then 5 for CTY country 'XYZ' when the contest title is 'YBDXDI-FT8' -- a
  test inventory D7 records as unable to match (the title is built as '<year>
  <name> <call>', and no CTY.DAT country is XYZ). Transcribed, through
  TStationContext.ContestTitle, not judged.

  ITS ADIF FIELD: the worked grid goes to GRIDSQUARE (postunit's
  `ARRLDIGI, WWDIGI, BATAVIA_FT8` arm; each of the three owns a copy). *)
unit uContestBataviaFT8;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestBataviaFT8 = class(TContestBase)
   protected
      (* PROTECTED, MATCHING THE BASE -- callers use the properties,
         descendants override the getters. Every getter below states
         the ContestsArray row quoted above. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetQRZRUId: integer; override;
      function GetSubmissionEmail: string; override;
      function GetDomesticFileName: string; override;
      function GetFriendlyName: string; override;
      function GetPrefixMultiplierType: PrefixMultType; override;
      function GetZoneMultiplierType: ZoneMultType; override;
      function GetDXMultiplierType: DXMultType; override;
      function GetDomesticMultiplierType: DomesticMultType; override;
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetQSOPointMethod: QSOPointMethodType; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   SysUtils, uContestRegistry,
   (* IndonesianCountry -- the arm's own test, already a leaf. *)
   uCallSignRoutines,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   uTR4WStrings;

procedure TContestBataviaFT8.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if IndonesianCountry(string(Station.MyCountry)) then
      begin
      if IndonesianCountry(string(aQso.QTH.CountryID)) then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 2;
         end;
      end
   else
      begin
      if IndonesianCountry(string(aQso.QTH.CountryID)) then
         begin
         aQso.QSOPoints := 2;
         end
      else if aQso.QTH.CountryID <> Station.MyCountry then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 0;
         end;
      end;

   if (Station.ContestTitle = 'YBDXDI-FT8') and (aQso.QTH.CountryID = 'XYZ') then
      begin
      aQso.QSOPoints := 5;
      end;
end;

function TContestBataviaFT8.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := EmitADIFField('GRIDSQUARE', string(aQso.QTHString));
end;

function TContestBataviaFT8.GetDisplayName: string;
begin
   Result := 'Batavia FT8 Contest';
end;

function TContestBataviaFT8.GetCabrilloName: string;
begin
   Result := 'BATAVIA';
end;

function TContestBataviaFT8.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'BATAVIA-FT8';
end;

function TContestBataviaFT8.GetWA7BNMId: integer;
begin
   Result := 677;
end;

function TContestBataviaFT8.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestBataviaFT8.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestBataviaFT8.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestBataviaFT8.GetFriendlyName: string;
begin
   Result := 'Batavia FT8 Contest';
end;

function TContestBataviaFT8.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := Prefix;
end;

function TContestBataviaFT8.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestBataviaFT8.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestBataviaFT8.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := NoDomesticMults;
end;

function TContestBataviaFT8.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := GridInitialExchange;
end;

function TContestBataviaFT8.GetExchangeKind: ExchangeType;
begin
   Result := GridExchange;
end;

function TContestBataviaFT8.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := YBFT8QP;
end;

function TContestBataviaFT8.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestBataviaFT8.DescribeSession(const aStation: TStationContext;
                                             aSession: TSessionDefaults);
begin
   aSession.DigitalModeEnable := True;
   aSession.QSOByMode := False;
   aSession.QSOByBand := True;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDIGI, ARRLVHFJAN, ARRLVHFJUN,
   ARRLVHFSEP, CQVHF, CUPRFCW, CUPRFDIG, CUPRFSSB, MAKROTHEN, RTC,
   STEWPERRY, TESLA, WWDIGI.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestBataviaFT8.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURFOURDIGITGRIDSQUARE, ncfMyGrid);
end;

initialization
   RegisterContest(BATAVIA_FT8, TContestBataviaFT8);

end.
