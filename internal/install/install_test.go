package install

import (
	"strings"
	"testing"

	"github.com/weefarm/38specialK/internal/config"
)

func TestEmitBasicStructure(t *testing.T) {
	cfg := &config.Config{
		Slugs: map[string]string{
			"clo": "cloudflare",
			"sys": "kube-system",
		},
		AllSlug: "all",
	}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	// Should contain the header
	if !strings.Contains(out, "auto-generated") {
		t.Error("expected header with 'auto-generated'")
	}

	// Should contain the skd alias
	if !strings.Contains(out, `alias skd="sk dispatch"`) {
		t.Error("expected skd alias in output")
	}

	// Should contain the all-namespaces function
	if !strings.Contains(out, "kall(){ sk dispatch all \"$@\"; }") {
		t.Error("expected kall function in output")
	}

	// Should contain plain slug functions
	if !strings.Contains(out, "kclo(){ sk dispatch clo \"$@\"; }") {
		t.Error("expected kclo function in output")
	}
	if !strings.Contains(out, "ksys(){ sk dispatch sys \"$@\"; }") {
		t.Error("expected ksys function in output")
	}
}

func TestEmitFilteredSlugs(t *testing.T) {
	cfg := &config.Config{
		Filtered: map[string]config.FilteredSlug{
			"cil": {NS: "kube-system", Grep: "cilium"},
		},
		AllSlug: "all",
	}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	if !strings.Contains(out, "kcil(){ sk dispatch cil \"$@\"; }") {
		t.Error("expected kcil function in output")
	}
}

func TestEmitGfGuard(t *testing.T) {
	cfg := &config.Config{AllSlug: "all"}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	if !strings.Contains(out, "lsf(){") {
		t.Error("expected lsf guard function in output")
	}
	if !strings.Contains(out, "Usage: kall lsf") {
		t.Error("expected lsf usage hint in output")
	}
	if !strings.Contains(out, "return 1") {
		t.Error("expected lsf guard to return 1")
	}
}

func TestEmitCompletion(t *testing.T) {
	cfg := &config.Config{
		Slugs:   map[string]string{"clo": "cloudflare"},
		AllSlug: "all",
	}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	// Should contain the completion function
	if !strings.Contains(out, "_sk_dispatch_complete") {
		t.Error("expected completion function in output")
	}

	// Should register completion for each slug function + all
	if !strings.Contains(out, "complete -F _sk_dispatch_complete kclo") {
		t.Error("expected completion registration for kclo")
	}
	if !strings.Contains(out, "complete -F _sk_dispatch_complete kall") {
		t.Error("expected completion registration for kall")
	}
}

func TestEmitDeterministicOrder(t *testing.T) {
	// Emit should produce deterministic output regardless of map iteration order
	cfg := &config.Config{
		Slugs: map[string]string{
			"clo":  "cloudflare",
			"sys":  "kube-system",
			"argo": "argocd",
		},
		AllSlug: "all",
	}

	var buf1, buf2 strings.Builder
	if err := Emit(cfg, &buf1); err != nil {
		t.Fatalf("first Emit failed: %v", err)
	}
	if err := Emit(cfg, &buf2); err != nil {
		t.Fatalf("second Emit failed: %v", err)
	}

	if buf1.String() != buf2.String() {
		t.Error("expected deterministic output across calls")
	}
}

func TestEmitSortedOrder(t *testing.T) {
	cfg := &config.Config{
		Slugs: map[string]string{
			"sys":  "kube-system",
			"clo":  "cloudflare",
			"argo": "argocd",
		},
		AllSlug: "all",
	}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	// Functions should appear in sorted order: argo, clo, sys
	idxArgo := strings.Index(out, "kargo(){")
	idxClo := strings.Index(out, "kclo(){")
	idxSys := strings.Index(out, "ksys(){")

	if idxArgo < 0 || idxClo < 0 || idxSys < 0 {
		t.Fatalf("missing expected functions in output")
	}
	if !(idxArgo < idxClo && idxClo < idxSys) {
		t.Errorf("expected sorted order (argo < clo < sys), got indices: argo=%d clo=%d sys=%d",
			idxArgo, idxClo, idxSys)
	}
}

func TestEmitCustomAllSlug(t *testing.T) {
	cfg := &config.Config{
		Slugs:    map[string]string{"clo": "cloudflare"},
		AllSlug:  "cluster",
	}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	if !strings.Contains(out, "kcluster(){ sk dispatch cluster \"$@\"; }") {
		t.Error("expected kcluster function with custom AllSlug")
	}
}

func TestEmitEmptyConfig(t *testing.T) {
	cfg := &config.Config{AllSlug: "all"}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	// Should still have header, skd alias, kall, lsf guard, and completion
	if !strings.Contains(out, "auto-generated") {
		t.Error("expected header even with empty config")
	}
	if !strings.Contains(out, `alias skd="sk dispatch"`) {
		t.Error("expected skd alias even with empty config")
	}
	if !strings.Contains(out, "kall(){ sk dispatch all \"$@\"; }") {
		t.Error("expected kall function even with empty config")
	}
}

func TestEmitRfCompletionTypes(t *testing.T) {
	// The completion block should include resource types for rmf completion
	cfg := &config.Config{AllSlug: "all"}
	var buf strings.Builder
	if err := Emit(cfg, &buf); err != nil {
		t.Fatalf("Emit failed: %v", err)
	}
	out := buf.String()

	expectedTypes := []string{"pods", "deployments", "services", "ingress", "configmaps", "secrets"}
	for _, typ := range expectedTypes {
		if !strings.Contains(out, typ) {
			t.Errorf("expected completion to include resource type %q", typ)
		}
	}
}
