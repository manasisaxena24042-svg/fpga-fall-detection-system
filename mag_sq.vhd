library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mag_sq is
    port(
        accel_x  : in  signed(15 downto 0);
        accel_y  : in  signed(15 downto 0);
        accel_z  : in  signed(15 downto 0);
        mag2_out : out unsigned(31 downto 0)
    );
end entity;

architecture rtl of mag_sq is
    -- Perform signed multiplication first (16-bit * 16-bit = 32-bit)
    signal x_sq_signed, y_sq_signed, z_sq_signed : signed(31 downto 0);
    
    -- Convert 32-bit signed to 32-bit unsigned
    signal x_sq, y_sq, z_sq : unsigned(31 downto 0);
    
    -- Sum requires one extra bit to prevent overflow during addition
    signal sum_sq           : unsigned(32 downto 0);
begin

    -- Step 1: Perform signed multiplication
    x_sq_signed <= accel_x * accel_x;
    y_sq_signed <= accel_y * accel_y;
    z_sq_signed <= accel_z * accel_z;

    -- Step 2: Convert signed squares to unsigned
    -- This is now safe, as the results are all positive
    x_sq <= unsigned(x_sq_signed);
    y_sq <= unsigned(y_sq_signed);
    z_sq <= unsigned(z_sq_signed);
    
    -- Step 3: Sum the squares (result is 17 bits)
    sum_sq <= ('0' & x_sq) + ('0' & y_sq) + ('0' & z_sq);

    -- Step 4: Output with Saturation Logic
    -- If the 33rd bit (MSB) is '1', an overflow occurred.
    -- In that case, output the maximum 32-bit value.
    -- Otherwise, output the lower 32 bits.
    mag2_out <= (others => '1') when sum_sq(32) = '1' else
                sum_sq(31 downto 0);

end architecture rtl;