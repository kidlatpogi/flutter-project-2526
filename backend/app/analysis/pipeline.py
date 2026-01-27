"""
Analysis Pipeline
Orchestrates the complete audio analysis workflow.
"""

import logging
import tempfile
import os
from pathlib import Path
from uuid import UUID, uuid4
from datetime import datetime

import librosa

from app.models import AnalysisResult, AudioMetrics, FluencyMetrics, PauseMetrics, ConfidenceScore
from app.analysis.transcription import transcribe_audio, TranscriptionResult
from app.analysis.acoustics import analyze_acoustics
from app.analysis.fluency import analyze_fluency
from app.analysis.pauses import analyze_pauses, calculate_speech_duration
from app.analysis.scoring import calculate_confidence_score

logger = logging.getLogger(__name__)


class AnalysisPipeline:
    """
    Complete audio analysis pipeline.
    
    Orchestrates transcription, acoustic analysis, fluency analysis,
    pause detection, and confidence scoring.
    """
    
    def __init__(self, session_id: UUID | None = None):
        """
        Initialize the analysis pipeline.
        
        Args:
            session_id: Optional pre-generated session ID.
        """
        self.session_id = session_id or uuid4()
        self.audio_path: Path | None = None
        self.duration: float = 0.0
        
        # Analysis results
        self.transcription: TranscriptionResult | None = None
        self.audio_metrics: AudioMetrics | None = None
        self.fluency_metrics: FluencyMetrics | None = None
        self.pause_metrics: PauseMetrics | None = None
        self.confidence_score: ConfidenceScore | None = None
    
    def _get_audio_duration(self, audio_path: Path) -> float:
        """Get audio duration using librosa."""
        duration = librosa.get_duration(path=str(audio_path))
        return float(duration)
    
    def _convert_to_wav(self, audio_path: Path) -> Path:
        """
        Convert audio to WAV format if needed.
        
        Some analysis tools work better with WAV files.
        """
        if audio_path.suffix.lower() == '.wav':
            return audio_path
        
        # Load and save as WAV
        y, sr = librosa.load(str(audio_path), sr=None)
        
        wav_path = audio_path.with_suffix('.wav')
        import soundfile as sf
        sf.write(str(wav_path), y, sr)
        
        return wav_path
    
    async def analyze(self, audio_path: Path) -> AnalysisResult:
        """
        Run complete analysis pipeline on audio file.
        
        Args:
            audio_path: Path to the audio file.
            
        Returns:
            Complete AnalysisResult with all metrics.
            
        Raises:
            Exception: If any analysis step fails.
        """
        logger.info(f"Starting analysis pipeline for session {self.session_id}")
        
        self.audio_path = audio_path
        
        # Ensure WAV format for Parselmouth
        wav_path = self._convert_to_wav(audio_path)
        
        try:
            # Get audio duration
            self.duration = self._get_audio_duration(wav_path)
            logger.info(f"Audio duration: {self.duration:.2f} seconds")
            
            # Step 1: Transcription
            logger.info("Step 1: Transcribing audio...")
            self.transcription = transcribe_audio(wav_path)
            
            # Step 2: Acoustic Analysis
            logger.info("Step 2: Analyzing acoustics...")
            self.audio_metrics = analyze_acoustics(wav_path)
            
            # Step 3: Pause Analysis
            logger.info("Step 3: Detecting pauses...")
            self.pause_metrics = analyze_pauses(
                wav_path,
                self.duration,
                self.transcription.segments
            )
            
            # Calculate speech duration (excluding pauses)
            speech_duration = calculate_speech_duration(self.duration, self.pause_metrics)
            
            # Step 4: Fluency Analysis
            logger.info("Step 4: Analyzing fluency...")
            self.fluency_metrics = analyze_fluency(
                self.transcription.text,
                self.duration,
                speech_duration
            )
            
            # Step 5: Confidence Scoring
            logger.info("Step 5: Calculating confidence score...")
            self.confidence_score = calculate_confidence_score(
                self.audio_metrics,
                self.fluency_metrics,
                self.pause_metrics
            )
            
            # Build result
            result = AnalysisResult(
                session_id=self.session_id,
                transcription=self.transcription.text,
                audio_duration=round(self.duration, 3),
                audio_metrics=self.audio_metrics,
                fluency_metrics=self.fluency_metrics,
                pause_metrics=self.pause_metrics,
                confidence_score=self.confidence_score,
                analyzed_at=datetime.utcnow()
            )
            
            logger.info(f"Analysis complete for session {self.session_id}")
            return result
            
        finally:
            # Clean up converted WAV if different from original
            if wav_path != audio_path and wav_path.exists():
                try:
                    os.remove(wav_path)
                except Exception as e:
                    logger.warning(f"Failed to clean up temp WAV: {e}")


async def run_analysis_pipeline(
    audio_path: Path,
    session_id: UUID | None = None
) -> AnalysisResult:
    """
    Convenience function to run the analysis pipeline.
    
    Args:
        audio_path: Path to audio file.
        session_id: Optional session ID.
        
    Returns:
        Complete analysis result.
    """
    pipeline = AnalysisPipeline(session_id)
    return await pipeline.analyze(audio_path)
