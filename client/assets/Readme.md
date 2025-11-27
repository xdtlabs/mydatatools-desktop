## Build
```bash
cd client/assets/python/aichat
pdm install --no-self
zip -r ../../../app/aichat.zip . -x "*.tar.gz" -x ".pytest_cache/*"  -x ".pdm-python/*" -x "google-*/*" -x ".git/*"
```

### Build with serious_python
```bash
# cd ../../../
# dart run serious_python:main package --asset app/aichat-darwin.zip -r -r -r assets/python/aichat/requirements.txt assets/python/aichat -p Darwin
```

### Find open port
```bash
python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
```
    