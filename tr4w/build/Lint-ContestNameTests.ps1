# Lint-ContestNameTests.ps1 -- SHARED CODE MAY NOT ASK "WHICH CONTEST IS THIS".
#
# BEHAVIOUR THAT DEPENDS ON THE CONTEST BELONGS IN THE CONTEST'S CLASS, under
# tr4w/src/contestFactory/. A shared unit that names a contest to branch --
#
#     if Contest = FLORIDAQSOPARTY then
#     if exch.ceContest in [SPDX, PACC] then
#     case Contest of  SPDX: ...
#
# -- is a second definition of that contest, living somewhere the contest's own
# file never mentions. Deleting or changing the contest then leaves the branch
# behind, and nothing says so. That is the same shape as a base radio class
# asking which model it is (CLAUDE.md, "Two hard rules").
#
# THIS IS A RATCHET, NOT A BAN. The tree already holds hundreds of these and
# they cannot all move at once. The rule is: no file may gain one, and a file
# that has lost some gets its ceiling lowered so they cannot come back.
#
# ------------------------------------------------------------------------
# WHAT IS COUNTED -- THE VALUE, NOT THE OPERAND (widened 2026-10-01)
# ------------------------------------------------------------------------
#
# The lint used to count comparisons of the GLOBAL `Contest` and deliberately
# skipped every qualified operand, so `case exch.ceContest of` -- 14 arms naming
# 25 contests -- and every `rec.liContest = X` passed unseen. It now tests the
# VALUE: any ContestType enum member (read from VC.pas, DUMMYCONTEST excepted)
# used, inside a begin..end body, as
#
#   * an operand of = or <>, whatever the other operand is (`Contest`,
#     `exch.ceContest`, `rec.liContest`, `SelectedContest`, a call, a parameter);
#   * a member of an `in [...]` set -- ONE per test, however long the set;
#   * a label of a case ARM -- ONE PER ARM that names a contest, however many
#     labels it lists (`SPDX, PACC:` is one) and a range (`A..B:`) is one.
#     The `case` statement itself no longer counts: its arms do. So a NEW ARM
#     added to an existing `case Contest of` now fails the build, which the old
#     per-case count could not see.
#
# HOW THE ARMS ARE FOUND. CLAUDE.md records that a line regex reports 188 arms
# where 91 exist once a case is nested, so this is a TOKEN WALK with a stack of
# open blocks -- begin, try, repeat, case, record, class. The stack is what knows
# that `until` closes a `repeat` (its `;`s are not the case's), that a nested
# case's `end` is not the outer one's, that an `else` after an `if` inside an
# arm is the if's, and that a record's variant `case` has no `end` of its own.
# The fixture below has every one of those shapes.
#
# THE COLLISION RULE. Some member names are also ordinary identifiers elsewhere
# (TENTEN, RDA, PCC, IOTA are the audited ones). Two things keep them out, and
# both are structural, so no list of names is kept:
#   1. Only code INSIDE a begin..end body is looked at. A typed constant
#      (`X: ContestType = SPDX`), a var initialiser, a default parameter, a
#      subrange and a record-variant label are declarations, not tests, and a
#      declaration is never in a body.
#   2. A comparison whose other operand is a number or string literal is not
#      a contest test (`rda = 5`).
# A local or field that SHARES a member's name and is compared with another
# identifier is the residual case; a rate this low is better reported than
# papered over, and the tree measurement states how many there are (none was
# found -- see the dated note on $CEILINGS).
#
# WHAT IS NOT COUNTED, and each is in the fixture:
#   * DUMMYCONTEST anywhere -- "is a contest loaded", not which one;
#   * qualified / called / indexed members: x.SPDX, SPDX(...), SPDX[...];
#   * lookalikes: ActiveContest, aContest, Contest (the variable on its own);
#   * assignment (`Contest := SPDX`), reads, array indexes;
#   * a comparison with a string -- strings are blanked, and that is another
#     lint's business (the string-compare shape in CONTEST_RULES_OUTSIDE_FACTORY);
#   * anything in a comment or a string literal -- PascalSource.psm1 strips both.
#
# SCOPE. tr4w/src, minus src/contestFactory/ (where the test is legitimate),
# and minus every backup / __history path (Get-ScanExclusions.ps1). tr4w/test is
# NOT scanned: a test names the contest it is testing, which is its job.
#
# ------------------------------------------------------------------------
# IT FAILS CLOSED
# ------------------------------------------------------------------------
#
#   * the fixture must pass BEFORE any tree number is believed;
#   * the member list must hold at least $MEMBER_FLOOR names, else the enum was
#     not read and an empty set would count nothing and pass;
#   * scanning zero files fails;
#   * a total below $TOTAL_FLOOR fails -- that is a broken parser, not progress.
#     The floor is set well below today's count, so honest progress passes;
#   * a file whose block stack does not balance is reported (a stray define can
#     do that), because an unbalanced walk is a wrong count.

