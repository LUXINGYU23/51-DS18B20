using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.IO.Ports;
using System.Windows.Forms.DataVisualization.Charting;
using SeeSharpTools.JY.Report;
using SeeSharpTools.JY.ArrayUtility;
using System.Web.UI.WebControls;

namespace lab5pro2
{
    public partial class Form1 : Form
    {
        int count;//定义一个整型count，用于定时器1
        ExcelReport excel;
        public Form1()
        {
            InitializeComponent();
            button_closeport.Enabled = false;
            button_sendorder.Enabled = false;
            timer3.Enabled = false;
            timer3.Stop();


        }

        List<string> temp = new List<string>();
        private int delayTime = 1000;

        private void Form1_Load(object sender, EventArgs e)
        {
            comboBox_port.Text = "COM3";
            comboBox_baud.Text = "9600";
            comboBox_parity.Text = "None";
            comboBox_data.Text = "7";
            comboBox_stop.Text = "One";
            timer1.Stop();//暂停计时   
        }

        private void button_searchport_Click(object sender, EventArgs e)//搜索可用串口
        {
            string[] portname = SerialPort.GetPortNames();//定义一个字符串来获取串口
            this.comboBox_port.Items.Clear();//清空comboBox1中的值
            foreach (string port in portname)//遍历串口
            {
                var serialPort = new SerialPort();//把串口赋给定义的var变量
                serialPort.PortName = port;
                serialPort.Open();//打开串口
                this.comboBox_port.Items.Add(port);//打开成功，则添加至下拉框
                serialPort.Close();//关闭串口
            }
        }

private void button_openport_Click(object sender, EventArgs e)//打开所选择的串口
{
    if (serialPort1.IsOpen)//如果串口是打开的
    {
        try
        {
                    serialPort1.Close();//先判断运行之前串口是否打开，若打开则要先关闭
        }
        catch
        {
            // 可选：处理关闭串口时的异常
        }
    }
    try
    {
                // 应用用户从界面选择的设置
                serialPort1.PortName = comboBox_port.Text; // 设置串口号
                serialPort1.BaudRate = int.Parse(comboBox_baud.Text); // 设置波特率
                serialPort1.DataBits = int.Parse(comboBox_data.Text); // 设置数据位
                serialPort1.StopBits = (StopBits)Enum.Parse(typeof(StopBits), comboBox_stop.Text); // 设置停止位
                serialPort1.Parity = (Parity)Enum.Parse(typeof(Parity), comboBox_parity.Text); // 设置校验位

                // 打开串口
                serialPort1.Open();

        // 更新界面元素状态
        button_openport.Enabled = false;
        comboBox_port.Enabled = false;
        comboBox_baud.Enabled = false;
        comboBox_parity.Enabled = false;
        comboBox_data.Enabled = false;
        comboBox_stop.Enabled = false;
        button_searchport.Enabled = false;
        button_closeport.Enabled = true;
        button_sendorder.Enabled = true;
    }
    catch (Exception ex) // 捕获所有可能的异常
    {
        MessageBox.Show("串口打开失败: " + ex.Message, "错误");
    }
}


        private void button_closeport_Click(object sender, EventArgs e)//关闭所选择的串口
        {
            try
            {
                serialPort1.Close();
                button_openport.Enabled = true;
                comboBox_port.Enabled = true;
                comboBox_baud.Enabled = true;
                comboBox_parity.Enabled = true;
                comboBox_data.Enabled = true;
                comboBox_stop.Enabled = true;
                button_searchport.Enabled = true;
                button_closeport.Enabled = false;

            }
            catch (Exception err)//一般情况下关闭串口不会出错，加上以防万一
            {
                MessageBox.Show(err.Message);
            }
        }
       




        private void button_sendorder_Click_1(object sender, EventArgs e)
        {
           // this.sendAndDisplayHexCommand();
            this.sendCommand();
            button_sendorder.Enabled =false;
            timer1.Start();
            timer2.Start();
        }

        private void timer1_Tick(object sender, EventArgs e)//定时器
        {

        }



        private void timer3_Tick(object sender, EventArgs e)
        {
        }

        private double? lastTemperature = null; // 存储上一次读取的温度
        private double count_t = 0; // 温度次数计数

