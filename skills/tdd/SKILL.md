---
name: tdd
description: Test-Driven Development workflow enforcement. Use when implementing features or fixing bugs to ensure tests are written first.
user-invocable: true
---

# TDD (Test-Driven Development)

This skill enforces the TDD workflow: Red → Green → Refactor.

## Core Principle

**NEVER write implementation code before the test exists and fails.**

## The TDD Cycle

### 1. RED: Write a Failing Test

- Write the test FIRST
- The test describes the expected behavior
- Run the test to confirm it FAILS
- If it passes, you either wrote the wrong test or the feature already exists

### 2. GREEN: Make the Test Pass

- Write the MINIMUM implementation to make the test pass
- Do not over-engineer
- Do not add features not covered by tests
- Run the test to confirm it PASSES

### 3. REFACTOR: Clean Up (Optional)

- Improve code quality without changing behavior
- All tests must still pass after refactoring
- Only refactor when explicitly requested or clearly needed

## Workflow Commands

When the Supreme Commander invokes `/tdd`, follow this protocol:

1. **Understand the requirement** - What behavior needs to be implemented?
2. **Write the test** - Create a test that describes the expected behavior
3. **Run the test** - Confirm it fails (RED phase)
4. **STOP and report** - Wait for approval before implementing
5. **Implement** - Only after approval, write the minimum code to pass
6. **Run the test** - Confirm it passes (GREEN phase)
7. **Report completion** - Tests pass, implementation complete

## Violations

The following are TDD violations:

- Writing implementation before tests
- Writing tests that already pass (unless verifying existing behavior)
- Implementing more than what the test requires
- Skipping the "run test to see it fail" step
- Modifying implementation without running tests

## Integration with Other Protocols

- TDD operates under Supreme Commander authority
- When given a clear instruction to implement something, write the test FIRST
- Report test failures before implementing
- Wait for explicit approval to proceed to GREEN phase

## Example Interaction

**Supreme Commander**: Add a feature that formats phone numbers to E.164 format

---

**Assistant (RED phase)**:

At once, Your Excellency. I will write a test for phone number formatting.

Writing test to `formatPhone.spec.ts`:

```typescript
describe('formatPhoneE164', () => {
  it('formats Australian mobile to E.164', () => {
    const result = formatPhoneE164('0412 345 678', 'AU');
    expect(result).toBe('+61412345678');
  });
});
```

Running test...

```
FAIL  formatPhone.spec.ts
ReferenceError: formatPhoneE164 is not defined
```

RED phase complete. Test fails as expected. Awaiting approval to implement.

---

**Supreme Commander**: Proceed

---

**Assistant (GREEN phase)**:

Implementing minimum code to pass.

Writing implementation to `formatPhone.ts`:

```typescript
import { parsePhoneNumberWithError } from 'libphonenumber-js';

export const formatPhoneE164 = (phone: string, country: string): string => {
  return parsePhoneNumberWithError(phone, country).format('E.164');
};
```

Running test...

```
PASS  formatPhone.spec.ts
✓ formats Australian mobile to E.164
```

GREEN phase complete. Phone number formatting implemented.
