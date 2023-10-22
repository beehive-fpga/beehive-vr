module log_install_ctrl (
     input clk
    ,input rst

    ,input  start_log_install

    ,input  logic                           src_install_req_val
    ,input  logic   [NOC_DATA_W-1:0]        src_install_req
    ,input  logic                           src_install_req_last
    ,input  logic   [NOC_PADBYTES_W-1:0]    src_install_req_padbytes
    ,output logic                           install_src_req_rdy

    ,output                                 log_install_rdy
    ,output logic   [INT_W-1:0]             first_log_op
    ,output logic   [INT_W-1:0]             last_commit
    ,output logic   [LOG_HDR_DEPTH_W:0]     hdr_log_tail
    ,output logic   [LOG_HDR_DEPTH_W:0]     data_log_tail
);

    typedef enum logic[1:0] {
        READY = 2'b0,
        GRAB_HDR = 2'd1,
        PASS_DATA = 2'd2,
    } start_view_state;
    
    start_view_state    start_view_state_reg;
    start_view_state    start_view_state_next;

    start_view_hdr      start_view_hdr_reg;
    start_view_hdr      start_view_hdr_next;
    logic               save_start_view_hdr;

    sep_in_state        sep_in_state_reg;
    sep_in_state        sep_in_state_next;
    
    logic                           hdr_strip_realign_data_val;
    logic   [DATA_W-1:0]            hdr_strip_realign_data;
    logic   [DATA_PADBYTES_W-1:0]   hdr_strip_realign_data_padbytes;
    logic                           hdr_strip_realign_data_last;
    logic                           realign_hdr_strip_data_rdy;
    
    logic                           realign_separate_data_val;
    logic   [DATA_W-1:0]            realign_separate_data;
    logic   [DATA_PADBYTES_W-1:0]   realign_separate_data_padbytes;
    logic                           realign_separate_data_last;
    logic                           separate_realign_data_rdy;

    always_ff @(posedge clk) begin
        if (rst) begin
            start_view_state_reg <= READY;
        end
        else begin
            start_view_state_reg <= start_view_state_next;
            start_view_hdr_reg <= start_view_hdr_next;

        end
    end

    always_comb begin
        save_start_view_hdr = 1'b0;
        install_src_req_rdy = 1'b0;
        hdr_strip_realign_data_val = 1'b0;
            
        start_view_state_next = start_view_state_reg;
        case (start_view_state_reg)
            READY: begin
                if (start_log_install) begin
                    start_view_state_next = GRAB_HDR;
                end
            end
            GRAB_HDR: begin
                install_src_req_rdy = realign_hdr_strip_data_rdy;
                hdr_strip_realign_data_val = src_install_req_val;
                save_start_view_hdr = 1'b1;
                if (realign_hdr_strip_data_rdy & src_install_req_val) begin
                    if (src_install_req_last) begin
                        state_next = READY;
                    end
                    else begin
                        state_next = PASS_DATA;
                    end
                end
            end
            PASS_DATA: begin
                install_src_req_rdy = realign_hdr_strip_data_rdy;
                hdr_strip_realign_data_val = src_install_req_val;
                if (realign_hdr_strip_data_rdy & src_install_req_val) begin
                    if (src_install_req_last) begin
                        state_next = READY;
                    end
                end
            end
        endcase
    end

    realign_compile #(
         .REALIGN_W (START_VIEW_HDR_W   )
        ,.DATA_W    (NOC_DATA_W         )
        ,.BUF_STAGES(4                  )
    ) hdr_strip (
         .clk   (clk    )
        ,.rst   (rst    )
    
        ,.src_realign_data_val      (hdr_strip_realign_data_val         )
        ,.src_realign_data          (hdr_strip_realign_data             )
        ,.src_realign_data_padbytes (hdr_strip_realign_data_padbytes    )
        ,.src_realign_data_last     (hdr_strip_realign_data_last        )
        ,.realign_src_data_rdy      (realign_hdr_strip_data_rdy         )
    
        ,.realign_dst_data_val      (realign_separate_data_val          )
        ,.realign_dst_data          (realign_separate_data              )
        ,.realign_dst_data_padbytes (realign_separate_data_padbytes     )
        ,.realign_dst_data_last     (realign_separate_data_last         )
        ,.dst_realign_data_rdy      (separate_realign_data_rdy          )
    
        ,.realign_dst_removed_data  ()
    );

    logic   reset_sep_state;
    logic   last_entry_line;

    always_comb begin
        reset_sep_state = 1'b0;

        sep_in_state_next = sep_in_state_reg;
        case (sep_in_state_reg)
            SEP_WAIT: begin
                reset_sep_state = 1'b1;
                if (start_log_install) begin
                    state_next = GRAB_HDR;
                end
            end
            GRAB_HDR: begin
            end
            IN_PASS_DATA: begin
            end
        endcase
    end
        
endmodule
