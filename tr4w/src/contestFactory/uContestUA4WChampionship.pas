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

(* THE UA4W CHAMPIONSHIP (R4W-CHAMP).

  The ContestsArray row this class states, verbatim:

   Email: 'r4w@narod.ru';  DF: '';  WA7BNM: 0000;  QRZRUID: 132;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: WYSIWYGDomestic;  P: 0;  AE: RSTAndGridSquareOrRDAExchange;
   XM: NoDXMults;  QP: UA4WMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: ''

  Blank CABName, ADIFName and FriendlyName resolve to the enum's spelling,
  'R4W-CHAMP'.

  WHY IT HAS A CLASS NOW. It was held classless on purpose from M5b to
  2026-10-14 (design Q28): its scoring asked CTY.DAT for MY CALL's CQ zone,
  and no class could be handed that. NY4I ruled (design 7.12) that MY CQ ZONE
  is a station fact a contest may override, and the station context carries
  it as the MyCQZone service. A registered class is the contest's scorer,
  set-up, parse, prompts and CQ exchange from the moment it exists, so the
  whole contest is transcribed here: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named
  it, each deleted from the shared code it stood in -- FCONTEST.FoundContest
  (the minitours), LogCfg.tSetupExchangeNumbers (the CQ exchange),
  LOGSTUFF.ProcessRSTAndGridSquareOrRDAExchange (the domestic QTH) and
  uNewContest.ClasslessPrompts (the prompt).

  SCORING: UA4WMethod -- 2 points. A station in oblast 4W (Udmurtia): 4 for
  a station whose QTH is not ours. Anyone else, for a station whose QTH is
  not ours: 3 on 80 m and 5 on 160 m, and for a 4W station 5 and 10 -- 10
  and 20 when OUR CQ zone is 18 or 19.

  OUR CQ ZONE IS THE STATED ONE, ELSE MY CALL'S -- TStationContext.MyCQZone.
  The legacy arm asked ctyGetCQZone(MY CALL) and ignored a stated zone; NY4I's
  7.12 makes a stated zone win (his laptop in CQ zone 3). It is NOT
  TStationContext.MyZone: this contest is an ITU-zone contest, so an
  unstated MY ZONE here is the ITU zone, and zones 18 and 19 in the rule are
  CQ zones (Siberia). See uContestBase.TMyCQZoneQuery for the measurement.

  OUR QTH IS Station.MyState -- the state this session sends, which is the
  resolved MY STATE because this contest states no SentState. The legacy arm
  read the resolved MY STATE; the two are the same value here. *)
