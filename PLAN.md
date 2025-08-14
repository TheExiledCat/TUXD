# TUXD - TERMINAL UNIX XECUTION DEBUGGER

---

## REQUIREMENTS

ratatui for the TUI

crossterm for terminal I/O

iced‑x86 for disassembly/formatting/metadata (and programmatic assembling via code_asm)

Keystone to assemble text Intel syntax into machine code

Unicorn to emulate and debug code (breakpoints, stepping, hooks)

(Optional) tree‑sitter‑x86asm for syntax highlighting

(Optional) ropey for a rope‑backed text buffer

> ⚠️ Important gotcha: iced‑x86 does not parse free‑form assembly text into bytes. Use Keystone to turn text → bytes. Use iced‑x86 to disassemble bytes, format nicely, and get instruction metadata.

---

0) ## Target & Non‑Goals

Target (MVP):

Open/edit a .asm buffer with Vim‑style modes.

Assemble the buffer to bytes (x86‑64).

Load into Unicorn, set RIP/stack, run/step.

Breakpoints (toggle per line), register view, memory view, instruction trace.

Pause on breakpoint, show current instruction highlight.

Non‑Goals (MVP):

Full OS/syscall emulation. (We’ll intercept basic interrupts and can stub a few syscalls later.)

Full macro/segment support of NASM/MASM. Keep to a simple subset first.

---

1) ## Prerequisites

Rust toolchain (stable).

Native libs for Unicorn & Keystone.

macOS: brew install unicorn keystone

Ubuntu/Debian: sudo apt install libunicorn-dev libkeystone-dev

Arch: sudo pacman -S unicorn keystone

Windows: use vcpkg or prebuilt binaries; ensure they’re discoverable by pkg-config / environment (see Unicorn/Keystone docs).

> Tip: If pkg‑config can’t find the libs, set LIBRARY_PATH/PKG_CONFIG_PATH or vendor them via build scripts.

---

2) ## Project Scaffold

### TUI & terminal

ratatui = "0.28"        # or latest
crossterm = "0.27"

### Text buffer

ropey = "1"             # optional but recommended

### Emulation

unicorn-engine = "2"     # Rust bindings for Unicorn 2.x

### Assembly

iced-x86 = { version = "1", features = ["decoder", "encoder", "nasm", "masm", "intel", "code_asm"] }
keystone-engine = "0.1"  # Rust bindings to Keystone

### Utilities

bitflags = "2"
parking_lot = "0.12"
serde = { version = "1", features = ["derive"] }
serde_json = "1"

### Optional highlighting via tree-sitter

tree-sitter = "0.20"

 tree-sitter-highlight = "0.20"

 tree-sitter-x86asm = { git = "https://github.com/bearcove/tree-sitter-x86asm" }

### Project layout suggestion:

- src/
  
  - main.rs
  
  - app.rs                # TUI app state + ratatui layout
  
  - buffer.rs             # rope-backed buffer + line/addr mapping
  
  - assemble.rs           # text -> bytes (Keystone) + map lines -> instruction spans
  
  - disasm.rs             # bytes -> iced-x86 Instruction (+ formatting)
  
  - emulate.rs            # Unicorn wrapper: map memory, regs, hooks, run/step
  
  - breakpoints.rs        # breakpoint set, patching (int3) or hook-based
  
  - keymap.rs             # Helix-like modal keymaps
  
  - ui/
    
    - editor.rs           # text view, cursor, selections
    
    - registers.rs        # registers panel
    
    - memory.rs           # memory inspector
    
    - trace.rs            # instruction trace panel

---

3) ## Licenses & Borrowing from Helix

Helix is MPL‑2.0. You can copy code files and modify them, but files you modify/derive must remain under MPL, and you must retain notices. Keep Helix‑derived code in a separate module with headers intact.

Instead of copying large chunks, consider replicating behavior (keymaps/state machine) using your own code + Helix docs as reference.

---

4) ## Editor Core (modal, Helix‑style)

Start simple: Normal and Insert modes; later add Visual. Use ropey for the buffer.

