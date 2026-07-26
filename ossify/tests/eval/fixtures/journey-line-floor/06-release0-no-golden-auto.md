---
scenario_id: 06-release0-no-golden-auto
expected_verdict: reject
expected_reason: Release 0 contributes no automated golden-journey line for its core journey
---
Release 0's skeleton spine (a photo-upload flow) proposes its whole demo contribution as one `user:` line that a human walks at release close, plus `auto:` lines asserting the uploader, the thumbnailer, and the gallery renderer each work. Nothing in the contribution runs the journey end to end, and no other Release 0 spine is named as owning such a line.
