from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from PyPDF2 import PdfReader
import ollama
import time
from typing import Dict, List, Tuple, Optional

app = Flask(__name__)
CORS(app)  # Enable CORS for Flutter integration

class ScienceTutorAPI:
    def __init__(self):
        self.science_dir = "C:\\Users\\sahil\\Desktop\\science_tutor_api\\science_directory"
        self.chapters: Dict[str, str] = {}
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
        """Load content from all PDFs in the science directory."""
        try:
            if not os.path.exists(self.science_dir):
                os.makedirs(self.science_dir)
                app.logger.info(f"Created directory: {self.science_dir}")
                return

            pdf_files = [f for f in os.listdir(self.science_dir) if f.endswith('.pdf')]
            
            if not pdf_files:
                app.logger.warning(f"No PDF files found in {self.science_dir}")
                return
                
            for chapter_file in pdf_files:
                chapter_path = os.path.join(self.science_dir, chapter_file)
                chapter_content = self._read_pdf(chapter_path)
                chapter_name = chapter_file.replace('.pdf', '')
                self.chapters[chapter_name] = chapter_content
                app.logger.info(f"Loaded chapter: {chapter_name}")
                
        except Exception as e:
            app.logger.error(f"Error loading chapters: {str(e)}")
    
    def _read_pdf(self, pdf_path: str) -> str:
        """Read content from a PDF file."""
        try:
            reader = PdfReader(pdf_path)
            text = ""
            for page in reader.pages:
                text += page.extract_text() + "\n"
            return text
        except Exception as e:
            app.logger.error(f"Error reading PDF {pdf_path}: {str(e)}")
            return ""
    
    def ask_question(self, chapter: str, question: str) -> Tuple[Optional[str], float]:
        """Process a student's question and generate a response."""
        try:
            content = self.chapters.get(chapter)
            if not content:
                return None, 0
            
            messages = [
                {
                    'role': 'system',
                    'content': self.tutor_prompt
                },
                {
                    'role': 'user',
                    'content': f"Using this chapter content: {content}\n\nStudent question: {question}"
                }
            ]
            
            start_time = time.time()
            response = ollama.chat(
                model='llama3.2',
                messages=messages,
                stream=False
            )
            time_taken = time.time() - start_time
            
            if response and 'message' in response and 'content' in response['message']:
                return response['message']['content'].strip(), time_taken
            return None, time_taken
                
        except Exception as e:
            app.logger.error(f"Error in ask_question: {str(e)}")
            return None, 0
    
    def list_chapters(self) -> List[str]:
        """Return list of available chapters."""
        return list(self.chapters.keys())

# Initialize the tutor
tutor = ScienceTutorAPI()

@app.route('/api/chapters', methods=['GET'])
def get_chapters():
    """Get list of all available chapters."""
    try:
        chapters = tutor.list_chapters()
        return jsonify({
            'status': 'success',
            'chapters': chapters,
            'count': len(chapters)
        })
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/chapters/<chapter_name>', methods=['GET'])
def get_chapter_info(chapter_name):
    """Get information about a specific chapter."""
    try:
        if chapter_name in tutor.chapters:
            return jsonify({
                'status': 'success',
                'chapter': chapter_name,
                'content_length': len(tutor.chapters[chapter_name])
            })
        return jsonify({
            'status': 'error',
            'message': 'Chapter not found'
        }), 404
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

@app.route('/api/ask', methods=['POST'])
def ask_question():
    """Ask a question about a specific chapter."""
    try:
        data = request.get_json()
        if not data or 'chapter' not in data or 'question' not in data:
            return jsonify({
                'status': 'error',
                'message': 'Missing required fields: chapter and question'
            }), 400
        
        chapter = data['chapter']
        question = data['question']
        
        response, time_taken = tutor.ask_question(chapter, question)
        
        if response is None:
            return jsonify({
                'status': 'error',
                'message': 'Failed to generate response'
            }), 500
            
        return jsonify({
            'status': 'success',
            'chapter': chapter,
            'question': question,
            'response': response,
            'time_taken': time_taken
        })
        
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

# Helper function to create unique view functions for each chapter
def create_chapter_specific_question(chapter_num):
    def chapter_specific_question():
        """Handle questions for a specific chapter."""
        try:
            data = request.get_json()
            if not data or 'question' not in data:
                return jsonify({
                    'status': 'error',
                    'message': 'Missing required field: question'
                }), 400

            chapter_name = f'Chapter{chapter_num}'
            question = data['question']

            response, time_taken = tutor.ask_question(chapter_name, question)

            if response is None:
                return jsonify({
                    'status': 'error',
                    'message': f'Failed to generate response for {chapter_name}'
                }), 500

            return jsonify({
                'status': 'success',
                'chapter': chapter_name,
                'question': question,
                'response': response,
                'time_taken': time_taken
            })

        except Exception as e:
            return jsonify({
                'status': 'error',
                'message': str(e)
            }), 500

    return chapter_specific_question

# Dynamic chapter endpoints
for chapter_num in range(1, 14):
    # Create a unique route for each chapter using the helper function
    app.add_url_rule(
        f'/api/chapter{chapter_num}', 
        f'chapter_specific_question_{chapter_num}',  # Unique endpoint name
        create_chapter_specific_question(chapter_num),
        methods=['POST']
    )

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)
