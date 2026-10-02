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

(* THE OK/OM DX CONTEST, SSB.

  The ContestsArray row this class states, verbatim:

   Email: '';  DF: 'okom';  WA7BNM: 567;  QRZRUID: 12;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;
   DM: DomesticFile;  P: 0;  AE: RSTAndQSONumberOrDomesticQTHExchange;
   XM: CQDXCC;  QP: OKOMSSBQSOPointMethod;
   ADIFName: '';  CABName: '';
   FriendlyName: 'OK/OM DX Contest, SSB'

  Blank CABName and ADIFName resolve to the enum's spelling, 'OK-OM DX SSB'.

  WHY IT HAS A CLASS. Milestone M7b (2026-10-02) gives every classless
  contest one -- this is batch 2 -- and a registered class is the contest's
  scorer, set-up, export, import, parse and final score from the moment it
  exists, so the whole contest is transcribed here, exactly: the row above
  as literals (Test_MovedRowValuesStillMatchTheArray), and every legacy arm
  that named it, each arm deleted from the shared code it stood in. The
  contest matrix is the proof: every line of its record but `contest.class`
  is unchanged.

  SCORING: OKOMSSBQSOPointMethod -- an OK or OM station: the other of the
  two 3, its own 2, Europe 3, elsewhere 5; anyone else: OK or OM 10, our
  own country 1, another continent 5, our continent 3.

  SET-UP: OK and OM as domestic countries, phone.

  NOT A SIBLING OF THE OK/OM DX CLASS (uContestOKDX, M5a): the CW running
  scores by OKDXQSOPointMethod, a different arm. *)
unit uContestOKOMSSB;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestOKOMSSB = class(TContestBase)
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
      (* SET-UP -- see TContestBase.DescribeSession. *)
      procedure DescribeSession(const aStation: TStationContext;
                                aSession: TSessionDefaults); override;
   end;

implementation

uses
   uContestRegistry,
   uCallSignRoutines;

(* OKOMSSBQSOPointMethod -- LOGSTUFF.CalculateQSOPoints's arm for this
   contest's point method, moved here as it stood (M7b batch 2). *)
procedure TContestOKOMSSB.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if OKOMStation(Station.MyCountry) then
      begin
      if ((Station.MyCountry = 'OK') and (aQso.QTH.CountryID = 'OM')) or
         ((Station.MyCountry = 'OM') and (aQso.QTH.CountryID = 'OK')) then
         begin
         aQso.QSOPoints := 3;
         end
      else if (rxCty = 'OK') or (rxCty = 'OM') then
         begin
         aQso.QSOPoints := 2;
         end
      else if aQso.QTH.Continent = Europe then
         begin
         aQso.QSOPoints := 3;
         end
      else
         begin
         aQso.QSOPoints := 5;
         end;
      end
   else if (rxCty = 'OK') or (rxCty = 'OM') then
      begin
      aQso.QSOPoints := 10;
      end
   else if rxCty = Station.MyCountry then
      begin
      aQso.QSOPoints := 1;
      end
   else if aQso.QTH.Continent <> Station.MyContinent then
      begin
      aQso.QSOPoints := 5;
      end
   else
      begin
      aQso.QSOPoints := 3;
      end;
end;

function TContestOKOMSSB.GetDisplayName: string;
begin
   Result := 'OK-OM DX SSB';
end;

function TContestOKOMSSB.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'OK-OM DX SSB';
end;

function TContestOKOMSSB.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'OK-OM DX SSB';
end;

function TContestOKOMSSB.GetWA7BNMId: integer;
begin
   Result := 567;
end;

function TContestOKOMSSB.GetQRZRUId: integer;
begin
   Result := 12;
end;

function TContestOKOMSSB.GetSubmissionEmail: string;
begin
   Result := '';
end;

function TContestOKOMSSB.GetDomesticFileName: string;
begin
   Result := 'okom';
end;

function TContestOKOMSSB.GetFriendlyName: string;
begin
   Result := 'OK/OM DX Contest, SSB';
end;

function TContestOKOMSSB.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestOKOMSSB.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestOKOMSSB.GetDXMultiplierType: DXMultType;
begin
   Result := CQDXCC;
end;

function TContestOKOMSSB.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestOKOMSSB.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestOKOMSSB.GetExchangeKind: ExchangeType;
begin
   Result := RSTAndQSONumberOrDomesticQTHExchange;
end;

function TContestOKOMSSB.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := OKOMSSBQSOPointMethod;
end;

function TContestOKOMSSB.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

(* SET-UP -- FCONTEST.FoundContest's arm for this contest, moved here as
   it stood (M7b batch 2, 2026-10-02). See TContestBase.DescribeSession: this
   writes no global and reads only aStation. *)
procedure TContestOKOMSSB.DescribeSession(const aStation: TStationContext;
                                          aSession: TSessionDefaults);
begin
   aSession.AddDomesticCountry('OK');
   aSession.AddDomesticCountry('OM');
   aSession.Mode := Phone;
end;

initialization
   RegisterContest(OKOMSSB, TContestOKOMSSB);

end.
