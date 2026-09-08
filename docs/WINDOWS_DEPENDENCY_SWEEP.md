# The Windows dependency sweep -- what is left, and how each kind moves

**Generated 2026-09-08** by walking every TR4W unit with `build/PascalSource.psm1`
(comments and string literals blanked, directives kept) and listing the ones that
name `Windows`, `Messages` or `WinSock` in a uses clause **the compiler always
sees** -- an entry already inside `{$IFDEF WINDOWS}` is not listed, because that
is the finished state.

**Regenerate rather than trust it.** The counts below drift with every commit,
which is exactly what CLAUDE.md says about counts in prose. The scan is
`tools/Compile-Linux.ps1`'s companion; the numbers here are a starting point for
a session, not a status.

## Why this file exists

The first pass at this (2026-09-08) followed `MainUnit`'s dependency chain with
the Linux cross compiler, unit by unit. That works right up until the chain
blocks -- it stopped at `CompareStringA` in `uCallsigns`, which cannot move until
its tests exist -- and then there is nothing obvious to do next, because the
worklist only ever existed as a path through a graph. **A blocked chain removes
one unit from the list; it does not end the sweep.** Hence a list.

## The stop condition

Zero ungated entries, **or** every remaining one has its reason written beside it
in the uses clause -- and, where the reason is a decision rather than a fact, an
entry in `BENCH_QUEUE.md`. "Windows stays here" is an acceptable outcome;
"Windows is here and nobody knows why" is not.

## The method, which is the part worth copying

1. `winscan` the unit -- code only -- to see what it actually references. **Most
   of the first tranche referenced NOTHING**: 23 units named `Windows` or
   `Messages` and used neither.
2. Convert, using the table below.
3. **Let the compiler judge.** The scan is a regex and it misses things --
   `IsChild`, `LoadIcon`, `MAXLONG`, `QueryPerformanceCounter` and `IsWin64` all
   got past it. A full Windows build after each batch is what catches them, and
   three of the first 26 candidates were wrong.
4. Full build + unit tests + lints before every commit.

## Conversions already proven in this tree

| Win32 | Replacement | Note |
|---|---|---|
| `GetTickCount` | `GetTickCount64` | widen the field to `QWord`. If a 32-bit value is on the wire or in a record, truncate DELIBERATELY and say so -- see `uIcomNetworkTransport.TickCount32` |
| `GetLastError` | `SysUtils.GetLastOSError` | literally `GetLastError` on Windows, `fpgetErrNo` on Unix |
| `lstrcatA` / `lstrlenA` | `uAnsiStr.StrPLCopy` / `uAnsiStr.StrLen` | and BOUND it -- `lstrcatA` walks to the NUL and keeps writing |
| `GetFileSize` | `utils_file.sFileSize` | NOT bare `FileSeek`: seeking MOVES the pointer, and callers depend on it not moving |
| `SetFilePointer` | `SysUtils.FileSeek(..., fsFromBeginning)` | |
| `ReadFile` / `WriteFile` / `CloseHandle` | `utils_file.sReadFile` / `sWriteFile` / `SysUtils.FileClose` | the wrappers are already on the RTL |
| `InitializeCriticalSection` / `DeleteCriticalSection` | `InitCriticalSection` / `DoneCriticalSection` | the RTL's names for the same record, on every platform. Enter/Leave already are |
| `WaitForSingleObject` + `CloseHandle` on a thread | `WaitForThreadTerminate` + `CloseThread` | `tCreateThread` is `BeginThread`, so it holds a `TThreadID`. Off Windows the TIMEOUT IS IGNORED -- say so at the site |
| `SetThreadPriority` | `ThreadSetPriority(h, -15..15)` | advisory off Windows; it usually needs a real-time policy |
| `InterlockedIncrement` | `System.InterLockedIncrement` | same intrinsic |
| `Sleep` | `SysUtils.Sleep` | already there once `Windows` goes |
| `DWORD`, `WPARAM`, `HWND`, `SW_*`, `IDYES`/`IDNO` | `LCLType` | on Windows these ARE the `Windows` declarations, so no signature moves |
| `MAXLONG` | `System.MaxLongint` | |
| `socket`/`sendto`/`setsockopt`/`inet_addr` | Indy: `TIdSocketHandle`, `SendBuffer`, `SetSockOpt`, `UpdateBindingLocal` | see `uIcomNetworkTransport` -- and read its bench entry first |
| genuinely Windows | `{$IFDEF WINDOWS}` **and the uses entry with it** | a unit whose CODE is gated but whose USES CLAUSE is not can never compile elsewhere |

