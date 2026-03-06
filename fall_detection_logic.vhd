library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.fall_pkg.all;

entity fall_detection_logic is
    port(
        clk         : in  std_logic;
        reset       : in  std_logic;
        accel_x     : in  signed(15 downto 0);
        accel_y     : in  signed(15 downto 0);
        accel_z     : in  signed(15 downto 0);
        
        -- This connects to the 'fall_trigger' port of Main_Control_FSM
        fall_trigger_out : out std_logic 
    );
end entity;

architecture rtl of fall_detection_logic is

    -- FSM states
    -- Added S_STARTUP to handle the sensor initialization safely
    type state_type is (S_STARTUP, S_MONITOR, S_FREEFALL);
    signal current_state, next_state : state_type;

    -- Internal signal for magnitude squared
    signal mag2 : unsigned(31 downto 0);
    
    -- Timeout counter for 1 second @ 50 MHz clock
    constant TIMEOUT_VALUE : integer := 50000000;
    signal timeout_counter : integer range 0 to TIMEOUT_VALUE;
    
    -- Control signals for the counter
    signal reset_counter, increment_counter : std_logic;

begin

    -- Instantiate the mag_sq module
    U_mag: entity work.mag_sq
        port map(
            accel_x  => accel_x,
            accel_y  => accel_y,
            accel_z  => accel_z,
            mag2_out => mag2
        );

    ------------------------------------------------------------------------
    -- Free-Fall Timeout Counter Process
    ------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            timeout_counter <= 0;
        elsif rising_edge(clk) then
            if reset_counter = '1' then
                timeout_counter <= 0;
            elsif increment_counter = '1' then
                if timeout_counter < TIMEOUT_VALUE then
                    timeout_counter <= timeout_counter + 1;
                end if;
            end if;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- State Register (Sequential)
    ------------------------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            -- Reset into S_STARTUP, not S_MONITOR
            current_state <= S_STARTUP;
        elsif rising_edge(clk) then
            current_state <= next_state;
        end if;
    end process;

    ------------------------------------------------------------------------
    -- Next State Logic (Combinational)
    ------------------------------------------------------------------------
    process(current_state, mag2, timeout_counter)
    begin
        -- Default outputs
        next_state         <= current_state;
        fall_trigger_out   <= '0';
        reset_counter      <= '0';
        increment_counter  <= '0';

        case current_state is

            -- NEW STATE: Wait for the accelerometer to come online.
            -- The accel interface outputs 0s during reset. We stay here until
            -- we see a value larger than FREE_FALL_THRESHOLD (indicating gravity).
            when S_STARTUP =>
                if mag2 > FREE_FALL_THRESHOLD then
                    -- Sensor is active and showing gravity. Now safe to monitor.
                    next_state <= S_MONITOR;
                end if;

            -- Normal Operation: Wait for a free-fall event
            when S_MONITOR =>
                if mag2 < FREE_FALL_THRESHOLD then
                    next_state <= S_FREEFALL;
                    reset_counter <= '1'; -- Start the 1-second timer
                end if;

            -- In free-fall, wait for impact or timeout
            when S_FREEFALL =>
                increment_counter <= '1'; -- Run the timer
                
                if mag2 > IMPACT_THRESHOLD then
                    -- IMPACT DETECTED! This is a fall.
                    next_state       <= S_MONITOR;
                    fall_trigger_out <= '1'; -- Send the trigger pulse
                
                elsif timeout_counter = TIMEOUT_VALUE then
                    -- TIMEOUT! No impact, not a fall.
                    next_state <= S_MONITOR;
                end if;
                
        end case;
    end process;

end architecture rtl;