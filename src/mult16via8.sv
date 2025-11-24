// Multiplier Design Selection:
// Change the instantiation below to test different designs:
// - dr_alm_16bit_signed: Native 16-bit DR-ALM (paper: MRED 3.03%)
// - 4x 8-bit approach using dr_alm_8bit_signed

module mult16bvia8bit (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);
  logic signed [ 7:0] inA[0:3];
  logic signed [ 7:0] inB[0:3];
  logic signed [15:0] ouP[0:3];

  ///////////////////////////// 4x 8-bit DR-ALM approach ///////////////////////////////////////
  // CURRENT DESIGN: 4x 8-bit DR-ALM-6
  // Uses four 8-bit multipliers to compute 16-bit multiplication

//   genvar i;
//   generate
//     for (i = 0; i < 4; i = i + 1) begin : mult_gen
//       dr_alm_8bit_signed #(.TRUNC_WIDTH(6)) mult_inst (
//           .i_a(inA[i]),
//           .i_b(inB[i]),
//           .o_z(ouP[i])
//       );
//     end
//   endgenerate
//   /////////////////////////////////////////////////////////////////////////////////////////////////////

//   assign inA[0] = {1'b0, i_a[6:0]};
//   assign inB[0] = {1'b0, i_b[6:0]};

//   assign inA[1] = {1'b0, i_a[6:0]};
//   assign inB[1] = i_b[14:7];

//   assign inA[2] = i_a[14:7];
//   assign inB[2] = {1'b0, i_b[6:0]};

//   assign inA[3] = i_a[14:7];
//   assign inB[3] = i_b[14:7];

//   always_comb begin
//     o_z = ouP[0] + (ouP[1] + ouP[2]) * 2 ** 7 + ouP[3] * 2 ** 14;
//   end

    dr_alm_core #(.DWIDTH(16), .TRUNC_WIDTH(7)) u_dr_alm (
    // dr_alm_16bit_signed #(.TRUNC_WIDTH(6)) u_dr_alm (
        .i_a(i_a),
        .i_b(i_b),
        .o_z(o_z)
    );

endmodule : mult16bvia8bit

