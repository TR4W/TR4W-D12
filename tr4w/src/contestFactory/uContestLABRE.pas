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

(* THE LABRE DX CONTEST.

  The ContestsArray row this class states, verbatim:

   Email: 'logs@labre.org.br';  DF: 'brazil';  WA7BNM: 761;  QRZRUID: 0;
   Pxm: NoPrefixMults;  ZnM: NoZoneMults;  AIE: NoInitialExchange;  DM: DomesticFile;  P: 0;
   AE: RSTDomesticOrDXQTHExchange;  XM: ARRLDXCC;  QP: LABREQSOPointMethod;
   ADIFName: '';  CABName: 'LABRE-DX';  FriendlyName: 'LABRE DX Contest'

  A blank ADIFName resolves to the enum's spelling, 'LABRE'; the CABName is
  stated, and is not.

  WHY IT HAS A CLASS NOW. M5b (2026-10-02) moved exchange parsing onto the
  contest, and this contest's parse rule was `if (Contest = LABRE)` in
  LOGSTUFF.ProcessExchange's case. A class to hold that rule needed the whole
  row and the scoring arm with it, because registering a class makes the
  class this contest's scorer too. Both are transcribed exactly;
  Test_MovedRowValuesStillMatchTheArray holds the row, and the contest matrix
  the rest -- every line of its record but `contest.class` is unchanged.

  SCORING, transcribed from LABREQSOPointMethod: another continent 6 on 160,
  80 and 40 m and 3 elsewhere; the same continent but another country 4 and
  2; the same country 2 and 1.
  ITS PARSE: a Brazilian station sends its state, so a PY station is parsed
  as a domestic QTH and never as DX; everybody else is the shape's own rule. *)
unit uContestLABRE;

{$I tr4w.inc}

interface

uses
   VC, uContestBase;

type
   TContestLABRE = class(TContestBase)
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
      (* A PY STATION SENDS A STATE -- see the header. Under the shape the
         rule stood in. *)
      function ParseReceivedExchange(const aText: string;
                                     const aSession: TReceivedExchangeSession;
                                     var aExch: ContestExchange;
                                     out aErrorMessage: string): boolean; override;
   end;

implementation

uses
   uContestRegistry;

procedure TContestLABRE.CalculateQSOPoints(var aQso: ContestExchange);
var
   rxCty: CallString;
begin
   rxCty := aQso.QTH.CountryID;

   if aQso.QTH.Continent <> Station.MyContinent then
      begin
      case aQso.Band of
         Band160:
            begin
            aQso.QSOPoints := 6;
            end;
         Band80:
            begin
            aQso.QSOPoints := 6;
            end;
         Band40:
            begin
            aQso.QSOPoints := 6;
            end;
         else
            begin
            aQso.QSOPoints := 3;
            end;
      end;
      end;

   if aQso.QTH.Continent = Station.MyContinent then
      begin
      if rxCty <> Station.MyCountry then
         begin
         case aQso.Band of
            Band160:
               begin
               aQso.QSOPoints := 4;
               end;
            Band80:
               begin
               aQso.QSOPoints := 4;
               end;
            Band40:
               begin
               aQso.QSOPoints := 4;
               end;
            else
               begin
               aQso.QSOPoints := 2;
               end;
         end;
         end;
      end;

   if rxCty = Station.MyCountry then
      begin
      case aQso.Band of
         Band160:
            begin
            aQso.QSOPoints := 2;
            end;
         Band80:
            begin
            aQso.QSOPoints := 2;
            end;
         Band40:
            begin
            aQso.QSOPoints := 2;
            end;
         else
            begin
            aQso.QSOPoints := 1;
            end;
      end;
      end;
end;

function TContestLABRE.ParseReceivedExchange(const aText: string;
                                            const aSession: TReceivedExchangeSession;
                                            var aExch: ContestExchange;
                                            out aErrorMessage: string): boolean;
begin
   if (aSession.Exchange = RSTDomesticOrDXQTHExchange) and
      (aExch.QTH.CountryID = 'PY')                    then
      begin
      aErrorMessage := '';
      Result := aSession.ParseShape(RSTDomesticQTHExchange, aText, aExch);
      Exit;
      end;

   Result := inherited ParseReceivedExchange(aText, aSession, aExch, aErrorMessage);
end;

function TContestLABRE.GetDisplayName: string;
begin
   Result := 'LABRE DX Contest';
end;

function TContestLABRE.GetCabrilloName: string;
begin
   Result := 'LABRE-DX';
end;

function TContestLABRE.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and import matches it (M1). *)
   Result := 'LABRE';
end;

function TContestLABRE.GetWA7BNMId: integer;
begin
   Result := 761;
end;

function TContestLABRE.GetQRZRUId: integer;
begin
   Result := 0;
end;

function TContestLABRE.GetSubmissionEmail: string;
begin
   Result := 'logs@labre.org.br';
end;

function TContestLABRE.GetDomesticFileName: string;
begin
   Result := 'brazil';
end;

function TContestLABRE.GetFriendlyName: string;
begin
   Result := 'LABRE DX Contest';
end;

function TContestLABRE.GetPrefixMultiplierType: PrefixMultType;
begin
   Result := NoPrefixMults;
end;

function TContestLABRE.GetZoneMultiplierType: ZoneMultType;
begin
   Result := NoZoneMults;
end;

function TContestLABRE.GetDXMultiplierType: DXMultType;
begin
   Result := ARRLDXCC;
end;

function TContestLABRE.GetDomesticMultiplierType: DomesticMultType;
begin
   Result := DomesticFile;
end;

function TContestLABRE.GetInitialExchangeKind: InitialExchangeType;
begin
   Result := NoInitialExchange;
end;

function TContestLABRE.GetExchangeKind: ExchangeType;
begin
   Result := RSTDomesticOrDXQTHExchange;
end;

function TContestLABRE.GetQSOPointMethod: QSOPointMethodType;
begin
   Result := LABREQSOPointMethod;
end;

function TContestLABRE.GetIsUSQSOParty: boolean;
begin
   (* P: 0 -- not a US state QSO party. *)
   Result := False;
end;

initialization
   RegisterContest(LABRE, TContestLABRE);

end.
