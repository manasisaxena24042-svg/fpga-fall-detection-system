library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fall_detector_top is
    port (
        MAX10_CLK1_50 : in  std_logic;
        KEY1          : in  std_logic; -- Reset
        KEY0          : in  std_logic; -- Cancel
        
        -- Accelerometer I2C Interface
        GSENSOR_SCLK  : inout std_logic; 
        GSENSOR_SDI   : inout std_logic; 
        GSENSOR_CS_N  : out   std_logic;
        GSENSOR_SDO   : out   std_logic; 

        -- Outputs
        LEDR          : out std_logic_vector(9 downto 0);
        HEX0, HEX1, HEX2, HEX3, HEX4, HEX5 : out std_logic_vector(7 downto 0)
    );
end entity fall_detector_top;

architecture Behavioral of fall_detector_top is

    component accelerometer_interface is
        port(
            clk_50mhz    : in  std_logic;
            reset_n      : in  std_logic;
            i2c_sda      : inout std_logic;
            i2c_scl      : inout std_logic;
            accel_x_out  : out signed(15 downto 0);
            accel_y_out  : out signed(15 downto 0);
            accel_z_out  : out signed(15 downto 0);
            data_ready   : out std_logic
        );
    end component;

    component fall_detection_logic is
        port(
            clk : in std_logic; reset : in std_logic;
            accel_x, accel_y, accel_z : in signed(15 downto 0);
            fall_trigger_out : out std_logic
        );
    end component;
    
    component Main_Control_FSM is
        port (
            clk : in std_logic; reset : in std_logic;
            fall_trigger, cancel_button_pressed, countdown_finished : in std_logic;
            start_countdown, enable_alarm_leds, reset_timer : out std_logic
        );
    end component;

    component io_controller is
        port(
            clk_50mhz, reset_n, cancel_button_raw : in std_logic;
            start_countdown, enable_alarm_leds, reset_timer : in std_logic;
            countdown_finished, cancel_button_pressed : out std_logic;
            leds_out : out std_logic_vector(9 downto 0);
            ssds_out : out std_logic_vector(47 downto 0)
        );
    end component;

    signal s_clk_50mhz, s_reset_n, s_reset_p : std_logic;
    signal s_accel_x, s_accel_y, s_accel_z : signed(15 downto 0);
    signal s_fall_trigger, s_start_countdown, s_enable_alarm_leds, s_reset_timer : std_logic;
    signal s_countdown_finished, s_cancel_button_pressed : std_logic;
    signal s_leds_out : std_logic_vector(9 downto 0);
    signal s_ssds_out : std_logic_vector(47 downto 0);

begin

    s_clk_50mhz <= MAX10_CLK1_50;
    s_reset_n   <= KEY1;
    s_reset_p   <= not KEY1;

    -- HARDWARE SETUP FOR I2C --
    -- Force CS High to enable I2C mode on ADXL345
    GSENSOR_CS_N <= '1'; 
    -- Force SDO Low to select Address 0x53
    GSENSOR_SDO  <= '0'; 

    U_Accel_Interface : accelerometer_interface
        port map (
            clk_50mhz    => s_clk_50mhz,
            reset_n      => s_reset_n,
            i2c_sda      => GSENSOR_SDI,  -- Mapping SDI to SDA
            i2c_scl      => GSENSOR_SCLK, -- Mapping SCLK to SCL
            accel_x_out  => s_accel_x,
            accel_y_out  => s_accel_y,
            accel_z_out  => s_accel_z,
            data_ready   => open
        );

    U_Fall_Logic : fall_detection_logic
        port map (
            clk => s_clk_50mhz, reset => s_reset_p,
            accel_x => s_accel_x, accel_y => s_accel_y, accel_z => s_accel_z,
            fall_trigger_out => s_fall_trigger
        );

    U_Main_FSM : Main_Control_FSM
        port map (
            clk => s_clk_50mhz, reset => s_reset_p,
            fall_trigger => s_fall_trigger,
            cancel_button_pressed => s_cancel_button_pressed,
            countdown_finished => s_countdown_finished,
            start_countdown => s_start_countdown,
            enable_alarm_leds => s_enable_alarm_leds,
            reset_timer => s_reset_timer
        );

    U_IO_Controller : io_controller
        port map (
            clk_50mhz => s_clk_50mhz, reset_n => s_reset_n,
            cancel_button_raw => KEY0,
            start_countdown => s_start_countdown,
            enable_alarm_leds => s_enable_alarm_leds,
            reset_timer => s_reset_timer,
            countdown_finished => s_countdown_finished,
            cancel_button_pressed => s_cancel_button_pressed,
            leds_out => s_leds_out,
            ssds_out => s_ssds_out
        );

    LEDR <= s_leds_out;
    HEX0 <= s_ssds_out(7 downto 0);
    HEX1 <= s_ssds_out(15 downto 8);
    HEX2 <= s_ssds_out(23 downto 16);
    HEX3 <= s_ssds_out(31 downto 24);
    HEX4 <= s_ssds_out(39 downto 32);
    HEX5 <= s_ssds_out(47 downto 40);

end architecture;