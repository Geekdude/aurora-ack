library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use std.env.stop;

entity aurora_ack_recv_tb is
    end aurora_ack_recv_tb;

architecture testbench of aurora_ack_recv_tb is
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

    constant WORD_SIZE   : positive := 64;
    constant FRAME_WIDTH : positive := 512;

    -- Input
    signal rst_n                   : std_logic;
    signal s_axi_rx_tdata          : std_logic_vector(WORD_SIZE - 1 downto 0);
    signal s_axi_rx_tkeep          : std_logic_vector((integer(WORD_SIZE) / 8) - 1 downto 0);
    signal s_axi_rx_tvalid         : std_logic;
    signal s_axi_rx_tlast          : std_logic;

    signal m_axi_recv_tready       : std_logic;

    signal crc_pass_fail_n         : std_logic;
    signal crc_valid               : std_logic;

    -- Output
    signal m_axi_recv_tdata        : std_logic_vector(FRAME_WIDTH - 1 downto 0);
    signal m_axi_recv_tvalid       : std_logic;
    signal m_axi_recv_tkeep        : std_logic_vector((integer(FRAME_WIDTH) / 8) - 1 downto 0);
    signal m_axi_recv_tlast        : std_logic;

    signal ack_num                 : std_logic_vector(8 - 1 downto 0);
    signal ack_set                 : std_logic;
    signal ack_send                : std_logic_vector(8 - 1 downto 0);

    -- Clock
    signal   clk : STD_LOGIC;
    constant clk_period : time := 10 ns;

    -- Verification signals
    -- Ack between sender and receiver
    signal ack_num_l    : std_logic_vector(8 - 1 downto 0);
    signal ack_new      : std_logic;
    signal ack_clear    : std_logic;
    signal ack_send_l   : std_logic_vector(8 - 1 downto 0);

