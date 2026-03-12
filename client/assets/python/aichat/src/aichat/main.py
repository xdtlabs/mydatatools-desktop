"""
Main FastAPI application for Gemma Local Chat API.

This is the entry point for the Gemma Local Chat API server. It sets up the FastAPI
application, configures startup/shutdown events, registers route handlers, and can
be run directly to start the server.

The application provides:
- Chat completions with dynamically loaded Gemma models
- Embedding generation for text and images  
- Model management with local caching and archive support
- Health monitoring and status endpoints

Usage:
    python main.py                          # Run with default settings
    uvicorn main:app --reload --port 8000   # Run with uvicorn (recommended)
"""
import os
from fastapi import FastAPI
from typing import Optional

from .config import DEFAULT_LOCAL_MODEL, API_TITLE, API_DESCRIPTION
from .models import ChatRequest, StartSessionRequest, EmbeddingRequest
from . import routes


# Create FastAPI app with configuration
app = FastAPI(
    title=API_TITLE,
    description=API_DESCRIPTION,
    version="1.0.0",
    docs_url="/docs",  # Swagger UI at /docs
    redoc_url="/redoc"  # ReDoc UI at /redoc
)

# Register API route handlers
app.get("/", summary="Health Check")(routes.health_check)
app.post("/start-session", summary="Dynamically load a Hugging Face model for chat")(routes.start_session)
app.post("/chat", summary="Generate a chat response using the currently loaded model")(routes.generate_chat_response)
app.post("/embedding", summary="Generate embeddings for text or image using Gemma-3-4B")(routes.generate_embedding)


def main() -> None:
    """
    Main entry point for running the application.
    
    Starts the uvicorn server with default configuration suitable for
    development. For production deployment, use uvicorn directly with
    appropriate settings for your environment.
    
    Example:
        python main.py  # Production server
        
    For production:
        uvicorn main:app --host 0.0.0.0 --port 8000 --workers 4
    """

    # make a local directory for models
    os.makedirs("models", exist_ok=True)
    
    # Run the server
    import uvicorn
    uvicorn.run(
        app, 
        host="0.0.0.0", 
        port=0,
        log_level="info",
        reload=False  # Set to True for development
    )


if __name__ == "__main__":
    import multiprocessing
    
    # Set the multiprocessing start method to "spawn" to prevent fork bombs on macOS
    # when loading large models with Transformers
    try:
        multiprocessing.set_start_method('spawn')
    except RuntimeError:
        pass # The start method has already been set
        
    multiprocessing.freeze_support()
    main()
