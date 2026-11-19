unit uRoverForm;

(* THE ROVER DIALOG -- issues 133 and 87 (NY4I, 2026-11-19).

  A bare ROVER in the call window, or Tools -> Commands -> ROVER, opens it. It
  shows the contest's places (uRoverSession.ContestRoverPlaces) as a check
  list and a box to type them in; typed units are split on a space, a comma, a
  dash or a slash (uRoverState.SplitRoverUnitsText). The two follow each
  other: ticking a place adds it to the box, typing one ticks it. OK checks
  the units against the contest's places and its county-line limit
  (RoverUnitsRefusal) and says why it refuses; "Rover off" turns roving off.
  Validation is the leaf's, so it is pinned without this form.

  WHAT A CHANGE DOES: RoverState is set (or cleared), the ROVER panel on the
  main window shows where the station is now (or hides), and the notice line
  says so. *)

{$I ..\..\tr4w.inc}

interface

uses
   Classes, SysUtils, Forms, Controls, StdCtrls, CheckLst,
   uNewContestHostArea,   (* THostAreaPlaces *)
   uRoverState;           (* TRoverState *)

type
   TfrmRover = class(TForm)
      lblUnits: TLabel;
      edtUnits: TEdit;
      clbUnits: TCheckListBox;
      lblRefusal: TLabel;
      btnOK: TButton;
      btnOff: TButton;
      btnCancel: TButton;
      procedure UnitsChange(Sender: TObject);
      procedure UnitsClickCheck(Sender: TObject);
      procedure OKClick(Sender: TObject);
      procedure OffClick(Sender: TObject);
   private
      FPlaces: TStrings;      (* the places' keys, index for index with clbUnits *)
      FMaxUnits: integer;
      FChosen: TStringList;
      FTurnedOff: boolean;
      FSyncing: boolean;
      FPlacesObject: THostAreaPlaces;
      procedure TickFromText;
   public
      constructor Create(aOwner: TComponent); override;
      destructor Destroy; override;

      (* Fill the list from aPlaces (kept, not copied: the caller owns it and
        outlives the form), the limit, and the units roving now. *)
      procedure Prepare(const aPlaces: THostAreaPlaces; aMaxUnits: integer;
                        const aCurrent: TRoverState);

      (* After OK: the units chosen, or TurnedOff when "Rover off" was
        pressed. *)
      property Chosen: TStringList read FChosen;
      property TurnedOff: boolean read FTurnedOff;
   end;

(* Open the dialog for the active contest, and apply what was chosen. A
  contest with no rover places says so on the notice line instead. *)
procedure ShowRoverDialog;

(* The ROVER panel: 'ROVER KOH/KON' while roving, hidden otherwise. *)
procedure ShowRoverStatus;

implementation

{$R *.lfm}

uses
   VC,                (* mweRover *)
   LogWind,           (* QuickDisplay *)
   PostUnit,          (* Contest -- the active contest's handle *)
   uContestFactory,   (* ActiveContest *)
   uMainForm,         (* SetElementText, ShowElement *)
   uRoverSession,     (* ContestRoverPlaces *)
   uAppStrings,       (* SRover* *)
   utils_text,        (* LclText -- a string into an LCL caption, stated *)
   MainUnit;          (* logger *)

constructor TfrmRover.Create(aOwner: TComponent);
begin
   inherited Create(aOwner);
   FChosen := TStringList.Create;
   Caption := SRoverDialogTitle;
   lblUnits.Caption := SRoverDialogPrompt;
   btnOK.Caption := SRoverDialogOK;
   btnOff.Caption := SRoverDialogOff;
   btnCancel.Caption := SRoverDialogCancel;
   lblRefusal.Caption := '';
end;

destructor TfrmRover.Destroy;
begin
   FreeAndNil(FChosen);
   inherited Destroy;
end;

procedure TfrmRover.Prepare(const aPlaces: THostAreaPlaces; aMaxUnits: integer;
                            const aCurrent: TRoverState);
begin
   FPlacesObject := aPlaces;
   FPlaces := aPlaces.Keys;
   FMaxUnits := aMaxUnits;
   FSyncing := True;
   try
      clbUnits.Items.Assign(aPlaces.Displays);
      edtUnits.Text := LclText(aCurrent.Joined(' '));
   finally
      FSyncing := False;
      end;
   TickFromText;
end;

(* Tick exactly the places the box names. *)
procedure TfrmRover.TickFromText;
var
   units: TStringList;
   i: integer;
begin
   if FPlaces = nil then
      begin
      Exit;
      end;
   units := TStringList.Create;
   FSyncing := True;
   try
      SplitRoverUnitsText(edtUnits.Text, units);
      for i := 0 to clbUnits.Items.Count - 1 do
         begin
         clbUnits.Checked[i] := units.IndexOf(FPlaces[i]) >= 0;
         end;
   finally
      FSyncing := False;
      units.Free;
      end;
end;

procedure TfrmRover.UnitsChange(Sender: TObject);
begin
   if FSyncing then
      begin
      Exit;
      end;
   lblRefusal.Caption := '';
   TickFromText;
end;

(* The box follows the ticks: a ticked place not typed is added at the end, an
  unticked one is taken out, and what was typed keeps its order. *)
procedure TfrmRover.UnitsClickCheck(Sender: TObject);
var
   units: TStringList;
   i, at: integer;
begin
   if FSyncing or (FPlaces = nil) then
      begin
      Exit;
      end;
   units := TStringList.Create;
   try
      SplitRoverUnitsText(edtUnits.Text, units);
      for i := 0 to clbUnits.Items.Count - 1 do
         begin
         at := units.IndexOf(FPlaces[i]);
         if clbUnits.Checked[i] and (at < 0) then
            begin
            units.Add(FPlaces[i]);
            end
         else if (not clbUnits.Checked[i]) and (at >= 0) then
            begin
            units.Delete(at);
            end;
         end;
      FSyncing := True;
      try
         units.Delimiter := ' ';
         edtUnits.Text := units.DelimitedText;
      finally
         FSyncing := False;
         end;
      lblRefusal.Caption := '';
   finally
      units.Free;
      end;
end;

procedure TfrmRover.OKClick(Sender: TObject);
var
   refusal: string;
begin
   SplitRoverUnitsText(edtUnits.Text, FChosen);
   refusal := RoverUnitsRefusal(FChosen, FPlacesObject, FMaxUnits);
   if refusal <> '' then
      begin
      lblRefusal.Caption := LclText(refusal);
      ModalResult := mrNone;
      Exit;
      end;
   FTurnedOff := False;
   ModalResult := mrOK;
end;

procedure TfrmRover.OffClick(Sender: TObject);
begin
   FChosen.Clear;
   FTurnedOff := True;
   ModalResult := mrOK;
end;

procedure ShowRoverStatus;
begin
   if RoverState.Active then
      begin
      SetElementText(mweRover, Format(SRoverStatus, [RoverState.Joined('/')]));
      end
   else
      begin
      SetElementText(mweRover, '');
      end;
   ShowElement(mweRover, RoverState.Active);
end;

procedure ShowRoverDialog;
var
   places: THostAreaPlaces;
   maxUnits: integer;
   form: TfrmRover;
begin
   places := THostAreaPlaces.Create;
   try
      if not ContestRoverPlaces(ActiveContest(Contest), places, maxUnits) then
         begin
         QuickDisplay(SRoverNoPlaces);
         Exit;
         end;

      form := TfrmRover.Create(nil);
      try
         form.Prepare(places, maxUnits, RoverState);
         if form.ShowModal <> mrOK then
            begin
            Exit;
            end;

         if form.TurnedOff then
            begin
            RoverState.TurnOff;
            logger.Info('[Rover] roving off');
            QuickDisplay(SRoverTurnedOff);
            end
         else
            begin
            RoverState.SetUnits(form.Chosen);
            logger.Info('[Rover] roving from %s', [RoverState.Joined('/')]);
            QuickDisplay(Format(SRoverStatus, [RoverState.Joined('/')]));
            end;
         ShowRoverStatus;
      finally
         form.Free;
         end;
   finally
      places.Free;
      end;
end;

end.
