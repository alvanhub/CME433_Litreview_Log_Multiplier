// Reference: "Design and Analysis of Energy-Efficient Dynamic Range Approximate Logarithmic Multipliers"
// Implements Algorithm 1 and Figure 2 from the paper.

module dr_alm_core #(
    parameter integer WIDTH = 16,
    parameter KEEP_WIDTH = 7
)(
    input  logic signed [WIDTH-1:0] i_a,
    input  logic signed [WIDTH-1:0] i_b,
    output logic signed [(2*WIDTH)-1:0] o_z
);
    localparam integer TRUNC_WIDTH = KEEP_WIDTH;

    logic sign_a, sign_b, sign_z;
    logic [WIDTH-1:0] abs_a, abs_b;
    
    // -------------------------------------------------------------------------
    // 1. Sign Handling (Section 3.2)
    // -------------------------------------------------------------------------
    assign sign_a = i_a[WIDTH-1];
    assign sign_b = i_b[WIDTH-1];
    assign sign_z = sign_a ^ sign_b;

    // The paper suggests 1's complement + OR for approx sign, but standard
    // testing usually requires exact sign handling to isolate multiplier error.
    assign abs_a = sign_a ? -i_a : i_a;
    assign abs_b = sign_b ? -i_b : i_b;

    // -------------------------------------------------------------------------
    // 2. Leading One Detector (LOD) - Algorithm 1 Step 1 
    // -------------------------------------------------------------------------
    logic [$clog2(WIDTH)-1:0] k_a, k_b;

    // Helper function to find the Most Significant Bit (MSB) location
    function automatic [$clog2(WIDTH)-1:0] get_lod(input [WIDTH-1:0] val);
        int i;
        get_lod = 0;
        for (i = WIDTH-1; i >= 0; i = i - 1) begin
            if (val[i]) begin
                get_lod = i[$clog2(WIDTH)-1:0];
                break;
            end
        end
    endfunction

    assign k_a = get_lod(abs_a);
    assign k_b = get_lod(abs_b);


    // lod16 lod_inst_a (
    //     .data_in(abs_a),
    //     .lead_one_pos(k_a)
    // );

    // lod16 lod_inst_b (
    //     .data_in(abs_b),
    //     .lead_one_pos(k_b)
    // );

    // -------------------------------------------------------------------------
    // 3. Dynamic Truncation - Algorithm 1 Step 2 
    // -------------------------------------------------------------------------
    // Shift left to align the leading 1 to the MSB
    logic [WIDTH-1:0] norm_a, norm_b;
    assign norm_a = abs_a << ((WIDTH-1) - k_a);
    assign norm_b = abs_b << ((WIDTH-1) - k_b);

    // Truncate to 't' bits.
    // The paper specifies taking the fractional parts x1, x2 and appending '1'
    // x1t <- {x1[n-2 .. n-t-1], 1'b1}
    logic [KEEP_WIDTH-1:0] x_a_trunc, x_b_trunc;

    // We extract KEEP_WIDTH-1 bits after the MSB, then append 1.
    // (WIDTH-2) is the bit immediately following the Leading One.
    assign x_a_trunc = {norm_a[(WIDTH-2) -: (KEEP_WIDTH-1)], 1'b1};
    assign x_b_trunc = {norm_b[(WIDTH-2) -: (KEEP_WIDTH-1)], 1'b1};

    // -------------------------------------------------------------------------
    // 4. Adder and Compensation - Algorithm 1 Step 3 & 4 [cite: 161, 159]
    // -------------------------------------------------------------------------
    // Sum exponents (k)
    logic [$clog2(WIDTH):0] sum_k; 
    logic [KEEP_WIDTH:0] sum_x;


    log_conv #(
        .WIDTH(WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH)
    ) log_adder (
        .x1_t(x_a_trunc),
        .x2_t(x_b_trunc),
        .k1(k_a),
        .k2(k_b),
        .sum_k(sum_k),
        .sum_x(sum_x)
    );

    // -------------------------------------------------------------------------
    // 5. Antilogarithmic Converter - Algorithm 1 Step 5 
    // -------------------------------------------------------------------------
    // Check if mantissa sum overflowed (>= 1.0)
    // If sum_x[KEEP_WIDTH] is 1, it means x1+x2 >= 1
    logic [$clog2(WIDTH):0] final_k;
    logic [WIDTH*2-1:0] mantissa_reconst;

    antilog_conv #(
        .WIDTH(WIDTH),
        .KEEP_WIDTH(KEEP_WIDTH)
    ) antilog_converter (
        .sum_k(sum_k),
        .sum_x(sum_x),
        .final_k(final_k),
        .mantissa_reconst(mantissa_reconst)
    );

    // -------------------------------------------------------------------------
    // 6. Final Shifter
    // -------------------------------------------------------------------------
    always_comb begin
        // Handle zero inputs explicitly (Log(0) is undefined)
        if (i_a == 0 || i_b == 0) begin
            o_z = 0;
        end else begin
            // Shift the reconstructed mantissa to the correct power of 2
            // The mantissa currently looks like: 1.xxxxx (width = KEEP_WIDTH)
            // It effectively has a decimal point after the first bit.
            // We need to shift it so the MSB is at position 'final_k'.
            
            // Logic: Result = mantissa * 2^(final_k - width_of_fraction)
            if (final_k >= KEEP_WIDTH)
                o_z = mantissa_reconst << (final_k - KEEP_WIDTH);
            else
                o_z = mantissa_reconst >> (KEEP_WIDTH - final_k);

            // Apply sign
            if (sign_z) o_z = -o_z;
        end
    end

endmodule
