program gate_c;

// FPC VIABILITY GATE C -- can an LCL form live inside TR4W's OWN message loop?
//
// TR4W is not an LCL application and never will be.  `program tr4w;` runs its
// own GetMessage / TranslateMessage / DispatchMessage loop (tr4w.dpr:1063) and
// builds its windows with CreateWindow.  There is no MainForm and
// Application.Run is never called.  Any GUI toolkit we adopt has to tolerate
// that, because the alternative is rewriting the entire main window first.
//
// This is the LCL version of the gate the FMX work already passed on the
// bench.  It deliberately mirrors TR4W's structure: a real Win32 window class,
// a real hand-rolled loop, and an LCL form created inside it.
//
// The four things it proves, in order of how badly each would hurt:
//
//   1. An LCL form can be created and shown while WE own the loop.
//   2. It receives input -- messages our loop dispatches reach its controls.
//   3. TThread.Queue drains.  This is the one the FMX gate flagged as
//      load-bearing: worker threads hand results back this way, so a form
//      that cannot drain the queue silently freezes every radio update.
//   4. Our own Win32 window still works afterwards -- the toolkit has not
//      quietly taken the loop over.
//
// Runs headless-ish: it drives itself from a timer and exits on its own.
//
// Built for x86_64 because that is where the LCL is installed.  The question
// is architectural, not about word size -- nothing here depends on pointer
// width -- so the result transfers to i386 once an i386 LCL exists.

{$MODE Delphi}
{$MODESWITCH UnicodeStrings}

uses
   Interfaces,   // MUST be first LCL unit: links the Win32 widgetset
   Forms,
   Controls,
   StdCtrls,
   Classes,
   SysUtils,
   Windows;

const
   TIMER_ID = 1;
   TICK_MS  = 150;

type
   TQueueProbe = class
   public
      Ran: Boolean;
      RanOnMainThread: Boolean;
      procedure MarkDone;
   end;

   TWorker = class(TThread)
   private
      FProbe: TQueueProbe;
   protected
      procedure Execute; override;
   public
      constructor Create(AProbe: TQueueProbe);
   end;

var
   Passed: Integer = 0;
   Failed: Integer = 0;
   Step: Integer = 0;
   MainHwnd: HWND = 0;
   MainWndHits: Integer = 0;
   LForm: TForm = nil;
   LEdit: TEdit = nil;
   Probe: TQueueProbe = nil;
   Worker: TWorker = nil;
   MainThreadId: TThreadID;

procedure Report(const AName: string; AOk: Boolean; const ADetail: string = '');
begin
   if AOk then
      begin
      Inc(Passed);
      WriteLn('  [PASS] ', AName, ' ', ADetail);
      end
   else
      begin
      Inc(Failed);
      WriteLn('  [FAIL] ', AName, ' ', ADetail);
      end;
end;

procedure TQueueProbe.MarkDone;
begin
   Ran := True;
   // A queued method must run on the MAIN thread -- that is the whole point.
   RanOnMainThread := (GetCurrentThreadId = MainThreadId);
end;

constructor TWorker.Create(AProbe: TQueueProbe);
begin
   FProbe := AProbe;
   inherited Create(False);
   FreeOnTerminate := False;
end;

procedure TWorker.Execute;
begin
   // Sleep first so the queue call genuinely arrives from another thread
   // while the main loop is already running, as a radio thread would.
   Sleep(120);
   TThread.Queue(nil, FProbe.MarkDone);
end;

// Our own Win32 window procedure -- exactly the shape MainUnit uses.
function MainWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
   if uMsg = WM_APP + 7 then
      begin
      Inc(MainWndHits);
      Result := 0;
      Exit;
      end;
   Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
end;

procedure CreateOurWindow;
var
   wc: WNDCLASSW;
begin
   FillChar(wc, SizeOf(wc), 0);
   wc.lpfnWndProc := @MainWndProc;
   wc.hInstance := HInstance;
   wc.lpszClassName := 'TR4W_GATE_C';
   wc.hCursor := LoadCursor(0, IDC_ARROW);
   Windows.RegisterClassW(@wc);

   MainHwnd := CreateWindowExW(0, 'TR4W_GATE_C', 'TR4W gate C host',
      WS_OVERLAPPEDWINDOW, 40, 40, 420, 180, 0, 0, HInstance, nil);
