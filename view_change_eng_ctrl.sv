module view_change_eng_ctrl 
import beehive_vr_pkg::*;
(
     input clk
    ,input rst
    // metadata bus in
    ,input  logic                           manage_vc_msg_val
    ,output logic                           vc_manage_msg_rdy

    // data bus in
    ,input  logic                           manage_vc_req_val
    ,input  logic                           manage_vc_req_last
    ,output logic                           vc_manage_req_rdy

    // state write
    ,output logic                           vc_vr_state_wr_req
    ,input  logic                           vr_state_vc_wr_req_rdy
    
    ,output logic                           vc_engine_rdy

    ,output logic                           send_do_change_req
    ,input  logic                           do_change_rdy

    ,output logic                           start_broadcast
    ,input  logic                           broadcast_rdy
    
    ,output logic                           ctrl_realign_data_val
    ,output logic                           ctrl_realign_data_last
    ,input  logic                           realign_ctrl_data_rdy

    ,output logic                           ctrl_datap_store_msg
    ,output logic                           ctrl_datap_store_req
    ,output logic                           ctrl_datap_store_new_state
    ,output logic                           ctrl_datap_clear_quorum_vec
    ,output logic                           ctrl_datap_set_quorum_vec

    ,output logic                           ctrl_install_start_install

    ,input  logic                           install_ctrl_val
    ,output logic                           ctrl_install_rdy
    
    ,input  logic                           datap_ctrl_new_view
    ,input  logic                           datap_ctrl_curr_view_change
    ,input  logic                           datap_ctrl_quorum_good
    ,input  msg_type_e                      datap_ctrl_msg_type   
);

    typedef enum logic [3:0] {
        READY = 4'd0,
        STORE_REQ = 4'd1,
        MSG_TYPE_CHECK = 4'd2,
        HANDLE_START_CHANGE = 4'd3,
        BROADCAST_START_CHANGE = 4'd4,
        WAIT_BROADCAST = 4'd5,
        CHECK_QUORUM = 4'd7,
        SEND_DO_CHANGE = 4'd8,
        WAIT_DO_CHANGE = 4'd9,
        HANDLE_START_VIEW = 4'd10,
        INSTALL_LOG_WR_FIFO = 4'd11,
        INSTALL_LOG_WAIT = 4'd14,
        // FIXME: do this for any uncommitted installed log reqs
        SEND_PREP_OK = 4'd12,
        WR_STATE = 4'd13,
        UND = 'X
    } state_e;

    state_e state_reg;
    state_e state_next;

    always_ff @(posedge clk) begin
        if (rst) begin
            state_reg <= READY;
        end
        else begin
            state_reg <= state_next;
        end
    end

    assign vc_engine_rdy = state_reg == READY;

    assign ctrl_realign_data_last = manage_vc_req_last;

    always_comb begin
        ctrl_datap_store_req = 1'b0;
        ctrl_datap_store_msg = 1'b0;
        ctrl_datap_store_new_state = 1'b0;
        ctrl_datap_clear_quorum_vec = 1'b0;
        ctrl_datap_set_quorum_vec = 1'b0;
    
        ctrl_install_start_install = 1'b0;
        ctrl_install_rdy = 1'b0;

        ctrl_realign_data_val = 1'b0;
        vc_manage_req_rdy = 1'b0;
        vc_manage_msg_rdy = 1'b0;

        start_broadcast = 1'b0;
        send_do_change_req = 1'b0;

        vc_vr_state_wr_req = 1'b0;

        state_next = state_reg;
        case (state_reg)
            READY: begin
                vc_manage_msg_rdy = 1'b1;
                ctrl_datap_store_msg = 1'b1;
                if (manage_vc_msg_val) begin
                    state_next = STORE_REQ;
                end
            end
            STORE_REQ: begin
                ctrl_datap_store_req = 1'b1;
                if (manage_vc_req_val) begin
                    state_next = MSG_TYPE_CHECK;
                end
            end
            MSG_TYPE_CHECK: begin
                if (datap_ctrl_msg_type == StartViewChange) begin
                    vc_manage_req_rdy = 1'b1;
                    state_next = HANDLE_START_CHANGE;
                end
                // we can't get any other message types
                else begin
                    state_next = HANDLE_START_VIEW;
                end
            end
            HANDLE_START_CHANGE: begin
                if (datap_ctrl_new_view) begin
                    ctrl_datap_clear_quorum_vec = 1'b1;
                    ctrl_datap_set_quorum_vec = 1'b1;
                    state_next = BROADCAST_START_CHANGE;
                end
                else if (datap_ctrl_curr_view_change) begin
                    ctrl_datap_set_quorum_vec = 1'b1;
                    state_next = CHECK_QUORUM;
                end
                // it's an old view, so discard
                else begin
                    state_next = READY;
                end
            end
            BROADCAST_START_CHANGE: begin
                start_broadcast = 1'b1;
                state_next = WAIT_BROADCAST;
            end
            WAIT_BROADCAST: begin
                if (broadcast_rdy) begin
                    state_next = CHECK_QUORUM;
                end
            end
            CHECK_QUORUM: begin
                if (datap_ctrl_quorum_good) begin
                    state_next = SEND_DO_CHANGE;
                end
                else begin
                    state_next = READY;
                end
            end
            SEND_DO_CHANGE: begin
                send_do_change_req = 1'b1;
                state_next = WAIT_DO_CHANGE;
            end
            WAIT_DO_CHANGE: begin
                ctrl_datap_store_new_state = 1'b1;
                if (do_change_rdy) begin
                    state_next = WR_STATE;
                end
            end
            HANDLE_START_VIEW: begin
                ctrl_install_start_install = 1'b1;
                state_next = INSTALL_LOG_WR_FIFO;
            end
            INSTALL_LOG_WR_FIFO: begin
                ctrl_realign_data_val = manage_vc_req_val;
                vc_manage_req_rdy = realign_ctrl_data_rdy;
                if (manage_vc_req_val & realign_ctrl_data_rdy & manage_vc_req_last) begin
                    state_next = INSTALL_LOG_WAIT;
                end
            end
            INSTALL_LOG_WAIT: begin
                ctrl_datap_store_new_state = 1'b1;
                ctrl_install_rdy = 1'b1;
                if (install_ctrl_val) begin
                    state_next = WR_STATE;
                end
            end
            WR_STATE: begin
                vc_vr_state_wr_req = 1'b1;
                if (vr_state_vc_wr_req_rdy) begin
                    state_next = READY;
                end
            end
        endcase
    end
endmodule
