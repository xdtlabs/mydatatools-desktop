import sys
import os

# Add the src directory to the python path so we can import the aichat package
sys.path.append(os.path.join(os.path.dirname(__file__), "src"))

from aichat.main import main

if __name__ == "__main__":
    main()