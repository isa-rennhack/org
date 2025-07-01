library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity control_unit is
  port (
    rst_n     : in  std_logic;
    clk       : in  std_logic;
    pc_enable : out std_logic;
    mem_write : out std_logic;
    mem_read  : out std_logic;
    branch    : out std_logic;
    addr_sel  : out std_logic;
    r_sel     : out std_logic;
    ir_enable : out std_logic;
    op_ULA    : out std_logic_vector(1 downto 0);
    reg_write : out std_logic;
    f_zero    : in  std_logic;
    f_neg     : in  std_logic;
    opcode    : in  std_logic_vector(3 downto 0);
    debug_current_state : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of control_unit is

  type state_type is (
    BUSCA_INST, DECODIFICA, EXECUTA, SALVA_PC,
    STORE, LOAD, ULA, ULA_OP, ULA_W8, WMEM, WREG, HALT,
    LOAD_ADD_MEM_READ, SWAP_READ, SWAP_WRITE
  );

  signal current_state : state_type;
  signal old_state     : state_type;

begin

  process (clk)
  begin
    if rising_edge(clk) then
      if rst_n = '0' then
        current_state <= BUSCA_INST;
      else
        old_state <= current_state;
        case current_state is
          when BUSCA_INST => current_state <= DECODIFICA;
          when DECODIFICA => current_state <= EXECUTA;
          when EXECUTA =>
            case opcode is
              when "0000" => current_state <= ULA;        -- ADD
              when "0001" => current_state <= ULA;        -- SUB
              when "0010" => current_state <= ULA;        -- AND
              when "0011" => -- BEQ
                if f_zero = '1' then current_state <= SALVA_PC;
                else current_state <= BUSCA_INST; end if;
              when "0100" => current_state <= SALVA_PC;  -- JUMP
              when "0101" => current_state <= LOAD;      -- LOAD
              when "0110" => current_state <= STORE;     -- STORE
              when "0111" => current_state <= LOAD_ADD_MEM_READ;  -- LOAD_ADD
              when "1000" => current_state <= SWAP_READ; -- SWAP_REG_MEM
              when others => current_state <= HALT;
            end case;
          when STORE => current_state <= WMEM;
          when WMEM => current_state <= BUSCA_INST;
          when WREG => current_state <= BUSCA_INST;
          when LOAD => current_state <= WREG;
          when ULA => current_state <= ULA_OP;
          when ULA_OP => current_state <= ULA_W8;
          when ULA_W8 => current_state <= WREG;
          when SALVA_PC => current_state <= BUSCA_INST;
          when LOAD_ADD_MEM_READ => current_state <= ULA; -- Após ler da memória, vai para ULA para somar
          when SWAP_READ => current_state <= SWAP_WRITE;
          when SWAP_WRITE => current_state <= BUSCA_INST;
          when others => current_state <= HALT;
        end case;
      end if;
    end if;
  end process;

  branch      <= '1' when current_state = SALVA_PC else '0';
  pc_enable   <= '1' when current_state = SALVA_PC or current_state = DECODIFICA else '0';
  ir_enable   <= '1' when current_state = DECODIFICA else '0';
  addr_sel    <= '1' when current_state = LOAD or current_state = WMEM or
                         current_state = LOAD_ADD_MEM_READ or current_state = SWAP_READ or current_state = SWAP_WRITE else '0';
  -- r_sel: Seleciona a fonte para escrita no registrador (1=memória, 0=ULA)
  -- Para LOAD e SWAP_WRITE, queremos o valor da memória. Para LOAD_ADD, queremos o valor da ULA.
  r_sel       <= '1' when (current_state = WREG and old_state = LOAD) or (current_state = SWAP_WRITE) else '0';
  mem_read    <= '1' when current_state = BUSCA_INST or current_state = LOAD or
                         current_state = LOAD_ADD_MEM_READ or current_state = SWAP_READ else '0';
  mem_write   <= '1' when current_state = WMEM or current_state = SWAP_WRITE else '0';
  reg_write   <= '1' when current_state = WREG or current_state = SWAP_WRITE else '0'; -- SWAP_WRITE também escreve no registrador

  -- op_ULA: Define a operação da ULA
  op_ULA <= "00" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0000" else -- ADD
            "01" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0001" else -- SUB
            "10" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0010" else -- AND
            "00" when (current_state = ULA_OP or current_state = ULA_W8) and opcode = "0111" else -- LOAD_ADD
            "11"; -- default (não utilizado para operações válidas)

  -- Mapeamento do estado atual para um vetor de std_logic para depuração
  with current_state select debug_current_state <=
    x"0" when BUSCA_INST,
    x"1" when DECODIFICA,
    x"2" when EXECUTA,
    x"3" when SALVA_PC,
    x"4" when STORE,
    x"5" when LOAD,
    x"6" when ULA,
    x"7" when ULA_OP,
    x"8" when ULA_W8,
    x"9" when WMEM,
    x"A" when WREG,
    x"B" when HALT,
    x"C" when LOAD_ADD_MEM_READ, -- Novo mapeamento
    x"D" when SWAP_READ,
    x"E" when SWAP_WRITE,
    x"F" when others;

end architecture;
