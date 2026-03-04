# Running EduLlama

## Prerequisites

- [Ollama](https://ollama.com) installed
- Python 3.11+
- Flutter SDK 3.5+
- Xcode (for iOS Simulator)

---

## One-time setup

```bash
# Pull the LLM model (only needed once)
ollama pull llama3.2

# Create Python virtual environment (only needed once)
cd Edu-LLAMA-Backend
python3 -m venv venv
pip install -r requirements.txt
```

---

## Terminal 1 — Backend

```bash
cd Edu-LLAMA-Backend
source venv/bin/activate
python app.py
```

✅ Ready when you see: `Running on http://127.0.0.1:6000`

---

## Terminal 2 — Flutter App

### macOS (Desktop)
```bash
flutter run -d macos
```

### iOS Simulator
```bash
# Boot the simulator first
flutter emulators --launch apple_ios_simulator

# Then run
flutter run -d "iPhone"
```

### Real iPhone (on same Wi-Fi as Mac)
```bash
flutter run -d "iPhone" --dart-define=BASE_URL=http://192.168.0.112:6000/api
```
> Replace `192.168.0.112` with your Mac's actual local IP (shown in the backend startup log).

---

## Useful Flutter commands (while app is running)

| Key | Action |
|-----|--------|
| `r` | Hot reload (apply code changes instantly) |
| `R` | Full restart |
| `q` | Quit |

---

## Content folder

Drop NCERT PDF files into the correct folder structure for them to be auto-indexed:

```
Edu-LLAMA-Backend/content/
├── Grade6/
│   ├── Science/       ← one PDF per chapter
│   ├── Maths/
│   ├── English/
│   └── Social_Science/
├── Grade7/
└── Grade8/
```

No code changes needed — the backend discovers PDFs automatically on startup.