keymap.rs (sketch):

pub enum Mode { Normal, Insert }

pub struct KeyBindings { /* maps of (Mode, KeyEvent) -> Action */ }

pub enum Action {
    MoveLeft, MoveRight, MoveUp, MoveDown,
    StartInsert, StopInsert,
    Save, AssembleAndRun,
    Step, StepOver, Continue,
    ToggleBreakpoint,
}

State machine: current Mode, cursor pos (line,col), selections, and a command palette later.

---

5) ## TUI Layout (ratatui)

Three main areas:

Left: Editor (source), with breakpoint gutter and current‑IP highlight.

Right (top): Registers.

Right (mid): Instruction trace (disasm around RIP).

Right (bottom): Memory inspector (follow pointers / stack).

Bottom status bar: Mode, messages, errors, assemble status.

app.rs (layout sketch):

```rust
use ratatui::{prelude::*, widgets::*};

pub struct App { /* buffers, disasm cache, emulator state, breakpoints, etc. */ }

impl App {
 pub fn ui(&mut self, f: &mut Frame) {
 let chunks = Layout::default()
 .direction(Direction::Vertical)
 .constraints([
 Constraint::Min(1), // main row
 Constraint::Length(1), // status bar
 ]).split(f.size());
    let main = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(65), // editor
            Constraint::Percentage(35), // side panels
        ]).split(chunks[0]);

    // editor
    // draw_editor(self, f, main[0]);

    let side = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(9),   // registers
            Constraint::Min(6),      // trace
            Constraint::Length(9),   // memory
        ]).split(main[1]);

    // draw_registers(self, f, side[0]);
    // draw_trace(self, f, side[1]);
    // draw_memory(self, f, side[2]);

    // status
    // draw_status(self, f, chunks[1]);
}
```

---

6) ## Assembling Intel Syntax (Keystone)

Goal: Convert .asm text → bytes for Unicorn.

Choose x86‑64 initially.

Treat the buffer line‑by‑line; strip comments; allow labels.

Keystone returns encoded bytes; we also compute line → [start,end) byte range to map breakpoints to addresses.

assemble.rs (sketch):

```rust
use anyhow::*;
use keystone_engine::{Keystone, Arch, Mode, OptionType, OptionValue};

pub struct AssemblyBytes {
 pub base: u64,
 pub bytes: Vec<u8>,
 pub line_spans: Vec<(usize /*line*/, u64 /*addr*/, usize /*len*/)>,
}

pub fn assemble_text(base: u64, text: &str) -> Result<AssemblyBytes> {
 let ks = Keystone::new(Arch::X86, Mode::MODE_64)?;
 ks.option(OptionType::SYNTAX, OptionValue::SYNTAX_INTEL)?;

// For a first pass, assemble the entire buffer; later we can do per-line and link labels.
let (bytes, _count) = ks.asm(text, base)?;

// Derive line -> addr mapping by disassembling the result (iced-x86) to get per‑insn sizes.
let mut spans = Vec::new();
let mut addr = base;
for (line_idx, insn) in crate::disasm::disassemble(&bytes, base).into_iter().enumerate() {
    let len = insn.len();
    spans.push((line_idx, addr, len));
    addr += len as u64;
}

Ok(AssemblyBytes { base, bytes, line_spans: spans })
}
```



> Later, support labels by keeping a symbol table (first pass) and re‑assembling with resolved addresses; Keystone already supports labels if you pass the whole blob.

---

7) ## Disassembly & Instruction Metadata (iced‑x86)

Use iced‑x86 to:

Show a disasm window around RIP.

Compute read/write registers/memory per instruction for UI hints.

Pretty‑print in Intel or NASM/MASM syntax.

disasm.rs (sketch):

