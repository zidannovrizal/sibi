#!/bin/bash

echo "🚀 Starting Enhanced Real-Time Object Detection System..."
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Python 3 is installed
print_status "Checking Python 3 installation..."
if ! command_exists python3; then
    print_error "Python 3 is not installed. Please install Python 3 first."
    exit 1
fi
print_success "Python 3 found: $(python3 --version)"

# Check if pip3 is installed
print_status "Checking pip3 installation..."
if ! command_exists pip3; then
    print_error "pip3 is not installed. Please install pip3 first."
    exit 1
fi
print_success "pip3 found: $(pip3 --version)"

# Check if Flutter is installed
print_status "Checking Flutter installation..."
if ! command_exists flutter; then
    print_error "Flutter is not installed. Please install Flutter first."
    exit 1
fi
print_success "Flutter found: $(flutter --version | head -n 1)"

# Navigate to Python server directory
print_status "Setting up Python Hand Detection Server..."
cd python_hand_detection_server

# Install Python dependencies
print_status "Installing Python dependencies..."
if pip3 install -r requirements.txt; then
    print_success "Python dependencies installed successfully"
else
    print_error "Failed to install Python dependencies"
    exit 1
fi

# Start Python server in background
print_status "Starting Python Hand Detection Server..."
python3 hand_detection_server.py &
PYTHON_PID=$!

# Wait a moment for server to start
sleep 3

# Check if Python server is running
if kill -0 $PYTHON_PID 2>/dev/null; then
    print_success "Python server started successfully (PID: $PYTHON_PID)"
else
    print_error "Failed to start Python server"
    exit 1
fi

# Navigate back to Flutter directory
cd ..

# Get Flutter dependencies
print_status "Getting Flutter dependencies..."
if flutter pub get; then
    print_success "Flutter dependencies installed successfully"
else
    print_error "Failed to install Flutter dependencies"
    kill $PYTHON_PID 2>/dev/null
    exit 1
fi

# Function to cleanup on exit
cleanup() {
    print_status "Cleaning up..."
    if kill -0 $PYTHON_PID 2>/dev/null; then
        print_status "Stopping Python server..."
        kill $PYTHON_PID
        wait $PYTHON_PID 2>/dev/null
        print_success "Python server stopped"
    fi
    print_success "Cleanup completed"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Display system information
echo ""
echo "🎯 Enhanced Real-Time Object Detection System"
echo "============================================="
echo "📱 Flutter App: Real-time UI and camera capture"
echo "🐍 Python Server: AI hand detection with MediaPipe"
echo "🌐 Communication: HTTP REST API with optimization"
echo ""
echo "🚀 Real-Time Features:"
echo "  • 3.3 FPS Processing (300ms interval)"
echo "  • Temporal Analysis (15-frame history)"
echo "  • Gesture Stability (5-frame confirmation)"
echo "  • Enhanced Finger Analysis"
echo "  • Real-time Performance Monitoring"
echo ""
echo "📊 Performance Metrics:"
echo "  • Detection Rate: 3.3 FPS"
echo "  • Confidence Threshold: 0.7"
echo "  • Processing Latency: < 300ms"
echo "  • Network Timeout: 3 seconds"
echo ""

# Start Flutter app
print_status "Starting Flutter app with real-time detection..."
print_status "Python server is running on http://localhost:5001"
print_status "Flutter app will connect to Python server automatically"
echo ""
print_warning "Press Ctrl+C to stop the system"
echo ""

# Start Flutter app
flutter run

# If Flutter exits, cleanup
cleanup
