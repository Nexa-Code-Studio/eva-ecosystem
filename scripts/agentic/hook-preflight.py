#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import hook_preflight

if __name__ == "__main__":
    hook_preflight.main()
