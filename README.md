# 🧠 Codebase Genius — Agentic Codebase Platform

[![Streamlit App](https://img.shields.io/badge/Launch%20App-Streamlit-red?style=flat-square&logo=streamlit)](https://ondiekifrank-codebase-geniu-agentic-codebase-geniusfeapp-hjvrqr.streamlit.app/)
[![GitHub Repo](https://img.shields.io/badge/View%20on-GitHub-black?style=flat-square&logo=github)](https://github.com/OndiekiFrank/codebase-genius-jac.git)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## 🌍 Overview

**Codebase Genius** is an **Agentic AI-driven platform** designed to help developers automatically analyze, document, and generate structured reports from codebases.  
It connects a **Jac-based backend** (running on Jaseci Cloud/Local BE) with a **Streamlit Frontend**, enabling real-time interaction between AI agents and your source code.

This project demonstrates how to integrate:
- 🔹 **Jac Language (Jaseci)** for AI walkers and graph-based orchestration  
- 🔹 **FastAPI backend** for serving walkers and user APIs  
- 🔹 **Streamlit frontend** for an intuitive, real-time dashboard interface  
- 🔹 **Doc generation & automation pipeline** for software analysis

---

## 🚀 Live Demo

👉 **Access the live app:**  
🔗 [Codebase Genius Streamlit App](https://ondiekifrank-codebase-geniu-agentic-codebase-geniusfeapp-hjvrqr.streamlit.app/)

💻 **GitHub Repository:**  
🔗 [https://github.com/OndiekiFrank/codebase-genius-jac.git](https://github.com/OndiekiFrank/codebase-genius-jac.git)

---

## 🧩 Features

- ✅ **AI-Assisted Codebase Analysis**
  - Uses Jac walkers like `PingV6` and `GenerateV4` to traverse and interpret backend logic.

- ⚙️ **Autonomous Documentation Generator**
  - Produces human-readable documentation from existing code structure.
  - Simple CLI execution:  
    ```bash
    python gen_docs.py
    # or
    make docs
    ```

- 🌐 **Interactive Frontend (Streamlit)**
  - Provides a friendly web interface for interacting with the backend API.  
  - Includes authentication, doc generation buttons, and output previews.

- 🔒 **Secure Backend Integration**
  - Token-based authentication using FastAPI + JWT.
  - Configurable through `.env` or environment variables.

---

## 🛠️ Tech Stack

| Layer | Technology | Purpose |
|-------|-------------|----------|
| **Frontend** | [Streamlit](https://streamlit.io) | Interactive dashboard |
| **Backend** | [FastAPI](https://fastapi.tiangolo.com/) | API + user endpoints |
| **Core Logic** | [Jac Language](https://jaseci.org) | Agentic walkers and orchestration |
| **Database** | LocalDB / Redis (optional) | Caching and persistence |
| **Auth** | JWT | Secure user login and verification |

---

## 📁 Project Structure

agentic_codebase_genius/
│
├── BE/ # Backend (Jac + FastAPI)
│ ├── main.jac # Walkers (PingV6, GenerateV4)
│ ├── gen_docs.py # Doc generator
│ ├── requirements.txt
│ └── ...
│
├── FE/ # Frontend (Streamlit)
│ ├── app.py
│ ├── requirements.txt
│ └── ...
│
└── README.md # Project documentation

## 2️⃣ Set Up Backend (Jac)
```bash
cd BE
python3 -m venv jac-env
source jac-env/bin/activate
pip install -r requirements.txt

# Build and serve
jac build main.jac
jac serve main.jac --port 8000
```
### 3️⃣ Run Frontend (Streamlit)
```bash
cd ../FE
pip install -r requirements.txt
streamlit run app.py
```
### 4️⃣ Access Locally

Visit 👉 http://localhost:8501

---

## 🧠 Walkers Reference

| Walker | Description | Example Output |
|--------|-------------|----------------|
| PingV6 | Tests connectivity and backend readiness | `{ "ok": true, "msg": "pong v6" }` |
| GenerateV4 | Generates documentation instructions | `{ "how_to_run": "python gen_docs.py .." }` |

---

## 👤 Author

**Frankline Ombachi Ondieki**  
📧 [ondiekifrank021@gmail.com](mailto:ondiekifrank021@gmail.com)  

💼 [LinkedIn](https://www.linkedin.com/in/frankline-ombachi-ondieki/)  
🌍 [GitHub Profile](https://github.com/OndiekiFrank)  

---

## 📜 License

This project is licensed under the **MIT License** — see [LICENSE](LICENSE) for details.

---

## 🧾 Notes for Reviewers / Markers

This submission demonstrates:

- End-to-end integration of a Jac backend with a Streamlit frontend
- Functional API connection between `/walker/PingV6` and `/walker/GenerateV4`
- Live deployment on Streamlit Cloud (link above)
- Clean, modular structure ready for extension (e.g., codebase traversal, docgen AI)

---

🌟 **Thank you for reviewing Codebase Genius!**

*"Where AI meets automation — transforming codebases into self-documenting systems."*
