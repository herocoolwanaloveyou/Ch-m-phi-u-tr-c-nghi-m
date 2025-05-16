from flask import Flask, request, jsonify
import os
import cv2
import pytesseract
import numpy as np
import re
import json

# Cấu hình đường dẫn Tesseract
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# File lưu đáp án
ANSWER_FILE = "answers.json"

app = Flask(__name__)

# Tải đáp án từ file
def load_answer_keys():
    try:
        with open(ANSWER_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return {int(k): v for k, v in data.items()}
    except FileNotFoundError:
        print(f"File {ANSWER_FILE} not found, returning empty dict.")
        return {}
    except json.JSONDecodeError as e:
        print(f"Invalid JSON in {ANSWER_FILE}: {e}, returning empty dict.")
        return {}
    except Exception as e:
        print(f"Error loading {ANSWER_FILE}: {e}, returning empty dict.")
        return {}

# Lưu đáp án vào file
def save_answer_keys(answer_keys):
    try:
        with open(ANSWER_FILE, 'w', encoding='utf-8') as f:
            json.dump({str(k): v for k, v in answer_keys.items()}, f, indent=4)
        print(f"Successfully saved to {ANSWER_FILE}")
    except Exception as e:
        print(f"Error saving to {ANSWER_FILE}: {e}")

# Tiền xử lý ảnh
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

# Trích xuất đáp án từ ảnh
def extract_answers(image_path):
    img = cv2.imread(image_path)
    if img is None:
        return None, None, "Không thể đọc ảnh."
    processed = preprocess_strongest(img)

    config = r'-c tessedit_char_whitelist=ABCD0123456789:-.()MD --oem 3 --psm 6'
    text = pytesseract.image_to_string(processed, config=config)
    exam_code, student_answers = parse_answers(text)
    return text, exam_code, student_answers

# Phân tích văn bản để lấy mã đề và đáp án
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

# Tính điểm
def calculate_score(student_answers, answer_key):
    score = 0
    total = len(answer_key)
    for q_no, correct_ans in answer_key.items():
        student_ans = student_answers.get(q_no)
        if student_ans == correct_ans:
            score += 1
    return score, total

# API để chấm điểm ảnh
@app.route('/api/grade', methods=['POST'])
def grade_image():
    if 'image' not in request.files:
        return jsonify({'error': 'No image file provided'}), 400
    file = request.files['image']
    if file.filename == '':
        return jsonify({'error': 'No selected file'}), 400

    # Lưu file tạm để xử lý
    upload_dir = 'uploads'
    if not os.path.exists(upload_dir):
        os.makedirs(upload_dir)
    filepath = os.path.join(upload_dir, file.filename)
    file.save(filepath)

    # Trích xuất dữ liệu từ ảnh
    raw_text, exam_code, student_answers = extract_answers(filepath)
    if exam_code is None:
        return jsonify({'error': 'Không tìm thấy mã đề trong ảnh'}), 400
    if not student_answers:
        return jsonify({'error': 'Không trích xuất được đáp án từ ảnh'}), 400

    # Tải đáp án
    answer_keys = load_answer_keys()
    if exam_code not in answer_keys:
        return jsonify({'error': f'No answer key found for exam code {exam_code}. Please add it via manage_answers API'}), 400

    # Tính điểm
    score, total = calculate_score(student_answers, answer_keys[exam_code])

    # Trả về kết quả
    result = {
        'exam_code': exam_code,
        'raw_text': raw_text,
        'student_answers': student_answers,
        'correct_answers': answer_keys[exam_code],
        'score': score,
        'total': total
    }
    return jsonify(result), 200

# API để quản lý đáp án
@app.route('/api/manage_answers', methods=['POST'])
def manage_answers():
    data = request.get_json()
    if not data:
        return jsonify({'error': 'No data provided'}), 400

    action = data.get('action')
    answer_keys = load_answer_keys()

    if action == 'add':
        code = data.get('code')
        answers = data.get('answers')
        if not code or not isinstance(answers, dict):
            return jsonify({'error': 'Invalid code or answers'}), 400
        try:
            code = int(code)
            if code in answer_keys:
                return jsonify({'error': f'Exam code {code} already exists'}), 400
            answer_keys[code] = answers
            save_answer_keys(answer_keys)
            return jsonify({'message': f'Added exam code {code}', 'answer_keys': answer_keys}), 200
        except ValueError:
            return jsonify({'error': 'Code must be an integer'}), 400

    elif action == 'edit':
        code = data.get('code')
        answers = data.get('answers')
        if not code or not isinstance(answers, dict):
            return jsonify({'error': 'Invalid code or answers'}), 400
        try:
            code = int(code)
            if code not in answer_keys:
                return jsonify({'error': f'Exam code {code} not found'}), 400
            answer_keys[code] = answers
            save_answer_keys(answer_keys)
            return jsonify({'message': f'Edited exam code {code}', 'answer_keys': answer_keys}), 200
        except ValueError:
            return jsonify({'error': 'Code must be an integer'}), 400

    elif action == 'delete':
        code = data.get('code')
        if not code:
            return jsonify({'error': 'No code provided'}), 400
        try:
            code = int(code)
            if code not in answer_keys:
                return jsonify({'error': f'Exam code {code} not found'}), 400
            del answer_keys[code]
            save_answer_keys(answer_keys)
            return jsonify({'message': f'Deleted exam code {code}', 'answer_keys': answer_keys}), 200
        except ValueError:
            return jsonify({'error': 'Code must be an integer'}), 400

    else:
        return jsonify({'error': 'Invalid action'}), 400

# API để lấy danh sách mã đề
@app.route('/api/get_answers', methods=['GET'])
def get_answers():
    answer_keys = load_answer_keys()
    return jsonify({'answer_keys': answer_keys}), 200

if __name__ == '__main__':
    if not os.path.exists('uploads'):
        os.makedirs('uploads')
    app.run(debug=True, host='0.0.0.0', port=5000)