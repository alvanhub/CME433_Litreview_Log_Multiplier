module mult16bvia8bit (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);
  logic signed [ 7:0] inA[0:3];
  logic signed [ 7:0] inB[0:3];
  logic signed [15:0] ouP[0:3];

  ///////////////////////////// Instantiate your multiplier here ///////////////////////////////////////
  // Using Dynamic Range Approximate Logarithmic Multiplier (DR-ALM)
  // Reference: Yin et al., "Design and Analysis of Energy-Efficient Dynamic Range
  // Approximate Logarithmic Multipliers for Machine Learning", IEEE TSUSC 2021

  // Optimal configuration: 1 DR-ALM for ouP[0], exact for others (69% accuracy)
  // Using all 4 DR-ALMs causes error accumulation (35% accuracy)

  dr_alm_8bit_signed #(.TRUNC_WIDTH(5)) dr_alm_0 (
      .i_a(inA[0]),
      .i_b(inB[0]),
      .o_z(ouP[0])
  );

  exact_mult exact_1 (
      .i_a(inA[1]),
      .i_b(inB[1]),
      .o_z(ouP[1])
  );

  exact_mult exact_2 (
      .i_a(inA[2]),
      .i_b(inB[2]),
      .o_z(ouP[2])
  );

  exact_mult exact_3 (
      .i_a(inA[3]),
      .i_b(inB[3]),
      .o_z(ouP[3])
  );
  /////////////////////////////////////////////////////////////////////////////////////////////////////

  assign inA[0] = {1'b0, i_a[6:0]};
  assign inB[0] = {1'b0, i_b[6:0]};

  assign inA[1] = {1'b0, i_a[6:0]};
  assign inB[1] = i_b[14:7];

  assign inA[2] = i_a[14:7];
  assign inB[2] = {1'b0, i_b[6:0]};

  assign inA[3] = i_a[14:7];
  assign inB[3] = i_b[14:7];

  always_comb begin
    o_z = ouP[0] + (ouP[1] + ouP[2]) * 2 ** 7 + ouP[3] * 2 ** 14;
  end

endmodule : mult16bvia8bit
