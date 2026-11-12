"""Small ASCII ADIF fixtures independent of TR4W's exporter implementation."""

from datetime import datetime, timezone


def record(fields):
   parts = []
   for name, value in fields.items():
      value = str(value)
      value.encode("ascii")
      parts.append("<" + name + ":" + str(len(value)) + ">" + value)
   return " ".join(parts) + " <EOR>\n"


def write_contacts(path, bad=False, mixed=False, own_grid=None, first_sent=4):
   text = "<ADIF_VER:5>3.1.6\n<EOH>\n"
   for index, call in enumerate(("K1GUI", "K2GUI")):
      mode = "SSB" if mixed and index == 0 else "CW"
      fields = {"CALL": call, "BAND": ("80m", "15m")[index] if mixed else ("20m", "40m")[index],
         "MODE": mode, "QSO_DATE": datetime.now(timezone.utc).strftime("%Y%m%d"),
         "TIME_ON": "12000" + str(index), "RST_SENT": "59" if mode == "SSB" else "599",
         "RST_RCVD": "59" if mode == "SSB" else "599", "STX": str(first_sent + index),
         "SRX": str(10 + index), "NAME": ("AMY", "BOB")[index],
         "STX_STRING": str(first_sent + index) + " TOM", "SRX_STRING": str(10 + index) + " " + ("AMY", "BOB")[index]}
      if own_grid:
         fields["MY_GRIDSQUARE"] = own_grid
      text += record(fields)
   if bad:
      text += "<EOR>\n"
   path.write_text(text, encoding="ascii")
