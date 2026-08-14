# Builds tr4w.dpr -- the APPLICATION -- with FPC.
#
# Why this exists, given that FMX has no FPC equivalent: the golden-master
# corpus drives `tr4w.exe "<contest>.CFG" /EXPORT`, and that path boots the
# contest, writes ADIF and Cabrillo, and Halt(0)s.  It never creates a form.
# So an FPC build with the FMX units excluded can still be asked the one
# question that matters most -- does the CONTEST ENGINE compute the same bytes
# under FPC as under Delphi -- without waiting for the LCL port.
#
# The result is deliberately ENGINE-ONLY and is not shippable: the four
# settings dialogs and the two spike commands are absent (tr4w.dpr and
# MainUnit carry the {$IFNDEF FPC} guards).  Do not hand this binary to a user.
#
#   .\fpc-build-app.ps1              # full rebuild (-B), the safe default
#   .\fpc-build-app.ps1 -Incremental # recompile only what changed -- see below
#   .\fpc-build-app.ps1 -Run         # build, then print the version banner

param(
   [string] $Mode = 'delphi',
   [string] $Cpu  = 'i386',
   [string] $Os   = 'win32',
   [string] $Fpc  = 'C:\FPC\3.2.2\bin\i386-win32\fpc.exe',
   [string] $Repo = 'C:\tr4w-d12',
   [switch] $Run,
   # Drop -B.  FPC then recompiles a unit only when its source is newer than its
   # PPU, which turns the edit-run-look-at-the-log loop from ~2-3 minutes into
   # seconds -- the difference between iterating on a GUI fault and not.
   #
   # THE DEFAULT STAYS FULL, deliberately.  A stale incremental build has
   # already cost this repo two sessions once (a phantom corpus crash that was
   # nothing but out-of-date DCUs), and FPC's mtime rule cannot see a changed
   # COMPILER SWITCH, a changed .inc, or a conditional-define flip.  So:
   # incremental while chasing one defect, and a full build before believing
   # any result -- green corpus, fixed bug, anything you would commit on.
   [switch] $Incremental,
   # Extra -d defines, e.g. @('LANG_ENG','VERSIONINFO_RES'). Left empty for the
   # bare engine builds this script was written for; FullBuild.ps1 passes the
   # release set. Kept as a parameter rather than hard-coded so that the SEARCH
   # PATHS below stay defined in exactly one place -- they were already
   # duplicated once into fpc-build-tests.ps1 and a third copy would drift.
   [string[]] $Defines = @(),
   # Where the linked binary goes. FullBuild overrides this to stage a release
   # build without disturbing the developer one.
   [string] $OutExe = '',
   [string] $Laz  = 'C:\Lazarus'
)

$app = Join-Path $Repo 'tr4w'
$src = Join-Path $app  'src'
$out = Join-Path $Repo "spike\units\app-$Cpu-$Os-$Mode"
$exe = if ($OutExe -ne '') { $OutExe } else { Join-Path $out 'tr4w_fpc.exe' }

if (-not (Test-Path $Fpc))
   {
   Write-Error "FPC not found at $Fpc"
   exit 1
   }

$fpcRoot = Split-Path (Split-Path (Split-Path $Fpc -Parent) -Parent) -Parent

if (-not (Test-Path $out))
   {
   New-Item -ItemType Directory -Path $out | Out-Null
   }

$searchPaths = @(
   $src
   Join-Path $src 'trdos'
   Join-Path $src 'utils'
   Join-Path $src 'lang'
   Join-Path $src 'radioFactory'
   Join-Path $src 'rotatorFactory'
   Join-Path $src 'ui\lcl'
   # The LCL itself.  Lazarus ships an x86_64 fpc binary but carries LCL
   # units for BOTH targets, and their PPU format (207) matches
   # C:\FPC\3.2.2, so the i386 compiler consumes them directly -- no
   # cross-compiler and no Lazarus fpc needed.
   "$Laz\lcl\units\$Cpu-$Os"
   "$Laz\lcl\units\$Cpu-$Os\win32"
   "$Laz\components\lazutils\lib\$Cpu-$Os"
   "$Laz\packager\units\$Cpu-$Os"
   Join-Path $fpcRoot "units\$Cpu-$Os\regexpr"
   Join-Path $fpcRoot "units\$Cpu-$Os\fcl-json"
   Join-Path $app 'Include'
   Join-Path $app 'include\Core'
   Join-Path $app 'include\System'
   Join-Path $app 'include\Protocols'
)

