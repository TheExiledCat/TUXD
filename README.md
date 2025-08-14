# 🐧 TUXD — Terminal Unix eXecution Debugger

**TUXD** is a TUI-based, Vim-style x86 assembly editor and live debugger for Linux.  
It lets you **edit, run, and debug assembly code in real time** — right from your terminal.  

---

## ✨ Features
- **Vim-style editing** for smooth, modal text navigation
- **x86 assembler + disassembler** via [Keystone](https://www.keystone-engine.org/) and [iced-x86](https://github.com/icedland/iced)
- **Live CPU emulation** powered by [Unicorn Engine](https://www.unicorn-engine.org/)
- **Breakpoints, step-through execution, and register view**
- **Syntax highlighting** with [tree-sitter-x86asm](https://github.com/bearcove/tree-sitter-x86asm)
- **Cross-platform Debian/Ubuntu compatibility** (dev setup script included)

---

## 📦 Installation

### Option 1 — Install via Cargo
```bash
cargo install tuxd
```
This will fetch the latest release from crates.io and compile it locally.

### Option 2 — Download Prebuilt Binary
1. Go to the [Releases](https://github.com/yourname/tuxd/releases) page.
2. Download the binary for your system (e.g., `tuxd` for Linux x86_64).
3. Make it executable:
```bash
chmod +x tuxd
```
4. Run it:
```bash
./tuxd
```

### Option 3 — Build from Source
#### Install dependencies (Debian/Ubuntu)
```bash
sudo apt update
sudo apt install -y build-essential pkg-config git curl
```
> If you don't have system Unicorn/Keystone libs, TUXD will build them from source automatically.

#### Clone and build
```bash
git clone https://github.com/yourname/tuxd.git
cd tuxd
cargo build --release
```

#### Run
```bash
./target/release/tuxd
```

---

## 🚀 Usage
TUXD opens into **Normal Mode** by default (like Vim).  
Press `i` to enter **Insert Mode** and start editing.  

Basic commands:
| Key | Action |
|-----|--------|
| `i` | Enter insert mode |
| `Esc` | Return to normal mode |
| `:q` | Quit |
| `:w` | Save |
| `F5` | Run program |
| `F10` | Step over |
| `F11` | Step into |
| `b <addr>` | Toggle breakpoint |

---

## 🔧 Development Setup
For reproducible environments:
```bash
./setup-debian.sh
```
This will:
- Install build tools
- Compile Unicorn & Keystone from source if not found
- Verify Rust toolchain is installed

---

## 📜 License
MIT License. See [LICENSE](LICENSE) for details.

---

## 🐧 Name
**TUXD** = **T**erminal **U**NIX e**X**ecution **D**ebugger.  
A nod to [Tux](https://en.wikipedia.org/wiki/Tux_(mascot)), the Linux penguin.

---

## 💡 Roadmap
- Syscall simulation
- Macro support
- Multi-architecture support (ARM, RISC-V)
- Configurable themes & keymaps
