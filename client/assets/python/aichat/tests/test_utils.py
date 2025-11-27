"""
Unit tests for the utils module.

This module tests all utility functions including path generation,
archive handling, and model downloading logic with proper mocking
of file system operations and external dependencies.
"""
import os
import pytest
from unittest.mock import Mock, patch, mock_open, call
import tarfile

from utils import get_local_path, get_local_zip_path, handle_local_archive, download_model_if_needed


class TestGetLocalPath:
    """Test suite for the get_local_path function."""
    
    def test_get_local_path_basic(self):
        """Test basic path generation with simple model ID."""
        result = get_local_path("facebook/opt-1.3b")
        expected = "./facebook-opt-1.3b-local/"
        assert result == expected
    
    def test_get_local_path_google_model(self):
        """Test path generation with Google model ID."""
        result = get_local_path("google/gemma-2-9b-it")
        expected = "./google-gemma-2-9b-it-local/"
        assert result == expected
    
    def test_get_local_path_complex_name(self):
        """Test path generation with complex model name."""
        result = get_local_path("microsoft/DialoGPT-medium")
        expected = "./microsoft-DialoGPT-medium-local/"
        assert result == expected
    
    def test_get_local_path_multiple_slashes(self):
        """Test path generation handles multiple forward slashes."""
        result = get_local_path("org/sub/model-name")
        expected = "./org-sub-model-name-local/"
        assert result == expected
    
    def test_get_local_path_no_slash(self):
        """Test path generation with model ID without slash."""
        result = get_local_path("simple-model")
        expected = "./simple-model-local/"
        assert result == expected
    
    def test_get_local_path_empty_string(self):
        """Test path generation with empty string."""
        result = get_local_path("")
        expected = "./-local/"
        assert result == expected


class TestGetLocalZipPath:
    """Test suite for the get_local_zip_path function."""
    
    def test_get_local_zip_path_basic(self):
        """Test basic zip path generation."""
        result = get_local_zip_path("facebook/opt-1.3b")
        expected = "./facebook-opt-1.3b-local.tar.gz"
        assert result == expected
    
    def test_get_local_zip_path_google_model(self):
        """Test zip path generation with Google model."""
        result = get_local_zip_path("google/gemma-2-9b-it")
        expected = "./google-gemma-2-9b-it-local.tar.gz"
        assert result == expected
    
    def test_get_local_zip_path_consistency(self):
        """Test that zip path is consistent with local path."""
        model_id = "test/model"
        local_path = get_local_path(model_id)
        zip_path = get_local_zip_path(model_id)
        
        # Extract base name for comparison
        local_base = local_path.rstrip('/').replace('./', '')
        zip_base = zip_path.replace('.tar.gz', '').replace('./', '')
        
        assert local_base == zip_base


class TestHandleLocalArchive:
    """Test suite for the handle_local_archive function."""
    
    def test_handle_local_archive_file_not_exists(self):
        """Test handling when archive file doesn't exist."""
        result = handle_local_archive("/nonexistent/path.tar.gz", "/target/dir")
        assert result is False
    
    @patch('os.path.exists')
    @patch('os.makedirs')
    @patch('tarfile.open')
    @patch('builtins.print')
    def test_handle_local_archive_success(self, mock_print, mock_tar_open, mock_makedirs, mock_exists):
        """Test successful archive extraction."""
        # Setup mocks
        mock_exists.return_value = True
        mock_tar = Mock()
        mock_tar_open.return_value.__enter__.return_value = mock_tar
        
        # Call function
        result = handle_local_archive("/path/to/archive.tar.gz", "/target/dir")
        
        # Assertions
        assert result is True
        mock_makedirs.assert_called_once_with("/target/dir", exist_ok=True)
        mock_tar_open.assert_called_once_with("/path/to/archive.tar.gz", 'r:*')
        mock_tar.extractall.assert_called_once_with(path="/target/dir")
        
        # Check print messages
        mock_print.assert_any_call("[LOADER] Found archive at /path/to/archive.tar.gz. Extracting...")
        mock_print.assert_any_call("[LOADER] Archive extraction complete to /target/dir.")
    
    @patch('os.path.exists')
    @patch('os.makedirs')
    @patch('tarfile.open')
    @patch('builtins.print')
    def test_handle_local_archive_extraction_error(self, mock_print, mock_tar_open, mock_makedirs, mock_exists):
        """Test handling of extraction errors."""
        # Setup mocks
        mock_exists.return_value = True
        mock_tar_open.side_effect = tarfile.TarError("Extraction failed")
        
        # Call function
        result = handle_local_archive("/path/to/archive.tar.gz", "/target/dir")
        
        # Assertions
        assert result is False
        mock_print.assert_any_call("[ERROR] Failed to extract /path/to/archive.tar.gz: Extraction failed")
    
    @patch('os.path.exists')
    @patch('os.makedirs')
    @patch('tarfile.open')
    @patch('builtins.print')
    def test_handle_local_archive_makedirs_error(self, mock_print, mock_tar_open, mock_makedirs, mock_exists):
        """Test handling of directory creation errors."""
        # Setup mocks
        mock_exists.return_value = True
        mock_makedirs.side_effect = OSError("Permission denied")
        
        # Call function
        result = handle_local_archive("/path/to/archive.tar.gz", "/target/dir")
        
        # Assertions
        assert result is False
        mock_print.assert_any_call("[ERROR] Failed to extract /path/to/archive.tar.gz: Permission denied")


