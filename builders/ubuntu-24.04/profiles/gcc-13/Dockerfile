ARG BASE_IMAGE=gr4-dev/ubuntu-24.04-base:latest
FROM ${BASE_IMAGE}

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc-13 \
    g++-13 \
  && rm -rf /var/lib/apt/lists/*

ENV CC=gcc-13
ENV CXX=g++-13
