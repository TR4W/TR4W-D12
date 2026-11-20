unit uCabrilloActivation;

(* ONE CABRILLO FILE PER ACTIVATION -- issues 133 and 87, rover step F (NY4I,
  2026-11-18 and 2026-11-19).

  A rover keeps ONE log for the whole event; each QSO is stamped with the
  place it was sent from (log schema 12, my_rover_qth). A contest whose rules
  want a separate log per activation (TContestBase.SplitsCabrilloByActivation
  -- the Hawaii QSO Party: "Such mobile stations must submit a separate log
  for each activation") has its Cabrillo export split by that place: one file
  per activation, each with its own header and sent QTH. A boundary QSO is
  already two rows (uRoverState.RoverBoundaryLegs), one per place, so each
  file gets its own leg.

  THE ACTIVATION OF A ROW IS THE PLACE ITS SENT COLUMN PRINTS -- the caller
  hands in PostUnit.CurrentMyStationExchange(...).MyState, which is the
  rover's place (ceRoverQTH) where it has one and the row's sent state
  otherwise (a QSO logged before roving). One rule, so a file's activation
  and its sent-QTH column cannot disagree.

  EVERY FILE'S CLAIMED-SCORE IS THE WHOLE LOG'S (NY4I, 2026-11-19: "the
  activations are ALL PART OF THE SAME SCORE"). That is the caller's: it
  reads the score once and writes it in every header.

  A LEAF: no store, no contest, no settings. The export walks the log and
  feeds each exported row in with Add; everything it then asks is answered
  from what was added, so the rules are pinned without a log
  (uTestCabrilloActivation). *)

{$I tr4w.inc}

interface

uses
   Classes;

type
   TCabrilloActivations = class
   private
      (* The places, in the order their first row was met. *)
      FPlaces: TStringList;
      (* Parallel to FPlaces: did any of that place's rows rove? *)
      FRoved: array of boolean;
      FAnyRoved: boolean;
      (* The call every added row was exported with, while they agree. *)
      FCommonRowCall: string;
      FRowCallsDiffer: boolean;
      FRowCount: integer;
   public
      constructor Create;
      destructor Destroy; override;

      (* ONE EXPORTED ROW: aPlace is the place its sent column prints (upper
        cased and trimmed here), aRoved whether it was sent while roving (its
        ceRoverQTH is set), aRowCall the call its QSO line would carry in a
        single file (uLogSource.ExportCallFor of its own facts). *)
      procedure Add(const aPlace: string; aRoved: boolean; const aRowCall: string);

      (* How many activations: distinct places. *)
      function Count: integer;
      function Place(aIndex: integer): string;
      function Roved(aIndex: integer): boolean;
      function AnyRoved: boolean;
      function IndexOfPlace(const aPlace: string): integer;

      (* SPLIT THE CABRILLO? Only where the contest says so (aContestSplits),
        the log really roved, and there are two activations or more. Anything
        else writes the one file it always wrote -- so a Hawaii log that never
        roved, and every other contest's, exports exactly as before. *)
      function ShouldSplit(aContestSplits: boolean): boolean;

      (* THE CALL OF ACTIVATION aIndex -- its CALLSIGN: header AND every QSO
        line of its file. A place that roved signs aPlainCall + '/' + place
        (AH7RF/KOH: the HQP homepage, "AH7RF/KOH is a different station than
        AH7RF/KON"), also for its boundary rows, whose stored my_call is the
        joined call (AH7RF/KOH/KON). A place that never roved -- the rows
        logged before roving -- signed the plain call on the air, so its file
        says aPlainCall. aPlainCall is the log's own call (the declared call,
        never a call with a rover suffix stripped back off). *)
      function ActivationCall(aIndex: integer; const aPlainCall: string): string;

      (* THE FILE NAME TAG OF ACTIVATION aIndex -- "<log>-<tag>.log" through
        uLogDatabase.LogExportFileNameTagged: the place in lower case, any
        character that is not a letter or a digit as '_'; 'noqth' for a place
        that is empty (no MY STATE). *)
      function FileTag(aIndex: integer): string;

      (* THE CALLSIGN: HEADER OF THE ONE UNSPLIT FILE. aSessionCall (MY CALL,
        as it always was), unless the log roved and every exported row carries
        the same call -- a rover that stayed in one place, NY4I/KOH -- when the
        header says that call, so it matches every QSO line under it. A log
        whose rows carry different calls keeps aSessionCall: there is no one
        call to name. *)
      function SingleFileHeaderCall(const aSessionCall: string): string;
   end;

implementation

uses
   SysUtils,
   uQsoMyFacts;   (* AssembledCall -- the one call assembly *)

constructor TCabrilloActivations.Create;
begin
   inherited Create;
   FPlaces := TStringList.Create;
   FPlaces.CaseSensitive := False;
end;

destructor TCabrilloActivations.Destroy;
begin
   FreeAndNil(FPlaces);
   inherited Destroy;
end;

procedure TCabrilloActivations.Add(const aPlace: string; aRoved: boolean;
                                   const aRowCall: string);
var
   key: string;
   index: integer;
begin
   key := UpperCase(Trim(aPlace));
   index := IndexOfPlace(key);
   if index < 0 then
      begin
      (* AnsiString() STATED: the list holds the RTL string; a place is an
        ASCII .dom key. *)
      index := FPlaces.Add(AnsiString(key));
      SetLength(FRoved, FPlaces.Count);
      FRoved[index] := False;
      end;
   if aRoved then
      begin
      FRoved[index] := True;
      FAnyRoved := True;
      end;

   if FRowCount = 0 then
      begin
      FCommonRowCall := aRowCall;
      end
   (* UnicodeSameText: SysUtils.SameText takes AnsiString here (narrowing). *)
   else if not UnicodeSameText(FCommonRowCall, aRowCall) then
      begin
      FRowCallsDiffer := True;
      end;
   Inc(FRowCount);
end;

function TCabrilloActivations.Count: integer;
begin
   Result := FPlaces.Count;
end;

function TCabrilloActivations.Place(aIndex: integer): string;
begin
   Result := string(FPlaces[aIndex]);
end;

function TCabrilloActivations.Roved(aIndex: integer): boolean;
begin
   Result := FRoved[aIndex];
end;

function TCabrilloActivations.AnyRoved: boolean;
begin
   Result := FAnyRoved;
end;

function TCabrilloActivations.IndexOfPlace(const aPlace: string): integer;
begin
   Result := FPlaces.IndexOf(AnsiString(UpperCase(Trim(aPlace))));
end;

function TCabrilloActivations.ShouldSplit(aContestSplits: boolean): boolean;
begin
   Result := aContestSplits and FAnyRoved and (FPlaces.Count >= 2);
end;

function TCabrilloActivations.ActivationCall(aIndex: integer;
                                             const aPlainCall: string): string;
begin
   Result := aPlainCall;
   if Roved(aIndex) then
      begin
      (* THE ONE ASSEMBLY (NY4I, 2026-11-20, ruling 6): the call as set and
         the activation's place -- uQsoMyFacts.AssembledCall, which RovingCall
         and every Cabrillo QSO line use too. *)
      Result := AssembledCall(aPlainCall, Place(aIndex));
      end;
end;

function TCabrilloActivations.FileTag(aIndex: integer): string;
var
   i: integer;
begin
   Result := LowerCase(Place(aIndex));
   for i := 1 to Length(Result) do
      begin
      if not CharInSet(Result[i], ['a'..'z', '0'..'9']) then
         begin
         Result[i] := '_';
         end;
      end;
   if Result = '' then
      begin
      Result := 'noqth';
      end;
end;

function TCabrilloActivations.SingleFileHeaderCall(const aSessionCall: string): string;
begin
   Result := aSessionCall;
   if FAnyRoved and (FRowCount > 0) and (not FRowCallsDiffer) and
      (FCommonRowCall <> '') then
      begin
      Result := FCommonRowCall;
      end;
end;

end.
