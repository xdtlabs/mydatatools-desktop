"""
Unit tests for the model_manager module.

This module tests model management functions including base64 image decoding,
and mocks the heavy machine learning functions to test their interfaces
without actually loading models or running inference.
"""
import pytest
import base64
from unittest.mock import Mock, patch, MagicMock
from PIL import Image
from io import BytesIO

from model_manager import (
    decode_base64_image,
    load_model_to_memory,
    load_embedding_model,
    generate_text_embedding,
    generate_image_embedding
)


class TestDecodeBase64Image:
    """Test suite for the decode_base64_image function."""
    
    def test_decode_base64_image_simple(self):
        """Test decoding a simple base64 image."""
        # Create a simple 1x1 red pixel PNG image
        img = Image.new('RGB', (1, 1), color='red')
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        
        # Convert to base64
        base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
        
        # Test decoding
        result = decode_base64_image(base64_data)
        
        assert isinstance(result, Image.Image)
        assert result.mode == 'RGB'
        assert result.size == (1, 1)
    
    def test_decode_base64_image_with_data_url_prefix(self):
        """Test decoding base64 image with data URL prefix."""
        # Create test image
        img = Image.new('RGB', (2, 2), color='blue')
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        
        # Convert to base64 with data URL prefix
        base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
        data_url = f"data:image/png;base64,{base64_data}"
        
        # Test decoding
        result = decode_base64_image(data_url)
        
        assert isinstance(result, Image.Image)
        assert result.mode == 'RGB'
        assert result.size == (2, 2)
    
    def test_decode_base64_image_different_formats(self):
        """Test decoding different image formats."""
        formats = ['PNG', 'JPEG']
        
        for fmt in formats:
            img = Image.new('RGB', (3, 3), color='green')
            buffer = BytesIO()
            img.save(buffer, format=fmt)
            
            base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
            
            result = decode_base64_image(base64_data)
            
            assert isinstance(result, Image.Image)
            assert result.mode == 'RGB'
            assert result.size == (3, 3)
    
    def test_decode_base64_image_converts_to_rgb(self):
        """Test that image is converted to RGB mode."""
        # Create RGBA image (with alpha channel)
        img = Image.new('RGBA', (2, 2), color=(255, 0, 0, 128))
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        
        base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
        
        result = decode_base64_image(base64_data)
        
        # Should be converted to RGB
        assert result.mode == 'RGB'
        assert result.size == (2, 2)
    
    def test_decode_base64_image_invalid_data(self):
        """Test handling of invalid base64 data."""
        invalid_data = "invalid_base64_data"
        
        with pytest.raises(ValueError, match="Invalid base64 image data"):
            decode_base64_image(invalid_data)
    
    def test_decode_base64_image_not_image_data(self):
        """Test handling of base64 data that's not an image."""
        # Create base64 of text data
        text_data = "This is not image data"
        base64_data = base64.b64encode(text_data.encode()).decode('utf-8')
        
        with pytest.raises(ValueError, match="Invalid base64 image data"):
            decode_base64_image(base64_data)
    
    def test_decode_base64_image_empty_string(self):
        """Test handling of empty base64 string."""
        with pytest.raises(ValueError, match="Invalid base64 image data"):
            decode_base64_image("")
    
    def test_decode_base64_image_data_url_variations(self):
        """Test different data URL prefix variations."""
        # Create test image
        img = Image.new('RGB', (1, 1), color='white')
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
        
        # Test different data URL prefixes
        prefixes = [
            "data:image/png;base64,",
            "data:image/jpeg;base64,",
            "data:image/gif;base64,",
        ]
        
        for prefix in prefixes:
            data_url = f"{prefix}{base64_data}"
            result = decode_base64_image(data_url)
            
            assert isinstance(result, Image.Image)
            assert result.mode == 'RGB'


class TestLoadModelToMemory:
    """Test suite for the load_model_to_memory function (mocked)."""
    
    @patch('model_manager.AutoTokenizer.from_pretrained')
    @patch('model_manager.AutoModelForCausalLM.from_pretrained')
    @patch('model_manager.pipeline')
    @patch('model_manager.HuggingFacePipeline')
    @patch('builtins.print')
    def test_load_model_to_memory_success(self, mock_print, mock_hf_pipeline, mock_pipeline, mock_model, mock_tokenizer):
        """Test successful model loading with proper mocks."""
        # Setup mocks
        mock_tokenizer_instance = Mock()
        mock_model_instance = Mock()
        mock_pipe_instance = Mock()
        mock_hf_pipeline_instance = Mock()
        
        mock_tokenizer.return_value = mock_tokenizer_instance
        mock_model.return_value = mock_model_instance
        mock_pipeline.return_value = mock_pipe_instance
        mock_hf_pipeline.return_value = mock_hf_pipeline_instance
        
        # Call function
        result = load_model_to_memory("/test/path")
        
        # Assertions
        assert result is mock_hf_pipeline_instance
        
        # Check that components were loaded correctly
        mock_tokenizer.assert_called_once_with("/test/path")
        mock_model.assert_called_once()
        mock_pipeline.assert_called_once()
        mock_hf_pipeline.assert_called_once_with(pipeline=mock_pipe_instance)
        
        # Check print message
        mock_print.assert_called_with("[LOADER] Attempting to load model from: /test/path. This may take time.")
    
    @patch('model_manager.AutoTokenizer.from_pretrained')
    @patch('builtins.print')
    def test_load_model_to_memory_tokenizer_error(self, mock_print, mock_tokenizer):
        """Test handling of tokenizer loading errors."""
        mock_tokenizer.side_effect = Exception("Tokenizer loading failed")
        
        with pytest.raises(Exception, match="Tokenizer loading failed"):
            load_model_to_memory("/test/path")
    
    @patch('model_manager.AutoTokenizer.from_pretrained')
    @patch('model_manager.AutoModelForCausalLM.from_pretrained')
    @patch('builtins.print')
    def test_load_model_to_memory_model_error(self, mock_print, mock_model, mock_tokenizer):
        """Test handling of model loading errors."""
        mock_tokenizer.return_value = Mock()
        mock_model.side_effect = Exception("Model loading failed")
        
        with pytest.raises(Exception, match="Model loading failed"):
            load_model_to_memory("/test/path")


