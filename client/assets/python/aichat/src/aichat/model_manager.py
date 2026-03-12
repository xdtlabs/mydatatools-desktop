"""
Model loading and management functionality.

This module handles all model-related operations including loading models from disk,
managing HuggingFace pipelines, generating embeddings, and processing images.
It provides the core functionality for both chat and embedding models.
"""
import os
import torch
from typing import Any, List, Tuple
from PIL import Image
import base64
from io import BytesIO

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.llms import LlamaCpp

from transformers import AutoModelForCausalLM, AutoProcessor

from .config import MAX_NEW_TOKENS, TEMPERATURE, DO_SAMPLE
from .utils import get_local_path, download_gguf_model_if_needed


def load_gemini_model() -> ChatGoogleGenerativeAI:
    """
    Initializes a connection to the Google Gemini API.

    This function creates a LangChain object for interacting with the
    Google Gemini service. It requires the GOOGLE_API_KEY environment
    variable to be set.

    Args:
        local_path (str): This argument is no longer used but kept for
                          interface compatibility.

    Returns:
        ChatGoogleGenerativeAI: An instance of the LangChain Google AI chat model.

    Raises:
        ValueError: If the GOOGLE_API_KEY environment variable is not set.
    """
    print("[LOADER] Initializing Google Gemini client.")

    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY environment variable not set.")

    # Initialize the ChatGoogleGenerativeAI client
    # You can specify other parameters like temperature, top_p, etc.
    llm = ChatGoogleGenerativeAI(
        model="gemini-3.1-pro-preview",
        google_api_key=api_key,
        temperature=TEMPERATURE,
        # convert_system_message_to_human=True # Use if needed for older models
    )

    return llm


def load_local_model(model_name: str, filename: str, local_dir: str) -> LlamaCpp:
    """
    Load a language model from disk into a LangChain LlamaCpp object.
    
    This function ensures the required GGUF file is available locally,
    then initializes the llama-cpp-python binding wrapped in LangChain.
    
    Args:
        model_name (str): HF repo ID or custom name
        filename (str): The specific GGUF file name
        local_dir (str): Path to the directory for storing/checking model files
        
    Returns:
        LlamaCpp: Wrapped pipeline ready for text generation
        
    Raises:
        Exception: If model loading fails due to missing files
    """
    print(f"[LOADER] Attempting to load GGUF model: {model_name}/{filename}")
    
    # 1. Download or locate the GGUF file
    model_path = download_gguf_model_if_needed(model_name, filename, local_dir)
    
    # 2. Initialize LlamaCpp
    print(f"[LOADER] Initializing LlamaCpp from {model_path}...")
    llm = LlamaCpp(
        model_path=model_path,
        temperature=TEMPERATURE,
        max_tokens=MAX_NEW_TOKENS,
        n_ctx=4096,
        n_gpu_layers=-1, # Offload all layers to GPU (Metal on Mac)
        verbose=True,    # Useful for debugging init info
    )
    
    return llm


def load_embedding_model(model_id: str, filename: str, local_dir: str) -> LlamaCpp:
    """
    Load a model specifically configured for embedding generation using LlamaCpp.
    
    Downloads (if needed) and loads a GGUF model that can generate text embeddings.
    
    Args:
        model_id (str): HuggingFace model identifier.
        filename (str): The specific GGUF file name
        local_dir (str): Path to the directory for storing/checking model files
        
    Returns:
        LlamaCpp: LlamaCpp object initialized with embedding capabilities
        
    Raises:
        Exception: If model download or loading fails
    """
    print(f"[EMBEDDING] Attempting to load embedding model: {model_id}/{filename}")
    
    model_path = download_gguf_model_if_needed(model_id, filename, local_dir)
    
    print(f"[EMBEDDING] Initializing LlamaCpp for embeddings from {model_path}...")
    llm = LlamaCpp(
        model_path=model_path,
        embedding=True,  # Crucial flag for embedding generation
        n_ctx=4096,
        n_gpu_layers=-1,
        verbose=False,
    )
    
    print(f"[EMBEDDING] Embedding model {model_id} loaded successfully.")
    return llm, None  # Returning None for processor as LlamaCpp doesn't use one in the same way


