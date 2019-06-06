/*	Definition section */
%{
#include <stdio.h>
#include <stdlib.h>
#include "header.h" // include header if needed
#include <string.h>


extern int yylineno;
extern int yylex();
extern char *yytext; // Get current token from lex
extern char buf[BUF_SIZE]; // Get current code line from lex

FILE *file; // To generate .j file for Jasmin

void yyerror(char *s);

/* symbol table functions */
int var_count = 0;

// Flags for lexer
bool dump_flag = false;
bool display_flag = false;

// Only head of the symbol table


struct SymTable* HEAD = NIL;
struct SymTable* DUMP = NIL;

int scope = 0;

struct SymTable newTable();
void removeTable(bool display_flag);
void insertNode(const char* name, TYPE entry_type, TYPE data_type, bool isFuncDefine, bool prevScope);
char* type2string(TYPE type);
void dumpTable();

struct FuncAttr* temp_attribute = NIL;

/* code generation functions, just an example! */
void gencode_function();

%}

/* Present nonterminal and token type */
%union {
    int i_val;
	float f_val;
	char* lexeme;
	TYPE type;
	OPERATOR op;
}

/* Token without return */
%token PRINT 
%token IF ELSE FOR WHILE
%token SEMICOLON
%token ADD SUB MUL DIV MOD INC DEC
%token MT LT MTE LTE EQ NE
%token ASGN ADDASGN SUBASGN MULASGN DIVASGN MODASGN
%token AND OR NOT
%token LB RB LCB RCB LSB RSB COMMA
%token TRUE FALSE RET

/* Token with return */
%token I_CONST
%token F_CONST
%token STRING_CONST
%token <lexeme> ID
%token VOID INT FLOAT BOOL STRING

/* Nonterminal with return */
%type <type> type_spec
%type <op> assign_op cmp_op add_op mul_op post_op 

/* Yacc start nonterminal */
%start program

/* Grammar section */
%%

program
	: decl_list 
	;

decl_list
	: decl_list decl
	| decl
	;

decl
	: var_decl
	| fun_decl
	;

var_decl
	: type_spec ID SEMICOLON { insertNode($2, VARIABLE_t, $1, false, false); }
	| type_spec ID ASGN expression SEMICOLON
	;

type_spec
	: VOID { $$=VOID_t; }
	| BOOL { $$=BOOLEAN_t; }
	| INT { $$=INTEGER_t; }
	| FLOAT { $$=FLOAT_t; } 
	| STRING { $$=STRING_t; }
	;

fun_decl
	: type_spec ID LB params RB SEMICOLON 
	| type_spec ID LB params RB function_compound_stmt
	;


params
	: param_list
	| VOID 	
	;

param_list
	: param_list COMMA param
	| param
	;

param
	: type_spec ID 
	|
	;

function_compound_stmt
	: LCB { var_count = 0; newTable(); }content_list RCB { removeTable(true); }
	;

compound_stmt
	: LCB { newTable(); }content_list RCB { removeTable(true); }
	;

content_list
	: content_list content
	|
	;

content
	: var_decl
	| stmt

stmt
	: assign_stmt
	| expression_stmt
	| compound_stmt 
	| if_stmt
	| while_stmt
	| return_stmt
	| print_stmt
	;

expression_stmt
	: expression SEMICOLON

assign_stmt
	: expression assign_op expression SEMICOLON

assign_op
	: ASGN { $$=ASGN_t; }
	| ADDASGN { $$=ADD_ASGN_t; }
	| SUBASGN { $$=SUB_ASGN_t; }
	| MULASGN { $$=MUL_ASGN_t; }
	| DIVASGN { $$=DIV_ASGN_t; }
	| MODASGN { $$=MOD_ASGN_t; }
	;

expression
	: or_expr
	;

or_expr
	: and_expr
	| or_expr OR and_expr
	;

and_expr
	: comparison_expr
	| and_expr AND comparison_expr
	;

comparison_expr
	: addition_expr
	| comparison_expr cmp_op addition_expr
	;

cmp_op
	: LT { $$=LT_t; }
	| MT { $$=MT_t; }
	| LTE { $$=LTE_t; }
	| MTE { $$=MTE_t; }
	| EQ { $$=EQ_t; }
	| NE { $$=NE_t; }
	;

addition_expr
	: multiplication_expr
	| addition_expr add_op multiplication_expr
	;

add_op
	: ADD { $$=ADD_t; }
	| SUB { $$=SUB_t; }
	;

multiplication_expr
	: postfix_expr
	| multiplication_expr mul_op postfix_expr
	;

mul_op
	: MUL { $$=MUL_t; }
	| DIV { $$=DIV_t; }
	| MOD { $$=MOD_t; }
	;

postfix_expr
	: parenthesis_clause
	| parenthesis_clause post_op
	;

post_op
	: INC { $$=INC_t; }
	| DEC { $$=DEC_t; }
	;

parenthesis_clause
	: constant
	| ID
	| func_invoke_stmt
	| LB expression RB
	;

