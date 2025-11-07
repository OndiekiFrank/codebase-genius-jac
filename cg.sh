#!/usr/bin/env bash
# Codebase Genius – one-command bootstrap & launcher
# Usage examples:
#   bash cg.sh up                              # bootstrap (if needed) + start BE & FE
#   bash cg.sh gen https://github.com/...      # ensure running then generate docs for a repo
#   bash cg.sh kill                            # stop background backend
#   bash cg.sh clean                           # remove venvs and outputs (keeps your git history)

set -euo pipefail

PROJECT_ROOT="agentic_codebase_genius"
BE_DIR="$PROJECT_ROOT/BE"
FE_DIR="$PROJECT_ROOT/FE"
OUT_DIR="$PROJECT_ROOT/outputs"
PY_DIR="$BE_DIR/py"
BACKEND_HOST="${BACKEND_HOST:-127.0.0.1}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
BACKEND_URL="http://$BACKEND_HOST:$BACKEND_PORT"
BE_VENV="$BE_DIR/.venv"
FE_VENV="$FE_DIR/.venv"
PIDFILE=".cg_backend.pid"

log()   { printf "\033[1;36m[CG]\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[CG]\033[0m %s\n" "$*"; }
error() { printf "\033[1;31m[CG]\033[0m %s\n" "$*" 1>&2; }
exists() { command -v "$1" >/dev/null 2>&1; }

ensure_sys_deps() {
  log "Checking system dependencies..."
  if ! exists git; then error "git not found. Install git and rerun."; exit 1; fi
  if ! exists python3; then error "python3 not found. Install Python 3.10+ and rerun."; exit 1; fi
  if ! exists pip3; then error "pip3 not found. Install pip and rerun."; exit 1; fi
  if ! exists dot; then
    warn "graphviz (dot) not found. Attempting to install..."
    if exists apt-get; then
      sudo apt-get update -y && sudo apt-get install -y graphviz
    elif exists brew; then
      brew install graphviz
    else
      warn "Could not auto-install graphviz. Please install it manually (needed for diagrams)."
    fi
  fi
}

