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

| Win32                                                 | Replacement                                                               | Note                                                                                                                                                     |
| ----------------------------------------------------- | ------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `GetTickCount`                                        | `GetTickCount64`                                                          | widen the field to `QWord`. If a 32-bit value is on the wire or in a record, truncate DELIBERATELY and say so -- see `uIcomNetworkTransport.TickCount32` |
| `GetLastError`                                        | `SysUtils.GetLastOSError`                                                 | literally `GetLastError` on Windows, `fpgetErrNo` on Unix                                                                                                |
| `lstrcatA` / `lstrlenA`                               | `uAnsiStr.StrPLCopy` / `uAnsiStr.StrLen`                                  | and BOUND it -- `lstrcatA` walks to the NUL and keeps writing                                                                                            |
| `GetFileSize`                                         | `utils_file.sFileSize`                                                    | NOT bare `FileSeek`: seeking MOVES the pointer, and callers depend on it not moving                                                                      |
| `SetFilePointer`                                      | `SysUtils.FileSeek(..., fsFromBeginning)`                                 |                                                                                                                                                          |
| `ReadFile` / `WriteFile` / `CloseHandle`              | `utils_file.sReadFile` / `sWriteFile` / `SysUtils.FileClose`              | the wrappers are already on the RTL                                                                                                                      |
| `InitializeCriticalSection` / `DeleteCriticalSection` | `InitCriticalSection` / `DoneCriticalSection`                             | the RTL's names for the same record, on every platform. Enter/Leave already are                                                                          |
| `WaitForSingleObject` + `CloseHandle` on a thread     | `WaitForThreadTerminate` + `CloseThread`                                  | `tCreateThread` is `BeginThread`, so it holds a `TThreadID`. Off Windows the TIMEOUT IS IGNORED -- say so at the site                                    |
| `SetThreadPriority`                                   | `ThreadSetPriority(h, -15..15)`                                           | advisory off Windows; it usually needs a real-time policy                                                                                                |
| `InterlockedIncrement`                                | `System.InterLockedIncrement`                                             | same intrinsic                                                                                                                                           |
| `Sleep`                                               | `SysUtils.Sleep`                                                          | already there once `Windows` goes                                                                                                                        |
| `DWORD`, `WPARAM`, `HWND`, `SW_*`, `IDYES`/`IDNO`     | `LCLType`                                                                 | on Windows these ARE the `Windows` declarations, so no signature moves                                                                                   |
| `MAXLONG`                                             | `System.MaxLongint`                                                       |                                                                                                                                                          |
| `socket`/`sendto`/`setsockopt`/`inet_addr`            | Indy: `TIdSocketHandle`, `SendBuffer`, `SetSockOpt`, `UpdateBindingLocal` | see `uIcomNetworkTransport` -- and read its bench entry first                                                                                            |
| genuinely Windows                                     | `{$IFDEF WINDOWS}` **and the uses entry with it**                         | a unit whose CODE is gated but whose USES CLAUSE is not can never compile elsewhere                                                                      |

## What is left

`CALLS` needs work, `TYPES` is usually a one-line swap to `LCLType`, `DEAD` means
the scan found nothing (verify with the compiler -- see step 3).

