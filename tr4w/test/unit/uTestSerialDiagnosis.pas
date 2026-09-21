unit uTestSerialDiagnosis;
{$I ..\..\src\tr4w.inc}
(*
  WHAT A FAILED SERIAL OPEN TELLS THE OPERATOR.

  These pin the DECISION, not the filesystem.  DescribeSerialOpenFailure is
  handed a set of facts -- a stat result and a membership answer -- and the
  tests assert which of the five diagnoses comes out.  No device is opened and
  none needs to exist, which is why they run identically on Windows, Linux and
  macOS.

  THE CASE THAT MATTERS MOST IS THE ONE THAT MUST NOT FIRE TOO OFTEN.  Telling
  an operator to join a group is only useful when the group is genuinely the
  way in; saying it when the user is ALREADY a member, or when no group has
  access at all, sends them to a dead end and costs a bench session.  So the
  group advice is asserted present in exactly one arrangement and absent in
  every other.
*)

interface

uses
   SysUtils, uTR4WTestFramework, uSerialDiagnosis;

type
   TSerialDiagnosisTests = class(TTestCase)
   protected
      procedure Test_AMissingNodeSaysSoAndNamesNoGroup;
      procedure Test_TheGroupAdviceNamesTheRealGroupAndTheLogout;
      procedure Test_AMemberIsNotToldToJoinTheGroupAgain;
      procedure Test_AWorldWritableNodeIsNotAGroupProblem;
      procedure Test_ANodeOnlyItsOwnerCanOpenOffersNoGroup;
      procedure Test_AnUnexaminableNodeClaimsNothing;
      procedure Test_ANonPermissionFailurePassesTheErrnoText;
      procedure Test_AnUnresolvedGidStillGivesAUsableCommand;
      procedure Test_AnUnresolvedOwnerUidFallsBackToOurOwnName;
   public
      procedure RunAllTests; override;
   end;

implementation

(* A node as Debian, Ubuntu and Mint ship it: crw-rw---- root:dialout. *)
function DialoutNode(AInGroup: Boolean): TSerialNodeFacts;
begin
   Result := TSerialNodeFacts.Create;
   Result.Examined := True;
   Result.Exists := True;
   Result.OwnerUid := 0;
   Result.OwnerGid := 20;
   Result.OwnerUserName := 'root';
   Result.GroupName := 'dialout';
   Result.UserName := 'ny4i';
   Result.PermissionBits := SERIAL_MODE_R_USR or SERIAL_MODE_W_USR or
                            SERIAL_MODE_R_GRP or SERIAL_MODE_W_GRP;
   Result.IsOwner := False;
   Result.InOwningGroup := AInGroup;
end;

