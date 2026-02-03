# Use Python 3.10 slim image for smaller size
FROM python:3.10-slim

# Install system dependencies required for audio processing
# - ffmpeg: for audio format conversion
# - libsndfile1: for soundfile library
# - build-essential: for compiling some Python packages
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .

# Install dependencies
# Note: faster-whisper uses CTranslate2 which is much lighter than PyTorch
RUN pip install --no-cache-dir -r requirements.txt

# NOTE: Model will be downloaded on first request, not during Docker build
# This prevents build timeout on HF Spaces and reduces build time significantly

# Copy the rest of the application code
COPY . .

# Expose the port (HF Spaces uses 7860)
ENV PORT=7860
EXPOSE 7860

# Set environment variables for optimization
ENV PYTHONUNBUFFERED=1
ENV OMP_NUM_THREADS=4
ENV MKL_NUM_THREADS=4

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]