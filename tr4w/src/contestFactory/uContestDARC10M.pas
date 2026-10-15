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

(* THE DARC 10-METER CONTEST.

  The ContestsArray row this class states, verbatim (its AE carries a
  commented-out RSTAndQSONumberOrDomesticQTHExchange beside it):

   Email: '';  DF: '';  WA7BNM: 223;  QRZRUID: 184;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTQSONumberAndPossibleDomesticQTHExchange;
   XM: CQDXCC;  QP: OnePointPerQSO;  ADIFName: '';
   CABName: '';  FriendlyName: 'DARC 10-Meter Contest'

  Blank ADIFName and CABName are the enum's spelling, 'DARC-10M'.

  WHY IT HAS A CLASS NOW. M4 (2026-10-01) made every contest format its own
  export, and this contest's rule was a `Contest = DARC10M` test inside a shared
  exporter -- which the base may never contain. A class to hold that rule
  needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record
  but `contest.class` is unchanged, which is the proof. EXCHANGE PARSING
  (M5b) and set-up (M7a) have moved since.

  SCORING IS OnePointPerQSO, stated through the FixedModePoints helper:

      OnePointPerQSO: RXData.QSOPoints := 1;

  ITS RECEIVED CABRILLO COLUMN IS ITS OWN: '%-3s %4.4d %3s' -- RST, serial,
  and a three-wide DOK -- where the shared
  RSTQSONumberAndPossibleDomesticQTHExchange arm writes a four-wide QTH. That
  was an `if Contest = DARC10M` inside the arm (n4af 4.43.7). The sent column
  is the arm's. *)
unit uContestDARC10M;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestDARC10M = class(TContestBase)
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
      function GetInitialExchangeKind: InitialExchangeType; override;
      function GetExchangeKind: ExchangeType; override;
      function GetReceivedExchangeFields: ExchangeInformationRecord; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      function FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                              const aQso: ContestExchange;
                                              const aCtx: TCabrilloQSOContext): string; override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* DOES IT HAVE A DX MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDXMultiplier (M11 S4 part 2). *)
      function HasDXMultiplier: boolean; override;
      (* THE DX MULTIPLIER -- see TContestBase.DXMultiplierKey (M11 S4). *)
      function DXMultiplierKey(const aQso: ContestExchange;
                               out aKey: DXMultiplierString): boolean; override;
   public
      (* THE DOMESTIC QTH -- see TContestBase.DomesticMultiplierFromQTH
         (M11 S6). *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; override;
      (* THE NEED-MULTIPLIER HINT -- see
         TContestBase.DomesticMultiplierHint (M11 S6). *)
      function DomesticMultiplierHint(const aText: Str14): string; override;
      (* see TContestBase.DomesticQTHReplacesDXMultiplier (M11 S6). *)
      function DomesticQTHReplacesDXMultiplier: boolean; override;
   public
      (* DOES IT HAVE A DOMESTIC MULTIPLIER AT THIS STATION? -- see
         TContestBase.HasDomesticMultiplier (M11 S6 part 2). *)
      function HasDomesticMultiplier: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   (* RDADistrictKey, DOKKey, GridSquareKey, GridFieldKey -- the shared
      domestic-QTH shapes (M11 S6). *)
   uDomesticKey,
   SysUtils, uContestRegistry, uContestFixedPoints,
   uTR4WStrings;

procedure TContestDARC10M.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestDARC10M.FormatCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                        const aQso: ContestExchange;
                                                        const aCtx: TCabrilloQSOContext): string;
begin
   Result := Format('%-3s %4.4d %3s', [aCtx.RSTReceived, aQso.NumberReceived, aCtx.HisQTH]);
end;

function TContestDARC10M.GetDisplayName: string;
begin
   Result := 'DARC 10-Meter Contest';
end;

function TContestDARC10M.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'DARC-10M';
end;

function TContestDARC10M.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'DARC-10M';
end;

function TContestDARC10M.GetWA7BNMId: integer;
begin
   Result := 223;
end;

function TContestDARC10M.GetQRZRUId: integer;
begin
   Result := 184;
end;

function TContestDARC10M.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestDARC10M.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestDARC10M.GetFriendlyName: string;
begin
   Result := 'DARC 10-Meter Contest';
end;

function TContestDARC10M.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestDARC10M.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestDARC10M.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQSONumberQTH;
end;

function TContestDARC10M.GetFlags: TContestFlags;
begin
   Result := [cfQSOByMode, cfMultByMode];
end;