class TestDownloadModelIfNeeded:
    """Test suite for the download_model_if_needed function."""
    
    @patch('os.path.exists')
    @patch('os.listdir')
    @patch('builtins.print')
    def test_model_already_exists_with_files(self, mock_print, mock_listdir, mock_exists):
        """Test when model directory exists and has files."""
        # Setup mocks - directory exists and has files
        mock_exists.return_value = True
        mock_listdir.return_value = ['config.json', 'pytorch_model.bin']
        
        # Call function
        result = download_model_if_needed("test/model", "/local/path")
        
        # Assertions
        assert result is True
        mock_print.assert_called_with("[LOADER] Local model found at /local/path. Skipping download.")
    
    @patch('os.path.exists')
    @patch('os.listdir')
    @patch('utils.handle_local_archive')
    @patch('utils.get_local_zip_path')
    @patch('builtins.print')
    def test_model_missing_custom_archive_success(self, mock_print, mock_get_zip, mock_handle_archive, mock_listdir, mock_exists):
        """Test using custom archive path when model is missing."""
        # Setup mocks
        mock_exists.return_value = False  # Local path doesn't exist
        mock_listdir.return_value = []
        mock_handle_archive.return_value = True  # Custom archive extraction succeeds
        
        # Call function
        result = download_model_if_needed("test/model", "/local/path", "/custom/archive.tar.gz")
        
        # Assertions
        assert result is True
        mock_handle_archive.assert_called_once_with("/custom/archive.tar.gz", "/local/path")
        mock_print.assert_called_with("[LOADER] Local model not found at /local/path.")
    
    @patch('os.path.exists')
    @patch('os.listdir')
    @patch('utils.handle_local_archive')
    @patch('utils.get_local_zip_path')
    @patch('builtins.print')
    def test_model_missing_standard_archives_success(self, mock_print, mock_get_zip, mock_handle_archive, mock_listdir, mock_exists):
        """Test using standard archive paths when model is missing."""
        # Setup mocks
        mock_exists.return_value = False  # Local path doesn't exist
        mock_listdir.return_value = []
        mock_get_zip.return_value = "./test-model-local.tar.gz"
        
        # First two archive attempts fail, third succeeds
        mock_handle_archive.side_effect = [False, False, True]
        
        # Call function
        result = download_model_if_needed("test/model", "/local/path")
        
        # Assertions
        assert result is True
        assert mock_handle_archive.call_count == 3
        
        # Check the expected archive paths were tried
        expected_calls = [
            call("./test-model-local.tar.gz", "/local/path"),
            call("./test-model-local.tgz", "/local/path"),
            call("./test-model-local.tar", "/local/path")
        ]
        mock_handle_archive.assert_has_calls(expected_calls)
    
    @patch('os.path.exists')
    @patch('os.listdir')
    @patch('utils.handle_local_archive')
    @patch('utils.get_local_zip_path')
    @patch('huggingface_hub.snapshot_download')
    @patch('builtins.print')
    def test_model_missing_download_from_hf_success(self, mock_print, mock_download, mock_get_zip, mock_handle_archive, mock_listdir, mock_exists):
        """Test downloading from HuggingFace Hub when no local archives found."""
        # Setup mocks
        mock_exists.return_value = False
        mock_listdir.return_value = []
        mock_get_zip.return_value = "./test-model-local.tar.gz"
        mock_handle_archive.return_value = False  # All archive attempts fail
        
        # Call function
        result = download_model_if_needed("test/model", "/local/path")
        
        # Assertions
        assert result is True
        mock_download.assert_called_once_with(
            repo_id="test/model",
            local_dir="/local/path",
            local_dir_use_symlinks=False
        )
        mock_print.assert_any_call("[LOADER] No local archive found. Starting download from Hugging Face...")
        mock_print.assert_any_call("[LOADER] Model download complete.")
    
    @patch('os.path.exists')
    @patch('os.listdir') 
    @patch('utils.handle_local_archive')
    @patch('utils.get_local_zip_path')
    @patch('huggingface_hub.snapshot_download')
    @patch('builtins.print')
    def test_model_missing_download_from_hf_failure(self, mock_print, mock_download, mock_get_zip, mock_handle_archive, mock_listdir, mock_exists):
        """Test handling of HuggingFace Hub download failures."""
        # Setup mocks
        mock_exists.return_value = False
        mock_listdir.return_value = []
        mock_get_zip.return_value = "./test-model-local.tar.gz" 
        mock_handle_archive.return_value = False  # All archive attempts fail
        mock_download.side_effect = Exception("Network error")
        
        # Call function
        result = download_model_if_needed("test/model", "/local/path")
        
        # Assertions
        assert result is False
        mock_print.assert_any_call("[ERROR] Error during model download for test/model: Network error")
    
    @patch('os.path.exists')
    @patch('os.listdir')
    def test_model_directory_exists_but_empty(self, mock_listdir, mock_exists):
        """Test when model directory exists but is empty."""
        # First call (directory exists check) returns True
        # Second call (listdir check) returns empty list
        mock_exists.return_value = True
        mock_listdir.return_value = []  # Empty directory
        
        # Mock the archive and download chain
        with patch('utils.handle_local_archive') as mock_handle_archive, \
             patch('utils.get_local_zip_path') as mock_get_zip, \
             patch('huggingface_hub.snapshot_download') as mock_download, \
             patch('builtins.print'):
            
            mock_handle_archive.return_value = False
            mock_get_zip.return_value = "./test-model-local.tar.gz"
            
            result = download_model_if_needed("test/model", "/local/path")
            
            # Should attempt download since directory is empty
            assert result is True
            mock_download.assert_called_once()


if __name__ == "__main__":
    # Run tests if file is executed directly
    pytest.main([__file__, "-v"])