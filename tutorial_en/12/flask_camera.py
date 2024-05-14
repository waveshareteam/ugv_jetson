from flask import Flask, render_template, Response  # Import Flask class, render_template function for rendering HTML templates, Response class for generating response objects
import time  # Import the time module for handling time-related tasks
import cv2  # Import the OpenCV library for image processing

app = Flask(__name__)  # Create a Flask application instance

def gen_frames():  # Define a generator function for generating frames captured by the camera
    camera = cv2.VideoCapture(-1) # 创建摄像头实例
    #设置分辨率
    camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

    while True:
        _, frame = camera.read()  # Capture a frame from the camera
        img = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        ret, buffer = cv2.imencode('.jpg', frame)  # Encode the captured frame as JPEG format

        frame = buffer.tobytes()  # Convert the JPEG image to a byte stream

        # Use yield to return the image byte stream, allowing for continuous transmission of video frames to form a video stream
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.route('/')  # Define the root route
def index():
    return render_template('index.html')  # Return the index.html page

@app.route('/video_feed')  # Define the video stream route
def video_feed():
    # Return a response object with video stream content, with content type multipart/x-mixed-replace
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)  # Start the Flask application, listening on port 5000 on all network interfaces, with debug mode enabled
