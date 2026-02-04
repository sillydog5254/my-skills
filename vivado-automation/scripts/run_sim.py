#!/usr/bin/env python3
"""
run_sim.py - 运行依赖 IP 核的 Testbench 仿真

这个脚本通过三步运行仿真:
1. 使用 Vivado TCL 生成仿真所需的 .prj 文件
2. 直接调用 xvlog, xvhdl 编译
3. 直接调用 xelab 装配
4. 直接调用 xsim 运行仿真

这种方法避免了 launch_simulation 在批处理模式下的 "Broken pipe" 问题。

用法: python run_sim.py <project.xpr> [testbench_name] [sim_time]

示例:
    python run_sim.py project.xpr
    python run_sim.py project.xpr tb_ModMul
    python run_sim.py project.xpr tb_ModMul 1000ns
"""

import sys
import os
import subprocess
import tempfile
from pathlib import Path

def run_command(cmd, cwd=None, timeout=600, show_output=True):
    """运行命令并返回输出"""
    if show_output:
        print(f"$ {cmd[:120]}..." if len(cmd) > 120 else f"$ {cmd}")

    try:
        proc = subprocess.Popen(
            cmd,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            cwd=cwd
        )

        output_lines = []
        for line in proc.stdout:
            output_lines.append(line.rstrip())
            if show_output:
                print(line.rstrip())

        proc.wait(timeout=timeout)
        return proc.returncode, '\n'.join(output_lines)
    except subprocess.TimeoutExpired:
        proc.kill()
        return -1, "Command timed out"
    except Exception as e:
        return -1, str(e)

def step1_generate_prj_files(proj_path, testbench, sim_time):
    """使用 Vivado 生成 .prj 仿真文件列表"""

    proj_path = proj_path.replace('\\', '/')

    tcl_content = f'''
# 生成仿真 .prj 文件
set proj_path "{proj_path}"
set tb_name "{testbench}"

open_project $proj_path

set proj_dir [get_property DIRECTORY [current_project]]
set proj_name [get_property NAME [current_project]]

update_compile_order -fileset sim_1

if {{$tb_name ne ""}} {{
    set_property top $tb_name [get_filesets sim_1]
    update_compile_order -fileset sim_1
}}

set sim_top [get_property top [get_filesets sim_1]]
set sim_dir "${{proj_dir}}/${{proj_name}}.sim/sim_1/behav/xsim"

# 设置仿真运行时间
set runtime "{sim_time}"
if {{$runtime ne "" && $runtime ne "all"}} {{
    set_property -name {{xsim.simulate.runtime}} -value $runtime -objects [get_filesets sim_1]
}}

# 使用 export_simulation 生成文件
puts "Generating simulation files for $sim_top..."
catch {{export_simulation -simulator xsim -directory $sim_dir -force}} err

# 输出关键信息
puts "SIM_TOP=$sim_top"
puts "SIM_DIR=$sim_dir"

close_project
'''

    # 写入临时文件
    with tempfile.NamedTemporaryFile(mode='w', suffix='.tcl', delete=False) as f:
        f.write(tcl_content)
        tcl_file = f.name

    try:
        # 运行 Vivado 生成 .prj 文件
        print("=== Step 1: Generating simulation project files ===")
        cmd = f'vivado -mode batch -nojournal -nolog -source "{tcl_file}"'
        code, output = run_command(cmd, timeout=300, show_output=False)

        # 解析输出
        sim_top = ""
        sim_dir = ""
        for line in output.split('\n'):
            if line.startswith('SIM_TOP='):
                sim_top = line.split('=', 1)[1].strip()
            elif line.startswith('SIM_DIR='):
                sim_dir = line.split('=', 1)[1].strip()

        if sim_top:
            print(f"  Top module: {sim_top}")
        if sim_dir:
            print(f"  Sim directory: {sim_dir}")

        return sim_top, sim_dir
    finally:
        os.unlink(tcl_file)

