Components
==========

Adding a component
------------------

Consider which of the following may require updates:

- EditorConfig (`.editorconfig`)  
  Editor settings for file paths.
- Git attributes (`.gitattributes`)  
  Non-default file encodings or line endings as well as vendored paths.
- Ignores
  - Ignore (`.ignore`)  
    Paths to be ignored by various tools (e.g. `ripgrep`).
  - Git ignore (`.gitignore`)  
    Paths to be ignored by Git.
  - Prettier ignore (`.prettierignore`)  
    Paths to be ignored by Prettier.
- Metadata (`metadata/`)
  - `component.sh`  
    Metadata used by `dot-manage`.
  - `component.xml`  
    Metadata used by [PSDotFiles](https://github.com/ralish/PSDotFiles).
- VS Code (`.vscode/settings.json`)
  - `files.associations`  
    File paths to language mappings.
  - `files.exclude`  
    Files to hide in Explorer tree.
  - `search.exclude`  
    Excludes for search & quick open.
  - `vsicons.associations.files`  
    File names and extensions to icon mappings.
  - `[lang]`  
    Language specific configuration (e.g. rulers).