write_files() {
  log "Scaffolding project structure at $(pwd)/$PROJECT_ROOT ..."
  mkdir -p "$BE_DIR" "$FE_DIR" "$OUT_DIR" "$PY_DIR"

  # Top-level README
  cat > "$PROJECT_ROOT/README.md" << 'EOF'
# Codebase Genius (Jac)
An agentic multi-actor system that generates high‑quality Markdown docs for any public GitHub repository (Python/Jac first).

## Quickstart
```bash
# Backend
cd agentic_codebase_genius/BE
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
jac serve main.jac

# Frontend (new terminal)
cd ../FE
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
streamlit run app.py
```
Outputs: `agentic_codebase_genius/outputs/<repo_name>/docs.md`
EOF

  # .gitignore (top-level)
  cat > ".gitignore" << 'EOF'
*.pyc
__pycache__/
.env
.venv/
*.so
agentic_codebase_genius/outputs/
EOF

  # Backend requirements
  cat > "$BE_DIR/requirements.txt" << 'EOF'
jaclang>=0.12.0
fastapi>=0.110
uvicorn>=0.30
pydantic>=2.6
python-dotenv>=1.0
GitPython>=3.1
tree_sitter>=0.21.3
graphviz>=0.20.3
networkx>=3.2
requests>=2.32
EOF

  # FE requirements
  cat > "$FE_DIR/requirements.txt" << 'EOF'
streamlit>=1.37
requests>=2.32
EOF

  # .env example
  cat > "$BE_DIR/.env.example" << 'EOF'
OPENAI_API_KEY=
GOOGLE_API_KEY=
DOCGENIUS_MODEL=openai:gpt-4o-mini
BACKEND_HOST=127.0.0.1
BACKEND_PORT=8000
EOF

  # Python helpers
  cat > "$PY_DIR/utils.py" << 'EOF'
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
EOF

  # Parser & graph
  cat > "$PY_DIR/parser.py" << 'EOF'
from pathlib import Path
from typing import Dict, List, Tuple
from tree_sitter import Parser, Language
import tempfile, os, re
import networkx as nx
from graphviz import Digraph

LANG_SO = Path(__file__).with_name("build_langs.so")

def _ensure_langs():
    if LANG_SO.exists(): return
    with tempfile.TemporaryDirectory() as tmp:
        libs = []
        os.system(f"git clone --depth 1 https://github.com/tree-sitter/tree-sitter-python {tmp}/py")
        libs.append(f"{tmp}/py")
        Language.build_library(str(LANG_SO), libs)

def build_ccg(src_root: str) -> Tuple[nx.DiGraph, Dict]:
    _ensure_langs()
    PY_LANG = Language(str(LANG_SO), "python")
    parser = Parser()
    parser.set_language(PY_LANG)

    g = nx.DiGraph()
    meta = {"files_analyzed": 0, "functions": 0, "classes": 0}

    for p in Path(src_root).rglob("*.py"):
        code = p.read_bytes()
        tree = parser.parse(code)
        meta["files_analyzed"] += 1
        text = code.decode("utf-8", errors="ignore")

        funcs = re.findall(r'^\s*def\s+([a-zA-Z_]\w*)\s*\(', text, re.M)
        clss  = re.findall(r'^\s*class\s+([a-zA-Z_]\w*)\s*(\(|:)', text, re.M)
        for f in funcs:
            g.add_node(f"func::{f}", kind="func", file=str(p))
            meta["functions"] += 1
        for c,_ in clss:
            g.add_node(f"class::{c}", kind="class", file=str(p))
            meta["classes"] += 1

        for caller in funcs:
            for callee in funcs:
                if caller != callee and re.search(rf'\\b{callee}\\s*\\(', text):
                    g.add_edge(f"func::{caller}", f"func::{callee}", type="calls", file=str(p))
    return g, meta

def graph_to_dot(g) -> Digraph:
    dot = Digraph(comment="Code Context Graph", graph_attr={"rankdir":"LR"})
    for n, data in g.nodes(data=True):
        label = f"{data.get('kind','?')}\\n{n.split('::',1)[-1]}"
        shape = "ellipse" if data.get("kind")=="func" else "box"
        dot.node(n, label=label, shape=shape)
    for u,v,data in g.edges(data=True):
        dot.edge(u, v, label=data.get("type",""))
    return dot
EOF

  # main.jac (server + agents)
  cat > "$BE_DIR/main.jac" << 'EOF'
import py ./py/utils.py as pyutils
import py ./py/parser.py as parser
import std.http as http
import std.fs as fs
import std.env as env

can http.server with host=env.getenv("BACKEND_HOST","127.0.0.1"), port=int(env.getenv("BACKEND_PORT","8000"))

node Repo {
    has repo_url: str;
    has local_dir: str;
    has work_tmp: str;
    has map_json: dict;
    has readme: str;
    has out_dir: str;
    has ccg_meta: dict;
    has ccg_dot_path: str;
    has docs_md_path: str;
}

walker supervisor {
    can spawn map_repo, analyze_code, generate_docs;
    has repo_url: str;
    has base_out: str = "../outputs";

    def entry() {
        if not repo_url or not repo_url.startswith("http"):
            fail "invalid repo_url";
        let tmp_and_local = pyutils.clone_repo(repo_url);
        here.work_tmp = tmp_and_local[0];
        here.local_dir = tmp_and_local[1];
        here.repo_url = repo_url;
        let rname = pyutils.safe_repo_name(repo_url);
        here.out_dir = "../outputs/" + rname;
        spawn here map_repo();
        spawn here analyze_code();
        spawn here generate_docs();
    }
}

walker map_repo {
    def entry() {
        here.map_json = pyutils.file_tree(here.local_dir);
        here.readme   = pyutils.readme_summary(here.local_dir);
    }
}

walker analyze_code {
    def entry() {
        let pair = parser.build_ccg(here.local_dir);
        let dot = parser.graph_to_dot(pair[0]);
        here.ccg_meta = pair[1];
        let dot_path = f"{here.out_dir}/ccg.gv";
        dot.render(dot_path, view=false, format="png");
        here.ccg_dot_path = f"{dot_path}.png";
    }
}

walker generate_docs {
    def entry() {
        let md_path = f"{here.out_dir}/docs.md";
        fs.make_dirs(here.out_dir);
        let meta = here.ccg_meta;
        let rsum = here.readme;

        let content = "# Codebase Genius Documentation\\n\\n";
        content += "## Project Overview\\n" + (rsum if rsum else "(No README)") + "\\n\\n";
        content += "## Code Context Graph (overview)\\n";
        content += "- Files analyzed: " + str(meta.get("files_analyzed",0)) + "\\n";
        content += "- Functions: " + str(meta.get("functions",0)) + "\\n";
        content += "- Classes: " + str(meta.get("classes",0)) + "\\n";
        if here.ccg_dot_path:
            content += f"\\n![CCG Diagram]({here.ccg_dot_path})\\n";

        fs.write_file(md_path, content);
        here.docs_md_path = md_path;
    }
}

walker ping_api {
    can http.route with method="GET", path="/api/ping";
    def entry() { http.send_json({"ok": true, "msg": "pong"}); }
}

walker generate_api {
    can http.route with method="POST", path="/api/generate";
    def entry() {
        let body = http.json();
        let url = body.get("repo_url","");
        spawn new Repo() as r;
        r.repo_url = url;
        spawn r supervisor(repo_url=url);
        http.send_json({"status":"started","repo_url":url,"outputs_dir":r.out_dir});
    }
}
EOF

  # Frontend app
  cat > "$FE_DIR/app.py" << 'EOF'
import os, requests, time
import streamlit as st

BACKEND = f"http://{os.getenv('BACKEND_HOST','127.0.0.1')}:{os.getenv('BACKEND_PORT','8000')}"

st.set_page_config(page_title="Codebase Genius", page_icon="🧠", layout="wide")
st.title("🧠 Codebase Genius – Agentic Code-Documentation (Jac)")

repo_url = st.text_input("Public GitHub Repository URL", "https://github.com/jaseci-labs/Agentic-AI")
col_run, col_ping = st.columns(2)

with col_ping:
    if st.button("Ping Backend"):
        try:
            r = requests.get(f"{BACKEND}/api/ping", timeout=5).json()
            st.success(r)
        except Exception as e:
            st.error(f"Backend unreachable: {e}")

with col_run:
    if st.button("Generate Documentation"):
        with st.spinner("Starting job..."):
            try:
                r = requests.post(f"{BACKEND}/api/generate", json={"repo_url": repo_url}, timeout=10).json()
                st.success("Job started ✅")
                st.json(r)
                st.info("Docs will appear under `agentic_codebase_genius/outputs/<repo_name>/docs.md`.")
            except Exception as e:
                st.error(f"Failed: {e}")
EOF

  touch "$OUT_DIR/.gitkeep"
}

