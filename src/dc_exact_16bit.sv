module dc_exact_16bit (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);
  always_comb begin
    o_z = i_a * i_b;
  end
endmodule : dc_exact_16bit