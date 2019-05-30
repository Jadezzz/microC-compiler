/*	Definition section */
%{
#include "xxxx.h" // include header if needed

extern int yylineno;
extern int yylex();
extern char *yytext; // Get current token from lex
extern char buf[BUF_SIZE]; // Get current code line from lex

FILE *file; // To generate .j file for Jasmin

void yyerror(char *s);

/* symbol table functions */
int lookup_symbol();
void create_symbol_table();
void free_symbol_table();
void insert_symbol();
void dump_symbol();

/* code generation functions, just an example! */
void gencode_function();

%}

%union {
}

/* Token without return */
%token INC DEC
%token MTE LTE EQ NE
%token ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token PRINT IF ELSE
%token ID SEMICOLON
%token I_CONST F_CONST STRING

/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program
    : program stat
    |
;

stat
    : declaration
    | compound_stat
    | expression_stat
    | print_func
;

declaration
    : type ID '=' initializer SEMICOLON
    | type ID SEMICOLON
;

/* actions can be taken when meet the token or rule */
type
    : INT { $$ = $1; }
    | FLOAT { $$ = $1; }
    | BOOL  { $$ = $1; }
    | STRING { $$ = $1; }
    | VOID { $$ = $1; }
;

%%

/* C code section */

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

    file = fopen("compiler_hw3.j","w");

    fprintf(file,   ".class public compiler_hw3\n"
                    ".super java/lang/Object\n"
                    ".method public static main([Ljava/lang/String;)V\n");

    yyparse();
    printf("\nTotal lines: %d \n",yylineno);

    fprintf(file, "\treturn\n"
                  ".end method\n");

    fclose(file);

    return 0;
}

void yyerror(char *s)
{
    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s\n", yylineno, buf);
    printf("| %s", s);
    printf("\n| Unmatched token: %s", yytext);
    printf("\n|-----------------------------------------------|\n");
    exit(-1);
}

/* stmbol table functions */
void create_symbol() {}
void insert_symbol() {}
int lookup_symbol() {}
void dump_symbol() {}

/* code generation functions */
void gencode_function() {}
