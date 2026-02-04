# zynq_ps_config.tcl - 查看和配置 Zynq Processing System 7 (PS) IP
# 用法:
#   查看: vivado -mode batch -source zynq_ps_config.tcl -tclargs <project.xpr> show [category]
#   修改: vivado -mode batch -source zynq_ps_config.tcl -tclargs <project.xpr> set <param> <value> [param2 value2 ...]
#
# 类别 (category):
#   all      - 所有配置 (非常长)
#   clocks   - 时钟配置 (FCLK)
#   uart     - UART 配置
#   gpio     - GPIO/MIO 配置
#   ddr      - DDR 内存配置
#   axi      - AXI 接口配置
#   periph   - 外设配置

if {$argc < 2} {
    puts "============================================"
    puts "     ZYNQ PS CONFIGURATION TOOL"
    puts "============================================"
    puts ""
    puts "Usage:"
    puts "  Show config:"
    puts "    vivado -mode batch -source zynq_ps_config.tcl -tclargs <project.xpr> show \[category\]"
    puts ""
    puts "  Set config:"
    puts "    vivado -mode batch -source zynq_ps_config.tcl -tclargs <project.xpr> set <param> <value> \[param2 value2 ...\]"
    puts ""
    puts "Categories for 'show':"
    puts "  all      - All configurations (very long)"
    puts "  clocks   - Clock settings (FCLK0-3)"
    puts "  uart     - UART configuration"
    puts "  gpio     - GPIO/MIO pin configuration"
    puts "  ddr      - DDR memory settings"
    puts "  axi      - AXI interface settings"
    puts "  periph   - Peripheral enables"
    puts "  preset   - Board preset information"
    puts ""
    puts "Examples:"
    puts "  # Show clock configuration"
    puts "  vivado -mode batch -source zynq_ps_config.tcl -tclargs project.xpr show clocks"
    puts ""
    puts "  # Change FCLK0 frequency to 100 MHz"
    puts "  vivado -mode batch -source zynq_ps_config.tcl -tclargs project.xpr set PCW_FPGA0_PERIPHERAL_FREQMHZ 100"
    puts ""
    puts "  # Enable UART1"
    puts "  vivado -mode batch -source zynq_ps_config.tcl -tclargs project.xpr set PCW_UART1_PERIPHERAL_ENABLE 1"
    exit 1
}

set proj_path [lindex $argv 0]
set action [lindex $argv 1]

puts "============================================"
puts "     ZYNQ PS CONFIGURATION"
puts "============================================"
puts "Project: $proj_path"
puts "Action:  $action"
puts "============================================"

# 打开项目
puts "\nOpening project..."
open_project $proj_path

# 获取 BD 文件
set bd_files [get_files *.bd]
if {[llength $bd_files] == 0} {
    puts "ERROR: No Block Design found."
    close_project
    exit 1
}
set bd_file [lindex $bd_files 0]

puts "Opening BD: $bd_file"
open_bd_design $bd_file

