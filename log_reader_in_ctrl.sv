module log_reader_in_ctrl (
     input clk
    ,input rst
    
    ,input  logic                           src_reader_req_val
    ,output logic                           reader_src_req_rdy

    ,output logic                           reader_log_hdr_mem_rd_req_val
    ,input  logic                           log_hdr_mem_reader_rd_req_rdy

    ,input  logic                           log_hdr_mem_reader_rd_resp_val
    ,output logic                           reader_log_hdr_mem_rd_resp_rdy

    ,output logic                           reader_log_data_mem_rd_req_val
    ,input  logic                           log_data_mem_reader_rd_req_rdy

    ,input  logic                           log_data_mem_reader_rd_resp_val
    ,output logic                           reader_log_data_mem_rd_resp_rdy

    ,output logic                           in_write_hdr_fifo_wr_val
    ,output logic                           in_write_hdr_wr_entry_hdr
    ,input  logic                           write_hdr_fifo_in_wr_rdy

    ,output logic                           store_last_view
    ,output logic                           store_req_info
    ,output logic                           store_log_hdr
    ,output logic                           store_data_line
    ,output logic                           incr_log_resp_size
    ,output logic                           reset_in_hdr_rd_addr
    ,output logic                           incr_in_hdr_rd_addr
    ,output logic                           reset_in_data_rd_addr
    ,output logic                           incr_in_data_rd_addr

    ,input  logic                           output_done
    ,input  logic                           last_hdr_in_rd
    ,input  logic                           last_data_in_rd
);

    typedef enum logic[2:0] {
        READY = 3'd0,
        READ_HDR = 3'd3, 
        STORE_HDR = 3'd4,
        WR_ENTRY_HDR = 3'd5,
        READ_DATA = 3'd6,
        STORE_DATA = 3'd6,
        WR_FIFO = 3'd6,
        WAIT_OUT = 3'd7,
        UND = 'X
    } state_e;

    state_e  state_reg;
    state_e  state_next;

    logic   size_pass_reg;
    logic   size_pass_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            size_pass_reg <= size_pass_next;
        end
    end

    always_comb begin
        reader_src_req_rdy = 1'b0;
        reader_log_hdr_mem_rd_req_val = 1'b0;
        reader_log_hdr_mem_rd_resp_rdy = 1'b0;
        reader_log_data_mem_rd_req_val = 1'b0;
        reader_log_data_mem_rd_resp_rdy = 1'b0;

        store_req_info = 1'b0;
        store_log_hdr = 1'b0;
        store_data_line = 1'b0;

        in_write_hdr_fifo_wr_val = 1'b0;
        in_write_hdr_wr_entry_hdr = 1'b0;

        incr_in_hdr_rd_addr = 1'b0;
        reset_in_hdr_rd_addr = 1'b0;
        incr_log_resp_size = 1'b0;
        reset_in_data_rd_addr = 1'b0;
        incr_in_data_rd_addr = 1'b0;

        size_pass_next = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                reader_src_req_rdy = 1'b1;
                store_req_info = 1'b1;
                size_pass_next = 1'b1;
                reset_in_hdr_rd_addr = 1'b1;
                if (src_reader_req_val) begin
                    state_next = READ_HDR;
                end
            end
            READ_HDR: begin
                reader_log_hdr_mem_rd_req_val = 1'b1;
                if (log_hdr_mem_reader_rd_req_rdy) begin
                    state_next = STORE_HDR;
                end
            end
            STORE_HDR: begin
                store_log_hdr = 1'b1;
                reader_log_hdr_mem_rd_resp_rdy = 1'b1;
                reset_in_data_rd_addr = 1'b1;
                if (log_hdr_mem_reader_rd_resp_val) begin
                    incr_in_hdr_rd_addr = 1'b1;
                    if (size_pass_reg) begin
                        state_next = READ_HDR;
                        if (last_hdr_in_rd) begin
                            reset_in_hdr_rd_addr = 1'b1;
                            store_last_view = 1'b1;
                            size_pass_next = 1'b0;
                        end
                    end
                    else begin
                        state_next = WR_ENTRY_HDR;
                    end
                end
            end
            WR_ENTRY_HDR: begin
                in_write_hdr_wr_entry_hdr = 1'b1;
                in_write_hdr_fifo_wr_val = 1'b1;
                if (write_hdr_fifo_in_wr_rdy) begin
                    state_next = READ_DATA;
                end
            end
            READ_DATA: begin
                reader_log_hdr_mem_rd_req_val = 1'b1;
                if (log_hdr_mem_reader_rd_req_rdy) begin
                    state_next = WR_FIFO;
                end
            end
            STORE_DATA: begin
                store_data_line = 1'b1;
                reader_log_data_mem_rd_resp_rdy = 1'b1;
                if (log_hdr_mem_reader_rd_resp_val) begin
                    state_next = WR_FIFO;
                end
            end
            WR_FIFO: begin
                in_write_hdr_fifo_wr_val = 1'b1;
                if (write_hdr_fifo_in_wr_rdy) begin
                    incr_in_data_rd_addr = 1'b1;
                    if (last_data_in_rd) begin
                        if (last_hdr_in_rd) begin
                            state_next = WAIT_OUT;
                        end
                        else begin
                            state_next = READ_HDR;
                        end
                    end
                    else begin
                        state_next = READ_DATA;
                    end
                end
            end
            WAIT_OUT: begin
                if (output_done) begin
                    state_next = READY;
                end
            end
            default: begin
                reader_src_req_rdy = 'X;
                reader_log_hdr_mem_rd_req_val = 'X;
                reader_log_hdr_mem_rd_resp_rdy = 'X;
                reader_log_data_mem_rd_req_val = 'X;
                reader_log_data_mem_rd_resp_rdy = 'X;

                store_req_info = 'X;
                store_log_hdr = 'X;
                store_data_line = 'X;

                in_write_hdr_fifo_wr_val = 'X;
                in_write_hdr_wr_entry_hdr = 'X;

                incr_in_hdr_rd_addr = 'X;
                reset_in_hdr_rd_addr = 'X;
                incr_log_resp_size = 'X;
                reset_in_data_rd_addr = 'X;
                incr_in_data_rd_addr = 'X;

                size_pass_next = 'X;

                state_next = UND;
            end
        endcase
    end
endmodule
