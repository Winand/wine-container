<#
.SYNOPSIS
Build Wine Docker image.

.PARAMETER ns
Docker image namespace
.PARAMETER tag
Docker image name (default=python:3.12-wine)
.PARAMETER proxy
Proxy (all_proxy) to use during build (default="")
.PARAMETER version
Wine release version or GitHub Actions run ID (default="11.8")
.PARAMETER variant
Wine variant (default="staging-amd64")
#>
param (
    [string]$ns="",  # nexus.corp/project-name/
    [string]$tag="python:3.12-wine",
    [string]$proxy="",  # socks5://host.docker.internal:2080
    [string]$version="11.8",  # 25616547611
    [string]$variant="staging-amd64"
)

# docker build -t nexus.ocrv.com.rzd/asuv-kps/python:3.12-wine .
$env:GH_TOKEN = $(uvx keyring get com.docker.pass.shared:docker-pass-cli:GH_TOKEN GH_TOKEN
                      || uvx keyring get com.docker.pass:docker-pass-cli:GH_TOKEN GH_TOKEN)
docker build --build-arg all_proxy=$proxy --build-arg WINE_VERSION=$version --build-arg WINE_VARIANT=$variant --secret id=GH_TOKEN -t $ns$tag .
$env:GH_TOKEN=$null
