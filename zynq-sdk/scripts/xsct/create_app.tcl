# create_app.tcl - 创建应用程序项目
# 用法: xsct create_app.tcl <workspace> <bsp_name> <app_name> [template]
#
# 模板选项:
#   - "Hello World" (默认)
#   - "Empty Application"
#   - "Zynq FSBL"
#   - "Memory Tests"
#   - "Peripheral Tests"
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

if {[llength $argv] < 3} {
    puts "Usage: xsct create_app.tcl <workspace> <bsp_name> <app_name> \[template\]"
    puts ""
    puts "Templates:"
    puts "  - \"Hello World\" (default)"
    puts "  - \"Empty Application\""
    puts "  - \"Zynq FSBL\""
    puts "  - \"Memory Tests\""
    puts "  - \"Peripheral Tests\""
    exit 1
}

set workspace [lindex $argv 0]
set bsp_name [lindex $argv 1]
set app_name [lindex $argv 2]
set template [expr {[llength $argv] >= 4 ? [lindex $argv 3] : "Hello World"}]

puts ""
puts "=============================================="
puts "         CREATE APPLICATION"
puts "=============================================="
puts "Workspace:  $workspace"
puts "BSP:        $bsp_name"
puts "App name:   $app_name"
puts "Template:   $template"
puts ""

# 设置工作区
puts "Setting workspace..."
setws $workspace

# 获取 BSP 关联的硬件项目
set existing [getprojects]
if {[lsearch -exact $existing $bsp_name] < 0} {
    puts "ERROR: BSP '$bsp_name' not found in workspace."
    puts "Available projects: $existing"
    exit 1
}

# 获取硬件项目名称 (从 BSP)
# 通过查找 _hw_platform 结尾的项目
set hw_name ""
foreach proj $existing {
    if {[string match "*_hw_platform*" $proj]} {
        set hw_name $proj
        break
    }
}

if {$hw_name eq ""} {
    puts "ERROR: Cannot find hardware platform project."
    exit 1
}

puts "Hardware platform: $hw_name"

# 获取处理器
set processor "ps7_cortexa9_0"

# 检查应用是否已存在
if {[lsearch -exact $existing $app_name] >= 0} {
    puts "Application '$app_name' already exists. Deleting and recreating..."
    deleteprojects -name $app_name
}

# 创建应用
puts ""
puts "Creating application..."
createapp -name $app_name -app [list $template] -hwproject $hw_name -proc $processor -bsp $bsp_name

# 构建应用
puts ""
puts "Building application..."
projects -build -type app -name $app_name

# 检查 ELF 文件
set elf_path "$workspace/$app_name/Debug/$app_name.elf"
if {[file exists $elf_path]} {
    puts ""
    puts "=============================================="
    puts "Application built successfully!"
    puts "ELF file: $elf_path"
    puts "=============================================="
} else {
    puts ""
    puts "WARNING: ELF file not found at expected location."
    puts "Check build output for errors."
}

puts ""
puts "Next step - Run on target:"
puts "  xsct download_elf.tcl $elf_path"
