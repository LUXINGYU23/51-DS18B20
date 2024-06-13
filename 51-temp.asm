
ORG 0000H             ; 程序入口点
    SJMP Main
ORG 0023H               ; 中断向量地址为0023H（中断4）
    LJMP UART_ISR        ; 跳转到中断服务例程
Main:
    CLR A              ; 清除累加器，用于安全起见
	MOV A,#0FFH
	MOV 42H,A          ;初始化42H
	CLR A
MainLoop:
    ACALL UartInit      ; 调用初始化函数
    ACALL Ds18b20ReadTemp  ; 调用读取温度的函数
    ACALL ProcessTemp       ; 调用数据处理函数
    ACALL DigDisplay      ; 调用显示函数
	MOV A,42H
	CJNE A, #0F0H, NOT_SEND
;	ACALL Delay_100ms
	ACALL SEND_TEMP
NOT_SEND:
    LJMP MainLoop         ; 无限循环回到开始
;-----------------------------------------------------------------------------------
;初始化DS18B20
Ds18b20Init:
    CLR  P3.7           ; 拉低总线
    ACALL Delay_642us   ; 延时642us
    SETB P3.7           ; 释放总线
    ACALL Delay_15us    ; 短暂延时等待响应

    MOV  R2, #6         ; 初始化计数器，设置最大等待时间
Wait_Response:
    JB   P3.7, Continue_Wait ; 如果P3.7是高, 继续等待
    MOV  A, #1          ; 总线被拉低，初始化成功，返回1
    ;Debug用，判断是否成功通信，测试通过
	MOV 41H,A   
    RET

Continue_Wait:
    ACALL Delay_1ms     ; 延时1ms
    DJNZ R2, Wait_Response ; 计数器递减，如果未到0继续循环
    MOV  A, #0          ; 计数器到0还未检测到低电平，初始化失败
	;Debug用，判断是否成功通信，测试通过
	MOV 41H,A   
    RET
;-----------------------------------------------------------------------------------
; 数据字节存储在RAM地址30H.向18B20写入一个字节
Ds18b20WriteByte:
    MOV R0, #8            ; 初始化循环计数器，准备写入8位数据
    MOV A, 30H            ; 将地址30H处的数据加载到累加器A

Write_Loop:
	CLR C
	RRC A
	CLR P3.7              ; 拉低总线，准备写入一位数据
    ACALL Delay_1us       ; 延时1微秒，实际上是5微秒
;    MOV C, ACC.0          ; 将数据的最低位移到进位标志位
    MOV P3.7, C           ; 将进位标志位的值写入P3.7（DSPORT）
    ACALL Delay_68us      ; 延时68微秒
    SETB P3.7             ; 释放总线
    ACALL Delay_1us       ; 延时1微秒以供总线恢复

;    RRC A                 ; 右旋转累加器，准备下一个数据位
    DJNZ R0, Write_Loop   ; 循环计数器递减并检查是否为0，不为0则继续循环

    RET                   ; 返回
;----------------------------------------------------------------------------------
; 数据字节存储在RAM地址31H.向18B20读取一个字节
Ds18b20ReadByte:
    MOV R0, #8            ; 初始化循环计数器，准备读取8位数据
    CLR A                 ; 清除A寄存器，准备存储数据字节

Read_Loop:
    CLR P3.7              ; 拉低总线
    ACALL Delay_1us       ; 延时1微秒
    SETB P3.7             ; 释放总线
    ACALL Delay_1us       ; 等待6微秒，数据稳定
    MOV C, P3.7           ; 将P3.7的值读取到进位标志位
    RRC A                 ; 左旋转累加器，将进位标志位移入A的最低位

    ACALL Delay_48us      ; 延时48微秒，准备下一次读取

    DJNZ R0, Read_Loop    ; 循环计数器递减并检查是否为0，不为0则继续循环

    MOV 31H, A            ; 将最终读取的字节存储到31H
    RET                   ; 返回
