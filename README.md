# extgen #

A macro tool to generate externals from existing haxe source codes.

### Usage ###
Compile your project with --macro extgen.Macro.generateHaxeExternals('path_to_output_directory'):
```
#!bash
haxe -lib mylib -cp src -main Main -js out.js --no-output --macro "extgen.Macro.generateHaxeExternals('externs')" 
```
