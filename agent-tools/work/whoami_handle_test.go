package main

import "testing"

func TestHandleFromEmail(t *testing.T) {
	cases := []struct{ in, want string }{
		{"ada.lovelace@example.com", "ada.lovelace"},
		{"ada@sub.example.co.uk", "ada"},
		{"already-a-handle", "already-a-handle"},
		{"", ""},
		{"@leading", "@leading"}, // no local part: leave alone rather than return ""
	}
	for _, c := range cases {
		if got := handleFromEmail(c.in); got != c.want {
			t.Errorf("handleFromEmail(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}
