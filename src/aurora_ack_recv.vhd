----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name: Aurora Acknowledgement Receive
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description: Receive logic for Aurora acknowledgement.
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
-- | D | 7 bytes unused| unused byte | 8 byte ack number | 8 byte packet number |
-- ------------------------------------------------------------------------------
-------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity aurora_ack_recv is
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
end aurora_ack_recv;

architecture Behavioral of aurora_ack_recv is

    -- Size of the sequence numbers
    constant NUM_SIZE : positive := 8;
    constant PACKET_SELECT_BITS : positive := 4;

    constant ONES : std_logic_vector((integer(FRAME_WIDTH+WORD_SIZE)/8)-1 downto 0) := (others => '1');
    signal ONE_WORD : std_logic_vector((integer(FRAME_WIDTH+WORD_SIZE)/8)-1 downto 0);

    component word_to_packet
    generic (
        FRAME_SIZE : positive := 512;
        WORD_SIZE  : positive := 64
    );
    port (
        clk                : in  std_logic;
        rst_n              : in  std_logic;

        s_axi_tdata        : in  std_logic_vector(WORD_SIZE - 1 downto 0);
        s_axi_tkeep        : in  std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
        s_axi_tready       : out std_logic;
        s_axi_tvalid       : in  std_logic;
        s_axi_tlast        : in  std_logic;

        m_axi_tdata        : out std_logic_vector(FRAME_SIZE - 1 downto 0);
        m_axi_tvalid       : out std_logic;
        m_axi_tready       : in  std_logic;
        m_axi_tkeep        : out std_logic_vector((integer(FRAME_SIZE) / 8) - 1 downto 0);
        m_axi_tlast        : out std_logic
    );
    end component;

    constant KEEP_BITS : positive := (integer(FRAME_WIDTH) / 8);

    -- AXI4-stream input interface
    signal axis_in_tvalid : std_logic;
    signal axis_in_tdata  : std_logic_vector(FRAME_WIDTH + WORD_SIZE - 1 downto 0);
    signal axis_in_tkeep  : std_logic_vector((integer(FRAME_WIDTH+WORD_SIZE)/8)-1 downto 0);
    signal axis_in_tlast  : std_logic;

    -- AXI4-stream output interface
    signal axis_out_tvalid   : std_logic;
    signal axis_out_tready   : std_logic;
    signal axis_out_tdata    : std_logic_vector(FRAME_WIDTH - 1 downto 0);
    signal axis_out_tkeep    : std_logic_vector(KEEP_BITS - 1 downto 0);
    signal axis_out_tlast    : std_logic;

    -- Receiver counts
    signal Rn : std_logic_vector(NUM_SIZE - 1 downto 0);
    signal Rnp1 : std_logic_vector(NUM_SIZE - 1 downto 0);

begin
    -- Constant assignment of ONE_WORD
    ONE_WORD_P : process(clk)
    begin
        ONE_WORD <= (others => '0');
        ONE_WORD(WORD_SIZE/8-1 downto 0) <= (others => '1');
    end process;

    -- Use a width converter to convert the words into a packet.
    input_wc_latch : word_to_packet
    generic map (
        FRAME_SIZE => FRAME_WIDTH + WORD_SIZE,
        WORD_SIZE  => WORD_SIZE
    )
    port map (
        clk                => clk,
        rst_n              => rst_n,

        s_axi_tdata        => s_axi_rx_tdata,
        s_axi_tkeep        => s_axi_rx_tkeep,
        s_axi_tready       => open,
        s_axi_tvalid       => s_axi_rx_tvalid,
        s_axi_tlast        => s_axi_rx_tlast,

        m_axi_tdata        => axis_in_tdata,
        m_axi_tvalid       => axis_in_tvalid,
        m_axi_tready       => '1',
        m_axi_tkeep        => axis_in_tkeep,
        m_axi_tlast        => axis_in_tlast
    );

    -- Output goes to the recv.
    m_axi_recv_tvalid <= axis_out_tvalid;
    axis_out_tready   <= m_axi_recv_tready;
    m_axi_recv_tdata  <= axis_out_tdata;
    m_axi_recv_tkeep  <= axis_out_tkeep;
    m_axi_recv_tlast  <= axis_out_tlast;

    -- Receive state machine
    recv_logic : process(clk, rst_n)
    begin
        -- Reset state
        if (rst_n = '0') then
            Rn <= (others => '0');
            ack_set <= '0';
            ack_send <= (others => '0');
            ack_num <= (others => '0');
            axis_out_tvalid <= '0';
            axis_out_tdata <= (others => '0');
            axis_out_tkeep <= (others => '0');
            axis_out_tlast <= '0';

        elsif (rising_edge(clk)) then
            -- default values unless changed
            ack_set <= '0';
            ack_send <= Rn;
            axis_out_tvalid <= '0';
            axis_out_tdata <= (others => '0');
            axis_out_tkeep <= (others => '0');
            axis_out_tlast <= '0';

            -- Only increment ack count when data was successfully sent from the width converter.
            if (axis_out_tvalid = '1' and axis_out_tready = '1') then
                ack_send <= Rnp1;
                ack_set <= '1';
                Rn <= Rnp1;
            end if;

            -- if received packet and crc
            if (crc_valid = '1' and axis_in_tlast = '1' and axis_in_tvalid = '1' and crc_pass_fail_n = '1') then
                -- Only pull out the ack number if data packet or header only.
                -- Do not accept the ack number if header only but frame size is wrong.
                -- This fixes a strange issue where the previous packet
                -- passed crc but the valid signal signal was delayed which
                -- causes a corrupt packet to be added to the front of the
                -- next frame.
                if ((axis_in_tdata(31) = '1' and   -- Must be a data packet
                        axis_in_tkeep = ONES) or   -- With full data
                    (axis_in_tdata(31) = '0' and   -- Or must be header only
                        axis_in_tkeep = ONE_WORD)  -- with only word valid bits
                ) then
                    -- pull out the ack number
                    ack_num <= axis_in_tdata(15 downto 8);
                end if;

                -- Check if packet is next in sequence
                if (axis_in_tdata(31) = '1' and           -- Must be data packet
                    Rnp1 = axis_in_tdata(7 downto 0) and  -- Must be next packet
                    axis_in_tkeep = ONES and              -- Must be full packet
                    axis_in_tlast = '1' and               -- Must only be one frame long
                    axis_out_tready = '1'                 -- Receiver must be ready (implements flow control)
                )then
                    axis_out_tvalid <= axis_in_tvalid;
                    axis_out_tdata  <= axis_in_tdata(FRAME_WIDTH + WORD_SIZE - 1 downto WORD_SIZE);
                    axis_out_tkeep  <= axis_in_tkeep(KEEP_BITS + (integer(WORD_SIZE) / 8) - 1 downto (integer(WORD_SIZE) / 8));
                    axis_out_tlast  <= axis_in_tlast;
                end if;

                -- If the packet is the current packet, Resend ack
                if (axis_in_tdata(31) = '1' and          -- Must be data packet
                    Rn  = axis_in_tdata(7 downto 0) and  -- Must be the current packet
                    axis_in_tlast = '1'                  -- Must only be one frame long
                ) then
                    ack_set <= '1';
                end if;
            end if;
        end if;
    end process;

    -- Calculate Rn plus one.
    Rnp1 <= std_logic_vector(unsigned(Rn) + 1);

end Behavioral;
-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