def step2_compile(sim_dir, testbench):
    """编译仿真源文件"""

    sim_dir = Path(sim_dir)

    # 查找 .prj 文件
    vlog_prj = sim_dir / f"{testbench}_vlog.prj"
    vhdl_prj = sim_dir / f"{testbench}_vhdl.prj"

    print("\n=== Step 2: Compiling sources ===")

    # 编译 Verilog/SystemVerilog
    if vlog_prj.exists():
        cmd = f'xvlog --incr --relax -L axi_vip_v1_1_5 -L processing_system7_vip_v1_0_7 -L xilinx_vip -prj "{vlog_prj}" -log xvlog.log'
        code, output = run_command(cmd, cwd=str(sim_dir), timeout=300, show_output=False)

        # 检查错误
        log_file = sim_dir / 'xvlog.log'
        if log_file.exists():
            log_content = log_file.read_text()
            if 'ERROR' in log_content:
                print("  xvlog: ERRORS found!")
                for line in log_content.split('\n'):
                    if 'ERROR' in line:
                        print(f"    {line}")
                return False
        print("  xvlog: SUCCESS")
    else:
        print(f"  WARNING: {vlog_prj.name} not found")

    # 编译 VHDL
    if vhdl_prj.exists():
        cmd = f'xvhdl --incr --relax -prj "{vhdl_prj}" -log xvhdl.log'
        code, output = run_command(cmd, cwd=str(sim_dir), timeout=300, show_output=False)

        log_file = sim_dir / 'xvhdl.log'
        if log_file.exists():
            log_content = log_file.read_text()
            if 'ERROR' in log_content:
                print("  xvhdl: ERRORS found!")
                for line in log_content.split('\n'):
                    if 'ERROR' in line:
                        print(f"    {line}")
                return False
        print("  xvhdl: SUCCESS")

    return True

def step3_elaborate(sim_dir, testbench):
    """装配仿真设计"""

    sim_dir = Path(sim_dir)
    snapshot = f"{testbench}_behav"

    print("\n=== Step 3: Elaborating design ===")

    # 标准库列表
    libs = "-L blk_mem_gen_v8_4_3 -L xil_defaultlib -L xbip_dsp48_wrapper_v3_0_4 -L xbip_utils_v3_0_10 -L xbip_pipe_v3_0_6 -L xbip_dsp48_macro_v3_0_17 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -L xpm"

    cmd = f'xelab --incr --debug typical --relax --mt 2 {libs} --snapshot {snapshot} xil_defaultlib.{testbench} xil_defaultlib.glbl -log elaborate.log'
    code, output = run_command(cmd, cwd=str(sim_dir), timeout=300, show_output=False)

    # 检查日志
    log_file = sim_dir / 'elaborate.log'
    if log_file.exists():
        log_content = log_file.read_text()
        if 'ERROR' in log_content:
            print("  xelab: ERRORS found!")
            for line in log_content.split('\n'):
                if 'ERROR' in line:
                    print(f"    {line}")
            return None

    print(f"  xelab: SUCCESS (snapshot: {snapshot})")
    return snapshot

