module prepare_eng 
import beehive_vr_pkg::*;
import beehive_udp_msg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst

    // metadata bus in
    ,input  logic                           manage_prep_msg_val
    ,input  udp_info                        manage_prep_pkt_info
    ,output logic                           prep_manage_msg_rdy

    // data bus in
    ,input  logic                           manage_prep_req_val
    ,input  logic   [NOC_DATA_W-1:0]        manage_prep_req
    ,input  logic                           manage_prep_req_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    manage_prep_req_padbytes
    ,output logic                           prep_manage_req_rdy

    // state read
    ,input  vr_state                        vr_state_prep_rd_resp_data

    // state write
    ,output logic                           prep_vr_state_wr_req
    ,output vr_state                        prep_vr_state_wr_data
    
    // log entry bus out
    ,output logic                           prep_log_mem_wr_val
    ,output logic   [NOC_DATA_W-1:0]        prep_log_mem_wr_data
    ,output logic   [LOG_DEPTH_W-1:0]       prep_log_mem_wr_addr
    ,input  logic                           log_mem_prep_wr_rdy
    
    ,output logic                           prep_to_udp_meta_val
    ,output udp_info                        prep_to_udp_meta_info
    ,input  logic                           to_udp_prep_meta_rdy

    ,output logic                           prep_to_udp_data_val
    ,output logic   [NOC_DATA_W-1:0]        prep_to_udp_data
    ,output logic   [NOC_PADBYTES_W-1:0]    prep_to_udp_data_padbytes
    ,output logic                           prep_to_udp_data_last
    ,input  logic                           to_udp_prep_data_rdy

    ,output logic                           prep_engine_rdy
);

    log_entry_hdr                   datap_inserter_log_hdr;
    logic                           ctrl_datap_store_info;
    logic                           datap_ctrl_prep_ok;
    logic                           datap_ctrl_log_has_space;

    logic                           start_req_ingest;
    logic                           log_write_done;
    logic                           log_ctrl_datap_incr_wr_addr;
    
    logic                           log_ctrl_realign_wr_val;
    logic                           log_ctrl_realign_wr_last;
    logic                           realign_log_ctrl_wr_rdy;

    logic                           insert_log_ctrl_rd_val;
    logic                           insert_log_ctrl_rd_last;
    logic                           log_ctrl_insert_rd_rdy;
    
    logic                           realign_insert_data_val;
    logic   [NOC_DATA_W-1:0]        realign_insert_data;
    logic   [NOC_PADBYTES_W-1:0]    realign_insert_data_padbytes;
    logic                           realign_insert_data_last;
    logic                           insert_realign_data_rdy;

    inserter_compile #(
         .INSERT_W  (LOG_ENTRY_HDR_W)
        ,.DATA_W    (NOC_DATA_W     )
    ) log_hdr_inserter (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.insert_data               (datap_inserter_log_hdr         )
        
        ,.src_insert_data_val       (realign_insert_data_val        )
        ,.src_insert_data           (realign_insert_data            )
        ,.src_insert_data_padbytes  (realign_insert_data_padbytes   )
        ,.src_insert_data_last      (realign_insert_data_last       )
        ,.insert_src_data_rdy       (insert_realign_data_rdy        )
    
        ,.insert_dst_data_val       (insert_log_ctrl_rd_val         )
        ,.insert_dst_data           (prep_log_mem_wr_data           )
        ,.insert_dst_data_padbytes  (/* unused */)
        ,.insert_dst_data_last      (insert_log_ctrl_rd_last        )
        ,.dst_insert_data_rdy       (log_ctrl_insert_rd_rdy         )
    );

    realign_compile #(
         .REALIGN_W     (PREPARE_MSG_HDR_W  )
        ,.DATA_W        (NOC_DATA_W         )
        ,.BUF_STAGES    (4)
    ) prepare_realigner (
         .clk    (clk    )
        ,.rst    (rst    )

        ,.src_realign_data_val      (log_ctrl_realign_wr_val        )
        ,.src_realign_data          (manage_prep_req                )
        ,.src_realign_data_padbytes (manage_prep_req_padbytes       )
        ,.src_realign_data_last     (manage_prep_req_last           )
        ,.realign_src_data_rdy      (realign_log_ctrl_wr_rdy        )

        ,.realign_dst_data_val      (realign_insert_data_val        )
        ,.realign_dst_data          (realign_insert_data            )
        ,.realign_dst_data_padbytes (realign_insert_data_padbytes   )
        ,.realign_dst_data_last     (realign_insert_data_last       )
        ,.dst_realign_data_rdy      (insert_realign_data_rdy        )

        ,.realign_dst_removed_data  ()
    );

    prepare_datap #(
        .NOC_DATA_W (NOC_DATA_W )
    ) datap (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.manage_prep_pkt_info          (manage_prep_pkt_info           )
                                                                        
        ,.manage_prep_req               (manage_prep_req                )
                                                                        
        ,.vr_state_prep_rd_resp_data    (vr_state_prep_rd_resp_data     )
                                                                        
        ,.prep_vr_state_wr_data         (prep_vr_state_wr_data          )
                                                                        
        ,.prep_log_mem_wr_addr          (prep_log_mem_wr_addr           )
                                                                        
        ,.prep_to_udp_meta_info         (prep_to_udp_meta_info          )
                                                                        
        ,.prep_to_udp_data              (prep_to_udp_data               )
        ,.prep_to_udp_data_padbytes     (prep_to_udp_data_padbytes      )
                                                                        
        ,.datap_inserter_log_hdr        (datap_inserter_log_hdr         )
                                                                        
        ,.ctrl_datap_store_info         (ctrl_datap_store_info          )
        ,.log_ctrl_datap_incr_wr_addr   (log_ctrl_datap_incr_wr_addr    )
                                                                        
        ,.datap_ctrl_prep_ok            (datap_ctrl_prep_ok             )
        ,.datap_ctrl_log_has_space      (datap_ctrl_log_has_space       )
    );

    prepare_log_ctrl log_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.start_req_ingest              (start_req_ingest               )
        ,.log_write_done                (log_write_done                 )

        ,.manage_prep_req_val           (manage_prep_req_val            )
        ,.manage_prep_req_last          (manage_prep_req_last           )
        ,.prep_manage_req_rdy           (prep_manage_req_rdy            )

        ,.log_ctrl_realign_wr_val       (log_ctrl_realign_wr_val        )
        ,.log_ctrl_realign_wr_last      (log_ctrl_realign_wr_last       )
        ,.realign_log_ctrl_wr_rdy       (realign_log_ctrl_wr_rdy        )

        ,.insert_log_ctrl_rd_val        (insert_log_ctrl_rd_val         )
        ,.insert_log_ctrl_rd_last       (insert_log_ctrl_rd_last        )
        ,.log_ctrl_insert_rd_rdy        (log_ctrl_insert_rd_rdy         )

        ,.prep_log_mem_wr_val           (prep_log_mem_wr_val            )
        ,.log_mem_prep_wr_rdy           (log_mem_prep_wr_rdy            )

        ,.log_ctrl_datap_incr_wr_addr   (log_ctrl_datap_incr_wr_addr    )
        ,.datap_ctrl_log_has_space      (datap_ctrl_log_has_space       )
    );

    prepare_eng_ctrl ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.manage_prep_msg_val       (manage_prep_msg_val        )
        ,.prep_manage_msg_rdy       (prep_manage_msg_rdy        )

        ,.manage_prep_req_val       (manage_prep_req_val        )

        ,.prep_vr_state_wr_req      (prep_vr_state_wr_req       )

        ,.ctrl_datap_store_info     (ctrl_datap_store_info      )
        ,.datap_ctrl_prep_ok        (datap_ctrl_prep_ok         )
        ,.datap_ctrl_log_has_space  (datap_ctrl_log_has_space   )

        ,.start_req_ingest          (start_req_ingest           )
        ,.log_write_done            (log_write_done             )

        ,.prep_to_udp_meta_val      (prep_to_udp_meta_val       )
        ,.to_udp_prep_meta_rdy      (to_udp_prep_meta_rdy       )

        ,.prep_to_udp_data_val      (prep_to_udp_data_val       )
        ,.prep_to_udp_data_last     (prep_to_udp_data_last      )
        ,.to_udp_prep_data_rdy      (to_udp_prep_data_rdy       )

        ,.prep_engine_rdy           (prep_engine_rdy            )
    );



endmodule
