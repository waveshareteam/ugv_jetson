import serial
import argparse
import threading
import json
import time

def read_serial():
    while True:
        data = ser.readline().decode('utf-8')
        if data:
            print(f"Received: {data}", end='')

def load_test():
    while True:
        for i in range(-500, 500):
            data = {"T":133,"X":i/100,"Y":i/100,"SPD":0,"ACC":0}
            ser.write((json.dumps(data)+'\n').encode("utf-8"))
        for i in range(500, -500, -1):
            data = {"T":133,"X":i/100,"Y":i/100,"SPD":0,"ACC":0}
            ser.write((json.dumps(data)+'\n').encode("utf-8"))

        # for i in range(-200, 200):
        #     data = {"T":1,"L":i/1000,"R":i/1000}
        #     ser.write((json.dumps(data)+'\n').encode("utf-8"))
        # for i in range(200, -200, -1):
        #     data = {"T":1,"L":i/1000,"R":i/1000}
        #     ser.write((json.dumps(data)+'\n').encode("utf-8"))

def main():
    global ser
    # parser = argparse.ArgumentParser(description='Serial JSON Communication')
    # parser.add_argument('port', type=str, help='Serial port name (e.g., COM1 or /dev/ttyUSB0)')

    # args = parser.parse_args()

    ser = serial.Serial('/dev/ttyACM0', baudrate=115200, dsrdtr=None)
    ser.setRTS(False)
    ser.setDTR(False)

    # serial_recv_thread = threading.Thread(target=read_serial)
    # serial_recv_thread.daemon = True
    # serial_recv_thread.start()

    while True:
        read_serial()
    
    # try:
    #     while True:
    #         command = input("")
    #         ser.write(command.encode() + b'\n')
    # except KeyboardInterrupt:
    #     pass
    # finally:
    #     ser.close()

    # serial_recv_thread = threading.Thread(target=load_test)
    # serial_recv_thread.daemon = True
    # serial_recv_thread.start()

    # serial_recv_thread_1 = threading.Thread(target=load_test)
    # serial_recv_thread_1.daemon = True
    # serial_recv_thread_1.start()

    # data = {"T":1,"L":0.5,"R":0.5}
    # ser.write((json.dumps(data)+'\n').encode("utf-8"))
    # print(data)
    # time.sleep(0.00001)

    # try:
    #     while True:
    #         for i in range(-500, 500):
    #             data = {"T":1,"L":i/1000,"R":i/1000}
    #             ser.write((json.dumps(data)+'\n').encode("utf-8"))
    #         for i in range(500, -500, -1):
    #             data = {"T":1,"L":i/1000,"R":i/1000}
    #             ser.write((json.dumps(data)+'\n').encode("utf-8"))
    # except KeyboardInterrupt:
    #     pass
    # finally:
    #     ser.close()

    # try:
    #     data = {"T":600}
    #     ser.write((json.dumps(data)+'\n').encode("utf-8"))
    # except KeyboardInterrupt:
    #     pass
    # finally:
    #     ser.close()


if __name__ == "__main__":
    main()

