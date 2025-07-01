library IEEE;
use IEEE.NUMERIC_std.all;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith;

entity tb_mips is

end tb_mips;

architecture tb_mips of tb_mips is
	signal clk	: std_logic := '0';
	signal rst_n	: std_logic := '0';
	constant clk_period : time	:= 10 ns;

begin


  rst_n <= '1' after 5*clk_period;
  clk_100Mhz : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

    mips: entity work.MIPs
    port map(
        clk => clk,
        rst_n => rst_n
    );

end tb_mips;