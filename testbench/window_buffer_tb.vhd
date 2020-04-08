library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use std.env.stop;

entity window_buffer_tb is
    end window_buffer_tb;

architecture testbench of window_buffer_tb is
    component window_buffer
    generic (
        FRAME_WIDTH  : positive := 520;
        PACKET_SELECT_BITS : positive := 4
    );
    port (
        clk       : in std_logic;
        rst_n     : in std_logic;

        -- Write
        wr_tdata  :  in  std_logic_vector(FRAME_WIDTH - 1 downto 0);
        wr_tvalid :  in  std_logic;
        wr_tkeep  :  in  std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

        -- Read
        rd_tdata  :  out std_logic_vector(FRAME_WIDTH - 1 downto 0);
        rd_tvalid :  out std_logic;
        rd_tkeep  :  out std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

        -- Control signals
        packet    :  in  std_logic_vector(PACKET_SELECT_BITS - 1 downto 0);
        drop      :  in  std_logic;

        -- Status signals
        count     :  out std_logic_vector(PACKET_SELECT_BITS downto 0);
        full      :  out std_logic;
        empty     :  out std_logic
    );
    end component;

    constant FRAME_WIDTH        : positive := 40;
    constant PACKET_SELECT_BITS : positive := 4;

    -- Inputs
    signal rst_n           : std_logic;

    signal wr_tdata        : std_logic_vector(FRAME_WIDTH - 1 downto 0);
    signal wr_tvalid       : std_logic;
    signal wr_tkeep        : std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

    signal packet          : std_logic_vector(PACKET_SELECT_BITS - 1 downto 0) := (others => '0');
    signal drop            : std_logic;

    -- Outputs
    signal rd_tdata        : std_logic_vector(FRAME_WIDTH - 1 downto 0);
    signal rd_tvalid       : std_logic;
    signal rd_tkeep        : std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0);

    signal count           : std_logic_vector(PACKET_SELECT_BITS downto 0);
    signal full            : std_logic;
    signal empty           : std_logic;

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

    UUT : window_buffer
    generic map (
        FRAME_WIDTH => FRAME_WIDTH,
        PACKET_SELECT_BITS => PACKET_SELECT_BITS
    )
    port map (
        clk       => clk,
        rst_n     => rst_n,
        wr_tdata  => wr_tdata,
        wr_tvalid => wr_tvalid,
        wr_tkeep  => wr_tkeep,
        rd_tdata  => rd_tdata,
        rd_tvalid => rd_tvalid,
        rd_tkeep  => rd_tkeep,
        drop      => drop,
        packet    => packet,
        count     => count,
        full      => full,
        empty     => empty
    );

    test : process

        -- Validate a packet to make sure the packet at packet_p has the data data_p and keep keep_p.
        procedure validate_packet(packet_p: in std_logic_vector(PACKET_SELECT_BITS - 1 downto 0); data_p: in std_logic_vector(FRAME_WIDTH - 1 downto 0); keep_p: in std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0)) is
        begin
            packet <= packet_p;
            wait for 1 * clk_period;
            assert (rd_tdata = data_p)
                report "Packet data does not match the expected value."
                severity failure;
            assert (rd_tkeep = keep_p)
                report "Packet keep does not match the expected value."
                severity failure;
            assert (rd_tvalid = '1')
                report "Packet is not valid."
                severity failure;
        end validate_packet;

        -- Validate to make sure packet_p is empty
        procedure validate_empty_packet(packet_p: in std_logic_vector(PACKET_SELECT_BITS - 1 downto 0)) is
        begin
            packet <= packet_p;
            wait for 1 * clk_period;
            assert (rd_tvalid = '0')
                report "Packet is valid but should be empty."
                severity failure;
        end validate_empty_packet;

        -- Drop a packet
        procedure drop_packet is
        begin
            drop <= '1';
            wait for 1 * clk_period;
            drop <= '0';
        end drop_packet;

        -- Append a packet with data_p and keep_p
        procedure append_packet(data_p: std_logic_vector(FRAME_WIDTH - 1 downto 0); keep_p: std_logic_vector((integer(FRAME_WIDTH) / 8) - 2 downto 0)) is
        begin
            wr_tdata <= data_p;
            wr_tvalid <= '1';
            wr_tkeep <= keep_p;
            wait for 1 * clk_period;
            wr_tvalid <= '0';
        end append_packet;

        -- Validate the full and empty flags to make sure they match the expected values.
        procedure validate_full_empty(full_p: std_logic; empty_p: std_logic) is
        begin
            assert (full = full_p)
                report "Full does not match expected."
                severity failure;
            assert (empty = empty_p)
                report "Empty does not match expected."
                severity failure;
        end validate_full_empty;

        -- Make sure the count of packets in memory matches the expected value.
        procedure validate_count(count_p: std_logic_vector(PACKET_SELECT_BITS downto 0)) is
        begin
            assert(count_p = count)
                report "Count does not match expected."
                severity failure;
        end validate_count;

    begin
        -- Set initial values
        rst_n <= '0';
        wr_tdata  <= (others => '0');
        wr_tvalid <= '0';
        wr_tkeep <= (others => '0');
        drop  <= '0';
        packet <= (others => '0');

        -- Reset
        report "Sending reset";
        wait for 10 * clk_period;
        rst_n <= '1';
        wait for 1 * clk_period;

        -- Verify memory is empty
        validate_empty_packet(x"0");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0','1');

        -- Add one packet
        append_packet(std_logic_vector(to_unsigned(1, wr_tdata'length)), "1111");
        validate_packet(x"0",  std_logic_vector(to_unsigned(1, wr_tdata'length)), "1111");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0','0');

        -- Drop packet
        drop_packet;
        validate_empty_packet(x"0");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0','1');

        -- Fill memory
        append_packet(std_logic_vector(to_unsigned(1, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(2, wr_tdata'length)),  "1110");
        append_packet(std_logic_vector(to_unsigned(3, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(4, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(5, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(6, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(7, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(8, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(9, wr_tdata'length)),  "1111");
        append_packet(std_logic_vector(to_unsigned(10, wr_tdata'length)), "1111");
        append_packet(std_logic_vector(to_unsigned(11, wr_tdata'length)), "1111");
        append_packet(std_logic_vector(to_unsigned(12, wr_tdata'length)), "1111");
        append_packet(std_logic_vector(to_unsigned(13, wr_tdata'length)), "1111");
        append_packet(std_logic_vector(to_unsigned(14, wr_tdata'length)), "1111");
        append_packet(std_logic_vector(to_unsigned(15, wr_tdata'length)), "1111");
        append_packet(std_logic_vector(to_unsigned(16, wr_tdata'length)), "1111");
        validate_packet(x"0",  std_logic_vector(to_unsigned(1, wr_tdata'length)), "1111");
        validate_packet(x"1",  std_logic_vector(to_unsigned(2, wr_tdata'length)), "1110");
        validate_packet(x"2",  std_logic_vector(to_unsigned(3, wr_tdata'length)), "1111");
        validate_packet(x"3",  std_logic_vector(to_unsigned(4, wr_tdata'length)), "1111");
        validate_packet(x"4",  std_logic_vector(to_unsigned(5, wr_tdata'length)), "1111");
        validate_packet(x"5",  std_logic_vector(to_unsigned(6, wr_tdata'length)), "1111");
        validate_packet(x"6",  std_logic_vector(to_unsigned(7, wr_tdata'length)), "1111");
        validate_packet(x"7",  std_logic_vector(to_unsigned(8, wr_tdata'length)), "1111");
        validate_packet(x"8",  std_logic_vector(to_unsigned(9, wr_tdata'length)), "1111");
        validate_packet(x"9",  std_logic_vector(to_unsigned(10, wr_tdata'length)), "1111");
        validate_packet(x"a",  std_logic_vector(to_unsigned(11, wr_tdata'length)), "1111");
        validate_packet(x"b",  std_logic_vector(to_unsigned(12, wr_tdata'length)), "1111");
        validate_packet(x"c",  std_logic_vector(to_unsigned(13, wr_tdata'length)), "1111");
        validate_packet(x"d",  std_logic_vector(to_unsigned(14, wr_tdata'length)), "1111");
        validate_packet(x"e",  std_logic_vector(to_unsigned(15, wr_tdata'length)), "1111");
        validate_packet(x"f",  std_logic_vector(to_unsigned(16, wr_tdata'length)), "1111");
        validate_full_empty('1','0');

        -- Append packet that can't fit
        append_packet(std_logic_vector(to_unsigned(17, wr_tdata'length)), "1111");
        validate_packet(x"0",  std_logic_vector(to_unsigned(1, wr_tdata'length)), "1111");
        validate_packet(x"1",  std_logic_vector(to_unsigned(2, wr_tdata'length)), "1110");
        validate_packet(x"2",  std_logic_vector(to_unsigned(3, wr_tdata'length)), "1111");
        validate_packet(x"3",  std_logic_vector(to_unsigned(4, wr_tdata'length)), "1111");
        validate_packet(x"4",  std_logic_vector(to_unsigned(5, wr_tdata'length)), "1111");
        validate_packet(x"5",  std_logic_vector(to_unsigned(6, wr_tdata'length)), "1111");
        validate_packet(x"6",  std_logic_vector(to_unsigned(7, wr_tdata'length)), "1111");
        validate_packet(x"7",  std_logic_vector(to_unsigned(8, wr_tdata'length)), "1111");
        validate_packet(x"8",  std_logic_vector(to_unsigned(9, wr_tdata'length)), "1111");
        validate_packet(x"9",  std_logic_vector(to_unsigned(10, wr_tdata'length)), "1111");
        validate_packet(x"a",  std_logic_vector(to_unsigned(11, wr_tdata'length)), "1111");
        validate_packet(x"b",  std_logic_vector(to_unsigned(12, wr_tdata'length)), "1111");
        validate_packet(x"c",  std_logic_vector(to_unsigned(13, wr_tdata'length)), "1111");
        validate_packet(x"d",  std_logic_vector(to_unsigned(14, wr_tdata'length)), "1111");
        validate_packet(x"e",  std_logic_vector(to_unsigned(15, wr_tdata'length)), "1111");
        validate_packet(x"f",  std_logic_vector(to_unsigned(16, wr_tdata'length)), "1111");
        validate_full_empty('1', '0');

        -- Drop 5 packets
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        validate_packet(x"0",  std_logic_vector(to_unsigned(6, wr_tdata'length)), "1111");
        validate_packet(x"1",  std_logic_vector(to_unsigned(7, wr_tdata'length)), "1111");
        validate_packet(x"2",  std_logic_vector(to_unsigned(8, wr_tdata'length)), "1111");
        validate_packet(x"3",  std_logic_vector(to_unsigned(9, wr_tdata'length)), "1111");
        validate_packet(x"4",  std_logic_vector(to_unsigned(10, wr_tdata'length)), "1111");
        validate_packet(x"5",  std_logic_vector(to_unsigned(11, wr_tdata'length)), "1111");
        validate_packet(x"6",  std_logic_vector(to_unsigned(12, wr_tdata'length)), "1111");
        validate_packet(x"7",  std_logic_vector(to_unsigned(13, wr_tdata'length)), "1111");
        validate_packet(x"8",  std_logic_vector(to_unsigned(14, wr_tdata'length)), "1111");
        validate_packet(x"9",  std_logic_vector(to_unsigned(15, wr_tdata'length)), "1111");
        validate_packet(x"a",  std_logic_vector(to_unsigned(16, wr_tdata'length)), "1111");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0', '0');

        -- Drop all but one
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        drop_packet;
        validate_packet(x"0",  std_logic_vector(to_unsigned(16, wr_tdata'length)), "1111");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0', '0');

        -- Drop last packet
        drop_packet;
        validate_empty_packet(x"0");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0', '1');

        -- Drop packet that doesn't exist
        drop_packet;
        validate_empty_packet(x"0");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0', '1');

        -- Add one packet
        wr_tdata <= std_logic_vector(to_unsigned(1, wr_tdata'length));
        wr_tvalid <= '1';
        wr_tkeep <= (others => '1');
        wait for 1 * clk_period;
        wr_tvalid <= '0';
        wait for 1 * clk_period;

        -- Drop Packet and add in the same cycle
        wr_tdata <= std_logic_vector(to_unsigned(2, wr_tdata'length));
        wr_tvalid <= '1';
        wr_tkeep <= (others => '1');
        drop <= '1';
        wait for 1 * clk_period;
        drop <= '0';
        wr_tvalid <= '0';
        wait for 1 * clk_period;

        -- Check memory
        validate_packet(x"0",  std_logic_vector(to_unsigned(2, wr_tdata'length)), "1111");
        validate_empty_packet(x"1");
        validate_empty_packet(x"2");
        validate_empty_packet(x"3");
        validate_empty_packet(x"4");
        validate_empty_packet(x"4");
        validate_empty_packet(x"5");
        validate_empty_packet(x"6");
        validate_empty_packet(x"7");
        validate_empty_packet(x"8");
        validate_empty_packet(x"9");
        validate_empty_packet(x"a");
        validate_empty_packet(x"b");
        validate_empty_packet(x"c");
        validate_empty_packet(x"d");
        validate_empty_packet(x"e");
        validate_empty_packet(x"f");
        validate_full_empty('0', '0');

        report "Simulation Finished";
        stop(0);
    end process;

end testbench;
