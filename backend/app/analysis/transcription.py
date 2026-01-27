"""
Speech-to-Text Transcription using OpenAI Whisper
Handles audio transcription with timing information.
"""

import logging
from pathlib import Path
from typing import Optional

import whisper
import numpy as np

from app.config import get_settings

logger = logging.getLogger(__name__)


class WhisperTranscriber:
    """Singleton wrapper for Whisper model."""
    
    _model: Optional[whisper.Whisper] = None
    _model_size: Optional[str] = None
    
    @classmethod
    def get_model(cls) -> whisper.Whisper:
        """Get or load Whisper model."""
        settings = get_settings()
        
        if cls._model is None or cls._model_size != settings.whisper_model_size:
            logger.info(f"Loading Whisper model: {settings.whisper_model_size}")
            cls._model = whisper.load_model(settings.whisper_model_size)
            cls._model_size = settings.whisper_model_size
            logger.info("Whisper model loaded successfully")
        
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


def transcribe_audio(audio_path: Path) -> TranscriptionResult:
    """
    Transcribe audio file using Whisper.
    
    Args:
        audio_path: Path to the audio file.
        
    Returns:
        TranscriptionResult containing text and timing information.
        
    Raises:
        Exception: If transcription fails.
    """
    model = WhisperTranscriber.get_model()
    
    logger.info(f"Transcribing audio: {audio_path}")
    
    try:
        # Transcribe with word-level timestamps
        result = model.transcribe(
            str(audio_path),
            word_timestamps=True,
            verbose=False
        )
        
        transcription = TranscriptionResult(
            text=result["text"].strip(),
            segments=result["segments"],
            language=result["language"],
            duration=result["segments"][-1]["end"] if result["segments"] else 0.0
        )
        
        logger.info(f"Transcription complete: {len(transcription.text)} characters")
        return transcription
        
    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        raise


def get_speech_segments(segments: list[dict]) -> list[tuple[float, float]]:
    """
    Extract speech segments (non-silent regions) from transcription.
    
    Args:
        segments: Whisper transcription segments.
        
    Returns:
        List of (start, end) tuples for speech regions.
    """
    return [(seg["start"], seg["end"]) for seg in segments if seg.get("text", "").strip()]
