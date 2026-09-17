Question to Perplexity about Mac port of TR4W-D12.

I have an app (TR4W) recently ported from Delphi 7 to Delphi 12. This app is currently using Win32 for all UX items (no VCL). I want to start using the framework but I also want to make this cross-platform (Mac and Linux). I presume I have to remove every single WIn32 API call and replace it all with FireMonkey?

Answer:

No—you do **not** have to remove every Win32 API call and blindly replace everything with FireMonkey. If you want TR4W to become cross-platform, the key step is to isolate platform-specific code and move the UI onto a cross-platform framework; in Delphi, that usually means FMX for the UI because VCL is Windows-only, while FMX is the framework Embarcadero positions for Windows and macOS, and RAD Studio’s supported target list shows FMX across Windows and macOS while VCL remains Windows-only. [embarcadero](https://www.embarcadero.com/products/delphi/features/windows)

## Core point

Your current app is effectively a custom Windows-native GUI, since you said it uses raw Win32 for all UX instead of VCL. That means the real problem is not “Win32 vs FireMonkey” at the API-call level; it is “Windows-specific architecture vs portable architecture.” [learndelphi](https://learndelphi.org/easy-native-windows-development-using-traditional-bindings/)

You should expect to replace most **UI-layer** Win32 usage, because message loops, HWND-based controls, GDI painting, dialogs, menus, accelerators, and common controls are Windows concepts. But you do **not** need to purge every single API call in one pass, because non-UI code can often stay as-is if you wrap Windows-specific parts behind services or conditional compilation. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/Athens/en/Supported_Target_Platforms)

## What must change

Anything tied directly to Windows widgets or window management will need a new abstraction or a rewrite in FMX: window creation, child controls, owner-draw logic, keyboard routing, clipboard, drag/drop, timers, focus handling, and custom painting. FMX is designed as the cross-platform application framework for Delphi and C++Builder, targeting Windows and macOS among others, so that is the natural place for portable UI work. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/Athens/en/Supported_Target_Platforms)

Also, if TR4W depends on Win32 messages as an internal architecture pattern, that will need redesign. FMX has its own control tree, event model, styling system, and rendering model, so trying to mechanically map `CreateWindowEx` or `WM_*` handling one-for-one usually produces bad results. [youtube](https://www.youtube.com/watch?v=j9XxM7W94p4)

## What can stay

Your contest logic, scoring, parsing, logging, radio-state machines, networking, file formats, CAT/CW abstractions, and most business rules should be kept independent of the UI and reused. The RAD Studio platform support page also shows Delphi supports Linux as a target, but that is not the same as “FMX desktop Linux UI” in the same first-party way as Windows/macOS, so keeping core logic portable matters even more if Linux is a longer-term goal. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/Athens/en/Supported_Target_Platforms)

