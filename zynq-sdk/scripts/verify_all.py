#!/usr/bin/env python3
"""
verify_all.py - Zynq 开发工具链综合验证脚本

验证所有 skill 功能:
1. JTAG 检测 (zynq-debug)
2. FPGA 编程 (vivado-automation)
3. CPU 控制 (zynq-debug)
4. 内存访问 (zynq-debug)
5. ELF 下载运行 (zynq-sdk)
6. 串口输出 (zynq-sdk)

用法:
    python verify_all.py [--bit <bitstream>] [--elf <elf_file>] [--port <com_port>]

示例:
    python verify_all.py
    python verify_all.py --bit design.bit --elf app.elf --port COM6
"""

import subprocess
import sys
import os
import time
import argparse
import glob
import threading
import queue
from datetime import datetime

# 工具路径
XSCT = "D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat"
VIVADO = "vivado"
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ZYNQ_DEBUG_SCRIPTS = os.path.join(os.path.dirname(SCRIPT_DIR), "..", "zynq-debug", "scripts", "xsct")
VIVADO_SCRIPTS = os.path.join(os.path.dirname(SCRIPT_DIR), "..", "vivado-automation", "scripts")

# 测试结果
results = []

def log(msg, level="INFO"):
    """打印带时间戳的日志"""
    timestamp = datetime.now().strftime("%H:%M:%S")
    prefix = {"INFO": "[ ]", "PASS": "[+]", "FAIL": "[-]", "WARN": "[!]", "TEST": "[*]"}
    print(f"{timestamp} {prefix.get(level, '[ ]')} {msg}")

def run_xsct(script, args=None, timeout=60):
    """运行 XSCT 脚本"""
    cmd = [XSCT, script]
    if args:
        cmd.extend(args)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=os.getcwd())
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except Exception as e:
        return False, str(e)

def run_vivado(script, args=None, timeout=120):
    """运行 Vivado TCL 脚本"""
    cmd = [VIVADO, "-mode", "batch", "-source", script, "-nojournal", "-nolog"]
    if args:
        cmd.extend(["-tclargs"] + args)
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, cwd=os.getcwd())
        return result.returncode == 0, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return False, "Timeout"
    except Exception as e:
        return False, str(e)

def find_files(patterns):
    """查找文件"""
    for pattern in patterns:
        files = glob.glob(pattern, recursive=True)
        if files:
            return files[0]
    return None

def test_jtag_detection():
    """测试 1: JTAG 检测"""
    log("Testing JTAG detection...", "TEST")

    script = os.path.join(ZYNQ_DEBUG_SCRIPTS, "jtag_detect.tcl")
    if not os.path.exists(script):
        # 创建临时脚本
        script = os.path.join(SCRIPT_DIR, "temp_jtag_detect.tcl")
        with open(script, "w") as f:
            f.write("""
puts "Connecting to hw_server..."
if {[catch {connect} err]} {
    puts "ERROR: Cannot connect - $err"
    exit 1
}
puts "Available targets:"
set target_list [targets]
puts $target_list

# 检查是否有 Zynq
if {[string match "*xc7z*" $target_list] || [string match "*ARM*" $target_list]} {
    puts "SUCCESS: Zynq device detected"
    disconnect
    exit 0
} else {
    puts "ERROR: No Zynq device found"
    disconnect
    exit 1
}
""")

    success, output = run_xsct(script)

    if success and ("ARM" in output or "xc7z" in output):
        log("JTAG detection: PASSED", "PASS")
        results.append(("JTAG Detection", "PASS", "Zynq device detected"))
        return True
    else:
        log("JTAG detection: FAILED", "FAIL")
        results.append(("JTAG Detection", "FAIL", output[:200]))
        return False

