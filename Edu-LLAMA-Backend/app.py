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

OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "llama3.2")


class ScienceTutorAPI:
    def __init__(self):
        self.science_dir = os.getenv(
            "SCIENCE_DIR",
            os.path.join(os.path.dirname(__file__), "science_directory")
        )
        self.chapters: Dict[str, str] = {}

        # ── RAG components ───────────────────────────────────────────────────
        # Local embedding model (~90 MB, downloaded once on first run)
        self.embedder = SentenceTransformer('all-MiniLM-L6-v2')
        # Persistent vector database saved to ./chroma_store/
        self.chroma_client = chromadb.PersistentClient(path="./chroma_store")
        self.collection = self.chroma_client.get_or_create_collection("science_chapters")
        # Splits PDF text into overlapping 500-char chunks
        self.splitter = RecursiveCharacterTextSplitter(chunk_size=500, chunk_overlap=50)
        # ─────────────────────────────────────────────────────────────────────

        self.load_chapters()

        self.tutor_prompt = """
        You are a friendly and engaging Science tutor for 7th grade CBSE students. Your role is to:
        - Explain scientific concepts in simple, relatable terms
        - Use everyday examples to illustrate scientific principles
        - Encourage scientific thinking and curiosity
        - Help students understand the practical applications of what they learn
        - Break down complex scientific concepts into easier parts
        - Ask questions to ensure understanding
        """

    def load_chapters(self) -> None:
        """Load PDFs, extract text, and build ChromaDB vector index for RAG."""
        try:
            if not os.path.exists(self.science_dir):
                os.makedirs(self.science_dir)
                app.logger.info(f"Created directory: {self.science_dir}")
                return

            pdf_files = [f for f in os.listdir(self.science_dir) if f.endswith('.pdf')]
            if not pdf_files:
                app.logger.warning(f"No PDF files found in {self.science_dir}")
                return

            # Get IDs already indexed so we skip re-indexing on restart
            existing_ids = set(self.collection.get()['ids'])

            for chapter_file in pdf_files:
                chapter_name = chapter_file.replace('.pdf', '')
                chapter_path = os.path.join(self.science_dir, chapter_file)
                text = self._read_pdf(chapter_path)
                self.chapters[chapter_name] = text

                # Split into chunks and index only new ones
                chunks = self.splitter.split_text(text)
                new_docs, new_ids, new_meta = [], [], []
                for i, chunk in enumerate(chunks):
                    cid = f"{chapter_name}_chunk_{i}"
                    if cid not in existing_ids:
                        new_docs.append(chunk)
                        new_ids.append(cid)
                        new_meta.append({"chapter": chapter_name})

                if new_docs:
                    embeddings = self.embedder.encode(new_docs).tolist()
                    self.collection.add(
                        documents=new_docs,
                        embeddings=embeddings,
                        ids=new_ids,
                        metadatas=new_meta
                    )
                    app.logger.info(f"Indexed {len(new_docs)} chunks for {chapter_name}")
                else:
                    app.logger.info(f"Already indexed: {chapter_name}")

        except Exception as e:
            app.logger.error(f"Error loading chapters: {str(e)}")

    def _read_pdf(self, pdf_path: str) -> str:
        """Extract text from a PDF file."""
        try:
            reader = PdfReader(pdf_path)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\n"
            return text
        except Exception as e:
            app.logger.error(f"Error reading PDF {pdf_path}: {str(e)}")
            return ""

    def ask_question(self, chapter: str, question: str,
                     history: List[Dict] = None) -> Tuple[Optional[str], float]:
        """RAG-powered answer: retrieves top-5 relevant passages then queries LLM."""
        try:
            # Step 1: Embed the question
            q_embedding = self.embedder.encode([question]).tolist()

            # Step 2: Retrieve top-5 most relevant chunks for this chapter
            results = self.collection.query(
                query_embeddings=q_embedding,
                n_results=5,
                where={"chapter": chapter}
            )
            context = "\n\n".join(results['documents'][0]) if results['documents'] \
                else self.chapters.get(chapter, '')[:3000]

            # Step 3: Build messages with optional conversation history
            messages = [{'role': 'system', 'content': self.tutor_prompt}]
            if history:
                messages.extend(history)
            messages.append({
                'role': 'user',
                'content': f"Use ONLY this context to answer:\n{context}\n\nQuestion: {question}"
            })

            # Step 4: Call Ollama
            start_time = time.time()
            response = ollama.chat(model=OLLAMA_MODEL, messages=messages, stream=False)
            time_taken = time.time() - start_time
            return response['message']['content'].strip(), time_taken

        except Exception as e:
            app.logger.error(f"Error in ask_question: {str(e)}")
            return None, 0

    def list_chapters(self) -> List[str]:
        """Return list of available chapter names."""
        return list(self.chapters.keys())


