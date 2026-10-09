PowerShell coding guide
=======================

- [Authority hierarchy](#authority-hierarchy)
- [Definitions](#definitions)
- [Key rules](#key-rules)
- [File layout and structure](#file-layout-and-structure)
  - [Scripts and modules (`.ps1`, `.psm1`)](#scripts-and-modules-ps1-psm1)
  - [Data files (`.psd1`)](#data-files-psd1)
  - [Format files (`.format.ps1xml`)](#format-files-formatps1xml)
- [Formatting and style](#formatting-and-style)
  - [Formatting](#formatting)
  - [Arrays and collections](#arrays-and-collections)
  - [Casing](#casing)
  - [Command invocation](#command-invocation)
  - [Comments](#comments)
  - [Comparisons and filtering](#comparisons-and-filtering)
  - [Messages](#messages)
  - [Output and streams](#output-and-streams)
  - [Parameter passing](#parameter-passing)
  - [Path handling](#path-handling)
  - [Strings and quoting](#strings-and-quoting)
  - [View definitions](#view-definitions)
- [Error handling](#error-handling)
  - [Choosing the mechanism](#choosing-the-mechanism)
  - [Constructing an `ErrorRecord`](#constructing-an-errorrecord)
  - [Specific exception type requirements](#specific-exception-type-requirements)
  - [`try`, `catch`, `finally`](#try-catch-finally)
  - [`-ErrorAction` versus `$ErrorActionPreference`](#-erroraction-versus-erroractionpreference)
  - [Native commands and `$LASTEXITCODE`](#native-commands-and-lastexitcode)
- [Functions and parameters](#functions-and-parameters)
  - [Function design](#function-design)
  - [Function naming](#function-naming)
  - [Parameter definition](#parameter-definition)
  - [Dynamic parameters](#dynamic-parameters)
  - [Parameter sets](#parameter-sets)
  - [Parameter validation attributes](#parameter-validation-attributes)
  - [`Mandatory` versus `[ValidateNotNullOrEmpty()]`](#mandatory-versus-validatenotnullorempty)
  - [`ShouldProcess` usage](#shouldprocess-usage)
  - [`OutputType` attribute](#outputtype-attribute)
  - [Pipeline input](#pipeline-input)
  - [Comment-based help](#comment-based-help)
- [Security](#security)
- [Strict mode](#strict-mode)
- [Compatibility](#compatibility)
  - [PowerShell versions](#powershell-versions)
  - [Syntax differences](#syntax-differences)
  - [Runtime behaviour](#runtime-behaviour)
  - [`#Requires` usage](#requires-usage)
  - [.NET types](#net-types)
  - [Cmdlet changes](#cmdlet-changes)
- [Linting](#linting)
  - [PSScriptAnalyzer](#psscriptanalyzer)

This is a prescriptive PowerShell coding guide for creating and modifying PowerShell code.

The conventions are written for codebases targeting Windows PowerShell 5.1 and currently supported PowerShell versions. Care must be taken with other PowerShell versions to ensure the described conventions are compatible.

Where a rule says *must*, comply unless a higher authority overrides it (see [Authority hierarchy](#authority-hierarchy)); where it says *should*, comply unless there is a compelling reason not to; where it says *may*, it is purely at the author's discretion.

Authority hierarchy
-------------------

When guidance conflicts, resolve in this order, highest first:

1. The project's mandatory rules (e.g. a `Style guide.md` file).
2. The project's *PSScriptAnalyzer* configuration (e.g. a `PSScriptAnalyzerSettings.psd1` file).
3. This guide.
4. Observed project conventions (the patterns the codebase establishes).
5. General PowerShell best practice.

The implied consequences of this authority hierarchy include:

- A project rule wins over everything below it, including a rule in this guide which says *must*.
- The *PSScriptAnalyzer* configuration wins over this guide only where it enables or configures a rule contrary to a convention stated here.  
  An excluded or disabled rule is not a contrary instruction; the convention this guide states still applies unless the guide expressly relaxes it.
- This guide wins over observed conventions: a rule must not be softened to match code that does not comply with it.  
  Where this guide expressly defers a choice to the codebase (e.g. whether single-statement `catch` blocks are compacted), the observed convention decides.
- Project conventions win over general best practice.
- Where a best practice does not conflict with any higher authority (e.g. a command's `-Filter` parameter over post-filtering with `Where-Object`), it must be applied.
- When a best practice must be violated to honour a higher authority, the tension should, if material, be noted in a comment so the choice is documented.

Definitions
-----------

- A *library* is considered to be a script not intended to be directly invoked; e.g. used via dot-sourcing.
- References to *simple functions* also pertain to standalone scripts that are not annotated as advanced.
- References to *advanced functions* also pertain to standalone scripts that are annotated as advanced.

Key rules
---------

- *Style consistency*  
  Match the style of the existing code: read a sibling in the same file or area and mirror its structure; mirror a data file's existing shape before editing it.
- *Correctness over brevity*  
  Handle edge cases, check return values, check native exit codes via `$LASTEXITCODE`, catch and handle exceptions, and never swallow them silently.
- *Language and dialect*  
  Use Australian English spelling in comments, messages, and documentation. Identifiers, parameter names, product names, and protocol terms retain their original spelling.
- *Pascal naming convention*  
  The naming convention used is Pascal case, also known as *upper camel case*, and is applicable to declared function, variable, and property names.
- *Compact conditional blocks*  
  Write a standalone `if` whose entire body is a `break`, `continue`, or bare `return` on one line; one with a short body may be, and `elseif` / `else` bodies never are.
- *Always use `$PSItem`*  
  `$_` is forbidden everywhere, including `ForEach-Object` / `Where-Object` script blocks, `switch` arms, `catch` blocks, and view definition script blocks.
- *Always use `-LiteralPath` for verbatim paths*  
  Where a command exposes `-Path` and `-LiteralPath`, use `-LiteralPath` for verbatim paths and reserve `-Path` for wildcard globbing.
- *Defensive string quoting*  
  Single-quote strings, including string literals to parameters, unless interpolation or a subexpression is required.
- *Provide `[OutputType(...)]` attribute*  
  Declare for all functions and standalone scripts; it documents the contract and populates the `OutputType` property of `Get-Command` output.
- *Honour the version floor*  
  Windows PowerShell 5.1 and every supported newer version by default, overridden only by a `#Requires -Version` statement or an explicit instruction.
- *Zero PSScriptAnalyzer findings*  
  Suppress a rule only as a deliberate, justified choice via a narrowly scoped `[Diagnostics.CodeAnalysis.SuppressMessage(...)]` attribute.

File layout and structure
-------------------------

### Scripts and modules (`.ps1`, `.psm1`)

- Ordering of file content for standalone scripts must be:
  - Top-of-file block comment  
    May be comment-based help or simply state the script's purpose.
  - `#Requires` lines  
    Must at least declare the minimum supported PowerShell version with `#Requires -Version`.
  - Attribute stack  
    Ordered as defined under [Function design](#function-design).
  - `Function` definitions
  - Script procedural body
- Modules and libraries do not contain `#Requires` lines or an attribute stack.
- Libraries may omit the top-of-file block comment; where present, it states the file's purpose.
- Larger files should partition their bodies into topical region blocks; i.e. `#region <Topic>` / `#endregion`.
- Within a region, functions should be ordered alphabetically by name; helper functions may be grouped into a trailing region.

### Data files (`.psd1`)

- Data files consist of a single literal and no executable statements; i.e. a hashtable or array of constant expressions.
  - Constant expressions are booleans (`$true` / `$false`), numbers, strings, arrays, hashtables, and `$null`.
  - Elements and entries follow the array and hashtable formatting rules (see [Formatting](#formatting)).
- A data file with a hashtable root can be loaded with `Import-PowerShellDataFile`; any other root is rejected.  
  Exception: `InvalidOperationException`, CategoryInfo: `InvalidData`, FullyQualifiedErrorId: `CouldNotParseAsPowerShellDataFileNoHashtableRoot`
- A data file with an array root must be read by:
  - Parsing it with `[Management.Automation.Language.Parser]::ParseFile(...)`.
  - Evaluating the literal with the `SafeGetValue()` method of its expression AST.
- Data files are not module manifests; manifest keys and conventions do not apply.
- Data files are not scripts; they must not be invoked with the call operator (`&`).

### Format files (`.format.ps1xml`)

- Format files are XML documents containing view definitions associated with type names.  
  For a complete description of the file format consult the [XML schema definition](https://raw.githubusercontent.com/PowerShell/PowerShell/refs/heads/master/src/Schemas/Format.xsd).
- Format files must begin with the XML declaration: `<?xml version="1.0" encoding="<encoding>"?>`.
- Views must be ordered alphabetically by name; i.e. the content of the `<Name>` element.
- Embedded PowerShell snippets may be included in views through the `<ScriptBlock>` element.

Formatting and style
--------------------

### Formatting

- The exact mechanics should be deferred to *PSScriptAnalyzer* where possible.
- Newlines, spacing, and alignment
  - Indentation (priority order)
    - *PSScriptAnalyzer* `PSUseConsistentIndentation` rule
    - *EditorConfig* configuration
    - Existing convention
    - Default configuration
      - 4 spaces  
        *PSSA* rule option(s): `IndentationSize`, `Kind`
      - Increase indentation for the first pipeline  
        *PSSA* rule option(s): `PipelineIndentation`
  - Whitespace (priority order)
    - *PSScriptAnalyzer* `PSUseConsistentWhitespace` rule
    - Existing convention
    - Default configuration
      - Space after an opening brace and before a closing brace  
        *PSSA* rule option(s): `CheckInnerBrace`
      - Space between a keyword and its opening brace  
        *PSSA* rule option(s): `CheckOpenBrace`  
        Not required if the opening brace is preceded by an opening parenthesis.
      - Space between a keyword and its opening parenthesis  
        *PSSA* rule option(s): `CheckOpenParen`
      - Space around binary and unary operators  
        *PSSA* rule option(s): `CheckOperator`
      - Space between a parameter and its value  
        *PSSA* rule option(s): `CheckParameter`
      - Space around a pipe, removing redundant whitespace  
        *PSSA* rule option(s): `CheckPipe`, `CheckPipeForRedundantWhitespace`
      - Space after a comma or semicolon  
        *PSSA* rule option(s): `CheckSeparator`
      - Ignore whitespace around assignment operators within multi-line hashtables  
        *PSSA* rule option(s): `IgnoreAssignmentOperatorInsideHashTable`
  - Brace placement (priority order)
    - *PSScriptAnalyzer* `PSPlaceOpenBrace` and/or `PSPlaceCloseBrace` rule(s)
    - Existing convention
    - Default configuration
      - Open brace on the same line as the preceding keyword  
        *PSSA* rule option(s): `OnSameLine`
      - Enforce a newline after an opening brace  
        *PSSA* rule option(s): `NewLineAfter`
      - Ignore formatting rule for closed brace pairs in a one-line block  
        *PSSA* rule option(s): `IgnoreOneLineBlock`
      - Style consistent with *One True Brace Style* (default)
  - Assignment alignment (priority order)
    - *PSScriptAnalyzer* `PSAlignAssignmentStatement` rule
    - Existing convention
    - Default configuration
      - Align assignment operator in hashtables, factoring in any intervening comments  
        *PSSA* rule option(s): `CheckHashtable`, `AlignHashtableKvpWithInterveningComment`
      - Align assignment operator in enumeration definitions, factoring in any intervening comments  
        *PSSA* rule option(s): `CheckEnums`, `AlignEnumMemberWithInterveningComment`
      - Include enumeration members without an explicitly assigned value in alignment handling  
        *PSSA* rule option(s): `IncludeValuelessEnumMembers`
  - Newlines
    - A line consisting solely of a closing brace must be followed by a blank line.  
      Unless the next line begins with a closing brace or parenthesis.
    - Consecutive blank lines must not be used.
    - Backtick line continuation must not be used.
    - Semicolons must not be used as line terminators.  
      *PSSA* rule: `PSAvoidSemicolonsAsLineTerminators`
- Arrays
  - A single element must be written as `@(<Element>)`.
  - Two or more elements written on a single line must be a comma-separated list without `@(...)`.
    - An array requiring an explicit element type must instead use `[<Type>[]]@(...)`.  
      A cast binds more tightly than the comma operator; i.e. `[String[]]'a', 'b'` yields a two-element `[Object[]]`.
  - Elements written across multiple lines must use `@(...)` with one element per line and no separating commas.  
    An option and its value (e.g. an array holding native command arguments) may share a line as a comma-separated pair.
- Dictionaries and hashtables
  - Multiple entries must be written with one entry per line.  
    A permitted exemption to this rule is constructing the parameter attributes in a `DynamicParam` block.
  - A single entry must be written on one line with a space inside each brace; e.g. `@{ ErrorAction = 'Stop' }`.  
    A `[PSCustomObject]` literal or a lookup table expected to gain entries may instead use the multi-line form.
  - Entries added or updated after construction must use index syntax; i.e. `$<Hashtable>['<Key>'] = <Value>`.  
    The `Add(...)` method or member access must not be used.
  - Keys must not be quoted unless they contain characters which require it; e.g. `'Content-Type'`.
- Keywords
  - A standalone `if` whose entire body is a `break`, `continue`, or bare `return` must be compacted to a single line.
  - A standalone `if` whose entire body is one or two short statements may be compacted to a single line where the block form adds no clarity.  
    E.g. a guarded release in a `finally` block, a counter in a loop, or a value-returning `return` in a view definition script block.
    - Consecutive statements of this form should share one style.
  - A `catch` block or `switch` arm whose entire body is a single statement may be compacted to a single line.  
    The style must be consistent per construct kind.
- Operators
  - Logical negation must use the `!` operator, not the `-not` operator.  
    *PSSA* rule: `PSAvoidExclaimOperator`  
    Where the project configuration enables the rule, negation must instead use the `-not` operator.
- Parameter blocks
  - A parameter declared with attributes must be preceded by a blank line, unless it is the first parameter.
  - Parameters declared without attributes may be placed on consecutive lines to form a group.
- Pipelines
  - The `$PSItem` automatic variable must be used to reference the current object in the pipeline, never `$_`.
- Regions
  - `#region` and `#endregion` must not be indented.
  - Only `#region` has a title; the associated `#endregion` must be bare.
  - A blank line must follow each `#region` and precede each `#endregion`.
  - Regions must be ordered alphabetically by title, with each title in sentence case.
    - Scripts which are procedural may instead order their regions by sequence of execution.
    - A trailing region grouping helper functions is exempt and is placed last (see [Scripts and modules](#scripts-and-modules-ps1-psm1)).

### Arrays and collections

- Arrays assigned to an object property must be cast to an explicit element type (e.g. `[String[]]@(...)`, `[Int[]]@(...)`), never a bare `@(...)`.  
  A bare `@(...)` is typed as `[Object[]]`, which discards element type information and silently accepts wrongly typed or heterogeneous elements.
  - A permitted exemption is an element type defined by a module which may not be loaded, or a COM type.  
    The property is assigned `@()` with the element type stated in a trailing comment; e.g. `` <Property> = @() # `__ComObject[]` ``.
- Generic collection types should be used over non-generic equivalents; e.g. `[Collections.Generic.List[T]]` instead of `[Collections.ArrayList]`.  
  *PSSA* rule: `PSAvoidUsingArrayList` (*not yet available as of v1.25.0*)
- Collections built progressively and of non-trivial size (more than about 5 objects) must use a collection type, never an array appended to with the `+=` operator.  
  Arrays are fixed-size, requiring reallocation on every append operation; i.e. *O(n^2)* performance.
- Everything that leaves a function must be controlled: any uncaptured expression is output, so `$null = ...` must be used for incidental values.
  - On a `[Collections.ArrayList]` the `.Add(<Item>)` method returns the inserted index, which may need to be discarded.
  - On a `[Collections.Generic.List[T]]` the `.Add(...)` method returns `[Void]` and so does not require null assignment.

### Casing

- Keyword casing is subject to the keyword type.  
  *PSSA* rule: `PSUseCorrectCasing` (option: `CheckKeyword`)  
  Where the project configuration enables the option, all keywords must instead be lowercase.
  - Statements and flow control are lowercase.
    - `if` constructs  
      `if`, `elseif`, `else`
    - `switch` constructs  
      `switch`, `default`
    - `for` constructs  
      `for`, `foreach`, `in`
    - `do` and `while` constructs  
      `do`, `while`, `until`
    - Loop control  
      `break`, `continue`
    - Exit statements  
      `exit`, `return`
    - Exception handling  
      `try`, `catch`, `finally`, `throw`, `trap`
  - Declarations and blocks are Pascal case.
    - Function declarations  
      `Function`, `Filter`, `Param`, `DynamicParam`
    - Function blocks  
      `Begin`, `Process`, `End`
    - Function cleanup block  
      `Clean`  
      *Added: PowerShell 7.3*
    - Type declarations  
      `Class`, `Enum`  
      *Added: Windows PowerShell 5.0*
    - Class members  
      `Hidden`, `Static`  
      *Added: Windows PowerShell 5.0*
    - Data sections  
      `Data`
  - Directives are lowercase.
    - `using` statements  
      `using`, `namespace`, `module`, `assembly`  
      *Added: Windows PowerShell 5.0*
  - Language extensions are Pascal case.
    - Workflows  
      `Workflow`, `Parallel`, `Sequence`, `InlineScript`  
      *Added: Windows PowerShell 3.0*  
      *Removed: PowerShell 6.0*
    - Desired State Configuration  
      `Configuration`  
      *Added: Windows PowerShell 4.0*
- Type literals must be in Pascal case, including type accelerators; e.g. `[Hashtable]`, `[PSCustomObject]`, `[Regex]`.
  - `[Boolean]` should be used in preference to `[Bool]`.
  - `[Int]` should be used in preference to `[Int32]`.
- Commands must use their canonical name, never aliases; e.g. `Get-ChildItem` instead of `gci`.  
  *PSSA* rule: `PSAvoidUsingCmdletAliases`, `PSUseCorrectCasing` (option: `CheckCommands`)
- Operators must use their canonical form wherever used in an expression; e.g. `-eq`, `-match`, `-replace`.  
  *PSSA* rule: `PSUseCorrectCasing` (option: `CheckOperator`)
- For the simple `Where-Object` comparison statement form (i.e. no script block), the comparison is a parameter of `Where-Object`:
  - For acronyms, uppercase is used; e.g. `-EQ`, `-GT`, `-LE`.
  - For words, Pascal case is used; e.g. `-Is`, `-Like`, `-NotContains`.
- Declared function, variable, and property names must be in Pascal case; e.g. `Update-Widget`, `$WidgetCount`, `LastUpdated`.
  - A permitted exemption is `$i` as the index variable of a `for` loop, which may be used in place of a descriptive name.
- Scope and namespace qualifiers must be in Pascal case; e.g. `$Env:`, `$Function:`, `$Global:`.
- Automatic and preference variable names must match their canonical casing; e.g. `$args`, `$Error`, `$HOME`.  
  The canonical casing is as returned in the output from a listing of the `Variable` drive.
  - Variables not yet set in scope are omitted from the `Variable` drive; e.g. `$LASTEXITCODE`, `$Matches`.  
    For these, the canonical casing is as written in the `about_Automatic_Variables` help topic.
- Environment variable names must match their canonical casing; e.g. `$Env:SystemRoot`, `$Env:LOCALAPPDATA`.  
  The canonical casing is as returned in the output from a listing of the `Env` drive.
  - Environment variable names are case-sensitive on Unix-like platforms.
    - A name in any casing other than the defined one resolves to `$null`.
    - An assignment creates or updates a variable with matching casing, leaving the intended variable unchanged if casing does not match.
  - Environment variable names are case-insensitive on Windows; a name in any casing other than the defined one resolves to the same variable.  
    The hashtable returned by `[Environment]::GetEnvironmentVariables()` has no comparer, so indexing it by name is always case-sensitive.
  - An environment variable name used by code which supports Windows and Unix-like platforms must be either:
    - Resolved at runtime to the casing in which the variable is defined.
    - The casing in which the variable is defined on Unix-like platforms; compatibility with Windows is retained due to its case-insensitivity.  
      This is a permitted exemption to the requirement to use canonical casing for ease of cross-platform portability.
- Provider drive names must match their canonical casing; e.g. `Alias`, `Env`, `Function`.  
  The canonical casing is as returned in the `Name` property of the output from `Get-PSDrive`.

### Command invocation

- Splatting should be used to invoke commands with several or conditional arguments.
  - For PowerShell invocations, a hashtable must be built, with conditional keys and values added after construction.
  - For native command invocations, the argument list must be:
    - A string array for a fixed argument list.
    - A generic string collection when arguments are added conditionally.
- A hashtable for splatting must be named `$<Purpose>Params`; e.g. `$UpdateParams`.
  - Parameters shared by several invocations within a function must be collected in `$CommonParams`.
  - The splatted variable should immediately follow the command name, preceding any explicit parameters.
- An argument array or collection for splatting to a native command must be named `$<Purpose>Args`; e.g. `$UpdateArgs`.
  - Parameters shared by several invocations within a function must be collected in `$CommonArgs`.
  - The splatted variable should immediately follow the command name, preceding any explicit parameters.
- A string representing the command line should be assigned to `$<Purpose>Cmd`; i.e. `"<Command> $($<Purpose>Args -join ' ')"`.
  - An argument added conditionally must be added to both the argument collection and the command-line string.
  - The command-line string should be written to the verbose stream before the invocation, following a description and a colon; e.g. `"Clearing npm cache: ${<Purpose>Cmd}"`.
  - If the command fails, the command-line string must be the target object of the raised error record.
- Native commands should be invoked using the call operator (`&`) and a splatted argument array or collection.
  - Unneeded output returned by native commands must be discarded; i.e. `$null = & ...` when invoking.
- Output which is expected to be a single line should be captured with `(& <Command> @<Purpose>Args) -join ''`.  
  Native commands emit a `[String]` per line, resulting in an `[Object[]]` for multiple lines; the join ensures a `[String]` is returned.
- Combined `stdout` and `stderr` native command output should be captured with `[String[]]@(& <Command> @<Purpose>Args 2>&1)`.
  - Windows PowerShell has a limitation with the combined-capture form:
    - When `$ErrorActionPreference` is `Stop` in the calling scope (including the scope a caller's `-ErrorAction 'Stop'` establishes), the first line the tool writes to `stderr` is raised as a terminating `NativeCommandError`.  
      This occurs even when the tool returns successfully (i.e. exit code 0), so the combined capture never completes and any `$LASTEXITCODE` check will never be reached; PowerShell 7.2 and later correctly records the line and continues.
    - To mitigate this behaviour the current value of `$ErrorActionPreference` must be saved, the preference variable set to `Continue` as close as possible to the capture, and the original value restored in a `finally` block.
- Native commands may write output in an encoding other than the console output encoding, requiring `[Console]::OutputEncoding` to be modified.  
  PowerShell decodes native command output using `[Console]::OutputEncoding`; a mismatch yields corrupted text rather than an error.
  - The original value must be saved before the `try` block and restored in its `finally` block (see [`try`, `catch`, `finally`](#try-catch-finally)).
  - The encoding must be set as close as possible to the invocation; e.g. `[Text.Encoding]::Unicode` for a command emitting UTF-16.

### Comments

- Comments must be no longer than 79 characters, inclusive of indentation; i.e. the 80th column is empty.
  - Length limits on comments are not enforced by *PSScriptAnalyzer*; they must be manually checked.
  - Changing code indentation may require re-wrapping of affected comments, which must be verified on each change.
  - Comment-based help text and comments that cannot be wrapped are exempt; e.g. a comment holding a long URL.
- References to code within a comment must be enclosed in backticks.  
  Inclusive of commands, parameters, variables, types, file names, and literal values.
- Text which is quoted from a user interface or is a term of art is enclosed in double quotes.
- The following tags are defined:
  - `HACK:`  
    A workaround for a defect in a dependency.
  - `TODO:`  
    Work which is outstanding.
  - `Via:`  
    Attribution of code derived from an external source, followed by the URL.
- An extended comment consists of:
  - A summary line.
  - A blank comment line.
  - One or more paragraphs separated by blank comment lines.
- Comment punctuation is subject to the comment length:
  - A single-line comment must be written as a phrase without terminal punctuation.
  - A multi-line comment must be written as sentences, each ending with a period.
  - Lines which consist of a label and value, a list item, a tag, a code reference, or a URL are exempt.
- A URL which directly documents the subject of an extended comment's summary line may follow it without a blank line.
- A reference must be written as a descriptive title on one line followed by the URL on the next.
- Multiple references without titles must be written as a list introduced by `References:`.
- Every top-level function must be preceded by at least a single plain `# <Description>` comment.
  - Comments must be written in the imperative mood.
  - A preceding comment is not required for nested functions.

### Comparisons and filtering

- When comparing a value to null, the `$null` operand must always be on the left; e.g. `$null -eq $Value`.  
  *PSSA* rule: `PSPossibleIncorrectComparisonWithNull`
- When the left operand is a collection, `-eq` and `-ne` act as filters, returning an array with matching elements.  
  I.e. the comparison does not produce a scalar `Boolean`, which will silently break an intended emptiness check.

### Messages

- The termination of a message is subject to its content:
  - Messages announcing an operation in progress must end with a space and three periods; e.g. `'Registering native argument completer ...'`.
  - Messages ending with a value must separate the value from the preceding text with a colon and a space, with no terminal period; e.g. `"Theme path: ${<Path>}"`.
  - Any other message must be a sentence ending with a period, including one whose value is enclosed in parentheses; e.g. `"Failed to update npm (rc: ${LASTEXITCODE})."`.

### Output and streams

- Usage of `Write-*` commands should be consistent with the type of information they are intended to convey:
  - `Write-Host`  
    Writes to the host.  
    For user-facing console UX; it must never be used to emit data a caller might capture as it bypasses the pipeline.  
    Output can be suppressed by passing `Ignore` to the `-InformationAction` common parameter; passing `SilentlyContinue` does not suppress output.  
    From Windows PowerShell 5.0, also writes to the *Information* stream.
  - `Write-Output`  
    Writes to the *Success* stream (`#1`).  
    The default stream for successful results and passing objects through the PowerShell pipeline. Connected to `stdout` for native applications.
  - `Write-Error`  
    Writes to the *Error* stream (`#2`).  
    The default stream for error results. Errors written to the stream are added to the `$Error` automatic variable. Connected to `stderr` for native applications.  
    Output is controlled by the `$ErrorActionPreference` variable and the `-ErrorAction` common parameter.
  - `Write-Warning`  
    Writes to the *Warning* stream (`#3`).  
    For error conditions less severe than those written to the *Error* stream; e.g. recoverable anomalies.  
    Output is controlled by the `$WarningPreference` variable and the `-WarningAction` common parameter.
  - `Write-Verbose`  
    Writes to the *Verbose* stream (`#4`).  
    For messages to troubleshoot commands.  
    Output is controlled by the `$VerbosePreference` variable and the `-Verbose` common parameter.
  - `Write-Debug`  
    Writes to the *Debug* stream (`#5`).  
    For messages to debug commands.  
    Output is controlled by the `$DebugPreference` variable and the `-Debug` common parameter.
  - `Write-Information`  
    Writes to the *Information* stream (`#6`).  
    For messages to convey what a script is doing. Messages are written to the host console only when the effective preference is `Continue`; the default is `SilentlyContinue`.  
    Output is controlled by the `$InformationPreference` variable and the `-InformationAction` common parameter.  
    *Added: Windows PowerShell 5.0*
  - `Write-Progress`  
    Writes to the *Progress* stream. There is no stream number as redirection is not supported.  
    For messages to communicate progress. The convention is to build a `$WriteProgressParams` variable to splat and end with `-Completed`.  
    Output is controlled by the `$ProgressPreference` variable.
- Functions should output objects, not pre-formatted text.
- `Format-*` or `Out-*` commands must not be called inside data-producing functions.  
  Display formatting must be provided by a view definition in a format file, selected by a type name stamped on the object (see [View definitions](#view-definitions)).
- Results must be emitted by either:
  - An explicit `return <Value>` statement (preferred for the final result).
  - Pipeline output from a `Process` block (for functions supporting pipelines).
- `-Verbose:$false` should be passed to a command whose verbose output is not useful to the caller; e.g. `Get-CimInstance`, `Import-Module`.

### Parameter passing

- Parameters must be passed by explicit name, never positionally; e.g. `Get-Command -Name 'Get-*'` instead of `Get-Command 'Get-*'`.  
  *PSSA* rule: `PSAvoidUsingPositionalParameters`
  - The following commands have partial exemptions to this rule:
    - `ForEach-Object`  
      The script block may be passed positionally.
    - `Where-Object`  
      The script block (in script block form) or property name (comparison statement form) may be passed positionally.
    - `Write-Host`  
      The `-Object` (message) argument may be provided positionally, after any named arguments.
  - The *PSScriptAnalyzer* rule only fires on a call with three or more positional parameters, so it cannot be relied on for conformity.
- Common parameters must follow parameters specific to the command; e.g. `-Path 'C:\Temp' -ErrorAction 'Stop'`.
- Multiple common parameters must be provided in alphabetical order; e.g. `-ErrorAction 'Stop' -Verbose:$false`.
- When the value to a parameter of a command is provided by a format expression, it must be enclosed in parentheses.
  - Command arguments are parsed in *argument mode*; parentheses are required for correct parsing.
    - If the operator is parsed as a parameter but cannot be bound, a `ParameterBindingException` will be thrown.  
      The exception cause can be either a matching parameter not being found or the parameter to bind being ambiguous.
    - If the operator is parsed as a parameter and bound, the template string and expression object(s) are used as value(s).  
      The template string binds as the previous parameter's value and the expression object(s) as the `-f` parameter's value(s).
    - With a `ValueFromRemainingArguments` parameter (positional or named) the entire format expression is used as values.
  - Keywords that take a pipeline are parsed in *expression mode*; if providing a command, *argument mode* rules apply.  
    The specific keywords that have this behaviour are `throw`, `return`, and `exit`.

### Path handling

- Some `-Path` parameters are not file system paths at all; e.g. a directory-service DN.
- Different directory separator characters must be handled correctly where supported by the platform.  
  E.g. Windows supports both `/` (Unix-like) and `\` (DOS-like), including using both in a single path.
  - The idiom is to use a `$DirSepChars` variable assigned the supported directory separator characters:  
    `$DirSepChars = [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar`
- Directory paths added to a path list, or compared to other paths, must be normalised.  
  The normalisation must use the `[IO.Path]::GetFullPath(<Path>).TrimEnd($DirSepChars)` form.
  - The path must already be fully qualified; `GetFullPath` resolves a relative path against the current working directory of the process.  
    This is not the same as the current working directory of PowerShell itself; it refers to the operating system process working directory.
  - A root path must not be trimmed as removing the trailing directory separator will turn the path into a drive-relative path; e.g. `C:`.
- When combining a wildcard with a literal path, the literal portion must be escaped.  
  The escaping must use the `[WildcardPattern]::Escape(...)` method.
- When providing a verbatim path to a command, `-LiteralPath` must be used when available.  
  Most commands treat `[ ] ? *` characters as wildcards with `-Path`; i.e. a filename containing any will silently fail to match.
  - `Join-Path` and `New-Item` do not expose `-LiteralPath`, so they necessarily use `-Path`.
  - `Get-ChildItem` may require usage of `-Path` under Windows PowerShell 5.1; see the behaviour notes below.
- Where a path must refer to a directory or a file, the idiom is:
  - The path is retrieved with `Get-Item -LiteralPath <Path> -Force -ErrorAction 'Ignore'`.  
    Without `-Force`, a hidden directory or file will be reported as inaccessible.
  - The type of the retrieved result is tested against `[IO.DirectoryInfo]` or `[IO.FileInfo]`.
  - On retrieval or type checking failure, the error message is (or the equivalent for a file):  
    `<Subject> path is inaccessible or not a directory: <Path>`
- Where only the existence of a path is relevant, the idiom is:
  - The existence of the path is tested with `Test-Path -LiteralPath <Path> [-PathType '<Type>']`.  
    When testing a file system path, the `-PathType` parameter must be specified.
- The result from `$PWD` or `Get-Location` must not be assumed to point to a valid file system path.
  - PowerShell supports drive providers which represent more abstract resources.  
    E.g. a Windows registry or LDAP path could be the current working directory.
  - `$ExecutionContext.SessionState.Path.CurrentFileSystemLocation` must be used instead.  
    Its usage can be especially important when handling relative file system paths.
- A path to a resource accompanying a script or module must be built from `$PSScriptRoot` with `Join-Path`.  
  The current location, as obtained from `$PWD` or `Get-Location`, bears no relation to the code's location.
  - `$PSScriptRoot` resolves to the directory of the file in which the executing code was defined.  
    Inclusive of the case where a function is invoked after dot-sourcing the file where it's defined.
  - `$PSScriptRoot` is an empty string when the code was not loaded from a file; e.g. entered at the prompt.
- Some commands have surprising or buggy behaviour under certain PowerShell versions:
  - `Get-ChildItem`
    - `-Path` is sometimes deliberate: Windows PowerShell 5.1 silently ignores `-Include` and `-Exclude` when combined with `-LiteralPath`, returning every item unfiltered, with or without `-Recurse`.
    - `-Path` filters a bare directory path directly with `-Exclude`, but `-Include` filters only when the path ends in a wildcard or `-Recurse` is given; a bare directory path with `-Include` returns nothing.
  - `New-Item`
    - `-Path` does not glob when `-Name` is not specified, so a literal name containing `[ ] ? *` characters is created verbatim.  
      The value must not be escaped with `[WildcardPattern]::Escape(...)`; the escape characters become part of the created name.

### Strings and quoting

- Strings must be single-quoted unless they require variable interpolation or subexpressions.  
  *PSSA* rule: `PSAvoidUsingDoubleQuotesForConstantString`
  - A simple variable must be interpolated with brace-delimited substitution; i.e. `"${<Name>}"`.
  - Member, index, method, or other expression access must be interpolated with a subexpression; e.g. `"$($<Item>.FullName)"`.
  - The `-f` format operator should be reserved for complex composition (e.g. format specifiers) or cases that read more cleanly as a template.
  - Escape sequences (e.g. `` `n ``) may be used with double quotes but their usage is discouraged.  
    Separate statements, a here-string, or `[Environment]::NewLine` for the platform line ending should be preferred.
  - The newline escape sequence is a bare line feed (`LF`); it never inserts a carriage return (`CR`).
- The `''` literal must be used for an empty string, never `[String]::Empty`; the latter has subtle pitfalls:
  - It is a static member resolved at runtime; `''` is a compile-time literal.
  - It cannot be used anywhere a constant is required; e.g. attribute arguments.
  - It can introduce parsing ambiguity with command arguments, requiring non-obvious addition of parentheses.
- String parameter values must be quoted; e.g. `-MemberType 'NoteProperty'`, `-ChildPath "System\${<Name>}"`.  
  A permitted exemption is `Where-Object` usage in comparison statement form: the property name need not be quoted.

### View definitions

- The `<Name>` element of each `<View>` definition should equal its `<TypeName>` under `<ViewSelectedBy>`.
  - Synthesised display types should use a stable, dotted Pascal case name in a project-specific namespace.
    - The convention is to use `<Namespace>.<Area>.<Function>`, omitting hyphens and the `Get` verb.
    - The producing function stamps the object using `$<Object>.PSObject.TypeNames.Insert(...)`.
- When choosing the type of control, a view should use:
  - `<ListControl>` for single rich result objects.
  - `<TableControl>` for flat record or collection views.
- When configuring the items and columns in a view:
  - A property being displayed without modification must use `<PropertyName>`.
  - A computed value must use `<Label>` with `<ScriptBlock>`, with the label being the name of the property.
  - The header of a column which displays a property without modification must not have a label; i.e. `<TableColumnHeader />`.
- When writing a `<ScriptBlock>` element:
  - A script block consisting of a single expression must be written on one line with its element.
  - Any other script block must be written across multiple lines, with its content indented one level from its element.
    - The first statement must assign `$PSItem`, or the property being formatted, to a named variable.
    - The first statement must be followed by a blank line.
- A function which returns a `PSCustomObject` for display requires:
  - A type name stamped on the object.
  - A matching `<View>` definition in the format file.
  - Property names in the view definition consistent with those the function emits.
- Validation for correctness must be performed against:
  - The XML schema definition for the XML document.  
    Validation can be performed by manual review or explicit validation against the schema.
  - This style guide for embedded PowerShell snippets.  
    *PSScriptAnalyzer* cannot be used as it does not support analysis of script blocks embedded in XML format files.

Error handling
--------------

### Choosing the mechanism

- The reporting mechanism must match the failure's blast radius.
- For per-item failures where the batch should continue, a non-terminating error must be emitted with:
  - `Write-Error` (simple functions)
  - `$PSCmdlet.WriteError(...)` (advanced functions)  
    The `Write-Error` command must not be used in advanced functions.
- For non-resumable failures where further processing should halt, a terminating error must be emitted with:
  - `throw` (simple functions)
  - `$PSCmdlet.ThrowTerminatingError(...)` (advanced functions)  
    The `throw` statement must not be used in advanced functions; it attributes the error to the `throw` site rather than to the command.

### Constructing an `ErrorRecord`

- The four-argument `[Management.Automation.ErrorRecord]` constructor must be used with:
  - A meaningful `Exception`.
  - A stable Pascal case error identifier callers can match.
  - The most specific `[Management.Automation.ErrorCategory]` value.
  - The offending `TargetObject` (use `$null` when there is no target object).
- The local variables storing exception data should be named:
  - `$ExcMsg`  
    Exception message
  - `$ErrExc`  
    Exception
  - `$ErrCat`  
    Category
  - `$ErrRec`  
    Record
- The constructor must be on a single line with the exception and category extracted into locals first.  
  E.g. `$ErrRec = [Management.Automation.ErrorRecord]::new($ErrExc, 'WidgetNotFound', $ErrCat, $Path)`.
- When choosing the error identifier:
  - An established error identifier should be reused where the class of failure matches, together with its exception type and category.
  - A new identifier which is specific to a subject should be prefixed with the subject; e.g. `AD`, `Aws`, `Csv`.
- An exception which wraps a caught exception must be constructed with the caught exception as the inner exception.
  - The message must end with the message of the caught exception, separated from the description by a colon and a space.  
    I.e. `"<Description>: $($PSItem.Exception.Message)"`.

### Specific exception type requirements

- `[ArgumentException]`
  - The second argument to the constructor must be the name of the parameter.
- `[ComponentModel.Win32Exception]`
  - The parameterless constructor must be used; it captures the last Win32 error code set by the failed call.
  - The imported function must declare `SetLastError = true` in its `DllImport` attribute; without it the error code read is stale.
  - A failed platform invocation must be reported with:
    - Exception: `ComponentModel.Win32Exception`
    - Error ID: `Win32ApiFailed`
    - Error category: `InvalidResult`
    - Target object: `$null`
- `[Management.Automation.CommandNotFoundException]`
  - The `CommandName` property must be assigned the name of the missing command.

### `try`, `catch`, `finally`

- Commands which may return non-terminating errors must be passed `-ErrorAction 'Stop'` and wrapped with `try`.  
  A permitted exemption is when all anticipated failures do not require error handling or further processing to halt.
- Specific exception types should be caught most-derived-first when recovery is dependent upon the exception type.
- When surfacing a caught error, `$PSCmdlet.ThrowTerminatingError($PSItem)` must be used to preserve its origin.
- If re-throwing an exception (only permitted in simple functions), `throw` or `throw $PSItem` must be used.
- Where the handling of a caught error depends on its identifier, it must be matched using `switch -Regex ($ErrRec.FullyQualifiedErrorId)`.
  - Each pattern must be anchored to the start and include the trailing comma; i.e. `'^<Identifier>,'`.  
    For an error raised by a command, the fully qualified identifier is the identifier, a comma, and the command's source.
    - For a compiled cmdlet, the command source is the implementing .NET type.  
      E.g. `DriveNotFound,Microsoft.PowerShell.Commands.GetItemCommand`.
    - For a script function, the command source is the function name.  
      E.g. `WidgetNotFound,Get-Widget`.
  - An error not raised by a command has no comma or suffix, and must be matched with `'^<Identifier>$'`.  
    E.g. `RuntimeException` for a division by zero and `FormatException` for a failed .NET method call.
  - The `default` arm should raise the error again or at least output the error information.
- An error which has been handled should be removed from the error history with `$Error.RemoveAt(0)`.
  - The handled error must be at index `0` at the point of removal.  
    I.e. the removal should precede any command in the `catch` block which may itself write an error record.
- .NET method failures surface as a `MethodInvocationException`; the cause is the `$PSItem.Exception.InnerException` nested exception.
- Empty `catch` blocks must not be used; an intentionally tolerated error requires at least a `Write-Verbose` or `Write-Debug` with an explanation.  
  *PSSA* rule: `PSAvoidUsingEmptyCatchBlock`
- If a `catch` block runs additional commands and still needs the original error afterwards, it should be stored in a local variable on the first line.
- A `finally` block should be used to release any acquired or mutated resource; e.g. file handles, pushed locations.  
  The block runs on success, caught errors, uncaught propagation, and on `return`, `break`, and `continue` statements.
  - Variables referenced in the `finally` block must be assigned before the `try` block; e.g. `$null` for a resource not yet acquired.  
    The block also runs when the `try` block fails before the assignment, where referencing an unassigned variable is a strict mode error.
    - Resources must be released in the reverse order of their acquisition.
    - A variable which will reference a disposable resource must be assigned `$null` before the resource is acquired.
    - A COM object must be released with `[Runtime.InteropServices.Marshal]::ReleaseComObject(...)`, discarding the returned reference count.
- Temporary state changes must occur inside a `try` block whose `finally` block restores the original values captured before the change.
  - The saved value is named `$Original<Name>`; e.g. `$OriginalErrorActionPreference`, `$OriginalOutputEncoding`.
  - An environment variable which did not exist is restored by assigning `$null`, which removes it.

### `-ErrorAction` versus `$ErrorActionPreference`

- Control flow must not branch on `$?`; it merely reflects whether the last command considered itself successful and is easily overwritten.
- `-ErrorAction` affects only non-terminating errors; it does not suppress statement-terminating errors raised by `$PSCmdlet.ThrowTerminatingError(...)`.  
  To suppress and continue past such an error, `$ErrorActionPreference` should be scoped to the smallest possible block and restored in a `finally` block.
- A per-call `-ErrorAction` should be used when available; `$ErrorActionPreference` applies to every command and callback invoked within the scope.
- `$ErrorActionPreference` must not be set at script or module scope as a blanket policy, and a mutated value must be restored as soon as possible.
- To suppress non-terminating errors `-ErrorAction 'Ignore'` should be used over `'SilentlyContinue'`, absent a reason to keep the record:
  - `Ignore` discards the error outright; i.e. it is not appended to the `$Error` array nor a variable specified through `-ErrorVariable`.
  - `SilentlyContinue` still appends to the `$Error` array and `-ErrorVariable`.
- Some `ActionPreference` values are only available in later PowerShell versions:
  - `SilentlyContinue`, `Stop`, `Continue`, and `Inquire`  
    *All versions*
  - `Ignore`  
    *Added: Windows PowerShell 3.0* (`-ErrorAction`)  
    *Added: PowerShell 7.0* (`$ErrorActionPreference`)
  - `Suspend`  
    *Added: Windows PowerShell 4.0*  
    *Removed: PowerShell 6.0*  
    Only valid with workflows.
  - `Break`  
    *Added: PowerShell 7.0*
- Assignment of `Ignore` to `$ErrorActionPreference` may result in incorrect behaviour subject to the PowerShell version.  
  Passing `Ignore` as the value to the `-ErrorAction` common parameter behaves correctly across all PowerShell versions.
  - PowerShell 7 or later correctly handles assignment of `Ignore` in all scopes.
  - Windows PowerShell 5.1 correctly handles assignment of `Ignore` when the variable holds it as a `[String]`.  
    This is the case for an untyped assignment which creates a new variable in a child scope:
    - A function body or script block.
    - A script invoked from a session, by path or via the call operator (`&`).
  - Windows PowerShell 5.1 rejects `Ignore` when the variable holds it as a `[Management.Automation.ActionPreference]`:
    - Assignment to the global variable from any scope, including via the `$Global:` qualifier from a child scope.
    - Assignment in a child scope with an explicit `[Management.Automation.ActionPreference]` type.
    - A top-level assignment in a script started with the `-File` parameter to `powershell.exe`.

### Native commands and `$LASTEXITCODE`

- A function which requires a native command must verify it is available before any other processing.  
  I.e. `if (!(Get-Command -Name '<Command>' -ErrorAction 'Ignore'))`.
  - If the command is not found and this is a fatal condition, a terminating error must be emitted with:
    - Exception: `Management.Automation.CommandNotFoundException` (see [Specific exception type requirements](#specific-exception-type-requirements))
    - Error ID: `NativeCommandNotFound`
    - Error category: `ObjectNotFound`
    - Target object: `<Command>`
  - The exception message should be `Unable to <Action> as <Command> command not found.`.  
    Where the command was expected at a path, the path follows a colon in place of the period.
- A non-zero exit code from a native command is not a PowerShell error:
  - It does not throw.
  - It is not caught by `try` / `catch`.
  - It is not escalated by `$ErrorActionPreference = 'Stop'`.  
    This behaviour can be changed in PowerShell 7.4 and later via the `$PSNativeCommandUseErrorActionPreference` preference variable.
- `$LASTEXITCODE` should be checked after every native command invocation and acted upon, absent a clear reason not to.  
  E.g. a native command shim that forwards its arguments verbatim and leaves `$LASTEXITCODE` for its caller to inspect.
  - The exit code must be read immediately after each invocation; a subsequent native command invocation replaces the value.
  - Where a command defines non-zero exit codes which are not failures, the check must enumerate the acceptable codes; e.g. `$LASTEXITCODE -notin <Codes>`.  
    A range comparison must not be used as it treats a negative exit code as acceptable; e.g. `-1073741510` from a process terminated by Ctrl+C on Windows.
  - The meaning of each acceptable exit code must be stated in a comment preceding the check, or by a reference to the documentation defining them.
  - A non-zero exit code which warrants distinct handling may be dispatched with a `switch`, whose `default` arm reports the exit code as unexpected.
- An unexpected exit code must be reported as an error with:
  - Exception: `Exception`
  - Error ID: `NativeCommandFailed`
  - Error category: `InvalidResult`
  - Target object: `<Command-line>` (see [Command invocation](#command-invocation))
- The exception message for reporting an unexpected exit code must take one of two forms (see [Messages](#messages)):
  - `Failed to <Action> (rc: <ExitCode>).`  
    A trailing value may follow the parenthetical, separated by a colon and a space, in place of the period.
  - `<Command> exited with <Qualifier> exit code: <ExitCode>`  
    Context may be inserted before the colon; e.g. `<Command> exited with <Qualifier> exit code <Action>: <ExitCode>`.
    - The qualifier is `non-zero` where every non-zero exit code is a failure.
    - The qualifier is `unexpected` where the command defines non-zero exit codes which are not failures.

Functions and parameters
------------------------

### Function design

- Function attribute stack order must be:
  - `[Diagnostics.CodeAnalysis.SuppressMessage(...)]` (optional)
  - `[CmdletBinding(...)]` (advanced functions)
  - `[OutputType(...)]`
  - `Param(...)`
- Simple function conventions:
  - Should only be used when exclusive usage of named parameters is not possible.  
    E.g. native command shims which splat `$args` and host-fixed contracts such as the `Prompt` function.
  - Must declare `[OutputType(...)]` and a `Param(...)` block, even if the function takes no custom parameters.
- Advanced function conventions:
  - `[CmdletBinding(...)]` marks the script or function as *advanced* which:
    - Adds the common parameters; e.g. `-ErrorAction`, `-OutVariable`, `-Verbose`.
    - Exposes the `$PSCmdlet` variable (type: `Management.Automation.PSScriptCmdlet`).
    - Removes the `$args` variable and rejects unknown arguments at bind time.
  - Must declare `[CmdletBinding(...)]`, `[OutputType(...)]`, and a `Param(...)` block, even if the function takes no custom parameters.  
    Declaring `[CmdletBinding(...)]` without an associated `Param(...)` block is a parse-time error.
- A function which is only used by one other function may be nested within it.
  - Nested functions must be defined at the start of the body of the enclosing function, preceding all other statements.
  - Nested functions must have the complete attribute stack.
  - Nested functions must not be declared in the global scope.

### Function naming

- Every function must be named using the `<Verb>-<Noun>` naming convention; e.g. `Update-PowerShell`.  
  The only exemption is functions whose name is dictated outside of PowerShell; e.g. native command shims.
- Function names must never match a language keyword; e.g. `function`, `process`, `throw`.  
  *PSSA* rule: `PSAvoidReservedWordsAsFunctionNames`
  - A function named for a keyword which can begin a statement (e.g. `if`) cannot be invoked by its bare name.
  - A function named for any other keyword (e.g. `catch`) parses and invokes, but remains prohibited.
  - The *PSScriptAnalyzer* rule has an incomplete list of keywords (*verified on v1.25.0*).
- Verbs should be from the approved set; i.e. as returned via `Get-Verb`.  
  *PSSA* rule: `PSUseApprovedVerbs`  
  [Approved Verbs for PowerShell Commands](https://learn.microsoft.com/en-au/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands)
  - By extension, verbs should never be a reserved verb or an unapproved synonym; e.g. `Create` instead of `New`.
    - The reserved verbs are `ForEach`, `Ping`, `Sort`, `Tee`, and `Where`.
    - Reserved verbs are defined only by the linked documentation; `Get-Verb` has no output identifying a verb as reserved.
  - The PowerShell language and a select few commands use reserved verbs in exceptional circumstances; e.g. `Sort-Object`.
  - `Get-Verb` returns `Ping` in the `Diagnostic` group but its usage is deprecated; it must be treated as not permitted.
- Nouns should be singular; the PowerShell convention is to avoid plural nouns.  
  *PSSA* rule: `PSUseSingularNouns`
  - Where the rule is excluded, a plural noun is permitted without further justification; the exclusion is the project's decision.
- Function names must never match a built-in alias; e.g. `select`, `tee`, `where`.  
  A function named for an alias cannot be invoked by its bare name as aliases outrank functions.
- Function names should be namespaced with a domain or product prefix, if applicable.
- Manual review is required to ensure full compliance with the naming constraints.

### Parameter definition

- All parameters must be strongly typed.
  - A permitted exemption is a parameter whose type is defined by a module which may not be loaded when the function is defined.
    - The parameter must be declared as `[PSObject]`, or `[Array]` for a collection, with the type stated in a trailing comment.  
      E.g. `` [PSObject]$<Name> # `<Namespace>.<Type>` ``.
    - The value must be validated once the module is imported, with failure reported as:
      - Exception: `ArgumentException` (see [Specific exception type requirements](#specific-exception-type-requirements))
      - Error ID: `PSInvalidType`
      - Error category: `InvalidType`
      - Target object: `$<Name>`
    - The exception message should be `Unexpected type for <Name> argument: <TypeName>`.
- Parameters must be declared in a `Param(...)` block, never inline in the function declaration.  
  *PSSA* rule: `PSUseConsistentParametersKind` (option: `ParametersKind`)
- Default values for parameters must be added inline; i.e. `[Type]$<Name> = <Default>`.
- `Mandatory` must be added to the `[Parameter(...)]` attribute for required parameters.
  - Mandatory parameters must not have a default value; the value can never be used.  
    *PSSA* rule: `PSAvoidDefaultValueForMandatoryParameter`
- `DontShow` must be added to the `[Parameter(...)]` attribute for internal parameters.  
  The parameter will be excluded from tab completion and *IntelliSense*.
- Boolean parameter attribute arguments must use the bare form.  
  I.e. `[Parameter(Mandatory)]` instead of `[Parameter(Mandatory = $true)]`.
- Parameter values must be constrained using validation attributes (see [Parameter validation attributes](#parameter-validation-attributes)).
  - Each validation attribute must be placed on its own line below the `[Parameter(...)]` attribute and above the `[Type]$<Name>` declaration.
  - Manually validating parameters and raising a terminating error must only be performed when validation cannot be handled by a validation attribute.
- Flags must use the `[Switch]` type; a switch parameter must never default to `$true` (`$false` is the default) and must never be positional.  
  *PSSA* rule: `PSAvoidDefaultValueSwitchParameter`
- Credentials must use the `[PSCredential]` type with the `[Management.Automation.Credential()]` attribute (see [Security](#security)).  
  An optional credential parameter must also have the `[ValidateNotNull()]` attribute to reject an explicit `$null` argument.
  - The attribute causes the credential transformation to run on a `$null`, so an interactive host prompts for credentials rather than failing.  
    A cancelled prompt yields `$null`, which the attribute then rejects; a non-interactive host fails with a `ParameterArgumentTransformationError`.
- `$PSBoundParameters.ContainsKey('<Param>')` must be used when testing for presence rather than value.  
  Testing for a parameter with `if ($<Param>) { ... }` is ambiguous for falsy values.

### Dynamic parameters

- Dynamic parameters must only be used where aspects of their definition can only be determined at runtime.  
  E.g. parameters only valid for certain platforms, or where the set of valid values is platform-specific.
- Defining a `DynamicParam` block requires the function body be defined in named blocks; e.g. `Process`.  
  This applies even if pipeline input is not supported; in that case the function body can reside entirely in an `End` block.
- The dictionary returned by the `DynamicParam` block must be named `$RuntimeParams`.

### Parameter sets

- Parameter set names are case-sensitive and must be referenced with identical casing.  
  *PSSA* rule: `PSUseConsistentParameterSetName`
- When parameter sets are defined, each parameter set must have a discriminating parameter.
- Behaviour which differs by parameter set must branch on `$PSCmdlet.ParameterSetName`.
- `DefaultParameterSetName` must be added to `[CmdletBinding(...)]` whenever a valid call could otherwise leave the parameter set ambiguous.  
  Not required when every parameter set is distinguished by a unique `Mandatory` parameter.
- In `[Parameter(...)]` attributes naming a parameter set, the `ParameterSetName` value must be placed first; i.e. before any `Mandatory` or pipeline-binding arguments.

### Parameter validation attributes

- All parameters
  - `[ValidateCount(<Min>, <Max>)]`  
    Minimum and maximum number of arguments for a cmdlet parameter.
  - `[ValidateDrive(...)]`  
    Set of allowed drives for a path argument to a cmdlet parameter.  
    *Added: Windows PowerShell 5.1*
    - If a relative path is provided the current drive must be in the allowed list.
  - `[ValidateLength(<Min>, <Max>)]`  
    Minimum and maximum number of characters for a cmdlet parameter argument.
  - `[ValidateNotNullOrEmpty()]`  
    Parameter cannot be `$null`, an empty string, an empty collection, a collection containing empty strings or null elements, or an empty hashtable.
  - `[ValidateNotNullOrWhiteSpace()]`  
    As per `ValidateNotNullOrEmpty` and also cannot be a string containing only whitespace or a collection containing strings containing only whitespace.  
    *Added: PowerShell 7.4*
  - `[ValidatePattern('<Regex>')]`  
    Regular expression pattern that validates the arguments of a cmdlet parameter.
  - `[ValidateRange(<Min>, <Max>)]` / `[ValidateRange('<ValidateRangeKind>')]`  
    Minimum and maximum values for a cmdlet parameter argument.  
    *Added: PowerShell 6.0* (`ValidateRangeKind` form)
  - `[ValidateScript({...})]`  
    Script that is used to validate a parameter or variable value.
    - A `$null` argument is rejected; the script block never runs for it.
  - `[ValidateSet(...)]`  
    Set of possible values for a cmdlet parameter argument.
    - Additionally enables tab completion for the specified values.
  - `[ValidateUserDrive()]`  
    Validates that the path argument to a cmdlet parameter is on the `User` drive.  
    *Added: Windows PowerShell 5.1*
    - If a relative path is provided the current drive must be `User` in *Just Enough Administration* sessions.
- Mandatory parameters
  - `[AllowEmptyCollection()]`  
    Allows an empty collection as the argument to a mandatory collection parameter.
  - `[AllowEmptyString()]`  
    Allows an empty string as the argument to a mandatory string parameter.
  - `[AllowNull()]`  
    Allows `$null` as the argument to a mandatory parameter.
    - Ineffective with the `[String]` type as `$null` is implicitly converted to the empty string.
- Optional parameters
  - `[ValidateNotNull()]`  
    Validates the parameter's argument is not `$null`.
    - Does not apply to types which implicitly convert from `$null`; e.g. `[String]`.

### `Mandatory` versus `[ValidateNotNullOrEmpty()]`

- The correct choice depends on the parameter type and whether it is mandatory or optional.
- `Mandatory` parameters:
  - Reject `$null`, except where the type coerces a null value.  
    E.g. an `[Int]` coerces `$null` to `0`, which is not rejected.
  - Reject an empty array for a collection.
  - Reject an empty string for a scalar `[String]`.
  - Reject any `$null` or empty string element inside a `[String[]]`.
  - Accept an empty hashtable for a `[Hashtable]`.
- `[ValidateNotNullOrEmpty()]` has the same behaviour as `Mandatory` and also rejects an empty hashtable.
- An optional `[String[]]` parameter accepts `$null`, an empty array, and an array with empty or null elements.
- On a mandatory `[String]` or `[String[]]` parameter the `[ValidateNotNullOrEmpty()]` attribute is redundant.
- On any `[Hashtable]` parameter the `[ValidateNotNullOrEmpty()]` attribute is required to reject an empty hashtable.

### `ShouldProcess` usage

- Commands that modify system state should declare `SupportsShouldProcess` in their `[CmdletBinding(...)]` attribute.  
  *PSSA* rule: `PSUseShouldProcessForStateChangingFunctions`
- `WhatIf` and `Confirm` parameters must never be declared manually; `SupportsShouldProcess` provides them.  
  *PSSA* rule: `PSUseSupportsShouldProcess`
- Each mutation should be guarded by a call to `$PSCmdlet.ShouldProcess(...)` placed as close to the change as possible.
  - The `$PSCmdlet.ShouldProcess(<Target>, <Action>)` method overload should be used for message uniformity.
  - The `Target` argument must be a noun phrase, name, or path which identifies what will be changed.
  - The `Action` argument must be a verb or verb phrase in sentence case; e.g. `Clear`, `Remove`, `Update`.
- `ConfirmImpact = 'High'` should be set in the `[CmdletBinding(...)]` attribute for destructive operations.
  - A high-impact function which must be automatable should add `[Switch]$Force` and lower `$ConfirmPreference`.  
    I.e. set `$ConfirmPreference` to `'None'` when `-Force` is provided and `-Confirm` was not bound.
- Processing which does not change state (e.g. validation) should still be performed when `-WhatIf` is specified.  
  For native commands that can simulate a change, the command should be invoked in that mode.
- A command which is relied upon to evaluate `-Confirm` and `-WhatIf` itself must be annotated with a comment.
- A command which incorrectly implements `-WhatIf` must be guarded by `$PSCmdlet.ShouldProcess(...)`, with a comment stating the defect.

### `OutputType` attribute

- The `[OutputType(...)]` attribute is purely metadata; it neither validates nor coerces output at runtime.  
  *PSSA* rule: `PSUseOutputTypeCorrectly`
  - As the declared output type can be incorrect with no runtime impact, extra care must be taken to ensure it correctly states the return type(s).
- `[OutputType(...)]` must be declared for all functions and standalone scripts.
  - The attribute must be placed immediately before the `Param(...)` block (simple functions) or after the `[CmdletBinding(...)]` attribute (advanced functions).
  - Pure side-effect functions (i.e. those that return no object) must be declared as emitting `[Void]`; i.e. `[OutputType([Void])]`.
  - Functions which may emit nothing must be declared as a union with `[Void]` placed first; i.e. `[OutputType([Void], ...)]`.
- Declared types must be expressed as a `[Type]` literal by default (e.g. `[OutputType([String])]`), not as a type-name string (e.g. `[OutputType('String')]`).
  - The first argument selects the attribute's constructor overload, so the two forms must not be mixed in one attribute.
    - A `[Type]` literal as the first argument requires every later argument to resolve as a type; a later string which is not a type name fails at invocation.
    - A type-name string as the first argument stores every later argument as a name; a later `[Type]` literal is stored as its type name.
  - An exemption to the required usage of `[Type]` literals is referencing a type in a module that may not be loaded when the attribute is resolved.  
    `[Type]` literals are resolved when the function is invoked, not when it is defined, and will throw an exception if the type is not yet loaded.
    - A commented-out attribute or `PSUseOutputTypeCorrectly` suppression with a stand-in type must not be substituted for the type-name string form.
- Types in the `System` namespace must have the `System.` prefix omitted in type-name strings, just as in a literal; e.g. `'Void'`, not `'System.Void'`.
- For per-parameter set output, `[OutputType(ParameterSetName = '...', ...)]` must be declared for each set, with `ParameterSetName` first.
- Declaring `[OutputType([PSCustomObject[]])]` but returning a bare array (i.e. `@()`) will result in a *PSScriptAnalyzer* finding due to a type mismatch.  
  A bare empty array is an `[Object[]]`; results must instead be accumulated in a `[Collections.Generic.List[PSCustomObject]]` and returned with `.ToArray()`.

### Pipeline input

- The `Begin` block must be used for one-time setup; e.g. building a `$CommonParams` splat.
- The `Process` block must be used for per-item work; i.e. processing each pipelined object.  
  *PSSA* rule: `PSUseProcessBlockForPipelineCommand`
- The `End` block must be used for finalisation work; e.g. post-processing on the complete results before returning.
- For pipeline input at least one parameter must be declared with `ValueFromPipeline` or `ValueFromPipelineByPropertyName`.
  - `ValueFromPipeline` should be used when the whole object is consumed.
  - `ValueFromPipelineByPropertyName` should be used when binding from a property.  
    The `[Alias(...)]` attribute can optionally be used in conjunction with it.
  - At most one parameter per parameter set may declare `ValueFromPipeline`.  
    *PSSA* rule: `PSUseSingleValueFromPipelineParameter`
- Pipeline parameters should be typed as an array so the function can also be called directly with a whole collection.  
  The collection must be iterated with a `foreach` in the `Process` block so both call styles work.
- On a single bad element, the command should call `$PSCmdlet.WriteError(...)` and subsequently `continue` rather than aborting the entire batch.
- Results can be emitted using one of two approaches:
  - Emitted from `Process` as each is produced, so the pipeline streams (*preferred*).
  - Accumulated in a typed `[Collections.Generic.List[T]]` created in `Begin` and returned in `End` with `$<Collection>.ToArray()`.  
    This prevents streaming of results, but is necessary where the complete input is required; e.g. a sorted or aggregate result.

### Comment-based help

- Comment-based help must be provided for functions exported from a module.  
  *PSSA* rule: `PSProvideCommentHelp` (option: `ExportedOnly`)
- Help definitions must use a comment block (i.e. `<# ... #>`), not per-line comments (i.e. `#`).  
  *PSSA* rule: `PSProvideCommentHelp` (option: `BlockComment`)
- The comment block must be placed at the start of the function body (i.e. the begin position, before the attribute stack) and all help lines kept contiguous.  
  *PSSA* rule: `PSProvideCommentHelp` (option: `Placement`)
- The `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER` (per parameter), at least one `.EXAMPLE`, and `.OUTPUTS` (where applicable) sections must be provided.
- The `.INPUTS` and `.OUTPUTS` sections must name types in full (e.g. `System.Management.Automation.PSCustomObject`), as PowerShell's built-in help does.

Security
--------

- Secrets must never be hard-coded.
- Secrets should be typed as `[PSCredential]` or `[SecureString]`; `[String]` (plain text) must only be used when essential.  
  *PSSA* rule: `PSAvoidUsingPlainTextForPassword`
  - The *PSScriptAnalyzer* rule detects credential parameters by matching against common parameter names.
- Parameters named `Credential` must use the `[PSCredential]` type.  
  *PSSA* rule: `PSUsePSCredentialType`
- A username and password must never be accepted as separate parameters; accept a `[PSCredential]` instead.  
  *PSSA* rule: `PSAvoidUsingUsernameAndPasswordParams`
- `ConvertTo-SecureString -AsPlainText` must not be used; the secret is held in memory as plain text.  
  *PSSA* rule: `PSAvoidUsingConvertToSecureStringWithPlainText`
- The `[Management.Automation.Credential()]` attribute must be added to `[PSCredential]` parameters.
  - The attribute is applied implicitly to `[PSCredential]` parameters with no other argument transformation attribute; declaring it makes the behaviour visible.  
    A `[PSCredential[]]` parameter, or one with another argument transformation attribute, receives the transformation only when explicitly declaring the attribute.
    - The transformation treats a string argument as the username and prompts for the password.  
      It also prompts on `$null` when the parameter is mandatory or carries `[ValidateNotNull()]`.
  - Credentials must be captured with `Get-Credential` (username and password) or `Read-Host -AsSecureString` (secret only).
- Usage of `Invoke-Expression` should be avoided as it can trivially become a code-injection primitive.  
  *PSSA* rule: `PSAvoidUsingInvokeExpression`  
  A permitted exemption is shell integration performed by calling a command which returns a shell script to be executed.
  - The call operator with splatting, a `[ScriptBlock]`, or the applicable command or .NET API should be used instead.
  - If using the *DevSkim* analyser, calls must be suppressed by appending `# DevSkim: ignore DS104456` to the call.
- Scripts assume the caller's execution policy and must not modify it with `Set-ExecutionPolicy` from within library code.

Strict mode
-----------

- Enabling strict mode at runtime is not required, though it is encouraged for modules and scripts which will be distributed.
  - If enabled, `Set-StrictMode -Version 'Latest'` must be the first statement of the script body; i.e. immediately after the attribute stack.
- Strict mode surfaces several classes of latent bugs, not all of which *PSScriptAnalyzer* can detect, turning them into terminating errors.
- The `-Version` parameter specifies the set of conditions which cause a terminating error, with later versions including checks from previous versions.
- All code must run cleanly in strict mode, whether or not it is enabled; i.e. treat code as if `Set-StrictMode -Version 'Latest'` is in effect.
  - Compliance must be verified by exercising the representative code paths with strict mode enabled in the calling scope:
    - A standalone script which supports `ShouldProcess` may be exercised with `-WhatIf`.
    - A library function is exercised by dot-sourcing its file and invoking it after calling `Set-StrictMode`.
- The defined strict mode versions are:
  - 1.0
    - Prohibits references to uninitialised variables, except for uninitialised variables in strings.  
      Exception: `RuntimeException`, CategoryInfo: `InvalidOperation`, FullyQualifiedErrorId: `VariableIsUndefined`
      - A variable assigned only conditionally must be initialised before the point it is read.  
        E.g. a value assigned on the success path of a `try` whose `catch` may skip the assignment.
  - 2.0
    - Prohibits references to uninitialised variables, including uninitialised variables in strings.
    - Prohibits references to non-existent properties of an object.  
      Exception: `PropertyNotFoundException`, CategoryInfo: `NotSpecified`, FullyQualifiedErrorId: `PropertyNotFoundStrict`
      - If a property may be absent it should first be tested with `$null -ne $Object.PSObject.Properties['<Name>']`.
      - The check does not apply to missing hashtable keys; i.e. `$<Hashtable>['<Absent>']` still returns `$null`.  
        `$<Hashtable>.ContainsKey('<Key>')` must be used to distinguish an absent key from a `$null` value.
    - Prohibits function calls that use the syntax for calling methods.  
      Exception: `RuntimeException`, CategoryInfo: `InvalidOperation`, FullyQualifiedErrorId: `StrictModeFunctionCallWithParens`
  - 3.0 (latest)
    - Prohibits out-of-bounds or unresolvable array indexes.  
      Exception: `IndexOutOfRangeException`, CategoryInfo: `OperationStopped`, FullyQualifiedErrorId: `System.IndexOutOfRangeException` (out-of-bounds)  
      Exception: `RuntimeException`, CategoryInfo: `InvalidArgument`, FullyQualifiedErrorId: `InvalidCastFromStringToInteger` (invalid format)
      - An index which may be out of range must be compared with the array's `Count` before use.

Compatibility
-------------

### PowerShell versions

- The default requirement is that code must parse and run on Windows PowerShell 5.1 and every currently supported subsequent PowerShell version.
  - `#Requires -Version` or an explicit instruction (e.g. a project rule) can override, in which case compatibility guidance applies relative to that version.
  - Whatever the version floor, code must work from it up through every supported newer version; a lower version restricts the usage of newer constructs.
  - Raising the version floor, through `#Requires -Version` or the project default, must be an explicit change and never a side effect of using a newer construct.
- If PowerShell 6 or later is a supported target, only currently supported versions need to be considered; earlier end-of-life PowerShell versions need not be accommodated.
- Supporting both editions demands attention to commands and parameters present in one edition but not the other, and behavioural differences in the same command.
  - *PSSA* rule: `PSAvoidOverwritingBuiltInCmdlets`  
    Identifies functions which overwrite cmdlets built into targeted PowerShell platforms. Each platform is defined as:  
    `<psedition>-<psversion>-<os>`
  - *PSSA* rule: `PSUseCompatibleCmdlets`  
    Identifies cmdlets unavailable in targeted PowerShell platforms. Each platform is defined as:  
    `<psedition>-<psversion>-<os>`
  - *PSSA* rule: `PSUseCompatibleCommands`  
    Identifies commands unavailable in targeted PowerShell platforms. Each platform is defined as:  
    `<os-name>_<os-arch>_<os-version>_<ps-version>_<ps-arch>_<dotnet-version>_<dotnet-edition>`
  - *PSSA* rule: `PSUseCompatibleSyntax`  
    Identifies syntax incompatible with targeted PowerShell versions. Each version is given as `<major>.<minor>`.
  - *PSSA* rule: `PSUseCompatibleTypes`  
    Identifies types unavailable in targeted PowerShell platforms. Each platform is defined as:  
    `<os-name>_<os-arch>_<os-version>_<ps-version>_<ps-arch>_<dotnet-version>_<dotnet-edition>`
    - Compliance must be checked manually; `PSUseCompatibleTypes` covers only the types in its profiles (see [PSScriptAnalyzer](#psscriptanalyzer)).

### Syntax differences

- Syntax introduced in PowerShell 6 or later is a syntax error under Windows PowerShell 5.1 or earlier.  
  The entire file will fail to load before any runtime guard defined in the same file can be run.
- Code compatible with Windows PowerShell 5.1 or earlier must not use:
  - `Clean` pipeline blocks  
    A function body consisting solely of a `Clean` block parses as a call to a command named `Clean`.
  - Null-coalescing operators (`??`, `??=`)  
    An `if` / `else` statement must be used instead.
  - Null-conditional operators (`?.`, `?[]`)  
    An explicit `$null -ne $<Object>` comparison must be used instead.
  - Pipeline-chaining operators (`&&`, `||`)  
    Separate statements must be used instead.
  - Trailing background operator (`&`)
  - Ternary operator (`? :`)  
    An `if` / `else` statement must be used instead.
  - `` `e `` and `` `u{...} `` escape sequences  
    These escape sequences will parse, but silently yield literal text.
- If syntax introduced in PowerShell 6 or later is essential it must be either:
  - Isolated in a separate file loaded only under compatible PowerShell versions.
  - Gated by a `#Requires -Version` to block loading on incompatible versions.

### Runtime behaviour

- Cross-edition behaviour must be handled at runtime; features in newer versions must only be used behind a version or feature guard.
- For PowerShell version and edition detection, `PSEdition` and `PSVersion` in the `$PSVersionTable` hashtable should be used.
- For platform (operating system) detection, `PSEdition` and `Platform` in the `$PSVersionTable` hashtable should be used.
  - The `Platform` key is absent on Windows PowerShell 5.1 or earlier; however, the platform is implicitly always Windows.
  - On Linux and macOS the value of `Platform` is `Unix`, so cannot be used to distinguish them; use `$IsLinux` or `$IsMacOS`.
  - The `$IsLinux`, `$IsMacOS`, and `$IsWindows` automatic variables require a version guard in code targeting Windows PowerShell 5.1 or earlier.  
    These automatic variables do not exist prior to PowerShell 6.0 and will silently evaluate to `$null` (or throw an exception under strict mode).
- Features which vary between releases of a native command should be gated on the command's reported version, parsed as a `[Version]`.
  - A version which is the entire output should be converted with `[Version]::TryParse(<RawVersion>, [Ref]$<Version>)`, with failure reported as:
    - Exception: `FormatException`
    - Error ID: `VersionParseFailed`
    - Error category: `ParserError`
    - Target object: `<RawVersion>`
  - A version which is part of the output must be extracted with a regular expression and should be cast to a `[Version]`, with failure reported as:
    - Exception: `FormatException`
    - Error ID: `RegexMatchFailed`
    - Error category: `ParserError`
    - Target object: `<RawOutput>`
  - The variable passed by `[Ref]` must be assigned before the call; an unassigned variable cannot be referenced, with or without strict mode.  
    Exception: `RuntimeException`, CategoryInfo: `InvalidOperation`, FullyQualifiedErrorId: `NonExistingVariableReference`
  - The `[Version]` must be the left operand of a comparison; the right operand is converted to the type of the left operand.  
    I.e. providing a string as the left operand will yield a lexical comparison.
- Functionality unavailable on the current edition, platform, or processor architecture must be reported with a terminating error:
  - Exception: `NotSupportedException`
  - Error ID: `<Subject>NotSupported`
  - Error category: `NotImplemented`
  - Target object: `<Context>`  
    Relevant context (e.g. the current processor architecture if unsupported) or `$null`.

### `#Requires` usage

- Applies globally regardless of placement and blocks execution when the requirement is unmet.
- Must only be used in standalone scripts; for modules define requirements in the module manifest.
- `#Requires -Modules { <Module-Name> | <Hashtable> }`  
  Required PowerShell modules.  
  *Added: Windows PowerShell 3.0*
  - The supported keys in the hashtable are:
    - `ModuleName` (*required*)  
      Name of the module.
    - `GUID` (*optional*)  
      GUID of the module.
    - `ModuleVersion` (*dependent*)  
      Minimum module version.
    - `MaximumVersion` (*dependent*)  
      Maximum module version.  
      *Added: Windows PowerShell 5.1*
    - `RequiredVersion` (*dependent*)  
      Required module version.  
      *Added: Windows PowerShell 5.0*
  - At least one of `ModuleVersion`, `MaximumVersion`, or `RequiredVersion` must be provided.
  - `RequiredVersion` is mutually exclusive with the `ModuleVersion` and `MaximumVersion` keys.
- `#Requires -PSEdition <PSEdition-Name>`  
  Required PowerShell edition.  
  *Added: Windows PowerShell 5.1*
- `#Requires -PSSnapin <PSSnapin-Name> [-Version <N>[.<n>]]`  
  Required PowerShell snap-in.  
  *Added: Windows PowerShell 1.0*  
  *Removed: PowerShell 6.0*
- `#Requires -RunAsAdministrator`  
  Requires administrator privileges.  
  *Added: Windows PowerShell 4.0*
  - Ignored on non-Windows operating systems.
- `#Requires -Version <N>[.<n>]`  
  Minimum PowerShell version.  
  *Added: Windows PowerShell 1.0*
  - The statement declares a minimum, not a pinned version; blocking a later version requires a runtime guard.
  - When editing a script, its `#Requires -Version` must be read first and treated as the floor for every change.

### .NET types

- Only .NET types and members available on every PowerShell version within the supported range may be used, absent a version guard.
- New instances of .NET types must be created using the `::new(...)` constructor syntax introduced in Windows PowerShell 5.0.  
  If compatibility with earlier Windows PowerShell versions is required, the `New-Object` command must be used.
- Types in the `System` namespace must have the `System.` prefix omitted when referenced; e.g. `[Collections.Generic.List[String]]`, `[IO.FileInfo]`.
  - The only exemption is where retaining it is strictly necessary because PowerShell's own type resolution is not in use; e.g. a type name specified as a string to a .NET reflection API.
  - Comment-based help text is also exempt; types referenced in the `.INPUTS` and `.OUTPUTS` sections must have their names reproduced in full (see [Comment-based help](#comment-based-help)).
- A type compiled with `Add-Type` must be guarded so compilation occurs once per session; i.e. `if (!('<Namespace>.<Class>' -as [Type]))`.  
  Compilation is expensive and `Add-Type` rejects a redefinition of a type name which already exists in the session.

### Cmdlet changes

- CIM cmdlets (e.g. `Get-CimInstance`) must be used over WMI cmdlets (e.g. `Get-WmiObject`).  
  *Added: Windows PowerShell 3.0*  
  *PSSA* rule: `PSAvoidUsingWMICmdlet`
- `Get-Content`
  - `-AsByteStream`  
    *Added: PowerShell 6.0*  
    Replaces `-Encoding 'Byte'`, which was removed in the same release.
- `Join-Path`
  - `-AdditionalChildPath`  
    *Added: PowerShell 6.0*  
    Permits joining an indefinite number of paths; `-ChildPath` is still mandatory.

Linting
-------

### PSScriptAnalyzer

- Suppressions must be written as `[Diagnostics.CodeAnalysis.SuppressMessage('<Rule>', '')]`.
  - The second argument is the rule suppression ID; an empty string suppresses every finding of the rule within the attributed scope.
  - A non-empty ID suppresses only findings the rule has stamped with that ID; matching is exact, case-insensitive, with no wildcard support.
    - An ID which matches no finding leaves the findings unsuppressed and *PSScriptAnalyzer* reports an error for the unapplied suppression.
    - The error is reported only when the rule produced a finding in the attributed scope; a stale ID on a rule with no findings is silent.
    - Where a rule stamps an ID (e.g. `PSReviewUnusedParameter` stamps the parameter name), a single finding can be suppressed while the others remain reported.
  - The second argument is mandatory; the attribute has no single-argument constructor, so the function fails when invoked.
- Each attribute must suppress one specific rule, and suppressions must be placed at the beginning of the script or function's attribute stack.
  - For advanced functions, suppressions are placed before the `[CmdletBinding(...)]` attribute; for simple functions, before the `[OutputType(...)]` attribute.
  - A brief justification comment must be added where the reason is not evident from the function's description comment or the construct that trips the rule.
  - On a bare assignment (e.g. a variable) the suppression is silently ignored; on a non-attributable statement (e.g. `if`) it is a parse error.  
    An ignored suppression still hides the variable from `PSUseDeclaredVarsMoreThanAssignments`, which skips any attributed assignment (see the errata).
- An excluded or disabled rule means applicable code will not be flagged, not that the code is *encouraged*.  
  The convention this guide states for the construct still applies unless there is guidance which expressly relaxes it (see [Authority hierarchy](#authority-hierarchy)).
- Commonly excluded or disabled rules and their effective conventions:
  - `PSAvoidLongLines`  
    Long code lines (notably lookup tables and `-f` templates) are tolerated; comment lines remain limited to 79 characters (see [Comments](#comments)).
  - `PSAvoidUsingInvokeExpression`  
    The `Invoke-Expression` command is a code-injection hazard; avoid it unless absolutely necessary (see [Security](#security)).
  - `PSAvoidUsingWriteHost`  
    The `Write-Host` command is sanctioned only for deliberate user-facing console UX; never to emit data (see [Output and streams](#output-and-streams)).
  - `PSReviewUnusedParameter`  
    Sometimes excluded because parameters are consumed by external modules; genuinely unused parameters are not excused.
  - `PSUseConstrainedLanguageMode`  
    Constrained language mode is rarely used, or even practical, for the majority of environments in which PowerShell is used.
  - `PSUseShouldProcessForStateChangingFunctions`  
    Implementing `ShouldProcess` on state-changing functions remains a convention (see [`ShouldProcess` usage](#shouldprocess-usage)).
  - `PSUseSingularNouns`  
    Plural nouns are permitted where it is excluded (see [Function naming](#function-naming)).
- The following rules have errata:
  - `PSAvoidGlobalFunctions`
    - Analyses only module files (`.psm1`); a globally scoped function in a `.ps1` file is not a finding.
    - A finding anchored at line 1 of a `.ps1` file is spurious and intermittent (*verified on v1.25.0*).  
      The analysis must be re-run in a fresh host; the scope modifier must not be removed, nor a suppression added.
  - `PSAvoidGlobalVars`
    - A suppression cannot be attached to a variable; i.e. it must be applied to a script or function `Param(...)` block.
    - Suppression is unnecessary when referencing preferences (e.g. `$Global:VerbosePreference`) or automatic variables (e.g. `$Global:Error`).
  - `PSUseCompatibleTypes`
    - Covers attributes, `New-Object` type names, type constraints, type literals, and static members accessed through type literals.
    - Instance members are not analysed, and static methods are matched by name without regard to overloads.
    - A type absent from every profile in the profile directory is assumed to be local to the environment and is not reported.
    - Bundled profiles end at PowerShell 7.0 on .NET Core 3.1 (*verified on v1.25.0*).
  - `PSUseDeclaredVarsMoreThanAssignments`
    - Does not report a variable whose assignment carries any attribute (*verified on v1.25.0*).
      - A suppression for any rule, or a validation attribute, on the assignment silences the rule for that variable.  
        This must not be relied upon to hide a genuinely unused variable.
      - The attribute is not recorded as a suppression; i.e. `-SuppressedOnly` does not report it (*verified on v1.25.0*).
    - A type constraint on the assignment is not an attribute and has no effect (*verified on v1.25.0*).
    - A variable assigned for use by a dot-sourced file is not unused, so the attribute may be applied to its assignment.  
      The attribute must be a suppression naming `PSUseDeclaredVarsMoreThanAssignments` so the intent is documented.
- *PSScriptAnalyzer* must be invoked with `Invoke-ScriptAnalyzer -Path <File> -Settings <Name>.psd1`.  
  If the interactive profile interferes, *PSScriptAnalyzer* should be invoked in a fresh host; e.g. `pwsh -NoProfile -NonInteractive -File <Script>`.
  - Most configurable rules (i.e. those with an `Enable` key) default to disabled.  
    Default enabled rules: `PSAvoidOverwritingBuiltInCmdlets`, `PSAvoidUsingPositionalParameters`, `PSProvideCommentHelp`, and `PSUseSingularNouns`.
  - Parsing of the settings file has the following behaviour:
    - Keys are matched case-insensitively.
    - Unknown keys are silently ignored.  
      I.e. a misspelt rule name or `Enable` key leaves the rule in its default state.
    - An invalid value in a rule entry resets every option of the rule.  
      I.e. an invalid value results in the rule being silently disabled, including rules that default to enabled.
  - Validation must be against the settings file designated as authoritative.
  - There must be zero findings of any severity, including the `Information` severity.
- *PSScriptAnalyzer* reliability issues have been repeatedly observed (*verified on v1.25.0*):
  - Any per-file finding set must be treated as potentially partial; a file which causes *PSScriptAnalyzer* to crash must never be inferred to be clean.
  - If *PSScriptAnalyzer* crashes, only the rule confirmed to cause the crash should be excluded to obtain the remaining findings.  
    The code must then be manually checked for what the excluded rule checks.
  - Intermittent `NullReferenceException` crashes have been witnessed with:
    - `PSUseConsistentIndentation` on larger files; which files crash, and the total finding count, can shift from run to run.
    - Deeply indented multi-line argument lists in functions; e.g. a multi-line `[Management.Automation.ErrorRecord]::new(...)` call.
