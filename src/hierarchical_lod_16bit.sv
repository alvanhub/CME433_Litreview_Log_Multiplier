// 16-bit Hierarchical Leading One Detector
// Implements the LOD from the diagram for a 16-bit input.
module hierarchical_lod_16bit (
    input  logic [15:0] a,
    output logic [3:0]  k
);

    logic [3:0] d [0:3];
    logic       or_out [0:3];

    // Stage 2 signals: One 4-bit LOD
    logic [3:0] lod_s2_in;
    logic [3:0] lod_s2_out;
    logic       or_s2_out; // Unused for this stage

    // Final one-hot output before encoding
    logic [15:0] one_hot_out;

    // Stage 1: Instantiate four 4-bit LODs
    generate
        genvar i;
        for (i = 0; i < 4; i=i+1) begin : stage1_lods
            lod4_bit lod (
                .a      (a[i*4 +: 4]),
                .d      (d[i]),
                .or_out (or_out[i])
            );
        end
    endgenerate

    // Stage 2: Instantiate one 4-bit LOD to process Stage 1 outputs
    assign lod_s2_in = {or_out[3], or_out[2], or_out[1], or_out[0]};

    lod4_bit lod_stage2 (
        .a      (lod_s2_in),
        .d      (lod_s2_out),
        .or_out (or_s2_out)
    );

    // Muxing to create the final 16-bit one-hot output vector
    // The output of the Stage 2 LOD selects the correct 4-bit chunk from Stage 1.
    assign one_hot_out[ 3: 0] = lod_s2_out[0] ? d[0] : 4'b0;
    assign one_hot_out[ 7: 4] = lod_s2_out[1] ? d[1] : 4'b0;
    assign one_hot_out[11: 8] = lod_s2_out[2] ? d[2] : 4'b0;
    assign one_hot_out[15:12] = lod_s2_out[3] ? d[3] : 4'b0;

    // One-hot to binary encoder for the final output 'k'
    always_comb begin
        casex (one_hot_out)
            16'b1xxx_xxxx_xxxx_xxxx: k = 4'd15;
            16'b01xx_xxxx_xxxx_xxxx: k = 4'd14;
            16'b001x_xxxx_xxxx_xxxx: k = 4'd13;
            16'b0001_xxxx_xxxx_xxxx: k = 4'd12;
            16'b0000_1xxx_xxxx_xxxx: k = 4'd11;
            16'b0000_01xx_xxxx_xxxx: k = 4'd10;
            16'b0000_001x_xxxx_xxxx: k = 4'd9;
            16'b0000_0001_xxxx_xxxx: k = 4'd8;
            16'b0000_0000_1xxx_xxxx: k = 4'd7;
            16'b0000_0000_01xx_xxxx: k = 4'd6;
            16'b0000_0000_001x_xxxx: k = 4'd5;
            16'b0000_0000_0001_xxxx: k = 4'd4;
            16'b0000_0000_0000_1xxx: k = 4'd3;
            16'b0000_0000_0000_01xx: k = 4'd2;
            16'b0000_0000_0000_001x: k = 4'd1;
            16'b0000_0000_0000_0001: k = 4'd0;
            default:                  k = 4'd0; // For input of 0
        endcase
    end

endmodule