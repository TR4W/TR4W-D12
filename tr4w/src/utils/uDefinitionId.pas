unit uDefinitionId;
{$I ..\tr4w.inc}

interface

function NewDefinitionId: string;

implementation

uses SysUtils;

function NewDefinitionId: string;
var
   guid: TGUID;
begin
   if CreateGUID(guid) <> 0 then
      begin
      (* A timestamp fallback can collide and attach the wrong credentials or
         queued work. Refuse creation rather than minting a non-unique ID. *)
      raise EInvalidOp.Create('A unique definition ID could not be generated');
      end;
   Result := Copy(string(GUIDToString(guid)), 2, 36);
end;

end.
