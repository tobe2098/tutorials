# Installation of a functional llm chat in your linux server using llama.cpp
Start by cloning the `git clone https://github.com/ggml-org/llama.cpp`
## CPU-only installation
1. Install OpenBLAS
2. `cmake .. -DBUILD_SHARED_LIBS=OFF -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS` from .../llama.cpp/build

## GPU (nvidia) installation
### CUDA
1. Check which GPU you have and the recommended drivers (in Ubuntu with `ubuntu-drivers devices`). Write down the compute capability of your GPU in [nvidia](https://developer.nvidia.com/cuda-gpus#compute).
2. Check in [nvidia docs](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html) which toolkit is the latest that is still compatible with your drivers
3. After installing the proper driver, _only_ then, install the toolkit version.

### Compiling llama.cpp
1. Now go into /llama.cpp/build/
2. `sudo cmake .. -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="" -DCMAKE_CUDA_COMPILER=$(which nvcc)` where the arch argument is the compute capability times 10.
3. `sudo cmake --build . --config Release`

## Model installation
1. Just git clone from hugging-face with git-lfs installed and enabled
`python3 convert_hf_to_gguf.py --model-name DeepSeek-R1-Distill-Llama-8B --outfile /opt/llm-chat/models/R1_Distill-Llama-8B.gguf ../models/DeepSeek-R1-Distill-Llama-8B`

- For quantization, go [here](https://github.com/ggml-org/llama.cpp/blob/master/examples/quantize/README.md)

## Script and configuration
1. Clone this repo (or copy the script for safety reasons)
2. Permission to execute for all users that you want them to use the llm_chat
3. Edit the llm_chat script with the path to your .../models/ folder.
4. Set-up the config.json with your own tweaks. Set the path in the script to find the config.json.
5. Link the script to the /usr/local/bin/ folder using: `ln -s /opt/llm-chat/linux_server/llm-chat llm_chat`
6. Enjoy!