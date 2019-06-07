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

char code_buf[BUF_SIZE];

FILE *file; // To generate .j file for Jasmin

void yyerror(char *s);

/* symbol table functions */
int var_count = 0;


bool err_flag = false;
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
char* type2String(TYPE type);
void dumpTable();
struct SymNode* lookupSymbol(char* name, bool recursive);

struct FuncAttr* temp_attribute = NIL;

/* code generation functions, just an example! */
void genPrint(TYPE type);
void codeGen(char const *s);
void genStore(struct SymNode* node);
void genLoad(struct SymNode* node);

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
%type <type> type_spec constant expression or_expr and_expr
%type <type> comparison_expr addition_expr multiplication_expr
%type <type> postfix_expr parenthesis_clause
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
	: global_var_decl
	| func_decl
	| func_def
	;

global_constant
	: I_CONST 
	| F_CONST 
	| SUB I_CONST { yylval.i_val *= -1; }
	| SUB F_CONST { yylval.f_val *= -1; }
	| TRUE 
	| FALSE 
	| STRING_CONST
	;

global_var_decl
	: type_spec ID ASGN global_constant SEMICOLON {
		// TODO: NOT DONE 
		// We can assume type will always be correct 
		if(lookupSymbol($2, false) == NIL){
			insertNode($2, VARIABLE_t, $1, false, false);
			char c;
			switch ($1){
				case INTEGER_t:
					c = 'I';
					sprintf(code_buf, ".field public static %s %c = %d\n", $2, c, yylval.i_val);
					codeGen(code_buf);
					break;
				case FLOAT_t:
					c = 'F';
					sprintf(code_buf, ".field public static %s %c = %f\n", $2, c, yylval.f_val);
					codeGen(code_buf);
					break;
				
				case BOOLEAN_t:
					c = 'I';
					sprintf(code_buf, ".field public static %s %c = %d\n", $2, c, yylval.i_val);
					codeGen(code_buf);
					break;
				
				default:
					yyerror("Unsupported global type\n");
					break;
			}
		}
		else{
			yyerror("Redeclared Symbol\n");
		}
	}
	;

var_decl
	: type_spec ID SEMICOLON { 	
		if(lookupSymbol($2, false) == NIL){
			insertNode($2, VARIABLE_t, $1, false, false);
			// Assign 0 as initial value
			struct SymNode* node = lookupSymbol($2, true);
			switch ($1){
				case INTEGER_t:
					codeGen("\tldc 0\n");
					genStore(node);
					break;

				case FLOAT_t:
					codeGen("\tldc 0.0\n");
					genStore(node);
					break;

				case BOOLEAN_t:
					codeGen("\tldc 0\n");
					genStore(node);
					break;

				case STRING_t:
					codeGen("\tldc \"\"\n");
					genStore(node);
					break;

				default:
					yyerror("Unsupported type in variable decl.\n");
					break;
			} 
		}
		else{
			yyerror("Redeclared Symbol\n");
		}
	}
	| type_spec ID ASGN expression SEMICOLON {
		if(lookupSymbol($2, false) == NIL){
			insertNode($2, VARIABLE_t, $1, false, false);
			struct SymNode* node = lookupSymbol($2, true);
			if($1 == INTEGER_t && $4 == INTEGER_t){
				// No need to cast int->int
			}
			else if($1 == INTEGER_t && $4 == FLOAT_t){
				// Cast stack to int float->int
				codeGen("\tf2i\n");
			}
			else if($1 == FLOAT_t && $4 == INTEGER_t){
				// Cast to float int->float
				codeGen("\ti2f\n");
			}
			else if($1 == FLOAT_t && $4 == FLOAT_t){
				// No need to cast float->float
			}
			else if($1 == STRING_t && $4 == STRING_t){
				// No need to cast string->string
			}
			else {
				yyerror("Type mismatch error\n");
			}
			genStore(node);
		}
		else{
			yyerror("Redeclared Symbol\n");
		}
	}
	;

type_spec
	: VOID { $$=VOID_t; }
	| BOOL { $$=BOOLEAN_t; }
	| INT { $$=INTEGER_t; }
	| FLOAT { $$=FLOAT_t; } 
	| STRING { $$=STRING_t; }
	;

