#ifndef _HEADER_H_
#define _HEADER_H_

#define BUF_SIZE 128
#define NIL (void*)-1
#include <stdbool.h>


typedef enum { BOOLEAN_t, VOID_t, INTEGER_t, FLOAT_t, STRING_t, \
               VARIABLE_t, FUNCTION_t, PARAMETER_t } TYPE;
typedef enum {
    ADD_t, SUB_t, MUL_t, DIV_t, MOD_t, INC_t, DEC_t,
    LTE_t, MTE_t, LT_t, MT_t, EQ_t, NE_t,
    ASGN_t, ADD_ASGN_t, SUB_ASGN_t, MUL_ASGN_t, DIV_ASGN_t, MOD_ASGN_t,
} OPERATOR;

struct TypeList {
    char name[30];
    TYPE type;
    struct TypeList* next;
};

struct FuncAttr {
    int paramNum;
    struct TypeList* params;    
};

struct SymNode {
    char name[30];
    int scope;
    TYPE entry_type;
    TYPE data_type;
    int index;
    struct SymNode* next;
    bool isFuncDefine;
    struct FuncAttr *attribute;
};

struct SymTable {
    struct SymTable* next;
    struct SymNode* first;
    int localVarCount;
    int scope;
    int while_count;
    int if_count;
    int elif_count;
};

#endif