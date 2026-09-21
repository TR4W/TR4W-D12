unit uMacMenuBar;

(* THE macOS GLOBAL MENU BAR, AND THE ONE THING THE LCL CANNOT SAY ABOUT IT.

  MEASURED, NOT REASONED. On 2026-09-21 NY4I reported that TR4W starts on
  macOS with an empty menu bar and that the bar appears only when the pointer
  enters it. Two explanations were possible and they need opposite fixes: the
  menu is never INSTALLED, or it is installed and simply not DRAWN.

  The program was instrumented and run on mac-ci, launched through
  LaunchServices the way an operator launches it. Its own log line, 300 ms
  after the main window appeared and long before any mouse moved:

    [MacMenu] promoting: Application.Active=True form.Active=True
      ActiveCustomForm=TTR4WMainForm menu=True menuHandle=True
      bar[mainMenu items=10 titles=|File|Settings|Windows|Alt-|Ctrl-|Commands
      |Tools|Net|Help| NSApp.active=True]
    [MacMenu] window: NSApp.key=True NSApp.main=True win visible=True
      key=True main=True canKey=True canMain=True

  So the menu IS installed, with every one of TR4W's titles on it, while the
  application is frontmost and its window is key. And a HOVER cannot install a
  menu -- nothing in this program is reached by the pointer entering the
  system menu bar. The bar was therefore installed and undrawn, and the hover
  made the system draw what was already there.

  WHY THE LCL HAS NOTHING FOR THIS. The LCL installs the menu in exactly one
  place -- TLCLWindowCallback.Activate, on windowDidBecomeKey -- and that is an
  EDGE. Once it has fired there is no LCL property, method or event that says
  "draw the bar again"; TCustomForm.UpdateMenu is private, and re-attaching
  through TMainMenu.WindowHandle ends at NSApp.setMainMenu with the same NSMenu
  object, which AppKit can legitimately treat as no change.

  Hence the one raw call in this unit, and its justification: AppKit rebuilds
  the menu bar when the main menu CHANGES, so the menu is taken down and put
  straight back. It happens once, at start-up, on Darwin only.

  DELETE THIS UNIT THE DAY THE LCL GROWS A WAY TO ASK FOR THE SAME THING. *)

{$MODE OBJFPC}{$H+}
{$IFDEF DARWIN}
{$modeswitch objectivec1}
{$ENDIF}

interface

(* Put the current main menu back up so AppKit redraws the bar. A no-op off
  Darwin, and a no-op if no main menu is installed -- there would be nothing
  to redraw, and this must never be the thing that CLEARS a menu bar. *)
procedure ForceMenuBarRedraw;

(* WHAT IS ON THE BAR RIGHT NOW, for the log. The question above took a bench
  round to answer because nothing in the program could report it. *)
function MenuBarDescription: string;

implementation

uses
   SysUtils
   {$IFDEF DARWIN}, CocoaAll, CocoaUtils{$ENDIF};

{$IFDEF DARWIN}
procedure ForceMenuBarRedraw;
var
   app:  NSApplication;
   menu: NSMenu;
begin
   app  := NSApplication.sharedApplication;
   menu := app.mainMenu;
   if menu = nil then
      begin
      Exit;
      end;

   (* RETAINED ACROSS THE GAP. setMainMenu(nil) releases the menu it is
     holding, and this is the only reference left to it. *)
   menu.retain;
   try
      app.setMainMenu(nil);
      app.setMainMenu(menu);
   finally
      menu.release;
   end;
end;

function MenuBarDescription: string;
var
   menu: NSMenu;
   i:    integer;
begin
   menu := NSApplication.sharedApplication.mainMenu;
   if menu = nil then
      begin
      Result := 'mainMenu=nil';
      end
   else
      begin
      Result := Format('mainMenu items=%d titles=', [menu.numberOfItems]);
      for i := 0 to menu.numberOfItems - 1 do
         begin
         Result := Result + NSStringToString(menu.itemAtIndex(i).title) + '|';
         end;
      end;

   Result := Result + Format(' NSApp.active=%s key=%s',
                             [BoolToStr(NSApplication.sharedApplication.isActive, True),
                              BoolToStr(NSApplication.sharedApplication.keyWindow <> nil, True)]);
end;
{$ELSE}
procedure ForceMenuBarRedraw;
begin
   (* Windows has no global menu bar and gtk2's is per-window. Nothing to do,
     and deliberately not an error: the caller is platform-neutral. *)
end;

function MenuBarDescription: string;
begin
   Result := 'not a global menu bar on this platform';
end;
{$ENDIF}

end.
