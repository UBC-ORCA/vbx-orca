library ieee;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;

use work.rv_components.all;
use work.top_component_pkg.all;
use work.top_util_pkg.all;

entity top is
  generic(
    GPIO_LENGTH : integer := 12
  );
  port(
    clk            : in std_logic;
    scratchpad_clk : in std_logic;
    reset_btn      : in std_logic;

    --uart
    rxd : in  std_logic;
    txd : out std_logic;
    cts : in  std_logic;
    rts : out std_logic;

    R_LED  : out std_logic;
    G_LED  : out std_logic;
    B_LED  : out std_logic;
    HP_LED : out std_logic;

    gpio : inout std_logic_vector(GPIO_LENGTH-1 downto 0)
  );
end entity;

architecture rtl of top is

  constant REGISTER_SIZE : integer := 32;

  constant LED_COUNTER_LENGTH : integer := 24; 

  --for combined memory
  constant RAM_SIZE      : natural := 8*1024;
  --for seperate memory
  constant INST_RAM_SIZE : natural := 4*1024;
  constant DATA_RAM_SIZE : natural := 4*1024;

  constant SEPERATE_MEMS : boolean := true;

  signal reset : std_logic;

  signal data_ADR_O  : std_logic_vector(31 downto 0);
  signal data_DAT_O  : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_WE_O   : std_logic;
  signal data_CYC_O  : std_logic;
  signal data_STB_O  : std_logic;
  signal data_SEL_O  : std_logic_vector(REGISTER_SIZE/8-1 downto 0);
  signal data_CTI_O  : std_logic_vector(2 downto 0);
  signal data_BTE_O  : std_logic_vector(1 downto 0);
  signal data_LOCK_O : std_logic;

  signal data_STALL_I : std_logic;
  signal data_DAT_I   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_ACK_I   : std_logic;
  signal data_ERR_I   : std_logic;
  signal data_RTY_I   : std_logic;

  signal instr_ADR_O  : std_logic_vector(31 downto 0);
  signal instr_DAT_O  : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal instr_CYC_O  : std_logic;
  signal instr_STB_O  : std_logic;
  signal instr_CTI_O  : std_logic_vector(2 downto 0);
  signal instr_BTE_O  : std_logic_vector(1 downto 0);
  signal instr_LOCK_O : std_logic;

  signal instr_STALL_I : std_logic;
  signal instr_DAT_I   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal instr_ACK_I   : std_logic;
  signal instr_ERR_I   : std_logic;
  signal instr_RTY_I   : std_logic;

  signal led_adr_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal led_dat_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal led_dat_o   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal led_stb_i   : std_logic;
  signal led_cyc_i   : std_logic;
  signal led_we_i    : std_logic;
  signal led_sel_i   : std_logic_vector(3 downto 0);
  signal led_cti_i   : std_logic_vector(2 downto 0);
  signal led_bte_i   : std_logic_vector(1 downto 0);
  signal led_ack_o   : std_logic;
  signal led_stall_o : std_logic;
  signal led_lock_i  : std_logic;
  signal led_err_o   : std_logic;
  signal led_rty_o   : std_logic;

  signal gpio_adr_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal gpio_dat_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal gpio_dat_o   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal gpio_stb_i   : std_logic;
  signal gpio_cyc_i   : std_logic;
  signal gpio_we_i    : std_logic;
  signal gpio_sel_i   : std_logic_vector(3 downto 0);
  signal gpio_cti_i   : std_logic_vector(2 downto 0);
  signal gpio_bte_i   : std_logic_vector(1 downto 0);
  signal gpio_ack_o   : std_logic;
  signal gpio_stall_o : std_logic;
  signal gpio_lock_i  : std_logic;
  signal gpio_err_o   : std_logic;
  signal gpio_rty_o   : std_logic;

  signal data_uart_adr_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_uart_dat_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_uart_dat_o   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_uart_stb_i   : std_logic;
  signal data_uart_cyc_i   : std_logic;
  signal data_uart_we_i    : std_logic;
  signal data_uart_sel_i   : std_logic_vector(3 downto 0);
  signal data_uart_cti_i   : std_logic_vector(2 downto 0);
  signal data_uart_bte_i   : std_logic_vector(1 downto 0);
  signal data_uart_ack_o   : std_logic;
  signal data_uart_stall_o : std_logic;
  signal data_uart_lock_i  : std_logic;
  signal data_uart_err_o   : std_logic;
  signal data_uart_rty_o   : std_logic;

  signal data_ram_adr_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_ram_dat_i   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_ram_dat_o   : std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_ram_stb_i   : std_logic;
  signal data_ram_cyc_i   : std_logic;
  signal data_ram_we_i    : std_logic;
  signal data_ram_sel_i   : std_logic_vector(3 downto 0);
  signal data_ram_cti_i   : std_logic_vector(2 downto 0);
  signal data_ram_bte_i   : std_logic_vector(1 downto 0);
  signal data_ram_ack_o   : std_logic;
  signal data_ram_lock_i  : std_logic;
  signal data_ram_stall_o : std_logic;
  signal data_ram_err_o   : std_logic;
  signal data_ram_rty_o   : std_logic;

  signal led_pio_out      : std_logic_vector(LED_COUNTER_LENGTH-1 downto 0);
  
  signal gpio_pio_in      : std_logic_vector(GPIO_LENGTH-1 downto 0);
  signal gpio_pio_oe      : std_logic_vector(GPIO_LENGTH-1 downto 0);
  signal gpio_pio_out     : std_logic_vector(GPIO_LENGTH-1 downto 0);

  type data_port_choice_t is (RAM_CHOICE, LED_CHOICE, UART_CHOICE);
  signal data_port_choice : data_port_choice_t;

  constant DEBUG_ENABLE  : boolean := false;
  signal debug_en        : std_logic;
  signal debug_write     : std_logic;
  signal debug_writedata : std_logic_vector(7 downto 0);
  signal debug_address   : std_logic_vector(7 downto 0);

  signal serial_in  : std_logic;
  signal rxrdy_n    : std_logic;
  signal cts_n      : std_logic;
  signal serial_out : std_logic;
  signal txrdy_n    : std_logic;
  signal rts_n      : std_logic;
  signal dir_n      : std_logic;

  signal uart_adr_i     : std_logic_vector(7 downto 0);
  signal uart_dat_i     : std_logic_vector(15 downto 0);
  signal uart_dat_o     : std_logic_vector(15 downto 0);
  signal uart_data_32   : std_logic_vector(31 downto 0);
  signal uart_stb_i     : std_logic;
  signal uart_cyc_i     : std_logic;
  signal uart_we_i      : std_logic;
  signal uart_sel_i     : std_logic_vector(3 downto 0);
  signal uart_cti_i     : std_logic_vector(2 downto 0);
  signal uart_bte_i     : std_logic_vector(1 downto 0);
  signal uart_ack_o     : std_logic;
  signal uart_interrupt : std_logic;
  signal uart_debug_ack : std_logic;

  constant UART_ADDR_DAT         : std_logic_vector(7 downto 0) := "00000000";
  constant UART_ADDR_LSR         : std_logic_vector(7 downto 0) := "00000011";
  constant UART_LSR_8BIT_DEFAULT : std_logic_vector(7 downto 0) := "00000011";
  signal uart_stall              : std_logic;
  signal mem_instr_stall         : std_logic;
  signal mem_instr_ack           : std_logic;

  signal rgb_led     : std_logic_vector(2 downto 0);
  signal red_led     : std_logic;
  signal green_led   : std_logic;
  signal blue_led    : std_logic;
  signal coe_to_host : std_logic_vector(31 downto 0);
  signal hp_pwm      : std_logic;

  constant SYSCLK_FREQ_HZ         : natural                                     := 12000000;
  constant HEARTBEAT_COUNTER_BITS : positive                                    := log2(SYSCLK_FREQ_HZ);  -- ~1 second to roll over
  signal heartbeat_counter        : unsigned(HEARTBEAT_COUNTER_BITS-1 downto 0) := (others => '0');


  signal auto_reset_count : unsigned(3 downto 0) := (others => '0');
  signal auto_reset       : std_logic;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      if auto_reset_count /= "1111" then
        auto_reset_count <= auto_reset_count +1;
        auto_reset       <= '1';
      else
        auto_reset <= '0';
      end if;
    end if;
  end process;
  reset <= not reset_btn or auto_reset;

  COMBINED_RAM_GEN : if not SEPERATE_MEMS generate
    signal RAM_ADR_I  : std_logic_vector(31 downto 0);
    signal RAM_DAT_I  : std_logic_vector(REGISTER_SIZE-1 downto 0);
    signal RAM_WE_I   : std_logic;
    signal RAM_CYC_I  : std_logic;
    signal RAM_STB_I  : std_logic;
    signal RAM_SEL_I  : std_logic_vector(REGISTER_SIZE/8-1 downto 0);
    signal RAM_CTI_I  : std_logic_vector(2 downto 0);
    signal RAM_BTE_I  : std_logic_vector(1 downto 0);
    signal RAM_LOCK_I : std_logic;

    signal RAM_STALL_O : std_logic;
    signal RAM_DAT_O   : std_logic_vector(REGISTER_SIZE-1 downto 0);
    signal RAM_ACK_O   : std_logic;
    signal RAM_ERR_O   : std_logic;
    signal RAM_RTY_O   : std_logic;
  begin
    mem : component wb_ram
      generic map(
        MEM_SIZE         => RAM_SIZE,
        DATA_WIDTH       => REGISTER_SIZE,
        INIT_FILE_FORMAT => "hex",
        INIT_FILE_NAME   => "test.mem",
        LATTICE_FAMILY   => "iCE5LP")
      port map(
        CLK_I => clk,
        RST_I => reset,

        ADR_I  => RAM_ADR_I,
        DAT_I  => RAM_DAT_I,
        WE_I   => RAM_WE_I,
        CYC_I  => RAM_CYC_I,
        STB_I  => RAM_STB_I,
        SEL_I  => RAM_SEL_I,
        CTI_I  => RAM_CTI_I,
        BTE_I  => RAM_BTE_I,
        LOCK_I => RAM_LOCK_I,

        STALL_O => RAM_STALL_O,
        DAT_O   => RAM_DAT_O,
        ACK_O   => RAM_ACK_O,
        ERR_O   => RAM_ERR_O,
        RTY_O   => RAM_RTY_O);

    arbiter : component wb_arbiter
      port map (
        CLK_I => clk,
        RST_I => reset,

        slave0_ADR_I  => data_ram_ADR_I,
        slave0_DAT_I  => data_ram_DAT_I,
        slave0_WE_I   => data_ram_WE_I,
        slave0_CYC_I  => data_ram_CYC_I,
        slave0_STB_I  => data_ram_STB_I,
        slave0_SEL_I  => data_ram_SEL_I,

        slave0_STALL_O => data_ram_STALL_O,
        slave0_DAT_O   => data_ram_DAT_O,
        slave0_ACK_O   => data_ram_ack_O,

        slave1_ADR_I  => data_ram_ADR_I,
        slave1_DAT_I  => data_ram_DAT_I,
        slave1_WE_I   => data_ram_WE_I,
        slave1_CYC_I  => data_ram_CYC_I,
        slave1_STB_I  => data_ram_STB_I,
        slave1_SEL_I  => data_ram_SEL_I,

        slave1_STALL_O => data_ram_STALL_O,
        slave1_DAT_O   => data_ram_DAT_O,
        slave1_ACK_O   => data_ram_ack_O,

        slave2_ADR_I  => instr_ADR_O,
        slave2_DAT_I  => instr_DAT_O,
        slave2_WE_I   => '0',
        slave2_CYC_I  => instr_CYC_O,
        slave2_STB_I  => instr_STB_O,
        slave2_SEL_I  => (others => '1'),

        slave2_STALL_O => mem_instr_stall,
        slave2_DAT_O   => instr_DAT_I,
        slave2_ACK_O   => mem_instr_ACK,

        master_ADR_O  => RAM_ADR_I,
        master_DAT_O  => RAM_DAT_I,
        master_WE_O   => RAM_WE_I,
        master_CYC_O  => RAM_CYC_I,
        master_STB_O  => RAM_STB_I,
        master_SEL_O  => RAM_SEL_I,

        master_STALL_I => RAM_STALL_O,
        master_DAT_I   => RAM_DAT_O,
        master_ACK_I   => RAM_ACK_O);

  end generate;

  SEPERATE_MEM_GEN : if SEPERATE_MEMS generate
  imem : entity work.wb_ram(bram)
      generic map(
        MEM_SIZE         => INST_RAM_SIZE,
        DATA_WIDTH       => REGISTER_SIZE,
        INIT_FILE_FORMAT => "hex",
        INIT_FILE_NAME   => "imem.mem",
        LATTICE_FAMILY   => "iCE5LP")
      port map(
        CLK_I => clk,
        RST_I => reset,

        ADR_I   => instr_ADR_O(log2(INST_RAM_SIZE)-1 downto 0),
        DAT_I   => (others => '0'),
        WE_I    => '0',
        CYC_I   => instr_CYC_O,
        STB_I   => instr_STB_O,
        SEL_I   => (others => '0'),
        CTI_I   => instr_CTI_O,
        BTE_I   => instr_BTE_O,
        LOCK_I  => instr_LOCK_O,
        STALL_O => mem_instr_stall,
        DAT_O   => instr_DAT_I,
        ACK_O   => mem_instr_ACK,
        ERR_O   => instr_ERR_I,
        RTY_O   => instr_RTY_I);

  dmem : entity work.wb_ram(bram)
      generic map(
        MEM_SIZE         => DATA_RAM_SIZE,
        DATA_WIDTH       => REGISTER_SIZE, 
        INIT_FILE_FORMAT => "hex",
        INIT_FILE_NAME   => "dmem.mem",
        LATTICE_FAMILY   => "iCE5LP")
      port map(
        CLK_I => clk,
        RST_I => reset,

        ADR_I   => data_ram_ADR_I(log2(INST_RAM_SIZE)-1 downto 0),
        DAT_I   => data_ram_DAT_I,
        WE_I    => data_ram_WE_I,
        CYC_I   => data_ram_CYC_I,
        STB_I   => data_ram_STB_I,
        SEL_I   => data_ram_SEL_I,
        CTI_I   => data_ram_CTI_I,
        BTE_I   => data_ram_BTE_I,
        LOCK_I  => data_ram_LOCK_I,
        STALL_O => data_ram_STALL_O,
        DAT_O   => data_ram_DAT_O,
        ACK_O   => data_ram_ack_O,
        ERR_O   => data_ram_ERR_O,
        RTY_O   => data_ram_RTY_O);

  end generate SEPERATE_MEM_GEN;

  rv : component orca
    generic map (
      REGISTER_SIZE         => REGISTER_SIZE,
			BYTE_SIZE							=> 8,
      AVALON_ENABLE         => 0,
      WISHBONE_ENABLE       => 1,
      AXI_ENABLE            => 0,
      RESET_VECTOR          => 16#00000200#,
      MULTIPLY_ENABLE       => 0,
      DIVIDE_ENABLE         => 0,
      SHIFTER_MAX_CYCLES    => 1,
      COUNTER_LENGTH        => 32,
      ENABLE_EXCEPTIONS     => 1,
      BRANCH_PREDICTORS     => 0,
      PIPELINE_STAGES       => 4,
      LVE_ENABLE            => 0,
      ENABLE_EXT_INTERRUPTS => 0,
      NUM_EXT_INTERRUPTS    => 1,
      SCRATCHPAD_ADDR_BITS  => 10,
			BURST_EN							=> 0,
			POWER_OPTIMIZED				=> 0,
			CACHE_ENABLE 					=> 0,
      FAMILY                => "LATTICE")
    port map(
      clk            => clk,
      scratchpad_clk => scratchpad_clk,
      reset          => reset,

			avm_data_address							=> OPEN,
			avm_data_byteenable						=> OPEN,
			avm_data_read									=> OPEN, 
			avm_data_readdata							=> (others => '-'), 
			avm_data_write								=> OPEN, 
			avm_data_writedata						=> OPEN, 
			avm_data_waitrequest					=> '-',
			avm_data_readdatavalid				=> '-',

			avm_instruction_address       => OPEN,
			avm_instruction_read          => OPEN,
			avm_instruction_readdata     	=> (others => '-'),
			avm_instruction_waitrequest  	=> '-',
			avm_instruction_readdatavalid	=> '-',

      data_ADR_O										=> data_ADR_O,
      data_DAT_I   	 								=> data_DAT_I,
      data_DAT_O   	 								=> data_DAT_O,
      data_WE_O    	 								=> data_WE_O,
      data_SEL_O   	 								=> data_SEL_O,
      data_STB_O   	 								=> data_STB_O,
      data_ACK_I   	 								=> data_ACK_I,
      data_CYC_O   	 								=> data_CYC_O,
      data_STALL_I 	 								=> data_STALL_I,
      data_CTI_O   	 								=> data_CTI_O,

      instr_ADR_O    								=> instr_ADR_O,
      instr_DAT_I    								=> instr_DAT_I,
      instr_STB_O    								=> instr_STB_O,
      instr_ACK_I    								=> instr_ACK_I,
      instr_CYC_O    								=> instr_CYC_O,
      instr_CTI_O    								=> instr_CTI_O,
      instr_STALL_I  								=> instr_STALL_I,
			
      data_ARID			 								=> OPEN,     
      data_ARADDR    								=> OPEN,  
      data_ARLEN     								=> OPEN,   
      data_ARSIZE    								=> OPEN,  
      data_ARBURST   								=> OPEN, 
      data_ARLOCK    								=> OPEN, 
      data_ARCACHE   								=> OPEN, 
      data_ARPROT    								=> OPEN,  
      data_ARVALID   								=> OPEN, 
      data_ARREADY   								=> '-', 
                     								       
      data_RID       								=> (others => '-'),
      data_RDATA     								=> (others => '-'),
      data_RRESP     								=> (others => '-'),
      data_RLAST     								=> '-',
      data_RVALID    								=> '-',
      data_RREADY    								=> OPEN,
                     								           
      data_AWID      								=> OPEN,
      data_AWADDR    								=> OPEN,
      data_AWLEN     								=> OPEN,
      data_AWSIZE    								=> OPEN,
      data_AWBURST   								=> OPEN,
      data_AWLOCK    								=> OPEN,
      data_AWCACHE   								=> OPEN,
      data_AWPROT    								=> OPEN,
      data_AWVALID   								=> OPEN,
      data_AWREADY   								=> '-',
                     								        
      data_WID       								=> OPEN,
      data_WDATA     								=> OPEN,
      data_WSTRB     								=> OPEN, 
      data_WLAST     								=> OPEN,
      data_WVALID    								=> OPEN,
      data_WREADY    								=> '-',
                     								           
      data_BID       								=> (others => '-'),
      data_BRESP     								=> (others => '-'),
      data_BVALID    								=> '-',
      data_BREADY    								=> OPEN,

      itcram_ARID		 								=> OPEN,     
      itcram_ARADDR  								=> OPEN,  
      itcram_ARLEN   								=> OPEN,   
      itcram_ARSIZE  								=> OPEN,  
      itcram_ARBURST 								=> OPEN, 
      itcram_ARLOCK  								=> OPEN, 
      itcram_ARCACHE 								=> OPEN, 
      itcram_ARPROT  								=> OPEN,  
      itcram_ARVALID 								=> OPEN, 
      itcram_ARREADY 								=> '-', 
                     								     
      itcram_RID     								=> (others => '-'),
      itcram_RDATA   								=> (others => '-'),
      itcram_RRESP   								=> (others => '-'),
      itcram_RLAST   								=> '-',
      itcram_RVALID  								=> '-',
      itcram_RREADY  								=> OPEN,
                     								         
      itcram_AWID    								=> OPEN,
      itcram_AWADDR  								=> OPEN,
      itcram_AWLEN   								=> OPEN,
      itcram_AWSIZE  								=> OPEN,
      itcram_AWBURST 								=> OPEN,
      itcram_AWLOCK  								=> OPEN,
      itcram_AWCACHE 								=> OPEN,
      itcram_AWPROT  								=> OPEN,
      itcram_AWVALID 								=> OPEN,
      itcram_AWREADY 								=> '-',
                     								      
      itcram_WID     								=> OPEN,
      itcram_WDATA   								=> OPEN,
      itcram_WSTRB   								=> OPEN, 
      itcram_WLAST   								=> OPEN,
      itcram_WVALID  								=> OPEN,
      itcram_WREADY  								=> '-',
                     								         
      itcram_BID     								=> (others => '-'),
      itcram_BRESP   								=> (others => '-'),
      itcram_BVALID  								=> '-',
      itcram_BREADY  								=> OPEN,

      iram_ARID			 								=> OPEN,     
      iram_ARADDR    								=> OPEN,  
      iram_ARLEN     								=> OPEN,   
      iram_ARSIZE    								=> OPEN,  
      iram_ARBURST   								=> OPEN, 
      iram_ARLOCK    								=> OPEN, 
      iram_ARCACHE   								=> OPEN, 
      iram_ARPROT    								=> OPEN,  
      iram_ARVALID   								=> OPEN, 
      iram_ARREADY   								=> '-', 
                     								       
      iram_RID       								=> (others => '-'),
      iram_RDATA     								=> (others => '-'),
      iram_RRESP     								=> (others => '-'),
      iram_RLAST     								=> '-',
      iram_RVALID    								=> '-',
      iram_RREADY    								=> OPEN,
                     								           
      iram_AWID      								=> OPEN,
      iram_AWADDR    								=> OPEN,
      iram_AWLEN     								=> OPEN,
      iram_AWSIZE    								=> OPEN,
      iram_AWBURST   								=> OPEN,
      iram_AWLOCK    								=> OPEN,
      iram_AWCACHE   								=> OPEN,
      iram_AWPROT    								=> OPEN,
      iram_AWVALID   								=> OPEN,
      iram_AWREADY   								=> '-',
                     								        
      iram_WID       								=> OPEN,
      iram_WDATA     								=> OPEN,
      iram_WSTRB     								=> OPEN, 
      iram_WLAST     								=> OPEN,
      iram_WVALID    								=> OPEN,
      iram_WREADY    								=> '-',
                     								           
      iram_BID       								=> (others => '-'),
      iram_BRESP     								=> (others => '-'),
      iram_BVALID    								=> '-',
      iram_BREADY    								=> OPEN,

      avm_scratch_address           => (others => '-'), 
      avm_scratch_byteenable        => (others => '-'), 
      avm_scratch_read              => '-', 
      avm_scratch_readdata          => OPEN, 
      avm_scratch_write             => '-', 
      avm_scratch_writedata         => (others => '-'), 
      avm_scratch_waitrequest       => OPEN, 
      avm_scratch_readdatavalid     => OPEN, 
                                  
      sp_ADR_I                      => (others => '-'),
      sp_DAT_O                      => OPEN, 
      sp_DAT_I                      => (others => '-'), 
      sp_WE_I                       => '-', 
      sp_SEL_I                      => (others => '-'), 
      sp_STB_I                      => '-', 
      sp_ACK_O                      => OPEN, 
      sp_CYC_I                      => '-', 
      sp_CTI_I                      => (others => '-'),
      sp_STALL_O                    => OPEN, 

			global_interrupts							=> (others => '-')
		);

  data_BTE_O   <= "00";
  data_LOCK_O  <= '0';
  instr_BTE_O  <= "00";
  instr_LOCK_O <= '0';

  split_wb_data : component wb_splitter
    generic map(
      SUB_ADDRESS_BITS => 16,
      NUM_MASTERS      => 4,
      JUST_OR_ACKS     => FALSE
    )
    port map(
      clk_i => clk,
      rst_i => reset,

      slave_ADR_I     => data_ADR_O,
      slave_DAT_I     => data_DAT_O,
      slave_WE_I      => data_WE_O,
      slave_CYC_I     => data_CYC_O,
      slave_STB_I     => data_STB_O,
      slave_SEL_I     => data_SEL_O,
      slave_CTI_I     => data_CTI_O,
      slave_BTE_I     => data_BTE_O,
      slave_LOCK_I    => data_LOCK_O,
      slave_STALL_O   => data_STALL_I,
      slave_DAT_O     => data_DAT_I,
      slave_ACK_O     => data_ACK_I,
      slave_ERR_O     => data_ERR_I,
      slave_RTY_O     => data_RTY_I,

      master0_ADR_O   => data_ram_ADR_I,
      master0_DAT_O   => data_ram_DAT_I,
      master0_WE_O    => data_ram_WE_I,
      master0_CYC_O   => data_ram_CYC_I,
      master0_STB_O   => data_ram_STB_I,
      master0_SEL_O   => data_ram_SEL_I,
      master0_CTI_O   => data_ram_CTI_I,
      master0_BTE_O   => data_ram_BTE_I,
      master0_LOCK_O  => data_ram_LOCK_I,
      master0_STALL_I => data_ram_STALL_O,
      master0_DAT_I   => data_ram_DAT_O,
      master0_ACK_I   => data_ram_ACK_O,
      master0_ERR_I   => data_ram_ERR_O,
      master0_RTY_I   => data_ram_RTY_O,

      master1_ADR_O   => led_ADR_I,
      master1_DAT_O   => led_DAT_I,
      master1_WE_O    => led_WE_I,
      master1_CYC_O   => led_CYC_I,
      master1_STB_O   => led_STB_I,
      master1_SEL_O   => led_SEL_I,
      master1_CTI_O   => led_CTI_I,
      master1_BTE_O   => led_BTE_I,
      master1_LOCK_O  => led_LOCK_I,
      master1_STALL_I => led_STALL_O,
      master1_DAT_I   => led_DAT_O,
      master1_ACK_I   => led_ACK_O,
      master1_ERR_I   => led_ERR_O,
      master1_RTY_I   => led_RTY_O,

      master2_ADR_O   => data_uart_ADR_I,
      master2_DAT_O   => data_uart_DAT_I,
      master2_WE_O    => data_uart_WE_I,
      master2_CYC_O   => data_uart_CYC_I,
      master2_STB_O   => data_uart_STB_I,
      master2_SEL_O   => data_uart_SEL_I,
      master2_CTI_O   => data_uart_CTI_I,
      master2_BTE_O   => data_uart_BTE_I,
      master2_LOCK_O  => data_uart_LOCK_I,
      master2_STALL_I => data_uart_STALL_O,
      master2_DAT_I   => data_uart_DAT_O,
      master2_ACK_I   => data_uart_ACK_O,
      master2_ERR_I   => data_uart_ERR_O,
      master2_RTY_I   => data_uart_RTY_O,

      master3_ADR_O   => gpio_ADR_I,
      master3_DAT_O   => gpio_DAT_I,
      master3_WE_O    => gpio_WE_I,
      master3_CYC_O   => gpio_CYC_I,
      master3_STB_O   => gpio_STB_I,
      master3_SEL_O   => gpio_SEL_I,
      master3_CTI_O   => gpio_CTI_I,
      master3_BTE_O   => gpio_BTE_I,
      master3_LOCK_O  => gpio_LOCK_I,
      master3_STALL_I => gpio_STALL_O,
      master3_DAT_I   => gpio_DAT_O,
      master3_ACK_I   => gpio_ACK_O,
      master3_ERR_I   => gpio_ERR_O,
      master3_RTY_I   => gpio_RTY_O
    );

  instr_stall_i <= uart_stall or mem_instr_stall;
  instr_ack_i   <= not uart_stall and mem_instr_ack;

  led_pio : component wb_pio
    generic map (
      DATA_WIDTH => LED_COUNTER_LENGTH)
    port map(
      CLK_I => clk,
      RST_I => reset,

      ADR_I        => led_ADR_I,
      DAT_I        => led_DAT_I(LED_COUNTER_LENGTH-1 downto 0),
      WE_I         => led_WE_I,
      CYC_I        => led_CYC_I,
      STB_I        => led_STB_I,
      SEL_I        => led_SEL_I,
      CTI_I        => led_CTI_I,
      BTE_I        => led_BTE_I,
      LOCK_I       => led_LOCK_I,
      ACK_O        => led_ACK_O,
      STALL_O      => led_STALL_O,
      DATA_O       => led_DAT_O(LED_COUNTER_LENGTH-1 downto 0),
      ERR_O        => led_ERR_O,
      RTY_O        => led_RTY_O,
      
      input        => (others => '0'),  
      output_en    => OPEN,
      output       => led_pio_out
    );

  gpio_pio : component wb_pio
    generic map (
      DATA_WIDTH => GPIO_LENGTH)
    port map(
      CLK_I => clk,
      RST_I => reset,

      ADR_I        => gpio_ADR_I,
      DAT_I        => gpio_DAT_I(gpio'range),
      WE_I         => gpio_WE_I,
      CYC_I        => gpio_CYC_I,
      STB_I        => gpio_STB_I,
      SEL_I        => gpio_SEL_I,
      CTI_I        => gpio_CTI_I,
      BTE_I        => gpio_BTE_I,
      LOCK_I       => gpio_LOCK_I,
      ACK_O        => gpio_ACK_O,
      STALL_O      => gpio_STALL_O,
      DATA_O       => gpio_DAT_O(gpio'range),
      ERR_O        => gpio_ERR_O,
      RTY_O        => gpio_RTY_O,
      
      input        => gpio_pio_in,
      output_en    => gpio_pio_oe, 
      output       => gpio_pio_out
    );      

-----------------------------------------------------------------------------
-- Debugging logic (PC over UART)
-- This is useful if we can't figure out why
-- the program isn't running.
-----------------------------------------------------------------------------
  debug_gen : if DEBUG_ENABLE generate
    signal last_valid_address : std_logic_vector(31 downto 0);
    signal last_valid_data    : std_logic_vector(31 downto 0);
    type debug_state_type is (INIT, IDLE, SPACE, ADR, DAT, CR, LF);
    signal debug_state        : debug_state_type;
    signal debug_count        : unsigned(log2((last_valid_data'length+3)/4)-1 downto 0);
    signal debug_wait         : std_logic;

    --Convert a hex digit to ASCII for outputting on the UART
    function to_ascii_hex (
      signal hex_in : std_logic_vector)
      return std_logic_vector is
    begin
      if unsigned(hex_in) > to_unsigned(9, hex_in'length) then
        --value + 'A' - 10
        return std_logic_vector(resize(unsigned(hex_in), 8) + to_unsigned(55, 8));
      end if;

      --value + '0'
      return std_logic_vector(resize(unsigned(hex_in), 8) + to_unsigned(48, 8));
    end to_ascii_hex;


  begin
    process (clk)
    begin  -- process
      if clk'event and clk = '1' then   -- rising clock edge
        case debug_state is
          when INIT =>
            debug_address   <= UART_ADDR_LSR;
            debug_writedata <= UART_LSR_8BIT_DEFAULT;
            debug_write     <= '1';
            if debug_write = '1' and debug_wait = '0' then
              debug_state   <= IDLE;
              debug_address <= UART_ADDR_DAT;
              debug_write   <= '0';
            end if;
          when IDLE =>
            uart_stall <= '1';
            if instr_CYC_O = '1' then
              debug_write        <= '1';
              last_valid_address <= instr_ADR_O(instr_ADR_O'left-4 downto 0) & "0000";
              debug_writedata    <= to_ascii_hex(instr_ADR_O(last_valid_address'left downto last_valid_address'left-3));
              debug_state        <= ADR;
              debug_count        <= to_unsigned(0, debug_count'length);
            end if;
          when ADR =>
            if debug_wait = '0' then
              if debug_count = to_unsigned(((last_valid_address'length+3)/4)-1, debug_count'length) then
                debug_writedata <= std_logic_vector(to_unsigned(32, 8));
                debug_count     <= to_unsigned(0, debug_count'length);
                debug_state     <= SPACE;
                last_valid_data <= instr_DAT_I;
              else
                debug_writedata    <= to_ascii_hex(last_valid_address(last_valid_address'left downto last_valid_address'left-3));
                last_valid_address <= last_valid_address(last_valid_address'left-4 downto 0) & "0000";
                debug_count        <= debug_count + to_unsigned(1, debug_count'length);
              end if;
            end if;
          when SPACE =>
            if debug_wait = '0' then
              debug_writedata <= to_ascii_hex(last_valid_data(last_valid_data'left downto last_valid_data'left-3));
              last_valid_data <= last_valid_data(last_valid_data'left-4 downto 0) & "0000";
              debug_state     <= DAT;
            end if;
          when DAT =>
            if debug_wait = '0' then
              if debug_count = to_unsigned(((last_valid_data'length+3)/4)-1, debug_count'length) then
                debug_writedata <= std_logic_vector(to_unsigned(13, 8));
                debug_count     <= to_unsigned(0, debug_count'length);
                debug_state     <= CR;
              else
                debug_writedata <= to_ascii_hex(last_valid_data(last_valid_data'left downto last_valid_data'left-3));
                last_valid_data <= last_valid_data(last_valid_data'left-4 downto 0) & "0000";
                debug_count     <= debug_count + to_unsigned(1, debug_count'length);
              end if;
            end if;

          when CR =>
            if debug_wait = '0' then
              debug_writedata <= std_logic_vector(to_unsigned(10, 8));
              debug_state     <= LF;
            end if;
          when LF =>
            if debug_wait = '0' then
              debug_write <= '0';
              debug_state <= IDLE;
              uart_stall  <= '0';
            end if;

          when others =>
            debug_state <= IDLE;
        end case;

        if reset = '1' then
          debug_state <= INIT;
          debug_write <= '0';
          uart_stall  <= '1';
        end if;
      end if;
    end process;
    debug_wait <= not uart_ack_o;
  end generate debug_gen;
  no_debug_gen : if not DEBUG_ENABLE generate
    debug_write     <= '0';
    debug_writedata <= (others => '0');
    debug_address   <= (others => '0');
    uart_stall      <= '0';
  end generate no_debug_gen;

  -----------------------------------------------------------------------------
  -- UART signals and interface
  -----------------------------------------------------------------------------
  cts_n     <= cts;
  txd       <= serial_out;
  serial_in <= rxd;
  rts       <= rts_n;

  the_uart : uart_core
    generic map (
      CLK_IN_MHZ => (SYSCLK_FREQ_HZ+500000)/1000000,
      BAUD_RATE  => 115200,
      ADDRWIDTH  => 3,
      DATAWIDTH  => 8,
      MODEM_B    => false,              --true by default...
      FIFO       => false
      )
    port map (
                                        -- Global reset and clock
      CLK        => clk,
      RESET      => reset,
                                        -- WISHBONE interface
      UART_ADR_I => uart_adr_i,
      UART_DAT_I => uart_dat_i,
      UART_DAT_O => uart_dat_o,
      UART_STB_I => uart_stb_i,
      UART_CYC_I => uart_cyc_i,
      UART_WE_I  => uart_we_i,
      UART_SEL_I => uart_sel_i,
      UART_CTI_I => uart_cti_i,
      UART_BTE_I => uart_bte_i,
      UART_ACK_O => uart_ack_o,
      INTR       => uart_interrupt,
                                        -- Receiver interface
      SIN        => serial_in,
      RXRDY_N    => rxrdy_n,
                                        -- MODEM
      DCD_N      => '1',
      CTS_N      => cts_n,
      DSR_N      => '1',
      RI_N       => '1',
      DTR_N      => dir_n,
      RTS_N      => rts_n,
                                        -- Transmitter interface
      SOUT       => serial_out,
      TXRDY_N    => txrdy_n
      );

  uart_pc : if DEBUG_ENABLE generate
  begin
    uart_dat_i(15 downto 8) <= (others => '0');
    uart_dat_i(7 downto 0)  <= debug_writedata;
    uart_we_i               <= debug_write;

    uart_stb_i <= uart_we_i and (not txrdy_n);
    uart_adr_i <= debug_address;
    uart_cyc_i <= uart_stb_i and (not txrdy_n);

    uart_cti_i <= WB_CTI_CLASSIC;

                                        --constant ack to the riscv port
    data_uart_ack_o   <= '1';
    data_uart_stall_o <= not data_uart_ack_O;
  end generate uart_pc;
  uart_data_bus : if not DEBUG_ENABLE generate
  begin
    uart_adr_i        <= data_uart_adr_i(9 downto 2);
    uart_dat_i        <= data_uart_dat_i(15 downto 0);
    data_uart_dat_o   <= x"0000" & uart_dat_o(15 downto 0);
    uart_stb_i        <= data_uart_stb_i;
    uart_cyc_i        <= data_uart_cyc_i;
    uart_we_i         <= data_uart_we_i;
    uart_sel_i        <= data_uart_sel_i;
    uart_cti_i        <= data_uart_cti_i;
    uart_bte_i        <= data_uart_bte_i;
    data_uart_ack_o   <= uart_ack_o;
    data_uart_stall_o <= not data_uart_ack_O;
  end generate uart_data_bus;

-------------------------------------------------------------------------------
-- LED and HEARTBEAT
-------------------------------------------------------------------------------

  rgb_led <=
    "111" when reset = '1' and heartbeat_counter(6 downto 0) = "0000001" else
    red_led & green_led & blue_led;

  red_led   <= '1' when unsigned(led_pio_out(23 downto 16)) > heartbeat_counter(7 downto 0) else '0';
  green_led <= '1' when unsigned(led_pio_out(15 downto 8)) > heartbeat_counter(7 downto 0)  else '0';
  blue_led  <= '1' when unsigned(led_pio_out(7 downto 0)) > heartbeat_counter(7 downto 0)   else '0';

  led : component my_led
    port map(
      red_i   => rgb_led(2),
      green_i => rgb_led(1),
      blue_i  => rgb_led(0),
      hp_i    => hp_pwm,
      red     => R_LED,
      green   => G_LED,
      blue    => B_LED,
      hp      => HP_LED
      );

  hp_pwm <= heartbeat_counter(heartbeat_counter'left) when heartbeat_counter(7 downto 0) = "00000001" else '0';

  process(clk)
  begin
    if rising_edge(clk) then
      heartbeat_counter <= heartbeat_counter + to_unsigned(1, heartbeat_counter'length);
    end if;
  end process;

-------------------------------------------------------------------------------
-- GPIO 
-------------------------------------------------------------------------------
  gpio_tristate : 
  for i in 0 to GPIO_LENGTH-1 generate
    gpio(i) <= gpio_pio_out(i) when gpio_pio_oe(i) = '1' else 'Z'; 
    gpio_pio_in(i) <= gpio(i);
  end generate gpio_tristate;

end architecture rtl;
