# timing_analysis.tcl - 时序分析报告
# 用法: vivado -mode batch -source timing_analysis.tcl -tclargs <project.xpr> [impl_run]
#
# 输出：
#   - WNS (最差负时序裕量)
#   - TNS (总负时序裕量)
#   - WHS (最差保持时序裕量)
#   - THS (总保持时序裕量)
#   - 失败路径数量和详情

if {$argc < 1} {
    # 尝试自动检测 .xpr 文件
    set xpr_files [glob -nocomplain *.xpr]
    if {[llength $xpr_files] > 0} {
        set proj_path [lindex $xpr_files 0]
        puts "Auto-detected project: $proj_path"
    } else {
        set xpr_files [glob -nocomplain project/*.xpr]
        if {[llength $xpr_files] > 0} {
            set proj_path [lindex $xpr_files 0]
            puts "Auto-detected project: $proj_path"
        } else {
            puts "Usage: vivado -mode batch -source timing_analysis.tcl -tclargs <project.xpr> \[impl_run\]"
            puts "No .xpr file found in current directory."
            exit 1
        }
    }
} else {
    set proj_path [lindex $argv 0]
}

set impl_run [expr {$argc > 1 ? [lindex $argv 1] : "impl_1"}]

puts "Opening project: $proj_path"
open_project $proj_path

# 检查实现运行状态
set run_status [get_property STATUS [get_runs $impl_run]]
if {![string match "*Complete*" $run_status] && ![string match "*routed*" $run_status]} {
    puts "ERROR: Implementation run '$impl_run' is not complete."
    puts "Status: $run_status"
    puts "Please run implementation first."
    close_project
    exit 1
}

# 打开实现运行
puts "Opening implementation run: $impl_run"
open_run $impl_run

puts ""
puts "=============================================="
puts "          TIMING ANALYSIS REPORT"
puts "=============================================="
puts ""

# 获取时序统计
set wns [get_property STATS.WNS [get_runs $impl_run]]
set tns [get_property STATS.TNS [get_runs $impl_run]]
set whs [get_property STATS.WHS [get_runs $impl_run]]
set ths [get_property STATS.THS [get_runs $impl_run]]

puts "Setup Timing:"
puts "  WNS (Worst Negative Slack):  ${wns} ns"
puts "  TNS (Total Negative Slack):  ${tns} ns"
puts ""
puts "Hold Timing:"
puts "  WHS (Worst Hold Slack):      ${whs} ns"
puts "  THS (Total Hold Slack):      ${ths} ns"
puts ""

# 判断时序是否收敛
if {$wns >= 0 && $whs >= 0} {
    puts "TIMING STATUS: PASSED (All constraints met)"
} else {
    puts "TIMING STATUS: FAILED (Timing violations exist)"
}
puts ""

# 获取失败路径
puts "----------------------------------------------"
puts "TOP 10 CRITICAL PATHS (Setup)"
puts "----------------------------------------------"

set failing_paths [get_timing_paths -max_paths 10 -slack_lesser_than 0.1 -sort_by slack]
set path_count [llength $failing_paths]

if {$path_count == 0} {
    puts "No critical paths with slack < 0.1 ns"
} else {
    set idx 1
    foreach path $failing_paths {
        set slack [get_property SLACK $path]
        set from [get_property STARTPOINT_PIN $path]
        set to [get_property ENDPOINT_PIN $path]
        set levels [get_property LOGIC_LEVELS $path]
        set delay [get_property DATAPATH_DELAY $path]

        puts ""
        puts "Path #$idx:"
        puts "  Slack:        $slack ns"
        puts "  From:         $from"
        puts "  To:           $to"
        puts "  Logic Levels: $levels"
        puts "  Data Delay:   $delay ns"

        incr idx
    }
}

puts ""
puts "----------------------------------------------"
puts "CLOCK SUMMARY"
puts "----------------------------------------------"

set clocks [get_clocks]
foreach clk $clocks {
    set period [get_property PERIOD $clk]
    set freq [expr {1000.0 / $period}]
    puts "  $clk: ${period} ns (${freq} MHz)"
}

puts ""
puts "=============================================="
puts "Report generated successfully."
puts "=============================================="

close_project
