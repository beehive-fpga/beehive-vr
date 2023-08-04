// FIXME: Needs batching implemented

module prepare_datap #(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)
    import beehive_vr_pkg::*;
(
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
    ,output logic   [LOG_DEPTH_W-1:0]       prep_log_mem_wr_addr
    
    ,input  udp_info                        prep_to_udp_meta_info

    ,input  logic   [NOC_DATA_W-1:0]        prep_to_udp_data
    ,input  logic   [NOC_PADBYTES_W-1:0]    prep_to_udp_data_padbytes

    ,output log_hdr                         datap_inserter_log_hdr
    
    ,input  logic                           ctrl_datap_store_info 
    ,input  logic                           log_ctrl_datap_incr_wr_addr

    ,output logic                           datap_ctrl_prep_ok
    ,output logic                           datap_ctrl_log_has_space
    
);
    localparam PREP_OK_PADDING = NOC_DATA_W - PREPARE_OK_HDR_W;
    localparam NOC_DATA_BYTES = NOC_DATA_W/8;

    udp_info    udp_info_reg;
    udp_info    udp_info_next;

    prepare_msg_hdr prepare_hdr_reg;
    prepare_msg_hdr prepare_hdr_next;
    
    prepare_ok_hdr  prepare_ok_hdr_cast;

    logic   [INT_W-1:0] entry_len_calc;
    logic   [LOG_DEPTH_W:0]   entry_lines;

    logic   [LOG_DEPTH_W:0] space_used;
    logic   [LOG_DEPTH_W:0] space_left;

    logic   [LOG_DEPTH_W-1:0]   wr_addr_reg;
    logic   [LOG_DEPTH_W-1:0]   wr_addr_next;

    always_ff @(posedge clk) begin
        udp_info_reg <= udp_info_next;
        prepare_hdr_reg <= prepare_hdr_next;
        wr_addr_reg <= wr_addr_next;
    end

    assign wr_addr_next = ctrl_datap_store_info
                        ? vr_state_prep_rd_resp_data.log_tail
                        : log_ctrl_datap_incr_wr_addr
                            ? wr_addr_next + 1'b1
                            : wr_addr_reg;
                    
    assign udp_info_next = ctrl_datap_store_info
                        ? manage_prep_pkt_info
                           : udp_info_reg;

    assign prepare_hdr_next = ctrl_datap_store_info
                                ? manage_prep_req[NOC_DATA_W-1 -: PREPARE_MSG_HDR_W]
                                : prepare_hdr_reg;

    // the output from the manage module subtracts off the Beehive header
    assign entry_len_calc = udp_info_reg.data_length - PREPARE_HDR_BYTES + LOG_ENTRY_BYTES;
    
    assign datap_ctrl_prep_ok = (prepare_hdr_reg.view == vr_state_prep_rd_resp_data.curr_view)
                            && (prepare_hdr_reg.opnum == vr_state_prep_rd_resp_data.last_op + 1'b1);

    assign space_used = vr_state_prep_rd_resp_data.log_tail - vr_state_prep_rd_resp_data.log_head;
    assign space_left = {1'b1, {(LOG_DEPTH_W){1'b0}}} - space_used;

    assign log_entry_line_cnt = entry_len_calc[LOG_W_BYTES_W-1:0] == 0
                            ? entry_len_calc >> LOG_W_BYTES_W
                            : (entry_len_calc >> LOG_W_BYTES_W) + 1'b1;
    assign datap_ctrl_log_has_space = space_left >= log_entry_line_cnt;

    assign prep_to_udp_data = {prepare_ok_hdr_cast, {(PREP_OK_PADDING){1'b0}}};
    assign prep_to_udp_data_padbytes = NOC_DATA_BYTES - PREPARE_OK_HDR_BYTES;

    always_comb begin
        prepare_ok_hdr_cast = '0;
        prepare_ok_hdr_cast.view = prepare_hdr_reg.view;
        prepare_ok_hdr_cast.opnum = prepare_hdr_reg.opnum;
        prepare_ok_hdr_cast.rep_index = vr_state_prep_rd_resp_data.my_replica_index;
    end

    always_comb begin
        prep_to_udp_meta_info = '0;

        prep_to_udp_meta_info.src_ip = udp_info_reg.dst_ip;
        prep_to_udp_meta_info.dst_ip = udp_info_reg.src_ip;
        prep_to_udp_meta_info.src_port = udp_info_reg.dst_port;
        prep_to_udp_meta_info.dst_port = udp_info_reg.src_port;
        prep_to_udp_meta_info.data_length = PREPARE_OK_HDR_BYTES; 
    end

    always_comb begin
        prep_vr_state_wr_data = vr_state_prep_rd_resp_data;
        prep_vr_state_wr_data.last_op = vr_state_prep_rd_resp_data.last_op + 1'b1;
        prep_vr_state_wr_data.log_tail = vr_state_prep_rd_resp_data.log_tail + entry_lines;
    end

endmodule