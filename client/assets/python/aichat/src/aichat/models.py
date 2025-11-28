"""
Pydantic models for request/response validation.

This module defines all the data models used for API request and response
validation using Pydantic. These models ensure type safety, automatic
validation, and generate OpenAPI documentation.
"""
from typing import Optional
from pydantic import BaseModel, Field


class ChatRequest(BaseModel):
    """
    Request model for chat completion endpoints.
    
    Defines the structure for incoming chat requests, including the user's
    prompt and optional system instructions for controlling model behavior.
    
    Attributes:
        prompt (str): The user's input message or question
        system_instruction (Optional[str]): Optional system prompt to guide model behavior
        use_genui (bool): Whether to return response in GenUI JSON format
    """
    prompt: str = Field(..., description="The user's input message or question", min_length=1)
    system_instruction: Optional[str] = Field(
        None, 
        description="Optional system prompt to guide the model's behavior and response style"
    )
    use_genui: bool = Field(
        default=True,
        description="If True, wrap response in GenUI JSON format for rich UI rendering"
    )
    
    session_id: str = Field(
        ...,
        description="Unique identifier for the chat session to maintain history"
    )
    
    class Config:
        """Configuration for the ChatRequest model with example data."""
        json_schema_extra = {
            "example": {
                "prompt": "Explain what the difference between a list and a tuple is in Python.",
                "system_instruction": "You are a concise programming tutor.",
                "use_genui": True,
                "session_id": "123e4567-e89b-12d3-a456-426614174000"
            }
        }


class StartSessionRequest(BaseModel):
    """
    Request model for starting a new model session.
    
    Defines the parameters needed to load a specific model, either from
    Hugging Face Hub or from a local archive file.
    
    Attributes:
        model_name (str): Hugging Face model identifier or custom name
        local_path (Optional[str]): Path to local model directory or archive file
    """
    model_name: str = Field(
        default="google/gemma-3-4b-it",
        description="Hugging Face model identifier (e.g., 'google/gemma-3-4b-it')"
    )
    local_path: Optional[str] = Field(
        None, 
        description="Optional path to local model directory or tar archive file"
    )
    
    class Config:
        """Configuration for the StartSessionRequest model with example data."""
        json_schema_extra = {
            "examples": [
                {
                    "model_name": "google/gemma-3-4b-it"
                },
                {
                    "model_name": "kaggle-gemma-4b",
                    "local_path": "./my-kaggle-models/gemma-4b-kaggle.tar.gz"
                }
            ]
        }


class EmbeddingRequest(BaseModel):
    """
    Request model for embedding generation endpoints.
    
    Defines the structure for embedding requests, supporting either text
    or base64-encoded images (but not both simultaneously).
    
    Attributes:
        text (Optional[str]): Text content to generate embeddings for
        image_base64 (Optional[str]): Base64-encoded image data
    """
    text: Optional[str] = Field(
        None, 
        description="Text content to generate embeddings for"
    )
    image_base64: Optional[str] = Field(
        None, 
        description="Base64-encoded image data (PNG, JPEG, etc.)"
    )
    
    class Config:
        """Configuration for the EmbeddingRequest model with example data."""
        json_schema_extra = {
            "example": {
                "text": "This is a sample text to generate embeddings for."
            }
        }