class TestLoadEmbeddingModel:
    """Test suite for the load_embedding_model function (mocked)."""
    
    @patch('model_manager.get_local_path')
    @patch('model_manager.download_model_if_needed')
    @patch('model_manager.AutoProcessor.from_pretrained')
    @patch('model_manager.AutoModelForCausalLM.from_pretrained')
    @patch('builtins.print')
    def test_load_embedding_model_success(self, mock_print, mock_model, mock_processor, mock_download, mock_get_path):
        """Test successful embedding model loading."""
        # Setup mocks
        mock_get_path.return_value = "/local/path"
        mock_download.return_value = True
        mock_processor_instance = Mock()
        mock_model_instance = Mock()
        mock_processor.return_value = mock_processor_instance
        mock_model.return_value = mock_model_instance
        
        # Call function
        model, processor = load_embedding_model("test/model")
        
        # Assertions
        assert model is mock_model_instance
        assert processor is mock_processor_instance
        
        mock_get_path.assert_called_once_with("test/model")
        mock_download.assert_called_once_with("test/model", "/local/path")
        mock_processor.assert_called_once_with("/local/path")
        mock_model.assert_called_once()
    
    @patch('model_manager.get_local_path')
    @patch('model_manager.download_model_if_needed')
    @patch('builtins.print')
    def test_load_embedding_model_download_failure(self, mock_print, mock_download, mock_get_path):
        """Test handling of download failures."""
        mock_get_path.return_value = "/local/path"
        mock_download.return_value = False
        
        with pytest.raises(Exception, match="Failed to download embedding model test/model"):
            load_embedding_model("test/model")


class TestGenerateTextEmbedding:
    """Test suite for the generate_text_embedding function (mocked)."""
    
    @patch('torch.no_grad')
    def test_generate_text_embedding_success(self, mock_no_grad):
        """Test successful text embedding generation."""
        # Setup mocks
        mock_model = Mock()
        mock_processor = Mock()
        
        # Mock processor output
        mock_inputs = {'input_ids': Mock(), 'attention_mask': Mock()}
        mock_processor.return_value = mock_inputs
        
        # Mock model device - use iter() to create proper iterator
        mock_param = Mock()
        mock_param.device = 'cpu'
        mock_model.parameters.return_value = iter([mock_param])
        
        # Mock model output with hidden states
        mock_hidden_state = Mock()
        mock_hidden_state.squeeze.return_value.cpu.return_value.numpy.return_value.tolist.return_value = [0.1, 0.2, 0.3]
        
        mock_outputs = Mock()
        mock_outputs.hidden_states = [None, mock_hidden_state]  # [-1] will get the last one
        mock_model.return_value = mock_outputs
        
        # Mock torch operations
        with patch('torch.mean') as mock_mean:
            mock_mean.return_value = mock_hidden_state
            
            # Call function
            result = generate_text_embedding("test text", mock_model, mock_processor)
        
        # Assertions
        assert result == [0.1, 0.2, 0.3]
        mock_processor.assert_called_once_with(text="test text", return_tensors="pt")
    
    def test_generate_text_embedding_with_real_mocks(self):
        """Test text embedding with more realistic mock setup."""
        # Create mock model and processor
        mock_model = Mock()
        mock_processor = Mock()
        
        # Mock the processor to return input tensors
        mock_processor.return_value = {
            'input_ids': Mock(),
            'attention_mask': Mock()
        }
        
        # Mock model parameters for device detection
        mock_param = Mock()
        mock_param.device = 'cpu'
        mock_model.parameters.return_value = iter([mock_param])
        
        # Mock the model output with hidden states
        mock_outputs = Mock()
        mock_last_hidden_state = Mock()
        mock_outputs.hidden_states = [Mock(), mock_last_hidden_state]  # Last one is [-1]
        
        # Mock torch operations
        with patch('torch.mean') as mock_mean, \
             patch('torch.no_grad'):
            
            mock_embeddings = Mock()
            mock_embeddings.squeeze.return_value.cpu.return_value.numpy.return_value.tolist.return_value = [1.0, 2.0, 3.0]
            mock_mean.return_value = mock_embeddings
            
            mock_model.return_value = mock_outputs
            
            # Call function
            result = generate_text_embedding("Hello world", mock_model, mock_processor)
            
            # Assertions
            assert result == [1.0, 2.0, 3.0]
            mock_processor.assert_called_once_with(text="Hello world", return_tensors="pt")


