# memory_access.tcl - 内存读写
# 用法: xsct memory_access.tcl read <address> [count] [size]
#       xsct memory_access.tcl write <address> <value> [size]
#
# size: b=byte, h=halfword(16-bit), w=word(32-bit, default)
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

if {[llength $argv] < 2} {
    puts "Usage:"
    puts "  xsct memory_access.tcl read <address> \[count\] \[size\]"
    puts "  xsct memory_access.tcl write <address> <value> \[size\]"
    puts ""
    puts "Arguments:"
    puts "  address - Memory address (hex with 0x prefix or decimal)"
    puts "  count   - Number of units to read (default: 1)"
    puts "  value   - Value to write"
    puts "  size    - b=byte, h=halfword, w=word (default)"
    puts ""
    puts "Examples:"
    puts "  read 0x43C00000          # Read 1 word from PL register"
    puts "  read 0x43C00000 16       # Read 16 words"
    puts "  read 0x43C00000 4 b      # Read 4 bytes"
    puts "  write 0x43C00000 0x1234  # Write word"
    puts "  write 0x43C00000 0xFF b  # Write byte"
    exit 1
}

set action [lindex $argv 0]
set address [lindex $argv 1]

puts ""
puts "=============================================="
puts "         MEMORY ACCESS"
puts "=============================================="
puts ""

# 连接
puts "Connecting..."
if {[catch {connect} result]} {
    puts "ERROR: Failed to connect to hw_server."
    exit 1
}

# 选择 ARM 核心
if {[catch {targets -set -filter {name =~ "*ARM*#0"}} result]} {
    puts "ERROR: Cannot find ARM processor."
    disconnect
    exit 1
}

puts "Target: ARM Cortex-A9 #0"
puts ""

switch -exact $action {
    read -
    rd -
    r {
        set count [expr {[llength $argv] >= 3 ? [lindex $argv 2] : 1}]
        set size [expr {[llength $argv] >= 4 ? [lindex $argv 3] : "w"}]

        puts "Reading from $address (count=$count, size=$size)..."
        puts ""

        # 根据 size 设置参数
        switch -exact $size {
            b -
            byte {
                set size_opt "-size b"
            }
            h -
            half {
                set size_opt "-size h"
            }
            w -
            word -
            default {
                set size_opt ""
            }
        }

        # 读取内存
        if {[catch {
            if {$size_opt ne ""} {
                set result [mrd $size_opt $address $count]
            } else {
                set result [mrd $address $count]
            }
            puts $result
        } err]} {
            puts "ERROR: Failed to read memory: $err"
        }
    }

    write -
    wr -
    w {
        if {[llength $argv] < 3} {
            puts "ERROR: Missing value for write operation."
            disconnect
            exit 1
        }

        set value [lindex $argv 2]
        set size [expr {[llength $argv] >= 4 ? [lindex $argv 3] : "w"}]

        puts "Writing $value to $address (size=$size)..."

        # 根据 size 设置参数
        switch -exact $size {
            b -
            byte {
                set size_opt "-size b"
            }
            h -
            half {
                set size_opt "-size h"
            }
            w -
            word -
            default {
                set size_opt ""
            }
        }

        # 写入内存
        if {[catch {
            if {$size_opt ne ""} {
                mwr $size_opt $address $value
            } else {
                mwr $address $value
            }
            puts "Write successful."

            # 回读验证
            puts ""
            puts "Readback verification:"
            if {$size_opt ne ""} {
                mrd $size_opt $address 1
            } else {
                mrd $address 1
            }
        } err]} {
            puts "ERROR: Failed to write memory: $err"
        }
    }

    dump {
        # 内存转储
        set count [expr {[llength $argv] >= 3 ? [lindex $argv 2] : 64}]

        puts "Memory dump from $address ($count words):"
        puts ""
        puts "Address      +0         +4         +8         +C"
        puts "------------ ---------- ---------- ---------- ----------"

        if {[catch {
            set data [mrd -value $address $count]

            set base_addr [expr $address]
            set idx 0
            foreach val $data {
                if {$idx % 4 == 0} {
                    puts -nonewline [format "0x%08X: " [expr {$base_addr + $idx * 4}]]
                }
                puts -nonewline [format "0x%08X " $val]
                if {$idx % 4 == 3} {
                    puts ""
                }
                incr idx
            }
            if {$idx % 4 != 0} {
                puts ""
            }
        } err]} {
            puts "ERROR: Failed to dump memory: $err"
        }
    }

    default {
        puts "Unknown action: $action"
        puts "Use 'read' or 'write'"
    }
}

puts ""
disconnect
