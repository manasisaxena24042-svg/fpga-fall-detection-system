-- File: io_controller.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity io_controller is
    port(
        -- Global Inputs
        clk_50mhz         : in  std_logic;
        reset_n           : in  std_logic;
        cancel_button_raw : in  std_logic; -- Raw signal from KEY0/KEY1
        
        -- Interface to Main_Control_FSM (Block 3)
        start_countdown     : in  std_logic;
        enable_alarm_leds   : in  std_logic;
        reset_timer         : in  std_logic;
        countdown_finished  : out std_logic;
        cancel_button_pressed : out std_logic;
        
        -- Physical Outputs
        leds_out            : out std_logic_vector(9 downto 0);
        ssds_out            : out std_logic_vector(47 downto 0)
    );
end entity;

architecture rtl of io_controller is

    -- Internal signals
    signal s_countdown_finished : std_logic;
    signal s_timer_is_counting  : std_logic;
    signal s_seconds_count      : integer range 0 to 30;
    signal s_1hz_flash_state    : std_logic := '0';
    
    -- 1Hz flasher (re-using the 1-sec logic from the timer)
    -- This is a simple toggle register for a 0.5s on, 0.5s off flash
    constant HALF_SECOND_COUNT : integer := 24999999;
    signal clk_divider_flash : integer range 0 to HALF_SECOND_COUNT;

    -- Internal numeric SSD output from the driver
    signal ssds_numeric : std_logic_vector(47 downto 0);

    -- 7-seg patterns (common anode: '0' = ON). Bit 7 = DP (off = '1').
    constant SEG_BLANK : std_logic_vector(7 downto 0) := "11111111";
    constant SEG_I     : std_logic_vector(7 downto 0) := "11111001"; -- '1' like
    constant SEG_D     : std_logic_vector(7 downto 0) := "10100001"; -- 'd'
    constant SEG_L     : std_logic_vector(7 downto 0) := "11000111"; -- 'L' approx
    constant SEG_E     : std_logic_vector(7 downto 0) := "10000110"; -- 'E'
    constant SEG_H     : std_logic_vector(7 downto 0) := "10001001"; -- 'H' approx
    -- 'P' for common-anode: DP off('1'), segments g,f,e,d,c,b,a = 0,0,0,1,1,0,0
    -- pattern bits are indexed as (7=DP)(6=g)(5=f)(4=e)(3=d)(2=c)(1=b)(0=a)
    constant SEG_P     : std_logic_vector(7 downto 0) := "10001100"; -- 'P' correct

    -- Rightmost 4 digits: HEX3..HEX0 will show words
    constant IDLE_vec : std_logic_vector(47 downto 0) :=
        SEG_BLANK & SEG_BLANK & SEG_I & SEG_D & SEG_L & SEG_E;
    constant HELP_vec : std_logic_vector(47 downto 0) :=
        SEG_BLANK & SEG_BLANK & SEG_H & SEG_E & SEG_L & SEG_P;

begin

    -- Instantiate the Button Debouncer
    U_Debouncer : entity work.button_debouncer
        port map(
            clk_50mhz   => clk_50mhz,
            reset_n     => reset_n,
            button_in   => cancel_button_raw,
            button_out  => cancel_button_pressed -- This is now debounced & active-high
        );

    -- Instantiate the 30-Second Timer
    U_Timer : entity work.countdown_timer_30s
        port map(
            clk_50mhz      => clk_50mhz,
            reset_n        => reset_n,
            start_pulse    => start_countdown,
            reset_pulse    => reset_timer,
            seconds_count  => s_seconds_count,
            is_counting    => s_timer_is_counting,
            finished_pulse => s_countdown_finished
        );
        
    -- Connect timer output to the FSM
    countdown_finished <= s_countdown_finished;

    -- Instantiate the 7-Segment Driver
    U_SSD : entity work.ssd_driver
        port map(
            seconds_in => s_seconds_count,
            ssds_out   => ssds_numeric
        );
        
        
    -- LED Control Logic (Flasher and Status)

    -- 2Hz flasher process (toggles every 0.5 seconds)
    process(clk_50mhz, reset_n)
    begin
        if reset_n = '0' then
            clk_divider_flash <= 0;
            s_1hz_flash_state <= '0';
        elsif rising_edge(clk_50mhz) then
            if clk_divider_flash = HALF_SECOND_COUNT then
                clk_divider_flash <= 0;
                s_1hz_flash_state <= not s_1hz_flash_state;
            else
                clk_divider_flash <= clk_divider_flash + 1;
            end if;
        end if;
    end process;
    
    -- LED output multiplexer

    process(enable_alarm_leds, s_timer_is_counting, s_1hz_flash_state, ssds_numeric)
    begin
        -- LED logic (unchanged behavior)
        if enable_alarm_leds = '1' then
            if s_1hz_flash_state = '1' then
                leds_out <= (others => '1'); -- All ON
            else
                leds_out <= (others => '0'); -- All OFF
            end if;
        else
            leds_out <= (others => '0');
            leds_out(0) <= s_1hz_flash_state;
            if s_timer_is_counting = '1' then
                leds_out(1) <= '1';
            end if;
        end if;

        -- SSD multiplexing
        if enable_alarm_leds = '1' then
            -- Blink with LEDs: show HELP during ON phase, blank during OFF phase
            if s_1hz_flash_state = '1' then
                ssds_out <= HELP_vec;
            else
                ssds_out <= (others => '1'); -- blank
            end if;
        elsif s_timer_is_counting = '0' then
            -- Idle: display IDLE on rightmost 4 digits
            ssds_out <= IDLE_vec;
        else
            -- Normal: show numeric SSD output from driver
            ssds_out <= ssds_numeric;
        end if;
    end process;
    
end architecture;