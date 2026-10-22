"""Headless tests for Peggle Redux on a stubbed WoW API (Lua 5.1 through lupa).

    python tests/run.py play [levels] [--seed N] [--balls N]   play rounds with random aim
    python tests/run.py ui                                     fire every UI handler on each screen
    python tests/run.py duel                                   two clients play a duel
    python tests/run.py loot                                   three-player Peggle Loot
    python tests/run.py battle                                 three-player battle
    python tests/run.py fidelity [levels] [--seeds 1,2] [--shots N]
        replays the same shots on the original addon (original/Peggle.lua) and on Peggle Redux
        and compares the pegs hit, orange count and score of every shot

Needs `pip install lupa` and the libraries in Libs/ (scripts/fetch-libs.sh).
"""
import argparse
import os
import random
import sys

import lupa.lua51 as lua

TESTS = os.path.dirname(os.path.abspath(__file__)).replace("\\", "/")
ROOT = os.path.dirname(TESTS) + "/"
QUIET = ("GLOBAL WRITE", "MISSING GLOBAL: PeggleReduxDB", "MISSING GLOBAL: ChatFrameUtil", "MISSING GLOBAL: SKIP_ADDON")


def runtime(**globals_):
    rt = lua.LuaRuntime()
    g = rt.globals()
    g.ROOT = ROOT
    g.HARNESS = TESTS + "/harness.lua"
    for key, value in globals_.items():
        g[key] = value
    out = []
    g.print = lambda *args: out.append(" ".join(str(a) for a in args))
    return rt, out


def problems(lines):
    return [l for l in lines if not any(q in l for q in QUIET) and not l.startswith(("SHOT", "level"))]


def levels_arg(text):
    return [int(x) for x in text.split(",")] if text else list(range(1, 13))


def cmd_play(args):
    failed = False
    for level in levels_arg(args.levels):
        rt, out = runtime(SEED=args.seed)
        rt.execute("dofile(HARNESS) H.boot() H.step(0.1)")
        rt.execute(f"""
            local ns, game = H.ns, H.ns.game
            math.randomseed({args.seed})
            ns.addon.window:Show()
            ns.Game.Start({level}, {{ mode = "quick", balls = {args.balls or 'nil'} }})
            ns.CharacterSelect.Hide()
            local t, shots = 0, 0
            while t < 900 and not ns.Summary.IsShown() do
                H.step(0.02)
                t = t + 0.02
                if game.readyToShoot and not ns.Game.IsOverlayShown() and #game.balls == 0 then
                    ns.Aim.SetAngle(math.random(160, 380) % 360)
                    ns.Aim.Shoot()
                    shots = shots + 1
                end
            end
            print(string.format("level %d: %d shots, score %d, orange %d/%d, summary %s",
                {level}, shots, game.score, game.orangeHit, game.orangeTotal, tostring(ns.Summary.IsShown())))
        """)
        bad = problems(out)
        print([l for l in out if l.startswith("level")][-1])
        for line in bad:
            print("  ", line[:200])
        failed = failed or bool(bad)
    return failed


def cmd_ui(args):
    rt, out = runtime()
    rt.execute(open(TESTS + "/ui_smoke.lua").read())
    bad = problems([l for l in out if l != "ui smoke done"])
    for line in bad:
        print("  ", line[:200])
    return bool(bad)


class Group:
    """Several clients whose addon messages are delivered to each other."""

    def __init__(self, names, leader=None):
        self.clients, self.outputs, self.log = {}, {}, []
        for i, name in enumerate(names):
            rt, out = runtime(SEED=10 + i, PLAYER_NAME=name)
            rt.execute(open(TESTS + "/client.lua").read())
            party = [n for n in names if n != name]
            if len(names) > 2:
                rt.execute("H.inGroup = true H.party = {%s}" % ",".join('"%s"' % n for n in party))
            if leader:
                looter = 0 if name == leader else party.index(leader) + 1
                rt.execute("C_PartyInfo.GetLootMethod = function() return 2, %d, nil end" % looter)
            self.clients[name], self.outputs[name] = rt, out

    def run(self, seconds, dt=0.02):
        t = 0
        while t < seconds:
            for name, rt in self.clients.items():
                messages = rt.globals().client_tick(dt)
                for i in range(1, len(messages) + 1):
                    m = messages[i]
                    self.log.append(f"{name} -> {m['distribution']} {m['target']}: {m['text'][:60]!r}")
                    for other, ort in self.clients.items():
                        if other == name:
                            continue
                        target = m["target"]
                        if m["distribution"] == "WHISPER" and (not target or target.split("-")[0] != other):
                            continue
                        ort.globals().client_receive(m["prefix"], m["text"], m["distribution"], name + "-Realm")
            t += dt

    def report(self):
        failed = False
        for name, rt in self.clients.items():
            bad = problems(self.outputs[name])
            for line in bad:
                print(f"  {name}: {line[:200]}")
            failed = failed or bool(bad) or rt.globals().client_errors() > 0
        print(f"{len(self.log)} addon messages exchanged")
        return failed


