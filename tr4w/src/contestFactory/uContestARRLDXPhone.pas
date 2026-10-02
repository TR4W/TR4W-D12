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

(* ARRL INTERNATIONAL DX -- Phone.

  A THIN SUBCLASS, WHICH IS THE POINT. Every rule ARRL DX has is shared with
  CW and lives in TContestARRLDXBase; this unit exists to say WHICH contest
  it is and to register it. TR4QT's ARRLDXPhoneContest is the same shape and
  carries the same near-nothing: an id, a name, a mode, and its Cabrillo tag.

  IT IS STILL A SEPARATE UNIT AND A SEPARATE REGISTRATION. An operator selects
  ARRL-DX-CW or ARRL-DX-SSB -- two contests, two rows in ContestsArray -- and
  the radio factory's rule says the same thing from the other side: one model,
  one registration, or the model becomes unselectable. A single class serving
  both modes would answer "which class is ARRL-DX-SSB" only by reading another
  unit. *)
unit uContestARRLDXPhone;

{$I tr4w.inc}

interface

uses
   (* TNewContestPrompts -- the New Contest dialog's prompts (M9a). *)
   uContestBase,
   uContestARRLDXBase;

type
   TContestARRLDXPhone = class(TContestARRLDXBase)
   protected
      (* THE GETTERS BEHIND TContestBase's PROPERTIES.

         PROTECTED, MATCHING THE BASE. Left public -- which is what the first
         conversion did, because a class body with no section defaults to
         public -- BOTH X.CabrilloName and X.GetCabrilloName are callable on
         this object. Two ways to ask the same question is exactly the
         ambiguity a property removes, so the getter is not part of the
         surface: callers use the property, descendants override the getter. *)
      function GetDisplayName: string; override;
      function GetCabrilloName: string; override;
      function GetADIFContestId: string; override;
      function GetFriendlyName: string; override;
   public
   public
      (* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's, moved here at
         M9a. See TContestBase.DescribeNewContestPrompts. *)
      procedure DescribeNewContestPrompts(aPrompts: TNewContestPrompts); override;
   end;

implementation

uses
   VC, uContestRegistry,
   uTR4WStrings;

function TContestARRLDXPhone.GetDisplayName: string;
begin
   Result := 'ARRL Inter. DX Contest, SSB';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestARRLDXPhone.GetCabrilloName: string;
begin
   Result := 'ARRL-DX-SSB';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestARRLDXPhone.GetADIFContestId: string;
begin
   Result := 'ARRL-DX-SSB';
end;

(* STATED, NOT INHERITED -- M9a (2026-10-02): every contest class states its
   identity, and this is the value the row gave it. *)
function TContestARRLDXPhone.GetFriendlyName: string;
begin
   Result := 'ARRL Inter. DX Contest, SSB';
end;

(* THE NEW CONTEST DIALOG'S PROMPTS -- uNewContest's two
   `case SelectedContest of` arms for this contest, moved here as they
   stood (M9a, 2026-10-02): the steps on CHOOSING the contest, then the
   ones on ticking its "I am in" box. See
   TContestBase.DescribeNewContestPrompts.
   The same steps on choosing stood for ARRLDXCW.
   Each contest holds its own copy (design 1.4), so a sponsor
   changing one changes one. *)
procedure TContestARRLDXPhone.DescribeNewContestPrompts(aPrompts: TNewContestPrompts);
begin
   aPrompts.AskFieldWithComment(TC_ENTERYOURQTHORPOWER, ncfMyState);
end;

initialization
   RegisterContest(ARRLDXSSB, TContestARRLDXPhone);

end.
