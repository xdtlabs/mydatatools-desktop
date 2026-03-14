---
trigger: always_on
---

# PROJECT SPECIFICATION: "Civic Voice"

## WHY: Project Purpose & Intent
Community engagement app to view, edit, comment, and vote on congressional bills. Aims to make legislation interactive and accessible bridging the gap between citizens and the legislative process.

## WHAT: Tech Stack & Architecture
- **Frontend**: Next.js (Latest Stable), TypeScript, Tailwind CSS, Shadcn UI
- **Backend/DB**: Firebase, Firebase DataConnect (PostGIS)
- **Auth**: Firebase Auth (Anonymous allowed for view, auth required for voting/comments)
- **AI/ML**: Firebase AI/Genkit with Google Gemini. (Use `gemini-3-flash-preview`; `gemini-1.5-flash` is deprecated)

### Core Features & Data Flow
- **Ingestion Pipeline**: Bill summary data is loaded from Congress.gov API. XML versions of bills (and rendered XML) are downloaded and cached in Cloud Storage.
- **Frontend Experience**: Users navigate the Home Page and Bill Detail pages to interact with structured legislation data.
- **Styling**: Use the '8-point grid system' for all spacing, sizing, and alignment.

## HOW: Development & Verification
- **Testing**: Always write unit tests for testable code changes. When fixing bugs, write a failing unit test first, then ensure it passes after the fix. Optimize for running single tests for future debugging.
- **Data Connect Usage**: Use Firebase Data Connect for all database operations. Put all database mutations in the generated SDK, never embedded directly in code.
- **Library Validation**: Use the `context7` MCP server to validate code against the latest library documentation.
- **GIT**: When using git, DO NOT commit code. I will commit the code after reviewing the changes.

