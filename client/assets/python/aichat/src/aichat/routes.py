"""
API route handlers for the Gemma Local Chat API.

This module contains all the FastAPI route handler functions that implement
the business logic for the API endpoints. Each function corresponds to a
specific API endpoint and handles request processing, validation, and response generation.
"""
from typing import Optional, Dict, Any
from fastapi import HTTPException, File, UploadFile
from PIL import Image
from io import BytesIO


from .models import ChatRequest, StartSessionRequest, EmbeddingRequest
from .model_manager import (
    load_local_model,
    load_embedding_model,
    generate_text_embedding,
    generate_image_embedding,
    decode_base64_image, load_gemini_model
)
from .utils import get_local_path, download_model_if_needed, download_huggingface_model_if_needed
from .state import (
    get_llm_instance, set_llm_instance,
    get_current_model_id, set_current_model_id,
    get_embedding_model, set_embedding_model,
    get_embedding_model_id, set_embedding_model_id,
    get_locks
)


async def health_check() -> Dict[str, Any]:
    """
    Health check endpoint that returns the current status of the API and loaded models.
    
    Provides information about:
    - API service status
    - Currently loaded chat model
    - Currently loaded embedding model  
    - Whether models are currently being loaded
    
    Returns:
        Dict[str, Any]: Status information including model states and loading status
        
    Example Response:
        {
            "status": "online",
            "current_chat_model": "google/gemma-3-4b-it",
            "chat_model_loaded": true,
            "current_embedding_model": "google/gemma-3-4b-it", 
            "embedding_model_loaded": true,
            "is_loading": false
        }
    """
    model_lock, embedding_lock = get_locks()
    embedding_model, _ = get_embedding_model()
    
    return {
        "status": "online",
        "current_chat_model": get_current_model_id() if get_llm_instance() else "None (Session not started)",
        "chat_model_loaded": get_llm_instance() is not None,
        "current_embedding_model": get_embedding_model_id() if embedding_model else "None",
        "embedding_model_loaded": embedding_model is not None,
        "is_loading": model_lock.locked() or embedding_lock.locked()
    }


async def start_session(request: StartSessionRequest) -> Dict[str, Any]:
    """
    Start a new model session by downloading and loading a specified model.
    
    This endpoint must be called successfully before using the chat endpoint.
    It handles model downloading from HuggingFace Hub or local archives,
    loads the model into memory, and makes it available for chat operations.
    
    The function implements several optimizations:
    - Checks if the requested model is already loaded
    - Uses async locks to prevent concurrent loading
    - Supports both HuggingFace Hub downloads and local archive files
    - Provides detailed error messages for troubleshooting
    
    Args:
        request (StartSessionRequest): Request containing model_name and optional local_path
        
    Returns:
        Dict[str, Any]: Success response with model information and status
        
    Raises:
        HTTPException: If model download or loading fails
        
    Example:
        >>> # Load from HuggingFace Hub
        >>> await start_session(StartSessionRequest(model_name="google/gemma-3-4b-it"))
        
        >>> # Load from local archive
        >>> await start_session(StartSessionRequest(
        ...     model_name="custom-model",
        ...     local_path="./models/custom-model.tar.gz"
        ... ))
    """
    model_lock, _ = get_locks()
    model_id = request.model_name
    local_path = get_local_path(model_id)

    print(f"[STARTUP] start session with model {model_id}")

    # 1. Check if the requested model is already loaded
    if get_current_model_id() == model_id:
        return {"status": "success", "message": f"Session already active with model: {model_id}", "model": model_id}

    # Use a lock to prevent multiple model loading attempts concurrently
    async with model_lock:
        # Re-check inside the lock in case another thread just finished loading it
        if get_current_model_id() == model_id:
            return {"status": "success", "message": f"Session already active with model: {model_id}", "model": model_id}
        
        # 2. Download files if necessary
        if not download_model_if_needed(model_id, local_path, request.local_path):
            # Fallback to Hugging Face download if needed
            # WIll only work with hugging face token set as env variable on users machine
            print(f"[STARTUP] fallback to hugging face download for model {model_id}")
            if download_huggingface_model_if_needed(model_id, local_path):
                print(f"[STARTUP] Default model {model_id} is ready at {local_path}")
            else:
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to download model files for {model_id}. Check logs and Hugging Face authentication."
                )
        
        # 3. Load the model
        try:
            # Clear previous model instance before loading new one
            set_llm_instance(None)
            set_current_model_id(None)

            if model_id == "gemini":
                new_llm = load_gemini_model()
            else:
                new_llm = load_local_model(local_path)
            
            set_llm_instance(new_llm)
            set_current_model_id(model_id)
            
            print(f"[LOADER] Model {model_id} loaded and set as active session.")
            
            return {
                "status": "success", 
                "message": f"Model '{model_id}' successfully loaded and session started.",
                "model": get_current_model_id(),
                "local_path": local_path
            }

        except Exception as e:
            print(f"[ERROR] Failed to load model {model_id}: {e}")
            set_llm_instance(None)
            set_current_model_id(None)
            raise HTTPException(
                status_code=500,
                detail=f"Failed to load model {model_id} into memory. Check console for details (e.g., VRAM/RAM limits). Error: {e}"
            )


