#!/bin/bash

# 定义日志目录和带时间戳的文件名
LOG_DIR="/var/log/rsync-mirror"
TIMESTAMPF="$(date +'%Y-%m-%d-%H-%M-%S')"  #日志文件名的时间格式（为了文件名无空格）
TIMESTAMPL="$(date +'%Y-%m-%d %H:%M:%S')"   #日志里的时间格式（为了增强可读性）
STDOUT_LOG="${LOG_DIR}/ubuntu-stdout-${TIMESTAMPF}.txt"
STDERR_LOG="${LOG_DIR}/ubuntu-stderr-${TIMESTAMPF}.txt"
RECORDS="${LOG_DIR}/ubuntu_rsync_log.txt"
DSTF="/path" #镜像文件储存位置
DSTE="/path2"  #脚本位置
NOTES="${DST}/镜像站文件同步中，请等待同步完成..."

# 创建日志目录（如果不存在）
mkdir -p "${LOG_DIR}"

# 记录开始时间
echo "===== 同步开始于: ${TIMESTAMPL} =====" > "${STDOUT_LOG}"
echo "===== 同步开始于: ${TIMESTAMPL} =====" > "${STDERR_LOG}"
echo "===== 同步开始于: ${TIMESTAMPL} =====" >> "${RECORDS}"

#通过文件标记同步状态
touch "${NOTES}"

# 执行rsync命令，分离输出到带时间戳的文件
rsync -aczvthP --delete --stats \
  --exclude-from="$DSTE/ubuntu-exclude.txt" \
  rsync://archive.ubuntu.com/ubuntu \
  "$DSTF" \
   >> "${STDOUT_LOG}" 2>> "${STDERR_LOG}"

# 记录结束时间和状态
#打印状态
source "$DSTE/exit_code.sh"

TIMESTAMPE="$(date +'%Y-%m-%d %H:%M:%S')"
echo "===== 同步结束于: ${TIMESTAMPE}，状态: $exit_log =====" >> "${STDOUT_LOG}"
echo "===== 同步结束于: ${TIMESTAMPE}，状态: $exit_log =====" >> "${STDERR_LOG}"
echo "===== 同步结束于: ${TIMESTAMPE}，状态: $exit_log =====" >> "${RECORDS}"

#删除文件标记同步状态
rm -f  "${NOTES}"

exit