# -Sc for C-style operators.  -B (rebuild everything) unless -Incremental was
# asked for; see the parameter for why full is the default.
# -WG = GUI subsystem. NOT cosmetic and NOT a guess: the shipping Delphi
# tr4w.exe has PE subsystem 2 (GUI) and FPC defaults to 3 (CONSOLE), so
# without this every launch pops a blank console window next to the real
# one. (tr4w.dproj still says <AppType>Console</AppType>; the linked binary
# says otherwise, and the binary is the authority.)
$fpcArgs = @("-M$Mode", "-P$Cpu", "-T$Os", '-Sc', '-WG', "-FU$out", "-o$exe")
if (-not $Incremental)
   {
   $fpcArgs += '-B'
   }
foreach ($d in $Defines)
   {
   $fpcArgs += "-d$d"
   }
foreach ($p in $searchPaths)
   {
   $fpcArgs += "-Fu$p"
   }
$fpcArgs += 'tr4w.dpr'

# A DESIGNED FORM IS TWO FILES AND FPC ONLY WATCHES ONE.  uPrefsForm.lfm is
# pulled in by {$R *.lfm} while uPrefsForm.pas is compiling, so editing the
# LAYOUT leaves the .pas older than its PPU and an incremental build silently
# keeps the previous resource.  That is not hypothetical: it cost a full
# edit-build-run cycle within minutes of this switch existing (2026-08-13 --
# an `Align = Left` fix that appeared not to take, because it had not).
#
# Touching the .pas is the whole fix.  It uses exactly the mtime rule FPC
# already uses, so it needs to know nothing about PPUs or resource formats.
if ($Incremental)
   {
   foreach ($lfm in Get-ChildItem -Path $src -Recurse -Filter '*.lfm')
      {
      $pas = [System.IO.Path]::ChangeExtension($lfm.FullName, '.pas')
      if (Test-Path $pas)
         {
         $pasItem = Get-Item $pas
         if ($lfm.LastWriteTime -gt $pasItem.LastWriteTime)
            {
            $pasItem.LastWriteTime = $lfm.LastWriteTime
            Write-Host "  layout newer than code -- forcing recompile of $($pasItem.Name)"
            }
         }
      }
   }

Push-Location $app
try
   {
   $output = & $Fpc @fpcArgs 2>&1
   $rc = $LASTEXITCODE
   }
finally
   {
   Pop-Location
   }

$errLines = $output | Select-String -Pattern '\bError:|\bFatal:'
$report = Join-Path $Repo "spike\app-build-$Mode.txt"
$output | Out-File -FilePath $report -Encoding utf8

# Name the build kind on every run.  An incremental result read as a full one is
# the exact mistake this switch makes easy, so it is never left to memory.
$kind = if ($Incremental) { 'INCREMENTAL (no -B)' } else { 'full (-B)' }
Write-Host "FPC application build -- $Cpu-$Os -M$Mode -- $kind"
Write-Host "errors+fatals : $($errLines.Count)"
Write-Host "full output   : $report"

if ($errLines.Count -gt 0)
   {
   Write-Host ''
   Write-Host '=== first 20 ==='
   $errLines | Select-Object -First 20 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
   }

# State the outcome explicitly -- a filtered pipeline that matches nothing
# prints nothing, which reads as success.
if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host "BUILD FAILED (exit $rc)"
   exit 1
   }

Write-Host ''
Write-Host "BUILD OK -> $exe"

if ($Run)
   {
   Write-Host ''
   & $exe /VERSION
   Write-Host "exit code = $LASTEXITCODE"
   }