async def generate_chat_response(request: ChatRequest) -> Dict[str, Any]:
    """
    Generate a chat response using the currently loaded language model.
    
    Sends a user prompt to the loaded model and returns the AI-generated response.
    The model must be loaded first using the start_session endpoint. This function
    formats the prompt according to Gemma model conventions and handles response parsing.
    
    The function automatically:
    - Formats prompts with Gemma-specific tokens (<start_of_turn>, <end_of_turn>)
    - Includes optional system instructions
    - Strips input prompt from model output
    - Handles response formatting and cleanup
    
    Args:
        request (ChatRequest): Request containing the user prompt and optional system instruction
        
    Returns:
        Dict[str, Any]: Response containing the user prompt, AI response, and model used
        
    Raises:
        HTTPException: If no model is loaded (503) or if generation fails (500)
        
    Example:
        >>> response = await generate_chat_response(ChatRequest(
        ...     prompt="Explain quantum computing in simple terms",
        ...     system_instruction="You are a helpful science teacher"
        ... ))
        >>> print(response["ai_response"])
    """
    llm_instance = get_llm_instance()
    
    if llm_instance is None:
        raise HTTPException(
            status_code=503,
            detail=f"No active model session. Please call the /start-session endpoint first, e.g., using model_name: 'google/gemma-3-4b-it'."
        )

    try:
        # Gemma 2 uses a specific instruction format (BOS/EOS tokens).
        # We manually construct the prompt to include the system instruction and user query.
        
        # A common instruction format for Gemma 2
        full_prompt = f"<start_of_turn>user\n\n"
        if request.system_instruction:
            full_prompt += f"System Instruction: {request.system_instruction}\n\n"
        
        full_prompt += f"{request.prompt}<end_of_turn>\n\n<start_of_turn>model\n"

        # The HuggingFacePipeline wrapper takes a single string input
        response_text = llm_instance.invoke(full_prompt)
        
        # The model output includes the input prompt, so we strip it out.
        if full_prompt in response_text:
            ai_response = response_text.split(full_prompt, 1)[-1].strip()
        else:
            ai_response = response_text.strip()
        
        # Strip potential remaining tags if the generation stops abruptly
        ai_response = ai_response.replace("<end_of_turn>", "").strip()

        return {
            "user_prompt": request.prompt,
            "ai_response": ai_response,
            "model_used": get_current_model_id(),
        }

    except Exception as e:
        print(f"[ERROR] An error occurred during model invocation: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate response: {e}"
        )


async def generate_embedding(request: EmbeddingRequest) -> Dict[str, Any]:
    """
    Generate high-dimensional vector embeddings for text or image input.
    
    Creates dense vector representations of text or images using the Gemma-3-4B
    multimodal model. These embeddings can be used for similarity search, 
    clustering, classification, and other machine learning tasks.
    
    The function supports:
    - Text embeddings from string input
    - Image embeddings from base64-encoded image data
    - Automatic model loading if not already loaded
    - Thread-safe concurrent request handling
    
    Args:
        request (EmbeddingRequest): Request containing either text or image_base64 data
        
    Returns:
        Dict[str, Any]: Response containing the embedding vector, input info, and metadata
        
    Raises:
        HTTPException: If both or neither text/image provided (400), or if processing fails (500)
        
    Example:
        >>> # Text embedding
        >>> response = await generate_embedding(EmbeddingRequest(
        ...     text="The quick brown fox jumps over the lazy dog"
        ... ))
        >>> embedding = response["embedding"]  # List[float] of 1024+ dimensions
        
        >>> # Image embedding  
        >>> response = await generate_embedding(EmbeddingRequest(
        ...     image_base64="iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB..."
        ... ))
    """
    _, embedding_lock = get_locks()
    
    # Validate request
    if not request.text and not request.image_base64:
        raise HTTPException(
            status_code=400,
            detail="Either 'text' or 'image_base64' must be provided."
        )
    
    if request.text and request.image_base64:
        raise HTTPException(
            status_code=400,
            detail="Please provide either 'text' or 'image_base64', not both."
        )
    
    # Load embedding model if not already loaded
    async with embedding_lock:
        embedding_model, embedding_processor = get_embedding_model()
        if embedding_model is None or embedding_processor is None:
            try:
                print("[EMBEDDING] Loading Gemma-3-4B model for embeddings...")
                model, processor = load_embedding_model("google/gemma-3-4b-it")
                set_embedding_model(model, processor)
                set_embedding_model_id("google/gemma-3-4b-it")
            except Exception as e:
                print(f"[ERROR] Failed to load embedding model: {e}")
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to load embedding model: {e}"
                )
    
    try:
        embedding_model, embedding_processor = get_embedding_model()
        
        if request.text:
            # Generate text embedding
            embedding = generate_text_embedding(request.text, embedding_model, embedding_processor)
            input_type = "text"
            input_content = request.text
        else:
            # Generate image embedding
            image = decode_base64_image(request.image_base64)
            embedding = generate_image_embedding(image, embedding_model, embedding_processor)
            input_type = "image"
            input_content = f"Image ({image.size[0]}x{image.size[1]})"
        
        return {
            "embedding": embedding,
            "input_type": input_type,
            "input_content": input_content,
            "model_used": get_embedding_model_id(),
            "embedding_dimension": len(embedding)
        }
    
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        print(f"[ERROR] Failed to generate embedding: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate embedding: {e}"
        )


