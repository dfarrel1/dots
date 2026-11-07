#!/usr/bin/env python3
"""Worst-case tests for every pattern: a realistic example, long labels, 2 items and 9 items.
usage: python3 patterns/test_patterns.py            writes patterns/out/<pattern>-<case>.svg and one page per pattern,
                                                    then run:  node scripts/figlint.mjs patterns/out/pages
A case either builds (and passes figkit's geometry check) or refuses with a Refused message that names what to
do instead. A case marked 'refuse' MUST refuse; any other outcome is a test failure. Exit 1 on any failure."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path[:0] = [HERE, os.path.join(os.path.dirname(HERE), "scripts")]
from patterns import *            # noqa
from figkit import page, FigureError

OUT = os.path.join(HERE, "out"); os.makedirs(os.path.join(OUT, "pages"), exist_ok=True)
LONG = "Administrator for the regional coordination centre approves"
W9 = ["Plan", "Request", "Review", "Approve", "Issue", "Install", "Verify", "Operate", "Retire"]

CASES = {
    "process_line": {
        "example": lambda: process_line("Nothing is issued until two people approve", "A person joins in five steps: invited, applies, vouched for, approved, and issued credentials automatically",
            steps=[("Sponsor invites", "single-use link"), ("Person applies", "their own details"), ("Sponsor vouches", "for them"), ("Administrator approves", "the second check"), ("Credentials issued", "in about 30 seconds")],
            bracket=(2, 3, "the two approvals")),
        "long": lambda: process_line("A long step name wraps under its disc", "Four steps, one with a very long name, which forces the numbered-row layout",
            steps=[("Request", "by the owner"), (LONG, None), ("Issue", "automatic"), ("Confirm", "by the reader")]),
        "2": lambda: process_line("Two steps are still a process", "A request is followed by an approval", steps=[("Request", "by the owner"), ("Approve", "by a second person")]),
        "9": lambda: process_line("Nine steps fall into two rows", "Nine lifecycle steps from plan to retire, in two columns", steps=[(w, None) for w in W9]),
        "numbers": lambda: process_line("Steps carry the driver's own phase numbers", "Nine stages labelled with the phase ranges a reader resumes from", steps=[(w, None) for w in W9], numbers=["1–2", "3–4", "5–6", "7–8", "9", "10–11", "12", "13", "14"]),
    },
    "hub_vs_mesh": {
        "example": lambda: hub_vs_mesh("Pair-by-pair links grow much faster than the systems", "Six systems linked pair by pair need fifteen links; through one hub they need six connections", 6,
            note="Pair by pair, 20 systems need 190 links and 50 need 1,225. Through one hub: 20 and 50."),
        "long": lambda: hub_vs_mesh("Long side labels wrap and stay balanced", "Five nodes pair by pair against five through a shared integration hub", 5,
            left="Every system integrated directly with every other system", right="Every system connected once to a shared integration hub"),
        "2": lambda: hub_vs_mesh("With two systems the approaches look alike", "Two systems need one link pair by pair and two connections through a hub", 2),
        "9": lambda: hub_vs_mesh("Nine systems: 36 links against 9 connections", "Nine systems linked pair by pair need thirty-six links; through one hub nine", 9),
    },
    "layers": {
        "example": lambda: layers("Data between systems is wrapped twice", "A message travels inside an application envelope, which travels inside a tunnel between hosts",
            [("Tunnel between hosts", "WireGuard", "panel"), ("Application envelope", "TLS", "plain")], ("The message", "a track update")),
        "long": lambda: layers("Long layer names stay on one line beside their detail", "Three nested layers with long names around a core message",
            [("Outer network tunnel between the two hosts", "WireGuard", "panel"), ("Mutually authenticated application session", "TLS 1.3", "plain"), ("Signed and sealed payload", None, "panel")], ("The message itself", "unchanged end to end")),
        "2": lambda: layers("One layer around the core", "A single envelope around a message", [("Envelope", None, "panel")], ("Message", None)),
        "9": lambda: layers("Nine levels refuse", "Nine nesting levels are refused in favour of a stack", [(w, None, "panel") for w in W9], ("Core", None)),
    },
    "enclosure": {
        "example": lambda: enclosure("A cut-off site keeps working", "A site cut off from the cloud keeps its open tunnels and local sharing, while enrolment waits for reconnection",
            "Host site", [("Keeps working", "open tunnels; local sharing", "good"), ("Waits", "enrolment; access changes", "warn")], outside=("Cloud", "relays, management"), cut=True,
            note="As of 26 October 2026: tunnels surviving a management outage have been observed; a full drill has not been run."),
        "long": lambda: enclosure("Long item names wrap inside their boxes", "Three items with long names inside a boundary, linked from outside",
            "Partner boundary with its own administration", [("Locally administered identity provider", "issues partner credentials", "plain"), ("Partner-operated data router", "forwards released streams only", "accent"), ("Audit store", "kept for thirty days", "plain")],
            outside=("Shared services", "directory, relays"), link_label="trusted"),
        "2": lambda: enclosure("Two things inside one boundary", "Two items inside a boundary with no outside party", "Site", [("Router", None), ("Store", None)]),
        "9": lambda: enclosure("Nine parts fill a three-by-three grid", "Nine parts inside a site, linked to the cloud", "Site", [(w, None) for w in W9], outside=("Cloud", None)),
    },
    "fan_out": {
        "example": lambda: fan_out("The owner of the data decides who receives it", "The owner of a stream chooses one of four releases: nobody, own organisation, named partners, or everyone",
            ("Data owner", "decides each release"), [("Nobody", "kept private"), ("Own organisation", None), ("Named partners", "listed by name", "accent"), ("Everyone", "all members", "warn")]),
        "long": lambda: fan_out("Long choices wrap and keep equal heights", "An owner chooses between three long-named options",
            ("The organisation that owns the sensor data", None), [("Release to the full coalition after review", None), ("Release to named partner organisations only", None), ("Keep inside the owning organisation", None)]),
        "2": lambda: fan_out("Two choices", "An owner chooses between keeping and sharing", ("Owner", None), [("Keep", None), ("Share", None, "good")]),
        "9": lambda: fan_out("Nine choices fall into two rows", "An owner fans out to nine lifecycle choices in two rows", ("Owner", None), [(w, None) for w in W9]),
    },
    "two_state": {
        "example": lambda: two_state("Connecting once replaces a web of links", "Before, each system kept its own links to every peer; after, each connects once to the shared hub",
            ("Before", ["a link per pair of systems", "each link built and tested", "a new system adds many links"], "warn"),
            ("After", ["one connection per system", "one place to grant access", "a new system adds one"], "good"), change="hub"),
        "long": lambda: two_state("Long items wrap inside each state", "Two states with long item text",
            ("Today, without the shared hub", ["every integration is negotiated and tested pair by pair between programmes", "access is granted separately in each system"], "warn"),
            ("With the shared hub in place", ["each system integrates once against a published format", "access is granted once and enforced everywhere"], "good")),
        "2": lambda: two_state("One item each side", "A single item before and after", ("Before", ["manual"]), ("After", ["automatic"], "good")),
        "9": lambda: two_state("Nine items each side are set compact", "Nine lifecycle steps before and after automation", ("Manual", W9, "warn"), ("Automated", W9, "good"), change="automate"),
    },
    "timeline": {
        "example": lambda: timeline("The service went from design to daily use in a year", "Five milestones from design in January to daily use in December",
            [("Jan", "Designed"), ("Apr", "First pilot site"), ("Jun", "Two sites linked"), ("Sep", "Partner joins"), ("Dec", "In daily use")], today=4),
        "long": lambda: timeline("Long event labels wrap under their dates", "Four milestones with long descriptions",
            [("Q1", "Architecture agreed by every participating organisation"), ("Q2", "First two sites connected over the shared backbone"), ("Q3", "Partner organisations onboarded through the standard path"), ("Q4", "Operations handed to the permanent support team")]),
        "2": lambda: timeline("Two dates", "Two milestones, start and finish", [("2025", "Started"), ("2026", "Finished")]),
        "9": lambda: timeline("Nine events alternate above and below", "Nine lifecycle events across a year", [(m, w) for m, w in zip(["Jan", "Feb", "Mar", "May", "Jun", "Aug", "Sep", "Nov", "Dec"], W9)]),
    },
    "matrix": {
        "example": lambda: matrix("Only the hub keeps working when the cloud is cut", "Three options compared on cost, setup time and behaviour when the cloud is cut; only the hub keeps working",
            ["Option", "Cost", "Setup", "Cloud cut"], [["Pair by pair", "high", "months", dict(sub="keeps working", tone="good")], ["Cloud broker", "medium", "weeks", dict(sub="stops", tone="warn")], ["Shared hub", "low", "days", dict(sub="keeps working", tone="good")]], col_widths=[1.3, 1, 1, 1.2]),
        "long": lambda: matrix("Long cells wrap within their columns", "Two options with long descriptions", ["Option", "What it needs"], [["Integrate directly", "a separately negotiated, built and tested interface for every pair"], ["Connect to the hub", "one interface against a published format, tested once"]], col_widths=[1, 2.2]),
        "2": lambda: matrix("Two options, one attribute", "Two options compared on one attribute", ["Option", "Works offline"], [["A", dict(sub="yes", tone="good")], ["B", dict(sub="no", tone="warn")]]),
        "9": lambda: matrix("Nine rows refuse: use an HTML table", "Nine lifecycle steps with an owner each", ["Step", "Owner", "Automated"], [[w, "operator", "yes" if i % 2 else "no"] for i, w in enumerate(W9)]),
    },
    "stack": {
        "example": lambda: stack("Every service sits on the same three tiers", "Applications run on shared services, which run on the network tier",
            [("Applications", ["Chat", "Maps", "Tracks", "Files"], "plain"), ("Shared services", ["Identity", "Data router", "Audit"], "accent"), ("Network", ["Mesh tunnels", "Relays"], "panel")]),
        "long": lambda: stack("Long part names wrap the tier onto two rows", "Two tiers with long part names",
            [("Shared services provided centrally", ["Identity and single sign-on", "Publish and subscribe data router", "Tamper-evident audit store"], "accent"), ("Network", ["Encrypted mesh tunnels between every host", "Relays"], "panel")]),
        "2": lambda: stack("Two tiers", "Applications run on top of a network", [("Apps", ["Chat"], "plain"), ("Network", ["Mesh"], "panel")]),
        "9": lambda: stack("Nine parts flow across a tier", "One tier with nine parts and one with two", [("Lifecycle", W9, "plain"), ("Platform", ["Mesh", "Identity"], "panel")]),
    },
    "map_callouts": {
        "example": lambda: map_callouts("Three sites cover the exercise area", "Three numbered sites on a schematic area: the main site, a forward site and a relay",
            [(0.3, 0.35, "Main site: core services"), (0.7, 0.55, "Forward site: works cut off"), (0.5, 0.8, "Relay: fallback path only")]),
        "long": lambda: map_callouts("Long callouts wrap beside the map", "Two markers with long callouts", [(0.3, 0.4, "Main operating base with the core services and the audit store"), (0.7, 0.6, "Forward site that keeps working while cut off from the cloud")]),
        "2": lambda: map_callouts("Two points", "Two numbered points on a schematic area", [(0.3, 0.4, "Start"), (0.7, 0.6, "Finish")]),
        "9": lambda: map_callouts("Nine numbered markers, read top to bottom", "Nine numbered points across a schematic area", [(x, y, w) for (x, y), w in zip([(.18, .3), (.4, .22), (.62, .3), (.82, .42), (.25, .55), (.5, .5), (.72, .66), (.35, .78), (.58, .8)], W9)]),
    },
    "small_multiples": {
        "example": lambda: small_multiples("Every site's traffic peaks on the second day", "Three sites' daily traffic over five days on one shared scale; each peaks on day two",
            {"Site one": [3, 9, 6, 5, 4], "Site two": [2, 7, 4, 4, 3], "Site three": [1, 5, 3, 2, 2]}, source="illustrative numbers", asof="26 October 2026", xlabels=["day 1", "day 5"], last_label="{} on day 5"),
        "long": lambda: small_multiples("Long panel names stay on one line", "Two panels with long names", {"Forward operating site": [2, 4, 3], "Main operating base": [5, 6, 7]}, source="illustrative numbers", asof="26 October 2026", kind="line"),
        "2": lambda: small_multiples("Two panels share one scale", "Two panels compared on one scale", {"A": [1, 2, 3], "B": [3, 2, 1]}, source="illustrative numbers", asof="26 October 2026"),
        "9": lambda: small_multiples("Nine panels fall into rows of five", "Nine panels of four values each on one scale", {w: [i % 4 + 1, (i + 1) % 4 + 1, (i + 2) % 4 + 2, i % 3 + 1] for i, w in enumerate(W9)}, source="illustrative numbers", asof="26 October 2026"),
    },
    "annotated_chart": {
        "example": lambda: annotated_chart("Pair-by-pair links outgrow the systems after five", "Links needed pair by pair grow as n(n-1)/2 while hub connections grow as n; at 20 systems it is 190 against 20",
            {"Pair by pair": [(n, n * (n - 1) / 2) for n in range(2, 21)], "Through a hub": [(n, n) for n in range(2, 21)]},
            source="computed from n(n-1)/2 and n", asof="26 October 2026", annotate=(20, 190, "20 systems: 190 links"), xlabel="Systems", ylabel="Links", kinds={"Pair by pair": "warn", "Through a hub": "good"}),
        "long": lambda: annotated_chart("Long series names refuse at the line end", "Series with very long names refuse", {"Integration effort with every pair of systems": [(1, 1), (2, 3)]}, source="x", asof="y"),
        "2": lambda: annotated_chart("Two series", "Two lines compared over three points", {"A": [(1, 1), (2, 2), (3, 3)], "B": [(1, 3), (2, 2), (3, 1)]}, source="illustrative", asof="26 October 2026"),
        "9": lambda: annotated_chart("Nine series dodge their end labels", "Nine lines whose end labels are pushed apart", {w: [(1, i), (2, i + 0.5), (3, i + 0.2)] for i, w in enumerate(W9)}, source="illustrative", asof="26 October 2026"),
    },
}
EXPECT_REFUSE = {("layers", "9"), ("annotated_chart", "long"), ("matrix", "9")}


def main():
    bad, rows = 0, []
    for pat, cases in CASES.items():
        svgs, caps = [], []
        for case, fn in cases.items():
            want_refuse = (pat, case) in EXPECT_REFUSE
            try:
                f = fn(); s = f.save(os.path.join(OUT, f"{pat}-{case}.svg"))
                svgs.append(s); caps.append(f"{pat}: {case} ({f.variant}, {f.w:.0f} x {f.height})")
                ok = not want_refuse; result = f"built {f.variant} 760x{f.height}"
            except Refused as e:
                ok = want_refuse; result = f"refused: {e}"
            except (ValueError, FigureError) as e:
                ok = False; result = f"ERROR: {str(e).splitlines()[0]} ..."
            bad += not ok
            rows.append((pat, case, "ok" if ok else "FAIL", result))
        page(svgs, f"Pattern: {pat}", out=os.path.join(OUT, "pages", f"{pat}.html"), captions=caps)
    w = max(len(r[0]) for r in rows)
    for r in rows: print(f"{r[0]:<{w}}  {r[1]:<8} {r[2]:<5} {r[3][:150]}")
    print(f"\npatterns: {len(rows)} cases, {bad} failing")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
