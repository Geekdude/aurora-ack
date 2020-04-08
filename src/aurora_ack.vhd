----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name: Aurora Acknowledgement
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description: This entity provides the logic to add acknowledgment to a AXI
-- stream for use over an aurora interface.
-- Additional Comments:
--
-- Go back N pseudocode from Wikipedia.
--
--   N  = window size
--   Rn = request number
--   Sn = sequence number
--   Sb = sequence base
--   Sm = sequence max
--
--   Receiver:
--   Rn = 0
--   Do the following forever:
--   If the packet received = Rn and the packet is error free
--           Accept the packet and send it to a higher layer
--           Rn = Rn + 1
--   Else
--           Refuse packet
--   Send a Request for Rn
--
--   Sender:
--   Sb = 0
--   Sm = N + 1
--   Repeat the following steps forever:
--   1. If you receive a request number where Rn > Sb
--           Sm = (Sm - Sb) + Rn
--           Sb = Rn
--   2.  If no packet is in transmission,
--           Transmit a packet where Sb <= Sn <= Sm.
--           Packets are transmitted in order.
--
--   Header Structure:
-- ------------------------------------------------------------------------------
-- | D | 7 bits unused | unused byte | 8 bits ack number | 8 bits packet number |
-- ------------------------------------------------------------------------------
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity aurora_ack is
    generic (
        -- Packet Parameters
        WORD_SIZE          : positive := 32;
        FRAME_WIDTH        : positive := 512;

        -- Flood control Parameters
        MAX_FLOOD          : positive := 2;
        FLOOD_WAIT         : positive := 100;
        NEW_PACKET_RESETS  : boolean  := TRUE
    );
    Port (
        clk         : in std_logic;
        rst_n       : in std_logic;

        -- TX Stream Interface
        m_axi_tx_tdata          : out std_logic_vector(WORD_SIZE - 1 downto 0);
        m_axi_tx_tvalid         : out std_logic;
        m_axi_tx_tready         : in  std_logic;
        m_axi_tx_tkeep          : out std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
        m_axi_tx_tlast          : out std_logic;

        -- RX Stream Interface
        s_axi_rx_tdata          : in  std_logic_vector(WORD_SIZE - 1 downto 0);
        s_axi_rx_tvalid         : in  std_logic;
        s_axi_rx_tkeep          : in  std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
        s_axi_rx_tlast          : in  std_logic;

        -- Send Stream Interface
        s_axi_send_tdata        : in  std_logic_vector(FRAME_WIDTH - 1 downto 0);
        s_axi_send_tvalid       : in  std_logic;
        s_axi_send_tready       : out std_logic;

        -- Receive Stream Interface
        m_axi_recv_tdata        : out std_logic_vector(FRAME_WIDTH - 1 downto 0);
        m_axi_recv_tvalid       : out std_logic;
        m_axi_recv_tready       : in  std_logic;

        -- Receive CRC
        crc_pass_fail_n         : in std_logic;
        crc_valid               : in std_logic
    );
end aurora_ack;

-- This architecture can be used to disable acknowledgement. The AXI4-stream
-- signals will be passed on with out any change.
architecture Passthrough of aurora_ack is
begin
    m_axi_recv_tdata <= s_axi_rx_tdata;
    m_axi_recv_tvalid<= s_axi_rx_tvalid;

    m_axi_tx_tdata    <= s_axi_send_tdata;
    m_axi_tx_tvalid   <= s_axi_send_tvalid;
    s_axi_send_tready <= m_axi_tx_tready;
    m_axi_tx_tkeep    <= (others => '1');
    m_axi_tx_tlast    <= '1';
end Passthrough;

-- This architecture can be used to perform a local loopback.
architecture Loopback of aurora_ack is
begin
    m_axi_recv_tdata    <= s_axi_send_tdata;
    m_axi_recv_tvalid   <= s_axi_send_tvalid;
    s_axi_send_tready   <= m_axi_recv_tready;
end Loopback;

-- /dev/null /dev/zero
architecture dev of aurora_ack is
begin
    -- Data in to /dev/null
    s_axi_send_tready <= '1';

    -- Data out from /dev/zero
    m_axi_recv_tdata <= (others => '0');
    m_axi_recv_tvalid <= '1';
end dev;

