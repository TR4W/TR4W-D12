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

(* NRAU-BALTIC CONTEST -- CW.

  The contest is TContestNRAUBalticBase's; this class states only what makes
  it the CW running: its names and its calendar id (WA7BNM 220, verified
  2026-09-29). The row's ADIFName and CABName are blank, so both are the
  enum's spelling, stated as such -- never ''.

  THE CABRILLO NAME IS A QUESTION FOR NY4I, NOT A DECISION MADE HERE. The
  contest calendar lists the Cabrillo names as NRAU-CW / NRAU-SSB, while TR4W
  has always sent NRAU-BALTIC-CW / NRAU-BALTIC-SSB. Transcribed unchanged. *)
unit uContestNRAUBalticCW;

{$I tr4w.inc}

interface

uses
   uContestNRAUBalticBase;

type
   TContestNRAUBalticCW = class(TContestNRAUBalticBase)
   protected
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetWA7BNMId: integer; override;
      function GetFriendlyName: string; override;
   end;

implementation

uses
   VC, uContestRegistry;

function TContestNRAUBalticCW.GetDisplayName: string;
begin
   Result := 'NRAU-Baltic Contest, CW';
end;

function TContestNRAUBalticCW.GetCabrilloName: string;
begin
   (* The row's CABName is blank; this is the enum's spelling it resolves
      to. *)
   Result := 'NRAU-BALTIC-CW';
end;

function TContestNRAUBalticCW.GetADIFContestId: string;
begin
   (* The row's ADIFName is blank; export writes the enum's spelling, and
      import matches it (M1). *)
   Result := 'NRAU-BALTIC-CW';
end;

function TContestNRAUBalticCW.GetWA7BNMId: integer;
begin
   Result := 220;
end;

function TContestNRAUBalticCW.GetFriendlyName: string;
begin
   Result := 'NRAU-Baltic Contest, CW';
end;

initialization
   RegisterContest(NRAUBALTICCW, TContestNRAUBalticCW);

end.
