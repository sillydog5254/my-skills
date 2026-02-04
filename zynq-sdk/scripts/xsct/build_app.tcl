# build_app.tcl - 编译应用程序
# 用法: xsct build_app.tcl <workspace> <app_name> [clean]
#
# 注意: 使用 D:/Program-Files/Xilinx/SDK/2019.1/bin/xsct.bat 运行

if {[llength $argv] < 2} {
    puts "Usage: xsct build_app.tcl <workspace> <app_name> \[clean\]"
    exit 1
}

set workspace [lindex $argv 0]
set app_name [lindex $argv 1]
set do_clean [expr {[llength $argv] >= 3 && [lindex $argv 2] eq "clean"}]

puts ""
puts "=============================================="
puts "         BUILD APPLICATION"
puts "=============================================="
puts "Workspace: $workspace"
puts "App name:  $app_name"
puts "Clean:     $do_clean"
puts ""

# 设置工作区
puts "Setting workspace..."
setws $workspace

# 验证项目存在
set existing [getprojects]
if {[lsearch -exact $existing $app_name] < 0} {
    puts "ERROR: Application '$app_name' not found in workspace."
    puts "Available projects: $existing"
    exit 1
}

# 清理（如果请求）
if {$do_clean} {
    puts "Cleaning project..."
    projects -clean -type app -name $app_name
}

# 编译
puts "Building project..."
projects -build -type app -name $app_name

# 检查 ELF 文件
set elf_path "$workspace/$app_name/Debug/$app_name.elf"
if {[file exists $elf_path]} {
    set elf_size [file size $elf_path]
    puts ""
    puts "=============================================="
    puts "Build successful!"
    puts "ELF file: $elf_path"
    puts "Size:     $elf_size bytes"
    puts "=============================================="
} else {
    # 尝试 Release 配置
    set elf_path "$workspace/$app_name/Release/$app_name.elf"
    if {[file exists $elf_path]} {
        set elf_size [file size $elf_path]
        puts ""
        puts "=============================================="
        puts "Build successful!"
        puts "ELF file: $elf_path"
        puts "Size:     $elf_size bytes"
        puts "=============================================="
    } else {
        puts ""
        puts "ERROR: Build may have failed. ELF file not found."
        exit 1
    }
}
