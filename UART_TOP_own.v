module UART_TOP_own (
    input               clk,
    input               clk26m,
    input               rstn,
    input               rst26m_n,
    input       [3:0]   paddr_i,    
    input       [31:0]  pwdata_i,   
    input               psel_i,     
    input               penable_i,
    input               pwrite_i,
    input               rx_in,
    output              tx_out,
    output              uart_int_o,
    output      [31:0]  prdata_o
);
    //RX signals
    wire                rx_bps_clk;
    wire                st_check;
    wire                partiy;
    wire                check_en;
    wire                p_error_ack;
    wire                rx_fifo_rst;
    wire                rx_fifo_rd_en;
    wire                rx_bps_en;
    wire                st_error;
    wire                p_error;
    wire                rx_fifo_rempty;
    wire        [4:0]   rx_fifo_cnt;
    wire        [7:0]   data_to_regif;//rx to reg_if

    //TX signals
    wire                tx_bps_clk;
    wire                stop_bit;
    wire        [3:0]   two_tx_delay;
    wire                tx_fifo_rst;
    wire                tx_fifo_wr_en;
    wire                tx_bps_en;
    wire                tx_fifo_wfull;
    wire        [4:0]   tx_fifo_cnt;
    wire        [7:0]   data_from_regif;//data to tx

    //BAUD signal
    wire        [9:0]   baud_div;

    //modulations
    UART_RX_own    uart_rx(
        .clk(clk),
        .rstn(rstn),
        .clk26m(clk26m),
        .rst26m_(rst26m_n),
        .rx_in(rx_in),
        .rx_bps_clk(rx_bps_clk),
        .st_check(st_check),
        .parity(parity),
        .check_en(check_en),
        .p_error_ack(p_error_ack),
        .st_error_ack(st_error_ack),
        .rx_fifo_rst(rx_fifo_rst),
        .rx_fifo_rd_en(rx_fifo_rd_en),
        .rx_bps_en(rx_bps_en),
        .st_error(st_error),
        .p_error(p_error),
        .rx_fifo_rempty(rx_fifo_rempty),
        .rx_fifo_cnt(rx_fifo_cnt),
        .data_to_regif(data_to_regif)
);
    UART_TX_own    uart_tx(
        .clk(clk),
        .rstn(rstn),
        .clk26m(clk26m),
        .rst26m_(rst26m_n),
        .check_en(check_en),
        .parity(parity),
        .tx_bps_clk(tx_bps_clk),
        .stop_bit(stop_bit),
        .data_from_regif(data_from_regif),
        .two_tx_delay(two_tx_delay),
        .tx_fifo_rst(tx_fifo_rst),
        .tx_fifo_wr_en(tx_fifo_wr_en),
        .tx_bpsen(tx_bps_en),
        .tx_out(tx_out),
        .tx_fifo_wfull(tx_fifo_wfull),
        .tx_fifo_cnt(tx_fifo_cnt)
);

    UART_BAUD_own    uart_baud(
        .clk26m(clk26m),
        .rst26m_n(rst26m_n),
        .tx_bps_en(tx_bps_en),
        .rx_bps_en(rx_bps_en),
        .baud_div(baud_div),
        .rx_bps_clk(rx_bps_clk),
        .tx_bps_clk(tx_bps_clk)
);
    UART_REG_IF_own uart_reg_if_own(
        .clk(clk),
        .rstn(rstn),
        .paddr_i(paddr_i),
        .pwdata_i(pwdata_i),
        .psel_i(psel_i),
        .penable_i(penable_i),
        .pwrite_i(pwrite_i),
        .st_error(st_error),
        .p_error(p_error),
        .rx_fifo_rempty(rx_fifo_rempty),
        .rx_fifo_cnt(rx_fifo_cnt),
        .rx_data(data_to_regif),
        .tx_fifo_wfull(tx_fifo_wfull),
        .tx_fifo_cnt(tx_fifo_cnt),
        .uart_int_o(uart_int_o),
        .prdata_o(prdata_o),
        .st_check(st_check),
        .p_error_ack(p_error_ack),
        .st_error_ack(st_error_ack),
        .rx_fifo_rst(rx_fifo_rst),
        .stop_bit(stop_bit),
        .two_tx_delay(two_tx_delay),
        .tx_data(data_from_regif),
        .tx_fifo_rst(tx_fifo_rst),
        .check_en(check_en),
        .parity(parity),
        .rx_fifo_rd_en(rx_fifo_rd_en),
        .tx_fifo_wr_en(tx_fifo_wr_en),
        .baud_div(baud_div)
);

endmodule