# ip_search.tcl - 搜索可用的 IP 核
# 用法: vivado -mode batch -source ip_search.tcl -tclargs <project.xpr> [search_pattern]
#
# 参数:
#   project.xpr    - Vivado 项目文件
#   search_pattern - 可选，搜索关键字 (如 "axi", "bram", "uart")

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source ip_search.tcl -tclargs <project.xpr> \[search_pattern\]"
    puts ""
    puts "Examples:"
    puts "  # List all IPs"
    puts "  vivado -mode batch -source ip_search.tcl -tclargs project.xpr"
    puts ""
    puts "  # Search for AXI related IPs"
    puts "  vivado -mode batch -source ip_search.tcl -tclargs project.xpr axi"
    puts ""
    puts "  # Search for BRAM related IPs"
    puts "  vivado -mode batch -source ip_search.tcl -tclargs project.xpr bram"
    exit 1
}

set proj_path [lindex $argv 0]
set search_pattern [expr {$argc > 1 ? [lindex $argv 1] : ""}]

puts "============================================"
puts "           SEARCH AVAILABLE IPS"
puts "============================================"
puts "Project: $proj_path"
if {$search_pattern ne ""} {
    puts "Pattern: $search_pattern"
} else {
    puts "Pattern: (all)"
}
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 更新 IP 目录
puts "Updating IP catalog..."
update_ip_catalog

# 获取所有 IP
puts "\nSearching IPs..."
if {$search_pattern ne ""} {
    set ips [get_ipdefs -filter "NAME =~ *$search_pattern* || DISPLAY_NAME =~ *$search_pattern*"]
} else {
    set ips [get_ipdefs]
}

puts "\n=== Available IPs ([llength $ips] found) ===\n"

# 按类别组织
set categories [dict create]
foreach ip $ips {
    set vendor [lindex [split $ip :] 0]
    set library [lindex [split $ip :] 1]
    set name [lindex [split $ip :] 2]
    set version [lindex [split $ip :] 3]

    set key "$vendor:$library"
    if {![dict exists $categories $key]} {
        dict set categories $key [list]
    }
    dict lappend categories $key "$name:$version"
}

# 显示结果
dict for {category ips} $categories {
    puts "--- $category ---"
    foreach ip [lsort -unique $ips] {
        set parts [split $ip :]
        set name [lindex $parts 0]
        set ver [lindex $parts 1]
        puts "  $name (v$ver)"
        puts "    VLNV: ${category}:$ip"
    }
    puts ""
}

# 显示常用 IP 参考
if {$search_pattern eq ""} {
    puts "=== Common IP Reference ===\n"
    puts "Zynq Processing System:"
    puts "  xilinx.com:ip:processing_system7:5.5"
    puts ""
    puts "Memory:"
    puts "  xilinx.com:ip:axi_bram_ctrl:4.1"
    puts "  xilinx.com:ip:blk_mem_gen:8.4"
    puts ""
    puts "Peripherals:"
    puts "  xilinx.com:ip:axi_gpio:2.0"
    puts "  xilinx.com:ip:axi_uartlite:2.0"
    puts "  xilinx.com:ip:axi_timer:2.0"
    puts ""
    puts "DMA:"
    puts "  xilinx.com:ip:axi_dma:7.1"
    puts "  xilinx.com:ip:axi_cdma:4.1"
    puts ""
    puts "Interconnect:"
    puts "  xilinx.com:ip:axi_interconnect:2.1"
    puts "  xilinx.com:ip:smartconnect:1.0"
    puts ""
    puts "Infrastructure:"
    puts "  xilinx.com:ip:proc_sys_reset:5.0"
    puts "  xilinx.com:ip:clk_wiz:6.0"
    puts ""
    puts "Utilities:"
    puts "  xilinx.com:ip:xlconcat:2.1"
    puts "  xilinx.com:ip:xlconstant:1.1"
    puts "  xilinx.com:ip:xlslice:1.0"
}

close_project
puts "\nDone."
