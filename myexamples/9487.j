.class public compiler_hw3
.super java/lang/Object
.field public static out I = -1
.method public static main([Ljava/lang/String;)V
.limit stack 51
.limit locals 51
	ldc 5
	istore 0
	ldc 4.000000
	fstore 1
	getstatic compiler_hw3/out I
	ldc 3
	iload 0
	ldc 1
	ldc 2
	iadd
	imul
	fload 1
	fstore 50
	i2f
	fload 50
	fdiv
	fstore 50
	i2f
	fload 50
	fadd
	ldc 10
	i2f
	fadd
	ldc 100
	i2f
	fsub
	ldc 11.620000
	fsub
	fstore 50
	i2f
	fload 50
	fmul
	ldc 1
	ldc 100
	iadd
	ldc 1
	isub
	i2f
	fmul
	f2i
	istore 2
	iload 2
	getstatic java/lang/System/out Ljava/io/PrintStream;
	swap
	invokevirtual java/io/PrintStream/println(I)V
	return
.end method
