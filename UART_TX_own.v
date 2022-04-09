 module UART_TX_own(
    //input
    input           clk,                //ARM功能时钟
    input           rstn,              //ARM复位，低有效
    input           clk26m,             //26MHz功能时钟
    input           rst26m_n,           //26MHz功能时钟复位，低有效
    input           tx_bps_clk,         //发送波特率时钟
    input           check_en,           //校验位的使能信号，高有效    
    input           parity,             //奇偶校验控制信号
    input           stop_bit,           //停止位控制信号
    input [7:0]     data_from_regif,    //从reg_if到tx_fifo模块的发送数据
    input [3:0]     two_tx_delay,       //两次信号发送之间,时钟bpsclk的delay数量
    input           tx_fifo_rst,        //tx_fifo复位信号
    input           tx_fifo_wr_en,      //tx_fifo写使能信号,高有效，输入端口
    //output
    output  reg     tx_bps_en,          //发送波特率使能信号，高有效
    output  reg     tx_out,             //UART发送数据线（rx_in与之对应）
    output          tx_fifo_wfull,      //tx_fifo写满信号
    output [4:0]    tx_fifo_cnt         //5位，tx_fifo内数据指示
);
    
    reg  [2:0]      state;
    reg  [2:0]      nextstate;
    reg  [1:0]      rdata_state;
    reg  [3:0]      data_cnt;             // 数据量计数
    reg  [3:0]      baud_cnt;             // 波特率计数
    reg             tx_fifo_rd_en;        //tx_fifo读使能信号，中间变量
    wire [7:0]      data_tx;              // data from TX FIFO to TX
    wire            tx_fifo_rempty;       //tx_fifo读空信号
    reg             tx_ack;               //发送数据的响应信号send data response signal
    reg             tx_start;            // 发送数据的请求信号send data request signal

//同步信号列表
    reg            tx_ack_delay1;
    reg            tx_ack_delay2;
    reg            tx_start_delay1;
    reg            tx_start_delay2;
    reg            stop_bit_syn1;
    reg            stop_bit_syn2;
    reg            check_en_syn1;
    reg            check_en_syn2;
    reg            parity_syn1;
    reg            parity_syn2;
    reg  [3:0]     two_tx_delay_syn1;
    reg  [3:0]     two_tx_delay_syn2;

//状态机定义
    parameter     IDLE      = 3'b000;
    parameter     IRQ       = 3'b001;
    parameter     START_BIT = 3'b011;
    parameter     TX_DATA   = 3'b010;
    parameter     CHECK_BIT = 3'b110;
    parameter     STOP      = 3'b111;
    parameter     DELAY     = 3'b101;

//调用FIFO模块
UART_FIFO_own   uart_tx_fifo(
    .clk(clk),
    .rstn(rstn),
    .fifo_rst(tx_fifo_rst),
    .rd_en(tx_fifo_rd_en),
    .wr_en(tx_fifo_wr_en),
    .data_in(data_tx),
    .data_out(data_from_regif),
    .wr_full(tx_fifo_wfull),
    .rd_empty(tx_fifo_rempty),
    .fifo_cnt(tx_fifo_cnt)
);

//时钟域同步：tx_ack to clk26m
always@(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n) begin
        tx_ack_delay1 <= 1'b0;
        tx_ack_delay2 <= 1'b0;
    end
    else begin
        tx_ack_delay1 <= tx_ack;
        tx_ack_delay2 <= tx_ack_delay1;
    end
end

//时钟域同步：tx_start to ARM clk
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_start_delay1 <= 1'b0;
        tx_start_delay2 <= 1'b0;
    end
    else begin
        tx_start_delay1 <= tx_start;
        tx_start_delay2 <= tx_start_delay1;
    end
end

//时钟域同步：st_bit to clk26m
always@(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n) begin
        stop_bit_syn1 <= 1'b1;
        stop_bit_syn2 <= 1'b1;
    end
    else begin
        stop_bit_syn1 <= stop_bit;
        stop_bit_syn2 <= stop_bit_syn1;
    end
end

//时钟域同步：check_en to clk26m
always@(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n) begin
        check_en_syn1 <= 1'b0;
        check_en_syn2 <= 1'b0;
    end
    else begin
        check_en_syn1 <= check_en;
        check_en_syn2 <= check_en_syn1;
    end
end

//时钟域同步：parity to clk 26m
always@(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n) begin
        parity_syn1 <= 1'b0;
        parity_syn2 <= 1'b0;
    end
    else begin
        parity_syn1 <= parity;
        parity_syn2 <= parity_syn1;
    end
