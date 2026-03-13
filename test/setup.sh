#!/usr/bin/env bash
# =============================================================================
# shiny-enigma — Minecraft Test Server Setup
# Tested on: Bazzite (Fedora immutable / rpm-ostree)
#
# What this does:
#   1. Checks / installs Java 21
#   2. Downloads latest Paper server
#   3. Downloads all required plugins (Skript, WorldGuard, WorldEdit,
#      LuckPerms, Citizens)
#   4. Copies the .sk scripts into the server
#   5. Pre-configures server.properties (RCON enabled, offline mode)
#
# Usage:  bash test/setup.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="$SCRIPT_DIR/server"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# =============================================================================
# 1. Java 21
# =============================================================================
info "Checking Java..."
if java -version 2>&1 | grep -q 'version "2[1-9]'; then
    info "Java 21+ already installed: $(java -version 2>&1 | head -1)"
else
    warn "Java 21 not found. Installing..."

    if command -v rpm-ostree &>/dev/null; then
        # Bazzite / immutable Fedora — uses layered packages
        info "Detected Bazzite/rpm-ostree. Installing java-21-openjdk-headless..."
        warn "This requires a reboot after installation on immutable Fedora!"
        rpm-ostree install java-21-openjdk-headless
        warn "Reboot your machine, then re-run this script."
        exit 0
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y java-21-openjdk-headless
    elif command -v apt-get &>/dev/null; then
        sudo apt-get install -y openjdk-21-jre-headless
    else
        error "Cannot install Java automatically. Please install Java 21 manually."
    fi
fi

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [[ "$JAVA_VERSION" -lt 21 ]]; then
    error "Java 21 or newer is required (found: $JAVA_VERSION). Please upgrade."
fi

# =============================================================================
# 2. Create server directory
# =============================================================================
mkdir -p "$SERVER_DIR/plugins"
cd "$SERVER_DIR"
info "Server directory: $SERVER_DIR"

# =============================================================================
# 3. Download Paper (latest 1.21.4)
# =============================================================================
PAPER_VERSION="1.21.4"

if [[ ! -f "paper.jar" ]]; then
    info "Fetching latest Paper build for $PAPER_VERSION..."
    PAPER_BUILD=$(curl -fsSL \
        "https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds" \
        | python3 -c "import sys,json; builds=json.load(sys.stdin)['builds']; print(builds[-1]['build'])")
    info "Latest Paper build: $PAPER_BUILD"
    curl -fsSL -o paper.jar \
        "https://api.papermc.io/v2/projects/paper/versions/$PAPER_VERSION/builds/$PAPER_BUILD/downloads/paper-$PAPER_VERSION-$PAPER_BUILD.jar"
    info "Paper downloaded."
else
    info "paper.jar already exists, skipping download."
fi

# =============================================================================
# 4. Accept EULA
# =============================================================================
echo "eula=true" > eula.txt
info "EULA accepted."

# =============================================================================
# 5. server.properties — offline mode + RCON enabled
# =============================================================================
cat > server.properties <<'EOF'
# shiny-enigma test server
online-mode=false
enable-rcon=true
rcon.password=testpassword123
rcon.port=25575
server-port=25565
max-players=10
level-name=world
gamemode=survival
difficulty=normal
spawn-protection=0
view-distance=8
simulation-distance=8
EOF
info "server.properties written."

# =============================================================================
# 6. Download Plugins
# =============================================================================
PLUGINS_DIR="$SERVER_DIR/plugins"

download_plugin() {
    local name="$1"
    local url="$2"
    local file="$PLUGINS_DIR/$name.jar"
    if [[ ! -f "$file" ]]; then
        info "Downloading $name..."
        curl -fsSL -L -o "$file" "$url"
        info "$name downloaded."
    else
        info "$name already present, skipping."
    fi
}