unit uContestUA4WChampionship;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUA4WChampionship = class(TContestBase)
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
      function GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                       const aQso: ContestExchange;
                                       const aCtx: TCabrilloQSOContext): string; override;
      function GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                           const aQso: ContestExchange;
                                           const aCtx: TCabrilloQSOContext): string; override;

      (* Its yes/no facts -- see TContestBase.GetFlags (M10 S5). *)
      function GetFlags: TContestFlags; override;
      function GetIsUSQSOParty: boolean; override;
      (* THE CONTEST'S OWN RULE -- see the header. Protected, as on
         TContestBase: ScoreQSO is the one public scoring entry. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); override;
   public
      (* THE RECEIVED EXCHANGE -- the base's parse, then this contest's rule:
         the RDA or grid it received IS the domestic QTH. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
      (* THE NEW CONTEST DIALOG'S PROMPTS -- see
         TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   public
      (* THE DOMESTIC QTH -- see TContestBase.DomesticMultiplierFromQTH
         (M11 S6). *)
      function DomesticMultiplierFromQTH(const aText: Str20;
                                         var aMultiplier: Str10;
                                         var aQTH: Str10;
                                         var aFound: boolean): TDomesticQTHAnswer; override;
      (* see TContestBase.DomesticQTHReplacesDXMultiplier (M11 S6). *)
      function DomesticQTHReplacesDXMultiplier: boolean; override;
   end;

implementation

uses
   uExchangeFields,
   uCabrilloExchange,
   uADIFExchange,
   uContestRegistry,
   uCallSignRoutines;

const
   (* Udmurtia, the sponsor's oblast, as GetOblast spells it. *)
   UA4W_OBLAST = '4W';

(* UA4WMethod -- the legacy LOGSTUFF arm for this contest's point method
   (deleted at M10 S3), moved here as it stood but for the zone's source (see
   the header). *)
procedure TContestUA4WChampionship.CalculateQSOPoints(var aQso: ContestExchange);
var
   myCQZone: integer;
begin
   aQso.QSOPoints := 2;

   if GetOblast(Station.MyCall) = UA4W_OBLAST then
      begin
      if string(aQso.DomesticQTH) <> Station.MyState then
         begin
         aQso.QSOPoints := 4;
         end;
      Exit;
      end;

   if string(aQso.DomesticQTH) <> Station.MyState then
      begin
      if aQso.Band = Band80 then
         begin
         aQso.QSOPoints := 3;
         end;
      if aQso.Band = Band160 then
         begin
         aQso.QSOPoints := 5;
         end;

      if GetOblast(string(aQso.Callsign)) = UA4W_OBLAST then
         begin
         if aQso.Band = Band80 then
            begin
            aQso.QSOPoints := 5;
            end;
         if aQso.Band = Band160 then
            begin
            aQso.QSOPoints := 10;
            end;

         myCQZone := 0;
         if Assigned(Station.MyCQZone) then
            begin
            myCQZone := Station.MyCQZone();
            end;
         if (myCQZone = 18) or (myCQZone = 19) then
            begin
            if aQso.Band = Band80 then
               begin
               aQso.QSOPoints := 10;
               end;
            if aQso.Band = Band160 then
               begin
               aQso.QSOPoints := 20;
               end;
            end;
         end;
      end;
end;

(* LOGSTUFF.ProcessRSTAndGridSquareOrRDAExchange's test of this contest,
   moved here (2026-10-14) and applied under the shape it was written for:
   a parse that found a QTH makes it the domestic QTH. *)
function TContestUA4WChampionship.ParseReceivedExchange(const aText: string;
                                                        const aSession: TReceivedExchangeSession;
                                                        var aExch: ContestExchange;
                                                        out aErrorMessage: string): boolean;
begin
   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
   (* NO SHAPE TEST -- THIS CONTEST'S SESSION ALWAYS PARSES
      RSTAndGridSquareOrRDAExchange, its trait, and no DescribeSession
      states another, so the test that stood here was always true.
      Deleted at M11 S2 (plan F11). *)
   if Result then
      begin
      aExch.DomesticQTH := aExch.QTHString;
      end;
end;

function TContestUA4WChampionship.GetDisplayName: string;
begin
   (* The row has no friendly name; the enum's spelling is the name shown
      (design Q53). *)
   Result := 'R4W-CHAMP';
end;

function TContestUA4WChampionship.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'R4W-CHAMP';
end;

function TContestUA4WChampionship.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'R4W-CHAMP';
end;

function TContestUA4WChampionship.GetWA7BNMId: integer;
begin
   Result := 0;
end;

function TContestUA4WChampionship.GetQRZRUId: integer;
begin
   Result := 132;
end;

function TContestUA4WChampionship.GetSubmissionEmail: string;
begin
   Result := 'r4w@narod.ru';
end;

function TContestUA4WChampionship.GetDomesticFileName: string;
begin
   Result := '';
end;

function TContestUA4WChampionship.GetFriendlyName: string;
begin
   (* The row's FriendlyName is blank; this is the enum's spelling it
      resolves to. *)
   Result := 'R4W-CHAMP';
end;

function TContestUA4WChampionship.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUA4WChampionship.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndGridSquareOrRDAExchange;
end;

(* NO FIELD AT ALL -- M11 S9a, transcribed, NOT a rule. Its shape,
   RSTAndGridSquareOrRDA, had no arm in LOGDUPE.SetUpExchangeInformation, so
   start-up marked nothing for it: no RST or QTH for the log-string parses,
   no RST for the ADIF export's RST test. Stated, so the gap is visible
   here (docs/CONTEST_FACTORY_M11_PLAN.md F24). *)
function TContestUA4WChampionship.GetReceivedExchangeFields: ExchangeInformationRecord;
begin
   Result := ExchangeFieldsNone;
end;

function TContestUA4WChampionship.GetADIFSentExchange(const aMy: TMyStationExchange;
                                                      const aQso: ContestExchange): string;
begin
   Result := ADIFSentNotImplemented(aMy, aQso);
end;

function TContestUA4WChampionship.GetCabrilloSentExchange(const aMy: TMyStationExchange;
                                                          const aQso: ContestExchange;
                                                          const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloSentNotHandled(aMy, aQso, aCtx);
end;

function TContestUA4WChampionship.GetCabrilloReceivedExchange(const aMy: TMyStationExchange;
                                                              const aQso: ContestExchange;
                                                              const aCtx: TCabrilloQSOContext): string;
begin
   Result := CabrilloReceivedNotHandled(aMy, aQso, aCtx);
end;

function TContestUA4WChampionship.GetFlags: TContestFlags;
begin
   Result := [cfQSOByBand, cfErmakSpecification];
end;

function TContestUA4WChampionship.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as it
   stood (2026-10-14): 15-minute minitours. *)
procedure TContestUA4WChampionship.DescribeSession(const aStation: TStationContext;
                                                   aSession: TSessionDefaults);
begin
   aSession.MinitourDuration := 15;
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved here as it
   stood (2026-10-14): the serial and the state SENT (design 7.11). *)
function TContestUA4WChampionship.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' # ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest.ClasslessPrompts' arm
   for this contest, moved here as it stood (2026-10-14): on choosing it,
   the RDA or grid in MY QTH. Nothing on ticking a box; it offers none. The
   text is a literal, as it was -- it has no TC_ constant, so it is not
   translated (TC_ENTERYOURRDAIDORGRID says something else). *)
procedure TContestUA4WChampionship.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment('Enter your RDA (for Russian stations) or four digit grid square:',
                                ncfMyQTH);
end;


(* THE DOMESTIC QTH -- M11 S6 part 1, 2026-10-14, moved from LOGDOM.GetDomQTH's
   WYSIWYGDomestic arm (the trait): the text as received is both the multiplier and
   the QTH, cut to the field's ten characters, and it is always found. *)
function TContestUA4WChampionship.DomesticMultiplierFromQTH(const aText: Str20;
                                                            var aMultiplier: Str10;
                                                            var aQTH: Str10;
                                                            var aFound: boolean): TDomesticQTHAnswer;
begin
   aMultiplier := aText;
   aQTH := aText;
   aFound := True;
   Result := dqaDecided;
end;

(* A DOMESTIC QTH TAKES THE PLACE OF THE DX MULTIPLIER -- M11 S6 part 1,
   moved from LOGDUPE.GetDXQTH's `= WYSIWYGDomestic` guard (the trait). See
   TContestBase.DomesticQTHReplacesDXMultiplier. *)
function TContestUA4WChampionship.DomesticQTHReplacesDXMultiplier: boolean;
begin
   Result := True;
end;

initialization
   RegisterContest(UA4WCHAMPIONSHIP, TContestUA4WChampionship);

end.
