# Worker rules — loop 76 (AZ-3329..AZ-3333)

Read `_docs/02_task_plans/text-and-ecc-test-waves/worker-rules.md` first (shell hygiene, forbidden git commands, package recipes, report shape); it applies unchanged except as below. The parent owns tracker, git, review, `_docs/AGENT_GOTCHAS.md`, the loop record and the one total test run (step 11).

- Your task spec is `_docs/02_tasks/todo/AZ-33NN_*.md`; the evidence is in `_docs/02_task_plans/hygiene-after-frame-ports/` (`problem.md`, `acceptance_criteria.md`, `input_data/expected_results/results_report.md`). Every figure in a spec was read from a run on HEAD a50e750; yours must be read from a run on your own result, never copied.
- Scratch work goes under `SCRATCH=/private/tmp/claude-501/-Users-zxsanny-dev-zxsanny-packbin/4e6e4dcf-198c-4f2b-8c9e-d0f3f9c3557c/scratchpad/<your task id>` (create it), never `/tmp` and never inside the repository. Build outputs (`obj/`, `bin/`, `target/`, `.build/`) never land in the repository.
- Do not run `scripts/loop-tests.sh`, a compose stage, or a full package suite beyond what your task spec names. The parent runs the one total run. Another worker is running at the same time: one build at a time, and print a status line every 30 seconds of a run longer than a minute.
- Each new file at most 500 lines; no new `lib`/toolchain requirement for consumers; no embedded markup in code.
- A figure or behavior that differs from the spec is a finding: stop on it and report it with the numbers; do not bend the check to pass.
- Report at the end, at most 40 lines: paths changed with line counts; per AC PASS or what is missing, with the command and its last result line; findings; `git status --short` of your owned paths and `git diff --cached` empty: yes/no.
