module commit_eng #(
    parameter NOC_DATA_W = -1
)
    import beehive_vr_pkg::*;
(
     input clk
    ,input rst
    
    ,input  logic                           manage_commit_msg_val
    ,input  udp_info                        manage_commit_pkt_info
    ,output logic                           commit_manage_msg_rdy
    
    // data bus in
    ,input  logic                           manage_commit_req_val
    ,input  logic   [NOC_DATA_W-1:0]        manage_commit_req
    ,input  logic                           manage_commit_req_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    manage_commit_req_padbytes
    ,output logic                           commit_manage_req_rdy
    

    ,input  vr_state                        vr_state_commit_rd_resp_data

    // state write
    ,output logic                           commit_vr_state_wr_req
    ,output vr_state                        commit_vr_state_wr_data
    ,input  logic                           vr_state_commit_wr_rdy

    // log entry rd bus
    ,output logic                           commit_log_mem_rd_req_val
    ,input  logic                           log_mem_commit_rd_req_rdy

    ,input  logic                           log_mem_commit_rd_resp_val
    ,input  logic   [NOC_DATA_W-1:0]        log_mem_commit_rd_resp_data
    ,output logic                           commit_log_mem_rd_resp_rdy
    
    // log entry bus out
    ,output logic                           commit_log_mem_wr_val
    ,output logic   [NOC_DATA_W-1:0]        commit_log_mem_wr_data
    ,input  logic                           log_mem_commit_wr_rdy

    ,output logic                           commit_eng_rdy
);
    
    logic                           ctrl_datap_store_msg;
    logic                           ctrl_datap_store_state;
    logic                           ctrl_datap_store_log_entry;
    logic                           ctrl_datap_calc_next_entry;
    
    logic                           datap_ctrl_commit_ok;
    logic                           datap_ctrl_last_commit;

    commit_eng_ctrl (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.manage_commit_msg_val         (manage_commit_msg_val          )
        ,.commit_manage_msg_rdy         (commit_manage_msg_rdy          )
                                                                        
        ,.manage_commit_req_val         (manage_commit_req_val          )
        ,.manage_commit_req_last        (manage_commit_req_last         )
        ,.commit_manage_req_rdy         (commit_manage_req_rdy          )
                                                                        
        ,.commit_vr_state_rd_req_val    (commit_vr_state_rd_req_val     )
        ,.vr_state_commit_rd_req_rdy    (vr_state_commit_rd_req_rdy     )
                                                                        
        ,.vr_state_commit_rd_resp_val   (vr_state_commit_rd_resp_val    )
        ,.commit_vr_state_rd_resp_rdy   (commit_vr_state_rd_resp_rdy    )
                                                                        
        ,.commit_vr_state_wr_req        (commit_vr_state_wr_req         )
        ,.vr_state_commit_wr_rdy        (vr_state_commit_wr_rdy         )
                                                                        
        ,.commit_log_mem_rd_req_val     (commit_log_mem_rd_req_val      )
        ,.log_mem_commit_rd_req_rdy     (log_mem_commit_rd_req_rdy      )
                                                                        
        ,.log_mem_commit_rd_resp_val    (log_mem_commit_rd_resp_val     )
        ,.commit_log_mem_rd_resp_rdy    (commit_log_mem_rd_resp_rdy     )
                                                                        
        ,.commit_log_mem_wr_val         (commit_log_mem_wr_val          )
        ,.log_mem_commit_wr_rdy         (log_mem_commit_wr_rdy          )
                                                                        
        ,.ctrl_datap_store_msg          (ctrl_datap_store_msg           )
        ,.ctrl_datap_store_state        (ctrl_datap_store_state         )
        ,.ctrl_datap_store_log_entry    (ctrl_datap_store_log_entry     )
        ,.ctrl_datap_calc_next_entry    (ctrl_datap_calc_next_entry     )
                                                                        
        ,.datap_ctrl_commit_ok          (datap_ctrl_commit_ok           )
        ,.datap_ctrl_last_commit        (datap_ctrl_last_commit         )

        ,.commit_eng_rdy                (commit_eng_rdy                 )
    );   

    commit_eng_datap #(
        .NOC_DATA_W (NOC_DATA_W )
    ) datap (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.manage_commit_pkt_info        (manage_commit_pkt_info         )
                                                                        
        ,.manage_commit_req             (manage_commit_req              )
                                                                        
        ,.vr_state_commit_rd_resp_data  (vr_state_commit_rd_resp_data   )
                                                                        
        ,.commit_vr_state_wr_data       (commit_vr_state_wr_data        )
                                                                        
        ,.log_mem_commit_rd_resp_data   (log_mem_commit_rd_resp_data    )
                                                                        
        ,.commit_log_mem_wr_data        (commit_log_mem_wr_data         )
        ,.commit_log_mem_wr_addr        (commit_log_mem_wr_addr         )
                                                                        
        ,.ctrl_datap_store_msg          (ctrl_datap_store_msg           )
        ,.ctrl_datap_store_state        (ctrl_datap_store_state         )
        ,.ctrl_datap_store_log_entry    (ctrl_datap_store_log_entry     )
        ,.ctrl_datap_calc_next_entry    (ctrl_datap_calc_next_entry     )
                                                                        
        ,.datap_ctrl_commit_ok          (datap_ctrl_commit_ok           )
        ,.datap_ctrl_last_commit        (datap_ctrl_last_commit         )
    );

endmodule
