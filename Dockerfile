ARG WINE_VERSION="11.8"
ARG WINE_VARIANT="staging-tkg-amd64" # amd64, staging-amd64
ARG UV_VERSION="0.11.13"


FROM debian:trixie-slim AS download
ARG WINE_VERSION
ARG WINE_VARIANT
ARG UV_VERSION
# RUN sed -i 's/deb.debian.org/mirror.yandex.ru/g' /etc/apt/sources.list.d/debian.sources

RUN apt update && \
    apt install -y --no-install-recommends ca-certificates wget unzip xz-utils rdfind locales jq && \
    rm -rf /var/lib/apt/lists/*

# Create GitHub token on page https://github.com/settings/personal-access-tokens
# Put token into secrets `docker pass set GH_TOKEN=github_pat_***`
# Load token in an env var `$env:GH_TOKEN=$(uvx keyring get com.docker.pass.shared:docker-pass-cli:GH_TOKEN GH_TOKEN)`
#
# Test for integer number: https://stackoverflow.com/a/19116862
# NOTE: wget 1.25 passes Authorization header to redirects too, so max-redirect=0 is used
RUN --mount=type=secret,id=GH_TOKEN \
    mkdir -p /opt/wine && \
    if [ ${WINE_VERSION} -eq ${WINE_VERSION} ]; then \
        GH_TOKEN=$(cat /run/secrets/GH_TOKEN); \
        ARTIFACT_URL=$(wget -q -O- "https://api.github.com/repos/Kron4ek/Wine-Builds/actions/runs/${WINE_VERSION}" \
                       | jq -r .artifacts_url | wget -q -i- -O- | jq -r '.artifacts[0] | .archive_download_url'); \
        wget --max-redirect=0 --header="Authorization: Bearer ${GH_TOKEN}" "$ARTIFACT_URL" 2>&1 \
            | grep -i "Location:" | awk '{print $2}' | wget -i- -O /tmp/wine.zip; \
        echo $(ls -l /tmp); \
        unzip -l /tmp/wine.zip | grep -P "wine-git-\w+-${WINE_VARIANT}.tar.xz" | awk '{print $4}' \
            | xargs unzip -p /tmp/wine.zip | tar -xJ -C /opt/wine --strip-components=1; \
        rm /tmp/wine.zip; \
    else \
        wget -q -O- https://github.com/Kron4ek/Wine-Builds/releases/download/${WINE_VERSION}/wine-${WINE_VERSION}-${WINE_VARIANT}.tar.xz \
        | tar -xJ -C /opt/wine/ --strip-components=1; \
    fi && \
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
# Astral.sh may not be available so download Python from GitHub directly
RUN --mount=from=download,source=/tmp/uv.exe,target=/home/wine/.wine/drive_c/users/wine/.local/bin/uv.exe \
    wine uv python install -v --mirror https://github.com/astral-sh/python-build-standalone/releases/download 3.12

# Fixed: Create a symlink cpython-3.12-windows-x86_64-none -> cpython-3.12.13-windows-x86_64-none,
# because junctions are not supported in Wine on older kernels like CentOS7 3.10 kernel.
# Otherwise ~/.wine/drive_c/users/wine/.local/bin/python3.12.exe won't start.
RUN PYTHON=$(find "$HOME/.wine/drive_c/users/wine/AppData/Roaming/uv/python" -maxdepth 2 -not -type l -name "python.exe" | head -n 1 | xargs dirname) && \
    PYTHON_MAJMIN=$(echo $PYTHON | sed 's/\([0-9]*\.[0-9]*\)\.[0-9]*/\1/') && \
    ln -s $PYTHON $PYTHON_MAJMIN

# COPY --from=download --chown=wine:wine /tmp/uv.exe /home/wine/.wine/drive_c/users/wine/.local/bin/uv.exe

# CMD ["wine", "cmd"]
CMD [ "bash" ]