```rust
use iced_x86::{Decoder, DecoderOptions, Instruction, IntelFormatter};

pub fn disassemble(code: &[u8], base: u64) -> Vec<Instruction> {
 let mut decoder = Decoder::with_ip(64, code, base, DecoderOptions::NONE);
 let mut v = Vec::new();
 while decoder.can_decode() {
 let mut insn = Instruction::default();
 decoder.decode_out(&mut insn);
 v.push(insn);
 }
 v
}

pub fn format(insn: &Instruction) -> String {
 let mut f = IntelFormatter::new();
 let mut output = String::new();
 f.format(insn, &mut output);
 output
}

```

---

8) ## Unicorn Emulation Wrapper

Responsibilities:

Map memory (code + stack + scratch heap).

Write bytes, set registers (RIP/RSP, etc.).

Hooks: instruction trace (UC_HOOK_CODE), memory (read/write), interrupts (e.g., int 3), and breakpoints.

Control: step, run_until_break, continue, stop.

Breakpoint strategies:

1. Hook‑based: On each instruction hook, if rip is in the breakpoint set → emu_stop() and return. (Simpler, no code patching.)

2. INT3 patching (software bp): overwrite first byte at target addr with 0xCC, catch UC_HOOK_INTR (INT3), then restore and single‑step. (More accurate to “real” debuggers.)

Start with hook‑based.

emulate.rs (sketch):

```rust
use anyhow::*;
use unicorn_engine::{Unicorn, RegisterX86};
use unicorn_engine::unicorn_const::{Arch, Mode, Permission, HookType};
use std::collections::BTreeSet;

pub struct Emulator {
 pub uc: Unicorn<'static, ()>,
 pub base: u64,
 pub stack_top: u64,
 pub breakpoints: BTreeSet<u64>,
}

impl Emulator {
 pub fn new(base: u64) -> Result<Self> {
 let uc = Unicorn::new(Arch::X86, Mode::MODE_64)?;
 let stack_size: u64 = 0x10000;
 let stack_base: u64 = 0x2000_0000;
 let stack_top = stack_base + stack_size - 8;

    uc.mem_map(base, 0x10000, Permission::ALL)?;         // code page(s)
    uc.mem_map(stack_base, stack_size, Permission::ALL)?; // stack

    Ok(Self { uc, base, stack_top, breakpoints: BTreeSet::new() })
}

pub fn load_and_reset(&mut self, bytes: &[u8]) -> Result<()> {
    self.uc.mem_write(self.base, bytes)?;
    self.uc.reg_write(RegisterX86::RIP, self.base)?;
    self.uc.reg_write(RegisterX86::RSP, self.stack_top)?;
    Ok(())
}

pub fn add_hooks<FTrace>(&mut self, mut on_insn: FTrace) -> Result<()>
where FTrace: FnMut(u64) + 'static {
    // Instruction hook for tracing & breakpoints
    let bp = self.breakpoints.clone();
    self.uc.add_code_hook( HookType::CODE, 1, 0, move |_uc, addr, _size| {
        on_insn(addr);
        if bp.contains(&addr) {
            _uc.emu_stop().ok();
        }
    })?;
    Ok(())
}

pub fn step(&mut self) -> Result<()> {
    let rip: u64 = self.uc.reg_read(RegisterX86::RIP)?;
    self.uc.emu_start(rip, 0, 0, 1)?; // count = 1 instruction
    Ok(())
}

pub fn run(&mut self, end: u64) -> Result<()> {
    let rip: u64 = self.uc.reg_read(RegisterX86::RIP)?;
    self.uc.emu_start(rip, end, 0, 0)?; // run until end (or hook stops)
    Ok(())
}

}
```



> For syscall/interrupt handling: add add_intr_hook and intercept int 0x80 / syscall. For MVP, avoid OS calls in sample code.

---

9) ## Line ↔ Address Mapping & Breakpoints

After assembling, you have line_spans: Vec<(line, addr, len)>.

To toggle a breakpoint on a line, map to its addr and insert/remove from Emulator.breakpoints.

On render, draw a gutter (e.g., ●) for lines whose addr is in the set.

On instruction hook, highlight the current line by reverse‑lookup: find the span whose addr == rip.