class TestGenerateImageEmbedding:
    """Test suite for the generate_image_embedding function (mocked)."""
    
    def test_generate_image_embedding_success(self):
        """Test successful image embedding generation."""
        # Create mock image
        mock_image = Mock(spec=Image.Image)
        
        # Create mock model and processor
        mock_model = Mock()
        mock_processor = Mock()
        
        # Mock the processor to return input tensors
        mock_processor.return_value = {
            'pixel_values': Mock()
        }
        
        # Mock model parameters for device detection
        mock_param = Mock()
        mock_param.device = 'cpu'
        mock_model.parameters.return_value = iter([mock_param])
        
        # Mock the model output
        mock_outputs = Mock()
        mock_last_hidden_state = Mock()
        mock_outputs.hidden_states = [Mock(), mock_last_hidden_state]
        
        # Mock torch operations
        with patch('torch.mean') as mock_mean, \
             patch('torch.no_grad'):
            
            mock_embeddings = Mock()
            mock_embeddings.squeeze.return_value.cpu.return_value.numpy.return_value.tolist.return_value = [0.5, 1.5, 2.5]
            mock_mean.return_value = mock_embeddings
            
            mock_model.return_value = mock_outputs
            
            # Call function
            result = generate_image_embedding(mock_image, mock_model, mock_processor)
            
            # Assertions
            assert result == [0.5, 1.5, 2.5]
            mock_processor.assert_called_once_with(images=mock_image, return_tensors="pt")
    
    def test_generate_image_embedding_with_pil_image(self):
        """Test image embedding with actual PIL Image object."""
        # Create a real PIL image for more realistic testing
        test_image = Image.new('RGB', (32, 32), color='red')
        
        # Create mocks for model components
        mock_model = Mock()
        mock_processor = Mock()
        
        mock_processor.return_value = {'pixel_values': Mock()}
        
        # Mock model device
        mock_param = Mock()
        mock_param.device = 'cuda'
        mock_model.parameters.return_value = iter([mock_param])
        
        # Mock model outputs
        mock_outputs = Mock()
        mock_hidden_state = Mock()
        mock_outputs.hidden_states = [Mock(), mock_hidden_state]
        
        with patch('torch.mean') as mock_mean, \
             patch('torch.no_grad'):
            
            mock_embeddings = Mock()
            mock_embeddings.squeeze.return_value.cpu.return_value.numpy.return_value.tolist.return_value = [1.1, 2.2, 3.3]
            mock_mean.return_value = mock_embeddings
            
            mock_model.return_value = mock_outputs
            
            # Call function
            result = generate_image_embedding(test_image, mock_model, mock_processor)
            
            # Assertions
            assert result == [1.1, 2.2, 3.3]
            mock_processor.assert_called_once_with(images=test_image, return_tensors="pt")


class TestModelManagerIntegration:
    """Integration tests for model manager functions."""
    
    def test_decode_base64_then_generate_embedding_flow(self):
        """Test the flow from base64 decoding to embedding generation."""
        # Create test image and encode to base64
        img = Image.new('RGB', (4, 4), color='blue')
        buffer = BytesIO()
        img.save(buffer, format='PNG')
        base64_data = base64.b64encode(buffer.getvalue()).decode('utf-8')
        
        # Decode the image
        decoded_image = decode_base64_image(base64_data)
        
        # Verify the decoded image
        assert isinstance(decoded_image, Image.Image)
        assert decoded_image.mode == 'RGB'
        assert decoded_image.size == (4, 4)
        
        # Now mock the embedding generation
        mock_model = Mock()
        mock_processor = Mock()
        
        mock_processor.return_value = {'pixel_values': Mock()}
        mock_param = Mock()
        mock_param.device = 'cpu'
        mock_model.parameters.return_value = iter([mock_param])
        
        mock_outputs = Mock()
        mock_hidden_state = Mock()
        mock_outputs.hidden_states = [Mock(), mock_hidden_state]
        
        with patch('torch.mean') as mock_mean, \
             patch('torch.no_grad'):
            
            mock_embeddings = Mock()
            mock_embeddings.squeeze.return_value.cpu.return_value.numpy.return_value.tolist.return_value = [4.0, 5.0, 6.0]
            mock_mean.return_value = mock_embeddings
            
            mock_model.return_value = mock_outputs
            
            # Generate embedding from decoded image
            embedding = generate_image_embedding(decoded_image, mock_model, mock_processor)
            
            assert embedding == [4.0, 5.0, 6.0]


if __name__ == "__main__":
    # Run tests if file is executed directly
    pytest.main([__file__, "-v"])