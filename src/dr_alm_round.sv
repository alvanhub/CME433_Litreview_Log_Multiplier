// Modified: Uses actual bit extraction for the LSB of the truncated significand instead of '1'.

module dr_alm_round #(
    parameter integer WIDTH = 16,
    parameter KEEP_WIDTH = 5
)(
    input  logic signed [WIDTH-1:0] i_a,
    input  logic signed [WIDTH-1:0] i_b,
    output logic signed [(2*WIDTH)-1:0] o_z
);

    logic sign_a, sign_b, sign_z;
    logic [WIDTH-1:0] abs_a, abs_b;
    
    // Sign Handling
    assign sign_a = i_a[WIDTH-1];
    assign sign_b = i_b[WIDTH-1];
    assign sign_z = sign_a ^ sign_b;

    // Standard exact sign handling to isolate multiplier error.
    assign abs_a = sign_a ? -i_a : i_a;
    assign abs_b = sign_b ? -i_b : i_b;

    // Leading One Detector
    logic [3:0] k_a, k_b;

    function automatic [$clog2(WIDTH)-1:0] get_lod_tree(input [WIDTH-1:0] val);
        logic [3:0] lod_out;
        
        if (val[15:8] != 0) begin
            lod_out[3] = 1'b1;
            if (val[15:12] != 0) begin
                lod_out[2] = 1'b1;
                if (val[15:14] != 0) begin
                    lod_out[1] = 1'b1;
                    lod_out[0] = val[15] ? 1'b1 : 1'b0;
                end else begin
                    lod_out[1] = 1'b0;
                    lod_out[0] = val[13] ? 1'b1 : 1'b0;
                end
            end else begin
                lod_out[2] = 1'b0;
                if (val[11:10] != 0) begin
                    lod_out[1] = 1'b1;
                    lod_out[0] = val[11] ? 1'b1 : 1'b0;
                end else begin
                    lod_out[1] = 1'b0;
                    lod_out[0] = val[9] ? 1'b1 : 1'b0;
                end
            end
        end else begin
            lod_out[3] = 1'b0;
            if (val[7:4] != 0) begin
                lod_out[2] = 1'b1;
                if (val[7:6] != 0) begin
                    lod_out[1] = 1'b1;
                    lod_out[0] = val[7] ? 1'b1 : 1'b0;
                end else begin
                    lod_out[1] = 1'b0;
                    lod_out[0] = val[5] ? 1'b1 : 1'b0;
                end
            end else begin
                lod_out[2] = 1'b0;
                if (val[3:2] != 0) begin
                    lod_out[1] = 1'b1;
                    lod_out[0] = val[3] ? 1'b1 : 1'b0;
                end else begin
                    lod_out[1] = 1'b0;
                    lod_out[0] = val[1] ? 1'b1 : 1'b0;
                end
            end
        end
        return lod_out;
    endfunction
    
    // Assign 4-bit LOD output to 5-bit characteristic value
    assign k_a = get_lod_tree(abs_a);
    assign k_b = get_lod_tree(abs_b);

    // Dynamic Truncation
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

    // UPDATED LOGIC:;
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

    // Adder and Compensation
    // Sum exponents (k)
    logic [$clog2(WIDTH):0] sum_k; 
    assign sum_k = k_a + k_b;

    // Sum significands + 1
    logic [KEEP_WIDTH:0] sum_x;
    assign sum_x = x_a_trunc + x_b_trunc + 1'b1;

    // Antilogarithmic Converter
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

    // Final Shifter
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