> If a line contains multiple instructions, split spans per instruction for accuracy. Consider caching Vec<(addr,len,line)> and binary‑search by rip.

---

10) ## Wiring the Loop (crossterm + ratatui)

Use crossterm’s raw mode & event reader (poll with timeout) to process keys.

On AssembleAndRun:

1. Assemble text via assemble_text() (base e.g. 0x1000_0000).

2. emulator.load_and_reset(bytes).

3. Start in paused state at first instruction.

On Step/Continue: call the emulator accordingly and refresh the UI.

Main loop sketch (main.rs):

```rust
fn main() -> anyhow::Result<()> {
 // init terminal + app state
 // load sample buffer
 // create Emulator::new(BASE)
 // event loop: handle key events -> actions -> mutate state -> draw
 Ok(())
}
```



---

11) ## Syntax Highlighting (optional, tree‑sitter)

Add tree-sitter-x86asm grammar, create a Highlighter with queries for Intel syntax.

Run incremental parse on buffer edits; produce per‑span styles for ratatui.

For MVP, skip this and use a simple regex highlighter (mnemonics, registers, numbers, comments).

---

12) ## Sample Program to Test

Keep it OS‑free. Example (demo.asm, Intel, x86‑64):

; RAX final should be 7
    mov rax, 5
    add rax, 2
    nop
    nop
    ; place a breakpoint on the add line

Assemble, run; RAX should be 7 after add.

Add more: memory store/load to show memory panel.

---

13) ## Registers & Memory Panels

Registers panel (read/write via Unicorn): periodically or on step, read:

64‑bit: RIP, RSP, RBP, RAX..R15, RFLAGS.

Format hex + changed‑since‑last‑render with a highlight.

Memory panel:

Start by showing [RSP-64, RSP+64].

Add follow mode: press f on a pointer value to jump the memory view to that address.

---

14) ## Instruction Trace Panel

Maintain a ring buffer of the last N executed instructions ((addr, bytes[..], formatted)), filled by the instruction hook.

Display with iced‑x86’s IntelFormatter for consistent style.

---

15) ## Breakpoint UX

Normal mode: b toggles breakpoint at cursor line.

F5 Continue, F10 Step over, F11 Step into (for calls).

Step‑over: if current insn is call, set a temporary breakpoint at the next RIP, then run().

---

16) ## Error Surfaces & Safety

Wrap emulator calls with anyhow::Context for clear messages (bad memory map, invalid instruction, etc.).

Add run budget (instruction count/time) to avoid infinite loops; on budget exceeded, auto‑stop and notify.

---

17) ## Borrowing from Helix (practical tips)

Keymaps: reproduce modal bindings similar to Helix (Normal: h j k l, i, :w, /, etc.).

Selections: Helix’s multiple selections are advanced; start with single cursor, add multi‑cursor later.

Rope: Helix uses ropes; ropey integrates well for large files.

MPL compliance: if you copy a file, keep its license header and add NOTICE in your repo.

---

18) ## Build & Run (quick path)
1. Ensure Unicorn & Keystone libraries are installed (see §1).

2. cargo run

3. Open the app; paste demo.asm.

4. Press :w to save (optional), Ctrl‑R (or your bound key) to Assemble & Reset, F10 to step.

Troubleshooting:

Linker errors for Unicorn/Keystone → adjust PKG_CONFIG_PATH / install dev packages.

Invalid instruction at runtime → inspect generated bytes with disasm view.

---

19) ## Extending Beyond MVP

INT3 breakpoints (software patching) for parity with real debuggers.

Symbolic labels and a lightweight assembler pass to support local labels, constants.

Syscall shims: intercept syscall/int 0x80 and emulate a handful (write, exit) to run tiny programs that print.

Watchpoints: memory read/write hooks that stop on specific ranges.

Snapshots: save/restore Unicorn context to rewind.

Configurable modes: 16/32‑bit support for old code.

Project support: multiple files, include paths.

---

20) ## Minimal Code Skeleton (compilable starting point)

> This is a compact scaffold to get you from zero to a blank UI + assemble + load + single‑step. You’ll still need to flesh out rendering and key handling.

