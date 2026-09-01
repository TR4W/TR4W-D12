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
Name    "TR4W v.${TR4WVERSION}"
!endif

!ifdef TR4WLANG
OutFile release\tr4w_setup_${TR4WVERSION}_${TR4WLANG}.exe
!else
OutFile release\tr4w_setup_${TR4WVERSION}.exe
!ifdef MMTTYMODE
OutFile release\tr4w_setup_${TR4WVERSION}_mmtty.exe
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
InstallDirRegKey HKCU "Software\TR4W" ""


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



Section "tr4w.exe" secexe
	SectionIn RO
	SetOutPath "$INSTDIR"
	File ..\target\tr4w.exe

	; SYMBOLS, WHILE WE ARE ON BENCH TESTERS (NY4I, 2026-08-16): "until we
	; go to release, we can ship the debug files with the release in the
	; installer. I might need it from our testers."
	;
	; tr4w.dbg is what turns an address in a tester's log into a file and a
	; line, and it is valid ONLY for this exact binary. ~46 MB uncompressed.
	; A public release should be built with -ExcludeSymbols and ship without
	; it; the file is archived beside the installer either way.
!ifdef INCLUDE_SYMBOLS
	File ..\target\tr4w.dbg
!endif
	File ..\target\r150s.dat
	File ..\target\rfobl.dat
	; inpout32.dll is intentionally NOT bundled: its kernel port-I/O driver is
	; flagged by several AV engines (hacktool/vulndriver) and was the only
	; true-positive trigger on the installer. Direct parallel-port (LPT) keying
	; is a legacy feature; users who need it supply inpout32.dll themselves
	; (next to tr4w.exe). TR4W loads it on demand only when an LPT port is
	; configured, and runs fine without it otherwise. See uIO.pas.
	File ..\target\libeay32.dll
	File ..\target\ssleay32.dll
	File ..\target\libhamlib-4.dll
	File ..\target\libgcc_s_dw2-1.dll
	File ..\target\libusb-1.0.dll
	File ..\target\libwinpthread-1.dll
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
	; IT MUST MATCH THE BUILD'S ARCHITECTURE.  This one is i386; the 64-bit move
	; has to swap it.  Windows reports a mismatch as "the specified module could
	; not be found", naming a file that is present -- which is why
	; uLogDatabase.DiagnoseSQLiteLoad reads the PE header and says so.
	File ..\target\sqlite3.dll

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
; NOTHING READS THESE YET. uOption.pas -- the Ctrl-J dialog that displayed
; per-command help from commands_help_<LANG>.ini -- was deleted in 4321ce1d, and
; Preferences has no help pane. The catalogues are installed so the pane can be
; built without waiting on a release, and so a translator's work has somewhere
; to land. Delete this block and the SetOutPath below to stop shipping them.
;
; The .ini above is the same story one step further back: it is still installed,
; still unread, and retires when the pane arrives reading these instead.
SetOutPath "$INSTDIR\help"
   File ..\..\i18n\help_cs.po
   File ..\..\i18n\help_de.po
   File ..\..\i18n\help_en.po
   File ..\..\i18n\help_es.po
   File ..\..\i18n\help_fr.po
   File ..\..\i18n\help_it.po
   File ..\..\i18n\help_nl.po
   File ..\..\i18n\help_ro.po
   File ..\..\i18n\help_ru.po
   File ..\..\i18n\help_uk.po
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
  File ..\tr4wserver\tr4wserver.exe
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

