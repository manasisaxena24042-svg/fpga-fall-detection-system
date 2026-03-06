library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity accelerometer_interface is
    port(
        clk_50mhz    : in  std_logic;
        reset_n      : in  std_logic;
        
        -- I2C Interface
        i2c_sda      : inout std_logic;
        i2c_scl      : inout std_logic;
        
        -- Outputs
        accel_x_out  : out signed(15 downto 0);
        accel_y_out  : out signed(15 downto 0);
        accel_z_out  : out signed(15 downto 0);
        data_ready   : out std_logic
    );
end entity accelerometer_interface;

architecture rtl of accelerometer_interface is

    component i2c_master IS
      GENERIC(
        input_clk : INTEGER;
        bus_clk   : INTEGER); 
      PORT(
        clk       : IN     STD_LOGIC;
        reset_n   : IN     STD_LOGIC;
        ena       : IN     STD_LOGIC;
        addr      : IN     STD_LOGIC_VECTOR(6 DOWNTO 0);
        rw        : IN     STD_LOGIC;
        data_wr   : IN     STD_LOGIC_VECTOR(7 DOWNTO 0);
        busy      : OUT    STD_LOGIC;
        data_rd   : OUT    STD_LOGIC_VECTOR(7 DOWNTO 0);
        ack_error : OUT STD_LOGIC;
        sda       : INOUT  STD_LOGIC;
        scl       : INOUT  STD_LOGIC);
    END component;

    -- Signals
    signal i2c_ena     : std_logic;
    signal i2c_addr    : std_logic_vector(6 downto 0);
    signal i2c_rw      : std_logic;
    signal i2c_data_wr : std_logic_vector(7 downto 0);
    signal i2c_busy    : std_logic;
    signal i2c_data_rd : std_logic_vector(7 downto 0);
    signal i2c_ack_err : std_logic := '0'; -- @suppress "Signal i2c_ack_err is never read"

    -- Constants
    constant ADXL345_ADDR  : std_logic_vector(6 downto 0) := "1010011"; -- 0x53
    constant REG_POWER_CTL : std_logic_vector(7 downto 0) := x"2D";
    constant CMD_MEASURE   : std_logic_vector(7 downto 0) := x"08";
    constant REG_DATAX0    : std_logic_vector(7 downto 0) := x"32";

    type state_type is (
        S_RESET, S_DELAY,
        
        -- Config 1: Power Control (Write 0x2D -> 0x08)
        S_CFG_PWR_START, S_CFG_PWR_WAIT_BUSY, S_CFG_PWR_LOAD_DATA, S_CFG_PWR_WAIT_FINISH,
        
        S_IDLE_WAIT,

        -- Set Read Pointer (Write 0x32)
        S_PTR_START, S_PTR_WAIT_BUSY, S_PTR_WAIT_FINISH,
        
        -- Read 6 Bytes
        S_READ_START,
        S_READ_B1_WAIT, S_READ_B1_ACK,
        S_READ_B2_WAIT, S_READ_B2_ACK,
        S_READ_B3_WAIT, S_READ_B3_ACK,
        S_READ_B4_WAIT, S_READ_B4_ACK,
        S_READ_B5_WAIT, S_READ_B5_ACK,
        S_READ_B6_WAIT, S_READ_B6_ACK,
        
        S_LATCH
    );
    signal state : state_type := S_RESET;

    signal x_l, x_h, y_l, y_h, z_l, z_h : std_logic_vector(7 downto 0); -- @suppress "Signal x_l is never read"  -- @suppress "Signal y_l is never read"  -- @suppress "Signal z_l is never read"
    signal timer : integer range 0 to 50000000 := 0;

