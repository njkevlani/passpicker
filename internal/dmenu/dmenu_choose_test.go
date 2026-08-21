//go:build darwin

package dmenu

import "testing"

func TestParseSelection(t *testing.T) {
	for _, tc := range []struct {
		out  string
		want Result
	}{
		{"web/gmail\n", Result{"web/gmail", ActionAccept}},
		{"web/gmail !otp\n", Result{"web/gmail", ActionCustom1}},
		{"", Result{"", ActionCancel}},
		{"  \n", Result{"", ActionCancel}},
		{"my !otp entry\n", Result{"my !otp entry", ActionAccept}}, // suffix only, not mid-string
	} {
		if got := parseSelection(tc.out); got != tc.want {
			t.Errorf("parseSelection(%q) = %+v, want %+v", tc.out, got, tc.want)
		}
	}
}
