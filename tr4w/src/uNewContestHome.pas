unit uNewContestHome;

(* DOES MY CALL CONTRADICT THE "I AM IN ..." BOX? -- issue 167 (from the D7
  repository's #365).

  WHY IT EXISTS. A contest that offers "I am in <region>" in the New Contest
  dialog sets the station up by it: inside, it asks for a QTH the sponsor
  gives domestic stations; outside, it does not. An operator who ticks it
  wrongly gets a contest set up for the wrong side, and nothing said so.

  The contest says what the box's region is in CTY terms
  (TContestBase.DescribeNewContestHome): country IDs, or a continent. At OK
  the dialog locates MY CALL and asks this unit whether the box and the call
  agree. When they do not, it asks the operator once; it never changes the
  box itself.

  THE CHECK IS NOT SYMMETRIC FOR EVERY BOX. "I am in Canada" is the whole of
  VE, CY0 and CY9, so a VE call with the box cleared is as wrong as a K call
  with it ticked. "I am in New England" is only part of K: a K call with the
  box ticked may be right or wrong, but a K call with it CLEARED is an
  ordinary out-of-area station. aHomeIsInside says which.

  A LEAF: no form, no contest, no country file. The caller locates the call;
  an unlocated call is never a contradiction, because a missing country file
  is not the operator's mistake. *)

{$I tr4w.inc}

interface

uses
   VC;   (* ContinentType *)

type
   (* WHAT THE BOX AND THE CALL SAY TOGETHER.
       iavAgree             nothing to ask;
       iavTickedOutside     ticked, but the call is not in the region;
       iavClearedInside     cleared, but the call is in it -- only asked when
                            every call of the region is inside the box. *)
   TIAmInVerdict = (iavAgree, iavTickedOutside, iavClearedInside);

(* IS A CALL LOCATED IN aCountryID, ON aCallContinent, IN THE REGION? The
  region is aCountries -- CTY country IDs, blank-separated, compared whole and
  exactly as CTY spells them -- or, when that is empty, aContinent. A region
  of neither ('' and UnknownContinent) holds no call. *)
function HomeHoldsCall(const aCountries: string;
                       aContinent: ContinentType;
                       const aCountryID: string;
                       aCallContinent: ContinentType): boolean;

(* THE VERDICT. aLocated False -- no country file, or a call it does not
  know -- is always iavAgree. *)
function IAmInVerdict(aTicked: boolean;
                      aLocated: boolean;
                      aCallIsHome: boolean;
                      aHomeIsInside: boolean): TIAmInVerdict;

implementation

uses
   SysUtils;

function HomeHoldsCall(const aCountries: string;
                       aContinent: ContinentType;
                       const aCountryID: string;
                       aCallContinent: ContinentType): boolean;
var
   id: string;
begin
   Result := False;
   id := Trim(aCountryID);

   if Trim(aCountries) <> '' then
      begin
      (* A whole word of the list: 'VE' is in 'VE CY0', 'V' is not. *)
      Result := (id <> '') and
                (Pos(' ' + id + ' ', ' ' + aCountries + ' ') > 0);
      Exit;
      end;

   if aContinent <> UnknownContinent then
      begin
      Result := aCallContinent = aContinent;
      end;
end;

function IAmInVerdict(aTicked: boolean;
                      aLocated: boolean;
                      aCallIsHome: boolean;
                      aHomeIsInside: boolean): TIAmInVerdict;
begin
   Result := iavAgree;
   if not aLocated then
      begin
      Exit;
      end;

   if aTicked and (not aCallIsHome) then
      begin
      Result := iavTickedOutside;
      end
   else if (not aTicked) and aCallIsHome and aHomeIsInside then
      begin
      Result := iavClearedInside;
      end;
end;

end.
