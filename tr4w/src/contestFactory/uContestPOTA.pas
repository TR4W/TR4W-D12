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

(* PARKS ON THE AIR -- an activation, logged as a contest.

  NY4I, 2026-10-13 (design Q6): "yes, make POTA a contest class. while it is
  not a contest per se, just like with GENERAL QSO, we treat it that way."
  General QSO is the precedent: registered without being a contest, on
  TContestBase, writing no ADIF CONTEST_ID. No TActivityBase until a second
  activity (SOTA, WWFF) shows what is genuinely shared (design section 6).

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: '';  WA7BNM: 0000;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: NoDomesticMults;  P: 0;  AE: RSTAndPOTAPark;
   XM: NoDXMults;  QP: OnePointPerQSO;  ADIFName: '';  CABName: '';
   FriendlyName: 'Parks on the Air(r) Logging'

  Blank ADIFName and CABName are the enum's spelling, 'POTA'.

  WHAT MOVED HERE, EACH SITE DELETED WHERE IT STOOD (2026-10-13):

    FCONTEST.FoundContest's arm       DescribeSession
    MainUnit.ApplyClasslessADIFImport ApplyADIFImport (the routine is gone:
                                      POTA was its last contest)
    PostUnit's ADIF tail, x3          EmitADIFExchangeFields,
                                      FormatADIFReceivedExchange and
                                      EmitADIFContestFields
    uADIF's `ceContest <> POTA`       WritesADIFContestId
    uNewContest.ClasslessPrompts, x2  DescribeNewContestPrompts
    MainUnit's menu test              OffersParkTools
    LOGSTUFF's OnePointPerQSO arm     CalculateQSOPoints (the arm was
                                      deleted at M10 S3)

  The three TRDOS helpers those sites called are leaves now --
  uPOTAReference (IsValidPOTAPark, ResolvePOTAParkFromADIF, LooksLikeAState)
  and uGridShape (Tree.LooksLikeAGrid's two halves).

  WHAT DID NOT MOVE, AND WHY. The EXCHANGE SHAPE RSTAndPOTAPark is the
  engine's until M10 retires the shared shapes (Q4): LOGSTUFF's parser for
  it (ProcessRSTAndPOTAPark) reads the downloaded park list, MY PARK and the
  operator name set, and queues an n-fer's extra parks, and the base's
  ParseReceivedExchange already hands the session's shape to it -- so a POTA
  exchange parses exactly as it did. The n-fer itself -- one contact logged
  against several parks, one row per park in one QSO set, like a county
  line -- is the engine's queue and TryLogContact's drain, and is untouched.
  The park list, its download and the park-name display are POTA DATA, not
  rules (uPOTAParks, MainUnit). *)