procedure TSerialDiagnosisTests.Test_AMissingNodeSaysSoAndNamesNoGroup;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   BeginTest('a device node that is not there says exactly that');
   facts := TSerialNodeFacts.Create;
   try
      facts.Examined := True;
      facts.Exists := False;
      (* EACCES AND NO NODE IS A REAL COMBINATION -- a search-permission
        failure on a directory in the path gives it -- and the node's absence
        is the more useful half.  It must win. *)
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', True, 'Permission denied', facts);
      CheckTrue(Pos('no such device', msg) > 0, 'says there is no such device: ' + msg);
      CheckTrue(Pos('usermod', msg) = 0, 'and does not send anybody to usermod: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_TheGroupAdviceNamesTheRealGroupAndTheLogout;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   BeginTest('a non-member gets the group, the command and the logout');
   facts := DialoutNode(False);
   try
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', True, 'Permission denied', facts);
      CheckTrue(Pos('/dev/ttyUSB0', msg) > 0, 'names the port: ' + msg);
      CheckTrue(Pos('permission was denied', msg) > 0, 'says permission: ' + msg);
      CheckTrue(Pos('group dialout', msg) > 0, 'names the group it FOUND: ' + msg);
      CheckTrue(Pos('is not a member', msg) > 0, 'says the user is not in it: ' + msg);
      CheckTrue(Pos('sudo usermod -aG dialout ny4i', msg) > 0,
                'gives the command with the real group and user: ' + msg);
      (* THE CLAUSE PEOPLE MISS.  A running session does not pick up a new
        group, so an operator who runs usermod and retries immediately sees
        the identical failure and concludes the advice was wrong. *)
      CheckTrue(Pos('log out and back in', msg) > 0, 'says to log out: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_AMemberIsNotToldToJoinTheGroupAgain;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   BeginTest('a user already in the group is not sent to usermod');
   facts := DialoutNode(True);
   try
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', True, 'Permission denied', facts);
      CheckTrue(Pos('usermod', msg) = 0, 'no usermod: ' + msg);
      CheckTrue(Pos('already a member', msg) > 0, 'says they are already in it: ' + msg);
      CheckTrue(Pos('udev', msg) > 0, 'names what could still be refusing: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_AWorldWritableNodeIsNotAGroupProblem;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   (* THE macOS SHAPE.  /dev/cu.usbserial-* is typically root:wheel and
     crw-rw-rw-, so the owning group grants nothing to anybody in particular
     and naming it would be noise.  A hardcoded test for 'dialout' would have
     produced advice that is nonsense on this machine. *)
   BeginTest('a world-writable node does not blame its group');
   facts := TSerialNodeFacts.Create;
   try
      facts.Examined := True;
      facts.Exists := True;
      facts.OwnerUid := 0;
      facts.OwnerGid := 0;
      facts.OwnerUserName := 'root';
      facts.GroupName := 'wheel';
      facts.UserName := 'ny4i';
      facts.PermissionBits := SERIAL_MODE_R_USR or SERIAL_MODE_W_USR or
                              SERIAL_MODE_R_GRP or SERIAL_MODE_W_GRP or
                              SERIAL_MODE_R_OTH or SERIAL_MODE_W_OTH;
      msg := DescribeSerialOpenFailure('/dev/cu.usbserial-A50285BI', True,
                                       'Permission denied', facts);
      CheckTrue(Pos('usermod', msg) = 0, 'no usermod: ' + msg);
      CheckTrue(Pos('do not explain', msg) > 0, 'says the mode does not explain it: ' + msg);
      CheckTrue(Pos('0666', msg) > 0, 'reports the mode it found: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_ANodeOnlyItsOwnerCanOpenOffersNoGroup;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   BeginTest('a 0600 node offers no group, because no group would help');
   facts := TSerialNodeFacts.Create;
   try
      facts.Examined := True;
      facts.Exists := True;
      facts.OwnerUid := 0;
      facts.OwnerGid := 0;
      facts.OwnerUserName := 'root';
      facts.GroupName := 'root';
      facts.UserName := 'ny4i';
      facts.PermissionBits := SERIAL_MODE_R_USR or SERIAL_MODE_W_USR;
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', True, 'Permission denied', facts);
      CheckTrue(Pos('usermod', msg) = 0, 'no usermod, it would not help: ' + msg);
      CheckTrue(Pos('no group grants access', msg) > 0, 'says so plainly: ' + msg);
      CheckTrue(Pos('0600', msg) > 0, 'reports the mode it found: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_AnUnexaminableNodeClaimsNothing;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   (* DO NOT CLAIM A CAUSE THAT WAS NOT ESTABLISHED.  If the stat itself
     failed, the owning group is unknown -- and an invented group name is
     worse than no advice, because it is actionable and wrong. *)
   BeginTest('a node that could not be examined names no group');
   facts := TSerialNodeFacts.Create;
   try
      facts.Examined := False;
      facts.ExamineError := 'Permission denied';
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', True, 'Permission denied', facts);
      CheckTrue(Pos('could not be examined', msg) > 0, 'says it could not look: ' + msg);
      CheckTrue(Pos('not known', msg) > 0, 'and that the group is unknown: ' + msg);
      CheckTrue(Pos('usermod', msg) = 0, 'and advises nothing: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_ANonPermissionFailurePassesTheErrnoText;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   BeginTest('a failure that is not about permission passes the errno through');
   facts := DialoutNode(True);
   try
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', False,
                                       'Device or resource busy', facts);
      CheckTrue(Pos('Device or resource busy', msg) > 0,
                'the platform text survives: ' + msg);
      CheckTrue(Pos('permission is not what refused it', msg) > 0,
                'and permission is ruled out, having been checked: ' + msg);
      CheckTrue(Pos('usermod', msg) = 0, 'no group advice: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_AnUnresolvedGidStillGivesAUsableCommand;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   (* A gid that lives only in a directory service does not resolve to a name
     here, and usermod takes a numeric group just as happily.  Degrade to the
     number rather than to silence. *)
   BeginTest('an unresolved gid degrades to its number, not to nothing');
   facts := DialoutNode(False);
   try
      facts.GroupName := '';
      facts.UserName := '';
      msg := DescribeSerialOpenFailure('/dev/ttyUSB0', True, 'Permission denied', facts);
      CheckTrue(Pos('group id 20', msg) > 0, 'names the gid it found: ' + msg);
      CheckTrue(Pos('sudo usermod -aG 20 $USER', msg) > 0,
                'and the command is still pasteable: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.Test_AnUnresolvedOwnerUidFallsBackToOurOwnName;
var
   facts: TSerialNodeFacts;
   msg: string;
begin
   (* THE macOS SHAPE AGAIN, AND A MEASURED ONE: ordinary accounts live in
     OpenDirectory and not in /etc/passwd, so uid 501 does not resolve to a
     name there.  When the node is owned by the account we are running as,
     that name is known anyway -- and printing 'uid 501' about the very
     person reading the message helps nobody. *)
   BeginTest('an owner uid that does not resolve falls back to our own name');
   facts := TSerialNodeFacts.Create;
   try
      facts.Examined := True;
      facts.Exists := True;
      facts.OwnerUid := 501;
      facts.OwnerGid := 0;
      facts.OwnerUserName := '';
      facts.GroupName := 'wheel';
      facts.UserName := 'ny4i';
      facts.IsOwner := True;
      facts.PermissionBits := 0;
      msg := DescribeSerialOpenFailure('/dev/cu.usbserial-A50285BI', True,
                                       'Permission denied', facts);
      CheckTrue(Pos('user ny4i', msg) > 0, 'names us as the owner: ' + msg);
      CheckTrue(Pos('uid 501', msg) = 0, 'and not as a number: ' + msg);
   finally
      facts.Free;
   end;
end;

procedure TSerialDiagnosisTests.RunAllTests;
begin
   Test_AMissingNodeSaysSoAndNamesNoGroup;
   Test_TheGroupAdviceNamesTheRealGroupAndTheLogout;
   Test_AMemberIsNotToldToJoinTheGroupAgain;
   Test_AWorldWritableNodeIsNotAGroupProblem;
   Test_ANodeOnlyItsOwnerCanOpenOffersNoGroup;
   Test_AnUnexaminableNodeClaimsNothing;
   Test_ANonPermissionFailurePassesTheErrnoText;
   Test_AnUnresolvedGidStillGivesAUsableCommand;
   Test_AnUnresolvedOwnerUidFallsBackToOurOwnName;
end;

end.
