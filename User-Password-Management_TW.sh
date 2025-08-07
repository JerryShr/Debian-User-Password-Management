#!/bin/bash

# 檢查是否以 root 權限運行
if [ "$(id -u)" != "0" ]; then
   echo "錯誤: 此腳本必須以 root 權限運行" >&2
   exit 1
fi

# 獲取可管理用戶列表 (包含 root 和普通用戶)
get_manageable_users() {
    awk -F: '($3 == 0 || $3 >= 1000) && $1 != "nobody" {print $1}' /etc/passwd
}

# 顯示操作選單
show_menu() {
    clear
    echo "========================================"
    echo "     Debian 用戶密碼管理腳本"
    echo "========================================"
    echo "1. 重設用戶密碼"
    echo "2. 鎖定用戶密碼"
    echo "3. 解除鎖定用戶密碼"
    echo "4. 顯示用戶密碼狀態"
    echo "5. 退出腳本"
    echo "========================================"
    read -p "請輸入選項 [1-5]: " choice
    return $choice
}

# 顯示用戶列表並選擇用戶
select_user() {
    local operation=$1
    local users=($(get_manageable_users))
    
    if [ ${#users[@]} -eq 0 ]; then
        echo "找不到可管理的用戶!"
        return 1
    fi
    
    echo "可${operation}的用戶列表:"
    echo "----------------------------------------"
    for i in "${!users[@]}"; do 
        # 為 root 用戶添加標記
        if [ "${users[$i]}" = "root" ]; then
            printf "%2d) %s (系統管理員)\n" $((i+1)) "${users[$i]}"
        else
            printf "%2d) %s\n" $((i+1)) "${users[$i]}"
        fi
    done
    echo "----------------------------------------"
    
    while true; do
        read -p "請選擇用戶 [1-${#users[@]}], 或輸入 0 返回主選單: " sel
        if [ "$sel" -eq 0 ] 2>/dev/null; then
            return 1
        elif [ "$sel" -gt 0 ] && [ "$sel" -le ${#users[@]} ] 2>/dev/null; then
            selected_user="${users[$((sel-1))]}"
            return 0
        else
            echo "無效選擇，請重新輸入"
        fi
    done
}

# 顯示用戶密碼狀態
show_password_status() {
    echo "用戶密碼狀態:"
    echo "----------------------------------------"
    {
        printf "%-15s %-10s %s\n" "用戶名" "狀態" "描述"
        echo "----------------------------------------"
        
        for user in $(get_manageable_users); do
            status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
            case "$status" in
                L) desc="已鎖定" ;;
                P) desc="密碼可用" ;;
                NP) desc="無密碼" ;;
                *) desc="未知狀態" ;;
            esac
            printf "%-15s %-10s %s\n" "$user" "$status" "$desc"
        done
    } | column -t
    echo "----------------------------------------"
    read -p "按 Enter 鍵繼續..."
}

# 主循環
while true; do
    show_menu
    choice=$?
    
    case $choice in
        1)  # 重設密碼
            if select_user "重設密碼"; then
                # root 用戶特別提示
                if [ "$selected_user" = "root" ]; then
                    echo "警告：您正在重設 root 帳戶密碼！"
                    read -p "確定要繼續嗎？(y/n) " confirm
                    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                        echo "已取消操作"
                        read -p "按 Enter 鍵繼續..."
                        continue
                    fi
                fi
                
                echo "正在重設用戶 [$selected_user] 的密碼..."
                passwd "$selected_user"
                read -p "按 Enter 鍵繼續..."
            fi
            ;;
            
        2)  # 鎖定密碼
            if select_user "鎖定"; then
                # root 用戶特別提示
                if [ "$selected_user" = "root" ]; then
                    echo "警告：鎖定 root 帳戶可能導致系統無法維護！"
                    read -p "確定要繼續嗎？(y/n) " confirm
                    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                        echo "已取消操作"
                        read -p "按 Enter 鍵繼續..."
                        continue
                    fi
                fi
                
                echo "正在鎖定用戶 [$selected_user] 的密碼..."
                passwd -l "$selected_user"
                echo "當前狀態:"
                passwd -S "$selected_user" | awk '{print "  "$0}'
                read -p "按 Enter 鍵繼續..."
            fi
            ;;
            
        3)  # 解除鎖定
            if select_user "解除鎖定"; then
                echo "正在解除鎖定用戶 [$selected_user] 的密碼..."
                passwd -u "$selected_user"
                echo "當前狀態:"
                passwd -S "$selected_user" | awk '{print "  "$0}'
                read -p "按 Enter 鍵繼續..."
            fi
            ;;
            
        4)  # 顯示密碼狀態
            show_password_status
            ;;
            
        5)  # 退出
            echo "腳本已退出"
            exit 0
            ;;
            
        *)
            echo "無效選項，請重新選擇"
            sleep 1
            ;;
    esac
done