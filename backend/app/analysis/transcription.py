"""
Speech-to-Text Transcription using Faster-Whisper
Optimized for CPU with async support and better memory efficiency.

faster-whisper is 4x faster than openai-whisper and uses less memory
by utilizing CTranslate2 instead of PyTorch.
"""

import asyncio
import logging
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Optional

import numpy as np
from faster_whisper import WhisperModel

from app.config import get_settings

logger = logging.getLogger(__name__)

# Thread pool for CPU-bound transcription tasks
_executor = ThreadPoolExecutor(max_workers=2)


class WhisperTranscriber:
    """Singleton wrapper for Faster-Whisper model."""
    
    _model: Optional[WhisperModel] = None
    _model_size: Optional[str] = None
    
    @classmethod
    def get_model(cls) -> WhisperModel:
        """Get or load Faster-Whisper model."""
        settings = get_settings()
        model_size = settings.whisper_model_size
        
        if cls._model is None or cls._model_size != model_size:
            logger.info(f"Loading Faster-Whisper model: {model_size}")
            
            # Faster-whisper model configuration:
            # - device="cpu": Use CPU (no GPU required)
            # - compute_type="int8": Quantized for faster CPU inference
            # - cpu_threads=4: Parallel processing
            cls._model = WhisperModel(
                model_size,
                device="cpu",
                compute_type="int8",  # int8 quantization for speed
                cpu_threads=4,
                num_workers=2,
            )
            cls._model_size = model_size
            logger.info("Faster-Whisper model loaded successfully")
        
        return cls._model
    
    @classmethod
    def is_loaded(cls) -> bool:
        """Check if model is loaded."""
        return cls._model is not None


class TranscriptionResult:
    """Container for transcription results with timing."""
    
    def __init__(
        self,
        text: str,
        segments: list[dict],
        language: str,
        duration: float
    ):
        self.text = text
        self.segments = segments
        self.language = language
        self.duration = duration
    
    @property
    def word_timestamps(self) -> list[dict]:
        """Extract word-level timestamps from segments."""
        words = []
        for segment in self.segments:
            if "words" in segment:
                words.extend(segment["words"])
        return words


def _transcribe_sync(audio_path: Path) -> TranscriptionResult:
    """
    Synchronous transcription (runs in thread pool).
    
    Args:
        audio_path: Path to the audio file (WAV format, 16kHz).
        
    Returns:
        TranscriptionResult containing text and timing information.
    """
    import librosa
    
    model = WhisperTranscriber.get_model()
    
    logger.info(f"Transcribing audio: {audio_path}")
    
    # Load audio using librosa (16kHz mono for Whisper)
    audio, sr = librosa.load(str(audio_path), sr=16000, mono=True)
    audio = audio.astype(np.float32)
    
    logger.info(f"Audio loaded: {len(audio)} samples at {sr}Hz, duration: {len(audio)/sr:.2f}s")
    
    # Transcribe with faster-whisper
    # Returns a generator of segments
    segments_gen, info = model.transcribe(
        audio,
        language="en",
        task="transcribe",
        beam_size=5,
        best_of=5,
        patience=1.0,
        temperature=0.0,
        condition_on_previous_text=True,
        initial_prompt="This is a speech practice session with clear pronunciation.",
        vad_filter=True,  # Voice Activity Detection for better accuracy
        vad_parameters=dict(
            min_silence_duration_ms=500,
            speech_pad_ms=200,
        ),
        word_timestamps=True,
    )
    
    # Convert generator to list and build result
    segments_list = []
    full_text_parts = []
    
    for segment in segments_gen:
        seg_dict = {
            "start": segment.start,
            "end": segment.end,
            "text": segment.text.strip(),
        }
        
        # Add word-level timestamps if available
        if segment.words:
            seg_dict["words"] = [
                {
                    "word": word.word,
                    "start": word.start,
                    "end": word.end,
                    "probability": word.probability,
                }
                for word in segment.words
            ]
        
        segments_list.append(seg_dict)
        full_text_parts.append(segment.text.strip())
    
    full_text = " ".join(full_text_parts)
    duration = segments_list[-1]["end"] if segments_list else 0.0
    
    result = TranscriptionResult(
        text=full_text,
        segments=segments_list,
        language=info.language,
        duration=duration
    )
    
    logger.info(f"Transcription complete: {len(result.text)} characters, {len(segments_list)} segments")
    return result


async def transcribe_audio_async(audio_path: Path) -> TranscriptionResult:
    """
    Async transcription - runs CPU-bound work in thread pool.
    
    Args:
        audio_path: Path to the audio file.
        
    Returns:
        TranscriptionResult containing text and timing information.
        
    Raises:
        Exception: If transcription fails.
    """
    loop = asyncio.get_event_loop()
    
    try:
        result = await loop.run_in_executor(
            _executor,
            _transcribe_sync,
            audio_path
        )
        return result
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        raise


def transcribe_audio(audio_path: Path) -> TranscriptionResult:
    """
    Synchronous wrapper for backward compatibility.
    
    For new code, prefer transcribe_audio_async().
    """
    return _transcribe_sync(audio_path)


def get_speech_segments(segments: list[dict]) -> list[tuple[float, float]]:
    """
    Extract speech segments (non-silent regions) from transcription.
    
    Args:
        segments: Whisper transcription segments.
        
    Returns:
        List of (start, end) tuples for speech regions.
    """
    return [(seg["start"], seg["end"]) for seg in segments if seg.get("text", "").strip()]
