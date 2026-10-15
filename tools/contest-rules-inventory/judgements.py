"""judgements.py -- the ONLY place this inventory states an opinion.

Everything else is computed from the tree. What is here was decided by reading
code, and is data rather than logic so that a reviewer can see every judgement
in one file:

   ROUTINES        which category a routine's contest rules belong to, and the
                   factory seam they would move to
   SITE_OVERRIDES  the few sites that do not belong to their routine's category
   CATEGORIES      the section order of the tables
   SHAPE_MACHINES  the routines keyed on the exchange SHAPE, whose arms are
                   data formats rather than contest rules (M11 S0a)
   FAMILY_MAX      the reach threshold between "a contest rule in disguise" and
                   "shared behaviour"
   GENERIC         reach-2-3 values whose NAME is generic -- flagged, not dropped
   SHAPE3          the string-identified sites that were read and kept

NO LINE NUMBERS. The throwaway version keyed SHAPE3 and the overrides by line,
which is wrong the first time someone edits the file above them. They are keyed
by a regex over the code-only line (comments stripped, strings kept) and an
EXPECTED MATCH COUNT; generate.py fails if the count is not met, because a
pattern that stopped matching means the code moved under a judgement and a
human has to look again.

Existing TContestBase virtuals (uContestBase.pas) are named exactly; anything
else is "new seam needed: <name>". "(s6)" marks a name docs/ADDING_A_CONTEST.md
section 6 already reserves.
"""

import re


def new(name):
   return f"new seam needed: {name}"


CATEGORIES = [
   ("scoring", "Scoring"),
   ("exchange", "Exchange parsing and validation"),
   ("dupe", "Dupe"),
   ("multipliers", "Multipliers"),
   ("adif-import", "ADIF import"),
   ("adif-export", "ADIF export"),
   ("cabrillo-export", "Cabrillo export"),
   ("score-summary", "Score, summary and totals"),
   ("ui", "UI, display and the new-contest dialog"),
   ("setup", "Setup (FoundContest / LogCfg)"),
   ("networking", "Networking and score reporting"),
   ("other", "Other"),
]