;  SetOutPath "$INSTDIR\Plugins"
;  File Plugins\tr4wSortLog.dll

  SetOutPath "$INSTDIR\dom"
   File ..\target\dom\alaska.dom
   File ..\target\dom\allja.dom
   File ..\target\dom\ari.dom
   File ..\target\dom\arizona.dom
   File ..\target\dom\arizona_cty.dom
   File ..\target\dom\arrl10.dom
   File ..\target\dom\arrlsect.dom
   File ..\target\dom\brazil.dom
   File ..\target\dom\california.dom
   File ..\target\dom\california_cty.dom
   File ..\target\dom\cis.dom
   File ..\target\dom\colorado.dom
   File ..\target\dom\colorado_cty.dom
   File ..\target\dom\croat.dom
    File ..\target\dom\dc.dom
   File ..\target\dom\delaware_cty.dom
   File ..\target\dom\ea.dom
   File ..\target\dom\eudx.dom
   File ..\target\dom\florida.dom
   File ..\target\dom\florida_cty.dom
   File ..\target\dom\gc.dom
   File ..\target\dom\grids.dom
   File ..\target\dom\hawaii.dom
   File ..\target\dom\hungary.dom
   File ..\target\dom\iaruhq.dom
   File ..\target\dom\in7qpne.dom
   File ..\target\dom\in7qpne_cty.dom
   File ..\target\dom\illinois_cty.dom
   File ..\target\dom\in.dom
   File ..\target\dom\in_cty.dom
   File ..\target\dom\ireland.dom
   File ..\target\dom\jacg3.dom
   File ..\target\dom\japref.dom
   File ..\target\dom\japrefct.dom
   File ..\target\dom\jidx.dom
   File ..\target\dom\kda.dom
   File ..\target\dom\lz.dom
   File ..\target\dom\mexico.dom
   File ..\target\dom\michigan.dom
   File ..\target\dom\michigan_cty.dom
   File ..\target\dom\minnesota.dom
   File ..\target\dom\minnesota_cty.dom
   File ..\target\dom\missouri.dom
   File ..\target\dom\missouri_cty.dom
   File ..\target\dom\naqp.dom
   File ..\target\dom\nc.dom
   File ..\target\dom\nc_cty.dom
   File ..\target\dom\neqso.dom
   File ..\target\dom\neqsow1.dom
   File ..\target\dom\nevada_cty.dom
   File ..\target\dom\newyork.dom
   File ..\target\dom\newyork_cty.dom
   File ..\target\dom\nrau.dom
   File ..\target\dom\ohio.dom
   File ..\target\dom\ohio_cty.dom
   File ..\target\dom\okom.dom
   File ..\target\dom\p12.dom
   File ..\target\dom\p13.dom
   File ..\target\dom\p14.dom
   File ..\target\dom\p8.dom
   File ..\target\dom\pa.dom
   File ..\target\dom\pa_cty.dom
   File ..\target\dom\pacc.dom
   File ..\target\dom\paccpa.dom
   File ..\target\dom\pmc.dom
   File ..\target\dom\ref.dom
   File ..\target\dom\romania.dom
   File ..\target\dom\rsgb.dom
   File ..\target\dom\russian.dom
   File ..\target\dom\s48.dom
   File ..\target\dom\s48p14dc.dom
   File ..\target\dom\s49p13.dom
   File ..\target\dom\s49p13dc.dom
   File ..\target\dom\s49p8.dom
   File ..\target\dom\s50.dom
   File ..\target\dom\s50p12.dom
   File ..\target\dom\s50p13.dom
   File ..\target\dom\s50p13dc.dom
   File ..\target\dom\s50p14dc.dom
   File ..\target\dom\s51.dom
   File ..\target\dom\seven.dom
   File ..\target\dom\seven_cty.dom
   File ..\target\dom\spdx.dom
   File ..\target\dom\swiss.dom
   File ..\target\dom\tennessee.dom
   File ..\target\dom\tennessee_cty.dom
   File ..\target\dom\texas.dom
   File ..\target\dom\texas_cty.dom
   File ..\target\dom\uba.dom
   File ..\target\dom\uk-ei.dom
   File ..\target\dom\ukraine.dom
   File ..\target\dom\washington.dom
   File ..\target\dom\washington_cty.dom
   File ..\target\dom\wisconsin.dom
   File ..\target\dom\wisconsin_cty.dom
   File ..\target\dom\yu.dom
   File ..\target\dom\ve7.dom
   File ..\target\dom\ve7_cty.dom
   File ..\target\dom\mwc.dom
   File ..\target\dom\va.dom
   File ..\target\dom\va_cty.dom
   File ..\target\dom\yota.dom
  
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

;    WriteRegStr HKCR ".TRW" "" "TR4W Log file"
	IfRebootFlag 0 noreboot
	MessageBox MB_YESNO "Reboot is required to finish the installation. Do you wish to reboot now?" IDNO noreboot
    Reboot
noreboot:

;ReadRegStr $R0 HKLM "SOFTWARE\Microsoft\Windows NT\CurrentVersion" CurrentVersion
;ReadRegStr $0 HKLM Software\NSIS ""
;DetailPrint "VERSION: $R0"


SectionEnd
