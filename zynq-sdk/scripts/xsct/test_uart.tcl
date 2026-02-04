# test_uart.tcl - 测试 UART 输出
# 用法: xsct test_uart.tcl

puts "=============================================="
puts "         UART TEST"
puts "=============================================="
puts ""

# 连接
puts "Connecting..."
connect

# 查看目标
puts ""
puts "Available targets:"
targets

# 选择 ARM 核心
puts ""
puts "Selecting ARM Cortex-A9 #0..."
targets -set -filter {name =~ "ARM*#0"}

# 加载 ps7_init
set ps7_init "C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/AlohaHE_wrapper_hw_platform_0/ps7_init.tcl"
if {[file exists $ps7_init]} {
    puts "Loading PS7 initialization..."
    source $ps7_init
}

# 复位
puts "Resetting processor..."
rst -processor

# 初始化 PS
puts "Running ps7_init..."
ps7_init
ps7_post_config

# 下载 ELF
set elf_file "C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/Aloha-HE/Debug/Aloha-HE.elf"
puts ""
puts "Downloading ELF: $elf_file"
dow $elf_file

# 启动 JTAG UART
puts ""
puts "Starting JTAG UART terminal..."
if {[catch {jtagterminal -start} result]} {
    puts "JTAG terminal not available: $result"
    puts "The design may not have JTAG UART IP."
} else {
    puts "JTAG terminal started."
}

# 运行程序
puts ""
puts "Starting program execution..."
con

# 等待
puts ""
puts "Waiting 10 seconds for program output..."
after 10000

# 读取 JTAG UART
puts ""
puts "Reading JTAG UART output..."
if {[catch {
    set output [readjtaguart]
    puts "JTAG UART output:"
    puts $output
} err]} {
    puts "Could not read JTAG UART: $err"
}

# 停止
puts ""
puts "Stopping program..."
stop

# 读取 PC 以确认状态
set pc [rrd pc]
puts "Current PC: $pc"

# 清理
if {[catch {jtagterminal -stop} result]} {
    # 忽略错误
}

disconnect

puts ""
puts "Test complete."
