Style Scan API (YOLO) - quick start

This folder contains a small Flask API for performing style/object detection using an Ultralytics YOLO model.

Files:
- `app.py` - Flask application implementing `/detect` and `/health` endpoints.
- `requirements.txt` - Python dependencies.
- `Dockerfile` - Minimal image for running the API.

Quick local run

1. Create a virtualenv and install dependencies:

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

2. Put your model file next to `app.py` and name it `best.pt` or set `MODEL_PATH` env var:

```bash
export MODEL_PATH=/path/to/your/best.pt
python app.py
```

3. Test with curl:

```bash
curl -X POST -F "image=@/path/to/image.jpg" http://0.0.0.0:5000/detect
```

Docker (optional)

Build image (make sure you COPY or mount the model):

```bash
docker build -t style-scan-api:latest .
# Run with model mounted from host
docker run -p 5000:5000 -e MODEL_PATH=/models/best.pt -v /host/models:/models style-scan-api:latest
```

Flutter client example (Dart)

Use `http` package for multipart upload (add to `pubspec.yaml`):

```dart
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

Future<Map<String, dynamic>> uploadImage(File imageFile) async {
  final uri = Uri.parse('http://YOUR_SERVER_HOST:5000/detect');
  final request = http.MultipartRequest('POST', uri);
  request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));

  final streamed = await request.send();
  final resp = await http.Response.fromStream(streamed);
  if (resp.statusCode != 200) {
    throw Exception('Server error: \\${resp.statusCode}');
  }
  return json.decode(resp.body) as Map<String, dynamic>;
}
```

Notes & recommendations
- Secure your API (authentication, rate limits) before exposing to public.
- Consider running inference on GPU if available (set proper device in ultralytics model: e.g., `YOLO(path, device='0')`).
- For production, run behind a reverse proxy and use more workers/threads depending on CPU/GPU.
- The Docker image doesn't include the model; either `COPY` it into the image or mount at runtime.

If you want, I can:
- Add server-side logging to send detection events to Firestore or another DB.
- Add a minimal Flutter UI page and service to integrate this endpoint into your app.
- Build a small Docker Compose dev setup.