| Kind      | Unit                             | Calls still referenced                                                                                                                                                                                                                                                                                                 | Types still referenced                                                                                    |
| --------- | -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| CALLS     | `bench_callsign.lpr`             | `QueryPerformance`                                                                                                                                                                                                                                                                                                     | `BOOL`                                                                                                    |
| CALLS     | `DLPortIO.pas`                   | `GetLastError` `lstrcat` `LoadLibrary` `GetProcAddress` `FreeLibrary`                                                                                                                                                                                                                                                  | `DWORD` `THandle` `MAX_PATH` `BOOL`                                                                       |
| ~~CALLS~~ | ~~`fcontest.pas`~~               | ~~`lstrcat`~~                                                                                                                                                                                                                                                                                                          | ~~`BOOL`~~                                                                                                |
| CALLS     | `GetWinVersionInfo.pas`          | `GetProcAddress` `GetModuleHandle` `GetSystemMetrics`                                                                                                                                                                                                                                                                  | `DWORD` `BOOL`                                                                                            |
| ~~CALLS~~ | ~~`LogCfg.pas`~~                 | ~~`GetTickCount` `lstrcat` `wsprintf`~~                                                                                                                                                                                                                                                                                | ~~`BOOL` `INVALID_HANDLE_VALUE`~~                                                                         |
| ~~CALLS~~ | ~~`logddx.pas`~~                 | ~~`Sleep`~~                                                                                                                                                                                                                                                                                                            | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`logdump.lpr`~~                | ~~`CreateFile` `WriteFile` `CloseHandle`~~                                                                                                                                                                                                                                                                             | ~~`DWORD` `THandle` `BOOL` `INVALID_HANDLE_VALUE`~~                                                       |
| ~~CALLS~~ | ~~`logdupe.pas`~~                | ~~`wsprintf` `CloseHandle`~~                                                                                                                                                                                                                                                                                           | ~~`THandle` `BOOL` `MAXWORD` `MAXLONG`~~                                                                  |
| CALLS     | `logdvp.pas`                     | `GetLastError` `Sleep` `lstrlen` `CreateFile` `ReadFile` `CloseHandle` `WaitForSingleObject` `timeSetEvent` `sndPlaySound`                                                                                                                                                                                             | `HANDLE` `THandle` `BOOL` `INVALID_HANDLE_VALUE`                                                          |
| ~~CALLS~~ | ~~`logedit.pas`~~                | ~~`wsprintf`~~                                                                                                                                                                                                                                                                                                         | ~~`BOOL` `SW_`~~                                                                                          |
| ~~CALLS~~ | ~~`logk1ea.pas`~~                | ~~`Sleep` `CloseHandle` `WaitForSingleObject` `SetThreadPriority` `timeBeginPeriod` `timeSetEvent`~~                                                                                                                                                                                                                   | ~~`DWORD` `THandle` `BOOL` `INVALID_HANDLE_VALUE`~~                                                       |
| ~~CALLS~~ | ~~`logstuff.pas`~~               | ~~`GetTickCount`~~                                                                                                                                                                                                                                                                                                     | ~~`BOOL` `MAXWORD`~~                                                                                      |
| ~~CALLS~~ | ~~`logsubs1.pas`~~               | ~~`Sleep`~~                                                                                                                                                                                                                                                                                                            | ~~`BOOL`~~                                                                                                |
| CALLS     | `logsubs2.pas`                   | `GetTickCount` `Sleep` `wsprintf` `CloseHandle` `WSA`                                                                                                                                                                                                                                                                  | `DWORD` `HANDLE` `THandle` `BOOL` `SW_` `IDNO` `SYSTEMTIME`                                               |
| CALLS     | `logwind.pas`                    | `GetTickCount` `wsprintf` `ReadFile` `CloseHandle` `SystemTimeToTz` `GetSystemTime`                                                                                                                                                                                                                                    | `THandle` `BOOL` `SW_` `SYSTEMTIME`                                                                       |
| CALLS     | `MainUnit.pas`                   | `GetTickCount` `GetLastError` `Sleep` `lstrcat` `wsprintf` `CloseHandle` `FindFirstFile` `SetEvent` `SetThreadPriority` `LoadLibrary` `GetProcAddress` `FreeLibrary` `ShowWindow` `MoveWindow` `SendMessage` `GetKeyState` `SetFocus` `GetSystemMetrics` `socket` `sendto` `GetSystemTime` `sndPlaySound` `MessageBox` | `DWORD` `WPARAM` `HANDLE` `THandle` `BOOL` `SW_` `VK_` `IDYES` `IDNO` `INVALID_HANDLE_VALUE` `SYSTEMTIME` |
| ~~CALLS~~ | ~~`tr4w_radio_bench.lpr`~~       | ~~`GetTickCount` `Sleep`~~                                                                                                                                                                                                                                                                                             | ~~`DWORD` `BOOL`~~                                                                                        |
| CALLS     | `tr4wserverUnit.pas`             | `Sleep` `SendMessage` `socket` `sendto`                                                                                                                                                                                                                                                                                | `DWORD` `HANDLE` `THandle` `BOOL` `IDYES` `IDNO` `INVALID_HANDLE_VALUE` `SYSTEMTIME`                      |
| ~~CALLS~~ | ~~`uAppInputHooks.pas`~~         | ~~`GetTickCount`~~                                                                                                                                                                                                                                                                                                     | ~~`HANDLE` `BOOL` `VK_`~~                                                                                 |
| ~~CALLS~~ | ~~`uBandmap.pas`~~               | ~~`GetTickCount`~~                                                                                                                                                                                                                                                                                                     | ~~`HMENU` `BOOL`~~                                                                                        |
| ~~CALLS~~ | ~~`uBandPlanForm.pas`~~          | ~~`GetSystemMetrics`~~                                                                                                                                                                                                                                                                                                 | ~~`HANDLE` `BOOL`~~                                                                                       |
| ~~CALLS~~ | ~~`uCabrilloHeader.pas`~~        | ~~`GetPrivateProfile`~~                                                                                                                                                                                                                                                                                                | ~~`DWORD` `BOOL`~~                                                                                        |
| CALLS     | `uCallsigns.pas`                 | `wsprintf` `CompareString`                                                                                                                                                                                                                                                                                             | `BOOL`                                                                                                    |
| ~~CALLS~~ | ~~`uCFG.pas`~~                   | ~~`lstrcat` `lstrlen` `wsprintf`~~                                                                                                                                                                                                                                                                                     | ~~`BOOL` `MAXWORD`~~                                                                                      |
| ~~CALLS~~ | ~~`uCheckLatestVersion.pas`~~    | ~~`Sleep` `wsprintf` `closesocket` `WSA`~~                                                                                                                                                                                                                                                                             | ~~`IDYES`~~                                                                                               |
| ~~CALLS~~ | ~~`uDXSpotParse.pas`~~           | ~~`lstrcpy`~~                                                                                                                                                                                                                                                                                                          | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uEditMessageForm.pas`~~       | ~~`CloseHandle` `SetFocus`~~                                                                                                                                                                                                                                                                                           | ~~`LPARAM` `HANDLE` `THandle` `BOOL` `VK_` `IDNO`~~                                                       |
| ~~CALLS~~ | ~~`uEditQSO.pas`~~               | ~~`wsprintf`~~                                                                                                                                                                                                                                                                                                         | ~~`BOOL` `MAXWORD`~~                                                                                      |
| ~~CALLS~~ | ~~`uExternalLoggerBase.pas`~~    | ~~`GetTickCount` `Sleep` `SetEvent` `socket` `sendto`~~                                                                                                                                                                                                                                                                | ~~`HANDLE` `BOOL`~~                                                                                       |
| ~~CALLS~~ | ~~`uFileView.pas`~~              | ~~`wsprintf` `LoadLibrary` `GetProcAddress` `FreeLibrary`~~                                                                                                                                                                                                                                                            | ~~`THandle` `BOOL`~~                                                                                      |
| ~~CALLS~~ | ~~`uFlexDiscovery.pas`~~         | ~~`GetTickCount`~~                                                                                                                                                                                                                                                                                                     | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uFunctionKeys.pas`~~          | ~~`GetKeyState`~~                                                                                                                                                                                                                                                                                                      | ~~`VK_`~~                                                                                                 |
| ~~CALLS~~ | ~~`uGetScores.pas`~~             | ~~`lstrlen` `CloseHandle`~~                                                                                                                                                                                                                                                                                            | ~~`HANDLE` `THandle` `SYSTEMTIME`~~                                                                       |
| CALLS     | `uGetServerLog.pas`              | `ReadFile` `CloseHandle` `SetFilePointer` `closesocket` `WSA`                                                                                                                                                                                                                                                          | `THandle` `BOOL` `INVALID_HANDLE_VALUE` `FILE_BEGIN`                                                      |
| ~~CALLS~~ | ~~`uGradient.pas`~~              | ~~`LoadLibrary` `GetProcAddress` `GetModuleHandle` `GetSysColor`~~                                                                                                                                                                                                                                                     | ~~`HDC` `BOOL`~~                                                                                          |
| ~~CALLS~~ | ~~`uHamScore.pas`~~              | ~~`CloseHandle` `CreateEvent` `SetEvent`~~                                                                                                                                                                                                                                                                             | ~~`DWORD` `HANDLE` `THandle` `BOOL`~~                                                                     |
| ~~CALLS~~ | ~~`uHistory.pas`~~               | ~~`wsprintf` `CreateFile` `CloseHandle` `SendMessage`~~                                                                                                                                                                                                                                                                | ~~`THandle` `BOOL` `INVALID_HANDLE_VALUE`~~                                                               |
| ~~CALLS~~ | ~~`uIcomNetworkDiscovery.pas`~~  | ~~`GetTickCount`~~                                                                                                                                                                                                                                                                                                     | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uIntercom.pas`~~              | ~~`CreateFile` `CloseHandle` `SetFilePointer`~~                                                                                                                                                                                                                                                                        | ~~`DWORD` `THandle` `BOOL` `INVALID_HANDLE_VALUE`~~                                                       |
| ~~CALLS~~ | ~~`uIO.pas`~~                    | ~~`LoadLibrary` `GetProcAddress` `FreeLibrary`~~                                                                                                                                                                                                                                                                       | ~~`DWORD` `THandle` `BOOL`~~                                                                              |
| ~~CALLS~~ | ~~`uK4Discovery.pas`~~           | ~~`GetTickCount`~~                                                                                                                                                                                                                                                                                                     | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uMMTTYForm.pas`~~             | ~~`MoveWindow` `SendMessage`~~                                                                                                                                                                                                                                                                                         | ~~`HANDLE` `VK_`~~                                                                                        |
| CALLS     | `uNet.pas`                       | `GetTickCount` `Sleep` `wsprintf` `CreateFile` `WaitForSingleObject` `SetEvent` `SendMessage` `sendto` `GetCurrentThreadId`                                                                                                                                                                                            | `BOOL` `INVALID_HANDLE_VALUE`                                                                             |
| ~~CALLS~~ | ~~`uPanelUpdate.pas`~~           | ~~`IsWindow` `IsChild`~~                                                                                                                                                                                                                                                                                               | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uPrefsForm.pas`~~             | ~~`SetFocus`~~                                                                                                                                                                                                                                                                                                         | ~~`BOOL` `VK_`~~                                                                                          |
| ~~CALLS~~ | ~~`uProcessCommand.pas`~~        | ~~`sendto` `WinExec`~~                                                                                                                                                                                                                                                                                                 | ~~`BOOL`~~                                                                                                |
| CALLS     | `uProgramMain.pas`               | `GetLastError` `CreateEvent`                                                                                                                                                                                                                                                                                           | `BOOL` `SYSTEMTIME`                                                                                       |
| ~~CALLS~~ | ~~`uQTCS.pas`~~                  | ~~`Sleep` `ReadFile`~~                                                                                                                                                                                                                                                                                                 | ~~`BOOL` `IDNO`~~                                                                                         |
| ~~CALLS~~ | ~~`uRadioConfigApply.pas`~~      | ~~`GetTickCount` `GetPrivateProfile`~~                                                                                                                                                                                                                                                                                 | ~~`BOOL` `MAXWORD`~~                                                                                      |
| ~~CALLS~~ | ~~`uRadioPolling.pas`~~          | ~~`GetTickCount` `Sleep`~~                                                                                                                                                                                                                                                                                             | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uRadioTCI.pas`~~              | ~~`sendto`~~                                                                                                                                                                                                                                                                                                           | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uSendKeyboardForm.pas`~~      | ~~`SetFocus`~~                                                                                                                                                                                                                                                                                                         | ~~`HANDLE` `BOOL` `VK_`~~                                                                                 |
| ~~CALLS~~ | ~~`uServerLogForm.pas`~~         | ~~`GetLastError` `CreateFile` `CloseHandle`~~                                                                                                                                                                                                                                                                          | ~~`HANDLE` `BOOL` `INVALID_HANDLE_VALUE`~~                                                                |
| ~~CALLS~~ | ~~`uSimProcess.pas`~~            | ~~`GetLastError` `WriteFile` `CloseHandle` `WaitForSingleObject`~~                                                                                                                                                                                                                                                     | ~~`DWORD` `HANDLE` `THandle` `BOOL`~~                                                                     |
| ~~CALLS~~ | ~~`uStations.pas`~~              | ~~`wsprintf`~~                                                                                                                                                                                                                                                                                                         | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uSynTime.pas`~~               | ~~`Sleep` `GetSystemTime`~~                                                                                                                                                                                                                                                                                            | ~~`SYSTEMTIME` `FILETIME`~~                                                                               |
| ~~CALLS~~ | ~~`uTCIServer.pas`~~             | ~~`GetTickCount` `SetEvent`~~                                                                                                                                                                                                                                                                                          | ~~`HANDLE` `BOOL`~~                                                                                       |
| CALLS     | `uTelnet.pas`                    | `wsprintf` `CreateFile` `CloseHandle` `WaitForSingleObject` `socket` `WSA` `sendto`                                                                                                                                                                                                                                    | `DWORD` `HANDLE` `THandle` `BOOL` `INVALID_HANDLE_VALUE`                                                  |
| CALLS     | `uTestCWByCATTimer.pas`          | `GetTickCount` `Sleep`                                                                                                                                                                                                                                                                                                 | `HANDLE` `BOOL`                                                                                           |
| ~~CALLS~~ | ~~`uTestFormatTranslation.pas`~~ | ~~`wsprintf`~~                                                                                                                                                                                                                                                                                                         | --                                                                                                        |
| ~~CALLS~~ | ~~`uTestLogRepository.pas`~~     | ~~`DeleteFile`~~                                                                                                                                                                                                                                                                                                       | ~~`BOOL` `MAXWORD`~~                                                                                      |
| CALLS     | `uTestMain.pas`                  | `Sleep`                                                                                                                                                                                                                                                                                                                | `BOOL`                                                                                                    |
| CALLS     | `uTestRadioConfigStore.pas`      | `DeleteFile`                                                                                                                                                                                                                                                                                                           | `BOOL`                                                                                                    |
| ~~CALLS~~ | ~~`uTestTCIServer.pas`~~         | ~~`GetTickCount` `Sleep`~~                                                                                                                                                                                                                                                                                             | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`uTestUtilsFile.pas`~~         | ~~`CreateFile` `ReadFile` `CloseHandle` `DeleteFile`~~                                                                                                                                                                                                                                                                 | ~~`DWORD` `THandle` `MAX_PATH` `INVALID_HANDLE_VALUE`~~                                                   |
| ~~CALLS~~ | ~~`uTestWebSocketLoopback.pas`~~ | ~~`GetTickCount` `Sleep`~~                                                                                                                                                                                                                                                                                             | ~~`BOOL`~~                                                                                                |
| ~~CALLS~~ | ~~`utils_net.pas`~~              | ~~`socket` `closesocket` `inet_addr` `htons` `WSA`~~                                                                                                                                                                                                                                                                   | ~~`DWORD` `BOOL`~~                                                                                        |
| ~~CALLS~~ | ~~`uWinManager.pas`~~            | ~~`ShowWindow`~~                                                                                                                                                                                                                                                                                                       | --                                                                                                        |
| ~~CALLS~~ | ~~`uWinManagerForm.pas`~~        | ~~`ShowWindow` `SetFocus`~~                                                                                                                                                                                                                                                                                            | ~~`HANDLE` `BOOL`~~                                                                                       |
| DEAD      | `tr4w.lpr`                       | --                                                                                                                                                                                                                                                                                                                     | --                                                                                                        |
| ~~DEAD~~  | ~~`tr4w_consts_esp.pas`~~        | --                                                                                                                                                                                                                                                                                                                     | --                                                                                                        |
| ~~TYPES~~ | ~~`postunit.pas`~~               | --                                                                                                                                                                                                                                                                                                                     | ~~`THandle` `BOOL` `IDYES` `MAXWORD`~~                                                                    |
| ~~TYPES~~ | ~~`tr4w_status_trace.lpr`~~      | --                                                                                                                                                                                                                                                                                                                     | ~~`BOOL`~~                                                                                                |
| TYPES     | `tr4wserver.lpr`                 | --                                                                                                                                                                                                                                                                                                                     | `BOOL` `IDNO`                                                                                             |
| ~~TYPES~~ | ~~`uCAT.pas`~~                   | --                                                                                                                                                                                                                                                                                                                     | ~~`BOOL` `INVALID_HANDLE_VALUE`~~                                                                         |
| ~~TYPES~~ | ~~`uEmbeddedTranslations.pas`~~  | --                                                                                                                                                                                                                                                                                                                     | ~~`LPARAM` `BOOL`~~                                                                                       |
| ~~TYPES~~ | ~~`uLogCompareForm.pas`~~        | --                                                                                                                                                                                                                                                                                                                     | ~~`LPARAM` `HANDLE` `BOOL`~~                                                                              |
| ~~TYPES~~ | ~~`uLPTForm.pas`~~               | --                                                                                                                                                                                                                                                                                                                     | ~~`HANDLE` `INVALID_HANDLE_VALUE`~~                                                                       |
| ~~TYPES~~ | ~~`uNewContest.pas`~~            | --                                                                                                                                                                                                                                                                                                                     | ~~`BOOL` `IDNO`~~                                                                                         |
| ~~TYPES~~ | ~~`uRadioEditForm.pas`~~         | --                                                                                                                                                                                                                                                                                                                     | ~~`HANDLE` `BOOL`~~                                                                                       |
| ~~TYPES~~ | ~~`uTestFreqTimeFormat.pas`~~    | --                                                                                                                                                                                                                                                                                                                     | ~~`SYSTEMTIME`~~                                                                                          |
| ~~TYPES~~ | ~~`uWin32Compat.pas`~~           | --                                                                                                                                                                                                                                                                                                                     | ~~`DWORD` `HANDLE` `THandle` `BOOL`~~                                                                     |

