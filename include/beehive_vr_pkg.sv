package beehive_vr_pkg;
    `include "packet_defs.vh"
    `include "noc_defs.vh"

    localparam INT_W = 64;
    localparam COUNT_W = 64;

    localparam [31:0]   NONFRAG_MAGIC = 31'h18_03_05_20;

    localparam FRAG_MAGIC_W = 32;
    localparam MSG_LEN_W = 64;

    localparam LOG_W = 512;
    localparam LOG_W_BYTES = LOG_W/8;
    localparam LOG_W_BYTES_W = $clog2(LOG_W_BYTES);
    localparam LOG_DEPTH = 2048;
    localparam LOG_DEPTH_W = $clog2(LOG_DEPTH);
    localparam LOG_HDR_DEPTH = 4096;
    localparam LOG_HDR_DEPTH_W = $clog2(LOG_HDR_DEPTH);

    localparam LOG_STATE_COMMITED = 0;
    localparam LOG_STATE_PREPARED = 1;
    
    typedef enum logic {
        NORMAL = 1'd0,
        VIEW_CHANGE = 1'd1
    } rep_status;

    typedef enum logic[7:0] {
        Prepare = 8'd5,
        PrepareOK = 8'd6,
        Commit = 8'd7,
        RequestStateTransfer= 8'd8,
        StateTransfer = 8'd9,
        StartViewChange = 8'd10,
        DoViewChange = 8'd11,
        StartView = 8'd12,
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
        logic   [INT_W-1:0]     clean_up_to;
        logic   [COUNT_W-1:0]   req_count;
    } prepare_msg_hdr;
    localparam PREPARE_MSG_HDR_W = $bits(prepare_msg_hdr);
    localparam PREPARE_HDR_BYTES = PREPARE_MSG_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] opnum;
        logic   [INT_W-1:0] rep_index;
        logic   [INT_W-1:0] last_committed;
    } prepare_ok_hdr;
    localparam PREPARE_OK_HDR_W = $bits(prepare_ok_hdr);
    localparam PREPARE_OK_HDR_BYTES = PREPARE_OK_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0]     view;
        logic   [INT_W-1:0]     opnum;
    } commit_msg_hdr;
    localparam COMMIT_MSG_HDR_W = $bits(commit_msg_hdr);

    typedef struct packed {
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] rep_index;
        logic   [INT_W-1:0] last_committed;
    } start_view_change_hdr;
    localparam START_VIEW_CHANGE_HDR_W = $bits(start_view_change_hdr);
    localparam START_VIEW_CHANGE_HDR_BYTES = START_VIEW_CHANGE_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] last_norm_view;
        logic   [INT_W-1:0] last_op;
        logic   [INT_W-1:0] last_committed;
        logic   [INT_W-1:0] rep_index;
        logic   [INT_W-1:0] byte_count;
    } do_view_change_hdr;
    localparam DO_VIEW_CHANGE_HDR_W = $bits(do_view_change_hdr);
    localparam DO_VIEW_CHANGE_HDR_BYTES = DO_VIEW_CHANGE_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] last_op;
        logic   [INT_W-1:0] last_committed;
        logic   [INT_W-1:0] byte_count;
    } start_view_hdr;
    localparam START_VIEW_HDR_W = $bits(start_view_hdr);
    localparam START_VIEW_HDR_BYTES = START_VIEW_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0]         curr_view;
        logic   [INT_W-1:0]         last_op;
        logic   [INT_W-1:0]         my_replica_index;
        logic   [INT_W-1:0]         first_log_op;
        logic   [LOG_HDR_DEPTH_W:0] hdr_log_head;
        logic   [LOG_HDR_DEPTH_W:0] hdr_log_tail;
        logic   [LOG_DEPTH_W:0]     data_log_head;
        logic   [LOG_DEPTH_W:0]     data_log_tail;
        logic   [INT_W-1:0]         last_commit;
        rep_status                  curr_status;
    } vr_state;
    localparam VR_STATE_W = $bits(vr_state);

    typedef struct packed {
        logic   [INT_W-1:0]         view;
        logic   [INT_W-1:0]         op_num;
        logic   [INT_W-1:0]         log_entry_state;
        logic   [INT_W-1:0]         payload_len;
        logic   [LOG_DEPTH_W-1:0]   payload_addr;
        logic   [INT_W-1:0]         req_count;
    } log_entry_hdr;
    localparam LOG_ENTRY_HDR_W = $bits(log_entry_hdr);

    typedef struct packed {
        logic   [INT_W-1:0] clientid;
        logic   [INT_W-1:0] clientreqid;
        logic   [INT_W-1:0] op_bytes_len;
    } request_hdr;
    localparam REQUEST_HDR_W = $bits(request_hdr);
    localparam REQUEST_HDR_BYTES = REQUEST_HDR_W/8;

    typedef struct packed {
        logic   [INT_W-1:0] total_size;
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] op_num;
        logic   [INT_W-1:0] log_entry_state;
        // FIXME: this assumes the hash is never used
        logic   [INT_W-1:0] hash_bytes_count;
    } log_reader_wire_hdr;
    localparam LOG_READER_WIRE_HDR_W = $bits(log_reader_wire_hdr);
    localparam LOG_READER_WIRE_HDR_BYTES = LOG_READER_WIRE_HDR_W/8;
    
    typedef struct packed {
        logic   [INT_W-1:0] total_size;
        logic   [INT_W-1:0] view;
        logic   [INT_W-1:0] op_num;
        logic   [INT_W-1:0] log_entry_state;
        // FIXME: this assumes the hash is never used
        logic   [INT_W-1:0] hash_bytes_count;
        request_hdr         request;
    } wire_log_entry_hdr;
    localparam WIRE_LOG_ENTRY_HDR_W = $bits(wire_log_entry_hdr);
    localparam WIRE_LOG_ENTRY_HDR_BYTES = WIRE_LOG_ENTRY_HDR_W/8;
    
    typedef struct packed {
        logic   [`IP_ADDR_W-1:0]    ip_addr;
        logic   [`PORT_NUM_W-1:0]   port_num;
    } machine_tuple;
    localparam MACHINE_TUPLE_W = $bits(machine_tuple);

    localparam CONFIG_NODE_CNT_W = 32;
    localparam MACHINE_INFO_W = `NOC_DATA_WIDTH - MACHINE_TUPLE_W - CONFIG_NODE_CNT_W;
    localparam MAX_CLUSTER_SIZE = (MACHINE_INFO_W + MACHINE_TUPLE_W)/MACHINE_TUPLE_W;
    localparam CONFIG_ADDR_W = $clog2(MAX_CLUSTER_SIZE);
    typedef struct packed {
        logic   [CONFIG_NODE_CNT_W-1:0] node_cnt;
        machine_tuple                   our_tuple;
        logic   [MACHINE_INFO_W-1:0]    machine_config;
    } config_pkt; 




endpackage
