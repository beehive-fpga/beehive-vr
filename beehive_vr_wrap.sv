module beehive_vr_wrap 
import beehive_udp_msg::*;
import beehive_vr_pkg::*;
#(
     parameter NOC_DATA_W = -1
    ,parameter NOC_PADBYTES = NOC_DATA_W/8
    ,parameter NOC_PADBYTES_W = $clog2(NOC_PADBYTES)
)(
     input clk
    ,input rst

    ,input  logic                           fr_udp_beehive_vr_meta_val
    ,input  udp_info                        fr_udp_beehive_vr_meta_info
    ,output logic                           beehive_vr_fr_udp_meta_rdy

    ,input  logic                           fr_udp_beehive_vr_data_val
    ,input  logic   [NOC_DATA_W-1:0]        fr_udp_beehive_vr_data
    ,input  logic                           fr_udp_beehive_vr_data_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    fr_udp_beehive_vr_data_padbytes
    ,output logic                           beehive_vr_fr_udp_data_rdy
    
    ,output logic                           beehive_vr_to_udp_meta_val
    ,output udp_info                        beehive_vr_to_udp_meta_info
    ,input  logic                           to_udp_beehive_vr_meta_rdy

    ,output logic                           beehive_vr_to_udp_data_val
    ,output logic   [NOC_DATA_W-1:0]        beehive_vr_to_udp_data
    ,input  logic                           to_udp_beehive_vr_data_rdy
);
    
    logic                           manage_prep_msg_val;
    udp_info                        manage_prep_pkt_info;
    logic                           prep_manage_msg_rdy;

    logic                           manage_prep_req_val;
    logic   [NOC_DATA_W-1:0]        manage_prep_req;
    logic                           manage_prep_req_last;
    logic   [NOC_PADBYTES_W-1:0]    manage_prep_req_padbytes;
    logic                           prep_manage_req_rdy;
    
    logic                           manage_commit_msg_val;
    udp_info                        manage_commit_pkt_info;
    logic                           commit_manage_msg_rdy;

    logic                           manage_commit_req_val;
    logic   [NOC_DATA_W-1:0]        manage_commit_req;
    logic                           manage_commit_req_last;
    logic   [NOC_PADBYTES_W-1:0]    manage_commit_req_padbytes;
    logic                           commit_manage_req_rdy;
    
    logic                           commit_log_hdr_mem_rd_req_val;
    logic   [LOG_HDR_DEPTH_W-1:0]   commit_log_hdr_mem_rd_req_addr;
    logic                           log_hdr_mem_commit_rd_req_rdy;

    logic                           log_hdr_mem_commit_rd_resp_val;
    log_entry_hdr                   log_hdr_mem_commit_rd_resp_data;
    logic                           commit_log_hdr_mem_rd_resp_rdy;
    
    logic                           log_hdr_mem_rd_req_val;
    logic   [LOG_HDR_DEPTH_W-1:0]   log_hdr_mem_rd_req_addr;
    logic                           log_hdr_mem_rd_req_rdy;

    logic                           log_hdr_mem_rd_resp_val;
    log_entry_hdr                   log_hdr_mem_rd_resp_data;
    logic                           log_hdr_mem_rd_resp_rdy;
    
    logic                           commit_log_hdr_mem_wr_val;
    log_entry_hdr                   commit_log_hdr_mem_wr_data;
    logic   [LOG_HDR_DEPTH_W-1:0]   commit_log_hdr_mem_wr_addr;
    logic                           log_hdr_mem_commit_wr_rdy;
    
    logic                           splitter_setup_meta_val;
    udp_info                        splitter_setup_meta_info;
    logic                           setup_splitter_meta_rdy;

    logic                           splitter_setup_data_val;
    logic   [NOC_DATA_W-1:0]        splitter_setup_data;
    logic                           splitter_setup_data_last;
    logic   [NOC_PADBYTES_W-1:0]    splitter_setup_data_padbytes;
    logic                           setup_splitter_data_rdy;
    
    logic                           splitter_manage_meta_val;
    udp_info                        splitter_manage_meta_info;
    logic                           manage_splitter_meta_rdy;

    logic                           splitter_manage_data_val;
    logic   [NOC_DATA_W-1:0]        splitter_manage_data;
    logic                           splitter_manage_data_last;
    logic   [NOC_PADBYTES_W-1:0]    splitter_manage_data_padbytes;
    logic                           manage_splitter_data_rdy;
    
    logic                           prep_log_hdr_mem_wr_val;
    log_entry_hdr                   prep_log_hdr_mem_wr_data;
    logic   [LOG_HDR_DEPTH_W-1:0]   prep_log_hdr_mem_wr_addr;
    logic                           log_hdr_mem_prep_wr_rdy;
    
    logic                           prep_log_data_mem_wr_val;
    logic   [NOC_DATA_W-1:0]        prep_log_data_mem_wr_data;
    logic   [LOG_DEPTH_W-1:0]       prep_log_data_mem_wr_addr;
    logic                           log_data_mem_prep_wr_rdy;

    logic                           log_data_mem_wr_req_val;
    logic   [NOC_DATA_W-1:0]        log_data_mem_wr_req_data;
    logic   [LOG_DEPTH_W-1:0]       log_data_mem_wr_req_addr;
    logic                           log_data_mem_wr_req_rdy;
    
    logic                           log_hdr_mem_wr_req_val;
    log_entry_hdr                   log_hdr_mem_wr_req_data;
    logic   [LOG_HDR_DEPTH_W-1:0]   log_hdr_mem_wr_req_addr;
    logic                           log_hdr_mem_wr_req_rdy;

    logic                           prep_log_hdr_mem_rd_req_val;
    logic   [LOG_HDR_DEPTH_W-1:0]   prep_log_hdr_mem_rd_req_addr;
    logic                           log_hdr_mem_prep_rd_req_rdy;

    logic                           log_hdr_mem_prep_rd_resp_val;
    log_entry_hdr                   log_hdr_mem_prep_rd_resp_data;
    logic                           prep_log_hdr_mem_rd_resp_rdy;

    vr_state                        vr_state_reg;
    vr_state                        vr_state_next;
    
    logic                           setup_vr_state_wr_val;
    vr_state                        setup_vr_state_wr_data;

    logic                           setup_eng_rdy;
    logic                           commit_eng_rdy;
    logic                           prep_engine_rdy;
    logic                           all_eng_rdy;
    
    logic                           setup_to_udp_meta_val;
    udp_info                        setup_to_udp_meta_info;
    logic                           to_udp_setup_meta_rdy;

    logic                           setup_to_udp_data_val;
    logic   [NOC_DATA_W-1:0]        setup_to_udp_data;
    logic   [NOC_PADBYTES_W-1:0]    setup_to_udp_data_padbytes;
    logic                           setup_to_udp_data_last;
    logic                           to_udp_setup_data_rdy;
    
    logic                           prep_to_udp_meta_val;
    udp_info                        prep_to_udp_meta_info;
    logic                           to_udp_prep_meta_rdy;

    logic                           prep_to_udp_data_val;
    logic   [NOC_DATA_W-1:0]        prep_to_udp_data;
    logic   [NOC_PADBYTES_W-1:0]    prep_to_udp_data_padbytes;
    logic                           prep_to_udp_data_last;
    logic                           to_udp_prep_data_rdy;
    
    logic                           commit_vr_state_wr_req;
    vr_state                        commit_vr_state_wr_data;
    logic                           vr_state_commit_wr_rdy;
    
    logic                           prep_vr_state_wr_req;
    vr_state                        prep_vr_state_wr_data;

    assign all_eng_rdy = setup_eng_rdy & commit_eng_rdy & prep_engine_rdy;

    always_ff @(posedge clk) begin
        vr_state_reg <= vr_state_next;
    end

    always_comb begin
        vr_state_commit_wr_rdy = 1'b0;
        
        vr_state_next = vr_state_reg;
        if (setup_vr_state_wr_val) begin
            vr_state_next = setup_vr_state_wr_data;
        end
        else if (prep_vr_state_wr_req) begin
            vr_state_next = prep_vr_state_wr_data;
        end
        else if (commit_vr_state_wr_req) begin
            vr_state_commit_wr_rdy = 1'b1;
            vr_state_next = commit_vr_state_wr_data;
        end
    end

    req_splitter #(
         .NOC_DATA_W        (NOC_DATA_W )
    ) req_splitter (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.fr_udp_beehive_vr_meta_val        (fr_udp_beehive_vr_meta_val         )
        ,.fr_udp_beehive_vr_meta_info       (fr_udp_beehive_vr_meta_info        )
        ,.beehive_vr_fr_udp_meta_rdy        (beehive_vr_fr_udp_meta_rdy         )
                                                                                
        ,.fr_udp_beehive_vr_data_val        (fr_udp_beehive_vr_data_val         )
        ,.fr_udp_beehive_vr_data            (fr_udp_beehive_vr_data             )
        ,.fr_udp_beehive_vr_data_last       (fr_udp_beehive_vr_data_last        )
        ,.fr_udp_beehive_vr_data_padbytes   (fr_udp_beehive_vr_data_padbytes    )
        ,.beehive_vr_fr_udp_data_rdy        (beehive_vr_fr_udp_data_rdy         )
                                                                                
        ,.splitter_setup_meta_val           (splitter_setup_meta_val            )
        ,.splitter_setup_meta_info          (splitter_setup_meta_info           )
        ,.setup_splitter_meta_rdy           (setup_splitter_meta_rdy            )
                                                                                
        ,.splitter_setup_data_val           (splitter_setup_data_val            )
        ,.splitter_setup_data               (splitter_setup_data                )
        ,.splitter_setup_data_last          (splitter_setup_data_last           )
        ,.splitter_setup_data_padbytes      (splitter_setup_data_padbytes       )
        ,.setup_splitter_data_rdy           (setup_splitter_data_rdy            )
                                                                                
        ,.splitter_manage_meta_val          (splitter_manage_meta_val           )
        ,.splitter_manage_meta_info         (splitter_manage_meta_info          )
        ,.manage_splitter_meta_rdy          (manage_splitter_meta_rdy           )
                                                                                
        ,.splitter_manage_data_val          (splitter_manage_data_val           )
        ,.splitter_manage_data              (splitter_manage_data               )
        ,.splitter_manage_data_last         (splitter_manage_data_last          )
        ,.splitter_manage_data_padbytes     (splitter_manage_data_padbytes      )
        ,.manage_splitter_data_rdy          (manage_splitter_data_rdy           )
    );

    out_merger #(
         .NOC_DATA_W    (NOC_DATA_W )
    ) out_merger (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.setup_to_udp_meta_val         (setup_to_udp_meta_val      )
        ,.setup_to_udp_meta_info        (setup_to_udp_meta_info     )
        ,.to_udp_setup_meta_rdy         (to_udp_setup_meta_rdy      )
                                                                    
        ,.setup_to_udp_data_val         (setup_to_udp_data_val      )
        ,.setup_to_udp_data             (setup_to_udp_data          )
        ,.setup_to_udp_data_padbytes    (setup_to_udp_data_padbytes )
        ,.setup_to_udp_data_last        (setup_to_udp_data_last     )
        ,.to_udp_setup_data_rdy         (to_udp_setup_data_rdy      )
                                                                    
        ,.prep_to_udp_meta_val          (prep_to_udp_meta_val       )
        ,.prep_to_udp_meta_info         (prep_to_udp_meta_info      )
        ,.to_udp_prep_meta_rdy          (to_udp_prep_meta_rdy       )
                                                                    
        ,.prep_to_udp_data_val          (prep_to_udp_data_val       )
        ,.prep_to_udp_data              (prep_to_udp_data           )
        ,.prep_to_udp_data_padbytes     (prep_to_udp_data_padbytes  )
        ,.prep_to_udp_data_last         (prep_to_udp_data_last      )
        ,.to_udp_prep_data_rdy          (to_udp_prep_data_rdy       )

        ,.merger_dst_meta_val           (beehive_vr_to_udp_meta_val )
        ,.merger_dst_meta_info          (beehive_vr_to_udp_meta_info)
        ,.dst_merger_meta_rdy           (to_udp_beehive_vr_meta_rdy )

        ,.merger_dst_data_val           (beehive_vr_to_udp_data_val )
        ,.merger_dst_data               (beehive_vr_to_udp_data     )
        ,.merger_dst_data_padbytes      ()
        ,.merger_dst_data_last          ()
        ,.dst_merger_data_rdy           (to_udp_beehive_vr_data_rdy )
    );

    setup_eng #(
         .NOC_DATA_W    (NOC_DATA_W)
    ) setup_eng (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_setup_msg_val             (splitter_setup_meta_val        )
        ,.src_setup_pkt_info            (splitter_setup_meta_info       )
        ,.setup_src_msg_rdy             (setup_splitter_meta_rdy        )
    
        ,.src_setup_req_val             (splitter_setup_data_val        )
        ,.src_setup_req                 (splitter_setup_data            )
        ,.src_setup_req_last            (splitter_setup_data_last       )
        ,.src_setup_req_padbytes        (splitter_setup_data_padbytes   )
        ,.setup_src_req_rdy             (setup_splitter_data_rdy        )
    
        ,.setup_vr_state_wr_val         (setup_vr_state_wr_val          )
        ,.setup_vr_state_wr_data        (setup_vr_state_wr_data         )
    
        ,.setup_to_udp_meta_val         (setup_to_udp_meta_val          )
        ,.setup_to_udp_meta_info        (setup_to_udp_meta_info         )
        ,.to_udp_setup_meta_rdy         (to_udp_setup_meta_rdy          )
                                                                        
        ,.setup_to_udp_data_val         (setup_to_udp_data_val          )
        ,.setup_to_udp_data             (setup_to_udp_data              )
        ,.setup_to_udp_data_padbytes    (setup_to_udp_data_padbytes     )
        ,.setup_to_udp_data_last        (setup_to_udp_data_last         )
        ,.to_udp_setup_data_rdy         (to_udp_setup_data_rdy          )

        ,.setup_eng_rdy                 (setup_eng_rdy                  )
    );


    manage_eng #(
         .NOC_DATA_W (NOC_DATA_W    )
    ) manage_eng (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.fr_udp_manage_meta_val        (splitter_manage_meta_val       )
        ,.fr_udp_manage_meta_info       (splitter_manage_meta_info      )
        ,.manage_fr_udp_meta_rdy        (manage_splitter_meta_rdy       )
                                         
        ,.fr_udp_manage_data_val        (splitter_manage_data_val       )
        ,.fr_udp_manage_data            (splitter_manage_data           )
        ,.fr_udp_manage_data_last       (splitter_manage_data_last      )
        ,.fr_udp_manage_data_padbytes   (splitter_manage_data_padbytes  )
        ,.manage_fr_udp_data_rdy        (manage_splitter_data_rdy       )
    
        ,.manage_prep_msg_val           (manage_prep_msg_val            )
        ,.manage_prep_pkt_info          (manage_prep_pkt_info           )
        ,.prep_manage_msg_rdy           (prep_manage_msg_rdy            )
                                                                        
        ,.manage_prep_req_val           (manage_prep_req_val            )
        ,.manage_prep_req               (manage_prep_req                )
        ,.manage_prep_req_last          (manage_prep_req_last           )
        ,.manage_prep_req_padbytes      (manage_prep_req_padbytes       )
        ,.prep_manage_req_rdy           (prep_manage_req_rdy            )
                                                                        
        ,.manage_commit_msg_val         (manage_commit_msg_val          )
        ,.manage_commit_pkt_info        (manage_commit_pkt_info         )
        ,.commit_manage_msg_rdy         (commit_manage_msg_rdy          )
                                                                        
        ,.manage_commit_req_val         (manage_commit_req_val          )
        ,.manage_commit_req             (manage_commit_req              )
        ,.manage_commit_req_last        (manage_commit_req_last         )
        ,.manage_commit_req_padbytes    (manage_commit_req_padbytes     )
        ,.commit_manage_req_rdy         (commit_manage_req_rdy          )

        ,.all_eng_rdy                   (all_eng_rdy                    )
    );

    prepare_eng #(
         .NOC_DATA_W    (NOC_DATA_W )
    ) prep_eng (
         .clk   (clk    )
        ,.rst   (rst    )

        ,.manage_prep_msg_val           (manage_prep_msg_val            )
        ,.manage_prep_pkt_info          (manage_prep_pkt_info           )
        ,.prep_manage_msg_rdy           (prep_manage_msg_rdy            )

        ,.manage_prep_req_val           (manage_prep_req_val            )
        ,.manage_prep_req               (manage_prep_req                )
        ,.manage_prep_req_last          (manage_prep_req_last           )
        ,.manage_prep_req_padbytes      (manage_prep_req_padbytes       )
        ,.prep_manage_req_rdy           (prep_manage_req_rdy            )

        ,.vr_state_prep_rd_resp_data    (vr_state_reg                   )

        ,.prep_vr_state_wr_req          (prep_vr_state_wr_req           )
        ,.prep_vr_state_wr_data         (prep_vr_state_wr_data          )

        ,.prep_log_hdr_mem_wr_val       (prep_log_hdr_mem_wr_val        )
        ,.prep_log_hdr_mem_wr_data      (prep_log_hdr_mem_wr_data       )
        ,.prep_log_hdr_mem_wr_addr      (prep_log_hdr_mem_wr_addr       )
        ,.log_hdr_mem_prep_wr_rdy       (log_hdr_mem_prep_wr_rdy        )

        ,.prep_log_data_mem_wr_val      (prep_log_data_mem_wr_val       )
        ,.prep_log_data_mem_wr_data     (prep_log_data_mem_wr_data      )
        ,.prep_log_data_mem_wr_addr     (prep_log_data_mem_wr_addr      )
        ,.log_data_mem_prep_wr_rdy      (log_data_mem_prep_wr_rdy       )

        ,.prep_log_hdr_mem_rd_req_val   (prep_log_hdr_mem_rd_req_val    )
        ,.prep_log_hdr_mem_rd_req_addr  (prep_log_hdr_mem_rd_req_addr   )
        ,.log_hdr_mem_prep_rd_req_rdy   (log_hdr_mem_prep_rd_req_rdy    )

        ,.log_hdr_mem_prep_rd_resp_val  (log_hdr_mem_prep_rd_resp_val   )
        ,.log_hdr_mem_prep_rd_resp_data (log_hdr_mem_prep_rd_resp_data  )
        ,.prep_log_hdr_mem_rd_resp_rdy  (prep_log_hdr_mem_rd_resp_rdy   )
    
        ,.prep_to_udp_meta_val          (prep_to_udp_meta_val           )
        ,.prep_to_udp_meta_info         (prep_to_udp_meta_info          )
        ,.to_udp_prep_meta_rdy          (to_udp_prep_meta_rdy           )

        ,.prep_to_udp_data_val          (prep_to_udp_data_val           )
        ,.prep_to_udp_data              (prep_to_udp_data               )
        ,.prep_to_udp_data_padbytes     (prep_to_udp_data_padbytes      )
        ,.prep_to_udp_data_last         (prep_to_udp_data_last          )
        ,.to_udp_prep_data_rdy          (to_udp_prep_data_rdy           )

        ,.prep_engine_rdy               (prep_engine_rdy                )
    );

    commit_eng #(
        .NOC_DATA_W (NOC_DATA_W )
    ) commit_eng (
         .clk   (clk    )
        ,.rst   (rst    )
        
        ,.manage_commit_msg_val             (manage_commit_msg_val              )
        ,.manage_commit_pkt_info            (manage_commit_pkt_info             )
        ,.commit_manage_msg_rdy             (commit_manage_msg_rdy              )
                                                                           
        ,.manage_commit_req_val             (manage_commit_req_val              )
        ,.manage_commit_req                 (manage_commit_req                  )
        ,.manage_commit_req_last            (manage_commit_req_last             )
        ,.manage_commit_req_padbytes        (manage_commit_req_padbytes         )
        ,.commit_manage_req_rdy             (commit_manage_req_rdy              )
                                                                           
        ,.vr_state_commit_rd_resp_data      (vr_state_reg                       )
                                                                           
        ,.commit_vr_state_wr_req            (commit_vr_state_wr_req             )
        ,.commit_vr_state_wr_data           (commit_vr_state_wr_data            )
        ,.vr_state_commit_wr_rdy            (vr_state_commit_wr_rdy             )
    
        // log entry rd bus
        ,.commit_log_hdr_mem_rd_req_val     (commit_log_hdr_mem_rd_req_val      )
        ,.commit_log_hdr_mem_rd_req_addr    (commit_log_hdr_mem_rd_req_addr     )
        ,.log_hdr_mem_commit_rd_req_rdy     (log_hdr_mem_commit_rd_req_rdy      )
                                                                                
        ,.log_hdr_mem_commit_rd_resp_val    (log_hdr_mem_commit_rd_resp_val     )
        ,.log_hdr_mem_commit_rd_resp_data   (log_hdr_mem_commit_rd_resp_data    )
        ,.commit_log_hdr_mem_rd_resp_rdy    (commit_log_hdr_mem_rd_resp_rdy     )

        // log entry bus out
        ,.commit_log_hdr_mem_wr_val         (commit_log_hdr_mem_wr_val          )
        ,.commit_log_hdr_mem_wr_data        (commit_log_hdr_mem_wr_data         )
        ,.commit_log_hdr_mem_wr_addr        (commit_log_hdr_mem_wr_addr         )
        ,.log_hdr_mem_commit_wr_rdy         (log_hdr_mem_commit_wr_rdy          )
                                                                           
        ,.commit_eng_rdy                    (commit_eng_rdy                     )
    );

    always_comb begin
        log_hdr_mem_prep_wr_rdy = 1'b0;
        log_hdr_mem_commit_wr_rdy = 1'b0;

        if (prep_log_hdr_mem_wr_val) begin
            log_hdr_mem_wr_req_val = prep_log_hdr_mem_wr_val;
            log_hdr_mem_wr_req_data = prep_log_hdr_mem_wr_data;
            log_hdr_mem_wr_req_addr = prep_log_hdr_mem_wr_addr;
            log_hdr_mem_prep_wr_rdy = log_hdr_mem_wr_req_rdy;
        end
        else begin
            log_hdr_mem_wr_req_val = commit_log_hdr_mem_wr_val;
            log_hdr_mem_wr_req_data = commit_log_hdr_mem_wr_data;
            log_hdr_mem_wr_req_addr = commit_log_hdr_mem_wr_addr;
            log_hdr_mem_commit_wr_rdy = log_hdr_mem_wr_req_rdy;
        end
    end

    assign log_data_mem_wr_req_val = prep_log_data_mem_wr_val;
    assign log_data_mem_wr_req_data = prep_log_data_mem_wr_data;
    assign log_data_mem_wr_req_addr = prep_log_data_mem_wr_addr;
    assign log_data_mem_prep_wr_rdy= log_data_mem_wr_req_rdy;

    mem_mux #(
         .ADDR_W    (LOG_HDR_DEPTH_W    )
        ,.DATA_W    (LOG_ENTRY_HDR_W    )
    ) hdr_rd_mux (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src0_rd_req_val   (prep_log_hdr_mem_rd_req_val    )
        ,.src0_rd_req_addr  (prep_log_hdr_mem_rd_req_addr   )
        ,.src0_rd_req_rdy   (log_hdr_mem_prep_rd_req_rdy    )
        
        ,.src0_rd_resp_val  (log_hdr_mem_prep_rd_resp_val   )
        ,.src0_rd_resp_data (log_hdr_mem_prep_rd_resp_data  )
        ,.src0_rd_resp_rdy  (prep_log_hdr_mem_rd_resp_rdy   )
        
        ,.src1_rd_req_val   (commit_log_hdr_mem_rd_req_val  )
        ,.src1_rd_req_addr  (commit_log_hdr_mem_rd_req_addr )
        ,.src1_rd_req_rdy   (log_hdr_mem_commit_rd_req_rdy  )
        
        ,.src1_rd_resp_val  (log_hdr_mem_commit_rd_resp_val )
        ,.src1_rd_resp_data (log_hdr_mem_commit_rd_resp_data)
        ,.src1_rd_resp_rdy  (commit_log_hdr_mem_rd_resp_rdy )
    
        ,.dst_rd_req_val    (log_hdr_mem_rd_req_val         )
        ,.dst_rd_req_addr   (log_hdr_mem_rd_req_addr        )
        ,.dst_rd_req_rdy    (log_hdr_mem_rd_req_rdy         )
        
        ,.dst_rd_resp_val   (log_hdr_mem_rd_resp_val        )
        ,.dst_rd_resp_data  (log_hdr_mem_rd_resp_data       )
        ,.dst_rd_resp_rdy   (log_hdr_mem_rd_resp_rdy        )
    );
    
    ram_1r1w_sync_backpressure #(
         .width_p   (LOG_ENTRY_HDR_W    )
        ,.els_p     (LOG_HDR_DEPTH      )
    ) log_hdr_mem (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.wr_req_val    (log_hdr_mem_wr_req_val         )
        ,.wr_req_addr   (log_hdr_mem_wr_req_addr        )
        ,.wr_req_data   (log_hdr_mem_wr_req_data        )
        ,.wr_req_rdy    (log_hdr_mem_wr_req_rdy         )
    
        ,.rd_req_val    (log_hdr_mem_rd_req_val         )
        ,.rd_req_addr   (log_hdr_mem_rd_req_addr        )
        ,.rd_req_rdy    (log_hdr_mem_rd_req_rdy         )
                                                        
        ,.rd_resp_val   (log_hdr_mem_rd_resp_val        )
        ,.rd_resp_data  (log_hdr_mem_rd_resp_data       )
        ,.rd_resp_rdy   (log_hdr_mem_rd_resp_rdy        )
    );

    ram_1r1w_sync_backpressure #(
         .width_p   (LOG_W      )
        ,.els_p     (LOG_DEPTH  )
    ) log_data_mem (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.wr_req_val    (log_data_mem_wr_req_val         )
        ,.wr_req_addr   (log_data_mem_wr_req_addr        )
        ,.wr_req_data   (log_data_mem_wr_req_data        )
        ,.wr_req_rdy    (log_data_mem_wr_req_rdy         )
    
        ,.rd_req_val    ('0)
        ,.rd_req_addr   ('0)
        ,.rd_req_rdy    ()
    
        ,.rd_resp_val   ()
        ,.rd_resp_data  ()
        ,.rd_resp_rdy   ('0)
    );
endmodule
