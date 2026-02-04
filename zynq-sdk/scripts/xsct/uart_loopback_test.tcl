# uart_loopback_test.tcl - 直接通过 XSCT 写 UART 寄存器测试
# 用法: xsct uart_loopback_test.tcl

puts "=============================================="
puts "     UART HARDWARE TEST"
puts "=============================================="
puts ""

# PS7 UART0 寄存器地址
set UART0_BASE 0xE0000000
set UART_CR    [expr {$UART0_BASE + 0x00}]  ;# Control Register
set UART_MR    [expr {$UART0_BASE + 0x04}]  ;# Mode Register
set UART_SR    [expr {$UART0_BASE + 0x2C}]  ;# Status Register
set UART_FIFO  [expr {$UART0_BASE + 0x30}]  ;# TX/RX FIFO
set UART_BDIV  [expr {$UART0_BASE + 0x34}]  ;# Baud Rate Divider
set UART_CD    [expr {$UART0_BASE + 0x18}]  ;# Baud Rate Generator

# PS7 UART1 寄存器地址
set UART1_BASE 0xE0001000

connect
targets -set -filter {name =~ "ARM*#0"}

# 先初始化 PS
puts "Initializing PS..."
source C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/AlohaHE_wrapper_hw_platform_0/ps7_init.tcl
rst -processor
ps7_init
ps7_post_config

puts ""
puts "Reading UART0 registers..."
puts "UART0 Base: 0xE0000000"
puts ""

# 读取 UART0 寄存器
set cr_val [mrd -value $UART_CR 1]
set mr_val [mrd -value $UART_MR 1]
set sr_val [mrd -value $UART_SR 1]
set bdiv_val [mrd -value $UART_BDIV 1]
set cd_val [mrd -value $UART_CD 1]

puts [format "Control Register (CR):   0x%08X" $cr_val]
puts [format "Mode Register (MR):      0x%08X" $mr_val]
puts [format "Status Register (SR):    0x%08X" $sr_val]
puts [format "Baud Divider (BDIV):     0x%08X -> %d" $bdiv_val $bdiv_val]
puts [format "Clock Divider (CD):      0x%08X -> %d" $cd_val $cd_val]

# 检查 UART 是否使能
puts ""
if {[expr {$cr_val & 0x10}]} {
    puts "UART0 TX: ENABLED"
} else {
    puts "UART0 TX: DISABLED"
}
if {[expr {$cr_val & 0x04}]} {
    puts "UART0 RX: ENABLED"
} else {
    puts "UART0 RX: DISABLED"
}

# 计算波特率 (假设 UART_REF_CLK = 100MHz)
set uart_clk 100000000
if {$cd_val > 0 && $bdiv_val > 0} {
    set baud_rate [expr {$uart_clk / ($cd_val * ($bdiv_val + 1))}]
    puts ""
    puts [format "Calculated Baud Rate: %d (approx)" $baud_rate]
}

# 读取 UART1 看是否也被使能
puts ""
puts "Reading UART1 registers..."
set UART1_CR [expr {$UART1_BASE + 0x00}]
set UART1_SR [expr {$UART1_BASE + 0x2C}]
set cr1_val [mrd -value $UART1_CR 1]
set sr1_val [mrd -value $UART1_SR 1]
puts [format "UART1 Control Register:  0x%08X" $cr1_val]
puts [format "UART1 Status Register:   0x%08X" $sr1_val]

# 尝试发送测试字符
puts ""
puts "Sending test characters via UART0..."

# 等待 TX FIFO 准备好 (SR bit 4 = TX FIFO not full)
set timeout 100
while {$timeout > 0} {
    set sr [mrd -value $UART_SR 1]
    if {[expr {$sr & 0x10}]} {
        break
    }
    after 10
    incr timeout -1
}

if {$timeout > 0} {
    # 发送 "TEST\r\n"
    foreach char {84 69 83 84 13 10} {
        mwr $UART_FIFO $char
        after 1
    }
    puts "Sent: TEST<CR><LF>"
} else {
    puts "ERROR: TX FIFO timeout"
}

puts ""
puts "Now check your serial terminal (COM6 @ 115200 or calculated baud rate)"
puts "You should see 'TEST' if the connection is correct"

disconnect
puts ""
puts "Test complete."
