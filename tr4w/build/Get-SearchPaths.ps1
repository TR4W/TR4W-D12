# The unit search paths, defined ONCE. Dot-source it; it defines
# Get-Tr4wSearchPaths.
#
# WHY THIS EXISTS.  The same list was written out three times -- in the app
# build, the unit-test build, and the server block of FullBuild -- and it had
# already drifted: rotatorFactory was present in one and missing from another.
# That class of drift does not announce itself; it surfaces as "can't find unit"
# in whichever build was forgotten, days later, usually to whoever did not make
# the change.
#
# THREE TARGETS, NOT ONE LIST.  They genuinely differ and pretending otherwise
# would be worse than duplication:
#
#   App    -- everything, including ui\lcl and the LCL itself.
#   Tests  -- the same, and ui\lcl must come BEFORE src: uSettingsBinding exists
#             in both, one binding FMX controls and one binding LCL ones, and
#             the test project names neither explicitly, so search ORDER is the
#             only thing choosing. (tr4w.dpr picks correctly with {$IFDEF FPC}.)
#   Server -- no LCL and no ui\ at all. tr4wserver is a console program; adding
#             the LCL would link a widgetset into something with no UI.

# ---------------------------------------------------------------------------
# INCLUDE paths -- a SEPARATE list from the unit paths, and it has to be.
#
# FPC resolves {$I foo.inc} from the INCLUDING FILE'S OWN DIRECTORY and then
# from -Fi.  It does NOT search -Fu.  So a unit that lives in one directory and
# includes a file from another needs -Fi, and no amount of unit path fixes it.
#
# WHY IT APPEARED.  Log4D.pas moved from src\ to include\ (e3e44888).  Its
# second line is {$I tr4w.inc}, and tr4w.inc is in src\ -- so from its new home
# the include stopped resolving and every FPC build through these scripts died
# with:
#
#     Log4D.pas(2,2) Fatal: Cannot open include file "tr4w.inc"
#
# That commit updated tr4w.dpr, tr4w.dproj and tr4w.lpi -- the IDE and Delphi
# paths -- and no build\*.ps1, which is the PACKAGING path.  The Lazarus project
# kept working, so nothing surfaced it until the next command-line build.
#
# ONE LIST FOR EVERY TARGET, deliberately: unlike the unit paths, App, Tests and
# Server have no reason to disagree about where an .inc lives, and giving them
# three chances to drift would repeat the mistake the header above describes.
# MAKE "FULL REBUILD" MEAN WHAT EVERYONE ALREADY ASSUMES IT MEANS.
#
# -B rebuilds the modules FPC decides to compile. It does not make FPC decide to
# compile a module whose .ppu looks current, and staleness is judged on MTIME --
# which is not a valid test across a rename.
#
# That is how a broken tree passed every gate on 2026-08-26. `git mv` moved
# Log4D.pas from src\ to include\ and, being a rename, KEPT ITS MTIME: the source
# read Aug 13, the .ppu from an earlier build read Aug 26. Newer artifact than
# source, so FPC reused it and never compiled the file from its new home. App,
# tests, lints and the corpus were all green against a unit that could not
# actually compile -- `Log4D.pas(2,2) Fatal: Cannot open include file "tr4w.inc"`.
#
# The same commit failed loudly in another worktree, because a CHECKOUT writes
# the file and resets its mtime where a rename does not. Same source, same
# compiler, opposite results, decided entirely by how the file arrived.
#
# CLAUDE.md already warns FPC's mtime rule cannot see a changed switch, a changed
# .inc or a define flip. This is the fourth case and the worst of them, because
# the stale artifact is USABLE -- the others fail, this one succeeds and lies.
#
# So a full build clears the compiled artifacts first. It costs nothing (-B was
# going to recompile them anyway) and it closes moves, renames and deletions
# together rather than needing a rule for each.
#
# THE LINKED BINARY IS LEFT ALONE, deliberately. It is not an input to the
# compile, and NY4I runs build-out\app-i386-win32\tr4w_fpc.exe directly -- if a
# build fails he should still have the last one that worked, rather than nothing.
function Clear-Tr4wUnitOutput
   {
   param(
      [Parameter(Mandatory = $true)][string] $OutDir
   )

   if (-not (Test-Path $OutDir)) { return 0 }

   $stale = @(Get-ChildItem -Path $OutDir -File -ErrorAction SilentlyContinue |
      Where-Object { $_.Extension -in '.ppu', '.o', '.a', '.rsj', '.rst', '.lfm' })
   foreach ($f in $stale) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
   return $stale.Count
   }


