package renderer

import "unicode"

// RTL Unicode ranges: Hebrew, Arabic, Syriac, Thaana, Arabic Extended, etc.
func isRTLRune(r rune) bool {
	return (r >= 0x0591 && r <= 0x05F4) || // Hebrew
		(r >= 0x0600 && r <= 0x06FF) || // Arabic
		(r >= 0x0700 && r <= 0x074F) || // Syriac
		(r >= 0x0780 && r <= 0x07BF) || // Thaana
		(r >= 0x08A0 && r <= 0x08FF) || // Arabic Extended-A
		(r >= 0xFB1D && r <= 0xFDFF) || // Hebrew/Arabic Presentation Forms
		(r >= 0xFE70 && r <= 0xFEFF) // Arabic Presentation Forms-B
}

func isLTRRune(r rune) bool {
	return unicode.IsLetter(r) && !isRTLRune(r)
}

// CheckRTL returns "rtl" if the first strong directional character
// in s is an RTL character, "ltr" if it's LTR, or "" if no strong
// directional characters are found.
func CheckRTL(s string) string {
	for _, r := range s {
		if isRTLRune(r) {
			return "rtl"
		}
		if isLTRRune(r) {
			return "ltr"
		}
		// digits, punctuation, whitespace — skip (neutral)
	}
	return ""
}
