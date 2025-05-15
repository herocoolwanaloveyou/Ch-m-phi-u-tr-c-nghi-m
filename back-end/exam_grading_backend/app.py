from flask import Flask, request, jsonify
from flask_cors import CORS
import cv2
import pytesseract
import os
import numpy as np
import re
import json
from werkzeug.utils import secure_filename

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = 'uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'
ANSWER_FILE = "answers.json"

# Load & save đáp án
def load_answers():
    if os.path.exists(ANSWER_FILE):
        with open(ANSWER_FILE, 'r', encoding='utf-8') as f:
            return {int(k): v for k, v in json.load(f).items()}
    return {}

def preprocess_strongest(image):
    image = cv2.resize(image, None, fx=1.5, fy=1.5, interpolation=cv2.INTER_LINEAR)
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)
    filtered = cv2.bilateralFilter(gray, 9, 75, 75)
    thresh = cv2.adaptiveThreshold(filtered, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 15, 8)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    morph = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
    return morph

def extract_answers(image_path):
    img = cv2.imread(image_path)
    processed = preprocess_strongest(img)
    config = r'-c tessedit_char_whitelist=ABCD0123456789:-.()MD --oem 3 --psm 6'
    text = pytesseract.image_to_string(processed, config=config)
    return text, parse_answers(text)

def parse_answers(text):
    answers = {}
    exam_code = None
    lines = text.splitlines()
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if exam_code is None:
            match_code = re.match(r'^MD[:\-]?\s*(\d+)$', line, re.IGNORECASE)
            if match_code:
                exam_code = int(match_code.group(1))
                continue
        match = re.match(r'^(\d+)\s*[:\)\-\.]?\s*([A-D])$', line, re.IGNORECASE)
        if match:
            question = int(match.group(1))
            answer = match.group(2).upper()
            answers[question] = answer
    return exam_code, answers

def calculate_score(student_answers, answer_key):
    score = 0
    total = len(answer_key)
    for q_no, correct_ans in answer_key.items():
        student_ans = student_answers.get(q_no)
        if student_ans == correct_ans:
            score += 1
    return score, total

@app.route('/api/grade', methods=['POST'])
def grade_exam():
    if 'image' not in request.files:
        return jsonify({'error': 'No file part'}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    filename = secure_filename(file.filename)
    filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
    file.save(filepath)

    raw_text, result = extract_answers(filepath)
    exam_code, student_answers = result
    answer_keys = load_answers()

    if exam_code is None:
        return jsonify({'error': 'Exam code not found in image'}), 400
    if exam_code not in answer_keys:
        return jsonify({'error': f'No answer key found for exam code {exam_code}'}), 400

    score, total = calculate_score(student_answers, answer_keys[exam_code])

    return jsonify({
        'exam_code': exam_code,
        'score': score,
        'total': total,
        'raw_text': raw_text,
        'student_answers': student_answers
    })
@app.route('/')
def index():
    return 'Flask server is running. Use POST /api/grade to submit an exam image.'# filepath = uploads/ten_file.jpg
from flask import send_from_directory

@app.route('/uploads/<filename>')
def uploaded_file(filename):
    return send_from_directory(app.config['UPLOAD_FOLDER'], filename)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
