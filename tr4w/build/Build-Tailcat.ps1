# Build-Tailcat.ps1 -- build libtailcat.dll (x86_64) from the pinned upstream
# commit, and stage it where the 64-bit app build picks its runtime DLLs up.
#
#   .\tr4w\build\Build-Tailcat.ps1            build, or say "up to date"
#   .\tr4w\build\Build-Tailcat.ps1 -Force     build even when up to date
#   .\tr4w\build\Build-Tailcat.ps1 -Jobs 2    fewer parallel compiles (less memory)
#
# WHY IT IS BUILT AND NOT COMMITTED (issue 293; NY4I, 2026-11-12). The library is
# Tailscale's Tailcat with a Go runtime inside it, about 20 MB. A binary that size
# in git is paid for by every clone for ever, and nobody can tell from the file
# what it was built from. Built here, the answer is tr4w\build\tailcat.pin.
#
# WHAT IT NEEDS ON THE MACHINE
#   git     to fetch the source
#   gcc     an x86_64 MinGW-w64 on PATH (cgo cannot use MSVC). Set TAILCAT_CC to
#           name one explicitly; this machine's PATH also holds FPC's i386 gcc,
#           and the script refuses a compiler that does not target x86_64.
#   Go      NOT needed beforehand. A `go` on PATH is used when it is EXACTLY the
#           pinned version; otherwise the official archive is downloaded, checked
#           against the sha256 in tailcat.pin and unpacked under build-out\.
#   network github.com (the source), go.dev (the toolchain, first run only) and
#           proxy.golang.org (the modules, first run only).
#
# WHERE THINGS GO. Everything it makes is under <repo>\build-out\tailcat\, which
# is gitignored with the rest of build-out:
#   toolchain\go<version>\      the Go toolchain, when it had to be downloaded
#   src\                        the upstream checkout
#   gopath\  gocache\           Go's module and build caches (nothing is written
#                               to the user profile)
#   x86_64-win64\libtailcat.dll          the result
#   x86_64-win64\libtailcat.built.txt    what it was built from (the cache key)
#   x86_64-win64\libtailcat-NOTICES.txt  the licence of every module linked in
# and the DLL alone is then copied to tr4w\redist\x86_64-win64\, from where
# Build-App.ps1 stages every *.dll beside the 64-bit exe.
#
# IT FAILS CLOSED. A checkout that is not the pinned commit, a toolchain archive
# whose checksum differs, a linked module with no licence file, or an output that
# is not an x86_64 PE each stop the script with a non-zero exit and no DLL staged.

param(
   [switch] $Force,
   [int]    $Jobs = 0,
   [string] $RedistDir = ''
)

$ErrorActionPreference = 'Stop'

$TR4W_DIR  = Split-Path $PSScriptRoot -Parent
$REPO_ROOT = Split-Path $TR4W_DIR -Parent
$WORK      = Join-Path $REPO_ROOT 'build-out\tailcat'
$TARGET    = 'x86_64-win64'
$OUT_DIR   = Join-Path $WORK $TARGET
$DLL       = Join-Path $OUT_DIR 'libtailcat.dll'
$STAMP     = Join-Path $OUT_DIR 'libtailcat.built.txt'
$NOTICES   = Join-Path $OUT_DIR 'libtailcat-NOTICES.txt'
$SRC       = Join-Path $WORK 'src'

if ($RedistDir -eq '')
   {
   $RedistDir = Join-Path $TR4W_DIR "redist\$TARGET"
   }
$STAGED = Join-Path $RedistDir 'libtailcat.dll'

function Fail
   {
   param([string] $Text)

   Write-Host "Build-Tailcat: FAILED: $Text" -ForegroundColor Red
   exit 1
   }

