# linux_server
Guide to set up your own linux server and to be able to access it from anywhere

## Router
1. Set fixed IP for the device
2. Use port forwarding from your router
3. Set up your ssh with the router IP and the port
4. Set up the keys
5. 

## Llama.cpp
Just git clone with git-lfs installed and enabled
python3 convert_hf_to_gguf.py --model-name DeepSeek-R1-Distill-Llama-8B --outfile /opt/llm-chat/models/R1_Distill-Llama-8B.gguf ../models/DeepSeek-R1-Distill-Llama-8B
### CPU-only
cmake -DBUILD_SHARED_LIBS=OFF -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS
### GPU
update cuda toolkit
sudo cmake .. -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="50" -DCMAKE_CUDA_COMPILER=$(which nvcc)
sudo cmake --build . --config Release

## Script
- Create chat.py
- Permission to execute
- Create a bash script that runs it in /usr/local/bin/
