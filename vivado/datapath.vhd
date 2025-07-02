library IEEE;
  use IEEE.STD_LOGIC_1164.all;
  use IEEE.NUMERIC_STD.all;
  use IEEE.STD_LOGIC_UNSIGNED.all;

library UNISIM;
  use UNISIM.VComponents.all;

entity datapath is
  port (
    rst_n          : in  std_logic;
    clk            : in  std_logic;
    data_in        : out std_logic_vector(15 downto 0); -- Saída para memória de dados (escrita)
    data_out       : in  std_logic_vector(15 downto 0); -- Entrada da memória de dados (leitura)
    data_out_instr : in  std_logic_vector(15 downto 0); -- Entrada da memória de instruções
    addr           : out std_logic_vector(7 downto 0);  -- Endereço para memória
    opcode         : out std_logic_vector(3 downto 0);  -- Opcode decodificado
    branch         : in  std_logic;
    addr_sel       : in  std_logic;
    r_sel          : in  std_logic;
    pc_enable      : in  std_logic;
    ir_enable      : in  std_logic;
    op_ULA         : in  std_logic_vector(1 downto 0);
    reg_write      : in  std_logic;
    flag_zero      : out std_logic;
    flag_neg       : out std_logic;
    mem_read       : in  std_logic;

    -- Novas portas de depuração
    debug_ula_a_mux_sel : out std_logic_vector(15 downto 0);
    debug_ula_b_mux_sel : out std_logic_vector(15 downto 0)
  );
end entity;

architecture rtl of datapath is
  signal pc              : std_logic_vector(7 downto 0);
  signal reg_banco_m     : std_logic_vector(15 downto 0); -- Valor a ser escrito no banco de registradores
  signal mem_addr        : std_logic_vector(7 downto 0);
  signal bus_a           : std_logic_vector(15 downto 0); -- Saída do banco de registradores A
  signal bus_b           : std_logic_vector(15 downto 0); -- Saída do banco de registradores B
  signal R1              : std_logic_vector(1 downto 0); -- Índice do registrador A
  signal R2              : std_logic_vector(1 downto 0); -- Índice do registrador B
  signal R3              : std_logic_vector(1 downto 0); -- Índice do registrador de destino/swap
  signal R4              : std_logic_vector(15 downto 0); -- Registrador 00
  signal R5              : std_logic_vector(15 downto 0); -- Registrador 01
  signal R6              : std_logic_vector(15 downto 0); -- Registrador 10
  signal R7              : std_logic_vector(15 downto 0); -- Registrador 11
  signal ula_a_reg       : std_logic_vector(15 downto 0); -- Registrador de entrada A da ULA
  signal ula_b_reg       : std_logic_vector(15 downto 0); -- Registrador de entrada B da ULA
  signal ula_out         : std_logic_vector(15 downto 0); -- Saída da ULA
  signal mux_branch_out  : std_logic_vector(7 downto 0);
  signal opcode_internal : std_logic_vector(3 downto 0); -- Opcode interno do IR
  signal temp_swap       : std_logic_vector(15 downto 0); -- Registrador temporário para SWAP_REG_MEM

  -- Sinais intermediários para seleção de registradores para ULA e memória
  signal reg_val_R1 : std_logic_vector(15 downto 0);
  signal reg_val_R2 : std_logic_vector(15 downto 0);
  signal reg_val_R3 : std_logic_vector(15 downto 0);

  -- Sinais para as entradas multiplexadas da ULA
  signal ula_a_mux_sel : std_logic_vector(15 downto 0);
  signal ula_b_mux_sel : std_logic_vector(15 downto 0);

