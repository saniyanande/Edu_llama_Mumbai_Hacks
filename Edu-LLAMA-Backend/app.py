from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
import os
import re
import threading
from PyPDF2 import PdfReader
import ollama
import time
import uuid
import json as json_lib
from typing import Dict, List, Tuple, Optional
from sentence_transformers import SentenceTransformer
import chromadb
from langchain_text_splitters import RecursiveCharacterTextSplitter
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
CORS(app)

OLLAMA_MODEL  = os.getenv("OLLAMA_MODEL", "llama3.2")
CONTENT_DIR   = os.getenv("CONTENT_DIR",
                           os.path.join(os.path.dirname(__file__), "content"))


class EduLlamaAPI:
    """
    Multi-grade, multi-subject AI tutor.
    Scans content/{Grade}/{Subject}/*.pdf automatically on startup.
    """

    def __init__(self):
        # 3-level dict:  grade → subject → chapter_name → full text
        self.content: Dict[str, Dict[str, Dict[str, str]]] = {}
        self._indexing_done = False

        # RAG pipeline components
        self.embedder      = SentenceTransformer('all-MiniLM-L6-v2')
        self.chroma_client = chromadb.PersistentClient(path="./chroma_store")
        self.collection    = self.chroma_client.get_or_create_collection("edu_llama_v2")
        self.splitter      = RecursiveCharacterTextSplitter(
                                chunk_size=500, chunk_overlap=50)

        self.tutor_prompt = """
        You are EduLlama, a friendly AI tutor for CBSE students in Grades 6-8.
        - Explain concepts simply and in an age-appropriate way
        - Use relatable, everyday examples
        - Encourage curiosity and critical thinking
        - Break complex topics into small, digestible parts
        Always mention the grade and subject context in your explanation when helpful.
        """

        # Phase 1: scan directories NOW (fast — just reads filenames)
        self._scan_dirs()
        # Phase 2: index PDFs in background (slow)
        thread = threading.Thread(target=self._index_pdfs, daemon=True)
        thread.start()

    # ── Content loading ───────────────────────────────────────────────────────

    def _scan_dirs(self) -> None:
        """Fast sync scan: build grade/subject/chapter structure from filenames only."""
        if not os.path.exists(CONTENT_DIR):
            os.makedirs(CONTENT_DIR)
            return
        for grade in sorted(os.listdir(CONTENT_DIR)):
            grade_path = os.path.join(CONTENT_DIR, grade)
            if not os.path.isdir(grade_path) or grade.startswith('.'):
                continue
            self.content[grade] = {}
            for subject in sorted(os.listdir(grade_path)):
                subject_path = os.path.join(grade_path, subject)
                if not os.path.isdir(subject_path) or subject.startswith('.'):
                    continue
                self.content[grade][subject] = {
                    f.replace('.pdf', ''): ''
                    for f in sorted(os.listdir(subject_path))
                    if f.endswith('.pdf')
                }
        app.logger.info(
            f"Directory scan complete: {list(self.content.keys())}")

    def _index_pdfs(self) -> None:
        """Background thread: read PDFs and index into ChromaDB."""
        existing_ids  = set(self.collection.get()['ids'])
        total_indexed = 0

        for grade, subjects in self.content.items():
            for subject, chapters in subjects.items():
                subject_path = os.path.join(CONTENT_DIR, grade, subject)
                for chapter_name in sorted(chapters.keys()):
                    pdf_path = os.path.join(subject_path, chapter_name + '.pdf')
                    text     = self._read_pdf(pdf_path)
                    self.content[grade][subject][chapter_name] = text

                    prefix = f"{grade}__{subject}__{chapter_name}"
                    chunks = self.splitter.split_text(text)
                    new_docs, new_ids, new_meta = [], [], []
                    for i, chunk in enumerate(chunks):
                        cid = f"{prefix}__chunk_{i}"
                        if cid not in existing_ids:
                            new_docs.append(chunk)
                            new_ids.append(cid)
                            new_meta.append({
                                "grade":   grade,
                                "subject": subject,
                                "chapter": chapter_name,
                            })
                    if new_docs:
                        embeddings = self.embedder.encode(new_docs).tolist()
                        self.collection.add(
                            documents=new_docs, embeddings=embeddings,
                            ids=new_ids, metadatas=new_meta)
                        total_indexed += len(new_docs)
                        app.logger.info(
                            f"Indexed {len(new_docs)} chunks: "
                            f"{grade}/{subject}/{chapter_name}")

        app.logger.info(f"✅ Indexing done — {total_indexed} new chunks.")
        self._indexing_done = True

    # Keep old name as alias for compatibility
    def load_all_content(self): self._index_pdfs()


    def _read_pdf(self, path: str) -> str:
        try:
            reader = PdfReader(path)
            return "\n".join(page.extract_text() or "" for page in reader.pages)
        except Exception as e:
            app.logger.error(f"PDF read error {path}: {e}")
            return ""

    # ── Catalogue helpers ─────────────────────────────────────────────────────

    def get_grades(self)                       -> List[str]:
        return sorted(self.content.keys())

    def get_subjects(self, grade: str)         -> List[str]:
        return sorted(self.content.get(grade, {}).keys())

    def get_chapters(self, grade: str, subject: str) -> List[str]:
        return sorted(self.content.get(grade, {}).get(subject, {}).keys())


