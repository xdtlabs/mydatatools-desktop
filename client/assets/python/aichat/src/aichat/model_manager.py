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

# --- FIX: Conditionally Import HuggingFacePipeline ---
try:
    from langchain_huggingface import HuggingFacePipeline
    print("Using langchain_huggingface.HuggingFacePipeline (Recommended).")
except ImportError:
    from langchain_community.llms import HuggingFacePipeline
    print("WARNING: Falling back to langchain_community.llms.HuggingFacePipeline. Please install 'langchain-huggingface' to eliminate all deprecation warnings.")

from transformers import AutoModelForCausalLM, AutoTokenizer, AutoProcessor, pipeline

from .config import MODEL_DTYPE, MAX_NEW_TOKENS, TEMPERATURE, DO_SAMPLE
from .utils import get_local_path, download_model_if_needed


def load_gemini_model(model_name: str = "gemini-2.5-pro") -> ChatGoogleGenerativeAI:
    """
    Initializes a connection to the Google Gemini API.

    This function creates a LangChain object for interacting with the
    Google Gemini service. It requires the GOOGLE_API_KEY environment
    variable to be set.

    Args:
        model_name (str): The name of the Gemini model to use (e.g., "gemini-2.5-pro", "gemini-2.5-flash").

    Returns:
        ChatGoogleGenerativeAI: An instance of the LangChain Google AI chat model.

    Raises:
        ValueError: If the GOOGLE_API_KEY environment variable is not set.
    """
    print(f"[LOADER] Initializing Google Gemini client with model: {model_name}")

    api_key = os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        raise ValueError("GOOGLE_API_KEY environment variable not set.")

    # Initialize the ChatGoogleGenerativeAI client
    # You can specify other parameters like temperature, top_p, etc.
    llm = ChatGoogleGenerativeAI(
        model=model_name,
        google_api_key=api_key,
        temperature=TEMPERATURE,
        # convert_system_message_to_human=True # Use if needed for older models
    )

    return llm


def load_local_model(local_path: str) -> HuggingFacePipeline:
    """
    Load a language model from disk into a LangChain HuggingFacePipeline object.
    
    This function loads a pre-trained language model from a local directory,
    creates a HuggingFace text generation pipeline, and wraps it in a
    LangChain HuggingFacePipeline for consistent interface.
    
    Args:
        local_path (str): Path to the directory containing model files
        
    Returns:
        HuggingFacePipeline: Wrapped pipeline ready for text generation
        
    Raises:
        Exception: If model loading fails due to missing files, memory issues, etc.
        
    Example:
        >>> pipeline = load_local_model("./google-gemma-3-4b-it-local/")
        >>> response = pipeline.invoke("Hello, world!")
    """
    print(f"[LOADER] Attempting to load model from: {local_path}. This may take time.")
    
    # 1. Load Tokenizer
    tokenizer = AutoTokenizer.from_pretrained(local_path)

    # 2. Load Model 
    # Using modern 'dtype' instead of deprecated 'torch_dtype'
    model = AutoModelForCausalLM.from_pretrained(
        local_path,
        dtype=getattr(torch, MODEL_DTYPE), 
        device_map="auto"
    )

    # 3. Create a HuggingFace Text Generation Pipeline
    pipe = pipeline(
        "text-generation",
        model=model,
        tokenizer=tokenizer,
        max_new_tokens=MAX_NEW_TOKENS,
        do_sample=DO_SAMPLE,
        temperature=TEMPERATURE,
        # Using modern 'dtype' in model_kwargs
        model_kwargs={"dtype": getattr(torch, MODEL_DTYPE)}, 
    )

    # 4. Wrap in LangChain HuggingFacePipeline
    return HuggingFacePipeline(pipeline=pipe)


def load_embedding_model(model_id: str = "google/gemma-3-4b-it") -> Tuple[Any, Any]:
    """
    Load a model specifically configured for embedding generation.
    
    Downloads (if needed) and loads a multimodal model that can generate
    embeddings for both text and images. Uses the same base model architecture
    but configured for embedding extraction rather than text generation.
    
    Args:
        model_id (str): HuggingFace model identifier. Defaults to "google/gemma-3-4b-it"
        
    Returns:
        Tuple[Any, Any]: A tuple of (model, processor) ready for embedding generation
        
    Raises:
        Exception: If model download or loading fails
        
    Example:
        >>> model, processor = load_embedding_model("google/gemma-3-4b-it")
        >>> embeddings = generate_text_embedding("Hello", model, processor)
    """
    local_path = get_local_path(model_id)
    
    print(f"[EMBEDDING] Attempting to load embedding model from: {local_path}")
    
    # Download model if needed
    if not download_model_if_needed(model_id, local_path):
        raise Exception(f"Failed to download embedding model {model_id}")
    
    # Load processor and model for multimodal capabilities
    processor = AutoProcessor.from_pretrained(local_path)
    model = AutoModelForCausalLM.from_pretrained(
        local_path,
        dtype=getattr(torch, MODEL_DTYPE),
        device_map="auto"
    )
    
    print(f"[EMBEDDING] Embedding model {model_id} loaded successfully.")
    return model, processor


def generate_text_embedding(text: str, model: Any, processor: Any) -> List[float]:
    """
    Generate embeddings for text input using a loaded model.
    
    Processes text through the model to extract high-dimensional vector
    representations. Uses the model's last hidden layer and applies
    average pooling across the sequence dimension.
    
    Args:
        text (str): Input text to generate embeddings for
        model (Any): Loaded language model with embedding capabilities
        processor (Any): Model processor for handling inputs
        
    Returns:
        List[float]: A list of float values representing the text embedding
        
    Example:
        >>> embedding = generate_text_embedding(
        ...     "Hello world", model, processor
        ... )
        >>> print(f"Embedding dimension: {len(embedding)}")
    """
    # Prepare text input
    inputs = processor(text=text, return_tensors="pt")
    
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