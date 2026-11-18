# Future work

## Optional log subentries

Implemented in the log class and log window on 2026-11-17. Note, Warning, Error and Debug return entry handles and accept an optional parent handle. The viewer has expandable branches and copies descendants with their parent. Source reviewed; runtime and visual verification remain with the user. Converting manual-export progress messages to use parent handles remains pending.

Allow each Studio log entry to have optional subentries. For example, a manual export should create one top-level entry, with steps such as reading the manual, paginating, and writing the PDF recorded beneath it. Each step should be visible without increasing the top-level entry count.

A tree view in the log window could let users expand an entry to inspect its steps or collapse it to see the main operations. Ordinary messages can remain standalone entries.
