"""
Unit tests for the generate_embedding_from_upload endpoint.

This module contains comprehensive unit tests for the generate_embedding_from_upload API route handler,
testing file upload validation, image embedding generation, and text+image processing scenarios.
Tests use pytest with async support and mocking for dependencies.
"""
import pytest
from unittest.mock import Mock, patch, AsyncMock
from fastapi import HTTPException

# Import the functions we want to test
from routes import generate_embedding_from_upload


class TestGenerateEmbeddingFromUpload:
    """Test suite for the generate_embedding_from_upload endpoint."""
    
    @pytest.mark.asyncio
    async def test_generate_embedding_upload_invalid_file_type(self):
        """Test embedding upload with non-image file."""
        # Create mock file with non-image content type
        mock_file = Mock()
        mock_file.content_type = "text/plain"
        
        with pytest.raises(HTTPException) as exc_info:
            await generate_embedding_from_upload(mock_file)
        
        assert exc_info.value.status_code == 400
        assert "File must be an image" in exc_info.value.detail
    
    @pytest.mark.asyncio
    async def test_generate_embedding_upload_none_content_type(self):
        """Test embedding upload with None content type."""
        mock_file = Mock()
        mock_file.content_type = None
        
        with pytest.raises(HTTPException) as exc_info:
            await generate_embedding_from_upload(mock_file)
        
        assert exc_info.value.status_code == 400
        assert "File must be an image" in exc_info.value.detail
    
    @pytest.mark.asyncio
    async def test_generate_embedding_upload_image_only_success(self):
        """Test successful image-only embedding from upload."""
        with patch('routes.get_locks') as mock_get_locks, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.generate_image_embedding') as mock_gen_image, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id:
            
            # Setup mocks
            embedding_lock = AsyncMock()
            mock_get_locks.return_value = (Mock(), embedding_lock)
            mock_model = Mock()
            mock_processor = Mock()
            mock_get_embedding.return_value = (mock_model, mock_processor)
            mock_gen_image.return_value = [0.1, 0.2, 0.3]
            mock_get_embedding_id.return_value = "embedding/model"
            
            # Create mock file
            mock_file = Mock()
            mock_file.content_type = "image/jpeg"
            mock_file.filename = "test.jpg"
            
            # Mock image data and PIL operations
            image_data = b"fake_image_data"
            mock_file.read = AsyncMock(return_value=image_data)
            
            with patch('PIL.Image.open') as mock_image_open:
                mock_image = Mock()
                mock_image.size = (64, 64)
                mock_image_open.return_value.convert.return_value = mock_image
                
                result = await generate_embedding_from_upload(mock_file)
                
                assert result["embedding"] == [0.1, 0.2, 0.3]
                assert result["input_type"] == "image"
                assert result["input_content"] == "Image (64x64)"
                assert result["model_used"] == "embedding/model"
                assert result["embedding_dimension"] == 3
                assert result["filename"] == "test.jpg"
    
    @pytest.mark.asyncio
    async def test_generate_embedding_upload_text_plus_image_success(self):
        """Test successful text+image embedding from upload."""
        with patch('routes.get_locks') as mock_get_locks, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('torch.no_grad'), \
             patch('torch.mean') as mock_mean:
            
            # Setup mocks
            embedding_lock = AsyncMock()
            mock_get_locks.return_value = (Mock(), embedding_lock)
            mock_model = Mock()
            mock_processor = Mock()
            mock_get_embedding.return_value = (mock_model, mock_processor)
            mock_get_embedding_id.return_value = "embedding/model"
            
            # Mock processor and model output
            mock_processor.return_value = {"input_ids": Mock(), "pixel_values": Mock()}
            mock_param = Mock()
            mock_param.device = 'cpu'
            mock_model.parameters.return_value = iter([mock_param])
            
            mock_outputs = Mock()
            mock_hidden_state = Mock()
            mock_outputs.hidden_states = [Mock(), mock_hidden_state]
            mock_model.return_value = mock_outputs
            
            # Mock torch operations
            mock_embeddings = Mock()
            mock_embeddings.squeeze.return_value.cpu.return_value.numpy.return_value.tolist.return_value = [0.7, 0.8, 0.9]
            mock_mean.return_value = mock_embeddings
            
            # Create mock file
            mock_file = Mock()
            mock_file.content_type = "image/png"
            mock_file.filename = "test.png"
            image_data = b"fake_image_data"
            mock_file.read = AsyncMock(return_value=image_data)
            
            with patch('PIL.Image.open') as mock_image_open:
                mock_image = Mock()
                mock_image.size = (128, 128)
                mock_image_open.return_value.convert.return_value = mock_image
                
                result = await generate_embedding_from_upload(mock_file, text="A beautiful image")
                
                assert result["embedding"] == [0.7, 0.8, 0.9]
                assert result["input_type"] == "text+image"
                assert result["input_content"] == "Text: 'A beautiful image' + Image (128x128)"
                assert result["model_used"] == "embedding/model"
                assert result["embedding_dimension"] == 3
                assert result["filename"] == "test.png"


if __name__ == "__main__":
    # Run tests if file is executed directly
    import pytest
    pytest.main([__file__, "-v"])