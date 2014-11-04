library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.defines.all;
use work.test_utils.all;

entity tb_register_file is
end tb_register_file;

architecture behavior of tb_register_file is 

  constant reg_addr_bits: integer := 4;
  constant num_registers: integer := 16;
  constant clk_period: time := 10 ns;
    
  -- General registers
  signal clk: std_logic;
  signal read_register_1_in: std_logic_vector(reg_addr_bits -1 downto 0);
  signal read_register_2_in: std_logic_vector(reg_addr_bits -1 downto 0);
  signal write_register_in: std_logic_vector(reg_addr_bits -1 downto 0);
  signal write_data_in: word_t;
  signal register_write_enable_in: std_logic;
  signal read_data_1_out: word_t;
  signal read_data_2_out: word_t;
  
  -- ID register
  signal id_register_write_enable_in: std_logic;
  signal id_register_in: thread_id_t;
  signal lsu_address_out: memory_address_t;
  
  -- Return Registers
  signal lsu_data_inout: word_t;
  signal return_register_write_enable_in: std_logic;
  
  -- Masking
  signal predicate_out: std_logic;

  
  -- Constant storage
  signal constant_value_in: word_t;
  signal constant_write_enable_in: std_logic;
  function get_reg_addr(reg: integer) return std_logic_vector is
    begin
      return std_logic_vector(to_unsigned(reg, reg_addr_bits));
   end;
   
  function make_word(word: integer) return std_logic_vector is
   begin
    return std_logic_vector(to_unsigned(word, WORD_WIDTH));
  end;
 begin

-- component instantiation
        register_file: entity work.register_file
        generic map(
              DEPTH => num_registers,
              LOG_DEPTH => reg_addr_bits
        )
        port map(
              clk => clk,
              read_register_1_in => read_register_1_in,
              read_register_2_in => read_register_2_in,
              write_register_in => write_register_in,
              write_data_in => write_data_in,
              register_write_enable_in => register_write_enable_in,
              read_data_1_out => read_data_1_out,
              read_data_2_out => read_data_2_out,
              id_register_write_enable_in => id_register_write_enable_in,
              id_register_in => id_register_in,
              return_register_write_enable_in => return_register_write_enable_in,
              lsu_data_inout => lsu_data_inout,
              lsu_address_out => lsu_address_out,
              constant_value_in => constant_value_in,
              predicate_out => predicate_out,
              constant_write_enable_in => constant_write_enable_in
        );

  clk_process :process
  begin
  clk <= '0';
  wait for clk_period/2;
  clk <= '1';
  wait for clk_period/2;
  end process;


--  test bench statements
  tb : process
    constant ALL_BITS_HIGH: memory_address_t := (others => '1');

    
   procedure assert_generic(reg: integer; value:integer; signal in_signal: register_address_t; signal out_signal: word_t ; message:string) is
    begin
      read_register_1_in <= get_reg_addr(reg);
      register_write_enable_in <= '1';
      read_register_2_in <= get_reg_addr(reg);
      write_register_in <= get_reg_addr(reg);
      write_data_in <= make_word(value);
      wait for clk_period;
      assert_equals(make_word(value), out_signal, message);
      assert_equals(make_word(value), out_signal, message);
    end assert_generic;
   
    procedure assert_generic(reg: integer; value:integer; signal in_signal: register_address_t; signal out_signal: word_t ) is
     begin
      assert_generic(reg, value, in_signal, out_signal, "Should be able to read/write general purpose register.");
    end assert_generic;
    
    procedure assert_lsu_address_registers is
      constant max_int: std_logic_vector(WORD_WIDTH-1 downto 0):= (others => '1');
     begin
      -- Address high/low can be treated as general purpose registers.
      -- Only difference is that their out should also be in lsu_data.
      -- Register $3 address high
      -- Test general purpose first
      assert_generic(to_integer(unsigned(max_int)), 3, read_register_1_in, read_data_1_out, " $3(Address high) Should be treated as a general purpose register."); 
      assert_generic(to_integer(unsigned(max_int)), 4, read_register_1_in, read_data_1_out, " $3(Address high) Should be treated as a general purpose register."); 
      
      -- Test special feature
      --assert_equals(ALL_BITS_HIGH, lsu_address_out, "LSU address should consist of Address low and high bits from address high."); 
    end assert_lsu_address_registers;
    
    procedure assert_zero_reg is
     begin
      read_register_1_in <= get_reg_addr(0);
      read_register_2_in <= get_reg_addr(0);
      wait for clk_period;
      assert_equals(make_word(0), read_data_1_out, "Register $0 should be zero.");
      assert_equals(make_word(0), read_data_2_out, "Register $0 should be zero.");
      write_register_in <= get_reg_addr(0);
      write_data_in <= make_word(1);
      wait for clk_period;
      assert_equals(make_word(0), read_data_1_out, "Register $0 should be write only.");
      assert_equals(make_word(0), read_data_2_out, "Register $0 should be write only.");
     end assert_zero_reg;
     
    procedure assert_id_registers is
     begin
      id_register_write_enable_in <= '1';
      id_register_in <= "1111111111111111111"; 
      read_register_1_in <= get_reg_addr(1);
      read_register_2_in <= get_reg_addr(2);
      wait for clk_period;
      assert_equals(make_word(7), read_data_1_out, "ID value should be split into high and low registers.");
      assert_equals("1111111111111111", read_data_2_out, "ID value should be split into high and low registers.");
      write_register_in <= get_reg_addr(1);
      write_data_in <= make_word(4);
      register_write_enable_in <= '1';
      wait for clk_period;
      write_register_in <= get_reg_addr(2);
      wait for clk_period;
      assert_equals(make_word(7), read_data_1_out, "ID should be readonly.");
      assert_equals("1111111111111111", read_data_2_out, "ID should be readonly.");
     end assert_id_registers;
     
    procedure assert_lsu_data_register is
     begin
      --Return register($5) is also a general purpose register
      assert_generic(12, 5, read_register_1_in, read_data_1_out, "$5 should be treated as a general register.");
     
      --Test write from lsu
      register_write_enable_in <= '0';
      read_register_1_in <= get_reg_addr(5);
      return_register_write_enable_in <= '1';
      lsu_data_inout <= make_word(9);
      wait for clk_period;
      assert_equals(make_word(9), read_data_1_out, "LSU should be able to write result");
     end assert_lsu_data_register;
     
    procedure assert_general_purpose_registers is
     begin
       register_write_enable_in <= '1';
       --Test other general registers
       for i in 7 to num_registers -1 loop
        assert_generic(30 + i, i,  read_register_1_in, read_data_1_out);
      end loop;
    end procedure assert_general_purpose_registers;
    
    procedure assert_mask_register is
     begin
      --assert_generic(1, 6, read_register_1_in, resize(to_unsigned(predicate_out & "", 1), WORD_WIDTH), "Predicate should be writable.");
    end procedure assert_mask_register;
    begin

      -- Test special registers first
      assert_zero_reg;
 
      assert_id_registers;
        
      assert_lsu_address_registers;
    
      --assert_lsu_data_register;
      
     --Mask register
     
      --assert_mask_register;
   
      assert_general_purpose_registers;
      wait; -- will wait forever
   end process tb;
  --  end test bench 

end;
