unit uWindowTable;

(* WHERE EACH TR4W TOOL WINDOW IS, AND WHETHER IT IS OPEN.

  This lived in VC.pas -- the types unit -- and it does not belong there,
  because VC.pas is linked by tr4wserver, which is a CONSOLE program with no
  widget set at all. A window table in a unit shared with a program that has no
  windows is not merely untidy: it is what stops the table from ever naming a
  form. WndHandle could only stay an HWND while it lived next to code that must
  compile without the LCL.

  THAT BOUNDARY HAS BEEN BREACHED BEFORE AND IT COST NINE DAYS. On 2026-08-23 a
  TF -> uCrashLog -> Forms edge dragged the LCL into tr4wserver's unit graph and
  the server stopped compiling; nothing noticed, because the search-path
  exclusion that guards it only fires on a full build. Moving the table here
  makes the boundary STRUCTURAL -- the server cannot reach this unit -- instead
  of something each author has to remember.

  Verified before moving: neither tr4wserver.lpr, tr4wserverUnit nor uServerNet
  mentions tr4w_WindowsArray, TWndEntry, tWindowsExist or WindowsType.

  WndProcAdr WENT WITH THE MOVE. It was a Pointer to the Win32 dialog procedure
  each window used to be created with, and it has no live reader or writer left
  -- both remaining mentions sit inside commented-out blocks, which is what
  OpenTR4WWindow's own note already said: "as of today NOT ONE entry in
  tr4w_WindowsArray has a WndProcAdr".

  NOT `packed` ANY MORE, and that is safe rather than incidental: the record
  used to be written to settings\tr4w.pos with a raw fwrite of the whole array,
  which is why the packing mattered. Layout is JSON now (uWindowLayoutStore,
  which carries its own record), so nothing depends on this one's byte layout.

  tWindowsExist CAME FROM TF.pas for the same reason as the table -- TF is in
  tr4wserver's unit graph too, and a one-line accessor that reads a window
  table had no business there. *)

{$I tr4w.inc}

interface

uses
   Types,   { TRect }
   Forms,   { TCustomForm }
   VC;      { WindowsType, and the tw_ ids that index this array }

type
   TWndEntry = record
      WndRect:    TRect;
      WndVisible: boolean;

      (* THE WINDOW, NOT ITS NUMBER.

        This was WndHandle: HWND, and every question the program asked of it --
        is it open, where is it, is it visible, is it minimised -- went through
        a Win32 call to get back to the object that already knew. Naming the
        form asks the object. NIL IS "CLOSED", carrying exactly what the zero
        handle carried.

        IT ALSO MAKES A REAL BUG UNREPRESENTABLE. A closed LCL form still has
        an object and still has a handle, so "a form exists" was NOT "the
        window is open" -- and the position autosave, which asks each window
        where it is every five seconds, had to guard against that by hand or it
        would save a hidden form's bounds over a good saved position. The table
        holds a form only while the window is open, so those are now one
        fact. *)
      WndForm: TCustomForm;
   end;

var
   tr4w_WindowsArray: array[WindowsType] of TWndEntry;

{ IS THIS WINDOW OPEN?  Moved from TF.pas unchanged. }
function tWindowsExist(wID: WindowsType): boolean;

implementation

function tWindowsExist(wID: WindowsType): boolean;
begin
   Result := tr4w_WindowsArray[wID].WndForm <> nil;
end;

end.
