library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.numeric_std.all;
use IEEE.STD_LOGIC_TEXTIO.all;
use STD.TEXTIO.all;

library work;
use work.utils.all;
use work.constants_pkg.all;

entity lve_ci is
  generic (
    REGISTER_SIZE : positive := 32
    );
  port (
    clk   : in std_logic;
    reset : in std_logic;

    func3 : in std_logic_vector(2 downto 0);

    valid_in : in std_logic;
    data1_in : in std_logic_vector(REGISTER_SIZE-1 downto 0);
    data2_in : in std_logic_vector(REGISTER_SIZE-1 downto 0);

    valid_out        : out std_logic;
    write_enable_out : out std_logic;
    data_out         : out std_logic_vector(REGISTER_SIZE-1 downto 0)
    );
end entity;

architecture rtl of lve_ci is
  constant PIPELINE_DEPTH : positive := 3;

  --For testing pipeline the result
  type data_out_shifter is array (natural range <>) of std_logic_vector(REGISTER_SIZE-1 downto 0);
  signal data_out_d : data_out_shifter(PIPELINE_DEPTH downto 0);

  --Delay the valid out to match data
  signal valid_out_d : std_logic_vector(PIPELINE_DEPTH downto 0);

  constant VCUSTOM0_FUNC3 : std_logic_vector(2 downto 0) := "101";
  constant VCUSTOM1_FUNC3 : std_logic_vector(2 downto 0) := "110";
  constant VCUSTOM2_FUNC3 : std_logic_vector(2 downto 0) := "111";
  constant VCUSTOM3_FUNC3 : std_logic_vector(2 downto 0) := "000";
  constant VCUSTOM4_FUNC3 : std_logic_vector(2 downto 0) := "001";
  constant VCUSTOM5_FUNC3 : std_logic_vector(2 downto 0) := "010";

  signal cust0_out_data : std_logic_vector(REGISTER_SIZE-1 downto 0);


begin

  cust0_out_data <= x"0000007F" when signed(data1_in) > 127 else
                    x"00000080" when signed(data1_in) < -128 else
                    x"000000" & data1_in(7 downto 0);

  valid_out_d(0) <= valid_in;
  data_out_d(0)  <= cust0_out_data when func3 = VCUSTOM0_FUNC3 else (others => '-');

  process (clk) is
  begin  -- process
    if clk'event and clk = '1' then     -- rising clock edge
      valid_out_d(valid_out_d'left downto 1) <= valid_out_d(valid_out_d'left-1 downto 0);
      data_out_d(data_out_d'left downto 1)   <= data_out_d(data_out_d'left-1 downto 0);
    end if;
  end process;

  valid_out        <= valid_out_d(PIPELINE_DEPTH);
  write_enable_out <= valid_out_d(PIPELINE_DEPTH);  --Always write back for now
  data_out         <= data_out_d(PIPELINE_DEPTH);
end architecture rtl;
