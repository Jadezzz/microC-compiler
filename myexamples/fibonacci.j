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
	iflt L_LT_TRUE_0
	iconst_0
	goto L_LT_FALSE_0
L_LT_TRUE_0:
	iconst_1
L_LT_FALSE_0:
	ifeq L_THEN0_0_1
	iload 0
	ireturn
	goto L_COND_EXIT_0_1
L_THEN0_0_1:
	iload 0
	ldc 1
	isub
	invokestatic compiler_hw3/fibonacci(I)I
	iload 0
	ldc 2
	isub
	invokestatic compiler_hw3/fibonacci(I)I
	iadd
	ireturn
L_COND_EXIT_0_1:
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
