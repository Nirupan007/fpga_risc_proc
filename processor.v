module fetch (input clk,
				  input rst,
				  input bren,
				  input [8:0] br_adr,
				  output reg [8:0] pc
				  );

always @(posedge clk, negedge rst)
begin
	if(!rst) pc <= 0;
	else
	begin
		if(bren)	pc <= br_adr;
		else
		begin
			if(pc==511)	pc <= 511;
			else			pc <= pc+1;
		end
	end
end
								
endmodule

module instruction_rom (input clk,
				            input [8:0] irom_addr,
			               output reg [31:0] irom_data
			            	);

reg [31:0] irom [511:0];

initial
	$readmemh("input_irom.txt", irom, 0, 511);

always @(posedge clk)
	irom_data <= irom [irom_addr];	
			 				 
endmodule

module register (input wen,
					  input clk,
					  input [3:0] rd_adr1,
					  input [3:0] rd_adr2,
					  input [3:0] wr_adr,  
                 input [31:0] wr_data,
                 output [31:0] rd_data1,
                 output [31:0] rd_data2
					  );
					  
reg [31:0] regs [15:0];
					  
wire [31:0] w1;
wire [31:0] w2;

always @(posedge clk)
begin
	if  (wen)	regs [wr_adr] <= wr_data;
end

assign	w1 = regs [rd_adr1];
assign	w2 = regs [rd_adr2];
assign	rd_data1 = (wen && rd_adr1==wr_adr) ? wr_data : w1;
assign	rd_data2 = (wen && rd_adr2==wr_adr) ? wr_data : w2;

endmodule

module decoder (input [3:0] opcode,
   				 output reg alu_en,
					 output reg branch_en,
					 output reg mov_en,
					 output reg load_en,
					 output reg str_en,
					 output reg [2:0] ctrl
					 );
					 
parameter ld = 2'b11;
parameter st = 2'b00;
parameter mv = 2'b01;				

always @(*)
begin
	alu_en = 1'b0;     
	branch_en = 1'b0;
	mov_en = 1'b0; 
	load_en = 1'b0;
	str_en = 1'b0;
	ctrl [2:0] = 3'b000;

	if (opcode[3] == 0) 
	begin 								
		alu_en = 1'b1;
		ctrl [2:0] = opcode [2:0];		
	end	
	else     
	begin
		if(opcode[2:0] < 3)
		begin
			branch_en = 1;
			ctrl [1:0] = opcode [1:0];
		end
		else
		begin
			case (opcode[1:0])
				ld : load_en = 1;
				st : str_en = 1;
				mv : mov_en = 1;
			endcase
		end	
	end	
end		

endmodule

module alu (input [2:0] ctrl,
			   input alu_en,
			   input [31:0] ra,
			   input [31:0] rb, 
			   input [4:0] shift,  
			   output reg [31:0] out,
			   output reg carry
			   );
			  
parameter add = 3'b000;
parameter sub = 3'b001;		
parameter mul = 3'b010;
parameter AND = 3'b011;
parameter OR  = 3'b100;
parameter NOT = 3'b101;
parameter sll = 3'b110;
parameter sra = 3'b111;

always @(*) 
begin
	out = 0;
	if(alu_en)
	begin
		case (ctrl[2:0])
			add: {carry, out} = ra + rb;
			sub: {carry, out} = ra - rb;
			mul: out = ra [15:0] * rb [15:0];
			AND: out = ra & rb;
			OR:  out = ra | rb;
			NOT: out = ~ra;
			sll: out = ra << shift;  
			sra: begin 
					  out = ra >> shift;
					  out[31] = ra[31];
				  end
		endcase
	end
end
			
endmodule

module carry (input c,
				  output reg carry
				  );

always @ (c)
	carry = c;

endmodule				  
	
module select (input aluen,
					input men,
					input lden,
					input carry,
					input [31:0] alu,
					input [31:0] datamemory,
					output reg wen,
					output reg [31:0] writedata
					);