;----------------------------------------------------------------------------------
;让18b20开始转换温度
Ds18b20ChangTemp:
    ACALL Ds18b20Init    ; 调用初始化函数

    ACALL Delay_1ms       ; 延时1ms，确保初始化稳定

    ; 发送跳过ROM操作命令
    MOV A, #0CCH         ; 将0xCC加载到累加器
    MOV 30H, A           ; 将0xCC写入RAM地址30H
    ACALL Ds18b20WriteByte ; 调用写字节函数

    ; 发送温度转换命令
    MOV A, #44H          ; 将0x44加载到累加器
    MOV 30H, A           ; 将0x44写入RAM地址30H
    ACALL Ds18b20WriteByte ; 调用写字节函数
    ; 通常需要等待转换完成，延时100ms
    ; 如果持续监控，可能不需要此延时
;    ACALL Delay100ms   ; 为转换过程延时
    RET  
;----------------------------------------------------------------------------------                
; 函 数 名: Ds18b20ReadTempCom
; 函数功能: 发送读取温度命令
Ds18b20ReadTempCom:
    ACALL Ds18b20Init    ; 调用初始化函数

    ACALL Delay_1ms       ; 延时1ms，确保初始化稳定

    ; 发送跳过ROM操作命令
    MOV A, #0CCH         ; 将0xCC加载到累加器
    MOV 30H, A           ; 将0xCC写入RAM地址30H
    ACALL Ds18b20WriteByte ; 调用写字节函数

    ; 发送读取温度命令
    MOV A, #0BEH         ; 将0xBE加载到累加器
    MOV 30H, A           ; 将0xBE写入RAM地址30H
    ACALL Ds18b20WriteByte ; 调用写字节函数
    RET    
;----------------------------------------------------------------------------------
; 函 数 名         : Ds18b20ReadTemp
; 函数功能		   : 读取温度,低位存储在32H,高位存储在33H            
; 51单片机汇编版本的Ds18b20ReadTemp函数

Ds18b20ReadTemp:
    ACALL Ds18b20ChangTemp   ; 开始温度转换
    ACALL Ds18b20ReadTempCom ; 发送读取温度命令

    ACALL Ds18b20ReadByte    ; 读取低字节
    MOV A,31H                ; 将读取的低位字节存储在累加器A
    MOV 32H, A               ; 将读取的低字节存储在地址32H

    ACALL Ds18b20ReadByte    ; 读取高字节
    MOV A,31H                ; 将读取的高位字节存储在累加器A
    MOV 33H, A               ; 将读取的高字节存储在地址33H
    RET                     ; 返回
;----------------------------------------------------------------------------------
; 函 数 名: ProcessTemp
; 函数功能: 处理温度数据,将温度按照整数和小数部分分别存储在34H和35H
; 假设：
; - 高字节存储在 33H
; - 低字节存储在 32H
; - 结果存储在内存地址 34H-35H，同时按数值储存到36-40H

ProcessTemp:
    ; 清除高字节中无效的位并移位，将有效位移至低位
    MOV A, 33H  ; 将高字节加载到累加器A
    ANL A, #07H ; 仅保留高字节的后三位
    SWAP A      ; 交换高低四位
    ANL A, #0F0H ; 清除现在的低四位（原高四位）
	MOV R0,A

    ; 提取低字节的高四位，处理整数部分
    MOV B, 32H  ; 将低字节加载到B
    ANL B, #0F0H ; 提取低字节的高四位
	MOV A,B
    SWAP A
	MOV B,A
	MOV A,R0
    ORL A, B    ; 将其加入A中
    MOV 34H, A  ; 假设此处直接存储整数部分

    ; 处理小数部分，低字节的低四位
    MOV A, 32H  ; 将低字节加载到A
    ANL A, #0FH ; 提取低字节的低四位
    MOV R0, A   ; 将提取的值存储到R0
    ; 将提取的值乘以6.25 
    MOV R4,A            ; 将A的值复制到R4
    MOV B,R4            ; 将A的值复制到B
    ADD A, B            ; A = A * 2
    MOV R5, A            ; 将A的值复制到R5,此时R5 = A * 2
    MOV B, R5            ; 将R5的值复制到B
    ADD A, B            ; A = A * 4 (此时A已经是原始值的4倍)
    ADD A, B            ; A = A * 4 + B * 2 = A * 6
    MOV R1, A            ; 将A的值复制到R1,此时R1 = A * 6
    ; 计算原值的25% (A / 4)
    MOV A, R0           ; 恢复原始值到A
	CLR C
    RRC A                ; A = A / 2
	CLR C
    RRC A                ; A = A / 4 (此时A为原始值的25%)
    ; 将25%的结果加到A * 6的结果上
    ADD A, R1           ; A = A * 6 + A * 0.25 = A * 6.25
    MOV 35H, A  ; 存储小数部分
    ; 整数部分abc存储在34H，小数部分ef存储在35H
    ; 处理整数部分abc
    MOV A, 34H            ; 加载整数部分abc
    MOV B, #100           ; 准备除以100以分离百位
    DIV AB                
    MOV 36H, A            ; 存储百位数到36H
    MOV A, B            
    MOV B, #10            ; 准备除以10以分离十位和个位
    DIV AB                ; A = bc / 10, B = c
    MOV 37H, A            ; 存储十位数到37H
    MOV 38H, B            ; 存储个位数到38H
    ; 处理小数部分ef
    MOV A, 35H            ; 加载小数部分ef
    MOV B, #10            ; 准备除以10以分离十位和个位
    DIV AB                ; A = ef / 10, B = f
    MOV 39H, A            ; 存储小数部分的十位数到39H
    MOV 40H, B            ; 存储小数部分的个位数到40H
    RET
