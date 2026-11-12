"""Online-scoring form regression using only a local HTTP test server."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import threading
import time

from pywinauto import Application, mouse
from pywinauto.timings import wait_until

from preferences_audit import select_page
from session import capture, close_normally, launch, wait_for_hint


def check(app, main, prefs, root, run_name, output, journal):
   log = root / "runs" / run_name / "tr4w.log"
   select_page(prefs, log, 22)
   requests = []

   class Handler(BaseHTTPRequestHandler):
      def do_GET(self):
         size = int(self.headers.get("Content-Length", "0"))
         requests.append({"path": self.path, "authorization": self.headers.get("Authorization"),
            "body": self.rfile.read(size).decode("utf-8", errors="replace")})
         status = {"/service": 201, "/posting": 202, "/reading": 203}.get(self.path, 404)
         self.send_response(status)
         self.end_headers()
         self.wfile.write(b"GUI regression response")

      def log_message(self, *args):
         pass

   server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
   worker = threading.Thread(target=server.serve_forever, daemon=True)
   worker.start()

   def controls():
      fields = [control for control in prefs.descendants(class_name="Edit") if control.is_visible()]
      left = prefs.rectangle().left
      fields = [control for control in fields if control.rectangle().left > left + 200]
      fields.sort(key=lambda control: control.rectangle().top)
      tests = sorted([control for control in prefs.descendants(class_name="Button")
         if control.is_visible() and control.window_text() == "Test"], key=lambda control: control.rectangle().top)
      certificates = sorted([control for control in prefs.descendants(class_name="Button")
         if control.is_visible() and control.window_text() == "Verify the server's certificate"], key=lambda control: control.rectangle().top)
      if len(fields) != 5 or len(tests) != 3 or len(certificates) != 2:
         raise AssertionError("Online scoring must expose three URLs/tests, username/password and two certificate controls")
      return [fields[0], fields[3], fields[4]], fields[1:3], tests, certificates

   try:
      urls, credentials, tests, certificates = controls()
      original = [field.window_text() for field in urls]
      if not all(control.get_check_state() == 1 for control in certificates):
         raise AssertionError("Fresh certificate controls must both start checked")
      post = prefs.child_window(title="Post my score while the contest runs", class_name="Button")
      if post.get_check_state():
         raise AssertionError("Fixture must not enable live score posting")
      baseline = prefs.rectangle()
      for url, button in zip(urls, tests):
         first, second = url.rectangle(), button.rectangle()
         if first.right > second.left or abs(first.top - second.top) > 8 or second.right > baseline.right - 10:
            raise AssertionError("URL/Test geometry overlaps or is outside the form")
      certificates[0].click_input()
      if not prefs.child_window(title="Save", class_name="Button").is_enabled():
         raise AssertionError("Certificate change did not arm Save")
      capture(prefs, output / "certificate-warning.png")
      prefs.child_window(title="Cancel").click_input()
      main.type_keys("^j")
      prefs.wait("visible enabled", timeout=10)
      select_page(prefs, log, 22)
      urls, credentials, tests, certificates = controls()
      if [field.window_text() for field in urls] != original or not all(c.get_check_state() == 1 for c in certificates):
         raise AssertionError("Cancel did not restore URL/certificate values")
      for certificate in certificates:
         certificate.click_input()
      credentials[0].set_edit_text("gui-user")
      credentials[1].set_edit_text("gui-password-not-a-secret")
      expected = ["http://127.0.0.1:" + str(server.server_port) + path for path in ("/service", "/posting", "/reading")]
      answers = []
      for index, (field, button, address) in enumerate(zip(urls, tests, expected)):
         field.set_edit_text(address)
         field.type_keys("{TAB}")
         before = prefs.child_window(title="Save", class_name="Button").is_enabled()
         count = len(requests)
         button.click_input()
         wait_until(15, 0.1, lambda: len(requests) > count)
         rectangle = field.rectangle()
         mouse.move(coords=(rectangle.left + 30, rectangle.bottom + 12))
         hints = wait_for_hint(5)
         text = " ".join(window.window_text() for window in hints)
         if "Answered " + str(201 + index) not in text:
            # Also ask UI Automation; some LCL versions expose the result directly.
            uia = Application(backend="uia").connect(process=app.process)
            text += " ".join(control.window_text() for control in uia.window(handle=prefs.handle).descendants())
         if "Answered " + str(201 + index) not in text:
            raise AssertionError("Test result did not show the response for its own URL: " + text)
         if prefs.child_window(title="Save", class_name="Button").is_enabled() != before:
            raise AssertionError("Test changed the Save state")
         answers.append({"url": address, "status": 201 + index, "displayed": text})
         capture(prefs, output / ("url-test-" + str(index) + ".png"))
      if [item["path"] for item in requests] != ["/service", "/posting", "/reading"] or any(item["authorization"] or item["body"] for item in requests):
         raise AssertionError("Tests did not ask exactly their own URL without credentials/body: " + repr(requests))
      if any(certificate.is_enabled() or certificate.get_check_state() for certificate in certificates):
         raise AssertionError("Plain HTTP must disable certificate controls while retaining unchecked state")
      prefs.child_window(title="Save and close").click_input()
      prefs.wait_not("visible", timeout=10)
      close_normally(app, main, journal)
      database = list((root / "runs" / run_name).glob("*.db"))[0]
      app = launch(root, run_name, database.name)
      main = app.window(title_re=r"TR4W v.*CWOPEN.*")
      main.wait("visible enabled", timeout=30)
      main.type_keys("^j")
      prefs = app.window(title="TR4W Preferences")
      prefs.wait("visible enabled", timeout=10)
      select_page(prefs, log, 22)
      urls, credentials, tests, certificates = controls()
      if [field.window_text() for field in urls] != expected or any(c.get_check_state() for c in certificates):
         raise AssertionError("Saved online-scoring values did not survive restart")
      prefs.child_window(title="Cancel").click_input()
      (output / "online-result.json").write_text(json.dumps({"answers": answers, "requests": requests,
         "cancel_verified": True, "restart_verified": True}, indent=3), encoding="utf-8")
      return {"passed": True, "note": "URL rows, certificate state, Cancel, local Test routing/no credentials, and restart asserted"}, app, main
   finally:
      server.shutdown()
      server.server_close()
      worker.join(timeout=5)
