module tb_control_module;

	logic 				MAIN_CLK_i;                      
	logic 				N_MAIN_RST_i;                    
	logic 				ANA_INTERFACE_IN_MODSELECT_o; 
	logic 				ADD_PD_OUT_OUTFLAG_i;            
	logic 				ADD_PD_STA_OUT_READY_i;          
	logic 				ANA_PD_EN_o;                     
	logic 				ANA_MOD_EN_o;                    
	logic 				ANA_FREQ_DIVIDER_EN_o;           
	logic [8:0] 	DATA_REG_MUX_SEL_DATA_o;        
	logic 				DATA_REG_MUX_EN_o;               
	logic 				ANA_MUX_EN_o;                     	
	logic [3:0] 	CFREG_DATA_BANK_REPEAT_i;        
	logic [3:0] 	CFREG_DATA_BANK_SELECT_i;        
	logic [35:0] 	CFREG_DATA_BANK_SEQUENCE_i;      
	logic 				CFREG_DATA_SEL_SINGLE_SEQUENCE_i;
	logic [4:0] 	CFREG_DELAY_DATA_BANK_REPEAT_i;  
	logic [7:0] 	CFREG_FORCE_STATE_FSM_i;         
	logic 				CFREG_PREAMB_i;                  
	logic 				CFREG_REPEAT_WITH_PREAMB_i;      	
	logic [2:0] 	PORT_STA_LED_o;									
	logic 				FLAG_POR_i;											
	
	
	CONTROL_MODULE dut (.*);
	
	initial MAIN_CLK_i = 0;
	always #10 MAIN_CLK_i = ~MAIN_CLK_i;
	
	initial
	begin
		N_MAIN_RST_i = 0;
		ADD_PD_OUT_OUTFLAG_i = 0;
		ADD_PD_STA_OUT_READY_i = 0;
		CFREG_DATA_BANK_REPEAT_i = 4'b0000;
		CFREG_DATA_BANK_SELECT_i = 4'b0000;
		CFREG_DATA_BANK_SEQUENCE_i = 36'b000000010010001101000101011110001111;
		CFREG_DATA_SEL_SINGLE_SEQUENCE_i = 0;
		CFREG_DELAY_DATA_BANK_REPEAT_i = 5'b00001;
		CFREG_FORCE_STATE_FSM_i = 8'b00000000;
		CFREG_PREAMB_i = 0;
		CFREG_REPEAT_WITH_PREAMB_i = 0;
		FLAG_POR_i = 0;
		
		repeat (10) @(posedge MAIN_CLK_i);
		
		N_MAIN_RST_i = 1;
		
		repeat (19) @(posedge MAIN_CLK_i);
		
		ADD_PD_OUT_OUTFLAG_i = 1;
		
		repeat (21) @(posedge MAIN_CLK_i);
		
		ADD_PD_OUT_OUTFLAG_i = 0;
		
		repeat (50) @(posedge MAIN_CLK_i);
	end

endmodule
		
		