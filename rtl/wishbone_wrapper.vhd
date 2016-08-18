library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library work;
use work.rv_components.all;

entity orca_wishbone is

  generic (
    REGISTER_SIZE      : integer               := 32;
    RESET_VECTOR       : natural               := 16#00000200#;
    MULTIPLY_ENABLE    : natural range 0 to 1  := 0;
    DIVIDE_ENABLE      : natural range 0 to 1  := 0;
    SHIFTER_MAX_CYCLES : natural               := 1;
    COUNTER_LENGTH     : natural               := 64;
    BRANCH_PREDICTORS  : natural               := 0;
    PIPELINE_STAGES    : natural range 4 to 5  := 5;
    FORWARD_ALU_ONLY   : natural range 0 to 1  := 1;
    LVE_ENABLE         : natural range 0 to 1  := 0;
    PLIC_ENABLE        : boolean               := false;
    NUM_EXT_INTERRUPTS : natural range 2 to 32 := 2;
    SCRATCHPAD_SIZE    : integer               := 1024;
    FAMILY             : string                := "ALTERA");

  port(clk            : in std_logic;
       scratchpad_clk : in std_logic;
       reset          : in std_logic;

       data_ADR_O   : out std_logic_vector(REGISTER_SIZE-1 downto 0);
       data_DAT_I   : in  std_logic_vector(REGISTER_SIZE-1 downto 0);
       data_DAT_O   : out std_logic_vector(REGISTER_SIZE-1 downto 0);
       data_WE_O    : out std_logic;
       data_SEL_O   : out std_logic_vector(REGISTER_SIZE/8 -1 downto 0);
       data_STB_O   : out std_logic;
       data_ACK_I   : in  std_logic;
       data_CYC_O   : out std_logic;
       data_CTI_O   : out std_logic_vector(2 downto 0);
       data_STALL_I : in  std_logic;

       instr_ADR_O   : out std_logic_vector(REGISTER_SIZE-1 downto 0);
       instr_DAT_I   : in  std_logic_vector(REGISTER_SIZE-1 downto 0);
       instr_STB_O   : out std_logic;
       instr_ACK_I   : in  std_logic;
       instr_CYC_O   : out std_logic;
       instr_CTI_O   : out std_logic_vector(2 downto 0);
       instr_STALL_I : in  std_logic;

       global_interrupts : in std_logic_vector(NUM_EXT_INTERRUPTS-1 downto 0)
       );

end entity orca_wishbone;



architecture rtl of orca_wishbone is
  signal avm_data_address       : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal avm_data_byteenable    : std_logic_vector(REGISTER_SIZE/8 -1 downto 0);
  signal avm_data_read          : std_logic;
  signal avm_data_readdata      : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal avm_data_write         : std_logic;
  signal avm_data_writedata     : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal avm_data_lock          : std_logic;
  signal avm_data_waitrequest   : std_logic;
  signal avm_data_readdatavalid : std_logic;

  signal data_waitrequest    : std_logic;
  signal data_readdatavalid  : std_logic;
  signal data_saved_data     : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_was_waiting    : std_logic;
  signal data_delayed_valid  : std_logic;
  signal data_suppress_valid : std_logic;

  signal instr_readdatavalid  : std_logic;
  signal instr_saved_data     : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal instr_was_waiting    : std_logic;
  signal instr_delayed_valid  : std_logic;
  signal instr_suppress_valid : std_logic;

  signal avm_instruction_address       : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal avm_instruction_read          : std_logic;
  signal avm_instruction_readdata      : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal avm_instruction_waitrequest   : std_logic;
  signal avm_instruction_readdatavalid : std_logic;

  signal instr_readvalid_mask : std_logic;
  signal data_readvalid_mask  : std_logic;


  constant INCR_BURST_CYC : std_logic_vector(2 downto 0) := "010";
  constant END_BURST_CYC  : std_logic_vector(2 downto 0) := "111";
  constant CLASSIC_CYC    : std_logic_vector(2 downto 0) := "000";

  signal burst_break   : std_logic;
  signal expected_addr : std_logic_vector(REGISTER_SIZE -1 downto 0);
  signal last_bb       : std_logic;