# ---------------------------------------------------------------------------
# The pin file.
# ---------------------------------------------------------------------------
function Read-TailcatPin
   {
   param([string] $Path)

   $pin = @{}
   foreach ($line in Get-Content -LiteralPath $Path)
      {
      $text = $line.Trim()
      if (($text -eq '') -or $text.StartsWith('#'))
         {
         continue
         }
      $at = $text.IndexOf('=')
      if ($at -lt 1)
         {
         Fail "tailcat.pin: not KEY=VALUE: $text"
         }
      $pin[$text.Substring(0, $at)] = $text.Substring($at + 1)
      }
   foreach ($key in @('TAILCAT_REPO', 'TAILCAT_COMMIT', 'GO_VERSION', 'GO_SHA256_WINDOWS_AMD64'))
      {
      if (-not $pin.ContainsKey($key) -or ($pin[$key] -eq ''))
         {
         Fail "tailcat.pin: $key is missing"
         }
      }
   if ($pin['TAILCAT_COMMIT'] -notmatch '^[0-9a-f]{40}$')
      {
      Fail 'tailcat.pin: TAILCAT_COMMIT must be a full 40-character commit id, not a tag or a branch'
      }
   return $pin
   }

# The machine word of a PE file: 0x8664 is x86_64, 0x014C is i386.
function Get-PEMachine
   {
   param([string] $Path)

   $stream = [IO.File]::OpenRead($Path)
   try
      {
      $reader = New-Object IO.BinaryReader($stream)
      if ($reader.ReadUInt16() -ne 0x5A4D)
         {
         return 0
         }
      $stream.Position = 0x3C
      $stream.Position = $reader.ReadUInt32()
      if ($reader.ReadUInt32() -ne 0x00004550)
         {
         return 0
         }
      return [int] $reader.ReadUInt16()
      }
   finally
      {
      $stream.Dispose()
      }
   }

function Get-Sha256
   {
   param([string] $Path)

   return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
   }

# Run a program and stop on a non-zero exit. Its output is NOT redirected: Go and
# git write progress to stderr, and Windows PowerShell turns redirected stderr
# into error records, which $ErrorActionPreference = 'Stop' then throws on.
function Invoke-Checked
   {
   param([string] $What, [string] $Exe, [string[]] $Arguments)

   & $Exe @Arguments
   if ($LASTEXITCODE -ne 0)
      {
      Fail "$What (exit $LASTEXITCODE)"
      }
   }

function Show-Result
   {
   param([string] $Path)

   $machine = Get-PEMachine -Path $Path
   Write-Host ("   file     {0}" -f $Path)
   Write-Host ("   bytes    {0}" -f (Get-Item -LiteralPath $Path).Length)
   Write-Host ("   sha256   {0}" -f (Get-Sha256 -Path $Path))
   Write-Host ("   machine  0x{0:X4}" -f $machine)
   }

# ---------------------------------------------------------------------------
# Up to date?  The stamp is the cache key: same commit, same Go, same tags, and
# the staged DLL is byte for byte the one that build produced.
# ---------------------------------------------------------------------------
$pin    = Read-TailcatPin -Path (Join-Path $PSScriptRoot 'tailcat.pin')
$commit = $pin['TAILCAT_COMMIT']
$goVer  = $pin['GO_VERSION']

Write-Host "Build-Tailcat: tailcat $commit, Go $goVer, target $TARGET"

function Test-UpToDate
   {
   if (-not (Test-Path -LiteralPath $STAMP) -or
       -not (Test-Path -LiteralPath $DLL) -or
       -not (Test-Path -LiteralPath $NOTICES) -or
       -not (Test-Path -LiteralPath $STAGED))
      {
      return $false
      }
   $recorded = @{}
   foreach ($line in Get-Content -LiteralPath $STAMP)
      {
      $at = $line.IndexOf('=')
      if ($at -gt 0)
         {
         $recorded[$line.Substring(0, $at)] = $line.Substring($at + 1)
         }
      }
   if (($recorded['commit'] -ne $commit) -or ($recorded['go'] -ne $goVer))
      {
      return $false
      }
   $sha = Get-Sha256 -Path $DLL
   return ($recorded['sha256'] -eq $sha) -and ((Get-Sha256 -Path $STAGED) -eq $sha)
   }

