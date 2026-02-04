# hw_server_control.tcl - hw_server 管理
# 用法: xsct hw_server_control.tcl [start|stop|status]
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

set action [expr {[llength $argv] >= 1 ? [lindex $argv 0] : "status"}]

proc hw_server_status {} {
    puts ""
    puts "Checking hw_server status..."

    if {[catch {connect -url tcp:127.0.0.1:3121} result]} {
        puts "hw_server: NOT RUNNING"
        puts ""
        puts "To start hw_server:"
        puts "  \"D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat\""
        return 0
    } else {
        puts "hw_server: RUNNING (port 3121)"
        puts ""
        puts "Available targets:"
        targets
        disconnect
        return 1
    }
}

proc hw_server_start {} {
    puts ""
    puts "Starting hw_server..."

    # 检查是否已在运行
    if {[catch {connect -url tcp:127.0.0.1:3121}]} {
        # 未运行，启动它
        puts "Launching hw_server in background..."

        # 使用 exec 在后台启动
        if {[catch {exec "D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat" &} result]} {
            puts "WARNING: Could not start hw_server automatically."
            puts "Please start it manually:"
            puts "  \"D:/Program-Files/Xilinx/SDK/2019.1/bin/hw_server.bat\""
            return 0
        }

        # 等待启动
        puts "Waiting for hw_server to start..."
        after 3000

        # 再次检查
        return [hw_server_status]
    } else {
        puts "hw_server is already running."
        disconnect
        return 1
    }
}

proc hw_server_stop {} {
    puts ""
    puts "Stopping hw_server..."

    # Windows: 使用 taskkill
    if {[catch {exec taskkill /IM hw_server.exe /F} result]} {
        puts "Note: hw_server may not have been running."
    } else {
        puts "hw_server stopped."
    }

    return 1
}

puts "=============================================="
puts "       HW_SERVER CONTROL"
puts "=============================================="

switch -exact $action {
    start {
        hw_server_start
    }
    stop {
        hw_server_stop
    }
    status {
        hw_server_status
    }
    default {
        puts "Usage: xsct hw_server_control.tcl \[start|stop|status\]"
        puts ""
        puts "Commands:"
        puts "  start  - Start hw_server"
        puts "  stop   - Stop hw_server"
        puts "  status - Check hw_server status (default)"
    }
}