function TContestDARC10M.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestDARC10M.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   aSession.Band := Band10;
   aSession.AddDomesticCountry('DL');
   aSession.QSOByMode := True;
   (* The DOKs an entrant outside Germany counts are the class's own rule
      (DomesticMultiplierFromQTH, HasDomesticMultiplier); the statement here
      went with the domestic kind, M11 S6 part 2. *)
   aSession.LiteralDomesticQTH := True;
   (* DL A SECOND TIME, AS THE ARM ADDED IT -- transcribed, not tidied. *)
   aSession.AddDomesticCountry('DL');
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for DARCXMAS, WAG.
   The same steps on ticking the box stood for DARCXMAS, WAG.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestDARC10M.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_GERMANY);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURDOK, ncfMyState);
end;

(* A DX MULTIPLIER AT EVERY STATION -- M11 S4 part 2, 2026-10-14: the trait
   this class stated (`CQDXCC`) and, for a German entrant, the kind its
   DescribeSession stated (`CQDXCC`) -- a DX multiplier either way -- until
   the kind was deleted. *)
function TContestDARC10M.HasDXMultiplier: boolean;
begin
   Result := True;
end;

(* THE DX MULTIPLIER KEY -- M11 S4, 2026-10-14, moved from LOGDUPE.GetDXQTH.
   Every country counts: the key is the CTY country -- GetDXQTH's `else`
   arm, for the session's CQDXCC. A DL entrant's DescribeSession restates CQDXCC, so the
   key does not depend on the station. *)
function TContestDARC10M.DXMultiplierKey(const aQso: ContestExchange;
                                         out aKey: DXMultiplierString): boolean;
begin
   aKey := aQso.QTH.CountryID;
   Result := True;
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH.
   An entrant outside Germany counts DOKs (the DOKCodes arm, which
   DescribeSession states for anyone but DL); the multiplier is the text's
   first letter, found only if it has one, and the QTH is the text either
   way. A German entrant takes the text as received (the WYSIWYGDomestic arm,
   the trait). *)
function TContestDARC10M.DomesticMultiplierFromQTH(const aText: Str20;
                                                   var aMultiplier: Str10;
                                                   var aQTH: Str10;
                                                   var aFound: boolean): TDomesticQTHAnswer;
var
   key: ShortString;
begin
   if Station.MyCountry <> 'DL' then
      begin
      aFound := DOKKey(aText, key);
      if aFound then
         begin
         aMultiplier := key;
         end;
      (* THE QTH IS THE TEXT EVEN WHEN NO DOK WAS FOUND -- the arm's order. *)
      aQTH := aText;
      Result := dqaDecided;
      end
   else
      begin
      aMultiplier := aText;
      aQTH := aText;
      aFound := True;
      Result := dqaDecided;
      end;
end;

(* THE NEED-MULTIPLIER HINT -- M11 S6 part 1, moved from LOGSTUFF.
   DomStringParse's DOKCodes arm, for an entrant outside Germany: the DOK's
   letter. A German entrant's session had no arm there: the text itself. *)
function TContestDARC10M.DomesticMultiplierHint(const aText: Str14): string;
var
   key: ShortString;
begin
   if Station.MyCountry <> 'DL' then
      begin
      if DOKKey(aText, key) then
         begin
         Result := string(key);
         end
      else
         begin
         (* NO LETTER, NO HINT -- an empty hint, F6 fixed 2026-10-14.
            DomStringParse returned its local TempMultiplier here without
            ever assigning it, so the hint was whatever the stack held; the
            S6 move transcribed that read on purpose and this commit ends it.
            The other DOK contest's class holds the same copy and changed
            with it. *)
         Result := '';
         end;
      end
   else
      begin
      Result := inherited DomesticMultiplierHint(aText);
      end;
end;

(* A DOMESTIC QTH TAKES THE PLACE OF THE DX MULTIPLIER -- M11 S6 part 1,
   moved from LOGDUPE.GetDXQTH's `= WYSIWYGDomestic` guard, for a German entrant -- the WYSIWYG session. See
   TContestBase.DomesticQTHReplacesDXMultiplier. *)
function TContestDARC10M.DomesticQTHReplacesDXMultiplier: boolean;
begin
   Result := Station.MyCountry = 'DL';
end;


(* A DOMESTIC MULTIPLIER AT EVERY STATION -- a DOK outside Germany, the QTH as
   received for a German entrant -- M11 S6 part 2, 2026-10-14. Its own
   answer, because a DOK has no shape flag for the base to compose (the
   German entrant's WYSIWYG one alone would answer only for DL). *)
function TContestDARC10M.HasDomesticMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(DARC10M, TContestDARC10M);

end.
