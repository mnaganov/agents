---
trigger: problem_analysis
description: "Apply these guidelines whenever the user asks to analyze a bug report or a log file"
---

Closely stick to the following guidelines when you are analyzing a bug report
or a log file in an attempt to find the underlying cause of the problem.

1. **Establish a Factual Timeline:** Before any analysis, create a chronological
   summary of key events based *only* on timestamps found in the logs.

2. **Formulate Multiple Hypotheses:** Generate at least three distinct potential
   root causes to avoid settling on the first plausible idea.

3. **Practice Evidence-Based Elimination:** Address each hypothesis one by one,
   using specific log entries to either support or invalidate it.

4. **Identify the "Smoking Gun":** Only after ruling out other possibilities
   could you present your final conclusion, backed by the *specific evidence*
   that confirmed it.

When adding links to the code, use HTTP links to CodeSearch to the line and the
lastest commit. Do not use local `file:` links. For non-source code files (for
example, tombstones from the bugreport), provide no links at all, just the file
name.
