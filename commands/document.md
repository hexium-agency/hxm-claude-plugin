---
allowed-tools: [Read, Write, Glob, Grep, Bash, Edit]
argument-hint: <target> [--type inline|centralized] [--level brief|detailed]
description: Generate comprehensive documentation for code, features, and system architecture
model: sonnet
---

# /hxm:document - Intelligent Documentation Generator

## Purpose

Generate comprehensive documentation for codebases, features, and system architecture with flexible output formats and detail levels.

## Usage

```bash
/hxm:document <target> [--type inline|centralized] [--level brief|detailed]
```

## Arguments

- `target` - What to document (resolved in priority order):
  1. File path (if exists): `src/services/auth.ts`
  2. Directory path: `src/auth/` or `.` for entire project
  3. Feature name (search codebase): `authentication` or `payment-processing`
- `--type` - Documentation format (default: inline)
  - `inline`: Generate documentation directly in code files (JSDoc, docstrings, XML docs)
  - `centralized`: Create structured markdown documentation in `/documentation/` folder
- `--level` - Documentation depth (default: brief)
  - `brief`: Essential documentation - function signatures, parameters, purpose (5-10 lines per item)
  - `detailed`: Comprehensive documentation - full descriptions, examples, edge cases, best practices (20+ lines per item)

## Documentation Conventions

- **Language**: All documentation must be written in English by default
  - Function/class names, parameters, descriptions, examples
  - Markdown files, comments, and inline documentation
  - Code examples and variable names in documentation
- **Formatting**: Follow language-specific conventions (JSDoc, docstrings, etc.)
- **Terminology**: Use consistent technical terminology throughout

## Existing Documentation Behavior

- **Inline type**: Updates existing doc comments in-place, preserves manual edits
- **Centralized type**:
  - If file exists: Appends new sections with timestamp separator
  - If new file: Creates complete documentation structure
  - Never overwrites existing content without review

## Process

1. **Target Analysis**

   - Analyze the specified target (file, directory, or feature)
   - Identify programming languages and frameworks in use
   - Determine existing documentation patterns and conventions
   - Map dependencies and relationships
   - Detect documentation categories using concrete patterns:
     - **External API usage**: Search for `import.*axios|fetch|request`, `@aws-sdk`, `stripe`, API keys in config
     - **Package structure**: Check for `packages/*/package.json`, `lerna.json`, monorepo configs
     - **Deployment configs**: Look for `Dockerfile`, `.github/workflows`, `deploy.yml`, cloud config files
     - **API endpoints**: Search for `@route|@controller|router.|app.get|app.post`, GraphQL schemas
     - **Error handling**: Find `try.*catch`, `error.*handler`, validation middleware patterns

2. **Documentation Strategy Selection**

   - **Inline Type**: Generate language-specific documentation within source files
     - JavaScript/TypeScript: JSDoc comments
     - Python: Docstrings and type hints
     - Java: Javadoc comments
     - C#: XML documentation comments
     - Go: Go doc comments
     - Rust: Rust doc comments
   - **Centralized Type**: Create structured documentation folder hierarchy
     - Create `/documentation/` at project root
     - Generate `index.md` with project overview and navigation
     - Analyze target to determine relevant documentation categories
     - Create only necessary subject-based folders based on project analysis:
       - `features/` - When user-facing features are detected
       - `external-api/` - When third-party API integrations are found
       - `packages/` - When multiple modules/packages exist
       - `architecture/` - For complex systems with multiple components
       - `deployment/` - When deployment configurations are present
       - `api/` - When API endpoints or services are detected
       - `troubleshooting/` - When error handling patterns are identified

