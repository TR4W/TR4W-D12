{
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
 }

{ THE ONE PLACE THE DOMAIN CROSSES INTO THE UI, AND THE ONE PLACE THAT
  MARSHALS.

  A domain state object notifies on whatever thread changed it and knows nothing
  about a main thread -- that is the point of it.  This unit subscribes, hops to
  the main thread once, and then decides what the state LOOKS like.

  WHY THAT SPLIT IS THE WHOLE EXERCISE.  Before this, a UDP listener thread
  called SetMainWindowText(mweWSJTX, 'WSJTX') and ShowElement(mweWSJTX, True):
  a network thread naming a widget, choosing a caption, and choosing whether it
  was visible.  The caption and the visibility are decisions about APPEARANCE
  and they live here.  uWSJTX now sets a boolean.

  MARSHALLING IS Application.QueueAsyncCall, AND THAT IS AN INTERIM, NOT A
  CONCLUSION.  It was first written here as "measured, do not modernise it
  back", which cements a workaround and hides the defect underneath it.  NY4I
  called that, 2026-08-24: "this sounds like a capitulation we would not do if
  this was started from scratch."

  THE FROM-SCRATCH ANSWER IS TThread.Queue.  Two things stand in the way and
  only the first is about the RTL:

    * TThread.Queue stamps each entry with the CALLING thread's id
      (classes.inc:556 -- unconditionally, so passing nil as the thread does NOT
      dodge it) and TThread.Destroy purges by the object AND by that id.  A
      thread that queues and then exits deletes its own pending callback.
      THAT SEMANTIC IS CORRECT: when a thread dies, an update about its work
      refers to something that no longer exists.  What is WRONG is that
      TReadingThread (uFactoryRadioBase:211) is DESTROYED AND RECREATED ON EVERY
      RECONNECT.  A radio connection is a long-lived resource and reconnecting is
      a state transition inside one thread's life; with a persistent thread the
      purge fires only at shutdown, which is exactly when it should.

    * QueueAsyncCall lives in Forms, so it binds marshalling to the LCL.
      TThread.Queue is RTL -- it works in a console tool, in the unit tests and
      on any widget set.  For a program meant to reach macOS and Linux that is
      the wrong default for a core mechanism, purge or no purge.

  So: fix the thread lifetime, then move to TThread.Queue.  Scheduled in
  docs\DOMAIN_LAYER_SEQUENCE.md rather than left as a comment nobody acts on.

  WHAT THIS UNIT WILL GROW INTO: one Apply per state object.  When radio state,
  keyer state and contest state follow, they subscribe here and nothing else in
  the program learns that mwe* identifiers exist. }
unit uStateBridge;

{$I ..\..\tr4w.inc}

interface

{ Call once, after the main form exists.  Idempotent. }
procedure InstallStateBridge;

{ Repaint the WSJT-X indicator NOW.

  The bridge is driven by WSJTXState, but the box also tracks the SETTING --
  enabled shows it, disabled hides it -- and turning the setting off is not a
  state change the bridge would otherwise hear about.  Called from uCFG's
  WSJT-X ENABLED hook so the box answers the operator immediately rather
  than at the next heartbeat, which for a setting just turned off would
  never come. }
procedure RefreshWSJTXIndicator;

implementation

uses
   SysUtils, Forms,
   VC,             // TMainWindowElement, tr4wColorsArray -- the APPEARANCE side
   TF,             // SetMainWindowText
   uCrashLog,      // OnMainThread, LogCaughtException
   MainUnit,       // WSJTXIndicatorBack -- the one colour rule
   uCFG,           // WSJTXEnabled -- the box tracks the SETTING, not the link
   uMainForm,      // ShowElement, SetElementColors
   uWSJTXState;

type
   { QueueAsyncCall wants a method, so one object owns the hop. }
   TStateBridge = class(TObject)
   public
      procedure WSJTXChanged;             // subscriber -- ANY thread
      procedure ApplyWSJTX(Data: PtrInt); // main thread only
   end;

