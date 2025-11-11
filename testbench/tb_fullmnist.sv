function int findCommaInString(string in_string);
  findCommaInString = -1;
  for (int idx = 0; idx < in_string.len(); idx = idx + 1) begin
    if (in_string[idx] == ",") begin
      findCommaInString = idx;
      break;
    end
  end
endfunction : findCommaInString

module tb_fullmnist;
  int layer_count = 3;

  logic [7:0] i_mulA1, i_mulA2, i_mulB1, i_mulB2;
  logic [15:0] o_mulP1, o_mulP2;

  string root_dir, inputs_dir, layers_dir, outputs_dir, temp_fp, line, version;

  int temp;
  int zp_file;
  int comma_loc;
  int meta_file;
  int layer_type;
  int quant_file;
  int layer_start;
  int layer_bdims;
  int output_file;
  int layer_idims[];
  int layer_wdims[];
  int layer_odims[];
  int input_zp_dims;
  int output_zp_dims;
  int weight_zp_dims;
  int last_layer_mode;
  int output_quant_mult_dims;
  int output_quant_shift_dims;

  int operation_count;

  logic signed [31:0] layer_b[];
  logic signed [7:0] layer_w[];
  logic signed [7:0] layer_i[];
  logic signed [7:0] layer_o[];

  logic signed [15:0] shifted_input;
  logic signed [15:0] shifted_output;
  logic signed [7:0] shifted_filter;
  logic signed [7:0] in8A;
  logic signed [7:0] in8B;

  logic signed [7:0] input_zp;
  logic signed [7:0] output_zp;
  logic signed [7:0] filter_zp;

  logic signed [31:0] quant_mult;
  logic signed [31:0] quant_shift;
  logic signed [31:0] total_shift;

  logic signed [15:0] product16;
  logic signed [15:0] offset16;
  logic signed [31:0] product32;
  logic signed [31:0] relu32;
  logic signed [63:0] product64;
  logic signed [63:0] shifted_product64;
  logic signed [63:0] round;
  logic signed [31:0] acc32;

  mult16bvia8bit mult (
      .i_a(shifted_input),
      .i_b(offset16),
      .o_z(product32)
  );

  initial begin
    if ($value$plusargs("V=%s", version)) begin
      $display(version);
    end else begin
      version = "default";
    end
    //last_layer_mode
    //MAKE SURE YOU RUN EXACT MULTIPLIER BEFORE RUNNING THE LAST LAYER MODE
    last_layer_mode = 0;

    // initialization
    root_dir = "../";
    inputs_dir = {root_dir, "inputs/"};
    layers_dir = {root_dir, "layers/"};
    outputs_dir = {root_dir, "results/"};
    layer_idims = '{0, 0};
    layer_wdims = '{0, 0};
    layer_odims = '{0, 0};

    layer_start = 0;
    if (last_layer_mode) begin
      layer_start = 2;
    end


    // network ops
    for (int input_idx = 0; input_idx < 100; input_idx = input_idx + 1) begin
      for (int layer_id = 0; layer_id < layer_count; layer_id = layer_id + 1) begin
        // load layer details from metadata
        $sformat(temp_fp, {layers_dir, "%0d_meta.txt"}, layer_id);
        meta_file = $fopen(temp_fp, "r");

        temp = $fscanf(meta_file, "%s", line);
        // $display("ID: %s", line);

        temp = $fscanf(meta_file, "%s", line);
        layer_type = line.atoi();
        // $display("Type: %0d", layer_type);

        temp = $fscanf(meta_file, "%s", line);
        comma_loc = findCommaInString(line);
        layer_idims[0] = line.substr(0, comma_loc).atoi();
        layer_idims[1] = line.substr(comma_loc + 1, line.len() - 1).atoi();
        // $display("Input dims: {%0d, %0d}", layer_idims[0], layer_idims[1]);

        temp = $fscanf(meta_file, "%s", line);
        comma_loc = findCommaInString(line);
        layer_odims[0] = line.substr(0, comma_loc).atoi();
        layer_odims[1] = line.substr(comma_loc + 1, line.len() - 1).atoi();
        // $display("Output dims: {%0d, %0d}", layer_odims[0], layer_odims[1]);

        temp = $fscanf(meta_file, "%s", line);
        comma_loc = findCommaInString(line);
        layer_wdims[0] = line.substr(0, comma_loc).atoi();
        layer_wdims[1] = line.substr(comma_loc + 1, line.len() - 1).atoi();
        // $display("Weight dims: {%0d, %0d}", layer_wdims[0], layer_wdims[1]);

        temp = $fscanf(meta_file, "%s", line);
        layer_bdims = line.atoi();
        // $display("Bias dims: %0d", layer_bdims);

        temp = $fscanf(meta_file, "%s", line);
        input_zp_dims = line.atoi();

        temp = $fscanf(meta_file, "%s", line);
        output_zp_dims = line.atoi();

        temp = $fscanf(meta_file, "%s", line);
        weight_zp_dims = line.atoi();

        temp = $fscanf(meta_file, "%s", line);
        output_quant_mult_dims = line.atoi();

        temp = $fscanf(meta_file, "%s", line);
        output_quant_shift_dims = line.atoi();

        $fclose(meta_file);

        // initialize layer parameters
        layer_i = new[layer_idims[0] * layer_idims[1]];
        layer_o = new[layer_odims[0] * layer_odims[1]];
        layer_w = new[layer_wdims[0] * layer_wdims[1]];
        layer_b = new[layer_bdims];

        $sformat(temp_fp, {layers_dir, "%0d_zeropoints.txt"}, layer_id);
        zp_file = $fopen(temp_fp, "r");
        temp = $fscanf(zp_file, "%b", input_zp);
        temp = $fscanf(zp_file, "%b", output_zp);
        temp = $fscanf(zp_file, "%b", filter_zp);
        $fclose(zp_file);

        $sformat(temp_fp, {layers_dir, "%0d_quants.txt"}, layer_id);
        // $display("%s", temp_fp);
        quant_file = $fopen(temp_fp, "r");
        temp = $fscanf(quant_file, "%b", quant_mult);
        temp = $fscanf(quant_file, "%b", quant_shift);
        // $display("%d, %d", quant_mult, quant_shift);
        $fclose(quant_file);


        // load layer data
        $sformat(temp_fp, {layers_dir, "%0d_filters.txt"}, layer_id);
        $readmemb(temp_fp, layer_w);
        $sformat(temp_fp, {layers_dir, "%0d_bias.txt"}, layer_id);
        $readmemb(temp_fp, layer_b);

        // load input data
        if (layer_id && !last_layer_mode) begin
          $sformat(temp_fp, {outputs_dir, "mult%s_%0din_layer%0d_out.txt"}, version, input_idx,
                   layer_id - 1);
          $readmemb(temp_fp, layer_i);
          //   $display("%b", layer_i[256]);
        end else if (layer_id && last_layer_mode) begin
          $sformat(temp_fp, {outputs_dir, "multexact_%0din_layer%0d_out.txt"}, input_idx,
                   layer_id - 1);
          $readmemb(temp_fp, layer_i);
          //   $display("%b", layer_i[256]);
        end else begin
          $sformat(temp_fp, {inputs_dir, "%0d_bin_inmnist.txt"}, input_idx);
          $readmemb(temp_fp, layer_i);
        end

        // Perform dot product (weights are transposed dim0->dim1, dim1->dim0)
        operation_count = 0;
        for (int dim1 = 0; dim1 < layer_wdims[0]; dim1 = dim1 + 1) begin
          acc32 = 0;
          for (int dim0 = 0; dim0 < layer_wdims[1]; dim0 = dim0 + 1) begin
            shifted_input = layer_i[dim0] - input_zp;
            offset16 = layer_w[dim1*layer_wdims[1]+dim0] - filter_zp;
            #10;
            acc32 = acc32 + product32;
          end
          acc32 = acc32 + layer_b[dim1];
          if (layer_type) relu32 = acc32;
          else relu32 = acc32[31] ? 0 : acc32;
          //   $display("%d", product32);
          total_shift = 31 - quant_shift;
          round = 1 << (total_shift - 1);
          //   $display("%d", round);
          product64 = relu32 * quant_mult;
          product64 = product64 + round;
          shifted_product64 = product64 >> total_shift;
          shifted_output = shifted_product64 + output_zp;
          layer_o[dim1] = shifted_output[7:0];
        end
        $sformat(temp_fp, {outputs_dir, "mult%s_%0din_layer%0d_out.txt"}, version, input_idx,
                 layer_id);
        output_file = $fopen(temp_fp, "w");
        for (int i = 0; i < layer_o.size; i = i + 1) begin
          $fdisplay(output_file, "%b", layer_o[i]);
        end
        $fclose(output_file);

        layer_i.delete();
        layer_w.delete();
        layer_o.delete();
        layer_b.delete();
      end
      if (input_idx % 10 == 0 && input_idx != 0)
        $display("Completed %d inputs out of 100", input_idx);
    end
    $display("Completed %d inputs out of 100", 100);
    $finish;
  end

endmodule : tb_fullmnist
