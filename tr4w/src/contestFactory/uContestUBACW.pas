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

(* THE UBA DX CONTEST, CW.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'uba';  WA7BNM: 261;  QRZRUID: 59;
   Pxm: BelgiumPrefixes;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTQSONumberAndPossibleDomesticQTHExchange;  XM: CQUBAEuropeanCountries;  QP: UBAQSOPointMethod;
   ADIFName: '';  CABName: '';  FriendlyName: 'UBA DX Contest, CW'

  Blank CABName and ADIFName resolve to the enum's spelling, 'UBA-DX-CW'.

  WHY IT HAS A CLASS NOW. M5a (2026-10-01) moved ADIF import interpretation
  onto the contest, and this contest's rule was an arm of a `case ceContest`
  in the main unit -- which a base may never contain. A class to hold that
  rule needed the whole row and the scoring arm with it, because registering a
  class makes the class this contest's scorer too. Both are transcribed
  exactly; Test_MovedRowValuesStillMatchTheArray holds the row, and the
  contest matrix the scoring and the export -- every line of its record but
  `contest.class` is unchanged, which is the proof. EXCHANGE PARSING (M5b) and
  set-up (M7) are not moved.

  SCORING, transcribed from UBAQSOPointMethod (4.106.5). A Belgian station
  (ON) scores 1 for ON, 2 for another UBA European country and 3 for the rest
  of the world; everyone else scores 10 for ON, 3 for a UBA country and 1
  otherwise. A Belgian station working ON with the QTH 'XXX' earns no
  domestic multiplier. The two country lists are uCallSignRoutines.UBACountry.
  ITS IMPORT: SRX_STRING is the domestic QTH. (The arm it came from named five
  contests, CQ 160 CW and SSB, UBA CW and SSB and ARRL 160; each owns its own
  copy of the body -- design 1.4.) *)
unit uContestUBACW;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestUBACW = class(TContestBase)
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
   end;

implementation

uses
   SysUtils, uContestRegistry, uCallSignRoutines;

procedure TContestUBACW.CalculateQSOPoints(var aQso: ContestExchange);
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

procedure TContestUBACW.ApplyADIFImport(const aTemps: TADIFRecordTemps;
                                        const aSession: TADIFImportSession;
                                        var aExch: ContestExchange);
begin
   aExch.DomesticQTH := ShortString(aTemps.SRX_String);
end;

function TContestUBACW.GetDisplayName: string;
begin
   Result := 'UBA DX Contest, CW';
end;

function TContestUBACW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves to. *)
   Result := 'UBA-DX-CW';
end;

function TContestUBACW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'UBA-DX-CW';
end;

function TContestUBACW.GetWA7BNMId: integer;
begin
   Result := 261;
end;

function TContestUBACW.GetQRZRUId: integer;
begin
   Result := 59;
end;

function TContestUBACW.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestUBACW.GetDomesticFileName: string;
begin
   Result := 'uba';
end;

function TContestUBACW.GetFriendlyName: string;
begin
   Result := 'UBA DX Contest, CW';
end;

function TContestUBACW.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := BelgiumPrefixes;
end;

function TContestUBACW.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestUBACW.GetDXMultiplierType: DXMultType;
begin
   Result := CQUBAEuropeanCountries;
end;

function TContestUBACW.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestUBACW.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestUBACW.GetExchangeKind: ExchangeType;
begin
   Result := RSTQSONumberAndPossibleDomesticQTHExchange;
end;

function TContestUBACW.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := UBAQSOPointMethod;
end;

function TContestUBACW.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(UBACW, TContestUBACW);

end.
