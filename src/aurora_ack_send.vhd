----------------------------------------------------------------------------------
-- Company: The University of Tennessee, Knoxville
-- Engineer: Aaron Young
--
-- Design Name: Aurora Acknowledgement Send
-- Project Name: DANNA 2
-- Tool Versions: Vivado 2016.4 or later
-- Description: Send logic for Aurora acknowledgement.
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


--------------------------------------------------------------------------------
-- Aurora Acknowledgement.
--
--   Acknowledges Aurora Frames.

entity aurora_ack_send is
    generic (
        -- Packet Parameters
        WORD_SIZE          : positive := 32;
        FRAME_WIDTH        : positive := 512;

        -- Flood control Parameters
        MAX_FLOOD         : positive := 2;
        FLOOD_WAIT        : positive := 100;
        NEW_PACKET_RESETS : boolean  := TRUE
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
end aurora_ack_send;

architecture Behavioral of aurora_ack_send is

    -- Size of the sequence numbers
    constant NUM_SIZE : positive := 8;
    constant PACKET_SELECT_BITS : positive := 4;

    component packet_to_word
        generic (
            FRAME_SIZE : positive := 512;
            WORD_SIZE  : positive := 64
        );
        port (
            clk                : in  std_logic;
            rst_n              : in  std_logic;

            s_axi_tdata        : in  std_logic_vector(FRAME_SIZE - 1 downto 0);
            s_axi_tkeep        : in  std_logic_vector((integer(FRAME_SIZE) / 8) - 1 downto 0);
            s_axi_tready       : out std_logic;
            s_axi_tvalid       : in  std_logic;
            s_axi_tlast        : in  std_logic;

            m_axi_tdata        : out std_logic_vector(WORD_SIZE - 1 downto 0);
            m_axi_tvalid       : out std_logic;
            m_axi_tready       : in  std_logic;
            m_axi_tkeep        : out std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
            m_axi_tlast        : out std_logic
        );
    end component;

    component window_buffer
        generic (
            FRAME_WIDTH  : positive := 520;
            PACKET_SELECT_BITS : positive := 4
        );
        port (
            clk   : in std_logic;
            rst_n : in std_logic;

            -- Write
            wr_tdata  :  in  std_logic_vector(FRAME_WIDTH - 1 downto 0);
            wr_tvalid :  in  std_logic;
            wr_tkeep  :  in  std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

            -- Read
            rd_tdata  :  out std_logic_vector(FRAME_WIDTH - 1 downto 0);
            rd_tvalid :  out std_logic;
            rd_tkeep  :  out std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

            -- Control signals
            packet          :  in  std_logic_vector(PACKET_SELECT_BITS - 1 downto 0);
            drop            :  in  std_logic;

            -- Status signals
            count           :  out std_logic_vector(PACKET_SELECT_BITS downto 0);
            full            :  out std_logic;
            empty           :  out std_logic
        );
    end component;

    signal axis_mem_to_window_tvalid : std_logic;
    signal axis_mem_to_window_tready : std_logic;
    signal axis_mem_to_window_tdata  : std_logic_vector(FRAME_WIDTH - 1 downto 0);
    signal axis_mem_to_window_tkeep  : std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0);
    signal axis_mem_to_window_tlast  : std_logic;

    signal axis_window_to_aurora_tvalid : std_logic;
    signal axis_window_to_aurora_tready : std_logic;
    signal axis_window_to_aurora_tdata  : std_logic_vector(FRAME_WIDTH + WORD_SIZE - 1 downto 0);
    signal axis_window_to_aurora_tkeep  : std_logic_vector((integer(FRAME_WIDTH + WORD_SIZE) / 8) - 1 downto 0);
    signal axis_window_to_aurora_tlast  : std_logic;


    -- Sliding window signals
    signal sw_wr_tdata  : std_logic_vector(FRAME_WIDTH + 7 downto 0);
    signal sw_wr_tvalid : std_logic;
    signal sw_wr_tkeep  : std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0);
    signal sw_rd_tdata  : std_logic_vector(FRAME_WIDTH + 7 downto 0);
    signal sw_rd_tvalid : std_logic;
    signal sw_rd_tkeep  : std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0);
    signal sw_packet    : std_logic_vector(PACKET_SELECT_BITS - 1 downto 0);
    signal sw_drop      : std_logic;
    signal sw_count     : std_logic_vector(PACKET_SELECT_BITS downto 0);
    signal sw_full      : std_logic;
    signal sw_empty     : std_logic;

    -- Send state variables
    type send_state_t is (SEND_INIT, SEND_DROP, SEND_ACK, SEND_SEND);
    signal send_state : send_state_t;
    signal send_tvalid : std_logic;
    signal send_data_pkt :std_logic;
    signal send_ack_diff : std_logic_vector(NUM_SIZE - 1 downto 0);
    signal send_ack_greater : std_logic;
    signal send_ack_cur_num : std_logic_vector(NUM_SIZE - 1 downto 0);

    -- Ack between sender and receiver
    signal ack_num_l    : std_logic_vector(NUM_SIZE - 1 downto 0);
    signal ack_new      : std_logic;
    signal ack_clear    : std_logic;
    signal ack_send_l   : std_logic_vector(NUM_SIZE - 1 downto 0);

    -- Sender counts
    signal Sm : std_logic_vector(NUM_SIZE - 1 downto 0);
    signal Sn : std_logic_vector(PACKET_SELECT_BITS - 1 downto 0);

    -- Flood protection
    signal resend_count : integer range 0 to MAX_FLOOD;
    signal resend_count_clr : std_logic;
    signal wait_count   : integer range 0 to FLOOD_WAIT;

