# reset_all_ooc.tcl - 重置所有 OOC (Out-of-Context) 综合运行
# 用法: vivado -mode batch -source reset_all_ooc.tcl -tclargs <project.xpr>
#
# 这解决了 Block Design 中 OOC 模块缓存导致 RTL 修改不生效的问题

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
            puts "Usage: vivado -mode batch -source reset_all_ooc.tcl -tclargs <project.xpr>"
            exit 1
        }
    }
} else {
    set proj_path [lindex $argv 0]
}

puts "Opening project: $proj_path"
open_project $proj_path

puts ""
puts "=============================================="
puts "    RESETTING ALL SYNTHESIS/IMPL RUNS"
puts "=============================================="
puts ""

# 获取所有综合运行
set synth_runs [get_runs -filter {IS_SYNTHESIS}]
puts "Found [llength $synth_runs] synthesis run(s):"

foreach run $synth_runs {
    set status [get_property STATUS $run]
    set is_ooc [get_property IS_OOCDIR $run]
    set ooc_label ""
    if {$is_ooc} {
        set ooc_label "(OOC)"
    }
    puts "  - $run $ooc_label : $status"
}

puts ""
puts "Resetting all synthesis runs..."
foreach run $synth_runs {
    puts "  Resetting: $run"
    reset_run $run
}

# 获取所有实现运行
set impl_runs [get_runs -filter {IS_IMPLEMENTATION}]
puts ""
puts "Found [llength $impl_runs] implementation run(s):"

foreach run $impl_runs {
    set status [get_property STATUS $run]
    puts "  - $run : $status"
}

puts ""
puts "Resetting all implementation runs..."
foreach run $impl_runs {
    puts "  Resetting: $run"
    reset_run $run
}

puts ""
puts "=============================================="
puts "All runs have been reset successfully."
puts "=============================================="
puts ""
puts "You can now run synthesis with:"
puts "  vivado -mode batch -source run_synth.tcl -tclargs $proj_path"

close_project
