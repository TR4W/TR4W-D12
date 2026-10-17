# Which target\dom files does full.nsi package?  Dot-sourced by dom-inventory.ps1
# and dom-named.ps1 so there is ONE reader of the installer's File lines.
# (GitHub issue #90; the Python scripts use nsi_dom.py, the same rule.)
#
# Two forms of File line name a dom file:
#   File ..\target\dom\x.dom     one file, by name
#   File ..\target\dom\*.*       a wildcard: EVERY file in that directory
#                                (since 8b3d3e9a the installer ships the folder)
# A wildcard is expanded against the directory on disk, the same idea
# build\Lint-DomCoverage.ps1 applies when it sees one (that lint only needs to
# know a wildcard exists, so it keeps its own flag).  Before this, a wildcard
# was read as one "file" named '*.*' and the packaged column collapsed to one.
#
# Returns a case-insensitive HashSet of leaf names.

function Get-NsiDomPackaged
   {
   param(
      [Parameter(Mandatory = $true)] [string] $Nsi,
      [Parameter(Mandatory = $true)] [string] $DomDir
   )

   $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   foreach ($line in Get-Content $Nsi)
      {
      $m = [regex]::Match($line, '^\s*File\s+(?:/[^\s]+\s+)*"?(.*?dom[\\/][^"\s]+)"?\s*(?:;.*)?$')
      if (-not $m.Success)
         {
         continue
         }
      $leaf = Split-Path $m.Groups[1].Value -Leaf
      if ($leaf -match '[*?]')
         {
         # -Filter uses the Windows matching rules NSIS itself relies on.
         foreach ($f in Get-ChildItem -Path $DomDir -Filter $leaf -File)
            {
            [void]$set.Add($f.Name)
            }
         }
      else
         {
         [void]$set.Add($leaf)
         }
      }
   # Comma operator: stop PowerShell unrolling the set into the pipeline.
   return ,$set
   }
