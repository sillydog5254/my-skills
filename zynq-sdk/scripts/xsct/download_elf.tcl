# download_elf.tcl - 下载并运行 ELF 到 Zynq
# 用法: xsct download_elf.tcl <elf_file> [bitstream] [--reset]
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行
# 需要 hw_server 正在运行或 JTAG 已连接

proc find_elf {} {
    # 搜索 ELF 文件
    set search_patterns [list \
        "*.elf" \
        "*/Debug/*.elf" \
        "*/Release/*.elf" \
        "*.sdk/*/Debug/*.elf" \
        "project/*.sdk/*/Debug/*.elf" \
    ]

    foreach pattern $search_patterns {
        set files [glob -nocomplain $pattern]
        if {[llength $files] > 0} {
            # 返回最新的
            set latest ""
            set latest_time 0
            foreach f $files {
                set mtime [file mtime $f]
                if {$mtime > $latest_time} {
                    set latest $f
                    set latest_time $mtime
                }
            }
            return $latest
        }
    }
    return ""
}

proc find_bitstream {} {
    set search_patterns [list \
        "*.bit" \
        "*.runs/impl_1/*.bit" \
        "project/*.runs/impl_1/*.bit" \
    ]

    foreach pattern $search_patterns {
        set files [glob -nocomplain $pattern]
        if {[llength $files] > 0} {
            return [lindex $files 0]
        }
    }
    return ""
}

proc find_ps7_init {elf_path} {
    # 从 ELF 路径推断 ps7_init.tcl 位置
    set workspace [file dirname [file dirname [file dirname $elf_path]]]

    # 搜索 _hw_platform 目录
    set hw_platforms [glob -nocomplain "$workspace/*_hw_platform*"]
    foreach hp $hw_platforms {
        set init_file "$hp/ps7_init.tcl"
        if {[file exists $init_file]} {
            return $init_file
        }
    }
    return ""
}

# 解析参数
set elf_file ""
set bit_file ""
set do_reset 0

foreach arg $argv {
    if {$arg eq "--reset" || $arg eq "-r"} {
        set do_reset 1
    } elseif {[string match "*.elf" $arg]} {
        set elf_file $arg
    } elseif {[string match "*.bit" $arg]} {
        set bit_file $arg
    }
}

if {$elf_file eq ""} {
    set elf_file [find_elf]
    if {$elf_file eq ""} {
        puts "Usage: xsct download_elf.tcl <elf_file> \[bitstream\] \[--reset\]"
        puts "No .elf file found."
        exit 1
    }
    puts "Auto-detected ELF: $elf_file"
}

if {![file exists $elf_file]} {
    puts "ERROR: ELF file not found: $elf_file"
    exit 1
}

puts ""
puts "=============================================="
puts "      DOWNLOAD AND RUN ELF"
puts "=============================================="
puts "ELF file:  $elf_file"
if {$bit_file ne ""} {
    puts "Bitstream: $bit_file"
}
puts "Reset:     $do_reset"
puts ""

# 连接到目标
puts "Connecting to hw_server..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect to hw_server."
    puts "       Start hw_server first or check JTAG connection."
    puts "       Error: $result"
    exit 1
}

# 列出可用目标
puts ""
puts "Available targets:"
targets

# 配置 FPGA（如果提供了比特流）
if {$bit_file ne "" && [file exists $bit_file]} {
    puts ""
    puts "Configuring FPGA..."
    targets -set -filter {name =~ "xc7z*" || name =~ "arm_dap*"}

    if {[catch {fpga $bit_file} result]} {
        puts "WARNING: FPGA configuration failed: $result"
        puts "         Continuing anyway..."
    } else {
        puts "FPGA configured successfully."
    }
}

# 选择 ARM 核心 0
puts ""
puts "Selecting ARM Cortex-A9 #0..."
if {[catch {targets -set -filter {name =~ "ARM*#0"}} result]} {
    puts "ERROR: Cannot find ARM processor."
    puts "       Available targets:"
    targets
    disconnect
    exit 1
}

# 加载 ps7_init.tcl（如果找到）
set ps7_init [find_ps7_init $elf_file]
if {$ps7_init ne "" && [file exists $ps7_init]} {
    puts "Loading PS7 initialization: $ps7_init"
    source $ps7_init
}

# 重置处理器（如果请求）
if {$do_reset} {
    puts "Resetting processor..."
    rst -processor
}

# 运行 PS7 初始化
if {[info procs ps7_init] ne ""} {
    puts "Running ps7_init..."
    ps7_init
}

if {[info procs ps7_post_config] ne ""} {
    puts "Running ps7_post_config..."
    ps7_post_config
}

# 下载 ELF
puts ""
puts "Downloading ELF..."
dow $elf_file

# 运行
puts ""
puts "Starting execution..."
con

puts ""
puts "=============================================="
puts "ELF downloaded and running!"
puts "=============================================="
puts ""
puts "Use UART terminal to see output:"
puts "  - Windows: Use PuTTY or Tera Term on the appropriate COM port"
puts "  - Or use: python uart_terminal.py"
puts ""
puts "To stop: xsct -eval \"connect; targets -set -filter {name =~ \\\"ARM*#0\\\"}; stop; disconnect\""

# 保持连接（不断开，让程序继续运行）
# disconnect
