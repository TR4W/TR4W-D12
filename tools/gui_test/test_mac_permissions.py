"""Preserve approved Mac identities while accepting native JSON zero values."""

import unittest

from build_mac_pilot import require_unapproved


class PermissionGuardTests(unittest.TestCase):
   def test_numeric_and_boolean_denials_are_equivalent(self):
      require_unapproved({"accessibility": 0, "screen_recording": 0})
      require_unapproved({"accessibility": False, "screen_recording": False})

   def test_granted_or_unknown_permission_refuses_replacement(self):
      for status in ({"accessibility": 1, "screen_recording": 0},
         {"accessibility": 0, "screen_recording": True}, {},
         {"accessibility": 0, "screen_recording": None}):
         with self.subTest(status=status), self.assertRaises(SystemExit):
            require_unapproved(status)
