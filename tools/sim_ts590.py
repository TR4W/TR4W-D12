"""Deprecated shim -- use:  python -m radiosim TS590 COM37"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from radiosim.__main__ import main
sys.argv = [sys.argv[0], "TS590"] + sys.argv[1:]
sys.exit(main())
