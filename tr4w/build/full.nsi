; TR4WVERSION is the full version (e.g. '4.149.0') and the single source of
; truth for both the displayed name and the installer filename.  It MUST be
; passed in with /DTR4WVERSION, derived from src\Version.pas by FullBuild.ps1.
;
; There is deliberately NO default.  There used to be one, and it had drifted to
; 4.148.1 while Version.pas said 4.149.0 -- a silently mis-versioned installer is
; far worse than a build that stops.  Fail loudly instead.
!ifndef TR4WVERSION
  !error "TR4WVERSION is not defined.  Build installers with FullBuild.ps1 -BuildInstallers (it derives the version from src\Version.pas and passes /DTR4WVERSION), not by running makensis on this script directly."
!endif

; ---------------------------------------------------------------------------
; ARCHITECTURE (issue 299, flipped 2026-11-12).  ABSENT /DTR4WARCH = THE 64-BIT
; INSTALLER, which is the shipping one: the exe, tr4w.dbg, the runtime DLLs,
; tr4wconvert.exe and cacert.pem are read from ..\target and tr4wserver.exe from
; ..\tr4wserver, which is where the shipping (x86_64-win64) build stages them
; (build\Get-StagingDir.ps1).
;
; /DTR4WARCH=i386 /DTR4WSTAGE=<dir> (passed by build\Build-Installer.ps1) builds
; the 32-bit installer from a stage directory (build-out\dist\i386-win32),
; NEVER from ..\target -- those are 64-bit files now.  It is buildable and not
; shipped.  /DTR4WARCH=x86_64 may be given explicitly with a /DTR4WSTAGE of its
; own (a scratch stage).  Files that are the same for every bitness (the .dat and
; .ini files, TRMASTER.DTA, cty.dat, dom\) are always read from ..\target.
; ---------------------------------------------------------------------------
!ifndef TR4WARCH
  !define TR4WARCH "x86_64"
!endif
!if "${TR4WARCH}" == "x86_64"
  !define TR4W64
  !ifdef TR4WSTAGE
    !define BINDIR    "${TR4WSTAGE}"
    !define SERVERDIR "${TR4WSTAGE}"
  !else
    !define BINDIR    "..\target"
    !define SERVERDIR "..\tr4wserver"
  !endif
  !define TR4WSUFFIX "-x64"
  !include LogicLib.nsh
  !include x64.nsh
!else
  !if "${TR4WARCH}" == "i386"
    !ifndef TR4WSTAGE
      !error "TR4WARCH=i386 needs TR4WSTAGE.  The 32-bit installer is built from a stage directory, never from ..\target (64-bit files); use build\Build-Installer.ps1 -Cpu i386."
    !endif
    !define BINDIR    "${TR4WSTAGE}"
    !define SERVERDIR "${TR4WSTAGE}"
    !define TR4WSUFFIX "-x86"
  !else
    !error "TR4WARCH must be x86_64 or i386."
  !endif
!endif

!define TR4WINSTFOLDER 'Software\TR4W'
!define TR4WDRVREG     'SYSTEM\CurrentControlSet\Services\TR4WIO'

;!define MMTTYMODE  'mmtty'
;!define TR4WLANG    'rus'
;!define TR4WLANG    'cze'
;!define TR4WLANG    'mng'

;!define TR4WLANG    'ser'
;!define TR4WLANG    'rom'
;!define TR4WLANG    'ger'
;!define TR4WLANG    'ukr'
; NOT IMPLEMENTED
;!define TR4WLANG    'esp'
;!define TR4WLANG    'pol'
;!define TR4WLANG    'chn'

!ifdef MMTTYMODE
Name    "TR4W v.${TR4WVERSION} - MMTTY"
!else
!ifdef TR4W64
Name    "TR4W v.${TR4WVERSION} (64-bit)"
!else
Name    "TR4W v.${TR4WVERSION}"
!endif
!endif

; Each installer carries its architecture in the name (-x64 shipping, -x86 not
; shipped), so a 32-bit one can never be mistaken for the real one.
!ifdef TR4WLANG
OutFile release\tr4w_setup_${TR4WVERSION}${TR4WSUFFIX}_${TR4WLANG}.exe
!else
OutFile release\tr4w_setup_${TR4WVERSION}${TR4WSUFFIX}.exe
!ifdef MMTTYMODE
OutFile release\tr4w_setup_${TR4WVERSION}${TR4WSUFFIX}_mmtty.exe
!endif
!endif

