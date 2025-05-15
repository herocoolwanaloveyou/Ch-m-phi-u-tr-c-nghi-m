import os
import json
import re
import logging
from uuid import uuid4
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS
from werkzeug.utils import secure_filename
import cv2
import pytesseract
import numpy as np
from dotenv import load_dotenv

# Cấu hình logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('app.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Khởi tạo Flask app
app = Flask(__name__)
CORS(app, resources={r"/api/*": {"origins": "*"}})

# Load biến môi trường
load_dotenv()
UPLOAD_FOLDER = os.getenv('UPLOAD_FOLDER', 'uploads')
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg'}
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB
TESSERACT_CMD = os.getenv('TESSERACT_CMD', r'C:\Program Files\Tesseract-OCR\tesseract.exe')
ANSWER_FILE = os.getenv('ANSWER_FILE', 'answers.json')

# Cấu hình Flask
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER
app.config['MAX_CONTENT_LENGTH'] = MAX_FILE_SIZE
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# Đặt đường dẫn Tesseract
pytesseract.pytesseract.tesseract_cmd = TESSERACT_CMD

def allowed_file(filename):
    """Kiểm tra phần mở rộng file có hợp lệ không."""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def load_answers():
    """Tải đáp án từ file JSON."""
    try:
        if os.path.exists(ANSWER_FILE):
            with open(ANSWER_FILE, 'r', encoding='utf-8') as f:
                return {int(k): v for k, v in json.load(f).items()}
        return {}
    except json.JSONDecodeError as e:
        logger.error(f"Error reading answers file: {e}")
        return {}
    except Exception as e:
        logger.error(f"Unexpected error loading answers: {e}")
        raise

def preprocess_image(image):
    """Tiền xử lý hình ảnh để cải thiện OCR."""
    try:
        # Resize và chuyển sang grayscale
        image = cv2.resize(image, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_LINEAR)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        
        # Tăng độ tương phản
        clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
        gray = clahe.apply(gray)
        
        # Lọc nhiễu
        filtered = cv2.bilateralFilter(gray, 9, 75, 75)
        
        # Nhị phân hóa
        thresh = cv2.adaptiveThreshold(
            filtered, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 15, 8
        )
        
        # Morphological operations
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
        morph = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        return morph
    except Exception as e:
        logger.error(f"Error preprocessing image: {e}")
        raise

def extract_answers(image_path):
    """Trích xuất mã đề và đáp án từ hình ảnh."""
    try:
        img = cv2.imread(image_path)
        if img is None:
            raise ValueError("Cannot read image")
        
        processed = preprocess_image(img)
        config = r'-c tessedit_char_whitelist=ABCD0123456789:-.()MD --oem 3 --psm 6'
        text = pytesseract.image_to_string(processed, config=config)
        exam_code, answers = parse_answers(text)
        
        return text, (exam_code, answers)
    except Exception as e:
        logger.error(f"Error extracting answers: {e}")
        raise

def parse_answers(text):
    """Phân tích văn bản OCR để lấy mã đề và đáp án."""
    answers = {}
    exam_code = None
    lines = text.splitlines()
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
            
        # Tìm mã đề
        if exam_code is None:
            match_code = re.match(r'^MD[:\-]?\s*(\d+)$', line, re.IGNORECASE)
            if match_code:
                exam_code = int(match_code.group(1))
                continue
        
        # Tìm đáp án
        match = re.match(r'^(\d+)\s*[:\)\-\.]?\s*([A-D])$', line, re.IGNORECASE)
        if match:
            question = int(match.group(1))
            answer = match.group(2).upper()
            answers[question] = answer
    
    return exam_code, answers

def calculate_score(student_answers, answer_key):
    """Tính điểm dựa trên đáp án học sinh và đáp án đúng."""
    score = 0
    total = len(answer_key)
    
    for q_no, correct_ans in answer_key.items():
        student_ans = student_answers.get(q_no)
        if student_ans == correct_ans:
            score += 1
            
    return score, total

@app.route('/api/grade', methods=['POST'])
def grade_exam():
    """Chấm điểm bài thi từ hình ảnh phiếu trả lời."""
    try:
        # Kiểm tra file
        if 'image' not in request.files:
            return jsonify({'error': 'No file part in request'}), 400
            
        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': 'No file selected'}), 400
            
        if not allowed_file(file.filename):
            return jsonify({'error': 'Invalid file type. Only PNG, JPG, JPEG allowed'}), 400
        
        # Lưu file
        filename = f"{uuid4().hex}_{secure_filename(file.filename)}"
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(filepath)
        logger.info(f"File saved: {filepath}")
        
        # Trích xuất và chấm điểm
        raw_text, (exam_code, student_answers) = extract_answers(filepath)
        answer_keys = load_answers()
        
        if exam_code is None:
            return jsonify({'error': 'Exam code not found in image'}), 400
        if exam_code not in answer_keys:
            return jsonify({'error': f'No answer key found for exam code {exam_code}'}), 400
            
        score, total = calculate_score(student_answers, answer_keys[exam_code])
        
        # Trả về kết quả
        response = {
            'exam_code': exam_code,
            'score': score,
            'total': total,
            'raw_text': raw_text,
            'student_answers': student_answers,
            'image_url': f"/uploads/{filename}"
        }
        
        logger.info(f"Graded exam {exam_code}: Score {score}/{total}")
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in grade_exam: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    """Phục vụ file hình ảnh đã upload."""
    try:
        return send_from_directory(app.config['UPLOAD_FOLDER'], filename)
    except Exception as e:
        logger.error(f"Error serving file {filename}: {e}")
        return jsonify({'error': 'File not found'}), 404

@app.route('/')
def index():
    """Trang chính của API."""
    return jsonify({
        'message': 'Flask server is running. Use POST /api/grade to submit an exam image.',
        'version': '1.0.0'
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)