function Get-Tr4wIncludePaths
   {
   param(
      [Parameter(Mandatory = $true)] [string] $Tr4wDir
   )

   $paths = [System.Collections.Generic.List[string]]::new()
   # src holds tr4w.inc, which every unit in the tree includes.
   $paths.Add((Join-Path $Tr4wDir 'src'))
   # include\ holds the vendored Indy .inc files, beside the units that use them.
   $paths.Add((Join-Path $Tr4wDir 'include'))
   return $paths
   }

function Get-Tr4wSearchPaths
   {
   param(
      [Parameter(Mandatory = $true)] [string] $Tr4wDir,
      [Parameter(Mandatory = $true)] $Toolchain,
      [Parameter(Mandatory = $true)] [ValidateSet('App', 'Tests', 'Server')] [string] $For,
      # Only meaningful for Tests -- the unit-test project directory, which must
      # be searched first so its own suites are found before anything in src.
      [string] $TestDir = ''
   )

   $src = Join-Path $Tr4wDir 'src'
   $cpu = $Toolchain.Cpu
   $os  = $Toolchain.Os
   $laz = $Toolchain.LazDir

   $paths = [System.Collections.Generic.List[string]]::new()

   if ($For -eq 'Tests' -and $TestDir)
      {
      $paths.Add($TestDir)
      }

   # ui\lcl BEFORE src -- see the header. Harmless for the app (tr4w.dpr names
   # its units with explicit paths) and load-bearing for the tests.
   if ($For -ne 'Server')
      {
      $paths.Add((Join-Path $src 'ui\lcl'))
      }

   $paths.Add($src)
   $paths.Add((Join-Path $src 'trdos'))
   $paths.Add((Join-Path $src 'utils'))
   $paths.Add((Join-Path $src 'lang'))
   $paths.Add((Join-Path $src 'domain'))
   $paths.Add((Join-Path $src 'radioFactory'))
   $paths.Add((Join-Path $src 'rotatorFactory'))

   if ($For -ne 'Server')
      {
      # Lazarus ships an x86_64 fpc binary but carries LCL units for BOTH
      # targets, and their PPU format matches FPC 3.2.2, so the i386 compiler
      # consumes them directly -- no cross-compiler and no Lazarus fpc needed.
      $paths.Add((Join-Path $laz "lcl\units\$cpu-$os"))
      $paths.Add((Join-Path $laz "lcl\units\$cpu-$os\$os"))
      $paths.Add((Join-Path $laz "components\lazutils\lib\$cpu-$os"))
      $paths.Add((Join-Path $laz "packager\units\$cpu-$os"))
      # TDateTimePicker for the Edit QSO date/time field. Lazarus ships
      # datetimectrls but prebuilds it for x86_64 only, so this is the SOURCE
      # directory -- FPC compiles datetimepicker.pas for i386 into our own
      # output dir. Derived from LAZARUS_DIR like everything else above, so a
      # fresh clone still builds.
      $paths.Add((Join-Path $laz 'components\datetimectrls'))
      }

   # regexpr supplies TRegExpr, which uRegex.pas uses in place of TPerlRegEx --
   # the vendored PCRE library is twenty Borland-format .obj files and FPC's
   # linker cannot read them.
   $paths.Add((Join-Path $Toolchain.FpcRoot "units\$cpu-$os\regexpr"))
   # fcl-json supplies fpjson/jsonparser, which uJSON.pas shims onto the
   # System.JSON spellings the config stores are written against.
   $paths.Add((Join-Path $Toolchain.FpcRoot "units\$cpu-$os\fcl-json"))

   # Vendored Indy 10.6.3.3 -- kept deliberately; D12 ships Indy as DCUs only.
   $paths.Add((Join-Path $Tr4wDir 'Include'))
   $paths.Add((Join-Path $Tr4wDir 'include\Core'))
   $paths.Add((Join-Path $Tr4wDir 'include\System'))
   $paths.Add((Join-Path $Tr4wDir 'include\Protocols'))

   return $paths
   }
