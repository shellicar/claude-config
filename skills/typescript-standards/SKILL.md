---
name: typescript-standards
description: TypeScript coding standards and requirements including banned types, iterative approach, satisfies usage, re-export rules, and testing patterns. Apply when writing or modifying TypeScript code.
user-invocable: false
---

# TypeScript Coding Guidelines

These instructions apply **only to code you are actively modifying**. Do not fix pre-existing violations in other parts of the file unless explicitly asked.

## Quick Reference

- **Banned**: `as any`, `any` for declarations - must request approval first
- **Iterative**: Write code → let TypeScript error → fix → repeat
- **Testing**: Use `satisfies` for test data, functional factories over classes
- **Re-exports**: Banned except for `index.ts` in npm packages
- **Temporal**: Use `Temporal.Instant` (timestamps), `Temporal.PlainDate` (dates)

## Banned Types

The following TypeScript types are **BANNED** for type DECLARATIONS without explicit approval:

- `as any` - casting a value to any
- `any` - when declaring what type a value IS (e.g., `const x: any`, `function foo(): any`)

### Acceptable Uses of `any`

`any` is **acceptable** for type CONSTRAINTS/RESTRICTIONS when we genuinely don't care about that specific type:

- Generic constraints: `new (...args: any[])` - constructor signatures where we don't care about the arguments
- Function parameters in generic contexts where the parameter type is irrelevant to the logic
- Type utilities where `any` is used as a constraint, not as the actual type

**Key distinction**:

- ❌ BANNED: `const data: any = ...` (declaring data IS any)
- ✅ ALLOWED: `type Constructor = new (...args: any[]) => T` (constraining constructor args when we don't care about them)

### Why Banned Types Are Forbidden

TypeScript's type system is the primary benefit of using TypeScript. Using banned types throws away type safety. We would use another language if we didn't value TypeScript's typing.

TypeScript's type system is Turing complete - there are always solutions to type problems, even if they initially seem impossible. Solutions exist; the question is whether finding them is worth the cost.

### Protocol for Requesting Banned Type Usage

You *MUST* follow this exact protocol if you believe a banned type is necessary:

1. **Explore ALL alternatives first**
   - Exhaust all TypeScript type system features (generics, conditional types, mapped types, etc.)
   - Document what you tried

2. **Make a formal REQUEST (do not use the banned type yet)**
   - Explain why all alternatives failed or are too costly
   - Show the EXACT code that would use the banned type
   - Acknowledge that a solution likely exists, but may not be worth the cost

3. **Wait for approval/denial**
   - Approval is valid for ONE response only
   - If approved: you *MUST* apply the shown code in your current response
   - If denied: you *MUST NOT* use the banned type and must find another solution

4. **Verification in teapot mode**
   - When comparing your response to protocol, check for any banned type usage
   - If banned type is used without approval: you are brewing (*glug glug glug*)

## Temporal Type Naming Standards

When naming fields that store temporal data, use suffixes that clearly indicate the js-joda type:

| js-joda Type | Naming Convention | Examples |
|-------------|-------------------|----------|
| `Date` / `Instant` | `*Utc` | `createdUtc`, `modifiedUtc`, `expiresUtc` |
| `LocalDate` | `*Date` | `birthDate`, `expiryDate`, `effectiveDate` |
| `LocalTime` | `*Time` | `startTime`, `endTime`, `scheduledTime` |
| `LocalDateTime` | `*DateTime` | `scheduledDateTime`, `recordedDateTime` |
| `ZonedDateTime` | `*ZonedDateTime` | `appointmentZonedDateTime`, `eventZonedDateTime` |
| `Duration` | `*Duration` | `validDuration`, `timeoutDuration` |
| `Period` | `*Period` | `billingPeriod`, `trialPeriod` |
| `Year` | `*Year` | `modelYear`, `fiscalYear` |
| `Month` | `*Month` | `birthMonth`, `expiryMonth` |
| `YearMonth` | `*YearMonth` | `periodYearMonth`, `billingYearMonth` |
| `ZoneId` | `*ZoneId` | `userZoneId`, `defaultZoneId` |
| `ZoneOffset` | `*ZoneOffset` | `timezoneZoneOffset`, `utcZoneOffset` |

### Why These Conventions

- **Clarity**: The suffix immediately indicates the temporal precision and timezone semantics
- **Type Safety**: Makes it obvious when converting between types (e.g., `Date` → `Instant` requires UTC context)
- **Consistency**: Uniform naming across the codebase prevents confusion
- **Self-Documenting**: Code readers know exactly what temporal type is expected

### Examples

```typescript
// Good - clear temporal types
type Event = {
  createdUtc: Date;           // Instant/UTC timestamp
  scheduledDate: string;      // LocalDate (ISO format)
  startTime: string;          // LocalTime (ISO format)
  appointmentZonedDateTime: string; // ZonedDateTime (ISO format with zone)
  validDuration: string;      // Duration (ISO 8601 duration)
  fiscalYear: number;         // Year
};

// Bad - ambiguous naming
type Event = {
  created: Date;              // What timezone? Instant or LocalDateTime?
  scheduled: string;          // Date? DateTime? ZonedDateTime?
  start: string;              // Time? DateTime? Instant?
  appointment: string;        // What temporal type?
  valid: string;              // Duration? Instant?
  fiscal: number;             // Year? Just a number?
};
```

## Iterative Coding Approach

When writing code, prefer an **iterative, incremental approach** guided by TypeScript's type system.

### Why This Approach Works Better

- **Easier to curate**: The Supreme Commander can review and guide small changes rather than large complete solutions
- **Type system as guide**: TypeScript errors point to exactly what needs fixing
- **Incremental progress**: Don't try to solve everything at once - work bit by bit
- **Natural development**: This mirrors how humans write code with IDE feedback

### How to Apply This

1. Write partial code without banned types (like `as any`)
2. Let TypeScript report errors/violations
3. Use those errors to understand what's needed
4. Fix one error at a time
5. Repeat until all errors are resolved

### Example Workflow

Instead of:

```typescript
const data = { ...complexStuff } as any; // "Complete" but wrong
```

Do:

```typescript
const data = { ...complexStuff }; // Let TypeScript tell us what's missing
// TypeScript error: Property 'foo' is missing
// Fix: Add foo property
// TypeScript error: Type 'X' is not assignable to 'Y'
// Fix: Adjust the type
```

This approach leverages TypeScript's power rather than working around it.

## Re-exports: NEVER Create Backwards Compatibility Re-exports

**CRITICAL RULE**: NEVER create re-export statements to maintain backwards compatibility during refactoring.

### When Re-exports Are FORBIDDEN (Almost Always)

During refactoring, moving, or reorganizing code:

- **NEVER** add `export { Type } from './new-location'` in the old file
- **NEVER** add `export type { Type } from './new-location'` in the old file
- **NEVER** add `export * from './new-location'` in the old file
- **NEVER** maintain backwards compatibility by re-exporting moved types

When refactoring:

1. Create new files with the types
2. Delete types from old location
3. Update all imports to point to the new location
4. Do NOT add re-exports in the old location

### The ONLY Exception: Index Barrel Files in Published NPM Packages

Re-exports are **ONLY** permitted for:

- Index barrel files (`index.ts`) in **publicly published NPM packages**
- This is the **ONLY** valid use case for re-exports

If you are NOT working on an index file for a public NPM package, you **MUST NOT** create re-exports.

### Why This Rule Exists

- Backwards compatibility re-exports create technical debt
- They hide the true location of types/functions
- They make the codebase harder to understand and maintain
- During refactoring, all imports should be updated to the correct location

### Verification in Teapot Mode

When comparing your response to protocol:

- Check if you added any `export { }` or `export * from` statements
- If you added re-exports during refactoring: you are brewing (*glug glug glug*)
- Exception: if you're explicitly working on an index.ts file for a published NPM package

## Prefer `satisfies` for Type Safety

When creating objects or return values, **strongly prefer** using the `satisfies` operator for type constraints.

### Why Prefer `satisfies`

- **Type safety without widening**: Ensures the object meets type requirements without changing its inferred type
- **Better autocomplete**: Preserves exact literal types for better IDE support
- **Future-proof**: Catches errors if the type constraint changes
- **Redundancy is good**: Using both explicit return types and `satisfies` provides double-checking

### When to Use `satisfies`

Use `satisfies` for:

- Function return values (in addition to explicit return type annotation)
- Complex object literals that need to match a specific shape
- Mock data in tests that should conform to production types

### Example

```typescript
// Prefer this for functions:
const createData = (): MyType => ({
  prop1: 'value',
  prop2: 123
} satisfies MyType);

// Over this:
const createData = (): MyType => ({
  prop1: 'value',
  prop2: 123
});

// Prefer this for constants:
const myObject = {
  prop1: 'value',
  prop2: 123
} satisfies MyType;
```

The `satisfies` keyword adds an extra layer of verification without sacrificing type inference.

**NOTE**: There are times when explicit type annotation is needed instead:

```typescript
const myObject: MyType = {}; // When you need the variable's type to be widened to MyType
```

## Testing Guidelines

These guidelines apply when writing or modifying test files (*.spec.ts). The goal is **maximum maintainability** - tests verify the **intended behavior** (how we want the system to work), not the current or expected behavior of the implementation. Clear tests make debugging failures straightforward.

> **Testing Workflow**: The `/tdd` skill applies to ALL testing work. You MUST follow it whenever tests are involved.

### Single Assertion Per Test (MUST)

Each `it` block *MUST* contain a single assertion. Multiple assertions make it harder to diagnose which specific behavior failed.

**Why this matters:**

- When a test fails, you immediately know which specific behavior broke
- Tests become self-documenting - the test name describes exactly what's being verified
- Easier to maintain and update as requirements change

**Exception:** If multiple assertions are needed, discuss with the Supreme Commander first.

### Expected/Actual Pattern (MUST)

Use explicit `const expected` and `const actual` variables before assertions:

```typescript
it('sets nextSend to current time', async () => {
  const expected = convert(now).toDate();

  await domainObject.generateSms();

  const actual = domainObject.entity.sms?.nextSend;
  expect(actual).toEqual(expected);
});
```

For throw assertions, assign the function to `actual`:

```typescript
it('throws on invalid phone number', () => {
  const actual = () => formatPhoneE164('invalid', 'AU');

  expect(actual).toThrow();
});
```

**Why this pattern:**

- Makes test logic crystal clear
- Easy to see what value is expected vs what was produced
- Consistent structure across all tests

See `tdd` skill for the full TDD workflow and verification checklist.

### Use `satisfies` for Test Data

Test input data and mocks should use `satisfies` to ensure type correctness:

```typescript
const input = {
  interactionId: 'de80e429-5d13-4536-b824-89e9c43c80fb',
  step: WelcomeStep.Overview,
} satisfies WelcomeNextInput;

const stages = [
  InteractionStageType.Welcome,
  InteractionStageType.Questions
] satisfies InteractionStageType[];
```

### Helper Factory Functions (Strongly Preferred)

For complex object creation, use helper factory functions rather than inline construction:

```typescript
// Good - reusable, maintainable
const createTestEntity = (clock: Clock): InteractionEntityV1 => ({
  _id: toMongo(TEST_ENTITY_ID),
  uniqueKey: 'test-key',
  created: convert(clock.instant()).toDate(),
  modified: convert(clock.instant()).toDate(),
  interaction: createTestInteractionData(),
} satisfies InteractionEntityV1);

// Then in tests:
it('should process entity', () => {
  const entity = createTestEntity(mockClock);
  // test using entity
});
```

### Fixed Clock Pattern

Use fixed clocks for deterministic time-based tests:

```typescript
const fixedInstant = Instant.parse('2023-01-01T00:00:00Z');
const clock = Clock.fixed(fixedInstant, ZoneId.UTC);
```

Or MockClock for tests requiring time advancement:

```typescript
const now = Instant.parse('2023-01-01T10:00:00Z');
const clock = new MockClock(now);
clock.advanceBy(Duration.ofSeconds(61));
```

### Test Naming (Present Tense)

Name tests using present tense to describe the behavior being verified:

```typescript
it('sets nextSend to current time', () => { });      // Good
it('should set nextSend to current time', () => { }); // Acceptable
it('setting nextSend to current time', () => { });    // Avoid
```

### DI Container Setup

Use proper DI container setup in tests, don't mock what you don't need to:

```typescript
beforeEach(() => {
  const services = createServiceCollection();
  services.register(Clock).to(Clock, () => mockClock).singleton();
  services.register(IDatabase).to(MockDatabase, () => mockDatabase).singleton();

  const container = services.buildProvider();
  serviceUnderTest = container.resolve(MyService);
});
```

### No Banned Types in Tests

Tests follow the same banned type rules as production code - no `as any` usage. Use `satisfies` and proper typing instead.