## Known to stay, with the reason recorded

Checked 2026-09-08 against NY4I's [AGENT] notes and a reference pass over
**cqrlog** and **trlinux** (both under `C:/projects/`), which he named as
multi-platform FPC/Lazarus siblings. **Three entries that used to be in this
table are gone, because the reasons were wrong** -- see the section after it.

| Unit                    | Why it stays                                                                                                                                                                                                                                                                                                    | Status                                                                                    |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `uWinKey`               | `QueryPerformanceCounter`. There is no RTL equivalent, and `GetTickCount64`'s 1 ms floor would blur the 15/46/122 ms gaps the trace exists to measure. Already gated, with the fallback's cost written down                                                                                                     | resolved by `uHPTimer` when it lands; nothing to do here first                            |
| `BeepUnit`              | the `Device\Beep` IOCTL. **The SIDETONE half is deleted (NY4I, 2026-09-08) -- no program-generated tone at all.** What keeps the unit alive is the WARNING BEEPS, which share the same unreliable path                                                                                                          | whether those go too is NY4I's call, in `BENCH_QUEUE.md`; if they do, the unit goes       |
| `uCallsigns`            | `CompareStringA`. One of three drifted copies, and the tests come before the repoint                                                                                                                                                                                                                            | `uStringCompare.pas` exists untracked; needs its test suite                               |
| `uIO`                   | inpout32.dll, for LPT keying. Gated -- but **whether the FEATURE stays is an open decision, not a technical one**, and I recorded it as settled once. Linux CAN reach a parallel port (`ports` + `fpioperm`, needs root; or ppdev, which does not), and the driver has an x64 build under a different file name | NY4I's call; in `BENCH_QUEUE.md`. Nothing blocks on it                                    |
| `uYCCCSO2R`             | overlapped HID I/O through SetupAPI -- genuine Windows device access                                                                                                                                                                                                                                            | its own question                                                                          |
| `uTestCWByCATTimer`     | pumps a real `WM_TIMER` loop so the LCL `TTimer` under test fires. Off Windows a timer is the widget set's own source, so `Application.ProcessMessages` is a DIFFERENT mechanism, not another spelling                                                                                                          | gate with an `{$ELSE}`, and extract the duplicated pump first                             |
| `uHamLibDirect`         | the library file name, and `PEMachineOf`'s PE read                                                                                                                                                                                                                                                              | one constant per platform, verified ON the platform                                       |
| `uEmbeddedTranslations` | `RT_RCDATA` only, and only on Windows                                                                                                                                                                                                                                                                           | the rest is converted; see below                                                          |
| `uInputQueryForm`       | `LoadIcon` for the standard dialog icons                                                                                                                                                                                                                                                                        | replaceable by `DialogRes.DialogGlyphs`, which also themes and HiDPI-scales; not yet done |
| `uPanelUpdate`          | --                                                                                                                                                                                                                                                                                                              | **RESOLVED: it was a bug, not a dependency**                                              |
| `logwind` (timezone)    | --                                                                                                                                                                                                                                                                                                              | **RESOLVED: no timezone database was ever involved**                                      |
| `tr4wserver.lpr`        | --                                                                                                                                                                                                                                                                                                              | **RESOLVED: the constraint was stale**                                                    |