!If ${TR4WLANG} == "rus"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\Russian.nlf"
	!define include_ini_file
!EndIf

!If ${TR4WLANG} == "ser"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\SerbianLatin.nlf"
!EndIf

!If ${TR4WLANG} == "esp"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\SpanishInternational.nlf"
!EndIf

!If ${TR4WLANG} == "mng"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\Mongolian.nlf"
!EndIf

!If ${TR4WLANG} == "pol"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\Polish.nlf"
!EndIf

!If ${TR4WLANG} == "cze"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\Czech.nlf"
	!define include_ini_file
!EndIf

!If ${TR4WLANG} == "rom"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\Romanian.nlf"
    !define include_ini_file
	!EndIf

!If ${TR4WLANG} == "ukr"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\Ukrainian.nlf"
	!define include_ini_file
!EndIf

!If ${TR4WLANG} == "chn"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\SimpChinese.nlf"
!EndIf

!If ${TR4WLANG} == "ger"
	LoadLanguageFile "${NSISDIR}\Contrib\Language files\German.nlf"
!EndIf




;Get installation folder from registry if available
!ifndef TR4W64
InstallDirRegKey HKCU "Software\TR4W" ""
!else
; ---------------------------------------------------------------------------
; THE 64-BIT INSTALLER DOES NOT USE InstallDirRegKey.  HKCU\Software\TR4W is
; shared with the 32-bit installer, so for someone upgrading it holds the old
; "C:\Program Files (x86)\TR4W", and InstallDirRegKey would put the 64-bit
; program back into the 32-bit folder.  .onInit below reads the key itself and
; decides deliberately.  (SetRegView 64 does not matter for HKCU\Software, which
; is not redirected; it is there for anything under HKLM.)
; ---------------------------------------------------------------------------
InstallDir "$PROGRAMFILES64\TR4W"
Var OLDDIR       ; an old 32-bit install to migrate from; empty when there is none

Function .onInit
	SetRegView 64

	${IfNot} ${RunningX64}
		MessageBox MB_OK|MB_ICONSTOP "This is the 64-bit TR4W installer and this is not a 64-bit Windows.$\r$\n$\r$\nUse the 32-bit TR4W installer instead." /SD IDOK
		Abort
	${EndIf}

	StrCpy $OLDDIR ""

	; /D=<dir> on the command line already replaced $INSTDIR; honour it and do
	; not second-guess the operator.  Otherwise $INSTDIR is still the InstallDir
	; default above.
	StrCmp $INSTDIR "$PROGRAMFILES64\TR4W" 0 onInit_done

	ReadRegStr $0 HKCU "Software\TR4W" ""
	StrCmp $0 "" onInit_noreg

	; Under "Program Files (x86)": the 32-bit installer's default.  Install to
	; Program Files and migrate.  Compared case-insensitively (StrCmp is).
	StrLen $2 "$PROGRAMFILES32"
	StrCpy $1 $0 $2
	StrCmp $1 "$PROGRAMFILES32" 0 onInit_elsewhere
		StrCpy $OLDDIR $0
		Goto onInit_done

onInit_elsewhere:
	; Anywhere else (a custom folder such as C:\TR4W, or an earlier 64-bit
	; install): there is no Program Files (x86) problem, so upgrade IN PLACE and
	; keep the operator's choice.  Nothing to migrate.
	StrCpy $INSTDIR $0
	Goto onInit_done

onInit_noreg:
	; No registry key, but the 32-bit installer's default folder may still hold
	; an install (a copy, or the key was cleaned).
	IfFileExists "$PROGRAMFILES32\TR4W\tr4w.exe" 0 onInit_done
		StrCpy $OLDDIR "$PROGRAMFILES32\TR4W"

onInit_done:
FunctionEnd
!endif


Page components
Page directory
Page instfiles


;BGGradient 0000FF FFFFFF
InstallColors  0000FF FFFFFF
;ShowInstDetails show


