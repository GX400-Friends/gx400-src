/*

FPGA compatible core of arcade hardware by LMN-san, OScherler, Raki.

This core is available for hardware compatible with MiSTer.
Other FPGA systems may be supported by the time you read this.
This work is not mantained by the MiSTer project. Please contact the
core authors for issues and updates.

(c) LMN-san, OScherler, Raki 2020–2023.

Support the authors:

       Raki: https://www.patreon.com/ikamusume
    LMN-san: https://ko-fi.com/lmnsan
  OScherler: https://ko-fi.com/oscherler

The authors do not endorse or participate in illegal distribution
of copyrighted material. This work can be used with legally
obtained ROM dumps of games or with homebrew software for
the arcade platform.

This file license is GNU GPLv3.
You can read the whole license file at http://www.gnu.org/licenses/

*/

//================================================================================
//  KONAMI 005291 TILEMAP GENERATOR
//================================================================================

/*
    March 17, 2021. Raki @ bubsys85.net

    This chip had been used exclusively by Konami GX400 hardware.
    Starting with famous Bubble System, Konami had provided a variety of games 
    for four years with this hardware.

    GX400 has two 512*256 tilemaps filled with 8*8 tiles. Each tile has 11 bits
    of CHAR RAM pointer, 4 bits of color including transparency, 
    4 bits of priority, 1 bit HFLIP, 1 bit VFLIP, and 7 bits of palette code.
    Two tilemaps, FG and BG can be raster scrolled separately. They can be
    scrolled line by line in horizontally, tile by tile(8 lines) vertically.
    This chip has 3 6246 64kb SRAM. VRAM 1 is 4k*16bit(half of 6246 pair), 
    VRAM 2 is 4k*8bit(half of 6246). 

    EPM7128 can hold this model. Consumes about 105 macrocells.
*/

