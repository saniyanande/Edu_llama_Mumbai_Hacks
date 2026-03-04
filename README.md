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

## 📽️ Demo Video

<!-- Add your video recording link or embed here -->
> 🎬 *Video coming soon — paste your recording link or upload to GitHub and embed it here.*

<!-- Example: -->
<!-- https://github.com/user-attachments/assets/YOUR-VIDEO-ASSET-ID -->

---

## 🎥 Walkthrough

https://github.com/user-attachments/assets/91c64666-4ce0-4fe5-9cab-d5833fd7a29d

---

## 📸 Screenshots

![Screenshot 1](https://github.com/user-attachments/assets/10cc5077-63ce-44cf-bba2-c2925b2261a4)
![Screenshot 2](https://github.com/user-attachments/assets/298c3811-8333-4f49-9024-788ef07fa12d)
![Screenshot 3](https://github.com/user-attachments/assets/b6e81470-06cf-483b-a195-a088acf99c10)

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
| 🐳 **Docker Support** | Full Docker + docker-compose setup for easy deployment |

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

## 📁 Content Structure

Drop NCERT PDF files into this folder structure — the backend auto-discovers them:

```
Edu-LLAMA-Backend/content/
├── Grade6/
│   ├── Science/
│   ├── Maths/
│   ├── English/
│   └── Social_Science/
├── Grade7/
│   └── ...
└── Grade8/
    └── ...
```

---

## 🚀 How to Run

### Prerequisites
- [Ollama](https://ollama.com) installed
- Python 3.11+
- Flutter SDK 3.5+

### One-time setup
```bash
ollama pull llama3.2

cd Edu-LLAMA-Backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

---

### Terminal 1 — Start the Backend
```bash
cd Edu-LLAMA-Backend
source venv/bin/activate
python app.py
```
✅ Ready when you see: `Running on http://127.0.0.1:6000`

---

### Terminal 2 — Run the Flutter App

**macOS:**
```bash
flutter run -d macos
```

**iOS Simulator:**
```bash
flutter emulators --launch apple_ios_simulator
flutter run -d "iPhone"
```

**Real iPhone (same Wi-Fi):**
```bash
flutter run -d "iPhone" --dart-define=BASE_URL=http://<YOUR_MAC_IP>:6000/api
```

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

## 🐳 Docker (Optional)

```bash
cd Edu-LLAMA-Backend
docker-compose up --build
```

Starts both Flask (port 6000) and Ollama (port 11434) together.

---

## 📄 License

MIT
