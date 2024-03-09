# How to do it?

## Unit Tests

As per usual. In TDD we trust.


## Integration Tests

Manually:

- start with document & resources (dump as tarball 0)
- run lualatex and tools in the expected sequence
- dump the whole directory as tarball after every step

A test case consists of

- the ordered collection of tarballs and
- the expected sequence of commands
- (some) expected log messages

Test executing works like:

Given: 
- working dir with content from tarball 0
- mock: command i == expected command i => replace working dir content with tarball i

When: 
- run chew

Then:
- command i == expected command i, for all i
- (final) log contains all expected messages


## E2E Tests

Given: 
- working dir with content from tarball 0

When:
- run chew

Then:
- command i == expected command i, for all i
- (final) log contains all expected messages
- output is generated (if happy case)
  - can we test content?
- exits with (correct) error (if unhappy case)