`default_nettype none

module K005291
(
    input   wire            i_MCLK,

    //flips
    input   wire            i_HFLIP,
    input   wire            i_VFLIP, 
    input   wire            i_VCLK,

    //pixel counter
    input   wire    [6:0]   i_HCNTR_BUS, //see below
    input   wire    [7:0]   i_VCNTR_BUS, //see below
    input   wire            i_256H_n,
    input   wire            i_128HA,

    //CPU address bus
    input   wire    [11:0]  i_CPU_ADDR_BUS,

    //scroll data bus
    input   wire    [7:0]   i_SCROLL_DATA_BUS,

    //tile graphic data "line" address bus
    output  wire    [2:0]   o_TILE_LINE_ADDR_BUS,

    //tile palette/properties/pointer RAM address bus
    output  reg     [11:0]  o_VRAM_ADDR_BUS,

    //???
    output  wire            o_SHIFT_A1,
    output  wire            o_SHIFT_A2,
    output  wire            o_SHIFT_B
);

/*
    RENAMED SIGNALS:
        VA1, VA2, VA4 -> TILE_LINE ADDR_BUS
        no name -> o_VRAM_ADDR_BUS
        no name -> i_SCROLL_DATA_BUS


    OMITTED SIGNALS:
        CLR : clear? not used
        TES : test pin? not used
*/

/*
    <HCNTR BUS> ~256H, 128HA, 1HF are generated by ControlTimingGenerator.v
        MSB 
    BIT12   11   10    9    8    7    6    5    4    3    2    1    0
      ~256H 128HA 1HF  ~1H  256H 128H 64H  32H  16H  8H   4H   2H   1H


    <VCNTR BUS>
        MSB 
    BIT                     8    7    6    5    4    3    2    1    0
                            256V 128V 64V  32V  16V  8V   4V   2V   1V


    <TILE LINE ADDR BUS>
        MSB
    BIT                                                   2    1    0
                                                          4VA  2VA  1VA
*/




/*
    HSCROLL TIMING GENERATOR(LS138 on bootleg)
*/

reg     [3:0]   hcounter_decoder = 4'b0000;
wire    [3:0]   hpixel_number; //hpixel7, 5, 3, 1
assign hpixel_number = ~(hcounter_decoder & {4{i_VCLK}});

always @(*) 
begin
    case(i_HCNTR_BUS[2:0])
        3'd0: hcounter_decoder = 4'b0000;
        3'd1: hcounter_decoder = 4'b0001;
        3'd2: hcounter_decoder = 4'b0000;
        3'd3: hcounter_decoder = 4'b0010;
        3'd4: hcounter_decoder = 4'b0000;
        3'd5: hcounter_decoder = 4'b0100;
        3'd6: hcounter_decoder = 4'b0000;
        3'd7: hcounter_decoder = 4'b1000;
    endcase
end



/*
    HSCROLL VALUE LATCHES
*/

wire    [8:0]   hscroll_value_latch_0;
wire    [8:0]   hscroll_value_latch_1;

bus_ff #( .W( 8 ) ) hscroll_0_lo_latch(
	.rst     ( 1'b0                       ),
	.clk     ( i_MCLK                     ),
	.trig    ( hpixel_number[0]           ),
	.d       ( i_SCROLL_DATA_BUS          ),
	.q       ( hscroll_value_latch_0[7:0] ),
	.q_n     (                            )
);

bus_ff #( .W( 1 ) ) hscroll_0_hi_latch(
	.rst     ( 1'b0                       ),
	.clk     ( i_MCLK                     ),
	.trig    ( hpixel_number[1]           ),
	.d       ( i_SCROLL_DATA_BUS[0]       ),
	.q       ( hscroll_value_latch_0[8]   ),
	.q_n     (                            )
);

bus_ff #( .W( 8 ) ) hscroll_1_lo_latch(
	.rst     ( 1'b0                       ),
	.clk     ( i_MCLK                     ),
	.trig    ( hpixel_number[2]           ),
	.d       ( i_SCROLL_DATA_BUS          ),
	.q       ( hscroll_value_latch_1[7:0] ),
	.q_n     (                            )
);

bus_ff #( .W( 1 ) ) hscroll_1_hi_latch(
	.rst     ( 1'b0                       ),
	.clk     ( i_MCLK                     ),
	.trig    ( hpixel_number[3]           ),
	.d       ( i_SCROLL_DATA_BUS[0]       ),
	.q       ( hscroll_value_latch_1[8]   ),
	.q_n     (                            )
);

/*
    SHIFT SIGNAL(?) GENERATOR
*/

reg     [3:0]   hscroll_shift_a_adder;
reg     [3:0]   hscroll_shift_b_adder;

always @( posedge i_MCLK ) begin
    hscroll_shift_a_adder <= hscroll_value_latch_0[2:0] + ( i_HCNTR_BUS[2:0] ^ {3{i_HFLIP}} );
    hscroll_shift_b_adder <= hscroll_value_latch_1[2:0] + ( i_HCNTR_BUS[2:0] ^ {3{i_HFLIP}} );
end

assign o_SHIFT_A1 = ~(  hscroll_shift_a_adder[2] & hscroll_shift_a_adder[1] & hscroll_shift_a_adder[0] );
assign o_SHIFT_A2 = ~( ~hscroll_shift_a_adder[2] & hscroll_shift_a_adder[1] & hscroll_shift_a_adder[0] );
assign o_SHIFT_B  = ~( ~hscroll_shift_b_adder[2] & hscroll_shift_b_adder[1] & hscroll_shift_b_adder[0] );



/*
    TILEMAP HORIZONTAL ADDRESS GENERATOR
*/

reg     [5:0]   latched_scroll_value = 5'd0;
reg     [6:0]   tile_h_address_adder;

always @( posedge i_MCLK ) begin
    tile_h_address_adder <= latched_scroll_value + ({i_256H_n, i_128HA, i_HCNTR_BUS[6:3]} ^ {6{i_HFLIP}});
end

always @(*) 
begin
    case(i_HCNTR_BUS[2])
        1'b0: latched_scroll_value = hscroll_value_latch_0[8:3];
        1'b1: latched_scroll_value = hscroll_value_latch_1[8:3];
    endcase
end



/*
    VSCROLL VALUE LATCHES
*/

wire            vscroll_latch_tick;
wire    [7:0]   vcntr_flip_bus_internal;
wire    [7:0]   vscroll_byte_value_latch;
wire    [2:0]   vscroll_3bit_value_latch;
wire    [2:0]   vscroll_vcntr_latch;

assign vcntr_flip_bus_internal = i_VCNTR_BUS[7:0] ^ {8{i_VFLIP}}; //new VCNTR_FLIP_BUS
assign vscroll_latch_tick      = ~&{ i_HCNTR_BUS[1], i_HCNTR_BUS[0] };

// U23
bus_ff #( .W( 8 ) ) vscroll_latch(
	.rst     ( 1'b0                     ),
	.clk     ( i_MCLK                   ),
	.trig    ( vscroll_latch_tick       ),
	.d       ( i_SCROLL_DATA_BUS        ),
	.q       ( vscroll_byte_value_latch ),
	.q_n     (                          )
);

// U20
bus_ff #( .W( 3 ) ) vscroll_adder_latch(
	.rst     ( 1'b0                          ),
	.clk     ( i_MCLK                        ),
	.trig    ( ~i_HCNTR_BUS[1]               ),
	.d       ( vscroll_byte_value_latch[2:0] ),
	.q       ( vscroll_3bit_value_latch      ),
	.q_n     (                               )
);

// U19
bus_ff #( .W( 3 ) ) vscroll_cntr_latch(
	.rst     ( 1'b0                         ),
	.clk     ( i_MCLK                       ),
	.trig    ( i_HCNTR_BUS[1]               ),
	.d       ( vcntr_flip_bus_internal[2:0] ),
	.q       ( vscroll_vcntr_latch          ),
	.q_n     (                              )
);



/*
    TILE LINE ADDRESS GENERATOR 
*/

//This makes charram address[2:0], a 8*8 tile horizontal line address from line 0 to 7

reg     [3:0]   tile_line_address_adder;

always @( posedge i_MCLK ) begin
    tile_line_address_adder <= vscroll_3bit_value_latch + vscroll_vcntr_latch;
end

assign o_TILE_LINE_ADDR_BUS = tile_line_address_adder[2:0];



/*
    TILEMAP VERTICAL ADDRESS GENERATOR
*/

reg     [8:0]   tile_v_address_adder;

always @( posedge i_MCLK ) begin
    tile_v_address_adder <= vscroll_byte_value_latch + vcntr_flip_bus_internal;
end



/*
    OUTPUT MUX
*/

// working on posedge i_MCLK gives just enough delay that the K5293 latches the correct tilemap later
always @( posedge i_MCLK ) begin

`ifdef K5291_NO_MUX
    o_VRAM_ADDR_BUS <= {i_HCNTR_BUS[2], tile_v_address_adder[7:3], tile_h_address_adder[5:0]};
`else
    case(i_HCNTR_BUS[1])
        1'b0: o_VRAM_ADDR_BUS <= i_CPU_ADDR_BUS;
        1'b1: o_VRAM_ADDR_BUS <= {i_HCNTR_BUS[2], tile_v_address_adder[7:3], tile_h_address_adder[5:0]};
    endcase
`endif

end

endmodule