# ── Initialize ────────────────────────────────────────────────────────────────
tutor = ScienceTutorAPI()

# In-memory conversation sessions: session_id → [{"role": ..., "content": ...}]
sessions: Dict[str, List[Dict]] = {}
# ─────────────────────────────────────────────────────────────────────────────


@app.route('/api/chapters', methods=['GET'])
def get_chapters():
    """Get list of all available chapters."""
    try:
        chapters = tutor.list_chapters()
        return jsonify({'status': 'success', 'chapters': chapters, 'count': len(chapters)})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/api/chapters/<chapter_name>', methods=['GET'])
def get_chapter_info(chapter_name):
    """Get info about a specific chapter."""
    try:
        if chapter_name in tutor.chapters:
            return jsonify({
                'status': 'success',
                'chapter': chapter_name,
                'content_length': len(tutor.chapters[chapter_name])
            })
        return jsonify({'status': 'error', 'message': 'Chapter not found'}), 404
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ── E1: Conversation Memory ───────────────────────────────────────────────────

@app.route('/api/ask', methods=['POST'])
def ask_question():
    """Ask a question with full conversation memory."""
    try:
        data = request.get_json()
        if not data or 'chapter' not in data or 'question' not in data:
            return jsonify({'status': 'error', 'message': 'Missing chapter or question'}), 400

        chapter = data['chapter']
        question = data['question']
        session_id = data.get('session_id') or str(uuid.uuid4())

        # Create a new session if this is a new conversation
        if session_id not in sessions:
            sessions[session_id] = [
                {'role': 'system', 'content': tutor.tutor_prompt}
            ]

        content = tutor.chapters.get(chapter)
        if not content:
            return jsonify({'status': 'error', 'message': 'Chapter not found'}), 404

        sessions[session_id].append({
            'role': 'user',
            'content': f"Chapter context:\n{content[:3000]}\n\nStudent question: {question}"
        })

        start_time = time.time()
        response = ollama.chat(model=OLLAMA_MODEL, messages=sessions[session_id], stream=False)
        time_taken = time.time() - start_time
        answer = response['message']['content'].strip()

        # Save AI reply back into session for next turn
        sessions[session_id].append({'role': 'assistant', 'content': answer})

        return jsonify({
            'status': 'success',
            'chapter': chapter,
            'question': question,
            'response': answer,
            'time_taken': time_taken,
            'session_id': session_id   # Flutter sends this back on the next message
        })

    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


@app.route('/api/session/clear', methods=['POST'])
def clear_session():
    """Delete a conversation session (used by the 'New Chat' button)."""
    data = request.get_json()
    sid = data.get('session_id') if data else None
    if sid and sid in sessions:
        del sessions[sid]
    return jsonify({'status': 'success'})


# ── E2: Streaming Responses ───────────────────────────────────────────────────

