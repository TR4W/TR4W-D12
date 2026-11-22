unit uQsoColumns;

(* THE qso TABLE'S COLUMNS, AND WHICH OF THEM ARE ON THE MULTI-OP WIRE -- stage W1
  of docs\TR4WSERVER_SQLITE_DESIGN.md section 13 (issues 300 and 341), LIFTED OUT
  OF uLogRepository IN STAGE W2.

  WHY IT IS A UNIT OF ITS OWN. The table is needed by three programs that must
  not disagree: the station's repository (to read a row as wire values), the
  in-tree tr4wserver (to build its own database with these columns) and, as
  columns.json, TR4WServerPy. uLogRepository's implementation reaches the contest
  registry, TF, the ADIF and binary-log units and the zone tables; the server
  cannot link those (design 5.1, verified against the uses clauses 2026-11-22).
  So the table lives here, in a LEAF whose only dependency is uWireQso, and the
  repository uses it.

  Every column of the qso table, in the CREATE TABLE's order (which is the
  wire's tag order and the checksum's field order, and is NOT QSO_COLUMNS'
  order), each with whether it is an INTEGER, its DEFAULT as canonical text, and
  whether it is ON THE WIRE or LOCAL to the station's database.
  uTestWireColumns pins it to the CREATE TABLE and to test\wire\columns.json, so
  a column added to the schema fails the build until it is classified here.

  Both lists are built once, when this unit initializes, and are READ-ONLY after
  that: share them, never free them. *)

{$I tr4w.inc}

interface

uses
   uWireQso;

