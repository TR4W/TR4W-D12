# dump-code-only.ps1 -- write two CODE-ONLY copies of every tracked Pascal file
# under tr4w/, minus tr4w/include (vendored) and tr4w/test:
#
#   <Out>\code\...     comments stripped AND string-literal insides blanked
#   <Out>\codestr\...  comments stripped, string literals kept
#
# Both come from tr4w/build/PascalSource.psm1 (Get-PascalCodeOnlyText), the same
# reader every counting lint uses, so this inventory sees Pascal the way the
# lints do. Line numbers are preserved, so a hit in a copy is a hit at the same
# line in the source.
#
# The file list is `git ls-files`, not a directory walk, so the gitignored
# backup/, graphify-out/ and .claude/worktrees/ copies are excluded by
# construction.
#
# Called by generate.py; not meant to be run by hand.
param(
   [Parameter(Mandatory = $true)][string] $Repo,
   [Parameter(Mandatory = $true)][string] $Out
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $Repo 'tr4w\build\PascalSource.psm1') -Force

$files = @(& git -C $Repo ls-files 'tr4w/*.pas' 'tr4w/*.inc' 'tr4w/*.lpr' |
           Where-Object { $_ -notmatch '^tr4w/(include|test)/' })
if ($LASTEXITCODE -ne 0)
{
   throw "git ls-files failed in $Repo"
}
if ($files.Count -eq 0)
{
   throw "no Pascal files listed under $Repo\tr4w -- refusing to produce an empty inventory"
}

if (Test-Path $Out)
{
   Remove-Item -Recurse -Force $Out
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($rel in $files)
{
   $src = Join-Path $Repo ($rel -replace '/', '\')
   $variants = @(
      @{ Dir = 'code';    Text = (Get-PascalCodeOnlyText -Path $src -BlankStrings) },
      @{ Dir = 'codestr'; Text = (Get-PascalCodeOnlyText -Path $src) }
   )
   foreach ($v in $variants)
   {
      $dst = Join-Path (Join-Path $Out $v.Dir) ($rel -replace '/', '\')
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst) | Out-Null
      [IO.File]::WriteAllText($dst, $v.Text, $utf8)
   }
}
Write-Host "dumped $($files.Count) file(s) to $Out"
