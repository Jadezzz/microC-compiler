int factorial(int num){
    if(num == 0){
        return 1;
    }
    else{
        return num * factorial(num-1);
    }
    return 0;
}

void main(){
    int a = 0;
    int ans;
    while(a <= 10){
        ans = factorial(a);
        print(ans);
        a++;
    }
    return;
}
