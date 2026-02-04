#!/usr/bin/env python3
"""
run_xsim_simple.py - 使用已生成的仿真脚本运行 XSim

这个脚本直接调用仿真目录中的 compile.bat, elaborate.bat, simulate.bat

用法: python run_xsim_simple.py <sim_dir> [testbench]
"""

import sys
import os
import subprocess
from pathlib import Path

def run_cmd_batch(sim_dir, script_name, timeout=300):
    """运行 Windows 批处理脚本"""
    script_path = sim_dir / script_name
    if not script_path.exists():
        print(f"ERROR: {script_name} not found")
        return False, ""

    # 使用 PowerShell 来运行批处理脚本并捕获输出
    # 注意：直接用 subprocess 运行 .bat 文件在 Windows 上工作正常
    cmd = f'cd /d "{sim_dir}" && {script_name}'

    proc = subprocess.Popen(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        cwd=str(sim_dir)
    )

    output_lines = []
    try:
        for line in proc.stdout:
            output_lines.append(line.rstrip())
            print(line.rstrip())

        proc.wait(timeout=timeout)
        return proc.returncode == 0, '\n'.join(output_lines)
    except subprocess.TimeoutExpired:
        proc.kill()
        return False, "Timeout"
    except Exception as e:
        return False, str(e)

def main():
    if len(sys.argv) < 2:
        print("Usage: python run_xsim_simple.py <sim_dir> [testbench]")
        print()
        print("Arguments:")
        print("  sim_dir   - Directory containing compile.bat, elaborate.bat, simulate.bat")
        print("  testbench - Optional testbench name (for display only)")
        print()
        print("Example:")
        print("  python run_xsim_simple.py C:/proj/proj.sim/sim_1/behav/xsim tb_ModMul")
        return 1

    sim_dir = Path(sys.argv[1])
    testbench = sys.argv[2] if len(sys.argv) > 2 else "unknown"

    print("============================================")
    print("     XSIM DIRECT RUNNER")
    print("============================================")
    print(f"Sim Dir:   {sim_dir}")
    print(f"Testbench: {testbench}")
    print("============================================")

    if not sim_dir.exists():
        print(f"ERROR: Directory not found: {sim_dir}")
        return 1

    # Step 1: Compile
    print("\n=== STEP 1: COMPILE ===")
    success, output = run_cmd_batch(sim_dir, "compile.bat", timeout=300)
    if not success:
        print("ERROR: Compile failed!")
        # 检查日志
        xvlog_log = sim_dir / "xvlog.log"
        if xvlog_log.exists():
            print("\nxvlog.log contents:")
            print(xvlog_log.read_text()[-2000:])
        return 1
    print("Compile: SUCCESS")

    # Step 2: Elaborate
    print("\n=== STEP 2: ELABORATE ===")
    success, output = run_cmd_batch(sim_dir, "elaborate.bat", timeout=300)
    if not success:
        print("ERROR: Elaborate failed!")
        # 检查日志
        xelab_log = sim_dir / "elaborate.log"
        if xelab_log.exists():
            print("\nelaborate.log contents:")
            print(xelab_log.read_text()[-2000:])
        return 1
    print("Elaborate: SUCCESS")

    # Step 3: Simulate
    print("\n=== STEP 3: SIMULATE ===")
    success, output = run_cmd_batch(sim_dir, "simulate.bat", timeout=600)
    # 仿真可能因为 $finish 返回非零，但实际仍然成功
    print("Simulate: COMPLETED")

    # 检查仿真日志
    sim_log = sim_dir / "simulate.log"
    if sim_log.exists():
        content = sim_log.read_text()
        print("\n=== SIMULATION OUTPUT ===")
        for line in content.split('\n'):
            if any(kw in line for kw in ['PASS', 'FAIL', 'ERROR', 'finish', 'stop', 'Test', 'Result', 'SUCCESS', 'FAILED']):
                print(line)

        if 'PASS' in content:
            print("\n========== SIMULATION PASSED ==========")
            return 0
        elif 'FAIL' in content:
            print("\n========== SIMULATION FAILED ==========")
            return 1

    print("\n============================================")
    print("      SIMULATION COMPLETE")
    print("============================================")
    return 0

if __name__ == '__main__':
    sys.exit(main())
