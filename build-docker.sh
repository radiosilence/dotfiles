#!/bin/bash
set -euo pipefail

# Build script for dotfiles Docker container with secure GitHub token handling
# This script uses Docker secrets to avoid leaking the GitHub token into image layers

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="dotfiles"
TAG="${1:-latest}"

echo "🔧 Building dotfiles Docker container..."

# Check if GitHub token is available
if [[ -z ${GH_PAT:-} ]]; then
  echo "❌ Error: GH_PAT environment variable is required"
  echo "   Please set your GitHub Personal Access Token:"
  echo "   export GH_PAT=your_token_here"
  exit 1
fi

# Create temporary file for the GitHub token
TEMP_TOKEN_FILE=$(mktemp)
echo "$GH_PAT" >"$TEMP_TOKEN_FILE"

# Ensure cleanup of temp file
cleanup() {
  rm -f "$TEMP_TOKEN_FILE"
}
trap cleanup EXIT

echo "🚀 Building image: ${IMAGE_NAME}:${TAG}"
echo "📁 Build context: ${SCRIPT_DIR}"

# Build with Docker secrets (secure, token not leaked into image)
docker build \
  --secret id=github_token,src="$TEMP_TOKEN_FILE" \
  -t "${IMAGE_NAME}:${TAG}" \
  "$SCRIPT_DIR"

echo "✅ Build completed successfully!"
echo "🐳 Image: ${IMAGE_NAME}:${TAG}"
echo ""
echo "To run the container:"
echo "  docker run -it --rm ${IMAGE_NAME}:${TAG}"
echo ""
echo "To run with SSH port forwarding:"
echo "  docker run -it --rm -p 2222:22 ${IMAGE_NAME}:${TAG}"
