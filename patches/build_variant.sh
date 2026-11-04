#!/usr/bin/env bash
# build_variant.sh v1.01 -- tree_mm (the deployed @cc:sq source) + patches -> $WORK/trees/NAME, cc1 rebuilt,
# sandbox-ready binaries bundled to $WORK/bin/NAME.  Usage: build_variant.sh NAME patch...
# (v1.01: machine paths are settings, not hard-coded; build steps unchanged.)
#   TOOLROOT  dir holding sysroot32/ (32-bit glibc sysroot) and bison128/ (bison 1.28)   default: $HOME/compiler_build
#   WORK      output dir; patches are read from $WORK/patches                            default: this script's dir/..
#   TREE_MM   the unpacked 991111b tree with mm08-ee-gcc-991111b.patch applied           default: $WORK/tree_mm
#   CONDA_ENV optional conda env to activate first (needs conda on PATH)                 default: none
set -e
NAME=$1; shift
ROOT=${TOOLROOT:-$HOME/compiler_build}; SR=$ROOT/sysroot32
Q=${WORK:-$(cd "$(dirname "$0")/.." && pwd)}; TS=$Q/trees/$NAME; TREE=${TREE_MM:-$Q/tree_mm}
mkdir -p $Q/trees; rm -rf $TS; cp -a "$TREE" $TS
ln -sfn $TS/gas/as-new $TS/gcc/as
for p in "$@"; do patch -d $TS -p1 -s < $Q/patches/$p; echo "applied $p"; done
if [ -n "$CONDA_ENV" ]; then eval "$(conda shell.bash hook)"; conda activate "$CONDA_ENV"; fi
export PATH="$ROOT/bison128/bin:$PATH"
export BISON_SIMPLE="$ROOT/bison128/share/bison.simple"; export BISON_HAIRY="$ROOT/bison128/share/bison.hairy"
G32="$SR/usr/lib/gcc/x86_64-linux-gnu/15/32"; L32="$SR/usr/lib32"
LEGACY="-fpermissive -Wno-implicit-int -Wno-implicit-function-declaration -Wno-int-conversion -Wno-return-mismatch -Wno-builtin-declaration-mismatch -Wno-incompatible-pointer-types -Wno-discarded-qualifiers -Wno-format-security -Wno-error"
CC32="gcc -m32 -B$G32 -B$L32 -idirafter /usr/include/x86_64-linux-gnu -idirafter $SR/extra-inc -L$G32 -L$L32 $LEGACY -Wl,--dynamic-linker=$SR/usr/lib32/ld-linux.so.2 -Wl,-rpath=$SR/usr/lib32"
cd "$TS/gcc"
nice -n 10 make LANGUAGES=c "CC=$CC32" "CFLAGS=-O2 -fno-strict-aliasing -fcommon -std=gnu89 -D_GNU_SOURCE $LEGACY" cc1 > $Q/trees/$NAME.build.log 2>&1
python3 - "$TS" "$Q/bin/$NAME" "$SR" <<"PY"
import os, sys
src, dst, sr = sys.argv[1:]
os.makedirs(dst, exist_ok=True)
INT = (sr + "/usr/lib32/ld-linux.so.2").encode()
RP = (sr + "/usr/lib32").encode()
for name, path in (("xgcc", "gcc/xgcc"), ("cc1", "gcc/cc1"), ("cpp", "gcc/cpp"), ("as", "gas/as-new")):
    d = open(f"{src}/{path}", "rb").read()
    d = d.replace(INT, b"/lib/ld-linux.so.2".ljust(len(INT), b"\0")).replace(RP, b"/opt/rt32".ljust(len(RP), b"\0"))
    open(f"{dst}/{name}", "wb").write(d); os.chmod(f"{dst}/{name}", 0o755)
PY
echo "built $NAME"
