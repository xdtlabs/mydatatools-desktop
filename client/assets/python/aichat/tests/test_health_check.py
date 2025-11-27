"""
Unit tests for the health_check endpoint.

This module contains comprehensive unit tests for the health_check API route handler,
testing various model states, loading conditions, and response structure validation.
Tests use pytest with async support and mocking for dependencies.
"""
import pytest
from unittest.mock import Mock, patch

# Import the functions we want to test
from routes import health_check


class TestHealthCheck:
    """Test suite for the health_check endpoint."""
    
    @pytest.mark.asyncio
    async def test_health_check_no_models_loaded(self):
        """
        Test health check when no models are loaded.
        
        Should return status with no active models and not loading.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock no models loaded
            mock_get_llm.return_value = None
            mock_get_model_id.return_value = None
            mock_get_embedding.return_value = (None, None)
            mock_get_embedding_id.return_value = None
            
            # Mock locks that are not locked
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = False
            mock_embedding_lock.locked.return_value = False
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["current_chat_model"] == "None (Session not started)"
            assert result["chat_model_loaded"] is False
            assert result["current_embedding_model"] == "None"
            assert result["embedding_model_loaded"] is False
            assert result["is_loading"] is False
    
    @pytest.mark.asyncio
    async def test_health_check_chat_model_loaded(self):
        """
        Test health check when chat model is loaded but embedding model is not.
        
        Should show chat model as loaded and embedding model as not loaded.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock chat model loaded
            mock_llm_instance = Mock()
            mock_get_llm.return_value = mock_llm_instance
            mock_get_model_id.return_value = "google/gemma-2-9b-it"
            
            # Mock no embedding model
            mock_get_embedding.return_value = (None, None)
            mock_get_embedding_id.return_value = None
            
            # Mock locks that are not locked
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = False
            mock_embedding_lock.locked.return_value = False
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["current_chat_model"] == "google/gemma-2-9b-it"
            assert result["chat_model_loaded"] is True
            assert result["current_embedding_model"] == "None"
            assert result["embedding_model_loaded"] is False
            assert result["is_loading"] is False
    
    @pytest.mark.asyncio
    async def test_health_check_embedding_model_loaded(self):
        """
        Test health check when embedding model is loaded but chat model is not.
        
        Should show embedding model as loaded and chat model as not loaded.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock no chat model
            mock_get_llm.return_value = None
            mock_get_model_id.return_value = None
            
            # Mock embedding model loaded
            mock_embedding_model = Mock()
            mock_embedding_processor = Mock()
            mock_get_embedding.return_value = (mock_embedding_model, mock_embedding_processor)
            mock_get_embedding_id.return_value = "google/gemma-3-4b-it"
            
            # Mock locks that are not locked
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = False
            mock_embedding_lock.locked.return_value = False
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["current_chat_model"] == "None (Session not started)"
            assert result["chat_model_loaded"] is False
            assert result["current_embedding_model"] == "google/gemma-3-4b-it"
            assert result["embedding_model_loaded"] is True
            assert result["is_loading"] is False
    
    @pytest.mark.asyncio
    async def test_health_check_both_models_loaded(self):
        """
        Test health check when both chat and embedding models are loaded.
        
        Should show both models as loaded and provide their IDs.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock chat model loaded
            mock_llm_instance = Mock()
            mock_get_llm.return_value = mock_llm_instance
            mock_get_model_id.return_value = "google/gemma-2-9b-it"
            
            # Mock embedding model loaded
            mock_embedding_model = Mock()
            mock_embedding_processor = Mock()
            mock_get_embedding.return_value = (mock_embedding_model, mock_embedding_processor)
            mock_get_embedding_id.return_value = "google/gemma-3-4b-it"
            
            # Mock locks that are not locked
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = False
            mock_embedding_lock.locked.return_value = False
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["current_chat_model"] == "google/gemma-2-9b-it"
            assert result["chat_model_loaded"] is True
            assert result["current_embedding_model"] == "google/gemma-3-4b-it"
            assert result["embedding_model_loaded"] is True
            assert result["is_loading"] is False
    
    @pytest.mark.asyncio
    async def test_health_check_model_loading_in_progress(self):
        """
        Test health check when model loading is in progress.
        
        Should show is_loading as True when either lock is locked.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock no models loaded
            mock_get_llm.return_value = None
            mock_get_model_id.return_value = None
            mock_get_embedding.return_value = (None, None)
            mock_get_embedding_id.return_value = None
            
            # Mock one lock is locked (model loading in progress)
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = True  # This one is locked
            mock_embedding_lock.locked.return_value = False
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["is_loading"] is True
    
    @pytest.mark.asyncio
    async def test_health_check_embedding_loading_in_progress(self):
        """
        Test health check when embedding model loading is in progress.
        
        Should show is_loading as True when embedding lock is locked.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock no models loaded
            mock_get_llm.return_value = None
            mock_get_model_id.return_value = None
            mock_get_embedding.return_value = (None, None)
            mock_get_embedding_id.return_value = None
            
            # Mock embedding lock is locked
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = False
            mock_embedding_lock.locked.return_value = True  # This one is locked
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["is_loading"] is True
    
    @pytest.mark.asyncio
    async def test_health_check_both_locks_locked(self):
        """
        Test health check when both locks are locked.
        
        Should show is_loading as True when both locks are locked.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock no models loaded
            mock_get_llm.return_value = None
            mock_get_model_id.return_value = None
            mock_get_embedding.return_value = (None, None)
            mock_get_embedding_id.return_value = None
            
            # Mock both locks are locked
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = True
            mock_embedding_lock.locked.return_value = True
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Assertions
            assert result["status"] == "online"
            assert result["is_loading"] is True
    
    @pytest.mark.asyncio
    async def test_health_check_response_structure(self):
        """
        Test that health check always returns the expected response structure.
        
        Ensures all required fields are present regardless of model state.
        """
        with patch('routes.get_llm_instance') as mock_get_llm, \
             patch('routes.get_current_model_id') as mock_get_model_id, \
             patch('routes.get_embedding_model') as mock_get_embedding, \
             patch('routes.get_embedding_model_id') as mock_get_embedding_id, \
             patch('routes.get_locks') as mock_get_locks:
            
            # Mock any state
            mock_get_llm.return_value = None
            mock_get_model_id.return_value = None
            mock_get_embedding.return_value = (None, None)
            mock_get_embedding_id.return_value = None
            
            mock_model_lock = Mock()
            mock_embedding_lock = Mock()
            mock_model_lock.locked.return_value = False
            mock_embedding_lock.locked.return_value = False
            mock_get_locks.return_value = (mock_model_lock, mock_embedding_lock)
            
            # Call the function
            result = await health_check()
            
            # Check response structure
            required_fields = [
                "status",
                "current_chat_model", 
                "chat_model_loaded",
                "current_embedding_model",
                "embedding_model_loaded", 
                "is_loading"
            ]
            
            for field in required_fields:
                assert field in result, f"Missing required field: {field}"
            
            # Check field types
            assert isinstance(result["status"], str)
            assert isinstance(result["current_chat_model"], str)
            assert isinstance(result["chat_model_loaded"], bool)
            assert isinstance(result["current_embedding_model"], str)
            assert isinstance(result["embedding_model_loaded"], bool)
            assert isinstance(result["is_loading"], bool)


if __name__ == "__main__":
    # Run tests if file is executed directly
    import pytest
    pytest.main([__file__, "-v"])