begin

    -- Lowered Bus Clock to 100kHz for maximum stability
    U_I2C : i2c_master
    generic map(
        input_clk => 50000000,
        bus_clk   => 100000
    )
    port map(
        clk       => clk_50mhz,
        reset_n   => reset_n,
        ena       => i2c_ena,
        addr      => i2c_addr,
        rw        => i2c_rw,
        data_wr   => i2c_data_wr,
        busy      => i2c_busy,
        data_rd   => i2c_data_rd,
        ack_error => i2c_ack_err,
        sda       => i2c_sda,
        scl       => i2c_scl
    );

    process(clk_50mhz, reset_n)
    begin
        if reset_n = '0' then
            state <= S_RESET;
            i2c_ena <= '0';
            i2c_rw <= '0';
            i2c_addr <= (others => '0');
            i2c_data_wr <= (others => '0');
            i2c_ack_err <= '0';
            data_ready <= '0';
            timer <= 0;
            accel_x_out <= (others => '0');
            accel_y_out <= (others => '0');
            accel_z_out <= (others => '0');
            x_l <= (others => '0');
            x_h <= (others => '0');
            y_l <= (others => '0');
            y_h <= (others => '0');
            z_l <= (others => '0');
            z_h <= (others => '0');
        elsif rising_edge(clk_50mhz) then
            
            data_ready <= '0';

            case state is
                when S_RESET =>
                    timer <= 0;
                    state <= S_DELAY;

                when S_DELAY =>
                    if timer < 1000000 then -- 20ms wait
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= S_CFG_PWR_START;
                    end if;

                ------------------------------------------------------------
                -- Write Power Control (0x2D) -> 0x08 (Measure Mode)
                ------------------------------------------------------------
                when S_CFG_PWR_START =>
                    i2c_addr <= ADXL345_ADDR;
                    i2c_rw   <= '0'; -- Write
                    i2c_data_wr <= REG_POWER_CTL; -- First Byte: Reg Addr
                    i2c_ena  <= '1';
                    state <= S_CFG_PWR_WAIT_BUSY;
                
                when S_CFG_PWR_WAIT_BUSY =>
                    if i2c_busy = '1' then
                        -- Master accepted Command. 
                        -- PRE-LOAD Next Data Byte NOW so it is ready when Busy drops.
                        i2c_data_wr <= CMD_MEASURE; 
                        state <= S_CFG_PWR_LOAD_DATA;
                    end if;

                when S_CFG_PWR_LOAD_DATA =>
                    if i2c_busy = '0' then
                        -- Busy dropped (Ack received). Master latches i2c_data_wr NOW.
                        state <= S_CFG_PWR_WAIT_FINISH;
                    end if;

                when S_CFG_PWR_WAIT_FINISH =>
                    if i2c_busy = '1' then
                        -- Second byte transmission started.
                        -- Now we can drop enable to tell master "Stop after this byte".
                        i2c_ena <= '0';
                    elsif i2c_busy = '0' and i2c_ena = '0' then
                        -- Transaction complete.
                        state <= S_IDLE_WAIT;
                    end if;

                ------------------------------------------------------------
                -- Polling Wait
                ------------------------------------------------------------
                when S_IDLE_WAIT =>
                    if timer < 500000 then -- 10ms
                        timer <= timer + 1;
                    else
                        timer <= 0;
                        state <= S_PTR_START;
                    end if;

                ------------------------------------------------------------
                -- Set Pointer to 0x32 (Single Byte Write)
                ------------------------------------------------------------
                when S_PTR_START =>
                    i2c_addr <= ADXL345_ADDR;
                    i2c_rw   <= '0'; 
                    i2c_data_wr <= REG_DATAX0;
                    i2c_ena  <= '1';
                    state <= S_PTR_WAIT_BUSY;

                when S_PTR_WAIT_BUSY =>
                    if i2c_busy = '1' then
                        -- Busy high. Since we only want to write one byte (the address),
                        -- we can drop Enable immediately. The master will finish this byte and Stop.
                        i2c_ena <= '0';
                        state <= S_PTR_WAIT_FINISH;
                    end if;

                when S_PTR_WAIT_FINISH =>
                    if i2c_busy = '0' then
                        state <= S_READ_START;
                    end if;

                ------------------------------------------------------------
                -- Read 6 Bytes
                ------------------------------------------------------------
                when S_READ_START =>
                    i2c_addr <= ADXL345_ADDR;
                    i2c_rw   <= '1'; -- Read
                    i2c_ena  <= '1';
                    state <= S_READ_B1_WAIT;

                -- Byte 1
                when S_READ_B1_WAIT =>
                    if i2c_busy = '1' then state <= S_READ_B1_ACK; end if;
                when S_READ_B1_ACK =>
                    if i2c_busy = '0' then 
                        x_l <= i2c_data_rd; 
                        state <= S_READ_B2_WAIT; 
                    end if;

                -- Byte 2
                when S_READ_B2_WAIT =>
                    if i2c_busy = '1' then state <= S_READ_B2_ACK; end if;
                when S_READ_B2_ACK =>
                    if i2c_busy = '0' then 
                        x_h <= i2c_data_rd; 
                        state <= S_READ_B3_WAIT; 
                    end if;

                -- Byte 3
                when S_READ_B3_WAIT =>
                    if i2c_busy = '1' then state <= S_READ_B3_ACK; end if;
                when S_READ_B3_ACK =>
                    if i2c_busy = '0' then 
                        y_l <= i2c_data_rd; 
                        state <= S_READ_B4_WAIT; 
                    end if;

                -- Byte 4
                when S_READ_B4_WAIT =>
                    if i2c_busy = '1' then state <= S_READ_B4_ACK; end if;
                when S_READ_B4_ACK =>
                    if i2c_busy = '0' then 
                        y_h <= i2c_data_rd; 
                        state <= S_READ_B5_WAIT; 
                    end if;

                -- Byte 5
                when S_READ_B5_WAIT =>
                    if i2c_busy = '1' then state <= S_READ_B5_ACK; end if;
                when S_READ_B5_ACK =>
                    if i2c_busy = '0' then 
                        z_l <= i2c_data_rd; 
                        state <= S_READ_B6_WAIT; 
                    end if;

                -- Byte 6 (Last)
                when S_READ_B6_WAIT =>
                    if i2c_busy = '1' then 
                        i2c_ena <= '0'; -- Nack/Stop after this
                        state <= S_READ_B6_ACK; 
                    end if;
                when S_READ_B6_ACK =>
                    if i2c_busy = '0' then 
                        z_h <= i2c_data_rd; 
                        state <= S_LATCH; 
                    end if;

                when S_LATCH =>
                    -- Combine high and low bytes into full 16-bit signed values
                    accel_x_out <= signed(x_h & x_l);
                    accel_y_out <= signed(y_h & y_l);
                    accel_z_out <= signed(z_h & z_l);
                    data_ready <= '1';
                    state <= S_IDLE_WAIT;

            end case;
        end if;
    end process;
end rtl;