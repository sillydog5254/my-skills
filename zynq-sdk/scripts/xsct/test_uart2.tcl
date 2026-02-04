# test_uart2.tcl - 测试 UART 输出 (使用文件重定向)
# 用法: xsct test_uart2.tcl

puts "=============================================="
puts "         UART TEST v2"
puts "=============================================="
puts ""

# 连接
puts "Connecting..."
connect

# 选择 ARM 核心
puts "Selecting ARM Cortex-A9 #0..."
targets -set -filter {name =~ "ARM*#0"}

# 加载 ps7_init
puts "Loading PS7 initialization..."
source C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/AlohaHE_wrapper_hw_platform_0/ps7_init.tcl

# 复位和初始化
puts "Resetting and initializing..."
rst -processor
ps7_init
ps7_post_config

# 设置 JTAG UART 输出到文件
set uart_log "C:/Users/asdle/jtag_uart_output.txt"
puts "Redirecting JTAG UART to: $uart_log"

# 打开文件
set fp [open $uart_log w]

# 启动 JTAG UART 读取并重定向到文件
if {[catch {readjtaguart -start -handle $fp} result]} {
    puts "Warning: $result"
}

# 下载 ELF
puts "Downloading ELF..."
dow C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/Aloha-HE/Debug/Aloha-HE.elf

# 运行
puts "Starting program..."
con

# 等待程序执行
puts "Waiting 15 seconds for program to run..."
after 15000

# 停止读取
puts "Stopping JTAG UART capture..."
if {[catch {readjtaguart -stop} result]} {
    puts "Note: $result"
}

close $fp

# 停止程序
stop

# 读取 PC
set pc [rrd pc]
puts "Final PC: $pc"

disconnect

# 显示捕获的输出
puts ""
puts "=============================================="
puts "Captured UART output:"
puts "=============================================="

if {[file exists $uart_log]} {
    set fp [open $uart_log r]
    set content [read $fp]
    close $fp

    if {$content eq ""} {
        puts "(No output captured)"
    } else {
        puts $content
    }
} else {
    puts "(Log file not created)"
}

puts ""
puts "Test complete."
