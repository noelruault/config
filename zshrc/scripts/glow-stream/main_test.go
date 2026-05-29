package main

import (
	"bytes"
	"strings"
	"testing"
)

// stripSGR removes ANSI SGR escapes so visible content can be compared.
func stripSGR(s string) string {
	return sgrRE.ReplaceAllString(s, "")
}

// containsAll asserts every needle is present in s (after no transformation).
func containsAll(t *testing.T, s string, needles ...string) {
	t.Helper()
	for _, n := range needles {
		if !strings.Contains(s, n) {
			t.Errorf("expected %q in output\n  got: %q", n, s)
		}
	}
}

// notContains asserts the needle is absent.
func notContains(t *testing.T, s string, needle string) {
	t.Helper()
	if strings.Contains(s, needle) {
		t.Errorf("did not expect %q in output\n  got: %q", needle, s)
	}
}

func TestHeaders(t *testing.T) {
	cases := []struct {
		in      string
		visible string
		hasBold bool
	}{
		{"# Title", "Title", true},
		{"## Subtitle", "Subtitle", true},
		{"### Section", "Section", true},
		{"#### Subsection", "Subsection", true},
	}
	for _, c := range cases {
		got := renderLine(c.in)
		if stripSGR(got) != c.visible {
			t.Errorf("%q: visible mismatch\n  want: %q\n  got:  %q", c.in, c.visible, stripSGR(got))
		}
		if c.hasBold && !strings.Contains(got, "\x1b[1") {
			t.Errorf("%q: missing bold escape", c.in)
		}
	}
}

func TestInlineBold(t *testing.T) {
	got := renderLine("a **bold** word")
	containsAll(t, got, "\x1b[1m", "bold", "\x1b[22m")
	if stripSGR(got) != "a bold word" {
		t.Errorf("visible: %q", stripSGR(got))
	}
}

func TestInlineItalic(t *testing.T) {
	got := renderLine("an *italic* word")
	containsAll(t, got, "\x1b[3m", "italic", "\x1b[23m")
}

func TestInlineCode(t *testing.T) {
	got := renderLine("call `gsub` here")
	containsAll(t, got, "gsub", "\x1b[38;5;203;48;5;236m")
}

func TestBullet(t *testing.T) {
	got := renderLine("- first item")
	containsAll(t, got, "• ", "first item")
	notContains(t, got, "- ")
}

func TestBulletIndented(t *testing.T) {
	got := renderLine("    - nested")
	containsAll(t, got, "    • ", "nested")
}

func TestBulletStarStyle(t *testing.T) {
	got := renderLine("* alpha")
	containsAll(t, got, "• ", "alpha")
}

func TestHorizontalRule(t *testing.T) {
	for _, in := range []string{"---", "***", "___", "  -----  "} {
		got := renderLine(in)
		if !strings.Contains(got, "─") {
			t.Errorf("%q: missing ─ divider", in)
		}
	}
}

func TestPlainText(t *testing.T) {
	got := renderLine("just text")
	if got != "just text" {
		t.Errorf("plain text should be unchanged, got %q", got)
	}
}

func TestMixedInline(t *testing.T) {
	got := renderLine("**bold** and *italic* with `code`")
	containsAll(t, got, "bold", "italic", "code", "\x1b[1m", "\x1b[3m", "\x1b[38;5;203")
}

func TestHeaderWithInlineCode(t *testing.T) {
	got := renderLine("### What is `gsub`?")
	notContains(t, stripSGR(got), "`")
	containsAll(t, got, "gsub", "\x1b[38;5;203")
}

func TestTableRowDetection(t *testing.T) {
	cases := map[string]bool{
		"| a | b |":       true,
		"|---|---|":       true,
		" | x | y | ":     true,
		"plain text":      false,
		"| only one":      false,
		"only one |":      false,
	}
	for in, want := range cases {
		if got := isTableRow(in); got != want {
			t.Errorf("isTableRow(%q) = %v, want %v", in, got, want)
		}
	}
}