always @(*)
begin
	if(aluen | men | lden)
	begin
		wen = 1'b1;
		if(aluen)		writedata [31:0] = alu [31:0];
		else if(men)	writedata [31:0] = {31'b0, carry};
		else				writedata [31:0] = datamemory [31:0];
	end
	else	
	begin
		wen = 0;
		writedata [31:0] = 0;
	end
end

endmodule

module branch (input ben,
					input carry,
				   input [1:0] cntrl,
				   input [31:0] data,
				   output reg bren
				   );

parameter br = 2'b00;
parameter bz = 2'b01;
parameter bc = 2'b10;

always @(*)
begin
	if(ben)
	begin
		bren = 0;
		case (cntrl [1:0])
			br : bren = 1;
			bc : if(carry)		bren = 1;				 
			bz : if(data==0)	bren = 1;
		endcase
	end
	else	bren = 0;
end

endmodule

module data_mem (input clk,
					  input str_en,
					  input ld_en,
				     input [8:0] dmem_addr_1,
				     input [8:0] dmem_addr_2,
					  input [31:0] dmem_wr_data,
			        output [31:0] dmem_rd_data
				     );

reg [31:0] dmem [511:0];
reg [8:0] ld_addr;

initial
	$readmemh("input_dmem.txt", dmem, 0, 511);

always @(posedge clk)
begin
	if (str_en)
		dmem [dmem_addr_1] <= dmem_wr_data;
	if (ld_en)
		ld_addr <= dmem_addr_2;		 				 
end

assign dmem_rd_data = dmem [ld_addr];

endmodule

module dff (input clk,
				input rst,
				input [WIDTH-1:0] d,
				output reg [WIDTH-1:0] q
				);			
				
parameter WIDTH = 32;				
				
always @ (posedge clk, negedge rst)				
begin
	if (!rst)	q <= 0;
	else			q <= d;
end
				
endmodule

module ctrl_dff (input clk,
				     input rst,
				     input ae,
					  input be,
					  input me,
					  input le,
					  input se,
					  input [2:0] ctrl,
				     output reg [7:0] q
				     );							
				
always @ (posedge clk, negedge rst)				
begin
	if (!rst)	q <= 0;
	else
	begin
		q [7] <= ae;
		q [6] <= be;
		q [5] <= me;
		q [4] <= le;
		q [3] <= se;
		q [2:0] <= ctrl [2:0];  
		
	end
end
			
endmodule

module iiitb_toy_proc (input clk,
							  input rst,
							  output [8:0] dmem_addr,
							  output [31:0] dmem_data,
							  output done
							  );
							  
assign done = (pc_w==482) ? 1 : 0;							  
assign dmem_addr = ir_w [8:0];
assign dmem_data = dm_w;							  

defparam ff4.WIDTH = 9;
defparam ff5.WIDTH = 4;

wire [8:0] pc_w;
wire [31:0] ir_w;

wire [31:0] ra_w;
wire [31:0] rb_w;

wire ae_w;
wire br_w;
wire mv_w;
wire ld_w;
wire st_w;
wire [2:0] ctrl_w;

wire [31:0] f1_w;
wire [31:0] f2_w;
wire [7:0] f3_w;
wire [8:0] f4_w;
wire [3:0] f5_w;

wire [31:0] alu_w;
wire ac_w;

wire cy_w;

wire we_w;
wire [31:0] wd_w;

wire be_w;

wire [31:0] dm_w;

fetch f(clk,rst,be_w,f4_w [8:0],pc_w [8:0]);
instruction_rom ir(clk,pc_w [8:0],ir_w [31:0]);
register r(we_w,clk,ir_w [23:20],ir_w [19:16],f5_w [3:0],wd_w [31:0],ra_w [31:0],rb_w [31:0]);
decoder d(ir_w [31:28],ae_w,br_w,mv_w,ld_w,st_w,ctrl_w [2:0]);
dff ff1(clk,rst,ra_w [31:0],f1_w [31:0]);
dff ff2(clk,rst,rb_w [31:0],f2_w [31:0]);
ctrl_dff ff3(clk,rst,ae_w,br_w,mv_w,ld_w,st_w,ctrl_w [2:0],f3_w [7:0]);
dff ff4(clk,rst,ir_w [8:0],f4_w [8:0]);
dff ff5(clk,rst,ir_w [27:24],f5_w [3:0]);
alu a(f3_w [2:0],f3_w [7],f1_w [31:0],f2_w [31:0],f4_w [4:0],alu_w [31:0],ac_w);
carry c(ac_w,cy_w);
select s(f3_w [7],f3_w [5],f3_w [4],cy_w,alu_w [31:0],dm_w [31:0],we_w,wd_w [31:0]);
branch b(f3_w [6],cy_w,f3_w [1:0],f1_w [31:0],be_w);
data_mem dm(clk,f3_w [3],ld_w,f4_w [8:0],ir_w [8:0],f1_w [31:0],dm_w [31:0]);

endmodule
