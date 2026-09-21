unit uSerialDiagnosis;
{$I tr4w.inc}

(* WHY A SERIAL PORT WOULD NOT OPEN, IN WORDS AN OPERATOR CAN ACT ON.

  Until now every failed open said the same thing -- "Cannot open
  /dev/ttyUSB0" -- whether the adapter was unplugged, the port name was wrong,
  the radio was switched off, or the account simply is not in the group that
  owns the device node. The last of those is the one an operator can fix in
  ten seconds and cannot possibly guess, and on Linux it is the FIRST thing
  that happens to a new installation.

  THREE RULES SHAPE THIS UNIT, and each of them is a thing that has gone
  wrong elsewhere in this tree:

  1. IT NEVER TESTS FOR A GROUP CALLED 'dialout'. The owning group is
     'dialout' on Debian, Ubuntu and Mint, 'uucp' on Arch, and on macOS a
     /dev/cu.* node is typically root:wheel and world-writable so the whole
     concept does not apply. A hardcoded name is a check that is confidently
     wrong on a system it will actually run on. The node is asked instead,
     and the answer is reported.

  2. IT NEVER PRE-FLIGHTS THE OPEN. Nothing here decides whether a port is
     usable -- an ACL, a udev rule, a container mount or a systemd seat grant
     can all disagree with what the mode bits say, and a pre-check would
     become a second source of truth about a port's usability. The open is
     attempted, always; this runs only once it has already failed, and only
     to word the message.

  3. IT REPORTS THE STATE IT FOUND AND NOTHING MORE. If the node cannot be
     examined, the message says the node could not be examined -- it does not
     guess at a group. If the mode bits say this user should have been
     allowed, the message says so and names the things that could still be
     refusing, rather than blaming the group falsely.

  THE DECISION IS SEPARATE FROM THE GATHERING, on purpose.
  DescribeSerialOpenFailure takes the facts and compiles on every platform, so
  the unit tests pin the wording and the branching with no device present.
  GatherSerialNodeFacts is the thin POSIX half that stats the node.

  NO NEW BINDING. Everything the gatherer uses is in FreePascal's own
  BaseUnix -- FpStat, FpGetgroups, FpGeteuid, FpGetegid -- all verified
  against FPC 3.2.2 on linux-ci-build before this was written.

  AND NOT FPC'S `users`/`grp` PACKAGE, WHICH WOULD HAVE BEEN THE OBVIOUS
  CHOICE. getgrgid is wrapped there, but that package is NOT INSTALLED on
  mac-ci (measured 2026-09-21: aarch64-darwin has rtl-extra and 60 others,
  and no `users`), so using it would have traded a Linux convenience for a
  macOS build failure. The gid and uid are resolved by reading /etc/group and
  /etc/passwd, which have the same colon-delimited shape on both platforms.
  That resolves a NAME FOR A MESSAGE and nothing else -- membership is decided
  by FpGetgroups, which is authoritative and needs no file at all -- so a gid
  that lives only in a directory service degrades to its number rather than to
  a wrong answer. *)

interface

uses
   SysUtils;

type
   (* WHAT WAS ESTABLISHED ABOUT THE DEVICE NODE. Facts, never conclusions --
     the conclusions are DescribeSerialOpenFailure's job, and keeping them
     apart is what makes the wording testable without a device. *)
   TSerialNodeFacts = class
   public
      (* False when the node could not be inspected at all. Exists carries no
        meaning in that case, and ExamineError says why. *)
      Examined: Boolean;
      ExamineError: string;
      (* True when a node is there. False means there is no such path. *)
      Exists: Boolean;
      OwnerUid: LongInt;
      OwnerGid: LongInt;
      (* The low permission bits of st_mode, nothing else. *)
      PermissionBits: LongWord;
      (* Empty when the id did not resolve to a name. The message then uses
        the number, which usermod accepts just as well. *)
      GroupName: string;
      OwnerUserName: string;
      (* The account the PROGRAM is running as -- which is not the account
        that owns the node, and mixing the two is how a message ends up
        telling an operator to add root to a group. *)
      UserName: string;
      IsOwner: Boolean;
      InOwningGroup: Boolean;
      constructor Create;
   end;

