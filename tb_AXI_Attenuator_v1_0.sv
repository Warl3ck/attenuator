`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.11.2021 11:50:41
// Design Name: 
// Module Name: tb_AXI4_SDRAM_v1_0
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
import axi_vip_pkg::*;
import axi_vip_mst_pkg::*;


module tb_AXI_Attenuator();

    localparam PERIOD_CLK = 10ns;
    localparam PERIOD_CLK_ATEN = 100ns;
    localparam PERIOD_CLK_10MHz = 100ns;


    bit aclk_0, aresetn_0, clk_aten, clk_10MHz; 
    bit [31:0]	addr1 = 32'h00000000; 
    bit [31:0]	addr2 = 32'h00000004;
    bit [31:0]  data_wr1 = 32'h00000378;
    bit [31:0]  data_rd1, state_att;
	event burst_mode_done, byte_mode_done;
	
    // AXI-Lite
	wire   [31:0]  m_axi_awaddr; 
	wire   [2:0]   m_axi_awprot, m_axi_arprot; 
	wire   m_axi_awvalid, m_axi_awready, m_axi_arvalid, m_axi_arready, m_axi_bvalid, m_axi_bready;
	wire   [31:0]  m_axi_wdata;
	wire   [3:0]   m_axi_wstrb;
	wire   m_axi_wvalid, m_axi_wready;
	wire   [1:0]   m_axi_bresp, m_axi_rresp;
	wire   [31:0]  m_axi_araddr;
	wire   [31:0]  m_axi_rdata;  
	wire   m_axi_rvalid, m_axi_rready;
	// Attenuator signals
	wire clk_i, si_i;
	bit le_i;
	reg [15:0] si_reg_att;
	reg [15:0] si_reg_0;
	
	// Clock_FPGA
	always #(PERIOD_CLK/2) aclk_0 <= ~aclk_0;
	// Clock for Attenuator
	always #(PERIOD_CLK_ATEN/2) clk_aten <= ~clk_aten;
	// Clock for DELAY_40us (25 kHz)
	always #(PERIOD_CLK_10MHz/2) clk_10MHz <= ~clk_10MHz;
	
	// reset process
	initial begin
		aresetn_0 = 1'b0;
		#(PERIOD_CLK*20)
		@(posedge aclk_0)
		aresetn_0 = 1'b1;
	end


axi_vip_mst_mst_t	 axi_mst_agent;

task automatic axi4_word_read ( 
                                    input string                     name ="single_read",
                                    input xil_axi_uint               id =0, 
                                    input xil_axi_ulong              addr =0,
                                    // input xil_axi_len_t              len =0, 
                                    input xil_axi_size_t             size =xil_axi_size_t'(xil_clog2((32)/8)),
                                    input xil_axi_burst_t            burst =XIL_AXI_BURST_TYPE_INCR,
                                    input xil_axi_lock_t             lock =XIL_AXI_ALOCK_NOLOCK ,
                                    input xil_axi_cache_t            cache =3,
                                    input xil_axi_prot_t             prot =0,
                                    input xil_axi_region_t           region =0,
                                    input xil_axi_qos_t              qos =0,
                                    input xil_axi_data_beat          aruser =0,
                                    input bit                        quiet = 1,
									output bit [31:0]				 data_out
                                                );
// Variables
	axi_transaction                             rd_trans;
	xil_axi_data_beat                       	mtestDataBeat[];
	bit [31:0]									beat_32;
	bit [31:0]									ta_len;
// Commands
    rd_trans = axi_mst_agent.rd_driver.create_transaction(name);
    rd_trans.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
    rd_trans.set_read_cmd(addr,burst,id,0,size);
    rd_trans.set_prot(prot);
    rd_trans.set_lock(lock);
    rd_trans.set_cache(cache);
    rd_trans.set_region(region);
    rd_trans.set_qos(qos);
    axi_mst_agent.rd_driver.send(rd_trans);  
    axi_mst_agent.rd_driver.wait_rsp(rd_trans);
    mtestDataBeat = new[rd_trans.get_len()+1];
    mtestDataBeat[0] = rd_trans.get_data_beat(0);
    data_out = mtestDataBeat[0][31:0];
    if (~quiet) $display("RD ADDR 0x%8h - 0x%8h", addr, mtestDataBeat[0][31:0]);
  endtask  : axi4_word_read
  
  task automatic axi4_word_write ( 
                                input string                     name ="single_write",
                                input xil_axi_uint               id =0, 
                                input xil_axi_ulong              addr =0,
                                input xil_axi_len_t              len =0, 
                                input xil_axi_size_t             size =xil_axi_size_t'(xil_clog2((32)/8)),
                                input xil_axi_burst_t            burst =XIL_AXI_BURST_TYPE_INCR,
                                input xil_axi_lock_t             lock = XIL_AXI_ALOCK_NOLOCK,
                                input xil_axi_cache_t            cache =3,
                                input xil_axi_prot_t             prot =0,
                                input xil_axi_region_t           region =0,
                                input xil_axi_qos_t              qos =0,
                                input xil_axi_data_beat [255:0]  wuser =0, 
                                input xil_axi_data_beat          awuser =0,
                                input bit [32-1:0]    data =0, 
								input xil_axi_uint				 beat_delay = 0,
								input xil_axi_strb_beat			 wstrb = {128{1'b1}}
                                                );
    axi_transaction                               wr_trans;
    wr_trans = axi_mst_agent.wr_driver.create_transaction(name);
    wr_trans.set_write_cmd(addr,burst,id,len,size);
    wr_trans.set_prot(prot);
    wr_trans.set_lock(lock);
    wr_trans.set_cache(cache);
    wr_trans.set_region(region);
    wr_trans.set_qos(qos);
    wr_trans.set_data_beat(0, data, 0, wstrb);
	  wr_trans.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
    axi_mst_agent.wr_driver.send(wr_trans);   
	 axi_mst_agent.wr_driver.wait_rsp(wr_trans);
	$display("WR ADDR 0x%8h - 0x%8h", addr, data);
  endtask  : axi4_word_write


	task cycle_read ();
		forever begin
			#(PERIOD_CLK*20)
			axi4_word_read(.addr(addr2), .data_out(state_att));
			#PERIOD_CLK
			if ( ~state_att[0] )
				break;	
			end	
	endtask : cycle_read

	initial begin
    	axi_mst_agent = new("master vip agent", tb_AXI_Attenuator_v1_0.axi_vip_mst_inst.inst.IF);
    	axi_mst_agent.set_agent_tag("Master VIP");
    	axi_mst_agent.set_verbosity(0);
    	axi_mst_agent.start_master();
    	#1us
    	@(posedge aclk_0)
    		axi4_word_write(.addr(addr1), .data(data_wr1));
			#PERIOD_CLK
			axi4_word_read(.addr(addr1), .data_out(data_rd1));
			#(PERIOD_CLK*10)
			cycle_read;
			axi4_word_write(.addr(addr1), .data(32'h0000F85A), .wstrb(4'b0101));
			#(PERIOD_CLK*10)
			axi4_word_read(.addr(addr1), .data_out(data_rd1));
			#(PERIOD_CLK*10)
			cycle_read;	
		->	byte_mode_done;
 	end 
 
	// Compare results 
	initial begin 
 		@ (le_i) ;
 		#1
     	$display("line_in: %h", data_wr1);
    	$display("line_out: %h", data_rd1);
    	$display("line_att: %h", si_reg_0);
    	if 	(data_wr1 == data_rd1 & data_rd1 == si_reg_0) 
    		$display("BURST_MODE & DATA_MERGE complete");
    	else begin  $display("Test don't pass"); 
        	$finish; 
    	end        
	end

 	// BYTE_MODE
 	initial begin
 		@(byte_mode_done);
 		#1
        	$display("line_in: %h", data_wr1);
    		$display("line_out: %h", data_rd1);
   	 	$finish;	
 	end

	always @ ( posedge clk_i)
	begin
		if (~aresetn_0)
			si_reg_att <= 16'h0;
		else
			si_reg_att <= {si_i, si_reg_att[15:1]};	
	end

	always @ ( le_i )
	begin
		if ( le_i )
			si_reg_0 = si_reg_att;
	end
	
    AXI_Attenuator  AXI_Attenuator_inst(
    .CLK_ATT				(clk_aten),
    .CLK_T					(clk_10MHz),
    .LE						(le_i),	
	.SI						(si_i),
	.CLK					(clk_i),
	// Ports of Axi Slave Bus Interface S00_AXI
	.s00_axi_aclk           (aclk_0),
	.s00_axi_aresetn        (aresetn_0),
	.s00_axi_awaddr         (m_axi_awaddr),
	.s00_axi_awprot         (m_axi_awprot),
	.s00_axi_awvalid        (m_axi_awvalid),
	.s00_axi_awready        (m_axi_awready),
	.s00_axi_wdata          (m_axi_wdata),
	.s00_axi_wstrb          (m_axi_wstrb),
	.s00_axi_wvalid         (m_axi_wvalid),
	.s00_axi_wready         (m_axi_wready),
	.s00_axi_bresp          (m_axi_bresp),
	.s00_axi_bvalid         (m_axi_bvalid),
	.s00_axi_bready         (m_axi_bready),
	.s00_axi_araddr         (m_axi_araddr),
	.s00_axi_arprot         (m_axi_arprot),
	.s00_axi_arvalid        (m_axi_arvalid),
	.s00_axi_arready        (m_axi_arready),
	.s00_axi_rdata          (m_axi_rdata),
	.s00_axi_rresp          (m_axi_rresp),
	.s00_axi_rvalid         (m_axi_rvalid),
	.s00_axi_rready         (m_axi_rready));


    axi_vip_mst axi_vip_mst_inst(
    .aclk                   (aclk_0),
    .aresetn                (aresetn_0),
    .m_axi_awaddr           (m_axi_awaddr),
    .m_axi_awprot           (m_axi_awprot),
    .m_axi_awvalid          (m_axi_awvalid),
    .m_axi_awready          (m_axi_awready),
    .m_axi_wdata            (m_axi_wdata),
    .m_axi_wstrb            (m_axi_wstrb),
    .m_axi_wvalid           (m_axi_wvalid),
    .m_axi_wready           (m_axi_wready),
    .m_axi_bresp            (m_axi_bresp),
    .m_axi_bvalid           (m_axi_bvalid),
    .m_axi_bready           (m_axi_bready),
    .m_axi_araddr           (m_axi_araddr),
    .m_axi_arprot           (m_axi_arprot),
    .m_axi_arvalid          (m_axi_arvalid),
    .m_axi_arready          (m_axi_arready),
    .m_axi_rdata            (m_axi_rdata),
    .m_axi_rresp            (m_axi_rresp),
    .m_axi_rvalid           (m_axi_rvalid),
    .m_axi_rready           (m_axi_rready));

endmodule