async def generate_embedding_from_upload(
    image_file: UploadFile = File(...),
    text: Optional[str] = None
) -> Dict[str, Any]:
    """
    Generate embeddings from uploaded image files with optional text combination.
    
    Accepts image files via multipart form upload and generates embeddings using
    the multimodal Gemma model. Supports both image-only embeddings and combined
    text+image embeddings for multimodal applications.
    
    Supported image formats:
    - PNG, JPEG, GIF, BMP, TIFF
    - Automatic conversion to RGB format
    - File size and type validation
    
    Args:
        image_file (UploadFile): Uploaded image file from multipart form
        text (Optional[str]): Optional text to combine with image for multimodal embedding
        
    Returns:
        Dict[str, Any]: Response with embedding vector, metadata, and file information
        
    Raises:
        HTTPException: If file is not an image (400) or processing fails (500)
        
    Example:
        >>> # Image-only embedding (via form upload)
        >>> with open("photo.jpg", "rb") as f:
        ...     files = {"image_file": ("photo.jpg", f, "image/jpeg")}
        ...     response = requests.post("/embedding/upload", files=files)
        
        >>> # Combined text+image embedding
        >>> with open("photo.jpg", "rb") as f:
        ...     files = {"image_file": ("photo.jpg", f, "image/jpeg")}
        ...     data = {"text": "A beautiful sunset over the ocean"}
        ...     response = requests.post("/embedding/upload", files=files, data=data)
    """
    _, embedding_lock = get_locks()
    
    # Validate file type
    if not image_file.content_type or not image_file.content_type.startswith('image/'):
        raise HTTPException(
            status_code=400,
            detail="File must be an image (PNG, JPEG, etc.)"
        )
    
    # Load embedding model if not already loaded
    async with embedding_lock:
        embedding_model, embedding_processor = get_embedding_model()
        if embedding_model is None or embedding_processor is None:
            try:
                print("[EMBEDDING] Loading Gemma-3-4B model for embeddings...")
                model, processor = load_embedding_model("google/gemma-3-4b-it")
                set_embedding_model(model, processor)
                set_embedding_model_id("google/gemma-3-4b-it")
            except Exception as e:
                print(f"[ERROR] Failed to load embedding model: {e}")
                raise HTTPException(
                    status_code=500,
                    detail=f"Failed to load embedding model: {e}"
                )
    
    try:
        embedding_model, embedding_processor = get_embedding_model()
        
        # Read and process the uploaded image
        image_data = await image_file.read()
        image = Image.open(BytesIO(image_data)).convert('RGB')
        
        if text:
            # Generate combined text+image embedding using processor
            import torch
            inputs = embedding_processor(text=text, images=image, return_tensors="pt")
            device = next(embedding_model.parameters()).device
            inputs = {k: v.to(device) for k, v in inputs.items()}
            
            with torch.no_grad():
                outputs = embedding_model(**inputs, output_hidden_states=True)
                last_hidden_state = outputs.hidden_states[-1]
                embedding = torch.mean(last_hidden_state, dim=1)
            
            embedding = embedding.squeeze().cpu().numpy().tolist()
            input_type = "text+image"
            input_content = f"Text: '{text}' + Image ({image.size[0]}x{image.size[1]})"
        else:
            # Generate image-only embedding
            embedding = generate_image_embedding(image, embedding_model, embedding_processor)
            input_type = "image"
            input_content = f"Image ({image.size[0]}x{image.size[1]})"
        
        return {
            "embedding": embedding,
            "input_type": input_type,
            "input_content": input_content,
            "model_used": get_embedding_model_id(),
            "embedding_dimension": len(embedding),
            "filename": image_file.filename
        }
    
    except Exception as e:
        print(f"[ERROR] Failed to generate embedding from upload: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Failed to generate embedding: {e}"
        )