begin  -- architecture rtl

  rv : component orca
    generic map (
      REGISTER_SIZE      => REGISTER_SIZE,
      RESET_VECTOR       => RESET_VECTOR,
      MULTIPLY_ENABLE    => MULTIPLY_ENABLE,
      DIVIDE_ENABLE      => DIVIDE_ENABLE,
      SHIFTER_MAX_CYCLES => SHIFTER_MAX_CYCLES,
      COUNTER_LENGTH     => COUNTER_LENGTH,
      BRANCH_PREDICTORS  => BRANCH_PREDICTORS,
      PIPELINE_STAGES    => PIPELINE_STAGES,
      FORWARD_ALU_ONLY   => FORWARD_ALU_ONLY,
      LVE_ENABLE         => LVE_ENABLE,
      SCRATCHPAD_SIZE    => SCRATCHPAD_SIZE,
      NUM_EXT_INTERRUPTS => NUM_EXT_INTERRUPTS,
      FAMILY             => FAMILY)
    port map(
      clk            => clk,
      scratchpad_clk => scratchpad_clk,
      reset          => reset,


      --avalon master bus
      avm_data_address       => avm_data_address,
      avm_data_byteenable    => avm_data_byteenable,
      avm_data_read          => avm_data_read,
      avm_data_readdata      => avm_data_readdata,
      avm_data_write         => avm_data_write,
      avm_data_writedata     => avm_data_writedata,
      avm_data_waitrequest   => avm_data_waitrequest,
      avm_data_readdatavalid => avm_data_readdatavalid,

      --avalon master bus                     --avalon master bus
      avm_instruction_address       => avm_instruction_address,
      avm_instruction_read          => avm_instruction_read,
      avm_instruction_readdata      => avm_instruction_readdata,
      avm_instruction_waitrequest   => avm_instruction_waitrequest,
      avm_instruction_readdatavalid => avm_instruction_readdatavalid,

      global_interrupts => global_interrupts
      );

  --output
  data_ADR_O             <= avm_data_address;
  data_DAT_O             <= avm_data_writedata;
  data_WE_O              <= avm_data_write;
  data_SEL_O             <= avm_data_byteenable;
  data_STB_O             <= (avm_data_write or avm_data_read);
  data_CYC_O             <= (avm_data_write or avm_data_read);
  data_CTI_O             <= CLASSIC_CYC;
  --input
  avm_data_readdata      <= data_saved_data when data_delayed_valid = '1' else data_DAT_I;
  data_readdatavalid     <= data_ACK_I and data_readvalid_mask;
  avm_data_waitrequest   <= data_STALL_I;
  avm_data_readdatavalid <= (data_readdatavalid and not data_suppress_valid) or data_delayed_valid;



  --output
  instr_ADR_O                   <= avm_instruction_address;
  instr_STB_O                   <= avm_instruction_read;
  instr_CYC_O                   <= avm_instruction_read;
  instr_CTI_O                   <= CLASSIC_CYC;
  --input
  avm_instruction_readdata      <= instr_saved_data when instr_delayed_valid = '1' else instr_DAT_I;
  avm_instruction_waitrequest   <= instr_STALL_I;
  instr_readdatavalid           <= instr_ACK_I and instr_readvalid_mask;
  avm_instruction_readdatavalid <= (instr_readdatavalid and not instr_suppress_valid) or instr_delayed_valid;



  --if previous cycle was a read, then this cycle can have a
  --readdatavalid, else not,
  process(clk)
  begin
    if rising_edge(clk) then

      if avm_data_read = '1' then
        data_readvalid_mask <= '1';
      elsif avm_data_readdatavalid = '1' then
        data_readvalid_mask <= '0';
      end if;

      if avm_instruction_read = '1' then
        instr_readvalid_mask <= '1';
      elsif avm_instruction_readdatavalid = '1' then
        instr_readvalid_mask <= '0';
      end if;

      if reset = '1' then
        instr_readvalid_mask <= '0';
        data_readvalid_mask  <= '0';
      end if;
    end if;
  end process;

  --it is possible for waitrequest to go low on the same cycle as readvalid
  --goes high, if this is the case, save the readdata for the next cycle.
  process(clk)
  begin
    if rising_edge(clk) then
      data_was_waiting   <= data_STALL_I;
      data_delayed_valid <= data_suppress_valid;
      data_saved_data    <= data_DAT_I;

      instr_was_waiting   <= instr_STALL_I;
      instr_delayed_valid <= instr_suppress_valid;
      instr_saved_data    <= instr_DAT_I;

    end if;
  end process;

  data_suppress_valid  <= data_was_waiting and data_readdatavalid;
  instr_suppress_valid <= instr_was_waiting and instr_readdatavalid;

end architecture rtl;
