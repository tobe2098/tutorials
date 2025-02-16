# linux_server
Guide to set up your own linux server and to be able to access it from anywhere

## Router
1. Set fixed IP for the device
2. Use port forwarding from your router
3. Set up your ssh with the router IP and the port
4. Set up the keys
5. 

## LLama.cpp
### CPU-only
cmake -DBUILD_SHARED_LIBS=OFF -DGGML_BLAS=ON -DGGML_BLAS_VENDOR=OpenBLAS
### GPU
update cuda toolkit
sudo cmake .. -DBUILD_SHARED_LIBS=OFF -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES="50" -DCMAKE_CUDA_COMPILER=$(which nvcc)
sudo cmake --build . --config Release
