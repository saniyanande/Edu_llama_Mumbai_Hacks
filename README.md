<h1 align="center">EduLlama 🎓</h1>

<p align="center">
  <em>An AI-powered tutoring app for CBSE students — Grades 6 to 8</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.5-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Python-3.11-yellow?logo=python" />
  <img src="https://img.shields.io/badge/LLM-llama3.2-purple" />
  <img src="https://img.shields.io/badge/RAG-ChromaDB-green" />
  <img src="https://img.shields.io/badge/Built%20at-Mumbai%20Hacks-orange" />
</p>

---

## 💡 What is EduLlama?

EduLlama is a local, offline-capable AI tutoring platform built for CBSE middle school students (Grades 6–8). It uses a locally running LLM (Llama 3.2 via Ollama) combined with a Retrieval-Augmented Generation (RAG) pipeline to answer questions and generate quizzes directly from NCERT textbook PDFs — no internet or cloud API required.

---

## ✨ Features

| Feature | Description |
|---|---|
| 📚 **Multi-Grade Support** | Covers Grades 6, 7, and 8 across Science, Maths, English, and Social Science |
| 🤖 **AI Chat Tutor** | Ask any question about a chapter and get an age-appropriate, CBSE-aligned answer |
| 🌊 **Streaming Responses** | AI replies appear token-by-token in real time, like ChatGPT |
| 🧠 **RAG Pipeline** | Answers are grounded in actual NCERT PDF content using ChromaDB vector search |
| 📝 **AI Quiz Generator** | Generates 5 multiple-choice questions per subject using the textbook content |
| 🏆 **Scoreboard** | Tracks all quiz attempts with best scores per subject, grouped by grade |
| 💾 **Chat Persistence** | Conversations are saved locally and restored on next open |
| 🗂️ **Auto Content Discovery** | Drop PDFs into the content folder — no code changes needed |

---

## 🏗️ Tech Stack

### Backend
- **Python 3.11** + **Flask** — REST API server
- **Ollama** — runs Llama 3.2 locally (no cloud API)
- **ChromaDB** — persistent vector store for RAG
- **Sentence Transformers** (`all-MiniLM-L6-v2`) — text embeddings
- **LangChain Text Splitters** — chunks PDFs into 500-token pieces
- **PyPDF2** — reads NCERT textbook PDFs

### Frontend
- **Flutter 3.5** (Dart) — cross-platform app (iOS, Android, macOS)
- **Dio** — streaming HTTP for real-time AI responses
- **SharedPreferences** — local persistence for chat history and scores

---

## 🔌 API Endpoints

| Method | Route | Description |
|---|---|---|
| `GET` | `/api/status` | Health check + indexing status |
| `GET` | `/api/grades` | List available grades |
| `GET` | `/api/subjects/<grade>` | List subjects for a grade |
| `GET` | `/api/chapters/<grade>/<subject>` | List chapters |
| `POST` | `/api/ask` | Ask a question (full response) |
| `POST` | `/api/ask/stream` | Ask a question (streaming) |
| `POST` | `/api/quiz` | Generate AI quiz questions |
| `POST` | `/api/session/clear` | Clear conversation history |

---

## 📽️ Demo Video



https://github.com/user-attachments/assets/8c614ec1-0d6e-4756-bc33-9b69de362c3b



---

> For setup and run instructions, see [RUNNING.md](RUNNING.md)

## 📄 License

MIT
