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

(* THE ARRL 160-METER CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '160meter@arrl.org';  DF: 'arrlsect';  WA7BNM: 194;  QRZRUID: 22;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTDomesticOrDXQTHExchange;
   XM: NoDXMults;  QP: ARRL160QSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'ARRL 160-Meter Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'ARRL-160'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one, and a registered class is the contest's scorer, set-up,
  export, import, parse and final score from the moment it exists -- so the
  whole contest is transcribed here, exactly: the row above as literals
  (Test_MovedRowValuesStillMatchTheArray), and every legacy arm that named it.
  The contest matrix is the proof: every line of its record but
  `contest.class` is unchanged.

  WHY IT WAITED UNTIL M7b. Its scoring asks whether a call is in the
  session's DOMESTIC COUNTRIES -- a CTY.DAT lookup against the list set-up
  built (ZoneCont.DomesticCountryCall) -- and a class may not reach TRDOS.
  DECIDED at M7b: the station context carries that lookup as a SERVICE,
  TStationContext.IsDomesticCountryCall, filled by
  uContestFactory.CurrentStation -- the shape M5b's parse session hands its
  engine services in. The class still reads no global, and a test hands it
  a stub. With no service (nil) a call is not domestic, which is what the
  engine answers for an empty list.

  SCORING: ARRL160QSOPointMethod -- a domestic station 2; else, if WE are
  domestic, 5; else 0.

  SET-UP: an ARRL-section country (W/VE and the US possessions) sends RST
  and its section or DX and counts DXCC without the sections; everyone else
  sends RST and a section. The twenty ARRL-section countries are domestic.
  LogCfg's CQ exchange: 5NN and MY STATE.

  EXPORT: a W/VE QSO's QTH is its ARRL_SECT -- PostUnit's tail named this
  contest until M7b. IMPORT: SRX_STRING is the domestic QTH -- the arm
  MainUnit.ApplyClasslessADIFImport kept for it until M7b; the arm it came
  from named CQ 160 and the UBA contests too, and each owns its copy. *)
unit uContestARRL160;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestARRL160 = class(TContestBase)
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
   private
      (* The station context's domestic-country service, or "not domestic"
         when there is none -- see the header. *)
      function IsDomesticCall(const aCall: string): boolean;
   public
      (* EXPORT -- see TContestBase.EmitADIFContestFields. *)
      function EmitADIFContestFields(const aQso: ContestExchange): string; override;
      (* IMPORT -- see TContestBase.ApplyADIFImport. *)
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   uContestRegistry,
   (* ARRLSectionCountry -- the leaf the set-up arm asked. *)
   uCallSignRoutines,
   (* EmitADIFField -- the tag spellings are ADIF's. *)
   uADIF,
   uTR4WStrings;

procedure TContestARRL160.CalculateQSOPoints(var aQso: ContestExchange);
begin
   if IsDomesticCall(string(aQso.Callsign)) then
      begin
      aQso.QSOPoints := 2;
      end
   else if IsDomesticCall(Station.MyCall) then
      begin
      aQso.QSOPoints := 5;
      end
   else
      begin
      aQso.QSOPoints := 0;
      end;
end;

function TContestARRL160.IsDomesticCall(const aCall: string): boolean;
begin
   if Assigned(Station.IsDomesticCountryCall) then
      begin
      Result := Station.IsDomesticCountryCall(aCall);
      end
   else
      begin
      Result := False;
      end;
end;

function TContestARRL160.GetDisplayName: string;
begin
   Result := 'ARRL 160-Meter Contest';
end;

function TContestARRL160.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'ARRL-160';
end;

function TContestARRL160.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'ARRL-160';
end;

function TContestARRL160.GetWA7BNMId: integer;
begin
   Result := 194;
end;

function TContestARRL160.GetQRZRUId: integer;
begin
   Result := 22;
end;

function TContestARRL160.GetSubmissionEmail: string;
begin
   Result := '160meter@arrl.org';
end;

function TContestARRL160.GetDomesticFileName: string;
begin
   Result := 'arrlsect';
end;

function TContestARRL160.GetFriendlyName: string;
begin
   Result := 'ARRL 160-Meter Contest';
end;

function TContestARRL160.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestARRL160.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestARRL160.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestARRL160.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestARRL160.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestARRL160.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestARRL160.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := ARRL160QSOPointMethod;
end;

function TContestARRL160.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* PostUnit's ARRL160 arm, moved at M7b: a W/VE station's QTH is its ARRL
   section. Asked only for a QSO whose QTH is not empty and not a grid. *)
function TContestARRL160.EmitADIFContestFields(const aQso: ContestExchange): string;
begin
   Result := '';
   if (aQso.QTH.CountryID = 'K') or
      (aQso.QTH.CountryID = 'VE') then
      begin
      Result := EmitADIFField('ARRL_SECT', string(aQso.QTHString));
      end;
end;

(* MainUnit.ApplyClasslessADIFImport's ARRL160 arm, moved at M7b:
   SRX_STRING is the domestic QTH. *)
procedure TContestARRL160.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                          const aSession: TADIFImportSession;
                                          var aExch: ContestExchange);
begin
   aExch.DomesticQTH := ShortString(aTemps.SRX_String);
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestARRL160.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   if ARRLSectionCountry(string(aStation.MyCountry)) then
      begin
      aSession.Exchange := RSTDomesticOrDXQTHExchange;
      aSession.DXMult := ARRLDXCCWithNoARRLSections;
      end
   else
      begin
      aSession.Exchange := RSTDomesticQTHExchange;
      end;
   aSession.AddDomesticCountries(DomesticCountriesARRLSections);
end;

(* LogCfg.tSetupExchangeNumbers' arm for this contest, moved at M7b -- see
   TContestBase.CQExchangeDefault. *)
function TContestARRL160.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN ' + aStation.MyState;
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRL10, ARRL_RTTY_ROUNDUP,
   CQ160CW, CQ160SSB, CQWWRTTY.
   The same steps on ticking the box stood for ARRL10, ARRLDXCW,
   ARRL_RTTY_ROUNDUP.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRL160.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.OfferIAmIn(TC_NORTHAMERICA);
   aPrompts.AskFieldWithCommentWhenInside(TC_ENTERTHEQTHTHATYOUWANTTOSEND, ncfMyState);
end;

initialization
   RegisterContest(ARRL160, TContestARRL160);

end.
