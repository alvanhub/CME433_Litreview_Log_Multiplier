module mult16bvia8bit (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);
  logic signed [ 7:0] inA[0:3];
  logic signed [ 7:0] inB[0:3];
  logic signed [15:0] ouP[0:3];

  ///////////////////////////// Instantiate your multiplier here ///////////////////////////////////////
  exact_mult mult (
      .i_a(inA[0]),
      .i_b(inB[0]),
      .o_z(ouP[0])
  );
  /////////////////////////////////////////////////////////////////////////////////////////////////////

  genvar i;
  generate
    ;
    for (i = 1; i < 4; i = i + 1) begin : base
      exact_mult mult (
          .i_a(inA[i]),
          .i_b(inB[i]),
          .o_z(ouP[i])
      );
    end
  endgenerate

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
