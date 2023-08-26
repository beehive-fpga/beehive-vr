// FIXME: Needs batching implemented

module prepare_datap 
import beehive_udp_msg::*;
import beehive_vr_pkg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst
    
    // metadata bus in
    ,input  udp_info                        manage_prep_pkt_info

    // data bus in
    ,input  logic   [NOC_DATA_W-1:0]        manage_prep_req

    // state read
    ,input  vr_state                        vr_state_prep_rd_resp_data

    // state write
    ,output vr_state                        prep_vr_state_wr_data
    
    // log entry bus out
    ,output logic   [LOG_DEPTH_W-1:0]       prep_log_data_mem_wr_addr
    
    ,output logic   [LOG_HDR_DEPTH_W-1:0]   prep_log_hdr_mem_wr_addr
    ,output log_entry_hdr                   prep_log_hdr_mem_wr_data

    ,output logic   [LOG_HDR_DEPTH_W-1:0]   prep_log_hdr_mem_rd_req_addr

    ,input  log_entry_hdr                   log_hdr_mem_prep_rd_resp_data

    ,output udp_info                        prep_to_udp_meta_info

    ,output logic   [NOC_DATA_W-1:0]        prep_to_udp_data
    ,output logic   [NOC_PADBYTES_W-1:0]    prep_to_udp_data_padbytes
    
    ,input  logic                           ctrl_datap_store_info 
    ,input  logic                           log_ctrl_datap_incr_wr_addr
    ,input  logic                           clean_ctrl_datap_store_hdr

    ,output logic                           datap_ctrl_prep_ok
    ,output logic                           datap_ctrl_log_has_space
    
);
    localparam PREP_OK_PADDING = NOC_DATA_W - PREPARE_OK_HDR_W - BEEHIVE_HDR_W;
    localparam NOC_DATA_BYTES = NOC_DATA_W/8;

    udp_info    udp_info_reg;
    udp_info    udp_info_next;

    prepare_msg_hdr prepare_hdr_reg;
    prepare_msg_hdr prepare_hdr_next;
    
    prepare_ok_hdr  prepare_ok_hdr_cast;
    beehive_hdr     beehive_hdr_cast;

    logic   [INT_W-1:0] entry_len_calc;
    logic   [LOG_DEPTH_W:0]   log_entry_line_cnt;

    logic   [LOG_DEPTH_W:0] space_used;
    logic   [LOG_DEPTH_W:0] space_left;

    logic   [LOG_DEPTH_W-1:0]   wr_addr_reg;
    logic   [LOG_DEPTH_W-1:0]   wr_addr_next;

    log_entry_hdr               entry_hdr_reg;
    log_entry_hdr               entry_hdr_next;
    
    logic   [LOG_HDR_DEPTH_W-1:0]   log_entry_offset;
    logic   [LOG_DEPTH_W:0]         clean_entry_line_cnt;
    logic                           clean_log;


    always_ff @(posedge clk) begin
        udp_info_reg <= udp_info_next;
        prepare_hdr_reg <= prepare_hdr_next;
        wr_addr_reg <= wr_addr_next;
        entry_hdr_reg <= entry_hdr_next;
    end

    assign log_entry_offset = prepare_hdr_reg.clean_up_to - vr_state_prep_rd_resp_data.first_log_op;
    assign prep_log_hdr_mem_rd_req_addr = vr_state_prep_rd_resp_data.hdr_log_head + log_entry_offset;

    assign clean_log = vr_state_prep_rd_resp_data.hdr_log_tail != vr_state_prep_rd_resp_data.hdr_log_head
        ? (prepare_hdr_reg.clean_up_to >= vr_state_prep_rd_resp_data.first_log_op)
            && (prepare_hdr_reg.clean_up_to <= vr_state_prep_rd_resp_data.last_commit)
        : '0;

    assign clean_entry_line_cnt = entry_hdr_reg.payload_len[LOG_W_BYTES_W-1:0] == 0
                                ? entry_hdr_reg.payload_len[LOG_W_BYTES_W-1:0] >> LOG_W_BYTES_W
                                : (entry_hdr_reg.payload_len[LOG_W_BYTES_W-1:0] >> LOG_W_BYTES_W) + 1'b1;

    assign entry_hdr_next = clean_ctrl_datap_store_hdr
                            ? log_hdr_mem_prep_rd_resp_data
                            : entry_hdr_reg;

    assign prep_log_data_mem_wr_addr = wr_addr_reg;

    assign prep_log_hdr_mem_wr_addr = vr_state_prep_rd_resp_data.hdr_log_tail;

    assign wr_addr_next = ctrl_datap_store_info
                        ? vr_state_prep_rd_resp_data.data_log_tail
                        : log_ctrl_datap_incr_wr_addr
                            ? wr_addr_reg + 1'b1
                            : wr_addr_reg;
                    
    assign udp_info_next = ctrl_datap_store_info
                        ? manage_prep_pkt_info
                           : udp_info_reg;

    assign prepare_hdr_next = ctrl_datap_store_info
                                ? manage_prep_req[NOC_DATA_W-1 -: PREPARE_MSG_HDR_W]
                                : prepare_hdr_reg;

    // the output from the manage module subtracts off the Beehive header
    assign entry_len_calc = udp_info_next.data_length - PREPARE_HDR_BYTES;
    
    assign datap_ctrl_prep_ok = (prepare_hdr_reg.view == vr_state_prep_rd_resp_data.curr_view)
                            && (prepare_hdr_reg.opnum == vr_state_prep_rd_resp_data.last_op + 1'b1);

    assign space_used = vr_state_prep_rd_resp_data.data_log_tail - vr_state_prep_rd_resp_data.data_log_head;
    assign space_left = {1'b1, {(LOG_DEPTH_W){1'b0}}} - space_used;

    assign log_entry_line_cnt = entry_len_calc[LOG_W_BYTES_W-1:0] == 0
                            ? entry_len_calc >> LOG_W_BYTES_W
                            : (entry_len_calc >> LOG_W_BYTES_W) + 1'b1;

    assign hdr_log_full = (vr_state_prep_rd_resp_data.hdr_log_tail[LOG_HDR_DEPTH_W] 
                          != vr_state_prep_rd_resp_data.hdr_log_head[LOG_HDR_DEPTH_W])
                          && (vr_state_prep_rd_resp_data.hdr_log_tail[LOG_HDR_DEPTH_W-1:0] 
                              == vr_state_prep_rd_resp_data.hdr_log_head[LOG_HDR_DEPTH_W-1:0]);
    assign datap_ctrl_log_has_space = (space_left >= log_entry_line_cnt) && (~hdr_log_full);

    logic   [PREP_OK_PADDING-1:0] padding;
    assign padding = {(PREP_OK_PADDING){1'b0}};
    assign prep_to_udp_data = {beehive_hdr_cast, prepare_ok_hdr_cast, padding};
    assign prep_to_udp_data_padbytes = PREP_OK_PADDING >> 3;

    always_comb begin
        beehive_hdr_cast = '0;
        beehive_hdr_cast.frag_num = NONFRAG_MAGIC;
        beehive_hdr_cast.msg_type = PrepareOK;
        beehive_hdr_cast.msg_len = PREPARE_OK_HDR_BYTES;
    end

    always_comb begin
        prepare_ok_hdr_cast = '0;
        prepare_ok_hdr_cast.view = prepare_hdr_reg.view;
        prepare_ok_hdr_cast.opnum = prepare_hdr_reg.opnum;
        prepare_ok_hdr_cast.rep_index = vr_state_prep_rd_resp_data.my_replica_index;
        prepare_ok_hdr_cast.last_committed = vr_state_prep_rd_resp_data.last_commit;
    end

    always_comb begin
        prep_to_udp_meta_info = '0;

        prep_to_udp_meta_info.src_ip = udp_info_reg.dst_ip;
        prep_to_udp_meta_info.dst_ip = udp_info_reg.src_ip;
        prep_to_udp_meta_info.src_port = udp_info_reg.dst_port;
        prep_to_udp_meta_info.dst_port = udp_info_reg.src_port;
        prep_to_udp_meta_info.data_length = PREPARE_OK_HDR_BYTES + BEEHIVE_HDR_BYTES; 
    end

    always_comb begin
        prep_vr_state_wr_data = vr_state_prep_rd_resp_data;
        prep_vr_state_wr_data.last_op = vr_state_prep_rd_resp_data.last_op + 1'b1;
        prep_vr_state_wr_data.hdr_log_tail = vr_state_prep_rd_resp_data.hdr_log_tail + 1'b1;
        prep_vr_state_wr_data.data_log_tail = vr_state_prep_rd_resp_data.data_log_tail + log_entry_line_cnt;
        if (clean_log) begin
            prep_vr_state_wr_data.first_log_op = prepare_hdr_reg.clean_up_to + 1'b1;
            prep_vr_state_wr_data.hdr_log_head = vr_state_prep_rd_resp_data.hdr_log_head + log_entry_offset + 1'b1;
            prep_vr_state_wr_data.data_log_head = entry_hdr_reg.payload_addr + clean_entry_line_cnt;
        end
    end

    always_comb begin
        prep_log_hdr_mem_wr_data = '0;
        prep_log_hdr_mem_wr_data.view = prepare_hdr_reg.view;
        prep_log_hdr_mem_wr_data.op_num = prepare_hdr_reg.opnum;
        prep_log_hdr_mem_wr_data.log_entry_state = LOG_STATE_PREPARED;
        prep_log_hdr_mem_wr_data.payload_addr = vr_state_prep_rd_resp_data.data_log_tail;
        prep_log_hdr_mem_wr_data.payload_len = entry_len_calc;
        prep_log_hdr_mem_wr_data.req_count = prepare_hdr_reg.req_count;
    end

endmodule