def cmd_duel(args):
    group = Group(["Alpha", "Bravo"])
    alpha, bravo = group.clients["Alpha"], group.clients["Bravo"]
    alpha.execute('H.ns.Duel.Invite("Bravo", 3, "good luck")')
    group.run(1)
    bravo.execute("H.ns.Duel.Accept()")
    group.run(300)
    for name, rt in group.clients.items():
        won, lost = rt.eval("H.ns.Duel.GetTotalRecord()")
        print(f"{name}: score {rt.eval('H.ns.game.score')}, record {won}-{lost}")
    return group.report()


def cmd_loot(args):
    group = Group(["Alpha", "Bravo", "Charlie"], leader="Alpha")
    alpha = group.clients["Alpha"]
    alpha.execute('H.ns.Loot.Start("[Sword of Testing]")')
    group.run(0.5)
    for name in ("Alpha", "Bravo"):
        group.clients[name].execute("H.ns.Loot.Play()")
    group.clients["Charlie"].execute("H.ns.Loot.Pass()")
    group.run(45)
    chat = alpha.eval("H.chat")
    for i in range(1, len(chat) + 1):
        if "SEND" in chat[i]:
            print(chat[i][:120])
    return group.report()


def cmd_battle(args):
    group = Group(["Alpha", "Bravo", "Charlie"])
    alpha = group.clients["Alpha"]
    record = alpha.eval('H.ns.Battle.Create(2, 3, 12 * 3600, {"Bravo", "Charlie"}, "first to the top")')
    group.run(1)
    battle_id = record["id"]
    for rt in group.clients.values():
        rt.eval("H.ns.Battle.Play(...)", battle_id)
        group.run(200)
    group.run(5)
    standings = set()
    for name, rt in group.clients.items():
        rows = rt.eval("H.ns.Battle.Standings(H.ns.Battle.Get(...))", battle_id)
        line = ", ".join(f"{rows[i]['name']} {rows[i]['score']}" for i in range(1, len(rows) + 1))
        standings.add(line)
        print(f"{name} sees: {line}")
    failed = group.report()
    return failed or len(standings) != 1


def cmd_fidelity(args):
    original = ROOT + "original/Peggle.lua"
    if not os.path.exists(original):
        print("original/Peggle.lua is missing; the fidelity test needs the original addon.")
        return True
    failed = False
    for seed in [int(s) for s in args.seeds.split(",")]:
        for level in levels_arg(args.levels):
            rng = random.Random(seed)
            count_rt, _ = runtime()
            count_rt.execute(f"local ns = {{}} assert(loadfile(ROOT .. 'Data/Levels.lua'))('x', ns) N = #ns.Levels[{level}].objects")
            layout = rng.sample(range(1, count_rt.globals().N + 1), 28)
            angles = [rng.choice([rng.uniform(160, 360), rng.uniform(0, 20)]) for _ in range(args.shots)]
            results = []
            for script in ("original", "redux"):
                rt, out = runtime(SEED=seed, LEVEL=level, ORIGINAL=original)
                rt.globals().LAYOUT = rt.table_from(layout)
                rt.globals().ANGLES = rt.table_from(angles)
                if script == "original":
                    rt.execute(open(TESTS + "/original.lua").read())
                    rt.execute(open(TESTS + "/compare_original.lua").read())
                else:
                    rt.execute("dofile(HARNESS) H.boot() H.step(0.1)")
                    rt.execute(open(TESTS + "/compare_redux.lua").read())
                results.append([l for l in out if l.startswith("SHOT")])
            a, b = results
            same = sum(1 for x, y in zip(a, b) if x == y)
            total = max(len(a), len(b))
            print(f"level {level} seed {seed}: {same}/{total} shots identical")
            if same != total:
                failed = True
                for x, y in zip(a, b):
                    if x != y:
                        print("   original:", x[:160])
                        print("   redux:   ", y[:160])
                        break
    return failed


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["play", "ui", "duel", "loot", "battle", "fidelity"])
    parser.add_argument("levels", nargs="?", help="comma-separated levels (default: all 12)")
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--balls", type=int)
    parser.add_argument("--seeds", default="1,2,3")
    parser.add_argument("--shots", type=int, default=10)
    args = parser.parse_args()
    failed = globals()["cmd_" + args.command](args)
    print("FAILED" if failed else "OK")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