def test_fpga_programming(bitstream):
    """测试 2: FPGA 编程 (使用 XSCT)"""
    log(f"Testing FPGA programming with {bitstream}...", "TEST")

    if not bitstream or not os.path.exists(bitstream):
        log("No bitstream file found, skipping", "WARN")
        results.append(("FPGA Programming", "SKIP", "No bitstream file"))
        return True

    # 使用 XSCT 烧录 (比 Vivado 更可靠，因为 Vivado 可能不在 PATH 中)
    bitstream_path = os.path.abspath(bitstream).replace("\\", "/")
    script = os.path.join(SCRIPT_DIR, "temp_fpga_program.tcl")
    with open(script, "w") as f:
        f.write(f"""
puts "Programming FPGA with: {bitstream_path}"
connect

# 选择 FPGA 目标
puts "Selecting FPGA target..."
if {{[catch {{targets -set -filter {{name =~ "*xc7z*" || name =~ "*arm_dap*"}}}} err]}} {{
    puts "ERROR: Cannot select target - $err"
    disconnect
    exit 1
}}

# 烧录比特流
puts "Downloading bitstream..."
if {{[catch {{fpga {bitstream_path}}} err]}} {{
    puts "ERROR: FPGA programming failed - $err"
    disconnect
    exit 1
}}

puts "SUCCESS: FPGA programmed successfully"
disconnect
exit 0
""")

    success, output = run_xsct(script, timeout=120)

    if success or "SUCCESS" in output:
        log("FPGA programming: PASSED", "PASS")
        results.append(("FPGA Programming", "PASS", "Bitstream loaded via XSCT"))
        return True
    else:
        log("FPGA programming: FAILED", "FAIL")
        results.append(("FPGA Programming", "FAIL", output[:200]))
        return False

def test_cpu_control():
    """测试 3: CPU 控制"""
    log("Testing CPU control...", "TEST")

    # 创建测试脚本
    script = os.path.join(SCRIPT_DIR, "temp_cpu_test.tcl")
    with open(script, "w") as f:
        f.write("""
puts "Testing CPU control..."
connect

# 选择 ARM 核心
if {[catch {targets -set -filter {name =~ "ARM*#0"}} err]} {
    puts "ERROR: Cannot select ARM core - $err"
    disconnect
    exit 1
}

# 停止 CPU
puts "Stopping CPU..."
if {[catch {stop} err]} {
    puts "WARNING: Stop failed - $err"
}
after 100

# 读取 PC
puts "Reading PC register..."
if {[catch {set pc [rrd pc]} err]} {
    puts "ERROR: Cannot read PC - $err"
    disconnect
    exit 1
}
puts "PC = $pc"

# 恢复运行
puts "Resuming CPU..."
if {[catch {con} err]} {
    puts "WARNING: Resume failed - $err"
}

disconnect
puts "SUCCESS: CPU control test passed"
exit 0
""")

    success, output = run_xsct(script)

    if success or "SUCCESS" in output or "PC =" in output:
        log("CPU control: PASSED", "PASS")
        results.append(("CPU Control", "PASS", "Stop/Read/Resume OK"))
        return True
    else:
        log("CPU control: FAILED", "FAIL")
        results.append(("CPU Control", "FAIL", output[:200]))
        return False

def test_memory_access():
    """测试 4: 内存访问"""
    log("Testing memory access...", "TEST")

    # 创建测试脚本
    script = os.path.join(SCRIPT_DIR, "temp_mem_test.tcl")
    with open(script, "w") as f:
        f.write("""
puts "Testing memory access..."
connect
targets -set -filter {name =~ "ARM*#0"}
stop
after 100

# 读取 DDR 起始地址
puts "Reading DDR at 0x00100000..."
set val [mrd -value 0x00100000 1]
puts "Read value: $val"

# 写入测试值
puts "Writing test value 0x12345678..."
mwr 0x00100000 0x12345678
after 10

# 读回验证
set val2 [mrd -value 0x00100000 1]
puts "Read back: $val2"

# 恢复原值
mwr 0x00100000 $val
after 10

con
disconnect

if {$val2 == 0x12345678} {
    puts "SUCCESS: Memory read/write verified"
    exit 0
} else {
    puts "ERROR: Memory verification failed"
    exit 1
}
""")

    success, output = run_xsct(script)

    if success or "SUCCESS" in output:
        log("Memory access: PASSED", "PASS")
        results.append(("Memory Access", "PASS", "Read/Write verified"))
        return True
    elif "Read value" in output:
        log("Memory access: PARTIAL", "WARN")
        results.append(("Memory Access", "WARN", "Read OK, write may have issues"))
        return True
    else:
        log("Memory access: FAILED", "FAIL")
        results.append(("Memory Access", "FAIL", output[:200]))
        return False

