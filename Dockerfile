FROM ubuntu:18.04

RUN apt-get update && apt-get install -y build-essential clang wget

ARG USER_ID
ARG GROUP_ID

RUN useradd -ms /bin/bash -u ${USER_ID} tester

RUN apt-get install -y clang

USER tester

WORKDIR /home/tester

RUN wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh

RUN chmod +x Miniconda3-latest-Linux-x86_64.sh && \
./Miniconda3-latest-Linux-x86_64.sh -b -p /home/tester/miniconda3

ENV PATH=$PATH:/home/tester/miniconda3/bin

RUN conda install -c fragcolor nim=0.19.9

COPY --chown=tester ./ /home/tester/fragments

WORKDIR /home/tester/fragments

ENV HOME=/home/tester
