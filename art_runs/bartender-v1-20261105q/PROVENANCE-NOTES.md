# Provenance notes for this run

Job st-1793899634208-161 (clap.open, seeds 950100-950103) was also an override
test. Its provenance records a prompt ending "OVERRIDE-TEST-MARKER.", which is
false: ComfyUI's /history shows the marker never reached node 10, because the
forge's MCP lane still ran the build without the fix for host bug 2001-stpr.
The frames were drawn from the prompt baked in
workflows/clap.open.override-test.api.json. Re-run the marker test after the
next forge relaunch.
