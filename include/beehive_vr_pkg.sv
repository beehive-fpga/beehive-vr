package beehive_vr_pkg;
    localparam INT_W = 64;
    localparam COUNT_W = 64;

    localparam FRAG_MAGIC_W = 32;
    localparam MSG_LEN_W = 64;

    localparam LOG_W = 512;
    localparam LOG_W_BYTES = LOG_W/8;
    localparam LOG_W_BYTES_W = $clog2(LOG_W_BYTES);
    localparam LOG_DEPTH = 1024;
    localparam LOG_DEPTH_W = $clog2(LOG_DEPTH);

    localparam LOG_STATE_COMMITED = 0;
    localparam LOG_STATE_PREPARED = 1;

    typedef enum logic[7:0] {
        Prepare = 8'd4,
        PrepareOK = 8'd5,
        Commit = 8'd6,
        RequestStateTransfer= 8'd7,
        StateTransfer = 8'd8,
        StartViewChange = 8'd9,
        DoViewChange = 8'd10,
        StartView = 8'd11,
        SetupBeehive = 8'd128
    } msg_type;

    typedef struct packed {
        logic   [FRAG_MAGIC_W-1:0]  frag_num;
        msg_type                    msg_type;
        logic   [MSG_LEN_W-1:0]     msg_len;
    } beehive_hdr;
    localparam BEEHIVE_HDR_W = $bits(beehive_hdr);
    localparam BEEHIVE_HDR_BYTES = BEEHIVE_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0]     view;
        logic   [INT_W-1:0]     opnum;
        logic   [INT_W-1:0]     batchstart;
        logic   [COUNT_W-1:0]   req_count;
    } prepare_msg_hdr;
    localparam PREPARE_MSG_HDR_W = $bits(prepare_hdr_msg);
    localparam PREPARE_HDR_BYTES = PREPARE_MSG_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] opnum;
        logic   [INT_W-1:0] rep_index;
    } prepare_ok_hdr;
    localparam PREPARE_OK_HDR_W = $bits(prepare_ok_hdr);
    localparam PREPARE_OK_HDR_BYTES = PREPARE_OK_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0]     view;
        logic   [INT_W-1:0]     opnum;
    } commit_msg_hdr;
    localparam COMMIT_MSG_HDR_W = $bits(commit_msg_hdr);

    typedef struct packed {
        logic   [INT_W-1:0]         curr_view;
        logic   [INT_W-1:0]         last_op;
        logic   [INT_W-1:0]         my_replica_index;
        logic   [LOG_DEPTH_W:0]     log_head;
        logic   [LOG_DEPTH_W:0]     log_tail;
        logic   [INT_W-1:0]         last_commit;
    } vr_state;
    localparam VR_STATE_W = $bits(vr_state);

    typedef struct packed {
        logic   [INT_W-1:0]         view;
        logic   [INT_W-1:0]         op_num;
        logic   [INT_W-1:0]         log_entry_state;
        logic   [INT_W-1:0]         entry_len;
        logic   [INT_W-1:0]         req_count;
    } log_entry_hdr;
    localparam LOG_ENTRY_HDR_W = $bits(log_entry_hdr);
    localparam LOG_ENTRY_BYTES = LOG_ENTRY_HDR_W/8;



endpackage
