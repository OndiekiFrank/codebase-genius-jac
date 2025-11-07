#!/usr/bin/env python3
"""
Codebase Genius - portable docs generator (no external deps)
- Scans a directory for multiple languages
- Summarizes README
- Builds a simple import dependency graph (Mermaid) for Python & JS/TS
- Writes outputs/docs.md

Usage:
  python gen_docs.py [root_dir]
"""

import os
import re
import sys
import json
from pathlib import Path

IGNORES = {
    ".git", ".hg", ".svn", ".idea", ".vscode", ".venv", "venv",
    "__pycache__", "node_modules", "dist", "build", ".pytest_cache",
    ".mypy_cache", ".ruff_cache", ".tox", ".cache", "target", "out", "bin"
}

LANG_EXTS = {
    "Python": (".py",),
    "JavaScript/TypeScript": (".js", ".mjs", ".cjs", ".jsx", ".ts", ".tsx"),
    "Java": (".java",),
    "Go": (".go",),
    "Rust": (".rs",),
    "C/C++": (".c", ".h", ".cc", ".cpp", ".hpp", ".cxx", ".hxx"),
}

README_FILES = ("README.md", "Readme.md", "readme.md", "README", "README.rst")


def walk_files(root: Path):
    for d, dirs, files in os.walk(root):
        # filter ignored dirs in-place for speed
        dirs[:] = [x for x in dirs if x not in IGNORES and not x.startswith(".")]
        for f in files:
            yield Path(d) / f


def find_by_lang(root: Path):
    buckets = {k: [] for k in LANG_EXTS}
    for p in walk_files(root):
        for lang, exts in LANG_EXTS.items():
            if p.suffix.lower() in exts:
                buckets[lang].append(p)
                break
    for k in buckets:
        buckets[k].sort()
    return buckets


def read_readme(root: Path) -> str | None:
    for name in README_FILES:
        f = root / name
        if f.exists():
            txt = f.read_text(encoding="utf-8", errors="ignore")
            # 1-liner summary: first non-empty line stripped of markdown hashes
            for line in txt.splitlines():
                clean = line.strip()
                if clean:
                    return re.sub(r"^#+\s*", "", clean)
    return None


def slug_for_mermaid(path: Path, root: Path) -> str:
    # turn "src/utils/file.py" into "src_utils_file_py"
    rel = path.relative_to(root).as_posix()
    slug = re.sub(r"[^A-Za-z0-9]+", "_", rel)
    return slug.strip("_")


def py_import_edges(files: list[Path], root: Path):
    """
    Super-light import edge detector:
    - detects lines like: import X, from X import Y
    - maps to filenames by best-effort module path.
    """
    modules = {  # module stem -> path list
        p.stem: p for p in files
    }
    edges = set()
    imp_re1 = re.compile(r"^\s*import\s+([A-Za-z0-9_\.]+)")
    imp_re2 = re.compile(r"^\s*from\s+([A-Za-z0-9_\.]+)\s+import\s+")
    for p in files:
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        src = slug_for_mermaid(p, root)
        for line in text.splitlines():
            m = imp_re1.match(line) or imp_re2.match(line)
            if not m:
                continue
            mod = m.group(1).split(".")[0]  # rough module head
            if mod in modules:
                dst = slug_for_mermaid(modules[mod], root)
                if src != dst:
                    edges.add((src, dst))
    return sorted(edges)


def js_import_edges(files: list[Path], root: Path):
    """
    Very rough JS/TS import detector for Mermaid:
    - import X from '...'
    - const X = require("...")
    Only resolves local relative files (./, ../) by basename matching.
    """
    edges = set()
    require_re = re.compile(r'require\(["\'](.+?)["\']\)')
    import_re = re.compile(r'^\s*import\s+.*?from\s+["\'](.+?)["\']')
    basenames = {f.stem: f for f in files}
    for p in files:
        try:
            text = p.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        src = slug_for_mermaid(p, root)
        for line in text.splitlines():
            m = import_re.match(line) or require_re.search(line)
            if not m:
                continue
            target = m.group(1)
            # only try relative bare names ./foo or ../foo => "foo"
            base = Path(target).stem
            if base in basenames:
                dst = slug_for_mermaid(basenames[base], root)
                if src != dst:
                    edges.add((src, dst))
    return sorted(edges)


def mermaid_graph(edges: list[tuple[str, str]], title: str) -> str:
    if not edges:
        return f"```mermaid\ngraph LR\n%% No edges detected for {title}\n```\n"
    lines = ["```mermaid", "graph LR"]
    for a, b in edges:
        lines.append(f"  {a} --> {b}")
    lines.append("```")
    lines.append("")  # trailing newline
    return "\n".join(lines)


def write_markdown(
    root: Path,
    buckets: dict[str, list[Path]],
    readme_line: str | None,
    py_edges: list[tuple[str, str]],
    js_edges: list[tuple[str, str]],
    out_md: Path,
):
    total_counts = {k: len(v) for k, v in buckets.items()}
    lines = []
    lines.append("# Codebase Genius — Docs\n")
    lines.append(f"Scanned root: `{root.resolve()}`\n")

    lines.append("## Summary\n")
    for lang in LANG_EXTS:
        lines.append(f"- {lang}: {total_counts[lang]}")
    lines.append("")

    if readme_line:
        lines.append("## README summary (first non-empty line)\n")
        lines.append(f"> {readme_line}\n")

    # Mermaid graphs
    if py_edges:
        lines.append("## Python import graph (Mermaid)\n")
        lines.append(mermaid_graph(py_edges, "Python"))
    if js_edges:
        lines.append("## JS/TS import graph (Mermaid)\n")
        lines.append(mermaid_graph(js_edges, "JS/TS"))

    # File listings
    for lang in LANG_EXTS:
        files = buckets[lang]
        lines.append(f"## {lang} files")
        if not files:
            lines.append("_None_")
        else:
            for p in files:
                lines.append(f"- `{p.relative_to(root)}`")
        lines.append("")  # gap

    out_md.parent.mkdir(parents=True, exist_ok=True)
    out_md.write_text("\n".join(lines), encoding="utf-8")


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    buckets = find_by_lang(root)
    readme_line = read_readme(root)

    # dependency edges
    py_edges = mermaid = []
    js_edges = mermaid = []
    if buckets["Python"]:
        py_edges = py_import_edges(buckets["Python"], root)
    if buckets["JavaScript/TypeScript"]:
        js_edges = js_import_edges(buckets["JavaScript/TypeScript"], root)

    out_md = Path("outputs") / "docs.md"
    write_markdown(root, buckets, readme_line, py_edges, js_edges, out_md)

    print(
        "Wrote outputs/docs.md with "
        f"{len(buckets['Python'])} Python, "
        f"{len(buckets['JavaScript/TypeScript'])} JavaScript/TypeScript, "
        f"{len(buckets['Java'])} Java, "
        f"{len(buckets['Go'])} Go, "
        f"{len(buckets['Rust'])} Rust, "
        f"{len(buckets['C/C++'])} C/C++."
    )


if __name__ == "__main__":
    main()
