package renderer

import "testing"

func TestCheckRTL(t *testing.T) {
	tests := []struct {
		name string
		input string
		want string
	}{
		{"hebrew", "שלום עולם", "rtl"},
		{"arabic", "مرحبا بالعالم", "rtl"},
		{"english", "Hello World", "ltr"},
		{"number then hebrew", "3. שלום", "rtl"},
		{"punctuation then hebrew", "- שלום", "rtl"},
		{"english then hebrew", "Hello שלום", "ltr"},
		{"hebrew then english", "שלום Hello", "rtl"},
		{"empty", "", ""},
		{"only numbers", "12345", ""},
		{"only punctuation", "!@#$%", ""},
		{"mixed with number prefix", "1. רשימה ממוספרת", "rtl"},
		{"parenthesized hebrew", "(שלום)", "rtl"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CheckRTL(tt.input)
			if got != tt.want {
				t.Errorf("CheckRTL(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}
