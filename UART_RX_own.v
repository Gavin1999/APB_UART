module UART_RX_own (
    //input
    input           clk,                //ARM功能时钟
    input           rstn,              //ARM复位，低有效
    input           clk26m,             //26MHz功能时钟
    input           rst26m_n,           //26MHz功能时钟复位，低有效
    input           rx_in,              //UART接收数据线
    input           rx_bps_clk,         //接收波特率时钟
    input           st_check,           //停止位检测控制信号
    input           parity,             //奇偶校验控制信号
    input           check_en,           //校验位的使能信号，高有效
    input           p_error_ack,        //p_error响应信号
    input           st_error_ack,       //st_error响应信号
    input           rx_fifo_rst,        //rx_fifo复位信号
    input           rx_fifo_rd_en,      //rx_fifo读使能信号,高有效
    //output
    output  reg     rx_bps_en,          //接收波特率使能信号，高有效
    output  reg     st_error,           //接收数据，停止位状态指示
    output  reg     p_error,            //接收数据，校验位状态指示
    output          rx_fifo_rempty,     //rx_fifo读空信号
    output [4:0]    rx_fifo_cnt,        //5位，rx_fifo内数据指示
    output [7:0]    data_to_regif       //从rx_fifo到reg_if模块的接收数据
);

    reg             rx_fifo_wr_en;      //rx_fifo写使能信号，高有效
    reg    [2:0]    state;
    reg    [2:0]    nextstate;
    reg    [1:0]    wdata_state;
    reg    [4:0]    data_cnt;
    reg    [7:0]    data_rx;
    wire            rx_fifo_wfull;


    wire            neg_rx_in;          //UART接收数据线rx_in的负边沿
    reg             start_right;        //起始bit的右侧标志
    reg             rx_start;           //接收数据的请求信号
    reg             rx_ack;             //接收数据的完成响应的信号
//同步信号，用于打拍
    reg             rx_in_delay1;
    reg             rx_in_delay2;
    reg             rx_ack_delay1;
    reg             rx_ack_delay2;
    reg             st_error_ack_delay1;
    reg             st_error_ack_delay2;
    reg             p_error_ack_delay1;
    reg             p_error_ack_delay2;
    reg             rx_start_delay1;
    reg             rx_start_delay2;
    reg             st_check_syn1;
    reg             st_check_syn2;
    reg             parity_syn1;
    reg             parity_syn2;
    reg             check_en_syn1;
    reg             check_en_syn2;

//状态机定义
parameter           IDLE        = 3'b000;
parameter           START       = 3'b001;
parameter           RX_DATA     = 3'b010;
parameter           CHECK_DATA  = 3'b011;
parameter           STOP        = 3'b110;
parameter           SEND        = 3'b111;

//调用FIFO模块
UART_FIFO_own   uart_rx_fifo(
    .clk(clk),
    .rstn(rstn),
    .fifo_rst(rx_fifo_rst),
    .rd_en(rx_fifo_rd_en),
    .wr_en(rx_fifo_wr_en),
    .data_in(data_rx),
    .data_out(data_to_regif),
    .wr_full(rx_fifo_wfull),
    .rd_empty(rx_fifo_rempty),
    .fifo_cnt(rx_fifo_cnt)
);

//时钟域同步：rx_ack to clk26m
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        rx_ack_delay1 <= 1'b0;
        rx_ack_delay2 <= 1'b0;
    end
    else begin
        rx_ack_delay1 <= rx_ack;
        rx_ack_delay2 <= rx_ack_delay1;
    end 
end

//时钟域同步：st_error_ack to clk26m
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        st_error_ack_delay1 <= 1'b0;
        st_error_ack_delay2 <= 1'b0;
    end
    else begin
       st_error_ack_delay1 <= st_error_ack;
       st_error_ack_delay2 <= st_error_ack_delay1; 
    end
end

//时钟域同步：p_error_ack to clk26m
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        p_error_ack_delay1 <= 1'b0;
        p_error_ack_delay2 <= 1'b0;
    end
    else begin
        p_error_ack_delay1 <= p_error_ack;
        p_error_ack_delay2 <= p_error_ack_delay1; 
    end
end

//时钟域同步：rx_start to ARM clk
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        rx_start_delay1 <= 1'b0;
        rx_start_delay2 <= 1'b0;       
    end
    else begin
       rx_start_delay1 <= rx_start;
       rx_start_delay2 <= rx_start_delay1; 
    end
end

//时钟域同步：st_check to clk26m
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        st_check_syn1 <= 1'b0;
        st_check_syn2 <= 1'b0;
    end
    else begin
        st_check_syn1 <= st_check;
        st_check_syn2 <= st_check_syn1;
    end
end

//时钟域同步，奇偶校验：parity to clk26m
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        parity_syn1 <= 1'b0;
        parity_syn2 <= 1'b0;
    end
    else begin
        parity_syn1 <= parity;
        parity_syn2 <= parity_syn1;
    end
end

//时钟域同步：check to clk26m
always@(posedge clk26m or negedge rst26m_n)begin
    if(!rst26m_n)begin
        check_en_syn1 <= 1'b0;
        check_en_syn2 <= 1'b0;
    end
    else begin
        check_en_syn1 <= check_en;
        check_en_syn2 <= check_en_syn1;
    end
