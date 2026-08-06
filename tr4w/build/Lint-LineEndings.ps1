<#
.SYNOPSIS
   Fails the build when a source file the RAD Studio IDE co-owns has LF line
   endings instead of CRLF.
.DESCRIPTION
   .gitattributes governs what git WRITES on checkout and STORES on commit. It
   cannot stop a tool -- an editor, a script, an AI assistant -- from writing a
   file with LF endings straight into the working tree, and git will not
   rewrite it on the next checkout because the content already normalises to
   the same blob. So the wrong endings can sit in the tree indefinitely.

   That is not cosmetic here. The IDE's form designer inserts code by BYTE
   OFFSET. Against an LF file every line boundary is off by one byte, and
   adding an event handler splices the new declaration into the middle of an
   identifier. On 2026-08-05 that produced, in one save:

       procedure btnCloseClick(Sende
     procedure FormCreate(Sender: TObject);r: TObject);

   Nothing was deleted -- the text landed at the wrong place. The unit no
   longer compiled and the damage read like file corruption. 150 tracked .pas
   files were sitting in the tree with LF endings at the time, VC.pas included,
   each one primed for the same splice.

   This lint is the tripwire: a bad file is caught by the build, before the
   IDE can splice it.
.PARAMETER SourceDir
   Root directory to scan. Scanned recursively.
.PARAMETER Fix
   Rewrite offending files to CRLF instead of failing. Off by default: a lint
   that silently edits source is not a lint. Intended for the one-off cleanup.
.OUTPUTS
   One line per offending file: <file>: <n> bare LF line ending(s)
   Exit code 1 if any file offends, 0 otherwise.
#>
[CmdletBinding()]
param(
   [Parameter(Mandatory = $true)]
   [string] $SourceDir,

   [switch] $Fix
)

$ErrorActionPreference = 'Stop'

# The extensions the IDE opens, parses and rewrites. Deliberately NOT every
# text file: .sh must stay LF (Git Bash), and .md/.json/.py are never touched
# by the designer, so forcing CRLF on them would be noise without a reason.
$extensions = @('.pas', '.dpr', '.dpk', '.inc', '.dproj', '.bdsproj', '.fmx', '.dfm', '.rc')

if (-not (Test-Path -LiteralPath $SourceDir))
   {
   Write-Error "Lint-LineEndings: source directory not found: $SourceDir"
   exit 2
   }

$offenders = @()

Get-ChildItem -LiteralPath $SourceDir -Recurse -File | Where-Object {
   $extensions -contains $_.Extension.ToLowerInvariant()
} | ForEach-Object {
   $bytes = [System.IO.File]::ReadAllBytes($_.FullName)

   # Count LF (0x0A) not preceded by CR (0x0D). Byte-level on purpose: reading
   # the file as text would let .NET normalise the very thing being measured.
   $bare = 0
   for ($i = 0; $i -lt $bytes.Length; $i++)
      {
      if ($bytes[$i] -eq 0x0A)
         {
         if (($i -eq 0) -or ($bytes[$i - 1] -ne 0x0D))
            {
            $bare++
            }
         }
      }

   if ($bare -gt 0)
      {
      $offenders += [PSCustomObject]@{ Path = $_.FullName; Count = $bare }
      }
}

if ($offenders.Count -eq 0)
   {
   Write-Host "Lint-LineEndings: $($extensions -join ' ') files checked, all CRLF."
   exit 0
   }

if ($Fix)
   {
   foreach ($o in $offenders)
      {
      $text = [System.IO.File]::ReadAllText($o.Path)
      # Collapse to LF first so an already-CRLF pair is not doubled to CR CR LF.
      $text = $text.Replace("`r`n", "`n").Replace("`n", "`r`n")
      [System.IO.File]::WriteAllText($o.Path, $text)
      Write-Host "fixed: $($o.Path) ($($o.Count) bare LF)"
      }
   Write-Host "Lint-LineEndings: rewrote $($offenders.Count) file(s) to CRLF."
   exit 0
   }

foreach ($o in $offenders)
   {
   Write-Host "$($o.Path): $($o.Count) bare LF line ending(s)"
   }

Write-Host ""
Write-Host "Lint-LineEndings: $($offenders.Count) file(s) have LF endings and must be CRLF."
Write-Host "The IDE designer inserts code by byte offset and will splice an LF file."
Write-Host "Fix with:  powershell -File tr4w\build\Lint-LineEndings.ps1 -SourceDir tr4w\src -Fix"
exit 1