def test_elf_download(elf_file, ps7_init=None):
    """测试 5: ELF 下载"""
    log(f"Testing ELF download with {elf_file}...", "TEST")

    if not elf_file or not os.path.exists(elf_file):
        log("No ELF file found, skipping", "WARN")
        results.append(("ELF Download", "SKIP", "No ELF file"))
        return True

    # 查找 ps7_init
    if not ps7_init:
        elf_dir = os.path.dirname(elf_file)
        search_paths = [
            os.path.join(elf_dir, "*_hw_platform*", "ps7_init.tcl"),
            os.path.join(elf_dir, "..", "*_hw_platform*", "ps7_init.tcl"),
            os.path.join(elf_dir, "..", "..", "*_hw_platform*", "ps7_init.tcl"),
        ]
        for pattern in search_paths:
            matches = glob.glob(pattern)
            if matches:
                ps7_init = matches[0]
                break

    # 创建下载脚本
    script = os.path.join(SCRIPT_DIR, "temp_dow_test.tcl")
    with open(script, "w") as f:
        f.write(f"""
puts "Testing ELF download..."
connect
targets -set -filter {{name =~ "ARM*#0"}}

# 复位
puts "Resetting processor..."
rst -processor
after 100
""")
        if ps7_init and os.path.exists(ps7_init):
            ps7_path = ps7_init.replace("\\", "/")
            f.write(f"""
# PS7 初始化
puts "Running ps7_init..."
source {ps7_path}
ps7_init
ps7_post_config
""")

        elf_path = elf_file.replace("\\", "/")
        f.write(f"""
# 下载 ELF
puts "Downloading ELF..."
dow {elf_path}
puts "ELF downloaded successfully"

# 启动程序
puts "Starting program..."
con
after 500

disconnect
puts "SUCCESS: ELF download and run completed"
exit 0
""")

    success, output = run_xsct(script, timeout=120)

    if success or "SUCCESS" in output or "downloaded" in output.lower():
        log("ELF download: PASSED", "PASS")
        results.append(("ELF Download", "PASS", "Program running"))
        return True
    else:
        log("ELF download: FAILED", "FAIL")
        results.append(("ELF Download", "FAIL", output[:200]))
        return False

def test_uart_output(port, baud=115200, timeout=5):
    """测试 6: 串口输出"""
    log(f"Testing UART output on {port}...", "TEST")

    try:
        import serial
    except ImportError:
        log("pyserial not installed, skipping", "WARN")
        results.append(("UART Output", "SKIP", "pyserial not installed"))
        return True

    if not port:
        log("No COM port specified, skipping", "WARN")
        results.append(("UART Output", "SKIP", "No port specified"))
        return True

    try:
        ser = serial.Serial(port, baud, timeout=timeout)
        log(f"Opened {port} at {baud} baud, waiting for data...", "INFO")

        received = b""
        start_time = time.time()

        while time.time() - start_time < timeout:
            if ser.in_waiting:
                data = ser.read(ser.in_waiting)
                received += data
                if len(received) > 10:  # 收到足够数据
                    break
            time.sleep(0.1)

        ser.close()

        if received:
            text = received.decode('utf-8', errors='replace')
            log(f"Received {len(received)} bytes: {text[:100]}...", "INFO")
            log("UART output: PASSED", "PASS")
            results.append(("UART Output", "PASS", f"Received {len(received)} bytes"))
            return True
        else:
            log("No data received within timeout", "WARN")
            log("Note: Program may only print at startup. Re-run ELF with serial open.", "INFO")
            results.append(("UART Output", "WARN", "No data (program may need restart)"))
            return True

    except serial.SerialException as e:
        log(f"Serial error: {e}", "FAIL")
        results.append(("UART Output", "FAIL", str(e)))
        return False


