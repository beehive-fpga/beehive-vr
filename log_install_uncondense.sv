module log_install_uncondense  
import beehive_vr_pkg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_DATA_BYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES = NOC_DATA_BYTES
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst

    ,input                                  start_log_install
    ,input  [INT_W-1:0]                     first_log_op
    ,input  [LOG_HDR_DEPTH_W:0]             log_hdr_ptr
    ,input  [LOG_HDR_DEPTH_W:0]             log_tail_ptr
    ,input  [LOG_DEPTH_W:0]                 log_data_tail_ptr

    ,input  logic                           src_install_req_val
    ,input  logic   [NOC_DATA_W-1:0]        src_install_req
    ,input  logic                           src_install_req_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    src_install_req_padbytes
    ,output logic                           install_src_req_rdy
    
    ,output logic                           install_log_hdr_mem_rd_req_val
    ,output logic   [LOG_HDR_DEPTH_W-1:0]   install_log_hdr_mem_rd_req_addr
    ,input  logic                           log_hdr_mem_install_rd_req_rdy

    ,input  logic                           log_hdr_mem_install_rd_resp_val
    ,input  log_entry_hdr                   log_hdr_mem_install_rd_resp_data
    ,output logic                           install_log_hdr_mem_rd_resp_rdy
    
    ,output logic                           install_log_hdr_mem_wr_val
    ,output log_entry_hdr                   install_log_hdr_mem_wr_data
    ,output logic   [LOG_HDR_DEPTH_W-1:0]   install_log_hdr_mem_wr_addr
    ,input  logic                           log_hdr_mem_install_wr_rdy

    ,output logic                           install_log_data_mem_wr_val
    ,output logic   [NOC_DATA_W-1:0]        install_log_data_mem_wr_data
    ,output logic   [LOG_DEPTH_W-1:0]       install_log_data_mem_wr_addr
    ,input  logic                           log_data_mem_install_wr_rdy
    
    ,output logic                           log_install_dst_val
    ,output logic   [LOG_HDR_DEPTH_W:0]     log_install_dst_hdr_log_tail
    ,output logic   [LOG_HDR_DEPTH_W:0]     log_install_dst_data_log_tail
    ,input  logic                           dst_log_install_rdy
);

    typedef enum logic[3:0] {
        READY = 4'd0,
        STORE_IN_ENTRY_HDR = 4'd1,
        WR_LOG_ENTRY_HDR = 4'd2,
        RD_LOG_HDR_MEM = 4'd3, 
        STORE_LOG_HDR_RD = 4'd4,
        WR_LOG_ENTRY_DATA = 4'd5,
        DRAIN_DATA = 4'd6,
        CALC_DIVERGENCE = 4'd7,
        STATE_OUT = 4'd8
    } state_e;

    state_e state_reg;
    state_e state_next;
    
    logic               store_wire_entry_hdr;
    wire_log_entry_hdr  wire_entry_hdr_reg;
    wire_log_entry_hdr  wire_entry_hdr_next;

    log_entry_hdr       write_entry_hdr_cast;

    logic               store_mem_entry_hdr;
    log_entry_hdr       stored_hdr_reg;
    log_entry_hdr       stored_hdr_next;

    logic               divergence_found_reg;
    logic               divergence_found_next;

    logic                       init_inputs;
    logic                       truncate_log;
    logic                       incr_tail_ptr;

    logic   [LOG_HDR_DEPTH_W:0] hdr_ptr_reg;
    logic   [LOG_HDR_DEPTH_W:0] hdr_ptr_next;
    logic   [LOG_HDR_DEPTH_W:0] curr_ptr;
    logic   [LOG_HDR_DEPTH_W:0] entry_offset;
    logic   [LOG_HDR_DEPTH_W:0] tail_ptr_reg;
    logic   [LOG_HDR_DEPTH_W:0] tail_ptr_next;
    logic   [LOG_HDR_DEPTH_W:0] log_entries_reg;
    logic   [LOG_HDR_DEPTH_W:0] log_entries_next;


    logic                       incr_tail_data_ptr;
    logic   [LOG_DEPTH_W:0]     tail_data_ptr_reg;
    logic   [LOG_DEPTH_W:0]     tail_data_ptr_next;
    logic   [LOG_DEPTH_W:0]     log_entry_line_cnt;

    logic   [INT_W-1:0]         log_start_op_reg;
    logic   [INT_W-1:0]         log_start_op_next;

    logic   [INT_W-1:0]         log_last_op;

    logic                       op_in_range;

    logic   reset_entry_bytes_in;
    logic   incr_entry_bytes_in;
    logic   [INT_W-1:0] entry_bytes_in_reg;
    logic   [INT_W-1:0] entry_bytes_in_next;
    logic               last_entry_bytes;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
            entry_bytes_in_reg <= entry_bytes_in_next;
            wire_entry_hdr_reg <= wire_entry_hdr_next;
            stored_hdr_reg <= stored_hdr_next;
            hdr_ptr_reg <= hdr_ptr_next;
            tail_ptr_reg <= tail_ptr_next;
            tail_data_ptr_reg <= tail_data_ptr_next;
            log_entries_reg <= log_entries_next;
            log_start_op_reg <= log_start_op_next;
        end
    end

    assign entry_offset = wire_entry_hdr_reg.op_num - log_start_op_reg;

    assign curr_ptr = hdr_ptr_reg + entry_offset;

    assign install_log_hdr_mem_rd_req_addr = curr_ptr;
    assign install_log_hdr_mem_wr_addr = tail_ptr_reg;

    always_comb begin
        install_log_hdr_mem_wr_data.view = wire_entry_hdr_reg.view;
        install_log_hdr_mem_wr_data.op_num = wire_entry_hdr_reg.op_num;
        install_log_hdr_mem_wr_data.log_entry_state = wire_entry_hdr_reg.log_entry_state;
        install_log_hdr_mem_wr_data.payload_len = wire_entry_hdr_reg.request.op_bytes_len + REQUEST_HDR_BYTES;
        install_log_hdr_mem_wr_data.payload_addr = tail_data_ptr_reg;
        install_log_hdr_mem_wr_data.req_count = 1;
    end

    assign install_log_data_mem_wr_addr = tail_data_ptr_reg;
    assign install_log_data_mem_wr_data = src_install_req;

    assign log_entries_next = init_inputs
                        ? log_tail_ptr - log_hdr_ptr
                        : log_entries_reg;
    assign log_start_op_next = init_inputs
                            ? first_log_op
                            : log_start_op_reg;

    assign log_install_dst_hdr_log_tail = tail_ptr_reg;
    assign log_install_dst_data_log_tail = tail_data_ptr_reg;

    assign log_last_op = (log_start_op_reg + log_entries_reg) - 1;
   

    always_comb begin
        entry_bytes_in_next = entry_bytes_in_reg;
        if (reset_entry_bytes_in) begin
            if (incr_entry_bytes_in) begin
                entry_bytes_in_next = NOC_DATA_BYTES;
            end
            else begin
                entry_bytes_in_next = '0;
            end
        end
        else if (incr_entry_bytes_in) begin
            entry_bytes_in_next = entry_bytes_in_reg + NOC_DATA_BYTES;
        end
    end
                
    assign hdr_ptr_next = init_inputs
                        ? log_hdr_ptr
                        : hdr_ptr_reg;

    assign tail_ptr_next = init_inputs
                        ? log_tail_ptr
                        : truncate_log
                            ? curr_ptr + 1'b1
                            : incr_tail_ptr
                                ? tail_ptr_reg + 1'b1
                                : tail_ptr_reg;

    assign log_entry_line_cnt = stored_hdr_reg.payload_len[LOG_W_BYTES_W-1:0] == 0
        ? stored_hdr_reg.payload_len[LOG_W_BYTES_W-1:0] >> LOG_W_BYTES_W
        : (stored_hdr_reg.payload_len[LOG_W_BYTES_W-1:0] >> LOG_W_BYTES_W) + 1'b1;

    assign tail_data_ptr_next = init_inputs
                            ? log_data_tail_ptr
                            : truncate_log
                                ? stored_hdr_reg.payload_addr + log_entry_line_cnt
                                : incr_tail_data_ptr
                                    ? tail_data_ptr_reg + 1'b1
                                    : tail_data_ptr_reg;

    assign last_entry_bytes = (wire_entry_hdr_reg.total_size - entry_bytes_in_reg) <= NOC_DATA_BYTES;

    assign stored_hdr_next = store_mem_entry_hdr
                            ? log_hdr_mem_install_rd_resp_data
                            : stored_hdr_reg;
    assign wire_entry_hdr_next = store_wire_entry_hdr
                                ? src_install_req[NOC_DATA_W-1 -: WIRE_LOG_ENTRY_HDR_W]
                                : wire_entry_hdr_reg;

    assign op_in_range = (wire_entry_hdr_reg.op_num >= log_start_op_reg) &&
                         (wire_entry_hdr_reg.op_num <= log_last_op);

    always_comb begin
        init_inputs = 1'b0;
        reset_entry_bytes_in = 1'b0;
        incr_entry_bytes_in = 1'b0;
        store_wire_entry_hdr = 1'b0;
        store_mem_entry_hdr = 1'b0;

        incr_tail_ptr = 1'b0;
        incr_tail_data_ptr = 1'b0;
        truncate_log = 1'b0;

        install_src_req_rdy = 1'b0;
        install_log_hdr_mem_rd_req_val = 1'b0;
        install_log_hdr_mem_rd_resp_rdy = 1'b0;
        install_log_hdr_mem_wr_val = 1'b0;
        install_log_data_mem_wr_val = 1'b0;

        log_install_dst_val = 1'b0;

        divergence_found_next = 1'b0;
        state_next = state_reg;
        case (state_reg)
            READY: begin
                divergence_found_next = 1'b0;
                init_inputs = 1'b1;

                if (src_install_req_val) begin
                    state_next = STORE_IN_ENTRY_HDR;
                end
            end
            STORE_IN_ENTRY_HDR: begin
                install_src_req_rdy = 1'b1;
                reset_entry_bytes_in = 1'b1;
                store_wire_entry_hdr = 1'b1;

                if (src_install_req_val) begin
                    incr_entry_bytes_in = 1'b1;
                    if (divergence_found_reg) begin
                        state_next = WR_LOG_ENTRY_HDR;
                    end
                    else begin
                        state_next = RD_LOG_HDR_MEM;
                    end
                end
            end
            RD_LOG_HDR_MEM: begin
                if (op_in_range) begin
                    install_log_hdr_mem_rd_req_val = op_in_range;
                    if (log_hdr_mem_install_rd_req_rdy) begin
                        state_next = STORE_LOG_HDR_RD;
                    end
                end
                else begin
                    state_next = CALC_DIVERGENCE;
                end
            end
            STORE_LOG_HDR_RD: begin
                if (op_in_range) begin
                    store_mem_entry_hdr = 1'b1;
                    install_log_hdr_mem_rd_resp_rdy = 1'b1;
                    if (log_hdr_mem_install_rd_resp_val) begin
                        state_next = CALC_DIVERGENCE;
                    end
                end
                else begin
                    state_next = CALC_DIVERGENCE;
                end
            end
            CALC_DIVERGENCE: begin
                if (~op_in_range) begin
                    if (log_start_op_reg > wire_entry_hdr_reg.op_num) begin
                        state_next = DRAIN_DATA;
                    end
                    else begin
                        divergence_found_next = 1'b1;
                        state_next = WR_LOG_ENTRY_HDR;
                    end
                end
                else if (stored_hdr_reg.view != wire_entry_hdr_reg.view) begin
                    divergence_found_next = 1'b1;
                    truncate_log = 1'b1;
                    state_next = WR_LOG_ENTRY_HDR;
                end
                else begin
                    state_next = DRAIN_DATA;
                end
            end
            WR_LOG_ENTRY_HDR: begin
                install_log_hdr_mem_wr_val = 1'b1;
                if (log_hdr_mem_install_wr_rdy) begin
                    incr_tail_ptr = 1'b1;
                    state_next = WR_LOG_ENTRY_DATA;
                end
            end
            WR_LOG_ENTRY_DATA: begin
                install_log_data_mem_wr_val = src_install_req_val;
                install_src_req_rdy = log_data_mem_install_wr_rdy;
                if (src_install_req_val & log_data_mem_install_wr_rdy) begin
                    incr_entry_bytes_in = 1'b1;
                    incr_tail_data_ptr = 1'b1;
                    if (last_entry_bytes) begin
                        if (src_install_req_last) begin
                            state_next = STATE_OUT;
                        end
                        else begin
                            state_next = STORE_IN_ENTRY_HDR;
                        end
                    end
                end
            end
            DRAIN_DATA: begin
                install_src_req_rdy = 1'b1;
                if (src_install_req_val) begin
                    incr_entry_bytes_in = 1'b1;
                    if (last_entry_bytes) begin
                        if (src_install_req_last) begin
                            state_next = STATE_OUT;
                        end
                        else begin
                            state_next = STORE_IN_ENTRY_HDR;
                        end
                    end
                end
            end
            STATE_OUT: begin
                log_install_dst_val = 1'b1;
                if (dst_log_install_rdy) begin
                    state_next = READY;
                end
            end
        endcase
    end

endmodule
