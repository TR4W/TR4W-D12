# netprobe

An independent client for the TR4W multi-op wire protocol -- **network protocol 2**
(the first message is a HELLO), not the D7 V1 wire -- to be pointed at any server
(`tr4wserver`, TR4WServerPy, or a future one). Python 3, standard library only.

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
| `--case` | `connect spot qso burst edit disc dup serial time hello resend catchup`, or `all` (default) |
| `--host`, `--port` | the main port; the log-sync port is `PORT + 1` |
| `--password` | default `TR4WSERVER` (sent as ten NUL-padded bytes) |
| `--label` | name printed on every result line |
| `--timeout` | seconds to wait for any one message (default 3) |
| `--expect-time` | `relay` or `none` to make `time` a pass/fail check; `any` (default) only reports |
| `--sync-bytes` | bytes written as the password on the sync port (default 10, what the TR4W client writes) |
| `--burst` | QSOs in the `burst`, `resend` and `catchup` cases (default 30) |
| `--contest` | the contest id the probes announce in their HELLO (default `ARRL-DX-CW`) |

Output is one line per check, `RESULT <label> <case> <check>: PASS|FAIL|INFO|SKIP`.
Exit code 0 means no check failed, 1 means one did, 2 means a case could not run
(refused, wrong password, no banner). Every wait has a deadline.

## The cases

| case | what it sends | what it proves |
|---|---|---|
| `connect` | password, reads the `TR4W` banner, sends a HELLO claiming computer id 1 | the handshake, the 19-byte log-compare packet on admit, the link stays up |
| `spot` | one 106-byte DX spot from A | B receives it byte for byte and A is not disconnected (a server that frames the spot at 98 bytes drops A) |
| `qso` | one 384-byte QSO | B receives it, A is not echoed, the server log grows by exactly one 376-byte record that equals what was sent |
| `burst` | 30 QSOs in a single `send` | every one reaches B and the log (a server without a per-connection tail buffer loses some) |
| `edit` | a QSO, then an edit with the same `(ceQSOID1, ceQSOID2)` | B gets the edit, A gets the 8300 ACK, the server record is rewritten in place |
| `disc` | A and B connect, B closes | A receives 8260 whose parameter is B's ordinal 1..26 (the client range-checks it) |
| `dup` | two connections claim id 1 | the second is refused with 8320; a station re-announcing its own id is not; the id of a station that has left can be taken again |
| `serial` | A and B connect, A reserves a serial | needs `SERIAL NUMBER LOCKOUT=1` on the server; otherwise SKIP |
| `time` | one time-sync packet from A | whether it is relayed; set `--expect-time` to match the server's `ALLOW TIME SYNCHRONIZING` |
| `hello` | a HELLO; a second station joining; a contest change; then stations that break the handshake | the server answers with its own HELLO (protocol 2, id 0); a later joiner is told every station's LATEST contest, byte for byte; a change is relayed; COMPUTERID or a QSO sent first closes the connection and is relayed to nobody; protocol 1 and 3 get 8330 carrying 2 and are closed; a HELLO claiming a held id, or id 0 or 27, gets 8320 and is never announced |
| `resend` | the catch-up of a station that was disconnected: a QSO, then the same QSO again as QSOINFO and as OFFLINEQSO; an OFFLINEQSO the server has never seen; two QSOs with ids (0, 0); an edit of a held QSO; then a whole burst sent twice | a QSO is stored once and relayed once however often it arrives (the pair `ceQSOID1`/`ceQSOID2` is the key); an OFFLINEQSO of a held QSO is still acknowledged (8300); a QSO with ids (0, 0) identifies nothing and is stored and relayed every time; an edit is always applied and relayed; the sender stays connected. Run it with `--burst 200` for the size of a long outage |
| `catchup` | A logs `--burst` QSOs while nobody else is connected; C then connects late and downloads the server's log on the sync port exactly as the client's catch-up does (ten password bytes, a four-byte size, then that many bytes) | the size LOGCOMPARE announced on admit is the size of the file sent; the file is a header and a whole number of 376-byte records; every QSO is in it, byte for byte, in arrival order, once; a joiner is NOT sent the earlier QSOs on admit (which is why it must fetch) but IS told the contest the others announced; a second download is the same file; the server's copy of an edited QSO is the edited record in place (so an edit made while a station was away is not something an insert-only catch-up can pick up) |

The log checks read the server's log through the sync port, the only way to see
it from outside. If that download fails the log checks are reported as SKIP.

## Cautions

- It writes real QSOs into the server's log. Point it at a throwaway server,
  never a station's live one, and give the server its own working directory.
- The records are built for a legacy contest handle (`ceContest` = 1) and carry
  the sender's ordinal in `qiSenderID`. The server stores whatever byte arrives.
- The size table is the Windows i386 one (`TNetDXSpot` = 106). The Pascal side
  pins every size in `tr4w/test/unit/uTestNetWireSizes.pas`; if that test and this
  table ever disagree, the test is the authority for what the tree sends.
