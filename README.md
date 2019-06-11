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

## Examples

Fibonacci Sequence

```C
int fibonacci(int n) {
	if(n < 2) {
		return n;
	}
	else {
		return fibonacci(n-1) + fibonacci(n-2);
	}

	return 0;
}
void main(){
    print("Fibonacci from 0 to 10");
    int a = 0;
    while(a < 11){
        int c = fibonacci(a);
        print(c);
        a++;
    }
    return;
}
```

```
.class public compiler_hw3
.super java/lang/Object
.method public static fibonacci(I)I
.limit stack 51
.limit locals 51
	iload 0
	iload 0
	ldc 2
	i2f
	fstore 50
	i2f
	fload 50
	fcmpl
	iflt L_LT_TRUE_0      -------
	iconst_0                    |
	goto L_LT_FALSE_0        compare < 
L_LT_TRUE_0:                  	    |
	iconst_1                    |
L_LT_FALSE_0:                 -------
	ifeq L_THEN0_0_1                          --if(n<2)--
	iload 0                                             |
	ireturn                                             |
	goto L_COND_EXIT_0_1                      -----------
L_THEN0_0_1:                                      ---else----
	iload 0                                             |
	ldc 1                                               |
	isub                                               n-1
	invokestatic compiler_hw3/fibonacci(I)I          fibonacci(n-1)
	iload 0                                             |
	ldc 2                                               |
	isub                                               n-2
	invokestatic compiler_hw3/fibonacci(I)I          fibonacci(n-2)
	iadd                                                +
	ireturn                                             |
L_COND_EXIT_0_1:                            	  -----------
	ldc 0
	ireturn
.end method
.method public static main([Ljava/lang/String;)V
.limit stack 51
.limit locals 51
	ldc "Fibonacci from 0 to 10"
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(Ljava/lang/String;)V
	ldc 0
	istore 0
L_WHILE_0_1:
	iload 0
	ldc 11
	i2f
	fstore 50
	i2f
	fload 50
	fcmpl
	iflt L_LT_TRUE_1
	iconst_0
	goto L_LT_FALSE_1
L_LT_TRUE_1:
	iconst_1
L_LT_FALSE_1:
	ifeq L_WHILE_EXIT_0_1
	iload 0
	invokestatic compiler_hw3/fibonacci(I)I
	istore 1
	iload 1
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(I)V
	iload 0
	ldc 1
	iadd
	istore 0
	goto L_WHILE_0_1
L_WHILE_EXIT_0_1:
	return
.end method
```
