---
phase: "4"
plan: "fcm363x-project"
subsystem: "application"
tags: [zephyr, rtos, fcm363x, rw612, hello-world]
depends_on: ["03-fcm363x-board"]
provides: ["hello-world-application"]
tech_stack:
  added: [zephyr-application, west-build]
  patterns: [out-of-tree-board, shared-sdk]
key_files:
  created:
    - projects/hello/CMakeLists.txt
    - projects/hello/prj.conf
    - projects/hello/VERSION
    - projects/hello/src/main.c
    - projects/hello/boards/fcm363x.overlay
    - projects/hello/.gitignore
  modified:
    - fcm363x-board/zephyr/module.yml
decisions:
  - Use shared SDK architecture instead of independent west workspace
  - Use zephyr/module.yml for board_root registration (official pattern)
  - Remove undefined Kconfig symbols to avoid build errors
metrics:
  duration: "15 min"
  completed_date: "2026-03-04"
  commits: 4
  files_modified: 9
---

# Phase 4 Plan: Create fcm363x-project Summary

## One-liner

FCM363X hello world application using shared SDK architecture with out-of-tree board support

## Completed Tasks

| Task | Description | Status | Commit |
|------|-------------|--------|--------|
| 1 | Add zephyr/module.yml to fcm363x-board | ✅ | b9f298f |
| 2 | Create projects/hello directory structure | ✅ | fb41640 |
| 3 | Create CMakeLists.txt | ✅ | fb41640 |
| 4 | Create prj.conf | ✅ | fb41640, 9cfd7d6 |
| 5 | Create VERSION file | ✅ | fb41640 |
| 6 | Create src/main.c | ✅ | fb41640, 9cfd7d6 |
| 7 | Create boards/fcm363x.overlay | ✅ | fb41640, 9cfd7d6 |
| 8 | Create .gitignore | ✅ | fb41640 |
| 9 | Build and verify | ✅ | - |
| 10 | Fix build issues | ✅ | 9cfd7d6 |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Functionality] Fixed board overlay alias conflict**
- **Found during:** Task 10 (Build)
- **Issue:** Board overlay referenced `led0` alias that conflicted with base DTS
- **Fix:** Removed duplicate alias from overlay, base DTS already has `led0 = &green_led`
- **Files modified:** boards/fcm363x.overlay
- **Commit:** 9cfd7d6

**2. [Rule 1 - Bug] Fixed undefined Kconfig symbol**
- **Found during:** Task 10 (Build)
- **Issue:** `CONFIG_NXP_PSRAM=n` is undefined in this SDK version
- **Fix:** Removed the undefined symbol from prj.conf
- **Files modified:** prj.conf
- **Commit:** 9cfd7d6

**3. [Rule 1 - Bug] Fixed undefined KERNEL_VERSION_STRING**
- **Found during:** Task 10 (Build)
- **Issue:** `KERNEL_VERSION_STRING` macro not available in Zephyr 4.3.0
- **Fix:** Removed version string printing from main.c
- **Files modified:** src/main.c
- **Commit:** 9cfd7d6

## Build Results

```
Memory region         Used Size  Region Size  %age Used
           FLASH:       88388 B         1 MB      8.43%
             RAM:       21472 B       960 KB      2.18%
            SMU1:        510 KB       510 KB    100.00%
            SMU2:        140 KB       140 KB    100.00%
```

**Output files:**
- `build/zephyr/zephyr.bin` - 86 KB
- `build/zephyr/zephyr.elf` - 1.6 MB

## Architecture

```
~/nxp-zephyr-ws/                    # Shared SDK workspace
├── nxp-zsdk/                       # NXP Zephyr SDK (shared)
│   └── zephyr/                     # ZEPHYR_BASE
├── fcm363x-board/                  # Board definition (independent git)
│   ├── boards/nxp/fcm363x/         # Board files
│   └── zephyr/module.yml           # Board root registration
└── projects/
    └── hello/                      # Hello world application
        ├── CMakeLists.txt
        ├── prj.conf
        ├── VERSION
        ├── boards/fcm363x.overlay
        └── src/main.c
```

## Key Decisions

1. **Shared SDK Architecture**: Projects share the nxp-zsdk SDK, saving disk space and simplifying updates
2. **module.yml Registration**: Using official Zephyr pattern for out-of-tree board registration
3. **Board Overlay Simplification**: Keep overlay minimal to avoid conflicts with base DTS

## Next Steps

1. **Phase 5**: Build verification and debugging setup
2. Add JLink debug configuration
3. Test firmware on actual FCM363X hardware

## Commits

| Commit | Message |
|--------|---------|
| b9f298f | feat(board): add zephyr/module.yml for board_root registration |
| fb41640 | feat(hello): add FCM363X hello world application |
| 9cfd7d6 | fix(hello): resolve build issues for fcm363x |

## Self-Check

- [x] All files created exist
- [x] Build succeeded
- [x] Git commits recorded
- [x] Deviations documented

## Self-Check: PASSED
