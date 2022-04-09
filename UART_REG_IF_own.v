module REG_IF_own (
    input               clk,
    input               rstn,
    //inputs from APB
    input       [3:0]   paddr_i,    
    input       [31:0]  pwdata_i,   
    input               psel_i,     
    input               penable_i,
    input               pwrite_i,
    //inputs from RX
    input               st_error,       //接收数据，停止位状态指示
    input               p_error,        //接收数据，校验位状态指示
    input               rx_fifo_rempty, //rx_fifo读空信号
    input       [4:0]   rx_fifo_cnt,    //5位，rx_fifo内数据指示
    input       [7:0]   rx_data,        //data_to_regif
    //inputs from TX
    input               tx_fifo_wfull,  //tx_fifo写满信号
    input       [4:0]   tx_fifo_cnt,    //5位，tx_fifo内数据指示
    //outputs to CPU
    output  reg         uart_int_o,     // interupt signal to CPU
    //outputs to APB
    output  reg [31:0]  prdata_o,
    //outputs to RX
    output  reg         st_check,
    output  reg         p_error_ack,
    output  reg         st_error_ack,
    output  reg         rx_fifo_rst,
    //outputs to TX
    output  reg         stop_bit,
    output  reg [3:0]   two_tx_delay,
    output  reg [7:0]   tx_data,
    output  reg          tx_fifo_rst,
    //outputs to RX and TX
    output reg          check,
    output reg          parity,
    output reg          rx_fifo_rd_en,
    output reg          tx_fifo_wr_en,
    output reg [9:0]    baud_div
);

reg  [31:0]     uart_tx;             // UART send data register
reg  [31:0]     uart_rx;             // UART receive data register
reg  [31:0]     uart_baud;           // baud frequency division register
reg  [31:0]     uart_conf;           // UART configuration register
reg  [31:0]     uart_rxtrig;         // RX_FIFO trigger register
reg  [31:0]     uart_txtrig;         // TX_FIFO trigger register
reg  [31:0]     uart_delay;          // UART delay register
reg  [31:0]     uart_status;         // UART statu register
reg  [31:0]     uart_rxfifo_stat;    // RX_FIFO statu register
reg  [31:0]     uart_txfifo_stat;    // TX_FIFO statu register
reg             rx_state;               // RX FIFO enable control state
reg  [1:0]      tx_state;            // TX FIFO enable control state
reg             rx_state_int;            // RX FIFO interrupt produce state
reg             tx_state_int;            // TX FIFO interrupt produce state

reg             uart_status3_delay1;
reg             uart_status3_delay2;
wire            neg_uart_status3;

reg             uart_status2_delay1;
reg             uart_status2_delay2;
wire            neg_uart_status2;

reg             st_error_syn1;
reg             st_error_syn2;
reg             st_error_syn3;
wire            st_error_syn;

reg             p_error_syn1;
reg             p_error_syn2;
reg             p_error_syn3;
wire            p_error_syn;

//第一部分：状态信息同步，打拍+边沿检测
//产生uart_status[3]的负边沿
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        uart_status3_delay1 <= 1'b0;
        uart_status3_delay2 <= 1'b0;
    end
    else begin
        uart_status3_delay1 <= uart_status[3];
        uart_status3_delay2 <= uart_status3_delay1;
    end
end
assign  neg_uart_status3 = (!uart_status3_delay1) && uart_status3_delay2;

//产生uart_status[2]的负边沿
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        uart_status2_delay1 <= 1'b0;
        uart_status2_delay2 <= 1'b0;
    end
    else begin
        uart_status2_delay1 <= uart_status[2];
        uart_status2_delay2 <= uart_status2_delay1;
    end
end
assign  neg_uart_status2 = (!uart_status2_delay1) && uart_status2_delay2;

//时钟域同步：p_error to clk
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        p_error_syn1 <= 1'b0;
        p_error_syn2 <= 1'b0;
        p_error_syn3 <= 1'b0;
    end
    else begin
        p_error_syn1 <= p_error;
        p_error_syn2 <= p_error_syn1;
        p_error_syn3 <= p_error_syn2;
    end
