// FIXME: the multiplexing of the UDP output bus is super janky
// currently it relies on the fact we only process one message at a time
// it should probably use a val-ready interface insteadG
`include "packet_defs.vh"
module view_change_eng 
import beehive_vr_pkg::*;
import beehive_udp_msg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst

    ,input [CONFIG_NODE_CNT_W-1:0]          node_count_reg

    // metadata bus in
    ,input  logic                           manage_vc_msg_val
    ,input  udp_info                        manage_vc_pkt_info
    ,output logic                           vc_manage_msg_rdy

    // data bus in
    ,input  logic                           manage_vc_req_val
    ,input  msg_type                        manage_vc_msg_type
    ,input  logic   [NOC_DATA_W-1:0]        manage_vc_req
    ,input  logic                           manage_vc_req_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    manage_vc_req_padbytes
    ,output logic                           vc_manage_req_rdy

    // state read
    ,input  vr_state                        vr_state_vc_rd_resp_data

    ,output logic                           vc_vr_state_wr_req
    ,input  logic                           vr_state_vc_wr_req_rdy
    ,output vr_state                        vc_vr_state_wr_req_data

    ,input  machine_tuple                   our_tuple
    
    ,output logic                           vc_log_hdr_mem_rd_req_val
    ,output logic   [LOG_HDR_DEPTH_W-1:0]   vc_log_hdr_mem_rd_req_addr
    ,input  logic                           log_hdr_mem_vc_rd_req_rdy

    ,input  logic                           log_hdr_mem_vc_rd_resp_val
    ,input  log_entry_hdr                   log_hdr_mem_vc_rd_resp_data
    ,output logic                           vc_log_hdr_mem_rd_resp_rdy
    
    ,output logic                           vc_log_data_mem_rd_req_val
    ,output logic   [LOG_DEPTH_W-1:0]       vc_log_data_mem_rd_req_addr
    ,input  logic                           log_data_mem_vc_rd_req_rdy

    ,input  logic                           log_data_mem_vc_rd_resp_val
    ,input  logic   [NOC_DATA_W-1:0]        log_data_mem_vc_rd_resp_data
    ,output logic                           vc_log_data_mem_rd_resp_rdy

    ,output logic                           vc_log_hdr_mem_wr_val
    ,output log_entry_hdr                   vc_log_hdr_mem_wr_data
    ,output logic   [LOG_HDR_DEPTH_W-1:0]   vc_log_hdr_mem_wr_addr
    ,input  logic                           log_hdr_mem_vc_wr_rdy

    ,output logic                           vc_log_data_mem_wr_val
    ,output logic   [NOC_DATA_W-1:0]        vc_log_data_mem_wr_data
    ,output logic   [LOG_DEPTH_W-1:0]       vc_log_data_mem_wr_addr
    ,input  logic                           log_data_mem_vc_wr_rdy

    ,output logic                           config_ram_rd_req_val
    ,output logic   [CONFIG_ADDR_W-1:0]     config_ram_rd_req_addr

    ,input  machine_tuple                   config_ram_rd_resp_data
    
    ,output logic                           vc_to_udp_meta_val
    ,output udp_info                        vc_to_udp_meta_info
    ,input  logic                           to_udp_vc_meta_rdy

    ,output logic                           vc_to_udp_data_val
    ,output logic   [NOC_DATA_W-1:0]        vc_to_udp_data
    ,output logic   [NOC_PADBYTES_W-1:0]    vc_to_udp_data_padbytes
    ,output logic                           vc_to_udp_data_last
    ,input  logic                           to_udp_vc_data_rdy

    ,output logic                           vc_engine_rdy
);

    localparam START_CHANGE_PADDING = NOC_DATA_W - START_VIEW_CHANGE_HDR_W - BEEHIVE_HDR_W;
    localparam LOG_PADBYTES_W = LOG_W_BYTES_W;

    typedef struct packed {
        logic   [NOC_DATA_W-1:0]   data;
        logic   [NOC_PADBYTES_W-1:0]   padbytes;
    } stream_struct;
    localparam STREAM_STRUCT_W = $bits(stream_struct);
    
    logic                           src_reader_req_val;
    logic   [LOG_HDR_DEPTH_W:0]     src_reader_addr_start;
    logic   [LOG_HDR_DEPTH_W:0]     src_reader_addr_end;
    logic                           reader_src_req_rdy;

    logic                           reader_dst_data_val;
    logic   [INT_W-1:0]             reader_dst_last_view;
    logic   [`UDP_LENGTH_W-1:0]     reader_dst_entries_len;
    logic   [LOG_W-1:0]             reader_dst_data;
    logic   [LOG_PADBYTES_W-1:0]    reader_dst_data_padbytes;
    logic                           reader_dst_data_last;
    logic                           dst_reader_data_rdy;
    
    logic                           insert_dst_data_val;
    logic   [NOC_DATA_W-1:0]        insert_dst_data;
    logic   [NOC_PADBYTES_W-1:0]    insert_dst_data_padbytes;
    logic                           insert_dst_data_last;
    logic                           dst_insert_data_rdy;
    
    logic                           init_do_change_state;
    logic                           decr_leader_calc;
    logic                           leader_found;
    
    logic                           do_change_to_udp_meta_val;
    udp_info                        do_change_to_udp_meta_info;
    logic                           to_udp_do_change_meta_rdy;

    logic   [`UDP_LENGTH_W-1:0]     payload_size_reg;
    logic   [`UDP_LENGTH_W-1:0]     payload_size_next;
    
    logic                           do_change_to_udp_data_val;
    logic   [NOC_DATA_W-1:0]        do_change_to_udp_data;
    logic   [NOC_PADBYTES_W-1:0]    do_change_to_udp_data_padbytes;
    logic                           do_change_to_udp_data_last;
    logic                           to_udp_do_change_data_rdy;
    
    logic                           store_do_change_size;

    logic                           store_leader_info;
    machine_tuple                   replica_info_reg;
    machine_tuple                   replica_info_next;
   
    start_view_change_hdr           start_view_change_hdr_reg;
    start_view_change_hdr           start_view_change_hdr_next;
    start_view_hdr                  start_view_hdr_reg;
    start_view_hdr                  start_view_hdr_next;
    do_view_change_hdr              do_view_change_hdr_cast;
    beehive_hdr                     beehive_hdr_cast;

    start_view_change_hdr start_view_change_cast;
    beehive_hdr           start_view_change_hdr_cast;
    
    logic                           start_change_config_ram_rd_req_val;
    logic   [CONFIG_ADDR_W-1:0]     start_change_config_ram_rd_req_addr;
    logic                           start_change_config_ram_rd_req_rdy;

    machine_tuple                   start_change_config_ram_rd_resp_data;
    
    logic                           do_change_config_ram_rd_req_val;
    logic   [CONFIG_ADDR_W-1:0]     do_change_config_ram_rd_req_addr;

    machine_tuple                   do_change_config_ram_rd_resp_data;
    
    logic                           start_change_to_udp_meta_val;
    udp_info                        start_change_to_udp_meta_info;
    logic                           to_udp_start_change_meta_rdy;
    
    logic                           start_change_to_udp_data_val;
    logic   [NOC_DATA_W-1:0]        start_change_to_udp_data;
    logic   [NOC_PADBYTES_W-1:0]    start_change_to_udp_data_padbytes;
    logic                           start_change_to_udp_data_last;
    logic                           to_udp_start_change_data_rdy;
    
    logic   start_broadcast;
    logic   broadcast_rdy;

    logic   start_change_store_config_ram_rd;

    logic   [INT_W-1:0] leader_view_calc_reg;
    logic   [INT_W-1:0] leader_view_calc_next;

    localparam COUNT_W = $clog2(MAX_CLUSTER_SIZE + 1);
    logic   [MAX_CLUSTER_SIZE-1:0]  quorum_reg;
    logic   [MAX_CLUSTER_SIZE-1:0]  quorum_next;
    logic   [COUNT_W-1:0]           num_resps;
    
    logic                           ctrl_datap_store_msg;
    logic                           ctrl_datap_store_req;
    
    logic                           ctrl_realign_data_val;
    logic                           ctrl_realign_data_last;
    logic                           realign_ctrl_data_rdy;
    
    logic                           ctrl_datap_store_new_state;
    logic                           ctrl_datap_clear_quorum_vec;
    logic                           ctrl_datap_set_quorum_vec;

    logic                           ctrl_install_start_install;

    logic                           install_ctrl_val;
    logic                           ctrl_install_rdy;

    msg_type                        msg_type_reg;
    msg_type                        msg_type_next;
    
    logic                           datap_ctrl_new_view;
    logic                           datap_ctrl_curr_view_change;
    logic                           datap_ctrl_quorum_good;
    msg_type                        datap_ctrl_msg_type;
    
    logic                           realign_install_data_val;
    logic   [NOC_DATA_W-1:0]        realign_install_data;
    logic   [NOC_PADBYTES_W-1:0]    realign_install_data_padbytes;
    logic                           realign_install_data_last;
    logic                           install_realign_data_rdy;
    
    logic                           reader_log_hdr_mem_rd_req_val;
    logic   [LOG_HDR_DEPTH_W-1:0]   reader_log_hdr_mem_rd_req_addr;
    logic                           log_hdr_mem_reader_rd_req_rdy;

    logic                           log_hdr_mem_reader_rd_resp_val;
    log_entry_hdr                   log_hdr_mem_reader_rd_resp_data;
    logic                           reader_log_hdr_mem_rd_resp_rdy;

    logic                           install_log_hdr_mem_rd_req_val;
    logic   [LOG_HDR_DEPTH_W-1:0]   install_log_hdr_mem_rd_req_addr;
    logic                           log_hdr_mem_install_rd_req_rdy;

    logic                           log_hdr_mem_install_rd_resp_val;
    log_entry_hdr                   log_hdr_mem_install_rd_resp_data;
    logic                           install_log_hdr_mem_rd_resp_rdy;
    
    logic   [LOG_HDR_DEPTH_W:0]     log_install_dst_hdr_log_tail;
    logic   [LOG_HDR_DEPTH_W:0]     log_install_dst_data_log_tail;

    vr_state                        new_state_reg;
    vr_state                        new_state_next;

    assign vc_vr_state_wr_req_data = new_state_reg;

    // FIXME: handle fragmentation correctly
    assign beehive_hdr_cast.frag_num = NONFRAG_MAGIC;
    assign beehive_hdr_cast.msg_type = DoViewChange;
    assign beehive_hdr_cast.msg_len = DO_VIEW_CHANGE_HDR_BYTES + reader_dst_entries_len;

    assign do_view_change_hdr_cast.view = start_view_change_hdr_reg.view;
    assign do_view_change_hdr_cast.last_norm_view = reader_dst_last_view;
    assign do_view_change_hdr_cast.last_op = vr_state_vc_rd_resp_data.last_op;
    assign do_view_change_hdr_cast.last_committed = vr_state_vc_rd_resp_data.last_commit;
    assign do_view_change_hdr_cast.rep_index = vr_state_vc_rd_resp_data.my_replica_index;
    assign do_view_change_hdr_cast.byte_count = reader_dst_entries_len;
  
    // use the clear signal to clear the reg if it's set (hence the not)
    // use the set signal to set a bit based on the replica index
    assign quorum_next = (quorum_reg & {MAX_CLUSTER_SIZE{~ctrl_datap_clear_quorum_vec}}) | (ctrl_datap_set_quorum_vec << start_view_change_hdr_reg.rep_index);

    bsg_popcount #(
        .width_p(MAX_CLUSTER_SIZE)
    ) resp_count (
         .i(quorum_reg  )
        ,.o(num_resps   )
    );
    assign datap_ctrl_quorum_good = num_resps >= (node_count_reg >> 1);

    assign config_ram_rd_req_val = do_change_config_ram_rd_req_val | start_change_config_ram_rd_req_rdy;
    assign start_change_config_ram_rd_req_rdy = ~do_change_config_ram_rd_req_val;

    assign config_ram_rd_req_addr = do_change_config_ram_rd_req_val
                                ? leader_view_calc_reg
                                : start_change_config_ram_rd_req_addr;

    assign replica_info_next = store_leader_info | start_change_store_config_ram_rd
                            ? config_ram_rd_resp_data
                            : replica_info_reg;

    assign msg_type_next = ctrl_datap_store_req
                        ? manage_vc_msg_type
                        : msg_type_reg;

    assign start_view_change_hdr_next = ctrl_datap_store_req
                            ? manage_vc_req[NOC_DATA_W-1 -: START_VIEW_CHANGE_HDR_W]
                            : start_view_change_hdr_reg;

    assign start_view_hdr_next = ctrl_datap_store_req
                            ? manage_vc_req[NOC_DATA_W-1 -: START_VIEW_HDR_W]
                            : start_view_hdr_reg;

    assign leader_view_calc_next = init_do_change_state
                                ? start_view_change_hdr_reg.view
                                : decr_leader_calc
                                    ? leader_view_calc_reg - node_count_reg
                                    : leader_view_calc_reg;

    assign leader_found = leader_view_calc_reg < node_count_reg;

    assign datap_ctrl_new_view = start_view_change_hdr_reg.view > vr_state_vc_rd_resp_data.curr_view;
    assign datap_ctrl_curr_view_change = vr_state_vc_rd_resp_data.curr_status == VIEW_CHANGE;
    assign datap_ctrl_msg_type = msg_type_reg;

    assign payload_size_next = store_do_change_size
                            ? reader_dst_entries_len + DO_VIEW_CHANGE_HDR_BYTES + BEEHIVE_HDR_BYTES
                            : payload_size_reg;

    always_ff @(posedge clk) begin
        leader_view_calc_reg <= leader_view_calc_next;
        start_view_change_hdr_reg <= start_view_change_hdr_next;
        start_view_hdr_reg <= start_view_hdr_next;
        replica_info_reg <= replica_info_next;

        quorum_reg <= quorum_next;
        msg_type_reg <= msg_type_next;

        payload_size_reg <= payload_size_next;

        new_state_reg <= new_state_next;
    end

    view_change_eng_ctrl overall_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.manage_vc_msg_val             (manage_vc_msg_val              )
        ,.vc_manage_msg_rdy             (vc_manage_msg_rdy              )
                                                                        
        ,.manage_vc_req_val             (manage_vc_req_val              )
        ,.manage_vc_req_last            (manage_vc_req_last             )
        ,.vc_manage_req_rdy             (vc_manage_req_rdy              )
                                                                        
        ,.vc_vr_state_wr_req            (vc_vr_state_wr_req             )
        ,.vr_state_vc_wr_req_rdy        (vr_state_vc_wr_req_rdy         )
    
        ,.vc_engine_rdy                 (vc_engine_rdy                  )
    
        ,.send_do_change_req            (send_do_change_req             )
        ,.do_change_rdy                 (do_change_rdy                  )
    
        ,.start_broadcast               (start_broadcast                )
        ,.broadcast_rdy                 (broadcast_rdy                  )
    
        ,.ctrl_realign_data_val         (ctrl_realign_data_val          )
        ,.ctrl_realign_data_last        (ctrl_realign_data_last         )
        ,.realign_ctrl_data_rdy         (realign_ctrl_data_rdy          )
    
        ,.ctrl_datap_store_msg          (ctrl_datap_store_msg           )
        ,.ctrl_datap_store_req          (ctrl_datap_store_req           )
    
        ,.ctrl_datap_store_new_state    (ctrl_datap_store_new_state     )
        ,.ctrl_datap_clear_quorum_vec   (ctrl_datap_clear_quorum_vec    )
        ,.ctrl_datap_set_quorum_vec     (ctrl_datap_set_quorum_vec      )
                                                                        
        ,.ctrl_install_start_install    (ctrl_install_start_install     )
                                                                        
        ,.install_ctrl_val              (install_ctrl_val               )
        ,.ctrl_install_rdy              (ctrl_install_rdy               )
                                                                        
        ,.datap_ctrl_new_view           (datap_ctrl_new_view            )
        ,.datap_ctrl_curr_view_change   (datap_ctrl_curr_view_change    )
        ,.datap_ctrl_quorum_good        (datap_ctrl_quorum_good         )
        ,.datap_ctrl_msg_type           (datap_ctrl_msg_type            )
    );

    do_change_ctrl do_change (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.send_do_change_req            (send_do_change_req                 )
        ,.do_change_rdy                 (do_change_rdy                      )
                                                                
        ,.init_do_change_state          (init_do_change_state               )
                                                                
        ,.src_reader_req_val            (src_reader_req_val                 )
        ,.reader_src_req_rdy            (reader_src_req_rdy                 )
                                                                
        ,.decr_leader_calc              (decr_leader_calc                   )
        ,.leader_found                  (leader_found                       )

        ,.store_leader_info             (store_leader_info                  )
        ,.config_ram_rd_req_val         (do_change_config_ram_rd_req_val    )

        ,.insert_dst_data_val           (insert_dst_data_val                )
        ,.insert_dst_data_last          (insert_dst_data_last               )
        ,.dst_insert_data_rdy           (dst_insert_data_rdy                )

        ,.do_change_to_udp_meta_val     (do_change_to_udp_meta_val          )
        ,.to_udp_do_change_meta_rdy     (to_udp_do_change_meta_rdy          )
                                                                            
        ,.do_change_to_udp_data_val     (do_change_to_udp_data_val          )
        ,.do_change_to_udp_data_last    (do_change_to_udp_data_last         )
        ,.to_udp_do_change_data_rdy     (to_udp_do_change_data_rdy          )
    
        ,.reader_dst_data_val           (reader_dst_data_val                )
        ,.store_do_change_size          (store_do_change_size               )
    );

    log_reader_uncondense reader (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_reader_req_val                (src_reader_req_val             )
        ,.src_reader_addr_start             (vr_state_vc_rd_resp_data.hdr_log_head)
        ,.src_reader_addr_end               (vr_state_vc_rd_resp_data.hdr_log_tail)
        ,.reader_src_req_rdy                (reader_src_req_rdy             )
    
        ,.reader_log_hdr_mem_rd_req_val     (reader_log_hdr_mem_rd_req_val  )
        ,.reader_log_hdr_mem_rd_req_addr    (reader_log_hdr_mem_rd_req_addr )
        ,.log_hdr_mem_reader_rd_req_rdy     (log_hdr_mem_reader_rd_req_rdy  )
                                                                            
        ,.log_hdr_mem_reader_rd_resp_val    (log_hdr_mem_reader_rd_resp_val )
        ,.log_hdr_mem_reader_rd_resp_data   (log_hdr_mem_reader_rd_resp_data)
        ,.reader_log_hdr_mem_rd_resp_rdy    (reader_log_hdr_mem_rd_resp_rdy )
    
        ,.reader_log_data_mem_rd_req_val    (vc_log_data_mem_rd_req_val     )
        ,.reader_log_data_mem_rd_req_addr   (vc_log_data_mem_rd_req_addr    )
        ,.log_data_mem_reader_rd_req_rdy    (log_data_mem_vc_rd_req_rdy     )
    
        ,.log_data_mem_reader_rd_resp_val   (log_data_mem_vc_rd_resp_val    )
        ,.log_data_mem_reader_rd_resp_data  (log_data_mem_vc_rd_resp_data   )
        ,.reader_log_data_mem_rd_resp_rdy   (vc_log_data_mem_rd_resp_rdy    )
    
        ,.reader_dst_data_val               (reader_dst_data_val            )
        ,.reader_dst_last_view              (reader_dst_last_view           )
        ,.reader_dst_entries_len            (reader_dst_entries_len         )
        ,.reader_dst_data                   (reader_dst_data                )
        ,.reader_dst_data_padbytes          (reader_dst_data_padbytes       )
        ,.reader_dst_data_last              (reader_dst_data_last           )
        ,.dst_reader_data_rdy               (dst_reader_data_rdy            )
    );

    inserter_compile #(
         .INSERT_W       (BEEHIVE_HDR_W + DO_VIEW_CHANGE_HDR_W)
        ,.DATA_W         (NOC_DATA_W    )
    ) hdr_insert (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.insert_data               ({beehive_hdr_cast, do_view_change_hdr_cast})
        
        ,.src_insert_data_val       (reader_dst_data_val        )
        ,.src_insert_data           (reader_dst_data            )
        ,.src_insert_data_padbytes  (reader_dst_data_padbytes   )
        ,.src_insert_data_last      (reader_dst_data_last       )
        ,.insert_src_data_rdy       (dst_reader_data_rdy        )
    
        ,.insert_dst_data_val       (insert_dst_data_val        )
        ,.insert_dst_data           (insert_dst_data            )
        ,.insert_dst_data_padbytes  (insert_dst_data_padbytes   )
        ,.insert_dst_data_last      (insert_dst_data_last       )
        ,.dst_insert_data_rdy       (dst_insert_data_rdy        )
    );


    start_change_broadcast start_change_broadcast (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.cluster_size                  (node_count_reg                             )
        ,.my_index                      (vr_state_vc_rd_resp_data.my_replica_index  )
    
        ,.start_broadcast               (start_broadcast                            )
        ,.broadcast_rdy                 (broadcast_rdy                              )
    
        ,.config_ram_rd_req             (start_change_config_ram_rd_req_val         )
        ,.config_ram_rd_req_addr        (start_change_config_ram_rd_req_addr        )
        ,.config_ram_rd_req_rdy         (start_change_config_ram_rd_req_rdy         )
        
        ,.start_change_to_udp_meta_val  (start_change_to_udp_meta_val               )
        ,.to_udp_start_change_meta_rdy  (to_udp_start_change_meta_rdy               )
                                                                                    
        ,.start_change_to_udp_data_val  (start_change_to_udp_data_val               )
        ,.start_change_to_udp_data_last (start_change_to_udp_data_last              )
        ,.to_udp_start_change_data_rdy  (to_udp_start_change_data_rdy               )
    
        ,.store_config_ram_rd           (start_change_store_config_ram_rd           )
    );

    assign do_change_to_udp_data_padbytes = insert_dst_data_padbytes;
    assign do_change_to_udp_data = insert_dst_data;

    assign start_view_change_hdr_cast.frag_num = NONFRAG_MAGIC;
    assign start_view_change_hdr_cast.msg_type = StartViewChange;
    assign start_view_change_hdr_cast.msg_len = START_VIEW_CHANGE_HDR_BYTES;
    assign start_view_change_cast.view = start_view_change_hdr_reg.view;
    assign start_view_change_cast.rep_index = vr_state_vc_rd_resp_data.my_replica_index;
    assign start_view_change_cast.last_committed = vr_state_vc_rd_resp_data.last_commit;

    realign_compile #(
         .REALIGN_W     (START_VIEW_HDR_W   )
        ,.DATA_W        (NOC_DATA_W         )
        ,.BUF_STAGES    (4)
    ) start_view_strip (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_realign_data_val      (ctrl_realign_data_val          )
        ,.src_realign_data          (manage_vc_req                  )
        ,.src_realign_data_padbytes (manage_vc_req_padbytes         )
        ,.src_realign_data_last     (ctrl_realign_data_last         )
        ,.realign_src_data_rdy      (realign_ctrl_data_rdy          )
    
        ,.realign_dst_data_val      (realign_install_data_val       )
        ,.realign_dst_data          (realign_install_data           )
        ,.realign_dst_data_padbytes (realign_install_data_padbytes  )
        ,.realign_dst_data_last     (realign_install_data_last      )
        ,.dst_realign_data_rdy      (install_realign_data_rdy       )
    
        ,.realign_dst_removed_data ()
    );

    
    log_install_uncondense #(
        .NOC_DATA_W (NOC_DATA_W )
    ) installer (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.start_log_install               (ctrl_install_start_install               )
        ,.first_log_op                    (vr_state_vc_rd_resp_data.first_log_op    )
        ,.log_hdr_ptr                     (vr_state_vc_rd_resp_data.hdr_log_head    )
        ,.log_tail_ptr                    (vr_state_vc_rd_resp_data.hdr_log_tail    )
        ,.log_data_tail_ptr               (vr_state_vc_rd_resp_data.data_log_tail   )

        ,.src_install_req_val             (realign_install_data_val                 )
        ,.src_install_req                 (realign_install_data                     )
        ,.src_install_req_last            (realign_install_data_last                )
        ,.src_install_req_padbytes        (realign_install_data_padbytes            )
        ,.install_src_req_rdy             (install_realign_data_rdy                 )
        
        ,.install_log_hdr_mem_rd_req_val  (install_log_hdr_mem_rd_req_val           )
        ,.install_log_hdr_mem_rd_req_addr (install_log_hdr_mem_rd_req_addr          )
        ,.log_hdr_mem_install_rd_req_rdy  (log_hdr_mem_install_rd_req_rdy           )
                                                                                    
        ,.log_hdr_mem_install_rd_resp_val (log_hdr_mem_install_rd_resp_val          )
        ,.log_hdr_mem_install_rd_resp_data(log_hdr_mem_install_rd_resp_data         )
        ,.install_log_hdr_mem_rd_resp_rdy (install_log_hdr_mem_rd_resp_rdy          )
        
        ,.install_log_hdr_mem_wr_val      (vc_log_hdr_mem_wr_val                    )
        ,.install_log_hdr_mem_wr_data     (vc_log_hdr_mem_wr_data                   )
        ,.install_log_hdr_mem_wr_addr     (vc_log_hdr_mem_wr_addr                   )
        ,.log_hdr_mem_install_wr_rdy      (log_hdr_mem_vc_wr_rdy                    )

        ,.install_log_data_mem_wr_val     (vc_log_data_mem_wr_val                   )
        ,.install_log_data_mem_wr_data    (vc_log_data_mem_wr_data                  )
        ,.install_log_data_mem_wr_addr    (vc_log_data_mem_wr_addr                  )
        ,.log_data_mem_install_wr_rdy     (log_data_mem_vc_wr_rdy                   )
        
        ,.log_install_dst_val             (install_ctrl_val                         )
        ,.log_install_dst_hdr_log_tail    (log_install_dst_hdr_log_tail             )
        ,.log_install_dst_data_log_tail   (log_install_dst_data_log_tail            )
        ,.dst_log_install_rdy             (ctrl_install_rdy                         )
    );
    
    mem_mux #(
         .ADDR_W    (LOG_HDR_DEPTH_W    )
        ,.DATA_W    (LOG_ENTRY_HDR_W    )
    ) hdr_mem_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_rd_req_val  (reader_log_hdr_mem_rd_req_val   )
        ,.src0_rd_req_addr (reader_log_hdr_mem_rd_req_addr  )
        ,.src0_rd_req_rdy  (log_hdr_mem_reader_rd_req_rdy   )
        
        ,.src0_rd_resp_val (log_hdr_mem_reader_rd_resp_val  )
        ,.src0_rd_resp_data(log_hdr_mem_reader_rd_resp_data )
        ,.src0_rd_resp_rdy (reader_log_hdr_mem_rd_resp_rdy  )
        
        ,.src1_rd_req_val  (install_log_hdr_mem_rd_req_val  )
        ,.src1_rd_req_addr (install_log_hdr_mem_rd_req_addr )
        ,.src1_rd_req_rdy  (log_hdr_mem_install_rd_req_rdy  )
        
        ,.src1_rd_resp_val (log_hdr_mem_install_rd_resp_val )
        ,.src1_rd_resp_data(log_hdr_mem_install_rd_resp_data)
        ,.src1_rd_resp_rdy (install_log_hdr_mem_rd_resp_rdy )
    
        ,.dst_rd_req_val   (vc_log_hdr_mem_rd_req_val       )
        ,.dst_rd_req_addr  (vc_log_hdr_mem_rd_req_addr      )
        ,.dst_rd_req_rdy   (log_hdr_mem_vc_rd_req_rdy       )
        
        ,.dst_rd_resp_val  (log_hdr_mem_vc_rd_resp_val      )
        ,.dst_rd_resp_data (log_hdr_mem_vc_rd_resp_data     )
        ,.dst_rd_resp_rdy  (vc_log_hdr_mem_rd_resp_rdy      )
    );

    always_comb begin
        new_state_next = new_state_reg;
        if (ctrl_datap_store_new_state) begin
            if (msg_type_reg == StartViewChange) begin
                new_state_next = vr_state_vc_rd_resp_data;
                new_state_next.curr_status =  VIEW_CHANGE;
                new_state_next.curr_view = start_view_change_hdr_reg.view;
            end
            else begin
                new_state_next = vr_state_vc_rd_resp_data;
                new_state_next.curr_status = NORMAL;
                new_state_next.curr_view = start_view_hdr_reg.view;
                new_state_next.hdr_log_tail = log_install_dst_hdr_log_tail;
                new_state_next.data_log_tail = log_install_dst_data_log_tail;
            end
        end
    end