        private void sendCommand() // 构造发送指令函数
        {
 //           textBox1.Text = "Null"; // 初始化文本框
            if (this.serialPort1.IsOpen)
            {
                try
                {
                    byte[] commandByte = { 0xF0 }; // 直接定义字节命令
                    this.serialPort1.Write(commandByte, 0, commandByte.Length);
                    // 等待足够时间确保数据完整接收
                    System.Threading.Thread.Sleep(500); // 等待500毫秒，可调整以适应具体情况

                    // 检查是否接收到足够的字节
                    if (this.serialPort1.BytesToRead >= 9)
                    {
                        byte[] byteReceive = new byte[9]; // 预期接收9个字节
                        this.serialPort1.Read(byteReceive, 0, byteReceive.Length); // 读取缓冲区中的数据

                        // 检查帧头和帧尾是否正确
                        if (byteReceive[0] == 0x00 && byteReceive[1] == 0x7F && byteReceive[2] == 0x7F && byteReceive[8] == 0x7F)
                        {
                            // 解析温度数据
                            int integerPart = byteReceive[3] * 100 + byteReceive[4] * 10 + byteReceive[5];
                            double fractionalPart = (byteReceive[6] * 10 + byteReceive[7]) * 0.01;
                            double temperature = integerPart + fractionalPart;

                            // 检查温度变化
                            if(count_t>2)
                            {
                                if (lastTemperature.HasValue && ((temperature - lastTemperature.Value) > 50|| (lastTemperature.Value- temperature  ) > 1))
                                {
                                 //   textBox1.Text = "Error4";
                                    return; // 放弃本次读取
                                }
                            }
                            // 更新上次温度记录
                            lastTemperature = temperature;
                            count_t++;
                            string tempString = temperature.ToString("F2").ToUpper();
                            textBox1.Text = tempString; // 更新文本框显示温度
                            listBox1.Items.Add(tempString); // 添加到列表框
                            listBox1.SelectedIndex = listBox1.Items.Count - 1; // 自动选择最新的项

                            double[] doubleArray = listBox1.Items.Cast<string>().Select(s => double.Parse(s)).ToArray();
                            easyChartX1.Plot(doubleArray); // 绘制图表
                        }
                        else
                        {
                            textBox1.Text = "Error1"; // 帧头或帧尾错误
                        }
                    }
                    else
                    {
                        textBox1.Text = "Error2"; // 数据未完全接收
                    }
                }
                catch (Exception er)
                {
                    MessageBox.Show(er.Message); // 异常处理
                    textBox1.Text = "Error in receiving data";
                }
            }
        }


        private void sendAndDisplayHexCommand()
        {
            textBox1.Text = "Null"; // 初始化文本桉
            if (this.serialPort1.IsOpen)
            {
                try
                {
                    byte[] commandByte = { 0xF0 }; // 定义发送的字节命令
                    this.serialPort1.Write(commandByte, 0, commandByte.Length); // 发送命令

                    // 等待足够时间确保数据完整接收
                    System.Threading.Thread.Sleep(500); // 等待200毫秒，可调整以适应具体情冇

                    int bytesToRead = this.serialPort1.BytesToRead; // 读取可用的字节长度
                    if (bytesToRead > 0)
                    {
                        
                        byte[] byteReceive = new byte[9]; // 根据可读的字节长度创建数组
                        this.serialPort1.Read(byteReceive, 0, byteReceive.Length); // 读取缓冲区中的数据

                        // 转换接收到的字节到16进制字符串
                        var hexString = BitConverter.ToString(byteReceive).Replace("-", " ");
                        textBox1.Text = hexString; // 显示16进制字符串
                    }
                    else
                    {
                        textBox1.Text = "No data received"; // 没有数据接收
                    }
                }
                catch (Exception er)
                {
                    MessageBox.Show(er.Message); // 显示异常信息
                    textBox1.Text = "Error in receiving data"; // 接收数据错误
                }
            }
            else
            {
                {
                    textBox1.Text = "Port not open"; // 串口未打开
                }
            }
        } 


            private void chart1_Click(object sender, EventArgs e)//双击chart事件来显示滑动条
        {

        }


        private void timer2_Tick(object sender, EventArgs e)
        {
       
        }





        private void easyChartX1_AxisViewChanged(object sender, SeeSharpTools.JY.GUI.EasyChartXViewEventArgs e)
        {

        }

        private void timer1_Tick_1(object sender, EventArgs e)
        {
            button_sendorder_Click_1(button_sendorder, null);//调用button_sendorder_Click_1函数
            if (serialPort1.IsOpen)   //如果串口已经打开
            {
                count++;
            }

        }

        private void button_stop_Click_1(object sender, EventArgs e)
        {
            button_sendorder.Enabled = true;
            timer1.Stop();
            timer3.Stop();
            count_t = 0;
        }

        private void groupBox1_Enter(object sender, EventArgs e)
        {

        }

        private void comboBox_baud_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
    }
}
