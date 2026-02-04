# uart_enable_and_send.tcl - 完整初始化 UART0 并发送测试
# 用法: xsct uart_enable_and_send.tcl

puts "=============================================="
puts "     UART FULL INITIALIZATION AND TEST"
puts "=============================================="

connect
targets -set -filter {name =~ "ARM*#0"}

# 运行 ps7_init
puts "Running ps7_init..."
source C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/AlohaHE_wrapper_hw_platform_0/ps7_init.tcl
rst -processor
ps7_init
ps7_post_config

# UART0 寄存器
set UART0_BASE 0xE0000000
set UART_CR    [expr {$UART0_BASE + 0x00}]
set UART_MR    [expr {$UART0_BASE + 0x04}]
set UART_SR    [expr {$UART0_BASE + 0x2C}]
set UART_FIFO  [expr {$UART0_BASE + 0x30}]
set UART_BDIV  [expr {$UART0_BASE + 0x34}]
set UART_CD    [expr {$UART0_BASE + 0x18}]

puts ""
puts "Step 1: Disable UART..."
mwr $UART_CR 0x00
after 10

puts "Step 2: Reset TX and RX paths..."
# bit 0 = TX reset, bit 1 = RX reset
mwr $UART_CR 0x03
after 10

puts "Step 3: Configure mode (8N1)..."
# Mode: 8 data bits, no parity, 1 stop bit
# 0x20 = CHMODE=00 (normal), NBSTOP=00 (1 stop), PAR=100 (none), CHRL=00 (8 bits)
mwr $UART_MR 0x20
after 10

puts "Step 4: Set baud rate 115200..."
# For 100 MHz ref clock: CD=124, BDIV=6 -> 115207 baud
mwr $UART_CD 124
mwr $UART_BDIV 6
after 10

puts "Step 5: Enable TX and RX..."
# Control: TX enable (bit 4), RX enable (bit 2)
mwr $UART_CR 0x14
after 10

puts ""
puts "UART0 Configuration:"
puts [format "  Control: 0x%08X" [mrd -value $UART_CR 1]]
puts [format "  Mode:    0x%08X" [mrd -value $UART_MR 1]]
puts [format "  Status:  0x%08X" [mrd -value $UART_SR 1]]
puts [format "  CD:      %d" [mrd -value $UART_CD 1]]
puts [format "  BDIV:    %d" [mrd -value $UART_BDIV 1]]

# 检查 TX FIFO 状态
set sr [mrd -value $UART_SR 1]
puts ""
puts "TX FIFO Status:"
puts "  Empty:    [expr {($sr & 0x08) ? \"YES\" : \"NO\"}]"
puts "  Not Full: [expr {($sr & 0x10) ? \"YES (can send)\" : \"NO (cannot send)\"}]"

# 发送测试
puts ""
puts "Sending test message..."

set message "\r\n=== UART0 TEST ===\r\nHello from XSCT!\r\n"

foreach char [split $message ""] {
    scan $char %c code

    # 等待 TX 就绪 (最多 10ms)
    set timeout 100
    while {$timeout > 0} {
        set sr [mrd -value $UART_SR 1]
        if {[expr {$sr & 0x10}]} {
            break
        }
        after 1
        incr timeout -1
    }

    if {$timeout > 0} {
        mwr $UART_FIFO $code
    } else {
        puts "TX timeout at char '$char'"
        break
    }
}

# 等待发送完成
puts "Waiting for TX to complete..."
set timeout 100
while {$timeout > 0} {
    set sr [mrd -value $UART_SR 1]
    if {[expr {$sr & 0x08}]} {
        break
    }
    after 10
    incr timeout -1
}

set final_sr [mrd -value $UART_SR 1]
puts [format "Final Status: 0x%08X" $final_sr]

puts ""
puts "TX FIFO Level: [mrd -value [expr {$UART0_BASE + 0x44}] 1]"

disconnect
puts "Done. Check COM6 @ 115200"