begin

  opcode <= opcode_internal;

  -- Conecta os sinais de depuração às saídas
  debug_ula_a_mux_sel <= ula_a_mux_sel;
  debug_ula_b_mux_sel <= ula_b_mux_sel;

  -- Seleciona o endereço para a memória (PC para instrução, mem_addr para dados)
  addr <= mem_addr when addr_sel = '1' else pc;

  -- Seleciona a fonte para escrita no banco de registradores (memória ou ULA)
  reg_banco_m <= data_out when r_sel = '1' else ula_out;

  -- Seleciona o próximo valor do PC (PC+1 ou endereço de branch/jump)
  mux_branch_out <= mem_addr when branch = '1' else pc + 1;

  -- Processo do Program Counter (PC)
  reg_pc: process (clk, rst_n)
  begin
    if rst_n = '0' then
      pc <= "00000000";
    elsif rising_edge(clk) then
      if pc_enable = '1' then
        pc <= mux_branch_out;
      end if;
    end if;
  end process;

  -- Processo do Instruction Register (IR) e decodificação de campos
  reg_inst: process (clk, rst_n)
  begin
    if rst_n = '0' then
      mem_addr <= x"00";
      R1 <= "00"; R2 <= "00"; R3 <= "00";
      opcode_internal <= "0000";
    elsif rising_edge(clk) then
      if ir_enable = '1' then
        case data_out_instr(15 downto 12) is
          when "0000" | "0001" | "0010" => -- R-type: ADD, SUB, AND
            R1 <= data_out_instr(3 downto 2);  -- Fonte 1
            R2 <= data_out_instr(1 downto 0);  -- Fonte 2
            R3 <= data_out_instr(5 downto 4);  -- Destino
          when "0011" | "0100" => -- I-type/J-type: BEQ, JUMP
            mem_addr <= data_out_instr(7 downto 0); -- Endereço
          when "0101" => -- LOAD
            R3 <= data_out_instr(11 downto 10); -- Destino
            mem_addr <= data_out_instr(7 downto 0); -- Endereço de memória
          when "0110" => -- STORE
            R1 <= data_out_instr(11 downto 10); -- Fonte (registrador a ser armazenado)
            mem_addr <= data_out_instr(7 downto 0); -- Endereço de memória
          when "0111" => -- LOAD_ADD
            R3 <= data_out_instr(11 downto 10); -- Destino (também fonte para ULA_A)
            mem_addr <= data_out_instr(7 downto 0); -- Endereço de memória
          when "1000" => -- SWAP_REG_MEM
            R3 <= data_out_instr(11 downto 10); -- Registrador para swap
            mem_addr <= data_out_instr(7 downto 0); -- Endereço de memória
          when others => null;
        end case;
        opcode_internal <= data_out_instr(15 downto 12);
      end if;
    end if;
  end process;

  -- Lógica combinacional para obter o valor dos registradores com base em seus índices
  with R1 select reg_val_R1 <=
    R4 when "00",
    R5 when "01",
    R6 when "10",
    R7 when others;

  with R2 select reg_val_R2 <=
    R4 when "00",
    R5 when "01",
    R6 when "10",
    R7 when others;

  with R3 select reg_val_R3 <=
    R4 when "00",
    R5 when "01",
    R6 when "10",
    R7 when others;

  -- Lógica combinacional para selecionar a entrada A da ULA (ula_a_mux_sel)
  with opcode_internal select ula_a_mux_sel <=
    reg_val_R3 when "0111", -- LOAD_ADD: R3 é a entrada A
    reg_val_R1 when others; -- Outras operações: R1 é a entrada A

  -- Lógica combinacional para selecionar a entrada B da ULA (ula_b_mux_sel)
  with opcode_internal select ula_b_mux_sel <=
    data_out when "0111", -- LOAD_ADD: data_out é a entrada B
    reg_val_R2 when others; -- Outras operações: R2 é a entrada B

  -- Registrador de entrada A da ULA
  reg_ula_a: process (clk, rst_n)
  begin
    if rst_n = '0' then
      ula_a_reg <= x"0000";
    elsif rising_edge(clk) then
      ula_a_reg <= ula_a_mux_sel; -- Registra a entrada multiplexada
    end if;
  end process;

  -- Registrador de entrada B da ULA
  reg_ula_b: process (clk, rst_n)
  begin
    if rst_n = '0' then
      ula_b_reg <= x"0000";
    elsif rising_edge(clk) then
      ula_b_reg <= ula_b_mux_sel; -- Registra a entrada multiplexada
    end if;
  end process;

  -- Processo do Banco de Registradores
  reg_banco: process (clk, rst_n)
  begin
    if rst_n = '0' then
      R4 <= x"0000"; R5 <= x"0000"; R6 <= x"0000"; R7 <= x"0000";
    elsif rising_edge(clk) then
      -- Escrita no registrador
      if reg_write = '1' then
        case R3 is
          when "00" => R4 <= reg_banco_m;
          when "01" => R5 <= reg_banco_m;
          when "10" => R6 <= reg_banco_m;
          when others => R7 <= reg_banco_m;
        end case;
      end if;

      -- Leitura do registrador R1 para bus_a
      case R1 is
        when "00" => bus_a <= R4;
        when "01" => bus_a <= R5;
        when "10" => bus_a <= R6;
        when others => bus_a <= R7;
      end case;

      -- Leitura do registrador R2 para bus_b
      case R2 is
        when "00" => bus_b <= R4;
        when "01" => bus_b <= R5;
        when "10" => bus_b <= R6;
        when others => bus_b <= R7;
      end case;
    end if;
  end process;

  -- Processo da Unidade Lógica Aritmética (ULA)
  ula: process (clk, rst_n)
  begin
    if rst_n = '0' then
      ula_out <= x"0000";
    elsif rising_edge(clk) then
      case op_ULA is
        when "00" => ula_out <= ula_a_reg + ula_b_reg;
        when "01" => ula_out <= ula_a_reg - ula_b_reg;
        when "10" => ula_out <= ula_a_reg and ula_b_reg;
        when others => null; -- Não deve ocorrer com opcodes válidos
      end case;
    end if;
  end process;

  -- Processo para armazenar o valor lido da memória em temp_swap para SWAP_REG_MEM
  reg_temp_swap: process (clk, rst_n)
  begin
    if rst_n = '0' then
      temp_swap <= x"0000";
    elsif rising_edge(clk) then
      -- Usa a porta de entrada mem_read diretamente (sem sinal intermediário)
      if (opcode_internal = "1000" and mem_read = '1') then
        temp_swap <= data_out;
      end if;
    end if;
  end process;

  -- Lógica combinacional para o dado a ser escrito na memória (data_in)
  with opcode_internal select data_in <=
    reg_val_R1 when "0110", -- STORE: R1 para memória
    reg_val_R3 when "1000", -- SWAP_REG_MEM: R3 para memória
    (others => '0') when others; -- Valor padrão

  -- Geração dos flags Zero e Negativo
  flag_zero <= '1' when ula_out = x"0000" else '0';
  flag_neg  <= '1' when ula_out(15) = '1' else '0';

end architecture;
