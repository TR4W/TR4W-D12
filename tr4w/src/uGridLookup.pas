(*
 Copyright Thomas M. Schaefer, NY4I (c) 2020.
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

(* MAIDENHEAD GRID -> STATE(S), issue 52.

   DATA PROVENANCE AND LICENCE. GRID_STATE_TABLE below is WSJT-X's grid.dat
   (WSJT-X is GPL v3, by Joe Taylor K1JT and the WSJT Development Group),
   converted by script from the grid.txt attached to TR4W issue 52: 695 grids,
   each with one state or several, in the file's own order. It is compiled in
   because NY4I ruled (issue 52) that grids and state borders do not change.
   The conversion: 'EN' + '61:IL-IN' becomes 'EN61=IL-IN'. The file's field
   blocks (EN<...>) are flattened; nothing else was altered. TR4W is GPL, so
   carrying a GPL data table is compatible. Attribution is kept here and in
   .claude/agents/integrations.md.

   THE RULE (NY4I, issue 52): a grid that lies in exactly ONE state names that
   state. A grid in several states is AMBIGUOUS: NO state is inferred (the
   order in the file is not "mostly the first"), and the candidates are
   offered as text, 'possible states for EN61 are IL and IN'. A grid the table
   does not hold is UNKNOWN. A 6-character grid is looked up by its first four
   characters, in any case.

   This unit has no dependencies on the rest of the program, so it is tested
   directly (uTestGridLookup). Who may call it for a QSO is the WSJT-X
   logging path's decision, in uWSJTX. *)

unit uGridLookup;
{$I tr4w.inc}

interface

uses Classes, SysUtils;

const
   GRID_STATE_TABLE_COUNT = 695;

type
   TGridStateKind = (gskUnknown, gskUnique, gskAmbiguous);

   TGridLookup = class(TObject)
   private
      (* Sorted by the four-character grid; Objects[] is the grid's own
         TStringList of states, in the table's order. *)
      FGrids: TStringList;
      function GetGridIndex(const aGrid: string): integer;
   public
      constructor Create;
      destructor Destroy; override;
      procedure AddStateToGrid(const aGrid: string; const aState: string);
      (* Appends the grid's states to aStates; False (and nothing appended)
         when the grid is unknown or not a grid. *)
      function ReturnStatesForGrid(const aGrid: string; aStates: TStrings): boolean;
      (* gskUnique: aState is the state. Otherwise aState is ''. *)
      function StateKindOfGrid(const aGrid: string; out aState: string): TGridStateKind;
      function GridCount: integer;
   end;

(* The grid as the table keys it: upper-case, four characters, A-R A-R 0-9
   0-9. A 4, 6 or 8 character locator is accepted; anything else (2 characters,
   5, 7, text) is not a grid and answers False. *)
function NormalizeGridForStateLookup(const aGrid: string; out aKey: string): boolean;

(* The one table, built on first use. Main-thread callers only. *)
function GridLookupShared: TGridLookup;

(* The pure answers the logging path uses. *)
function StateOfGrid(const aGrid: string; out aState: string): TGridStateKind;
function PossibleStatesComment(const aGrid: string): string;

implementation

const
   (* 'GGNN=SS' or 'GGNN=SS-SS-SS'. The count is a compile-time check of the
      array bounds; uTestGridLookup pins the loaded total as well. *)
   GRID_STATE_TABLE: array[0..GRID_STATE_TABLE_COUNT - 1] of string = (
      'AL91=HI', 'AL92=HI', 'BK19=HI', 'BK28=HI', 'BK29=HI',
      'AO01=AK', 'AO11=AK', 'AO21=AK', 'AO22=AK', 'AO32=AK',
      'AO52=AK', 'AO53=AK', 'AO63=AK', 'AO69=AK', 'AO74=AK',
      'AO79=AK', 'AO84=AK', 'AO85=AK', 'AO89=AK', 'AO95=AK',
      'AO98=AK', 'AO99=AK', 'AP30=AK', 'AP43=AK', 'AP52=AK',
      'AP53=AK', 'AP60=AK', 'AP64=AK', 'AP65=AK', 'AP66=AK',
      'AP68=AK', 'AP70=AK', 'AP71=AK', 'AP72=AK', 'AP73=AK',
      'AP75=AK', 'AP76=AK', 'AP77=AK', 'AP78=AK', 'AP79=AK',
      'AP80=AK', 'AP81=AK', 'AP82=AK', 'AP83=AK', 'AP84=AK',
      'AP85=AK', 'AP86=AK', 'AP87=AK', 'AP88=AK', 'AP89=AK',
      'AP90=AK', 'AP91=AK', 'AP92=AK', 'AP93=AK', 'AP94=AK',
      'AP95=AK', 'AP96=AK', 'AP97=AK', 'AP98=AK', 'AP99=AK',
      'AQ80=AK', 'AQ90=AK', 'BO05=AK', 'BO06=AK', 'BO07=AK',
      'BO08=AK', 'BO09=AK', 'BO16=AK', 'BO17=AK', 'BO18=AK',
      'BO19=AK', 'BO26=AK', 'BO27=AK', 'BO28=AK', 'BO29=AK',
      'BO36=AK', 'BO37=AK', 'BO38=AK', 'BO39=AK', 'BO48=AK',
      'BO49=AK', 'BO59=AK', 'BO99=AK', 'BP01=AK', 'BP02=AK',
      'BP03=AK', 'BP04=AK', 'BP05=AK', 'BP06=AK', 'BP07=AK',
      'BP08=AK', 'BP09=AK', 'BP10=AK', 'BP11=AK', 'BP12=AK',
      'BP13=AK', 'BP14=AK', 'BP15=AK', 'BP16=AK', 'BP17=AK',
      'BP18=AK', 'BP19=AK', 'BP20=AK', 'BP21=AK', 'BP22=AK',
      'BP23=AK', 'BP24=AK', 'BP25=AK', 'BP26=AK', 'BP27=AK',
      'BP28=AK', 'BP29=AK', 'BP30=AK', 'BP31=AK', 'BP32=AK',
      'BP33=AK', 'BP34=AK', 'BP35=AK', 'BP36=AK', 'BP37=AK',
      'BP38=AK', 'BP39=AK', 'BP40=AK', 'BP41=AK', 'BP42=AK',
      'BP43=AK', 'BP44=AK', 'BP45=AK', 'BP46=AK', 'BP47=AK',
      'BP48=AK', 'BP49=AK', 'BP50=AK', 'BP51=AK', 'BP52=AK',
      'BP53=AK', 'BP54=AK', 'BP55=AK', 'BP56=AK', 'BP57=AK',
      'BP58=AK', 'BP59=AK', 'BP60=AK', 'BP61=AK', 'BP62=AK',
      'BP63=AK', 'BP64=AK', 'BP65=AK', 'BP66=AK', 'BP67=AK',
      'BP68=AK', 'BP69=AK', 'BP70=AK', 'BP71=AK', 'BP72=AK',
      'BP73=AK', 'BP74=AK', 'BP75=AK', 'BP76=AK', 'BP77=AK',
      'BP78=AK', 'BP79=AK', 'BP80=AK', 'BP81=AK', 'BP82=AK',
      'BP83=AK', 'BP84=AK', 'BP85=AK', 'BP86=AK', 'BP87=AK',
      'BP88=AK', 'BP89=AK', 'BP90=AK', 'BP91=AK', 'BP92=AK',
      'BP93=AK', 'BP94=AK', 'BP95=AK', 'BP96=AK', 'BP97=AK',
      'BP98=AK', 'BP99=AK', 'BQ00=AK', 'BQ10=AK', 'BQ11=AK',
      'BQ20=AK', 'BQ21=AK', 'BQ30=AK', 'BQ40=AK', 'BQ50=AK',
      'BQ60=AK', 'BQ70=AK', 'CO09=AK', 'CO17=AK', 'CO18=AK',
      'CO19=AK', 'CO26=AK', 'CO27=AK', 'CO28=AK', 'CO29=AK',
      'CO34=AK', 'CO35=AK', 'CO36=AK', 'CO37=AK', 'CO38=AK',
      'CO44=AK', 'CO45=AK', 'CO46=AK', 'CP00=AK', 'BL01=HI',
      'BL02=HI', 'BL10=HI', 'BL11=HI', 'BL20=HI', 'CM86=CA',
      'CM87=CA', 'CM88=CA', 'CM89=CA', 'CM93=CA', 'CM94=CA',
      'CM95=CA', 'CM96=CA', 'CM97=CA', 'CM98=CA', 'CM99=CA',
      'CN70=CA', 'CN71=CA', 'CN72=OR', 'CN73=OR', 'CN74=OR',
      'CN75=OR', 'CN76=OR-WA', 'CN77=WA', 'CN78=WA', 'CN80=CA',
      'CN81=CA', 'CN82=OR', 'CN83=OR', 'CN84=OR', 'CN85=OR-WA',
      'CN86=WA-OR', 'CN87=WA', 'CN88=WA', 'CN90=CA', 'CN91=CA',
      'CN92=OR', 'CN93=OR', 'CN94=OR', 'CN95=OR-WA', 'CN96=WA',
      'CN97=WA', 'CN98=WA', 'DL79=TX', 'DL89=TX', 'DL98=TX',
      'DL99=TX', 'DM03=CA', 'DM04=CA', 'DM05=CA', 'DM06=CA',
      'DM07=CA-NV', 'DM08=CA-NV', 'DM09=NV', 'DM12=CA', 'DM13=CA',
      'DM14=CA', 'DM15=CA', 'DM16=CA-NV', 'DM17=CA-NV', 'DM18=NV',
      'DM19=NV', 'DM22=CA-AZ', 'DM23=CA-AZ', 'DM24=CA-AZ', 'DM25=CA-AZ-NV',
      'DM26=CA-AZ-NV', 'DM27=NV', 'DM28=NV', 'DM29=NV', 'DM31=AZ',
      'DM32=AZ', 'DM33=AZ', 'DM34=AZ', 'DM35=AZ', 'DM36=AZ',
      'DM37=UT', 'DM38=UT', 'DM39=UT', 'DM41=AZ', 'DM42=AZ',
      'DM43=AZ', 'DM44=AZ', 'DM45=AZ', 'DM46=AZ', 'DM47=UT',
      'DM48=UT', 'DM49=UT', 'DM51=AZ-NM', 'DM52=AZ-NM', 'DM53=AZ-NM',
      'DM54=AZ-NM', 'DM55=AZ-NM', 'DM56=AZ-NM', 'DM57=UT-CO', 'DM58=UT-CO',
      'DM59=UT-CO', 'DM61=NM-TX', 'DM62=NM', 'DM63=NM', 'DM64=NM',
      'DM65=NM', 'DM66=NM', 'DM67=CO', 'DM68=CO', 'DM69=CO',
      'DM70=TX', 'DM71=TX', 'DM72=NM', 'DM73=NM', 'DM74=NM',
      'DM75=NM', 'DM76=NM', 'DM77=CO', 'DM78=CO', 'DM79=CO',
      'DM80=TX', 'DM81=TX', 'DM82=NM-TX', 'DM83=NM-TX', 'DM84=NM-TX',
      'DM85=NM-TX', 'DM86=NM-TX-OK', 'DM87=CO', 'DM88=CO', 'DM89=CO',
      'DM90=TX', 'DM91=TX', 'DM92=TX', 'DM93=TX', 'DM94=TX',
      'DM95=TX', 'DM96=TX-OK', 'DM97=KS', 'DM98=KS', 'DM99=KS',
      'DN00=NV', 'DN01=NV', 'DN02=OR', 'DN03=OR', 'DN04=OR',
      'DN05=OR-WA', 'DN06=WA', 'DN07=WA', 'DN08=WA', 'DN10=NV',
      'DN11=NV', 'DN12=OR-ID', 'DN13=OR-ID', 'DN14=OR-ID', 'DN15=OR-ID',
      'DN16=WA-ID', 'DN17=WA-ID', 'DN18=WA-ID', 'DN20=NV', 'DN21=NV',
      'DN22=ID', 'DN23=ID', 'DN24=ID', 'DN25=ID-MT', 'DN26=ID-MT',
      'DN27=ID-MT', 'DN28=MT', 'DN30=UT', 'DN31=UT', 'DN32=ID',
      'DN33=ID', 'DN34=ID-MT', 'DN35=ID-MT', 'DN36=MT', 'DN37=MT',
      'DN38=MT', 'DN40=UT', 'DN41=UT-WY', 'DN42=ID-WY', 'DN43=ID-WY',
      'DN44=ID-WY-MT', 'DN45=MT', 'DN46=MT', 'DN47=MT', 'DN48=MT',
      'DN50=UT-CO', 'DN51=WY', 'DN52=WY', 'DN53=WY', 'DN54=WY',
      'DN55=MT', 'DN56=MT', 'DN57=MT', 'DN58=MT', 'DN60=CO',
      'DN61=WY', 'DN62=WY', 'DN63=WY', 'DN64=WY', 'DN65=MT',
      'DN66=MT', 'DN67=MT', 'DN68=MT', 'DN70=CO', 'DN71=WY',
      'DN72=WY', 'DN73=WY', 'DN74=WY', 'DN75=MT', 'DN76=MT',
      'DN77=MT', 'DN78=MT', 'DN80=CO', 'DN81=NE', 'DN82=NE',
      'DN83=SD', 'DN84=SD', 'DN85=SD', 'DN86=ND', 'DN87=ND',
      'DN88=ND', 'DN90=NE', 'DN91=NE', 'DN92=NE', 'DN93=SD',
      'DN94=SD', 'DN95=SD', 'DN96=ND', 'DN97=ND', 'DN98=ND',
      'EL06=TX', 'EL07=TX', 'EL08=TX', 'EL09=TX', 'EL15=TX',
      'EL16=TX', 'EL17=TX', 'EL18=TX', 'EL19=TX', 'EL28=TX',
      'EL29=TX', 'EL39=TX-LA', 'EL49=LA', 'EL59=LA', 'EL79=FL',
      'EL84=FL', 'EL86=FL', 'EL87=FL', 'EL88=FL', 'EL89=FL',
      'EL94=FL', 'EL95=FL', 'EL96=FL', 'EL97=FL', 'EL98=FL',
      'EL99=FL', 'EM00=TX', 'EM01=TX', 'EM02=TX', 'EM03=TX-OK',
      'EM04=TX-OK', 'EM05=OK', 'EM06=OK', 'EM07=KS', 'EM08=KS',
      'EM09=KS', 'EM10=TX', 'EM11=TX', 'EM12=TX', 'EM13=TX-OK',
      'EM14=OK-TX', 'EM15=OK', 'EM16=OK', 'EM17=KS', 'EM18=KS',
      'EM19=KS', 'EM20=TX', 'EM21=TX-LA', 'EM22=TX', 'EM23=TX-OK-AR',
      'EM24=OK-AR', 'EM25=OK-AR', 'EM26=OK-AR-MO', 'EM27=KS-MO', 'EM28=KS-MO',
      'EM29=KS-MO', 'EM30=TX-LA', 'EM31=TX-LA', 'EM32=LA', 'EM33=AR',
      'EM34=AR', 'EM35=AR', 'EM36=AR-MO', 'EM37=MO', 'EM38=MO',
      'EM39=MO', 'EM40=LA', 'EM41=LA-MS', 'EM42=LA-MS', 'EM43=AR-MS',
      'EM44=AR-MS', 'EM45=AR-TN', 'EM46=AR-MO', 'EM47=MO', 'EM48=MO-IL',
      'EM49=MO-IL', 'EM50=LA-MS-AL', 'EM51=MS-AL', 'EM52=MS-AL', 'EM53=MS-AL',
      'EM54=MS-AL', 'EM55=AR-TN', 'EM56=MO-TN-KY', 'EM57=MO-KY-IL', 'EM58=IL',
      'EM59=IL', 'EM60=AL-FL', 'EM61=AL', 'EM62=AL', 'EM63=AL',
      'EM64=AL', 'EM65=TN', 'EM66=TN-KY', 'EM67=KY-IN', 'EM68=IL-KY-IN',
      'EM69=IL-IN', 'EM70=FL-GA', 'EM71=AL-GA', 'EM72=AL-GA', 'EM73=AL-GA',
      'EM74=AL-GA', 'EM75=TN-NC', 'EM76=TN-KY', 'EM77=KY', 'EM78=KY-IN',
      'EM79=KY-IN-OH', 'EM80=FL-GA', 'EM81=GA', 'EM82=GA', 'EM83=GA-SC',
      'EM84=GA-SC', 'EM85=TN-SC-NC', 'EM86=TN-NC-KY-VA', 'EM87=KY-VA-WV', 'EM88=KY-WV-OH',
      'EM89=OH-WV', 'EM90=FL-GA', 'EM91=GA', 'EM92=GA-SC', 'EM93=GA-SC',
      'EM94=SC-NC', 'EM95=SC-NC', 'EM96=TN-NC-VA', 'EM97=VA-WV', 'EM98=OH-WV',
      'EM99=OH-WV-PA', 'EN00=NE', 'EN01=NE', 'EN02=NE-SD', 'EN03=SD',
      'EN04=SD', 'EN05=SD', 'EN06=ND', 'EN07=ND', 'EN08=ND',
      'EN10=NE', 'EN11=NE-IA', 'EN12=NE-IA-SD', 'EN13=NE-SD-IA-MN', 'EN14=SD-MN',
      'EN15=SD-MN', 'EN16=ND-MN', 'EN17=ND-MN', 'EN18=ND-MN', 'EN20=NE-MO-IA',
      'EN21=NE-IA', 'EN22=IA', 'EN23=IA-MN', 'EN24=MN', 'EN25=MN',
      'EN26=MN', 'EN27=MN', 'EN28=MN', 'EN30=MO-IA', 'EN31=IA',
      'EN32=IA', 'EN33=IA-MN', 'EN34=MN-WI', 'EN35=MN-WI', 'EN36=MN-WI',
      'EN37=MN', 'EN38=MN', 'EN40=MO-IA-IL', 'EN41=IA-IL', 'EN42=IA-IL-WI',
      'EN43=IA-WI-MN', 'EN44=MN-WI', 'EN45=WI', 'EN46=WI', 'EN47=MN',
      'EN48=MN', 'EN50=IL', 'EN51=IL', 'EN52=IL-WI', 'EN53=WI',
      'EN54=WI', 'EN55=WI-MI', 'EN56=WI-MI', 'EN57=MN-MI', 'EN58=MN-MI',
      'EN60=IL-IN', 'EN61=IL-IN-MI', 'EN62=IL-WI-MI', 'EN63=WI-MI', 'EN64=WI-MI',
      'EN65=WI-MI', 'EN66=MI', 'EN70=IN-OH', 'EN71=IN-MI-OH', 'EN72=MI',
      'EN73=MI', 'EN74=MI', 'EN75=MI', 'EN76=MI', 'EN80=OH',
      'EN81=OH-MI', 'EN82=MI', 'EN83=MI', 'EN84=MI', 'EN85=MI',
      'EN86=MI', 'EN90=OH-WV-PA', 'EN91=OH-PA', 'EN92=PA', 'FM02=SC',
      'FM03=SC-NC', 'FM04=SC-NC', 'FM05=NC', 'FM06=NC-VA', 'FM07=VA',
      'FM08=VA-WV', 'FM09=VA-WV-MD-PA', 'FM14=NC', 'FM15=NC', 'FM16=NC-VA',
      'FM17=VA', 'FM18=VA-DC-MD', 'FM19=VA-MD-PA', 'FM25=NC', 'FM26=NC-VA',
      'FM27=VA', 'FM28=VA-MD-DE', 'FM29=MD-DE-NJ-PA', 'FN00=PA', 'FN01=PA',
      'FN02=NY', 'FN03=NY', 'FN10=PA', 'FN11=PA', 'FN12=NY',
      'FN13=NY', 'FN14=NY', 'FN20=PA-NJ-NY', 'FN21=PA-NJ-NY', 'FN22=NY',
      'FN23=NY', 'FN24=NY', 'FN30=NY-NJ', 'FN31=NJ-NY-CT-MA', 'FN32=NY-CT-MA-VT-NH',
      'FN33=NY-VT-NH', 'FN34=NY-NH-VT', 'FN35=NY-VY', 'FN40=NY', 'FN41=NY-CT-RI-MA',
      'FN42=CT-RI-MA-NH', 'FN43=NH-ME', 'FN44=VT-NH-ME', 'FN45=VT-NH-ME', 'FN46=ME',
      'FN51=RI', 'FN53=ME', 'FN54=ME', 'FN55=ME', 'FN56=ME',
      'FN57=ME', 'FN64=ME', 'FN65=ME', 'FN66=ME', 'FN67=ME'
   );

var
   GSharedGridLookup: TGridLookup;

function NormalizeGridForStateLookup(const aGrid: string; out aKey: string): boolean;
var
   text: string;
begin
   Result := False;
   aKey := '';
   text := UpperCase(Trim(aGrid));
   if not (Length(text) in [4, 6, 8]) then
      begin
      Exit;
      end;
   if (text[1] < 'A') or (text[1] > 'R') or
      (text[2] < 'A') or (text[2] > 'R') or
      (text[3] < '0') or (text[3] > '9') or
      (text[4] < '0') or (text[4] > '9') then
      begin
      Exit;
      end;
   aKey := Copy(text, 1, 4);
   Result := True;
end;

constructor TGridLookup.Create;
var
   i: integer;
   entry: string;
   rest: string;
   dashAt: integer;
   grid: string;
begin
   inherited Create;
   FGrids := TStringList.Create;
   FGrids.CaseSensitive := True;
   FGrids.Sorted := True;
   for i := Low(GRID_STATE_TABLE) to High(GRID_STATE_TABLE) do
      begin
      entry := GRID_STATE_TABLE[i];
      grid := Copy(entry, 1, 4);
      rest := Copy(entry, 6, Length(entry));
      while rest <> '' do
         begin
         dashAt := Pos('-', rest);
         if dashAt = 0 then
            begin
            AddStateToGrid(grid, rest);
            rest := '';
            end
         else
            begin
            AddStateToGrid(grid, Copy(rest, 1, dashAt - 1));
            rest := Copy(rest, dashAt + 1, Length(rest));
            end;
         end;
      end;
end;

destructor TGridLookup.Destroy;
var
   i: integer;
begin
   if FGrids <> nil then
      begin
      for i := 0 to FGrids.Count - 1 do
         begin
         FGrids.Objects[i].Free;
         end;
      FGrids.Free;
      end;
   inherited Destroy;
end;

function TGridLookup.GetGridIndex(const aGrid: string): integer;
var
   key: string;
begin
   if NormalizeGridForStateLookup(aGrid, key) then
      begin
      Result := FGrids.IndexOf(key);
      end
   else
      begin
      Result := -1;
      end;
end;

procedure TGridLookup.AddStateToGrid(const aGrid: string; const aState: string);
var
   i: integer;
   states: TStringList;
   key: string;
begin
   if not NormalizeGridForStateLookup(aGrid, key) then
      begin
      Exit;
      end;
   i := FGrids.IndexOf(key);
   if i < 0 then
      begin
      states := TStringList.Create;
      states.Add(aState);
      FGrids.AddObject(key, states);
      end
   else
      begin
      states := TStringList(FGrids.Objects[i]);
      if states.IndexOf(aState) < 0 then
         begin
         states.Add(aState);
         end;
      end;
end;

function TGridLookup.ReturnStatesForGrid(const aGrid: string; aStates: TStrings): boolean;
var
   i: integer;
begin
   i := GetGridIndex(aGrid);
   Result := i >= 0;
   if Result then
      begin
      aStates.AddStrings(TStringList(FGrids.Objects[i]));
      end;
end;

function TGridLookup.StateKindOfGrid(const aGrid: string; out aState: string): TGridStateKind;
var
   i: integer;
   states: TStringList;
begin
   aState := '';
   i := GetGridIndex(aGrid);
   if i < 0 then
      begin
      Result := gskUnknown;
      Exit;
      end;
   states := TStringList(FGrids.Objects[i]);
   if states.Count = 1 then
      begin
      aState := states[0];
      Result := gskUnique;
      end
   else
      begin
      Result := gskAmbiguous;
      end;
end;

function TGridLookup.GridCount: integer;
begin
   Result := FGrids.Count;
end;

function GridLookupShared: TGridLookup;
begin
   if GSharedGridLookup = nil then
      begin
      GSharedGridLookup := TGridLookup.Create;
      end;
   Result := GSharedGridLookup;
end;

function StateOfGrid(const aGrid: string; out aState: string): TGridStateKind;
begin
   Result := GridLookupShared.StateKindOfGrid(aGrid, aState);
end;

function PossibleStatesComment(const aGrid: string): string;
var
   states: TStringList;
   key: string;
   i: integer;
begin
   Result := '';
   if not NormalizeGridForStateLookup(aGrid, key) then
      begin
      Exit;
      end;
   states := TStringList.Create;
   try
      if (GridLookupShared.ReturnStatesForGrid(key, states)) and
         (states.Count > 1) then
         begin
         Result := 'possible states for ' + key + ' are ';
         for i := 0 to states.Count - 1 do
            begin
            if i = 0 then
               begin
               Result := Result + states[i];
               end
            else if i = states.Count - 1 then
               begin
               Result := Result + ' and ' + states[i];
               end
            else
               begin
               Result := Result + ', ' + states[i];
               end;
            end;
         end;
   finally
      states.Free;
   end;
end;

initialization
   GSharedGridLookup := nil;

finalization
   FreeAndNil(GSharedGridLookup);

end.