constant
	: I_CONST
	| F_CONST
	| SUB I_CONST
	| SUB F_CONST
	| TRUE
	| FALSE
	| STRING_CONST
	;

print_stmt
	: PRINT LB ID RB SEMICOLON
    | PRINT LB I_CONST RB SEMICOLON
	| PRINT LB F_CONST RB SEMICOLON
	| PRINT LB STRING RB SEMICOLON
	;

while_stmt
	: WHILE LB expression RB compound_stmt

if_stmt
	: IF LB expression RB compound_stmt else_if_stmt else_stmt
	;

else_if_stmt
	: else_if_stmt ELSE IF LB expression RB compound_stmt 
	|
	;

else_stmt
	: ELSE compound_stmt
	|
	;

return_stmt
	: RET SEMICOLON
	| RET expression SEMICOLON

func_invoke_stmt
	: ID LB args RB

arg_list
	: arg_list COMMA expression
	| expression
	;

args
	: arg_list
	|
	;


%% 
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
struct SymTable newTable(){

    struct SymTable* new_tab = malloc(sizeof(struct SymTable));
	
    new_tab->first = NIL;
    new_tab->localVarCount = 0;
    new_tab->scope = scope;
    scope++;

    // If head is NIL, create a table
    if(HEAD == NIL){
        new_tab->next = NIL;
        HEAD = new_tab;
    }
    else{
        new_tab->next = HEAD;
        HEAD = new_tab;
    }

}

void removeTable(bool display){
    /* 
     * display_flag = 1, set dump flag
     * display_flag = 0, do not set dump flag
     */

    dump_flag = true;

    if(display){
        display_flag = true;
    }
    else{
        display_flag = false;
    }

    DUMP = HEAD;
    HEAD = HEAD->next;
    scope--;
}

void dumpTable(void){
	
    if(DUMP->first == NIL){

    }
    else{

        if(display_flag){
			
            printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
		           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
        }

        struct SymNode* ptr = DUMP->first;
        struct SymNode* del_ptr = NIL;
        while(ptr != NIL){
            if(display_flag){
                printf("%-10d", ptr->index);
                printf("%-10s", ptr->name);
                printf("%-12s", type2string(ptr->entry_type));
                printf("%-10s", type2string(ptr->data_type));
                printf("%-10d", ptr->scope);
            }

            if(ptr->entry_type == FUNCTION_t){
                int param_num = ptr->attribute->paramNum;
                struct TypeList* param_ptr = ptr->attribute->params;
                struct TypeList* del_param_ptr = NIL;
                while(param_num--){
                    if(display_flag){
                        if(param_num == 1){
                            printf("%s\n", type2string(param_ptr->type));
                        }
                        else{
                            printf("%s, ", type2string(param_ptr->type));
                        }
                    }
                    del_param_ptr = param_ptr;
                    param_ptr = param_ptr->next;
                    free(del_param_ptr);
                }
                free(ptr->attribute);
            }
			else{
				if(display_flag){
					printf("\n");
				}
			}
            del_ptr = ptr;
            ptr = ptr->next;
            free(del_ptr);
        }
		if(display_flag){
			printf("\n");
		}
    }

    free(DUMP);
    DUMP = NIL;
    dump_flag = false;
}


char* type2string(TYPE type){
    switch (type)
    {
    case BOOLEAN_t:
        return "bool";
        break;
    
    case VOID_t:
        return "void";
        break;
    
    case INTEGER_t:
        return "int";
        break;
    
    case FLOAT_t:
        return "float";
        break;

    case STRING_t:
        return "string";
        break;

    case VARIABLE_t:
        return "variable";
        break;
    
    case FUNCTION_t:
        return "function";
        break;
    
    case PARAMETER_t:
        return "parameter";
        break;
    
    default:
        break;
    }
}


void insertNode(const char* name, TYPE entry_type, TYPE data_type, bool isFuncDefine, bool prevScope){
    
    struct SymNode* new_node = malloc(sizeof(struct SymNode));
    strcpy(new_node->name, name);
	
    new_node->entry_type = entry_type;
    new_node->data_type = data_type;

    new_node->next = NIL;
    new_node->isFuncDefine = isFuncDefine;

    // TODO: Attribute

	// Insert to sym table
	if(prevScope){

		new_node->index = var_count++;
		HEAD->next->localVarCount++;
		new_node->scope = HEAD->next->scope;

		struct SymNode* ptr = HEAD->next->first;

		if (ptr == NIL){
			HEAD->next->first = new_node;
		} else {
			while(ptr->next != NIL){
				ptr = ptr->next;
			}
			ptr->next = new_node;
		}
	}
	else{

		new_node->index =  var_count++;
    	HEAD->localVarCount++;
		new_node->scope = HEAD->scope;

		struct SymNode* ptr = HEAD->first;
		
		if (ptr == NIL){
			HEAD->first = new_node;
		} else {
			while(ptr->next != NIL){
				ptr = ptr->next;
			}
			ptr->next = new_node;
		}
	}
}

/* code generation functions */
void gencode_function() {}
