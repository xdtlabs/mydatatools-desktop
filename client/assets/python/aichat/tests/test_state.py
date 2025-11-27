"""
Unit tests for the state module.

This module tests all global state management functions including
getter/setter functions for model instances, IDs, and synchronization locks.
Tests verify thread-safe state access and proper state transitions.
"""
import pytest
import asyncio
from unittest.mock import Mock

from state import (
    get_llm_instance, set_llm_instance,
    get_current_model_id, set_current_model_id,
    get_embedding_model, set_embedding_model,
    get_embedding_model_id, set_embedding_model_id,
    get_locks
)


class TestLLMInstanceManagement:
    """Test suite for LLM instance getter/setter functions."""
    
    def test_get_llm_instance_initial_state(self):
        """Test that LLM instance is initially None."""
        # Reset state first
        set_llm_instance(None)
        result = get_llm_instance()
        assert result is None
    
    def test_set_and_get_llm_instance(self):
        """Test setting and getting LLM instance."""
        mock_llm = Mock()
        mock_llm.name = "test_llm"
        
        set_llm_instance(mock_llm)
        result = get_llm_instance()
        
        assert result is mock_llm
        assert result.name == "test_llm"
    
    def test_set_llm_instance_to_none(self):
        """Test clearing LLM instance by setting to None."""
        # First set a mock instance
        mock_llm = Mock()
        set_llm_instance(mock_llm)
        assert get_llm_instance() is mock_llm
        
        # Then clear it
        set_llm_instance(None)
        result = get_llm_instance()
        assert result is None
    
    def test_llm_instance_persistence(self):
        """Test that LLM instance persists across multiple gets."""
        mock_llm = Mock()
        set_llm_instance(mock_llm)
        
        # Multiple calls should return same instance
        result1 = get_llm_instance()
        result2 = get_llm_instance()
        result3 = get_llm_instance()
        
        assert result1 is mock_llm
        assert result2 is mock_llm
        assert result3 is mock_llm
        assert result1 is result2 is result3


class TestCurrentModelIdManagement:
    """Test suite for current model ID getter/setter functions."""
    
    def test_get_current_model_id_initial_state(self):
        """Test that current model ID is initially None."""
        set_current_model_id(None)
        result = get_current_model_id()
        assert result is None
    
    def test_set_and_get_current_model_id(self):
        """Test setting and getting current model ID."""
        model_id = "google/gemma-2-9b-it"
        
        set_current_model_id(model_id)
        result = get_current_model_id()
        
        assert result == model_id
    
    def test_set_current_model_id_different_formats(self):
        """Test setting model IDs in different formats."""
        test_cases = [
            "google/gemma-2-9b-it",
            "facebook/opt-1.3b",
            "microsoft/DialoGPT-medium",
            "simple-model-name",
            "org/sub/model"
        ]
        
        for model_id in test_cases:
            set_current_model_id(model_id)
            result = get_current_model_id()
            assert result == model_id
    
    def test_set_current_model_id_to_none(self):
        """Test clearing current model ID by setting to None."""
        # First set a model ID
        set_current_model_id("test/model")
        assert get_current_model_id() == "test/model"
        
        # Then clear it
        set_current_model_id(None)
        result = get_current_model_id()
        assert result is None
    
    def test_current_model_id_overwrite(self):
        """Test that setting a new model ID overwrites the previous one."""
        set_current_model_id("first/model")
        set_current_model_id("second/model")
        
        result = get_current_model_id()
        assert result == "second/model"


class TestEmbeddingModelManagement:
    """Test suite for embedding model getter/setter functions."""
    
    def test_get_embedding_model_initial_state(self):
        """Test that embedding model is initially (None, None)."""
        set_embedding_model(None, None)
        model, processor = get_embedding_model()
        assert model is None
        assert processor is None
    
    def test_set_and_get_embedding_model(self):
        """Test setting and getting embedding model and processor."""
        mock_model = Mock()
        mock_processor = Mock()
        mock_model.name = "test_embedding_model"
        mock_processor.name = "test_processor"
        
        set_embedding_model(mock_model, mock_processor)
        model, processor = get_embedding_model()
        
        assert model is mock_model
        assert processor is mock_processor
        assert model.name == "test_embedding_model"
        assert processor.name == "test_processor"
    
    def test_set_embedding_model_partial_none(self):
        """Test setting embedding model with one parameter as None."""
        mock_model = Mock()
        
        # Test model set, processor None
        set_embedding_model(mock_model, None)
        model, processor = get_embedding_model()
        assert model is mock_model
        assert processor is None
        
        # Test model None, processor set
        mock_processor = Mock()
        set_embedding_model(None, mock_processor)
        model, processor = get_embedding_model()
        assert model is None
        assert processor is mock_processor
    
    def test_set_embedding_model_to_none(self):
        """Test clearing embedding model by setting both to None."""
        # First set mock objects
        mock_model = Mock()
        mock_processor = Mock()
        set_embedding_model(mock_model, mock_processor)
        
        model, processor = get_embedding_model()
        assert model is mock_model
        assert processor is mock_processor
        
        # Then clear both
        set_embedding_model(None, None)
        model, processor = get_embedding_model()
        assert model is None
        assert processor is None
    
    def test_embedding_model_tuple_unpacking(self):
        """Test that get_embedding_model returns a proper tuple."""
        mock_model = Mock()
        mock_processor = Mock()
        set_embedding_model(mock_model, mock_processor)
        
        result = get_embedding_model()
        assert isinstance(result, tuple)
        assert len(result) == 2
        
        # Test tuple unpacking
        model, processor = result
        assert model is mock_model
        assert processor is mock_processor


