/*	Definition section */
%{
#include <stdio.h>
#include <stdlib.h>
#include "header.h" // include header if needed
#include <string.h>

// Flags and Variables for lex
extern int yylineno;
extern int yylex();
extern char *yytext; // Get current token from lex
extern char buf[BUF_SIZE]; // Get current code line from lex
extern bool semantic_error_flag;
extern bool syntax_error_flag;
char err_msg[BUF_SIZE];

// For temp code buffer
char code_buf[BUF_SIZE];

// To generate .j file for Jasmin
FILE *file; 

void yyerror(char *s);

TYPE func_ret = VOID_t;

int cmp_label=0;
int scope = 0;
/* symbol table functions */
int var_count = 0;

bool err_flag = false;
// Flags for lexer
bool dump_flag = false;
bool display_flag = false;

// Only head of the symbol table
struct SymTable* HEAD = NIL;
struct SymTable* DUMP = NIL;

struct SymTable newTable();
void removeTable(bool display_flag);
void insertNode(const char* name, TYPE entry_type, TYPE data_type, bool isFuncDefine, bool prevScope);
char* type2String(TYPE type);
char* type2Code(TYPE type);
void dumpTable();
struct SymNode* lookupSymbol(char* name, bool recursive);
bool assertAttributes(struct FuncAttr* a_attr, struct FuncAttr* b_attr);

struct FuncAttr* temp_attribute = NIL;
struct TypeList* temp_param = NIL;
void addAttribute(TYPE type, char* name);

/* code generation functions */
void genPrint(TYPE type);
void codeGen(char const *s);
void genStore(struct SymNode* node);
void genLoad(struct SymNode* node);
void doPostfixExpr(OPERATOR op, struct SymNode* node);

TYPE doMultExpr(OPERATOR op, TYPE left, TYPE right);
TYPE doMul(TYPE left, TYPE right);
TYPE doDiv(TYPE left, TYPE right);
TYPE doMod(TYPE left, TYPE right);

TYPE doAddExpr(OPERATOR op, TYPE left, TYPE right);
TYPE doAdd(TYPE left, TYPE right);
TYPE doSub(TYPE left, TYPE right);

void doCompExpr(OPERATOR op, TYPE left, TYPE right);

void doFuncCallArg(TYPE type);
void doInvokeFunc(struct SymNode* node);

void doAssign(OPERATOR op, struct SymNode* node, TYPE right);

void doGlobalVarDecl(char* name, TYPE type, bool hasValue);

bool lastConstZero = false;
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
%token I_CONST F_CONST STRING_CONST
%token VOID INT FLOAT BOOL STRING

/* Token with return */
%token <lexeme> ID

/* Nonterminal with return */
%type <type> type_spec constant expression or_expr and_expr
%type <type> comparison_expr addition_expr multiplication_expr
%type <type> parenthesis_clause func_invoke_stmt 
%type <op> assign_op cmp_op add_op mul_op post_op 

/* Yacc start nonterminal */
%start program

/* Grammar section */
%%

program
	: decl_list 
	| error { syntax_error_flag = true; }
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
	;

global_var_decl
	: type_spec ID ASGN global_constant SEMICOLON {
		doGlobalVarDecl($2, $1, true);
	}
	| type_spec ID SEMICOLON {
		doGlobalVarDecl($2, $1, false);
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
					yyerror("Unsupported type in variable decl!");
					break;
			} 
		}
		else{
			yyerror("Redeclared Symbol!");
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
			else if($1 == BOOLEAN_t && $4 == BOOLEAN_t){
				// No need to cast bool->bool
			}
			else {
				yyerror("Type mismatch error!");
			}
			genStore(node);
		}
		else{
			yyerror("Redeclared Variable");
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
	: type_spec ID LB params RB SEMICOLON {
		// Deal with no parameter 
		if(temp_attribute == NIL){
			temp_attribute = malloc(sizeof(struct FuncAttr));
			temp_attribute->paramNum = 0;
			temp_attribute->params = malloc(sizeof(struct TypeList));
			temp_attribute->params->type = VOID_t;
			temp_attribute->params->next = NIL;
		}

		// Insert to symbol table, check for redeclear first
		struct SymNode* node = lookupSymbol($2, false);
		if(node == NIL){
			insertNode($2, FUNCTION_t, $1, false, false);
		}
		else if(node != NIL && node->entry_type == FUNCTION_t){
			if(node->isFuncDefine == false){
				yyerror("Redeclared Function");
			}
			if($1 != node->data_type){
				yyerror("Function return type is not the same");
			}
			if(!assertAttributes(temp_attribute, node->attribute)){
				yyerror("Function formal parameter is not the same");
			}
		}

		temp_attribute = NIL;
	}
	;
func_def
	: type_spec ID LB params RB { 

		// Deal with no parameter 
		if(temp_attribute == NIL){
			temp_attribute = malloc(sizeof(struct FuncAttr));
			temp_attribute->paramNum = 0;
			temp_attribute->params = malloc(sizeof(struct TypeList));
			temp_attribute->params->type = VOID_t;
			temp_attribute->params->next = NIL;
		}
		
		// Insert to symbol table, check for redeclear first
		struct SymNode* node = lookupSymbol($2, false);
		if(node == NIL){
			insertNode($2, FUNCTION_t, $1, true, false);
		}
		else if(node != NIL && node->entry_type == FUNCTION_t){
			if(node->isFuncDefine == true){
				yyerror("Redefined Function");
			}
			if($1 != node->data_type){
				yyerror("Function return type is not the same");
			}
			if(!assertAttributes(temp_attribute, node->attribute)){
				yyerror("Function formal parameter is not the same");
			}
		}
	
        codeGen(".method public static ");
		codeGen($2);
		codeGen("(");
		// Generate Param Types
		struct TypeList* ptr = temp_attribute->params;
		if(!strcmp($2, "main")){
			if(temp_attribute->paramNum != 0){
				yyerror("Main function should not have parameter!");
			}
			codeGen(type2Code(STRING_t));
		}
		else{
			while(ptr != NIL){
				if(ptr->type != VOID_t){
					codeGen(type2Code(ptr->type));
				}
				ptr = ptr->next;
			}
		}
		
		codeGen(")");
		// Generate Return Type
		if(!strcmp($2, "main")){
			codeGen(type2Code(VOID_t));
			if($1 != VOID_t){
				yyerror("Main function should return void!");
			}
			func_ret = VOID_t;
		}
		else{
			func_ret = $1;
			codeGen(type2Code($1));
		}
		
		codeGen("\n");

		codeGen(".limit stack 50\n");
		codeGen(".limit locals 50\n");		


		// Open a new table, insert params first
		var_count = 0; 
		newTable(); 	
		
		ptr = temp_attribute->params;
		while(ptr != NIL && temp_attribute->paramNum != 0){
			insertNode(ptr->name, PARAMETER_t, ptr->type, false, false);
			ptr = ptr->next;
		}
		
		temp_attribute = NIL;
		
		struct SymNode* node_ptr = HEAD->first;
		while(node_ptr != NIL){
			genLoad(node_ptr);
			node_ptr = node_ptr->next;
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
	: type_spec ID {
		addAttribute($1, $2);
	}
	|
	;

function_compound_stmt
	: LCB content_list  RCB { removeTable(true); codeGen(".end method\n"); }
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
	| return_stmt
	| expression_stmt
	| compound_stmt 
	| if_stmt
	| while_stmt
	| print_stmt
	;

expression_stmt
	: func_invoke_stmt SEMICOLON
	| postfix_expr SEMICOLON
	;

postfix_expr
 	: ID post_op {
		struct SymNode* node = lookupSymbol($1, true); 
		if(node == NIL){
			yyerror("Undeclared variable");
		}
		doPostfixExpr($2, node); 
	}
	;

post_op
	: INC { $$=INC_t; }
	| DEC { $$=DEC_t; }
	;

assign_stmt
	: ID assign_op expression SEMICOLON {
		struct SymNode* node = lookupSymbol($1, true);
		if(node == NIL){
			yyerror("Undeclared Variable");
		}
		doAssign($2, node, $3);
	}

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
	| or_expr OR and_expr { 
		$$=BOOLEAN_t; 
		if( $1 != BOOLEAN_t || $3 != BOOLEAN_t ){
			yyerror("Cannot do OR with other type than bool");
		}
		else{
			codeGen("\tior\n");
		}
	}
	;

and_expr
	: comparison_expr { $$=$1; }
	| and_expr AND comparison_expr { 
		$$=BOOLEAN_t; 
		if( $1 != BOOLEAN_t || $3 != BOOLEAN_t ){
			yyerror("Cannot do AND with other type than bool");
		}
		else{
			codeGen("\tiand\n");
		}
	}
	;

comparison_expr
	: addition_expr { $$=$1; } 
	| comparison_expr cmp_op addition_expr { 
		doCompExpr($2, $1, $3);
		$$=BOOLEAN_t; 
	}
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
	| addition_expr add_op multiplication_expr {
		$$=doAddExpr($2, $1, $3); 
	}
	;

add_op
	: ADD { $$=ADD_t; }
	| SUB { $$=SUB_t; }
	;

multiplication_expr
	: parenthesis_clause { $$=$1; }
	| multiplication_expr mul_op parenthesis_clause { 
		$$=doMultExpr($2, $1, $3);
	}
	;

mul_op
	: MUL { $$=MUL_t; }
	| DIV { $$=DIV_t; }
	| MOD { $$=MOD_t; }
	;


parenthesis_clause
	: constant { $$=$1; }
	| ID { 
		struct SymNode* node = lookupSymbol($1, true);
		if(node == NIL){
			yyerror("Undeclared variable");
		}
		$$=node->data_type; 
		genLoad(node);
		lastConstZero = false;
	}
	| func_invoke_stmt { lastConstZero = false; $$=$1; }
	| LB expression RB { $$=$2; }
	;

constant
	: I_CONST { 
		$$=INTEGER_t; 
		sprintf(code_buf, "\tldc %d\n", yylval.i_val); 
		codeGen(code_buf);

		if(yylval.i_val == 0){
			lastConstZero = true;
		}
		else{
			lastConstZero = false;
		}
	}
	| F_CONST { 
		$$=FLOAT_t; 
		sprintf(code_buf, "\tldc %f\n", yylval.f_val); 
		codeGen(code_buf);

		if(yylval.f_val == 0){
			lastConstZero = true;
		}
		else{
			lastConstZero = false;
		}
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
			yyerror("Undefined Variable in print()!");
		}
	}
    | PRINT LB constant RB SEMICOLON { genPrint($3); }
	;

while_stmt
	: WHILE {
		sprintf(code_buf, "L_WHILE_%d_%d", HEAD->while_count, HEAD->scope);
		codeGen(code_buf);	
		codeGen(":\n");
	}
	LB expression RB {
		sprintf(code_buf, "\tifeq L_WHILE_EXIT_%d_%d\n", HEAD->while_count, HEAD->scope);
		codeGen(code_buf);
	}
	compound_stmt{
		sprintf(code_buf, "\tgoto L_WHILE_%d_%d\n", HEAD->while_count, HEAD->scope);
		codeGen(code_buf);
		sprintf(code_buf, "L_WHILE_EXIT_%d_%d", HEAD->while_count, HEAD->scope);
		codeGen(code_buf);
		codeGen(":\n");
		HEAD->while_count++;
	}

if_stmt
	: IF LB expression RB {
		HEAD->elif_count = 0;
		sprintf(code_buf, "\tifeq L_THEN%d_%d_%d\n",HEAD->elif_count, HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
	}compound_stmt {
		sprintf(code_buf, "\tgoto L_COND_EXIT_%d_%d\n", HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
		sprintf(code_buf, "L_THEN%d_%d_%d",HEAD->elif_count, HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
		codeGen(":\n");
		HEAD->elif_count ++;
	} else_if_stmt else_stmt {
		sprintf(code_buf, "L_COND_EXIT_%d_%d", HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
		codeGen(":\n");
		HEAD->if_count++;
		HEAD->elif_count = 0;
	}
	;

else_if_stmt
	: else_if_stmt ELSE IF LB expression RB {
		sprintf(code_buf, "\tifeq L_THEN%d_%d_%d\n",HEAD->elif_count, HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
	}compound_stmt {
		sprintf(code_buf, "\tgoto L_COND_EXIT_%d_%d\n", HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
		sprintf(code_buf, "L_THEN%d_%d_%d",HEAD->elif_count, HEAD->if_count, HEAD->scope);
		codeGen(code_buf);
		codeGen(":\n");
		HEAD->elif_count ++;
	}
	|
	;

else_stmt
	: ELSE compound_stmt
	|
	;

return_stmt
	: RET SEMICOLON {
		if(func_ret == VOID_t){
			codeGen("\treturn\n");
		}
		else{
			yyerror("Return is not void");
		}
	}
	| RET expression SEMICOLON{
		
		if(func_ret == INTEGER_t && $2 == INTEGER_t){
			// No need to cast int->int
			codeGen("\tireturn\n");
		}
		else if(func_ret == INTEGER_t && $2 == FLOAT_t){
			// Cast stack to int float->int
			codeGen("\tf2i\n");
			codeGen("\tireturn\n");
		}
		else if(func_ret == FLOAT_t && $2 == INTEGER_t){
			// Cast to float int->float
			codeGen("\ti2f\n");
			codeGen("\tfreturn\n");
		}
		else if(func_ret == FLOAT_t && $2 == FLOAT_t){
			// No need to cast float->float
			codeGen("\tfreturn\n");
		}
		else if(func_ret == BOOLEAN_t && $2 == BOOLEAN_t){
			// No need to cast bool->bool
			codeGen("\tireturn\n");
		}
		else {
			//yyerror("Return Type mismatch error");
		}
	
	}

func_invoke_stmt
	: ID {
		struct SymNode* node = lookupSymbol($1, true);
		if(node == NIL || node->scope != 0 || node->entry_type != FUNCTION_t){
			yyerror("Undeclared Function");
		}
		else{
			temp_attribute = node->attribute;
			temp_param = temp_attribute->params;
		}
	} LB args RB {
		struct SymNode* node = lookupSymbol($1, true);
		doInvokeFunc(node);
		$$=node->data_type;
		temp_attribute = NIL;
	}

arg_list
	: arg_list COMMA expression{
		doFuncCallArg($3);
		if(temp_param != NIL){
			yyerror("Function formal parameter is not the same");
		}
	}
	| expression {
		doFuncCallArg($1);
	}
	;

args
	: arg_list
	| {
		if(temp_attribute->paramNum != 0){
			yyerror("Function formal parameter is not the same");
		}
	}
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


    fclose(file);

	if(err_flag){
		remove("compiler_hw3.j");
	}
	
    return 0;
}

void yyerror(char *s)
{
	err_flag = true;
    if(!strcmp(s, "syntax error")){
		syntax_error_flag = true;
	}
	else{
		semantic_error_flag = true;
		strncpy(err_msg, s, strlen(s));
	}
}

/* stmbol table functions */
struct SymTable newTable(){

    struct SymTable* new_tab = malloc(sizeof(struct SymTable));
	
    new_tab->first = NIL;
    new_tab->localVarCount = 0;
	new_tab->while_count = 0;
	new_tab->if_count = 0;
	new_tab->elif_count = 0;
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
                if (param_num == 0){
					printf("\n");
				}
				while(param_num--){
                    if(display_flag){
                        if(param_num == 0){
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

char* type2Code(TYPE type){
    switch (type)
    {
    case BOOLEAN_t:
        return "Z";
        break;
    
    case VOID_t:
        return "V";
        break;
    
    case INTEGER_t:
        return "I";
        break;
    
    case FLOAT_t:
        return "F";
        break;

    case STRING_t:
        return "[Ljava/lang/String;";
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

    // Attribute
	if(entry_type == FUNCTION_t){
		if(temp_attribute == NIL){
			yyerror("ERR!! temp attribute should not be NIL!");
		}
		else{
			new_node->attribute = temp_attribute;
		}
	}

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

void addAttribute(TYPE type, char* name){
	if(temp_attribute == NIL){
		temp_attribute = malloc(sizeof(struct FuncAttr));
		temp_attribute->paramNum = 1;
		struct TypeList* new_param = malloc(sizeof(struct TypeList));
		new_param->type = type;
		new_param->next = NIL;
		strcpy(new_param->name, name);
		temp_attribute->params = new_param;
	}
	else{
		struct TypeList* new_param = malloc(sizeof(struct TypeList));
		new_param->type = type;
		new_param->next = NIL;
		strcpy(new_param->name, name);

		struct TypeList* ptr = temp_attribute->params;
		while(ptr->next != NIL){
			ptr = ptr->next;
		}

		ptr->next = new_param;

		temp_attribute->paramNum += 1;
	}
}

bool assertAttributes(struct FuncAttr* a_attr, struct FuncAttr* b_attr){
	if(a_attr->paramNum != b_attr->paramNum){
		return false;
	}
	int attr_count = a_attr->paramNum;	
	struct TypeList* a_param = a_attr->params;
	struct TypeList* b_param = b_attr->params;

	while(attr_count--){
		if(a_param->type != b_param->type){
			return false;
		}
		a_param = a_param->next;
		b_param = b_param->next;
	}

	return true;
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
	
	case BOOLEAN_t:
		sprintf(code_buf, "\tinvokevirtual java/io/PrintStream/println(I)V\n");
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
	TYPE data_type = node->data_type;
	char* type = type2Code(data_type);
	char* name = node->name;
	bool isStatic = false;
	if(node->scope == 0){
		isStatic = true;
	}
	switch (data_type){
		case INTEGER_t:
			if(isStatic){
				sprintf(code_buf, "\tputstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tistore %d\n", index);
			}
			codeGen(code_buf);
			break;

		case FLOAT_t:
			if(isStatic){
				sprintf(code_buf, "\tputstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tfstore %d\n", index);
			}
			codeGen(code_buf);
			break;

		case STRING_t:
			if(isStatic){
				sprintf(code_buf, "\tputstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tastore %d\n", index);
			}
			codeGen(code_buf);
			break;

		case BOOLEAN_t:
			if(isStatic){
				sprintf(code_buf, "\tputstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tistore %d\n", index);
			}
			codeGen(code_buf);
			break;
		
		default:
			yyerror("Unable to generate store instruction\n");
			break;
	}
}

void genLoad(struct SymNode* node){
	int index = node->index;
	TYPE data_type = node->data_type;
	char* type = type2Code(data_type);
	char* name = node->name;
	bool isStatic = false;
	if(node->scope == 0){
		isStatic = true;
	}
	switch (data_type){
		case INTEGER_t:
			if(isStatic){
				sprintf(code_buf, "\tgetstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tiload %d\n", index);
			}
			codeGen(code_buf);
			break;

		case FLOAT_t:
			if(isStatic){
				sprintf(code_buf, "\tgetstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tfload %d\n", index);
			}
			codeGen(code_buf);
			break;

		case STRING_t:
			if(isStatic){
				sprintf(code_buf, "\tgetstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\taload %d\n", index);
			}
			codeGen(code_buf);
			break;

		case BOOLEAN_t:
			if(isStatic){
				sprintf(code_buf, "\tgetstatic compiler_hw3/%s %s\n", name, type);
			}
			else{
				sprintf(code_buf, "\tiload %d\n", index);
			}
			codeGen(code_buf);
			break;

		default:
			yyerror("Unable to generate load instruction\n");
			break;
	}
}


void doPostfixExpr(OPERATOR op, struct SymNode* node){
	genLoad(node);
	switch(op){
	case INC_t:
		if(node->data_type == INTEGER_t){
			codeGen("\tldc 1\n");
			codeGen("\tiadd\n");
			genStore(node);
		}
		else if(node->data_type == FLOAT_t){
			codeGen("\tldc 1.0\n");
			codeGen("\tfadd\n");
			genStore(node);
		}
		else{
			yyerror("Only int and float can do post expression");
		}
		break;
		
	case DEC_t:
		if(node->data_type == INTEGER_t){
			codeGen("\tldc 1\n");
			codeGen("\tisub\n");
			genStore(node);
		}
		else if(node->data_type == FLOAT_t){
			codeGen("\tldc 1.0\n");
			codeGen("\tfsub\n");
			genStore(node);
		}
		else{
			yyerror("Only int and float can do post expression");
		}
		break;
	}
}

TYPE doMultExpr(OPERATOR op, TYPE left, TYPE right){
	switch(op){
	case MUL_t:
		return doMul(left, right);
		break;
	
	case DIV_t:
		return doDiv(left, right);
		break;

	case MOD_t:
		return doMod(left, right);
		break;

	}
}

TYPE doMul(TYPE left, TYPE right){
	if(left == INTEGER_t && right == INTEGER_t){
		codeGen("\timul\n");
		return INTEGER_t;
	}
	else if(left == INTEGER_t && right == FLOAT_t){
		// save to temp register
		codeGen("\tswap\n");
		// change type
		codeGen("\ti2f\n");
		// push back
		codeGen("\tswap\n");
		codeGen("\tfmul\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == FLOAT_t){
		codeGen("\tfmul\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == INTEGER_t){
		// change to float
		codeGen("\ti2f\n");
		codeGen("\tfmul\n");
		return FLOAT_t;
	}
	else{
		yyerror("Only int and float can do multiplication");
	}
}

TYPE doDiv(TYPE left, TYPE right){
	if(lastConstZero){
		yyerror("Divide by zero");
	}
	if(left == INTEGER_t && right == INTEGER_t){
		codeGen("\tidiv\n");
		return INTEGER_t;
	}
	else if(left == INTEGER_t && right == FLOAT_t){
		// save to temp register
		codeGen("\tswap\n");
		// change type
		codeGen("\ti2f\n");
		// push back
		codeGen("\tswap\n");
		codeGen("\tfdiv\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == FLOAT_t){
		codeGen("\tfdiv\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == INTEGER_t){
		// change to float
		codeGen("\ti2f\n");
		codeGen("\tfdiv\n");
		return FLOAT_t;
	}
	else{
		yyerror("Only int and float can do division");
	}
}

TYPE doMod(TYPE left, TYPE right){
	if(left == INTEGER_t && right == INTEGER_t){
		codeGen("\tirem\n");
		return INTEGER_t;
	}
	else{
		yyerror("Only int can do mod");
	}
}


TYPE doAddExpr(OPERATOR op, TYPE left, TYPE right){
	switch(op){
	case ADD_t:
		return doAdd(left, right);
		break;
	
	case SUB_t:
		return doSub(left, right);
		break;
	}
}
TYPE doAdd(TYPE left, TYPE right){
	if(left == INTEGER_t && right == INTEGER_t){
		codeGen("\tiadd\n");
		return INTEGER_t;
	}
	else if(left == INTEGER_t && right == FLOAT_t){
		// save to temp register
		codeGen("\tswap\n");
		// change type
		codeGen("\ti2f\n");
		// push back
		codeGen("\tswap\n");
		codeGen("\tfadd\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == FLOAT_t){
		codeGen("\tfadd\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == INTEGER_t){
		// change to float
		codeGen("\ti2f\n");
		codeGen("\tfadd\n");
		return FLOAT_t;
	}
	else{
		yyerror("Only int and float can do addition");
	}
}
TYPE doSub(TYPE left, TYPE right){
	if(left == INTEGER_t && right == INTEGER_t){
		codeGen("\tisub\n");
		return INTEGER_t;
	}
	else if(left == INTEGER_t && right == FLOAT_t){
		// save to temp register
		codeGen("\tswap\n");
		// change type
		codeGen("\ti2f\n");
		// push back
		codeGen("\tswap\n");
		codeGen("\tfsub\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == FLOAT_t){
		codeGen("\tfsub\n");
		return FLOAT_t;
	}
	else if(left == FLOAT_t && right == INTEGER_t){
		// change to float
		codeGen("\ti2f\n");
		codeGen("\tfsub\n");
		return FLOAT_t;
	}
	else{
		yyerror("Only int and float can do subtraction");
	}
}


void doCompExpr(OPERATOR op, TYPE left, TYPE right){
	if(left == INTEGER_t && right == INTEGER_t){
		// change right to float
		codeGen("\ti2f\n");
		// save right to register
		codeGen("\tswap\n");
		// change left to float
		codeGen("\ti2f\n");
		// pushback right
		codeGen("\tswap\n");
	}
	else if(left == INTEGER_t && right == FLOAT_t){
		// save right to register
		codeGen("\tswap\n");
		// change left to float
		codeGen("\ti2f\n");
		// pushback right
		codeGen("\tswap\n");
	}
	else if(left == FLOAT_t && right == FLOAT_t){
		// no need to cast
	}
	else if(left == FLOAT_t && right == INTEGER_t){
		codeGen("\ti2f\n");
	}
	else{
		yyerror("Unsupported data type for comparison");
	}

	// Do compare
	codeGen("\tfcmpl\n");

	char label_name[10];
	char op_code[10];

	switch(op){
	case LT_t:
		sprintf(op_code, "iflt");
		sprintf(label_name, "LT");
		break;
	
	case MT_t:
		sprintf(op_code, "ifgt");
		sprintf(label_name, "MT");
		break;

	case LTE_t:
		sprintf(op_code, "ifle");
		sprintf(label_name, "LTE");
		break;

	case MTE_t:
		sprintf(op_code, "ifge");
		sprintf(label_name, "MTE");
		break;

	case EQ_t:
		sprintf(op_code, "ifeq");
		sprintf(label_name, "EQ");
		break;

	case NE_t:
		sprintf(op_code, "ifne");
		sprintf(label_name, "NE");
		break;
	}

	sprintf(code_buf, "\t%s L_%s_TRUE_%d\n", op_code, label_name, cmp_label);
	codeGen(code_buf);
	codeGen("\ticonst_0\n");
	sprintf(code_buf, "\tgoto L_%s_FALSE_%d\n", label_name, cmp_label);
	codeGen(code_buf);
	sprintf(code_buf, "L_%s_TRUE_%d:\n", label_name, cmp_label);
	codeGen(code_buf);
	codeGen("\ticonst_1\n");
	sprintf(code_buf,"L_%s_FALSE_%d:\n", label_name, cmp_label);
	codeGen(code_buf);

	cmp_label++;
}

void doFuncCallArg(TYPE type){
	if(type != temp_param->type){
		if (type == INTEGER_t && temp_param->type == FLOAT_t){
			codeGen("\ti2f\n");
		}
		else {
			yyerror("Function formal parameter is not the same");
		}
	}
	temp_param = temp_param -> next;
}


void doInvokeFunc(struct SymNode* node){
	codeGen("\tinvokestatic compiler_hw3/");
	codeGen(node->name);
	codeGen("(");
	// Generate Param Types
	struct TypeList* ptr = node->attribute->params;
	while(ptr != NIL){
		if(ptr->type != VOID_t){
			codeGen(type2Code(ptr->type));
		}
		ptr = ptr->next;
	}
	codeGen(")");
	// Generate Return Type
	codeGen(type2Code(node->data_type));
	codeGen("\n");
}

void doAssign(OPERATOR op, struct SymNode* node, TYPE right){
	
	TYPE left = node->data_type;

	switch(op){
	case ASGN_t:
		if(left == INTEGER_t && right == INTEGER_t){
			genStore(node);
		}
		else if(left == INTEGER_t && right == FLOAT_t){
			codeGen("\tf2i\n");
			genStore(node);
		}
		else if(left == FLOAT_t && right == FLOAT_t){
			genStore(node);
		}
		else if(left == FLOAT_t && right == INTEGER_t){
			codeGen("\ti2f\n");
			genStore(node);
		}
		else if(left == BOOLEAN_t && right == BOOLEAN_t){
			genStore(node);
		}
		else if(left == STRING_t && right == STRING_t){
			genStore(node);
		}
		else{
			yyerror("Wrong type at assign!");
		}
		break;
		
	case ADD_ASGN_t:
		genLoad(node);
		codeGen("\tswap\n");
		doAdd(left, right);
		genStore(node);
		break;
	
	case SUB_ASGN_t:
		genLoad(node);
		codeGen("\tswap\n");
		doSub(left, right);
		genStore(node);
		break;
	
	case DIV_ASGN_t:
		genLoad(node);
		codeGen("\tswap\n");
		doDiv(left, right);
		genStore(node);
		break;

	case MOD_ASGN_t:
		genLoad(node);
		codeGen("\tswap\n");
		doMod(left, right);
		genStore(node);
		break;

	case MUL_ASGN_t:
		genLoad(node);
		codeGen("\tswap\n");
		doMul(left, right);
		genStore(node);
		break;
	}

	return;
}

void doGlobalVarDecl(char* name, TYPE type, bool hasValue){
	// We can assume type will always be correct 
	if(lookupSymbol(name, false) == NIL){
		insertNode(name, VARIABLE_t, type, false, false);
		char c;
		switch (type){
			case INTEGER_t:
				c = 'I';
				if(hasValue){
					sprintf(code_buf, ".field public static %s %c = %d\n", name, c, yylval.i_val);
				}
				else{
					sprintf(code_buf, ".field public static %s %c\n", name, c);
				}
				codeGen(code_buf);
				break;
			case FLOAT_t:
				c = 'F';
				if(hasValue){
					if(yylval.f_val == 0){
						sprintf(code_buf, ".field public static %s %c\n", name, c);
					}
					else{
						sprintf(code_buf, ".field public static %s %c = %f\n", name, c, yylval.f_val);	
					}
				}
				else{
					sprintf(code_buf, ".field public static %s %c\n", name, c);
				}
				codeGen(code_buf);
				break;
			
			case BOOLEAN_t:
				c = 'I';
				if(hasValue){
					sprintf(code_buf, ".field public static %s %c = %d\n", name, c, yylval.i_val);					
				}
				else{
					sprintf(code_buf, ".field public static %s %c\n", name, c);
				}

				codeGen(code_buf);
				break;
			
			default:
				yyerror("Unsupported global type!");
				break;
		}
	}
	else{
		yyerror("Redeclared Variable");
	}
}