if (-not $Force -and (Test-UpToDate))
   {
   Write-Host 'Build-Tailcat: up to date, nothing built.'
   Show-Result -Path $STAGED
   exit 0
   }

# ---------------------------------------------------------------------------
# The tools.
# ---------------------------------------------------------------------------
$git = Get-Command git -ErrorAction SilentlyContinue
if ($null -eq $git)
   {
   Fail 'git is not on PATH'
   }

$cc = $env:TAILCAT_CC
if ([string]::IsNullOrEmpty($cc))
   {
   $found = Get-Command gcc -ErrorAction SilentlyContinue
   if ($null -eq $found)
      {
      Fail 'no gcc on PATH. cgo needs an x86_64 MinGW-w64 gcc; put one on PATH or name it in TAILCAT_CC.'
      }
   $cc = $found.Source
   }
$ccMachine = (& $cc -dumpmachine | Select-Object -First 1)
if ($ccMachine -notmatch '^x86_64-')
   {
   Fail "the C compiler $cc targets '$ccMachine', not x86_64. Name an x86_64 MinGW-w64 gcc in TAILCAT_CC."
   }
Write-Host "   cc       $cc ($ccMachine)"

# Go: the one on PATH only when it is exactly the pinned version.
$go = ''
$onPath = Get-Command go -ErrorAction SilentlyContinue
if ($null -ne $onPath)
   {
   $said = (& $onPath.Source version | Select-Object -First 1)
   if ($said -eq "go version go$goVer windows/amd64")
      {
      $go = $onPath.Source
      }
   }
if ($go -eq '')
   {
   $toolRoot = Join-Path $WORK "toolchain\go$goVer"
   $go       = Join-Path $toolRoot 'go\bin\go.exe'
   if (-not (Test-Path -LiteralPath $go))
      {
      $archive = "go$goVer.windows-amd64.zip"
      $zip     = Join-Path $WORK "toolchain\$archive"
      New-Item -ItemType Directory -Force -Path $toolRoot | Out-Null
      Write-Host "   downloading https://go.dev/dl/$archive"
      $ProgressPreference = 'SilentlyContinue'
      Invoke-WebRequest -Uri "https://go.dev/dl/$archive" -OutFile $zip -UseBasicParsing
      $got = Get-Sha256 -Path $zip
      if ($got -ne $pin['GO_SHA256_WINDOWS_AMD64'].ToLowerInvariant())
         {
         Remove-Item -LiteralPath $zip -Force
         Fail "$archive has sha256 $got, tailcat.pin says $($pin['GO_SHA256_WINDOWS_AMD64'])"
         }
      # tar.exe ships with Windows 10 and later and reads a zip far faster than
      # Expand-Archive does for the twelve thousand files in a Go toolchain.
      Invoke-Checked -What "unpacking $archive" -Exe 'tar.exe' -Arguments @('-xf', $zip, '-C', $toolRoot)
      Remove-Item -LiteralPath $zip -Force
      }
   }
Write-Host "   go       $go"

# ---------------------------------------------------------------------------
# The source, at exactly the pinned commit.
# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath (Join-Path $SRC '.git')))
   {
   New-Item -ItemType Directory -Force -Path $WORK | Out-Null
   Invoke-Checked -What 'git clone' -Exe $git.Source -Arguments @('clone', '--quiet', '--no-checkout', $pin['TAILCAT_REPO'], $SRC)
   }

$have = (& $git.Source -C $SRC rev-parse --verify --quiet "$commit^{commit}" | Select-Object -First 1)
if ($have -ne $commit)
   {
   Invoke-Checked -What 'git fetch' -Exe $git.Source -Arguments @('-C', $SRC, 'fetch', '--quiet', 'origin')
   }
# --force: a previous run's checkout is ours to replace, and nothing else is
# ever edited in this directory.
Invoke-Checked -What "git checkout $commit" -Exe $git.Source -Arguments @('-C', $SRC, 'checkout', '--quiet', '--force', '--detach', $commit)

