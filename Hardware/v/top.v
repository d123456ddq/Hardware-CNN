`include "../network_params.h"
module top(
  input clock, 
  input reset,

  // video inputs
  input [`SCREEN_X_BITWIDTH:0] screen_x_pos,
  input [`SCREEN_Y_BITWIDTH:0] screen_y_pos,
  input [`CAMERA_PIXEL_BITWIDTH:0] test_pixel,
  // hex outputs
  
  output [`RECT_OUT_BITWIDTH:0] rect1,
  output [`RECT_OUT_BITWIDTH:0] rect2,
  output [`RECT_OUT_BITWIDTH:0] rect3,
  output [`RECT_OUT_BITWIDTH:0] rect4,
  output [`RECT_OUT_BITWIDTH:0] rect5,
  output [`RECT_OUT_BITWIDTH:0] rect6,
  output [`RECT_OUT_BITWIDTH:0] rect7,
  output [`RECT_OUT_BITWIDTH:0] rect0
);


//////////////////////
// wire declaratations
//////////////////////

// window wires
wire [`WINDOW_VECTOR_BITWIDTH:0] window_content;
wire shift_left;
wire shift_up;
wire buffer_rdy; // indicates that the shifting window buffer is full

// multiply adder wires
wire [`X_COORD_BITWIDTH:0] ma_x_coord;
wire [`Y_COORD_BITWIDTH:0] ma_y_coord;
wire [`CONV_ADD_BITWIDTH:0] fm_pixel_vector[`NUM_KERNELS-1:0]; // one pixel from the end of each multiply adder tree
wire [`RECT_OUT_BITWIDTH:0] rectified_vector[`NUM_KERNELS-1:0]; // one pixel from the output of each rect-linear module 
wire pixel_rdy;
wire [(`KERNEL_SIZE_SQ*`CAMERA_PIXEL_WIDTH)-1:0] k[`NUM_KERNELS-1:0];

// feature map sr wires
wire [`X_COORD_BITWIDTH:0] fm_x_coord;  // connected to fm sr outputs
wire [`Y_COORD_BITWIDTH:0] fm_y_coord;

// feature map RAM buffer wires
wire [`FM_ADDR_BITWIDTH:0] fm_wr_addr;
wire [(`FFN_IN_WIDTH*`NUM_KERNELS)-1:0] fm_buffer_data_vector;
wire [(`FFN_IN_WIDTH*`NUM_KERNELS)-1:0] w_buffer_data_vector;
wire [`FFN_IN_BITWIDTH:0] fm_mux_q;
wire fm_buffer_full;

// matrix multiply wires

// reg declarations

// parameters
//parameter BUFFER_X_POS = `SCREEN_X_WIDTH'd300; // changed for testing
//parameter BUFFER_Y_POS = `SCREEN_Y_WIDTH'd300;

// FOR TESTING
assign rect0 = rectified_vector[0];
assign rect1 = rectified_vector[1];
assign rect2 = rectified_vector[2];
assign rect3 = rectified_vector[3];
assign rect4 = rectified_vector[4];
assign rect5 = rectified_vector[5];
assign rect6 = rectified_vector[6];
assign rect7 = rectified_vector[7];
parameter BUFFER_X_POS = `SCREEN_X_WIDTH'd0;
parameter BUFFER_Y_POS = `SCREEN_Y_WIDTH'd0;



//////////////////////
// assign statments
//////////////////////


