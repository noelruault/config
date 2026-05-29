// glow-stream: streams stdin through a line-buffered markdown → ANSI rewriter.
// Each completed line is transformed and emitted immediately. Append-only,
// no cursor manipulation, no flicker, no repaint.
//
// Handles inline **bold**, *italic*, `code`, ATX headers (#, ##, ###, ####),
// dash/star bullets, horizontal rules (---, ***, ___), code fences (dimmed),
// and pipe tables (buffered within the table block then formatted).
//
// Flag: -gray   wrap every output line in \033[90m..\033[0m and drop our own
//                color codes first, so the whole block reads as gray.
package main

import (
	"bufio"
	"flag"
	"fmt"
	"io"
	"os"
	"regexp"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/lipgloss/table"
	"github.com/muesli/termenv"
)

func init() {
	// Force ANSI output even when stdout is not a TTY (e.g. piped). Without
	// this, lipgloss strips all color/bold when redirected or under tests.
	lipgloss.DefaultRenderer().SetColorProfile(termenv.TrueColor)
}

var (
	boldRE     = regexp.MustCompile(`\*\*([^*\n]+?)\*\*`)
	italicRE   = regexp.MustCompile(`(^|[^*\w])\*([^*\n]+?)\*([^*\w]|$)`)
	codeRE     = regexp.MustCompile("`([^`\n]+?)`")
	h1RE       = regexp.MustCompile(`^# +(.+)$`)
	h2RE       = regexp.MustCompile(`^## +(.+)$`)
	h3RE       = regexp.MustCompile(`^### +(.+)$`)
	h4RE       = regexp.MustCompile(`^#### +(.+)$`)
	bulletRE   = regexp.MustCompile(`^(\s*)[-*] +(.+)$`)
	hrRE       = regexp.MustCompile(`^\s*(-{3,}|\*{3,}|_{3,})\s*$`)
	tableRowRE = regexp.MustCompile(`^\s*\|.*\|\s*$`)
	tableSepRE = regexp.MustCompile(`^\s*\|?[\s:|-]+\|?\s*$`)
	brRE       = regexp.MustCompile(`(?i)<br\s*/?>`)
	sgrRE      = regexp.MustCompile(`\x1b\[[0-9;]*m`)
)

const (
	minColWidth = 6 // floor when proportional shrink kicks in
	colSepWidth = 3 // visible chars in " │ "
)

// termWidth returns the wrap budget for tables, falling back to 100.
func termWidth() int {
	if c := os.Getenv("COLUMNS"); c != "" {
		var n int
		if _, err := fmt.Sscanf(c, "%d", &n); err == nil && n > 0 {
			return n
		}
	}
	return 100
}


func renderLine(line string) string {
	if hrRE.MatchString(line) {
		return "\x1b[2m" + strings.Repeat("─", 60) + "\x1b[22m"
	}
	if m := h1RE.FindStringSubmatch(line); m != nil {
		return "\x1b[1;38;5;39m" + applyInline(m[1]) + "\x1b[0m"
	}
	if m := h2RE.FindStringSubmatch(line); m != nil {
		return "\x1b[1;38;5;39m" + applyInline(m[1]) + "\x1b[0m"
	}
	if m := h3RE.FindStringSubmatch(line); m != nil {
		return "\x1b[1;38;5;75m" + applyInline(m[1]) + "\x1b[0m"
	}
	if m := h4RE.FindStringSubmatch(line); m != nil {
		return "\x1b[1;38;5;111m" + applyInline(m[1]) + "\x1b[0m"
	}
	if m := bulletRE.FindStringSubmatch(line); m != nil {
		return m[1] + "• " + applyInline(m[2])
	}
	return applyInline(line)
}

func applyInline(s string) string {
	s = boldRE.ReplaceAllString(s, "\x1b[1m$1\x1b[22m")
	s = italicRE.ReplaceAllString(s, "$1\x1b[3m$2\x1b[23m$3")
	s = codeRE.ReplaceAllString(s, "\x1b[38;5;203;48;5;236m $1 \x1b[0m")
	return s
}

func isTableRow(line string) bool { return tableRowRE.MatchString(line) }
func isTableSep(line string) bool {
	return tableSepRE.MatchString(line) && strings.Contains(line, "-")
}

func parseRow(line string) []string {
	t := strings.TrimSpace(line)
	t = strings.TrimPrefix(t, "|")
	t = strings.TrimSuffix(t, "|")
	parts := strings.Split(t, "|")
	for i, p := range parts {
		parts[i] = strings.TrimSpace(p)
	}
	return parts
}

func displayWidth(s string) int {
	return len([]rune(sgrRE.ReplaceAllString(s, "")))
}

