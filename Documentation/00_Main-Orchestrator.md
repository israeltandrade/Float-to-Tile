# 📘 **Main Orchestrator: `00_main.sh`**

The `00_main.sh` script is the **heart of the Float-to-Tile system**.  
Its responsibility is to ensure a **robust and centralized execution** of all modules.

---

## ✨ **Mission of the Orchestrator (Fault Tolerant)**

| # | Functionality | Key Detail |
|---|----------------|------------|
| 1 | **Sequential Management** | Executes all data collection modules (`NN_*.sh`) in order. |
| 2 | **Centralized Logging** | Ensures centralized and readable logs in the `00_main.log` file. |
| 3 | **Fault Tolerance** | **NEW:** It does **NOT** stop on failure. It records the failure (`ORCHESTRATION_FAILED`), continues to the next module, and signals global failure only at the end. |

---

## 💾 **Code Breakdown (by Logical Blocks)**

### 1️⃣ **Setup and Initialization**

```bash
SCRIPT_DIR="$(dirname "$0")"
MAIN_LOG_FILE="./00_main.log"
ORCHESTRATION_FAILED=0

# Clears the main log before each new run
: > "$MAIN_LOG_FILE"
main_log "ORCHESTRATION START"
```

| Variable/Command | Explanation |
|------------------|-------------|
| `ORCHESTRATION_FAILED=0` | **NEW.** This global flag tracks if any module failed. It's set to `1` upon the first non-zero exit code. |
| `: > "$MAIN_LOG_FILE"` | Uses the null command (`:`) with redirection to clear the log before starting. |

---

### 2️⃣ **Essential Functions**

#### 🧩 **A. Function `main_log()`**

Encapsulates all log writing, ensuring consistent formatting.

```bash
main_log() {
    local message="$1"
    printf "[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$message" >> "$MAIN_LOG_FILE"
}
```

**Log:** The `>>` operator appends messages to the end of the log file with each call.

---

#### ⚙️ **B. Function `check_status()` (Fault Tolerant Logic)**

Implements Fault Tolerance logic. It records the failure without exiting the main script.

```bash
check_status() {
    local exit_code=$?
    local module_path="$1"

    if [ "$exit_code" -ne 0 ]; then
        # ... (Error feedback and logging) ...
        ORCHESTRATION_FAILED=1 # CRITICAL: Sets the global flag to signal failure
    else
        # ... (Success feedback and logging) ...
    fi
}
```

| Key Point | Explanation |
|------------|-------------|
| `local exit_code=$?` | Captures the exit code of the last executed command. |
| **Tolerance Logic** | If a failure occurs, the `ORCHESTRATION_FAILED` flag is set to `1`. Crucially, the script does **NOT** halt, allowing the execution loop to continue. |

---

### 3️⃣ **Orchestration Loop and Finalization**

The orchestrator executes all modules and determines the final exit code based on the global failure flag.

```bash
for module_path in "$SCRIPT_DIR"/??_*.sh; do
    # ... (Module execution and check_status call) ...
done

# --- FINALIZATION ---
# Determines the final exit code based on the global failure flag.
if [ "$ORCHESTRATION_FAILED" -eq 1 ]; then
    main_log "ORCHESTRATION COMPLETE (WITH FAILURES)"
    # ... (Console output) ...
    exit 1
else
    main_log "ORCHESTRATION COMPLETE (SUCCESS)"
    # ... (Console output) ...
    exit 0
fi
```

**Loop:** The flow remains `Execute → Verify`, but verification no longer halts the process.  
**Finalization:** The final `if/else` block checks the state of `ORCHESTRATION_FAILED` after all modules have run and sets the final exit code for the script accordingly.