## HAMLIB IS A BINDING. NOT `rigctld`. (NY4I, 2026-09-08)

**Do not re-propose the subprocess design.** The reference pass found that
**both** sibling projects avoid linking hamlib entirely: cqrlog spawns
`rigctld` and speaks its text protocol over TCP (`src/uRigControl.pas:190-197`,
`:298-322`), and trlinux does the same through `src/rigctld.pas`. Neither has a
single `external` hamlib declaration anywhere.

**That is explicitly NOT the direction here.** NY4I: *"in this case, ignore what
those programs do. I specifically do not want to use rigctld and prefer to bind
the library. I will keep looking for a mac and linux app that does it that
way."*

**DONE, 2026-09-08: the name is per-platform.** NY4I settled the deployment
model -- *"the library is usually available to the program as an .so file that
has to be in the program directory when we install it"* -- so these are the
files TR4W'S OWN INSTALLER ships beside the binary, not guesses about what a
distro provides. `HAMLIB_DLL` is `HAMLIB_LIB`; the packaging must match the
names exactly.

**And the loading already works the same on all three platforms**, which
corrects a caution written earlier the same day. `LocateHamLib` resolves the
name to an ABSOLUTE path -- program directory first -- and `LoadLibrary` is
given that path. `dlopen()` with a slash in the name skips the loader's search
list and opens exactly that file, so "beside the binary" behaves on Linux and
macOS as it does on Windows. The `PATH` fallback is the branch that does not
translate, and it is only a fallback.

