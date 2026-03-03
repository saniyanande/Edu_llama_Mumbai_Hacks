from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
import os
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

        # RAG pipeline components
        self.embedder      = SentenceTransformer('all-MiniLM-L6-v2')
        self.chroma_client = chromadb.PersistentClient(path="./chroma_store")
        # Using a versioned collection so old Grade7/Science-only data is separate
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

        self.load_all_content()

    # ── Content loading ───────────────────────────────────────────────────────

    def load_all_content(self) -> None:
        """Walk content/{Grade}/{Subject}/ and index every PDF into ChromaDB."""
        if not os.path.exists(CONTENT_DIR):
            os.makedirs(CONTENT_DIR)
            return

        existing_ids  = set(self.collection.get()['ids'])
        total_indexed = 0

        for grade in sorted(os.listdir(CONTENT_DIR)):
            grade_path = os.path.join(CONTENT_DIR, grade)
            if not os.path.isdir(grade_path) or grade.startswith('.'):
                continue

            self.content[grade] = {}

            for subject in sorted(os.listdir(grade_path)):
                subject_path = os.path.join(grade_path, subject)
                if not os.path.isdir(subject_path) or subject.startswith('.'):
                    continue

                self.content[grade][subject] = {}
                pdf_files = sorted(
                    f for f in os.listdir(subject_path) if f.endswith('.pdf'))

                for pdf_file in pdf_files:
                    chapter_name = pdf_file.replace('.pdf', '')
                    text         = self._read_pdf(
                                        os.path.join(subject_path, pdf_file))
                    self.content[grade][subject][chapter_name] = text

                    # ChromaDB chunk IDs encode grade + subject + chapter
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
                            documents=new_docs,
                            embeddings=embeddings,
                            ids=new_ids,
                            metadatas=new_meta,
                        )
                        total_indexed += len(new_docs)
                        app.logger.info(
                            f"Indexed {len(new_docs)} chunks: "
                            f"{grade}/{subject}/{chapter_name}")
                    else:
                        app.logger.info(
                            f"Already indexed: {grade}/{subject}/{chapter_name}")

        app.logger.info(
            f"✅ Content load complete — {total_indexed} new chunks indexed.")

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

@app.route('/api/quiz', methods=['POST'])
def generate_quiz():
    try:
        data    = request.get_json()
        grade   = data.get('grade',   'Grade7')
        subject = data.get('subject', 'Science')
        chapter = data.get('chapter', '')
        num_q   = int(data.get('num_questions', 5))

        # RAG retrieval scoped to this grade+subject+chapter
        q_emb   = tutor.embedder.encode(
            [f"quiz questions about {subject} {chapter}"]).tolist()
        results = tutor.collection.query(
            query_embeddings=q_emb,
            n_results=8,
            where={"grade": grade, "subject": subject, "chapter": chapter},
        )
        context = (
            "\n\n".join(results['documents'][0])
            if results['documents']
            else tutor.content
                      .get(grade, {})
                      .get(subject, {})
                      .get(chapter, '')[:3000]
        )

        prompt = (
            f"Generate {num_q} multiple-choice questions about {subject} "
            f"for {grade} students from the text below.\n"
            "Return ONLY a valid JSON array — no explanation, no markdown fences.\n"
            'Each item: {"question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"answer":"A"}\n\n'
            f"Text:\n{context}"
        )

        response = ollama.chat(
            model=OLLAMA_MODEL,
            messages=[
                {'role': 'system',
                 'content': 'You are a quiz generator. Output only valid JSON arrays.'},
                {'role': 'user', 'content': prompt},
            ],
            stream=False,
        )

        raw = response['message']['content'].strip()
        if raw.startswith('```'):
            raw = raw.split('```')[1]
            if raw.startswith('json'):
                raw = raw[4:].strip()

        return jsonify({
            'status':    'success',
            'grade':     grade,
            'subject':   subject,
            'chapter':   chapter,
            'questions': json_lib.loads(raw),
        })
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0',
            port=int(os.getenv('PORT', 6000)))