;Section "" SecCheckDLPortIO
; SEtRebootFlag false
; IfFileExists $SYSDIR\dlportio.dll checksys 0
; SEtRebootFlag true
; checksys:
; IfFileExists $SYSDIR\DRIVERS\dlportio.sys dlportioexist 0
; SEtRebootFlag true
; dlportioexist:
;SectionEnd



!ifdef TR4W64
; ---------------------------------------------------------------------------
; UPGRADING FROM A 32-BIT INSTALL (64-bit installer only; hidden, runs first).
;
; .onInit set $OLDDIR when it found a 32-bit TR4W under Program Files (x86).
; The 64-bit program goes to Program Files, so the operator's data has to come
; with it.  What this does, and deliberately does not:
;
;   * ASKS first (OK / Cancel; a silent install, setup /S, answers OK).
;   * COPIES, never moves: settings\, every other sub-folder of the old install
;     (each contest keeps its log in its own folder -- "2026 ARRL-FD NY4I\" --
;     plus dom\, dvk\, dxcluster\, CallHistoryFiles\), and the loose log files
;     (*.db with its -wal and -shm, *.trw, *.cfg, *.rst, *.adi, *.cbr).  A .db
;     without its -wal loses every QSO not yet checkpointed, so the three travel
;     together.  The old folder's DATA is left exactly as it was.
;   * SKIPS the copy when $INSTDIR\settings\tr4w.json already exists, so running
;     the installer twice can never overwrite live settings with stale ones.
;   * REMOVES ONLY the old PROGRAM files (exe, .dbg, the DLLs, tr4wconvert,
;     server\tr4wserver.exe, the shortcuts) -- and only when the copy left a
;     settings folder behind.  Not the old folder, not data files.
;
; There is no uninstaller and no Add/Remove entry, so nothing else refers to the
; old program files.  The registry key HKCU\Software\TR4W is rewritten to the new
; folder by the tr4w.exe section below, and the shortcuts by the sections after.
; ---------------------------------------------------------------------------
Section "" SecMigrate
	StrCmp $OLDDIR "" mig_done
	StrCmp $OLDDIR $INSTDIR mig_done
	IfFileExists "$OLDDIR\tr4w.exe" 0 mig_done

	DetailPrint "A 32-bit TR4W was found in $OLDDIR"
	MessageBox MB_OKCANCEL|MB_ICONINFORMATION "A 32-bit TR4W was found in:$\r$\n    $OLDDIR$\r$\n$\r$\nTR4W is now 64-bit and installs to:$\r$\n    $INSTDIR$\r$\n$\r$\nYour settings, contest logs and data folders will be COPIED to the new folder, and the old program files (tr4w.exe and its DLLs) will be removed. The data left in the old folder is not touched.$\r$\n$\r$\nClose TR4W before you continue.$\r$\n$\r$\nOK to continue, Cancel to stop the installation." /SD IDOK IDOK mig_go
		Abort
mig_go:
	CreateDirectory "$INSTDIR"

	IfFileExists "$INSTDIR\settings\tr4w.json" 0 mig_copy
		DetailPrint "settings\tr4w.json already exists in $INSTDIR - not copying over it."
		Goto mig_remove

mig_copy:
	; Loose files in the old folder's top level.
	CopyFiles /SILENT "$OLDDIR\*.db"     "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.db-wal" "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.db-shm" "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.trw"    "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.cfg"    "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.rst"    "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.adi"    "$INSTDIR"
	CopyFiles /SILENT "$OLDDIR\*.cbr"    "$INSTDIR"

	; Every sub-folder except the two this installer owns outright.
	FindFirst $0 $1 "$OLDDIR\*.*"
mig_loop:
	StrCmp $1 "" mig_loopdone
	StrCmp $1 "." mig_next
	StrCmp $1 ".." mig_next
	StrCmp $1 "help" mig_next
	StrCmp $1 "server" mig_next
	IfFileExists "$OLDDIR\$1\*.*" 0 mig_next
		DetailPrint "copying $1"
		CopyFiles /SILENT "$OLDDIR\$1\*.*" "$INSTDIR\$1"
mig_next:
	FindNext $0 $1
	Goto mig_loop
mig_loopdone:
	FindClose $0