func TestTableSeparator(t *testing.T) {
	cases := map[string]bool{
		"|---|---|":         true,
		"| --- | --- |":     true,
		"| :---: | :---: |": true,
		"| a | b |":         false,
	}
	for in, want := range cases {
		if got := isTableSep(in); got != want {
			t.Errorf("isTableSep(%q) = %v, want %v", in, got, want)
		}
	}
}

func TestTableRender(t *testing.T) {
	rows := []string{
		"| Arg | Meaning |",
		"| --- | --- |",
		"| a   | first   |",
		"| bb  | second  |",
	}
	out := renderTable(rows)
	if len(out) != 4 { // header, separator line, body row, body row
		t.Fatalf("expected 4 output lines, got %d:\n%s", len(out), strings.Join(out, "\n"))
	}
	joined := strings.Join(out, "\n")
	containsAll(t, joined, "Arg", "Meaning", "first", "second", "│", "─")
	notContains(t, joined, "---")
	// Header should be bold.
	if !strings.Contains(out[0], "\x1b[1m") {
		t.Errorf("header row missing bold escape: %q", out[0])
	}
}

func TestTableNoSeparator(t *testing.T) {
	// Some models emit tables without the --- row. We still render them; first
	// row becomes header by convention.
	rows := []string{
		"| a | b |",
		"| 1 | 2 |",
	}
	out := renderTable(rows)
	if len(out) != 3 { // header + sep line + 1 body row
		t.Fatalf("got %d lines: %v", len(out), out)
	}
}

func TestFenceDimmed(t *testing.T) {
	var buf bytes.Buffer
	r := &Renderer{}
	r.Process("```", &buf)
	r.Process("code line", &buf)
	r.Process("```", &buf)
	out := buf.String()
	containsAll(t, out, "code line", "\x1b[2m", "\x1b[22m")
	// Inside fence, bold markers should NOT trigger inline rendering.
	buf.Reset()
	r2 := &Renderer{}
	r2.Process("```", &buf)
	r2.Process("**not bold here**", &buf)
	r2.Process("```", &buf)
	out = buf.String()
	containsAll(t, out, "**not bold here**")
	notContains(t, out, "\x1b[1m")
}

func TestGrayMode(t *testing.T) {
	var buf bytes.Buffer
	r := &Renderer{gray: true}
	r.Process("**bold**", &buf)
	r.Process("plain", &buf)
	r.Close(&buf)
	out := buf.String()
	// Every output line should be wrapped in gray escapes.
	for _, line := range strings.Split(strings.TrimRight(out, "\n"), "\n") {
		if !strings.HasPrefix(line, "\x1b[90m") {
			t.Errorf("line missing gray prefix: %q", line)
		}
		if !strings.HasSuffix(line, "\x1b[0m") {
			t.Errorf("line missing gray suffix: %q", line)
		}
	}
	// Bold escape should have been stripped by gray mode.
	notContains(t, out, "\x1b[1m")
}

func TestTableViaProcess(t *testing.T) {
	var buf bytes.Buffer
	r := &Renderer{}
	r.Process("Some text.", &buf)
	r.Process("| Arg | Value |", &buf)
	r.Process("| --- | --- |", &buf)
	r.Process("| a   | 1     |", &buf)
	r.Process("Done.", &buf) // non-table line should flush table buffer
	out := buf.String()
	containsAll(t, out, "Some text.", "Arg", "Value", "│", "Done.")
	notContains(t, out, "| --- |")
}

func TestTableFlushAtClose(t *testing.T) {
	var buf bytes.Buffer
	r := &Renderer{}
	r.Process("| a | b |", &buf)
	r.Process("| --- | --- |", &buf)
	r.Process("| 1 | 2 |", &buf)
	r.Close(&buf)
	containsAll(t, buf.String(), "a", "b", "1", "2", "│")
}

