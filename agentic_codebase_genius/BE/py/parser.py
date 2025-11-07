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
