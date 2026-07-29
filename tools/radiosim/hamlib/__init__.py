"""Simulators PORTED FROM HAMLIB -- an INDEPENDENT reference.

WHY THIS PACKAGE IS SEPARATE FROM THE ONES ABOVE IT
---------------------------------------------------
The simulators in radiosim/ (kenwood.py, icom.py, ...) were written FOR TR4W:
their responses are laid out to match what TR4W's drivers parse.  That makes them
useful for regression and useless for validation -- if a driver and its sibling
simulator agree, all that proves is that the same author held the same belief
twice.  radiosim/core.py says as much in its own header.

The modules in THIS package are line-by-line ports of the C simulators in
hamlib's simulators/ directory.  Hamlib is an independent implementation, written
by other people from the same radio manuals, so agreement between a TR4W driver
and one of these IS evidence.  Disagreement is a question worth answering.

PROVENANCE
    source: https://github.com/Hamlib/Hamlib  simulators/*.c
    tree:   C:\\Users\\toms\\projects\\Hamlib
    rev:    c7fb0fa  ("Merge GitHub PR #2108")
    ported: 2026-07-29

THE ONE RULE FOR EDITING ANYTHING IN HERE
-----------------------------------------
A port is derived from the C source and from NOTHING ELSE.  Never adjust a
response because a TR4W driver expects something different -- that converts the
independent reference into a mirror of our own assumptions, which is exactly the
failure this package exists to avoid.

That includes hamlib's BUGS.  Where the C does something obviously wrong, the
port reproduces it and says so in a comment.  A faithful port of a flawed
reference is still independent evidence; a "corrected" one is not evidence at
all.

WHAT THESE CAN AND CANNOT TELL YOU
----------------------------------
Hamlib's simulators are test fixtures for hamlib's own test suite, not
conformance models of the radios.  simts450, for instance, answers IF; from a
hardcoded template with only the frequency patched in -- mode, split, RIT and TX
are frozen.  So they are good evidence about:

    - framing and terminator handling
    - command acceptance (does the radio recognise what we send at all)
    - frequency set/read round-trips
    - the SHAPE and LENGTH of a response

and no evidence at all about state transitions those fixtures do not model.

If TR4W sends a command one of these does not answer, that is a FINDING -- either
hamlib does not believe the radio has it, or the sim is just shallow.  Work out
which; do not add the command here to make a bench run clean.

Truth hierarchy is unchanged: manufacturer manual, then an independent
implementation (this package, or hamlib's rigs/ backends), then TR4W's own
shipping code, then a TR4W-authored simulator.
"""