begin

    -- Send goes to to the memory signals
    axis_mem_to_window_tvalid <= s_axi_send_tvalid;
    s_axi_send_tready         <= axis_mem_to_window_tready;
    axis_mem_to_window_tdata  <= s_axi_send_tdata;
    axis_mem_to_window_tkeep  <= s_axi_send_tkeep;
    axis_mem_to_window_tlast  <= s_axi_send_tlast;

    -- Use a width converter to convert the frame to output size
    output_wc_latch : packet_to_word
    generic map (
        FRAME_SIZE => FRAME_WIDTH + WORD_SIZE,
        WORD_SIZE  => WORD_SIZE
    )
    port map (
        clk => clk,
        rst_n => rst_n,

        s_axi_tvalid => axis_window_to_aurora_tvalid,
        s_axi_tready => axis_window_to_aurora_tready,
        s_axi_tdata => axis_window_to_aurora_tdata,
        s_axi_tkeep => axis_window_to_aurora_tkeep,
        s_axi_tlast => axis_window_to_aurora_tlast,

        m_axi_tvalid => m_axi_tx_tvalid,
        m_axi_tready => m_axi_tx_tready,
        m_axi_tdata => m_axi_tx_tdata,
        m_axi_tkeep => m_axi_tx_tkeep,
        m_axi_tlast => m_axi_tx_tlast
    );

    -- Use a window buffer to store packets in the send window
    sliding_window : window_buffer
    generic map (
        FRAME_WIDTH => FRAME_WIDTH+8,
        PACKET_SELECT_BITS => 4
    )
    port map (
        clk       => clk,
        rst_n     => rst_n,
        wr_tdata  => sw_wr_tdata,
        wr_tvalid => sw_wr_tvalid,
        wr_tkeep  => sw_wr_tkeep,
        rd_tdata  => sw_rd_tdata,
        rd_tvalid => sw_rd_tvalid,
        rd_tkeep  => sw_rd_tkeep,
        drop      => sw_drop,
        packet    => sw_packet,
        count     => sw_count,
        full      => sw_full,
        empty     => sw_empty
    );

    -- Process to add packets to the sliding window
    add_to_window : process(clk, rst_n)
    begin
        -- First packet has sequence number 1.
        if (rst_n = '0') then
            Sm <= (0 => '1', others => '0');
            resend_count_clr <= '0';
        -- Sequence numbers are increased by 1
        elsif (rising_edge(clk)) then
            resend_count_clr <= '0';
            if (axis_mem_to_window_tvalid = '1' and sw_full = '0' and axis_mem_to_window_tlast = '1') then
                Sm <= std_logic_vector(unsigned(Sm) + 1);

                -- Reset resend count when new packets are received.
                if (NEW_PACKET_RESETS = true or sw_empty = '1') then
                    resend_count_clr <= '1';
                end if;

            end if;
        end if;
    end process;
    sw_wr_tdata(FRAME_WIDTH - 1 downto 0) <= axis_mem_to_window_tdata;
    sw_wr_tdata(FRAME_WIDTH + 8 - 1 downto FRAME_WIDTH) <= Sm;
    sw_wr_tvalid <= axis_mem_to_window_tvalid;
    sw_wr_tkeep <= axis_mem_to_window_tkeep;
    axis_mem_to_window_tready <= not sw_full;

    -- Process to send and drop from the sliding window
    send_drop_p : process(clk, rst_n)
        variable resend_count_v : integer range 0 to MAX_FLOOD;
    begin
        -- Reset state
        if (rst_n = '0') then
            Sn <= (others => '0');
            send_state <= SEND_INIT;
            send_tvalid <= '0';
            send_data_pkt <= '0';
            resend_count <= 0;
            wait_count <= 0;

        elsif (rising_edge(clk)) then
            resend_count_v := resend_count;

            -- Reset the resend count
            if (resend_count_clr = '1') then
                resend_count_v := 0;
            end if;

            -- Handle the wait count
            if (resend_count_v = MAX_FLOOD) then
                if (wait_count = FLOOD_WAIT) then
                    resend_count_v := 0;
                else
                    wait_count <= wait_count + 1;
                end if;
            else
                wait_count <= 0;
            end if;

            -- When new packets don't reset the wait count, reset the wait count
            -- when acknowledge packets are received.
            if (NEW_PACKET_RESETS = FALSE and ack_new = '1') then
                wait_count <= 0;
            end if;

            case send_state is
                -- Initial state
                when SEND_INIT =>
                    -- If the output window is ready and the sliding window is not empty,
                    -- then send the next packet in the window.
                    if (axis_window_to_aurora_tready = '1' and sw_empty = '0' and
                    (resend_count_v < MAX_FLOOD or (unsigned(Sn)+1) < unsigned(sw_count))) then
                        -- Wrap around once the packets are sent
                        if ((unsigned(Sn)+1) >= unsigned(sw_count)) then
                            Sn <= (others => '0');
                            resend_count_v := resend_count_v + 1;
                        else
                            Sn <= std_logic_vector(unsigned(Sn) + 1);
                        end if;
                        send_state <= SEND_SEND;
                        send_tvalid <= '1';

                    -- If the sliding window is not empty and the ack number is greater than the first packet or has wrapped around or is equal,
                    -- drop the first packet.
                    elsif (sw_empty = '0' and ((send_ack_greater = '1' and unsigned(send_ack_diff) < 2**(PACKET_SELECT_BITS + 1)) or
                    unsigned(send_ack_diff) = 0 or
                    (send_ack_greater = '0' and unsigned(send_ack_diff) > 2**(PACKET_SELECT_BITS + 1)))) then
                        send_state <= SEND_DROP;

                    -- If there is a new ack number and the sender is ready,
                    -- Send an ack only packet.
                    elsif (axis_window_to_aurora_tready = '1' and ack_new = '1') then
                        send_state <= SEND_ACK;
                        send_tvalid <= '1';
                    end if;

                -- Send a packet
                when SEND_SEND =>
                    if (axis_window_to_aurora_tready = '1') then
                        send_tvalid <= '0';
                        send_state <= SEND_INIT;
                    end if;

                -- Drop a packet from the send window
                when SEND_DROP =>
                    send_state <= SEND_INIT;
                    -- Back up the current send place if Sn is greater than 0
                    if ((unsigned(Sn)) > 0) then
                        Sn <= std_logic_vector(unsigned(Sn) - 1);
                    end if;

                -- Send an acknowledgement
                when SEND_ACK  =>
                    if (axis_window_to_aurora_tready = '1') then
                        send_tvalid <= '0';
                        send_state <= SEND_INIT;
                    end if;

                -- If error state, go back to init
                when others =>
                    send_state <= SEND_INIT;
            end case;
                resend_count <= resend_count_v;
        end if;
    end process;

    -- Based on the state, update the signals
    process(send_state, sw_rd_tdata, sw_rd_tkeep)
    begin
        case send_state is
            when SEND_INIT =>
                sw_drop <= '0';
                sw_packet <= (others => '0');
                ack_clear <= '0';
                axis_window_to_aurora_tdata(FRAME_WIDTH+WORD_SIZE-1 downto WORD_SIZE) <= sw_rd_tdata(FRAME_WIDTH-1 downto 0);
                axis_window_to_aurora_tdata(WORD_SIZE-1  downto 32) <= (others => '0');
                axis_window_to_aurora_tdata(7 downto 0) <= sw_rd_tdata(FRAME_WIDTH+8-1 downto FRAME_WIDTH);
                axis_window_to_aurora_tdata(15 downto 8) <= ack_send_l;
                axis_window_to_aurora_tdata(30 downto 16) <= (others => '0');
                axis_window_to_aurora_tdata(31) <= '1';
                axis_window_to_aurora_tkeep((integer(FRAME_WIDTH+WORD_SIZE) / 8) - 1 downto (integer(WORD_SIZE) / 8)) <= sw_rd_tkeep;
                axis_window_to_aurora_tkeep((integer(WORD_SIZE) / 8) - 1 downto 0) <= (others => '1');

            when SEND_SEND =>
                sw_drop <= '0';
                sw_packet <= Sn;
                ack_clear <= '1';
                axis_window_to_aurora_tdata(FRAME_WIDTH+WORD_SIZE-1 downto WORD_SIZE) <= sw_rd_tdata(FRAME_WIDTH-1 downto 0);
                axis_window_to_aurora_tdata(WORD_SIZE-1  downto 32) <= (others => '0');
                axis_window_to_aurora_tdata(7 downto 0) <= sw_rd_tdata(FRAME_WIDTH+8-1 downto FRAME_WIDTH);
                axis_window_to_aurora_tdata(15 downto 8) <= ack_send_l;
                axis_window_to_aurora_tdata(30 downto 16) <= (others => '0');
                axis_window_to_aurora_tdata(31) <= '1';
                axis_window_to_aurora_tkeep((integer(FRAME_WIDTH+WORD_SIZE) / 8) - 1 downto (integer(WORD_SIZE) / 8)) <= sw_rd_tkeep;
                axis_window_to_aurora_tkeep((integer(WORD_SIZE) / 8) - 1 downto 0) <= (others => '1');

            when SEND_DROP =>
                sw_drop <= '1';
                sw_packet <= (others => '0');
                ack_clear <= '0';
                axis_window_to_aurora_tdata(FRAME_WIDTH+WORD_SIZE-1 downto WORD_SIZE) <= sw_rd_tdata(FRAME_WIDTH-1 downto 0);
                axis_window_to_aurora_tdata(WORD_SIZE-1  downto 32) <= (others => '0');
                axis_window_to_aurora_tdata(7 downto 0) <= sw_rd_tdata(FRAME_WIDTH+8-1 downto FRAME_WIDTH);
                axis_window_to_aurora_tdata(15 downto 8) <= ack_send_l;
                axis_window_to_aurora_tdata(30 downto 16) <= (others => '0');
                axis_window_to_aurora_tdata(31) <= '1';
                axis_window_to_aurora_tkeep((integer(FRAME_WIDTH+WORD_SIZE) / 8) - 1 downto (integer(WORD_SIZE) / 8)) <= sw_rd_tkeep;
                axis_window_to_aurora_tkeep((integer(WORD_SIZE) / 8) - 1 downto 0) <= (others => '1');

            when SEND_ACK  =>
                sw_drop <= '0';
                sw_packet <= (others => '0');
                ack_clear <= '1';
                axis_window_to_aurora_tdata(FRAME_WIDTH+WORD_SIZE-1 downto WORD_SIZE) <= sw_rd_tdata(FRAME_WIDTH-1 downto 0);
                axis_window_to_aurora_tdata(WORD_SIZE-1  downto 32) <= (others => '0');
                axis_window_to_aurora_tdata(7 downto 0) <= sw_rd_tdata(FRAME_WIDTH+8-1 downto FRAME_WIDTH);
                axis_window_to_aurora_tdata(15 downto 8) <= ack_send_l;
                axis_window_to_aurora_tdata(30 downto 16) <= (others => '0');
                axis_window_to_aurora_tdata(31) <= '0';
                axis_window_to_aurora_tkeep((integer(FRAME_WIDTH+WORD_SIZE) / 8) - 1 downto (integer(WORD_SIZE) / 8)) <= (others => '0');
                axis_window_to_aurora_tkeep((integer(WORD_SIZE) / 8) - 1 downto 0) <= (others => '1');

        end case;
    end process;

    -- AXI send to width converter is only valid if the send and the incoming data
    -- is valid.
    process(send_tvalid, sw_rd_tvalid, send_state)
    begin
        if (send_state = SEND_ACK) then
            axis_window_to_aurora_tvalid <= send_tvalid;
        else
            axis_window_to_aurora_tvalid <= send_tvalid and sw_rd_tvalid;
        end if;
    end process;

    -- Packets are sent as complete frames.
    axis_window_to_aurora_tlast <= '1';

    -- Compute the difference between the sliding window ack and the current received ack
    process(send_ack_cur_num, ack_num_l, send_ack_greater)
    begin
        if (send_ack_greater = '1') then
            send_ack_diff <= std_logic_vector(unsigned(ack_num_l) - unsigned(send_ack_cur_num));
        else
            send_ack_diff <= std_logic_vector(unsigned(send_ack_cur_num) - unsigned(ack_num_l));
        end if;
    end process;

    -- Read the lowest send ack number from the sliding window
    send_ack_cur_num <= sw_rd_tdata(519 downto 512);

    -- Process to determine if the sliding window ack is greater or less than the current received ack
    process(ack_num_l, sw_rd_tdata)
    begin
        if (unsigned(ack_num_l) > unsigned(send_ack_cur_num)) then
            send_ack_greater <= '1';
        else
            send_ack_greater <= '0';
        end if;
    end process;

    -- Latch used to pass acknowledgement from recv to send
    ack_latch : process(clk, rst_n, ack_clear)
    begin
        if (rst_n = '0') then
            ack_new <= '0';
            ack_num_l <= (others => '0');
            ack_send_l <= (others => '0');
        elsif(ack_clear = '1') then
            ack_new <= '0';
        elsif (rising_edge(clk)) then
            ack_num_l <= ack_num;

            if(ack_set = '1') then
                ack_send_l <= ack_send;
                ack_new <= '1';
            end if;
        end if;
    end process;

end Behavioral;
-- vim: shiftwidth=4 tabstop=4 softtabstop=4 expandtab
