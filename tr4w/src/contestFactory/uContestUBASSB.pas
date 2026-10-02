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

(* THE UBA DX CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'uba';  WA7BNM: 235;  QRZRUID: 58;
   Pxm: BelgiumPrefixes;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTQSONumberAndPossibleDomesticQTHExchange;  XM: CQUBAEuropeanCountries;  QP: UBAQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'UBA DX Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'UBA-DX-SSB'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7a) have moved since.

  SCORING, transcribed from UBAQSOPointMethod (4.106.5). A Belgian station
  (ON) scores 1 for ON, 2 for another UBA European country and 3 for the rest
  of the world; everyone else scores 10 for ON, 3 for a UBA country and 1
  otherwise. A Belgian station working ON with the QTH 'XXX' earns no
  domestic multiplier. The two country lists are uCallSignRoutines.UBACountry.
  ITS IMPORT: SRX_STRING is the domestic QTH. (The arm it came from named five
  contests, CQ 160 CW and SSB, UBA CW and SSB and ARRL 160; each owns its own
  copy of the body -- design 1.4.) *)
unit uContestUBASSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUBASSB = class(TContestBase)
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
      procedure ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                const aSession: TADIFImportSession;
                                var aExch: ContestExchange); override;
   public
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
      (* LogCfg's default CQ exchange -- see TContestBase.CQExchangeDefault. *)
      function CQExchangeDefault(const aStation: TStationContext): string; override;
   end;

implementation

uses
   SysUtils, uContestRegistry, uCallSignRoutines;

procedure TContestUBASSB.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if Station.MyCountry = 'ON' then
      begin
      if rxCty = 'ON' then
         begin
         aQso.QSOPoints := 1;
         if aQso.QTHString = 'XXX' then
            begin
            aQso.DomesticMult := False;
            end;
         end
      else if UBACountry(aQso.DXQTH) then
         begin
         aQso.QSOPoints := 2;
         end
      else
         begin
         aQso.QSOPoints := 3;
         end;
      Exit;
      end;

   if rxCty = 'ON' then
      begin
      aQso.QSOPoints := 10;
      end
   else if UBACountry(rxCty) then
      begin
      aQso.QSOPoints := 3;
      end
   else
      begin
      aQso.QSOPoints := 1;
      end;
end;

procedure TContestUBASSB.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                         const aSession: TADIFImportSession;
                                         var aExch: ContestExchange);
begin
   aExch.DomesticQTH := ShortString(aTemps.SRX_String);
end;

function TContestUBASSB.GetDisplayName: string;
begin
   Result := 'UBA DX Contest, SSB';
end;

function TContestUBASSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'UBA-DX-SSB';
end;

function TContestUBASSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'UBA-DX-SSB';
end;

function TContestUBASSB.GetWA7BNMId: integer;
begin
   Result := 235;
end;

function TContestUBASSB.GetQRZRUId: integer;
begin
   Result := 58;
end;

function TContestUBASSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUBASSB.GetDomesticFileName: string;
begin
   Result := 'uba';
end;

function TContestUBASSB.GetFriendlyName: string;
begin
   Result := 'UBA DX Contest, SSB';
end;

function TContestUBASSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := BelgiumPrefixes;
end;

function TContestUBASSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestUBASSB.GetDXMultiplierType: DXMultType;
begin
   Result := CQUBAEuropeanCountries;
end;

function TContestUBASSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestUBASSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUBASSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestUBASSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := UBAQSOPointMethod;
end;

function TContestUBASSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation.
   The arm named UBACW, UBASSB; each of them holds its own
   copy (design 1.4), so a sponsor changing one changes one. *)
procedure TContestUBASSB.DescribeSession(const aStation: TStationContext;
                                         aSession: TSessionDefaults);
begin
   aSession.LiteralDomesticQTH := True;
   if aStation.MyCountry = 'ON' then
      begin
      aSession.DXMult := CQDXCC;
      aSession.DomesticMult := NoDomesticMults;
      aSession.Band := Band80;
      aSession.PrefixMult := NoPrefixMults;
      end
   else
      begin
      aSession.PrefixMult := BelgiumPrefixes;
      aSession.DomesticMult := DomesticFile;
      end;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestUBASSB.CQExchangeDefault(const aStation: TStationContext): string;
begin
   Result := ' 5NN # ' + aStation.MyState;
end;

initialization
   RegisterContest(UBASSB, TContestUBASSB);

end.