end;

procedure BuildLCLForm;
begin
   LForm := TForm.CreateNew(nil);
   LForm.Caption := 'LCL form inside TR4W''s loop';
   LForm.SetBounds(500, 40, 420, 180);

   LEdit := TEdit.Create(LForm);
   LEdit.Parent := LForm;
   LEdit.SetBounds(20, 40, 360, 28);
   LEdit.Text := '';

   LForm.Show;
end;

procedure Tick;
var
   i: Integer;
   s: string;
begin
   Inc(Step);

   case Step of
      1:
         begin
         WriteLn('LCL form:');
         BuildLCLForm;
         Report('form created and shown', (LForm <> nil) and LForm.Visible);
         Report('native handle allocated', LForm.HandleAllocated,
            '(HWND ' + IntToStr(LForm.Handle) + ')');
         end;

      2:
         begin
         // Post characters at the LCL edit's own HWND.  They travel through
         // OUR GetMessage/DispatchMessage loop to reach it.
         s := 'TR4W';
         for i := 1 to Length(s) do
            begin
            PostMessageW(LEdit.Handle, WM_CHAR, WPARAM(Ord(s[i])), 0);
            end;
         end;

      3:
         begin
         Report('input reached LCL control', LEdit.Text = 'TR4W',
            '(Edit.Text = "' + LEdit.Text + '")');
         end;

      4:
         begin
         WriteLn;
         WriteLn('Cross-thread marshalling:');
         Probe := TQueueProbe.Create;
         Worker := TWorker.Create(Probe);
         end;

      5, 6:
         begin
         // give the worker a tick or two
         end;

      7:
         begin
         Report('TThread.Queue drained', Probe.Ran);
         Report('queued method ran on main thread', Probe.RanOnMainThread);
         end;

      8:
         begin
         WriteLn;
         WriteLn('Host Win32 window:');
         PostMessageW(MainHwnd, WM_APP + 7, 0, 0);
         end;

      9:
         begin
         Report('our own WndProc still served', MainWndHits = 1,
            '(hits = ' + IntToStr(MainWndHits) + ')');
         Report('LCL form still alive', LForm.HandleAllocated);
         end;

      10:
         begin
         PostQuitMessage(0);
         end;
   end;
end;

var
   msg: Windows.TMsg;

begin
   MainThreadId := GetCurrentThreadId;

   WriteLn('FPC Gate C -- LCL form inside TR4W''s own message loop');
   WriteLn('compiler: FPC ', {$I %FPCVERSION%}, '  target: ', {$I %FPCTARGETCPU%}, '-', {$I %FPCTARGETOS%});
   WriteLn;

   // LCL is initialised, but Application.Run is NEVER called -- we own the loop.
   Application.Initialize;

   WriteLn('Host window:');
   CreateOurWindow;
   Report('Win32 host window created', MainHwnd <> 0, '(HWND ' + IntToStr(MainHwnd) + ')');
   ShowWindow(MainHwnd, SW_SHOW);

   SetTimer(MainHwnd, TIMER_ID, TICK_MS, nil);

   // TR4W's loop, verbatim in shape (tr4w.dpr:1063).
   while GetMessage(msg, 0, 0, 0) do
      begin
      if (msg.hwnd = MainHwnd) and (msg.message = WM_TIMER) then
         begin
         Tick;
         end;

      TranslateMessage(msg);
      DispatchMessage(msg);

      // Drain queued cross-thread calls.  TR4W's loop would do the same;
      // this is the LCL analogue of the fall-through DispatchMessage that
      // the FMX gate found load-bearing.
      CheckSynchronize(0);
      end;

   KillTimer(MainHwnd, TIMER_ID);

   if Worker <> nil then
      begin
      Worker.WaitFor;
      Worker.Free;
      end;
   Probe.Free;

   WriteLn;
   WriteLn(Format('PASSED: %d  FAILED: %d', [Passed, Failed]));
   if Failed > 0 then
      begin
      Halt(1);
      end;
end.
