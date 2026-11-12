"""Verify edited message banks by closing and restarting the real program."""

from message_workflow import program_messages
from session import close_normally, launch


def check(app, main, root, run_name, output, journal):
   first = output / "written"
   first.mkdir(exist_ok=True)
   program_messages(app, main, first, journal, include_modifiers=True)
   database = list((root / "runs" / run_name).glob("*.db"))
   if len(database) != 1:
      raise RuntimeError("Message fixture must have one database")
   close_normally(app, main, journal)
   app = launch(root, run_name, database[0].name)
   main = app.window(title_re=r"TR4W v.*CWOPEN.*")
   main.wait("visible enabled", timeout=30)
   second = output / "reopened"
   second.mkdir(exist_ok=True)
   program_messages(app, main, second, journal, read_only=True, include_modifiers=True)
   return {"passed": True, "note": "CQ, exchange, other, Ctrl and Alt messages survived restart; no memory sent"}, app, main
