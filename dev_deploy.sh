# Exit immediately if a command exits with a non-zero status
set -e

# Function to display help message
show_help() {
    echo "Usage: $0 [options] -r <remote_ip>"
    echo
    echo "Required:"
    echo "  -r, --remote <remote_ip>   Remote host IP address"
    echo
    echo "Optional:"
    echo "  -u, --user <remote_user>   Remote username (default: root)"
    echo "  -i, --install              Install the release version (jetkvm_app) instead of the debug version (jetkvm_app_debug)"
    echo "      --help                 Display this help message"
    echo
    echo "Example:"
    echo "  $0 -r 192.168.0.17"
    echo "  $0 -r 192.168.0.17 -u admin"
    echo "  $0 -r 192.168.0.17 -i"
    exit 0
}

# Default values
REMOTE_USER="root"
REMOTE_PATH="/userdata/jetkvm/bin"
INSTALL_RELEASE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--remote)
            REMOTE_HOST="$2"
            shift 2
            ;;
        -u|--user)
            REMOTE_USER="$2"
            shift 2
            ;;
        -i|--install)
            INSTALL_RELEASE=true
            shift 1
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verify required parameters
if [ -z "$REMOTE_HOST" ]; then
    echo "Error: Remote IP is a required parameter"
    show_help
fi

# Build the appropriate version on the host
make frontend
if [ "$INSTALL_RELEASE" = true ]; then
    make build_release_prod
else
    make build_dev
fi

# Change directory to the binary output directory
cd bin

# Determine the binary to deploy
if [ "$INSTALL_RELEASE" = true ]; then
    BINARY_NAME="jetkvm_app"
else
    BINARY_NAME="jetkvm_app_debug"
fi

# Kill any existing instances of the application
ssh "${REMOTE_USER}@${REMOTE_HOST}" "killall $BINARY_NAME || true"

# Copy the binary to the remote host
cat "$BINARY_NAME" | ssh "${REMOTE_USER}@${REMOTE_HOST}" "cat > $REMOTE_PATH/$BINARY_NAME"

# Deploy and run the application on the remote host
ssh "${REMOTE_USER}@${REMOTE_HOST}" ash <<EOF
set -e

# Set the library path to include the directory where librockit.so is located
export LD_LIBRARY_PATH=/oem/usr/lib:\$LD_LIBRARY_PATH

# Kill any existing instances of the application
killall jetkvm_app || true
killall jetkvm_app_debug || true

# Navigate to the directory where the binary will be stored
cd "$REMOTE_PATH"

# Make the new binary executable
chmod +x $BINARY_NAME

# Run the application in the background
if [ "$INSTALL_RELEASE" = true ]; then
    ./$BINARY_NAME &
else
    PION_LOG_TRACE=jetkvm,cloud ./$BINARY_NAME
fi
EOF

echo "Deployment complete."