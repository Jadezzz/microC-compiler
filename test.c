void lol(int num){
    while(num > 0){
        print("in lol");
        print(num);
        num --;
    }
    return;
}

void main(){
    int a = 10;
    int b = 0;
    while(a > 0){
        print(a);
        a --;
        while(b <= 5){
            print(b);
            b++;
        }
    }
    print(b);
    int c=3;
    while (b < 10){
        b++;
        print(b);
        lol(c);
    }
    return;
}
