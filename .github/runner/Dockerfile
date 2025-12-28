FROM fedora:43

# Install build dependencies for native Linux and Windows cross-compilation
RUN dnf install -y \
    gcc gcc-c++ make \
    mingw64-gcc mingw64-gcc-c++ mingw64-winpthreads-static \
    curl tar gzip \
    git \
    && dnf clean all

# Create runner user (don't run as root for security)
RUN useradd -m -s /bin/bash runner
USER runner
WORKDIR /home/runner

# Download and extract GitHub Actions runner
# Version should match latest from: https://github.com/actions/runner/releases
RUN curl -o actions-runner-linux-x64-2.321.0.tar.gz \
    -L https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-linux-x64-2.321.0.tar.gz \
    && tar xzf actions-runner-linux-x64-2.321.0.tar.gz \
    && rm actions-runner-linux-x64-2.321.0.tar.gz

# SDK will be mounted at /sdk (read-only) when container runs
# Build workflows will symlink /sdk to workspace library/sdk before building

# Entrypoint runs the GitHub Actions runner
CMD ["./run.sh"]