mig_remove:
	; CopyFiles does not report failure reliably, so check the one thing that
	; matters: if the old install had settings, the new folder must now have them.
	; If not, leave the old program in place rather than strand the operator.
	IfFileExists "$OLDDIR\settings\*.*" 0 mig_delete
	IfFileExists "$INSTDIR\settings\*.*" mig_delete 0
		MessageBox MB_OK|MB_ICONEXCLAMATION "The settings could not be copied to $INSTDIR.$\r$\n$\r$\nThe old TR4W in $OLDDIR has been left as it was." /SD IDOK
		Goto mig_done

mig_delete:
	Delete "$OLDDIR\tr4w.exe"
	Delete "$OLDDIR\tr4w.dbg"
	Delete "$OLDDIR\libeay32.dll"
	Delete "$OLDDIR\ssleay32.dll"
	Delete "$OLDDIR\libhamlib-4.dll"
	Delete "$OLDDIR\libgcc_s_dw2-1.dll"
	Delete "$OLDDIR\libusb-1.0.dll"
	Delete "$OLDDIR\libwinpthread-1.dll"
	Delete "$OLDDIR\sqlite3.dll"
	Delete "$OLDDIR\tr4wconvert.exe"
	Delete "$OLDDIR\server\tr4wserver.exe"
	RMDir "$OLDDIR\server"
	; The shortcuts point at the deleted exe.  The ones this installer creates
	; replace them below.
	Delete "$DESKTOP\TR4W.lnk"
	Delete "$SMPROGRAMS\TR4W\TR4W.lnk"
	Delete "$SMPROGRAMS\TR4W\history.lnk"
	DetailPrint "old 32-bit program files removed from $OLDDIR"
mig_done:
SectionEnd
!endif

Section "tr4w.exe" secexe
	SectionIn RO
	SetOutPath "$INSTDIR"
	File "${BINDIR}\tr4w.exe"
!ifdef TR4W64
	; A 64-bit install into a folder that held the 32-bit one (an in-place
	; upgrade of a custom folder) must not keep the 32-bit unwinder: it is not
	; loaded by anything now, and a wrong-architecture DLL left beside the exe
	; is exactly the 0xC000007B trap tr4w\redist\README.md describes.
	Delete "$INSTDIR\libgcc_s_dw2-1.dll"
!endif

	; SYMBOLS, WHILE WE ARE ON BENCH TESTERS (NY4I, 2026-08-16): "until we
	; go to release, we can ship the debug files with the release in the
	; installer. I might need it from our testers."
	;
	; tr4w.dbg is what turns an address in a tester's log into a file and a
	; line, and it is valid ONLY for this exact binary. ~67 MB uncompressed
	; (measured 2026-09-27; this said 46 MB, which it had not been for a
	; while -- the number is here to set an expectation about installer size,
	; so a stale one misleads about the only thing it is for).
	; A public release should be built with -ExcludeSymbols and ship without
	; it. Either way the file is ALSO attached to the GitHub release as
	; tr4w-<version>.dbg, so an emailed log can be symbolised on a machine
	; that never ran the installer -- see .github/workflows/release.yml.
!ifdef INCLUDE_SYMBOLS
	File "${BINDIR}\tr4w.dbg"
!endif
	File ..\target\r150s.dat
	File ..\target\rfobl.dat
	; inpout32.dll is intentionally NOT bundled: its kernel port-I/O driver is
	; flagged by several AV engines (hacktool/vulndriver) and was the only
	; true-positive trigger on the installer. Direct parallel-port (LPT) keying
	; is a legacy feature; users who need it supply inpout32.dll themselves
	; (next to tr4w.exe). TR4W loads it on demand only when an LPT port is
	; configured, and runs fine without it otherwise. See uIO.pas.
	File "${BINDIR}\libeay32.dll"
	File "${BINDIR}\ssleay32.dll"
	; The trusted root certificates those two are checked against. Without it
	; TR4W cannot verify any server it downloads from or uploads to, and says
	; so in the log rather than failing -- see src\utils\uTLSTrust.pas.
	; Refresh from https://curl.se/ca/cacert.pem at each release; the checksum
	; is published beside it and MUST be checked.
	File "${BINDIR}\cacert.pem"
	File "${BINDIR}\libhamlib-4.dll"
