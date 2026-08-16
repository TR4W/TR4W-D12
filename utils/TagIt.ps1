# Create and push a release tag, after proving the tag matches the COMMITTED
# Version.pas -- the same check .github/workflows/release.yml applies, so a tag
# that passes here cannot fail CI for a version mismatch.
#
# REMOTE AND BRANCH ARE DERIVED, NOT HARDCODED, and that is a correctness fix
# rather than a tidy-up. This script previously pulled 'origin master' and
# pushed the tag to 'origin'. In this clone `origin` is TR4W/TR4W -- the DELPHI 7
# heritage repository -- while the active line lives on the `d12` remote, whose
# default branch became `fpc` on 2026-08-13. Run unchanged it would have tried
# to fast-forward the FPC branch onto the D7 master and then pushed a v5 tag
# into the wrong repository.
#
# So it reads the CURRENT branch's configured upstream and uses that. If the
# branch has no upstream it stops and says so, rather than guessing.

param(
   [Parameter(Mandatory)][string] $Tag
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent          # ..\ from utils\

# ---------------------------------------------------------------------------
# NORMALISE THE TAG ONCE, HERE, AND USE $tagName EVERYWHERE AFTER THIS POINT.
#
# This used to strip a leading 'v' for the version COMPARISON and then build the
# tag itself as "v$Tag" from the original string. With the documented usage
# (TagIt.cmd 4.147.26 -- no 'v') the two agreed and it was invisible. Passing the
# tag the way it is actually written down, 'v5.0.1', passed every guard and then
# created and pushed 'vv5.0.1'. A wrong tag is not a local mistake: it is pushed
# to GitHub and it is what release.yml keys on.
#
# So: accept either spelling, derive one canonical name, and never re-derive it.
# '-all' once selected an all-languages build. That build is gone; the suffix is
# still tolerated so an old-habit tag releases rather than failing obscurely.
# ---------------------------------------------------------------------------
$bare = $Tag -replace '^v', '' -replace '-all$', ''
if ($bare -notmatch '^\d+(\.\d+)*$')
   {
   throw "Tag '$Tag' does not look like a version (expected e.g. 5.0.1 or v5.0.1)."
   }
$tagName = "v$bare"

function Fail([string] $msg)
   {
   throw $msg
   }

# ---------------------------------------------------------------------------
# Where are we, and where does this branch actually push?
# ---------------------------------------------------------------------------
$branch = (git -C $repo rev-parse --abbrev-ref HEAD).Trim()

$upstream = (git -C $repo rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $upstream)
   {
   Fail "Branch '$branch' has no upstream. Set one (git push -u <remote> $branch) so this script knows which repository to tag."
   }
$upstream = $upstream.Trim()

# 'd12/fpc' -> remote 'd12', branch 'fpc'
$remote       = $upstream.Split('/')[0]
$remoteBranch = $upstream.Substring($remote.Length + 1)

Write-Host "Branch   : $branch"
Write-Host "Upstream : $upstream  (remote '$remote')"

# ---------------------------------------------------------------------------
# Guard 1: refuse to tag with an uncommitted Version.pas. The version check
# below validates the COMMITTED file -- what the tag actually captures -- so an
# edit that is on disk but not committed would otherwise sail through and tag
# the pre-bump commit, which CI then rejects. Checked BEFORE the pull so the
# message is clear.
# ---------------------------------------------------------------------------
$dirty = git -C $repo status --porcelain -- tr4w/src/Version.pas
if ($dirty)
   {
   Fail 'Version.pas has uncommitted changes. Commit and push your version bump before tagging.'
   }

git -C $repo pull --ff-only $remote $remoteBranch
if ($LASTEXITCODE -ne 0)
   {
   Fail "Local $branch is not fast-forwardable to $upstream. Resolve before tagging."
   }

# ---------------------------------------------------------------------------
# Guard 2: refuse to tag if HEAD is not exactly the upstream commit.
# 'pull --ff-only' silently succeeds when local is AHEAD, which would tag a
# commit that is not yet on the remote branch.
# ---------------------------------------------------------------------------
$head   = (git -C $repo rev-parse HEAD).Trim()
$remoteHead = (git -C $repo rev-parse $upstream).Trim()
if ($head -ne $remoteHead)
   {
   Fail "Local HEAD ($head) is not $upstream ($remoteHead). Push your commits before tagging."
   }

# ---------------------------------------------------------------------------
# Guard 3: the tag must match the committed Version.pas. Mirrors release.yml.
# Reads the file via 'git show HEAD:...' -- NOT the working tree -- so it
# validates exactly what the tag will capture.
# ---------------------------------------------------------------------------
$verLine = git -C $repo show HEAD:tr4w/src/Version.pas |
           Select-String -Pattern 'TR4W_CURRENTVERSION_NUMBER' |
           Select-Object -First 1
if (-not $verLine)
   {
   Fail 'Could not read TR4W_CURRENTVERSION_NUMBER from the committed tr4w/src/Version.pas.'
   }

$version = [regex]::Match($verLine.Line, "'([^']+)'").Groups[1].Value
if ($bare -ne $version)
   {
   Fail "Tag $tagName does not match committed Version.pas ($version). Bump one or the other before tagging."
   }
Write-Host "Tag $tagName matches committed Version.pas $version - OK"

git -C $repo tag -a $tagName -m "TR4W $tagName"
if ($LASTEXITCODE -ne 0) { Fail "Could not create tag $tagName (does it already exist?)" }

git -C $repo push $remote $tagName
if ($LASTEXITCODE -ne 0) { Fail "Could not push $tagName to $remote." }

Write-Host ""
Write-Host "Pushed $tagName to $remote -- release.yml will pick it up when a win-ci runner is attached."
