#!/bin/bash

# 执行一个示例命令，这里使用true作为示例（退出码为0）
# 可以替换为任何需要检查的命令
#true

# 获取上一个命令的退出状态码
exit_code=$?

# 显示原始退出码
#exit_log="命令退出状态码: $exit_code"

# 根据退出码显示对应的中文含义
case $exit_code in
    0)
        exit_log="命令执行成功"
        ;;
    1)
        exit_log="通用错误（如除以零、语法错误等）"
        ;;
    2)
        exit_log="误用shell命令（如错误的选项或参数）"
        ;;
    126)
        exit_log="命令无法执行（权限不足）"
        ;;
    127)
        exit_log="未找到命令"
        ;;
    128)
        exit_log="无效的退出参数"
        ;;
    129)
        exit_log="SIGHUP - 终端挂断"
        ;;
    130)
        exit_log="SIGINT - 程序被用户中断（通常是Ctrl+C）"
        ;;
    131)
        exit_log="SIGQUIT - 程序被用户终止（通常是Ctrl+\）"
        ;;
    132)
        exit_log="SIGILL - 非法指令"
        ;;
    133)
        exit_log="SIGTRAP - 跟踪陷阱"
        ;;
    134)
        exit_log="SIGABRT - 程序异常终止"
        ;;
    135)
        exit_log="SIGBUS - 总线错误"
        ;;
    136)
        exit_log="SIGFPE - 浮点异常（如除以零）"
        ;;
    137)
        exit_log="SIGKILL - 程序被强制终止（通常是kill -9）"
        ;;
    138)
        exit_log="SIGUSR1 - 用户定义信号1"
        ;;
    139)
        exit_log="SIGSEGV - 段错误（非法内存访问）"
        ;;
    140)
        exit_log="SIGUSR2 - 用户定义信号2"
        ;;
    141)
        exit_log="SIGPIPE - 管道破裂（写入无人读取的管道）"
        ;;
    142)
        exit_log="SIGALRM - 闹钟信号（超时）"
        ;;
    143)
        exit_log="SIGTERM - 程序被请求终止（通常是kill命令）"
        ;;
    255)
        exit_log="退出状态码越界（超出0-255范围）"
        ;;
    *)
        exit_log="未知退出状态码"
        ;;
esac
echo $exit_log
