module improved_dr_alm_16_7trunc (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);
    // Instantiate improved_dr_alm_16 with M_WIDTH = 7
    improved_dr_alm_16_approx_lod #(
        .M_WIDTH(7)
    ) mult_inst (
        .i_a(i_a),
        .i_b(i_b),
        .o_z(o_z)
    );
endmodule