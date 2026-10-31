module

import LeanIn

/-! `lake exe pumpLifecycle <case>`: the pump thread starts, retires and restarts around a multi-carrier run.

Each case finishes or it does not: `tests/pump-lifecycle.sh` bounds it with a watchdog, so a stranded timer and a
process held open by a cancelled deadline both read as the watchdog's exit. `control` never finishes, and is that
detector's affirmative control. -/

open LeanIn LeanIn.Runtime

abbrev It := LeanIn.Task.Item

def carrier : IO (Sched.Executor It 256) := Sched.Executor.new It 256 1

def record (name : String) : IO Unit := do
  IO.println s!"pumpLifecycle|case={name}|done=yes"
  (← IO.getStdout).flush

/-- Timers armed one after another from a carrier: each fire can leave the pump with nothing to drive, so the next
arm has to find it running or restart it. Enough rounds to land in the window while it retires. -/
def rearm : IO Unit := do
  let e ← carrier
  let c := Clock.live (← Hooks.new)
  let _ ← runCarriersWait e 1 do
    for _ in [0:200] do sleep c 1
  record "rearm"

/-- A second run in one process, after the first run's pump has retired. -/
def twoRuns : IO Unit := do
  let c := Clock.live (← Hooks.new)
  for _ in [0:2] do
    let e ← carrier
    let _ ← runCarriersWait e 1 (sleep c 1)
    IO.sleep 20
  record "two-runs"

/-- A won timeout leaves a cancelled entry a minute out, which must not hold the process open. This one returns
from `main` rather than exiting, because the process's own exit is what is under test. -/
def wonTimeout : IO Unit := do
  let e ← carrier
  let c := Clock.live (← Hooks.new)
  let _ ← runCarriersWait e 1 do
    let _ ← withTimeout c 60000 (sleep c 1)
  record "won-timeout"

/-- Stranded on purpose: a program that never finishes. -/
def stranded : IO Unit := do
  let e ← carrier
  let _ ← runCarriersWait e 1 (never : LeanIn.Task.Async Unit)
  record "control"

public def main (args : List String) : IO UInt32 := do
  match args with
  | ["rearm"] => rearm; return 0
  | ["two-runs"] => twoRuns; return 0
  | ["won-timeout"] => wonTimeout; return 0
  | ["control"] => stranded; return 0
  | _ => IO.eprintln "usage: pumpLifecycle rearm|two-runs|won-timeout|control"; return 2