end



//时钟域同步，uart数据接收线：rx_in，并产生其负边沿neg_rx_in
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        rx_in_delay1 <= 1'b0;
        rx_in_delay2 <= 1'b0;
    end
    else begin
        rx_in_delay1 <= rx_in;
        rx_in_delay2 <= rx_in_delay1;
    end
end
assign neg_rx_in = !rx_in_delay1 && rx_in_delay2;

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
always @(*) begin
    case(state)
    IDLE:begin
        if(neg_rx_in)begin
            nextstate = START;
        end
        else begin
            nextstate = IDLE; 
        end 
    end
    START:begin
        if(start_right==1)begin
            nextstate = RX_DATA;
        end
        else begin
            nextstate = IDLE;
        end
    end
    RX_DATA:begin
        if(data_cnt < 4'd8)begin
            nextstate = RX_DATA;
        end
        else begin
            if(rx_bps_clk) begin//在接收波特率时钟下，状态转移
                if(check_en_syn2) begin
                    nextstate = CHECK_DATA; 
                end
                else begin
                    nextstate = STOP;
                end
            end
            else begin
                nextstate = RX_DATA;
            end 
        end 
    end
    CHECK_DATA:begin
        if(p_error_ack_delay2)begin
            nextstate = IDLE;
        end
        else begin
            if(rx_bps_clk)begin
                    if(p_error)begin
                        nextstate = CHECK_DATA;  
                    end
                    else begin
                        if(st_check_syn2)begin
                            nextstate = STOP;
                        end
                        else begin
                            nextstate = SEND;
                        end
                end
            end
            else begin
                nextstate = CHECK_DATA;
            end
        end
    end
    STOP:begin
        if(st_error_ack_delay2)begin
            nextstate = IDLE;
        end
        else begin
            if(rx_bps_clk)begin
                if(st_error) begin
                    nextstate = STOP;
                end
                else begin
                    nextstate = SEND;
                end
            end
            else begin
                nextstate = STOP;
            end
        end    
    end
    SEND: begin
        if(rx_ack_delay2)begin
            nextstate = IDLE;
        end
        else begin
            nextstate = SEND;
        end
    end
    default:begin
        nextstate = IDLE;
    end
    endcase
end    

//第三段：组合逻辑，输出信号
always @(posedge clk26m or negedge rst26m_n) begin
    if(!rst26m_n)begin
        rx_bps_en   <= 1'b0;
        st_error    <= 1'b0;
        p_error     <= 1'b0;
        data_cnt    <= 4'd0;
        data_rx     <= 8'd0;
        start_right <= 1'b0;
        rx_start    <= 1'b0;
    end
    else begin
        case(nextstate)
        IDLE:begin
            rx_bps_en   <= 1'b0;
            st_error    <= 1'b0;
            p_error     <= 1'b0;
            data_cnt    <= 4'b0;
            data_rx     <= 8'b0;
            start_right <= 1'b0;
        end
        START:begin
            rx_bps_en   <= 1'b1;
            if(rx_bps_clk)begin
                if(rx_in == 1'b0)begin
                    start_right <= 1'b1;
                end
                else begin
                    start_right <= 1'b0;
                end
            end
        end
        RX_DATA:begin
            if(rx_bps_clk)begin
                data_rx[data_cnt] <= rx_in;
                data_cnt <=data_cnt +1'b1;
            end
        end
        CHECK_DATA:begin
            if(rx_bps_clk)begin
                //奇校验
                if(parity_syn2)begin
                    if(^data_rx ==  rx_in) begin
                        p_error     <= 1'b1;
                        rx_bps_en   <= 1'b0;
                    end
                end
                //偶校验
                else begin
                    if (^data_rx == !rx_in) begin
                        p_error     <= 1'b1;
                        rx_bps_en   <= 1'b0;
                    end
                end
            end
        end    
        STOP:begin
            if(rx_bps_clk)begin
                if(rx_in == 1'b0) begin
                    st_error    <= 1'b1;
                    rx_bps_en   <= 1'b0;
                end
            end
        end
        SEND:begin
            rx_start <= 1'b1;
        end
        endcase
    end
end

//发送数据FIFO控制
//状态机，传输数据：data to RX_FIFO
always @(posedge clk or negedge rstn) begin
    if(!rstn)begin
        rx_ack          <= 1'b0;
        rx_fifo_wr_en   <= 1'b0;
        wdata_state     <= 2'b0;
    end
    else begin
        case(wdata_state)
        2'b00:begin
            if(!rx_fifo_wfull && rx_start_delay2)begin
                rx_ack          <= 1'b1;
                rx_fifo_wr_en   <= 1'b1;
                wdata_state     <= 2'b01;
            end
        end
        2'b01:begin
            rx_fifo_wr_en       <=1'b0;
            if(!rx_start_delay2)begin
                rx_ack          <=1'b0;
                wdata_state     <=2'b10;
            end 
        end
        2'b10:begin
            wdata_state         <=2'b00;
        end
        endcase
    end
end

endmodule