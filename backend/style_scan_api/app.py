import os
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from ultralytics import YOLO
import cv2
import numpy as np
import tempfile

# --- Basic configuration ---
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)
CORS(app)

# Limit upload size to 10 MB
app.config['MAX_CONTENT_LENGTH'] = 10 * 1024 * 1024

MODEL_PATH = os.environ.get('MODEL_PATH', 'best.pt')

# Allowed extensions
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg"}


def allowed_file(filename: str) -> bool:
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def load_model(path: str):
    try:
        model = YOLO(path)
        logging.info(f"Model loaded from '{path}'")
        # optional: warmup with a small dummy array to reduce first inference overhead
        try:
            import numpy as _np
            dummy = _np.zeros((640, 640, 3), dtype=_np.uint8)
            _ = model(dummy, verbose=False)
        except Exception:
            pass
        return model
    except Exception as e:
        logging.error(f"Failed to load model: {e}", exc_info=True)
        return None


model = load_model(MODEL_PATH)


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'ok', 'model_loaded': model is not None})


@app.errorhandler(413)
def request_entity_too_large(error):
    return jsonify({'status': 'error', 'message': 'File too large (max 10 MB)'}), 413


@app.route('/detect', methods=['POST'])
def detect():
    if model is None:
        return jsonify({'status': 'error', 'message': 'Model not loaded.'}), 500

    if 'image' not in request.files:
        return jsonify({'status': 'error', 'message': 'Image file is required under form field "image".'}), 400

    file = request.files['image']
    if file.filename == '':
        return jsonify({'status': 'error', 'message': 'Empty filename.'}), 400

    if not allowed_file(file.filename):
        return jsonify({'status': 'error', 'message': 'Unsupported file type.'}), 400

    try:
        # read bytes then decode with OpenCV
        img_bytes = file.read()
        nparr = np.frombuffer(img_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            return jsonify({'status': 'error', 'message': 'Invalid image data.'}), 400

        # Inference
        results = model(img)

        detections = []
        # results[0].boxes may be empty; iterate safely
        for box in results[0].boxes:
            # box.cls and box.conf are arrays; some YOLO versions return tensors
            try:
                cls_idx = int(box.cls[0]) if hasattr(box.cls, '__len__') else int(box.cls)
            except Exception:
                cls_idx = int(box.cls)

            try:
                confidence = float(box.conf[0]) if hasattr(box.conf, '__len__') else float(box.conf)
            except Exception:
                confidence = float(box.conf)

            try:
                coords = box.xyxy[0].tolist() if hasattr(box.xyxy, '__len__') else list(box.xyxy)
            except Exception:
                coords = []

            class_name = model.names.get(cls_idx, str(cls_idx)) if getattr(model, 'names', None) is not None else str(cls_idx)

            detections.append({
                'class_id': cls_idx,
                'class_name': class_name,
                'confidence': confidence,
                'coordinates_xyxy': coords
            })

        return jsonify({'status': 'success', 'data': {'count': len(detections), 'detections': detections}}), 200

    except Exception as e:
        logging.error(f"Error during detection: {e}", exc_info=True)
        return jsonify({'status': 'error', 'message': 'Internal server error.'}), 500


if __name__ == '__main__':
    logging.info('Starting style scan API on http://0.0.0.0:5000')
    # debug=False recommended for production
    app.run(host='0.0.0.0', port=5000, debug=True)