$head = (& $git.Source -C $SRC rev-parse HEAD | Select-Object -First 1)
if ($head -ne $commit)
   {
   Fail "the checkout is at '$head', not the pinned $commit"
   }
$dirty = @(& $git.Source -C $SRC status --porcelain)
if ($dirty.Count -ne 0)
   {
   Fail "the checkout in $SRC has local changes; delete the directory and run again"
   }
Write-Host "   source   $SRC at $head"

# ---------------------------------------------------------------------------
# The build. These are upstream's own release settings (its build-tags.md):
# the ts_omit_ tags drop the Tailscale features Tailcat does not use, and
# -s -w drops the symbol and DWARF tables. -trimpath keeps this machine's
# directory names out of the binary.
# ---------------------------------------------------------------------------
$tagsFile = Join-Path $SRC 'build-tags.txt'
if (-not (Test-Path -LiteralPath $tagsFile))
   {
   Fail 'upstream build-tags.txt is missing at the pinned commit'
   }
$tags = (Get-Content -LiteralPath $tagsFile -Raw).Trim()

New-Item -ItemType Directory -Force -Path $OUT_DIR | Out-Null
foreach ($old in @($DLL, $STAMP, $NOTICES, (Join-Path $OUT_DIR 'libtailcat.h')))
   {
   if (Test-Path -LiteralPath $old)
      {
      Remove-Item -LiteralPath $old -Force
      }
   }

$env:CGO_ENABLED = '1'
$env:GOOS        = 'windows'
$env:GOARCH      = 'amd64'
$env:CC          = $cc
$env:GOTOOLCHAIN = 'local'            # never fetch a different Go behind our back
$env:GOFLAGS     = '-mod=readonly'    # go.sum decides; the build may not edit it
$env:GOPATH      = Join-Path $WORK 'gopath'
$env:GOCACHE     = Join-Path $WORK 'gocache'

$buildArgs = @('build', '-buildmode=c-shared', '-trimpath', '-ldflags=-s -w', '-tags', $tags)
if ($Jobs -gt 0)
   {
   $buildArgs += @('-p', "$Jobs")
   }
$buildArgs += @('-o', $DLL, './cmd/libtailcat')

$clock = [Diagnostics.Stopwatch]::StartNew()
Push-Location $SRC
try
   {
   Invoke-Checked -What 'go build' -Exe $go -Arguments $buildArgs
   }
finally
   {
   Pop-Location
   }
$clock.Stop()
Write-Host ("   built in {0:N0} s" -f $clock.Elapsed.TotalSeconds)

if (-not (Test-Path -LiteralPath $DLL))
   {
   Fail 'go build reported success and wrote no DLL'
   }
$machine = Get-PEMachine -Path $DLL
if ($machine -ne 0x8664)
   {
   Fail ("the DLL's PE machine is 0x{0:X4}, not 0x8664 (x86_64)" -f $machine)
   }

# ---------------------------------------------------------------------------
# The notices. The DLL is Tailcat PLUS every Go module linked into it, and each
# of those licences asks for its text to travel with a binary. The list is read
# out of the DLL itself (`go version -m`), so it is what was linked and not what
# go.mod mentions; the texts come from the module cache this build just used.
# ---------------------------------------------------------------------------
$modCache = Join-Path $env:GOPATH 'pkg\mod'
$goRoot   = (& $go env GOROOT | Select-Object -First 1)
$isLicence = '^(LICEN[CS]E|COPYING|NOTICE|PATENTS|AUTHORS|COPYRIGHT)([.-].*)?$'

