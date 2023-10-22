module log_reader_out_ctrl_uncondense (
     input  clk
    ,input  rst

    ,input  logic                           write_hdr_fifo_out_rd_val
    ,input  logic                           write_hdr_fifo_out_rd_data_last
    ,output logic                           out_write_hdr_fifo_rd_rdy
    
    ,output logic                           reader_dst_data_val
    ,output logic                           reader_dst_data_last
    ,input  logic                           dst_reader_data_rdy
    
    ,output logic                           out_reset_entry_addr
    ,output logic                           out_incr_entry_addr
    ,output logic                           output_done
    
    ,input  logic                           last_entry_out
);

    typedef enum logic [1:0] {
        READY = 2'd0,
        ENTRIES_OUT = 2'd1,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    assign output_done = state_reg == READY;

    always_comb begin
        reader_dst_data_val = 1'b0;
        reader_dst_data_last = 1'b0;
        
        out_reset_entry_addr = 1'b0;
        out_incr_entry_addr = 1'b0;
        
        out_write_hdr_fifo_rd_rdy = 1'b0;
        
        state_next = state_reg;
        case (state_reg)
            READY: begin
                out_reset_entry_addr = 1'b1;
                if (write_hdr_fifo_out_rd_val) begin
                    state_next = ENTRIES_OUT;
                end
            end
            ENTRIES_OUT: begin
                reader_dst_data_val = write_hdr_fifo_out_rd_val;
                reader_dst_data_last = last_entry_out 
                                       ? write_hdr_fifo_out_rd_data_last
                                       : '0;
                out_write_hdr_fifo_rd_rdy = dst_reader_data_rdy;
                if (dst_reader_data_rdy & write_hdr_fifo_out_rd_val) begin
                    if (write_hdr_fifo_out_rd_data_last) begin
                        out_incr_entry_addr = 1'b1;
                        if (last_entry_out) begin
                            state_next = READY;
                        end
                    end
                end
            end
        endcase
    end
endmodule
