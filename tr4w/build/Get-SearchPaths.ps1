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
