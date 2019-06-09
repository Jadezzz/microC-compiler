# Micro C Compiler

A simple compiler that can compile micro-C (a subset of C) to JVM instructions.

## Note: This project is under construction!

### Compile it

```bash
$ make 
```

### Run it

```test.c``` can be any other file.

Will produce ```compiler_hw3.j``` if no error occured.

```bash
$ ./myparser < test.c 
```

### Turn to JVM class

Will produce ```compiler_hw3.class``` which is a java class file.
```bash
$ java -jar jasmin.jar compiler_hw3.j
```

### Run on JVM
```bash
$ java compiler_hw3
```

## STAR THIS REPO if it helps you :)