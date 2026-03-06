-- File: ssd_driver.vhd
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ssd_driver is
    port(
        seconds_in : in  integer range 0 to 99;
        
        -- 6 x 8-bit outputs for HEX5 down to HEX0
        -- (bits 6..0 are segments, bit 7 is decimal point)
        ssds_out   : out std_logic_vector(47 downto 0)
    );
end entity;

architecture rtl of ssd_driver is

    signal tens_digit : integer range 0 to 9;
    signal ones_digit : integer range 0 to 9;

    -- Function to convert one BCD digit to a 7-segment pattern
    -- DE10-Lite is common anode, so '0' = segment ON [cite: 894]
    -- Segments: 0=top, 1=top-right, 2=bottom-right, 3=bottom,
    --           4=bottom-left, 5=top-left, 6=middle
    function bcd_to_7seg(digit : integer) return std_logic_vector is
        variable pattern : std_logic_vector(6 downto 0);
    begin
        case digit is
            when 0 =>   pattern := "1000000"; -- '0'
            when 1 =>   pattern := "1111001"; -- '1'
            when 2 =>   pattern := "0100100"; -- '2'
            when 3 =>   pattern := "0110000"; -- '3'
            when 4 =>   pattern := "0011001"; -- '4'
            when 5 =>   pattern := "0010010"; -- '5'
            when 6 =>   pattern := "0000010"; -- '6'
            when 7 =>   pattern := "1111000"; -- '7'
            when 8 =>   pattern := "0000000"; -- '8'
            when 9 =>   pattern := "0010000"; -- '9'
            when others => pattern := "1111111"; -- Blank
        end case;
        return pattern;
    end function;

begin

    -- Convert the integer seconds into two BCD digits
    tens_digit <= seconds_in / 10;
    ones_digit <= seconds_in mod 10;
    
    -- Assign HEX0 (Ones Digit)
    ssds_out(6 downto 0) <= bcd_to_7seg(ones_digit);
    ssds_out(7)          <= '1'; -- Decimal Point OFF
    
    -- Assign HEX1 (Tens Digit)
    ssds_out(14 downto 8) <= bcd_to_7seg(tens_digit);
    ssds_out(15)          <= '1'; -- Decimal Point OFF
    
    -- Assign HEX2, HEX3, HEX4, HEX5 (All Blank)
    ssds_out(47 downto 16) <= (others => '1'); -- All segments and DPs OFF

end architecture;