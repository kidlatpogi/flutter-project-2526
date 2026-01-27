"""
Application Configuration
Handles environment variables and settings using Pydantic Settings.
"""

from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Supabase Configuration
    supabase_url: str
    supabase_key: str
    
    # Whisper Configuration
    whisper_model_size: str = "base"
    
    # Audio Processing Configuration
    max_audio_duration_seconds: int = 600  # 10 minutes max
    allowed_audio_types: list[str] = ["audio/wav", "audio/mpeg", "audio/mp3", "audio/x-wav"]
    
    # Filler words to detect
    filler_words: list[str] = ["um", "uh", "ah", "like", "you know", "er", "hmm", "so", "actually", "basically"]
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False
    )


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()
