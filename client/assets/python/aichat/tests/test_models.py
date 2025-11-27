"""
Unit tests for the models module.

This module tests Pydantic model validation, serialization, and edge cases
for all request/response models used in the API. Tests verify that models
correctly validate input data and provide helpful error messages.
"""
import pytest
from pydantic import ValidationError

from models import ChatRequest, StartSessionRequest, EmbeddingRequest


class TestChatRequest:
    """Test suite for the ChatRequest model."""
    
    def test_chat_request_valid_basic(self):
        """Test valid ChatRequest with minimal fields."""
        request = ChatRequest(prompt="Hello, world!")
        
        assert request.prompt == "Hello, world!"
        assert request.system_instruction is None
    
    def test_chat_request_valid_with_system_instruction(self):
        """Test valid ChatRequest with system instruction."""
        request = ChatRequest(
            prompt="Explain quantum physics",
            system_instruction="You are a helpful physics teacher"
        )
        
        assert request.prompt == "Explain quantum physics"
        assert request.system_instruction == "You are a helpful physics teacher"
    
    def test_chat_request_empty_prompt(self):
        """Test ChatRequest with empty prompt should fail."""
        with pytest.raises(ValidationError) as exc_info:
            ChatRequest(prompt="")
        
        # Check that validation error mentions minimum length
        error_msg = str(exc_info.value)
        assert "at least 1 character" in error_msg or "string_too_short" in error_msg
    
    def test_chat_request_missing_prompt(self):
        """Test ChatRequest without prompt should fail."""
        with pytest.raises(ValidationError) as exc_info:
            ChatRequest(system_instruction="You are helpful")
        
        # Check that validation error mentions missing field
        error_msg = str(exc_info.value)
        assert "field required" in error_msg or "Field required" in error_msg
    
    def test_chat_request_whitespace_prompt(self):
        """Test ChatRequest with whitespace-only prompt."""
        # Single space should pass min_length=1
        request = ChatRequest(prompt=" ")
        assert request.prompt == " "
        
        # Multiple spaces should also pass
        request = ChatRequest(prompt="   ")
        assert request.prompt == "   "
    
    def test_chat_request_long_prompt(self):
        """Test ChatRequest with very long prompt."""
        long_prompt = "A" * 10000  # 10k characters
        request = ChatRequest(prompt=long_prompt)
        
        assert request.prompt == long_prompt
        assert len(request.prompt) == 10000
    
    def test_chat_request_special_characters(self):
        """Test ChatRequest with special characters."""
        special_prompt = "Hello! @#$%^&*()_+{}|:<>?[]\\;'\",./"
        request = ChatRequest(prompt=special_prompt)
        
        assert request.prompt == special_prompt
    
    def test_chat_request_unicode_characters(self):
        """Test ChatRequest with Unicode characters."""
        unicode_prompt = "こんにちは 🌍 Здравствуй 🚀 مرحبا"
        request = ChatRequest(prompt=unicode_prompt)
        
        assert request.prompt == unicode_prompt
    
    def test_chat_request_json_serialization(self):
        """Test ChatRequest JSON serialization."""
        request = ChatRequest(
            prompt="Test prompt",
            system_instruction="Test instruction"
        )
        
        json_data = request.model_dump()
        
        expected = {
            "prompt": "Test prompt",
            "system_instruction": "Test instruction"
        }
        assert json_data == expected
    
    def test_chat_request_json_serialization_none_system(self):
        """Test ChatRequest JSON serialization with None system instruction."""
        request = ChatRequest(prompt="Test prompt")
        
        json_data = request.model_dump()
        
        expected = {
            "prompt": "Test prompt",
            "system_instruction": None
        }
        assert json_data == expected
    
    def test_chat_request_from_dict(self):
        """Test creating ChatRequest from dictionary."""
        data = {
            "prompt": "Dictionary prompt",
            "system_instruction": "Dictionary instruction"
        }
        
        request = ChatRequest(**data)
        
        assert request.prompt == "Dictionary prompt"
        assert request.system_instruction == "Dictionary instruction"