// kernel files
`include "../kernel_defs.h"


// camera refrence design
/*
DE2_115_CAMERA(
module DE2_115_CAMERA(

	//////////// CLOCK //////////
  .CLOCK_50(),
  .CLOCK2_50(),
	.CLOCK3_50(),
	//////////// LED //////////
	.LEDG(),
	.LEDR(),

	//////////// KEY //////////
	.KEY(),
	//////////// SW //////////
	.SW(),

	//////////// SEG7 //////////
	.HEX0(),
	.HEX1(),
	.HEX2(),
	.HEX3(),
	.HEX4(),
	.HEX5(),
	.HEX6(),
	.HEX7(),

	//////////// VGA //////////
	.VGA_B(),
	.VGA_BLANK_N(),
	.VGA_CLK(),
	.VGA_G(),
	.VGA_HS(),
	.VGA_R(),
	.VGA_SYNC_N(),
	.VGA_VS(),
	//////////// SDRAM //////////
	.DRAM_ADDR(),
	.DRAM_BA(),
	.DRAM_CAS_N(),
	.DRAM_CKE(),
	.DRAM_CLK(),
	.DRAM_CS_N(),
	.DRAM_DQ(),
	.DRAM_DQM(),
	.DRAM_RAS_N(),
	.DRAM_WE_N(),
	//////////// GPIO, GPIO connect to D5M - 5M Pixel Camera //////////
	.D5M_D(),
	.D5M_FVAL(),
	.D5M_LVAL(),
	.D5M_PIXLCLK(),
	.D5M_RESET_N(),
	.D5M_SCLK(),
	.D5M_SDATA(),
	.D5M_STROBE(),
	.D5M_TRIGGER(),
	.D5M_XCLKIN() 
);

*/

// shifting window and window selectors
window_wrapper window_inst(
  .clock(clock),
  .reset(reset),
  // buffer inputs
  .pixel_in(test_pixel),
  .shift_left(shift_left),
  .shift_up(shift_up),
  // window inputs
  .kernel_x(ma_x_coord), // the bottom right corner of the kernel position
  .kernel_y(ma_y_coord), // the bottom right corner of the kernel position

  // the kernel sized view of the buffer to be fed into the multipliers
  .window_out(window_content)
);

window_ctrl window_ctrl_inst(
  .clock(clock),
  .reset(reset),
  .buffer_x_pos(BUFFER_X_POS),
  .buffer_y_pos(BUFFER_Y_POS),
  .screen_x(screen_x_pos), // from demo
  .screen_y(screen_y_pos),
  .shift_up(shift_up),
  .shift_left(shift_left),
  .buffer_rdy(buffer_rdy)
);


// multiply-adder control module, inst outside of loop (only 1 is needed)
mult_adder_ctrl ma_inst(
  .clock(clock),
  .reset(reset),
  .start(buffer_rdy),
  .x_coord(ma_x_coord),
  .y_coord(ma_y_coord),
  .pixel_rdy(pixel_rdy) // rdy sr includes regs for mult and rect linear stages
);
genvar tree_count;
generate
for (tree_count = 0; tree_count < `NUM_KERNELS; tree_count = tree_count+1) begin : inst_mult_adder_trees
  // multiply adder trees
  mult_adder mult_adder_inst(
    .clock(clock),
    .reset(reset),
    .in({`WINDOW_PAD_WIDTH'd0, window_content}),
    .kernal({`WINDOW_PAD_WIDTH'd0, k[tree_count]}),
    .out(fm_pixel_vector[tree_count])
  );

  // rectified linear function
  rect_linear rect_inst(
    .clock(clock),
    .reset(reset),
    .rect_in(fm_pixel_vector[tree_count]),
    .rect_out(rectified_vector[tree_count])
  );
/*
  // Feature Map RAM buffer
  fm_buffer fm_buffer_inst(
    .clock(clock),
    .reset(reset),
    .wraddress(fm_wr_addr),
    .data(rectified_vector[tree_count]),
    .wren(pixel_rdy),
    .rdaddress(fm_rd_addr),
    .q(fm_buffer_data_vector[(`FFN_IN_WIDTH*tree_count)+`FFN_IN_BITWIDTH:`FFN_IN_WIDTH*tree_count])
  );

  // Weight Matrix Buffer
  weight_rom weight_buffer_inst(
    .clock(clock),
    .reset(reset),
//    .wraddress(weight_wr_addr),
//    .data()
//    .wren(pixel_rdy),
    .rdaddress(fm_rd_addr),
    .q(w_buffer_data_vector[(`FFN_IN_WIDTH*tree_count)+`FFN_IN_BITWIDTH:`FFN_IN_WIDTH*tree_count])
  );
*/

end // for
endgenerate

fm_coord_sr fm_coord_sr_inst(
  .clock(clock),
  .reset(reset),
  .x_coord(ma_x_coord),
  .y_coord(ma_y_coord),
  .fm_x_coord(fm_x_coord),
  .fm_y_coord(fm_y_coord)
);


/*
feature_map_buffer_ctrl(
  .clock(clock),
  .reset(reset),
  .data_rdy(pixel_rdy),
  .xcoord(fm_x_coord),// must hold coords through tree
  .ycoord(fm_y_coord),
  .addr(fm_wr_addr),
  .buffer_full(fm_buffer_full)
);


// read port mux
read_port_mux fm_port_mux_inst(
  .clock(clock),
  .reset(reset),
  .ram_select(fm_buffer_select),
  .buffer_data_vector(fm_buffer_data_vector),
  .data_out(fm_mux_q)
);

read_port_mux w_port_mux_inst(
  .clock(clock),
  .reset(reset),
  .ram_select(fm_buffer_select),
  .buffer_data_vector(w_buffer_data_vector),
  .data_out(w_mux_q)
);
// matrix multiply
genvar np_counter;
generate
for (np_counter=0; np_counter<`NUM_CLASSES; np_counter=np_counter+1) begin : np_inst_loop
  np_matrix_mult mm_inst(
    .clock(clock),
    .reset(reset),
    .feature_pixel(fm_mux_q),
    .weight(w_mux_q),
    .sum(),
  );
end // for
endgenerate

np_matrix_mult_ctrl mm_ctrl_inst(
  .clock(clock),
  .reset(reset),
  .start(fm_buffer_full),
  .addr(fm_rd_addr),
  .ram_select(fm_buffer_select),
  .product_rdy()
);
*/
// hex decode


endmodule