begin
    clock : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
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

    UUT : aurora_ack_recv
        generic map (
            WORD_SIZE          => WORD_SIZE,
            FRAME_WIDTH        => FRAME_WIDTH
        )
        Port map (
            clk                      => clk,
            rst_n                    => rst_n,
            s_axi_rx_tdata           => s_axi_rx_tdata,
            s_axi_rx_tkeep           => s_axi_rx_tkeep,
            s_axi_rx_tvalid          => s_axi_rx_tvalid,
            s_axi_rx_tlast           => s_axi_rx_tlast,
            m_axi_recv_tdata         => m_axi_recv_tdata,
            m_axi_recv_tvalid        => m_axi_recv_tvalid,
            m_axi_recv_tready        => m_axi_recv_tready,
            m_axi_recv_tkeep         => m_axi_recv_tkeep,
            m_axi_recv_tlast         => m_axi_recv_tlast,
            ack_num                  => ack_num,
            ack_set                  => ack_set,
            ack_send                 => ack_send,
            crc_pass_fail_n          => crc_pass_fail_n,
            crc_valid                => crc_valid
        );



    test : process
        type packets_t is array(0 to 100) of std_logic_vector(FRAME_WIDTH - 1 downto 0);
        variable packets : packets_t;

        -- Receive a new valid packet from the aurora channel.
        procedure receive_packet(packet_p: std_logic_vector(FRAME_WIDTH - 1 downto 0); packet_num_p: std_logic_vector(7 downto 0); ack_num_p: std_logic_vector(7 downto 0); valid: std_logic; check: std_logic) is
        begin
            if(check = '1') then
                m_axi_recv_tready <= '1';
            end if;

            s_axi_rx_tdata(63 downto 32) <= (others => '0');
            s_axi_rx_tdata(31) <= '1';
            s_axi_rx_tdata(30 downto 16) <= (others => '0');
            s_axi_rx_tdata(15 downto 8) <= ack_num_p;
            s_axi_rx_tdata(7 downto 0) <= packet_num_p;
            s_axi_rx_tkeep <= (others => '1');
            s_axi_rx_tvalid <= '1';
            s_axi_rx_tlast  <= '0';
            wait for clk_period;

            for i in 0 to 6 loop
                s_axi_rx_tdata <= packet_p(WORD_SIZE*i+WORD_SIZE-1 downto WORD_SIZE*i);
                wait for clk_period;
            end loop;

            s_axi_rx_tdata <= packet_p(WORD_SIZE*7+WORD_SIZE-1 downto WORD_SIZE*7);
            s_axi_rx_tlast <= '1';
            crc_valid <= '1';
            crc_pass_fail_n <= valid;
            wait for clk_period;
            s_axi_rx_tlast <= '0';
            s_axi_rx_tvalid <= '0';
            s_axi_rx_tdata <= x"0000000000000000";
            crc_valid <= '0';
            crc_pass_fail_n <= '0';

            if(check = '1') then

                assert(m_axi_recv_tvalid = '1')
                    report "recv not valid"
                    severity failure;

                assert(m_axi_recv_tvalid = '1')
                    report "recv not valid"
                    severity failure;
                assert(m_axi_recv_tdata = packet_p)
                    report "Packet not valid"
                    severity failure;
                assert(m_axi_recv_tlast = '1')
                    report "Tlast = 1 is not correct"
                    severity failure;
                wait for clk_period;
                m_axi_recv_tready <= '0';
                wait for clk_period;

                assert(ack_send = packet_num_p)
                    report "ack_send not correct"
                    severity failure;

                assert(ack_num = ack_num_p)
                    report "ack_num not correct"
                    severity failure;
                end if;
        end receive_packet;

        -- Receive a new valid packet from the aurora channel but missalign the CRC making it invalid.
        procedure receive_packet_missaligned_CRC(packet_p: std_logic_vector(FRAME_WIDTH - 1 downto 0); packet_num_p: std_logic_vector(7 downto 0); ack_num_p: std_logic_vector(7 downto 0); valid: std_logic) is
        begin
            s_axi_rx_tdata(63 downto 32) <= (others => '0');
            s_axi_rx_tdata(31) <= '1';
            s_axi_rx_tdata(30 downto 16) <= (others => '0');
            s_axi_rx_tdata(15 downto 8) <= ack_num_p;
            s_axi_rx_tdata(7 downto 0) <= packet_num_p;
            s_axi_rx_tkeep <= (others => '1');
            s_axi_rx_tvalid <= '1';
            s_axi_rx_tlast  <= '0';
            wait for clk_period;

            for i in 0 to 6 loop
                s_axi_rx_tdata <= packet_p(WORD_SIZE*i+WORD_SIZE-1 downto WORD_SIZE*i);
                wait for clk_period;
            end loop;

            s_axi_rx_tdata <= packet_p(WORD_SIZE*7+WORD_SIZE-1 downto WORD_SIZE*7);
            s_axi_rx_tlast <= '1';
            wait for clk_period;
            s_axi_rx_tlast <= '0';
            s_axi_rx_tvalid <= '0';
            s_axi_rx_tdata <= x"0000000000000000";
            crc_valid <= '1';
            crc_pass_fail_n <= valid;
            wait for clk_period;
            crc_valid <= '0';
            crc_pass_fail_n <= '0';
            wait for clk_period;
        end receive_packet_missaligned_CRC;

        -- Receive an ack only packet
        procedure receive_ack(ack_num_p: std_logic_vector(7 downto 0); valid: std_logic) is
        begin
            s_axi_rx_tdata(63 downto 16) <= (others => '0');
            s_axi_rx_tdata(15 downto 8) <= ack_num_p;
            s_axi_rx_tdata(7 downto 0) <= (others => '0');
            s_axi_rx_tkeep <= (others => '1');
            s_axi_rx_tvalid <= '1';
            s_axi_rx_tlast <= '1';
            crc_valid <= '1';
            crc_pass_fail_n <= valid;
            wait for clk_period;
            s_axi_rx_tlast <= '0';
            s_axi_rx_tvalid <= '0';
            s_axi_rx_tdata <= (others => '0');
            crc_valid <= '0';
            crc_pass_fail_n <= '0';
            wait for clk_period;
        end receive_ack;

        -- Receive an ack only packet with no crc
        procedure receive_ack_no_crc(ack_num_p: std_logic_vector(7 downto 0)) is
        begin
            s_axi_rx_tdata(63 downto 16) <= (others => '0');
            s_axi_rx_tdata(15 downto 8) <= ack_num_p;
            s_axi_rx_tdata(7 downto 0) <= (others => '0');
            s_axi_rx_tkeep <= (others => '1');
            s_axi_rx_tvalid <= '1';
            s_axi_rx_tlast <= '1';
            wait for clk_period;
            s_axi_rx_tlast <= '0';
            s_axi_rx_tvalid <= '0';
            s_axi_rx_tdata <= (others => '0');
            wait for clk_period;
        end receive_ack_no_crc;

        -- Verify the correct packet numbers sent to ack_send module.
        procedure verify_ack_passed(packet_num_p: std_logic_vector(7 downto 0); ack_num_p: std_logic_vector(7 downto 0); ack_new_p : std_logic) is
        begin
            assert(ack_num_l = ack_num_p)
                report "ack_num not correct"
                severity failure;

            assert(ack_send_l = packet_num_p)
                report "packet number not correct"
                severity failure;

            assert(ack_new = ack_new_p)
                report "ack_new is not " & std_logic'image(ack_new_p)
                severity failure;

            ack_clear <= '1';
            wait for clk_period;
            ack_clear <= '0';
            wait for clk_period;

            assert(ack_new = '0')
                report "ack_new is not cleared."
                severity failure;

        end verify_ack_passed;

        -- Verify that no new packet is available to be read in.
        procedure verify_no_new_packet is
        begin
            assert(m_axi_recv_tvalid = '0')
                report "Packet availible but shouldn't be"
                severity failure;
        end verify_no_new_packet;

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
        rst_n              <= '0';
        s_axi_rx_tdata     <= (others => '0');
        s_axi_rx_tkeep     <= (others => '0');
        s_axi_rx_tvalid    <= '0';
        s_axi_rx_tlast     <= '0';
        m_axi_recv_tready  <= '0';
        crc_pass_fail_n    <= '0';
        crc_valid          <= '0';
        ack_clear          <= '0';

        -- Generate random packets
        for i in 0 to 100 loop
            packets(i) := random_packet;
        end loop;

        -- Reset
        report "Sending reset";
        rst_n <= '1';
        wait for 1 * clk_period;
        rst_n <= '0';
        wait for 16 * clk_period;
        rst_n <= '1';
        wait for 2 * clk_period;

        report "Sending valid packet 1";
        packets(0) := std_logic_vector(to_unsigned(1,FRAME_WIDTH));
        verify_no_new_packet;
        receive_packet(packets(0), x"01", x"00", '1', '1');
        wait for 10 * clk_period;
        verify_ack_passed(x"01", x"00", '1');
        verify_no_new_packet;

        report "Sending Ack Only";
        receive_ack(x"01", '1');
        wait for 3 * clk_period;
        verify_ack_passed(x"01", x"01", '0');
        verify_no_new_packet;

        report "Sending Invalid packet 2";
        packets(1) := std_logic_vector(to_unsigned(2,FRAME_WIDTH));
        verify_no_new_packet;
        receive_packet(packets(1), x"02", x"01", '0', '0');
        wait for 3 * clk_period;
        verify_ack_passed(x"01", x"01", '0');
        verify_no_new_packet;

        report "Send valid packet 3";
        verify_no_new_packet;
        receive_packet(packets(2), x"03", x"02", '1', '0');
        wait for 3 * clk_period;
        verify_ack_passed(x"01", x"02", '0');
        verify_no_new_packet;

        report "Send valid packet 2";
        verify_no_new_packet;
        receive_packet(packets(1), x"02", x"03", '1', '1');
        wait for 3 * clk_period;
        verify_ack_passed(x"02", x"03", '1');
        verify_no_new_packet;

        report "Send valid packet 3";
        verify_no_new_packet;
        receive_packet(packets(2), x"03", x"03", '1', '1');
        wait for 3 * clk_period;
        verify_ack_passed(x"03", x"03", '1');
        verify_no_new_packet;

        report "Send valid packet 4 and 5 and only read one packet.";
        verify_no_new_packet;
        receive_packet(packets(3), x"04", x"03", '1', '1');
        wait for 3 * clk_period;
        -- verify_receive_packet(packets(2), x"03", x"03");
        verify_ack_passed(x"04", x"03", '1');
        --Send valid packet 5
        receive_packet(packets(4), x"05", x"03", '1', '0');
        wait for 3 * clk_period;
        verify_ack_passed(x"04", x"03", '0');
        verify_no_new_packet;

        report "Resend valid packet 5 and varify reack";
        verify_no_new_packet;
        receive_packet(packets(4), x"05", x"03", '1', '1');
        wait for 4 * clk_period;
        verify_ack_passed(x"05", x"03", '1');
        verify_no_new_packet;

        report "Test receive with miss aligned CRC valid";
        verify_no_new_packet;
        receive_packet_missaligned_CRC(packets(5), x"06", x"03", '1');
        wait for 3 * clk_period;
        verify_ack_passed(x"05", x"03", '0');
        verify_no_new_packet;

        report "Test receive with miss aligned CRC invalid";
        verify_no_new_packet;
        receive_packet_missaligned_CRC(packets(5), x"06", x"03", '0');
        wait for 3 * clk_period;
        verify_ack_passed(x"05", x"03", '0');
        verify_no_new_packet;

        report "Test receive ack with bad valid word.";
        verify_no_new_packet;
        receive_ack_no_crc(x"fa");
        receive_ack(x"04", '1');
        wait for 3 * clk_period;
        verify_ack_passed(x"05", x"04", '0');
        verify_no_new_packet;

        report "Test receive packet with bad valid word.";
        verify_no_new_packet;
        receive_ack_no_crc(x"fa");
        receive_packet(packets(5), x"06", x"04", '1', '1');
        wait for 3 * clk_period;
        verify_ack_passed(x"06", x"04", '1');
        verify_no_new_packet;

        report "Simulation Finished";
        stop(0);
    end process;

end testbench;