!ifdef TR4W64
	File "${BINDIR}\libgcc_s_seh-1.dll"
!else
	File "${BINDIR}\libgcc_s_dw2-1.dll"
!endif
	File "${BINDIR}\libusb-1.0.dll"
	File "${BINDIR}\libwinpthread-1.dll"
	; The contest log.  SQLITE_LOG_SCHEMA_PLAN.md section 9 said to add this line
	; "in the same commit as the first code that opens a database" -- which is
	; the commit that added src\domain\uLogDatabase.pas, so here it is.
	;
	; It ships BEFORE any menu item reaches it, deliberately.  FPC binds SQLite
	; dynamically, so a missing DLL is a run-time failure rather than a link
	; error: an installer built after the log code lands but before somebody
	; remembers this line produces a TR4W that starts normally and cannot open
	; its own log.  2.5 MB against a remembered step is not a close call, and
	; this tree's whole position is that remembered steps drift.
	;
	; IT MUST MATCH THE BUILD'S ARCHITECTURE.  BINDIR is the stage of that build, so the right one is copied; the 64-bit move
	; has to swap it.  Windows reports a mismatch as "the specified module could
	; not be found", naming a file that is present -- which is why
	; uLogDatabase.DiagnoseSQLiteLoad reads the PE header and says so.
	File "${BINDIR}\sqlite3.dll"

	; THE CONVERTER, WHICH IS THE TOOL THE UPGRADE MESSAGE AT THE END OF THIS
	; SCRIPT TELLS AN OPERATOR TO RUN.  It was not shipped until 2026-09-19,
	; which made that message unfollowable: it named a program the operator
	; did not have.  Built by FullBuild.ps1 (build\Build-Convert.ps1) into
	; target\ beside tr4w.exe.
	;
	; IT MUST LAND IN $INSTDIR, not a subfolder: it looks for settings\tr4w.json
	; beside its own binary, which is where TR4W keeps it.
	File "${BINDIR}\tr4wconvert.exe"

!ifdef TR4WLANG
!ifdef include_ini_file
	File ..\target\commands_help_${TR4WLANG}.ini
	!endif
!else
File ..\target\commands_help_eng.ini
 !endif

; ---------------------------------------------------------------------------
; HELP TEXT, ONE CATALOGUE PER LANGUAGE.
;
; The UI strings are carried INSIDE tr4w.exe (res\tr4w_languages.res, built by
; build\Make-LanguageRes.ps1). The HELP text is not, and deliberately: it is
; 2.2 MB against ~500 KB for every UI string in sixteen languages, it is read on
; demand rather than at start-up, and a wording fix should not need a rebuild.
; That split is NY4I's (2026-08-26).
;
; READ SINCE 2026-11-02: src\uCommandHelp.pas loads $INSTDIR\help\help_<code>.po
; over help_en.po and Preferences shows each bound setting's text as its
; tooltip. help_en.po MUST ship -- it is every language's fallback.
;
; The .ini above is still installed and still unread by the program; it is
; ini2po.py's authoring source. Retiring it from the payload is a separate call.
;
; EVERY CATALOGUE, BY WILDCARD (2026-11-02). This was a hand-kept list of ten,
; and it had already missed help_pl.po: a catalogue that exists and is not
; listed simply never reaches an operator, with no warning. The wildcard takes
; whatever i18n\ holds -- the Unix stage (build-unix.sh, stage_package) does the
; same -- and makensis fails the build if it matches nothing. A name is kept
; as it is on disk (help_pt_BR.po); uCommandHelp asks for that spelling.
SetOutPath "$INSTDIR\help"
   File ..\..\i18n\help_*.po
SetOutPath "$INSTDIR"


;File commands_help_rom.ini
;File commands_help_eng.ini
;File Help\TR4W_RUS.hlp
;SetOutPath "$FONTS"
;File luconsz.ttf

;Store installation folder
WriteRegStr HKCU "Software\TR4W" "" $INSTDIR

SectionEnd

Section "tr4wserver.exe" secserv
  SectionIn RO
  SetOutPath "$INSTDIR\server"
  File "${SERVERDIR}\tr4wserver.exe"
  SetOutPath "$INSTDIR"