What is still owed, and it is **packaging rather than code**:

- **An `$ORIGIN` rpath on the executable at link time.** Hamlib has its own
  dependencies (libusb and friends), and a dlopen'd library's dependencies are
  resolved by the loader's normal search, which does NOT include the directory
  the library was loaded from. NY4I: *"whatever the best and typical way it is
  done on linux. no need to reinvent the wheel"* -- and `$ORIGIN` is that
  idiom. Note it wants `DT_RPATH` rather than `DT_RUNPATH` to cover a dlopen'd
  library's dependencies, which on modern binutils means passing
  `--disable-new-dtags`. Verify with `ldd` on the shipped tree.
- `PEMachineOf` becomes Windows-only behind a neutral name. It already fails
  SAFE off Windows -- an ELF or Mach-O file misses the PE signature, so it
  returns 0 ("unknown") and lets the load report the real error -- so a second
  file-format parser would buy nothing but a better message.

## What the sweep corrected about ITSELF

Three reasons in this document were wrong, and **two of them were written on
2026-09-08, the same day they were disproved**. They are recorded because the
failure mode is the point, not the units.

**`logwind` did not need a timezone database.** This file said it did. The code
zeroes `StandardDate` and `DaylightDate` and sets only `TZ.Bias`, which is
Win32's documented no-DST case -- so `SystemTimeToTzSpecificLocalTime` was
computing `local = UTC - Bias` and nothing else. It could not have done more:
the only input is `CTY.ctyTable[Country].UTCOffset`, one fixed `Smallint` per
DXCC entity, read from CTY.DAT as hours times 60. There is no zone name and no
rule set anywhere in the data. It is two lines of `IncMinute` now. **PascalTZ
would be a FEATURE, not a port fix** -- it needs unpacked IANA tzdata and a zone
NAME per location, and TR4W has a country index.