end

//时钟域同步：two_tx_delay to clk 26m
always@(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n) begin
        two_tx_delay_syn1 <= 4'h2;
        two_tx_delay_syn2 <= 4'h2;
    end
    else begin
        two_tx_delay_syn1 <= two_tx_delay;
        two_tx_delay_syn2 <= two_tx_delay_syn1;
    end
end



//三段式状态机
//第一段：状态转移
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        state <= IDLE;
    end
    else begin
        state <= nextstate;
    end
end

//第二段：状态转移的条件
always@(*) begin
    case(state)
    IDLE: begin
        if(tx_ack_delay2) begin
            nextstate = IRQ;
        end
        else begin
            nextstate = IDLE;
        end
    end
    IRQ: begin
        if(tx_bps_clk) begin
            nextstate = START_BIT;
        end
        else begin
            nextstate = IRQ;
        end
    end
    START_BIT: begin
        if(tx_bps_clk) begin
            nextstate = TX_DATA;
        end
        else begin
            nextstate = START_BIT;
        end
    end
    TX_DATA: begin
        //传输8bit的信号
        if(data_cnt < 4'd8) begin
            nextstate = TX_DATA;
        end
        else begin
            if(tx_bps_clk) begin
                if(check_en_syn2) begin
                    nextstate = CHECK_BIT;
                end
                else begin
                    nextstate = STOP;
                end
            end 
            else begin
                nextstate = TX_DATA;
            end
        end
    end
    CHECK_BIT: begin
        if(tx_bps_clk) begin
            if(stop_bit_syn2) begin
                nextstate = STOP;
            end
            else begin
                nextstate = DELAY;
            end
        end
        else begin
            nextstate = CHECK_BIT;
        end
    end
    STOP: begin
        if(tx_bps_clk) begin
            nextstate = DELAY;
        end
        else begin
            nextstate = STOP;
        end
    end
    DELAY: begin
        if(baud_cnt < two_tx_delay_syn2) begin
            nextstate = DELAY;
        end
        else begin
            nextstate = IDLE;
        end
    end
    default: begin
        nextstate = IDLE;
    end
    endcase
end

//第三段：输出信号
always@(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n) begin
        tx_bps_en <= 1'b0;
        tx_start <= 1'b0;
        tx_out   <= 1'b1;
        data_cnt <= 4'd0;
        baud_cnt <= 4'd0;
    end
    else begin
        case(nextstate)
        IDLE: begin
            tx_start   <= 1'b1;
            baud_cnt   <= 4'd0;
            data_cnt   <= 4'd0;
        end
        IRQ: begin
            tx_bps_en   <= 1'b1;
            tx_start   <= 1'b0;
        end
        START_BIT: begin
            if(tx_bps_clk) begin
                tx_out <= 1'b0;
            end
        end
        TX_DATA: begin
            if(tx_bps_clk) begin
                tx_out   <= data_tx[data_cnt];
                data_cnt <= data_cnt + 1'b1;
            end
        end
        CHECK_BIT: begin
            if(tx_bps_clk) begin
                // odd check
                if(parity_syn2) begin
                    tx_out <= ^data_tx;
                end
                // even check
                else begin
                    tx_out <= ^~data_tx;
                end
            end
        end
        STOP: begin
            if(tx_bps_clk) begin
                tx_out <= 1'b1;
            end
        end
        DELAY: begin
            if(tx_bps_clk) begin
                baud_cnt <= baud_cnt + 1'b1;
                tx_out   <= 1'b1;    // 两次数据传输之间的delay为1
            end
        end
        endcase
    end
end

//接收数据FIFO控制
//状态机，用来接收数据：dato from RX FIFO
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        tx_ack              <= 1'b0;
        tx_fifo_rd_en       <= 1'b0;
        rdata_state         <= 2'b0;
    end
    else begin
        case(rdata_state)
        2'b00: begin
            if(!tx_fifo_rempty && tx_start_delay2) begin
                tx_ack       <= 1'b1;
                tx_fifo_rd_en <= 1'b1;
                rdata_state  <= 2'b01;
            end
        end
        2'b01: begin
            tx_fifo_rd_en <= 1'b0;
            if(!tx_start_delay2) begin
                tx_ack      <= 1'b0;
                rdata_state <= 2'b10;
            end
        end
        2'b10: begin
            rdata_state <= 2'b0;
        end
        endcase
    end
end

endmodule