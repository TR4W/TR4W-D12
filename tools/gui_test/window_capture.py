"""Capture the foreground window's visible frame, excluding invisible resize margins."""

import ctypes
from ctypes import wintypes

from PIL import ImageGrab
import win32gui


def capture_window(handle, region=None):
   if not win32gui.IsWindowVisible(handle) or win32gui.IsIconic(handle):
      raise RuntimeError("Capture requires a visible, restored window")
   if win32gui.GetForegroundWindow() != handle:
      raise RuntimeError("Requested window is not foreground; refusing a background capture")
   visible = wintypes.RECT()
   dwm = ctypes.WinDLL("dwmapi")
   bounds = dwm.DwmGetWindowAttribute
   bounds.argtypes = [wintypes.HWND, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD]
   bounds.restype = ctypes.c_long
   if bounds(handle, 9, ctypes.byref(visible), ctypes.sizeof(visible)) != 0:
      raise RuntimeError("Cannot obtain visible DWM window frame")
   if visible.right <= visible.left or visible.bottom <= visible.top:
      raise RuntimeError("Window has an empty visible frame")
   # Preserve the compositor's actual title/menu styling, unlike PrintWindow.
   frame = (visible.left, visible.top, visible.right, visible.bottom)
   if region is not None:
      left, top, right, bottom = region
      if not (frame[0] <= left < right <= frame[2] and frame[1] <= top < bottom <= frame[3]):
         raise RuntimeError("Requested control region is clipped or outside the foreground frame")
   image = ImageGrab.grab(bbox=frame if region is None else region,
      all_screens=True)
   if win32gui.GetForegroundWindow() != handle:
      raise RuntimeError("Foreground changed during capture; refusing an obscured image")
   return image
