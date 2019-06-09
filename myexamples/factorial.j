.class public compiler_hw3
.super java/lang/Object
.method public static factorial(I)I
.limit stack 51
.limit locals 51
	iload 0
	iload 0
	ldc 0
	i2f
	fstore 50
	i2f
	fload 50
	fcmpl
	ifeq L_EQ_TRUE_0
	iconst_0
	goto L_EQ_FALSE_0
L_EQ_TRUE_0:
	iconst_1
L_EQ_FALSE_0:
	ifeq L_THEN0_0_1
	ldc 1
	ireturn
	goto L_COND_EXIT_0_1
L_THEN0_0_1:
	iload 0
	iload 0
	ldc 1
	isub
	invokestatic compiler_hw3/factorial(I)I
	imul
	ireturn
L_COND_EXIT_0_1:
	ldc 0
	ireturn
.end method
.method public static main([Ljava/lang/String;)V
.limit stack 51
.limit locals 51
	ldc 0
	istore 0
	ldc 0
	istore 1
L_WHILE_0_1:
	iload 0
	ldc 10
	i2f
	fstore 50
	i2f
	fload 50
	fcmpl
	ifle L_LTE_TRUE_1
	iconst_0
	goto L_LTE_FALSE_1
L_LTE_TRUE_1:
	iconst_1
L_LTE_FALSE_1:
	ifeq L_WHILE_EXIT_0_1
	iload 0
	invokestatic compiler_hw3/factorial(I)I
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
