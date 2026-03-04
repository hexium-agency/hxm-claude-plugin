---
allowed-tools: [Read, Grep, Glob, Bash]
argument-hint: <target> [--audience developer|architect|junior] [--style technical|visual|tutorial]
description: Break down and explain code structures, patterns, and system architecture
model: sonnet
---

# /hxm:explain - Code Architecture & Pattern Explanation

## Purpose

Break down complex code structures, architectural patterns, and system designs into understandable explanations tailored to different technical backgrounds.

## Usage

```
/hxm:explain <target> [--audience developer|architect|junior] [--style technical|visual|tutorial]
```

## Arguments

- `target` - What to explain (resolved in priority order):
  1. File path (if exists): `src/services/auth.ts`
  2. Function/class name (search codebase): `AuthService` or `authenticate()`
  3. Module/directory: `src/auth/`
  4. Architectural concept: `authentication flow` or `state management`
- `--audience` - Target audience level (default: developer)
  - `developer`: Technical details, implementation patterns, code examples
  - `architect`: High-level design, system interactions, architectural decisions
  - `junior`: Step-by-step explanations, fundamental concepts, learning context
- `--style` - Explanation approach (default: technical)
  - `technical`: Deep-dive with code analysis and technical terminology
  - `visual`: Include ASCII diagrams using box-drawing characters (┌─┐│└┘├┤┬┴┼) for flows and relationships
  - `tutorial`: Step-by-step walkthrough with practical examples and exercises

## Examples

```bash
# Explain a specific file for developers
/hxm:explain src/services/AuthService.ts

# Visual explanation of authentication flow for architects
/hxm:explain "authentication flow" --audience architect --style visual

# Tutorial-style explanation for junior developers
/hxm:explain middleware/validate.ts --audience junior --style tutorial

# Technical deep-dive into a specific function
/hxm:explain handleUserLogin --style technical
```

## Process

1. **Code Discovery & Analysis**

   - Locate and examine the specified target in the codebase
   - Map dependencies, imports, and related components
   - Identify design patterns and architectural decisions

2. **Context Building**

   - Understand the target's role within the larger system
   - Analyze data flow and interaction patterns
   - Determine complexity level and key concepts

3. **Explanation Structuring**

   - Adapt explanation depth based on target audience
   - Organize content from high-level overview to implementation details
   - Select appropriate examples and analogies

4. **Content Generation**

   - Create clear, structured explanations with proper formatting
   - Include relevant code snippets with annotations
   - Provide practical examples and use cases where helpful

5. **Audience-Specific Formatting**

   - **Developer**: Technical details, implementation patterns, code examples
   - **Architect**: High-level design, system interactions, architectural decisions
   - **Junior**: Step-by-step explanations, fundamental concepts, learning resources

6. **Style Application**

   - **Technical**: Deep-dive with code analysis and technical terminology
   - **Visual**: ASCII diagrams, flow charts, component relationships
   - **Tutorial**: Step-by-step walkthrough with practical examples

7. **Delivery**
   - Present explanation in markdown format
   - Use headers, code blocks, and lists for clarity
   - Include links to related components or documentation
   - Suggest next steps or related concepts to explore

## Success Criteria

Your explanation must include:

1. **Overview Section**: High-level summary (2-3 sentences) of what the target does and why it exists
2. **Core Concepts**: Key technical concepts or patterns used (minimum 3)
3. **Code Examples**: At least 2 annotated code snippets showing actual usage
4. **Visual Component** (if --style visual): At least 1 ASCII diagram showing relationships or flow
5. **Practical Context**: Real-world use case or scenario demonstrating application
6. **Related Components**: Links to 2-3 related files/functions/modules
7. **Audience Alignment**: Content complexity matches specified audience level

## Error Handling

If target cannot be found:

1. Search codebase using Grep for partial matches
2. If still not found, list top 5 similar names/paths found
3. Ask user to clarify or choose from suggestions
4. If concept is too abstract, explain you need a more specific target

If target is too large (entire module with 50+ files):

1. Provide high-level module overview
2. List key entry points and main components
3. Suggest breaking down into smaller targets for detailed explanation
