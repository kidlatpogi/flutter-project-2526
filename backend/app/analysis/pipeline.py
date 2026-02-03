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

        # For webm/ogg, we MUST use FFmpeg - librosa doesn't handle these well
        if audio_path.suffix.lower() in {'.webm', '.ogg'}:
            logger.info(f"Converting {audio_path.suffix} to WAV...")
            
            # First, try to get input file duration using ffprobe
            ffprobe = shutil.which('ffprobe')
            if ffprobe:
                try:
                    probe_result = subprocess.run(
                        [ffprobe, '-v', 'error', '-show_entries', 'format=duration', 
                         '-of', 'default=noprint_wrappers=1:nokey=1', str(audio_path)],
                        capture_output=True, text=True, timeout=10
                    )
                    if probe_result.stdout.strip():
                        input_duration = float(probe_result.stdout.strip())
                        logger.info(f"FFprobe detected input duration: {input_duration:.2f}s")
                except Exception as e:
                    logger.warning(f"FFprobe failed: {e}")
            
            # Use FFmpeg for conversion
            ffmpeg = shutil.which('ffmpeg')
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
                logger.info(f"Using FFmpeg: {ffmpeg}")
                wav_path = audio_path.with_suffix('.wav')
                try:
                    # CRITICAL: Browser MediaRecorder creates webm files with missing/incorrect duration
                    # The webm duration metadata is often wrong or missing entirely.
                    # We need to force FFmpeg to read the ENTIRE file, not trust duration metadata.
                    #
                    # Key flags:
                    # -fflags +genpts+igndts: Generate PTS, ignore DTS errors
                    # -analyzeduration/probesize: Analyze entire file
                    # -f webm: Force input format to webm (helps with detection)
                    
                    # First, convert to raw PCM to bypass container issues
                    # then wrap in WAV container
                    cmd = [
                        ffmpeg,
                        '-y',
                        '-fflags', '+genpts+igndts+discardcorrupt',
                        '-analyzeduration', '2147483647',  # Max int32 - analyze everything
                        '-probesize', '2147483647',        # Max int32 - probe everything
                        '-f', 'webm',                      # Force webm input format
                        '-i', str(audio_path),
                        '-vn',                             # No video
                        '-ar', '16000',
                        '-ac', '1',
                        '-acodec', 'pcm_s16le',
                        '-f', 'wav',                       # Force WAV output
                        str(wav_path),
                    ]
                    logger.info(f"Running: {' '.join(cmd)}")
                    
                    result = subprocess.run(
                        cmd,
                        capture_output=True,
                        timeout=180,  # 3 minutes for large files
                    )
                    
                    # Log ffmpeg output for debugging
                    stderr_text = result.stderr.decode('utf-8', errors='ignore')
                    for line in stderr_text.split('\n'):
                        if any(x in line for x in ['Duration:', 'time=', 'size=', 'Error', 'error', 'Stream']):
                            logger.info(f"FFmpeg: {line.strip()}")
                    
                    if result.returncode != 0:
                        logger.error(f"FFmpeg failed with code {result.returncode}")
                        # Log full stderr on failure
                        logger.error(f"FFmpeg stderr: {stderr_text[:2000]}")
                        raise subprocess.CalledProcessError(result.returncode, cmd)
                    
                    # Verify output file exists and has content
                    if wav_path.exists():
                        wav_size = wav_path.stat().st_size
                        # WAV 16kHz mono 16-bit = 32000 bytes/second + 44 byte header
                        wav_duration = (wav_size - 44) / 32000
                        logger.info(f"FFmpeg SUCCESS: {wav_path.name}, size: {wav_size} bytes, duration: {wav_duration:.1f}s")
                        
                        # Check for significant duration mismatch with input size
                        # webm at ~50KB/s: 1.6MB should be ~32s
                        expected_input_duration = original_size / 50000  # rough estimate
                        if wav_duration < expected_input_duration * 0.7:
                            logger.warning(f"WARNING: Output duration ({wav_duration:.1f}s) is much shorter than expected ({expected_input_duration:.1f}s based on input size)")
                        
                        return wav_path
                    else:
                        logger.error("FFmpeg ran but output file not found")
                        
                except subprocess.TimeoutExpired:
                    logger.error("FFmpeg timed out after 180 seconds")
                except subprocess.CalledProcessError as e:
                    logger.error(f"FFmpeg failed: {e}")
                except Exception as e:
                    logger.error(f"FFmpeg error: {e}")
            else:
                logger.error("FFmpeg not found! Cannot convert webm to wav properly.")
            
            # Method 2: Try pydub (uses ffmpeg under the hood but handles it differently)
            try:
                from pydub import AudioSegment
                logger.info("Trying pydub for webm conversion...")
                audio_segment = AudioSegment.from_file(str(audio_path))
                original_duration = len(audio_segment) / 1000.0  # pydub uses milliseconds
                logger.info(f"Pydub loaded audio: duration = {original_duration:.2f}s")
                
                wav_path = audio_path.with_suffix('.wav')
                audio_segment = audio_segment.set_frame_rate(16000).set_channels(1)
                audio_segment.export(str(wav_path), format='wav')
                
                wav_size = wav_path.stat().st_size if wav_path.exists() else 0
                logger.info(f"Pydub conversion successful: {wav_path.name}, size: {wav_size} bytes")
                return wav_path
            except ImportError:
                logger.warning("pydub not installed")
            except Exception as e:
                logger.warning(f"pydub conversion failed: {e}")
        
        # Fallback: Load and save as WAV using librosa
        logger.info(f"Converting {audio_path.suffix} to WAV using librosa and soundfile")
        try:
            # For webm/ogg, librosa may need audioread backend
            logger.info(f"Loading audio with librosa: {audio_path}")
            y, sr = librosa.load(str(audio_path), sr=16000, mono=True)
            
            if y is None or len(y) == 0:
                raise RuntimeError("No audio data loaded from file")
            
            # Calculate and log the actual audio duration
            actual_duration = len(y) / sr
            logger.info(f"Librosa loaded audio: {len(y)} samples at {sr}Hz = {actual_duration:.2f} seconds")
            
            # CRITICAL: Check if librosa loaded the full audio
            # For 32 seconds at 16kHz, we expect ~512,000 samples
            expected_samples_per_second = 16000
            if actual_duration < 10:  # If less than 10 seconds, warn
                logger.warning(f"WARNING: Audio duration seems short ({actual_duration:.2f}s). Original file may not have been fully loaded.")
            
            wav_path = audio_path.with_suffix('.wav')
            import soundfile as sf
            sf.write(str(wav_path), y, sr)
            
            # Log output file size
            output_size = wav_path.stat().st_size if wav_path.exists() else 0
            logger.info(f"WAV output file: {wav_path.name}, size: {output_size} bytes, duration: {actual_duration:.2f}s")
            
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
