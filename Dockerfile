# ============================================================
# Stage 1: Build llama.cpp
# ============================================================
FROM debian:bookworm-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    ca-certificates \
    libcurl4-openssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git

WORKDIR /src/llama.cpp

RUN cmake -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DLLAMA_CURL=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DLLAMA_BUILD_EXAMPLES=OFF \
    -DLLAMA_BUILD_SERVER=ON

RUN cmake --build build \
    --config Release \
    --target llama-server \
    -j2


# ============================================================
# Stage 2: Runtime
# ============================================================
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime libraries only
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libcurl4 \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app


# ============================================================
# Copy llama.cpp binaries + shared libraries
# ============================================================

COPY --from=builder /src/llama.cpp/build/bin/ /app/bin/

ENV PATH="/app/bin:${PATH}"
ENV LD_LIBRARY_PATH="/app/bin"


# ============================================================
# Download model
# ============================================================

ARG MODEL_URL="https://huggingface.co/unsloth/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf"

RUN mkdir -p /app/models && \
    curl -L \
    --fail \
    --retry 3 \
    --retry-delay 2 \
    -o /app/models/smollm2-135m-instruct-q4_k_m.gguf \
    "${MODEL_URL}"


# ============================================================
# Render
# ============================================================

EXPOSE 10000


# ============================================================
# Start llama-server
# ============================================================

CMD ["/bin/sh", "-c", \
    "llama-server \
    --model /app/models/smollm2-135m-instruct-q4_k_m.gguf \
    --host 0.0.0.0 \
    --port ${PORT:-10000} \
    --ctx-size 512 \
    --threads 1 \
    --threads-batch 1 \
    --batch-size 32 \
    --ubatch-size 32 \
    --parallel 1 \
    --n-predict 128 \
    --no-webui"]