const
   (* POSIX permission bits, spelled out here rather than taken from BaseUnix
     so that the routine that DECIDES compiles on Windows and can be pinned by
     the unit tests. These values are fixed by POSIX; they are not a platform
     detail that could drift. *)
   SERIAL_MODE_R_USR = 256;      (* 0400 *)
   SERIAL_MODE_W_USR = 128;      (* 0200 *)
   SERIAL_MODE_R_GRP = 32;       (* 0040 *)
   SERIAL_MODE_W_GRP = 16;       (* 0020 *)
   SERIAL_MODE_R_OTH = 4;        (* 0004 *)
   SERIAL_MODE_W_OTH = 2;        (* 0002 *)

(* THE DECISION. Platform-free by construction: it is handed the facts and
  produces the sentence an operator reads.

  AOpenError is the platform's own text for the failure (strerror), already
  looked up by the caller. APermissionDenied is the caller's answer to "was
  this EACCES or EPERM" -- a Boolean rather than an errno so that the errno
  constants stay on the POSIX side of the unit. *)
function DescribeSerialOpenFailure(const APortName: string;
                                   APermissionDenied: Boolean;
                                   const AOpenError: string;
                                   AFacts: TSerialNodeFacts): string;

(* THE WHOLE THING, for the one caller that matters.

  CALL THIS IMMEDIATELY AFTER A FAILED OPEN AND BEFORE ANYTHING ELSE: on a
  POSIX system its first act is to read errno, and any intervening system call
  would overwrite it.

  Answers '' when it has nothing to add -- which is every Windows build, where
  a serial failure keeps the message it has always had. *)
function DiagnoseSerialOpenFailure(const APortName: string): string;

(* Gathering, exposed for the tests and for anything that wants the facts
  without the prose. Answers a fully-populated object on POSIX, and one that
  reports "not examined" everywhere else. The CALLER OWNS IT. *)
function GatherSerialNodeFacts(const APortName: string): TSerialNodeFacts;

implementation

{$IFDEF UNIX}
uses
   BaseUnix, UnixType, Errors;
{$ENDIF}

{ TSerialNodeFacts }

constructor TSerialNodeFacts.Create;
begin
   inherited Create;
   Examined := False;
   ExamineError := '';
   Exists := False;
   OwnerUid := -1;
   OwnerGid := -1;
   PermissionBits := 0;
   GroupName := '';
   OwnerUserName := '';
   UserName := '';
   IsOwner := False;
   InOwningGroup := False;
end;

(* '0660', for a message. Only the nine permission bits; the device type and
  the setuid bits are not what anybody is being asked to fix. *)
function PermissionBitsToOctal(ABits: LongWord): string;
var
   digit: Integer;
   i: Integer;
begin
   Result := '';
   for i := 2 downto 0 do
      begin
      digit := (ABits shr (i * 3)) and 7;
      Result := Result + IntToStr(digit);
      end;
   Result := '0' + Result;
end;

(* How the node is owned, in one phrase: 'user root, group dialout'. Falls
  back to the numbers, which is a true statement rather than a guess. *)
function OwnershipPhrase(AFacts: TSerialNodeFacts): string;
var
   who: string;
   grp: string;
begin
   if AFacts.OwnerUserName <> '' then
      begin
      who := AFacts.OwnerUserName;
      end
   else if AFacts.IsOwner and (AFacts.UserName <> '') then
      begin
      (* WE ARE THE OWNER, so our own name is the owner's name -- and it is
        often the only one available. macOS keeps ordinary accounts in
        OpenDirectory and not in /etc/passwd, so a uid of 501 does not
        resolve there and the message would otherwise read 'uid 501' about
        the very person reading it. *)
      who := AFacts.UserName;
      end
   else
      begin
      who := 'uid ' + IntToStr(AFacts.OwnerUid);
      end;

   if AFacts.GroupName <> '' then
      begin
      grp := AFacts.GroupName;
      end
   else
      begin
      grp := 'gid ' + IntToStr(AFacts.OwnerGid);
      end;

   Result := Format('user %s, group %s', [who, grp]);
