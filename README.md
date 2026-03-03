# NXP Zephyr Workspace for FCM363X

This workspace contains:
- nxp-zsdk: NXP Zephyr SDK
- fcm363x-board: Board definition repository
- fcm363x-project: Application project repository

Created: 2026-03-03
Target: Quectel FCM363XABMD (NXP RW612)

## Structure

```
nxp-zephyr-ws/
├── .venv/           # Python virtual environment (self-contained)
├── .git/            # Git repository
├── tools/           # Local tools (ARM toolchain, blhost-helper)
├── logs/            # Build and verification logs
├── nxp-zsdk/        # NXP Zephyr SDK (west managed)
├── fcm363x-board/   # Board definition repository
└── fcm363x-project/ # Application project repository
```

## Quick Start

```bash
# Activate environment
source setup_env.sh

# Build
cd fcm363x-project
west build -b fcm363x
```