# ── Initialise ────────────────────────────────────────────────────────────────
tutor    = EduLlamaAPI()
sessions: Dict[str, List[Dict]] = {}   # session_id → message history


# ── Health / Status ───────────────────────────────────────────────────────────

@app.route('/api/status', methods=['GET'])
def status():
    return jsonify({
        'status':         'ok',
        'indexing_done':  tutor._indexing_done,
        'grades_loaded':  list(tutor.content.keys()),
    })


# ── Grade / Subject / Chapter listing ────────────────────────────────────────

@app.route('/api/grades', methods=['GET'])
def get_grades():
    return jsonify({'status': 'success', 'grades': tutor.get_grades()})


@app.route('/api/subjects/<grade>', methods=['GET'])
def get_subjects(grade):
    subjects = tutor.get_subjects(grade)
    if not subjects:
        return jsonify({'status': 'error', 'message': 'Grade not found'}), 404
    return jsonify({'status': 'success', 'grade': grade, 'subjects': subjects})


@app.route('/api/chapters/<grade>/<subject>', methods=['GET'])
def get_chapters(grade, subject):
    chapters = tutor.get_chapters(grade, subject)
    return jsonify({
        'status':  'success',
        'grade':   grade,
        'subject': subject,
        'chapters': chapters,
    })


# Legacy endpoint — kept for backward compatibility with old Flutter code
@app.route('/api/chapters', methods=['GET'])
def get_chapters_legacy():
    chapters = tutor.get_chapters('Grade7', 'Science')
    return jsonify({
        'status':   'success',
        'chapters': chapters,
        'count':    len(chapters),
    })


# ── E1: Conversation memory ───────────────────────────────────────────────────