/*********************************************
 * FIXME: ugly multiplexing
 ********************************************/

    assign start_change_to_udp_data = {start_view_change_hdr_cast, start_view_change_cast, {(START_CHANGE_PADDING){1'b0}}};
    assign start_change_to_udp_data_padbytes = START_CHANGE_PADDING >> 3;

    assign vc_to_udp_meta_val = start_change_to_udp_meta_val | do_change_to_udp_meta_val;

    assign to_udp_do_change_meta_rdy = to_udp_vc_meta_rdy & do_change_to_udp_meta_val;
    assign to_udp_start_change_meta_rdy = to_udp_vc_meta_rdy & start_change_to_udp_meta_val;

    assign vc_to_udp_meta_info.src_ip = our_tuple.ip_addr;
    assign vc_to_udp_meta_info.src_port = our_tuple.port_num;
    assign vc_to_udp_meta_info.dst_ip = replica_info_reg.ip_addr;
    assign vc_to_udp_meta_info.dst_port = replica_info_reg.port_num;
    assign vc_to_udp_meta_info.data_length = do_change_to_udp_meta_val
                                ? payload_size_reg
                                : BEEHIVE_HDR_BYTES + START_VIEW_CHANGE_HDR_BYTES;

    stream_struct do_change_udp_out_mux_data;
    stream_struct start_change_udp_out_mux_data;
    stream_struct udp_out_mux_dst_data; 

    assign do_change_udp_out_mux_data.data = do_change_to_udp_data;
    assign do_change_udp_out_mux_data.padbytes = do_change_to_udp_data_padbytes;
    assign start_change_udp_out_mux_data.data = start_change_to_udp_data;
    assign start_change_udp_out_mux_data.padbytes = start_change_to_udp_data_padbytes;

    assign vc_to_udp_data = udp_out_mux_dst_data.data;
    assign vc_to_udp_data_padbytes = udp_out_mux_dst_data.padbytes;

    stream_mux #(
         .NUM_SRCS  (2)
        ,.DATA_W    (STREAM_STRUCT_W    )
    ) udp_out_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.mux_dst_val  (vc_to_udp_data_val  )
        ,.mux_dst_last (vc_to_udp_data_last )
        ,.mux_dst_data (udp_out_mux_dst_data)
        ,.dst_mux_rdy  (to_udp_vc_data_rdy  )
         
        ,.src_mux_vals ({do_change_to_udp_data_val, start_change_to_udp_data_val})
        ,.src_mux_lasts({do_change_to_udp_data_last, start_change_to_udp_data_last})
        ,.src_mux_datas({do_change_udp_out_mux_data, start_change_udp_out_mux_data})
        ,.mux_src_rdys ({to_udp_do_change_data_rdy, to_udp_start_change_data_rdy})
    );



endmodule