# --- Skript (latest GitHub release) ---
SKRIPT_URL=$(curl -fsSL https://api.github.com/repos/SkriptLang/Skript/releases/latest \
    | python3 -c "import sys,json; assets=json.load(sys.stdin)['assets']; \
      print(next(a['browser_download_url'] for a in assets if a['name'].endswith('.jar')))")
download_plugin "Skript" "$SKRIPT_URL"

# --- WorldEdit (required by WorldGuard) ---
WORLDEDIT_URL=$(curl -fsSL \
    "https://api.modrinth.com/v2/project/enginehub:worldedit/version?loaders=[%22bukkit%22,%22spigot%22,%22paper%22]&game_versions=[%221.21.4%22]" \
    | python3 -c "import sys,json; v=json.load(sys.stdin)[0]; \
      print(next(f['url'] for f in v['files'] if f['primary']))" 2>/dev/null || \
    echo "SKIP")
if [[ "$WORLDEDIT_URL" != "SKIP" ]]; then
    download_plugin "WorldEdit" "$WORLDEDIT_URL"
else
    warn "Could not auto-download WorldEdit. Download manually from https://dev.bukkit.org/projects/worldedit/files"
fi

# --- WorldGuard ---
WORLDGUARD_URL=$(curl -fsSL \
    "https://api.modrinth.com/v2/project/enginehub:worldguard/version?loaders=[%22bukkit%22,%22spigot%22,%22paper%22]&game_versions=[%221.21.4%22]" \
    | python3 -c "import sys,json; v=json.load(sys.stdin)[0]; \
      print(next(f['url'] for f in v['files'] if f['primary']))" 2>/dev/null || \
    echo "SKIP")
if [[ "$WORLDGUARD_URL" != "SKIP" ]]; then
    download_plugin "WorldGuard" "$WORLDGUARD_URL"
else
    warn "Could not auto-download WorldGuard. Download manually from https://dev.bukkit.org/projects/worldguard/files"
fi

# --- LuckPerms ---
LUCKPERMS_URL="https://download.luckperms.net/1559/bukkit/loader/LuckPerms-Bukkit-5.4.145.jar"
download_plugin "LuckPerms" "$LUCKPERMS_URL"

# --- Citizens ---
# Citizens has no clean public API; we use the latest known direct link
CITIZENS_URL="https://ci.citizensnpcs.co/job/Citizens2/lastSuccessfulBuild/artifact/dist/target/Citizens-2.0.35-b3516.jar"
if [[ ! -f "$PLUGINS_DIR/Citizens.jar" ]]; then
    info "Downloading Citizens..."
    curl -fsSL -L -o "$PLUGINS_DIR/Citizens.jar" "$CITIZENS_URL" 2>/dev/null \
        || warn "Citizens auto-download failed. Download manually from https://citizensnpcs.co/download.html and place in test/server/plugins/"
fi

# =============================================================================
# 7. Copy .sk scripts into server
# =============================================================================
SK_DIR="$PLUGINS_DIR/Skript/scripts"
mkdir -p "$SK_DIR"
cp "$REPO_DIR/game.sk"            "$SK_DIR/"
cp "$REPO_DIR/shop-items.sk"      "$SK_DIR/"
cp "$REPO_DIR/test-commands.sk"   "$SK_DIR/"
info "Skript files copied to $SK_DIR"

# =============================================================================
# 8. Pre-create LuckPerms groups so permissions work immediately
# =============================================================================
LP_DIR="$PLUGINS_DIR/LuckPerms"
mkdir -p "$LP_DIR"
cat > "$LP_DIR/config.yml" <<'EOF'
storage-method: h2
EOF

# =============================================================================
# Done
# =============================================================================
echo ""
info "======================================================"
info " Setup complete!"
info " Next steps:"
info "   1. Run:  bash test/start.sh"
info "   2. Wait for 'Done' in the server log"
info "   3. Run:  bash test/run-tests.sh"
info "======================================================"
