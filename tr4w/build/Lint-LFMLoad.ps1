# Gates the build on every .lfm actually STREAMING through the LCL's loader.
#
# WHY THIS EXISTS BESIDE Lint-LFMProperties, which asks a very similar
# question and asks it statically.
#
# 5.0.20 and 5.0.21 shipped a Preferences window that could not be opened:
#
#    EReadError: Error reading btnOK.AnchorSideRight.Side: Invalid value
#    for property
#
# The .lfm said `asrLeft`, which controls.pp declares as a CONSTANT
# (asrLeft = asrTop), not as a member of TAnchorSideReference. It reads
# perfectly in Pascal and cannot exist in an .lfm, which streams an enum BY
# NAME. Lint-LFMProperties reported that same commit clean -- it does not
# value-check DOTTED properties, which is now fixed -- and the layout was
# checked by rebuilding the button row in code, which never touches the .lfm.
#
# Two green checks, and neither had asked the loader anything. This one asks
# the loader: ObjectTextToBinary + TReader, the same code path the running
# program takes. See build\lfmload\lfmload.lpr for the two substitutions it
# makes (root class, event addresses) and why neither weakens the answer.
#
# FAILS CLOSED, like its sibling: no toolchain, no forms found, or a checker
# that will not build all exit non-zero. A lint that cannot run must not look
# like a lint that found nothing.
#
#   powershell -File tr4w\build\Lint-LFMLoad.ps1
#   powershell -File tr4w\build\Lint-LFMLoad.ps1 -Rebuild
#   powershell -File tr4w\build\Lint-LFMLoad.ps1 -SelfTest

