#!/usr/bin/env python3
"""
Simple Python Server untuk Testing
"""

import cv2
import numpy as np
import base64
import json
import threading
import time
import signal
import sys
import atexit
import warnings
import multiprocessing
from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import os

# Suppress OpenCV warnings
warnings.filterwarnings('ignore', category=UserWarning)

# Fix multiprocessing resource leak
try:
    multiprocessing.set_start_method('spawn', force=True)
except RuntimeError:
    pass  # Already set

app = Flask(__name__)
CORS(app)

class SimpleDetector:
    def __init__(self):
        self.camera = None
        self.is_camera_active = False
        self.current_frame = None
        self.frame_lock = threading.Lock()
        self._shutdown_flag = False
        self._cleanup_done = False
        print("✅ Simple Detector initialized")
    
    def start_camera(self):
        """Mulai kamera untuk streaming"""
        try:
            if self.camera is None:
                self.camera = cv2.VideoCapture(0)
                if not self.camera.isOpened():
                    raise Exception("Tidak dapat membuka kamera")
                
                # Set resolusi kamera untuk performa lebih baik
                self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 320)  # Lebih kecil
                self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)  # Lebih kecil
                self.camera.set(cv2.CAP_PROP_FPS, 10)  # 10 FPS
                self.camera.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Buffer minimal
                
                self.is_camera_active = True
                print("✅ Kamera berhasil dimulai")
                return True
            return True
        except Exception as e:
            print(f"❌ Error memulai kamera: {e}")
            return False
    
    def stop_camera(self):
        """Hentikan kamera"""
        if self._cleanup_done:
            return True
            
        try:
            self._shutdown_flag = True
            self.is_camera_active = False
            
            if self.camera is not None:
                try:
                    self.camera.release()
                except:
                    pass
                self.camera = None
            
            # Clear current frame
            with self.frame_lock:
                self.current_frame = None
            
            self._cleanup_done = True
            print("🛑 Kamera dihentikan")
            return True
        except Exception as e:
            print(f"❌ Error menghentikan kamera: {e}")
            return False
    
    def get_frame(self):
        """Ambil frame dari kamera"""
        if not self.is_camera_active or self.camera is None or self._shutdown_flag:
            return None
            
        try:
            ret, frame = self.camera.read()
            if ret and frame is not None:
                with self.frame_lock:
                    self.current_frame = frame.copy()
                return frame
            else:
                # Jika tidak bisa baca frame, tunggu sebentar
                time.sleep(0.01)
        except Exception as e:
            print(f"❌ Error reading frame: {e}")
            time.sleep(0.01)
        return None
    
    def detect_hands(self, image):
        """Deteksi tangan sederhana - versi enteng"""
        try:
            if image is None or image.size == 0:
                return self._get_empty_result()
            
            # Resize image untuk deteksi yang lebih cepat
            small_image = cv2.resize(image, (160, 120))
            
            # Convert ke grayscale
            gray = cv2.cvtColor(small_image, cv2.COLOR_BGR2GRAY)
            
            # Simple threshold tanpa blur untuk performa lebih baik
            _, thresh = cv2.threshold(gray, 120, 255, cv2.THRESH_BINARY)
            
            # Find contours
            contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Filter contours berdasarkan area (disesuaikan dengan ukuran kecil)
            hand_contours = []
            for contour in contours:
                try:
                    area = cv2.contourArea(contour)
                    if 200 < area < 10000:  # Filter untuk ukuran kecil
                        hand_contours.append(contour)
                except:
                    continue
            
            if hand_contours:
                # Ambil contour terbesar
                largest_contour = max(hand_contours, key=cv2.contourArea)
                
                # Get bounding box
                x, y, w, h = cv2.boundingRect(largest_contour)
                
                # Scale back ke ukuran asli
                scale_x = image.shape[1] / 160
                scale_y = image.shape[0] / 120
                
                # Normalize coordinates
                bbox = {
                    'left': (x * scale_x) / image.shape[1],
                    'top': (y * scale_y) / image.shape[0],
                    'width': (w * scale_x) / image.shape[1],
                    'height': (h * scale_y) / image.shape[0]
                }
                
                return {
                    'hands_detected': 1,
                    'confidence': 0.6,  # Confidence lebih rendah tapi lebih cepat
                    'gestures': ['Tangan terdeteksi'],
                    'landmarks': [],
                    'bounding_box': bbox,
                    'tracking_quality': 'good'
                }
            else:
                return self._get_empty_result()
                
        except Exception as e:
            print(f"❌ Error deteksi: {e}")
            return self._get_empty_result()
    
    def _get_empty_result(self):
        """Return empty detection result"""
        return {
            'hands_detected': 0,
            'confidence': 0.0,
            'gestures': [],
            'landmarks': [],
            'bounding_box': None,
            'tracking_quality': 'poor'
        }

# Global detector instance
detector = SimpleDetector()

def cleanup_resources():
    """Clean up all resources"""
    print("🧹 Cleaning up resources...")
    detector.stop_camera()
    # Force cleanup of OpenCV resources
    cv2.destroyAllWindows()
    # Clean up multiprocessing resources
    try:
        for child in multiprocessing.active_children():
            child.terminate()
            child.join(timeout=1)
    except:
        pass
    print("✅ Cleanup complete")

def signal_handler(sig, frame):
    """Handle shutdown signals gracefully"""
    print(f"\n🛑 Received signal {sig}, shutting down server...")
    cleanup_resources()
    sys.exit(0)

