#!/bin/bash

#检测磁盘空间是否充足

# 检查磁盘可用空间，单位为千字节(KB)
available_space=$(df / | awk 'NR==2 {print $4}')

# 将可用空间转换为GB
available_space_gb=$(($available_space / 1024 / 1024))

# 判断磁盘空间是否小于3GB
if [ $available_space_gb -lt 3 ]; then
    echo "磁盘空间不足，请清理后再试"
    exit 1
else
    echo "磁盘空间足够，继续执行脚本..."
fi

# 检查是否已有swap文件
if [ -f /swapfile ]; then
    echo "检测到已有swap文件，正在检查是否已激活."

    # 检查当前swap文件是否被启用
    if sudo swapon --show | grep -q '/swapfile'; then
        echo "正在禁用当前的swap文件."
        sudo swapoff /swapfile
        if [ $? -ne 0 ]; then
            echo "Failed to disable existing swap. Exiting."
            exit 1
        fi
    else
        echo "当前swap文件未启用，无需禁用."
    fi

    # 删除现有的swap文件
    sudo rm /swapfile
    if [ $? -ne 0 ]; then
        echo "Failed to remove existing swapfile. Exiting."
        exit 1
    fi

    # 从 /etc/fstab 中移除旧的swap配置
    sudo sed -i '/\/swapfile swap swap defaults 0 0/d' /etc/fstab
    if [ $? -ne 0 ]; then
        echo "Failed to remove swapfile entry from /etc/fstab. Exiting."
        exit 1
    fi
fi

# 创建一个大小为3GB的swap文件
sudo dd if=/dev/zero of=/swapfile bs=1M count=3072
if [ $? -ne 0 ]; then
    echo "Failed to allocate space for swapfile. Exiting."
    exit 1
fi

# 查看swap文件大小
ls -lh /swapfile

# 设置合适的权限，防止未授权访问
sudo chmod 600 /swapfile
if [ $? -ne 0 ]; then
    echo "Failed to set permissions on swapfile. Exiting."
    exit 1
fi

# 创建swap文件
sudo mkswap /swapfile
if [ $? -ne 0 ]; then
    echo "Failed to create swap on /swapfile. Exiting."
    exit 1
fi

# 启用swap分区
sudo swapon /swapfile
if [ $? -ne 0 ]; then
    echo "Failed to enable swap on /swapfile. Exiting."
    exit 1
fi

# 查看是否生效
free -h

# 将swap分区配置添加到 /etc/fstab，以便开机自动挂载
echo "/swapfile swap swap defaults 0 0" | sudo tee -a /etc/fstab

# 确保配置文件中的swap已生效
sudo mount -a
if [ $? -ne 0 ]; then
    echo "Failed to reload /etc/fstab. Exiting."
    exit 1
fi

echo "Swap 安装成功！"