@app.route('/api/ask', methods=['POST'])
def ask_question():
    try:
        data       = request.get_json()
        grade      = data.get('grade',    'Grade7')
        subject    = data.get('subject',  'Science')
        chapter    = data.get('chapter',  '')
        question   = data.get('question', '')
        session_id = data.get('session_id') or str(uuid.uuid4())

        if session_id not in sessions:
            sessions[session_id] = [
                {'role': 'system', 'content': tutor.tutor_prompt}]

        content = (tutor.content
                   .get(grade, {})
                   .get(subject, {})
                   .get(chapter, ''))

        sessions[session_id].append({
            'role': 'user',
            'content': (
                f"Grade: {grade} | Subject: {subject} | Chapter: {chapter}\n"
                f"Context:\n{content[:3000]}\n\nQuestion: {question}"
            ),
        })

        start_time = time.time()
        response   = ollama.chat(
            model=OLLAMA_MODEL,
            messages=sessions[session_id],
            stream=False)
        time_taken = time.time() - start_time
        answer     = response['message']['content'].strip()

        sessions[session_id].append(
            {'role': 'assistant', 'content': answer})

        return jsonify({
            'status':     'success',
            'grade':      grade,
            'subject':    subject,
            'chapter':    chapter,
            'question':   question,
            'response':   answer,
            'time_taken': time_taken,
            'session_id': session_id,
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/api/session/clear', methods=['POST'])
def clear_session():
    data = request.get_json()
    sid  = data.get('session_id') if data else None
    if sid and sid in sessions:
        del sessions[sid]
    return jsonify({'status': 'success'})


# ── E2: Streaming ─────────────────────────────────────────────────────────────

@app.route('/api/ask/stream', methods=['POST'])
def ask_question_stream():
    try:
        data       = request.get_json()
        grade      = data.get('grade',    'Grade7')
        subject    = data.get('subject',  'Science')
        chapter    = data.get('chapter',  '')
        question   = data.get('question', '')
        session_id = data.get('session_id') or str(uuid.uuid4())

        if session_id not in sessions:
            sessions[session_id] = [
                {'role': 'system', 'content': tutor.tutor_prompt}]

        content = (tutor.content
                   .get(grade, {})
                   .get(subject, {})
                   .get(chapter, ''))

        sessions[session_id].append({
            'role': 'user',
            'content': (
                f"Grade: {grade} | Subject: {subject} | Chapter: {chapter}\n"
                f"Context:\n{content[:3000]}\n\nQuestion: {question}"
            ),
        })

        full_reply = []

        def generate():
            for chunk in ollama.chat(
                    model=OLLAMA_MODEL,
                    messages=sessions[session_id],
                    stream=True):
                token = chunk['message']['content']
                full_reply.append(token)
                yield token
            sessions[session_id].append(
                {'role': 'assistant', 'content': ''.join(full_reply)})

        return Response(
            stream_with_context(generate()),
            mimetype='text/plain',
            headers={'X-Session-Id': session_id},
        )
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ── E4: Quiz ──────────────────────────────────────────────────────────────────

def _extract_json_array(text: str):
    """Robustly extract a JSON array from LLM output, with multiple fallbacks."""
    # 1. Strip markdown fences
    text = re.sub(r'```(?:json)?\s*', '', text).strip()
    text = text.replace('```', '').strip()

    # 2. Find the outermost [...] block
    start = text.find('[')
    end   = text.rfind(']')
    if start == -1 or end == -1:
        raise ValueError(f"No JSON array found in LLM output:\n{text[:300]}")
    candidate = text[start:end + 1]

    # 3. Try direct parse first
    try:
        return json_lib.loads(candidate)
    except json_lib.JSONDecodeError:
        pass

    # 4. Try fixing common LLM mistakes:
    #    - trailing commas before ] or }
    #    - single quotes instead of double quotes
    fixed = re.sub(r',\s*([\]\}])', r'\1', candidate)   # trailing commas
    fixed = fixed.replace("'", '"')                       # single → double quotes
    try:
        return json_lib.loads(fixed)
    except json_lib.JSONDecodeError:
        pass

    # 5. Last resort: extract individual question objects via regex
    pattern = r'\{[^{}]*"question"[^{}]*\}'
    objects = re.findall(pattern, candidate, re.DOTALL)
    if objects:
        results = []
        for obj in objects:
            try:
                results.append(json_lib.loads(obj))
            except Exception:
                pass
        if results:
            return results

    raise ValueError(f"Could not parse JSON from LLM output:\n{text[:300]}")


@app.route('/api/quiz', methods=['POST'])
def generate_quiz():
    try:
        data    = request.get_json()
        grade   = data.get('grade',   'Grade7')
        subject = data.get('subject', 'Science')
        chapter = data.get('chapter', '')   # '' means whole-subject quiz
        num_q   = int(data.get('num_questions', 5))

        # ── RAG retrieval ─────────────────────────────────────────────────────
        query_text = (
            f"quiz questions about {subject} {chapter}"
            if chapter else f"quiz questions about {subject}"
        )
        q_emb = tutor.embedder.encode([query_text]).tolist()

        # Build the where-filter — omit chapter filter when chapter is empty
        where_filter: dict = {"grade": grade, "subject": subject}
        if chapter:
            where_filter["chapter"] = chapter

        try:
            results = tutor.collection.query(
                query_embeddings=q_emb,
                n_results=min(8, tutor.collection.count() or 1),
                where=where_filter,
            )
            docs = results.get('documents', [[]])
            context = "\n\n".join(docs[0]) if docs and docs[0] else ""
        except Exception as chroma_err:
            app.logger.warning(f"ChromaDB query failed ({chroma_err}); falling back to raw text.")
            context = ""

        # Fall back to raw stored text if ChromaDB gave nothing
        if not context:
            subject_chapters = tutor.content.get(grade, {}).get(subject, {})
            if chapter and chapter in subject_chapters:
                context = subject_chapters[chapter][:4000]
            elif subject_chapters:
                # Concatenate first few chapters (subject-wide quiz)
                combined = "\n\n".join(
                    text for text in list(subject_chapters.values())[:3] if text
                )
                context = combined[:4000]

        if not context:
            return jsonify({
                'status':  'error',
                'message': (
                    f"No content found for {grade}/{subject}/{chapter or '(all)'}. "
                    "Make sure PDFs are placed in the content folder and the backend has finished indexing."
                )
            }), 404

        # ── Prompt ────────────────────────────────────────────────────────────
        chapter_label = f"chapter '{chapter}'" if chapter else subject
        example = (
            '[\n'
            '  {"question": "What is photosynthesis?", '
            '"options": ["A. Breathing", "B. Making food from sunlight", "C. Digestion", "D. Reproduction"], '
            '"answer": "B"},\n'
            '  {"question": "Which gas do plants absorb?", '
            '"options": ["A. Oxygen", "B. Nitrogen", "C. Carbon dioxide", "D. Hydrogen"], '
            '"answer": "C"}\n'
            ']'
        )
        prompt = (
            f"Generate exactly {num_q} multiple-choice questions about {chapter_label} "
            f"for {grade} CBSE students, based ONLY on the text below.\n\n"
            "OUTPUT FORMAT: Return ONLY a raw JSON array — no explanation, no markdown, no code fences.\n"
            'Each element: {"question": "...", "options": ["A. ...", "B. ...", "C. ...", "D. ..."], "answer": "X"}\n'
            '"answer" must be ONLY the single letter: A, B, C, or D (nothing else).\n\n'
            f"EXAMPLE OUTPUT:\n{example}\n\n"
            f"TEXT:\n{context[:3500]}"
        )

        response = ollama.chat(
            model=OLLAMA_MODEL,
            messages=[
                {'role': 'system',
                 'content': 'You are a quiz generator. Output ONLY a valid JSON array, nothing else.'},
                {'role': 'user', 'content': prompt},
            ],
            stream=False,
        )

        raw = response['message']['content'].strip()
        questions = _extract_json_array(raw)

        return jsonify({
            'status':    'success',
            'grade':     grade,
            'subject':   subject,
            'chapter':   chapter,
            'questions': questions,
        })
    except Exception as e:
        app.logger.error(f"Quiz generation error: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0',
            port=int(os.getenv('PORT', 6000)))
