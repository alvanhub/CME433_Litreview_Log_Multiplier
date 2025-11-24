module tb_verify_alm;

  logic signed [7:0] a, b;
  logic signed [15:0] result_approx;
  
  // Instantiating the module you built
  dr_alm_8bit_signed #(.TRUNC_WIDTH(6)) dut (
    .i_a(a),
    .i_b(b),
    .o_z(result_approx)
  );

  longint total_relative_error_accum = 0;
  longint count = 0;
  real mred_percent;
  
  int exact_prod;
  int error_dist;
  real rel_error;

  initial begin
    $display("--- Starting DR-ALM-6 Verification ---");
    
    // Exhaustive test: -128 to 127
    for (int i = -128; i < 128; i++) begin
      for (int j = -128; j < 128; j++) begin
        a = i;
        b = j;
        #1; // Wait for logic
        
        exact_prod = a * b;
        
        // Calculate Error Distance (ED) = |Exact - Approx|
        error_dist = exact_prod - result_approx;
        if (error_dist < 0) error_dist = -error_dist;
        
        // Calculate Relative Error (RED) = ED / Exact
        // Skip division by zero
        if (exact_prod != 0) begin
          rel_error = real'(error_dist) / real'(exact_prod);
          if (rel_error < 0) rel_error = -rel_error; // absolute value
          
          // Accumulate for Mean calculation
          total_relative_error_accum += longint'(rel_error * 100000); // Scale to keep precision
          count++;
        end
      end
    end

    mred_percent = real'(total_relative_error_accum) / real'(count) / 1000.0; // Scale back
    
    $display("Total Non-Zero Operations Tested: %0d", count);
    $display("Calculated MRED: %0.4f%%", mred_percent);
    $display("Target MRED (from Paper Table 2): ~2.91 percent");
    
    if (mred_percent > 2.5 && mred_percent < 3.5) 
        $display("PASS: Logic matches paper specifications.");
    else 
        $display("FAIL: Accuracy deviates significantly from paper.");
        
    $finish;
  end

endmodule