class TestStartSessionRequest:
    """Test suite for the StartSessionRequest model."""
    
    def test_start_session_request_default(self):
        """Test StartSessionRequest with default values."""
        request = StartSessionRequest()
        
        assert request.model_name == "google/gemma-2-9b-it"
        assert request.local_path is None
    
    def test_start_session_request_custom_model(self):
        """Test StartSessionRequest with custom model name."""
        request = StartSessionRequest(model_name="facebook/opt-1.3b")
        
        assert request.model_name == "facebook/opt-1.3b"
        assert request.local_path is None
    
    def test_start_session_request_with_local_path(self):
        """Test StartSessionRequest with local path."""
        request = StartSessionRequest(
            model_name="custom/model",
            local_path="/path/to/model.tar.gz"
        )
        
        assert request.model_name == "custom/model"
        assert request.local_path == "/path/to/model.tar.gz"
    
    def test_start_session_request_various_model_names(self):
        """Test StartSessionRequest with various model name formats."""
        test_cases = [
            "google/gemma-2-9b-it",
            "microsoft/DialoGPT-medium",
            "simple-model",
            "org/sub/model-name",
            "123-numeric-model"
        ]
        
        for model_name in test_cases:
            request = StartSessionRequest(model_name=model_name)
            assert request.model_name == model_name
    
    def test_start_session_request_various_local_paths(self):
        """Test StartSessionRequest with various local path formats."""
        test_cases = [
            "/absolute/path/model.tar.gz",
            "./relative/path/model.tgz",
            "../parent/path/model.tar",
            "simple-filename.tar.gz",
            "/path/with spaces/model.tar.gz"
        ]
        
        for local_path in test_cases:
            request = StartSessionRequest(
                model_name="test/model",
                local_path=local_path
            )
            assert request.local_path == local_path
    
    def test_start_session_request_json_serialization(self):
        """Test StartSessionRequest JSON serialization."""
        request = StartSessionRequest(
            model_name="test/model",
            local_path="/test/path"
        )
        
        json_data = request.model_dump()
        
        expected = {
            "model_name": "test/model",
            "local_path": "/test/path"
        }
        assert json_data == expected
    
    def test_start_session_request_from_dict(self):
        """Test creating StartSessionRequest from dictionary."""
        data = {
            "model_name": "dict/model",
            "local_path": "/dict/path.tar.gz"
        }
        
        request = StartSessionRequest(**data)
        
        assert request.model_name == "dict/model"
        assert request.local_path == "/dict/path.tar.gz"
    
    def test_start_session_request_partial_data(self):
        """Test StartSessionRequest with partial data."""
        # Only model_name provided
        request1 = StartSessionRequest(model_name="only/model")
        assert request1.model_name == "only/model"
        assert request1.local_path is None
        
        # Empty dict should use defaults
        request2 = StartSessionRequest()
        assert request2.model_name == "google/gemma-2-9b-it"
        assert request2.local_path is None