# The module cache spells an upper-case letter as "!" and its lower-case form.
function Get-ModuleCacheDir
   {
   param([string] $Module, [string] $Version)

   $escaped = [regex]::Replace($Module, '[A-Z]', { param($m) '!' + $m.Value.ToLowerInvariant() })
   $escapedVersion = [regex]::Replace($Version, '[A-Z]', { param($m) '!' + $m.Value.ToLowerInvariant() })
   return (Join-Path $modCache (($escaped + '@' + $escapedVersion) -replace '/', '\'))
   }

$out = New-Object Text.StringBuilder
[void] $out.AppendLine('libtailcat -- third-party notices')
[void] $out.AppendLine('')
[void] $out.AppendLine("libtailcat is Tailscale's Tailcat (" + $pin['TAILCAT_REPO'] + ')')
[void] $out.AppendLine("built from commit $commit with Go $goVer for $TARGET.")
[void] $out.AppendLine('It contains the Go runtime and the modules listed below. The licence text of')
[void] $out.AppendLine('each follows, as its authors published it.')
[void] $out.AppendLine('')

$sections = New-Object Collections.ArrayList
[void] $sections.Add(@{ Name = 'github.com/tailscale/tailcat ' + $commit; Dir = $SRC })
[void] $sections.Add(@{ Name = "Go $goVer (runtime and standard library)"; Dir = $goRoot })

$missing = @()
foreach ($line in (& $go version -m $DLL))
   {
   $fields = $line.Trim() -split "`t"
   if (($fields.Count -lt 3) -or (($fields[0] -ne 'dep') -and ($fields[0] -ne '=>')))
      {
      continue
      }
   if ($fields[0] -eq '=>')
      {
      # A replaced module: the replacement is what was linked. Drop the entry it
      # replaces, which was added on the line before.
      $sections.RemoveAt($sections.Count - 1)
      }
   [void] $sections.Add(@{ Name = $fields[1] + ' ' + $fields[2]; Dir = (Get-ModuleCacheDir -Module $fields[1] -Version $fields[2]) })
   }
if ($sections.Count -lt 3)
   {
   Fail '`go version -m` listed no modules in the DLL, so the notices cannot be written'
   }

foreach ($section in $sections)
   {
   [void] $out.AppendLine('=' * 78)
   [void] $out.AppendLine($section.Name)
   [void] $out.AppendLine('=' * 78)
   $files = @()
   if (Test-Path -LiteralPath $section.Dir)
      {
      $files = @(Get-ChildItem -LiteralPath $section.Dir -File | Where-Object { $_.Name -match $isLicence } | Sort-Object Name)
      }
   if ($files.Count -eq 0)
      {
      $missing += $section.Name
      continue
      }
   foreach ($file in $files)
      {
      [void] $out.AppendLine('')
      [void] $out.AppendLine('--- ' + $file.Name + ' ---')
      [void] $out.AppendLine('')
      [void] $out.AppendLine(([IO.File]::ReadAllText($file.FullName)).TrimEnd())
      }
   [void] $out.AppendLine('')
   }
if ($missing.Count -ne 0)
   {
   Fail ('no licence file found for: ' + ($missing -join ', ') + '. The DLL is not staged; a binary may not ship without them.')
   }
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($NOTICES, $out.ToString(), $utf8)
Write-Host ("   notices  {0} ({1} modules)" -f $NOTICES, $sections.Count)

# ---------------------------------------------------------------------------
# Stamp it, then stage the DLL. The stamp is written first so a failed copy is
# a build that is not up to date, never a staged DLL nobody can account for.
# ---------------------------------------------------------------------------
$sha = Get-Sha256 -Path $DLL
$stampText = @(
   "commit=$commit",
   "repo=$($pin['TAILCAT_REPO'])",
   "go=$goVer",
   "target=$TARGET",
   "cc=$ccMachine",
   "sha256=$sha"
) -join "`r`n"
[IO.File]::WriteAllText($STAMP, $stampText + "`r`n", $utf8)

New-Item -ItemType Directory -Force -Path $RedistDir | Out-Null
Copy-Item -LiteralPath $DLL -Destination $STAGED -Force
if ((Get-Sha256 -Path $STAGED) -ne $sha)
   {
   Fail "the copy in $RedistDir does not match the DLL that was built"
   }

Write-Host 'Build-Tailcat: BUILD OK'
Show-Result -Path $STAGED
exit 0
