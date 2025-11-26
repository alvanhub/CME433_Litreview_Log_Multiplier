#!/bin/bash

# Script to switch the multiplier configuration

MULT_TYPE=$1
SRC_FILE="mult16via8.sv"

if [ -z "$MULT_TYPE" ]; then
    echo "Usage: $0 {exact|base_log|dr_alm|improved}"
    exit 1
fi

case $MULT_TYPE in
    "exact")
        MULT_MODULE="exact_mult"
        ;;
    "base_log")
        MULT_MODULE="base_log_mult"
        ;;
    "dr_alm")
        MULT_MODULE="dr_alm #(.M_WIDTH(5))"        ;;
    "improved")
        MULT_MODULE="improved_dr_alm #(.M_WIDTH(5))"
        ;;
    *)
        # Assume the user provided a valid module name for a custom multiplier
        MULT_MODULE="$MULT_TYPE"
        echo "Unknown type '$MULT_TYPE', assuming module name is '$MULT_MODULE'"
        ;;
esac

# Create the file content
cat > $SRC_FILE << 'EOF'
module mult16bvia8bit (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);
  logic signed [ 7:0] inA[0:3];
  logic signed [ 7:0] inB[0:3];
  logic signed [15:0] ouP[0:3];

  ///////////////////////////// Instantiate your multiplier here ///////////////////////////////////////
  MULT_MODULE mult (
      .i_a(inA[0]),
      .i_b(inB[0]),
      .o_z(ouP[0])
  );
  /////////////////////////////////////////////////////////////////////////////////////////////////////

  genvar i;
  generate
    ;
    for (i = 1; i < 4; i = i + 1) begin : base
      MULT_MODULE mult (
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
EOF

# Replace MULT_MODULE with the actual module name
sed -i "s/MULT_MODULE/$MULT_MODULE/g" $SRC_FILE

echo "Switched to $MULT_TYPE multiplier ($MULT_MODULE)"