end
assign  p_error_syn = p_error_syn2 && (!p_error_syn3);

//时钟域同步：st_error to clk
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        st_error_syn1 <= 1'b0;
        st_error_syn2 <= 1'b0;
        st_error_syn3 <= 1'b0;
    end
    else begin
        st_error_syn1 <= st_error;
        st_error_syn2 <= st_error_syn1;
        st_error_syn3 <= st_error_syn2;
    end
end
assign  st_error_syn = st_error_syn2 && (!st_error_syn3);

//第二部分：APB总线读写
//写寄存器
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        uart_tx     <= 32'h0;
        uart_baud   <= 32'hf152;
        uart_conf   <= 32'h34;
        uart_rxtrig <= 32'h1;
        uart_txtrig <= 32'h0;
        uart_delay  <= 32'h2;
    end
    else begin
        // APB write
        if(psel_i && penable_i && pwrite_i) begin
            case(paddr_i)
            4'h0:
                uart_tx     <= pwdata_i;
            4'h2:
                uart_baud   <= pwdata_i;
            4'h3:
                uart_conf   <= pwdata_i;
            4'h4:
                uart_rxtrig <= pwdata_i;
            4'h5:
                uart_txtrig <= pwdata_i;
            4'h6:
                uart_delay  <= pwdata_i;
            endcase
        end
    end
end

//读寄存器
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        prdata_o <= 32'h0;
    end
    else begin
        // APB read
        if(psel_i && (!penable_i) && (!pwrite_i)) begin
            case(paddr_i)
            4'h0:
                prdata_o <= uart_tx;
            4'h1:
                prdata_o <= uart_rx;
            4'h2:
                prdata_o <= uart_baud;
            4'h3:
                prdata_o <= uart_conf;
            4'h4:
                prdata_o <= uart_rxtrig;
            4'h5:
                prdata_o <= uart_txtrig;
            4'h6:
                prdata_o <= uart_delay;
            4'h7:
                prdata_o <= uart_status;
            4'h8:
                prdata_o <= uart_rxfifo_stat;
            4'h9:
                prdata_o <= uart_txfifo_stat;
            endcase
        end
    end
end

