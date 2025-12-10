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
    
    // Sign Handling
    assign sign_a = i_a[WIDTH-1];
    assign sign_b = i_b[WIDTH-1];
    assign sign_z = sign_a ^ sign_b;

    // The paper suggests 1's complement + OR for approx sign, but standard
    // testing usually requires exact sign handling to isolate multiplier error.
    assign abs_a = sign_a ? -i_a : i_a;
    assign abs_b = sign_b ? -i_b : i_b;

    // Leading One Detector (LOD)
    logic [$clog2(WIDTH)-1:0] k_a, k_b;

    function automatic [$clog2(WIDTH)-1:0] get_lod_tree(input [WIDTH-1:0] val);
        // Pure tree-based LOD for 16-bit with 4 stages
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


    assign k_a = get_lod_tree(abs_a);
    assign k_b = get_lod_tree(abs_b);

    // Dynamic Truncation
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

    // Adder and Compensation
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

    // Antilogarithmic Converter
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

    // Final Shifter
    always_comb begin
        // Handle zero inputs explicitly (Log(0) is undefined)
        if (i_a == 0 || i_b == 0) begin
            o_z = 0;
        end else begin
            if (final_k >= KEEP_WIDTH)
                o_z = mantissa_reconst << (final_k - KEEP_WIDTH);
            else
                o_z = mantissa_reconst >> (KEEP_WIDTH - final_k);

            // Apply sign
            if (sign_z) o_z = -o_z;
        end
    end

endmodule
