library ieee;
  use ieee.std_logic_1164.all;
  use ieee.std_logic_unsigned.all;
  use ieee.numeric_std.all;
library work;

entity mem is
  port (
    clk     : in  std_logic;
    rst_n   : in  std_logic;

    out_mem : out std_logic_vector(15 downto 0);
    in_mem  : in  std_logic_vector(15 downto 0);
    read    : in  std_logic;
    write   : in  std_logic;
    end_mem : in  std_logic_vector(7 downto 0)
  );
end entity;

architecture rtl of mem is
  subtype word is std_logic_vector(15 downto 0);
  type mem is array (0 to 255) of word;
  signal memoria : mem;
begin

  process (clk)
  begin
    if rising_edge(clk) then
      if (rst_n = '0') then
        -- Teste para LOAD_ADD: R4 = R4 + MEM(38)
          memoria(0) <= "0101000000100000"; -- LOAD R4, 32   -> R4 = 2
          memoria(1) <= "0111000000100110"; -- LOAD_ADD R4, 38  -> R4 = R4 + MEM(38) = 2 + 5 = 7
        
          -- Teste para SWAP_REG_MEM: Troca R5 com MEM(40)
          memoria(2) <= "0101010000100010"; -- LOAD R5, 34   -> R5 = 2
          memoria(3) <= "1000010000101000"; -- SWAP R5, 40   -> Troca R5 <-> MEM(40)
        
          memoria(4) <= "1111000000000000"; -- HALT
        
          -- Memória de dados
          memoria(32) <= "0000000000000010"; -- 2
          memoria(34) <= "0000000000000010"; -- 2
          memoria(36) <= "0000000001100011"; -- 99
          memoria(38) <= "0000000000000101"; -- 5 (para somar no LOAD_ADD)
          memoria(40) <= "0000000000000011"; -- 3 (para trocar com R5)

        for i in 50 to 255 loop
          memoria(i) <= (others => '0');
        end loop;

      else
        -------- Leitura da memoria
        if (read = '1' and write = '0') then
          out_mem <= memoria(to_integer(unsigned(end_mem)));
          -------- Escrita na memoria
        --elsif (read = '0' and write = '1') then
        else
          memoria(to_integer(unsigned(end_mem))) <= in_mem;
        end if;
      end if;
    end if;
  end process;
end architecture;
