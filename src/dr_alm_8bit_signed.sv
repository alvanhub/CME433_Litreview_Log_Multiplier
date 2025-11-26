module dr_alm_8bit_signed #(
    parameter integer TRUNC_WIDTH = 6 // Referred to as 't' or 'L' in the paper
)(
    input  logic signed [7:0] i_a,
    input  logic signed [7:0] i_b,
    output logic signed [15:0] o_z
);

    // 1. Sign Handling [cite: 206, 207]
    // The paper specifies approximate sign conversion: 1's complement + OR with LSB.
    // However, for standard compatibility, we calculate the final sign bit XOR
    // and process magnitudes.
    logic sign_a, sign_b, sign_z;
    logic [7:0] mag_a, mag_b;
    logic [7:0] abs_a, abs_b;

    assign sign_a = i_a[7];
    assign sign_b = i_b[7];
    assign sign_z = sign_a ^ sign_b;

    // Paper[cite: 207]: "use one's complement and an OR operation with the logic one... instead of negation"
    // Ideally: assign abs_a = sign_a ? (~i_a | 8'b1) : i_a;
    // But for clearer functional verification within your testbench, we use exact absolute value below.
    // (You can uncomment the line above to strictly match the paper's approximate sign hardware).
    assign abs_a = sign_a ? -i_a : i_a;
    assign abs_b = sign_b ? -i_b : i_b;

    // 2. Leading One Detector (LOD) [cite: 154, 161]
    // Finds the position of the most significant bit (k)
    logic [2:0] k_a, k_b;
    
    function automatic [2:0] get_lod(input [7:0] val);
        int i;
        get_lod = 0;
        for (i = 7; i >= 0; i = i - 1) begin
            if (val[i]) begin
                get_lod = i[2:0];
                break;
            end
        end
    endfunction

    assign k_a = get_lod(abs_a);
    assign k_b = get_lod(abs_b);

    // 3. Dynamic Truncation & Log Conversion [cite: 151, 161]
    // Algorithm 1 Step 2: Extract fractional part and truncate to TRUNC_WIDTH
    // The paper shifts the operand to align the MSB, then takes the top bits.
    
    logic [7:0] norm_a, norm_b;
    logic [TRUNC_WIDTH-1:0] x_a_trunc, x_b_trunc;

    // Shift left to align the leading 1 to the MSB position (bit 7)
    // We calculate shift amount based on k. shift = 7 - k.
    assign norm_a = abs_a << (7 - k_a);
    assign norm_b = abs_b << (7 - k_b);

    // Truncate: Take the bits following the leading 1.
    // Normalized format: [1 . f f f f f f f]
    // We take the top (TRUNC_WIDTH - 1) fractional bits and append '1' 
    // The -2 accounts for skipping the implicit 1 (bit 7) and handling array indexing.
    assign x_a_trunc = {norm_a[6 -: (TRUNC_WIDTH-1)], 1'b1}; 
    assign x_b_trunc = {norm_b[6 -: (TRUNC_WIDTH-1)], 1'b1};

    // 4. Adder and Compensation [cite: 159, 168]
    // Sum of exponents (k) and Sum of truncated mantissas (x)
    // The paper adds a '1' for compensation: L = op1 + op2 + 1
    
    logic [3:0] sum_k; // Width to hold max k (7+7=14)
    logic [TRUNC_WIDTH:0] sum_x; // Width for overflow detection
    
    assign sum_k = k_a + k_b;
    
    // Sum fractions + compensation '1' 
    assign sum_x = x_a_trunc + x_b_trunc + 1'b1;

    // 5. Antilogarithmic Converter [cite: 160, 168]
    // If sum_x >= 1 (detected by MSB overflow in our fixed width), we shift k by 1
    
    logic [15:0] pre_shift_res;
    logic [3:0]  final_k;
    logic        carry_x;
    logic [TRUNC_WIDTH-1:0] final_x;

    assign carry_x = sum_x[TRUNC_WIDTH]; // Detect if mantissas added up > 1.0
    assign final_k = sum_k + carry_x;    // Adjust exponent if overflow
    
    // Reconstruct the value: implicit '1' concatenated with the resulting fraction
    // We strip the carry bit from sum_x to get the fraction
    assign final_x = sum_x[TRUNC_WIDTH-1:0];

    // 6. Shifting (Antilog) 
    // The result is roughly: (1.final_x) * 2^(final_k)
    // We construct a temporary base integer and shift it.
    
    logic [15:0] mantissa_reconst;
    
    // Place the reconstruction at the bottom
    assign mantissa_reconst = {1'b1, final_x};
    
    // We need to shift this to the correct magnitude position.
    // The current mantissa_reconst represents a value where the binary point 
    // is to the left of the MSB. We need to align it to `final_k`.
    // Shift logic: result = mantissa << (final_k - (TRUNC_WIDTH bits));
    // However, to ensure 16-bit output alignment:
    
    always_comb begin
        // Handle Zero Input Case (Log of 0 is undefined, result must be 0)
        if (i_a == 0 || i_b == 0) begin
            o_z = 0;
        end else begin
            // Calculate shift. The mantissa is currently effectively "TRUNC_WIDTH" bits long.
            // We want the MSB to end up at bit position 'final_k'.
            // Currently, the MSB is at bit TRUNC_WIDTH.
            // So we shift left by (final_k - TRUNC_WIDTH).
            // Since Verilog shifts are integers, we handle this carefully:
            if (final_k >= TRUNC_WIDTH)
                o_z = mantissa_reconst << (final_k - TRUNC_WIDTH);
            else
                o_z = mantissa_reconst >> (TRUNC_WIDTH - final_k);

            // Apply Sign
            if (sign_z) o_z = -o_z;
        end
    end

endmodule
