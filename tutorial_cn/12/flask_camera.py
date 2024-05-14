from flask import Flask, render_template, Response  # 从flask库导入Flask类，render_template函数用于渲染HTML模板，Response类用于生成响应对象
# from picamera2 import Picamera2  # 从picamera2库导入Picamera2类，用于访问和控制摄像头
import time  # 导入time模块，可以用来处理时间相关的任务
import cv2  # 导入OpenCV库，用于图像处理

app = Flask(__name__)  # 创建Flask应用实例

def gen_frames():  # 定义一个生成器函数，用于逐帧生成摄像头捕获的图像
    camera = cv2.VideoCapture(-1) # 创建摄像头实例
    #设置分辨率
    camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    
    while True:
        _, frame = camera.read()  # 从摄像头捕获一帧图像
        img = cv2.cvtColor(frame, cv2.COLOR_RGB2BGR)
        ret, buffer = cv2.imencode('.jpg', frame)  # 将捕获的图像帧编码为JPEG格式

        frame = buffer.tobytes()  # 将JPEG图像转换为字节流

        # 使用yield返回图像字节流，这样可以连续发送视频帧，形成视频流
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.route('/')  # 定义根路由
def index():
    return render_template('index.html')  # 返回index.html页面

@app.route('/video_feed')  # 定义视频流路由
def video_feed():
    # 返回响应对象，内容是视频流，内容类型是multipart/x-mixed-replace
    return Response(gen_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)  # 启动Flask应用，监听所有网络接口上的5000端口，开启调试模式