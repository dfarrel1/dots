// Tests for directed messages (--to) and bus ack (delivery-contract track).
//
// The delivery hook (.claude/hooks/session-bus-tail.sh) matches directed
// messages by substring on the canonical "TO session <id>: " /
// "TO track <name>: " prefix; these tests pin that prefix so the emit side
// and the hook can't drift apart silently.
package main

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

func TestBusDirectedPrefix(t *testing.T) {
	cases := []struct {
		name    string
		to      string
		want    string
		wantErr bool
	}{
		{"session form", "session:p1522", "TO session p1522: ", false},
		{"track form", "track:gear-perm-audit", "TO track gear-perm-audit: ", false},
		{"empty session id", "session:", "", true},
		{"empty track name", "track:", "", true},
		{"bare value", "p1522", "", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := busDirectedPrefix(tc.to)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected error for %q, got %q", tc.to, got)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if got != tc.want {
				t.Errorf("prefix mismatch: got %q want %q", got, tc.want)
			}
		})
	}
}

func TestBusEmit_ToFlagPrefixesMsg(t *testing.T) {
	sandbox(t)
	if err := cmdBusEmit("info", []string{"--to", "session:p999", "please", "rebase"}); err != nil {
		t.Fatalf("emit: %v", err)
	}
	path, _ := busFilePath()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var ev BusEvent
	if err := json.Unmarshal([]byte(strings.TrimSpace(string(data))), &ev); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if ev.Msg != "TO session p999: please rebase" {
		t.Errorf("unexpected msg: %q", ev.Msg)
	}
}

func TestBusAck_DirectsInfoAtSenderWithRef(t *testing.T) {
	sandbox(t)

	// Simulate another session's message on the bus.
	origTS := "2026-08-11T04:56:21Z"
	orig := BusEvent{
		TS:        origTS,
		Level:     "info",
		Msg:       "TO the session doing X: some context",
		Owner:     "sender@example.com",
		SessionID: "p1522",
	}
	if err := busAppend(orig, false); err != nil {
		t.Fatalf("seed event: %v", err)
	}

	if err := cmdBusAck([]string{origTS, "--note", "picked up"}); err != nil {
		t.Fatalf("ack: %v", err)
	}

	path, _ := busFilePath()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimSpace(string(data)), "\n")
	if len(lines) != 2 {
		t.Fatalf("expected 2 events (orig + ack), got %d", len(lines))
	}
	var ack BusEvent
	if err := json.Unmarshal([]byte(lines[1]), &ack); err != nil {
		t.Fatalf("unmarshal ack: %v", err)
	}
	if ack.Level != "info" {
		t.Errorf("ack level: got %q want info", ack.Level)
	}
	if ack.Ref != origTS {
		t.Errorf("ack ref: got %q want %q", ack.Ref, origTS)
	}
	wantMsg := "TO session p1522: ACK " + origTS + " — picked up"
	if ack.Msg != wantMsg {
		t.Errorf("ack msg: got %q want %q", ack.Msg, wantMsg)
	}
}

func TestBusAck_UnknownTSErrors(t *testing.T) {
	sandbox(t)
	if err := busAppend(BusEvent{
		TS: "2026-08-11T00:00:00Z", Level: "info", Msg: "x", Owner: "o",
	}, false); err != nil {
		t.Fatalf("seed: %v", err)
	}
	err := cmdBusAck([]string{"2026-01-01T00:00:00Z"})
	if err == nil || !strings.Contains(err.Error(), "no bus event with ts") {
		t.Fatalf("expected no-such-event error, got %v", err)
	}
}
