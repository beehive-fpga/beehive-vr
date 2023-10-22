module log_reader_out_ctrl (
     input clk
    ,input rst

    ,input  logic                           write_hdr_fifo_out_rd_val
    ,input  logic                           write_hdr_fifo_out_rd_data_last
    ,output logic                           out_write_hdr_fifo_rd_rdy

    ,output logic                           out_condense_entries_wr_val
    ,output logic                           out_condense_entries_wr_last
    ,input  logic                           condense_entries_out_wr_rdy    
    
    ,input  logic                           condense_entries_out_rd_val
    ,input  logic                           condense_entries_out_rd_data_last
    ,output logic                           out_condense_entries_rd_rdy
    
    ,output logic                           reader_dst_data_val
    ,output logic                           reader_dst_data_last
    ,input  logic                           dst_reader_data_rdy

    ,output logic                           out_reset_entry_addr
    ,output logic                           out_incr_entry_addr
    ,output logic                           save_last_entry_line
    ,output logic                           reuse_entry_line
    ,output logic                           output_done
    
    ,input  logic                           last_entry_out
);

    typedef enum logic [1:0] {
        READY = 2'd0,
        WRITE_ENTRY = 2'd1,
        DRAIN = 2'd2,
        REUSE_LAST_LINE = 2'd3,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    assign output_done = state_reg == READY;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    always_comb begin
        out_reset_entry_addr = 1'b0;
        out_incr_entry_addr = 1'b0;

        out_write_hdr_fifo_rd_rdy = 1'b0;
        out_condense_entries_wr_val = 1'b0;
        
        out_condense_entries_rd_rdy = 1'b0;
        reader_dst_data_val = 1'b0;
        reader_dst_data_last = 1'b0;
        
        save_last_entry_line = 1'b0;

        reuse_entry_line = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                out_reset_entry_addr = 1'b1;
                if (write_hdr_fifo_out_rd_val) begin
                    state_next = WRITE_ENTRY;
                end
            end
            WRITE_ENTRY: begin
                out_condense_entries_wr_val = write_hdr_fifo_out_rd_val;
                out_condense_entries_wr_last = write_hdr_fifo_out_rd_data_last;
                out_write_hdr_fifo_rd_rdy = condense_entries_out_wr_rdy;
                reader_dst_data_val = condense_entries_out_rd_val;
                out_condense_entries_rd_rdy = dst_reader_data_rdy;

                if (write_hdr_fifo_out_rd_val & condense_entries_out_wr_rdy) begin
                    if (write_hdr_fifo_out_rd_data_last) begin
                        state_next = DRAIN;
                    end
                end
            end
            DRAIN: begin
                if (condense_entries_out_rd_val) begin
                    if (last_entry_out) begin
                        reader_dst_data_val = condense_entries_out_rd_val;
                        reader_dst_data_last = condense_entries_out_rd_data_last;
                        out_condense_entries_rd_rdy = dst_reader_data_rdy;
                        if (condense_entries_out_rd_val 
                            & dst_reader_data_rdy 
                            & condense_entries_out_rd_data_last) begin
                            state_next = READY;
                        end
                    end
                    else begin
                        if (condense_entries_out_rd_data_last) begin
                            out_incr_entry_addr = 1'b1;
                            out_write_hdr_fifo_rd_rdy = 1'b1;
                            save_last_entry_line = 1'b1;
                            state_next = REUSE_LAST_LINE;
                        end
                        else begin
                            reader_dst_data_val = condense_entries_out_rd_val;
                            out_condense_entries_rd_rdy = dst_reader_data_rdy;
                        end
                    end
                end
            end
            REUSE_LAST_LINE: begin
                reuse_entry_line = 1'b1;
                out_condense_entries_wr_val = 1'b1;
                if (condense_entries_out_wr_rdy) begin
                    state_next = WRITE_ENTRY;
                end
            end
            default: begin
                out_reset_entry_addr = 'X;
                out_incr_entry_addr = 'X;

                out_write_hdr_fifo_rd_rdy = 'X;
                out_condense_entries_wr_val = 'X;
                
                save_last_entry_line = 'X;

                reuse_entry_line = 'X;

                state_next = UND;
            end
        endcase
    end
endmodule
