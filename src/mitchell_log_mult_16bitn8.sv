module mitchell_log_mult_16bitn8 (
    input  logic [15:0] i_a,
    input  logic [15:0] i_b,
    output logic [31:0] o_z
);

// instansiate the core module
mitchell_log_mult_core #(.W(8), .N(16)) u_mitchell_log_mult_core (
    .i_a(i_a),
    .i_b(i_b),
    .o_z(o_z)
);


endmodule : mitchell_log_mult_16bitn8