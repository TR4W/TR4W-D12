# The N1MM log listener (issue 45)

TR4W can take a logged QSO from JTDX (TCP) or JTAlert / WSJT-X (UDP) the way N1MM Logger+ does:
the program sends `<command:3>Log<parameters:n>` followed by one ADIF record of exactly `n`
bytes (n1mmwp.hamdocs.com, "Sending log data to N1MM").

## Turning it on

Preferences, WSJT-X / JTDX page, block "N1MM log listener (JTDX, JTAlert)":

| setting | command name | default |
|---|---|---|
| Accept QSOs from JTDX and JTAlert | `ENABLE N1MM LOG LISTENER` | off |
| Address the listener binds to | `N1MM LISTEN ADDRESS` | `127.0.0.1` |

Both apply as soon as Preferences is saved; no restart. Ports are N1MM's and are not settings:
**TCP 52001** (JTDX) and **UDP 2333** (JTAlert, WSJT-X). Point the sending program at the address
and port above.

## Network and firewall

With the default address the listener is reachable only from the same computer, and Windows asks
nothing. To receive from another computer on the LAN, set the address to that computer's LAN
address (or `0.0.0.0` for every interface). Windows then asks whether to allow TR4W through its
firewall, and **anything on that network can add QSOs to the open contest log** -- the listener
has no password. Leave it on loopback unless the sender really is another machine.

If another program (a real N1MM Logger+) already holds UDP 2333 or TCP 52001, TR4W reports a bind
error on the status line and in `tr4w.log`; the other transport still runs.

## What happens to a record

The record goes through the same path as a QSO from WSJT-X (`uInboundQso`): the open contest
interprets it, and its fields are the QSO -- nothing in it is re-read as typed exchange text
(2026-11-25); a record that lacks a field the contest needs is logged and one status line names
the field. The normal dupe sheet flags a repeat (a resend is logged and marked as a dupe, not
refused), and an unknown mode is logged as Digital with a warning in `tr4w.log`. As with WSJT-X,
the call and exchange boxes are cleared when the QSO is logged. Nothing is sent back to the
sender.

A UDP datagram must hold exactly one envelope with one record; anything else is refused and the
reason is in `tr4w.log`.

## Trying it without JTDX

TCP, from PowerShell on the same computer (the byte count is the length of the ADIF text):

    $adif = '<Call:5>K1ABC<Band:3>20M<Freq:6>14.076<Mode:3>FT8<QSO_DATE:8>20261122<TIME_ON:6>184000<RST_Rcvd:3>-03<RST_Sent:3>-07<EOR>'
    $msg  = '<command:3>Log<parameters:' + $adif.Length + '>' + $adif
    $c = New-Object Net.Sockets.TcpClient('127.0.0.1', 52001)
    $b = [Text.Encoding]::ASCII.GetBytes($msg)
    $c.GetStream().Write($b, 0, $b.Length)
    $c.Close()

For UDP use `Net.Sockets.UdpClient` with `Send($b, $b.Length, '127.0.0.1', 2333)`. Use a
copy of a contest log: the QSO is real.