;----------------------------------------------------------------------------------
;函数名:DigDisplay()
;函数功能:数码管显示函数
DigDisplay:
    MOV R7, #6          ; 用于控制显示的数字数量

DISPLAY_LOOP:
    MOV DPTR, #KEY_TABLE    ; 设置DPTR指向查找表的开始地址
    ; 设置位选
    MOV A, R7
	CJNE A, #6, NOT_SIXTH
	CLR P2.2
    CLR P2.3
    CLR P2.4
	MOV A,#12
	MOVC A, @A+DPTR       ; 查找字符表
    MOV P0, A             ; 输出到数码管
    SJMP DISPLAYED
NOT_SIXTH:
    CJNE A, #5, NOT_FIFTH
	SETB P2.2
    CLR P2.3
    CLR P2.4
	MOV A,40H
	MOVC A, @A+DPTR       ; 查找字符表
    MOV P0, A             ; 输出到数码管
    SJMP DISPLAYED
NOT_FIFTH:
    CJNE A, #4, NOT_FOURTH
	CLR P2.2
    SETB P2.3
    CLR P2.4
	MOV A,39H
	MOVC A, @A+DPTR       ; 查找字符表
    MOV P0, A             ; 输出到数码管
    SJMP DISPLAYED
NOT_FOURTH:
    CJNE A, #3, NOT_THIRD
	SETB P2.2
    SETB P2.3
    CLR P2.4
	MOV A,38H
	MOVC A, @A+DPTR       ; 查找字符表
    MOV P0, A             ; 输出到数码管
	ACALL Delay_100us    ; 调用延时
    MOV P0,#0H          ; 清空显示以避免幽灵效应
	MOV A,#80H
    MOV P0, A             ; 输出到数码管
    SJMP DISPLAYED
NOT_THIRD:
    CJNE A, #2, NOT_SECOND
	CLR P2.2
    CLR P2.3
    SETB P2.4
	MOV A,37H
	MOVC A, @A+DPTR       ; 查找字符表
    MOV P0, A             ; 输出到数码管
    SJMP DISPLAYED
NOT_SECOND:
    CJNE A, #1, NOT_FIRST
    SETB P2.2
    CLR P2.3
    SETB P2.4
	MOV A,36H
	MOVC A, @A+DPTR       ; 查找字符表
    MOV P0, A             ; 输出到数码管
    SJMP DISPLAYED
NOT_FIRST:

DISPLAYED:
    ACALL Delay_100us    ; 调用延时
    MOV P0,#0H          ; 清空显示以避免幽灵效应
    DJNZ R7, DISPLAY_LOOP ; 继续显示下一个数字
    RET
;----------------------------------------------------------------------------------
; 延时函数
Delay_100us:
    MOV R0, #20
DELAY_100_LOOP:
    ACALL Delay_1us    ; 调用5微秒延时20次
    DJNZ R0, DELAY_100_LOOP
    RET

; 实现1ms延时
Delay_1ms:
    MOV R1, #10
DELAY_1MS_LOOP:
    ACALL Delay_100us  ; 调用100微秒延时10次
    DJNZ R1, DELAY_1MS_LOOP
    RET


;100ms的延时函数
Delay_100ms:
    MOV R2, #100
DELAY_100MS_LOOP:
    ACALL Delay_1ms    ; 调用1毫秒延时100次
    DJNZ R2, DELAY_100MS_LOOP
    RET