SectionEnd

 ;Section "DLPORTIO Driver" seclpt
 ;SectionIn RO
 	;SetOutPath "$SYSDIR"
 	;File inpout32.dll
;	SetOutPath "$SYSDIR\DRIVERS"
;	File dlportio.sys
; 	SetOutPath "$INSTDIR"
 ;SectionEnd

!ifdef TR4WLANG
!If ${TR4WLANG} == "rus"
Section "tr4w_manual_rus.chm" secrusmanual
;	File tr4w_manual_rus.chm
SectionEnd
!endif
!endif

;Section /o "tr4wio.sys" Sectr4wiosys

;	SetRebootFlag false

;	ClearErrors
;	ReadRegStr $0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentVersion
;	IfErrors lbl_win98ME 0

;	IfFileExists "$SYSDIR\DRIVERS\tr4wio.sys" rebootisneed 0
;	SetRebootFlag true
;rebootisneed:

;	WriteRegDWORD HKLM ${TR4WDRVREG} "Type"          1
;	WriteRegDWORD HKLM ${TR4WDRVREG} "Start"         2
;	WriteRegDWORD HKLM ${TR4WDRVREG} "ErrorControl"  1
;	;	WriteRegStr   HKLM ${TR4WDRVREG} "ImagePath"     "SYSTEM32\DRIVERS\TR4WIO.SYS"
;	WriteRegStr   HKLM ${TR4WDRVREG} "DisplayName"   "TR4W IO Access"

;	SetOutPath "$SYSDIR\DRIVERS"
;	File tr4wio.sys

;lbl_win98ME:
;	SetOutPath "$INSTDIR"
;SectionEnd


Section /o "cluster_commands.txt" Secclustercomm
  File ..\target\cluster_commands.txt
SectionEnd

Section "TRMASTER.DTA" Sectrmaster
  File ..\target\TRMASTER.DTA
SectionEnd

 Section "cty.dat" Seccty
  ; REQUIRED, NOT OPTIONAL (NY4I, 2026-08-16).  TR4W cannot start without a
  ; country file -- it reports the missing file and terminates -- so leaving
  ; this deselectable let a user uncheck one box and install a TR4W that
  ; refuses to run.  tr4w.exe and tr4wserver.exe were already RO; this is the
  ; third file that is genuinely not optional.
  ;
  ; The copy in the repo goes stale between drops, and that is fine: it only
  ; has to be good enough to start the program.  Startup offers to fetch a
  ; current one, and Alt-O refreshes it on demand thereafter.
  SectionIn RO
  File ..\target\cty.dat
SectionEnd

;  cursor.bmp is no longer installed (2026-08-18).  It was the bitmap for
;  TR4W's own block caret in the callsign and exchange fields; those fields
;  are LCL TEdits since Phase 3b and carry their own caret, so the program no
;  longer loads the file.  The CUSTOM CARET command is csRem in uCFG.pas.
;
;  The file stays in target\ so an existing installation is unaffected; it is
;  simply not shipped to new ones.

Section "Desktop shortcut"
  CreateShortCut "$DESKTOP\TR4W.lnk" "$INSTDIR\tr4w.exe"
SectionEnd

Section "Domestic multiplier files" Secdom


  SetOutPath "$INSTDIR\dom"
   ; EVERY FILE IN target\dom, by wildcard (NY4I, 2026-10-16): a new contest
   ; adds its .dom files and touches nothing here. This list named 107 files
   ; by hand and had already drifted -- prov12.dom, which newyork.dom INCLUDEs,
   ; was never shipped. Linux and macOS ship the whole folder too. Debris
   ; (eudx.dom.new, a copy whose name was a flattened Windows path) deleted.
   File ..\target\dom\*.*
  
SectionEnd


Section "trcluster.dat" Seccluster
SetOutPath "$INSTDIR"
  File ..\target\trcluster.dat
  SectionEnd


!ifdef TR4WLANG
Section "" SecLan

;	File ..\MakeRES\${TR4WLANG}\def.h
;	File ..\tr4w_consts_${TR4WLANG}.ini
	File ..\src\lang\tr4w_consts_${TR4WLANG}.pas
SectionEnd
!endif


