# uart_send_test.tcl - 重新初始化 UART 并发送测试
# 用法: xsct uart_send_test.tcl

puts "=============================================="
puts "     UART SEND TEST"
puts "=============================================="

# PS7 UART0 寄存器地址
set UART0_BASE 0xE0000000
set UART_CR    [expr {$UART0_BASE + 0x00}]
set UART_MR    [expr {$UART0_BASE + 0x04}]
set UART_SR    [expr {$UART0_BASE + 0x2C}]
set UART_FIFO  [expr {$UART0_BASE + 0x30}]

connect
targets -set -filter {name =~ "ARM*#0"}

# 初始化
puts "Initializing PS..."
source C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/AlohaHE_wrapper_hw_platform_0/ps7_init.tcl
rst -processor
ps7_init
ps7_post_config

# 重置 UART
puts ""
puts "Resetting UART0..."
# CR bit 0 = SW reset TX, bit 1 = SW reset RX
mwr $UART_CR 0x03
after 10

# 使能 TX 和 RX
# CR bit 4 = TX enable, bit 2 = RX enable
mwr $UART_CR 0x14
after 10

# 检查状态
set sr [mrd -value $UART_SR 1]
puts [format "UART0 Status: 0x%08X" $sr]

# SR bit 3 = TX FIFO empty, bit 4 = TX FIFO not full
puts ""
if {[expr {$sr & 0x08}]} {
    puts "TX FIFO: EMPTY (good)"
} else {
    puts "TX FIFO: NOT EMPTY"
}

if {[expr {$sr & 0x10}]} {
    puts "TX FIFO: NOT FULL (ready to send)"
} else {
    puts "TX FIFO: FULL (cannot send)"
}

# 发送测试消息
puts ""
puts "Sending test message..."

set message "=== UART TEST FROM XSCT ===\r\n"
foreach char [split $message ""] {
    scan $char %c code

    # 等待 TX FIFO 有空间
    set wait 1000
    while {$wait > 0} {
        set sr [mrd -value $UART_SR 1]
        if {[expr {$sr & 0x10}]} {
            break
        }
        incr wait -1
    }

    if {$wait > 0} {
        mwr $UART_FIFO $code
    } else {
        puts "TX FIFO full, cannot send more"
        break
    }
}

puts "Message sent!"

# 再发几行
after 100
set message2 "Hello from Zynq FPGA!\r\n"
foreach char [split $message2 ""] {
    scan $char %c code
    set wait 100
    while {$wait > 0} {
        set sr [mrd -value $UART_SR 1]
        if {[expr {$sr & 0x10}]} {
            break
        }
        incr wait -1
    }
    if {$wait > 0} {
        mwr $UART_FIFO $code
    }
}

puts ""
puts "Check COM6 at 115200 baud for output"

disconnect
