
# FUTURE Features & Improvements

After completing the MVP in PLAN.md, here are the recommended next steps:

## 1. Syscall and Interrupt Support
- Implement handlers for common syscalls (`write`, `exit`, etc.) in Linux x86-64.
- Intercept `syscall`/`int 0x80` in Unicorn via interrupt hooks.
- Simulate simple I/O (stdout, stdin) inside the TUI.

## 2. Macro and Include Support
- Extend assembler pipeline to process macros (e.g., `%define`, `%macro` in NASM style).
- Implement an include path system for splitting code across files.

## 3. INT3 Breakpoints
- Switch to software breakpoints by injecting `0xCC` at target addresses.
- Restore original byte after breakpoint hit and single-step back to normal execution.

## 4. Watchpoints
- Use Unicorn memory hooks to stop execution when a watched address/range is read or written.

## 5. Snapshot and Reverse Execution
- Save Unicorn CPU/memory state periodically for rewind/forward debugging.

## 6. Symbol Table and Debug Info
- Support symbolic labels in the UI for registers, memory addresses, and disassembly view.
- Load symbol information from external `.sym` or `.map` files.

## 7. Multiple Architecture Modes
- Allow toggling between 16-bit, 32-bit, and 64-bit modes.
- Adjust assembler, disassembler, and emulator configurations accordingly.

## 8. DAP (Debug Adapter Protocol) Support
- Implement DAP server to let external editors and IDEs attach to the emulator.

## 9. Scripting API
- Expose Lua or Python bindings for automated tests, batch execution, or custom commands.

## 10. Enhanced Syntax Highlighting
- Expand tree-sitter queries for registers, labels, constants, and macros.
- Add semantic highlighting based on instruction semantics.

## 11. Performance Profiling
- Measure and display instruction execution counts and timing for profiling.

## 12. Testing Framework
- Add unit tests for assembler pipeline, emulator control, and UI components.
- Include integration tests with sample assembly programs.

---

These features will gradually transform the MVP into a fully featured interactive x86 assembly IDE/debugger in the terminal.
