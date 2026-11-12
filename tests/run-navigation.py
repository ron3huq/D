"""Compile/exercise the actual D functions with a deterministic native controller.

python3 tests/run-navigation.py /path/to/luau [--source /path/to/D]
The optional source lets the same physical tests expose baseline regressions.
"""
import argparse
from pathlib import Path
import re
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument("luau", nargs="?", default="luau")
parser.add_argument("--source", type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
source = (args.source or root / "D").read_text()

def function(name):
    match = re.search(r"^(?:local )?function " + re.escape(name) + r"\(", source, re.M)
    if not match:
        return ""
    line = source[match.start():].splitlines()[0]
    if re.search(r"\bend\s*$", line):
        return line + "\n"
    end = re.search(r"^end\s*$", source[match.end():], re.M)
    assert end, name
    return source[match.start():match.end() + end.end()] + "\n"

names = """
FH.ResetCaches FH.MotionPriority FH.MotionValid FH.MotionActive FH.MotionAvailable FH.MarkWork FH.IsWorking
FH.NoteStallIntent FH.IsHacking FH.AwaitingFloorRoute FH.CommittedTraversal FH.StallJumpStep
FH.RecoveryAim Follow.RescueControlled Follow.ObserveRescueMotion Follow.RescueFailedPart Follow.ObserveRescueJump FH.Move FH.CarryMotion FH.ReleaseMotion FH.BodyRadius FH.CollisionBody
FH.ContactDistance FH.ContactGoal FH.SelectedTrigger FH.InteractionAck FH.SetContactApproach
FH.ContactApproachValid FH.ComputerSlotTaken FH.ComputerContactClear FH.ComputerContact FH.PodContactReady
FH.LaneRevision FH.RejectLane FH.LaneRejected FH.PathLaneRejected FH.AddBad FH.IsBad FH.PathBad
FH.JumpReady FH.RecordTakeoff FH.CompTriggers FH.CanHold FH.Feet FH.Space Follow.RescueGrounded FH.TakeoffSupported FH.NormalJump
FH.ConfirmNormalTakeoff FH.NoteNormalTakeoff FH.Jump FH.Tick FH.JumpTickStep FH.MotionProfile FH.PreciseMove FH.JumpMoveStep
FH.MotionGuardedStep FH.MotionStep FH.ForwardLane FH.ReleaseForward FH.ForwardOwner FH.PressForward FH.ForwardWatchStep
FH.PeriodicComputerBlocked FH.PeriodicSpaceStep FH.GroundMoveStep FH.StairProbe FH.StairJumpStep FH.ReleaseSpace FH.CanDoubleInput
FH.NativeJumpLimits FH.SupportVelocityY FH.TraversalOwned FH.TraversalSweep FH.TraversalStairs
FH.TraversalLane FH.TryJump FH.ApproachClear FH.StairLane FH.Profile FH.Seg FH.Line
FH.Ground FH.Path FH.Len FH.RouteCost FH.PathAny Follow.Hold Follow.Release Follow.PlanClear
Follow.DropLane Follow.ActiveDrop Follow.DropClear Follow.StartDrop FH.BindNativeFlight
Follow.ActiveCrossing Follow.CrossingPlan Follow.CommitCrossing Follow.RouteProfile
Follow.RescueSurfaceLane Follow.RescueWaypoints Follow.RescueStaleEntry Follow.RescuePathIndex Follow.RescueBodyClear Follow.OwnedLaneClear Follow.ActiveEscape Follow.RescueLocalLane Follow.PlanStep Follow.RescueJumpRoute Follow.RescueJumpLane Follow.RescueShortcut
Follow.RecheckLane Follow.PathIndex Follow.Airborne Follow.AirClear Follow.GoalGround Follow.GoalOnFloor
Follow.WalkTo FH.PodRay FH.PodRouteGoal FH.PodApproach FH.RescueJuke FH.RescuePod AR.ThreatPreempts
AR.Loop Follow.EscapeRoom Follow.FindDoorRoute Follow.DoorRoute Follow.PlanDoor Follow.Pick AH.Scan AR.Nearest
Follow.RescueDoorState Follow.RescueDoorDir Follow.RescueRouteReturns Follow.RescueDoorKind Follow.RescueDoorCrossed
Follow.DoorOpening Follow.PassDoor Follow.ActiveDoor Follow.Push FH.Triggers FH.DoorStand FH.DoorCanHold
Follow.CenterAim Follow.BreakerDirection FH.ExitSpan FH.ExitLane FH.ExitTriggerDistance FH.ExitTeamPull FH.BeastNearPoint FH.ExitWaitExpired FH.RescueBeastAhead AH.ContactThreat AH.NoteMeet AH.RoundStep AH.PanicSuppressed AH.PanicChaser AH.SeerActive FH.ExitEscapePending AH.PodsPending FH.SetEndgame FH.ActiveSurvivor FH.ExitPolicy FH.ExitDanger FH.ExitThreat FH.ExitPriority FH.ExitRoute FH.ExitTraversalClear FH.ExitTraverse AH.Pursuing
""".split()
functions = "\n".join(function(n) for n in names)
functions += "\n" + function("AH.Eval").replace("function AH.Eval(", "function AH.TestEval(", 1)
functions += "\n" + function("FH.ExitOpen").replace("function FH.ExitOpen(", "function FH.TestExitOpen(", 1)
# Exercise the real Main wrapper too: no success-only stand-in for its terminal loop.
main = source.index("function Follow.Main(token, player)\n")
last = source.index("    local function farmWatch()\n", main)
prefix = source[main:last].replace("function Follow.Main(", "function Follow.TestMainContact(", 1)
functions += "\n" + prefix + "\n    return function(comp) hackComputer(comp, nil, nil, true) end\nend\n"
fixture = (root / "tests/navigation.spec.luau").read_text()
fixture = fixture.replace("-- SOURCE_FUNCTIONS", functions)
exit_range = re.search(r"^Follow\.ExitTeamRange = ([0-9.]+)", source, re.M)
fixture = fixture.replace("-- EXIT_TEAM_RANGE", "Follow.ExitTeamRange = " + exit_range.group(1))
with tempfile.TemporaryDirectory(prefix="ftf-navigation-") as folder:
    path = Path(folder) / "fixture.luau"
    path.write_text(fixture)
    result = subprocess.run([args.luau, str(path)], text=True, capture_output=True)
    print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")
    raise SystemExit(result.returncode)