[CmdletBinding()]
param(
   [string] $SourceDir = '',
   # Print every counted line, so a ceiling can be worked down.
   [switch] $List,
   # Print the baseline table as PowerShell, ready to paste over $CEILINGS.
   [switch] $Emit,
   [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'PascalSource.psm1') -Force
. (Join-Path $PSScriptRoot 'Get-ScanExclusions.ps1')   # Test-Tr4wScannable

# --------------------------------------------------------------------------
# THE CEILINGS -- path relative to src, lower case, backslashes.
# Lower one when work lands; NEVER raise one. A file not listed has ceiling 0.
# --------------------------------------------------------------------------
$CEILINGS = @{
   # Measured 2026-10-01: 342 in 15 files -- 246 case arms, 96 comparisons and
   # `in` tests (-Emit prints this table). The old, narrower lint counted 91 in
   # 12 files; that figure is not comparable, it counted each case once and
   # skipped every qualified operand. No false positive was found in the tree:
   # no TENTEN / RDA / PCC / IOTA hit is a local or a field.
   #
   # M4, 2026-10-01 -- each contest formats its own export: postunit 26 -> 15,
   # uadif 4 -> 3, uadifexchange 5 -> 0 and ucabrilloexchange 11 -> 0 (both
   # unlisted now, so their ceiling is 0 and any contest test fails them).
   #
   # M5a, 2026-10-01 -- each contest interprets its own ADIF import:
   # mainunit 26 -> 14 (the twelve arms of ApplyContestSpecificADIFTail and the
   # Field Day arm of the dead ProcessImportedSRX_String went; what remains is
   # ARRL 160 and POTA, the two contests with no class that still own an import
   # arm) and uadif 3 -> 1 (the two APP_N1MM_EXCHANGE1 tests).
   #
   # M5b, 2026-10-02 -- each contest parses its own exchange: logstuff 14 -> 3.
   # Gone: IARU's zone, SAC x2, UK/EI, LABRE, ALRS (dead, deleted), the PCC's
   # call shape, and D1's four Field Day tests in ValidClass. Left: GeneralQSO's
   # WARC band stepping (set-up), the RU3AX doubling in the legacy RussianDX
   # scoring arm (dead by default -- both contests have classes -- and kept
   # until M10 like the other D3 arms), and the UA4W Championship's parse rule,
   # which stays named until its class can be handed a CTY lookup of MY CALL.
   #
   # M6, 2026-10-02 -- each contest owns its final score: logedit 17 -> 11
   # (TotalScore's ARRL and Winter Field Day, Ural Cup x2, Ukraine Championship
   # and Missouri arms went to their classes; the RSGB 1.8 MHz "times one"
   # stays, its class blocked on the multiplier sheet -- design Q33),
   # mainunit 14 -> 13 and logsubs2 4 -> 3 (Missouri's bonus-station check in
   # the log's loader and in live entry).
   #
   # M7a, 2026-10-02 -- each contest describes its own session: fcontest
   # 107 -> 50 (FoundContest's 55 arms for contests with a class went into
   # their DescribeSession, with the two Contest = tests inside the Cup RF and
   # RF Championship arms; ALLJA left the ALLJA/YOTA arm, which stays for
   # YOTA) and logcfg 14 -> 10 (four of tSetupExchangeNumbers' arms went
   # whole into CQExchangeDefault; six more lost their registered labels and
   # stay for the classless contests beside them).
   #
   # M7b batch 1, 2026-10-02 -- thirty-nine classless contests gained a class:
   # fcontest 50 -> 25 (24 FoundContest arms went into DescribeSession, and
   # the closing `Contest in [JIDXCW, JIDXSSB]` test became the JIDX
   # classes' SuppressZoneExchangeMessages; CQ WPX RTTY left the arm it shared
   # with WRTC, which stays), logcfg 10 -> 6 (four CQ-exchange arms whole),
   # mainunit 13 -> 12 and postunit 15 -> 14 (ARRL 160's import and export
   # arms -- its class was handed the domestic-country lookup its scoring
   # needed).
   #
   # M7b batch 2, 2026-10-02 -- forty more classless contests gained a class:
   # fcontest 25 -> 2 (FoundContest's 23 arms for them went into
   # DescribeSession; the `case` keeps POTA and the UA4W Championship, the two
   # arms of contests still classless on purpose) and logcfg 6 -> 1 (five
   # CQ-exchange arms whole into CQExchangeDefault; the UA4W Championship's
   # stays, RAEM having left its label). Every other site that names a batch 2
   # contest is a seam not built yet (M8 multipliers, M9 display and HamScore)
   # and is unchanged -- design 8.2k lists them.
   #
   # M8, 2026-10-02 -- each contest declares its own multiplier rules:
   # logdupe 5 -> 0 (SetMultFlags' BC, New York and Indiana 'DX' tests, the
   # PCC's own-country prefix and the Jock White Field Day's own branch are
   # their classes' CountsAsMultiplier; unlisted now, so any contest test
   # there fails), logedit 11 -> 7 (GetMultArray's four need-multiplier arms
   # are DomesticMultiplierFromCall) and mainunit 12 -> 11 (ParametersOkay's
   # YB DX test, which changed nothing, deleted with the copy of SetPrefix it
   # sat in).
   #
   # M9a, 2026-10-02 -- each contest tells the display and the reports what to
   # show, as data the UI renders: unewcontest 92 -> 5 (the New Contest
   # dialog's two `case SelectedContest of` are DescribeNewContestPrompts;
   # left are the arms of POTA, RSGB 1.8 MHz and the UA4W Championship,
   # classless on purpose), uexchangebuilder 11 -> 0 and utotal 5 -> 0 (both
   # unlisted now: CanonicalReceived/SentExchange and TotalsDisplay),
   # postunit 14 -> 5 (the summary sheet, the hour totals' score column, the
   # Cabrillo header's location guard, contest name and section lines, and the
   # Cabrillo mode column), mainunit 11 -> 8 and logedit 7 -> 6 (WRTC's
   # operating aids and the WAE QTC menu) and logsubs2 3 -> 2 (WRTC's
   # score-posting labels). What is left in those files is listed in design
   # 8.2m with the step it waits for.
   'mainunit.pas'          = 8
   'trdos\fcontest.pas'    = 2
   'trdos\logcfg.pas'      = 1
   'trdos\logedit.pas'     = 6
   'trdos\logstuff.pas'    = 3
   'trdos\logsubs2.pas'    = 2
   'trdos\logwind.pas'     = 1
   'trdos\postunit.pas'    = 5
   'uadif.pas'             = 1
   'unewcontest.pas'       = 5
}

# Roughly two thirds of the count at the time of writing, and far above what a
# parser that read nothing would find. See "It fails closed".
#
# M7a, 2026-10-02: 228 -> 180. The total fell 281 -> 220 because 61 tests
# genuinely moved into the contest classes (the ceilings above); 180 keeps
# the floor at about the ratio to the count (81%) it had before.
#
# M7b batch 1, 2026-10-02: 180 -> 150. The total fell 220 -> 189 (31 tests
# moved into the classes, ceilings above); 150 is again about 80% of it.
#
# M7b batch 2, 2026-10-02: 150 -> 130. The total fell 189 -> 161 (28 tests
# moved into the classes, ceilings above); 130 is again about 80% of it.
#
# M8, 2026-10-02: 130 -> 120. The total fell 161 -> 151 (10 tests moved into
# the classes or were deleted as no-ops, ceilings above); 120 is again about
# 80% of it.
#
# M9a, 2026-10-02: 120 -> 27. The total fell 151 -> 34 (117 tests moved into
# the classes, ceilings above -- 87 of them the New Contest dialog's arms);
# 27 is again about 80% of it.
$TOTAL_FLOOR  = 27
$MEMBER_FLOOR = 130

# --------------------------------------------------------------------------
# THE MEMBER LIST. Read from VC.pas's ContestType declaration, never typed
# here, so a new contest is covered the day it is added to the enum.
# --------------------------------------------------------------------------
function Get-ContestTypeMembers
{
   param([Parameter(Mandatory = $true)][string] $VcPath)

   $text = Get-PascalCodeOnlyText -Path $VcPath -BlankStrings   # comments stripped
   $m = [regex]::Match($text, '(?<![\w.])ContestType\s*=\s*\((?<body>[^)]*)\)', 'IgnoreCase')
   $set = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
   if ($m.Success)
   {
      foreach ($item in $m.Groups['body'].Value.Split(','))
      {
         $im = [regex]::Match($item, '^\s*([A-Za-z_]\w*)')
         if ($im.Success) { [void]$set.Add($im.Groups[1].Value) }
      }
   }
   [void]$set.Remove('DUMMYCONTEST')   # the sentinel asks "is a contest loaded", not which
   return ,$set
}

# --------------------------------------------------------------------------
# THE COUNT. See the header for the rule; this is the walk.
# --------------------------------------------------------------------------
$script:TokenRx = [regex]::new(
   "[A-Za-z_][A-Za-z0-9_]*|:=|<>|<=|>=|\.\.|'[^']*'|[0-9]+|\S")
$script:DirectiveRx = [regex]::new('\{\$[^}]*\}|\(\*\$.*?\*\)', 'Singleline')
$script:MemberRx = $null     # built once from the member set
$script:CodeDepth = 0        # open begin / try / repeat / case frames

function New-Frame
{
   param($Kind)
   return [pscustomobject]@{
      Kind   = $Kind
      State  = 'sel'                              # case only: sel -> label -> stmt -> label ... / else
      Depth  = 0                                  # paren depth while reading a selector or a label
      Ifs    = 0                                  # `if`s awaiting their `else`
      Labels = (New-Object System.Collections.ArrayList)
   }
}

function Set-MemberRx
{
   param($Members)
   $script:MemberRx = [regex]::new('\b(?:' + (($Members | ForEach-Object { [regex]::Escape($_) }) -join '|') + ')\b', 'IgnoreCase')
}

function Get-ContestNameTests
{
   param(
      [Parameter(Mandatory = $true)][string] $Path,
      [Parameter(Mandatory = $true)] $Members,
      [switch] $ReportBalance
   )

   $raw  = Get-PascalCodeOnlyText -Path $Path -BlankStrings
   $hits = New-Object System.Collections.ArrayList

   # Cheap prefilter: most files name no contest at all.
   if (-not $script:MemberRx.IsMatch($raw)) { return @() }

   $text = $script:DirectiveRx.Replace($raw, { param($d) $d.Value -replace '[^\r\n]', ' ' })
   $ms   = $script:TokenRx.Matches($text)
   $n    = $ms.Count
   $tv   = New-Object 'string[]' $n
   $tx   = New-Object 'int[]' $n
   for ($k = 0; $k -lt $n; $k++) { $tv[$k] = $ms[$k].Value.ToLowerInvariant(); $tx[$k] = $ms[$k].Index }

   $add = {
      param($tok, $kind, $nameTok = -1)
      if ($nameTok -lt 0) { $nameTok = $tok }
      $line = 1 + ([regex]::Matches($text.Substring(0, $tx[$tok]), "`n")).Count
      [void]$hits.Add([pscustomobject]@{ Line = $line; Kind = $kind; Name = $ms[$nameTok].Value })
   }
   $isMember  = { param($k) ($k -ge 0) -and ($k -lt $n) -and $Members.Contains($ms[$k].Value) }
   $isLiteral = { param($k) ($k -lt 0) -or ($k -ge $n) -or ($tv[$k][0] -eq "'") -or [char]::IsDigit($tv[$k][0]) }

   $stack = New-Object System.Collections.ArrayList
   $done  = @{}                     # right-hand members already counted as one pair
   $script:CodeDepth = 0

   $push = {
      param($kind)
      [void]$stack.Add((New-Frame $kind))
      if ($kind -in 'begin', 'try', 'repeat', 'case') { $script:CodeDepth++ }
   }
   $pop = {
      if ($stack.Count -gt 0)
      {
         $kind = $stack[$stack.Count - 1].Kind
         $stack.RemoveAt($stack.Count - 1)
         if ($kind -in 'begin', 'try', 'repeat', 'case') { $script:CodeDepth-- }
      }
   }

   for ($i = 0; $i -lt $n; $i++)
   {
      $t    = $tv[$i]
      $prev = ''
      if ($i -gt 0) { $prev = $tv[$i - 1] }
      $top  = $null
      if ($stack.Count -gt 0) { $top = $stack[$stack.Count - 1] }

      # ---- inside a case, between statements: the selector, then arm labels ----
      if (($null -ne $top) -and ($top.Kind -eq 'case') -and ($top.State -ne 'stmt') -and ($top.State -ne 'else'))
      {
         if ($top.State -eq 'sel')
         {
            if ($t -eq '(') { $top.Depth++ }
            elseif ($t -eq ')') { $top.Depth-- }
            elseif (($t -eq 'of') -and ($top.Depth -eq 0)) { $top.State = 'label'; $top.Depth = 0; $top.Labels.Clear() }
            continue
         }
         # State = label
         if ($t -eq 'end') { & $pop; continue }
         if (($t -eq 'else') -and ($top.Depth -eq 0)) { $top.State = 'else'; continue }
         if (($t -eq '(') -or ($t -eq '[')) { $top.Depth++ }
         elseif (($t -eq ')') -or ($t -eq ']')) { $top.Depth-- }
         elseif (($t -eq ':') -and ($top.Depth -eq 0))
         {
            foreach ($li in $top.Labels)
            {
               if ((& $isMember $li) -and (($li -eq 0) -or ($tv[$li - 1] -ne '.')))
               {
                  & $add $li 'arm'
                  break
               }
            }
            $top.State = 'stmt'; $top.Ifs = 0
         }
         elseif ($t -ne ';') { [void]$top.Labels.Add($i) }
         continue
      }

      # ---- structure ----
      $structural = $true
      switch ($t)
      {
         'begin'  { & $push 'begin' }
         'try'    { & $push 'try' }
         'repeat' { & $push 'repeat' }
         'record' { & $push 'record' }
         'case'
         {
            # A record's variant case is a declaration and has no `end` of its own.
            if (-not (($null -ne $top) -and ($top.Kind -eq 'record'))) { & $push 'case' }
         }
         { $_ -in 'class', 'object', 'interface' }
         {
            # `= class(TBase)` opens a block that `end` closes; `= class;`,
            # `= class(TBase);` and `class of X` do not, and neither does the
            # `interface` section keyword (not preceded by `=`).
            if (($i -gt 0) -and ($prev -in '=', 'packed'))
            {
               $j = $i + 1
               if (($j -lt $n) -and ($tv[$j] -eq '('))
               {
                  $d = 0
                  while ($j -lt $n)
                  {
                     if ($tv[$j] -eq '(') { $d++ }
                     elseif ($tv[$j] -eq ')') { $d--; if ($d -eq 0) { break } }
                     $j++
                  }
                  $j++
               }
               if (($j -lt $n) -and ($tv[$j] -notin ';', 'of')) { & $push 'class' }
            }
         }
         'end'   { & $pop }
         'until' { if (($null -ne $top) -and ($top.Kind -eq 'repeat')) { & $pop } }
         'if'    { if ($null -ne $top) { $top.Ifs++ } }
         'else'
         {
            if ($null -ne $top)
            {
               if ($top.Ifs -gt 0) { $top.Ifs-- }
               elseif (($top.Kind -eq 'case') -and ($top.State -eq 'stmt')) { $top.State = 'else' }
            }
         }
         ';'
         {
            if (($null -ne $top) -and ($top.Kind -eq 'case') -and ($top.State -eq 'stmt'))
            {
               $top.State = 'label'; $top.Depth = 0; $top.Ifs = 0; $top.Labels.Clear()
            }
         }
         'in'
         {
            $structural = $false
            if (($script:CodeDepth -gt 0) -and ($i + 1 -lt $n) -and ($tv[$i + 1] -eq '['))
            {
               $d = 0
               for ($j = $i + 1; $j -lt $n; $j++)
               {
                  if ($tv[$j] -eq '[') { $d++ }
                  elseif ($tv[$j] -eq ']') { $d--; if ($d -eq 0) { break } }
                  elseif ((& $isMember $j) -and ($tv[$j - 1] -ne '.')) { & $add $i 'in' $j; break }
               }
            }
         }
         default { $structural = $false }
      }
      if ($structural) { continue }

      # ---- a member as a comparison operand, in a body only ----
      if (($script:CodeDepth -gt 0) -and (& $isMember $i))
      {
         if ($prev -eq '.') { continue }
         $nx = ''
         if ($i + 1 -lt $n) { $nx = $tv[$i + 1] }
         if ($nx -in '.', '(', '[', '^') { continue }
         if (($nx -eq '=') -or ($nx -eq '<>'))
         {
            if (-not (& $isLiteral ($i + 2)))
            {
               & $add $i 'compare'
               if (& $isMember ($i + 2)) { $done[$i + 2] = $true }
            }
         }
         elseif ((($prev -eq '=') -or ($prev -eq '<>')) -and (-not $done.ContainsKey($i)))
         {
            if (-not (& $isLiteral ($i - 2))) { & $add $i 'compare' }
         }
      }
   }

   if ($ReportBalance -and (($stack.Count -ne 0) -or ($script:CodeDepth -ne 0)))
   {
      Write-Host ("   unbalanced block stack at end of file ({0} open): {1}" -f $stack.Count, $Path) -ForegroundColor Yellow
   }
   return @($hits | Sort-Object Line)
}

# --------------------------------------------------------------------------
# THE FIXTURE. Every shape, counted and excluded. Each line carries its
# expected hit count in a trailing <<N tag (inside a // comment, which the
# stripper removes). A hit is reported on the line of the member token -- or,
# for an `in` test, of the `in`.
# --------------------------------------------------------------------------
function Invoke-FixtureCheck
{
   param($Members)

   $fixture = @(
      'unit F;'
      'interface'
      'type'
      '   TRec = record'
      '      a: integer;'
      '      case b: integer of'
      '         SPDX: (x: integer);                                // <<0  record variant, a declaration'
      '         PACC: (y: integer);                                // <<0'
      '   end;'
      '   TCls = class(TObject)'
      '      procedure P(c: ContestType = SPDX);                    // <<0  default parameter'
      '   end;'
      '   TFwd = class;'
      '   TFwd2 = class(TObject);'
      'const'
      '   Initial: ContestType = SPDX;                              // <<0  typed constant'
      'var'
      '   v: ContestType = PACC;                                    // <<0  initialiser'
      'implementation'
      'procedure Foo;'
      'const'
      '   K: ContestType = CQWWCW;                                  // <<0  local typed constant'
      'begin'
      '   if Contest = FLORIDAQSOPARTY then x;                      // <<1'
      '   if Contest <> PCC then x;                                 // <<1'
      '   if contest=spdx then x;                                   // <<1  no spaces, lower case'
      '   if exch.ceContest = SPDX then x;                          // <<1  qualified operand'
      '   if rec.liContest <> PACC then x;                          // <<1  qualified operand'
      '   if SelectedContest = CQWWCW then x;                       // <<1  another variable'
      '   if PACC = Contest then x;                                 // <<1  reversed'
      '   if s^.liContest = PACC then x;                            // <<1  pointer field'
      '   if Foo(x) = SPDX then x;                                  // <<1  a call'
      '   if (Contest = SPDX) or (Contest = PACC) then x;           // <<2'
      '   if SPDX = PACC then x;                                    // <<1  one test, not two'
      '   if Contest in [SPDX, PACC] then x;                        // <<1'
      '   if not (Contest in [SPDX]) then x;                        // <<1'
      '   if exch.ceContest in [SPDX..PACC, CQWWCW] then x;         // <<1  one per test'
      '   if x in [1, 2] then x;                                    // <<0'
      '   if Contest {a brace comment} = {and another} CQWWCW then x;   // <<1'
      '   if (Contest (* paren comment *) <> CQWWCW) then x;        // <<1'
      '   if Contest ='
      '      SPDX then x;                                           // <<1  hit is on the member''s line'
      '   if Contest <> DUMMYCONTEST then x;                        // <<0  sentinel'
      '   if Contest = DummyContest then x;                         // <<0  sentinel, any case'
      '   if DUMMYCONTEST = Contest then x;                         // <<0  sentinel, reversed'
      '   if Contest in [DUMMYCONTEST] then x;                      // <<0  sentinel in a set'
      '   if rda = 5 then x;                                        // <<0  collision: a number'
      '   if TENTEN <> ''x'' then x;                                // <<0  collision: a string'
      '   if 7 = Iota then x;                                       // <<0  collision: a number'
      '   if ActiveContest = x then x;                              // <<0  lookalike'
      '   if aContest = x then x;                                   // <<0  lookalike'
      '   if x.SPDX = y then x;                                     // <<0  a field of that name'
      '   if SPDX(x) = y then x;                                    // <<0  a call of that name'
      '   y := ContestsArray[SPDX];                                 // <<0  index'
      '   y := ContestsArray[Contest].Name;                         // <<0'
      '   Contest := SPDX;                                          // <<0  assignment'
      '   x := SPDX;                                                // <<0  read'
      '   s := ''Contest = SPDX'';                                  // <<0  string literal'
      '   // if Contest = SPDX then x;                              <<0  line comment'
      '   (* if Contest in [SPDX] then x; *)                        // <<0'
      '   { case Contest of SPDX: x; end; }                         // <<0'
      ''
      '   // ---- case: every arm that names a contest, once ----'
      '   case Contest of'
      '      SPDX: x;                                               // <<1'
      '      PACC, CQWWCW: x;                                       // <<1  a label list is ONE arm'
      '      FLORIDAQSOPARTY..CQWWSSB: x;                           // <<1  a range is one arm'
      '      DUMMYCONTEST: x;                                       // <<0  sentinel'
      '      3: x;                                                  // <<0  not a contest'
      '      4: if Contest = SPDX then x;                           // <<1  the compare in the body, not the label'
      '      5: x := SPDX                                           // <<0  a read; no `;` before the else'
      '   else'
      '      x; if Contest = PCC then x;                            // <<1  else arm: a SECOND statement is still no label'
      '   end;'
      '   case exch.ceContest of                                    // <<0  the case itself is not counted'
      '      SPDX: x;                                               // <<1  a qualified selector counts too'
      '   end;'
      '   case Contest of SPDX: x; PACC: x; end;                    // <<2  two arms on one line'
      '   case y of'
      '      1: x;                                                  // <<0'
      '   end;'
      ''
      '   // ---- nesting: the stack must know which case an end closes ----'
      '   case Contest of'
      '      SPDX:                                                  // <<1'
      '         case y of'
      '            1: x;                                            // <<0'
      '            2: if Contest = PACC then x else x;              // <<1'
      '         end;'
      '      PACC:                                                  // <<1  reached after the inner end'
      '         if a then x else y;                                 // <<0  this else is the if''s'
      '      CQWWCW:                                                // <<1'
      '         if a then begin x; end else begin y; end;           // <<0'
      '      FLORIDAQSOPARTY:                                       // <<1'
      '         begin'
      '            case z of'
      '               2: x;                                         // <<0'
      '            end;'
      '            x;'
      '         end;'
      '      ARRL160: x;                                            // <<1  still an outer arm'
      '   else'
      '      x;                                                     // <<0'
      '   end;'
      ''
      '   // ---- a case inside if / else ----'
      '   if a then'
      '      case Contest of'
      '         SPDX: x;                                            // <<1'
      '      end'
      '   else'
      '      case Contest of'
      '         PACC: x;                                            // <<1'
      '      end;'
      ''
      '   // ---- repeat .. until: its semicolons are not the case''s ----'
      '   repeat'
      '      x;'
      '      case Contest of'
      '         SPDX: x;                                            // <<1'
      '      end;'
      '   until Contest = CQWWCW;                                   // <<1'
      '   case Contest of'
      '      PACC: repeat x; until Contest = CQWWCW;                // <<2  the arm, and the until'
      '      SPDX: x;                                               // <<1'
      '   end;'
      ''
      '   // ---- try .. except / finally ----'
      '   try'
      '      x;'
      '      case Contest of'
      '         SPDX: x;                                            // <<1'
      '      end;'
      '   except'
      '      on E: Exception do'
      '         if Contest = PACC then x;                           // <<1'
      '   end;'
      '   try x; finally case Contest of PACC: x; end; end;         // <<1'
      '   case Contest of'
      '      SPDX: try x; except on E: Exception do y; end;         // <<1'
      '      PACC: x;                                               // <<1'
      '   end;'
      'end;'
      'end.'
   )

   $tmp = Join-Path ([IO.Path]::GetTempPath()) ("contestnames_" + [Guid]::NewGuid().ToString('N') + ".pas")
   [IO.File]::WriteAllText($tmp, ($fixture -join "`r`n"))
   try
   {
      $hits = @(Get-ContestNameTests -Path $tmp -Members $Members -ReportBalance)
   }
   finally
   {
      Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
   }

   $bad = 0

   # The fixture's own names must be real members, or it proves nothing.
   foreach ($nm in 'SPDX', 'PACC', 'CQWWCW', 'CQWWSSB', 'FLORIDAQSOPARTY', 'PCC', 'ARRL160', 'TENTEN', 'RDA', 'IOTA')
   {
      if (-not $Members.Contains($nm))
      {
         $bad++
         Write-Host ("FIXTURE FAIL  '$nm' is not in the ContestType enum read from VC.pas") -ForegroundColor Red
      }
   }

   $expected = @{}
   for ($i = 0; $i -lt $fixture.Count; $i++)
   {
      $m = [regex]::Match($fixture[$i], '<<(\d+)')
      if ($m.Success -and ([int]$m.Groups[1].Value -gt 0)) { $expected[$i + 1] = [int]$m.Groups[1].Value }
   }
   $got = @{}
   foreach ($h in $hits) { $got[[int]$h.Line] = 1 + $(if ($got.ContainsKey([int]$h.Line)) { $got[[int]$h.Line] } else { 0 }) }

   $lines = @($expected.Keys) + @($got.Keys) | Sort-Object -Unique
   $disagree = @($lines | Where-Object { $expected[$_] -ne $got[$_] })
   if ($disagree.Count -gt 0)
   {
      $bad++
      Write-Host 'FIXTURE FAIL' -ForegroundColor Red
      foreach ($ln in $disagree)
      {
         $e = 0; if ($expected.ContainsKey($ln)) { $e = $expected[$ln] }
         $g = 0; if ($got.ContainsKey($ln)) { $g = $got[$ln] }
         Write-Host ('   line {0}: expected {1}, got {2}   {3}' -f $ln, $e, $g, $fixture[$ln - 1].Trim()) -ForegroundColor Red
      }
   }
   elseif ($SelfTest)
   {
      $total = 0; foreach ($v in $got.Values) { $total += $v }
      Write-Host ('FIXTURE ok   {0} hit(s) on {1} line(s), {2} fixture lines' -f $total, $got.Count, $fixture.Count)
   }

   $bad += Invoke-PascalSourceSelfTest
   return $bad
}

# --------------------------------------------------------------------------
# THE MEMBER LIST, THEN THE FIXTURE, BEFORE ANY TREE NUMBER IS BELIEVED.
# --------------------------------------------------------------------------
$vc = Join-Path (Split-Path -Parent $PSScriptRoot) 'src\VC.pas'
if (-not (Test-Path -LiteralPath $vc))
{
   Write-Host "Lint-ContestNameTests: VC.pas not found at $vc -- cannot read the ContestType enum." -ForegroundColor Red
   exit 1
}
$members = Get-ContestTypeMembers -VcPath $vc
if ($members.Count -lt $MEMBER_FLOOR)
{
   Write-Host ("Lint-ContestNameTests FAILED -- read only {0} ContestType members from VC.pas (floor {1}). " -f $members.Count, $MEMBER_FLOOR +
               'An empty or short set counts nothing and would pass; that is a broken read, not a clean tree.') -ForegroundColor Red
   exit 1
}
Set-MemberRx $members

$fixtureFailures = Invoke-FixtureCheck -Members $members
if ($fixtureFailures -ne 0)
{
   Write-Host 'Lint-ContestNameTests: the fixture failed -- the parse cannot be trusted, which is not a pass.' -ForegroundColor Red
   exit 1
}
if ($SelfTest) { Write-Host ('{0} ContestType members read.' -f $members.Count); exit 0 }

# --------------------------------------------------------------------------
# THE TREE.
# --------------------------------------------------------------------------
if ($SourceDir -eq '') { $SourceDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'src' }
$srcRoot = (Resolve-Path -LiteralPath $SourceDir).Path.TrimEnd('\')

$files = @(Get-ChildItem -LiteralPath $srcRoot -Recurse -File |
           Where-Object { ($_.Extension -ieq '.pas' -or $_.Extension -ieq '.inc') -and
                          (Test-Tr4wScannable $_.FullName) -and
                          $_.FullName -notmatch '\\contestFactory\\' -and
                          $_.FullName -notmatch '\\graphify-out\\' -and
                          $_.Name -notmatch '~' })

if ($files.Count -eq 0)
{
   Write-Host "Lint-ContestNameTests: scanned ZERO files under $srcRoot -- that is a broken lint, not a pass." -ForegroundColor Red
   exit 1
}

$counts = @{}
$lines  = @{}
$total  = 0
foreach ($f in $files)
{
   $rel  = $f.FullName.Substring($srcRoot.Length).TrimStart('\').ToLowerInvariant()
   $hits = @(Get-ContestNameTests -Path $f.FullName -Members $members -ReportBalance)
   if ($hits.Count -gt 0)
   {
      $counts[$rel] = $hits.Count
      $lines[$rel]  = $hits
      $total       += $hits.Count
   }
}

if ($Emit)
{
   foreach ($k in ($counts.Keys | Sort-Object))
   {
      Write-Host ("   '{0}' = {1}" -f $k, $counts[$k])
   }
   Write-Host ("# total {0} in {1} file(s), {2} scanned, {3} members" -f $total, $counts.Count, $files.Count, $members.Count)
   exit 0
}

if ($List)
{
   foreach ($k in ($counts.Keys | Sort-Object))
   {
      foreach ($h in $lines[$k]) { Write-Host ('{0}:{1}  {2}  {3}' -f $k, $h.Line, $h.Kind, $h.Name) }
   }
}

$failed  = $false
$dropped = @()

foreach ($k in ($counts.Keys | Sort-Object))
{
   $ceiling = 0
   if ($CEILINGS.ContainsKey($k)) { $ceiling = $CEILINGS[$k] }
   if ($counts[$k] -gt $ceiling)
   {
      $failed = $true
      $why = if ($CEILINGS.ContainsKey($k)) { "ceiling $ceiling" } else { 'a file with no ceiling' }
      Write-Host ('   {0}: {1} contest-name test(s), {2}' -f $k, $counts[$k], $why) -ForegroundColor Red
      foreach ($h in $lines[$k]) { Write-Host ('      line {0}  {1}  {2}' -f $h.Line, $h.Kind, $h.Name) -ForegroundColor Red }
   }
   elseif ($counts[$k] -lt $ceiling)
   {
      $dropped += ('{0}: {1} (ceiling {2})' -f $k, $counts[$k], $ceiling)
   }
}
# A ceilinged file that now has none is progress too, and is not in $counts.
foreach ($k in ($CEILINGS.Keys | Sort-Object))
{
   if (-not $counts.ContainsKey($k) -and $CEILINGS[$k] -gt 0)
   {
      $dropped += ('{0}: 0 (ceiling {1})' -f $k, $CEILINGS[$k])
   }
}

Write-Host ''
Write-Host ('Lint-ContestNameTests: {0} contest-name test(s) in {1} file(s), {2} file(s) scanned, {3} members, floor {4}.' -f
            $total, $counts.Count, $files.Count, $members.Count, $TOTAL_FLOOR)

if ($total -lt $TOTAL_FLOOR)
{
   Write-Host ("Lint-ContestNameTests FAILED -- only $total found, below the floor of $TOTAL_FLOOR. " +
               'That is a broken parse, not progress. If the tests were genuinely moved, lower the floor with them.') -ForegroundColor Red
   exit 1
}

if ($dropped.Count -gt 0)
{
   Write-Host 'These files are BELOW their ceiling -- lower it so the tests cannot come back:' -ForegroundColor Yellow
   foreach ($d in $dropped) { Write-Host "   $d" -ForegroundColor Yellow }
}

if ($failed)
{
   Write-Host ''
   Write-Host 'Lint-ContestNameTests FAILED -- shared code is testing the contest by name.' -ForegroundColor Red
   Write-Host '  What differs about a contest belongs in its class under src/contestFactory/,' -ForegroundColor Red
   Write-Host '  reached through a virtual, not in a branch here. See docs/ADDING_A_CONTEST.md.' -ForegroundColor Red
   exit 1
}

Write-Host 'Lint-ContestNameTests: no file has gained a contest-name test.' -ForegroundColor Green
exit 0
