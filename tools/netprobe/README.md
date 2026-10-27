# netprobe

An independent client for the TR4W multi-op V1 wire protocol, to be pointed at
any server (`tr4wserver`, TR4WServerPy, or a future one). Python 3, standard
library only.

The in-tree client and `tr4wserver` agree with each other because both compile
`VC.pas`; a record that changes size there changes the wire for everyone else
and nothing in the build notices. This tool carries its own size table and its
own record builders, so it can disagree with a server and say so.

## Use

```
python tools/netprobe/netprobe.py --host 127.0.0.1 --port 1061 --label mine
python tools/netprobe/netprobe.py --port 1061 --case spot
```

| option | meaning |
|---|---|
| `--case` | `connect spot qso burst edit disc dup serial time`, or `all` (default) |
| `--host`, `--port` | the main port; the log-sync port is `PORT + 1` |
| `--password` | default `TR4WSERVER` (sent as ten NUL-padded bytes) |
| `--label` | name printed on every result line |
| `--timeout` | seconds to wait for any one message (default 3) |
| `--expect-time` | `relay` or `none` to make `time` a pass/fail check; `any` (default) only reports |
| `--sync-bytes` | bytes written as the password on the sync port (default 10, what the TR4W client writes) |
| `--burst` | QSOs in the `burst` case (default 30) |

Output is one line per check, `RESULT <label> <case> <check>: PASS|FAIL|INFO|SKIP`.
Exit code 0 means no check failed, 1 means one did, 2 means a case could not run
(refused, wrong password, no banner). Every wait has a deadline.

## The cases

| case | what it sends | what it proves |
|---|---|---|
| `connect` | password, reads the `TR4W` banner, claims computer id 1 | the handshake, the 19-byte log-compare packet on admit, the link stays up |
| `spot` | one 106-byte DX spot from A | B receives it byte for byte and A is not disconnected (a server that frames the spot at 98 bytes drops A) |
| `qso` | one 384-byte QSO | B receives it, A is not echoed, the server log grows by exactly one 376-byte record that equals what was sent |
| `burst` | 30 QSOs in a single `send` | every one reaches B and the log (a server without a per-connection tail buffer loses some) |
| `edit` | a QSO, then an edit with the same `(ceQSOID1, ceQSOID2)` | B gets the edit, A gets the 8300 ACK, the server record is rewritten in place |
| `disc` | A and B connect, B closes | A receives 8260 whose parameter is B's ordinal 1..26 (the client range-checks it) |
| `dup` | two connections claim id 1 | the second is refused with 8320 |
| `serial` | A and B connect, A reserves a serial | needs `SERIAL NUMBER LOCKOUT=1` on the server; otherwise SKIP |
| `time` | one time-sync packet from A | whether it is relayed; set `--expect-time` to match the server's `ALLOW TIME SYNCHRONIZING` |

The log checks read the server's log through the sync port, the only way to see
it from outside. If that download fails the log checks are reported as SKIP.

## Cautions

- It writes real QSOs into the server's log. Point it at a throwaway server,
  never a station's live one, and give the server its own working directory.
- The records are built for a legacy contest handle (`ceContest` = 1). The server
  stores whatever byte arrives.
- The size table is the Windows i386 one (`TNetDXSpot` = 106). The Pascal side
  pins every size in `tr4w/test/unit/uTestNetWireSizes.pas`; if that test and this
  table ever disagree, the test is the authority for what the tree sends.
