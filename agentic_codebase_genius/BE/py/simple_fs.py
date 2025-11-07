# py/simple_fs.py
import os
from pathlib import Path

def list_py_files(root: str):
    """Return sorted list of relative .py files under root."""
    root_path = Path(root).resolve()
    files = []
    for p in root_path.rglob("*.py"):
        try:
            files.append(str(p.relative_to(root_path)))
        except Exception:
            files.append(str(p))
    files.sort()
    return files

def ensure_dir(path: str):
    """Create directory (parents ok)."""
    Path(path).mkdir(parents=True, exist_ok=True)

def write_text(path: str, content: str):
    """Write text atomically(ish)."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    tmp.replace(path)
