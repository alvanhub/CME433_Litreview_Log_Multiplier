// NMED and MRED Testbench for 16-bit DR-ALM
// Calculates error metrics for 16-bit multiplier
// Uses sampling since exhaustive test is 2^32 combinations

`timescale 1ns/1ps

module tb_nmed_16bit;

    // Test signals
    logic [15:0] a, b;
    logic [31:0] exact_result, approx_result;

    // Error accumulation
    real total_error;
    real total_rel_error;
    real max_product;
    real nmed, mred;
    integer total_tests;
    integer non_zero_tests;

    // For random sampling
    integer seed;

    // Instantiate exact multiplier
    assign exact_result = a * b;

    // Instantiate 16-bit DR-ALM
    dr_alm_16bit #(.TRUNC_WIDTH(6)) uut (
        .i_a(a), .i_b(b), .o_z(approx_result)
    );

    // Calculate absolute error
    function automatic real abs_error(input logic [31:0] exact, input logic [31:0] approx);
        if (exact >= approx)
            return real'(exact - approx);
        else
            return real'(approx - exact);
    endfunction

    // Calculate relative error
    function automatic real rel_error(input logic [31:0] exact, input logic [31:0] approx);
        real err;
        if (exact == 0)
            return 0.0;
        if (exact >= approx)
            err = real'(exact - approx);
        else
            err = real'(approx - exact);
        return err / real'(exact);
    endfunction

    initial begin
        total_error = 0.0;
        total_rel_error = 0.0;
        max_product = 65535.0 * 65535.0;  // Max product for 16-bit
        total_tests = 0;
        non_zero_tests = 0;
        seed = 12345;

        $display("========================================");
        $display("NMED/MRED Calculation for 16-bit DR-ALM-6");
        $display("========================================");

        // Method 1: Sample 1M random test cases
        $display("Running 1,000,000 random test cases...");

        for (int i = 0; i < 1000000; i++) begin
            a = $random(seed);
            b = $random(seed);
            #1;  // Allow combinational logic to settle

            // Calculate errors
            total_error = total_error + abs_error(exact_result, approx_result);
            if (exact_result != 0) begin
                total_rel_error = total_rel_error + rel_error(exact_result, approx_result);
                non_zero_tests = non_zero_tests + 1;
            end
            total_tests = total_tests + 1;

            // Progress indicator
            if (i % 100000 == 0 && i != 0)
                $display("Progress: %0d/1000000 tests completed", i);
        end

        // Calculate NMED and MRED
        nmed = total_error / (real'(total_tests) * max_product);
        mred = total_rel_error / real'(non_zero_tests) * 100.0;

        $display("========================================");
        $display("Results (Random Sampling):");
        $display("  Total tests: %0d", total_tests);
        $display("  Non-zero tests: %0d", non_zero_tests);
        $display("  Total error: %0f", total_error);
        $display("  Max product: %0f", max_product);
        $display("  NMED: %0.6f", nmed);
        $display("  NMED (scientific): %0e", nmed);
        $display("  MRED: %0.2f%%", mred);
        $display("========================================");
        $display("");
        $display("Expected from paper (Table 2):");
        $display("  NMED: 0.0073 (7.3e-3)");
        $display("  MRED: 3.03%%");
        $display("========================================");

        $finish;
    end

endmodule
