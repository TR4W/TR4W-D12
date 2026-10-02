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

(* THE RAC WINTER CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'p13';  WA7BNM: 205;  QRZRUID: 101;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTAndQSONumberOrDomesticQTHExchange;  XM: NoDXMults;  QP: RACQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'RAC Winter Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'CANADA WINTER'.

  WHY IT HAS A CLASS NOW. M5b (2026-10-02) moved exchange parsing onto the
  contest, and this contest's parse rule was a test of ActiveQSOPointMethod
  inside a shared shape parser -- which an operator's QSO POINT METHOD line
  reached in any contest. A class to hold that rule needed the whole row and
  the scoring arm with it, because registering a class makes the class this
  contest's scorer too. Both are transcribed exactly;
  Test_MovedRowValuesStillMatchTheArray holds the row, and the contest matrix
  the scoring, export, import and parse -- every line of its record but
  `contest.class` is unchanged, which is the proof.

  A COPY OF THE RAC CANADA DAY CONTEST'S CLASS, AND DELIBERATELY SO (design 1.4).
  The two are RAC's two contests, on different dates and under rules RAC
  revises separately; today they score and parse alike. Do not merge them.

  SCORING, transcribed from RACQSOPointMethod: a Canadian station scores 10,
  20 if its call contains RAC (an RAC official station); anybody else 2.
  ITS PARSE: a VE0 station (maritime mobile) sends a serial, whatever its
  country makes it look like; everybody else is the shape's own rule. *)
unit uContestCanadaWinter;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestCanadaWinter = class(TContestBase)
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
      (* A VE0 STATION SENDS A SERIAL -- see the header. It stood in
         LOGSTUFF.ProcessRSTAndQSONumberOrDomesticQTHExchange as a test of
         ActiveQSOPointMethod = RACQSOPointMethod; stated here under that
         shape. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
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
   uContestRegistry,
   uTR4WStrings;

procedure TContestCanadaWinter.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if aQso.QTH.CountryID = 'VE' then
      begin
      if Pos('RAC', aQso.Callsign) > 0 then
         begin
         aQso.QSOPoints := 20;
         end
      else
         begin
         aQso.QSOPoints := 10;
         end;
      end
   else
      begin
      aQso.QSOPoints := 2;
      end;
end;

function TContestCanadaWinter.ParseReceivedExchange(const aText: string;
                                                const aSession: TReceivedExchangeSession;
                                                var aExch: ContestExchange;
                                                out aErrorMessage: string): boolean;
begin
   if (aSession.Exchange = RSTAndQSONumberOrDomesticQTHExchange) and
      (Copy(aExch.Callsign, 1, 3) = 'VE0')                       then
      begin
      aErrorMessage := '';
      Result := aSession.ParseShape(RSTQSONumberExchange, aText, aExch);
      Exit;
      end;

   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
end;

function TContestCanadaWinter.GetDisplayName: string;
begin
   Result := 'RAC Winter Contest';
end;

function TContestCanadaWinter.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'CANADA WINTER';
end;

function TContestCanadaWinter.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'CANADA WINTER';
end;

function TContestCanadaWinter.GetWA7BNMId: integer;
begin
   Result := 205;
end;

function TContestCanadaWinter.GetQRZRUId: integer;
begin
   Result := 101;
end;

function TContestCanadaWinter.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestCanadaWinter.GetDomesticFileName: string;
begin
   Result := 'p13';
end;

function TContestCanadaWinter.GetFriendlyName: string;
begin
   Result := 'RAC Winter Contest';
end;

function TContestCanadaWinter.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestCanadaWinter.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestCanadaWinter.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestCanadaWinter.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestCanadaWinter.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestCanadaWinter.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestCanadaWinter.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := RACQSOPointMethod;
end;

function TContestCanadaWinter.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named CANADA_DAY, CANADA_WINTER; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestCanadaWinter.DescribeSession(const aStation: TStationContext;
                                               aSession: TSessionDefaults);
begin
   if aStation.MyCountry <> 'VE' then
      begin
      aSession.SentState := '';
      end;
   aSession.AddDomesticCountry('VE');
   aSession.AddDomesticCountry('CY0');
   aSession.AddDomesticCountry('CY9');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for CANADA_DAY.
   The same steps on ticking the box stood for ARI_DX, CANADA_DAY,
   HELVETIA, KINGOFSPAINCW, KINGOFSPAINSSB, PACC, UBACW, UBASSB.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestCanadaWinter.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_CANADA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURPROVINCEID, ncfMyState);
end;

initialization
   RegisterContest(CANADA_WINTER, TContestCanadaWinter);

end.