# Register cleanup handlers
atexit.register(cleanup_resources)
signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'message': 'Simple Python Server is running',
        'camera_active': detector.is_camera_active
    })

@app.route('/start_camera', methods=['POST'])
def start_camera():
    """Mulai kamera"""
    try:
        print("🎥 Starting camera...")
        success = detector.start_camera()
        print(f"🎥 Camera start result: {success}")
        return jsonify({
            'success': success,
            'message': 'Kamera dimulai' if success else 'Gagal memulai kamera'
        })
    except Exception as e:
        print(f"❌ Error starting camera: {e}")
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/stop_camera', methods=['POST'])
def stop_camera():
    """Hentikan kamera"""
    try:
        success = detector.stop_camera()
        return jsonify({
            'success': success,
            'message': 'Kamera dihentikan' if success else 'Gagal menghentikan kamera'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'message': f'Error: {str(e)}'
        }), 500

@app.route('/detect_hands', methods=['POST'])
def detect_hands():
    """Deteksi tangan dari image yang dikirim"""
    try:
        data = request.get_json()
        if not data or 'image' not in data:
            return jsonify({
                'success': False,
                'error': 'No image data provided'
            }), 400
        
        # Decode base64 image
        image_data = base64.b64decode(data['image'])
        
        # Convert to OpenCV format
        nparr = np.frombuffer(image_data, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            return jsonify({
                'success': False,
                'error': 'Invalid image data'
            }), 400
        
        # Deteksi tangan
        result = detector.detect_hands(image)
        
        return jsonify({
            'success': True,
            'data': result
        })
        
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/detect_hands_realtime', methods=['GET'])
def detect_hands_realtime():
    """Deteksi tangan real-time dari kamera"""
    try:
        if detector._shutdown_flag:
            return jsonify({
                'success': False,
                'error': 'Server is shutting down'
            }), 503
        
        print(f"🔍 Detect hands realtime - Camera active: {detector.is_camera_active}")
        
        if not detector.is_camera_active:
            print("❌ Camera not active, returning 400")
            return jsonify({
                'success': False,
                'error': 'Camera not active'
            }), 400
        
        # Ambil frame dari kamera
        frame = detector.get_frame()
        if frame is None:
            print("❌ No frame available, returning 400")
            return jsonify({
                'success': False,
                'error': 'No camera frame available'
            }), 400
        
        print("✅ Frame obtained, detecting hands...")
        # Deteksi tangan
        result = detector.detect_hands(frame)
        print(f"🤖 Detection result: {result}")
        
        return jsonify({
            'success': True,
            'data': result
        })
        
    except Exception as e:
        print(f"❌ Exception in detect_hands_realtime: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/gestures', methods=['GET'])
def get_gestures():
    """Dapatkan daftar gesture yang tersedia"""
    gestures = [
        {
            'name': 'Halo',
            'type': 'sapaan',
            'category': 'SIBI',
            'difficulty': 'Mudah'
        },
        {
            'name': 'Terima Kasih',
            'type': 'ucapan',
            'category': 'SIBI',
            'difficulty': 'Mudah'
        },
        {
            'name': 'Tangan terdeteksi',
            'type': 'deteksi',
            'category': 'SIBI',
            'difficulty': 'Mudah'
        }
    ]
    
    return jsonify({
        'gestures': gestures
    })

@app.route('/video_feed')
def video_feed():
    """Stream video dari kamera Python ke Flutter"""
    def generate_frames():
        while detector.is_camera_active and not detector._shutdown_flag:
            try:
                frame = detector.get_frame()
                if frame is not None:
                    # Frame sudah kecil (320x240), tidak perlu resize lagi
                    # Encode frame sebagai JPEG dengan quality sangat rendah
                    ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 30])
                    if ret:
                        frame_bytes = buffer.tobytes()
                        yield (b'--frame\r\n'
                               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
                time.sleep(0.1)  # 10 FPS untuk mengurangi beban
            except Exception as e:
                print(f"❌ Video stream error: {e}")
                break
    
    return Response(generate_frames(),
                   mimetype='multipart/x-mixed-replace; boundary=frame')

@app.route('/frame')
def get_frame():
    """Get single frame as JPEG"""
    try:
        if not detector.is_camera_active:
            return jsonify({'error': 'Camera not active'}), 400
        
        frame = detector.get_frame()
        if frame is None:
            return jsonify({'error': 'No frame available'}), 400
        
        # Frame sudah kecil (320x240), tidak perlu resize lagi
        # Encode frame sebagai JPEG dengan quality sangat rendah
        ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 30])
        if ret:
            return Response(buffer.tobytes(), mimetype='image/jpeg')
        else:
            return jsonify({'error': 'Failed to encode frame'}), 500
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("🚀 Starting Simple Python Server...")
    print("📱 Server akan berjalan di http://localhost:5001")
    print("🤖 Endpoint deteksi: http://localhost:5001/detect_hands")
    print("🎥 Video stream: http://localhost:5001/video_feed")
    print("📸 Single frame: http://localhost:5001/frame")
    print("")
    print("Tekan Ctrl+C untuk menghentikan server")
    print("")
    
    try:
        app.run(host='0.0.0.0', port=5001, debug=True, threaded=True)
    except KeyboardInterrupt:
        print("\n🛑 Server stopped by user")
    except Exception as e:
        print(f"❌ Server error: {e}")
    finally:
        cleanup_resources()
        print("✅ Server shutdown complete")
