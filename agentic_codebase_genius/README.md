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
