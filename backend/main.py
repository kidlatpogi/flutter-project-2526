"""
Bigkas Backend API
FastAPI application for public speaking assessment.

This API receives audio files, analyzes them using signal processing
and machine learning, and stores the results in Supabase.
"""

import logging
import os
import tempfile
from contextlib import asynccontextmanager
from datetime import datetime
from pathlib import Path
from typing import Annotated
from uuid import UUID

from fastapi import FastAPI, File, UploadFile, HTTPException, status, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import get_settings
from app.models import (
    AnalysisResult,
    HealthResponse,
    ErrorResponse,
)
from app.database import (
    insert_analysis_result,
    get_analysis_by_session,
    check_connection,
)
from app.analysis.pipeline import run_analysis_pipeline
from app.analysis.transcription import WhisperTranscriber

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler.
    Pre-loads Whisper model on startup.
    """
    logger.info("Starting Bigkas Backend...")
    
    # Pre-load Whisper model
    try:
        logger.info("Pre-loading Whisper model...")
        WhisperTranscriber.get_model()
        logger.info("Whisper model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load Whisper model: {e}")
    
    # Check Supabase connection
    try:
        connected = await check_connection()
        if connected:
            logger.info("Supabase connection verified")
        else:
            logger.warning("Supabase connection could not be verified")
    except Exception as e:
        logger.error(f"Supabase connection error: {e}")
    
    yield
    
    logger.info("Shutting down Bigkas Backend...")


# Initialize FastAPI app
app = FastAPI(
    title="Bigkas API",
    description="Public Speaking Assessment API - Analyzes voice recordings for speaking confidence metrics",
    version="1.0.0",
    lifespan=lifespan,
    responses={
        500: {"model": ErrorResponse, "description": "Internal Server Error"}
    }
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["Root"])
async def root():
    """Root endpoint with API information."""
    return {
        "name": "Bigkas API",
        "version": "1.0.0",
        "description": "Public Speaking Assessment Tool",
        "docs_url": "/docs",
        "health_check": "/health"
    }


@app.get("/health", response_model=HealthResponse, tags=["Health"])
async def health_check():
    """
    Health check endpoint.
    
    Returns the status of the API and its dependencies.
    """
    supabase_connected = await check_connection()
    
    return HealthResponse(
        status="healthy",
        timestamp=datetime.utcnow(),
        whisper_model_loaded=WhisperTranscriber.is_loaded(),
        supabase_connected=supabase_connected
    )


@app.post(
    "/analyze-audio",
    response_model=AnalysisResult,
    status_code=status.HTTP_200_OK,
    tags=["Analysis"],
    responses={
        400: {"model": ErrorResponse, "description": "Invalid audio file"},
        413: {"model": ErrorResponse, "description": "File too large"},
        422: {"model": ErrorResponse, "description": "Unsupported audio format"},
        500: {"model": ErrorResponse, "description": "Analysis failed"}
    }
)
async def analyze_audio(
    audio: Annotated[UploadFile, File(description="Audio file (WAV or MP3)")],
    save_to_db: Annotated[bool, Query(description="Save results to database")] = True
):
    """
    Analyze an audio recording for public speaking confidence metrics.
    
    This endpoint accepts an audio file and performs comprehensive analysis including:
    
    - **Transcription**: Converts speech to text using Whisper
    - **Acoustic Analysis**: Extracts pitch, jitter, shimmer, and HNR
    - **Fluency Analysis**: Calculates WPM and detects filler words
    - **Pause Detection**: Identifies and measures pauses in speech
    - **Confidence Scoring**: Generates an overall speaking confidence score
    
    **Supported Formats**: WAV, MP3
    
    **Maximum Duration**: 10 minutes
    
    Returns a complete analysis with all metrics and a confidence score (0-100).
    """
    settings = get_settings()
    
    # Validate content type
    if audio.content_type not in settings.allowed_audio_types:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Unsupported audio format: {audio.content_type}. Allowed: {settings.allowed_audio_types}"
        )
    
    # Determine file extension
    if audio.content_type in ["audio/mpeg", "audio/mp3"]:
        suffix = ".mp3"
    else:
        suffix = ".wav"
    
    temp_path: Path | None = None
    
    try:
        # Save uploaded file temporarily
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            content = await audio.read()
            temp_file.write(content)
            temp_path = Path(temp_file.name)
        
        logger.info(f"Received audio file: {audio.filename}, size: {len(content)} bytes")
        
        # Run analysis pipeline
        result = await run_analysis_pipeline(temp_path)
        
        # Validate duration
        if result.audio_duration > settings.max_audio_duration_seconds:
            raise HTTPException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                detail=f"Audio duration ({result.audio_duration:.1f}s) exceeds maximum allowed ({settings.max_audio_duration_seconds}s)"
            )
        
        # Save to database if requested
        if save_to_db:
            try:
                await insert_analysis_result(result)
                logger.info(f"Analysis result saved to database: {result.session_id}")
            except Exception as e:
                logger.error(f"Failed to save to database: {e}")
                # Don't fail the request, just log the error
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Analysis failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Analysis failed: {str(e)}"
        )
    finally:
        # Clean up temporary file
        if temp_path and temp_path.exists():
            try:
                os.remove(temp_path)
            except Exception as e:
                logger.warning(f"Failed to clean up temp file: {e}")


@app.get(
    "/analysis/{session_id}",
    response_model=dict,
    tags=["Analysis"],
    responses={
        404: {"model": ErrorResponse, "description": "Session not found"}
    }
)
async def get_analysis(session_id: UUID):
    """
    Retrieve a previous analysis result by session ID.
    
    Args:
        session_id: The UUID of the analysis session to retrieve.
        
    Returns:
        The stored analysis record.
    """
    try:
        result = await get_analysis_by_session(session_id)
        
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Analysis session {session_id} not found"
            )
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to retrieve analysis: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to retrieve analysis: {str(e)}"
        )


@app.exception_handler(Exception)
async def global_exception_handler(request, exc):
    """Global exception handler for unhandled errors."""
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "Internal Server Error",
            "detail": str(exc),
            "timestamp": datetime.utcnow().isoformat()
        }
    )


if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