param(
   [string] $SourceDir = (Join-Path $PSScriptRoot '..\src'),
   [string] $Fpc       = '',
   [string] $Laz       = '',
   [string] $Cpu       = 'i386',
   [string] $Os        = 'win32',
   [switch] $Rebuild,
   # Runs the checker against built-in fixtures instead of the tree: one clean
   # form, and one carrying the exact shape that shipped broken.
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

if ((-not $Fpc) -or (-not $Laz))
   {
   . (Join-Path $PSScriptRoot 'Find-Toolchain.ps1')
   $tc = Find-Tr4wToolchain -Fpc $Fpc -Laz $Laz -Cpu $Cpu -Os $Os -Quiet
   if ($null -eq $tc)
      {
      Write-Host 'Lint-LFMLoad: no FPC + Lazarus able to target i386-win32.' -ForegroundColor Red
      Write-Host '  Find-Toolchain printed every path it tried. This lint needs the LCL'
      Write-Host '  itself to answer the question at all -- see the header.'
      exit 2
      }
   if (-not $Fpc) { $Fpc = $tc.FpcExe }
   if (-not $Laz) { $Laz = $tc.LazDir }
   }

$toolSrc = Join-Path $PSScriptRoot 'lfmload\lfmload.lpr'
$toolOut = Join-Path $PSScriptRoot 'lfmload\units'
$toolExe = Join-Path $toolOut 'lfmload.exe'

$needBuild = $Rebuild -or
             (-not (Test-Path -LiteralPath $toolExe)) -or
             ((Get-Item -LiteralPath $toolSrc).LastWriteTime -gt
              (Get-Item -LiteralPath $toolExe).LastWriteTime)

if ($needBuild)
   {
   if (-not (Test-Path -LiteralPath $Fpc))
      {
      Write-Host "Lint-LFMLoad: FPC not found at $Fpc" -ForegroundColor Red
      exit 2
      }

   $lclUnits = Join-Path $Laz "lcl\units\$Cpu-$Os"
   if (-not (Test-Path -LiteralPath $lclUnits))
      {
      Write-Host "Lint-LFMLoad: no LCL units for $Cpu-$Os at $lclUnits" -ForegroundColor Red
      exit 2
      }

   if (-not (Test-Path -LiteralPath $toolOut))
      {
      New-Item -ItemType Directory -Path $toolOut | Out-Null
      }

   $paths = @(
      $lclUnits
      Join-Path $lclUnits 'win32'
      Join-Path $Laz "components\lazutils\lib\$Cpu-$Os"
      Join-Path $Laz "packager\units\$Cpu-$Os"
      Join-Path $Laz "components\datetimectrls"
      Join-Path $PSScriptRoot "..\src\ui\lcl"
   )

   $fpcArgs = @("-M`delphi", "-P$Cpu", "-T$Os", '-B', "-FU$toolOut", "-o$toolExe")
   foreach ($p in $paths)
      {
      $fpcArgs += "-Fu$p"
      }
   $fpcArgs += $toolSrc

   Push-Location (Split-Path $toolSrc -Parent)
   try
      {
      $out = & $Fpc @fpcArgs 2>&1
      $rc  = $LASTEXITCODE
      }
   finally
      {
      Pop-Location
      }

   if ($rc -ne 0)
      {
      Write-Host 'Lint-LFMLoad: the checker itself failed to build.' -ForegroundColor Red
      $out | Select-String 'Error:|Fatal:' | Select-Object -First 10 |
         ForEach-Object { Write-Host "  $($_.Line.Trim())" }
      exit 2
      }
   }

# ---------------------------------------------------------------- self test --
#
# The fixtures are .lfm text, written to a temp directory and fed to the same
# binary the gate runs. `shipped_broken` is byte-for-byte the shape that broke
# 5.0.20: a const alias where the streamer needs an enum member name.

if ($SelfTest)
   {
   $fixtures = @(
      @{ Name = 'clean'; Expect = 0; Body = @'
object Form1: TForm
  Caption = 'Fixture'
  ClientHeight = 100
  ClientWidth = 200
  object btnApply: TButton
    AnchorSideRight.Control = Owner
    AnchorSideRight.Side = asrBottom
    Left = 100
    Height = 25
    Top = 10
    Width = 90
    Anchors = [akTop, akRight]
    Caption = 'Apply'
    TabOrder = 0
  end
end
'@ },

      # THE 5.0.20 DEFECT. asrLeft is a const in controls.pp, not a member of
      # TAnchorSideReference, so the loader has no such name to find.
      @{ Name = 'shipped_broken'; Expect = 1; Body = @'
object Form1: TForm
  Caption = 'Fixture'
  ClientHeight = 100
  ClientWidth = 200
  object btnOK: TButton
    AnchorSideRight.Control = Owner
    AnchorSideRight.Side = asrLeft
    Left = 10
    Height = 25
    Top = 10
    Width = 90
    Anchors = [akTop, akRight]
    Caption = 'OK'
    TabOrder = 0
  end
end
'@ },

      # An undotted enum value with the wrong spelling -- the FMX-ism the
      # static lint was written for. Both lints must catch this one.
      @{ Name = 'bad_plain_enum'; Expect = 1; Body = @'
object Form1: TForm
  Caption = 'Fixture'
  ClientHeight = 100
  ClientWidth = 200
  object pnlA: TPanel
    Left = 0
    Height = 50
    Top = 0
    Width = 200
    Align = Left
    TabOrder = 0
  end
end
'@ }
   )

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("lfmload-selftest-" + [Guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Path $tmp | Out-Null
   $failed = 0
   try
      {
      foreach ($f in $fixtures)
         {
         $path = Join-Path $tmp ($f.Name + '.lfm')
         [IO.File]::WriteAllText($path, ($f.Body -replace "`r?`n", "`r`n"))
         $out = & $toolExe $path 2>&1
         $bad = 0
         $out | ForEach-Object {
            if ($_ -match 'streamed by the real LCL loader, (\d+) failed') { $bad = [int]$Matches[1] }
         }
         if ($bad -ne $f.Expect)
            {
            Write-Host ("SELFTEST FAIL {0}: expected {1} failure(s), got {2}" -f $f.Name, $f.Expect, $bad) -ForegroundColor Red
            $out | ForEach-Object { Write-Host "   $_" }
            $failed++
            }
         else
            {
            Write-Host ("SELFTEST ok   {0} ({1} failure(s))" -f $f.Name, $bad)
            }
         }
      }
   finally
      {
      Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
      }

   if ($failed -gt 0)
      {
      Write-Host "Lint-LFMLoad SELFTEST: $failed fixture(s) failed." -ForegroundColor Red
      exit 1
      }
   Write-Host ("Lint-LFMLoad SELFTEST: all {0} fixtures behaved as documented." -f $fixtures.Count)
   exit 0
   }

# ------------------------------------------------------------------- the run --

if (-not (Test-Path -LiteralPath $SourceDir))
   {
   Write-Host "Lint-LFMLoad: source directory not found: $SourceDir" -ForegroundColor Red
   exit 2
   }

$forms = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -Filter '*.lfm' -File |
           Where-Object { Test-Tr4wScannable $_.FullName })

if ($forms.Count -eq 0)
   {
   Write-Host "Lint-LFMLoad: no .lfm files found under $SourceDir -- refusing to pass." -ForegroundColor Red
   exit 1
   }

$result = & $toolExe @($forms.FullName) 2>&1
$rc = $LASTEXITCODE

$result | ForEach-Object { Write-Host $_ }

if ($rc -ne 0)
   {
   Write-Host ''
   Write-Host 'Lint-LFMLoad: the LCL loader REFUSED the above, so those windows cannot open.' -ForegroundColor Red
   Write-Host 'Streaming aborts at the FIRST bad property, so expect more once these are fixed.'
   exit 1
   }

exit 0
