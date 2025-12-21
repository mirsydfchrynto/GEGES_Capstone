FROM python:3.11-slim

# Set a working directory
WORKDIR /app

# Install system deps required by some packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy app
COPY app.py ./

# Expose port
EXPOSE 5000

# Set model path env var (you should COPY your model into the image or mount at runtime)
ENV MODEL_PATH=best.pt

# Run with gunicorn for production; keep using 1 worker by default
CMD ["gunicorn", "-b", "0.0.0.0:5000", "app:app", "--workers", "1", "--threads", "2"]
