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

(* CQ WPX - CW.

  Scoring is TContestCQWPXBase's. The RTTY running uses a different method and is not this class. *)
unit uContestCQWPXCW;

{$I tr4w.inc}

interface

uses
   uContestCQWPXBase;

type
   TContestCQWPXCW = class(TContestCQWPXBase)
   public
      function GetDisplayName: string; override;
   end;

implementation

uses
   VC, uContestRegistry;

function TContestCQWPXCW.GetDisplayName: string;
begin
   Result := 'CQ WPX - CW';
end;

initialization
   RegisterContest(CQWPXCW, TContestCQWPXCW);

end.