end;

function DescribeSerialOpenFailure(const APortName: string;
                                   APermissionDenied: Boolean;
                                   const AOpenError: string;
                                   AFacts: TSerialNodeFacts): string;
var
   ownerAllows: Boolean;
   groupAllows: Boolean;
   otherAllows: Boolean;
   groupIsTheWayIn: Boolean;
   groupPhrase: string;
   groupArg: string;
   userPhrase: string;
   userArg: string;
begin
   if AFacts = nil then
      begin
      Result := Format('Cannot open %s', [APortName]);
      Exit;
      end;

   (* NO SUCH NODE. Said first, because it is also the answer when the open
     failed with something that looks like a permission problem: if the path
     is not there, the group cannot be the story. *)
   if AFacts.Examined and (not AFacts.Exists) then
      begin
      Result := Format('Cannot open %s: there is no such device. Check the port name, ' +
                       'and that the adapter is still plugged in.',
                       [APortName]);
      Exit;
      end;

   (* NOT A PERMISSION PROBLEM. Pass the platform's own text through and say
     what was, and was not, established about the node. *)
   if not APermissionDenied then
      begin
      Result := Format('Cannot open %s: %s.', [APortName, AOpenError]);
      if AFacts.Examined then
         begin
         Result := Result + Format(' The device node is there (%s, mode %s) and permission ' +
                                   'is not what refused it.',
                                   [OwnershipPhrase(AFacts),
                                    PermissionBitsToOctal(AFacts.PermissionBits)]);
         end
      else if AFacts.ExamineError <> '' then
         begin
         Result := Result + Format(' The device node could not be examined either (%s), ' +
                                   'so nothing more is known about it.',
                                   [AFacts.ExamineError]);
         end;
      Exit;
      end;

   (* PERMISSION DENIED, BUT THE NODE COULD NOT BE EXAMINED. Say exactly that.
     Naming a group here would be inventing one. *)
   if not AFacts.Examined then
      begin
      Result := Format('Cannot open %s: permission was denied, and the device node could ' +
                       'not be examined (%s) -- so the group that owns it is not known.',
                       [APortName, AFacts.ExamineError]);
      Exit;
      end;

   if AFacts.GroupName <> '' then
      begin
      groupPhrase := 'group ' + AFacts.GroupName;
      groupArg := AFacts.GroupName;
      end
   else
      begin
      groupPhrase := Format('group id %d', [AFacts.OwnerGid]);
      groupArg := IntToStr(AFacts.OwnerGid);
      end;

   (* The name of the account we are RUNNING AS, which is not necessarily the
     name that owns the node. '$USER' is a correct thing to paste into a shell
     when the name did not resolve, so the command stays usable either way. *)
   if AFacts.UserName <> '' then
      begin
      userPhrase := Format('this user (%s)', [AFacts.UserName]);
      userArg := AFacts.UserName;
      end
   else
      begin
      userPhrase := 'this user';
      userArg := '$USER';
      end;

   ownerAllows := AFacts.IsOwner and
                  ((AFacts.PermissionBits and SERIAL_MODE_R_USR) <> 0) and
                  ((AFacts.PermissionBits and SERIAL_MODE_W_USR) <> 0);
   groupAllows := AFacts.InOwningGroup and
                  ((AFacts.PermissionBits and SERIAL_MODE_R_GRP) <> 0) and
                  ((AFacts.PermissionBits and SERIAL_MODE_W_GRP) <> 0);
   otherAllows := ((AFacts.PermissionBits and SERIAL_MODE_R_OTH) <> 0) and
                  ((AFacts.PermissionBits and SERIAL_MODE_W_OTH) <> 0);

   (* THE MODE SAYS WE SHOULD HAVE BEEN LET IN. Do not blame the group -- name
     the things that outrank the mode bits, and let the operator look. *)
   if ownerAllows or groupAllows or otherAllows then
      begin
      Result := Format('Cannot open %s: the device exists but permission was denied, and ' +
                       'its permissions do not explain why -- it is %s, mode %s, which ' +
                       'allows %s. Something above the mode bits is refusing: a filesystem ' +
                       'ACL, a udev rule if this is Linux, or a sandbox or container that ' +
                       'mounted the node differently.',
                       [APortName, OwnershipPhrase(AFacts),
                        PermissionBitsToOctal(AFacts.PermissionBits), userPhrase]);
      if AFacts.InOwningGroup then
         begin
         Result := Result + Format(' It belongs to %s and this user is already a member, ' +
                                   'so joining a group is not the fix.', [groupPhrase]);
         end;
      Exit;
      end;

   (* THE ORDINARY LINUX CASE, AND THE ONE THIS UNIT EXISTS FOR. *)
   groupIsTheWayIn := ((AFacts.PermissionBits and SERIAL_MODE_R_GRP) <> 0) and
                      ((AFacts.PermissionBits and SERIAL_MODE_W_GRP) <> 0) and
                      (not AFacts.InOwningGroup);
   if groupIsTheWayIn then
      begin
      Result := Format('Cannot open %s: the device exists but permission was denied. It ' +
                       'belongs to %s, and %s is not a member. Add yourself with ' +
                       '"sudo usermod -aG %s %s", then log out and back in -- a running ' +
                       'session does not pick up a new group.',
                       [APortName, groupPhrase, userPhrase, groupArg, userArg]);
      Exit;
      end;

   (* Denied, and no group opens it either. *)
   Result := Format('Cannot open %s: the device exists but permission was denied, and no ' +
                    'group grants access to it -- it is %s, mode %s. Its ownership or its ' +
                    'permissions have to change before %s can open it; on Linux that is ' +
                    'usually a udev rule.',
                    [APortName, OwnershipPhrase(AFacts),
                     PermissionBitsToOctal(AFacts.PermissionBits), userPhrase]);
