ARG WINE_VERSION="11.7"
ARG WINE_VARIANT="staging-tkg-amd64" # amd64, staging-amd64
ARG UV_VERSION="0.11.7"


FROM debian:trixie-slim AS download
ARG WINE_VERSION
ARG WINE_VARIANT
ARG UV_VERSION
# RUN sed -i 's/deb.debian.org/mirror.yandex.ru/g' /etc/apt/sources.list.d/debian.sources

RUN apt update && \
    apt install -y --no-install-recommends ca-certificates wget unzip xz-utils rdfind locales && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/wine && \
    wget -q -O- https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/wine-${WINE_VERSION}-${WINE_VARIANT}.tar.xz \
    | tar -xJ -C /opt/wine/ --strip-components=1 && \
    find /opt/wine/lib/wine -name "*.a" -delete && \
    rm -rf /opt/wine/include

RUN wget -q -O /tmp/uv.zip https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-pc-windows-msvc.zip && \
    unzip -j /tmp/uv.zip uv.exe -d /tmp && \
    rm /tmp/uv.zip

# RUN echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
#     echo "ru_RU.UTF-8 UTF-8" > /etc/locale.gen && \
#     locale-gen


FROM debian:trixie-slim
# RUN sed -i 's/deb.debian.org/mirror.yandex.ru/g' /etc/apt/sources.list.d/debian.sources
# libc6:i386 is required
# libfreetype6 addresses warning "cannot find the FreeType font library"
# libgnutls30 for "failed to load libgnutls, no support for pfx import/export"
RUN dpkg --add-architecture i386 && apt update && \
    apt install -y --no-install-recommends \
        libc6:i386 libfreetype6 libfreetype6:i386 libgnutls30 \
        libxrender1 libxext6 libgl1 libegl1  && \
    rm -rf /var/lib/apt/lists/*

# COPY --from=download /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive

RUN groupadd --system wine && \
    useradd --system -m -g wine wine
USER wine
WORKDIR /home/wine

ENV LC_ALL="C.utf8"
ENV PATH="/home/wine/.local/bin:$PATH"
ENV WINEPATH="C:\users\wine\.local\bin"

RUN --mount=from=download,source=/usr/bin/rdfind,target=/usr/bin/rdfind \
    --mount=from=download,source=/opt/wine,target=/tmp/wine \
    mkdir $HOME/.local && \
    cp -ra /tmp/wine/. $HOME/.local && \
    wineboot --init && wineserver --wait && \
    rdfind -makehardlinks true -makeresultsfile false $HOME/.local $HOME/.wine

RUN mkdir -p $(winepath -u $WINEPATH)
RUN --mount=from=download,source=/tmp/uv.exe,target=/home/wine/.wine/drive_c/users/wine/.local/bin/uv.exe \
    wine uv python install 3.12

# FIX: Create a symlink cpython-3.12-windows-x86_64-none -> cpython-3.12.13-windows-x86_64-none,
# because junctions are not supported in Wine on older kernels like CentOS7 3.10 kernel.
# Otherwise ~/.wine/drive_c/users/wine/.local/bin/python3.12.exe won't start.
RUN PYTHON=$(find "$HOME/.wine/drive_c/users/wine/AppData/Roaming/uv/python" -maxdepth 2 -not -type l -name "python.exe" | head -n 1 | xargs dirname) && \
    PYTHON_MAJMIN=$(echo $PYTHON | sed 's/\([0-9]*\.[0-9]*\)\.[0-9]*/\1/') && \
    ln -s $PYTHON $PYTHON_MAJMIN

# COPY --from=download --chown=wine:wine /tmp/uv.exe /home/wine/.wine/drive_c/users/wine/.local/bin/uv.exe

# CMD ["wine", "cmd"]
CMD [ "bash" ]