**`tr4wserver` could use LCLType all along.** This file said it could not,
because the server build excludes the LCL. That WAS true, and stopped being true
on 2026-09-06: `build/Get-SearchPaths.ps1:153-156` adds the LCL units for all
three targets, its own header says *"Server has it too since it became an LCL
application"*, and the only `-ne 'Server'` exclusion left guards SQLite. The
program file already used `Interfaces`, `Forms` and `Dialogs`.

**The lesson is not "check twice".** That claim WAS measured -- the import was
removed and the compiler read -- but measured against a build script that had
changed two days earlier, and then written down as a standing constraint. **A
measurement dates as fast as the thing it measured.** Record what you measured
it against, and prefer a claim the reader can re-run over one they must trust.

**`uEmbeddedTranslations` was not an open decision.** This file called it one --
"where do translations live off Windows". FPC's **System unit** declares
`EnumResourceNames`, `FindResource`, `LoadResource`, `SizeofResource`,
`LockResource` and `Is_IntResource` for every target (`rtl/inc/resh.inc`), with
the implementation chosen by `fpintres.pp` and ELF and Mach-O readers shipped.
The embedded design ports as it is; only the `A` suffixes had to go. The one
genuinely unverified thing is whether `Make-LanguageRes.ps1`'s output survives
the ELF/Mach-O resource pipeline -- and if it does not, that unit already
documents a loose-file fallback, so it degrades to the file design rather than
to English.

