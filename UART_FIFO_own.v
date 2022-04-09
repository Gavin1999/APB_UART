`timescale 1ns/1ps
module    UART_FIFO_own(
    //inputs
    input clk,                 // ARM功能时钟
    input rstn,                // ARM复位，低有效
    input fifo_rst,            // rx_fifo复位信号
    input rd_en,               // FIFO read enable signal
    input wr_en,                // FIFO write enable signal
    input data_in,              // in data line
    //outputs
    output reg [7:0] data_out,  // FIFO out data
    output wr_full,              // write full signal
    output rd_empty,             // read empty signal
    output reg [4:0] fifo_cnt    // FIFO statu register
);

wire             full;
wire             empty;   
reg  [4:0]      wptr;                // write pointer
reg  [4:0]      rptr;                // read pointer
reg  [7:0]      ram[15:0];           // ram in FIFO,8位，深度为16的ram

assign wr_full=full;
assign rd_empty=empty;

//read data from ram, rd_en且!empty，FIFO非空，可以read，rptr+1
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        data_out <= 8'd0;
        rptr   <= 5'd0;
    end
    else begin
        if(fifo_rst) begin
            rptr <= 5'd0;
        end
        else begin
            if(rd_en && !empty) begin
                data_out <= ram[rptr[3:0]];
                rptr   <= rptr + 1'b1;
            end
        end
    end
end

// write data in ram，wr_en且!full,FIFO未满，可以write，wptr+1
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        wptr <= 5'd0;
    end
    else begin
        if(fifo_rst) begin
            wptr <= 5'd0;
        end
        else begin
            if(wr_en && !full) begin
                ram[wptr[3:0]] <= data_in;
                wptr            <= wptr + 1'b1; 
            end
        end
    end
end

// the number of data in the FIFO
always@(posedge clk or negedge rstn) begin
    if(!rstn) begin
        fifo_cnt <= 5'd0;
    end
    else begin
        fifo_cnt <= wptr - rptr;
    end
end

// produce full and empty signal
assign    full  = ({!wptr[4],wptr[3:0]}==rptr)? 1'b1 : 1'b0;
assign    empty = (wptr==rptr)? 1'b1:1'b0;

endmodule