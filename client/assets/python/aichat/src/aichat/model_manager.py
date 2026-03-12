"""
Model loading and management functionality.

This module handles loading and managing GGUF models via LlamaCpp and
Google Gemini API models. It provides the core functionality for both
chat and embedding models.
"""
import os
from typing import Any, List

from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_community.llms import LlamaCpp

from .config import MAX_NEW_TOKENS, TEMPERATURE, DO_SAMPLE


def load_gemini_model() -> ChatGoogleGenerativeAI:
    """
    Initializes a connection to the Google Gemini API.

    This function creates a LangChain object for interacting with the
    Google Gemini service. It requires the GOOGLE_API_KEY environment
    variable to be set.

    Returns:
        ChatGoogleGenerativeAI: An instance of the LangChain Google AI chat model.

    Raises:
        ValueError: If the GOOGLE_API_KEY environment variable is not set.
        
    Example:
        >>> gemini_llm = load_gemini_model()
        >>> response = gemini_llm.invoke("Hello, Gemini!")
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


def load_local_model(model_name: str, model_path: str) -> LlamaCpp:
    """
    Load a language model from disk into a LangChain LlamaCpp object.
    
    Args:
        model_name (str): HF repo ID or display name (used for logging only)
        model_path (str): Full absolute path to the .gguf file
        
    Returns:
        LlamaCpp: Wrapped pipeline ready for text generation
        
    Raises:
        Exception: If model loading fails.

    Example:
        >>> llm = load_local_model("bartowski/gemma", "/path/to/gemma-3-4b.gguf")
        >>> response = llm.invoke("Hi!")
    """
    print(f"[LOADER] Attempting to load GGUF model: {model_name} from {model_path}")
    
    # Initialize LlamaCpp directly from the resolved path
    print(f"[LOADER] Initializing LlamaCpp from {model_path}...")
    llm = LlamaCpp(
        model_path=model_path,
        temperature=TEMPERATURE,
        max_tokens=MAX_NEW_TOKENS,
        n_ctx=4096,
        n_gpu_layers=-1, # Offload all layers to GPU (Metal on Mac)
        verbose=False,   # Disabled to clean up flutter logs
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
        tuple[LlamaCpp, None]: LlamaCpp object initialized with embedding capabilities and a None placeholder for processor.
        
    Raises:
        Exception: If model download or loading fails.

    Example:
        >>> embed_model, _ = load_embedding_model("bartowski/gemma", "gemma-embedding.gguf", "./models")
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
        List[float]: A list of float values representing the text embedding.
        
    Raises:
        ValueError: If the provided model instance lacks embedding capabilities.

    Example:
        >>> embed_model, processor = load_embedding_model("repo", "filename", "./models")
        >>> vector = generate_text_embedding("Some text", embed_model, processor)
        >>> print(len(vector))
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

