// Multiplier Design Selection:
// Change the instantiation below to test different designs:
// - dr_alm_16bit_signed: Native 16-bit DR-ALM (paper: MRED 3.03%)
// - 4x 8-bit approach using dr_alm_8bit_signed

module dr_alm_core_16bit7trunc (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

    // ================================ INSTANTIATE WHATEVER DESIGN YOU WANT HERE ================================
    // ============================================================================================================
    dr_alm_core #(.DWIDTH(16), .TRUNC_WIDTH(7)) u_dr_alm (
    // dr_alm_16bit_signed #(.TRUNC_WIDTH(6)) u_dr_alm (
        .i_a(i_a),
        .i_b(i_b),
        .o_z(o_z)
    );
    // ============================================================================================================

endmodule : dr_alm_core_16bit7trunc