# Keyed by (file base name, routine). Pascal is case-insensitive, so lookups
# fold case; the spellings below are the declarations'.
ROUTINES = {
   # ---------------------------------------------------------------- scoring
   ("logstuff.pas", "CalculateQSOPoints"): ("scoring", "CalculateQSOPoints (existing)"),
   ("logdupe.pas", "CheckMOQSOPartyBonusStation"): ("scoring", new("CalculateTotalScore (s6)")),
   ("MainUnit.pas", "LoadinLog"): ("scoring", new("CalculateTotalScore (s6)")),
   ("logsubs2.pas", "LogContact"): ("scoring", new("CalculateTotalScore (s6)")),
   # ------------------------------------------------- exchange parsing/validation
   # ProcessExchange's blank-exchange gate left at M11 S7: the contest answers
   # AcceptsBlankExchange. It reads no session kind (it hands the shape on).
   ("logstuff.pas", "ProcessRSTAndDomesticQTHExchange"): ("exchange", new("ParseReceivedExchange (s6)")),
   # ProcessRSTAndGridSquareOrRDAExchange named the UA4W Championship until its class (2026-10-14).
   ("logstuff.pas", "ProcessRSTAndQSONumberExchange"): ("exchange", new("ParseReceivedExchange (s6)")),
   ("logstuff.pas", "ProcessRSTAndQSONumberOrDomesticQTHExchange"): ("exchange", new("ParseReceivedExchange (s6)")),
   ("logstuff.pas", "ProcessRSTAndZoneExchange"): ("exchange", new("ParseReceivedExchange (s6)")),
   ("logstuff.pas", "ProcessRSTQSONumberAndPossibleDomesticQTHExchange"): ("exchange", new("ParseReceivedExchange (s6)")),
   ("logstuff.pas", "ValidClass"): ("exchange", "ValidateClass (existing) -- already answers first; see dead code"),
   # DomStringParse's five domestic-kind arms left at M11 S6 part 1: the
   # contest answers DomesticMultiplierHint. It reads no session kind.
   ("logstuff.pas", "LooksLikeACallSign"): ("exchange", new("IsAcceptableCallsign")),
   ("uCallSignRoutines.pas", "IsAGoodCall"): ("exchange", new("IsAcceptableCallsign")),
   # GetDomQTH's six domestic-kind arms left at M11 S6 part 1: the contest
   # answers DomesticMultiplierFromQTH (base: the domestic file); its
   # no-domestic exit asks HasDomesticMultiplier since M11 S6 part 2. It reads
   # no session kind.
   # SetUpExchangeInformation is DELETED (M11 S9a): each contest states
   # ReceivedExchangeFields, calling a uExchangeFields helper.
   # ParseExchangeIntoContestExchange is DELETED (M11 S9e part 1, plan F29):
   # its FISTS placement was dead code -- its only caller chain began at
   # LogBackCopy, which nothing called.
   ("logdupe.pas", "GetInitialExchangeStringFromContestExchange"): ("exchange", new("InitialExchangeFromHistory")),
   ("logedit.pas", "InitialExchangeEntry"): ("exchange", new("InitialExchangeFromHistory (InitialExchangeKind is the existing trait)")),
   ("zonecont.pas", "GetVEInitialExchange"): ("exchange", new("InitialExchangeFromHistory")),
   # MainUnit's exchange-shape rules left at M11 S7, each now the contest's
   # answer: ParametersOkay's blank exchange (AcceptsBlankExchange),
   # ExchangeWindowChange's park lookup (OffersParkTools), the two rover
   # routines (StripsRoverCountyFromCall) and ReturnInSAPOpMode's several
   # QTHs (LogsSeveralQTHsFromOneEntry). ProcessReturn's split was deleted.
   # ------------------------------------------------------------------ dupe
   ("logedit.pas", "EditableLog.CallIsADupe"): ("dupe", new("DupeRule")),
   # ----------------------------------------------------------- multipliers
   ("logdupe.pas", "DupeAndMultSheet.SetMultFlags"): ("multipliers", new("MultiplierValue (s6)")),
   # GetDXQTH's `case` on the DX kind left at M11 S4 (part 1): the contest
   # states its key (DXMultiplierKey). Its head's WYSIWYG domestic test left
   # at M11 S6 part 1 (DomesticQTHReplacesDXMultiplier). It reads no session
   # kind.
   # LOGDUPE.SetUpRemainingMultiplierArrays left at M11 S5: its `case` on the
   # zone kind at part 1 (the contest answers ZoneMultiplierCount), its
   # DoingZoneMults gate at part 2 (the contest answers HasZoneMultiplier).
   # It reads no session kind.
   ("logedit.pas", "EditableLog.GetMultArray"): ("multipliers", new("DomesticMultFromQTH")),
   # logedit.SetPrefix left at M11 S3: it names no contest and reads no kind --
   # the contest states its key (PrefixMultiplierKey) and whether it has one
   # (HasPrefixMultiplier); PrefixMultiplierType is deleted (part 2).
   # The EUHFCYear zero-based test left ShowRemMultsInWindow (its nested Add)
   # at M11 S5 part 1: the contest answers NumbersZonesFromZero. The row
   # went at part 2, when ZoneMultType was deleted; nothing there reads a
   # session kind.
   # uMults.FillVisibleBytes left at M11 S4: its three DX-kind filters at part 1
   # (the contest answers ListsRemainingDXCountry), its DoingDXMults gate at
   # part 2 (the contest answers HasDXMultiplier). It reads no session kind.
   # ------------------------------------------------------------ ADIF import
   # ApplyContestSpecificADIFTail and ProcessImportedSRX_String were deleted in M5a (1908626e).
   # ApplyClasslessADIFImport went when its last contest gained a class -- ARRL 160 at M7b,
   # POTA on 2026-10-13 (Q6); ResolvePOTAParkFromADIF is the leaf uPOTAReference's now.
   ("uPOTAReference.pas", "ResolvePOTAParkFromADIF"): ("adif-import", "ApplyADIFImport (existing; TContestPOTA's helper, a leaf)"),
   ("uADIF.pas", "ApplyADIFFieldsToExchange"): ("adif-import", new("ApplyADIFImport (APP_N1MM_EXCHANGE1)")),
   # ------------------------------------------------------------ ADIF export
   # M4 (2026-10-01): every contest is asked through ContestIdentity, and
   # these three seams exist. FormatsExchange is gone.
   ("postunit.pas", "EmitContestSpecificTailForExport"): ("adif-export", "EmitADIFContestFields (existing)"),
   ("uADIF.pas", "EmitADIFRecord"): ("adif-export", "ADIFContestId / WritesADIFContestId / ADIFPowerTag (existing)"),
   # uADIFExchange.FormatADIFExchangeOfKind was DELETED (M11 S9b, 2026-10-14):
   # each class states TContestBase.GetADIFSentExchange, calling a uADIFExchange
   # helper; the file holds named helpers and no routine keyed on a kind.
   # The one contest test left in those helpers is the TRC Digital state, which
   # has no ContestType (SHAPE3 below): a class of its own when it is a contest.
   ("uADIFExchange.pas", "ADIFSentRSTQSONumberState"): ("adif-export", "GetADIFSentExchange (existing, M11 S9b; TRC Digital has no ContestType)"),
   # -------------------------------------------------------- Cabrillo export
   ("postunit.pas", "GetCabrilloTagText"): ("cabrillo-export", "CabrilloContestName / RequiresCabrilloLocation / CabrilloHeaderLinesBeforeTag (existing, M9a)"),
   ("postunit.pas", "tGenerateLogPortionOfCabrilloFile"): ("cabrillo-export", "FormatCabrilloReceivedExchange / CabrilloQSOLineFormat / CabrilloModeString (existing; CabrilloModeString M9a)"),
   # uCabrilloExchange.FormatCabrilloExchangeOfKind (and the nested SetHisEx
   # the walker attributed its arms to) was DELETED (M11 S9c, 2026-10-14):
   # each class states TContestBase.GetCabrilloSentExchange and
   # GetCabrilloReceivedExchange, calling a uCabrilloExchange helper; the file
   # holds named helpers and no routine keyed on a kind. The contest tests left
   # in those helpers are the TRC Digital state and the PGA title, which have
   # no ContestType (SHAPE3 below): a class of their own when they are contests.
   ("uCabrilloExchange.pas", "CabrilloSentRSTQSONumberState"): ("cabrillo-export", "GetCabrilloSentExchange (existing, M11 S9c; TRC Digital and PGA have no ContestType)"),
   ("uCabrilloExchange.pas", "CabrilloReceivedRSTQSONumberQTH"): ("cabrillo-export", "GetCabrilloReceivedExchange (existing, M11 S9c; TRC Digital and PGA have no ContestType)"),
   # ---------------------------------------------------- score/summary/totals
   # logedit.TotalScore named RSGB 1.8 MHz until its class (2026-10-14); it names no contest now.
   ("postunit.pas", "WriteScoreInformationToSummarySheet"): ("score-summary", "SummarySheet (existing, M9a)"),
   ("postunit.pas", "PrintHourTotals"): ("score-summary", "ReportsRunningScore (existing, M9a)"),
   ("uTotal.pas", "UpdateTotals2"): ("score-summary", "TotalsDisplay (existing, M9a)"),
   ("postunit.pas", "CheckForNewContestDate"): ("score-summary", new("MaxContestDates")),
   ("postunit.pas", "CalculateTotals"): ("score-summary", new("OffTimeMinimumMinutes")),
   # ------------------------------------------------- UI / display / dialogs
   ("MainUnit.pas", "CreateMainWindow"): ("ui", "PermittedOperatingAids / OffersQTCs (existing, M9a) / OffersParkTools (existing, POTA 2026-10-13) + " + new("UIFeatures (off-time)")),
   ("MainUnit.pas", "OpenTR4WWindow"): ("ui", "PermittedOperatingAids (existing, M9a)"),
   ("MainUnit.pas", "BuildLogRow"): ("ui", new("LogColumns")),
   # SetColumnsWidth's Sweepstakes columns left at M11 S9e part 1 (F15/F15a):
   # they ask the contest's received-field list (uExchangeFields).
   # TREE.LooksLikeAGrid's kind set left with them (S9f): the contest
   # answers ExchangeTextMayHoldGridSquare.
   ("MainUnit.pas", "ReturnInCQOpMode"): ("ui", new("ShowsMultiplierStatus")),
   ("MainUnit.pas", "CallWindowChange"): ("ui", new("OnCallsignChanged")),
   ("logedit.pas", "ShowStationInformation"): ("ui", new("ShowsMultiplierStatus")),
   ("logedit.pas", "EditableLog.SuperCheckPartial"): ("ui", "PermittedOperatingAids (existing, M9a)"),
   ("logwind.pas", "SetUpBandMapEntry"): ("ui", new("ShowsMultiplierStatus")),
   ("logsubs2.pas", "OperateContest"): ("ui", new("ShowsMultiplierStatus")),
   ("logstuff.pas", "BandChange"): ("ui", new("AllowsWARCBands")),
   # uNewContest.ClasslessPrompts was deleted when its last contests gained classes (RSGB 1.8, UA4W; 2026-10-14).
   ("uNewContest.pas", "ApplyContestChoice"): ("ui", "DescribeNewContestPrompts (existing, M9a)"),
   # ------------------------------------------------------------------ setup
   ("fcontest.pas", "FoundContest"): ("setup", new("ConfigureSession (the FoundContest arm)")),
   # SetUpRSTMyZoneExchange's CQ WW RTTY state left at M11 S7: the contest
   # answers SendsStateAfterZone. FoundContest's closing sent-message case
   # over the exchange kind left at M11 S9e part 1 (F30): each contest calls
   # a TExchangeMessageWriters method from WriteDefaultExchangeMessages.
   # LogCfg.tSetupExchangeNumbers named the UA4W Championship until its class (2026-10-14); CQExchangeDefault now.
   # -------------------------------------------------------------- networking
   ("logsubs2.pas", "SendScoreToUDP"): ("networking", "ScorePostingMultiplierType (existing, M9a)"),
   ("uExchangeBuilder.pas", "BuildSentExchangeText"): ("networking", "CanonicalSentExchange (existing, M9a)"),
   ("uExchangeBuilder.pas", "BuildRxExchangeText"): ("networking", "CanonicalReceivedExchange (existing, M9a)"),
   # ------------------------------------------------------------------ other
   # The four logddx (DDX simulator) rows went with the unit, deleted by
   # NY4I's Q91 ruling (2026-10-14): nothing had compiled it since D7.
}