func_decl
	: type_spec ID LB params RB SEMICOLON
	;
func_def
	: type_spec ID LB params RB { 
		if(!strcmp($2, "main")){
			fprintf(file,
                    ".method public static main([Ljava/lang/String;)V\n"
					".limit stack 50\n"
					".limit locals 50\n" );
		}
	} function_compound_stmt
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
	: LCB { var_count = 0; newTable(); } content_list RCB { removeTable(true); }
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
	: ID assign_op expression SEMICOLON

assign_op
	: ASGN { $$=ASGN_t; }
	| ADDASGN { $$=ADD_ASGN_t; }
	| SUBASGN { $$=SUB_ASGN_t; }
	| MULASGN { $$=MUL_ASGN_t; }
	| DIVASGN { $$=DIV_ASGN_t; }
	| MODASGN { $$=MOD_ASGN_t; }
	;

expression
	: or_expr { $$=$1; }
	;

or_expr
	: and_expr { $$=$1; }
	| or_expr OR and_expr { $$=BOOLEAN_t; }
	;

and_expr
	: comparison_expr { $$=$1; }
	| and_expr AND comparison_expr { $$=BOOLEAN_t; }
	;

comparison_expr
	: addition_expr { $$=$1; } 
	| comparison_expr cmp_op addition_expr { $$=BOOLEAN_t; }
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
	: multiplication_expr { $$=$1; }
	| addition_expr add_op multiplication_expr { //TEMP!!!
												 $$=INTEGER_t; }
	;

add_op
	: ADD { $$=ADD_t; }
	| SUB { $$=SUB_t; }
	;

multiplication_expr
	: postfix_expr { $$=$1; }
	| multiplication_expr mul_op postfix_expr { //TEMP!!!
												 $$=INTEGER_t; }
	;

mul_op
	: MUL { $$=MUL_t; }
	| DIV { $$=DIV_t; }
	| MOD { $$=MOD_t; }
	;

postfix_expr
	: parenthesis_clause { $$=$1; }
 	| parenthesis_clause post_op { //TEMP!!!
								   $$=INTEGER_t; }
	;

post_op
	: INC { $$=INC_t; }
	| DEC { $$=DEC_t; }
	;

parenthesis_clause
	: constant { $$=$1; }
	| ID { 
		struct SymNode* node = lookupSymbol($1, true);
		$$=node->data_type; 
		genLoad(node);
	}
	| func_invoke_stmt { //TEMP!!!
						 $$=INTEGER_t; }
	| LB expression RB { $$=$2; }
	;

constant
	: I_CONST { 
		$$=INTEGER_t; 
		sprintf(code_buf, "\tldc %d\n", yylval.i_val); 
		codeGen(code_buf);
	}
	| F_CONST { 
		$$=FLOAT_t; 
		sprintf(code_buf, "\tldc %f\n", yylval.f_val); 
		codeGen(code_buf);
	}
	| SUB I_CONST { 
		$$=INTEGER_t; 
		sprintf(code_buf, "\tldc %d\n", -1*yylval.i_val); 
		codeGen(code_buf);
	}
	| SUB F_CONST { 
		$$=FLOAT_t; 
		sprintf(code_buf, "\tldc %f\n", -1*yylval.f_val); 
		codeGen(code_buf);
	}
	| TRUE { 
		$$=BOOLEAN_t;
		sprintf(code_buf, "\tldc 1\n");
		codeGen(code_buf); 
	}
	| FALSE { 
		$$=BOOLEAN_t; 
		sprintf(code_buf, "\tldc 0\n");
		codeGen(code_buf);	
	}
	| STRING_CONST { 
		$$=STRING_t; 
		sprintf(code_buf, "\tldc \"%s\"\n", yylval.lexeme); 
		codeGen(code_buf);
	}
	;

