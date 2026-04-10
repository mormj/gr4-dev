ARG BASE_IMAGE=gr4-dev/ubuntu-24.04-base:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    clang-18 \
    lld-18 \
    llvm-18 \
  && rm -rf /var/lib/apt/lists/*

ENV CC=clang-18
ENV CXX=clang++-18