# A site that does not belong to its routine's category. Keyed by (file base,
# routine, regex over the code-only line); each must match at least one site.
# The logsubs2 dupe-marking site (ActiveQSOPointMethod = AlwaysOnePointPerQSO)
# left this list at M3 (2026-10-01): it asks TContestBase.MarksDupes now.
SITE_OVERRIDES = [
   ("MainUnit.pas", "LoadinLog", r"\bcontest\s*=\s*RADIOYOC\b",
    ("exchange", new("SessionExchangeState (previous QSO number)"))),
]

# THE EXCHANGE-SHAPE MACHINES (M11 S0a, plan F1 and 0.1). Each is keyed on the
# exchange SHAPE -- how an exchange is spelled -- and holds one arm per shape,
# so a reach-1 arm there is a data format one contest uses, not a contest rule
# in disguise. Q92 (NY4I, option 2) turns each into named helpers the classes
# call, one machine per stage; until a machine goes its arms are judged SHAPE,
# counted and never tabled as PROXY. Keyed (file base, routine). The one
# left takes the shape as a parameter the scan does not follow, and is named
# so that widening the scan cannot table its arms as contest rules.
# ~~("logdupe.pas", "SetUpExchangeInformation")~~ was the one the scan reached
# (through scan.KIND_PARAMETERS); it is DELETED (M11 S9a, 2026-10-14) -- each
# class states TContestBase.ReceivedExchangeFields, calling uExchangeFields.
# ~~("uADIFExchange.pas", "FormatADIFExchangeOfKind")~~ is DELETED too (M11
# S9b, 2026-10-14) -- each class states TContestBase.GetADIFSentExchange,
# calling a uADIFExchange helper.
# ~~("uCabrilloExchange.pas", "SetHisEx")~~ is DELETED too (M11 S9c,
# 2026-10-14) -- each class states TContestBase.GetCabrilloSentExchange and
# GetCabrilloReceivedExchange, calling uCabrilloExchange helpers.
# ~~("logstuff.pas", "ParseExchangeShape")~~ is DELETED too (M11 S9d,
# 2026-10-15) -- each class states TContestBase.ParseReceivedExchangeFormat,
# calling the engine's parser for its format by name on
# uContestBase.TExchangeParsers (LOGSTUFF's TEngineExchangeParsers). NO
# SHAPE MACHINE IS LEFT: the set is empty and stays so; a routine keyed on
# the exchange kind is a reader for the deletion stage (S9e), not a machine.
SHAPE_MACHINES = set()