create_venv_and_install() {
  log "Creating backend venv + installing deps..."
  python3 -m venv "$BE_VENV"
  # shellcheck disable=SC1090
  source "$BE_VENV/bin/activate"
  pip install --upgrade pip wheel setuptools
  pip install -r "$BE_DIR/requirements.txt"
  cp -n "$BE_DIR/.env.example" "$BE_DIR/.env" || true
  deactivate

  log "Creating frontend venv + installing deps..."
  python3 -m venv "$FE_VENV"
  # shellcheck disable=SC1090
  source "$FE_VENV/bin/activate"
  pip install --upgrade pip wheel setuptools
  pip install -r "$FE_DIR/requirements.txt"
  deactivate
}

start_backend() {
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    warn "Backend already running (PID $(cat "$PIDFILE"))."
    return
  fi
  log "Starting backend on $BACKEND_URL ..."
  # shellcheck disable=SC1090
  source "$BE_VENV/bin/activate"
  ( cd "$BE_DIR" && nohup jac serve main.jac >/tmp/cg_backend.log 2>&1 & echo $! > "../$PIDFILE" )
  deactivate
  sleep 2
  if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    log "Backend started (PID $(cat "$PIDFILE")). Logs: /tmp/cg_backend.log"
  else
    error "Backend failed to start. See /tmp/cg_backend.log"; exit 1
  fi
}

start_frontend() {
  log "Starting Streamlit frontend... (Ctrl+C to stop FE only)"
  # shellcheck disable=SC1090
  source "$FE_VENV/bin/activate"
  ( cd "$FE_DIR" && streamlit run app.py )
  deactivate
}

kill_backend() {
  if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE")"
    if kill -0 "$PID" 2>/dev/null; then
      log "Stopping backend PID $PID ..."
      kill "$PID" || true
      rm -f "$PIDFILE"
    else
      warn "Stale PID file found; removing."
      rm -f "$PIDFILE"
    fi
  else
    warn "No backend PID file found."
  fi
}

clean_all() {
  kill_backend || true
  log "Removing venvs and outputs..."
  rm -rf "$BE_VENV" "$FE_VENV" "$OUT_DIR"
  log "Done."
}

bootstrap_if_needed() {
  if [ ! -d "$PROJECT_ROOT" ]; then
    ensure_sys_deps
    write_files
    create_venv_and_install
  else
    # ensure venvs & basic files exist
    [ -d "$BE_VENV" ] || create_venv_and_install
  fi
}

gen_docs() {
  local url="$1"
  if [ -z "${url:-}" ]; then error "Provide a repo URL. Example: bash cg.sh gen https://github.com/user/repo"; exit 1; fi
  start_backend
  log "Requesting doc generation for: $url"
  if ! exists curl; then
    error "curl not found. Please install curl."
    exit 1
  fi
  curl -s -X POST "$BACKEND_URL/api/generate" \
    -H 'Content-Type: application/json' \
    -d "{\"repo_url\":\"$url\"}"
  echo
  log "Docs will be placed under $OUT_DIR/<repo_name>/docs.md"
}

cmd="${1:-up}"
case "$cmd" in
  up)
    bootstrap_if_needed
    start_backend
    start_frontend
    ;;
  gen)
    shift || true
    bootstrap_if_needed
    gen_docs "${1:-}"
    ;;
  kill)
    kill_backend
    ;;
  clean)
    clean_all
    ;;
  *)
    echo "Usage: bash cg.sh [up|gen <repo_url>|kill|clean]"
    exit 1
    ;;
esac
