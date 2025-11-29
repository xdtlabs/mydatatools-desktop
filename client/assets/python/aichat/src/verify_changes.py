import sys
import os

# Add src to path
sys.path.append('/Users/mikenimer/Development/github/mydatatools-desktop/client/assets/python/aichat/src')

try:
    from aichat.state import get_session_model, set_session_model
    print("state.py imports: OK")
except ImportError as e:
    print(f"state.py imports failed: {e}")

try:
    from aichat.model_manager import load_gemini_model
    print("model_manager.py imports: OK")
except ImportError as e:
    print(f"model_manager.py imports failed: {e}")

try:
    from aichat.routes import start_session, generate_chat_response
    print("routes.py imports: OK")
except ImportError as e:
    print(f"routes.py imports failed: {e}")
