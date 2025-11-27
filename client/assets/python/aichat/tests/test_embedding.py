"""
Unit tests for the generate_embedding endpoint.

This module contains comprehensive unit tests for the generate_embedding API route handler,
testing text and image embedding generation, model loading, and error handling scenarios.
Tests use pytest with async support and mocking for dependencies.
"""
import pytest
from unittest.mock import Mock, patch, AsyncMock
from fastapi import HTTPException

# Import the functions we want to test
from routes import generate_embedding
from models import EmbeddingRequest


class TestGenerateEmbedding:
    """Test suite for the generate_embedding endpoint."""
    
    @pytest.mark.asyncio
    async def test_generate_embedding_missing_both_inputs(self):
        """Test embedding generation when neither text nor image provided."""
        request = EmbeddingRequest()  # Both text and image_base64 are None
        
        with pytest.raises(HTTPException) as exc_info:
            await generate_embedding(request)
        
        assert exc_info.value.status_code == 400
        assert "Either 'text' or 'image_base64' must be provided" in exc_info.value.detail
    
    @pytest.mark.asyncio
    async def test_generate_embedding_both_inputs_provided(self):
        """Test embedding generation when both text and image provided."""
        request = EmbeddingRequest(text="Hello", image_base64="base64data")
        
        with pytest.raises(HTTPException) as exc_info:
            await generate_embedding(request)
        
        assert exc_info.value.status_code == 400
        assert "Please provide either 'text' or 'image_base64', not both" in exc_info.value.detail
    
    @pytest.mark.asyncio
    async def test_generate_embedding_text_success(self):
        """Test successful text embedding generation."""
        with patch('routes.get_locks') as mock_get_locks, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.generate_text_embedding') as mock_gen_text, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id:
            
            # Setup mocks
            embedding_lock = AsyncMock()
            mock_get_locks.return_value = (Mock(), embedding_lock)
            mock_model = Mock()
            mock_processor = Mock()
            mock_get_embedding.return_value = (mock_model, mock_processor)
            mock_gen_text.return_value = [0.1, 0.2, 0.3, 0.4]
            mock_get_embedding_id.return_value = "embedding/model"
            
            request = EmbeddingRequest(text="Hello world")
            
            result = await generate_embedding(request)
            
            assert result["embedding"] == [0.1, 0.2, 0.3, 0.4]
            assert result["input_type"] == "text"
            assert result["input_content"] == "Hello world"
            assert result["model_used"] == "embedding/model"
            assert result["embedding_dimension"] == 4
    
    @pytest.mark.asyncio
    async def test_generate_embedding_image_success(self):
        """Test successful image embedding generation."""
        with patch('routes.get_locks') as mock_get_locks, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.decode_base64_image') as mock_decode, \
             patch('routes.generate_image_embedding') as mock_gen_image, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id:
            
            # Setup mocks
            embedding_lock = AsyncMock()
            mock_get_locks.return_value = (Mock(), embedding_lock)
            mock_model = Mock()
            mock_processor = Mock()
            mock_get_embedding.return_value = (mock_model, mock_processor)
            
            mock_image = Mock()
            mock_image.size = (100, 100)
            mock_decode.return_value = mock_image
            mock_gen_image.return_value = [0.5, 0.6, 0.7]
            mock_get_embedding_id.return_value = "embedding/model"
            
            request = EmbeddingRequest(image_base64="base64imagedata")
            
            result = await generate_embedding(request)
            
            assert result["embedding"] == [0.5, 0.6, 0.7]
            assert result["input_type"] == "image"
            assert result["input_content"] == "Image (100x100)"
            assert result["model_used"] == "embedding/model"
            assert result["embedding_dimension"] == 3
    
    @pytest.mark.asyncio
    async def test_generate_embedding_model_loading_failure(self):
        """Test embedding generation when model loading fails."""
        with patch('routes.get_locks') as mock_get_locks, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.load_embedding_model') as mock_load_embedding, \
             patch('builtins.print'):
            
            # Setup mocks
            embedding_lock = AsyncMock()
            mock_get_locks.return_value = (Mock(), embedding_lock)
            mock_get_embedding.return_value = (None, None)  # No model loaded
            mock_load_embedding.side_effect = Exception("Model loading failed")
            
            request = EmbeddingRequest(text="Hello")
            
            with pytest.raises(HTTPException) as exc_info:
                await generate_embedding(request)
            
            assert exc_info.value.status_code == 500
            assert "Failed to load embedding model" in exc_info.value.detail


if __name__ == "__main__":
    # Run tests if file is executed directly
    import pytest
    pytest.main([__file__, "-v"])