(*
 Copyright Thomas M. Schaefer, NY4I (c) 2026.

 This file is part of TR4W  (SRC)

 TR4W is free software: you can redistribute it and/or
 modify it under the terms of the GNU General Public License as
 published by the Free Software Foundation, either version 2 of the
 License, or (at your option) any later version.

 TR4W is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General
     Public License along with TR4W in  GPL_License.TXT.
If not, ref:
http://www.gnu.org/licenses/gpl-3.0.txt
 *)

(* THE CONTEST FACTORY -- ONE CLASS PER CONTEST, AS THE RADIO FACTORY IS ONE
  CLASS PER RADIO.

  NY4I: "a contest factory to go along with the radio factory we already have",
  and from CLAUDE.md: "we want to do this once. Refactoring is not as important
  a factor as getting the object model correct."

  WHY THE UNIT IS A CONTEST AND NOT A STRATEGY ENUM. TR4W already decomposes a
  contest into strategy enums -- QSOPointMethodType, ExchangeType, DXMultType,
  PrefixMultType, ZoneMultType -- each dispatched by its own `case`, and it
  would be less work to turn each enum into a class. That is the wrong object
  model for this program:

    A CONTEST IS THE THING THAT EXISTS. An operator selects ARRL-DX-CW, not a
    point method. ContestsArray is already a row per contest; the enums are how
    that row is currently SPELLED, not what it is.

    THE ENUMS DO NOT COMPOSE CLEANLY. CalculateQSOPoints branches on the point
    method and then, inside several arms, on Contest anyway -- because scoring
    depends on things the enum does not carry. Splitting by enum keeps that
    second branch; splitting by contest removes it.

    A NEW CONTEST WOULD STILL TOUCH SHARED FILES. Adding a radio touches its own
    unit, tr4w.lpr and the test .lpr -- verified when TCI was added. That is the
    property worth copying, and only one-class-per-contest gives it.

  INHERITANCE CARRIES THE FAMILIES. ARRL DX, ARRL Sweepstakes and Field Day
  share far more with each other than with CQ WW, and QSO parties share almost
  everything. Those are base classes, and a contest overrides what it actually
  differs in.

  THE RULE THE RADIO FACTORY LEARNED THE HARD WAY APPLIES HERE UNCHANGED:
  A BASE CLASS MUST NEVER ASK WHICH CONTEST IT IS. The subclass declares the
  trait; the base guards on the trait. Three defects in one afternoon had the
  shape `if RadioModel in [FT857, FT897]`, and `if Contest = ...` inside a base
  would be the same mistake with different nouns.

  STRANGLER, NOT REWRITE -- the pattern CLAUDE.md names for both existing
  factories: "thin adapters over the existing globals first, prove the seam on
  hardware, then delete the legacy path". A contest that has no class here falls
  through to the legacy `case` untouched, so the two can coexist for as long as
  it takes, and the golden corpus proves each move byte for byte. *)
unit uContestBase;

{$I tr4w.inc}

interface

uses
   VC;

type
   (* WHAT SCORING KNOWS ABOUT US.

      Contest rules are a function of two things: the QSO, and the station
      making it. The QSO arrives as a parameter; this is the other half.

      IT IS A SNAPSHOT, NOT A VIEW OF THE GLOBALS, and that is the point. MyCountry
      and its neighbours live in LOGWIND, PostUnit and elsewhere -- read them
      directly and every one of ~200 contest classes acquires a dependency on the
      display layer and cannot be tested without booting the program. Taken once,
      here, they become data a test can construct.

      IT GROWS AS CONTESTS ARE MOVED. Adding a field is adding one line here and
      one in Refresh; guessing at every field 88 point methods might want, before
      moving them, would be inventing a structure to fit code nobody has read
      yet. *)
   TStationContext = record
      MyCountry: CallString;
   end;

   TContestBase = class
   private
      FContest: ContestType;
      FStation: TStationContext;
   protected
      (* WHICH CONTEST THIS INSTANCE IS -- READABLE BY SUBCLASSES, AND NOT TO BE
         BRANCHED ON.

         It exists for diagnostics and for the few places that legitimately need
         to name the contest in a message. A subclass that reads it to decide
         BEHAVIOUR has reintroduced the thing this class removes: state the
         behaviour as an override, or as a trait on the base. *)
      property Contest: ContestType read FContest;

      (* The station, as it was when this contest object was made or last
         refreshed.  Subclasses read this instead of the globals. *)
      property Station: TStationContext read FStation;
   public
      constructor Create(aContest: ContestType); virtual;

      (* THE CONTEST'S NAME, for logging and for the "which class am I" question
         a bench session asks. Defaults to the enum's own spelling. *)
      function DisplayName: string; virtual;

      (* SCORING. Sets aQso.QSOPoints, and nothing else -- multipliers and dupe
         state are decided elsewhere and a scorer that changed them would make
         the order of the two calls significant.

         The base scores nothing. That is deliberate rather than a placeholder:
         NoQSOPointMethod is a real value in QSOPointMethodType and it means
         exactly this, so a contest that does not score is not a special case. *)
      procedure CalculateQSOPoints(var aQso: ContestExchange); virtual;

      (* Re-reads the station snapshot from the program's globals.

         CALLED BEFORE EVERY SCORE rather than once at construction. MyCountry is
         recomputed whenever MY CALL changes -- from the .cfg, from the log's
         stored configuration, from the operator editing it mid-contest -- and a
         contest object holding the value from startup would score the rest of
         the log against a station that has moved. It is a few field copies. *)
      procedure RefreshStation;
   end;

   TContestClass = class of TContestBase;

implementation

uses
   (* THE ONE PLACE IN THE FACTORY THAT TOUCHES THE PROGRAM'S GLOBALS.
      LOGWIND holds MyCountry. Keeping this in the base means a contest class
      is a function of (station, QSO) and nothing else. *)
   LOGWIND;

constructor TContestBase.Create(aContest: ContestType);
begin
   inherited Create;
   FContest := aContest;
   RefreshStation;
end;

procedure TContestBase.RefreshStation;
begin
   FStation.MyCountry := MyCountry;
end;

function TContestBase.DisplayName: string;
begin
   Result := string(ContestTypeSA[FContest]);
end;

procedure TContestBase.CalculateQSOPoints(var aQso: ContestExchange);
begin
   aQso.QSOPoints := 0;
end;

end.
