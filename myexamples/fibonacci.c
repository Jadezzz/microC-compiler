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
