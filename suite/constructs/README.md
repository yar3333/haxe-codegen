Each construct should be a minimal example of something that should be
able to be exposed in a public API and consumed by another
program. For example, the public API might provide a class that can be
resused.

Each subfolder represents one such construct. Each construct shall an
`api` and `apiConsumer` folder. The `api` folder will have a file
`MODULES` listing the entry points to pass to haxe when compiling
it. The `consumer` folder shall have at least a `Run.hx` file. The
`codegen.filter` file will be generated from this. However, for some
projects this cannot automatically be generated. In that case, provide
a `codegen.filter` file and that will be used instead.

Some Haxe features are intended to ensure that invalid consumer code
does not compile. This requires compilation when testing, with the
whole validating that things should fail do fail and, more
importantly, that they fail for the right reason (instead of just
generally failing). To test this, each `consumer` folder may also have
an `EXPECTED_FAILURES` file. This file shall have the format where
each line is a compiler definition followed by a colon followed by a
string to expect in compiler error output. For example, a line like
`violate-constraints:Constraint check failure` will cause an extra run
of `Run.hx` with `-D violate-constraints` which is expected to cause a
compilation failure with build output including `Constraint check
failure` somewhere in it. The `Run.hx` must still compile and run
without errors when no conditional compilation directives are
specified.

For each construct, all known targets will be looped over. For each
target, the following will occur:

1. Compile the API to the target.

2. Run codegen on the API for the target with a filter file generated
   from `MODULES`.

2. Verify that the consumer code can be compiled against the externs
   created by codegen.

3. For supported targets (for now, JavaScript via node), the results
   will be executed.

4. For each entry in `consumer/EXPECTED_FAILURES` if it exists, verify
   that compilation fails and includes the specified message
   (substring match) when the `-D` flag is passed to the compiler.