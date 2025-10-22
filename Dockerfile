FROM ubuntu:latest

ENV DEBIAN_FRONTEND=noninteractive \
    GO_VERSION=1.25.3 \
    GOLANG_VERSION=1.25.3 \
    GOPATH=/root/go \
    PATH=/root/go/bin:/usr/local/go/bin:$PATH \
    NVM_DIR=/root/.nvm \
    NODE_VERSION=20.11.0

LABEL maintainer="Fuzzing Tools Container" \
      description="Complete fuzzing toolkit with all major tools"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        # Build essentials
        build-essential \
        cmake \
        make \
        gcc \
        g++ \
        # Network & Download tools
        curl \
        wget \
        git \
        # Python & dependencies
        python3 \
        python3-pip \
        python3-dev \
        python3-setuptools \
        # Ruby & dependencies
        ruby \
        ruby-dev \
        # Libraries
        libpcap-dev \
        libssl-dev \
        libffi-dev \
        libxml2 \
        libxml2-dev \
        libxslt1-dev \
        libcurl4-openssl-dev \
        gem \
        # Network tools
        nmap \
        net-tools \
        dnsutils \
        # Other utilities
        unzip \
        zip \
        jq \
        ca-certificates \
        apt-transport-https \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*


RUN wget https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz && \
    rm go${GO_VERSION}.linux-amd64.tar.gz && \
    mkdir -p $GOPATH/bin && \
    go version


RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . $NVM_DIR/nvm.sh && \
    nvm install $NODE_VERSION && \
    nvm use $NODE_VERSION && \
    nvm alias default $NODE_VERSION

# ==================== PROJECTDISCOVERY TOOLS ====================
RUN echo "Installing ProjectDiscovery tools..." && \
    go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest && \
    go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest && \
    go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest && \
    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest && \
    go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest && \
    go install -v github.com/projectdiscovery/katana/cmd/katana@latest && \
    go install -v github.com/hahwul/dalfox/v2@latest && \
    # Tải nuclei templates
    nuclei -update-templates || true

# ==================== GO-BASED FUZZING TOOLS ====================
RUN echo "Installing Go-based fuzzing tools..." && \
    # ffuf - Fast web fuzzer
    go install -v github.com/ffuf/ffuf/v2@latest && \
    # gobuster - Directory/File & DNS busting
    go install -v github.com/OJ/gobuster/v3@latest && \
    # feroxbuster (Rust-based, will use prebuilt binary)
    # amass - Attack surface mapping
    go install -v github.com/owasp-amass/amass/v4/...@master && \
    # gau - Get All URLs
    go install -v github.com/lc/gau/v2/cmd/gau@latest && \
    # uro - URL deduplication
    go install -v github.com/s0md3v/uro@latest || \
    pip3 install uro --break-system-packages && \
    # subjack - Subdomain takeover
    go install -v github.com/haccer/subjack@latest && \
	# httprobe - HTTP probe for finding live hosts
	go install -v github.com/tomnomnom/httprobe@latest

