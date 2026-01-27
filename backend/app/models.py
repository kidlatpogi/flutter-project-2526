"""
Pydantic Models for Request/Response Validation
Defines all data structures used in the API.
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


class AudioMetrics(BaseModel):
    """Acoustic metrics extracted from audio."""
    
    pitch_mean: float = Field(..., description="Mean fundamental frequency (F0) in Hz")
    pitch_std: float = Field(..., description="Standard deviation of pitch")
    jitter_local: float = Field(..., description="Local jitter (pitch perturbation) as percentage")
    shimmer_local: float = Field(..., description="Local shimmer (amplitude perturbation) as percentage")
    harmonics_to_noise_ratio: float = Field(..., description="HNR in dB")
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "pitch_mean": 150.5,
            "pitch_std": 25.3,
            "jitter_local": 0.8,
            "shimmer_local": 3.2,
            "harmonics_to_noise_ratio": 18.5
        }
    })


class FluencyMetrics(BaseModel):
    """Fluency metrics calculated from transcription."""
    
    words_per_minute: float = Field(..., description="Speaking rate in WPM")
    filler_count: int = Field(..., description="Number of filler words detected")
    filler_words_found: list[str] = Field(default_factory=list, description="List of detected filler words")
    total_words: int = Field(..., description="Total word count")
    articulation_rate: float = Field(..., description="Words per minute excluding pauses")
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "words_per_minute": 130.5,
            "filler_count": 5,
            "filler_words_found": ["um", "uh", "like"],
            "total_words": 150,
            "articulation_rate": 145.2
        }
    })


class PauseMetrics(BaseModel):
    """Pause and silence analysis metrics."""
    
    total_pause_duration: float = Field(..., description="Total pause duration in seconds")
    pause_count: int = Field(..., description="Number of pauses detected")
    pause_ratio: float = Field(..., description="Ratio of pause time to total duration")
    average_pause_duration: float = Field(..., description="Average pause length in seconds")
    longest_pause: float = Field(..., description="Longest pause duration in seconds")
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "total_pause_duration": 12.5,
            "pause_count": 8,
            "pause_ratio": 0.15,
            "average_pause_duration": 1.56,
            "longest_pause": 3.2
        }
    })


class ConfidenceScore(BaseModel):
    """Confidence score breakdown."""
    
    overall_score: float = Field(..., ge=0, le=100, description="Overall confidence score (0-100)")
    pitch_score: float = Field(..., ge=0, le=100, description="Pitch stability score")
    fluency_score: float = Field(..., ge=0, le=100, description="Fluency score")
    voice_quality_score: float = Field(..., ge=0, le=100, description="Voice quality score (jitter/shimmer)")
    pace_score: float = Field(..., ge=0, le=100, description="Speaking pace score")
    
    model_config = ConfigDict(json_schema_extra={
        "example": {
            "overall_score": 78.5,
            "pitch_score": 82.0,
            "fluency_score": 75.0,
            "voice_quality_score": 80.0,
            "pace_score": 77.0
        }
    })


class AnalysisResult(BaseModel):
    """Complete analysis result returned by the API."""
    
    session_id: UUID = Field(..., description="Unique session identifier")
    transcription: str = Field(..., description="Transcribed text from audio")
    audio_duration: float = Field(..., description="Audio duration in seconds")
    audio_metrics: AudioMetrics
    fluency_metrics: FluencyMetrics
    pause_metrics: PauseMetrics
    confidence_score: ConfidenceScore
    analyzed_at: datetime = Field(default_factory=datetime.utcnow)
    
    model_config = ConfigDict(from_attributes=True)


class HealthResponse(BaseModel):
    """Health check response."""
    
    status: str = "healthy"
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    whisper_model_loaded: bool = False
    supabase_connected: bool = False


class ErrorResponse(BaseModel):
    """Error response model."""
    
    error: str
    detail: Optional[str] = None
    timestamp: datetime = Field(default_factory=datetime.utcnow)
