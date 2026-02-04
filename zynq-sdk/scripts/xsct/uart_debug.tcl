# uart_debug.tcl - 深度 UART 调试
# 检查时钟、MIO 和 UART 配置

puts "=============================================="
puts "     UART DEEP DEBUG"
puts "=============================================="

connect
targets -set -filter {name =~ "ARM*#0"}

# 初始化
puts "Initializing PS..."
source C:/Files/verilog-workspace/my_Aloha/project/Aloha-HE_ZYNQ.sdk/AlohaHE_wrapper_hw_platform_0/ps7_init.tcl

# 不要复位处理器，直接检查状态
puts ""
puts "========== SLCR REGISTERS =========="

# SLCR 基地址
set SLCR_BASE 0xF8000000

# UART 时钟控制
set UART_CLK_CTRL [expr {$SLCR_BASE + 0x154}]
set uart_clk [mrd -value $UART_CLK_CTRL 1]
puts [format "UART_CLK_CTRL (0xF8000154): 0x%08X" $uart_clk]

# 检查 UART0 时钟使能 (bit 0)
if {[expr {$uart_clk & 0x01}]} {
    puts "  UART0 clock: ENABLED"
} else {
    puts "  UART0 clock: DISABLED *** PROBLEM ***"
}

# 检查 UART1 时钟使能 (bit 1)
if {[expr {$uart_clk & 0x02}]} {
    puts "  UART1 clock: ENABLED"
} else {
    puts "  UART1 clock: DISABLED"
}

# UART 复位控制
set UART_RST_CTRL [expr {$SLCR_BASE + 0x228}]
set uart_rst [mrd -value $UART_RST_CTRL 1]
puts [format "UART_RST_CTRL (0xF8000228): 0x%08X" $uart_rst]

if {[expr {$uart_rst & 0x01}]} {
    puts "  UART0: IN RESET *** PROBLEM ***"
} else {
    puts "  UART0: NOT in reset (good)"
}

if {[expr {$uart_rst & 0x02}]} {
    puts "  UART1: IN RESET"
} else {
    puts "  UART1: NOT in reset"
}

# MIO 配置 - UART0 TX/RX 引脚
puts ""
puts "========== MIO PIN CONFIGURATION =========="

# MIO 14/15 通常用于 UART0
# MIO_PIN_14 = 0xF8000738, MIO_PIN_15 = 0xF800073C
set MIO_PIN_14 [expr {$SLCR_BASE + 0x738}]
set MIO_PIN_15 [expr {$SLCR_BASE + 0x73C}]

set mio14 [mrd -value $MIO_PIN_14 1]
set mio15 [mrd -value $MIO_PIN_15 1]

puts [format "MIO_PIN_14 (0xF8000738): 0x%08X" $mio14]
puts [format "MIO_PIN_15 (0xF800073C): 0x%08X" $mio15]

# MIO 48/49 也可能用于 UART0 (Bank 1)
set MIO_PIN_48 [expr {$SLCR_BASE + 0x7C0}]
set MIO_PIN_49 [expr {$SLCR_BASE + 0x7C4}]

set mio48 [mrd -value $MIO_PIN_48 1]
set mio49 [mrd -value $MIO_PIN_49 1]

puts [format "MIO_PIN_48 (0xF80007C0): 0x%08X" $mio48]
puts [format "MIO_PIN_49 (0xF80007C4): 0x%08X" $mio49]

puts ""
puts "========== UART0 DETAILED REGISTERS =========="

set UART0_BASE 0xE0000000
set regs {
    {0x00 "Control"}
    {0x04 "Mode"}
    {0x08 "IER"}
    {0x0C "IDR"}
    {0x10 "IMR"}
    {0x14 "ISR"}
    {0x18 "Baud Gen"}
    {0x1C "RX Timeout"}
    {0x20 "RX WaterMark"}
    {0x24 "Modem Ctrl"}
    {0x28 "Modem Status"}
    {0x2C "Channel Status"}
    {0x34 "Baud Divider"}
    {0x38 "Flow Delay"}
    {0x44 "TX FIFO Level"}
}

foreach reg $regs {
    set offset [lindex $reg 0]
    set name [lindex $reg 1]
    set addr [expr {$UART0_BASE + $offset}]
    set val [mrd -value $addr 1]
    puts [format "  0x%02X %-15s: 0x%08X" $offset $name $val]
}

# 检查 Channel Status 详细信息
puts ""
puts "========== CHANNEL STATUS BITS =========="
set UART_SR [expr {$UART0_BASE + 0x2C}]
set sr [mrd -value $UART_SR 1]

puts [format "Channel Status: 0x%08X" $sr]
puts "  Bit 0 (RX FIFO Trigger):    [expr {($sr >> 0) & 1}]"
puts "  Bit 1 (RX FIFO Empty):      [expr {($sr >> 1) & 1}]"
puts "  Bit 2 (RX FIFO Full):       [expr {($sr >> 2) & 1}]"
puts "  Bit 3 (TX FIFO Empty):      [expr {($sr >> 3) & 1}]"
puts "  Bit 4 (TX FIFO Not Full):   [expr {($sr >> 4) & 1}]  <-- Must be 1 to send"
puts "  Bit 5-7:                    Reserved"
puts "  Bit 11 (TX Active):         [expr {($sr >> 11) & 1}]"
puts "  Bit 12 (RX Active):         [expr {($sr >> 12) & 1}]"

disconnect
puts ""
puts "Debug complete."
