module exact_mult (
    input  logic signed [ 7:0] i_a,
    input  logic signed [ 7:0] i_b,
    output logic signed [15:0] o_z
);
  always_comb begin
    o_z = i_a * i_b;
  end
endmodule : exact_mult
