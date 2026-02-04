@echo off
REM run_xsim.bat - 直接运行 XSim 仿真（支持 IP 依赖）
REM 用法: run_xsim.bat <sim_dir> [sim_time]
REM
REM 参数:
REM   sim_dir   - 仿真脚本目录 (包含 compile.bat, elaborate.bat, simulate.bat)
REM   sim_time  - 可选的仿真时间 (如 "1000ns", "10us")
REM
REM 示例:
REM   run_xsim.bat C:\project\proj.sim\sim_1\behav\xsim
REM   run_xsim.bat C:\project\proj.sim\sim_1\behav\xsim 1000ns

setlocal enabledelayedexpansion

if "%~1"=="" (
    echo ============================================
    echo      XSIM DIRECT RUNNER
    echo ============================================
    echo.
    echo Usage: run_xsim.bat ^<sim_dir^> [sim_time]
    echo.
    echo Arguments:
    echo   sim_dir   - Directory containing compile.bat, elaborate.bat, simulate.bat
    echo   sim_time  - Optional simulation time ^(e.g., "1000ns", "10us"^)
    echo.
    echo Example:
    echo   run_xsim.bat C:\project\proj.sim\sim_1\behav\xsim
    echo   run_xsim.bat C:\project\proj.sim\sim_1\behav\xsim 1000ns
    exit /b 1
)

set SIM_DIR=%~1
set SIM_TIME=%~2

echo ============================================
echo      XSIM DIRECT RUNNER
echo ============================================
echo Sim Dir:  %SIM_DIR%
if not "%SIM_TIME%"=="" (
    echo Sim Time: %SIM_TIME%
) else (
    echo Sim Time: ^(run all^)
)
echo ============================================

REM 检查目录是否存在
if not exist "%SIM_DIR%" (
    echo ERROR: Directory not found: %SIM_DIR%
    exit /b 1
)

REM 切换到仿真目录
pushd "%SIM_DIR%"

echo.
echo === STEP 1: Compile ===
if exist compile.bat (
    call compile.bat
    if errorlevel 1 (
        echo ERROR: Compile failed!
        popd
        exit /b 1
    )
    echo Compile: SUCCESS
) else (
    echo ERROR: compile.bat not found!
    popd
    exit /b 1
)

echo.
echo === STEP 2: Elaborate ===
if exist elaborate.bat (
    call elaborate.bat
    if errorlevel 1 (
        echo ERROR: Elaborate failed!
        popd
        exit /b 1
    )
    echo Elaborate: SUCCESS
) else (
    echo ERROR: elaborate.bat not found!
    popd
    exit /b 1
)

echo.
echo === STEP 3: Simulate ===
if exist simulate.bat (
    if not "%SIM_TIME%"=="" (
        REM 修改 simulate.bat 中的运行时间
        echo Running simulation for %SIM_TIME%...
        REM 直接调用 xsim 而不是 simulate.bat，以便指定运行时间
        for /f "tokens=*" %%a in ('dir /b xsim.dir\*_behav 2^>nul') do (
            set SNAPSHOT=%%a
        )
        if defined SNAPSHOT (
            xsim !SNAPSHOT! -runall -R %SIM_TIME%
        ) else (
            call simulate.bat
        )
    ) else (
        call simulate.bat
    )
    if errorlevel 1 (
        echo WARNING: Simulate returned error ^(may be normal for $finish^)
    )
    echo Simulate: DONE
) else (
    echo ERROR: simulate.bat not found!
    popd
    exit /b 1
)

popd

echo.
echo ============================================
echo      SIMULATION COMPLETE
echo ============================================
echo Check logs in: %SIM_DIR%
echo   - xvlog.log  ^(compile log^)
echo   - xelab.log  ^(elaborate log^)
echo   - simulate.log ^(simulation log^)
echo ============================================

exit /b 0
