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

(* ARRL INTERNATIONAL DX -- CW.

  A THIN SUBCLASS, WHICH IS THE POINT. Every rule ARRL DX has is shared with
  Phone and lives in TContestARRLDXBase; this unit exists to say WHICH contest
  it is and to register it. TR4QT's ARRLDXCWContest is the same shape and
  carries the same near-nothing: an id, a name, a mode, and its Cabrillo tag.

  IT IS STILL A SEPARATE UNIT AND A SEPARATE REGISTRATION. An operator selects
  ARRL-DX-CW or ARRL-DX-SSB -- two contests, two rows in ContestsArray -- and
  the radio factory's rule says the same thing from the other side: one model,
  one registration, or the model becomes unselectable. A single class serving
  both modes would answer "which class is ARRL-DX-SSB" only by reading another
  unit. *)
unit uContestARRLDXCW;

{$I tr4w.inc}

interface

uses
   uContestARRLDXBase;

type
   TContestARRLDXCW = class(TContestARRLDXBase)
   public
      function GetDisplayName: string; override;
   end;

implementation

uses
   VC, uContestRegistry;

function TContestARRLDXCW.GetDisplayName: string;
begin
   Result := 'ARRL International DX Contest - CW';
end;

initialization
   RegisterContest(ARRLDXCW, TContestARRLDXCW);

end.
