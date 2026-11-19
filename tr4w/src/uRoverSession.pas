unit uRoverSession;

(* WHICH PLACES A CONTEST'S ROVER MAY OPERATE FROM -- issues 133 and 87.

  THE CONTEST'S OWN UNITS, BY THE RULE THE NEW CONTEST DIALOG ALREADY USES: the
  keys of the county file its host-area box offers
  (TContestBase.DescribeNewContestHostArea -> PlacesFile, read by
  uNewContestHostArea.THostAreaPlaces). So a rover chooses from exactly the
  list a fixed station inside the area chooses its MY STATE from -- a Hawaii
  district, a Georgia county -- and nothing set-up would judge out of area.

  HOW MANY AT ONCE IS THE CLASS'S: a state party's CountyLineCountiesMax (two
  for Hawaii, four for California, unlimited where the class states none);
  one for a contest that is no state party. A contest whose box names no file
  has no rover places, and ROVER says so. *)

{$I tr4w.inc}

interface

uses
   uContestBase,          (* TContestBase *)
   uNewContestHostArea;   (* THostAreaPlaces *)

(* aContest's rover places loaded into aPlaces, and how many may be active at
  once in aMaxUnits. False, with aPlaces empty, when the contest has none. *)
function ContestRoverPlaces(const aContest: TContestBase;
                            const aPlaces: THostAreaPlaces;
                            out aMaxUnits: integer): boolean;

implementation

uses
   SysUtils,
   uAppPaths,                  (* ShippedDomFilePath -- set-up's own path *)
   uDomFileKeys,               (* DOM_EXTENSION *)
   uContestStateQSOPartyBase;  (* CountyLineCountiesMax *)

function ContestRoverPlaces(const aContest: TContestBase;
                            const aPlaces: THostAreaPlaces;
                            out aMaxUnits: integer): boolean;
var
   area: TNewContestHostArea;
begin
   aMaxUnits := 1;
   aPlaces.Keys.Clear;
   aPlaces.Displays.Clear;
   Result := False;
   if aContest = nil then
      begin
      Exit;
      end;
   if not aContest.DescribeNewContestHostArea(area) then
      begin
      Exit;
      end;
   if area.PlacesFile = '' then
      begin
      Exit;
      end;

   aPlaces.LoadFromFile(ShippedDomFilePath(area.PlacesFile + string(DOM_EXTENSION)));
   if aContest is TContestStateQSOPartyBase then
      begin
      aMaxUnits := TContestStateQSOPartyBase(aContest).CountyLineCountiesMax;
      end;
   if aMaxUnits < 1 then
      begin
      aMaxUnits := 1;
      end;
   Result := aPlaces.Count > 0;
end;

end.