unit uContestPOTA;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestPOTA = class(TContestBase)
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
      function GetADIFSentExchange(const aMy: TMyStationExchange;
                                   const aQso: ContestExchange): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      function GetWritesADIFContestId: boolean; override;
      function GetOffersParkTools: boolean; override;
      (* THE CONTEST'S OWN RULE. Protected, as on TContestBase: ScoreQSO is
         the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* ADIF EXPORT -- PostUnit's tail. *)
      function FormatADIFReceivedExchange(const aQso: ContestExchange;
                                          aExchangeCarriesRST: boolean): string; override;
      function EmitADIFExchangeFields(const aMy: TMyStationExchange;
                                      const aQso: ContestExchange;
                                      aExchangeCarriesRST: boolean): string; override;
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      (* ADIF IMPORT. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
      (* A BLANK EXCHANGE -- see TContestBase.AcceptsBlankExchange (M11 S7). *)
      function AcceptsBlankExchange: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uADIFExchange,
   SysUtils, uContestRegistry, uContestFixedPoints,
   (* EmitADIFField -- the tags this contest writes. *)
   uADIF,
   (* IsValidPOTAPark, ResolvePOTAParkFromADIF, LooksLikeAState. *)
   uPOTAReference,
   (* LooksLikeGridSquare. *)
   uGridShape,
   (* TC_ENTERYOURPARKREFERENCEDESIGNATOR. *)
   uTR4WStrings;

(* ONE POINT A CONTACT, whatever the mode -- the legacy LOGSTUFF
   OnePointPerQSO arm (deleted at M10 S3), `RXData.QSOPoints := 1`, through
   the FixedModePoints helper. *)
procedure TContestPOTA.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := FixedModePoints(aQso.Mode, 1, 1, 1);
end;

function TContestPOTA.GetDisplayName: string;
begin
   (* The human name, the row's FriendlyName (M9a). *)
   Result := 'Parks on the Air(r) Logging';
end;

function TContestPOTA.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'POTA';
end;

function TContestPOTA.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank, so the enum's spelling. Export writes NO
      CONTEST_ID for an activation (WritesADIFContestId); the score-posting
      clients still send this. *)
   Result := 'POTA';
end;

function TContestPOTA.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestPOTA.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestPOTA.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestPOTA.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestPOTA.GetFriendlyName: string;
begin
   Result := 'Parks on the Air(r) Logging';
end;

function TContestPOTA.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestPOTA.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndPOTAPark;
end;

function TContestPOTA.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsRSTQTH;
end;

function TContestPOTA.GetADIFSentExchange(const aMy: TMyStationExchange;
                                          const aQso: ContestExchange): string;
begin
   Result := ADIFSentPark(aMy, aQso);
end;

function TContestPOTA.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfQSOByMode];
end;

function TContestPOTA.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* AN ACTIVATION, NOT A CONTEST: no CONTEST_ID in ADIF. uADIF.EmitADIFRecord
   tested `rec.ceContest <> POTA` until this class existed. *)
function TContestPOTA.GetWritesADIFContestId: boolean;
begin
   Result := False;
end;

(* MainUnit hid Download POTA Parks and Repeat POTA Parks (2nd Op) when
   `Contest <> POTA`. *)
function TContestPOTA.GetOffersParkTools: boolean;
begin
   Result := True;
end;

(* THE SRX_STRING IS THE PARK WORKED, ELSE THE EXCHANGE AS TYPED -- never the
   RST in front of it, whatever the exchange's RST flag says. PostUnit's POTA
   branch, moved. *)
function TContestPOTA.FormatADIFReceivedExchange(const aQso: ContestExchange;
                                                 aExchangeCarriesRST: boolean): string;
begin
   if IsValidPOTAPark(string(aQso.QTHString)) then
      begin
      Result := string(aQso.QTHString);
      end
   else
      begin
      Result := string(aQso.ExchString);
      end;
end;

(* THE ACTIVATION, THE SRX_STRING, AND WHERE A HUNTER NOT IN A PARK IS --
   PostUnit's tail, in the order it wrote them:

     MY_SIG, MY_SIG_INFO, MY_POTA_REF   our park, MY PARK
     SRX_STRING                         FormatADIFReceivedExchange above
     DXCC 291 and STATE                 a hunter who sent a state -- DXCC is
                                        hard-coded to the US, as it was
     GRIDSQUARE                         a hunter who sent a grid

   The state or grid is looked for only when the QSO's QTH is not a park.

   A GRID IS ALWAYS LOOKED FOR (M11 S9b). This used to ask whether the
   SESSION'S exchange could carry one (GRID_CARRYING_EXCHANGES, handed in as
   data). POTA's session exchange is its own, RSTAndPOTAPark, which is in
   that set, and nothing else can set it: the answer was always yes. *)
function TContestPOTA.EmitADIFExchangeFields(const aMy: TMyStationExchange;
                                             const aQso: ContestExchange;
                                             aExchangeCarriesRST: boolean): string;
