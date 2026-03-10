## Build

PDM is simply a package manager (like Node's NPM) that installs Python dependencies. Zipping the PDM project folder only zips raw source code; it **does not** create an executable.

To create the standalone `aichat` executable that your Flutter app expects to run, you must compile the code using `PyInstaller`.
```bash
cd client/assets/python/aichat

# 1. Install dependencies
pdm install

# 2. Compile the executable
pdm run pyinstaller main.spec

# 3. Zip the compiled output for Flutter
cd dist/aichat
zip -r ../../../../../app/aichat-macos.zip .
cd ../../../../../app/

# 4. Copy to your application support directory to test locally
cp ./*.zip ~/Library/Application\ Support/mydata.tools/aichat/
```
```bash
# cd ../../../
# dart run serious_python:main package --asset app/aichat-darwin.zip -r -r -r assets/python/aichat/requirements.txt assets/python/aichat -p Darwin
```

### Find open port
```bash
python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
```
    