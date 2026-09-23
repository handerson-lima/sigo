import 'dart:io';

void main() {
  final diffContent = File('scratch/review_diff.patch').readAsStringSync();
  final claimsContent = File('_bmad-output/implementation-artifacts/spec-routing-fixes.md').readAsStringSync();

  // Blind Hunter
  final blindHunterPrompt = """
Conduct a review of CONTENT.
Look for what's missing, not only what's wrong.
Compute your finding floor N from the diff file's size: N = min(floor(sqrt(kB) + 1), 10), where kB is the file's size in kilobytes. State the arithmetic in one line, then find at least N issues to fix or improve.
Output a Markdown list of findings only — no severity, priority, or ranking.
If the content is empty, stop and say so.
If you have zero findings, re-check and keep thinking; do not stop with an empty list.

CONTENT:
```diff
$diffContent
```

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message.
""";
  File('_bmad-output/implementation-artifacts/review-prompt-blind-hunter.md').writeAsStringSync(blindHunterPrompt);

  // Edge Case Hunter
  final edgeCaseInstructions = File('_bmad/render/bmad-build/obras-91efc0f03832/c56748b5e3eddcc65e3b/review-prompts/edge-case-hunter.md').readAsStringSync();
  final edgeCasePrompt = """
Review instructions:
$edgeCaseInstructions

claims_file (leave unread until your instructions call for it): 
```markdown
$claimsContent
```

Review content:
```diff
$diffContent
```

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message.
""";
  File('_bmad-output/implementation-artifacts/review-prompt-edge-case-hunter.md').writeAsStringSync(edgeCasePrompt);

  // Verification Gap Reviewer
  final verificationGapInstructions = File('_bmad/render/bmad-build/obras-91efc0f03832/c56748b5e3eddcc65e3b/review-prompts/verification-gap.md').readAsStringSync();
  final verificationGapPrompt = """
Review instructions:
$verificationGapInstructions

Review content:
```diff
$diffContent
```

Do not invoke any skill, and do not spawn subagents of your own — you are the reviewer. Return your findings as text in your final message.
""";
  File('_bmad-output/implementation-artifacts/review-prompt-verification-gap.md').writeAsStringSync(verificationGapPrompt);

  print('Review prompts generated.');
}
