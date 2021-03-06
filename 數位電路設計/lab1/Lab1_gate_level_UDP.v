`include"Lab1_UDP.v"

module Lab1_gate_level_UDP(F,A,B,C,D);
	input A,B,C,D;
	output F;
	wire wireBD;
	Lab1_UDP (wireABC,A,B,C);
	or(wireBD,B,~D);
	and(F,wireABC,wireBD);
endmodule