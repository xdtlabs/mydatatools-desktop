"""
Utility functions for file operations, path management, and archive handling.

This module provides helper functions for managing model files, including
path generation, archive extraction, and model downloading from Hugging Face Hub.
"""
import os
import tarfile
from typing import Optional


def get_local_path(model_id: str) -> str:
    """
    Generate a local directory path for storing a model.
    
    Converts a Hugging Face model ID into a safe local directory path
    by replacing forward slashes with hyphens and adding a suffix.
    
    Args:
        model_id (str): Hugging Face model identifier (e.g., 'google/gemma-3-4b-it')
        
    Returns:
        str: Local directory path (e.g., './google-gemma-3-4b-it-local/')
        
    Example:
        >>> get_local_path("google/gemma-3-4b-it")
        './models/google-gemma-3-4b-it-local/'
    """
    # Use a sanitized version of the model ID for the directory name
    safe_model_name = model_id.replace("/", "-")
    return f"./models/{safe_model_name}-local/"


def get_local_zip_path(model_id: str) -> str:
    """
    Generate a local archive file path for a model.
    
    Creates a standardized path for model archive files based on the
    model ID, using tar.gz format for compression.
    
    Args:
        model_id (str): Hugging Face model identifier
        
    Returns:
        str: Local archive file path (e.g., './google-gemma-3-4b-it-local.tar.gz')
        
    Example:
        >>> get_local_zip_path("google/gemma-3-4b-it")
        './models/google-gemma-3-4b-it-local.tar.gz'
    """
    # Use a sanitized version of the model ID for the directory name
    safe_model_name = model_id.replace("/", "-")
    return f"./models/{safe_model_name}-local.tar.gz"


def handle_local_archive(archive_path: str, target_dir: str) -> bool:
    """
    Extract a local archive file to the specified target directory.
    
    Supports tar archives with various compression formats (tar, tar.gz, tar.bz2, etc.).
    Creates the target directory if it doesn't exist.
    
    Args:
        archive_path (str): Path to the archive file to extract
        target_dir (str): Directory where files should be extracted
        
    Returns:
        bool: True if extraction was successful, False otherwise
        
    Example:
        >>> handle_local_archive("./model.tar.gz", "./model/")
        True
    """
    if not os.path.exists(archive_path):
        return False
        
    print(f"[LOADER] Found archive at {archive_path}. Extracting...")
    try:
        # Create the target directory
        os.makedirs(target_dir, exist_ok=True)
        
        # Extract the archive (auto-detects compression format)
        with tarfile.open(archive_path, 'r:*') as tar:
            tar.extractall(path=target_dir)
        
        print(f"[LOADER] Archive extraction complete to {target_dir}.")
        return True
        
    except Exception as extract_error:
        print(f"[ERROR] Failed to extract {archive_path}: {extract_error}")
        return False


def download_from_url(url: str, target_dir: str) -> bool:
    """
    Download an archive file from a URL and extract it to the target directory.

    Args:
        url (str): URL to download the archive from
        target_dir (str): Directory where files should be extracted

    Returns:
        bool: True if download and extraction were successful, False otherwise

    Example:
        >>> download_from_url("https://example.com/model.tar.gz", "./model/")
        True
    """
    import urllib.request
    import urllib.error
    import tempfile
    import time

    try:
        print(f"[LOADER] Downloading from {url}...")

        # Create a temporary file to store the download
        with tempfile.NamedTemporaryFile(delete=False, suffix='.tar.gz') as tmp_file:
            tmp_path = tmp_file.name

            try:
                with urllib.request.urlopen(url) as response:
                    total_size = int(response.getheader('Content-Length', 0))
                    chunk_size = 8192 * 8  # 32KB chunks
                    downloaded_size = 0
                    start_time = time.time()

                    while True:
                        chunk = response.read(chunk_size)
                        if not chunk:
                            break

                        tmp_file.write(chunk)
                        downloaded_size += len(chunk)

                        # Report progress
                        if total_size > 0:
                            percent = (downloaded_size / total_size) * 100
                            current_time = time.time()
                            if current_time - start_time > 5: # Update every 5 seconds
                                print(f"[LOADER] Download progress: {percent:.1f}%")
                                start_time = current_time

                print("[LOADER] Download complete. Extracting...")

                # Ensure all data is written to disk before extracting
                tmp_file.flush()
                os.fsync(tmp_file.fileno())

                # Extract the downloaded archive
                success = handle_local_archive(tmp_path, target_dir)

                return success

            finally:
                # Clean up the temporary file
                if os.path.exists(tmp_path):
                    os.remove(tmp_path)

    except urllib.error.HTTPError as e:
        print(f"[ERROR] HTTP error downloading from {url}: {e.code} {e.reason}")
        return False
    except urllib.error.URLError as e:
        print(f"[ERROR] URL error downloading from {url}: {e.reason}")
        return False
    except Exception as e:
        print(f"[ERROR] Failed to download from {url}: {e}")
        return False


