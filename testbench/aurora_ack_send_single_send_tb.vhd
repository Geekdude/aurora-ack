library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use ieee.math_real.all;

use std.env.stop;

entity aurora_ack_send_single_send_tb is
    end aurora_ack_send_single_send_tb;

architecture testbench of aurora_ack_send_single_send_tb is
    component aurora_ack_send
        generic (
            -- Packet Parameters
            WORD_SIZE          : positive := 32;
            FRAME_WIDTH        : positive := 512;

            -- Flood control Parameters
            MAX_FLOOD  : positive := 2;
            FLOOD_WAIT : positive := 100;
            NEW_PACKET_RESETS : boolean := TRUE
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

    constant WORD_SIZE   : positive := 64;
    constant FRAME_WIDTH : positive := 512;

    -- Inputs
    signal rst_n             : std_logic := '0';
    signal m_axi_tx_tready   : std_logic := '0';
    signal s_axi_send_tdata  : std_logic_vector(FRAME_WIDTH - 1 downto 0) := (others => '0');
    signal s_axi_send_tkeep  : std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0) := (others => '0');
    signal s_axi_send_tvalid : std_logic := '0';
    signal s_axi_send_tlast  : std_logic := '0';
    signal ack_num           : std_logic_vector(8 - 1 downto 0) := (others => '0');
    signal ack_set           : std_logic := '0';
    signal ack_send          : std_logic_vector(8 - 1 downto 0) := (others => '0');

    -- Outputs
    signal m_axi_tx_tdata          : std_logic_vector(WORD_SIZE - 1 downto 0) := (others => '0');
    signal m_axi_tx_tvalid         : std_logic := '0';
    signal m_axi_tx_tkeep          : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0) := (others => '0');
    signal m_axi_tx_tlast          : std_logic := '0';
    signal s_axi_send_tready       : std_logic := '0';

    -- Clock
    signal   clk : STD_LOGIC;
    constant clk_period : time := 10 ns;

