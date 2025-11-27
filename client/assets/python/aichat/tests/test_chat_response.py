"""
Unit tests for the generate_chat_response endpoint.

This module contains comprehensive unit tests for the generate_chat_response API route handler,
testing chat functionality, response generation, and error handling scenarios.
Tests use pytest with async support and mocking for dependencies.
"""
import pytest
from unittest.mock import Mock, patch
from fastapi import HTTPException

# Import the functions we want to test
from routes import generate_chat_response
from models import ChatRequest


class TestGenerateChatResponse:
    """Test suite for the generate_chat_response endpoint."""
    
    @pytest.mark.asyncio
    async def test_generate_chat_response_no_model_loaded(self):
        """Test chat response when no model is loaded."""
        with patch('routes.get_llm_instance') as mock_get_llm:
            mock_get_llm.return_value = None
            
            request = ChatRequest(prompt="Hello")
            
            with pytest.raises(HTTPException) as exc_info:
                await generate_chat_response(request)
            
            assert exc_info.value.status_code == 503
            assert "No active model session" in exc_info.value.detail
    
    @pytest.mark.asyncio
    async def test_generate_chat_response_success_basic(self):
        """Test successful chat response generation."""
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id:
            
            # Setup mock LLM
            mock_llm = Mock()
            mock_llm.invoke.return_value = "<start_of_turn>user\nHello<end_of_turn>\n<start_of_turn>model\nHi there!<end_of_turn>"
            mock_get_llm.return_value = mock_llm
            mock_get_model_id.return_value = "test/model"
            
            request = ChatRequest(prompt="Hello")
            
            result = await generate_chat_response(request)
            
            assert result["user_prompt"] == "Hello"
            assert result["ai_response"] == "Hi there!"
            assert result["model_used"] == "test/model"
    
    @pytest.mark.asyncio
    async def test_generate_chat_response_with_system_instruction(self):
        """Test chat response with system instruction."""
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id:
            
            mock_llm = Mock()
            mock_llm.invoke.return_value = "Full response with system instruction and user query\nI'll be helpful as instructed."
            mock_get_llm.return_value = mock_llm
            mock_get_model_id.return_value = "test/model"
            
            request = ChatRequest(
                prompt="How can I help?",
                system_instruction="Be helpful and concise"
            )
            
            result = await generate_chat_response(request)
            
            assert result["user_prompt"] == "How can I help?"
            assert "helpful" in result["ai_response"]
    
    @pytest.mark.asyncio
    async def test_generate_chat_response_model_error(self):
        """Test chat response when model invocation fails."""
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('builtins.print'):
            
            mock_llm = Mock()
            mock_llm.invoke.side_effect = Exception("Model error")
            mock_get_llm.return_value = mock_llm
            
            request = ChatRequest(prompt="Hello")
            
            with pytest.raises(HTTPException) as exc_info:
                await generate_chat_response(request)
            
            assert exc_info.value.status_code == 500
            assert "Failed to generate response" in exc_info.value.detail


if __name__ == "__main__":
    # Run tests if file is executed directly
    import pytest
    pytest.main([__file__, "-v"])