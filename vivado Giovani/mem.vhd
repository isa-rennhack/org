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
        memoria(0) <= "0101000000100000"; -- LOAD R4, 32 (Carrega valor 1 para R4)
        memoria(1) <= "0101010000100010"; -- LOAD R5, 34 (Carrega valor 2 para R5)

        -- Subtrair os valores
        memoria(2) <= "0001010001010110"; -- SUB R6, R4, R5 (R6 = R4 - R5)

        -- Armazenar o resultado na memória
        memoria(3) <= "0110011000100100"; -- STORE R6, 36 (Armazena R6 em 36)

        -- Finalizar o programa
        memoria(4) <= "1111000000000000"; -- HALT

        -- Dados na memória
        memoria(32) <= "0000000000000001"; -- Valor 1 (endereço 32)
        memoria(34) <= "0000000000000010"; -- Valor 2 (endereço 34)
        memoria(36) <= "0000000000000000"; -- Resultado será armazenado aqui (endereço 36)

        for i in 40 to 255 loop
          memoria(i) <= (others => '0');
        end loop;

      else
        -------- Leitura da memoria
        if (read = '1' and write = '0') then
          out_mem <= memoria(to_integer(unsigned(end_mem)));
          -------- Escrita na memoria
        elsif (read = '0' and write = '1') then
          memoria(to_integer(unsigned(end_mem))) <= in_mem;
        end if;
      end if;
    end if;
  end process;
end architecture;
