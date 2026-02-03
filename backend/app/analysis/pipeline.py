"""
Analysis Pipeline
Orchestrates the complete audio analysis workflow.
"""

import logging
import tempfile
import os
import shutil
import subprocess
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
        logger.info(f"Audio file: {audio_path.name}, duration detected: {duration:.2f} seconds")
        return float(duration)
    
    def _convert_to_wav(self, audio_path: Path) -> Path:
        """
        Convert audio to WAV format if needed.
        
        Some analysis tools work better with WAV files.
        """
        # Log original file info
        original_size = audio_path.stat().st_size if audio_path.exists() else 0
        logger.info(f"Input file: {audio_path.name}, size: {original_size} bytes, suffix: {audio_path.suffix}")
        
        if audio_path.suffix.lower() == '.wav':
            return audio_path

        # For webm/ogg, try ffmpeg first, then fallback to librosa
        if audio_path.suffix.lower() in {'.webm', '.ogg'}:
            ffmpeg = shutil.which('ffmpeg')
            
            # Try common installation paths if not in PATH
            if not ffmpeg:
                potential_paths = [
                    'C:\\Program Files\\ffmpeg\\bin\\ffmpeg.exe',
                    'C:\\Program Files (x86)\\ffmpeg\\bin\\ffmpeg.exe',
                    'C:\\ffmpeg\\bin\\ffmpeg.exe',
                ]
                for path in potential_paths:
                    if os.path.exists(path):
                        ffmpeg = path
                        break
            
            if ffmpeg:
                logger.info(f"Converting {audio_path.suffix} to WAV using ffmpeg: {ffmpeg}")
                wav_path = audio_path.with_suffix('.wav')
                try:
                    subprocess.run(
                        [
                            ffmpeg,
                            '-y',
                            '-i',
                            str(audio_path),
                            '-ar',
                            '16000',
                            '-ac',
                            '1',
                            str(wav_path),
                        ],
                        check=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.PIPE,
                        timeout=30,
                    )
                    logger.info(f"Successfully converted to WAV using ffmpeg: {wav_path}")
                    return wav_path
                except (subprocess.TimeoutExpired, subprocess.CalledProcessError) as e:
                    logger.warning(f"FFmpeg conversion failed, falling back to librosa: {e}")
                    # Fall through to librosa
            else:
                logger.info(f"FFmpeg not found, using librosa to convert {audio_path.suffix} to WAV")
        
        # Fallback: Load and save as WAV using librosa
        logger.info(f"Converting {audio_path.suffix} to WAV using librosa and soundfile")
        try:
            # For webm/ogg, librosa may need audioread backend
            y, sr = librosa.load(str(audio_path), sr=16000, mono=True)
            
            if y is None or len(y) == 0:
                raise RuntimeError("No audio data loaded from file")
            
            # Calculate and log the actual audio duration
            actual_duration = len(y) / sr
            logger.info(f"Librosa loaded audio: {len(y)} samples at {sr}Hz = {actual_duration:.2f} seconds")
            
            wav_path = audio_path.with_suffix('.wav')
            import soundfile as sf
            sf.write(str(wav_path), y, sr)
            
            # Log output file size
            output_size = wav_path.stat().st_size if wav_path.exists() else 0
            logger.info(f"WAV output file: {wav_path.name}, size: {output_size} bytes, expected duration: {actual_duration:.2f}s")
            
            return wav_path
            
            return wav_path
        except Exception as e:
            logger.error(f"Failed to convert audio to WAV with librosa: {e}")
            # Try pydub as last resort
            try:
                from pydub import AudioSegment
                logger.info(f"Trying pydub for {audio_path.suffix} conversion...")
                audio_segment = AudioSegment.from_file(str(audio_path))
                wav_path = audio_path.with_suffix('.wav')
                audio_segment = audio_segment.set_frame_rate(16000).set_channels(1)
                audio_segment.export(str(wav_path), format='wav')
                logger.info(f"Successfully converted to WAV using pydub: {wav_path}")
                return wav_path
            except ImportError:
                logger.warning("pydub not installed, cannot use as fallback")
            except Exception as pydub_error:
                logger.error(f"pydub conversion also failed: {pydub_error}")
            
            raise RuntimeError(f'Failed to convert {audio_path.suffix} to WAV: {e}')

    
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
            
            # Store the wav_path so it can be accessed for upload
            self.wav_path = wav_path
            
            return result
            
        except Exception:
            # Clean up converted WAV if different from original on error
            if wav_path != audio_path and wav_path.exists():
                try:
                    os.remove(wav_path)
                except Exception as e:
                    logger.warning(f"Failed to clean up temp WAV: {e}")
            raise


async def run_analysis_pipeline(
    audio_path: Path,
    session_id: UUID | None = None
) -> tuple[AnalysisResult, Path | None]:
    """
    Convenience function to run the analysis pipeline.
    
    Args:
        audio_path: Path to audio file.
        session_id: Optional session ID.
        
    Returns:
        Tuple of (analysis result, path to WAV file for playback).
        The WAV path may be different from audio_path if conversion was needed.
        Caller is responsible for cleaning up the WAV file.
    """
    pipeline = AnalysisPipeline(session_id)
    result = await pipeline.analyze(audio_path)
    return result, getattr(pipeline, 'wav_path', None)
