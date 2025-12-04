#!/bin/bash

echo "🐍 Starting Python Hand Detection Server..."
echo "📦 Installing dependencies..."

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3 first."
    exit 1
fi

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "❌ pip3 is not installed. Please install pip3 first."
    exit 1
fi

# Install dependencies
echo "📥 Installing Python dependencies..."
pip3 install -r requirements.txt

# Start the server
echo "🚀 Starting Flask server..."
python3 hand_detection_server.py