# Reach 1 is unambiguous. Reach 2-3 is kept as a proxy because it is almost
# always a CW/SSB pair or one sponsor's family. 4 or more is shared behaviour.
FAMILY_MAX = 3

# Values reaching 2-3 contests whose NAME describes a generic shape rather than
# a contest. They stay in the tables, flagged GENERIC-NAMED, to be judged one
# by one rather than silently reclassified.
GENERIC = {x.upper() for x in [
   "ThreePointsPerQSO", "AlwaysOnePointPerQSO", "TenPointsPerQSO",
   "RSTNameAndQTHExchange", "RSTAndPOTAPark", "GridExchange",
   "QSONumberDomesticOrDXQTHExchange", "RSTQSONumberAndDomesticQTHExchange",
   "RSTAgeExchange", "ARRLDXCCWithNoARRLSections"]}

# Shape 3: a contest identified by a STRING. scan_strings() in scan.py lists
# CANDIDATES; these are the ones that were read and kept, because they TEST a
# name, a title, a station state or a sponsor callsign. (Dropped: translation
# tables whose text happens to equal a domestic-file name, FoundContest
# ASSIGNING a name, and 'POTA' emitted inside an already-POTA branch.)
#
# (file, regex over the code-only line with strings kept, expected matches,
#  contests, note). Each match becomes one row.
SHAPE3 = [
   ("tr4w/src/MainUnit.pas", r"pos\s*\(\s*'CQ-WW'\s*,\s*ContestTypeSA\s*\[\s*Contest\s*\]", 1,
    ["CQWWCW", "CQWWSSB", "CQWWRTTY", "IARU"],
    "`Pos('CQ-WW'` / `'IARU-HF'` in `ContestTypeSA[Contest]` -- 60-minute off-time"),
   ("tr4w/src/trdos/postunit.pas", r"pos\s*\(\s*'CQ-WW'\s*,\s*Settings\.Contest\.Name\s*\)", 1,
    ["CQWWCW", "CQWWSSB", "CQWWRTTY"],
    "`Pos('CQ-WW', Settings.Contest.Name)` -- 60-minute off-time"),
   ("tr4w/src/uCabrilloExchange.pas", r"\bContestTitle\s*=\s*'PGA'", 2, [],
    "`ContestTitle = 'PGA'` -- no ContestType; operator-titled"),
   ("tr4w/src/uCabrilloExchange.pas", r"\baMy\.MyState\s*=\s*'TRC'", 1, [],
    "`aMy.MyState = 'TRC'` -- TRC Digital, no ContestType (was `cMyState = 'TRC'` until M11 S9c)"),
   ("tr4w/src/uCabrilloExchange.pas", r"\baCtx\.HisQTH\s*=\s*'TRC'", 1, [],
    "`aCtx.HisQTH = 'TRC'` (was `csQTHString = 'TRC'` until M11 S9c)"),
   ("tr4w/src/uADIFExchange.pas", r"\bClippedState\s*\(\s*aMy\s*\)\s*=\s*'TRC'", 1, [],
    "`ClippedState(aMy) = 'TRC'` (was `cMyState = 'TRC'` until M11 S9b)"),
   # The logstuff entries here (TRC, DL-DX-RTTY, EURASIA, YBDXDI-FT8 and the
   # G4FOC/N4T/RAEM/LOCUST bonus calls) went with the legacy scoring case at
   # M10 S3 (2026-10-14); the classes own those rules.
   # logddx's `Settings.Contest.Name = 'Scandinavian Contest'` went with the
   # unit (Q91, 2026-10-14).
   # postunit's `Settings.Contest.Name = 'WWDIGI'` went at M4 (2026-10-01):
   # TContestWWDigi chooses its own received QTH.
   ("tr4w/src/trdos/postunit.pas", r"Settings\.Contest\.Name\s*=\s*'LABRE'", 1, ["LABRE"],
    "`Settings.Contest.Name = 'LABRE'`"),
   ("tr4w/src/trdos/postunit.pas", r"Settings\.Contest\.Name\s*=\s*'EURASIA'", 1, [],
    "`Settings.Contest.Name = 'EURASIA'` -- see dead code"),
   ("tr4w/src/uCallSignRoutines.pas", r"^\s*if\s+Call\s*=\s*'RAEM'", 1, ["RAEM"],
    "`Call = 'RAEM'` accepted as a callsign"),
   # Missouri's W0MA / K0GQ bonus-call test moved onto its class as declared
   # bonus stations in M6 (25e25461).
   # GAGARINCUP's six GC-station callsigns left LOGEDIT.SetPrefix for
   # TContestGagarinCup.PrefixMultiplierKey at M11 S3 (2026-10-14): the rule
   # is its class's own, so it is no longer a row.
   # Lifted from logstuff with ResolvePOTAParkFromADIF to the leaf uPOTAReference
   # when POTA gained its class (2026-10-13), and AnsiUpperCase became UpperCase.
   ("tr4w/src/uPOTAReference.pas", r"UpperCase\s*\(\s*aSIG\s*\)\s*=\s*'POTA'", 1, ["POTA"],
    "ADIF `SIG = 'POTA'` -- the park from `SIG_INFO` (D5, fixed in `3f9e3f28`); TContestPOTA's leaf"),
]

