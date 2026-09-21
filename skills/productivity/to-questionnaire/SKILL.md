---
name: to-questionnaire
description: Turn a decision you can't fully answer into a questionnaire for one person, or a group, to fill in.
disable-model-invocation: true
---

Turn something the user can't answer alone into a **questionnaire**: a Markdown document they hand to people to fill in async, or fill out together over a meeting. The recipients hold knowledge the user lacks; the questionnaire pulls it out of them.

**Grill the send, not the subject.** Interview the user only about the _send_, which they can always answer: who it goes to, and what they need back. The questions in the document then target the **gap** between what the recipients know and what the user needs.


1. **Who is it going to?** Ask, in one exchange, each recipient's role, expertise, and relationship to the user. This fixes the questionnaire's tone and how much context it must carry. **Where the recipients know different things, settle whether that is one document or several** — one set of questions aimed at four audiences is answered by whichever of them the middle questions happen to suit, and skipped by the rest. Done when you know who the recipients are and what each of them knows that the user does not.

2. **What do you need back?** Ask, in one exchange, the specific decisions or facts the user can't resolve alone and needs from these people. Done when you have a concrete list of what the user must walk away able to do or decide.

3. **Write the questionnaire.** Draft questions aimed at the gap from steps 1–2, following the Document structure below. Done when every item the user named in step 2 is covered by a question, the file sits where Where the draft goes says, and you have reported both that path and how it reaches the recipients.

## Where the draft goes

**A scratch file, outside the repo.** A questionnaire is spent once it has been answered, and an unanswered one found months later reads as an open question that was probably resolved — a stale file that costs a reader time and tells them nothing true.

**The answers are the durable artifact.** They land wherever the decision they enable lands: an ADR, a spec, a ticket. The repo has a home for each of those and none for a questionnaire, so committing the draft gains a file nobody will maintain.

**It stays a draft until it reaches the recipients.** They read mail, chat and the tracker, not a path on someone's laptop, so settle with the user how it will be sent and match the format to that. A Markdown file nobody can open is a questionnaire that was never asked.

## Document structure

Frame the document as a **discovery questionnaire**: the user lacks context, the recipient holds it. Order questions most-important-first, since async means you may only get one pass, and group them under `##` headings by theme once there are more than a handful. Write it using the template below.

<questionnaire-template>

# <Questionnaire title>

**Purpose:** why this questionnaire exists and the decision riding on it.

**From:** <the user>, **To:** <the recipient>, **How your answers will be used:** <where they go>

## Context

One paragraph orienting a recipient who wasn't in the user's head. Enough to answer well, not a page.

## How to answer

Deadline and rough effort. Partial answers and "I don't know" are useful: flag anything you're unsure of rather than skipping it.

## <Theme heading>

One `##` section per theme. Under each, its questions, most-important-first. Every question is one idea, never compound, with an answer stub directly beneath, and a one-line _why this matters_ only where the question could be misread or invite a throwaway answer.

<question-example>
### What load is the system expected to handle at launch?

_Why this matters: it decides whether we provision for burst traffic now or defer it._

>
</question-example>

## Anything else?

A closing catch-all: anything we didn't ask that we should know?

</questionnaire-template>