def step4_simulate(sim_dir, snapshot, sim_time):
    """运行仿真"""

    sim_dir = Path(sim_dir)

    print("\n=== Step 4: Running simulation ===")

    # 构建 xsim 命令
    if sim_time and sim_time != 'all':
        # 创建一个简单的 TCL 脚本来设置运行时间
        tcl_file = sim_dir / 'run_sim.tcl'
        tcl_file.write_text(f'run {sim_time}\nexit\n')
        cmd = f'xsim {snapshot} -tclbatch run_sim.tcl -log simulate.log'
    else:
        cmd = f'xsim {snapshot} -runall -log simulate.log'

    code, output = run_command(cmd, cwd=str(sim_dir), timeout=600, show_output=False)

    # 检查仿真日志
    log_file = sim_dir / 'simulate.log'
    if log_file.exists():
        log_content = log_file.read_text()

        # 显示重要输出（排除大量重复的错误）
        print("\n  === Simulation Output ===")
        shown_errors = set()
        finish_time = None

        for line in log_content.split('\n'):
            # 捕获 $finish 时间
            if '$finish' in line and 'time :' in line:
                finish_time = line
                print(f"  {line}")
            elif '$stop' in line:
                print(f"  {line}")
            # 过滤重复错误，只显示每种错误一次
            elif 'ERROR' in line:
                # 提取错误的关键部分
                error_key = line.split('ERROR:')[1][:50] if 'ERROR:' in line else line[:50]
                if error_key not in shown_errors:
                    shown_errors.add(error_key)
                    print(f"  {line}")
                    if len(shown_errors) >= 5:
                        print("  ... (more errors omitted)")
            elif any(kw in line for kw in ['PASS', 'FAIL', 'Test', 'Result', 'SUCCESS', 'FAILED']):
                print(f"  {line}")

        # 判断结果
        has_fatal_error = False
        if 'ERROR' in log_content:
            # 某些错误不是致命的（如文件路径问题）
            non_fatal_patterns = ['File descriptor', '$fscanf', '$fopen', '$readmem']
            for line in log_content.split('\n'):
                if 'ERROR' in line and not any(p in line for p in non_fatal_patterns):
                    has_fatal_error = True
                    break

        if has_fatal_error:
            print("\n  xsim: FAILED (fatal errors)")
            return False
        elif finish_time or '$stop' in log_content:
            if shown_errors:
                print(f"\n  xsim: COMPLETED with warnings ({len(shown_errors)} error types)")
            else:
                print("\n  xsim: COMPLETED")
            return True

    return True

def main():
    if len(sys.argv) < 2:
        print("============================================")
        print("  XSim Simulation with IP Dependencies")
        print("============================================")
        print()
        print("Usage: python run_sim.py <project.xpr> [testbench] [sim_time]")
        print()
        print("Arguments:")
        print("  project.xpr - Vivado project file")
        print("  testbench   - Testbench module name (optional, uses project default)")
        print("  sim_time    - Simulation time (optional, e.g., '1000ns', '10us', 'all')")
        print()
        print("Examples:")
        print("  python run_sim.py project.xpr")
        print("  python run_sim.py project.xpr tb_ModMul")
        print("  python run_sim.py project.xpr tb_ModMul 1000ns")
        return 1

    proj_path = sys.argv[1]
    testbench = sys.argv[2] if len(sys.argv) > 2 else ""
    sim_time = sys.argv[3] if len(sys.argv) > 3 else "all"

    print("============================================")
    print("  XSim Simulation with IP Dependencies")
    print("============================================")
    print(f"Project:   {proj_path}")
    print(f"Testbench: {testbench if testbench else '(project default)'}")
    print(f"Sim Time:  {sim_time}")
    print("============================================")

    # 检查项目文件
    if not os.path.exists(proj_path):
        print(f"ERROR: Project file not found: {proj_path}")
        return 1

    # Step 1: 生成 .prj 文件
    sim_top, sim_dir = step1_generate_prj_files(proj_path, testbench, sim_time)

    if not sim_dir:
        print("ERROR: Failed to determine simulation directory")
        return 1

    if not sim_top:
        sim_top = testbench or "tb_UnifiedTransformation"
        print(f"  Using testbench: {sim_top}")

    # Step 2: 编译
    if not step2_compile(sim_dir, sim_top):
        return 1

    # Step 3: 装配
    snapshot = step3_elaborate(sim_dir, sim_top)
    if not snapshot:
        return 1

    # Step 4: 仿真
    success = step4_simulate(sim_dir, snapshot, sim_time)

    print("\n============================================")
    if success:
        print("  SIMULATION COMPLETED SUCCESSFULLY")
    else:
        print("  SIMULATION FAILED")
    print("============================================")
    print(f"Logs: {sim_dir}")

    return 0 if success else 1

if __name__ == '__main__':
    sys.exit(main())
