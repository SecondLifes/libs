
`src\test\run_tests.bat` builds and runs the real DUnitX test suite via MSBuild — this is how to get genuine (not just code-reviewed) pass/fail results for `src\test\unit\*.Tests.pas` files.

What it does: sets `DELPHI_PATH` (RAD Studio 37.0 bin), calls `rsvars.bat`, runs `MSBuild ".\RunTests.dproj" /t:Build /p:Config=Debug /p:platform=Win32`, then runs `.\RunTests.exe -xml:".\reports\test_results.xml"`. Console output shows per-test pass/fail inline; the XML report lands at `src\test\test_results.xml` (not actually under `reports\`, despite the flag — the `reports` subfolder isn't auto-created).

**To add a new test unit so it actually runs:** it must be registered in TWO places, not just exist on disk:
1. `src\test\RunTests.dpr` — add `YourUnit in 'unit\YourUnit.pas',` to the `uses` clause (this triggers `initialization TDUnitX.RegisterTestFixture(...)` to run).
2. `src\test\RunTests.dproj` — add `<DCCReference Include="unit\YourUnit.pas"/>` to the `<ItemGroup>` (this is what MSBuild actually compiles).
Existing test files like `rad.eventbus.Tests.pas`, `rad.cache.Tests.pas` are NOT wired into `RunTests.dpr`/`.dproj` as of 2026-07-03 — only `rad.utils.Tests.pas` is (user wired it in manually). `RunTests.dpr`'s original content only referenced a stale `Test.DateTime.pas` that doesn't correspond to any current test file — treat that as legacy/unrelated, not a template to copy from.

**How to apply:** Before claiming a `rad.*.pas` change is tested/verified, actually run `src\test\run_tests.bat` (via PowerShell) rather than relying on manual code tracing — this project's owner explicitly asked "şimdi bir dene" (now try it) and expects real dcc32 compilation + DUnitX execution, not just review. If a new test file needs to run, check whether it's wired into `RunTests.dpr`/`.dproj` first.
