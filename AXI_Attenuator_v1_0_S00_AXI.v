
`timescale 1 ns / 1 ps

	module AXI_Attenuator_S00_AXI# (
	
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		parameter integer C_S_AXI_ADDR_WIDTH	= 32
	)
	(
		// Users to add ports here
		input 	wire 								CLK_ATT,
		input	wire								CLK_T,
		output 	wire 								LE,
		output 	wire 								SI,
		output 	wire 								CLK,
		// Global Clock Signal
		input 	wire  								S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input 	wire  S_AXI_ARESETN,
		input 	wire [C_S_AXI_ADDR_WIDTH-1 : 0] 	S_AXI_AWADDR,
		input 	wire [2 : 0] 						S_AXI_AWPROT,
		input 	wire  								S_AXI_AWVALID,
		output 	wire 								S_AXI_AWREADY,
		input 	wire [C_S_AXI_DATA_WIDTH-1 : 0] 	S_AXI_WDATA, 
		input 	wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		input 	wire  								S_AXI_WVALID,
		output 	wire 								S_AXI_WREADY,
		output 	wire [1 : 0] 						S_AXI_BRESP,
		output 	wire 								S_AXI_BVALID,
		input 	wire 								S_AXI_BREADY,
		input 	wire [C_S_AXI_ADDR_WIDTH-1 : 0] 	S_AXI_ARADDR,
		input 	wire [2 : 0] 						S_AXI_ARPROT,
		input 	wire  								S_AXI_ARVALID,
		output 	wire 								S_AXI_ARREADY,
		output 	wire [C_S_AXI_DATA_WIDTH-1 : 0] 	S_AXI_RDATA,
		output 	wire [1 : 0] 						S_AXI_RRESP,
		output 	wire 								S_AXI_RVALID,
		input 	wire  								S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  							axi_awready;
	reg  							axi_wready;
	reg [1 : 0] 					axi_bresp;
	reg  							axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  							axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 					axi_rresp;
	reg  							axi_rvalid;

	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;

	//-- Number of Slave Registers 4
	reg [C_S_AXI_DATA_WIDTH-1:0]	dataw;
	reg [C_S_AXI_DATA_WIDTH-1:0]	status;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;
	//
	wire [15:0] 	data_slv_reg_0;
	wire [15:0] 	data_si;
	reg	[15:0] 		data_slv_reg_latch;
	reg [15:0] 		data_i;
	//
	wire reset_att;
	wire reset_t;
	reg bvalid_i;
	//
	wire 	att_free_i;
	reg 	att_busy;
	wire 	att_busy_t_i, att_busy_cdc_i;
	reg 	att_count_valid, att_count_valid_z;
	wire	att_write_done_i;
	wire	pulse_start_count;
	//
	reg [3:0] counter;
	reg bvalid_z;
	wire le_i;
	reg [8:0] counter_t;
	
	// I/O Connections assignments
	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       
	

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      dataw <= 0;
//	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          2'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                dataw[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
//	          2'h1:
//	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
//	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
//	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
//	              end  
	          2'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          default : begin
	                      dataw <= dataw;
//	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                    end
	        endcase
	      end
	  end
	end    

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        2'h0   : reg_data_out <= dataw;
	        2'h1   : reg_data_out <= status;
	        2'h2   : reg_data_out <= slv_reg2;
	        2'h3   : reg_data_out <= slv_reg3;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	// защелкиваем данные и выставл€ем сигнал зан€тости только при удачной транзакции 
	always @ ( posedge S_AXI_ACLK )
	begin
		if (~S_AXI_ARESETN) begin
			data_slv_reg_latch <= 16'h0;
			att_busy <= 1'b0;
		end else if (axi_bvalid) begin
			data_slv_reg_latch <= dataw[15:0];
			att_busy <= 1'b1;	// дл€ slv_reg1
		end	else if (att_free_i)
			att_busy <= 1'b0;
	end		
	
	// регистр дл€ чтени€ (признак зан€тости аттенюатора)
	always @ ( posedge S_AXI_ACLK )
	begin
		if ( S_AXI_ARESETN == 1'b0 )
			status <= 0;
		else 
			status[0] <= 	att_busy;
	end		
	
	assign data_slv_reg_0 = data_slv_reg_latch;

	// CDC DATA
   xpm_cdc_array_single #(
      .DEST_SYNC_FF(2),
      .INIT_SYNC_FF(0),  
      .SIM_ASSERT_CHK(0),
      .SRC_INPUT_REG(1),
      .WIDTH(16))
   xpm_cdc_array_single_inst (
      .dest_out	(data_si),
      .dest_clk	(CLK_ATT), 		
      .src_clk	(S_AXI_ACLK),   
      .src_in	(data_slv_reg_0));

	// CDC RESET
	xpm_cdc_sync_rst #(
      .DEST_SYNC_FF(2),  
      .INIT(1),         
      .INIT_SYNC_FF(0),  
      .SIM_ASSERT_CHK(0))
   xpm_cdc_sync_rst_inst (
      .dest_rst	(reset_att), 
      .dest_clk	(CLK_ATT), 	
      .src_rst	(~S_AXI_ARESETN));
   
   // CDC BUSY ATTENUATOR  
  assign  att_busy_t_i = att_busy;
  
   xpm_cdc_single #(
      .DEST_SYNC_FF	(2),
      .INIT_SYNC_FF	(0),  
      .SIM_ASSERT_CHK(0), 
      .SRC_INPUT_REG(1))
   xpm_cdc_single_inst (
      .dest_out	(att_busy_cdc_i), 
      .dest_clk	(CLK_T),
      .src_clk	(S_AXI_ACLK),  
      .src_in	(att_busy_t_i));  

	// формирование сигнала валидности дл€ счетчика
	always @( posedge CLK_ATT ) 
	begin
		if (reset_att) begin
			data_i <= 16'h0;
			bvalid_i <= 1'b0;
		end else if (data_si != data_i) begin
			bvalid_i <= 1'b1;
			data_i <= data_si;
		end else if (counter == 4'd15)
			bvalid_i <= 1'b0;
	end
	
	// счетчик дл€ кол-ва переданных бит в аттенюатор	
	always @ ( posedge CLK_ATT )
	begin
		if (reset_att)
			counter <= 4'b0;
		else if (bvalid_i)
			counter <= counter + 1;
		else if (counter == 4'd15)
			counter <= 4'b0;
	end				
		
	// формирование стороба LE
	always @ ( posedge CLK_ATT )
	begin
		if (reset_att)
			bvalid_z <= 1'b0;
		else
			bvalid_z <= bvalid_i;	
	end
	
	assign le_i = bvalid_z & ~bvalid_i;
	
	
	// перенос ресета на CLK_T (частота дл€ выставлени€ задержки)
	xpm_cdc_sync_rst #(
      .DEST_SYNC_FF(2),  
      .INIT(1),         
      .INIT_SYNC_FF(0),  
      .SIM_ASSERT_CHK(0))
   xpm_cdc_sync_rst_inst_t (
      .dest_rst(reset_t), 
      .dest_clk(CLK_T), 	
      .src_rst(~S_AXI_ARESETN));
      
   // перенос сигнала Latch_enable аттенюатора дл€ старта задержки   
   xpm_cdc_pulse #(
      .DEST_SYNC_FF(2), 
      .INIT_SYNC_FF(0), 
      .REG_OUTPUT(0),     
      .RST_USED(1),      
      .SIM_ASSERT_CHK(0))
   xpm_cdc_pulse_le (
      .dest_pulse(pulse_start_count),
      .dest_clk(CLK_T),    
      .dest_rst(reset_t),  
      .src_clk(CLK_ATT),     
      .src_pulse(le_i),
      .src_rst(reset_att)); 	
      
    always @ ( posedge CLK_T )
    begin
    	if (reset_t)
    		att_count_valid_z <= 1'b0;
    	else
    		att_count_valid_z <= att_count_valid;
    end
    
    // признак завершени€ передачи и необходимого таймаута (25к√ц/40us)			
    assign  att_write_done_i = (att_busy_cdc_i) ? att_count_valid_z & ~att_count_valid : 9'd0;
    
    // формирование валида дл€ счетчика
    always @ ( posedge CLK_T )
    begin
    	if (reset_t)
    		att_count_valid <= 1'b0;
    	else if (pulse_start_count)
    		att_count_valid <= 1'b1;
    	else if (counter_t == 9'd390)
    		att_count_valid <= 1'b0;
    end				
    
   // счетчик задержки между операци€ми 40us
	always @ ( posedge CLK_T )    
	begin
		if (reset_t)
			counter_t <= 9'b0;
		else if (att_count_valid)	
			counter_t <= counter_t + 1;
		else
			counter_t <= 9'b0;		
	end
	
   // перенос сигнала завершени€ тайматуа на частоту AXI		
   xpm_cdc_pulse #(
      .DEST_SYNC_FF(2), 
      .INIT_SYNC_FF(0), 
      .REG_OUTPUT(0),     
      .RST_USED(1),      
      .SIM_ASSERT_CHK(0))
   xpm_cdc_pulse_inst (
      .dest_pulse(att_free_i),
      .dest_clk(S_AXI_ACLK),    
      .dest_rst(~S_AXI_ARESETN),  
      .src_clk(CLK_T),     
      .src_pulse(att_write_done_i),
      .src_rst(reset_t));  
		
	assign SI = (bvalid_i == 1'b1) ? data_i[counter] : 1'b0;
	assign CLK = (bvalid_i == 1'b1) ? ~CLK_ATT : 1'b0;
	assign LE = le_i;
	
	endmodule