begin
    clock : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    UUT : aurora_ack_send
    generic map (
        WORD_SIZE         => WORD_SIZE,
        FRAME_WIDTH       => FRAME_WIDTH,
        MAX_FLOOD         => 1,
        FLOOD_WAIT        => 800,
        NEW_PACKET_RESETS => FALSE
    )
    port map (
            clk                      =>   clk,
            rst_n                    =>   rst_n,
            m_axi_tx_tdata           =>   m_axi_tx_tdata,
            m_axi_tx_tvalid          =>   m_axi_tx_tvalid,
            m_axi_tx_tready          =>   m_axi_tx_tready,
            m_axi_tx_tkeep           =>   m_axi_tx_tkeep,
            m_axi_tx_tlast           =>   m_axi_tx_tlast,
            s_axi_send_tdata         =>   s_axi_send_tdata,
            s_axi_send_tkeep         =>   s_axi_send_tkeep,
            s_axi_send_tready        =>   s_axi_send_tready,
            s_axi_send_tvalid        =>   s_axi_send_tvalid,
            s_axi_send_tlast         =>   s_axi_send_tlast,
            ack_num                  =>   ack_num,
            ack_set                  =>   ack_set,
            ack_send                 =>   ack_send
    );

    test : process
        type packets_t is array(0 to 100) of std_logic_vector(FRAME_WIDTH - 1 downto 0);
        variable packets : packets_t;

        procedure send_packet(packet_p: std_logic_vector(FRAME_WIDTH - 1 downto 0)) is
        begin
            report "Sending packet";
            s_axi_send_tdata <= packet_p;
            s_axi_send_tkeep <= (others => '1');
            s_axi_send_tvalid <= '1';
            s_axi_send_tlast  <= '1';
            assert(s_axi_send_tready = '1')
                report "Send is not ready to receive."
                severity failure;
            wait for 1 * clk_period;
            s_axi_send_tlast <= '0';
            s_axi_send_tvalid <= '0';
        end send_packet;

        procedure ack_packet(ack_num_p: std_logic_vector(7 downto 0); ack_send_p: std_logic_vector(7 downto 0)) is
        begin
            ack_num   <= ack_num_p;
            ack_send  <= ack_send_p;
            ack_set   <= '1';
            wait for 1 * clk_period;
            ack_set   <= '0';
            wait for 1 * clk_period;
        end ack_packet;

        procedure verify_ack_packet(ack_send_p: std_logic_vector(7 downto 0)) is
        begin
            m_axi_tx_tready <= '1';

            -- Verify header
            assert(m_axi_tx_tvalid = '1')
                report "TX packet not ready."
                severity failure;
            assert(m_axi_tx_tdata(15 downto 8) = ack_send_p)
                report "TX packet number does not match"
                severity failure;
            assert(m_axi_tx_tdata(31) = '0')
                report "TX packet is not a data packet"
                severity failure;
            assert(m_axi_tx_tlast = '1')
                report "TX Last is asserted"
                severity failure;

            wait for clk_period;
            m_axi_tx_tready <= '0';
            wait for clk_period;
        end verify_ack_packet;

        procedure verify_packet(packet_no_p: std_logic_vector(7 downto 0); packet_p: std_logic_vector(FRAME_WIDTH - 1 downto 0); ack_send_p: std_logic_vector(7 downto 0)) is
        begin
            m_axi_tx_tready <= '1';

            -- Verify header
            assert(m_axi_tx_tvalid = '1')
                report "TX packet not ready."
                severity failure;
            assert(m_axi_tx_tdata(7 downto 0) = packet_no_p)
                report "TX packet number does not match"
                severity failure;
            assert(m_axi_tx_tdata(15 downto 8) = ack_send_p)
                report "TX packet number does not match"
                severity failure;
            assert(m_axi_tx_tdata(31) = '1')
                report "TX packet is not a data packet"
                severity failure;
            assert(m_axi_tx_tlast = '0')
                report "TX Last is asserted"
                severity failure;

            wait for clk_period;

            -- Verify data
            for i in 0 to 7 loop
                assert(m_axi_tx_tvalid = '1')
                    report "TX packet not ready."
                    severity failure;
                assert(m_axi_tx_tdata = packet_p(WORD_SIZE*i+WORD_SIZE-1 downto WORD_SIZE*i))
                    report "TX data packet does not match"
                    severity failure;
                if (i = 7) then
                    assert(m_axi_tx_tlast = '1')
                        report "TX Last is not asserted"
                        severity failure;
                else
                    assert(m_axi_tx_tlast = '0')
                        report "TX Last is asserted"
                        severity failure;
                end if;

                wait for clk_period;
            end loop;
            m_axi_tx_tready <= '0';
            wait for clk_period;
            wait for clk_period;
        end verify_packet;

        procedure verify_empty is
        begin
            m_axi_tx_tready <= '1';

            assert(m_axi_tx_tvalid = '0')
                report "TX packet ready."
                severity failure;

            wait for clk_period;

            m_axi_tx_tready <= '0';
            wait for clk_period;
        end verify_empty;

        function random_packet return std_logic_vector is
            variable seed1 : positive;
            variable seed2 : positive;
            variable re1 : integer;
            variable re2 : real;
            variable packet : std_logic_vector(FRAME_WIDTH - 1 downto 0);
        begin

            uniform (seed1, seed2, re2);
            re1 := integer(re2 * real(2**30 -1));
            packet := std_logic_vector(to_unsigned (re1,FRAME_WIDTH));
            return packet;
        end random_packet;


    begin
        -- Set initial values
        m_axi_tx_tready     <= '0';
        s_axi_send_tdata    <= (others => '0');
        s_axi_send_tkeep    <= (others => '0');
        s_axi_send_tvalid   <= '0';
        s_axi_send_tlast    <= '0';
        ack_num   <= (others => '0');
        ack_set   <= '0';
        ack_send  <= (others => '0');

        -- Generate random packets
        for i in 0 to 100 loop
            packets(i) := random_packet;
        end loop;

        -- Reset
        report "Sending reset";
        rst_n <= '0';
        wait for 16 * clk_period;
        rst_n <= '1';
        wait for 2 * clk_period;

        -- Ready to send
        assert s_axi_send_tready = '1' report "Not ready to send" severity failure;

        -- Send 3 Packets
        packets(0) := std_logic_vector(to_unsigned(1,FRAME_WIDTH));
        send_packet(packets(0));
        send_packet(packets(1));
        send_packet(packets(2));

        -- Verify 3 Packets
        verify_packet(x"01", packets(0), x"00");
        verify_packet(x"02", packets(1), x"00");
        verify_packet(x"03", packets(2), x"00");

        -- Send 2 more Packets after a delay
        wait for 100 * clk_period;
        send_packet(packets(3));
        send_packet(packets(4));
        wait for 10 * clk_period;

        -- Verify the two packets
        verify_packet(x"04", packets(3), x"00");
        verify_packet(x"05", packets(4), x"00");

        wait for 900 * clk_period;

        -- After the timeout verify all of the packets again
        verify_packet(x"01", packets(0), x"00");
        verify_packet(x"02", packets(1), x"00");
        verify_packet(x"03", packets(2), x"00");
        verify_packet(x"04", packets(3), x"00");
        verify_packet(x"05", packets(4), x"00");
        verify_packet(x"01", packets(0), x"00");
        verify_packet(x"02", packets(1), x"00");
        verify_packet(x"03", packets(2), x"00");
        verify_packet(x"04", packets(3), x"00");
        verify_packet(x"05", packets(4), x"00");

        wait for 10 * clk_period;

        -- Send an ack of the packets so that the sending window is empty.
        ack_packet(x"05", x"00");
        wait for 30 * clk_period;
        -- Verify the ack
        verify_ack_packet(x"00");
        wait for 10 * clk_period;


        -- Make sure that the sending works correctly after emptying the send window.
        wait for 0 * clk_period;
        send_packet(packets(5));
        wait for 10 * clk_period;
        send_packet(packets(6));
        wait for 10 * clk_period;
        verify_packet(x"06", packets(5), x"00");
        verify_packet(x"07", packets(6), x"00");

        wait for 10 * clk_period;
        report "Simulation Finished";
        stop(0);
    end process;

end testbench;
