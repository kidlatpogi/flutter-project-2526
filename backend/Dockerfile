# Use a slim Python base image to keep things small
FROM python:3.10-slim

# Install system dependencies required for audio processing (ffmpeg, libsndfile)
# We clean up the apt cache afterwards to reduce layer size
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsndfile1 \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# 1. Install CPU-only PyTorch FIRST
# This prevents pip from downloading the massive GPU version later.
# We use the extra-index-url to point to the CPU-specific wheels.
RUN pip install --no-cache-dir torch torchaudio --index-url https://download.pytorch.org/whl/cpu

# 2. Copy requirements (with torch removed)
COPY requirements.txt .

# 3. Install the rest of the dependencies
# We use --no-cache-dir to prevent storing downloaded files in the image
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY . .

# Expose the port
ENV PORT=8000
EXPOSE 8000

# Command to run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]