func TestTableBRTagSplitsCell(t *testing.T) {
	rows := []string{
		"| Cmd | Params |",
		"| --- | --- |",
		"| erase | FAT32<br>device |",
	}
	out := renderTable(rows)
	joined := strings.Join(out, "\n")
	containsAll(t, joined, "FAT32", "device")
	notContains(t, joined, "<br>")
	visibleLines := strings.Split(stripSGR(joined), "\n")
	gotFAT, gotDevice := -1, -1
	for i, ln := range visibleLines {
		if strings.Contains(ln, "FAT32") {
			gotFAT = i
		}
		if strings.Contains(ln, "device") {
			gotDevice = i
		}
	}
	if gotFAT < 0 || gotDevice < 0 || gotFAT == gotDevice {
		t.Errorf("FAT32 and device must be on different lines (FAT32=%d, device=%d)\n%s", gotFAT, gotDevice, stripSGR(joined))
	}
}

func TestTableProportionalShrinkOnNarrowTerminal(t *testing.T) {
	t.Setenv("COLUMNS", "40")
	rows := []string{
		"| A | B |",
		"| --- | --- |",
		"| this is a long sentence that needs wrapping | also long content here |",
	}
	out := renderTable(rows)
	joined := strings.Join(out, "\n")
	notContains(t, joined, "this is a long sentence that needs wrapping")
	for _, ln := range strings.Split(stripSGR(joined), "\n") {
		if len([]rune(ln)) > 40 {
			t.Errorf("line exceeds 40 cols: %q (%d)", ln, len([]rune(ln)))
		}
	}
}

func TestTableRawPassthroughWhenTooNarrow(t *testing.T) {
	t.Setenv("COLUMNS", "10")
	rows := []string{
		"| a | b | c | d | e | f | g | h |",
		"| --- | --- | --- | --- | --- | --- | --- | --- |",
		"| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |",
	}
	out := renderTable(rows)
	if len(out) != len(rows) {
		t.Fatalf("expected raw passthrough of %d rows, got %d", len(rows), len(out))
	}
	containsAll(t, strings.Join(out, "\n"), "| a | b |", "| --- |")
}

func TestTableMinColWidthFloor(t *testing.T) {
	t.Setenv("COLUMNS", "60")
	rows := []string{
		"| Short | Very long column name here |",
		"| --- | --- |",
		"| a | x |",
	}
	out := renderTable(rows)
	joined := strings.Join(out, "\n")
	// Formatted output uses │ separators; raw passthrough preserves | --- |.
	notContains(t, joined, "| --- |")
	containsAll(t, joined, "│")
	for _, ln := range strings.Split(joined, "\n") {
		if displayWidth(ln) > 60 {
			t.Errorf("line exceeds 60: %q (%d)", stripSGR(ln), displayWidth(ln))
		}
	}
}

func TestCompleteDocument(t *testing.T) {
	doc := []string{
		"# Big",
		"",
		"## Sub",
		"",
		"A paragraph with **bold**, *italic*, `code`.",
		"",
		"- one",
		"- two with **emphasis**",
		"",
		"---",
		"",
		"| Col1 | Col2 |",
		"| --- | --- |",
		"| a   | b   |",
		"",
		"```",
		"raw code",
		"```",
		"",
		"End.",
	}
	var buf bytes.Buffer
	r := &Renderer{}
	for _, l := range doc {
		r.Process(l, &buf)
	}
	r.Close(&buf)
	out := buf.String()
	containsAll(t, out,
		"Big", "Sub",
		"bold", "italic", "code",
		"• one", "• two",
		"─", // hr divider
		"Col1", "Col2", "│",
		"raw code",
		"End.",
	)
	// Pipe separators from raw markdown should be replaced by ANSI │ in the table.
	if strings.Contains(out, "| a   | b   |") {
		t.Errorf("raw pipe row leaked into output")
	}
}
