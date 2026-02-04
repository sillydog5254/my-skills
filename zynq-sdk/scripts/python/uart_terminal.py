#!/usr/bin/env python3
"""
UART Terminal for Zynq PS communication

Usage:
    python uart_terminal.py [port] [baud]

Examples:
    python uart_terminal.py              # Auto-detect port
    python uart_terminal.py COM6         # Specify port
    python uart_terminal.py COM6 115200  # Specify port and baud
"""

import sys
import time
import threading

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not installed.")
    print("Install with: pip install pyserial")
    sys.exit(1)


def list_ports():
    """List all available serial ports"""
    ports = serial.tools.list_ports.comports()
    print("\nAvailable serial ports:")
    print("-" * 60)
    for port in ports:
        print(f"  {port.device}: {port.description}")
    print("-" * 60)
    return ports


def find_zynq_uart():
    """Find likely Zynq UART port"""
    ports = serial.tools.list_ports.comports()

    # Priority order for Zynq UART detection
    priority_keywords = [
        "FTDI",           # FTDI USB-Serial
        "USB Serial",     # Generic USB-Serial
        "CH340",          # CH340 USB-Serial
        "CP210",          # Silicon Labs
        "Digilent",       # Digilent boards
        "USB-SERIAL",     # Various
    ]

    for keyword in priority_keywords:
        for port in ports:
            if keyword.lower() in port.description.lower():
                return port.device

    # Return first non-Bluetooth port as fallback
    for port in ports:
        if "bluetooth" not in port.description.lower():
            return port.device

    return None


def uart_terminal(port, baud=115200, log_file=None):
    """Simple UART terminal with optional logging"""

    try:
        ser = serial.Serial(port, baud, timeout=0.1)
    except serial.SerialException as e:
        print(f"ERROR: Cannot open {port}: {e}")
        return

    print(f"\n{'='*60}")
    print(f" UART Terminal - {port} @ {baud} baud")
    print(f"{'='*60}")
    print("Press Ctrl+C to exit")
    print("-" * 60)
    print()

    # Optional log file
    log_fp = None
    if log_file:
        log_fp = open(log_file, 'w')
        print(f"Logging to: {log_file}")

    # Flag to stop threads
    running = True

    def read_thread():
        """Background thread to read from serial port"""
        while running:
            try:
                data = ser.read(1024)
                if data:
                    text = data.decode('utf-8', errors='replace')
                    sys.stdout.write(text)
                    sys.stdout.flush()
                    if log_fp:
                        log_fp.write(text)
                        log_fp.flush()
            except serial.SerialException:
                break
            except Exception as e:
                if running:
                    print(f"\nRead error: {e}")
                break

    # Start reader thread
    reader = threading.Thread(target=read_thread, daemon=True)
    reader.start()

    try:
        while True:
            try:
                # Read line from user
                line = input()
                # Send to serial port
                ser.write((line + '\r\n').encode())
            except EOFError:
                break
    except KeyboardInterrupt:
        pass
    finally:
        running = False
        print("\n")
        print("-" * 60)
        print("Disconnected.")

        if log_fp:
            log_fp.close()

        ser.close()


def main():
    port = None
    baud = 115200

    # Parse arguments
    for i, arg in enumerate(sys.argv[1:], 1):
        if arg.startswith("COM") or arg.startswith("/dev/"):
            port = arg
        elif arg.isdigit():
            baud = int(arg)
        elif arg == "--list" or arg == "-l":
            list_ports()
            return
        elif arg == "--help" or arg == "-h":
            print(__doc__)
            return

    # Auto-detect port if not specified
    if port is None:
        port = find_zynq_uart()
        if port is None:
            print("ERROR: No suitable serial port found.")
            list_ports()
            print("\nPlease specify the port manually.")
            return
        print(f"Auto-detected port: {port}")

    # Run terminal
    uart_terminal(port, baud)


if __name__ == "__main__":
    main()
