FROM ubuntu:20.04 AS build-lsquic

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
    apt-get install -y apt-utils build-essential git software-properties-common \
                       zlib1g-dev libevent-dev wget

# Install CMake 3.22 or higher (required by BoringSSL)
RUN wget https://github.com/Kitware/CMake/releases/download/v3.22.0/cmake-3.22.0-linux-x86_64.sh && \
    echo "b23922a3416bb21b31735ec0179b72b3f219e94c78748ff0c163640a5881bdf3  cmake-3.22.0-linux-x86_64.sh" | sha256sum -c && \
    chmod +x cmake-3.22.0-linux-x86_64.sh && \
    ./cmake-3.22.0-linux-x86_64.sh --skip-license --prefix=/usr/local && \
    rm cmake-3.22.0-linux-x86_64.sh

RUN add-apt-repository ppa:longsleep/golang-backports && \
    apt-get update && \
    apt-get install -y golang-1.21-go && \
    cp /usr/lib/go-1.21/bin/go* /usr/bin/.

ENV GOROOT /usr/lib/go-1.21

RUN mkdir /src
WORKDIR /src

RUN mkdir /src/lsquic
COPY ./ /src/lsquic/

RUN git clone --depth=1 https://github.com/google/boringssl.git && \
    cd boringssl && \
    cmake . && \
    make

ENV EXTRA_CFLAGS -DLSQUIC_QIR=1
RUN cd /src/lsquic && \
    cmake -DLIBSSL_DIR=/src/boringssl . && \
    make

RUN cd lsquic && cp bin/http_client /usr/bin/ && cp bin/http_server /usr/bin

FROM martenseemann/quic-network-simulator-endpoint:latest AS lsquic-qir
COPY --from=build-lsquic /usr/bin/http_client /usr/bin/http_server /usr/bin/
COPY qir/run_endpoint.sh .
RUN chmod +x run_endpoint.sh
ENTRYPOINT [ "./run_endpoint.sh" ]
