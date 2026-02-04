#!/usr/bin/env python3
"""
run_xsim.py - 直接运行 XSim 仿真（支持 IP 依赖）

这个脚本分两步执行:
1. 使用 Vivado 生成仿真脚本 (export_simulation)
2. 直接调用 XSim 命令行工具运行仿真

这样可以避免 launch_simulation 在批处理模式下的 "Broken pipe" 问题。

用法: python run_xsim.py <project.xpr> [testbench_name] [sim_time]
     python run_xsim.py project.xpr tb_ModMul 1000ns
"""

import sys
import os
import subprocess
import tempfile
import time
from pathlib import Path

def run_command(cmd, cwd=None, timeout=600):
    """运行命令并返回输出"""
    print(f"Running: {cmd[:100]}..." if len(cmd) > 100 else f"Running: {cmd}")
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except Exception as e:
        return -1, "", str(e)

def generate_sim_scripts(proj_path, testbench, sim_time):
    """使用 Vivado 生成仿真脚本"""

    # 创建临时 TCL 脚本
    tcl_content = f'''
# 自动生成的仿真脚本生成器
set proj_path "{proj_path.replace(chr(92), '/')}"
set tb_name "{testbench}"
set sim_time "{sim_time}"

puts "============================================"
puts "     GENERATING SIMULATION SCRIPTS"
puts "============================================"
puts "Project:   $proj_path"
puts "Testbench: $tb_name"
puts "Sim Time:  $sim_time"

# 打开项目
open_project $proj_path

# 获取项目目录
set proj_dir [get_property DIRECTORY [current_project]]
set proj_name [get_property NAME [current_project]]

# 更新编译顺序
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# 设置 testbench
if {{$tb_name ne ""}} {{
    puts "Setting testbench: $tb_name"
    set_property top $tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1
}}

# 获取 top 模块
set sim_top [get_property top [get_filesets sim_1]]
puts "Top module: $sim_top"

# 获取仿真目录
set sim_dir "${{proj_dir}}/${{proj_name}}.sim/sim_1/behav/xsim"

# 设置仿真运行时间
if {{$sim_time ne "" && $sim_time ne "all"}} {{
    set_property -name {{xsim.simulate.runtime}} -value $sim_time -objects [get_filesets sim_1]
}}

# 生成仿真目标 - 只针对特定的仿真 fileset
puts "\\nGenerating simulation targets..."
if {{[catch {{generate_target simulation [get_filesets sim_1]}} err]}} {{
    puts "Note: generate_target sim returned: $err"
}}

# 使用 export_simulation 生成脚本
puts "\\nExporting simulation scripts..."
file mkdir $sim_dir
if {{[catch {{export_simulation -simulator xsim -directory $sim_dir -force}} err]}} {{
    puts "Note: export_simulation returned: $err"
    # 如果 export_simulation 失败，尝试用 launch_simulation 生成
    puts "Trying alternative method..."
    if {{[catch {{set_property -name {{xsim.elaborate.relax}} -value {{1}} -objects [get_filesets sim_1]}} err2]}} {{
        puts "Note: set_property returned: $err2"
    }}
}}

# 输出结果
puts "\\n============================================"
puts "SIM_DIR=$sim_dir"
puts "SIM_TOP=$sim_top"
puts "============================================"

close_project
puts "\\nDone."
'''

    # 写入临时文件
    with tempfile.NamedTemporaryFile(mode='w', suffix='.tcl', delete=False) as f:
        f.write(tcl_content)
        tcl_file = f.name

    try:
        # 运行 Vivado
        cmd = f'vivado -mode batch -nojournal -nolog -source "{tcl_file}"'
        code, stdout, stderr = run_command(cmd, timeout=600)

        # 解析输出获取仿真目录
        sim_dir = None
        sim_top = None
        for line in stdout.split('\n'):
            if line.startswith('SIM_DIR='):
                sim_dir = line.split('=', 1)[1].strip()
            elif line.startswith('SIM_TOP='):
                sim_top = line.split('=', 1)[1].strip()

        # 也打印 Vivado 输出中的关键信息
        for line in stdout.split('\n'):
            if 'ERROR' in line or 'WARNING' in line or 'Testbench' in line or 'Top module' in line:
                print(line)

        return code == 0, sim_dir, sim_top, stdout

    finally:
        os.unlink(tcl_file)

