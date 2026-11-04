# MM08 room: the `sq2` compiler leg (cc-mm08.sh v1.01)

Status: written by the guest (dnb4ever) for the host. Nothing was posted to the room and nothing changed on the room board.
**Every existing leg is unchanged.** v1.01 only adds a new marker, so all matches built on `none`, `sq`, `2.9`, `O1` and `sib`
keep building exactly as before.

## What it is

`/* @cc:sq2 */` anywhere in the C picks `mm08-gcc-sq2/`. That build is the `sq` build (patched Cygnus 2.9-ee-991111b,
quad callee saves, MM08 save-slot order) plus five source changes. Each one fixes a difference between the `sq` build and
the retail compiler:

| Change | Why (what we measured on the ROM / near-misses) |
|---|---|
| No sibling calls (lombyte `0022-no-sibcalls.patch`) | cc1 991111b has no `-fno-optimize-sibling-calls`, so the wrapper drops that flag on the sq leg. As a result the sq leg turns a void call in tail position into `j f`. The ROM has **0** tail jumps in all 8190 functions. 108 of 378 open sq-leg near-misses had this diff. |
| Prologue saves are not `MEM_VOLATILE_P` (`0101-prologue-saves-not-volatile.patch`) | The sq build marks the saves volatile to keep them in order. That has two side effects. sched2 cannot interleave the saves with the first statements the way retail does: e.g. `lui/addiu %hi/%lo` of a global, or `move $s0,$a0`, landing between `sq` lines (this is the "saves come first" family, room note #678). And reorg cannot fill a `jal` delay slot across a volatile store, so the build emits `nop` where retail moved `move $sN,$aN` into the slot (95 near-misses). |
| gcc-2.95.2 scheduler call-clobbers (lombyte `0029-call-clobber-pending.patch`) | The scheduler treats call-clobbered registers as clobbers, not sets. Biggest single gain: +66 matches on top of the two changes above. |
| No edge-based LCM by default (lombyte `0016`) | +8 |
| `-O2` does not turn on strict aliasing (lombyte `0037`) | +1 |

The lombyte patches are GPL, from the public lombyte decomp's compiler patch stack for the same 991111b archive. Source
patches and the build recipe are in `patches/` in this repo. Apply them after the existing `mm08-ee-gcc-991111b.patch`, then run
`make LANGUAGES=c cc1`. Rebuilding the unpatched tree with the same script reproduces the deployed `mm08-gcc/` byte for byte.

## Measured (guest board copy, decompnet's own compile + link + score path, bwrap sandbox)

* Open near-misses (989, best score <= 25% of max): the room's **existing best C** with only the marker changed to `sq2`
  matches **182**: 179 new (132 that were stuck on `sq`, 45 on the default leg, 2 on `2.9`) plus 3 that already matched on their own leg. Most of the rest improve.
* A re-run over today's 1116 near-misses with the room's lever logic: **195 match, 368 more improve**.
* All matched functions (2223): every one still matches **on its own leg** through v1.01 (0 regressions). Recompiled on `sq2`
  instead, 2192 of 2223 also match (333 of 335 sq-leg matches), so `sq2` is close to a superset. It is still a new leg, not a
  replacement for `sq`.
* What is left on the sq leg after `sq2` is mostly in the C: argument/statement order, `$s0`/`$s1` variable order, callee
  return types (`$v0`/`$v1`), and struct shape. Scheduler-only diffs fall from 25 to 20, and unfilled delay slots from 95 to 13.

## Host steps

1. Download `mm08-gcc-bundle-v1.01.tar.gz` from this repo's v1.01 release and unpack it into the same `<MM08CC>` dir as v1.00. It holds `cc-mm08.sh` v1.01,
   `mm08-gcc/` (unchanged) and `mm08-gcc-sq2/`. sha256 of the tarball:
   `47db38b4170a729fd7191070d27d7f5ba81fb6b31ec1382c33d5c7f94e91a363`.
   sq2 binaries: cc1 `008af531...`, xgcc `5187734c...`, cpp `86acde76...`, as `6d487b80...`.
2. No project config change is needed: `cmd` and `ro_paths` stay the same, because the new dir sits inside `<MM08CC>`.
3. Add one line to the agents' instructions: "`/* @cc:sq2 */` = the sq compiler with retail scheduling; try it first on any
   sq-prologue near-miss and on non-leaf functions."

Until the host has v1.01, a `sq2` source compiles on the host as the default 2.96 leg, so the host cannot confirm those
matches. The guest therefore holds its sq2 permuter/drafter/sweep changes until the host confirms the update.

## License

GCC and these patches are GPL-2.0-or-later (the four `lombyte` patches come from the public lombyte decomp's compiler patch stack; `0101` is ours under the same license). The release bundle is built from GCC 2.9-ee-991111b plus these patches with `patches/build_variant.sh`, so this repo is the corresponding source.
