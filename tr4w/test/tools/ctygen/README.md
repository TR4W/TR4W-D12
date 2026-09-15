# `ctygen` — the uCTYDAT characterisation generator

Regenerates `tr4w/test/unit/fixtures/ctydat_characterisation.txt`, the golden
file `uTestCTYDAT.Test_Characterisation` compares against.

## What it is for

`uCTYDAT` is 1,600 lines of prefix tables, hand-built index arrays and a shell
sort, and it decides the **country, zone, continent and grid of every callsign
an operator types**. It had ten tests.

Ten tests are enough to say the answer is RIGHT for nine entities. They are not
enough to rewrite the unit, because a rewrite can be perfectly self-consistent
and still answer differently — and the difference shows up as a wrong
multiplier, mid-contest, on someone's score.

So the golden file records what the implementation ANSWERED on 2026-09-14 for
1,684 callsigns, and the test fails if any of them moves.

## Where the callsigns come from

| | |
|---|---|
| 1,573 | every DISTINCT callsign in the 13 golden-corpus logs — real calls, worked in real contests, DX and domestic |
| 111 | `edge-cases.txt`, hand-picked: district digits, portable prefixes and suffixes, `/MM`, the KG4 two-character rule, unallocated blocks, garbage, empty, length boundaries |

The corpus half matters because it is not a guess about what is hard. When the
KG4 rule was deliberately broken to prove the net has teeth, it caught
**KG4IAL, KG4MYD, KG4OGC, KG4RSP and KG4SRK** — five stations somebody actually
worked — flipping country and zone.

## IT RECORDS BEHAVIOUR, NOT CORRECTNESS

A line in the golden file is what the program told an operator, not what the
DXCC rules say. Where the two disagree the golden is still right about its own
job: a refactor must not change the answer *by accident*. Changing one is a
deliberate decision, with its own commit, and this file is updated in it.

## Regenerating

Only when the answers are meant to change — a new `cty.dat`, or a ruled
behaviour change. Never to make a red build go green.

```powershell
# build it against the test search paths
cd tr4w
. .\build\Find-Toolchain.ps1
. .\build\Get-SearchPaths.ps1
$tc = Find-Tr4wToolchain -Quiet
$sp = 'test\tools\ctygen'
$a = @('-Mdelphi','-Pi386','-Twin32','-Sc','-WG',"-FU$sp",'-dLANG_ENG')
foreach ($p in (Get-Tr4wSearchPaths -Tr4wDir (Get-Location) -Toolchain $tc -For Tests)) { $a += "-Fu$p" }
foreach ($p in (Get-Tr4wIncludePaths -Tr4wDir (Get-Location)))                          { $a += "-Fi$p" }
& $tc.FpcExe @a "$sp\ctygen.lpr"
```

```sh
# the corpus callsigns, then both halves
cat tr4w/test/corpus/*/ref.adi | grep -oiE '<CALL:[0-9]+>[^ <]+' | sed 's/.*>//' | sort -u > calls.txt
ctygen tr4w/target/cty.dat calls.txt corpus-part.txt
ctygen tr4w/target/cty.dat tr4w/test/tools/ctygen/edge-cases.txt edge-part.txt
```

Then concatenate the two record sets under the existing header and write the
result to `tr4w/test/unit/fixtures/ctydat_characterisation.txt` as **CRLF**.

**It links `Interfaces`** — `uCTYDAT` reaches the LCL through its dependency
graph, which is also why this is a standalone program rather than part of the
unit-test binary.

## Adding an edge case

Put the callsign in `edge-cases.txt`, regenerate, and **read the new line
before committing it**. The generator will happily record a wrong answer; the
point of the file is that the answer stops changing silently, not that it is
blessed.