# 查找 PS7 IP
set ps7 [get_bd_cells -quiet -filter {VLNV =~ "*processing_system7*"}]
if {$ps7 eq ""} {
    puts "ERROR: No Zynq Processing System found in BD."
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

puts "Found PS7: $ps7"
puts ""

if {$action eq "show"} {
    # 显示配置
    set category [expr {$argc > 2 ? [lindex $argv 2] : "all"}]

    puts "=== PS7 Configuration (Category: $category) ===\n"

    # 定义各类别的过滤模式
    switch $category {
        "clocks" {
            set patterns {*FCLK* *CLK* *FREQ*}
            puts "--- Clock Configuration ---"
        }
        "uart" {
            set patterns {*UART*}
            puts "--- UART Configuration ---"
        }
        "gpio" {
            set patterns {*GPIO* *MIO* *EMIO*}
            puts "--- GPIO/MIO Configuration ---"
        }
        "ddr" {
            set patterns {*DDR* *DRAM* *MEMORY*}
            puts "--- DDR Configuration ---"
        }
        "axi" {
            set patterns {*AXI* *GP0* *GP1* *HP0* *HP1* *HP2* *HP3* *ACP*}
            puts "--- AXI Interface Configuration ---"
        }
        "periph" {
            set patterns {*PERIPHERAL_ENABLE* *USE_*}
            puts "--- Peripheral Enables ---"
        }
        "preset" {
            set patterns {*PRESET* *BOARD*}
            puts "--- Board Preset ---"
        }
        default {
            set patterns {*}
            puts "--- All Configuration ---"
        }
    }

    # 获取所有 CONFIG 属性
    set all_props [list_property $ps7 CONFIG.*]
    set count 0

    foreach prop $all_props {
        set match 0
        foreach pattern $patterns {
            if {[string match "CONFIG.$pattern" $prop] || [string match "CONFIG.PCW$pattern" $prop]} {
                set match 1
                break
            }
        }

        if {$match || $category eq "all"} {
            set value [get_property $prop $ps7]
            if {$value ne "" && $value ne "0" && $value ne "<Select>" && $value ne "Custom"} {
                # 移除 CONFIG. 前缀以便显示更清晰
                set short_name [string range $prop 7 end]
                puts [format "  %-50s = %s" $short_name $value]
                incr count
            }
        }
    }

    puts "\nTotal: $count parameters shown"

    # 显示一些关键的实际值
    if {$category eq "clocks" || $category eq "all"} {
        puts "\n--- Actual Clock Frequencies ---"
        foreach prop {PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ
                      PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ
                      PCW_ACT_APU_PERIPHERAL_FREQMHZ PCW_ACT_DCI_PERIPHERAL_FREQMHZ} {
            set value [get_property CONFIG.$prop $ps7]
            if {$value ne ""} {
                puts [format "  %-50s = %s MHz" $prop $value]
            }
        }
    }

} elseif {$action eq "set"} {
    # 设置配置
    if {$argc < 4} {
        puts "ERROR: Need parameter and value."
        puts "Usage: ... set <param> <value> [param2 value2 ...]"
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    # 解析参数对
    set config_list [list]
    for {set i 2} {$i < $argc} {incr i 2} {
        set param [lindex $argv $i]
        set value [lindex $argv [expr {$i + 1}]]

        if {$value eq ""} {
            puts "ERROR: Missing value for parameter '$param'"
            break
        }

        # 自动添加 CONFIG. 和 PCW_ 前缀
        if {![string match "CONFIG.*" $param]} {
            if {![string match "PCW_*" $param]} {
                set param "PCW_$param"
            }
            set param "CONFIG.$param"
        }

        lappend config_list $param $value
    }

    if {[llength $config_list] == 0} {
        puts "ERROR: No valid parameters to set."
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    # 显示将要修改的参数
    puts "\n=== Parameters to modify ==="
    foreach {param value} $config_list {
        set current [get_property -quiet $param $ps7]
        puts [format "  %s: %s -> %s" $param $current $value]
    }

    # 应用配置
    puts "\nApplying configuration..."
    if {[catch {set_property -dict $config_list $ps7} err]} {
        puts "ERROR: Failed to set properties - $err"
        puts ""
        puts "Note: Some PS7 parameters may require specific combinations."
        puts "Check Vivado documentation for valid parameter values."
        close_bd_design [current_bd_design]
        close_project
        exit 1
    }

    # 显示新值
    puts "\n=== Updated values ==="
    foreach {param value} $config_list {
        set new_value [get_property $param $ps7]
        puts [format "  %s = %s" $param $new_value]
    }

    # 验证设计
    puts "\nValidating design..."
    if {[catch {validate_bd_design} err]} {
        puts "WARNING: Validation issues: $err"
    }

    # 保存设计
    puts "\nSaving design..."
    save_bd_design

    puts "\n=== Configuration Updated Successfully ==="

} else {
    puts "ERROR: Unknown action '$action'. Use 'show' or 'set'."
    close_bd_design [current_bd_design]
    close_project
    exit 1
}

close_bd_design [current_bd_design]
close_project
puts "\nDone."
