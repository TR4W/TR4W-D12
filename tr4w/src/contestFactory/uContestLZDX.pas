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

(* THE LZ DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'lz';  WA7BNM: 187;  QRZRUID: 53;
   Pxm: NoPrefixMults;  ZnM: ITUZones;  AIE: ZoneInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTZoneOrDomesticQTH;  XM: NoDXMults;  QP: LZDXQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'LZ DX Contest'

  Blank CABName and ADIFName resolve to the enum's spelling, 'LZ DX'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7a) have moved since.

  SCORING, transcribed from LZDXQSOPointMethod: Bulgaria (LZ) scores 1 for
  another LZ if the station is LZ itself and 10 otherwise; any other country
  scores 3 on another continent and 1 on the station's own.
  ITS IMPORT: an alphabetic SRX_STRING is a domestic QTH and anything else is
  stored as the QTH string. (The arm it came from named three contests,
  Ukrainian DX, OK/OM DX and LZ DX; each owns its own copy -- design 1.4.) *)
unit uContestLZDX;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestLZDX = class(TContestBase)
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
   SysUtils, uContestRegistry, uADIF;

procedure TContestLZDX.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if rxCty = 'LZ' then
      begin
      if Station.MyCountry = 'LZ' then
         begin
         aQso.QSOPoints := 1;
         end
      else
         begin
         aQso.QSOPoints := 10;
         end;
      end
   else
      begin
      if Station.MyContinent <> aQso.QTH.Continent then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 1;
         end;
      end;
end;

procedure TContestLZDX.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                       const aSession: TADIFImportSession;
                                       var aExch: ContestExchange);
begin
   if ADIFTextIsAlphabetic(aTemps.SRX_String) then
      begin
      aExch.DomesticQTH := ShortString(aTemps.SRX_String);
      end
   else
      begin
      aExch.QTHString := ShortString(aTemps.SRX_String);
      end;
end;

function TContestLZDX.GetDisplayName: string;
begin
   Result := 'LZ DX Contest';
end;

function TContestLZDX.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'LZ DX';
end;

function TContestLZDX.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'LZ DX';
end;

function TContestLZDX.GetWA7BNMId: integer;
begin
   Result := 187;
end;

function TContestLZDX.GetQRZRUId: integer;
begin
   Result := 53;
end;

function TContestLZDX.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestLZDX.GetDomesticFileName: string;
begin
   Result := 'lz';
end;

function TContestLZDX.GetFriendlyName: string;
begin
   Result := 'LZ DX Contest';
end;

function TContestLZDX.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestLZDX.GetZoneMultiplierType: ZoneMultType;
begin
   Result := ITUZones;
end;

function TContestLZDX.GetDXMultiplierType: DXMultType;
begin
   Result := NoDXMults;
end;

function TContestLZDX.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestLZDX.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := ZoneInitialExchange;
end;

function TContestLZDX.GetExchangeKind: ExchangeType;
begin
   Result := RSTZoneOrDomesticQTH;
end;

function TContestLZDX.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := LZDXQSOPointMethod;
end;

function TContestLZDX.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7a, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestLZDX.DescribeSession(const aStation: TStationContext;
                                       aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('LZ');
   aSession.Band := Band80;
end;

(* THE CQ EXCHANGE THIS CONTEST OFFERS WHEN THE OPERATOR HAS NONE --
   LogCfg.tSetupExchangeNumbers' arm for it, moved here at M7a. See
   TContestBase.CQExchangeDefault. *)
function TContestLZDX.CQExchangeDefault(const aStation: TStationContext): string;
begin
   if aStation.MyState <> '' then
      begin
      Result := ' 5NN ' + aStation.MyState;
      end
   else
      begin
      Result := ' 5NN ' + aStation.MyZoneText;
      end;
end;

initialization
   RegisterContest(LZDX, TContestLZDX);

end.
