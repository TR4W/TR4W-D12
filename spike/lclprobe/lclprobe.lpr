program lclprobe;

{
  Runs the LCL probe form inside a hand-rolled GetMessage loop -- TR4W's
  structure, not the LCL's.  Application.Run is never called, exactly as in
  tr4w.dpr, because that is the constraint any toolkit here has to tolerate.

  Gate C already proved that shape works for a form built IN CODE.  What this
  adds is the part the port actually depends on: a form STREAMED FROM A .lfm
  that was written by hand the way a converter would emit it.

  Prints one line per check and exits non-zero if any failed, so it can gate.
}

{$mode objfpc}{$H+}

uses
   Windows,
   SysUtils,
   Classes,
   Interfaces,          // the LCL widgetset -- must come before Forms
   Forms,
   Controls,
   ComCtrls,
   uLCLProbeForm;

var
   probe   : TLCLProbeForm;
   report  : TStringList;
   msg     : TMsg;
   i       : integer;
   failed  : integer;
   node    : TTreeNode;
   ticks   : integer;

begin
   WriteLn('LCL .lfm streaming probe');
   WriteLn('compiler: FPC ', {$I %FPCVERSION%}, '   target: ',
           {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
   WriteLn;

   // Initialised, but NEVER Run -- we own the loop.
   Application.Initialize;

   probe := TLCLProbeForm.Create(nil);
   try
      // TTreeViewItem has no streamed LCL equivalent; nodes are built in code.
      // Doing it here proves the substitute carries the 27 items the FMX tree
      // holds as design-time children.
      node := probe.trvTree.Items.Add(nil, 'root');
      probe.trvTree.Items.AddChild(node, 'child');

      probe.Show;

      // Pump OUR loop briefly so the form is realised through the same path
      // TR4W would drive it -- streaming that only works under Application.Run
      // would be no use here.
      ticks := 0;
      while (ticks < 200) and PeekMessage(msg, 0, 0, 0, PM_REMOVE) do
         begin
         TranslateMessage(msg);
         DispatchMessage(msg);
         Inc(ticks);
         end;

      // THE FMX TRAP, asked directly of the LCL.  Under FMX every hosted form
      // stayed Active=False because Application.Run was never called, and the
      // only visible symptom was that edits took keystrokes but showed NO
      // CARET.  If the LCL has the same dependency it needs its own shim; if
      // not, uLCLCoexist has nothing to mirror.  Asked, not assumed.
      WriteLn;
      WriteLn('  form Active     : ', probe.Active);
      WriteLn('  form Visible    : ', probe.Visible);
      WriteLn('  handle allocated: ', probe.HandleAllocated);
      probe.edtAddress.SetFocus;
      for ticks := 0 to 50 do
         begin
         if PeekMessage(msg, 0, 0, 0, PM_REMOVE) then
            begin
            TranslateMessage(msg);
            DispatchMessage(msg);
            end;
         end;
      WriteLn('  edit Focused    : ', probe.edtAddress.Focused);
      WriteLn;

      report := ProbeReport(probe);
      try
         failed := 0;
         for i := 0 to report.Count - 1 do
            begin
            WriteLn(report[i]);
            if Pos('FAIL', report[i]) > 0 then
               begin
               Inc(failed);
               end;
            end;
         WriteLn;
         WriteLn(Format('%d check(s), %d failed', [report.Count, failed]));
      finally
         report.Free;
      end;
   finally
      probe.Free;
   end;

   if failed > 0 then
      begin
      Halt(1);
      end;
end.