## What is left

`CALLS` needs work, `TYPES` is usually a one-line swap to `LCLType`, `DEAD` means
the scan found nothing (verify with the compiler -- see step 3).

| Kind | Unit | Calls still referenced | Types still referenced |
|---|---|---|---|
| CALLS | `bench_callsign.lpr` | `QueryPerformance` | `BOOL` |
| CALLS | `DLPortIO.pas` | `GetLastError` `lstrcat` `LoadLibrary` `GetProcAddress` `FreeLibrary` | `DWORD` `THandle` `MAX_PATH` `BOOL` |
| CALLS | `fcontest.pas` | `lstrcat` | `BOOL` |
| CALLS | `GetWinVersionInfo.pas` | `GetProcAddress` `GetModuleHandle` `GetSystemMetrics` | `DWORD` `BOOL` |
| CALLS | `LogCfg.pas` | `GetTickCount` `lstrcat` `wsprintf` | `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `logddx.pas` | `Sleep` | `BOOL` |
| CALLS | `logdump.lpr` | `CreateFile` `WriteFile` `CloseHandle` | `DWORD` `THandle` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `logdupe.pas` | `wsprintf` `CloseHandle` | `THandle` `BOOL` `MAXWORD` `MAXLONG` |
| CALLS | `logdvp.pas` | `GetLastError` `Sleep` `lstrlen` `CreateFile` `ReadFile` `CloseHandle` `WaitForSingleObject` `timeSetEvent` `sndPlaySound` | `HANDLE` `THandle` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `logedit.pas` | `wsprintf` | `BOOL` `SW_` |
| CALLS | `logk1ea.pas` | `Sleep` `CloseHandle` `WaitForSingleObject` `SetThreadPriority` `timeBeginPeriod` `timeSetEvent` | `DWORD` `THandle` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `logstuff.pas` | `GetTickCount` | `BOOL` `MAXWORD` |
| CALLS | `logsubs1.pas` | `Sleep` | `BOOL` |
| CALLS | `logsubs2.pas` | `GetTickCount` `Sleep` `wsprintf` `CloseHandle` `WSA` | `DWORD` `HANDLE` `THandle` `BOOL` `SW_` `IDNO` `SYSTEMTIME` |
| CALLS | `logwind.pas` | `GetTickCount` `wsprintf` `ReadFile` `CloseHandle` `SystemTimeToTz` `GetSystemTime` | `THandle` `BOOL` `SW_` `SYSTEMTIME` |
| CALLS | `MainUnit.pas` | `GetTickCount` `GetLastError` `Sleep` `lstrcat` `wsprintf` `CloseHandle` `FindFirstFile` `SetEvent` `SetThreadPriority` `LoadLibrary` `GetProcAddress` `FreeLibrary` `ShowWindow` `MoveWindow` `SendMessage` `GetKeyState` `SetFocus` `GetSystemMetrics` `socket` `sendto` `GetSystemTime` `sndPlaySound` `MessageBox` | `DWORD` `WPARAM` `HANDLE` `THandle` `BOOL` `SW_` `VK_` `IDYES` `IDNO` `INVALID_HANDLE_VALUE` `SYSTEMTIME` |
| CALLS | `tr4w_radio_bench.lpr` | `GetTickCount` `Sleep` | `DWORD` `BOOL` |
| CALLS | `tr4wserverUnit.pas` | `Sleep` `SendMessage` `socket` `sendto` | `DWORD` `HANDLE` `THandle` `BOOL` `IDYES` `IDNO` `INVALID_HANDLE_VALUE` `SYSTEMTIME` |
| CALLS | `uAppInputHooks.pas` | `GetTickCount` | `HANDLE` `BOOL` `VK_` |
| CALLS | `uBandmap.pas` | `GetTickCount` | `HMENU` `BOOL` |
| CALLS | `uBandPlanForm.pas` | `GetSystemMetrics` | `HANDLE` `BOOL` |
| CALLS | `uCabrilloHeader.pas` | `GetPrivateProfile` | `DWORD` `BOOL` |
| CALLS | `uCallsigns.pas` | `wsprintf` `CompareString` | `BOOL` |
| CALLS | `uCFG.pas` | `lstrcat` `lstrlen` `wsprintf` | `BOOL` `MAXWORD` |
| CALLS | `uCheckLatestVersion.pas` | `Sleep` `wsprintf` `closesocket` `WSA` | `IDYES` |
| CALLS | `uDXSpotParse.pas` | `lstrcpy` | `BOOL` |
| CALLS | `uEditMessageForm.pas` | `CloseHandle` `SetFocus` | `LPARAM` `HANDLE` `THandle` `BOOL` `VK_` `IDNO` |
| CALLS | `uEditQSO.pas` | `wsprintf` | `BOOL` `MAXWORD` |
| CALLS | `uExternalLoggerBase.pas` | `GetTickCount` `Sleep` `SetEvent` `socket` `sendto` | `HANDLE` `BOOL` |
| CALLS | `uFileView.pas` | `wsprintf` `LoadLibrary` `GetProcAddress` `FreeLibrary` | `THandle` `BOOL` |
| CALLS | `uFlexDiscovery.pas` | `GetTickCount` | `BOOL` |
| CALLS | `uFunctionKeys.pas` | `GetKeyState` | `VK_` |
| CALLS | `uGetScores.pas` | `lstrlen` `CloseHandle` | `HANDLE` `THandle` `SYSTEMTIME` |
| CALLS | `uGetServerLog.pas` | `ReadFile` `CloseHandle` `SetFilePointer` `closesocket` `WSA` | `THandle` `BOOL` `INVALID_HANDLE_VALUE` `FILE_BEGIN` |
| CALLS | `uGradient.pas` | `LoadLibrary` `GetProcAddress` `GetModuleHandle` `GetSysColor` | `HDC` `BOOL` |
| CALLS | `uHamScore.pas` | `CloseHandle` `CreateEvent` `SetEvent` | `DWORD` `HANDLE` `THandle` `BOOL` |
| CALLS | `uHistory.pas` | `wsprintf` `CreateFile` `CloseHandle` `SendMessage` | `THandle` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `uIcomNetworkDiscovery.pas` | `GetTickCount` | `BOOL` |
| CALLS | `uIntercom.pas` | `CreateFile` `CloseHandle` `SetFilePointer` | `DWORD` `THandle` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `uIO.pas` | `LoadLibrary` `GetProcAddress` `FreeLibrary` | `DWORD` `THandle` `BOOL` |
| CALLS | `uK4Discovery.pas` | `GetTickCount` | `BOOL` |
| CALLS | `uMMTTYForm.pas` | `MoveWindow` `SendMessage` | `HANDLE` `VK_` |
| CALLS | `uNet.pas` | `GetTickCount` `Sleep` `wsprintf` `CreateFile` `WaitForSingleObject` `SetEvent` `SendMessage` `sendto` `GetCurrentThreadId` | `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `uPanelUpdate.pas` | `IsWindow` `IsChild` | `BOOL` |
| CALLS | `uPrefsForm.pas` | `SetFocus` | `BOOL` `VK_` |
| CALLS | `uProcessCommand.pas` | `sendto` `WinExec` | `BOOL` |
| CALLS | `uProgramMain.pas` | `GetLastError` `CreateEvent` | `BOOL` `SYSTEMTIME` |
| CALLS | `uQTCS.pas` | `Sleep` `ReadFile` | `BOOL` `IDNO` |
| CALLS | `uRadioConfigApply.pas` | `GetTickCount` `GetPrivateProfile` | `BOOL` `MAXWORD` |
| CALLS | `uRadioPolling.pas` | `GetTickCount` `Sleep` | `BOOL` |
| CALLS | `uRadioTCI.pas` | `sendto` | `BOOL` |
| CALLS | `uSendKeyboardForm.pas` | `SetFocus` | `HANDLE` `BOOL` `VK_` |
| CALLS | `uServerLogForm.pas` | `GetLastError` `CreateFile` `CloseHandle` | `HANDLE` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `uSimProcess.pas` | `GetLastError` `WriteFile` `CloseHandle` `WaitForSingleObject` | `DWORD` `HANDLE` `THandle` `BOOL` |
| CALLS | `uStations.pas` | `wsprintf` | `BOOL` |
| CALLS | `uSynTime.pas` | `Sleep` `GetSystemTime` | `SYSTEMTIME` `FILETIME` |
| CALLS | `uTCIServer.pas` | `GetTickCount` `SetEvent` | `HANDLE` `BOOL` |
| CALLS | `uTelnet.pas` | `wsprintf` `CreateFile` `CloseHandle` `WaitForSingleObject` `socket` `WSA` `sendto` | `DWORD` `HANDLE` `THandle` `BOOL` `INVALID_HANDLE_VALUE` |
| CALLS | `uTestCWByCATTimer.pas` | `GetTickCount` `Sleep` | `HANDLE` `BOOL` |
| CALLS | `uTestFormatTranslation.pas` | `wsprintf` | -- |
| CALLS | `uTestLogRepository.pas` | `DeleteFile` | `BOOL` `MAXWORD` |
| CALLS | `uTestMain.pas` | `Sleep` | `BOOL` |
| CALLS | `uTestRadioConfigStore.pas` | `DeleteFile` | `BOOL` |
| CALLS | `uTestTCIServer.pas` | `GetTickCount` `Sleep` | `BOOL` |
| CALLS | `uTestUtilsFile.pas` | `CreateFile` `ReadFile` `CloseHandle` `DeleteFile` | `DWORD` `THandle` `MAX_PATH` `INVALID_HANDLE_VALUE` |
| CALLS | `uTestWebSocketLoopback.pas` | `GetTickCount` `Sleep` | `BOOL` |
| CALLS | `utils_net.pas` | `socket` `closesocket` `inet_addr` `htons` `WSA` | `DWORD` `BOOL` |
| CALLS | `uWinManager.pas` | `ShowWindow` | -- |
| CALLS | `uWinManagerForm.pas` | `ShowWindow` `SetFocus` | `HANDLE` `BOOL` |
| DEAD | `tr4w.lpr` | -- | -- |
| DEAD | `tr4w_consts_esp.pas` | -- | -- |
| TYPES | `postunit.pas` | -- | `THandle` `BOOL` `IDYES` `MAXWORD` |
| TYPES | `tr4w_status_trace.lpr` | -- | `BOOL` |
| TYPES | `tr4wserver.lpr` | -- | `BOOL` `IDNO` |
| TYPES | `uCAT.pas` | -- | `BOOL` `INVALID_HANDLE_VALUE` |
| TYPES | `uEmbeddedTranslations.pas` | -- | `LPARAM` `BOOL` |
| TYPES | `uLogCompareForm.pas` | -- | `LPARAM` `HANDLE` `BOOL` |
| TYPES | `uLPTForm.pas` | -- | `HANDLE` `INVALID_HANDLE_VALUE` |
| TYPES | `uNewContest.pas` | -- | `BOOL` `IDNO` |
| TYPES | `uRadioEditForm.pas` | -- | `HANDLE` `BOOL` |
| TYPES | `uTestFreqTimeFormat.pas` | -- | `SYSTEMTIME` |
| TYPES | `uWin32Compat.pas` | -- | `DWORD` `HANDLE` `THandle` `BOOL` |

## Known to stay, with the reason recorded

| Unit | Why |
|---|---|
| `uPanelUpdate` | `IsChild` -- the LCL declares `IsWindow` but not `IsChild`, and `IsChild` is the one that matters |
| `uInputQueryForm` | `LoadIcon` for the standard system icons; off Windows the dialog shows none |
| `uWinKey` | `QueryPerformanceCounter` -- no RTL equivalent, and `GetTickCount64`'s 1 ms floor would blur what the trace measures |
| `BeepUnit` | `\Device\Beep` by IOCTL. Off Windows every entry point is a no-op that says so once |
| `uCallsigns` | `CompareStringA` -- one of three drifted copies; the TESTS come before the repoint |
| `logwind` | `SystemTimeToTzSpecificLocalTime` -- no RTL timezone-database call. The rest of its list is ordinary |
| `uHamLibDirect` | nothing, syntactically -- but `HAMLIB_DLL` names a `.dll` and `PEMachineOf` asks a PE question. Verify the soname ON the platform; do not invent it |
