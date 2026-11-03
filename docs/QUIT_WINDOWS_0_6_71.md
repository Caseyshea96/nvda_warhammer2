# Exit to Windows — 0.6.71

The November 3 player log showed `button_windows` in the campaign Game Menu,
followed by its child `string` labelled "Exit to Windows". The reader exposed
two items, "Windows, button" and "Exit to Windows". Activating the latter
reported "Not supported yet." because it was plain text.

The reader now folds that specific label into its owning button, retaining the
button's native path and identity checks. `button_windows` always requires
confirmation, even though its ID contains neither "exit" nor "quit".

Open the Game Menu with Escape, select "Exit to Windows, button", and press
Enter. The reader asks "Exit to Windows? Press Enter again to confirm."
Navigation or an expired confirmation cancels the pending exit.

Validation: Lua 5.1 harnesses (415 frontend and 62 campaign scenarios), full
Windows build checks and pack round-trip passed. Six new campaign cases cover
the single named button, one click on confirmation, navigation cancellation,
hidden/disabled/replaced targets, and timeout. Live exit remains unverified.
No campaign was loaded and no saves were changed during these checks.