class TestEmbeddingModelIdManagement:
    """Test suite for embedding model ID getter/setter functions."""
    
    def test_get_embedding_model_id_initial_state(self):
        """Test that embedding model ID is initially None."""
        set_embedding_model_id(None)
        result = get_embedding_model_id()
        assert result is None
    
    def test_set_and_get_embedding_model_id(self):
        """Test setting and getting embedding model ID."""
        model_id = "google/gemma-3-4b-it"
        
        set_embedding_model_id(model_id)
        result = get_embedding_model_id()
        
        assert result == model_id
    
    def test_set_embedding_model_id_different_formats(self):
        """Test setting embedding model IDs in different formats."""
        test_cases = [
            "google/gemma-3-4b-it",
            "openai/clip-vit-base-patch32",
            "sentence-transformers/all-MiniLM-L6-v2",
            "custom-embedding-model"
        ]
        
        for model_id in test_cases:
            set_embedding_model_id(model_id)
            result = get_embedding_model_id()
            assert result == model_id
    
    def test_set_embedding_model_id_to_none(self):
        """Test clearing embedding model ID by setting to None."""
        # First set an embedding model ID
        set_embedding_model_id("test/embedding-model")
        assert get_embedding_model_id() == "test/embedding-model"
        
        # Then clear it
        set_embedding_model_id(None)
        result = get_embedding_model_id()
        assert result is None


class TestLocksManagement:
    """Test suite for locks getter function."""
    
    def test_get_locks_returns_tuple(self):
        """Test that get_locks returns a tuple of two locks."""
        locks = get_locks()
        assert isinstance(locks, tuple)
        assert len(locks) == 2
    
    def test_get_locks_returns_asyncio_locks(self):
        """Test that get_locks returns asyncio.Lock objects."""
        model_lock, embedding_lock = get_locks()
        
        assert isinstance(model_lock, asyncio.Lock)
        assert isinstance(embedding_lock, asyncio.Lock)
    
    def test_get_locks_consistency(self):
        """Test that get_locks returns the same lock instances on multiple calls."""
        locks1 = get_locks()
        locks2 = get_locks()
        locks3 = get_locks()
        
        # Should return the same lock objects
        assert locks1[0] is locks2[0] is locks3[0]  # model_lock
        assert locks1[1] is locks2[1] is locks3[1]  # embedding_lock
    
    def test_get_locks_unpacking(self):
        """Test proper unpacking of locks tuple."""
        model_lock, embedding_lock = get_locks()
        
        # Should be different lock instances
        assert model_lock is not embedding_lock
        
        # Both should be Lock objects
        assert isinstance(model_lock, asyncio.Lock)
        assert isinstance(embedding_lock, asyncio.Lock)
    
    @pytest.mark.asyncio
    async def test_locks_functionality(self):
        """Test that the returned locks actually function as async locks."""
        model_lock, embedding_lock = get_locks()
        
        # Test that locks can be acquired and released
        async with model_lock:
            assert model_lock.locked()
        
        assert not model_lock.locked()
        
        async with embedding_lock:
            assert embedding_lock.locked()
        
        assert not embedding_lock.locked()


class TestStateIntegration:
    """Integration tests for state management functions."""
    
    def test_independent_state_management(self):
        """Test that different state variables are managed independently."""
        # Set up different states
        mock_llm = Mock()
        mock_model = Mock()
        mock_processor = Mock()
        
        set_llm_instance(mock_llm)
        set_current_model_id("chat/model")
        set_embedding_model(mock_model, mock_processor)
        set_embedding_model_id("embedding/model")
        
        # Verify all states are correct
        assert get_llm_instance() is mock_llm
        assert get_current_model_id() == "chat/model"
        
        embedding_model, embedding_processor = get_embedding_model()
        assert embedding_model is mock_model
        assert embedding_processor is mock_processor
        assert get_embedding_model_id() == "embedding/model"
        
        # Clear one state, others should remain
        set_current_model_id(None)
        
        assert get_llm_instance() is mock_llm  # Should still be set
        assert get_current_model_id() is None  # Should be cleared
        assert get_embedding_model() == (mock_model, mock_processor)  # Should still be set
        assert get_embedding_model_id() == "embedding/model"  # Should still be set
    
    def test_state_reset(self):
        """Test resetting all state to initial conditions."""
        # Set up all states
        mock_llm = Mock()
        mock_model = Mock()
        mock_processor = Mock()
        
        set_llm_instance(mock_llm)
        set_current_model_id("chat/model")
        set_embedding_model(mock_model, mock_processor)
        set_embedding_model_id("embedding/model")
        
        # Reset all states
        set_llm_instance(None)
        set_current_model_id(None)
        set_embedding_model(None, None)
        set_embedding_model_id(None)
        
        # Verify all states are cleared
        assert get_llm_instance() is None
        assert get_current_model_id() is None
        assert get_embedding_model() == (None, None)
        assert get_embedding_model_id() is None


if __name__ == "__main__":
    # Run tests if file is executed directly
    pytest.main([__file__, "-v"])