def run_xsim(sim_dir, sim_time):
    """直接运行 XSim"""

    sim_dir = Path(sim_dir)

    # 检查脚本是否存在
    compile_bat = sim_dir / 'compile.bat'
    elaborate_bat = sim_dir / 'elaborate.bat'
    simulate_bat = sim_dir / 'simulate.bat'

    if not compile_bat.exists():
        print(f"ERROR: compile.bat not found in {sim_dir}")
        return False

    # 步骤 1: 编译
    print("\n=== STEP 1: COMPILE ===")
    cmd = f'cmd.exe /c "cd /d {sim_dir} && compile.bat"'
    code, stdout, stderr = run_command(cmd, timeout=300)

    # 检查编译日志
    xvlog_log = sim_dir / 'xvlog.log'
    if xvlog_log.exists():
        with open(xvlog_log, 'r') as f:
            log_content = f.read()
        if 'ERROR' in log_content:
            print("Compile errors found:")
            for line in log_content.split('\n'):
                if 'ERROR' in line:
                    print(f"  {line}")
            return False
        print("Compile: SUCCESS")
    else:
        print("WARNING: xvlog.log not found")

    # 步骤 2: 装配
    print("\n=== STEP 2: ELABORATE ===")
    if elaborate_bat.exists():
        cmd = f'cmd.exe /c "cd /d {sim_dir} && elaborate.bat"'
        code, stdout, stderr = run_command(cmd, timeout=300)

        # 检查装配日志
        xelab_log = sim_dir / 'elaborate.log'
        if xelab_log.exists():
            with open(xelab_log, 'r') as f:
                log_content = f.read()
            if 'ERROR' in log_content:
                print("Elaborate errors found:")
                for line in log_content.split('\n'):
                    if 'ERROR' in line:
                        print(f"  {line}")
                return False
            print("Elaborate: SUCCESS")
    else:
        print("WARNING: elaborate.bat not found")

    # 步骤 3: 仿真
    print("\n=== STEP 3: SIMULATE ===")
    if simulate_bat.exists():
        cmd = f'cmd.exe /c "cd /d {sim_dir} && simulate.bat"'
        code, stdout, stderr = run_command(cmd, timeout=600)

        # 检查仿真日志
        sim_log = sim_dir / 'simulate.log'
        if sim_log.exists():
            with open(sim_log, 'r') as f:
                log_content = f.read()

            # 显示仿真结果
            print("\n=== SIMULATION OUTPUT ===")
            lines = log_content.split('\n')
            for i, line in enumerate(lines):
                # 显示重要信息
                if any(kw in line for kw in ['PASS', 'FAIL', 'ERROR', 'finish', 'stop', 'Test', 'Result']):
                    print(line)

            if 'PASS' in log_content or 'finish' in log_content.lower():
                print("\nSimulate: COMPLETED")
                return True
            elif 'ERROR' in log_content:
                print("\nSimulate: FAILED")
                return False
            else:
                print("\nSimulate: COMPLETED (no explicit pass/fail)")
                return True
    else:
        print("WARNING: simulate.bat not found")

    return True

def main():
    if len(sys.argv) < 2:
        print("============================================")
        print("     XSIM DIRECT SIMULATION")
        print("============================================")
        print()
        print("Usage: python run_xsim.py <project.xpr> [testbench] [sim_time]")
        print()
        print("Arguments:")
        print("  project.xpr - Vivado project file")
        print("  testbench   - Testbench module name (optional)")
        print("  sim_time    - Simulation time, e.g. '1000ns', '10us' (optional)")
        print()
        print("Examples:")
        print("  python run_xsim.py project.xpr")
        print("  python run_xsim.py project.xpr tb_ModMul")
        print("  python run_xsim.py project.xpr tb_ModMul 1000ns")
        return 1

    proj_path = sys.argv[1]
    testbench = sys.argv[2] if len(sys.argv) > 2 else ""
    sim_time = sys.argv[3] if len(sys.argv) > 3 else "all"

    print("============================================")
    print("     XSIM DIRECT SIMULATION")
    print("============================================")
    print(f"Project:   {proj_path}")
    print(f"Testbench: {testbench if testbench else '(project default)'}")
    print(f"Sim Time:  {sim_time}")
    print("============================================")

    # 检查项目文件是否存在
    if not os.path.exists(proj_path):
        print(f"ERROR: Project file not found: {proj_path}")
        return 1

    # 步骤 1: 生成仿真脚本
    print("\n=== PHASE 1: GENERATE SIMULATION SCRIPTS ===")
    success, sim_dir, sim_top, output = generate_sim_scripts(proj_path, testbench, sim_time)

    if not success or not sim_dir:
        print("ERROR: Failed to generate simulation scripts")
        print("Vivado output:")
        print(output[-2000:] if len(output) > 2000 else output)
        return 1

    print(f"Simulation directory: {sim_dir}")
    print(f"Top module: {sim_top}")

    # 步骤 2: 运行仿真
    print("\n=== PHASE 2: RUN SIMULATION ===")
    success = run_xsim(sim_dir, sim_time)

    if success:
        print("\n============================================")
        print("      SIMULATION COMPLETED SUCCESSFULLY")
        print("============================================")
        print(f"Logs available in: {sim_dir}")
        return 0
    else:
        print("\n============================================")
        print("      SIMULATION FAILED")
        print("============================================")
        print(f"Check logs in: {sim_dir}")
        return 1

if __name__ == '__main__':
    sys.exit(main())