Section "" SecSC
  CreateDirectory "$SMPROGRAMS\TR4W"
  CreateShortCut "$SMPROGRAMS\TR4W\TR4W.lnk" "$INSTDIR\tr4w.exe" "" "$INSTDIR\tr4w.exe" 0
  CreateShortCut "$SMPROGRAMS\TR4W\history.lnk" "$INSTDIR\history.txt" "" "$INSTDIR\history.txt" 0

!ifdef TR4WLANG
	!If ${TR4WLANG} == "rus"
		CreateShortCut "$SMPROGRAMS\TR4W\TR4W Help.lnk" "$INSTDIR\tr4w_manual_rus.chm" "" "" 0
	!endif
!endif

  CreateDirectory "$INSTDIR\dxcluster"
  SetOutPath "$INSTDIR\dvk"
  SetOutPath "$INSTDIR\dvk\lettersandnumbers"
  SetOutPath "$INSTDIR\dvk\fullcallsigns"
  SetOutPath "$INSTDIR\dvk\fullserialnumbers"
  SetOutPath "$INSTDIR"
  SetOutPath "$INSTDIR\settings"

; ---------------------------------------------------------------------------
; UPGRADING FROM TR4W 4.x: SAY SO HERE, ONCE, AND ONLY TO UPGRADERS.
;
; TR4W 5 stopped reading settings\tr4w.ini at start-up altogether.  An
; operator coming from 4.x therefore has a file full of working settings that
; the program now ignores, and NOTHING in the program says so: NY4I ruled
; (2026-09-19) that the notice belongs in SETUP rather than in TR4W, because
; in-program detection "kept getting in the way and causing confusion".
;
; ONLY UPGRADERS SEE IT.  settings\tr4w.ini is what distinguishes them: TR4W 5
; neither writes that file nor reads it, so its presence in the install
; directory means an earlier version left it there.  4.x wrote it to exactly
; this path (<installdir>\settings\tr4w.ini), and the InstallDirRegKey at the
; top of this script points $INSTDIR at the existing installation on an
; upgrade.  A first-time installer has no old settings and is told nothing.
;
; WINDOWS ONLY, and that is not an omission: 4.x was Windows-only, so a
; "previous TR4W user" cannot exist on Linux or macOS.  The tarball and the
; .app bundle carry no equivalent.
;
; /SD IDOK, AFTER THE TEXT, BECAUSE A SILENT INSTALL (setup /S) STILL RUNS
; this line -- without it the run would stop on a dialog nobody can see.  NSIS
; wants /SD after the message and not beside the options; putting it with the
; options makes it the message and the message a jump label, which is the
; error "could not resolve label".  The DetailPrint is what a silent run
; leaves behind.
; ---------------------------------------------------------------------------
  IfFileExists "$INSTDIR\settings\tr4w.ini" 0 tr4wconvert_not_needed
    DetailPrint "settings\tr4w.ini from an earlier TR4W found -- see the message about tr4wconvert."
    MessageBox MB_OK|MB_ICONINFORMATION "TR4W 5 does not read your old settings file.$\r$\n$\r$\nSettings from your previous version are still here:$\r$\n    $INSTDIR\settings\tr4w.ini$\r$\n$\r$\nTR4W 5 keeps its settings in a new file and leaves that one untouched - nothing has been changed or lost, but your old setup is not in use yet.$\r$\n$\r$\nTo bring it across, do this BEFORE starting TR4W for the first time:$\r$\n$\r$\n  1. Open a Command Prompt in$\r$\n         $INSTDIR$\r$\n  2. Run:  tr4wconvert$\r$\n$\r$\nIt lists what it would change and then asks whether to apply it.  The answer defaults to No, so nothing is written unless you type Yes.  Then start TR4W.$\r$\n$\r$\nPrefer to set the station up fresh?  Skip this - TR4W 5 works either way." /SD IDOK
tr4wconvert_not_needed:

;    WriteRegStr HKCR ".TRW" "" "TR4W Log file"
	IfRebootFlag 0 noreboot
	MessageBox MB_YESNO "Reboot is required to finish the installation. Do you wish to reboot now?" IDNO noreboot
    Reboot
noreboot:

;ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentVersion
;ReadRegStr $0 HKLM Software\NSIS ""
;DetailPrint "VERSION: $R0"


SectionEnd
