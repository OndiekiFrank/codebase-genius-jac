import os
import requests
import streamlit as st

API_BASE = os.getenv("BACKEND_URL", "http://127.0.0.1:8000")

st.set_page_config(page_title="Codebase Genius", page_icon="🧠", layout="wide")

st.title("🧠 Codebase Genius — Frontend")
st.caption(f"Backend: {API_BASE}")

# -------------------------
# Session state for token
# -------------------------
if "token" not in st.session_state:
    st.session_state.token = None

# -------------------------
# Auth panel
# -------------------------
with st.sidebar:
    st.subheader("🔐 Login")
    email = st.text_input("Email", value="tester@example.com")
    password = st.text_input("Password", value="pass1234", type="password")
    if st.button("Login"):
        try:
            r = requests.post(
                f"{API_BASE}/user/login",
                json={"email": email, "password": password},
                timeout=15,
            )
            if r.status_code == 200:
                data = r.json()
                st.session_state.token = data.get("token")
                st.success("Logged in.")
            else:
                st.error(f"Login failed: {r.status_code} {r.text}")
        except Exception as e:
            st.error(f"Login error: {e}")

    if st.session_state.token:
        st.success("Authenticated ✔")
    else:
        st.warning("Not authenticated")

# -------------------------
# Helpers
# -------------------------
def authed_headers():
    if not st.session_state.token:
        return {}
    return {"Authorization": f"Bearer {st.session_state.token}", "Content-Type": "application/json"}

def call_walker(name: str, payload: dict | None = None):
    payload = payload or {}
    try:
        r = requests.post(
            f"{API_BASE}/walker/{name}",
            headers=authed_headers(),
            json=payload,
            timeout=30,
        )
        return r.status_code, r.json()
    except Exception as e:
        return 0, {"error": str(e)}

# -------------------------
# Tabs
# -------------------------
tab_ping, tab_generate, tab_outputs = st.tabs(["Ping", "Generate", "Outputs"])

with tab_ping:
    st.subheader("PingV6")
    if st.button("Call PingV6"):
        code, res = call_walker("PingV6", {})
        st.write("Status:", code)
        st.json(res)

with tab_generate:
    st.subheader("GenerateV4")
    st.caption("Currently returns instructions on how to run the docs generator.")
    root = st.text_input("Root folder to scan", value="..")
    if st.button("Call GenerateV4"):
        # Your current walker ignores payload; we still send it for future-proofing.
        code, res = call_walker("GenerateV4", {"root": root})
        st.write("Status:", code)
        st.json(res)
    st.info(
        "To actually generate docs locally right now, run:\n\n"
        f"`python gen_docs.py {root or '..'}`\n\n"
        "or use `make docs` / `make docs-up` in the BE folder."
    )

with tab_outputs:
    st.subheader("Outputs")
    st.write("When you run the generator, it writes `outputs/docs.md` in the repo root.")
    out_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "outputs", "docs.md"))
    st.code(out_path, language="bash")
    if os.path.exists(out_path):
        st.success("Found outputs/docs.md")
        try:
            with open(out_path, "r", encoding="utf-8", errors="ignore") as f:
                st.download_button("Download docs.md", f.read(), file_name="docs.md")
        except Exception as e:
            st.error(f"Read error: {e}")
    else:
        st.warning("No docs.md yet. Run the generator first.")