def generate_text_embedding(text: str, model: Any, processor: Any) -> List[float]:
    """
    Generate embeddings for text input using a loaded model.
    
    Processes text through the LlamaCpp model to extract high-dimensional vector
    representations.
    
    Args:
        text (str): Input text to generate embeddings for
        model (Any): Loaded language model with embedding capabilities (LlamaCpp)
        processor (Any): Not used for LlamaCpp
        
    Returns:
        List[float]: A list of float values representing the text embedding
    """
    from langchain_community.embeddings import LlamaCppEmbeddings
    # If using LlamaCpp directly (from LangChain's LLM), we can use the underlying client
    if hasattr(model, 'client') and hasattr(model.client, 'embed'):
        result = model.client.embed(text)
        # Handle different return formats from llama-cpp-python versions
        if isinstance(result, list) and len(result) > 0:
            if isinstance(result[0], list):
                return result[0]
            elif hasattr(result[0], 'embedding'): # Check for Embedding output object
                return result[0].embedding
        return result
    else:
        # Fallback if the underlying method isn't available easily
        raise ValueError("Provided model does not support LlamaCpp embedding generation correctly")


def generate_image_embedding(image: Image.Image, model: Any, processor: Any) -> List[float]:
    """
    Generate embeddings for image input using a loaded multimodal model.
    
    Processes images through a multimodal model to extract high-dimensional
    vector representations. Similar to text embeddings but handles visual data.
    
    Args:
        image (PIL.Image.Image): Input image to generate embeddings for
        model (Any): Loaded multimodal model with image processing capabilities
        processor (Any): Model processor for handling image inputs
        
    Returns:
        List[float]: A list of float values representing the image embedding
        
    Example:
        >>> from PIL import Image
        >>> image = Image.open("photo.jpg")
        >>> embedding = generate_image_embedding(image, model, processor)
        >>> print(f"Image embedding dimension: {len(embedding)}")
    """
    # Prepare image input
    inputs = processor(images=image, return_tensors="pt")
    
    # Move inputs to same device as model
    device = next(model.parameters()).device
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    with torch.no_grad():
        # Get hidden states from the model
        outputs = model(**inputs, output_hidden_states=True)
        # Use the last hidden state and average pool across sequence length
        last_hidden_state = outputs.hidden_states[-1]  # [batch_size, seq_len, hidden_dim]
        # Average pooling across the sequence dimension
        embeddings = torch.mean(last_hidden_state, dim=1)  # [batch_size, hidden_dim]
        
    return embeddings.squeeze().cpu().numpy().tolist()


def decode_base64_image(base64_string: str) -> Image.Image:
    """
    Decode a base64-encoded string into a PIL Image object.
    
    Handles base64 image data, including data URLs with prefixes like
    'data:image/png;base64,'. Automatically converts images to RGB format
    for consistent processing.
    
    Args:
        base64_string (str): Base64-encoded image data, optionally with data URL prefix
        
    Returns:
        PIL.Image.Image: Decoded image in RGB format
        
    Raises:
        ValueError: If the base64 string is invalid or cannot be decoded as an image
        
    Example:
        >>> base64_data = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        >>> image = decode_base64_image(base64_data)
        >>> print(f"Image size: {image.size}")
    """
    try:
        # Remove data URL prefix if present (e.g., "data:image/png;base64,")
        if base64_string.startswith('data:image'):
            base64_string = base64_string.split(',')[1]
        
        # Decode base64 data to bytes
        image_data = base64.b64decode(base64_string)
        
        # Create PIL Image from bytes
        image = Image.open(BytesIO(image_data))
        
        # Ensure consistent RGB format for processing
        return image.convert('RGB')
        
    except Exception as e:
        raise ValueError(f"Invalid base64 image data: {e}")