(* The on-wire columns in tag order (tag i = entry i - 1). *)
function QsoWireColumns: TWireColumns;
(* Every qso column, local ones included, in the CREATE TABLE's order. *)
function QsoTableColumns: TWireColumns;
(* True for a column that is about THIS database and never sent. *)
function QsoColumnIsLocal(const aName: string): boolean;

implementation

uses
   SysUtils;

type
   (* ONE ROW OF THE TABLE BELOW. A record because it is a constant table's
     row and nothing else: it never leaves this unit -- the program sees the
     table through QsoWireColumns / QsoTableColumns, which are classes. *)
   TQsoTableColumn = record
      Name: string;
      Numeric: boolean;   (* declared INTEGER *)
      Default: string;    (* the DEFAULT as canonical text; '' = NULL / none *)
      OnWire: boolean;    (* False: about THIS database, never sent *)
   end;

const
   (* LOCAL (OnWire False): id, session_id, session_seq, sent_to_server,
     server_dirty, sent_udp, udp_dirty -- this database's row number, which
     session wrote it, and what has been handed to the server or the UDP
     broadcast. A receiver's database has its own.

     ON THE WIRE PENDING A RULING (design note 13.5): notes, rcvd_extra and
     qso_set_id. Taking one off is flipping its OnWire here.

     rcvd_extra IS NOT IN uLogRepository's QSO_COLUMNS (no build writes or reads
     it), so the wire reader there SELECTs it after the row id. *)
   QSO_TABLE_COLUMNS: array[0..95] of TQsoTableColumn = (
      (Name: 'id';                Numeric: True;  Default: '';    OnWire: False),
      (Name: 'guid';              Numeric: False; Default: '';    OnWire: True),
      (Name: 'exchange_id';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'qso_set_id';        Numeric: False; Default: '';    OnWire: True),
      (Name: 'session_id';        Numeric: True;  Default: '';    OnWire: False),
      (Name: 'session_seq';       Numeric: True;  Default: '';    OnWire: False),
      (Name: 'computer_id';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'operator_id';       Numeric: True;  Default: '';    OnWire: True),
      (Name: 'record_kind';       Numeric: False; Default: 'QSO'; OnWire: True),
      (Name: 'qso_at';            Numeric: True;  Default: '';    OnWire: True),
      (Name: 'callsign';          Numeric: False; Default: '';    OnWire: True),
      (Name: 'freq_tx_hz';        Numeric: True;  Default: '';    OnWire: True),
      (Name: 'freq_rx_hz';        Numeric: True;  Default: '';    OnWire: True),
      (Name: 'is_split';          Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'band';              Numeric: False; Default: '';    OnWire: True),
      (Name: 'mode';              Numeric: False; Default: '';    OnWire: True),
      (Name: 'submode';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'exchange_sent';     Numeric: False; Default: '';    OnWire: True),
      (Name: 'exchange_received'; Numeric: False; Default: '';    OnWire: True),
      (Name: 'rst_sent';          Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rst_received';      Numeric: True;  Default: '';    OnWire: True),
      (Name: 'serial_sent';       Numeric: True;  Default: '';    OnWire: True),
      (Name: 'serial_received';   Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rcvd_zone';         Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rcvd_name';         Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_age';          Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rcvd_check';        Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rcvd_precedence';   Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_class';        Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_power';        Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_chapter';      Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_prefecture';   Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rcvd_member_no';    Numeric: True;  Default: '';    OnWire: True),
      (Name: 'rcvd_qth';          Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_random';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'random_sent';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_kids';         Numeric: False; Default: '';    OnWire: True),
      (Name: 'qtc_call';          Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_extra';        Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_county';         Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_grid';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_state';          Numeric: False; Default: '';    OnWire: True),
      (Name: 'dxcc_prefix';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'standard_call';     Numeric: False; Default: '';    OnWire: True),
      (Name: 'dxcc_entity';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'dxcc_code';         Numeric: True;  Default: '';    OnWire: True),
      (Name: 'cty_cq_zone';       Numeric: True;  Default: '';    OnWire: True),
      (Name: 'cty_continent';     Numeric: False; Default: '';    OnWire: True),
      (Name: 'mult_domestic';     Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'mult_dx';           Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'mult_prefix';       Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'mult_zone';         Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'inhibit_mults';     Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'prefix_mult';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'dx_mult';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'domestic_mult';     Numeric: False; Default: '';    OnWire: True),
      (Name: 'domestic_qth';      Numeric: False; Default: '';    OnWire: True),
      (Name: 'qso_points';        Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'is_dupe';           Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'is_run';            Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'is_xqso';           Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'is_skipped';        Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'sent_in_qtc';       Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'name_sent';         Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'mp3_recorded';      Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'clear_dupe_sheet';  Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'clear_mult_sheet';  Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'radio_nr';          Numeric: True;  Default: '1';   OnWire: True),
      (Name: 'operator_call';     Numeric: False; Default: '';    OnWire: True),
      (Name: 'deleted';           Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'notes';             Numeric: False; Default: '';    OnWire: True),
      (Name: 'sent_to_server';    Numeric: True;  Default: '0';   OnWire: False),
      (Name: 'server_dirty';      Numeric: True;  Default: '0';   OnWire: False),
      (Name: 'sent_udp';          Numeric: True;  Default: '0';   OnWire: False),
      (Name: 'udp_dirty';         Numeric: True;  Default: '0';   OnWire: False),
      (Name: 'my_call';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_section';        Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_park';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_iota';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_country';        Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_continent';      Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_cq_zone';        Numeric: True;  Default: '';    OnWire: True),
      (Name: 'my_itu_zone';       Numeric: True;  Default: '';    OnWire: True),
      (Name: 'my_source';         Numeric: False; Default: '';    OnWire: True),
      (Name: 'rcvd_year';         Numeric: True;  Default: '';    OnWire: True),
      (Name: 'year_sent';         Numeric: True;  Default: '';    OnWire: True),
      (Name: 'my_name';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_fd_class';       Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_check';          Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_prec';           Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_postal_code';    Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_foc_number';     Numeric: False; Default: '';    OnWire: True),
      (Name: 'is_off_contest';    Numeric: True;  Default: '0';   OnWire: True),
      (Name: 'my_rover_qth';      Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_sent_unit';      Numeric: False; Default: '';    OnWire: True),
      (Name: 'my_rover_places';   Numeric: False; Default: '';    OnWire: True));

var
   GQsoWireColumns: TWireColumns = nil;
   GQsoTableColumns: TWireColumns = nil;

procedure BuildColumnTables;
var
   i: integer;
begin
   GQsoWireColumns := TWireColumns.Create;
   GQsoTableColumns := TWireColumns.Create;
   for i := Low(QSO_TABLE_COLUMNS) to High(QSO_TABLE_COLUMNS) do
      begin
      GQsoTableColumns.Add(QSO_TABLE_COLUMNS[i].Name, QSO_TABLE_COLUMNS[i].Numeric,
                           QSO_TABLE_COLUMNS[i].Default);
      if QSO_TABLE_COLUMNS[i].OnWire then
         begin
         GQsoWireColumns.Add(QSO_TABLE_COLUMNS[i].Name, QSO_TABLE_COLUMNS[i].Numeric,
                             QSO_TABLE_COLUMNS[i].Default);
         end;
      end;
end;

function QsoWireColumns: TWireColumns;
begin
   Result := GQsoWireColumns;
end;

function QsoTableColumns: TWireColumns;
begin
   Result := GQsoTableColumns;
end;

function QsoColumnIsLocal(const aName: string): boolean;
var
   i: integer;
begin
   Result := False;
   for i := Low(QSO_TABLE_COLUMNS) to High(QSO_TABLE_COLUMNS) do
      begin
      if QSO_TABLE_COLUMNS[i].Name = aName then
         begin
         Result := not QSO_TABLE_COLUMNS[i].OnWire;
         Exit;
         end;
      end;
end;

initialization
   BuildColumnTables;

finalization
   FreeAndNil(GQsoWireColumns);
   FreeAndNil(GQsoTableColumns);

end.
