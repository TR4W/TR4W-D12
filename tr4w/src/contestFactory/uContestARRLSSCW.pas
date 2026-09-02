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

(* ARRL Sweepstakes - CW.

  The scoring is TContestARRLSSBase's. This says which running it is. *)
unit uContestARRLSSCW;

{$I tr4w.inc}

interface

uses
   uContestARRLSSBase;

type
   TContestARRLSSCW = class(TContestARRLSSBase)
   public
      function GetDisplayName: string; override;
   end;

implementation

uses
   VC, uContestRegistry;

function TContestARRLSSCW.GetDisplayName: string;
begin
   Result := 'ARRL Sweepstakes - CW';
end;

initialization
   RegisterContest(ARRLSSCW, TContestARRLSSCW);

end.
