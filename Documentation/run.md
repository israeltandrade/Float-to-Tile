# 🎬 Main Orchestrator: `run.sh`

## 🎯 Objective
The `run.sh` script is the central nervous system of the Float-to-Tile suite. Its responsibility is to execute the data collection modules (`01` through `07`) in a strict **sequential order**.

**Key Characteristics:**
1. **Sequential Execution:** Runs modules one by one (`01` → `02` → ...).
2. **Fail-Fast Architecture:** Unlike loose orchestrators, this script stops immediately if a module fails. Since Module 02 depends on Module 01, continuing after a failure would produce corrupted data.
3. **Centralized Logging:** Aggregates the status of all operations into `Logs/run.log`.

---

## 🧠 Logic: The Execution Flow

The script relies on the file naming convention `??_*.sh` (where `??` are digits) to ensure modules run in the correct order.

1. **Initialization:** Sets up paths and clears the previous log.
2. **The Loop:** Iterates through every script in the `Scripts/` directory.
3. **Status Check:** After every execution, it checks the Exit Code (`$?`).
4. **Circuit Breaker:** If a module returns a non-zero exit code (Failure), the orchestrator flags a global error and **breaks** the loop immediately to prevent cascading errors.

---

## 💾 Code Breakdown (By Logical Blocks)

### 1️⃣ Setup & Path Configuration
The script resolves absolute paths dynamically, ensuring it works regardless of the working directory.

```bash
SCRIPT_ROOT_DIR="$(dirname "$0")"
LOG_DIR="$SCRIPT_ROOT_DIR/Logs"
SCRIPTS_DIR="$SCRIPT_ROOT_DIR/Scripts"

# Global Flag to track overall success/failure
ORCHESTRATION_FAILED=0
```

---

### 2️⃣ Utility Functions

#### 📝 Logging
Simple wrapper to append timestamped messages to the main log file.

```bash
log() {
    local message="$1"
    printf "[%s] %s\n" "$(date +'%H:%M:%S')" "$message" >> "$LOG_DIR/run.log"
}
```

#### 🚦 Status Checking (`check_status`)
This function is called immediately after a module runs. It serves as the judge of the operation.

```bash
check_status() {
    local exit_code=$?
    # ...
    if [ "$exit_code" -ne 0 ]; then
        # Log failure and FLIP THE SWITCH
        ORCHESTRATION_FAILED=1
    else
        # Log success
    fi
}
```

---

### 3️⃣ The Execution Loop (Circuit Breaker)

This block contains the critical "Fail-Fast" logic.

```bash
for module_path in "$SCRIPTS_DIR"/??_*.sh; do
    # 1. Execute the module
    "$module_path"

    # 2. Verify the result
    check_status "$module_path"

    # 3. CIRCUIT BREAKER: Stop immediately if something broke
    if [ "$ORCHESTRATION_FAILED" -eq 1 ]; then
        log "CRITICAL FAILURE: STOPPING EXECUTION SEQUENCE."
        break
    fi
done
```

---

## 📄 Log Output: `run.log`

The orchestrator produces a clean summary of the entire pipeline.

```text
ORCHESTRATION START
MODULE SUCCESS: 01_Screen-Resolution.sh.
MODULE SUCCESS: 02_Desktop-Details.sh.
MODULE SUCCESS: 03_Window-List.sh.
MODULE SUCCESS: 04_Monitor-Area.sh.
MODULE SUCCESS: 05_Floating-WIDs.sh.
MODULE SUCCESS: 06_Window-Cycle-Map.sh.
MODULE SUCCESS: 07_Layout-Matrices.sh.
ORCHESTRATION COMPLETE (SUCCESS)
```

If a module fails (e.g., `03_Window-List.sh`), the log will show the failure and stop there, omitting 04, 05, etc.