def download_model_if_needed(model_id: str, local_path: str, custom_archive_path: Optional[str] = None) -> bool:
    """
    Ensure a model is available locally, downloading if necessary.

    This function implements a fallback strategy:
    1. Check if model directory already exists and has files
    2. Try to extract from custom archive path (if provided)
    3. Try to extract from standard archive paths (.tar.gz, .tgz, .tar)
    4. Download from GCS if MODEL_DOWNLOAD_URL environment variable is set
    5. return False if all methods fail

    Args:
        model_id (str): Hugging Face model identifier
        local_path (str): Target directory for the model files
        custom_archive_path (Optional[str]): Optional path to a specific archive file

    Returns:
        bool: True if model is available locally, False if all methods failed

    Example:
        >>> download_model_if_needed("google/gemma-3-4b-it", "./model/")
        True
    """
    # Check if model directory already exists and has files
    if os.path.exists(local_path) and os.listdir(local_path):
        print(f"[LOADER] Local model found at {local_path}. Skipping download.")
        return True

    print(f"[LOADER] Local model not found at {local_path}.")

    # First, try custom archive path if provided
    if custom_archive_path and handle_local_archive(custom_archive_path, local_path):
        print("[LOADER] Successfully extracted model from custom archive.")
        return True

    # Check for compressed tar files before downloading
    tar_path = get_local_zip_path(model_id)  # This returns .tar.gz path
    alternative_paths = [
        tar_path,  # .tar.gz from get_local_zip_path
        tar_path.replace('.tar.gz', '.tgz'),  # .tgz variant
        tar_path.replace('.tar.gz', '.tar')   # uncompressed .tar
    ]

    # Try each archive format
    for archive_path in alternative_paths:
        if handle_local_archive(archive_path, local_path):
            return True

    # Check if Flutter set a custom download URL via environment variable
    gcs_url = os.environ.get('MODEL_DOWNLOAD_URL')
    print(gcs_url)
    if gcs_url:
        print(f"[LOADER] Found MODEL_DOWNLOAD_URL: {gcs_url}")

        # Construct download URL for the model archive
        safe_model_name = model_id.replace('/', '-')
        download_url = f"{gcs_url.rstrip('/')}/download/{safe_model_name}"

        print(f"[LOADER] Attempting to download from: {download_url}")

        # Try to download and extract from GCS
        if download_from_url(download_url, local_path):
            print("[LOADER] Successfully downloaded and extracted model from GCS.")
            return True
        else:
            print("[LOADER] GCS download failed. Falling back to Hugging Face.")

    return False


def download_huggingface_model_if_needed(model_id: str, local_path: str, custom_archive_path: Optional[str] = None) -> bool:
    """
    Ensure a model is available locally, downloading if necessary.
    
    This function implements a fallback strategy:
    1. Check if model directory already exists and has files
    2. Try to extract from custom archive path (if provided)
    3. Try to extract from standard archive paths (.tar.gz, .tgz, .tar)
    4. Download from Hugging Face Hub as last resort
    
    Args:
        model_id (str): Hugging Face model identifier
        local_path (str): Target directory for the model files
        custom_archive_path (Optional[str]): Optional path to a specific archive file
        
    Returns:
        bool: True if model is available locally, False if all methods failed
        
    Example:
        >>> download_model_if_needed("google/gemma-3-4b-it", "./model/")
        True
    """
    from huggingface_hub import snapshot_download
    
    # Check if model directory already exists and has files
    if not os.path.exists(local_path) or not os.listdir(local_path):
        print(f"[LOADER] Local model not found at {local_path}.")
        
        # First, try custom archive path if provided
        if custom_archive_path and handle_local_archive(custom_archive_path, local_path):
            return True
        
        # Check for compressed tar files before downloading
        tar_path = get_local_zip_path(model_id)  # This returns .tar.gz path
        alternative_paths = [
            tar_path,  # .tar.gz from get_local_zip_path
            tar_path.replace('.tar.gz', '.tgz'),  # .tgz variant
            tar_path.replace('.tar.gz', '.tar')   # uncompressed .tar
        ]
        
        # Try each archive format
        for archive_path in alternative_paths:
            if handle_local_archive(archive_path, local_path):
                return True
        
        # No archive found or extraction failed, proceed with download
        print(f"[LOADER] No local archive found. Starting download from Hugging Face...")
        try:
            snapshot_download(
                repo_id=model_id, 
                local_dir=local_path, 
                local_dir_use_symlinks=False,
            )
            print("[LOADER] Model download complete.")
        except Exception as dl_error:
            print(f"[ERROR] Error during model download for {model_id}: {dl_error}")
            return False
    else:
        print(f"[LOADER] Local model found at {local_path}. Skipping download.")
    return True

    