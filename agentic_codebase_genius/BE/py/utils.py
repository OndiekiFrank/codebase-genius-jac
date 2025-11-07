import os, re, tempfile, shutil
from pathlib import Path
from typing import Dict, Tuple
from git import Repo

IGNORE_DIRS = {'.git', 'node_modules', '.idea', '.venv', '__pycache__', 'dist', 'build'}

def safe_repo_name(url: str) -> str:
    name = url.rstrip('/').split('/')[-1]
    if name.endswith('.git'):
        name = name[:-4]
    return re.sub(r'[^a-zA-Z0-9_.-]', '-', name)

def clone_repo(repo_url: str) -> Tuple[str, str]:
    tmpdir = tempfile.mkdtemp(prefix="cgen_")
    local = os.path.join(tmpdir, safe_repo_name(repo_url))
    Repo.clone_from(repo_url, local)
    return tmpdir, local

def file_tree(root: str) -> Dict:
    root_p = Path(root)
    def walk(p: Path):
        children = []
        for c in sorted(p.iterdir(), key=lambda x: (x.is_file(), x.name)):
            if c.name in IGNORE_DIRS: continue
            if c.is_dir():
                children.append({"type":"dir","name":c.name,"children":walk(c)})
            else:
                children.append({"type":"file","name":c.name,"path":str(c.relative_to(root_p))})
        return children
    return {"root": Path(root).name, "children": walk(root_p)}

def readme_summary(root: str) -> str:
    for cand in ["README.md", "readme.md", "Readme.md"]:
        p = Path(root, cand)
        if p.exists():
            text = p.read_text(errors="ignore")
            first_lines = "\n".join(text.strip().splitlines()[:40])
            return first_lines if first_lines else "(README present but empty)"
    return "(No README found)"
