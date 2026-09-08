unit uHamLibDirect;
{$I tr4w.inc}


interface

uses
  (* No Windows: the library loads through DynLibs and the header probe uses
    SysUtils' FileOpen / FileSeek / FileRead. *)
  SysUtils;

const
  (* THE LIBRARY TR4W SHIPS, BESIDE THE BINARY -- one name per platform.

    NY4I, 2026-09-08: "the library is usually available to the program as an
    .so file that has to be in the program directory when we install it."

    So these are not guesses about what a distro happens to install; they are
    the file names TR4W'S OWN INSTALLER PUTS beside the executable, and the
    packaging must match them exactly. The forms below are hamlib's normal
    versioned names on each platform.

    WHY LOADING IT WORKS THE SAME EVERYWHERE, which is not obvious:
    LocateHamLib resolves this to an ABSOLUTE path (program directory first --
    see there), and LoadLibrary is given that path. dlopen() with a slash in
    the name skips the loader's search list entirely and opens exactly that
    file, so "beside the binary" behaves on Linux and macOS as it does on
    Windows. The PATH fallback further down is the branch that does NOT
    translate, and it is only a fallback.

    WHAT IS STILL OWED IS PACKAGING, NOT CODE: hamlib has its own dependencies
    (libusb and friends), and a dlopen'd library's dependencies are resolved by
    the loader's normal search, which does NOT include the directory the
    library was loaded from. The standard idiom is an $ORIGIN rpath on the
    executable at link time so a bundled set resolves beside it. That belongs
    in the Linux/macOS build and installer, not here. *)
{$IF DEFINED(WINDOWS)}
  HAMLIB_LIB = 'libhamlib-4.dll';
{$ELSEIF DEFINED(DARWIN)}
  HAMLIB_LIB = 'libhamlib.4.dylib';
{$ELSE}
  HAMLIB_LIB = 'libhamlib.so.4';
{$IFEND}

{-----------------------------------------------------------------------------
  Type Definitions
-----------------------------------------------------------------------------}

type
  // Opaque handle to a RIG structure
  PRIG = Pointer;

  // Frequency type in Hz (can hold SHF frequencies)
  freq_t = Double;

  // Short frequency type for offsets, shifts (31-bit signed)
  shortfreq_t = Integer;

  // VFO identifier
  vfo_t = Cardinal;

  // Radio mode (64-bit bitmask)
  rmode_t = Int64;

  // Passband width
  pbwidth_t = Integer;

  // PTT status
  ptt_t = Integer;

  // DCD status
  dcd_t = Integer;

  // Configuration token
  hamlib_token_t = Integer;

{-----------------------------------------------------------------------------
  Error Codes

  Functions return RIG_OK (0) on success, or negative error code on failure
-----------------------------------------------------------------------------}

const
  RIG_OK          = 0;   // No error, operation completed successfully
  RIG_EINVAL      = -1;  // Invalid parameter
  RIG_ECONF       = -2;  // Invalid configuration (serial, etc.)
  RIG_ENOMEM      = -3;  // Memory shortage
  RIG_ENIMPL      = -4;  // Function not implemented
  RIG_ETIMEOUT    = -5;  // Communication timed out
  RIG_EIO         = -6;  // IO error, including open failed
  RIG_EINTERNAL   = -7;  // Internal Hamlib error
  RIG_EPROTO      = -8;  // Protocol error
  RIG_ERJCTED     = -9;  // Command rejected by the rig
  RIG_ETRUNC      = -10; // Command performed, but arg truncated
  RIG_ENAVAIL     = -11; // Function not available
  RIG_ENTARGET    = -12; // VFO not targetable
  RIG_BUSERROR    = -13; // Error talking on the bus
  RIG_BUSBUSY     = -14; // Collision on the bus
  RIG_EARG        = -15; // NULL RIG handle or invalid pointer
  RIG_EVFO        = -16; // Invalid VFO
  RIG_EDOM        = -17; // Argument out of domain
  RIG_EDEPRECATED = -18; // Function deprecated
  RIG_ESECURITY   = -19; // Security error
  RIG_EPOWER      = -20; // Rig not powered on
  RIG_ELIMIT      = -21; // Limit exceeded
  RIG_EACCESS     = -22; // Access denied (e.g., port already in use)

{-----------------------------------------------------------------------------
  Debug Levels
-----------------------------------------------------------------------------}

type
  rig_debug_level_e = (
    RIG_DEBUG_NONE = 0,  // No debug output
    RIG_DEBUG_BUG,       // Serious bug
    RIG_DEBUG_ERR,       // Error case
    RIG_DEBUG_WARN,      // Warning
    RIG_DEBUG_VERBOSE,   // Verbose
    RIG_DEBUG_TRACE,     // Tracing
    RIG_DEBUG_CACHE      // Cache debugging
  );

{-----------------------------------------------------------------------------
  VFO Definitions
-----------------------------------------------------------------------------}

const
  // enum rig_caps_int_e selectors for rig_get_caps_int (hamlib 4.4+)
  RIG_CAPS_TARGETABLE_VFO = 0;

  // caps->targetable_vfo bits (rig.h): which operations HamLib can address to
  // a specific VFO WITHOUT physically switching the rig's front-panel selection.
  RIG_TARGETABLE_NONE = 0;
  RIG_TARGETABLE_FREQ = 1;       // (1 shl 0)

const
  RIG_VFO_NONE     = $00000000;  // VFO unknown
  RIG_VFO_A        = $00000001;  // VFO A
  RIG_VFO_B        = $00000002;  // VFO B
  RIG_VFO_C        = $00000004;  // VFO C
  RIG_VFO_SUB_A    = $00200000;  // Sub VFO A
  RIG_VFO_SUB_B    = $00400000;  // Sub VFO B
  RIG_VFO_MAIN_A   = $00800000;  // Main VFO A
  RIG_VFO_MAIN_B   = $01000000;  // Main VFO B
  RIG_VFO_SUB      = $02000000;  // Sub VFO
  RIG_VFO_MAIN     = $04000000;  // Main VFO
  RIG_VFO_VFO      = $08000000;  // Last/any VFO mode
  RIG_VFO_MEM      = $10000000;  // Memory mode
  RIG_VFO_CURR     = $20000000;  // Current VFO
  RIG_VFO_TX_FLAG  = $40000000;  // Flag to set if VFO can transmit
  RIG_VFO_ALL      = $80000000;  // All VFOs

  RIG_VFO_TX       = RIG_VFO_CURR or RIG_VFO_TX_FLAG;  // Split TX
  RIG_VFO_RX       = RIG_VFO_CURR;                      // Split RX

{-----------------------------------------------------------------------------
  Mode Definitions (64-bit bitmasks)

  Note: These are bit flags computed as (1 << bit_number)
-----------------------------------------------------------------------------}

const
  RIG_MODE_NONE    = Int64(0);              // No mode
  RIG_MODE_AM      = Int64(1) shl 0;        // Amplitude Modulation
  RIG_MODE_CW      = Int64(1) shl 1;        // CW normal sideband
  RIG_MODE_USB     = Int64(1) shl 2;        // Upper Side Band
  RIG_MODE_LSB     = Int64(1) shl 3;        // Lower Side Band
  RIG_MODE_RTTY    = Int64(1) shl 4;        // Radio Teletype
  RIG_MODE_FM      = Int64(1) shl 5;        // Narrow band FM
  RIG_MODE_WFM     = Int64(1) shl 6;        // Broadcast wide FM
  RIG_MODE_CWR     = Int64(1) shl 7;        // CW reverse sideband
  RIG_MODE_RTTYR   = Int64(1) shl 8;        // RTTY reverse sideband
  RIG_MODE_AMS     = Int64(1) shl 9;        // AM Synchronous
  RIG_MODE_PKTLSB  = Int64(1) shl 10;       // Packet/Digital LSB
  RIG_MODE_PKTUSB  = Int64(1) shl 11;       // Packet/Digital USB
  RIG_MODE_PKTFM   = Int64(1) shl 12;       // Packet/Digital FM
  RIG_MODE_ECSSUSB = Int64(1) shl 13;       // ECSS USB
  RIG_MODE_ECSSLSB = Int64(1) shl 14;       // ECSS LSB
  RIG_MODE_FAX     = Int64(1) shl 15;       // Facsimile
  RIG_MODE_SAM     = Int64(1) shl 16;       // Synchronous AM double sideband
  RIG_MODE_SAL     = Int64(1) shl 17;       // Synchronous AM lower sideband
  RIG_MODE_SAH     = Int64(1) shl 18;       // Synchronous AM upper sideband
  RIG_MODE_DSB     = Int64(1) shl 19;       // Double sideband suppressed carrier
  RIG_MODE_FMN     = Int64(1) shl 21;       // FM Narrow
  RIG_MODE_PKTAM   = Int64(1) shl 22;       // Packet/Digital AM
  RIG_MODE_P25     = Int64(1) shl 23;       // APCO/P25 digital
  RIG_MODE_DSTAR   = Int64(1) shl 24;       // D-Star digital
  RIG_MODE_DPMR    = Int64(1) shl 25;       // dPMR digital
  RIG_MODE_NXDNVN  = Int64(1) shl 26;       // NXDN-VN digital
  RIG_MODE_NXDN_N  = Int64(1) shl 27;       // NXDN-N digital
  RIG_MODE_DCR     = Int64(1) shl 28;       // DCR digital
  RIG_MODE_AMN     = Int64(1) shl 29;       // AM Narrow
  RIG_MODE_PSK     = Int64(1) shl 30;       // PSK
  RIG_MODE_PSKR    = Int64(1) shl 31;       // PSK Reverse
  RIG_MODE_DD      = Int64(1) shl 32;       // DD Mode
  RIG_MODE_C4FM    = Int64(1) shl 33;       // Yaesu C4FM
  RIG_MODE_PKTFMN  = Int64(1) shl 34;       // Packet FM Narrow
  RIG_MODE_SPEC    = Int64(1) shl 35;       // Spectrum (unfiltered)
  RIG_MODE_CWN     = Int64(1) shl 36;       // CW Narrow
  RIG_MODE_IQ      = Int64(1) shl 37;       // IQ mode

  // Composite modes
  RIG_MODE_SSB     = RIG_MODE_USB or RIG_MODE_LSB;
  RIG_MODE_ECSS    = RIG_MODE_ECSSUSB or RIG_MODE_ECSSLSB;

{-----------------------------------------------------------------------------
  Passband Width
-----------------------------------------------------------------------------}

const
  RIG_PASSBAND_NORMAL   = 0;   // Normal passband for mode
  RIG_PASSBAND_NOCHANGE = -1;  // Leave passband unchanged

{-----------------------------------------------------------------------------
  PTT Status
-----------------------------------------------------------------------------}

const
  RIG_PTT_OFF      = 0;  // PTT deactivated
  RIG_PTT_ON       = 1;  // PTT activated
  RIG_PTT_ON_MIC   = 2;  // PTT Mic only
  RIG_PTT_ON_DATA  = 3;  // PTT Data (Mic-muted)

{-----------------------------------------------------------------------------
  Split Mode
-----------------------------------------------------------------------------}

const
  RIG_SPLIT_OFF = 0;  // Split mode disabled
  RIG_SPLIT_ON  = 1;  // Split mode enabled

{-----------------------------------------------------------------------------
  Configuration Tokens

  Common tokens for rig_set_conf() / rig_get_conf()
-----------------------------------------------------------------------------}

const
  TOK_PATHNAME      = 1;  // rig_pathname (e.g., 'COM3', '/dev/ttyS0')
  TOK_WRITE_DELAY   = 2;  // write_delay
  TOK_POST_WRITE_DELAY = 3;  // post_write_delay
  TOK_TIMEOUT       = 4;  // timeout
  TOK_RETRY         = 5;  // retry
  TOK_SERIAL_SPEED  = 10; // serial_speed (e.g., '38400')
  TOK_DATA_BITS     = 11; // data_bits
  TOK_STOP_BITS     = 12; // stop_bits
  TOK_PARITY        = 13; // parity
  TOK_HANDSHAKE     = 14; // handshake
  TOK_RTS_STATE     = 15; // rts_state
  TOK_DTR_STATE     = 16; // dtr_state

  // From hamlib/rig.h
  HAMLIB_FILPATHLEN = 512;  // Maximum pathname length

{-----------------------------------------------------------------------------
  Rig Model IDs

  Common radio model IDs - see riglist.h for complete list
-----------------------------------------------------------------------------}

const
  RIG_MODEL_NONE        = 0;
  RIG_MODEL_DUMMY       = 1;
  RIG_MODEL_NETRIGCTL   = 2;

  // Elecraft
  RIG_MODEL_K3          = 2029;
  RIG_MODEL_K4          = 2039;  // Elecraft K4

  // Yaesu
  RIG_MODEL_FT991       = 1035;
  RIG_MODEL_FTDX101D    = 1043;
  RIG_MODEL_FTDX101MP   = 1044;

  // Icom
  RIG_MODEL_IC7300      = 3073;
  RIG_MODEL_IC7610      = 3079;
  RIG_MODEL_IC9700      = 3081;

{-----------------------------------------------------------------------------
  Core API Functions
-----------------------------------------------------------------------------}

(*
   HAMLIB IS LOADED ON DEMAND, NOT BY THE WINDOWS LOADER.

   Every function below used to be declared `external HAMLIB_LIB`, which is a
   STATIC import: FPC writes the name into the PE import table and Windows
   resolves it during process creation. Three consequences, none of them
   intended, all measured on 2026-09-05:

   1. THE DLL LOADED WHETHER OR NOT A HAMLIB RADIO EXISTED. TR4W never called
      it; the loader loaded it. A station with no HamLib rig configured -- the
      overwhelming majority -- still could not start without the file present
      and correct.

   2. A WRONG-ARCHITECTURE COPY KILLED THE PROCESS WITH NOTHING LOGGED. A
      WSJT-X install puts C:/WSJT/wsjtx/bin on the MACHINE path, present every
      boot whether or not WSJT-X runs, and ships a 64-bit libhamlib-4.dll. A
      32-bit TR4W that failed to find its own copy first got that one and died
      with 0xC000007B before a line of our code ran. tr4w.log and
      tr4w-early.log were both EMPTY -- the crash handler had not been
      installed yet either.

   3. NO DIAGNOSIS WAS POSSIBLE. A check inside TR4W cannot report a failure
      that happens before TR4W starts. That is why this is a loader change and
      not a message-box change.

   EnsureHamLib does the work the loader used to do, at a moment we choose:
   it locates the DLL, CHECKS ITS ARCHITECTURE AGAINST THIS PROCESS, loads it,
   and resolves every entry point -- reporting exactly which step failed.

   WHY MOST ENTRY POINTS ARE PLAIN VARIABLES AND FIVE ARE FUNCTIONS.
   Everything except rig_init, rig_set_debug, rig_get_caps_int, rigerror and
   rig_strrmode takes a PRIG, and a non-nil PRIG can ONLY have come from
   rig_init -- which calls EnsureHamLib and returns nil if it fails. So "the
   library is loaded" is an INVARIANT carried by the argument itself, not an
   assumption about call order. The five that take no PRIG are real functions
   that ensure the load themselves.

   CROSS-PLATFORM: only the NAME here is Windows. HamLib ships .so and .dylib,
   so a port changes HAMLIB_LIB and nothing else -- see the helper-class note
   in CLAUDE.md.
*)

// True once the library is loaded and every entry point resolved. Idempotent:
// safe to call from any of the entry points, and it only tries once.
function EnsureHamLib: Boolean;

// Empty until EnsureHamLib has failed. Written for an operator, not a
// developer: it names the path tried and, on a mismatch, both architectures.
function HamLibLoadError: string;

// The full path actually loaded, or the file that was rejected. Empty before
// the first attempt.
function HamLibDllPath: string;

// WITHOUT LOADING ANYTHING. Reports where the DLL is, its architecture, and
// whether that matches this process -- by reading the file's PE header. This
// is what startup logs, so a mismatch appears in tr4w.log as a sentence
// instead of as a process that never started.
function DescribeHamLibDll: string;

// Resolve an OPTIONAL entry point -- one that some builds of HamLib do not
// export, so its absence is not an error. Returns nil if the library is
// unusable or the name is not there. Callers that need a REQUIRED entry point
// do not use this: those are resolved by EnsureHamLib and are never nil once
// it has succeeded.
//
// It exists so that no other unit has to open the library itself. The driver
// used to call LoadLibrary(HAMLIB_LIB) with a bare name to reach
// rig_set_debug_file, which is the same PATH search that produced the
// 0xC000007B described above -- and could load a SECOND, different copy.
function HamLibProcAddress(const aName: AnsiString): Pointer;

// Debug control
procedure rig_set_debug(debug_level: rig_debug_level_e); cdecl;
// rig_set_debug_file is loaded dynamically at runtime (may not exist in all builds)
// Use MSVCRT fopen to obtain a C FILE* compatible with HamLib's debug stream
// msvcrt is a system DLL that is always present and always matches the
// process, so a static import of it carries none of the risk described above.
function msvcrt_fopen(filename: PAnsiChar; mode: PAnsiChar): Pointer; cdecl; external 'msvcrt.dll' name 'fopen';

// Initialization and cleanup.
//
// THE GATE. This is the only way to obtain a PRIG, so it is the only place the
// library has to be ensured. Returns nil if HamLib cannot be loaded -- which
// the driver already handles, because rig_init could always return nil.
function rig_init(rig_model: Integer): PRIG; cdecl;
// Model-level capability lookup (no open rig needed).  With
// RIG_CAPS_TARGETABLE_VFO it returns the backend's caps->targetable_vfo
// bitmask -- the AUTHORITATIVE answer to "can VFO B be read without physically
// switching the rig".  Probing with rig_get_freq(RIG_VFO_B) cannot answer
// that: on a non-targetable rig HamLib EMULATES the read by swapping VFOs, so
// the probe succeeds and the swap is exactly the side effect being probed for.
// Takes a model id rather than a PRIG, so it ensures the load itself.
// Returns 0 if HamLib is unavailable -- the same "no capability" answer the
// caller already handles.
function rig_get_caps_int(rig_model: Integer; rig_caps: Integer): UInt64; cdecl;

var
  rig_open:    function(rig: PRIG): Integer; cdecl;
  rig_close:   function(rig: PRIG): Integer; cdecl;
  rig_cleanup: function(rig: PRIG): Integer; cdecl;

// Configuration
var
  rig_set_conf:     function(rig: PRIG; token: hamlib_token_t; const val: PAnsiChar): Integer; cdecl;
  rig_get_conf:     function(rig: PRIG; token: hamlib_token_t; val: PAnsiChar): Integer; cdecl;
  rig_token_lookup: function(rig: PRIG; const name: PAnsiChar): hamlib_token_t; cdecl;

{-----------------------------------------------------------------------------
  Frequency Control
-----------------------------------------------------------------------------}

var
  rig_set_freq: function(rig: PRIG; vfo: vfo_t; freq: freq_t): Integer; cdecl;
  rig_get_freq: function(rig: PRIG; vfo: vfo_t; var freq: freq_t): Integer; cdecl;

{-----------------------------------------------------------------------------
  Mode Control
-----------------------------------------------------------------------------}

var
  rig_set_mode: function(rig: PRIG; vfo: vfo_t; mode: rmode_t; width: pbwidth_t): Integer; cdecl;
  rig_get_mode: function(rig: PRIG; vfo: vfo_t; var mode: rmode_t; var width: pbwidth_t): Integer; cdecl;

{-----------------------------------------------------------------------------
  VFO Control
-----------------------------------------------------------------------------}

var
  rig_set_vfo: function(rig: PRIG; vfo: vfo_t): Integer; cdecl;
  rig_get_vfo: function(rig: PRIG; var vfo: vfo_t): Integer; cdecl;

{-----------------------------------------------------------------------------
  PTT Control
-----------------------------------------------------------------------------}

var
  rig_set_ptt: function(rig: PRIG; vfo: vfo_t; ptt: ptt_t): Integer; cdecl;
  rig_get_ptt: function(rig: PRIG; vfo: vfo_t; var ptt: ptt_t): Integer; cdecl;

{-----------------------------------------------------------------------------
  Split Operation
-----------------------------------------------------------------------------}

var
  rig_set_split_freq: function(rig: PRIG; vfo: vfo_t; tx_freq: freq_t): Integer; cdecl;
  rig_get_split_freq: function(rig: PRIG; vfo: vfo_t; var tx_freq: freq_t): Integer; cdecl;
  rig_set_split_mode: function(rig: PRIG; vfo: vfo_t; tx_mode: rmode_t; tx_width: pbwidth_t): Integer; cdecl;
  rig_get_split_mode: function(rig: PRIG; vfo: vfo_t; var tx_mode: rmode_t; var tx_width: pbwidth_t): Integer; cdecl;
  rig_set_split_vfo:  function(rig: PRIG; vfo: vfo_t; split: Integer; tx_vfo: vfo_t): Integer; cdecl;
  rig_get_split_vfo:  function(rig: PRIG; vfo: vfo_t; var split: Integer; var tx_vfo: vfo_t): Integer; cdecl;

{-----------------------------------------------------------------------------
  RIT/XIT Control
-----------------------------------------------------------------------------}

var
  rig_set_rit: function(rig: PRIG; vfo: vfo_t; rit: shortfreq_t): Integer; cdecl;
  rig_get_rit: function(rig: PRIG; vfo: vfo_t; var rit: shortfreq_t): Integer; cdecl;
  rig_set_xit: function(rig: PRIG; vfo: vfo_t; xit: shortfreq_t): Integer; cdecl;
  rig_get_xit: function(rig: PRIG; vfo: vfo_t; var xit: shortfreq_t): Integer; cdecl;

{-----------------------------------------------------------------------------
  Function settings (on/off capabilities) — rig_get_func / rig_set_func
  setting_t is a 64-bit bitmask; each bit represents one function.
  RIG_FUNC_RIT = bit 5 (32), RIG_FUNC_XIT = bit 6 (64).
-----------------------------------------------------------------------------}

type
  setting_t = Int64;

const
  RIG_FUNC_RIT = setting_t(1) shl 24;  // RIT on/off state (hamlib rig.h bit 24)
  RIG_FUNC_XIT = setting_t(1) shl 31;  // XIT on/off state (hamlib rig.h bit 31)

var
  rig_get_func: function(rig: PRIG; vfo: vfo_t; func: setting_t; var status: Integer): Integer; cdecl;
  rig_set_func: function(rig: PRIG; vfo: vfo_t; func: setting_t; status: Integer): Integer; cdecl;

{-----------------------------------------------------------------------------
  Utility Functions
-----------------------------------------------------------------------------}

// Get error message for error code.
// Takes no PRIG -- it exists to explain a FAILED call, including a failed
// rig_init -- so it ensures the load itself and returns nil if unavailable.
function rigerror(errnum: Integer): PAnsiChar; cdecl;

// Mode string conversion. Same reasoning as rigerror.
function rig_strrmode(mode: rmode_t): PAnsiChar; cdecl;

{-----------------------------------------------------------------------------
  Transceive Mode

  When enabled with RIG_TRN_RIG, the radio pushes unsolicited freq/mode/PTT
  changes. HamLib invokes the registered callbacks from its internal reader
  thread. Register callbacks before calling rig_set_trn.
-----------------------------------------------------------------------------}

const
  RIG_TRN_OFF  = 0;  // Transceive disabled (polling only)
  RIG_TRN_RIG  = 1;  // Radio pushes changes (requires backend/hardware support)
  RIG_TRN_POLL = 2;  // HamLib polls and fires callbacks (software emulation)

type
  // Called from HamLib reader thread when radio pushes a frequency change.
  // rig_arg is the user pointer registered via rig_set_freq_callback.
  TRigFreqCallback = function(rig: PRIG; vfo: vfo_t; freq: freq_t;
                               rig_arg: Pointer): Integer; cdecl;

  // Called from HamLib reader thread when radio pushes a mode/width change.
  TRigModeCallback = function(rig: PRIG; vfo: vfo_t; mode: rmode_t;
                               width: pbwidth_t; rig_arg: Pointer): Integer; cdecl;

  // Called from HamLib reader thread when radio pushes a VFO change.
  TRigVFOCallback  = function(rig: PRIG; vfo: vfo_t;
                               rig_arg: Pointer): Integer; cdecl;

  // Called from HamLib reader thread when radio pushes a PTT state change.
  TRigPTTCallback  = function(rig: PRIG; vfo: vfo_t; ptt: ptt_t;
                               rig_arg: Pointer): Integer; cdecl;

// Enable or disable transceive mode.
// Must be called after rig_open. Returns RIG_ENIMPL if backend does not support it.
var
  rig_set_trn: function(rig: PRIG; trn: Integer): Integer; cdecl;

// Register a callback to be invoked when the radio pushes unsolicited changes.
// arg is passed back verbatim to each callback invocation (use as Self pointer).
var
  rig_set_freq_callback: function(rig: PRIG; cb: TRigFreqCallback;
                                  arg: Pointer): Integer; cdecl;
  rig_set_mode_callback: function(rig: PRIG; cb: TRigModeCallback;
                                  arg: Pointer): Integer; cdecl;
  rig_set_vfo_callback:  function(rig: PRIG; cb: TRigVFOCallback;
                                  arg: Pointer): Integer; cdecl;
  rig_set_ptt_callback:  function(rig: PRIG; cb: TRigPTTCallback;
                                  arg: Pointer): Integer; cdecl;

{-----------------------------------------------------------------------------
  Helper Functions (Delphi-specific)
-----------------------------------------------------------------------------}

// Convert error code to string
function RigErrorToString(errcode: Integer): string;

// Convert mode constant to readable string
function RigModeToString(mode: rmode_t): string;

// Convert VFO constant to readable string
function RigVFOToString(vfo: vfo_t): string;

// Get HamLib version string from DLL
function GetHamLibVersion: string;

// Direct structure access helper for setting pathname
// This bypasses rig_set_conf which may not work for all backends
procedure RigSetPathname(rig: PRIG; const pathname: string);

// Read back pathname for verification
function RigGetPathname(rig: PRIG): string;

// Set timeout for network operations (in milliseconds)
procedure RigSetTimeout(rig: PRIG; timeoutMs: Integer);

implementation

uses
  uAppPaths,  // DataFilePath -- the ONE place that knows where shipped files live
  DynLibs;    // LoadLibrary/GetProcedureAddress that take a string and are not
              // Windows-specific. Preferred over the Win32 entry points: this
              // is the one place that knows how a shared library is opened, and
              // on macOS or Linux only HAMLIB_LIB's value has to change.

var
  GHamLibModule : TLibHandle = NilHandle;
  GHamLibTried  : Boolean    = False;
  GHamLibOK     : Boolean    = False;
  GHamLibError  : string     = '';
  GHamLibPath   : string     = '';

  // The five entry points that take no PRIG are reached through these, so the
  // public names can be real functions that ensure the load first.
  p_rig_set_debug    : procedure(debug_level: rig_debug_level_e); cdecl;
  p_rig_init         : function(rig_model: Integer): PRIG; cdecl;
  p_rig_get_caps_int : function(rig_model: Integer; rig_caps: Integer): UInt64; cdecl;
  p_rigerror         : function(errnum: Integer): PAnsiChar; cdecl;
  p_rig_strrmode     : function(mode: rmode_t): PAnsiChar; cdecl;

const
  IMAGE_MACHINE_I386  = $014C;
  IMAGE_MACHINE_AMD64 = $8664;
  IMAGE_MACHINE_ARM64 = $AA64;

(*
   THE PE MACHINE TYPE OF A FILE ON DISK, WITHOUT LOADING IT.

   This is the whole point of the exercise: once the image is loaded the
   question is already settled, and if the architecture is wrong the load is
   what kills us. Reading two fields out of the header answers it first, and
   costs a file open.

   SysUtils.FileOpen rather than Windows.ReadFile -- the semantics that matter
   here (seek, read, a short read is a malformed file) are expressible either
   way, and only one of them survives a port.

   AND rather than TFileStream, whose constructor takes an AnsiString: this
   path comes from DataFilePath or PATH and can sit under a profile name with
   non-ASCII characters, so handing it to an AnsiString parameter narrows it
   and can open the wrong file or none. FileOpen has a UnicodeString overload
   that carries the name to the OS intact.
*)
function PEMachineOf(const aPath: string): Word;
var
  h     : THandle;
  peOfs : LongInt;
  sig   : LongWord;
  found : Word;
begin
   Result := 0;
   if not FileExists(aPath) then
      begin
      Exit;
      end;

   h := FileOpen(aPath, fmOpenRead or fmShareDenyNone);
   if h = THandle(-1) then
      begin
      Exit;
      end;
   try
      // e_lfanew: where the PE header starts.
      if FileSeek(h, Int64($3C), fsFromBeginning) <> Int64($3C) then
         begin
         Exit;
         end;
      if FileRead(h, peOfs, SizeOf(peOfs)) <> SizeOf(peOfs) then
         begin
         Exit;
         end;
      if peOfs <= 0 then
         begin
         Exit;
         end;
      if FileSeek(h, Int64(peOfs), fsFromBeginning) <> Int64(peOfs) then
         begin
         Exit;
         end;
      if FileRead(h, sig, SizeOf(sig)) <> SizeOf(sig) then
         begin
         Exit;
         end;
      if sig <> $00004550 then                  // the PE signature
         begin
         Exit;
         end;
      if FileRead(h, found, SizeOf(found)) <> SizeOf(found) then
         begin
         Exit;
         end;
      Result := found;
   finally
      // An unreadable or truncated file is not a diagnosis: every path above
      // leaves Result 0, which reads as "unknown" and lets the load attempt
      // produce the real error.
      FileClose(h);
   end;
end;

function MachineName(aMachine: Word): string;
begin
   case aMachine of
      IMAGE_MACHINE_I386  : Result := 'x86 (32-bit)';
      IMAGE_MACHINE_AMD64 : Result := 'x64 (64-bit)';
      IMAGE_MACHINE_ARM64 : Result := 'ARM64';
   else
      Result := Format('machine type 0x%.4x', [aMachine]);
   end;
end;

(*
   DERIVED FROM THE COMPILER'S OWN TARGET, NEVER HARDCODED. TR4W is moving to
   64-bit, at which point the mismatch inverts and the 32-bit DLLs become the
   wrong ones. A check written as "64-bit is bad" would then pass the broken
   case and fail the good one.
*)
function ThisProcessMachine: Word;
begin
{$IF DEFINED(CPUI386)}
   Result := IMAGE_MACHINE_I386;
{$ELSEIF DEFINED(CPUX86_64)}
   Result := IMAGE_MACHINE_AMD64;
{$ELSEIF DEFINED(CPUAARCH64)}
   Result := IMAGE_MACHINE_ARM64;
{$ELSE}
   Result := 0;   // unknown target: skip the check rather than guess wrong
{$IFEND}
end;

(*
   WHERE THE LIBRARY SHOULD COME FROM, AS A FULL PATH.

   TR4W'S OWN COPY FIRST, and then loaded BY THAT PATH -- which is what takes
   the environment out of the decision. Passing a bare name lets the OS search,
   and on Windows that search reaches PATH, where a WSJT-X install contributes
   a 64-bit libhamlib-4.dll from a directory on the MACHINE path. That is how a
   32-bit TR4W came to be handed a 64-bit DLL.

   DataFilePath, not ExtractFilePath(ParamStr(0)): a shipped read-only file is
   exactly what this is, and uAppPaths owns that rule per platform -- the
   working directory on Windows (NY4I, 2026-08-31, chosen because it keeps
   working when the binary is run from build-out), Contents/Resources on macOS,
   the XDG data directory on Linux. Resolving it here would be a fourth copy of
   a rule that has already caused one defect by existing twice.

   Only if TR4W has no copy do we fall back to searching PATH ourselves -- with
   FileSearch, so that we still end up holding a real path to check and to name
   in an error, rather than letting the loader pick silently.
*)
function LocateHamLib: string;
begin
   Result := DataFilePath(HAMLIB_LIB);
   if FileExists(Result) then
      begin
      Exit;
      end;
   Result := FileSearch(HAMLIB_LIB, GetEnvironmentVariable('PATH'));

   // ALWAYS A FULL PATH. FileSearch answers relative to whatever entry matched
   // -- including the current directory, which it searches first -- and
   // "libhamlib-4.dll is 64-bit" without a directory is precisely the report
   // that cannot be acted on. WHICH copy is the entire question here.
   if Result <> '' then
      begin
      Result := ExpandFileName(Result);
      end;
end;

function EnsureHamLib: Boolean;
var
  wanted  : Word;
  found   : Word;
  missing : string;

   // Resolving by name, recording every miss rather than stopping at the
   // first: a half-resolved library is the one failure mode that would still
   // crash later, and the operator wants the whole list in one message.
   // AnsiString because that is what GetProcedureAddress takes, and because a
   // C export name IS ASCII -- so this is the exact type for the value, not a
   // narrowing of a wider one.
   function Need(const aName: AnsiString): Pointer;
   begin
      Result := GetProcedureAddress(GHamLibModule, aName);
      if Result = nil then
         begin
         missing := missing + ' ' + aName;
         end;
   end;

begin
   if GHamLibTried then
      begin
      Result := GHamLibOK;
      Exit;
      end;
   GHamLibTried := True;
   GHamLibOK    := False;
   GHamLibError := '';
   missing      := '';

   GHamLibPath := LocateHamLib;
   if GHamLibPath = '' then
      begin
      GHamLibError := Format('%s was not found beside %s or anywhere on PATH.',
                             [HAMLIB_LIB, ExtractFileName(ParamStr(0))]);
      Result := False;
      Exit;
      end;

   wanted := ThisProcessMachine;
   found  := PEMachineOf(GHamLibPath);
   if (wanted <> 0) and (found <> 0) and (found <> wanted) then
      begin
      // The message an operator can act on: which file, and which way round.
      GHamLibError := Format('%s is %s, but TR4W is %s.  That file cannot be ' +
                             'loaded by this program.  The matching copy ships ' +
                             'in the TR4W program folder; this one was found at %s.',
                             [ExtractFileName(GHamLibPath), MachineName(found),
                              MachineName(wanted), ExtractFilePath(GHamLibPath)]);
      Result := False;
      Exit;
      end;

   GHamLibModule := LoadLibrary(GHamLibPath);
   if GHamLibModule = NilHandle then
      begin
      GHamLibError := Format('%s could not be loaded (%s).',
                             [GHamLibPath, GetLoadErrorStr]);
      Result := False;
      Exit;
      end;

   @p_rig_set_debug    := Need('rig_set_debug');
   @p_rig_init         := Need('rig_init');
   @p_rig_get_caps_int := Need('rig_get_caps_int');
   @p_rigerror         := Need('rigerror');
   @p_rig_strrmode     := Need('rig_strrmode');

   @rig_open              := Need('rig_open');
   @rig_close             := Need('rig_close');
   @rig_cleanup           := Need('rig_cleanup');
   @rig_set_conf          := Need('rig_set_conf');
   @rig_get_conf          := Need('rig_get_conf');
   @rig_token_lookup      := Need('rig_token_lookup');
   @rig_set_freq          := Need('rig_set_freq');
   @rig_get_freq          := Need('rig_get_freq');
   @rig_set_mode          := Need('rig_set_mode');
   @rig_get_mode          := Need('rig_get_mode');
   @rig_set_vfo           := Need('rig_set_vfo');
   @rig_get_vfo           := Need('rig_get_vfo');
   @rig_set_ptt           := Need('rig_set_ptt');
   @rig_get_ptt           := Need('rig_get_ptt');
   @rig_set_split_freq    := Need('rig_set_split_freq');
   @rig_get_split_freq    := Need('rig_get_split_freq');
   @rig_set_split_mode    := Need('rig_set_split_mode');
   @rig_get_split_mode    := Need('rig_get_split_mode');
   @rig_set_split_vfo     := Need('rig_set_split_vfo');
   @rig_get_split_vfo     := Need('rig_get_split_vfo');
   @rig_set_rit           := Need('rig_set_rit');
   @rig_get_rit           := Need('rig_get_rit');
   @rig_set_xit           := Need('rig_set_xit');
   @rig_get_xit           := Need('rig_get_xit');
   @rig_get_func          := Need('rig_get_func');
   @rig_set_func          := Need('rig_set_func');
   @rig_set_trn           := Need('rig_set_trn');
   @rig_set_freq_callback := Need('rig_set_freq_callback');
   @rig_set_mode_callback := Need('rig_set_mode_callback');
   @rig_set_vfo_callback  := Need('rig_set_vfo_callback');
   @rig_set_ptt_callback  := Need('rig_set_ptt_callback');

   if missing <> '' then
      begin
      // FAIL CLOSED. A partially resolved library would work until it reached
      // the one entry point that is nil, and then crash with no explanation --
      // exactly the class of failure this change exists to remove.
      GHamLibError := Format('%s loaded but is missing:%s', [GHamLibPath, missing]);
      UnloadLibrary(GHamLibModule);
      GHamLibModule := NilHandle;
      Result := False;
      Exit;
      end;

   GHamLibOK := True;
   Result    := True;
end;

function HamLibLoadError: string;
begin
   Result := GHamLibError;
end;

function HamLibDllPath: string;
begin
   Result := GHamLibPath;
end;

function HamLibProcAddress(const aName: AnsiString): Pointer;
begin
   if EnsureHamLib then
      begin
      Result := GetProcedureAddress(GHamLibModule, aName);
      end
   else
      begin
      Result := nil;
      end;
end;

function DescribeHamLibDll: string;
var
  path   : string;
  found  : Word;
  wanted : Word;
begin
   path := LocateHamLib;
   if path = '' then
      begin
      Result := Format('%s not found (no HamLib radio can be used)', [HAMLIB_LIB]);
      Exit;
      end;
   found  := PEMachineOf(path);
   wanted := ThisProcessMachine;
   if (wanted <> 0) and (found <> 0) and (found <> wanted) then
      begin
      Result := Format('%s is %s but TR4W is %s -- IT CANNOT BE LOADED',
                       [path, MachineName(found), MachineName(wanted)]);
      end
   else
      begin
      Result := Format('%s, %s, not loaded until a HamLib radio is used',
                       [path, MachineName(found)]);
      end;
end;

(*
   THE FIVE THAT TAKE NO PRIG.

   Each ensures the load and then returns the library's answer, or a value the
   caller already treats as "not available": nil from rig_init is what the
   driver has always checked for, and 0 from rig_get_caps_int is "no such
   capability".
*)
procedure rig_set_debug(debug_level: rig_debug_level_e); cdecl;
begin
   if EnsureHamLib then
      begin
      p_rig_set_debug(debug_level);
      end;
end;

function rig_init(rig_model: Integer): PRIG; cdecl;
begin
   if EnsureHamLib then
      begin
      Result := p_rig_init(rig_model);
      end
   else
      begin
      Result := nil;
      end;
end;

function rig_get_caps_int(rig_model: Integer; rig_caps: Integer): UInt64; cdecl;
begin
   if EnsureHamLib then
      begin
      Result := p_rig_get_caps_int(rig_model, rig_caps);
      end
   else
      begin
      Result := 0;
      end;
end;

function rigerror(errnum: Integer): PAnsiChar; cdecl;
begin
   if EnsureHamLib then
      begin
      Result := p_rigerror(errnum);
      end
   else
      begin
      Result := nil;
      end;
end;

function rig_strrmode(mode: rmode_t): PAnsiChar; cdecl;
begin
   if EnsureHamLib then
      begin
      Result := p_rig_strrmode(mode);
      end
   else
      begin
      Result := nil;
      end;
end;

function GetHamLibVersion: string;
var
  pVersion: ^PAnsiChar;
begin
   Result := 'unknown';
   if not EnsureHamLib then
      begin
      Exit;
      end;
   // hamlib_version2 is exported DATA, not a function -- the address is of a
   // PAnsiChar, so it is dereferenced once.
   pVersion := GetProcedureAddress(GHamLibModule, 'hamlib_version2');
   if pVersion <> nil then
      begin
      Result := string(pVersion^);
      end;
end;

function RigErrorToString(errcode: Integer): string;
begin
  case errcode of
    RIG_OK:          Result := 'OK';
    RIG_EINVAL:      Result := 'Invalid parameter';
    RIG_ECONF:       Result := 'Invalid configuration';
    RIG_ENOMEM:      Result := 'Memory shortage';
    RIG_ENIMPL:      Result := 'Function not implemented';
    RIG_ETIMEOUT:    Result := 'Communication timeout';
    RIG_EIO:         Result := 'IO error';
    RIG_EINTERNAL:   Result := 'Internal error';
    RIG_EPROTO:      Result := 'Protocol error';
    RIG_ERJCTED:     Result := 'Command rejected';
    RIG_ETRUNC:      Result := 'Argument truncated';
    RIG_ENAVAIL:     Result := 'Function not available';
    RIG_ENTARGET:    Result := 'VFO not targetable';
    RIG_BUSERROR:    Result := 'Bus error';
    RIG_BUSBUSY:     Result := 'Bus busy';
    RIG_EARG:        Result := 'Invalid argument';
    RIG_EVFO:        Result := 'Invalid VFO';
    RIG_EDOM:        Result := 'Argument out of domain';
    RIG_EDEPRECATED: Result := 'Function deprecated';
    RIG_ESECURITY:   Result := 'Security error';
    RIG_EPOWER:      Result := 'Rig not powered on';
    RIG_ELIMIT:      Result := 'Limit exceeded';
    RIG_EACCESS:     Result := 'Access denied';
  else
    Result := Format('Unknown error (%d)', [errcode]);
  end;
end;

function RigModeToString(mode: rmode_t): string;
begin
  // Check for composite modes first
  if mode = RIG_MODE_SSB then
     begin
     Result := 'SSB'
     end
  else if mode = RIG_MODE_ECSS then
     begin
     Result := 'ECSS'
     end
  // Individual modes
  else if mode = RIG_MODE_AM then
     begin
     Result := 'AM'
     end
  else if mode = RIG_MODE_CW then
     begin
     Result := 'CW'
     end
  else if mode = RIG_MODE_USB then
     begin
     Result := 'USB'
     end
  else if mode = RIG_MODE_LSB then
     begin
     Result := 'LSB'
     end
  else if mode = RIG_MODE_RTTY then
     begin
     Result := 'RTTY'
     end
  else if mode = RIG_MODE_FM then
     begin
     Result := 'FM'
     end
  else if mode = RIG_MODE_WFM then
     begin
     Result := 'WFM'
     end
  else if mode = RIG_MODE_CWR then
     begin
     Result := 'CWR'
     end
  else if mode = RIG_MODE_RTTYR then
     begin
     Result := 'RTTYR'
     end
  else if mode = RIG_MODE_AMS then
     begin
     Result := 'AMS'
     end
  else if mode = RIG_MODE_PKTLSB then
     begin
     Result := 'PKT-LSB'
     end
  else if mode = RIG_MODE_PKTUSB then
     begin
     Result := 'PKT-USB'
     end
  else if mode = RIG_MODE_PKTFM then
     begin
     Result := 'PKT-FM'
     end
  else if mode = RIG_MODE_FAX then
     begin
     Result := 'FAX'
     end
  else if mode = RIG_MODE_PKTAM then
     begin
     Result := 'PKT-AM'
     end
  else if mode = RIG_MODE_FMN then
     begin
     Result := 'FMN'
     end
  else if mode = RIG_MODE_C4FM then
     begin
     Result := 'C4FM'
     end
  else if mode = RIG_MODE_DSTAR then
     begin
     Result := 'D-STAR'
     end
  else if mode = RIG_MODE_NONE then
     begin
     Result := 'NONE'
     end
  else
     begin
     Result := Format('Mode($%x)', [mode]);
     end;
end;

function RigVFOToString(vfo: vfo_t): string;
begin
  // Note: RIG_VFO_RX = RIG_VFO_CURR, so we check TX flag first
  if (vfo and RIG_VFO_TX_FLAG) <> 0 then
     begin
     Result := 'TX';
     Exit;
     end;

  case vfo of
    RIG_VFO_NONE:   Result := 'NONE';
    RIG_VFO_A:      Result := 'VFO A';
    RIG_VFO_B:      Result := 'VFO B';
    RIG_VFO_C:      Result := 'VFO C';
    RIG_VFO_CURR:   Result := 'CURRENT';  // Also covers RIG_VFO_RX
    RIG_VFO_MEM:    Result := 'MEMORY';
    RIG_VFO_MAIN:   Result := 'MAIN';
    RIG_VFO_SUB:    Result := 'SUB';
    RIG_VFO_MAIN_A: Result := 'MAIN A';
    RIG_VFO_MAIN_B: Result := 'MAIN B';
    RIG_VFO_SUB_A:  Result := 'SUB A';
    RIG_VFO_SUB_B:  Result := 'SUB B';
  else
    Result := Format('VFO($%x)', [vfo]);
  end;
end;

procedure RigSetPathname(rig: PRIG; const pathname: string);
(*
  Directly sets the pathname in rig->state.rigport.pathname field.

  This is equivalent to the C code:
    strncpy(rig->state.rigport.pathname, pathname, HAMLIB_FILPATHLEN - 1);

  Structure layout (32-bit):
    struct rig:
      struct rig_caps *caps;        // +0, 4 bytes (pointer)
      struct rig_state state;       // +4

    struct rig_state:
      hamlib_port_t rigport;        // +0 (first field)

    struct hamlib_port_t:
      int fd;                       // +0, 4 bytes
      void *handle;                 // +4, 4 bytes
      int write_delay;              // +8, 4 bytes
      int post_write_delay;         // +12, 4 bytes
      struct timeout;               // +16, 8 bytes
      int retry;                    // +24, 4 bytes
      char pathname[512];           // +28, 512 bytes  <-- THIS IS WHAT WE SET

  So pathname is at offset: 4 (caps) + 28 (rigport fields) = 32 bytes from rig
*)
const
  PATHNAME_OFFSET = 32;  // Offset of pathname field from start of RIG structure
var
  pathnamePtr: PAnsiChar;
  sourceBytes: PAnsiChar;
  pathnameA: AnsiString;   // ANSI copy: pathname is a wide string device path (ASCII)
  bytesToCopy: Integer;
  i: Integer;
begin
  if rig = nil then
     begin
     Exit;
     end;

  // Calculate pointer to pathname field
  pathnamePtr := PAnsiChar(Integer(rig) + PATHNAME_OFFSET);

  // Copy pathname string (similar to strncpy)
  pathnameA := AnsiString(pathname);
  sourceBytes := PAnsiChar(pathnameA);
  bytesToCopy := Length(pathnameA);
  if bytesToCopy > HAMLIB_FILPATHLEN - 1 then
     begin
     bytesToCopy := HAMLIB_FILPATHLEN - 1;
     end;

  // Copy bytes
  for i := 0 to bytesToCopy - 1 do
     begin
     pathnamePtr[i] := sourceBytes[i];
     end;

  // Null terminate
  pathnamePtr[bytesToCopy] := #0;
end;

function RigGetPathname(rig: PRIG): string;
const
  PATHNAME_OFFSET = 32;
var
  pathnamePtr: PAnsiChar;
begin
  Result := '';
  if rig = nil then
     begin
     Exit;
     end;

  // Calculate pointer to pathname field
  pathnamePtr := PAnsiChar(Integer(rig) + PATHNAME_OFFSET);

  // Read null-terminated string
  Result := string(pathnamePtr);
end;

procedure RigSetTimeout(rig: PRIG; timeoutMs: Integer);
(*
  Sets the timeout in rig->state.rigport.timeout field.

  Based on TR4QT HamlibRadio.cpp:77
    m_rig->state.rigport.timeout = 1000;  // 1000ms = 1 second

  Structure layout shows timeout is before pathname.
  Since pathname is at offset 32, and timeout is typically an int (4 bytes)
  positioned before several other fields and pathname, the timeout offset
  should be at offset 16 (after fd, handle, write_delay, post_write_delay).
*)
const
  TIMEOUT_OFFSET = 16;  // Offset of timeout field from start of RIG structure
var
  timeoutPtr: PInteger;
begin
  if rig = nil then
     begin
     Exit;
     end;

  // Calculate pointer to timeout field
  timeoutPtr := PInteger(Integer(rig) + TIMEOUT_OFFSET);

  // Set timeout value (in milliseconds)
  timeoutPtr^ := timeoutMs;
end;

end.