@app.route('/api/ask/stream', methods=['POST'])
def ask_question_stream():
    """Streams LLM tokens as they are generated (word-by-word like ChatGPT)."""
    try:
        data = request.get_json()
        chapter = data.get('chapter', '')
        question = data.get('question', '')
        session_id = data.get('session_id') or str(uuid.uuid4())

        if session_id not in sessions:
            sessions[session_id] = [{'role': 'system', 'content': tutor.tutor_prompt}]

        content = tutor.chapters.get(chapter, '')
        sessions[session_id].append({
            'role': 'user',
            'content': f"Chapter context:\n{content[:3000]}\n\nQuestion: {question}"
        })

        full_reply = []

        def generate():
            for chunk in ollama.chat(
                model=OLLAMA_MODEL,
                messages=sessions[session_id],
                stream=True
            ):
                token = chunk['message']['content']
                full_reply.append(token)
                yield token
            # Save complete reply to session after streaming finishes
            sessions[session_id].append({
                'role': 'assistant',
                'content': ''.join(full_reply)
            })

        return Response(
            stream_with_context(generate()),
            mimetype='text/plain',
            headers={'X-Session-Id': session_id}
        )

    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ── E4: AI Quiz Generation ────────────────────────────────────────────────────

@app.route('/api/quiz', methods=['POST'])
def generate_quiz():
    """Generate multiple-choice quiz questions for a chapter using LLM + RAG."""
    try:
        data = request.get_json()
        chapter = data.get('chapter', '')
        num_q = int(data.get('num_questions', 5))

        # Use RAG to get relevant context for quiz generation
        q_emb = tutor.embedder.encode([f"quiz questions about {chapter}"]).tolist()
        results = tutor.collection.query(
            query_embeddings=q_emb,
            n_results=8,
            where={"chapter": chapter}
        )
        context = "\n\n".join(results['documents'][0]) if results['documents'] \
            else tutor.chapters.get(chapter, '')[:3000]

        # Strict JSON-mode prompt — tells the LLM exactly what to output
        prompt = f"""Generate {num_q} multiple-choice questions from the text below.
Return ONLY a valid JSON array — no explanation, no markdown fences.
Each item must follow this exact format:
{{"question":"...","options":["A. ...","B. ...","C. ...","D. ..."],"answer":"A"}}

Text:
{context}"""

        response = ollama.chat(
            model=OLLAMA_MODEL,
            messages=[
                {'role': 'system', 'content': 'You are a quiz generator. Output only valid JSON arrays.'},
                {'role': 'user', 'content': prompt}
            ],
            stream=False
        )

        raw = response['message']['content'].strip()
        # Strip markdown code fences if the model added them
        if raw.startswith('```'):
            raw = raw.split('```')[1]
            if raw.startswith('json'):
                raw = raw[4:].strip()

        questions = json_lib.loads(raw)
        return jsonify({'status': 'success', 'chapter': chapter, 'questions': questions})

    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500


# ── Legacy chapter-specific endpoints (kept for backward compatibility) ────────

def create_chapter_specific_question(chapter_num):
    def chapter_specific_question():
        try:
            data = request.get_json()
            if not data or 'question' not in data:
                return jsonify({'status': 'error', 'message': 'Missing required field: question'}), 400
            chapter_name = f'Chapter{chapter_num}'
            question = data['question']
            response, time_taken = tutor.ask_question(chapter_name, question)
            if response is None:
                return jsonify({'status': 'error',
                                'message': f'Failed to generate response for {chapter_name}'}), 500
            return jsonify({'status': 'success', 'chapter': chapter_name,
                            'question': question, 'response': response, 'time_taken': time_taken})
        except Exception as e:
            return jsonify({'status': 'error', 'message': str(e)}), 500
    return chapter_specific_question


for chapter_num in range(1, 14):
    app.add_url_rule(
        f'/api/chapter{chapter_num}',
        f'chapter_specific_question_{chapter_num}',
        create_chapter_specific_question(chapter_num),
        methods=['POST']
    )

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=6000)