class TestEmbeddingRequest:
    """Test suite for the EmbeddingRequest model."""
    
    def test_embedding_request_text_only(self):
        """Test EmbeddingRequest with text only."""
        request = EmbeddingRequest(text="Sample text for embedding")
        
        assert request.text == "Sample text for embedding"
        assert request.image_base64 is None
    
    def test_embedding_request_image_only(self):
        """Test EmbeddingRequest with image only."""
        base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        
        request = EmbeddingRequest(image_base64=base64_image)
        
        assert request.text is None
        assert request.image_base64 == base64_image
    
    def test_embedding_request_both_none(self):
        """Test EmbeddingRequest with both fields None (should be valid for Pydantic)."""
        # Note: Business logic validation happens in the API layer, not Pydantic
        request = EmbeddingRequest()
        
        assert request.text is None
        assert request.image_base64 is None
    
    def test_embedding_request_both_provided(self):
        """Test EmbeddingRequest with both text and image (should be valid for Pydantic)."""
        # Note: Business logic validation happens in the API layer, not Pydantic
        base64_image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
        
        request = EmbeddingRequest(
            text="Sample text",
            image_base64=base64_image
        )
        
        assert request.text == "Sample text"
        assert request.image_base64 == base64_image
    
    def test_embedding_request_long_text(self):
        """Test EmbeddingRequest with long text."""
        long_text = "This is a very long text " * 1000  # ~25k characters
        
        request = EmbeddingRequest(text=long_text)
        
        assert request.text == long_text
        assert len(request.text) == len(long_text)
    
    def test_embedding_request_empty_text(self):
        """Test EmbeddingRequest with empty text."""
        request = EmbeddingRequest(text="")
        
        assert request.text == ""
    
    def test_embedding_request_empty_image_base64(self):
        """Test EmbeddingRequest with empty image_base64."""
        request = EmbeddingRequest(image_base64="")
        
        assert request.image_base64 == ""
    
    def test_embedding_request_unicode_text(self):
        """Test EmbeddingRequest with Unicode text."""
        unicode_text = "多言語テスト 🌍 مرحبا بالعالم 🚀 Привет мир"
        
        request = EmbeddingRequest(text=unicode_text)
        
        assert request.text == unicode_text
    
    def test_embedding_request_large_base64(self):
        """Test EmbeddingRequest with large base64 image."""
        # Create a longer base64 string (simulating larger image)
        large_base64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==" * 100
        
        request = EmbeddingRequest(image_base64=large_base64)
        
        assert request.image_base64 == large_base64
    
    def test_embedding_request_json_serialization(self):
        """Test EmbeddingRequest JSON serialization."""
        request = EmbeddingRequest(
            text="Test text",
            image_base64="test_base64"
        )
        
        json_data = request.model_dump()
        
        expected = {
            "text": "Test text",
            "image_base64": "test_base64"
        }
        assert json_data == expected
    
    def test_embedding_request_from_dict(self):
        """Test creating EmbeddingRequest from dictionary."""
        data = {
            "text": "Dictionary text",
            "image_base64": "dict_base64_data"
        }
        
        request = EmbeddingRequest(**data)
        
        assert request.text == "Dictionary text"
        assert request.image_base64 == "dict_base64_data"


class TestModelIntegration:
    """Integration tests for all models together."""
    
    def test_all_models_json_compatibility(self):
        """Test that all models can be serialized and deserialized."""
        # Create instances of all models
        chat_req = ChatRequest(prompt="Test", system_instruction="Test system")
        session_req = StartSessionRequest(model_name="test/model", local_path="/test/path")
        embed_req = EmbeddingRequest(text="Test embedding", image_base64="test_base64")
        
        # Serialize to JSON
        chat_json = chat_req.model_dump()
        session_json = session_req.model_dump()
        embed_json = embed_req.model_dump()
        
        # Deserialize from JSON
        chat_restored = ChatRequest(**chat_json)
        session_restored = StartSessionRequest(**session_json)
        embed_restored = EmbeddingRequest(**embed_json)
        
        # Verify data integrity
        assert chat_restored.prompt == chat_req.prompt
        assert chat_restored.system_instruction == chat_req.system_instruction
        
        assert session_restored.model_name == session_req.model_name
        assert session_restored.local_path == session_req.local_path
        
        assert embed_restored.text == embed_req.text
        assert embed_restored.image_base64 == embed_req.image_base64
    
    def test_model_schema_generation(self):
        """Test that all models can generate JSON schemas."""
        # This tests that the models are properly configured for OpenAPI
        chat_schema = ChatRequest.model_json_schema()
        session_schema = StartSessionRequest.model_json_schema()
        embed_schema = EmbeddingRequest.model_json_schema()
        
        # Check that schemas contain expected properties
        assert "properties" in chat_schema
        assert "prompt" in chat_schema["properties"]
        assert "system_instruction" in chat_schema["properties"]
        
        assert "properties" in session_schema
        assert "model_name" in session_schema["properties"]
        assert "local_path" in session_schema["properties"]
        
        assert "properties" in embed_schema
        assert "text" in embed_schema["properties"]
        assert "image_base64" in embed_schema["properties"]
    
    def test_model_field_descriptions(self):
        """Test that models have proper field descriptions for API docs."""
        chat_schema = ChatRequest.model_json_schema()
        session_schema = StartSessionRequest.model_json_schema()
        embed_schema = EmbeddingRequest.model_json_schema()
        
        # Check that important fields have descriptions
        assert "description" in chat_schema["properties"]["prompt"]
        assert "description" in session_schema["properties"]["model_name"]
        assert "description" in embed_schema["properties"]["text"]


if __name__ == "__main__":
    # Run tests if file is executed directly
    pytest.main([__file__, "-v"])