A good split is:
- Core layer: pure Delphi units, no UI, no Win32.
- Platform services: serial, sound, file associations, shell integration, low-level device access.
- UI layer: FMX now, possibly a different Linux strategy later if needed. [embarcadero](https://www.embarcadero.com/products/delphi/features/windows)

## Linux caution

For your stated goal of Mac and Linux, be careful with the assumption that “FMX solves all three desktop platforms cleanly.” Embarcadero’s current supported-platform documentation lists Linux as a Delphi target, but FMX is primarily positioned on Embarcadero pages as Windows/macOS/iOS/Android, so Linux desktop UI needs extra scrutiny before you commit the whole product architecture to FMX alone. [embarcadero](https://www.embarcadero.com/products/delphi/features/windows)

That means your safest strategy is:
- Use FMX for Windows + macOS desktop UI.
- Keep the app core UI-agnostic.
- Treat Linux UI as a separate decision point rather than assuming your FMX forms will just carry over unchanged. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/Athens/en/Supported_Target_Platforms)

## Recommended migration path

Do this incrementally instead of a rewrite.

1. Extract a **core** TR4W engine with no Win32 references at all.
2. Define interfaces for platform services, such as serial/CAT, CW keying, audio alerts, clipboard, shell, and timers.
3. Build a thin FMX shell for one workflow first, such as the main log window plus bandmap or entry panel.
4. Keep the existing Win32 front end alive while you port screen-by-screen.
5. Only after the core/UI split is solid, decide how you want to handle Linux desktop delivery. [embarcadero](https://www.embarcadero.com/products/delphi/features/windows)

For a heavily keyboard-driven app like TR4W, I would be especially cautious about FMX usability before full commitment. Contest software lives or dies by focus behavior, low-latency input, text rendering density, multi-window ergonomics, and predictable keyboard shortcuts—areas where a Win32 custom UI may feel sharper than a straight FMX port unless you design carefully. FMX does support platform/native control options in some scenarios, but its normal model is still an FMX-managed UI rather than classic Win32 controls. [blogs.embarcadero](https://blogs.embarcadero.com/apply-the-robust-native-controls-of-firemonkey-on-delphi-and-c-with-the-fmx-nativecontrols-sample/)

My practical answer is: **replace the UI architecture, not every API call at once**. If you want, I can sketch a concrete TR4W-oriented architecture showing which modules should remain pure Delphi, which Win32 calls should be wrapped, and which screens are safest to port to FMX first.


Yes. A good TR4W migration target is a **ports-and-adapters** structure: keep the contest engine pure Delphi, isolate hardware/OS integration behind interfaces, and let FMX be just one front end. MVVM is a reasonable pattern for the UI layer because it separates view code from application logic, and Delphi supports conditional compilation plus FMX platform services for platform-specific integrations where needed. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/en/Conditional_compilation_(Delphi))

## Proposed layout

Here is a practical package structure for a Delphi codebase that wants Windows now and macOS later, while keeping Linux open as a separate UI decision. FMX provides the cross-platform UI layer, and Delphi’s conditional compilation plus platform services give you clean seams for platform-specific behavior. [docwiki.embarcadero](https://docwiki.embarcadero.com/Libraries/Sydney/en/FMX.Platform.TPlatformServices)

```text
TR4W/
  src/
    Core/
      TR4W.Core.Types.pas
      TR4W.Core.Interfaces.pas
      TR4W.Core.Events.pas
      TR4W.Core.Commands.pas
      TR4W.Core.Config.pas

    Domain/
      Contest/
        TR4W.Domain.ContestState.pas
        TR4W.Domain.QSO.pas
        TR4W.Domain.Score.pas
        TR4W.Domain.Mults.pas
        TR4W.Domain.DupeSheet.pas
        TR4W.Domain.Exchange.pas
      Radio/
        TR4W.Domain.RadioState.pas
        TR4W.Domain.BandPlan.pas
        TR4W.Domain.VFO.pas
      CW/
        TR4W.Domain.CWMessage.pas
        TR4W.Domain.FunctionKeys.pas
      Network/
        TR4W.Domain.ClusterSpot.pas
        TR4W.Domain.NodePacket.pas

    Application/
      TR4W.App.Session.pas
      TR4W.App.CommandRouter.pas
      TR4W.App.LogService.pas
      TR4W.App.RadioService.pas
      TR4W.App.BandmapService.pas
      TR4W.App.PartialCheckService.pas
      TR4W.App.ExportService.pas
      TR4W.App.SettingsService.pas

    Services/
      Abstractions/
        TR4W.Services.RadioIO.pas
        TR4W.Services.CWKeyerIO.pas
        TR4W.Services.AudioIO.pas
        TR4W.Services.Clock.pas
        TR4W.Services.Storage.pas
        TR4W.Services.Network.pas
        TR4W.Services.Windowing.pas
        TR4W.Services.Clipboard.pas
        TR4W.Services.Hotkeys.pas
      Windows/
        TR4W.Services.Windows.RadioIO.pas
        TR4W.Services.Windows.CWKeyerIO.pas
        TR4W.Services.Windows.AudioIO.pas
        TR4W.Services.Windows.Storage.pas
        TR4W.Services.Windows.Clipboard.pas
        TR4W.Services.Windows.Hotkeys.pas
      Mac/
        TR4W.Services.Mac.RadioIO.pas
        TR4W.Services.Mac.AudioIO.pas
        TR4W.Services.Mac.Storage.pas
      Linux/
        TR4W.Services.Linux.RadioIO.pas
        TR4W.Services.Linux.AudioIO.pas
        TR4W.Services.Linux.Storage.pas

    UI/
      ViewModels/
        TR4W.VM.Main.pas
        TR4W.VM.Entry.pas
        TR4W.VM.Bandmap.pas
        TR4W.VM.RadioControl.pas
        TR4W.VM.Mults.pas
        TR4W.VM.RateMeter.pas
        TR4W.VM.Messages.pas
        TR4W.VM.Settings.pas
      FMX/
        Forms/
          TR4W.UI.FMX.MainForm.pas
          TR4W.UI.FMX.EntryFrame.pas
          TR4W.UI.FMX.BandmapFrame.pas
          TR4W.UI.FMX.MultsFrame.pas
          TR4W.UI.FMX.SettingsForm.pas
        Controls/
          TR4W.UI.FMX.CallEntryControl.pas
          TR4W.UI.FMX.RateGraphControl.pas
          TR4W.UI.FMX.SpotListControl.pas
      Win32Legacy/
        TR4W.UI.Win32.MainWindow.pas
        TR4W.UI.Win32.EntryWindow.pas

    Bootstrap/
      TR4W.Bootstrap.Container.pas
      TR4W.Bootstrap.Platform.pas
      TR4W.dpr
```

## Layer roles

The **Domain** layer should know nothing about Win32, FMX, forms, threads, serial ports, or sockets directly. MVVM guidance from Embarcadero stresses decoupling the UI from business logic, which fits well here: the domain owns rules like dupe detection, multiplier state, exchange parsing, and score calculation. [blogs.embarcadero](https://blogs.embarcadero.com/learn-how-to-build-mvvm-pattern-based-app-in-20-minutes/)

The **Application** layer coordinates use cases such as “enter QSO,” “change band,” “process cluster spot,” and “send CW message.” It talks to abstractions like `IRadioIO`, `ICWKeyerIO`, and `IStorage`, not to platform APIs directly, which is the same general separation encouraged by MVVM-style Delphi architecture. [blogs.embarcadero](https://blogs.embarcadero.com/learn-how-to-build-mvvm-pattern-based-app-in-20-minutes/)

The **Services** layer is where OS and hardware specifics live. Delphi’s conditional compilation directives are built for this kind of split, and FMX platform services are the right tool for capabilities such as clipboard, dialogs, timers, cursor, and window services on supported targets. [docwiki.embarcadero](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Platform.Win.RegisterCorePlatformServices)

The **UI** layer should be thin. FMX forms render state and forward user intent to ViewModels; ViewModels expose properties, commands, and state snapshots, but should not know whether they are displayed by FMX today or something else later. [blogs.embarcadero](https://blogs.embarcadero.com/learn-how-to-build-mvvm-pattern-based-app-in-20-minutes/)

## Key interfaces

For TR4W, these interfaces are the seams that matter most because they isolate the pain points: radios, CW, keyboard behavior, storage, and host OS integration. Delphi’s conditional compilation lets you bind different implementations per target without contaminating the rest of the codebase. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/en/Conditional_compilation_(Delphi))

```pascal
type
  IRadioIO = interface
    ['{A1111111-1111-1111-1111-111111111111}']
    procedure Connect;
    procedure Disconnect;
    function GetFrequencyHz: Int64;
    procedure SetFrequencyHz(const Value: Int64);
    function GetMode: string;
    procedure SetMode(const Value: string);
    function GetPTT: Boolean;
    procedure SetPTT(const Value: Boolean);
  end;

  ICWKeyerIO = interface
    ['{A2222222-2222-2222-2222-222222222222}']
    procedure SendText(const S: string);
    procedure Stop;
    procedure SetSpeedWPM(Value: Integer);
  end;

  IHotkeyService = interface
    ['{A3333333-3333-3333-3333-333333333333}']
    procedure RegisterHotkeys;
    procedure UnregisterHotkeys;
  end;

  IClipboardService = interface
    ['{A4444444-4444-4444-4444-444444444444}']
    procedure SetText(const S: string);
    function GetText: string;
  end;

  IContestSession = interface
    ['{A5555555-5555-5555-5555-555555555555}']
    procedure EnterQSO(const Call, Exchange: string);
    function CurrentScore: Integer;
    function OperatorCall: string;
  end;
```

A useful rule is: if a unit needs `Windows`, `Messages`, `FMX.*`, `Macapi.*`, or `Posix.*`, it should usually not be in `Domain`. That dependency boundary is what keeps the port manageable. [docwiki.embarcadero](https://docwiki.embarcadero.com/Libraries/Sydney/en/FMX.Platform.TPlatformServices)

## Bootstrap example

Your bootstrap layer decides which concrete services to register at startup. Delphi’s conditional compilation is the cleanest built-in way to select Windows vs macOS code paths in one codebase. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/Athens/en/Delphi_compiler_directives)

```pascal
uses
  TR4W.Services.RadioIO,
  TR4W.Services.CWKeyerIO,
  {$IFDEF MSWINDOWS}
  TR4W.Services.Windows.RadioIO,
  TR4W.Services.Windows.CWKeyerIO,
  TR4W.Services.Windows.Hotkeys,
  {$ENDIF}
  {$IFDEF MACOS}
  TR4W.Services.Mac.RadioIO,
  TR4W.Services.Mac.AudioIO,
  {$ENDIF}
  TR4W.App.Session,
  TR4W.VM.Main;

procedure RegisterPlatformServices(Container: TContainer);
begin
  {$IFDEF MSWINDOWS}
  Container.RegisterType<IRadioIO, TWindowsRadioIO>;
  Container.RegisterType<ICWKeyerIO, TWindowsCWKeyerIO>;
  Container.RegisterType<IHotkeyService, TWindowsHotkeyService>;
  {$ENDIF}

  {$IFDEF MACOS}
  Container.RegisterType<IRadioIO, TMacRadioIO>;
  {$ENDIF}
end;
```

For FMX-native services such as clipboard, timers, dialogs, or screen services, Delphi exposes `TPlatformServices` so you can query what is available at runtime instead of hardwiring assumptions. That is especially useful when one platform lacks a service or behaves differently. [docwiki.embarcadero](https://docwiki.embarcadero.com/Libraries/Athens/en/FMX.Platform.Win.RegisterCorePlatformServices)

## TR4W-specific advice

Because TR4W is keyboard-driven and latency-sensitive, I would keep a dedicated **input subsystem** between FMX and the command router. Let the UI translate raw key events into semantic commands such as `cq-focus`, `log-qso`, `send-f1`, `toggle-split`, or `next-radio`, then handle those centrally rather than scattering key logic across forms. MVVM’s main benefit here is that your ViewModels and command router can stay stable even if the front end changes. [blogs.embarcadero](https://blogs.embarcadero.com/learn-how-to-build-mvvm-pattern-based-app-in-20-minutes/)

I would also split out these subsystems early:
- `RadioEngine`: CAT/CIV/rig state, frequency/mode/PTT abstraction.
- `ContestEngine`: exchange validation, multiplier state, score/rate logic.
- `SpotEngine`: DX cluster ingestion, filtering, dupes, bandmap projection.
- `MessageEngine`: CW memories, ESM behavior, run/S&P message selection.
- `WorkspaceState`: window layout, columns, operator preferences, fonts, colors. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/en/Conditional_compilation_(Delphi))

A simple event flow could look like this:

```text
FMX View
  -> MainViewModel
  -> CommandRouter
  -> Application Service
  -> Domain Model update
  -> Event published
  -> ViewModel refresh
  -> FMX View redraw
```

That keeps the UI reactive without making your domain depend on forms or message handlers. [blogs.embarcadero](https://blogs.embarcadero.com/learn-how-to-build-mvvm-pattern-based-app-in-20-minutes/)

## First screens to port

Do not start with every window. Port the smallest vertical slice that proves the architecture: main entry panel, QSO log grid, radio status strip, and one message/CW panel. That gives you the hard problems first—focus, keyboard routing, visible state updates, and radio integration—without forcing a full rewrite. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/en/Conditional_compilation_(Delphi))

A staged path I would use:
1. Move score/QSO/radio logic into `Domain` and `Application`.
2. Wrap all Win32-only dependencies behind service interfaces.
3. Keep the old Win32 UI running against the new core.
4. Build one FMX shell against the same core.
5. Compare ergonomics before porting bandmap, mult windows, and config dialogs. [docwiki.embarcadero](https://docwiki.embarcadero.com/RADStudio/en/Conditional_compilation_(Delphi))

Would you like a more concrete version next, such as a sample `MainViewModel` plus `CommandRouter` in Delphi code?