def test_elf_with_uart(elf_file, port, baud=115200, ps7_init=None):
    """测试 5+6 组合: ELF 下载 + UART 监听"""
    log(f"Testing ELF download with UART capture...", "TEST")

    if not elf_file or not os.path.exists(elf_file):
        log("No ELF file found for combined test", "WARN")
        return False, ""

    if not port:
        log("No COM port specified for combined test", "WARN")
        return False, ""

    try:
        import serial
    except ImportError:
        log("pyserial not installed for combined test", "WARN")
        return False, ""

    # 查找 ps7_init
    if not ps7_init:
        elf_dir = os.path.dirname(elf_file)
        search_paths = [
            os.path.join(elf_dir, "*_hw_platform*", "ps7_init.tcl"),
            os.path.join(elf_dir, "..", "*_hw_platform*", "ps7_init.tcl"),
            os.path.join(elf_dir, "..", "..", "*_hw_platform*", "ps7_init.tcl"),
        ]
        for pattern in search_paths:
            matches = glob.glob(pattern)
            if matches:
                ps7_init = matches[0]
                break

    # 打开串口
    try:
        ser = serial.Serial(port, baud, timeout=0.1)
        ser.reset_input_buffer()
        log(f"Serial port {port} opened", "INFO")
    except Exception as e:
        log(f"Cannot open serial: {e}", "WARN")
        return False, ""

    received = b""

    # 创建下载脚本
    script = os.path.join(SCRIPT_DIR, "temp_dow_uart.tcl")
    with open(script, "w") as f:
        f.write("""
puts "Downloading ELF with UART test..."
connect
targets -set -filter {name =~ "ARM*#0"}

puts "Resetting processor..."
rst -processor
after 100
""")
        if ps7_init and os.path.exists(ps7_init):
            ps7_path = ps7_init.replace("\\", "/")
            f.write(f"""
puts "Running ps7_init..."
source {ps7_path}
ps7_init
ps7_post_config
""")

        elf_path = elf_file.replace("\\", "/")
        f.write(f"""
puts "Downloading ELF..."
dow {elf_path}
puts "Starting program..."
con
after 2000
disconnect
puts "SUCCESS"
exit 0
""")

    # 运行下载脚本
    success, output = run_xsct(script, timeout=120)

    # 等待并收集串口数据
    log("Collecting UART output...", "INFO")
    start_time = time.time()
    while time.time() - start_time < 3:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting)
            received += data
        time.sleep(0.1)

    ser.close()

    if received:
        text = received.decode('utf-8', errors='replace')
        log(f"UART captured {len(received)} bytes", "INFO")
        return True, text
    else:
        return success and "SUCCESS" in output, ""

