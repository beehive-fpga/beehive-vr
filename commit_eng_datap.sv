module commit_eng_datap 
import beehive_vr_pkg::*;
import beehive_udp_msg::*;
#(
    parameter NOC_DATA_W = -1
)(
     input clk
    ,input rst
    
    ,input  udp_info                        manage_commit_pkt_info
    
    // data bus in
    ,input  logic   [NOC_DATA_W-1:0]        manage_commit_req
    
    // state read
    ,input  vr_state                        vr_state_commit_rd_resp_data

    // state write
    ,output vr_state                        commit_vr_state_wr_data

    // log entry rd bus
    ,output logic   [LOG_DEPTH_W-1:0]       commit_log_mem_rd_req_addr

    ,input  logic   [NOC_DATA_W-1:0]        log_mem_commit_rd_resp_data
    
    // log entry bus out
    ,output logic   [NOC_DATA_W-1:0]        commit_log_mem_wr_data
    ,output logic   [LOG_DEPTH_W-1:0]       commit_log_mem_wr_addr
    
    ,input  logic                           ctrl_datap_store_msg
    ,input  logic                           ctrl_datap_store_state
    ,input  logic                           ctrl_datap_store_log_entry
    ,input  logic                           ctrl_datap_calc_next_entry
    
    ,output logic                           datap_ctrl_commit_ok
    ,output logic                           datap_ctrl_last_commit
);

    localparam NOC_BYTES = NOC_DATA_W/8;
    localparam NOC_BYTES_W = $clog2(NOC_BYTES);

    commit_msg_hdr  hdr_reg;
    commit_msg_hdr  hdr_next;
    
    vr_state        vr_state_reg;
    vr_state        vr_state_next;
    vr_state        vr_state_new;

    log_entry_hdr   log_entry_hdr_cast;
    log_entry_hdr   log_entry_hdr_new;

    logic   [NOC_DATA_W-1:0]    log_entry_hdr_line_reg;
    logic   [NOC_DATA_W-1:0]    log_entry_hdr_line_next;

    logic   [LOG_DEPTH_W-1:0]   log_entry_line_cnt;

    logic   [LOG_DEPTH_W-1:0]   curr_log_addr_reg;
    logic   [LOG_DEPTH_W-1:0]   curr_log_addr_next;
    logic   [LOG_DEPTH_W-1:0]   next_log_addr;

    always_ff @(posedge clk) begin
        hdr_reg <= hdr_next;
        vr_state_reg <= vr_state_next;
        log_entry_hdr_line_reg <= log_entry_hdr_line_next;
        curr_log_addr_reg <= curr_log_addr_next;
    end

    assign log_entry_hdr_cast = log_entry_hdr_line_reg[NOC_DATA_W-1 -: LOG_ENTRY_HDR_W];

    assign commit_log_mem_rd_req_addr = curr_log_addr_reg;

    always_comb begin
        vr_state_new = vr_state_reg;
        vr_state_new.last_commit = hdr_reg.opnum;
        vr_state_new.log_head = curr_log_addr_reg;
    end

    assign commit_vr_state_wr_data = vr_state_new;

    always_comb begin
        log_entry_hdr_new = log_entry_hdr_cast;
        log_entry_hdr_new.log_entry_state = LOG_STATE_COMMITED;
    end

    // is it an even number of lines?
    assign log_entry_line_cnt = log_entry_hdr_cast.entry_len[NOC_BYTES_W-1:0] == 0
                                ? log_entry_hdr_cast.entry_len >> NOC_BYTES_W
                                // if there's extra space, just align to the next line
                                : (log_entry_hdr_cast.entry_len >> NOC_BYTES_W) + 1'b1;

    assign commit_log_mem_wr_addr = curr_log_addr_reg;

    assign commit_log_mem_wr_data = {log_entry_hdr_new, log_entry_hdr_line_reg[NOC_DATA_W - LOG_ENTRY_HDR_W - 1:0]};

    assign curr_log_addr_next = ctrl_datap_store_state
                                ? vr_state_next.log_head
                                : ctrl_datap_calc_next_entry
                                    ? curr_log_addr_reg + log_entry_line_cnt
                                    : curr_log_addr_reg;
                                

    assign hdr_next = ctrl_datap_store_msg
                    ? manage_commit_req[NOC_DATA_W-1 -: COMMIT_MSG_HDR_W]
                    : hdr_reg;

    assign vr_state_next = ctrl_datap_store_state
                        ? vr_state_commit_rd_resp_data
                        : vr_state_reg;

    assign log_entry_hdr_line_next = ctrl_datap_store_log_entry
                                    ? log_mem_commit_rd_resp_data
                                    : log_entry_hdr_line_reg;

    // for the commit to be good, we need to be in the right view
    // we also need the commit op number to be larger than last commit but smaller than last op
    assign datap_ctrl_commit_ok = (hdr_reg.view == vr_state_reg.curr_view)
                            && (hdr_reg.opnum > vr_state_reg.last_commit)
                            && (hdr_reg.opnum <= vr_state_reg.last_op);

    assign datap_ctrl_last_commit = log_entry_hdr_cast.op_num == hdr_reg.opnum;
                        
endmodule