architecture Behavioral of aurora_ack is
    component aurora_ack_send
        generic (
            -- Packet Parameters
            WORD_SIZE          : positive := 32;
            FRAME_WIDTH        : positive := 512;

            -- Flood control Parameters
            MAX_FLOOD          : positive := 2;
            FLOOD_WAIT         : positive := 100;
            NEW_PACKET_RESETS  : boolean  := TRUE
        );
        Port (
            clk         : in std_logic;
            rst_n       : in std_logic;

            -- TX Stream Interface
            m_axi_tx_tdata          : out std_logic_vector(WORD_SIZE - 1 downto 0);
            m_axi_tx_tvalid         : out std_logic;
            m_axi_tx_tready         : in  std_logic;
            m_axi_tx_tkeep          : out std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            m_axi_tx_tlast          : out std_logic;

            -- Send Stream Interface
            s_axi_send_tdata        : in  std_logic_vector(FRAME_WIDTH - 1 downto 0);
            s_axi_send_tkeep        : in  std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0);
            s_axi_send_tready       : out std_logic;
            s_axi_send_tvalid       : in  std_logic;
            s_axi_send_tlast        : in  std_logic;

            -- Ack Interface
            ack_num      : in std_logic_vector(8 - 1 downto 0);
            ack_set      : in std_logic;
            ack_send     : in std_logic_vector(8 - 1 downto 0)
        );
    end component;

    component aurora_ack_recv
        generic (
            WORD_SIZE          : positive := 32;
            FRAME_WIDTH        : positive := 512
        );
        Port (
            clk         : in std_logic;
            rst_n       : in std_logic;

            -- RX Stream Interface
            s_axi_rx_tdata          : in  std_logic_vector(WORD_SIZE - 1 downto 0);
            s_axi_rx_tkeep          : in  std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            s_axi_rx_tvalid         : in  std_logic;
            s_axi_rx_tlast          : in  std_logic;

            -- Receive Stream Interface
            m_axi_recv_tdata        : out std_logic_vector(FRAME_WIDTH - 1 downto 0);
            m_axi_recv_tvalid       : out std_logic;
            m_axi_recv_tready       : in  std_logic;
            m_axi_recv_tkeep        : out std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0);
            m_axi_recv_tlast        : out std_logic;

            -- Ack Interface
            ack_num      : out std_logic_vector(8 - 1 downto 0);
            ack_set      : out std_logic;
            ack_send     : out std_logic_vector(8 - 1 downto 0);

            -- Receive CRC
            crc_pass_fail_n         : in std_logic;
            crc_valid               : in std_logic
        );
    end component;

    signal ack_num      : std_logic_vector(8 - 1 downto 0);
    signal ack_set      : std_logic;
    signal ack_send     : std_logic_vector(8 - 1 downto 0);

begin

    -- Connect the send component of the retransmission logic
    aurora_ack_send_i : aurora_ack_send
    generic map (
        WORD_SIZE         => WORD_SIZE,
        FRAME_WIDTH       => FRAME_WIDTH,

        MAX_FLOOD         => MAX_FLOOD,
        FLOOD_WAIT        => FLOOD_WAIT,
        NEW_PACKET_RESETS => NEW_PACKET_RESETS
    )
    port map (
        clk               => clk,
        rst_n             => rst_n,
        m_axi_tx_tdata    => m_axi_tx_tdata,
        m_axi_tx_tvalid   => m_axi_tx_tvalid,
        m_axi_tx_tready   => m_axi_tx_tready,
        m_axi_tx_tkeep    => m_axi_tx_tkeep,
        m_axi_tx_tlast    => m_axi_tx_tlast,
        s_axi_send_tdata  => s_axi_send_tdata,
        s_axi_send_tkeep  => (others => '1'),
        s_axi_send_tready => s_axi_send_tready,
        s_axi_send_tvalid => s_axi_send_tvalid,
        s_axi_send_tlast  => '1',
        ack_num           => ack_num,
        ack_set           => ack_set,
        ack_send          => ack_send
    );

    -- Connect the receive component of the retransmission logic
    aurora_ack_recv_i : aurora_ack_recv
    generic map (
        WORD_SIZE          => WORD_SIZE,
        FRAME_WIDTH        => FRAME_WIDTH
    )
    Port map (
        clk               => clk,
        rst_n             => rst_n,
        s_axi_rx_tdata    => s_axi_rx_tdata,
        s_axi_rx_tkeep    => s_axi_rx_tkeep,
        s_axi_rx_tvalid   => s_axi_rx_tvalid,
        s_axi_rx_tlast    => s_axi_rx_tlast,
        m_axi_recv_tdata  => m_axi_recv_tdata,
        m_axi_recv_tvalid => m_axi_recv_tvalid,
        m_axi_recv_tready => m_axi_recv_tready,
        m_axi_recv_tkeep  => open,
        m_axi_recv_tlast  => open,
        ack_num           => ack_num,
        ack_set           => ack_set,
        ack_send          => ack_send,
        crc_pass_fail_n   => crc_pass_fail_n,
        crc_valid         => crc_valid
    );

end Behavioral;

-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