end;

{$IFDEF UNIX}

(* One colon-delimited field of one /etc/passwd or /etc/group line. The two
  files agree on the two fields this unit wants: the name is field 0 and the
  numeric id is field 2 in both. *)
function ColonField(const ALine: string; AIndex: Integer): string;
var
   i: Integer;
   start: Integer;
   field: Integer;
begin
   Result := '';
   field := 0;
   start := 1;
   for i := 1 to Length(ALine) + 1 do
      begin
      if (i > Length(ALine)) or (ALine[i] = ':') then
         begin
         if field = AIndex then
            begin
            Result := Copy(ALine, start, i - start);
            Exit;
            end;
         Inc(field);
         start := i + 1;
         end;
      end;
end;

(* A name for a number, for a message. Answers '' when the file does not have
  it, and the caller then reports the number -- see the header for why this is
  not getgrgid. *)
function NameForId(const AFileName: string; AId: LongInt): string;
var
   f: TextFile;
   line: string;
   wanted: string;
begin
   Result := '';
   if AId < 0 then
      begin
      Exit;
      end;
   if not FileExists(AFileName) then
      begin
      Exit;
      end;

   wanted := IntToStr(AId);
   AssignFile(f, AFileName);
   {$I-}
   Reset(f);
   {$I+}
   if IOResult <> 0 then
      begin
      Exit;
      end;
   try
      while not Eof(f) do
         begin
         ReadLn(f, line);
         if (line <> '') and (line[1] <> '#') then
            begin
            if ColonField(line, 2) = wanted then
               begin
               Result := ColonField(line, 0);
               Exit;
               end;
            end;
         end;
   finally
      CloseFile(f);
   end;
end;

type
   (* FpGetgroups takes FPC's C-array workaround type, which is declared
     array[0..0]. Handing it a real array means a pointer cast, and this is
     the only one in the unit: it is the shape the RTL's own declaration
     forces, not a habit. *)
   PGrpArr = ^TGrpArr;