; 延时6微秒
Delay_6us:
    ; 实际上是10us
    MOV R1, #2 
DELAY_6_LOOP:
    ACALL Delay_1us    ; 调用5微秒延时2次
    DJNZ R1, DELAY_6_LOOP
    RET


; 延时48微秒,实际上是60，下同
Delay_48us:
    MOV R1, #12
DELAY_48_LOOP:
    ACALL Delay_1us    ; 调用5微秒延时12次
    DJNZ R1, DELAY_48_LOOP
    RET

; 延时15微秒
Delay_15us:
    MOV R0, #3
DELAY_15_LOOP:
    ACALL Delay_1us    ; 调用5微秒延时3次
    DJNZ R0, DELAY_15_LOOP
    RET

Delay_642us:
    MOV R2, #70
DELAY_642_LOOP:
    ACALL Delay_6us    ; 调用10微秒延时70次
    DJNZ R2, DELAY_642_LOOP
    RET

; 延时1微秒
Delay_1us:
    ; 实际上是5us
    RET
    
; 延时68微秒
Delay_68us:
    MOV R1, #14
DELAY_68_LOOP:
    ACALL Delay_1us    ; 调用5微秒延时14次
    DJNZ R1, DELAY_68_LOOP
    RET
;-------------------------------------------------------------------------------------------
; UartInit函数：在11.0592MHz下初始化UART
UartInit:
    ANL   PCON, #07H  
    ; 设置SCON = 50H（模式1，REN启用）
    MOV   SCON, #50H     
    ; 设置TMOD为20H，为定时器1设置模式2（自动重载）
    ANL   TMOD, #0FH     ; 清除高4位，保留低位不变
    ORL   TMOD, #20H     ; 设置高4位为2（0010），定时器1为模式2
    ; 将TH1和TL1设置为FDH，用于波特率生成
    MOV   TH1, #0FDH     
    MOV   TL1, #0FDH     
    ; 禁用定时器1中断
    CLR   ET1           
    ; 启动定时器1
    SETB  TR1            
    ; 启用UART中断和全局中断
    SETB  ES             
    SETB  EA             
    ; 函数返回
    RET                  
;---------------------------------------------------------------------------------------------
; UART_SendByte 函数：发送一个字节
; 参数：数据字节存储在内存地址41H
UART_SendByte:
    ; 读取内存地址41H中的数据
    MOV   A, 41H          ; 将地址41H的内容加载到累加器A
    ; 将数据写入SBUF寄存器
    MOV   SBUF, A         
    ; 等待发送完成，检测TI标志位
Wait_TI:
    JNB   TI, Wait_TI     ; 如果TI=0，继续等待
    ; 清除TI标志位以准备下一次发送
	MOV A,#0
	MOV 41H,A
    CLR   TI              
    ; 函数返回
    RET                  
;----------------------------------------------------------------------------------------------
; UART_Routine 中断服务例程：处理接收到的数据并回送
; 使用中断号4
UART_ISR:
    JB    RI, Received   ; 检查接收中断标志位RI，如果置位则处理接收
    SJMP  Exit_ISR       ; 否则直接退出中断服务例程
    Received:
    CLR   RI             ; 清除接收中断标志位RI
    MOV   A, SBUF        ; 从SBUF寄存器读取接收到的数据
    MOV   42H, A         ; 将数据存储到内存地址42H
    MOV   A  ,#0F1H      ;表示成功接受,DEBUG用
    ; 调用发送函数将成功接受标志数据回送
    ACALL UART_SendByte  

Exit_ISR:
    RETI                 ; 从中断返回
;----------------------------------------------------------------------------------------------
;SEND_TEMP
SEND_TEMP:
    MOV A,#0FFH   ;初始位
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,#0FFH   ;初始位
	MOV 41H,A
	ACALL UART_SendByte
    MOV A,36H
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,37H
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,38H
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,39H
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,40H
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,#0FFH   ;截止位
	MOV 41H,A
	ACALL UART_SendByte
	MOV A,#0FFH
	MOV 42H,A          ;初始化42H
	RET
KEY_TABLE:            
	DB 0x3f,0x06,0x5b,0x4f,0x66,0x6d,0x7d,0x07,0x7f,0x6f,0x77,0x7c,0x39,0x5e,0x79,0x71
END                   ; 结束程序