**And `uPanelUpdate` was a BUG, not a dependency.** `IsChild` and `IsWindow`
were testing `Target`, which stopped being a window handle on 2026-09-06 -- it
is a panel slot, 1 or 2, or 0 for an element. So `not IsWindow(Target)` was
ALWAYS TRUE, and `ForgetPanel(1)` cleared panel 2's entries and every element
entry along with its own. Deleting the calls fixed it. Porting them would have
preserved it.

## Audio: THE SIDETONE QUESTION WAS ANSWERED BY DELETING IT (2026-09-08)

**NY4I closed this rather than resolving it.** *"We do not need a sidetone
generated by the program at all. It is notoriously unreliable on windows and
the sidetone comes from the radio."* So none of the work costed below gets
written: the program's generated CW sidetone was two `ntBeep` calls in
`logk1ea`, and they are deleted. CW element timing is unaffected -- `ntBeep`
fired a `DeviceIoControl` and returned, so `tCWSleep` was always the thing
timing an element.

**`BeepUnit` SURVIVES, and only just.** Its remaining callers are the WARNING
BEEPS -- `tDoABeep`, `QuickBeep`, tree's note player -- which reach the same
`\Device\Beep` path through `SpeakerBeep`, and therefore have the same
reliability problem NY4I just described. **Whether those go too is in
`BENCH_QUEUE.md` and is his call**; if they do, this unit and its
`QueryDosDevice`/`DefineDosDevice`/`DeviceIoControl` block leave the tree
entirely and this section closes.

Two other things named "sidetone" are NOT this and were deliberately left: the
WinKeyer's own hardware sidetone (a setting we send to the keyer, neither
unreliable nor Windows-bound), and `Config.CWTone`, which is no longer a tone
at all -- it is threaded through `AddStringToBuffer(Msg, Tone)` as a dead
parameter and tested against 0 as a CW-enabled flag.

**The costing below is kept as the record of what was avoided.**

`BeepUnit` was the one entry in the table with nothing to convert to.

- FPC's Unix `Beep` is `Write(#7); Flush(Output)` (`rtl/unix/sysutils.pp`) --
  no frequency, no duration, and nothing at all in a GUI process.