3. **Content Generation**

   - **Brief Level**: Generate essential documentation
     - Function/class purpose and basic usage
     - Key parameters and return values
     - Simple examples where helpful
     - Overview of main features and concepts
     - **For centralized brief**: Create concise `index.md` (under 20 lines) with direct file links
   - **Detailed Level**: Generate comprehensive documentation
     - Complete API documentation with all parameters
     - Usage patterns and best practices
     - Code examples and integration guides
     - Edge cases and error handling
     - Performance considerations
     - Related components and dependencies
     - **For centralized detailed**: Create full structure with organized folders

4. **Documentation Structure (Centralized Type)**

   - Create `/documentation/` directory at project root
   - **For brief level**: Create simple `index.md` with essential overview and direct links to key files
   - **For detailed level**: Create comprehensive structure with subject folders
   - Analyze target to determine if subject folders are needed:
     - Single file target: Document directly in `documentation/[filename].md`
     - Simple project: Basic `index.md` with essential links
     - Complex project: Create relevant subject folders and organize content
   - **Subject folders**: Only create when content justifies organization
   - **Cross-references**: Link between related documentation files

5. **Quality Assurance**
   - Ensure documentation follows project conventions
   - Validate code examples and syntax
   - Check for consistency in tone and format
   - Verify all references and links work correctly

## Examples

### Inline Documentation

```bash
/hxm:document src/auth/login.js --type inline --level detailed
# Generates JSDoc comments directly in the login.js file
```

### Centralized Documentation

```bash
/hxm:document src/payment --type centralized --level brief
# Creates documentation/features/payment.md with overview
# Only creates folders relevant to payment functionality
```

### Full Project Documentation

```bash
/hxm:document . --type centralized --level detailed
# Analyzes entire project and creates documentation structure
# Only includes folders for detected components (e.g., skips external-api/ if none found)
```

## Success Criteria

Your documentation must meet these quality standards:

### Inline Documentation
**Brief:**
- Every public function/class has a doc comment
- Parameters and return types documented
- One-line purpose statement

**Detailed:**
- Complete parameter descriptions with types and constraints
- At least 1 usage example per public function
- Edge cases and error conditions documented
- Cross-references to related functions

### Centralized Documentation
**Brief:**
- `index.md` created with project overview (10-30 lines)
- Direct links to 5+ key files
- Basic getting started section

**Detailed:**
- Comprehensive `index.md` with navigation
- At least 3 subject-specific documentation files
- Each file includes: overview, examples, related components
- Cross-references between documentation files
- Architecture diagrams or flow descriptions

### Quality Checks
- All code examples are syntactically valid
- All file references and links are accurate
- Consistent formatting and terminology throughout
- No placeholder text (TODO, FIXME, etc.)

## Error Handling

### Target Not Found
1. Search codebase using Grep for partial matches
2. Search for similar directory names using Glob
3. If feature name: search for related terms in comments and file names
4. Present top 5 closest matches with context
5. Ask user to clarify or select from suggestions

### Target Too Large
If target includes 50+ files:
1. Inform user of scope (file count, estimated documentation size)
2. For inline: Suggest breaking into smaller directories
3. For centralized: Create high-level overview with links to subdirectories
4. Offer to process in batches by subdirectory

### Existing Documentation Conflicts
If documentation already exists:
1. **Inline**: Show diff preview of changes before applying
2. **Centralized**: List existing files that will be updated
3. Ask user to confirm before proceeding
4. Preserve existing content by appending with clear separators

### Unsupported Language
If target language lacks standard documentation format:
1. List detected languages
2. Explain which are supported for inline documentation
3. Suggest centralized documentation as alternative
4. Proceed with centralized type if user agrees

## Notes

- **Brief centralized**: Creates minimal structure with concise index.md and direct file documentation
- **Detailed centralized**: Creates comprehensive folder structure only when justified by project complexity
- Subject folders are created only when analysis detects relevant content patterns
- Single file targets get documented directly without unnecessary folder nesting
- For centralized documentation, existing files are updated rather than overwritten
- Cross-references between documentation files are automatically generated
- Documentation follows markdown best practices with proper headers and formatting
