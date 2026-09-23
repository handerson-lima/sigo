Conduct a review of the recent routing modularization changes in `app_router.dart` and the new `*_routes.dart` files.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the size of the changes: N = min(floor(sqrt(15) + 1), 10) = 4. State the arithmetic in one line, then find at least 4 issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT:
The changed files in the current worktree (specifically `app_router.dart` and the 15 new files under `features/*/routing/*_routes.dart`). Inspect them directly before reviewing.

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message; do not route them through any findings-reporting tool the host may offer.
