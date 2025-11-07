# gen_bridge.py
import os
import json
from pathlib import Path

def run_gen(root: str = "."):
    """
    Run gen_docs.py inside `root`, then report the outputs/docs.md path + size.
    Returns a plain dict so Jac can `report` it cleanly.
    """
    root = root or "."
    root_path = Path(root).resolve()
    cwd = Path.cwd()
    try:
        os.chdir(root_path)
        import gen_docs  # your existing script
        # call its main() directly (it writes outputs/docs.md under CWD)
        gen_docs.main()
        out_md = root_path / "outputs" / "docs.md"
        return {
            "ok": True,
            "root": str(root_path),
            "docs_path": str(out_md),
            "exists": out_md.exists(),
            "size_bytes": out_md.stat().st_size if out_md.exists() else 0,
        }
    except Exception as e:
        return {"ok": False, "error": str(e), "root": str(root_path)}
    finally:
        os.chdir(cwd)
