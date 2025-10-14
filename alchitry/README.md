# Proton Pack Telemetry Capture System

## Alchitry Pt Design

Build from https://fpga.jenkins-ecs.shure.com/job/DEVELOPMENT/job/TELEMETRY/job/protonpack/

Setup:

```
git clone --filter=tree:0 --no-checkout --quiet ssh://git@bitbucket.shure.com:7999/dpsm_fpga/protonpack.git
cd protonpack
git checkout --no-progress $branch

cd alchitry
source ./build_fpga $branch
```
