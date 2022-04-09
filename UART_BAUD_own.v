`timescale 1ns/1ps

module    UART_BAUD(
   // inputs
    input           clk26m,// 26M function clock
    input           rstn,// function clk's rst_
    input           tx_bps_en, // baud enable signal
    input           rx_bps_en,
    input    [9:0]  baud_div,// baud frequency divide factor
    // outputs
    output          rx_bpsclk, // receive bps clk,
    output          tx_bpsclk// send bps clk
);


reg  [13:0]     cnt_value;           // bps counter 
reg  [13:0]     cnt_baud_rx;         // receive baud counter
reg  [13:0]     cnt_baud_tx;         // send baud counter


// 产生接收信号rx_bpsclk。当rx的计数等于counter的1/2时，则输出高电平的rx_bpsclk。
//目的是保证采样出最稳定的数据
always@(posedge clk26m or negedge rstn) begin
    if(!rstn) begin
        cnt_baud_rx <= 14'd0;
    end
    else begin
        if(rx_bps_en) begin
            if(cnt_baud_rx > cnt_value - 1'b1) begin
                cnt_baud_rx <= 14'd0;
            end
            else begin
                cnt_baud_rx <= cnt_baud_rx + 1'b1;
            end
        end
        else begin
            cnt_baud_rx <= 14'd0;
        end
    end
end

assign  rx_bpsclk = (cnt_baud_rx == (cnt_value/2))? 1'b1:1'b0;

// 产生发送信号tx_bpsclk
always@(posedge clk26m or negedge rstn) begin
    if(!rstn) begin
        cnt_baud_tx <= 14'd0;
    end
    else begin
        if(tx_bps_en) begin
            if(cnt_baud_tx > cnt_value - 1'b1) begin
                cnt_baud_tx <= 14'd0;
            end
            else begin
                cnt_baud_tx <= cnt_baud_tx + 1'b1;
            end
        end
        else begin
            cnt_baud_tx <= 14'd0;
        end
    end
end

assign  tx_bpsclk = (cnt_baud_tx == (cnt_value/2))? 1'b1:1'b0;

//计算一个波特率周期所需的功能时钟数
always@(posedge clk26m or negedge rstn) begin
    if(!rstn) begin
        cnt_value <= (10'd338+ 1'b1) << 4;
    end
    else begin
        cnt_value <= (baud_div + 1'b1) << 4;
    end
end
endmodule