// normalizeCells strips <br> tags (replaces them with newlines so lipgloss
// will treat each fragment as its own line inside the cell) and applies our
// inline markdown rewriter so bold/italic/code render inside table cells.
func normalizeCells(cells []string) []string {
	out := make([]string, len(cells))
	for i, c := range cells {
		c = brRE.ReplaceAllString(c, "\n")
		parts := strings.Split(c, "\n")
		for j, p := range parts {
			parts[j] = applyInline(strings.TrimSpace(p))
		}
		out[i] = strings.Join(parts, "\n")
	}
	return out
}

// rawTablePassthrough returns the raw rows wrapped in dim markers so a too-narrow
// terminal at least preserves the markdown source.
func rawTablePassthrough(rows []string) []string {
	out := make([]string, 0, len(rows))
	for _, r := range rows {
		out = append(out, "\x1b[2m"+r+"\x1b[22m")
	}
	return out
}

// renderTable formats a block of pipe-table rows via charmbracelet/lipgloss/table:
//
//  1. Strip the markdown separator row (| --- | --- |).
//  2. Apply inline markdown + expand <br> in every cell.
//  3. Treat the first row as headers, the rest as body.
//  4. Render with lipgloss/table:
//     - column separators only (no outer or row borders)
//     - dim border style; bold headers
//     - width capped to terminal so cells word-wrap automatically
//  5. If the terminal is too narrow even for lipgloss to lay out (very low
//     COLUMNS) we fall back to a raw dim passthrough so the user still sees
//     the markdown source.
func renderTable(rows []string) []string {
	var parsed [][]string
	for _, r := range rows {
		if isTableSep(r) {
			continue
		}
		parsed = append(parsed, parseRow(r))
	}
	if len(parsed) == 0 {
		return nil
	}

	width := termWidth()
	numCols := 0
	for _, row := range parsed {
		if len(row) > numCols {
			numCols = len(row)
		}
	}
	if numCols == 0 {
		return nil
	}
	// Need at least minColWidth per column plus a separator between each.
	if width < numCols*minColWidth+(numCols-1)*colSepWidth {
		return rawTablePassthrough(rows)
	}

	headers := normalizeCells(parsed[0])
	for len(headers) < numCols {
		headers = append(headers, "")
	}
	body := make([][]string, 0, len(parsed)-1)
	for _, row := range parsed[1:] {
		cells := normalizeCells(row)
		for len(cells) < numCols {
			cells = append(cells, "")
		}
		body = append(body, cells)
	}

	headerStyle := lipgloss.NewStyle().Bold(true).Padding(0, 1)
	cellStyle := lipgloss.NewStyle().Padding(0, 1)
	borderStyle := lipgloss.NewStyle().Faint(true)

	t := table.New().
		Border(lipgloss.NormalBorder()).
		BorderStyle(borderStyle).
		BorderTop(false).
		BorderBottom(false).
		BorderLeft(false).
		BorderRight(false).
		BorderRow(false).
		BorderColumn(true).
		Width(width).
		StyleFunc(func(row, _ int) lipgloss.Style {
			if row == table.HeaderRow {
				return headerStyle
			}
			return cellStyle
		}).
		Headers(headers...).
		Rows(body...)

	rendered := t.Render()
	// Split on newline; lipgloss emits one terminal row per output line.
	return strings.Split(strings.TrimRight(rendered, "\n"), "\n")
}

type Renderer struct {
	gray     bool
	inFence  bool
	tableBuf []string
}

func (r *Renderer) flushTable(w io.Writer) {
	if len(r.tableBuf) == 0 {
		return
	}
	for _, line := range renderTable(r.tableBuf) {
		r.emit(w, line)
	}
	r.tableBuf = nil
}

func (r *Renderer) emit(w io.Writer, out string) {
	if r.gray {
		out = sgrRE.ReplaceAllString(out, "")
		out = "\x1b[90m" + out + "\x1b[0m"
	}
	fmt.Fprintln(w, out)
}

func (r *Renderer) Process(line string, w io.Writer) {
	if !r.inFence && isTableRow(line) {
		r.tableBuf = append(r.tableBuf, line)
		return
	}
	r.flushTable(w)

	var out string
	switch {
	case strings.HasPrefix(strings.TrimSpace(line), "```"):
		r.inFence = !r.inFence
		out = "\x1b[2m" + line + "\x1b[22m"
	case r.inFence:
		out = "\x1b[2m" + line + "\x1b[22m"
	default:
		out = renderLine(line)
	}
	r.emit(w, out)
}

func (r *Renderer) Close(w io.Writer) {
	r.flushTable(w)
}

func main() {
	var gray bool
	flag.BoolVar(&gray, "gray", false, "Strip color codes and tint output gray")
	flag.Parse()

	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 64*1024), 1024*1024)

	writer := bufio.NewWriter(os.Stdout)
	defer writer.Flush()

	r := &Renderer{gray: gray}
	for scanner.Scan() {
		r.Process(scanner.Text(), writer)
		writer.Flush()
	}
	r.Close(writer)
}
