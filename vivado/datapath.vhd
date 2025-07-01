library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use IEEE.STD_LOGIC_UNSIGNED.all; -- Mantenha esta biblioteca para a opera��o de soma no PC
  -- Uncomment the following library declaration if instantiating
  -- any Xilinx leaf cells in this code.
library UNISIM;
  use UNISIM.VComponents.all;

entity datapath is
  port (
    rst_n          : in  std_logic;
    clk            : in  std_logic;
    data_in        : out std_logic_vector(15 downto 0);
    data_out       : in  std_logic_vector(15 downto 0);
    addr           : out std_logic_vector(7 downto 0);
    opcode         : out std_logic_vector(3 downto 0);
    ----IN
    --------------MUX's
    branch         : in  std_logic;
    addr_sel       : in  std_logic;
    r_sel          : in  std_logic;
    pc_enable      : in  std_logic;
    ir_enable      : in  std_logic;
    op_ULA         : in  std_logic_vector(1 downto 0);
    reg_write      : in  std_logic;
    -------------FLAG's
    flag_zero      : out std_logic;
    flag_neg       : out std_logic
  );
end entity;

architecture rtl of datapath is
  signal pc             : std_logic_vector(7 downto 0);
  signal mem_out        : std_logic_vector(15 downto 0);
  signal reg_banco_m    : std_logic_vector(15 downto 0);
  signal mem_addr       : std_logic_vector(7 downto 0);
  signal bus_a          : std_logic_vector(15 downto 0);
  signal bus_b          : std_logic_vector(15 downto 0);
  signal R1             : std_logic_vector(2 downto 0);
  signal R2             : std_logic_vector(2 downto 0);
  signal R3             : std_logic_vector(2 downto 0);
  signal R4             : std_logic_vector(15 downto 0);
  signal R5             : std_logic_vector(15 downto 0);
  signal R6             : std_logic_vector(15 downto 0);
  signal R7             : std_logic_vector(15 downto 0);
  signal ula_a          : std_logic_vector(15 downto 0);
  signal ula_b          : std_logic_vector(15 downto 0);
  signal ula_out        : std_logic_vector(15 downto 0);
  signal mux_branch_out : std_logic_vector(7 downto 0);

begin
  -----------------
  mux_mem: addr <= mem_addr when addr_sel = '1' else pc;

  mux_reg: reg_banco_m <= data_out when r_sel = '1' else ula_out;

  mux_branch: mux_branch_out <= mem_addr when branch = '1' else pc + 1;
  -----------------
  reg_pc: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        pc <= "00000000";
      else
        if (pc_enable = '1') then
          pc <= mux_branch_out;
        end if;
      end if;
    end if;
  end process;
  -----------------
  reg_inst: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        mem_addr <= x"00";
        R1 <= "000";
        R2 <= "000";
        R3 <= "000";
        opcode <= "0000";
      elsif (ir_enable = '1') then
        case data_out(15 downto 12) is
          when "0000" => --add
            R3 <= data_out(11 downto 9);
            R1 <= data_out(8 downto 6);
            R2 <= data_out(5 downto 3);
          when "0001" => --sub
            R3 <= data_out(11 downto 9);
            R1 <= data_out(8 downto 6);
            R2 <= data_out(5 downto 3);
          when "0010" => --and
            R3 <= data_out(11 downto 9);
            R1 <= data_out(8 downto 6);
            R2 <= data_out(5 downto 3);
          when "0011" => --beq
            R1 <= data_out(11 downto 9);
            R2 <= data_out(8 downto 6);
            mem_addr <= "00" & data_out(5 downto 0);
          when "0100" => --jump
            mem_addr <= data_out(7 downto 0);
          when "0101" => --load
            R1 <= data_out(11 downto 9);
            R2 <= data_out(8 downto 6);
            mem_addr <= "00" & data_out(5 downto 0);
          when "0110" => --store
            R1 <= data_out(11 downto 9);
            R2 <= data_out(8 downto 6);
            mem_addr <= "00" & data_out(5 downto 0);
          when "1111" => --halt
          -- nao faz nada
          when others =>
          -- nao faz nada
        end case;
        opcode <= data_out(15 downto 12);
      end if;
    end if;
  end process;
  -----------------
  reg_a: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        ula_a <= x"0000";
      else
        ula_a <= bus_a;
        data_in <= bus_a;
      end if;
    end if;
  end process;

  reg_b: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        ula_b <= x"0000";
      else
        ula_b <= bus_b;
        data_in <= bus_b;
      end if;
    end if;
  end process;
  -----------------
  reg_banco: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        R4 <= x"0000";
        R5 <= x"0000";
        R6 <= x"0000";
        R7 <= x"0000";
        bus_b <= x"0000";
        bus_a <= x"0000";
      else
        if (reg_write = '1') then
          case R3 is
            when "000" => R4 <= reg_banco_m;
            when "001" => R5 <= reg_banco_m;
            when "010" => R6 <= reg_banco_m;
            when others => R7 <= reg_banco_m;
          end case;
        end if;
        case R1 is
          when "000" => bus_a <= R4;
          when "001" => bus_a <= R5;
          when "010" => bus_a <= R6;
          when others => bus_a <= R7;
        end case;
        case R2 is
          when "000" => bus_b <= R4;
          when "001" => bus_b <= R5;
          when "010" => bus_b <= R6;
          when others => bus_b <= R7;
        end case;
      end if;
    end if;
  end process;
  -----------------
  ula: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        ula_out <= x"0000";
      else
        case op_ULA is
          when "00" => --add
            ula_out <= ula_a + ula_b;
          when "01" => --sub
            ula_out <= ula_a - ula_b;
          when "10" => --and
            ula_out <= ula_a and ula_b;
          when others =>
        end case;
      end if;
    end if;
  end process;
  -------------------
  flag_zero <= '1' when ula_out = x"0000" else '0';
  flag_neg  <= '1' when (ula_out(15) = '1') else '0';
  -------------------
end architecture;
