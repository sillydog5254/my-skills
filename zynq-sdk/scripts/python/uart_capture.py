#!/usr/bin/env python3
"""
UART Capture - 捕获串口输出到文件

Usage:
    python uart_capture.py [port] [baud] [output_file] [duration_seconds]
"""

import serial
import time
import sys


def capture_uart(port='COM6', baud=115200, output_file='uart_output.txt', duration=30):
    """Capture UART output to file"""
    try:
        ser = serial.Serial(port, baud, timeout=0.1)
        print(f"=== UART Capture ===")
        print(f"Port: {port}")
        print(f"Baud: {baud}")
        print(f"Output: {output_file}")
        print(f"Duration: {duration} seconds")
        print("-" * 50)
        sys.stdout.flush()

        with open(output_file, 'w', encoding='utf-8') as f:
            start = time.time()
            total_bytes = 0

            while time.time() - start < duration:
                data = ser.read(1024)
                if data:
                    text = data.decode('utf-8', errors='replace')
                    print(text, end='')
                    sys.stdout.flush()
                    f.write(text)
                    f.flush()
                    total_bytes += len(data)

        print()
        print("-" * 50)
        print(f"Captured {total_bytes} bytes")
        ser.close()
        return total_bytes > 0

    except Exception as e:
        print(f"Error: {e}")
        return False


if __name__ == "__main__":
    port = sys.argv[1] if len(sys.argv) > 1 else 'COM6'
    baud = int(sys.argv[2]) if len(sys.argv) > 2 else 115200
    output = sys.argv[3] if len(sys.argv) > 3 else 'uart_output.txt'
    duration = int(sys.argv[4]) if len(sys.argv) > 4 else 30

    capture_uart(port, baud, output, duration)