begin
   Result := EmitADIFField('MY_SIG', 'POTA');
   Result := Result + EmitADIFField('MY_SIG_INFO', aMy.MyPark);
   Result := Result + EmitADIFField('MY_POTA_REF', aMy.MyPark);
   Result := Result + EmitADIFField('SRX_STRING',
      FormatADIFReceivedExchange(aQso, aExchangeCarriesRST));

   if IsValidPOTAPark(string(aQso.QTHString)) then
      begin
      Exit;
      end;

   if LooksLikeAState(string(aQso.ExchString)) then
      begin
      Result := Result + EmitADIFField('DXCC', '291');
      Result := Result + EmitADIFField('STATE', string(aQso.ExchString));
      end
   else
      begin
      if LooksLikeGridSquare(string(aQso.ExchString)) then
         begin
         Result := Result + EmitADIFField('GRIDSQUARE', string(aQso.ExchString));
         end;
      end;
end;

(* THE PARK WORKED, IN ALL THREE TAGS ADIF HAS FOR IT -- SIG, SIG_INFO and
   POTA_REF. PostUnit's location `case` named POTA for this; a QTH that is not
   a park writes nothing here, as the arm did. *)
function TContestPOTA.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := '';
   if IsValidPOTAPark(string(aQso.QTHString)) then
      begin
      Result := EmitADIFField('SIG', 'POTA');
      Result := Result + EmitADIFField('SIG_INFO', string(aQso.QTHString));
      Result := Result + EmitADIFField('POTA_REF', string(aQso.QTHString));
      end;
end;

(* THE PARK A RECORD NAMES, ELSE THE STATE IT NAMES -- MainUnit's
   ApplyClasslessADIFImport arm, moved whole. It replaced the base's default
   there rather than adding to it, so this does not call inherited: a record
   naming neither keeps what the generic import gave it. *)
procedure TContestPOTA.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                       const aSession: TADIFImportSession;
                                       var aExch: ContestExchange);
var
   parkRef: string;
begin
   parkRef := ResolvePOTAParkFromADIF(aTemps.POTARef, aTemps.SIG, aTemps.SIG_Info);
   if parkRef <> '' then
      begin
      aExch.QTHString := ShortString(parkRef);
      end
   else
      begin
      if LooksLikeAState(aTemps.State) then
         begin
         aExch.QTHString   := ShortString(aTemps.State);
         aExch.DomesticQTH := ShortString(aTemps.State);
         end;
      end;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as it
   stood (2026-10-13). See TContestBase.DescribeSession: this writes no global
   and reads nothing of aStation. Dupes are allowed -- a hunter works the
   same activator again from another park -- and auto-dupe is off both
   ways. The arm's last line built the operator name set from TRMASTER.DTA;
   that is an engine action, so it is asked for (UseOperatorNameSet) and the
   applier runs it last, where the arm did. *)
procedure TContestPOTA.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AllowDupeQSOs := True;
   aSession.AutoDupeEnableCQ := False;
   aSession.AutoDupeEnableSAndP := False;
   aSession.ContestName := 'POTA';
   aSession.WARCEnabled := True;
   aSession.SetCQMemory(CW, smkF1, 'CQ^POTA \ \ ');
   aSession.SetCQMemory(CW, smkF2, 'CQ^POTA CQ^POTA \ \ FD');
   aSession.QSLCW := '73 \ EE';
   aSession.UseOperatorNameSet;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest.ClasslessPrompts' two POTA
   arms, moved as they stood (2026-10-13): the "I am in" box captioned
   'Activator' on choosing, and MY PARK with its comment when it is ticked.
   'Activator' was a literal in the dialog, not a TC_ string; it is kept as
   one. *)
procedure TContestPOTA.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmInCaption('Activator');
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERYOURPARKREFERENCEDESIGNATOR, ncfMyPark);
end;

(* THE RECEIVED EXCHANGE MAY BE BLANK, at every station -- M11 S7,
   2026-10-14. It was the session's RSTAndPOTAPark shape; see
   TContestBase.AcceptsBlankExchange. *)
function TContestPOTA.AcceptsBlankExchange: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(POTA, TContestPOTA);

end.