var
   GBridge: TStateBridge = nil;

{ ------------------------------------------------------------- WSJT-X ------ }

procedure TStateBridge.ApplyWSJTX(Data: PtrInt);
begin
   // THE APPEARANCE DECISIONS -- ALL FOUR OF THEM -- in the layer that owns
   // them: a live link is captioned and GREEN, a dead one is blank and hidden.
   //
   // THE COLOUR USED TO BE LEFT TO RefreshMainWindowElementColors, and that was
   // wrong.  Nothing calls it when the WSJT-X state changes: its callers are a
   // band/mode change in LOGWIND and a job on the RADIO POLLING thread.  So the
   // indicator kept whatever colour it was last painted -- red, from before the
   // link came up -- and only went green if a radio happened to repaint it.
   //
   // With the radios switched off it never went green at all.  NY4I,
   // 2026-08-26: "wsjtx is up but the box remains red."  An indicator whose
   // colour depends on an unrelated subsystem being busy is not an indicator.
   //
   // The view paints from the state it was handed. That is the whole point of
   // the bridge.
   { WHAT THE BOX MEANS: "you asked for WSJT-X", and its COLOUR says whether
     you are getting it.  Enabled and not connected is RED AND VISIBLE, not
     hidden.

     NY4I settled this, 2026-08-26: "the normal user is not in development mode
     -- wouldn't the red indicator show that. We should put WSJTX in that box
     regardless if it is red or green (again if WSJT-X ENABLED is true)."

     It is the right rule and it is worth more than it looks.  A wrong
     multicast group in WSJT-X presents to TR4W as complete silence: the join
     succeeds and nothing ever arrives.  Under the old behaviour the box simply
     was not there, which is indistinguishable from "the feature is off" -- so
     the one visible sign that something was misconfigured was a box the
     operator had to know was MISSING.  Red says it.

     It also answers the older bench-queue item, "it does not go to red, it
     just goes away entirely when I quit WSJT-X with the enabled option still
     true".  Same defect, and this is the fix -- so the open question there
     (how long does red show before it hides) is moot: while it is enabled, it
     does not hide. }
   if not WSJTXEnabled then
      begin
      SetMainWindowText(mweWSJTX, '');
      ShowElement(mweWSJTX, False);
      Exit;
      end;

   SetMainWindowText(mweWSJTX, 'WSJTX');

   { THE SAME RULE THE SWEEP USES -- MainUnit.WSJTXIndicatorBack.  Not a second
     copy of "green means connected": two writers for one property is how they
     come to disagree. }
   SetElementColors(mweWSJTX,
                    tr4wColorsArray[WSJTXIndicatorBack],
                    tr4wColorsArray[TWindows[mweWSJTX].mweColor]);
   ShowElement(mweWSJTX, True);
end;

procedure TStateBridge.WSJTXChanged;
begin
   // Called from the UDP listener thread.  One hop, and only when we are not
   // already where we need to be.
   if OnMainThread then
      begin
      ApplyWSJTX(0);
      Exit;
      end;

   if (Application = nil) or Application.Terminated then
      begin
      Exit;
      end;
   Application.QueueAsyncCall(GBridge.ApplyWSJTX, 0);
end;

{ ------------------------------------------------------------- install ----- }

procedure RefreshWSJTXIndicator;
begin
   { Through the same hop as a state change -- it must run on the main thread,
     and a config hook can be reached from either. }
   if GBridge <> nil then
      begin
      GBridge.WSJTXChanged;
      end;
end;

procedure InstallStateBridge;
begin
   if GBridge <> nil then
      begin
      Exit;
      end;
   GBridge := TStateBridge.Create;

   WSJTXState.Subscribe(GBridge.WSJTXChanged);

   // The state may already be set -- WSJT-X can heartbeat before the main form
   // is up -- so the view is brought into line once at install rather than
   // waiting for the next change.
   GBridge.WSJTXChanged;
end;

finalization
   FreeAndNil(GBridge);

end.
