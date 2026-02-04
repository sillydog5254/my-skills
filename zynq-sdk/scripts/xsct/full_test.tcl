# full_test.tcl - 完整的 Zynq 功能验证测试
# 用法: xsct full_test.tcl <elf_file>
#
# 此脚本会：
# 1. 检测 JTAG 连接
# 2. 烧录比特流（如果提供）
# 3. 下载并运行 ELF
# 4. 程序输出会显示在串口（需要另开终端监听）

puts "=============================================="
puts "     ZYNQ FULL SYSTEM TEST"
puts "=============================================="
puts ""

# 解析参数
set elf_file ""
set bit_file ""

foreach arg $argv {
    if {[string match "*.elf" $arg]} {
        set elf_file $arg
    } elseif {[string match "*.bit" $arg]} {
        set bit_file $arg
    }
}

# 自动查找 ELF
if {$elf_file eq ""} {
    set elf_files [glob -nocomplain "*.elf" "*/*.elf" "*/*/*.elf" "*.sdk/*/*/*.elf"]
    if {[llength $elf_files] > 0} {
        set elf_file [lindex $elf_files 0]
        puts "Auto-detected ELF: $elf_file"
    }
}

if {$elf_file eq "" || ![file exists $elf_file]} {
    puts "ERROR: No ELF file found or specified."
    puts "Usage: xsct full_test.tcl <elf_file> \[bit_file\]"
    exit 1
}

# 自动查找比特流
if {$bit_file eq ""} {
    set bit_files [glob -nocomplain "*.bit" "*/*.bit" "*.sdk/*/*.bit" "*.runs/impl_1/*.bit"]
    if {[llength $bit_files] > 0} {
        set bit_file [lindex $bit_files 0]
        puts "Auto-detected bitstream: $bit_file"
    }
}

# 自动查找 ps7_init
set ps7_init ""
set elf_dir [file dirname $elf_file]
set search_dirs [list $elf_dir [file dirname $elf_dir] [file dirname [file dirname $elf_dir]]]
foreach dir $search_dirs {
    set candidates [glob -nocomplain "$dir/*_hw_platform*/ps7_init.tcl"]
    if {[llength $candidates] > 0} {
        set ps7_init [lindex $candidates 0]
        break
    }
}

puts ""
puts "Configuration:"
puts "  ELF file:    $elf_file"
puts "  Bitstream:   [expr {$bit_file ne \"\" ? $bit_file : \"(not provided)\"}]"
puts "  ps7_init:    [expr {$ps7_init ne \"\" ? $ps7_init : \"(not found)\"}]"
puts ""

# Step 1: 连接
puts "Step 1: Connecting to JTAG..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect. Is hw_server running?"
    puts "  Start hw_server: D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat"
    exit 1
}
puts "  Connected!"

# Step 2: 检测目标
puts ""
puts "Step 2: Detecting targets..."
set target_list [targets]
puts $target_list

# 检查是否有 ARM
set has_arm 0
if {[string match "*ARM*" $target_list]} {
    set has_arm 1
    puts "  ARM processor: DETECTED"
} else {
    puts "  ARM processor: NOT DETECTED"
}

# 检查是否有 FPGA
set has_fpga 0
if {[string match "*xc7z*" $target_list]} {
    set has_fpga 1
    puts "  Zynq FPGA: DETECTED"
} else {
    puts "  Zynq FPGA: NOT DETECTED"
}

if {!$has_arm || !$has_fpga} {
    puts "ERROR: Required targets not found. Check JTAG connection."
    disconnect
    exit 1
}

# Step 3: 配置 FPGA（如果提供比特流）
if {$bit_file ne "" && [file exists $bit_file]} {
    puts ""
    puts "Step 3: Configuring FPGA..."
    targets -set -filter {name =~ "*xc7z*" || name =~ "*arm_dap*"}
    if {[catch {fpga $bit_file} result]} {
        puts "  WARNING: FPGA configuration failed: $result"
    } else {
        puts "  FPGA configured successfully!"
    }
} else {
    puts ""
    puts "Step 3: Skipping FPGA configuration (no bitstream)"
}

# Step 4: 初始化 PS
puts ""
puts "Step 4: Initializing PS..."
targets -set -filter {name =~ "*ARM*#0"}

# 复位处理器
puts "  Resetting processor..."
rst -processor

# 运行 ps7_init
if {$ps7_init ne "" && [file exists $ps7_init]} {
    puts "  Loading ps7_init..."
    source $ps7_init
    ps7_init
    ps7_post_config
    puts "  PS initialized!"
} else {
    puts "  WARNING: ps7_init not found, PS may not be properly initialized"
}

# Step 5: 下载 ELF
puts ""
puts "Step 5: Downloading ELF..."
dow $elf_file
puts "  ELF downloaded!"

# Step 6: 运行程序
puts ""
puts "Step 6: Starting program execution..."
con
puts "  Program running!"

puts ""
puts "=============================================="
puts "TEST COMPLETE - Program is now running"
puts "=============================================="
puts ""
puts "To see program output, open a serial terminal:"
puts "  python uart_terminal.py COM6 115200"
puts ""
puts "To stop the program:"
puts "  xsct -eval \"connect; targets -set -filter {name =~ \\\"ARM*#0\\\"}; stop; disconnect\""
puts ""

# 保持连接让程序运行
# disconnect
