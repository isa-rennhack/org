library IEEE;
  use IEEE.STD_LOGIC_1164.all;

  use IEEE.NUMERIC_STD.all;

library UNISIM;
  use UNISIM.VComponents.all;

entity control_unit is
  port (
    rst_n     : in  std_logic;
    clk       : in  std_logic;
    pc_enable : out std_logic;
    mem_write : out std_logic;
    mem_read  : out std_logic;
    -------------datapath
    branch    : out std_logic;
    addr_sel  : out std_logic;
    r_sel     : out std_logic;
    ir_enable : out std_logic;
    op_ULA    : out std_logic_vector(1 downto 0);
    reg_write : out std_logic;
    -------------FLAG's
    f_zero    : in  std_logic;
    f_neg     : in  std_logic;
    opcode    : in  std_logic_vector(3 downto 0)
  );

end entity;

architecture rtl of control_unit is

  type state_type is (BUSCA_INST, DECODIFICA, EXECUTA, SALVA_PC, STORE, LOAD, ULA, ULA_OP, ULA_W8, WMEM, WREG, HALT);
  signal current_state : state_type;
  signal old_state     : state_type;
begin

  inicio: process (clk)
  begin
    if (clk'event and clk = '1') then
      if (rst_n = '0') then
        current_state <= BUSCA_INST;
      else
        old_state <= current_state;
        case current_state is
          when BUSCA_INST =>
            current_state <= DECODIFICA;
          when DECODIFICA =>
            current_state <= EXECUTA;
          when EXECUTA =>
            case opcode is
              when "0000" => -- ADD
                current_state <= ULA;
              when "0001" => -- SUB
                current_state <= ULA;
              when "0010" => -- AND
                current_state <= ULA;
              when "0011" => -- BEQ
                if (f_zero = '1') then
                  current_state <= SALVA_PC;
                else
                  current_state <= BUSCA_INST;
                end if;
              when "0100" => -- JUMP
                current_state <= SALVA_PC;
              when "0101" => -- LOAD
                current_state <= LOAD;
              when "0110" => -- STORE
                current_state <= STORE;
              when others =>
                current_state <= HALT;
            end case;
          when STORE =>
            current_state <= WMEM;
          when WMEM =>
            current_state <= BUSCA_INST;
          when WREG =>
            current_state <= BUSCA_INST;
          when LOAD =>
            current_state <= WREG;
          when ULA =>
            current_state <= ULA_OP;
          when ULA_OP =>
            current_state <= ULA_W8;
          when ULA_W8 =>
            current_state <= WREG;
          when SALVA_PC =>
            current_state <= BUSCA_INST;
          when others => --halt
            current_state <= HALT;
        end case;
      end if;
    end if;
  end process;

  branch    <= '1' when current_state = SALVA_PC else '0';
  pc_enable <= '1' when (current_state = SALVA_PC or current_state = DECODIFICA) else '0';
  ir_enable <= '1' when current_state = DECODIFICA else '0';
  addr_sel  <= '1' when current_state = LOAD or current_state = WMEM else '0';
  r_sel     <= '1' when (current_state = WREG and old_state = LOAD) else '0';
  mem_read  <= '1' when (current_state = BUSCA_INST or current_state = LOAD) else '0';
  mem_write <= '1' when current_state = WMEM else '0';
  reg_write <= '1' when current_state = WREG else '0';

  op_ULA <= "00" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0000" else -- ADD
            "01" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0001" else -- SUB
            "10" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0010" else -- AND
            "11" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0011";

end architecture;
