# resource_analysis.tcl - 资源利用率分析
# 用法: vivado -mode batch -source resource_analysis.tcl -tclargs <project.xpr> [synth_run]
#
# 输出：
#   - LUT, FF, BRAM, DSP 使用量和利用率
#   - 按模块的层次化资源分解

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
            puts "Usage: vivado -mode batch -source resource_analysis.tcl -tclargs <project.xpr> \[run_name\]"
            puts "No .xpr file found in current directory."
            exit 1
        }
    }
} else {
    set proj_path [lindex $argv 0]
}

set run_name [expr {$argc > 1 ? [lindex $argv 1] : "synth_1"}]

puts "Opening project: $proj_path"
open_project $proj_path

# 检查运行状态
set run_status [get_property STATUS [get_runs $run_name]]
if {![string match "*Complete*" $run_status]} {
    puts "ERROR: Run '$run_name' is not complete."
    puts "Status: $run_status"
    close_project
    exit 1
}

# 打开运行
puts "Opening run: $run_name"
open_run $run_name

# 获取器件信息
set part [get_property PART [current_project]]

puts ""
puts "=============================================="
puts "        RESOURCE UTILIZATION REPORT"
puts "=============================================="
puts "Project: [file tail $proj_path]"
puts "Run:     $run_name"
puts "Device:  $part"
puts ""

# 定义器件资源 (Zynq-7020)
# 根据实际器件自动获取
set device_resources [dict create]
if {[string match "*xc7z020*" $part]} {
    dict set device_resources LUT 53200
    dict set device_resources FF 106400
    dict set device_resources BRAM 140
    dict set device_resources DSP 220
} elseif {[string match "*xc7z030*" $part]} {
    dict set device_resources LUT 78600
    dict set device_resources FF 157200
    dict set device_resources BRAM 265
    dict set device_resources DSP 400
} elseif {[string match "*xc7z045*" $part]} {
    dict set device_resources LUT 218600
    dict set device_resources FF 437200
    dict set device_resources BRAM 545
    dict set device_resources DSP 900
} else {
    # 默认值
    dict set device_resources LUT 50000
    dict set device_resources FF 100000
    dict set device_resources BRAM 150
    dict set device_resources DSP 200
}

# 获取实际使用量
set lut_used [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ CLB.LUT.*}]]
set ff_used [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ CLB.FDRE.* || PRIMITIVE_TYPE =~ CLB.FDSE.* || PRIMITIVE_TYPE =~ CLB.FDCE.* || PRIMITIVE_TYPE =~ CLB.FDPE.*}]]
set bram_used [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ BMEM.BRAM.*}]]
set dsp_used [llength [get_cells -hierarchical -filter {PRIMITIVE_TYPE =~ ARITHMETIC.DSP.*}]]

# 计算利用率
set lut_avail [dict get $device_resources LUT]
set ff_avail [dict get $device_resources FF]
set bram_avail [dict get $device_resources BRAM]
set dsp_avail [dict get $device_resources DSP]

set lut_pct [format "%.2f" [expr {100.0 * $lut_used / $lut_avail}]]
set ff_pct [format "%.2f" [expr {100.0 * $ff_used / $ff_avail}]]
set bram_pct [format "%.2f" [expr {100.0 * $bram_used / $bram_avail}]]
set dsp_pct [format "%.2f" [expr {100.0 * $dsp_used / $dsp_avail}]]

puts "----------------------------------------------"
puts "SUMMARY"
puts "----------------------------------------------"
puts [format "%-10s %10s %10s %10s" "Resource" "Used" "Available" "Util%"]
puts "----------------------------------------------"
puts [format "%-10s %10d %10d %9s%%" "LUT" $lut_used $lut_avail $lut_pct]
puts [format "%-10s %10d %10d %9s%%" "FF" $ff_used $ff_avail $ff_pct]
puts [format "%-10s %10d %10d %9s%%" "BRAM" $bram_used $bram_avail $bram_pct]
puts [format "%-10s %10d %10d %9s%%" "DSP" $dsp_used $dsp_avail $dsp_pct]
puts "----------------------------------------------"
puts ""

# 层次化分析 - 获取顶层模块的子模块
puts "----------------------------------------------"
puts "HIERARCHICAL BREAKDOWN (Top-Level Modules)"
puts "----------------------------------------------"

set top_cells [get_cells -filter {IS_PRIMITIVE == 0}]
set module_stats [dict create]

foreach cell $top_cells {
    set cell_name [get_property NAME $cell]
    # 只获取第一层层次
    if {[string first "/" $cell_name] == -1} {
        set child_luts [llength [get_cells -hierarchical -filter "NAME =~ ${cell_name}/* && PRIMITIVE_TYPE =~ CLB.LUT.*"]]
        set child_ffs [llength [get_cells -hierarchical -filter "NAME =~ ${cell_name}/* && (PRIMITIVE_TYPE =~ CLB.FDRE.* || PRIMITIVE_TYPE =~ CLB.FDSE.*)"]]
        set child_brams [llength [get_cells -hierarchical -filter "NAME =~ ${cell_name}/* && PRIMITIVE_TYPE =~ BMEM.BRAM.*"]]
        set child_dsps [llength [get_cells -hierarchical -filter "NAME =~ ${cell_name}/* && PRIMITIVE_TYPE =~ ARITHMETIC.DSP.*"]]

        if {$child_luts > 0 || $child_ffs > 0 || $child_brams > 0 || $child_dsps > 0} {
            dict set module_stats $cell_name [list $child_luts $child_ffs $child_brams $child_dsps]
        }
    }
}

puts [format "%-40s %8s %8s %6s %6s" "Module" "LUT" "FF" "BRAM" "DSP"]
puts "----------------------------------------------------------------------"

dict for {module stats} $module_stats {
    set m_lut [lindex $stats 0]
    set m_ff [lindex $stats 1]
    set m_bram [lindex $stats 2]
    set m_dsp [lindex $stats 3]

    # 截断长模块名
    if {[string length $module] > 40} {
        set module "[string range $module 0 36]..."
    }
    puts [format "%-40s %8d %8d %6d %6d" $module $m_lut $m_ff $m_bram $m_dsp]
}

puts ""
puts "=============================================="
puts "Report generated successfully."
puts "=============================================="

close_project