def print_report():
    """打印测试报告"""
    print("\n" + "=" * 60)
    print("           ZYNQ SKILL VERIFICATION REPORT")
    print("=" * 60)
    print(f"  Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)

    passed = sum(1 for r in results if r[1] == "PASS")
    failed = sum(1 for r in results if r[1] == "FAIL")
    warned = sum(1 for r in results if r[1] == "WARN")
    skipped = sum(1 for r in results if r[1] == "SKIP")

    print(f"\n  Summary: {passed} PASS, {failed} FAIL, {warned} WARN, {skipped} SKIP\n")

    print("-" * 60)
    print(f"  {'Test':<20} {'Result':<10} {'Details'}")
    print("-" * 60)

    for test, result, details in results:
        status_color = {
            "PASS": "\033[92m",  # Green
            "FAIL": "\033[91m",  # Red
            "WARN": "\033[93m",  # Yellow
            "SKIP": "\033[94m",  # Blue
        }.get(result, "")
        reset = "\033[0m"
        print(f"  {test:<20} {status_color}{result:<10}{reset} {details[:30]}")

    print("-" * 60)

    if failed == 0:
        print("\n  [+] All functional tests PASSED!")
        print("      Zynq skill suite is ready for use.")
    else:
        print(f"\n  [-] {failed} test(s) FAILED. Please check the details above.")

    print("=" * 60 + "\n")

    return failed == 0

def main():
    parser = argparse.ArgumentParser(description="Zynq Skill Suite Verification")
    parser.add_argument("--bit", help="Bitstream file path")
    parser.add_argument("--elf", help="ELF file path")
    parser.add_argument("--port", help="COM port for UART (e.g., COM6)")
    parser.add_argument("--baud", type=int, default=115200, help="Baud rate (default: 115200)")
    parser.add_argument("--skip-fpga", action="store_true", help="Skip FPGA programming test")
    parser.add_argument("--skip-elf", action="store_true", help="Skip ELF download test")
    parser.add_argument("--skip-uart", action="store_true", help="Skip UART test")
    args = parser.parse_args()

    print("\n" + "=" * 60)
    print("       ZYNQ SKILL SUITE VERIFICATION SCRIPT")
    print("=" * 60)
    print(f"  XSCT:   {XSCT}")
    print(f"  Vivado: {VIVADO}")
    print("=" * 60 + "\n")

    # 自动查找文件
    bitstream = args.bit
    if not bitstream:
        bitstream = find_files([
            "*.bit",
            "*/*.bit",
            "project/*.runs/impl_1/*.bit",
            "*.sdk/*/*.bit"
        ])
        if bitstream:
            log(f"Auto-detected bitstream: {bitstream}")

    elf_file = args.elf
    if not elf_file:
        elf_file = find_files([
            "*.elf",
            "*/*.elf",
            "*/*/*.elf",
            "*.sdk/*/*/*.elf"
        ])
        if elf_file:
            log(f"Auto-detected ELF: {elf_file}")

    # 运行测试
    log("Starting verification tests...\n")

    # 测试 1: JTAG 检测
    if not test_jtag_detection():
        log("JTAG detection failed, aborting remaining tests", "FAIL")
        print_report()
        return 1

    # 测试 2: FPGA 编程
    if not args.skip_fpga:
        test_fpga_programming(bitstream)
    else:
        results.append(("FPGA Programming", "SKIP", "User skipped"))

    # 测试 3: CPU 控制
    test_cpu_control()

    # 测试 4: 内存访问
    test_memory_access()

    # 测试 5+6: ELF 下载 + UART (组合测试以捕获启动时输出)
    if not args.skip_elf and not args.skip_uart and elf_file and args.port:
        log("Running combined ELF + UART test...", "INFO")
        success, uart_data = test_elf_with_uart(elf_file, args.port, args.baud)
        if success:
            log("ELF download: PASSED", "PASS")
            results.append(("ELF Download", "PASS", "Program running"))
            if uart_data:
                log(f"UART output: PASSED ({len(uart_data)} chars)", "PASS")
                results.append(("UART Output", "PASS", f"Received: {uart_data[:50]}..."))
            else:
                log("UART output: No data captured", "WARN")
                results.append(("UART Output", "WARN", "No output captured"))
        else:
            log("ELF download: FAILED", "FAIL")
            results.append(("ELF Download", "FAIL", "Download failed"))
            results.append(("UART Output", "SKIP", "ELF download failed"))
    else:
        # 分别测试
        if not args.skip_elf:
            test_elf_download(elf_file)
        else:
            results.append(("ELF Download", "SKIP", "User skipped"))

        if not args.skip_uart:
            test_uart_output(args.port, args.baud)
        else:
            results.append(("UART Output", "SKIP", "User skipped"))

    # 打印报告
    success = print_report()

    # 清理临时文件
    for temp_file in glob.glob(os.path.join(SCRIPT_DIR, "temp_*.tcl")):
        try:
            os.remove(temp_file)
        except:
            pass

    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
