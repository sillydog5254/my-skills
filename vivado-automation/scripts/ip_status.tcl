# ip_status.tcl - 报告项目中IP核的状态
# 用法: vivado -mode batch -source ip_status.tcl -tclargs <project.xpr>

if {$argc < 1} {
    puts "Usage: vivado -mode batch -source ip_status.tcl -tclargs <project.xpr>"
    exit 1
}

set proj_path [lindex $argv 0]

puts "Opening project: $proj_path"
open_project $proj_path

puts "\n=========================================="
puts "IP Status Report"
puts "==========================================\n"

# 获取所有IP文件
set ip_files [get_files -filter {FILE_TYPE == "IP"}]
puts "=== IP Files in Project ==="
puts "Total: [llength $ip_files] IPs\n"

foreach ip $ip_files {
    set ip_name [get_property NAME $ip]
    # 使用catch处理可能不存在的属性
    if {[catch {set ip_vlnv [get_property IPDEF $ip]} err]} {
        set ip_vlnv "N/A"
    }
    if {[catch {set is_locked [get_property IS_LOCKED $ip]} err]} {
        set is_locked "N/A"
    }
    if {[catch {set upgrade_versions [get_property UPGRADE_VERSIONS $ip]} err]} {
        set upgrade_versions ""
    }

    puts "$ip_name"
    puts "  VLNV: $ip_vlnv"
    puts "  Locked: $is_locked"
    if {$upgrade_versions ne ""} {
        puts "  Available upgrades: $upgrade_versions"
    }
    puts ""
}

puts "\n=== IP Status Summary ==="
report_ip_status -return_string

close_project
puts "\nDone."
