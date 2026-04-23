# Containerized wine
This base image contains a minimal [wine](https://github.com/Kron4ek/Wine-Builds)
installation and Python for Windows (`wine python3.12`).
The image size is minimized to about 1GB using hardlinks in wine prefix path.

The primary purpose is to run Python CLI applications:
```bash
wine python3.12 -m venv venv
wine venv/Scripts/pip.exe install package_name
```

If uv is needed it can be mounted during new image build as shown in [Dockerfile](Dockerfile).

## Running GUI application
Start an X Server on the host machine, e.g. MobaXterm X server.
Start a container with `DISPLAY` variable set to the host IP:
```bash
docker run -it --rm -e DISPLAY=192.168.1.100:0.0 -u root wine-container
```

Install and start xterm (as an example):
```bash
apt update && apt install xterm
xterm
```

## See Also
- [webcomics/pywine](https://github.com/webcomics/pywine)
- [tymonx/pywine](https://gitlab.com/tymonx/pywine) |
[Reddit thread](https://www.reddit.com/r/Python/comments/1mmow8a/pywine_containerized_wine_with_python_to_test/)
- [Kron4ek/Wine-Builds](https://github.com/Kron4ek/Wine-Builds)
