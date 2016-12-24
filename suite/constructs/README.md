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

For each construct, all known targets will be looped over. For each
target, the following will occur:

1. Compile the API to the target.

2. Run codegen on the API for the target with a filter file generated
   from `MODULES`.

2. Verify that the consumer code can be compiled against the externs
   created by codegen.

3. For supported targets (for now, JavaScript via node), the results
   will be executed.
