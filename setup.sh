#!/bin/bash

# 스크립트 실행 중 에러가 발생하면 즉시 중단
set -e

# 1. pip install
echo "--- Installing packages from requirement.txt ---"
cd /workspace/poc_jci_anomalydiffusion
pip install -r requirement.txt

# 2. taming-transformers install
echo "--- Installing taming-transformers from source ---"
cd /workspace

if [ -d "taming-transformers" ]; then
    echo "Removing existing taming-transformers directory..."
    rm -rf taming-transformers
fi
git clone https://github.com/CompVis/taming-transformers.git
cd taming-transformers
python -m pip install -e .

# 3. system libraries install
echo "--- Installing system libraries (libgl1, libglib2) ---"
apt-get update && apt-get install -y libgl1-mesa-glx libglib2.0-0

echo "--- Setup complete! ---"
