unit uGuidSet;
{$I tr4w.inc}

(* A SET OF ROW GUIDS -- protocol 5 (W3+W5, 2026-11-22). A QSO's identity on the
  multi-op wire is its guid (docs/TR4WSERVER_SQLITE_DESIGN.md 13.1, 13.7): the
  old pair (ceQSOID1, ceQSOID2) is the station's local session_id/session_seq and
  no longer travels. This is what the pair set (uServerQsoIndex, deleted) was:
  the guids the server's log holds (the catch-up and the restock ask it), the
  guids a resend posted on this link, the guids a plan has already taken.

  A LEAF: no store, no socket, no widget set. Text compare is EXACT (a guid is
  what the sender's generator made; no case folding). The empty guid names
  nothing -- it is never added and never contained, as the pair (0, 0) never was. *)

interface

uses
   SysUtils,
   Classes;

type
   TGuidSet = class(TObject)
   private
      FKeys: TStringList;
   public
      constructor Create;
      destructor Destroy; override;

      procedure Clear;
      function Count: integer;
      (* False for '' and for a guid not added. *)
      function Contains(const aGuid: string): boolean;
      (* Ignored for '' and for a guid already held. *)
      procedure Add(const aGuid: string);
   end;

implementation

constructor TGuidSet.Create;
begin
   inherited Create;
   FKeys := TStringList.Create;
   FKeys.Sorted := True;
   FKeys.Duplicates := dupIgnore;
   FKeys.CaseSensitive := True;
end;

destructor TGuidSet.Destroy;
begin
   FKeys.Free;
   inherited Destroy;
end;

procedure TGuidSet.Clear;
begin
   FKeys.Clear;
end;

function TGuidSet.Count: integer;
begin
   Result := FKeys.Count;
end;

function TGuidSet.Contains(const aGuid: string): boolean;
var
   at: integer;
begin
   Result := False;
   if aGuid = '' then
      begin
      Exit;
      end;
   (* AnsiString: TStringList's own methods take one (a guid is ASCII). *)
   Result := FKeys.Find(AnsiString(aGuid), at);
end;

procedure TGuidSet.Add(const aGuid: string);
begin
   if aGuid = '' then
      begin
      Exit;
      end;
   FKeys.Add(AnsiString(aGuid));
end;

end.
