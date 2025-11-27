// Modified: Uses actual bit extraction for the LSB of the truncated significand instead of '1'.

module dr_alm_round_and_est #(
    parameter integer WIDTH = 16,      // Data Width (8 or 16)
    parameter KEEP_WIDTH = 7
)(
    input  logic signed [WIDTH-1:0] i_a,
    input  logic signed [WIDTH-1:0] i_b,
    output logic signed [(2*WIDTH)-1:0] o_z
);

    logic sign_a, sign_b, sign_z;
    logic [WIDTH-1:0] abs_a, abs_b;
    
    // -------------------------------------------------------------------------
    // 1. Sign Handling (Section 3.2)
    // -------------------------------------------------------------------------
    assign sign_a = i_a[WIDTH-1];
    assign sign_b = i_b[WIDTH-1];
    assign sign_z = sign_a ^ sign_b;

    // Standard exact sign handling to isolate multiplier error.
    assign abs_a = sign_a ? -i_a : i_a;
    assign abs_b = sign_b ? -i_b : i_b;

    // ============================================================================
    // Leading One Detector (log2 characteristic)
    // ============================================================================
    logic [4:0] k_a, k_b;
    logic [3:0] k_a_raw, k_b_raw;

    // Instantiate the hierarchical LOD for each input
    hierarchical_lod_16bit lod_a (
        .a (abs_a),
        .k (k_a_raw)
    );

    hierarchical_lod_16bit lod_b (
        .a (abs_b),
        .k (k_b_raw)
    );
    
    // Assign 4-bit LOD output to 5-bit characteristic value
    assign k_a = {1'b0, k_a_raw};
    assign k_b = {1'b0, k_b_raw};

    // -------------------------------------------------------------------------
    // 3. Dynamic Truncation - Algorithm 1 Step 2 (IMPROVED)
    // -------------------------------------------------------------------------
    // Shift left to align the leading 1 to the MSB
    logic [WIDTH-1:0] norm_a, norm_b;
    assign norm_a = abs_a << ((WIDTH-1) - k_a);
    assign norm_b = abs_b << ((WIDTH-1) - k_b);

    // Truncate to 't' bits.
    logic [KEEP_WIDTH-1:0] x_a_trunc, x_b_trunc;
    logic [WIDTH - KEEP_WIDTH - 1:0] unused_bits_a, unused_bits_b;
    logic round_bit_a, round_bit_b;
    
    // ORIGINAL LOGIC:
    // assign x_a_trunc = {norm_a[(WIDTH-2) -: (KEEP_WIDTH-1)], 1'b1};
    // assign x_b_trunc = {norm_b[(WIDTH-2) -: (KEEP_WIDTH-1)], 1'b1};

    // UPDATED LOGIC:
    // We take KEEP_WIDTH bits directly starting from the bit after the Leading One bit.
    // This captures the (t-1) fraction bits and the next bit (MSB of the truncated part).
    // assign x_a_trunc = norm_a[(WIDTH-2) -: KEEP_WIDTH];
    // assign x_b_trunc = norm_b[(WIDTH-2) -: KEEP_WIDTH];
    integer total_bits;
    assign total_bits = 2^(WIDTH - KEEP_WIDTH-1) - 1;
    assign unused_bits_a = norm_a[(KEEP_WIDTH-1):0];
    assign unused_bits_b = norm_b[(KEEP_WIDTH-1):0];

    always_comb begin
        round_bit_a = 1'b0;
        round_bit_b = 1'b0;

        if (unused_bits_a > total_bits/2) begin
            round_bit_a = 1'b1;
        end

        if (unused_bits_b > total_bits/2) begin
            round_bit_b = 1'b1;
        end
    end
    assign x_a_trunc = {norm_a[(WIDTH-2) -: (KEEP_WIDTH-1)], round_bit_a};
    assign x_b_trunc = {norm_b[(WIDTH-2) -: (KEEP_WIDTH-1)], round_bit_b};

    // -------------------------------------------------------------------------
    // 4. Adder and Compensation - Algorithm 1 Step 3 & 4
    // -------------------------------------------------------------------------
    // Sum exponents (k)
    logic [$clog2(WIDTH):0] sum_k; 
    assign sum_k = k_a + k_b;

    // Sum significands + 1 (Compensation as per Eq 7 and Algo 1 Step 4)
    logic [KEEP_WIDTH:0] sum_x;
    assign sum_x = x_a_trunc + x_b_trunc + 1'b1;

    // -------------------------------------------------------------------------
    // 5. Antilogarithmic Converter - Algorithm 1 Step 5 
    // -------------------------------------------------------------------------
    // Check if significand sum overflowed (>= 1.0)
    // If sum_x[KEEP_WIDTH] is 1, it means x1+x2 >= 1
    logic carry_x;
    assign carry_x = sum_x[KEEP_WIDTH];

    // Calculate final exponent K
    logic [$clog2(WIDTH):0] final_k;
    assign final_k = sum_k + carry_x;

    // Calculate final fractional part (xt)
    logic [KEEP_WIDTH-1:0] final_x;
    assign final_x = sum_x[KEEP_WIDTH-1:0];

    // Reconstruct the value: {1.xt}
    logic [WIDTH*2-1:0] mantissa_reconst;
    assign mantissa_reconst = {1'b1, final_x};

    // -------------------------------------------------------------------------
    // 6. Final Shifter
    // -------------------------------------------------------------------------
    always_comb begin
        // Handle zero inputs explicitly (Log(0) is undefined)
        if (i_a == 0 || i_b == 0) begin
            o_z = 0;
        end else begin
            // Shift the reconstructed significand to the correct power of 2
            if (final_k >= KEEP_WIDTH)
                o_z = mantissa_reconst << (final_k - KEEP_WIDTH);
            else
                o_z = mantissa_reconst >> (KEEP_WIDTH - final_k);

            // Apply sign
            if (sign_z) o_z = -o_z;
        end
    end

endmodule