# Contests that exist only as an operator-configured name, with no ContestType.
# Section 6.2 names them, counted from the SHAPE3 rows whose note mentions them.
NAME_ONLY_CONTESTS = [
   ("TRC Digital", "'TRC'", "`cMyState = 'TRC'`"),
   ("PGA", "'PGA'", "`ContestTitle = 'PGA'`"),
]


def classify(file, routine, line_text):
   """((category, seam), override index or None) for a site; the verdict is
   None when no judgement covers it. The index lets the caller prove every
   override still matches something."""
   base = file.split("/")[-1].lower()
   for n, (f, r, rx, verdict) in enumerate(SITE_OVERRIDES):
      if f.lower() == base and r.lower() == routine.lower() and re.search(rx, line_text, re.I):
         return verdict, n
   return _ROUTINES_FOLDED.get((base, routine.lower())), None


_ROUTINES_FOLDED = {(f.lower(), r.lower()): v for (f, r), v in ROUTINES.items()}
_SHAPE_MACHINES_FOLDED = {(f.lower(), r.lower()) for f, r in SHAPE_MACHINES}


def is_shape_machine(file, routine):
   """True when a site sits in one of SHAPE_MACHINES."""
   return (file.split("/")[-1].lower(), routine.lower()) in _SHAPE_MACHINES_FOLDED
