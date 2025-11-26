module improved_dr_alm_16 #(
    parameter M_WIDTH = 10     // number of kept mantissa bits (<= 15)
) (
    input  logic signed [15:0] i_a,
    input  logic signed [15:0] i_b,
    output logic signed [31:0] o_z
);

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
  function automatic [4:0] get_k(input logic [15:0] val);
    if (val[15]) return 15;
    if (val[14]) return 14;
    if (val[13]) return 13;
    if (val[12]) return 12;
    if (val[11]) return 11;
    if (val[10]) return 10;
    if (val[ 9]) return 9;
    if (val[ 8]) return 8;
    if (val[ 7]) return 7;
    if (val[ 6]) return 6;
    if (val[ 5]) return 5;
    if (val[ 4]) return 4;
    if (val[ 3]) return 3;
    if (val[ 2]) return 2;
    if (val[ 1]) return 1;
    return 0;
  endfunction

  logic [4:0] k_a, k_b;
  assign k_a = get_k(abs_a);
  assign k_b = get_k(abs_b);

  // ============================================================================
  // Normalize Inputs
  // ============================================================================
  logic [15:0] norm_a, norm_b;
  assign norm_a = abs_a << (15 - k_a);
  assign norm_b = abs_b << (15 - k_b);

  // ============================================================================
  // Extract 15-bit Fractional Mantissa
  // ============================================================================
  logic [14:0] frac_a, frac_b;

  assign frac_a = norm_a[14:0];
  assign frac_b = norm_b[14:0];

  // ============================================================================
  // Truncation (keep upper M_WIDTH bits of 15-bit mantissa)
  // ============================================================================
  logic [M_WIDTH-1:0] frac_a_trunc, frac_b_trunc;
  assign frac_a_trunc = frac_a[14 : 15-M_WIDTH];
  assign frac_b_trunc = frac_b[14 : 15-M_WIDTH];

  // ============================================================================
  // Truncated remainder (used for error compensation)
  // ============================================================================
  localparam REM_WIDTH = 15 - M_WIDTH;

  logic [REM_WIDTH-1:0] trunc_a, trunc_b;

  assign trunc_a = frac_a[REM_WIDTH-1:0];
  assign trunc_b = frac_b[REM_WIDTH-1:0];

  // ============================================================================
  // Error Compensation Logic (scaled up from 7-bit version)
  // ============================================================================
  logic [M_WIDTH:0] compensation;

  always_comb begin
    if (REM_WIDTH > 0) begin
      logic apply_compensation;
      apply_compensation = (k_a >= 3) && (k_b >= 3);

      if (apply_compensation) begin
        logic [REM_WIDTH:0] sum_trunc;
        sum_trunc = {1'b0, trunc_a} + {1'b0, trunc_b};

        // same 75% rule
        if (sum_trunc >= ((sum_trunc >> 1) + (sum_trunc >> 2)))
          compensation = 1;
        else
          compensation = 0;

      end else begin
        compensation = 0;
      end
    end else begin
      compensation = 0;
    end
  end

  // ============================================================================
  // Add characteristics + truncated mantissas
  // ============================================================================
  logic [5:0] sum_k;
  logic [M_WIDTH:0] sum_frac_trunc;

  assign sum_k = k_a + k_b;
  assign sum_frac_trunc =
        {1'b0, frac_a_trunc} +
        {1'b0, frac_b_trunc} +
        compensation;

  // ============================================================================
  // Restore to full 15-bit mantissa width for Mitchell's antilog
  // ============================================================================
  logic [14:0] sum_frac_restored;

  assign sum_frac_restored =
      {sum_frac_trunc, {REM_WIDTH{1'b0}}};  // pad LSBs

  // ============================================================================
  // Antilog (Mitchell)
  // ============================================================================
  logic [31:0] result_mag;
  int shift_amt;
  logic [14:0] mantissa;

  always_comb begin
    if (abs_a == 0 || abs_b == 0) begin
      result_mag = 0;

    end else begin
      if (sum_frac_restored[14]) begin
        // mantissa >= 1.0
        shift_amt = (sum_k + 1) - 15;

        if (shift_amt >= 0)
            result_mag = {16'b0, sum_frac_restored} << shift_amt;
        else
            result_mag = {16'b0, sum_frac_restored} >> -shift_amt;

      end else begin
        // mantissa < 1.0 → add implicit 1.0 (bit 14)
        mantissa = (15'h4000 | sum_frac_restored);
        shift_amt = sum_k - 15;

        if (shift_amt >= 0)
            result_mag = {16'b0, mantissa} << shift_amt;
        else
            result_mag = {16'b0, mantissa} >> -shift_amt;
      end
    end
  end

  // ============================================================================
  // Apply sign
  // ============================================================================
  assign o_z = sign_z ? -result_mag : result_mag;

endmodule
