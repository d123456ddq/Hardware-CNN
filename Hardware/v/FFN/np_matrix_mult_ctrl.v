`include "../../network_params.h"
module np_matrix_mult_ctrl(
  input clock,
  input reset,

  input start,
  
  output reg [`FM_ADDR_BITWIDTH:0] addr,
  output reg [`NUM_KERNELS-1:0] ram_select,
  output reg product_rdy
);

always @(posedge clock or negedge reset) begin
  if (reset == 1'b0) begin
    addr <= `FM_ADDR_WIDTH'd0;
    ram_select <= `NUM_KERNELS'd0;
  end else begin
    if (start) begin
      addr <= `FM_ADDR_WIDTH'd0;
      ram_select <= `NUM_KERNELS'd0;
    end else if( addr == `ADDR_MAX) begin
      ram_select <= ram_select + `NUM_KERNELS'd1;
      addr <= `FM_ADDR_WIDTH'd0;
    end else begin
      addr <= addr + `FM_ADDR_WIDTH'd1;
      ram_select <= ram_select;
    end 
  end // reset
end // always


// ready signal logic
always@(posedge clock or negedge reset) begin
  if(reset == 1'b0) begin
    product_rdy <= 1'b0;
  end else begin
    if(ram_select == `NUM_KERNELS & addr == `ADDR_MAX) begin
      product_rdy <= 1'b1;
    end else begin
      product_rdy <= 1'b0;
    end // select max
  end // reset
end // always

endmodule