# ==================== BASH SCRIPTS ====================
RUN echo "Installing Bash-based tools..." && \
    # crt.sh - Certificate transparency subdomain finder
    git clone --depth 1 https://github.com/az7rb/crt.sh.git /opt/crtsh && \
    chmod +x /opt/crtsh/*.sh && \
    ln -s /opt/crtsh/crt_v2.sh /usr/local/bin/crtsh && \
    ln -s /opt/crtsh/crt.sh /usr/local/bin/crtsh-v1

    
# ==================== PYTHON-BASED TOOLS ====================
RUN echo "Installing Python-based tools..." && \
    # SQLMap - SQL injection tool
    git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git /opt/sqlmap && \
    ln -s /opt/sqlmap/sqlmap.py /usr/local/bin/sqlmap

# install pipx
RUN apt update && apt install -y --no-install-recommends python3-venv pipx
RUN python3 -m pipx ensurepath && pipx completions
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> /etc/profile.d/pipx.sh

# install dirsearch
RUN pipx install dirsearch

# install waymore
RUN pipx install waymore

# enum4linux-ng
RUN pipx install "git+https://github.com/cddmp/enum4linux-ng.git" 

# ldapsearch-ad
RUN git clone --depth 1 https://github.com/yaap7/ldapsearch-ad.git /opt/ldapsearch-ad && \
    cd /opt/ldapsearch-ad && pip3 install -r requirements.txt --break-system-packages && \
    ln -s /opt/ldapsearch-ad/ldapsearch-ad.py /usr/local/bin/ldapsearch-ad

# ldapdomaindump
RUN pipx install ldapdomaindump

# Certipy - Active Directory certificate abuse
RUN pipx install certipy-ad

# ==================== RUBY-BASED TOOLS ====================
RUN echo "Installing Ruby-based tools..." && \
    # WPScan - WordPress vulnerability scanner
    gem install wpscan

# ==================== RUST-BASED TOOLS (via prebuilt binary) ====================
RUN echo "Installing Rust-based tools..." && \
    # feroxbuster
    FEROX_VERSION=$(curl -s https://api.github.com/repos/epi052/feroxbuster/releases/latest | grep 'tag_name' | cut -d'"' -f4 | sed 's/v//') && \
    wget https://github.com/epi052/feroxbuster/releases/latest/download/x86_64-linux-feroxbuster.zip -O /tmp/feroxbuster.zip && \
    unzip /tmp/feroxbuster.zip -d /tmp && \
    mv /tmp/feroxbuster /usr/local/bin/ && \
    chmod +x /usr/local/bin/feroxbuster && \
    rm /tmp/feroxbuster.zip

# ==================== WORDLISTS - SecLists ====================
RUN echo "Installing SecLists wordlists..." && \
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git /opt/SecLists

# install impacket
RUN pipx install impacket
ENV PATH="${PATH}:/root/.local/share/pipx/venvs/impacket/bin"

# ==================== FINAL SETUP ====================

RUN mkdir -p /root/workspace /root/.config
RUN pipx runpip dirsearch install 'setuptools<81'

RUN pipx ensurepath

# fix path sqlmap
RUN sed -i '1s|^#![[:space:]]*/usr/bin/env[[:space:]]*python$|#!/usr/bin/env python3|' /opt/sqlmap/sqlmap.py

ENV PATH="${PATH}:/opt/sqlmap:/opt/dirsearch:/opt/enum4linux-ng:/opt/ldapsearch-ad:/root/.local/bin:/opt/venv/bin"

# Working directory
WORKDIR /root/workspace

# Verify installations
RUN echo "Verifying tool installations..." && \
    echo "=== ProjectDiscovery Tools ===" && \
    nuclei -version || echo "nuclei: FAILED" && \
    naabu -version || echo "naabu: FAILED" && \
    httpx -version || echo "httpx: FAILED" && \
    subfinder -version || echo "subfinder: FAILED" && \
    dnsx -version || echo "dnsx: FAILED" && \
    katana -version || echo "katana: FAILED" && \
    echo "=== Fuzzing Tools ===" && \
    ffuf -V || echo "ffuf: FAILED" && \
    gobuster --version || echo "gobuster: FAILED" && \
    feroxbuster --version || echo "feroxbuster: FAILED" && \
    echo "=== Other Tools ===" && \
    sqlmap --version || echo "sqlmap: FAILED" && \
    nmap --version || echo "nmap: FAILED" && \
    dirsearch --version || echo "dirsearch: FAILED" && \
    wpscan --version || echo "wpscan: FAILED" && \
    amass --version || echo "amass: FAILED" && \
    gau --version || echo "gau: FAILED" && \
    subjack --version || echo "subjack: FAILED" && \
    certipy --version || echo "certipy: FAILED" && \
    echo "=== Wordlists ===" && \
    ls -lh /opt/SecLists | head -10 && \
    echo "=== All tools installed! ==="

# Display help on container start
CMD ["bash", "-c", "echo '=========================' && \
    echo 'Fuzzing Tools Container' && \
    echo '=========================' && \
    echo '' && \
    echo 'Available Tools:' && \
    echo '  ProjectDiscovery: nuclei, naabu, httpx, subfinder, dnsx, katana' && \
    echo '  Fuzzers: ffuf, gobuster, feroxbuster, dirsearch' && \
    echo '  Scanners: sqlmap, nmap, wpscan, amass' && \
    echo '  AD Tools: enum4linux-ng, ldapsearch-ad, ldapdomaindump, certipy' && \
    echo '  URL Tools: gau, uro, waymore, subjack' && \
    echo '' && \
    echo 'Wordlists: /opt/SecLists' && \
    echo 'Workspace: /root/workspace' && \
    echo '=========================' && \
    exec /bin/bash"]

