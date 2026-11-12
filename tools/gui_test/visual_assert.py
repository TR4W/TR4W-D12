"""Compare fixed-DPI UI regions against explicitly reviewed repository baselines."""

from PIL import Image, ImageChops


def compare_images(observed_path, expected_path, difference_path):
   if not expected_path.is_file():
      raise RuntimeError("Missing reviewed visual baseline: " + str(expected_path))
   with Image.open(observed_path) as observed, Image.open(expected_path) as expected:
      if observed.size != expected.size:
         raise AssertionError("Visual region geometry changed: " + str(observed_path))
      difference = ImageChops.difference(observed.convert("RGB"), expected.convert("RGB"))
      if difference.point(lambda value: 255 if value > 8 else 0).getbbox():
         difference.save(difference_path)
         raise AssertionError("Visual baseline differs: " + str(observed_path))