```rust
// src/main.rs
use anyhow::*;

fn main() -> Result<()> {
 // init terminal (crossterm + ratatui), create App, event loop
 Ok(())
}

// src/assemble.rs
use anyhow::*;
use keystone_engine::{Keystone, Arch, Mode, OptionType, OptionValue};
use iced_x86::{Decoder, DecoderOptions, Instruction};

pub struct AsmOut { pub base: u64, pub bytes: Vec<u8>, pub spans: Vec<(usize,u64,usize)> }

pub fn assemble(base: u64, text: &str) -> Result<AsmOut> {
 let ks = Keystone::new(Arch::X86, Mode::MODE_64)?;
 ks.option(OptionType::SYNTAX, OptionValue::SYNTAX_INTEL)?;
 let (bytes, _) = ks.asm(text, base)?;
 // derive spans by decoding bytes back with iced-x86
 let mut spans = Vec::new();
 let mut dec = Decoder::with_ip(64, &bytes, base, DecoderOptions::NONE);
 let mut line = 0usize; // naive: 1 insn per line to start
 while dec.can_decode() {
 let ip = dec.ip();
 let instr: Instruction = dec.decode();
 spans.push((line, ip, instr.len()));
 line += 1;
 }
 Ok(AsmOut { base, bytes, spans })
}

// src/emulate.rs
use anyhow::*;
use unicorn_engine::{Unicorn, RegisterX86};
use unicorn_engine::unicorn_const::{Arch, Mode, Permission};

pub struct Emu { pub uc: Unicorn<'static, ()>, pub base: u64, pub stack_top: u64 }

impl Emu {
 pub fn new(base: u64) -> Result<Self> {
 let uc = Unicorn::new(Arch::X86, Mode::MODE_64)?;
 let stack_base = 0x2000_0000u64; let stack_sz = 0x10000u64;
 uc.mem_map(base, 0x10000, Permission::ALL)?;
 uc.mem_map(stack_base, stack_sz, Permission::ALL)?;
 Ok(Self { uc, base, stack_top: stack_base + stack_sz - 8 })
 }
 pub fn load(&mut self, bytes: &[u8]) -> Result<()> {
 self.uc.mem_write(self.base, bytes)?;
 self.uc.reg_write(RegisterX86::RIP, self.base)?;
 self.uc.reg_write(RegisterX86::RSP, self.stack_top)?;
 Ok(())
 }
 pub fn step(&mut self) -> Result<()> {
 let rip: u64 = self.uc.reg_read(RegisterX86::RIP)?;
 self.uc.emu_start(rip, 0, 0, 1)?;
 Ok(())
 }
}
```



---

21) ## Development Workflow

Start with the backend (assemble → emulate → step) and print logs to the terminal.

Once stable, wire in ratatui rendering.

Add keymaps last so you can drive the app while debugging.

---

22) ## Pitfalls & Tips

Instruction sizes vary; always compute next RIP using iced‑x86 if you manually need it.

Alignment: when mapping code pages, align base/size to page (e.g., 0x1000). Unicorn largely tolerates non‑aligned but better to align.

Windows paths: ensure ucrt/vcruntime are present if linking via MSVC; prefer x86_64-pc-windows-gnu with mingw for simpler C libs.

Performance: cache disassembly windows; don’t re‑decode whole buffers on every keypress.

Safety: sandbox—emulated code can still run forever; enforce instruction/time budgets.

---

23) ## What’s Next

Scriptable breakpoints/conditions.

DAP (Debug Adapter Protocol) to interop with external frontends.

Unit tests for assembler pipeline and address mapping.

---

Quick Checklist

[ ] TUI skeleton renders

[ ] Buffer edits & save

[ ] Assemble buffer with Keystone

[ ] Load bytes into Unicorn

[ ] Step & Continue work

[ ] Disasm/trace panel shows current RIP

[ ] Register & memory panels update

[ ] Breakpoint toggle/stop works

[ ] Basic error handling and run budget


