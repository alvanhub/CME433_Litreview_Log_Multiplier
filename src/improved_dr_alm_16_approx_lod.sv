module improved_dr_alm_16_approx_lod #(
    parameter KEEP_WIDTH = 7
) (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

  localparam integer M_WIDTH = KEEP_WIDTH;
  // ============================================================================
  // Sign and Absolute Value
  // ============================================================================
  logic sign_a, sign_b, sign_z;
  logic [15:0] abs_a, abs_b;

  assign sign_a = i_a[15];
  assign sign_b = i_b[15];
  assign sign_z = sign_a ^ sign_b;

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

  // ============================================================================
  // Normalize Inputs
  // ============================================================================
  logic [15:0] norm_a, norm_b;
  assign norm_a = abs_a << (15 - k_a);
  assign norm_b = abs_b << (15 - k_b);

  // ============================================================================
  // Extract fractional part
  // ============================================================================
  logic [14:0] frac_a, frac_b;
  assign frac_a = norm_a[14:0];
  assign frac_b = norm_b[14:0];

  // ============================================================================
  // Truncation - Following paper's approach (Alg 1 Step 2)
  // ============================================================================
  logic [M_WIDTH-1:0] x_a_trunc, x_b_trunc;
  
  assign x_a_trunc = {frac_a[14 -: (M_WIDTH-1)], 1'b1};
  assign x_b_trunc = {frac_b[14 -: (M_WIDTH-1)], 1'b1};
  
  localparam REM_WIDTH = 15 - (M_WIDTH-1);
  logic [REM_WIDTH-1:0] trunc_a, trunc_b;
  assign trunc_a = frac_a[REM_WIDTH-1:0];
  assign trunc_b = frac_b[REM_WIDTH-1:0];

  // ============================================================================
  // Adaptive Compensation
  // ============================================================================
  logic [M_WIDTH:0] compensation;
  logic [REM_WIDTH:0] sum_trunc;
  logic [REM_WIDTH:0] threshold;

  always_comb begin
    compensation = 1; // Base compensation
    
    // Optional adaptive for large magnitudes
    if (REM_WIDTH > 2 && (k_a >= 5) && (k_b >= 5)) begin
      sum_trunc = {1'b0, trunc_a} + {1'b0, trunc_b};
      
      threshold = (7 * (1 << REM_WIDTH)) >> 3;
      if (sum_trunc >= threshold)
        compensation = compensation + 1;
    end
  end

 // ============================================================================
  // Add characteristics + truncated mantissas
  // ============================================================================
  logic [5:0] sum_k;
  logic [M_WIDTH:0] sum_x;

  assign sum_k = k_a + k_b;
  assign sum_x = x_a_trunc + x_b_trunc + compensation;

  // ============================================================================
  // Antilog - Following paper's approach
  // ============================================================================
  logic carry_x;
  logic [5:0] final_k;
  logic [M_WIDTH-1:0] final_x;
  logic [31:0] mantissa_reconst;
  logic [31:0] result_mag;

  assign carry_x = sum_x[M_WIDTH];
  assign final_k = sum_k + carry_x;
  assign final_x = sum_x[M_WIDTH-1:0];
  assign mantissa_reconst = {1'b1, final_x};

  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 0;
    end else begin
      if (final_k >= M_WIDTH)
        result_mag = mantissa_reconst << (final_k - M_WIDTH);
      else
        result_mag = mantissa_reconst >> (M_WIDTH - final_k);
    end
  end

  // ============================================================================
  // Apply sign
  // ============================================================================
  assign o_z = sign_z ? -result_mag : result_mag;

endmodule