print_stmt
	: PRINT LB ID RB SEMICOLON { 	
		struct SymNode* node = lookupSymbol($3, true);
		if( node != NIL){
			genLoad(node);
			genPrint(node->data_type);
		}
		else{
			yyerror("Undefined Variable in print()!\n");
		}
	}
    | PRINT LB constant RB SEMICOLON { genPrint($3); }
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
                    ".super java/lang/Object\n" );
	newTable();
    yyparse();

	removeTable(true);
	dumpTable();
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
                printf("%-12s", type2String(ptr->entry_type));
                printf("%-10s", type2String(ptr->data_type));
                printf("%-10d", ptr->scope);
            }

            if(ptr->entry_type == FUNCTION_t){
                int param_num = ptr->attribute->paramNum;
                struct TypeList* param_ptr = ptr->attribute->params;
                struct TypeList* del_param_ptr = NIL;
                while(param_num--){
                    if(display_flag){
                        if(param_num == 1){
                            printf("%s\n", type2String(param_ptr->type));
                        }
                        else{
                            printf("%s, ", type2String(param_ptr->type));
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


char* type2String(TYPE type){
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

struct SymNode* lookupSymbol(char* name, bool recursive){
	/*
	 * Return symbol node reference if found, NIL if not found
	 * If using recursive, try all existing symbol table
	 */
	
	struct SymTable* tab_ptr = HEAD;
	struct SymNode* node_ptr = tab_ptr->first;

	if(recursive){
		while(tab_ptr != NIL){
			node_ptr = tab_ptr->first;
			while(node_ptr != NIL){
				if(!strcmp(node_ptr->name, name)){
					return node_ptr;
				}	
				node_ptr = node_ptr->next;
			}
			tab_ptr = tab_ptr->next;
		}
		return NIL;
	}
	else{
		node_ptr = tab_ptr->first;
		while(node_ptr != NIL){
			if(!strcmp(node_ptr->name, name)){
				return node_ptr;
			}	
			node_ptr = node_ptr->next;
		}
		return NIL;
	}
}

/* code generation functions */
void genPrint(TYPE type){
	sprintf(code_buf, "\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n");
	codeGen(code_buf);
	sprintf(code_buf, "\tswap\n");
	codeGen(code_buf);

	switch (type)
	{
	case INTEGER_t:
		sprintf(code_buf, "\tinvokevirtual java/io/PrintStream/println(I)V\n");
		codeGen(code_buf);
		break;
	
	case FLOAT_t:
		sprintf(code_buf, "\tinvokevirtual java/io/PrintStream/println(F)V\n");
		codeGen(code_buf);
		break;
	
	case STRING_t:
		sprintf(code_buf, "\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
		codeGen(code_buf);
		break;
	
	default:
		yyerror("Unsupported Type in print() !");
	}
}

void codeGen(char const *s)
{
    if (!err_flag)
        fprintf(file, "%s", s);
}

void genStore(struct SymNode* node){
	int index = node->index;
	TYPE type = node->data_type;
	switch (type){
		case INTEGER_t:
			sprintf(code_buf, "\tistore %d\n", index);
			codeGen(code_buf);
			break;

		case FLOAT_t:
			sprintf(code_buf, "\tfstore %d\n", index);
			codeGen(code_buf);
			break;

		case STRING_t:
			sprintf(code_buf, "\tastore %d\n", index);
			codeGen(code_buf);
			break;

		case BOOLEAN_t:
			sprintf(code_buf, "\tistore %d\n", index);
			codeGen(code_buf);
			break;
		
		default:
			yyerror("Unable to generate store instruction\n");
			break;
	}
}

void genLoad(struct SymNode* node){
	int index = node->index;
	TYPE type = node->data_type;
	switch (type){
		case INTEGER_t:
			sprintf(code_buf, "\tiload %d\n", index);
			codeGen(code_buf);
			break;

		case FLOAT_t:
			sprintf(code_buf, "\tfload %d\n", index);
			codeGen(code_buf);
			break;

		case STRING_t:
			sprintf(code_buf, "\taload %d\n", index);
			codeGen(code_buf);
			break;

		case BOOLEAN_t:
			sprintf(code_buf, "\tiload %d\n", index);
			codeGen(code_buf);
			break;

		default:
			yyerror("Unable to generate load instruction\n");
			break;
	}
}