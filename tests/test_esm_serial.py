"""
Test ESM serial interface
Tests the embedded system module CLI via UART to verify register access
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer, ClockCycles, with_timeout
import tests.verilator as verilator
import os
from tests.conftest import root_dir

# UART parameters (from rs_core instantiation in alchitry_top.sv)
BAUD_RATE = 115200
CLK_FREQ = 128_000_000  # 128 MHz internal clock for rs_core
BIT_PERIOD_NS = int((1.0 / BAUD_RATE) * 1e9)  # ~8680 ns per bit


###################################################################################
## pytest entry point
###################################################################################
def test_esm_serial(no_compile, waves):
    """Execute ESM serial test"""
    recompile = not no_compile

    # Setup the run directory
    run_dir = verilator.setup_sim_dir(delete_existing=recompile)
    
    if waves:
        do = "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; log -r /*; run -a; quit"
    else:
        do = "set StdArithNoWarnings 1; set NumericStdNoWarnings 1; run -a; quit"

    verilator.run_rtl_sim_verilator(
        compile_txt_files_list=[
            os.path.join(root_dir, "tests/compile_esm_serial.txt")
        ],
        cocotb_toplevel="tb_esm_serial",
        rtl_run_path=run_dir,
        do_argument=do,
        compile_rtl=recompile
    )


##############################################################
# Cocotb UART helper functions
##############################################################

class UARTMonitor:
    """Continuously monitors UART RX line and buffers received data"""
    def __init__(self, uart_rx_signal, dut):
        self.uart_rx_signal = uart_rx_signal
        self.dut = dut
        self.buffer = []
        self.running = False
        self.task = None
    
    async def _monitor_loop(self):
        """Background task that continuously reads UART"""
        self.dut._log.info("UART monitor started")
        while self.running:
            byte_val = await uart_receive_byte(self.uart_rx_signal, self.dut, timeout_us=100)
            if byte_val is not None:
                self.buffer.append(byte_val)
                char_repr = chr(byte_val) if 32 <= byte_val < 127 else f"\\x{byte_val:02x}"
                self.dut._log.debug(f"UART Monitor buffered: 0x{byte_val:02x} '{char_repr}'")
    
    def start(self):
        """Start the monitor task"""
        self.running = True
        self.task = cocotb.start_soon(self._monitor_loop())
    
    def stop(self):
        """Stop the monitor task"""
        self.running = False
    
    def get_received(self, clear=True):
        """Get received data as string and optionally clear buffer"""
        data = self.buffer.copy()
        if clear:
            self.buffer.clear()
        try:
            return ''.join(chr(b) for b in data if b != 0)
        except (ValueError, UnicodeDecodeError):
            return ''.join(chr(b) for b in data if b < 128)
    
    def wait_for_pattern(self, pattern, timeout_us=100000):
        """Wait for a specific pattern in the buffer"""
        return self._wait_for_pattern_impl(pattern, timeout_us)
    
    async def _wait_for_pattern_impl(self, pattern, timeout_us):
        """Implementation of wait for pattern"""
        start_time = cocotb.utils.get_sim_time('us')
        while True:
            current_str = self.get_received(clear=False)
            if pattern in current_str:
                return current_str
            
            elapsed = cocotb.utils.get_sim_time('us') - start_time
            if elapsed > timeout_us:
                return None
            
            await Timer(100, units='us')

async def uart_send_byte(uart_tx_signal, byte_val):
    """
    Send a single byte over UART
    uart_tx_signal: the DUT input (our output) - normally high, inverted in UART
    """
    # Start bit (low)
    uart_tx_signal.value = 0
    await Timer(BIT_PERIOD_NS, unit='ns')
    
    # Data bits (LSB first)
    for i in range(8):
        bit = (byte_val >> i) & 1
        uart_tx_signal.value = bit
        await Timer(BIT_PERIOD_NS, unit='ns')
    
    # Stop bit (high)
    uart_tx_signal.value = 1
    await Timer(BIT_PERIOD_NS, unit='ns')
    
    # Debug: log sent byte
    import cocotb
    char_repr = chr(byte_val) if 32 <= byte_val < 127 else f"\\x{byte_val:02x}"
    cocotb.log.debug(f"UART TX: 0x{byte_val:02x} ({byte_val:3d}) '{char_repr}'")


async def uart_receive_byte(uart_rx_signal, dut, timeout_us=1000):
    """
    Receive a single byte from UART
    uart_rx_signal: the DUT output (our input) to monitor
    dut: DUT instance for logging
    Returns: received byte or None on timeout
    """
    timeout_ns = timeout_us * 1000
    start_time = cocotb.utils.get_sim_time('ns')
    
    # Wait for start bit (high to low transition)
    while uart_rx_signal.value == 1:
        await Timer(100, unit='ns')
        if (cocotb.utils.get_sim_time('ns') - start_time) > timeout_ns:
            return None
    
    # Log start bit detection with timestamp
    start_bit_time = cocotb.utils.get_sim_time('ns')
    dut._log.debug(f"[{start_bit_time:12.0f} ns] UART RX: Start bit detected")
    
    # Wait half a bit period to sample in the middle
    await Timer(BIT_PERIOD_NS // 2, unit='ns')
    
    # Verify start bit is still low
    if uart_rx_signal.value != 0:
        dut._log.warning("Start bit not low!")
        return None
    
    # Wait to middle of first data bit
    await Timer(BIT_PERIOD_NS, unit='ns')
    
    # Read 8 data bits (LSB first)
    byte_val = 0
    for i in range(8):
        bit = int(uart_rx_signal.value)
        bit_time = cocotb.utils.get_sim_time('ns')
        dut._log.debug(f"[{bit_time:12.0f} ns] UART RX: Bit {i} = {bit}")
        byte_val |= (bit << i)
        await Timer(BIT_PERIOD_NS, unit='ns')
    
    # Verify stop bit is high
    stop_bit_time = cocotb.utils.get_sim_time('ns')
    if uart_rx_signal.value != 1:
        dut._log.warning(f"Stop bit not high! Got: {uart_rx_signal.value}")
    else:
        dut._log.debug(f"[{stop_bit_time:12.0f} ns] UART RX: Stop bit = {uart_rx_signal.value}")
    
    # Debug: log received byte
    char_repr = chr(byte_val) if 32 <= byte_val < 127 else f"\\x{byte_val:02x}"
    dut._log.debug(f"UART RX: 0x{byte_val:02x} ({byte_val:3d}) '{char_repr}'")
    
    return byte_val


async def uart_send_string(uart_tx_signal, string):
    """Send a string over UART"""
    for char in string:
        await uart_send_byte(uart_tx_signal, ord(char))
        # Small delay between characters
        await Timer(BIT_PERIOD_NS, unit='ns')
        
    # longer delay after string for debug
    #await Timer(10*BIT_PERIOD_NS, unit='ns')
        

async def uart_receive_prompt(uart_rx_signal, dut, max_chars=100, timeout_us=100000):
    """
    Receive a string from UART until timeout or max_chars reached
    dut: DUT instance for logging
    stop when ">>" is detected (for CLI prompt)
    """
    received = []
    for _ in range(max_chars):
        byte_val = await uart_receive_byte(uart_rx_signal, dut, timeout_us=timeout_us)
        if byte_val is None:
            break
        received.append(byte_val)
        
        # Check for CLI prompt ending ">>"
        if len(received) >= 2:
            if received[-2] == ord('>') and received[-1] == ord('>'):
                dut._log.debug("Detected '>>' prompt, stopping receive")
                break
            
    # Convert bytes to string
    try:
        return ''.join(chr(b) for b in received if b != 0)
    except (ValueError, UnicodeDecodeError):
        return ''.join(chr(b) for b in received if b < 128)


async def uart_receive_string(uart_rx_signal, dut, max_chars=100, timeout_us=100000):
    """
    Receive a string from UART until timeout or max_chars reached
    dut: DUT instance for logging
    """
    received = []
    for _ in range(max_chars):
        byte_val = await uart_receive_byte(uart_rx_signal, dut, timeout_us=timeout_us)
        if byte_val is None:
            break
        received.append(byte_val)
                
        # Check for common terminators
        if byte_val == ord('\n') or byte_val == 0:
            break
    
    # Convert bytes to string
    try:
        return ''.join(chr(b) for b in received if b != 0)
    except (ValueError, UnicodeDecodeError):
        return ''.join(chr(b) for b in received if b < 128)


##############################################################
# Cocotb test
##############################################################

async def simulation_heartbeat(dut):
    """Background task to log simulation progress at adaptive intervals"""
    start_time = cocotb.utils.get_sim_time('us')
    
    while True:
        current_time = cocotb.utils.get_sim_time('us')
        elapsed = current_time - start_time
        
        # Determine interval based on elapsed time
        if elapsed < 100:  # 0-100 us: every 10 us
            interval = 10
        elif elapsed < 1000:  # 100 us - 1 ms: every 100 us
            interval = 100
        elif elapsed < 10000:  # 1 ms - 10 ms: every 1 ms
            interval = 1000
        elif elapsed < 100000:  # 10 ms - 100 ms: every 10 ms
            interval = 10000
        elif elapsed < 1000000:  # 100 ms - 1 s: every 100 ms
            interval = 100000
        else:  # > 1 s: every 1 s
            interval = 1000000
        
        # Log progress
        if elapsed < 1000:
            dut._log.info(f"Sim time: {elapsed:.1f} us")
        elif elapsed < 1000000:
            dut._log.info(f"Sim time: {elapsed/1000:.2f} ms")
        else:
            dut._log.info(f"Sim time: {elapsed/1000000:.3f} s")
        
        await Timer(interval, unit='us')

@cocotb.test()
async def test_esm_version_read(dut):
    """
    Test ESM serial interface by reading version register
    
    Expected sequence:
    1. Wait for ">>" prompt from ESM
    2. Send "r 00000000\r" command
    3. Receive response "addr: 00000000 = 00000048" (version 0.0.0.72)
    """
    # Enable debug logging
    # or run with
    # COCOTB_LOG_LEVEL=DEBUG pytest tests/test_esm_serial.py --waves --log-cli-level=DEBUG
    import logging
    dut._log.setLevel(logging.DEBUG)
    cocotb.log.setLevel(logging.DEBUG)
    
    dut._log.info("="*80)
    dut._log.info("Starting ESM Serial Test")
    dut._log.info("="*80)
    
    # Start heartbeat logging in background
    cocotb.start_soon(simulation_heartbeat(dut))
    
    # Debug: print current working directory
    import os
    dut._log.info(f"Current working directory: {os.getcwd()}")
    
    # Wait for reset to complete (with timeout)
    #await Timer(1, unit='ns')
    try:
        await with_timeout(RisingEdge(dut.rst_n), 10, 'us')
        dut._log.info("Reset released")
    except Exception as e:
        dut._log.error(f"Timeout waiting for reset release: {e}")
        raise

    # Wait a bit for initial blocks to execute
    #await Timer(10, unit='ns')
    
    # Log ROM loading info
    try:
        # Check if we can access the ROM contents
        rom_val_0 = int(dut.alchitry_top.rs_core_0.progrom[0].value)
        rom_val_1 = int(dut.alchitry_top.rs_core_0.progrom[1].value)
        rom_val_2 = int(dut.alchitry_top.rs_core_0.progrom[2].value)
        dut._log.info(f"[rs_core] ROM loaded - progrom[0] = 0x{rom_val_0:05x}")
        dut._log.info(f"[rs_core] ROM loaded - progrom[1] = 0x{rom_val_1:05x}")
        dut._log.info(f"[rs_core] ROM loaded - progrom[2] = 0x{rom_val_2:05x}")
    except (AttributeError, IndexError, TypeError) as e:
        dut._log.warning(f"Could not read ROM contents: {e}")
    
    # Get UART signals from testbench (not DUT BOT pins)
    # uart_rx is a reg in testbench (we drive it) -> connects to BOT_B4 -> DUT input
    # uart_tx is a wire in testbench (DUT drives it) -> connects from BOT_B6 -> DUT output
    uart_tx = dut.uart_rx  # We transmit by driving testbench's uart_rx input
    uart_rx = dut.uart_tx  # We receive by reading testbench's uart_tx output
    
    # Initialize UART TX to idle (high)
    uart_tx.value = 1
    
    # Start UART monitor to continuously read RX
    monitor = UARTMonitor(uart_rx, dut)
    monitor.start()
    
    # Wait for system to initialize
    await Timer(110, unit='ns')
    
    # Wait for initial prompt ">>" from ESM
    dut._log.info("Waiting for initial '>>' prompt...")
    prompt = await monitor._wait_for_pattern_impl(">>", timeout_us=500000)
    if prompt:
        dut._log.info(f"Received prompt: '{prompt}'")
    else:
        dut._log.error("Timeout waiting for initial prompt")
        monitor.stop()
        raise AssertionError("No initial prompt received")
    
    # Clear buffer after getting prompt
    monitor.get_received(clear=True)
    
    # Send "r 00000000" command followed by carriage return
    command = "r 00000000\r"
    dut._log.info(f"Sending command: '{command}'")
    await uart_send_string(uart_tx, command)
    
    # Wait for response (will echo command and return result)
    dut._log.info("Waiting for response...")
    response = await monitor._wait_for_pattern_impl(">>", timeout_us=500000)
    if response:
        dut._log.info(f"Received response: '{response}'")
    else:
        dut._log.error("Timeout waiting for response")
        all_received = monitor.get_received(clear=False)
        dut._log.error(f"Partial response: '{all_received}'")
        monitor.stop()
        raise AssertionError("No response received")
    
    # Check for expected version
    # Version is 0.0.0.72 = 0x00000048
    expected_version = "0000004a"
    
    # Parse response - looking for "addr: 00000000 = 00000048"
    if "addr:" in response and expected_version in response:
        dut._log.info(f"✓ SUCCESS: Version register read correctly!")
        dut._log.info(f"  Expected version: 0.0.0.72 (0x{expected_version})")
        dut._log.info(f"  Response: {response}")
    else:
        dut._log.error(f"✗ FAILED: Version mismatch or parse error")
        dut._log.error(f"  Expected: addr: 00000000 = {expected_version}")
        dut._log.error(f"  Got: {response}")
        monitor.stop()
        assert False, f"Version register read failed. Expected {expected_version} in response."
    
    # Stop the monitor
    monitor.stop()
    
    # Wait a bit more to capture any trailing data
    await Timer(100, unit='us')
    
    dut._log.info("="*80)
    dut._log.info("ESM Serial Test Complete")
    dut._log.info("ESM Serial Test Complete")
    dut._log.info("="*80)