//状态寄存器写入
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        uart_rxfifo_stat <= 32'h0;
        uart_txfifo_stat <= 32'h0;
    end
    else begin
        uart_rxfifo_stat <= {27'b0,rx_fifo_cnt};
        uart_txfifo_stat <= {27'b0,tx_fifo_cnt};
    end
end

//第三部分：FIFO使能控制
//ARM read
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        rx_fifo_rd_en <= 1'b0;
        rx_state       <= 1'b0;
    end
    else begin
        case(rx_state)
        1'b0: begin
            /* 在cpu读uart状态寄存器（uart_status）时，
            如果rx中断有效（即状态位的第1bit位有效），且FIFO不为空，RX_FIFO读使能一个时钟周期*/
            if(psel_i && (!penable_i)&&(!pwrite_i)&&(paddr_i==4'h7)) begin
                if(uart_status[1] && !rx_fifo_rempty) begin
                    rx_fifo_rd_en <= 1'b1;
                    rx_state        <= 1'b1;
                end
            end
            /* 或在cpu读接收数据寄存器（uart_rx）时，RX_FIFO读使能一个时钟周期。*/
            if(psel_i &&(!penable_i)&&(!pwrite_i)&&(paddr_i==4'h1)) begin
                rx_fifo_rd_en <= 1'b1;
                rx_state        <= 1'b1;
            end
        end
        1'b1: begin
            rx_fifo_rd_en <= 1'b0;
            rx_state        <= 1'b0;
        end
        endcase
    end
end

//TX_FIFO enable
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_fifo_wr_en <= 1'b0;
        tx_state     <= 2'b0;
    end
    else begin
        case(tx_state)
        2'b0: begin
            // ARM write uart_tx,tx_fifo_winc enable 1 clk after 1 clk
            if(psel_i && penable_i && pwrite_i && (paddr_i==4'h0)) begin
                tx_state <= 2'b01;
            end
        end
        2'b01: begin
            tx_state    <= 2'b10;
            tx_fifo_wr_en <= 1'b1;
        end
        2'b10: begin
            tx_fifo_wr_en <= 1'b0;
            tx_state     <= 2'b0;
        end
        endcase
    end
end

/*第四部分：状态寄存器操作及中断产生
uart_status register operation*/
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        p_error_ack  <= 1'b0;
        st_error_ack <= 1'b0;
        uart_status  <= 32'h0;
        rx_state_int     <= 1'b0;
        tx_state_int     <= 1'b0;
    end
    else begin
        if(st_error_syn) begin
            uart_status[3]   <= 1'b1;
        end
        else begin
            if(neg_uart_status3) begin
                st_error_ack <= 1'b1;
            end
            else begin
                if(!st_error_syn2) begin
                    st_error_ack <= 1'b0;
                end
            end
        end
        if(p_error_syn) begin
            uart_status[2]   <= 1'b1;
        end
        else begin
            if(neg_uart_status2) begin
                p_error_ack  <= 1'b1;
            end
            else begin
                if(!p_error_syn2) begin
                    p_error_ack  <= 1'b0;
                end
            end
        end
        // when rx_fifo_cnt from less than to equal the rxtrig,
        // rx_int is active
        case(rx_state_int)
        1'b0: begin
            if(rx_fifo_cnt == (uart_rxtrig[3:0] - 1'b1)) begin
                rx_state_int      <= 1'b1;
            end
            else begin
                rx_state_int      <= 1'b0;
            end
        end
        1'b1: begin
            if(rx_fifo_cnt == uart_rxtrig[3:0]) begin
                uart_status[1] <= 1'b1;
                rx_state_int       <= 1'b0;
            end
            else begin
                rx_state_int       <= 1'b1;
            end
        end
        endcase
        // 当tx_fifo计数减小，直到等于trigger register数目时，置tx_int为1
        //when tx_fifo_cnt from greater than to equal the txtrig,
        // tx_int is active
        case(tx_state_int)
        1'b0: begin
            if(tx_fifo_cnt == (uart_txtrig[3:0] + 1'b1)) begin
                tx_state_int       <= 1'b1;
            end
            else begin
                tx_state_int       <= 1'b0;
            end
        end
        1'b1: begin
            if(tx_fifo_cnt == uart_txtrig[3:0]) begin
                uart_status[0] <= 1'b1;
                tx_state_int       <= 1'b0;
            end
            else begin
                tx_state_int       <= 1'b1;
            end
        end
        endcase
        // ARM write 1 clean 0  uart_status
        if(psel_i && penable_i && pwrite_i && (paddr_i==4'h7)) begin
            uart_status <= uart_status & (~pwdata_i);
        end
    end
end

// 产生中断信号produce interrupt to CPU
always @(posedge clk or negedge rstn) begin
    if(!rstn) begin
	      uart_int_o <= 1'b0;
		end
	  else begin
	      if(|uart_status[3:0]) begin
            uart_int_o <= 1'b1;
        end
		    else begin
            uart_int_o <= 1'b0;
        end
		end
end


// read data from RX FIFO to uart_rx
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        uart_rx <= 8'h0;
    end
    else begin
        uart_rx <= {24'b0,rx_data};
    end
end


// outputs register
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        tx_data         <= 8'h0;
        baud_div        <= 10'h152;
        rx_fifo_rst     <= 1'b0;
        tx_fifo_rst     <= 1'b0;
        st_check        <= 1'b0;
        stop_bit        <= 1'b0;
        parity          <= 1'b0;
        check           <= 1'b0;
        two_tx_delay    <= 4'h2;
    end
    else begin
        tx_data         <= uart_tx[7:0];
        baud_div        <= uart_baud[9:0];
        rx_fifo_rst     <= uart_conf[15];
        tx_fifo_rst     <= uart_conf[14];
        st_check        <= uart_conf[3];
        stop_bit        <= uart_conf[2];
        parity          <= uart_conf[1];
        check           <= uart_conf[0];
        two_tx_delay    <= uart_delay[3:0];
    end
end

endmodule

 