- trlinux DOES solve it, and its INTERFACE is already the shape TR4W needs: a
  state machine over `LSound(hz)` / `LNoSound` (`beep.pas:29-89`), which maps
  one-for-one onto `SpeakerBeep` / `NoSound`. Underneath it offers a console
  `KDMKTONE` ioctl -- the same PC-speaker dead end as the Windows path -- and a
  synthesised sine written to ALSA from a dedicated thread
  (`linuxsound.pas:190-247`). **Take the architecture, not the bindings**: that
  is `{$linklib asound}` with about thirty hand-written externals, Linux only.
- cqrlog contributes nothing: audio is a user-editable shell script calling
  `mpg123`. Fine for a voice keyer with half a second of tolerance, useless for
  a sidetone that must start and stop with the element.

~~**Two decisions for NY4I:** whether a sidetone is required on Linux/macOS at
first release, or whether shipping with the WinKeyer's own hardware sidetone is
acceptable; and which audio dependency, given it must also carry `logdvp`'s WAV
playback -- evaluate them together, or you buy two.~~

**ANSWERED 2026-09-08, and the first question dissolved the second.** No
sidetone is required anywhere, so the only audio TR4W still owes off Windows is
`logdvp`'s WAV playback for the voice keyer -- one dependency, with half a
second of tolerance instead of element-accurate timing. That is a materially
easier problem than the one this section was sizing, and it is the only one
left.

## Timing: EpikTimer, re-checked

NY4I's [AGENT] note asked about `C:/projects/epikTimer`. The assessment in
`PLATFORM_CLOCK_ABSTRACTION.md` holds, and its two load-bearing claims were
re-verified: `epiktimer.pas:425`'s "precision delay" is a bare `Sleep`, so
adopting it for `tCWSleep` would give the keyer the same fallback it already
takes when `timeSetEvent` fails; and its conditionals are Windows, Linux and
FreeBSD with **no Darwin**, with the hardware timebase gated on `{$IFDEF
CPUI386}` and RDTSC, which Apple Silicon does not have. Right project, wrong
half: keep it in view as a CLOCK, never as a DELAY.

trlinux has nothing to offer here either -- `keyerwin.pas` carries no timing
instrumentation at all, and its finest primitive is a 500 microsecond
`fpNanoSleep` polling loop, coarser than what TR4W has on Windows today.
**TR4W's `uSerialPort` is already ahead of trlinux's raw termios layer.**

## General cross-platform recommendations

From the reference pass, filtered to what TR4W does not already do.

1. **Namespace platform-dependent keys in `tr4w.json` BEFORE the first
   non-Windows release.** cqrlog's `PlatformKey` (`src/dUtils.pas:3455-3470`)
   suffixes every path- or device-bearing key -- `RigCtldPath_mac`, `_flatpak`,
   `_snap` -- because a sandboxed install and a native one share one `$HOME`,
   and therefore one config, and each clobbers the other. TR4W has that exposure
   the day it runs on two platforms: every COM port, keyer port and rotator
   address. Changing the key shape afterwards is a migration.
2. **Keep platform conditionals inside named helpers, never at call sites.**
   `uAppPaths` already does this well. The metric to watch is the `{$IFDEF
   WINDOWS}` count, and each unit in the table above should end at zero or one.
3. **Detect the environment by evidence, not by a define** -- cqrlog tests
   `FileExists('/.flatpak-info')` and `GetEnvironmentVariable('SNAP')`. A
   compile-time define cannot answer "am I in a sandbox", because the same
   binary runs both in and out of one.
4. **Serial enumeration off Windows is a `/dev` glob, and two details are easy
   to get wrong**: macOS wants `/dev/cu.*` and NOT `/dev/tty.*` (the tty variant
   blocks on carrier detect), and `/dev/serial/by-id/*` on Linux is stable
   across plug order -- which matters to an SO2R operator with two USB adapters.
5. **Decide about Linux serial lockfiles deliberately.** FPC's `serial` unit
   does not manage the `/var/lock` convention, so two TR4W instances -- or TR4W
   and another program -- can open the same port with nothing said.
6. **Keep a per-platform compiler-bug register.** cqrlog documents FPC 3.2.2 on
   aarch64 with `-O2` miscompiling `TParam.AsFloat` to zero, and routes around
   it. A silent wrong VALUE on one platform is the worst class of port defect,
   and TR4W's frequency and score arithmetic is exactly that shape. **Run the
   golden corpus on Apple Silicon early, at the optimisation level you intend to
   ship** -- nothing else would surface it.
7. **Two useful negatives.** cqrlog has no translation infrastructure at all --
   one `resourcestring` in the whole tree -- so there is nothing to learn from it
   on i18n, where TR4W is far ahead. And cqrlog is Unix-ONLY, not
   three-platform: it links `cthreads` unconditionally and its `{$IFDEF
   WINDOWS}` count is one. Read it as a Linux-and-macOS reference, which is the
   half TR4W lacks, and not as a model for one tree across three platforms.