const
   (* NGROUPS_MAX is 65536 on modern Linux but the practical count is a
     handful; 128 covers every real account and keeps this off the heap. A
     truncated list can only make the membership test answer "not a member",
     which is the safe direction: the operator is told to join a group they
     are already in, rather than being told the group is not the problem. *)
   MAX_SUPPLEMENTARY_GROUPS = 128;

function ProcessIsInGroup(AGid: LongInt): Boolean;
var
   groups: array[0..MAX_SUPPLEMENTARY_GROUPS - 1] of TGid;
   count: Integer;
   i: Integer;
begin
   Result := (AGid >= 0) and (LongInt(FpGetegid) = AGid);
   if Result then
      begin
      Exit;
      end;

   count := FpGetgroups(Length(groups), PGrpArr(@groups[0])^);
   if count <= 0 then
      begin
      Exit;
      end;
   if count > Length(groups) then
      begin
      count := Length(groups);
      end;

   for i := 0 to count - 1 do
      begin
      if LongInt(groups[i]) = AGid then
         begin
         Result := True;
         Exit;
         end;
      end;
end;

function GatherSerialNodeFacts(const APortName: string): TSerialNodeFacts;
var
   info: stat;
   err: Integer;
begin
   Result := TSerialNodeFacts.Create;

   if FpStat(AnsiString(APortName), info) = 0 then
      begin
      Result.Examined := True;
      Result.Exists := True;
      Result.OwnerUid := LongInt(info.st_uid);
      Result.OwnerGid := LongInt(info.st_gid);
      Result.PermissionBits := LongWord(info.st_mode) and 511;   (* 0777 *)
      Result.GroupName := NameForId('/etc/group', Result.OwnerGid);
      Result.OwnerUserName := NameForId('/etc/passwd', Result.OwnerUid);
      Result.IsOwner := LongInt(FpGeteuid) = Result.OwnerUid;
      Result.InOwningGroup := ProcessIsInGroup(Result.OwnerGid);
      end
   else
      begin
      err := fpgeterrno;
      if err = ESysENOENT then
         begin
         (* A definite answer, not a failure to look: there is no node. *)
         Result.Examined := True;
         Result.Exists := False;
         end
      else
         begin
         Result.Examined := False;
         Result.ExamineError := string(StrError(err));
         end;
      end;

   (* The account we are RUNNING AS, which is what the usermod line needs. *)
   Result.UserName := NameForId('/etc/passwd', LongInt(FpGeteuid));
   if (Result.UserName = '') then
      begin
      Result.UserName := GetEnvironmentVariable('USER');
      end;
   if (Result.UserName = '') then
      begin
      Result.UserName := GetEnvironmentVariable('LOGNAME');
      end;
end;

function DiagnoseSerialOpenFailure(const APortName: string): string;
var
   err: Integer;
   facts: TSerialNodeFacts;
begin
   (* FIRST, BEFORE ANY OTHER CALL. Everything below stats files. *)
   err := fpgeterrno;

   facts := GatherSerialNodeFacts(APortName);
   try
      Result := DescribeSerialOpenFailure(
         APortName,
         (err = ESysEACCES) or (err = ESysEPERM),
         string(StrError(err)),
         facts);
   finally
      facts.Free;
   end;
end;

{$ELSE}

(* WINDOWS HAS ITS OWN PERMISSION STORY AND IS DELIBERATELY UNCHANGED. There
  is no owning group on a COM port, the failure an operator actually meets is
  "already in use", and the message it has always produced is the one the
  bench notes and the help file describe. *)

function GatherSerialNodeFacts(const APortName: string): TSerialNodeFacts;
begin
   Result := TSerialNodeFacts.Create;
   Result.Examined := False;
   Result.ExamineError := 'device nodes are a POSIX concept';
end;

function DiagnoseSerialOpenFailure(const APortName: string): string;
begin
   Result := '';
end;

{$ENDIF}

end.
