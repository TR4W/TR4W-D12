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

(* ARKTIKA SPRING.

  THREE POINTS FOR A DOMESTIC MULTIPLIER QTH, ONE FOR EVERYTHING ELSE -- the
  whole of ArktikaSpringQSOPointMethod, which was one arm of LOGSTUFF's 88-way
  case and is now this class.

  IT TESTS DomMultQTH AND NOT DomesticQTH, and the two are different fields on
  ContestExchange: DomesticQTH is the corrected QTH, DomMultQTH is the string
  the multiplier count is keyed on. Reproducing the arm means reproducing which
  field it read; substituting the more familiar one would score every QSO the
  same for a log where the two diverge, and nothing would say so. *)
unit uContestArktikaSpring;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestArktikaSpring = class(TContestBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. A class body with no visibility section
         defaults to public, which would make both X.DisplayName and
         X.GetDisplayName callable -- two ways to ask one question is exactly
         the ambiguity a property removes. *)
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
      function GetIsUSQSOParty: boolean; override;

      (* THE NARROWER CABRILLO QSO LINE -- taken over from PostUnit, where it
         was written as an `if Contest = ARKTIKA_SPRING`.

         It consumes only the first FOUR of the five arguments the general
         layout takes; the multi-op flag is dropped, and Format ignores the
         trailing argument it is still handed. That is how the legacy code
         served both layouts from one argument list, and it is preserved here
         rather than tidied -- changing the argument list would change the
         bytes of every other contest's Cabrillo. *)
      function GetCabrilloQSOLineFormat: string; override;
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public

      (* THE WHOLE ContestsArray ROW, STATED HERE.

         NY4I, 2026-09-29: "all the info in [the row] should go into the contest
         class."

         Every getter above returns what the array holds today, so this changes
         no behaviour -- it moves the ANSWER, so that reading this one file tells
         you what Arktika Spring is without cross-referencing a 200-row table by
         enum position. When the array goes, these are already the definition.

         The array row this replaces, verbatim:

           Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 351;
           Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
           DM: WYSIWYGDomestic;  P: 0;
           AE: RSTAndQSONumberOrDomesticQTHExchange;  XM: NoDXMults;
           QP: ArktikaSpringQSOPointMethod;  ADIFName: '';  CABName: '';
           FriendlyName: ''

         THE ROW IS NOT DELETED AND MUST NOT BE. It still answers for every
         contest that has no class, and TContestBase still reads it for the ones
         that do not override. *)

      (* DIGITS AND BLANKS ARE A SERIAL, ANYTHING ELSE A QTH -- M5b.

         It stood in LOGSTUFF.ProcessRSTAndQSONumberOrDomesticQTHExchange as a
         test of ActiveQSOPointMethod = ArktikaSpringQSOPointMethod, ahead of
         that shape's own rule; stated here under that shape. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   end;

implementation

uses
   uContestRegistry,
   (* StringIsAllNumbersOrSpaces -- the test the arm made. *)
   utils_text;

function TContestArktikaSpring.ParseReceivedExchange(const aText: string;
                                                    const aSession: TReceivedExchangeSession;
                                                    var aExch: ContestExchange;
                                                    out aErrorMessage: string): boolean;
begin
   if aSession.Exchange <> RSTAndQSONumberOrDomesticQTHExchange then
      begin
      Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
      Exit;
      end;

   aErrorMessage := '';
   if StringIsAllNumbersOrSpaces(aText) then
      begin
      Result := aSession.ParseShape(RSTQSONumberExchange, aText, aExch);
      end
   else
      begin
      Result := aSession.ParseShape(RSTDomesticQTHExchange, aText, aExch);
      end;
end;

procedure TContestArktikaSpring.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.DomMultQTH <> '' then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

function TContestArktikaSpring.GetCabrilloQSOLineFormat: string;
begin
   Result := '%s%-12s%-10s%-10s' + #13#10;
end;

function TContestArktikaSpring.GetDisplayName: string;
begin
   Result := 'Arktika Spring';
end;

function TContestArktikaSpring.GetCabrilloName: string;
begin
   (* THE ROW'S CABName IS EMPTY, AND THIS IS NOT THE EMPTY STRING. PostUnit's
      rule -- reproduced by TContestBase.GetCabrilloName -- is that a blank
      CABName means the enum's own spelling, so the CONTEST: line of a submitted
      log reads ARKTIKA-SPRING. Returning '' here would put a blank CONTEST:
      line in the header, which is a different answer from the one the array
      produces. *)
   Result := 'ARKTIKA-SPRING';
end;

function TContestArktikaSpring.GetADIFContestId: string;
begin
   (* WHAT TR4W'S ADIF EXPORT WRITES, AND SO WHAT ITS IMPORT MATCHES. The
      row's ADIFName is blank, and export has always written the enum's own
      spelling in its place; this states that id. It was '' until M1
      (2026-10-01), which is why a file TR4W exported for this contest
      never re-imported to it (inventory D9). See
      TContestBase.GetADIFContestId. *)
   Result := 'ARKTIKA-SPRING';
end;

function TContestArktikaSpring.GetWA7BNMId: integer;
begin
   (* 0000 in the row: this contest is not in the WA7BNM calendar. *)
   Result := 0;
end;

function TContestArktikaSpring.GetQRZRUId: integer;
begin
   (* 351 -- the contest's id on the QRZ.RU calendar, which is where a Russian
      contest is listed when WA7BNM does not carry it. *)
   Result := 351;
end;

function TContestArktikaSpring.GetSubmissionEmail: string;
begin
   (* Blank in the row: no submission address is recorded for this contest. *)
   Result := '';
end;

function TContestArktikaSpring.GetDomesticFileName: string;
begin
   (* Blank, and consistent with WYSIWYGDomestic below: there is no .DOM file
      of legal QTHs, because whatever the operator types IS the QTH. *)
   Result := '';
end;

function TContestArktikaSpring.GetFriendlyName: string;
begin
   (* THE ROW'S FriendlyName IS BLANK, AND BLANK IS NOT THE ANSWER -- the same
      two-step as CabrilloName. The array's own note says "If blank, use
      ContestTypeSA[ct]", so what an operator actually sees is the enum
      spelling, ARKTIKA-SPRING.

      This was written as '' first and the transcription test caught it, which
      is the whole reason that test compares against a base object rather than
      against the raw record field: two of this row's fields are blank and
      NEITHER of them means the empty string. DisplayName above is the
      factory's own readable name and is a separate question. *)
   Result := 'ARKTIKA-SPRING';
end;

function TContestArktikaSpring.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestArktikaSpring.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestArktikaSpring.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestArktikaSpring.GetDomesticMultiplierType: DomesticMultType;
begin
   (* WYSIWYGDomestic -- the exchange's QTH is the multiplier as typed, with no
      .DOM file to validate it against. This one IS stated in the array (Field
      Day's DM is commented out and is therefore left reading the array); here
      there is a chosen value to move. *)
   Result := WYSIWYGDomestic;
end;

function TContestArktikaSpring.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestArktikaSpring.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestArktikaSpring.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- this is not a US state QSO party. *)
   Result := False;
end;

(* WHAT WAS DELIBERATELY NOT TAKEN OVER, AND WHY.

   THE EXCHANGE PARSE STAYS IN LOGSTUFF.
   ProcessRSTAndQSONumberOrDomesticQTHExchange asks
   `if ActiveQSOPointMethod = ArktikaSpringQSOPointMethod` and then routes to an
   RST-and-serial parse or an RST-and-domestic-QTH parse depending on whether
   the typed exchange is all digits. That is a contest rule sitting in shared
   code and it belongs here eventually -- but TContestBase has no parsing seam
   at all today (docs/ADDING_A_CONTEST.md section 6 names parseReceivedExchange
   as not built), and NO AUTOMATED GATE IN THIS TREE TYPES AN EXCHANGE, so
   inventing the seam and the arm in one move would be unverifiable. It moves
   when the parsing seam is designed.

   THE EXCHANGE COLUMNS ARE THE BASE'S DEFAULT (M4): TContestBase formats
   them through the shared RSTAndQSONumberOrDomesticQTHExchange arm, which
   several other contests run as well. Only the LINE is this contest's. *)

initialization
   RegisterContest(ARKTIKA_SPRING, TContestArktikaSpring);

end.
