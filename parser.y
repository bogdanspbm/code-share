%skeleton "lalr1.cc"
%require "2.3"

%defines
%define api.namespace {calc}
%define api.value.type variant
%define api.parser.class {Parser}

%code requires {
    #include <iostream>
    #include <memory>
    #include "ast.h"
    namespace calc {class Lexer;}
}

%parse-param {calc::Lexer& lexer} {std::shared_ptr<Ast>& result} {std::string& message}

%code {
    #include "lexer.h"
    #define yylex lexer.lex
}

%token END 0 "end of file"
%token ERROR
%token EOL "\n"

%token <int> NUM
%token <std::string> NAME

%token EQUALS "="

%token IF "if"

%token DEF "def"
%token EXTEND ":"

%token DO "do"
%token DONE "done"

%token NOT "!"
%token AND "&&"
%token OR "||"

%token EQUAL "=="
%token NOT_EQUAL "!="
%token MORE_EQUAL ">="
%token MORE ">"
%token LESS_EQUAL "<="
%token LESS "<"

%token PLUS "+"
%token MINUS "-"
%token MUL "*"
%token DIV "/"
%token LPAR "("
%token RPAR ")"

%type <std::shared_ptr<Ast>> expr stmt condition block
%type <std::vector<std::string>> params
%type <std::vector<std::shared_ptr<Ast>>> arguments

%left "+" "-"
%left "*" "/"
%nonassoc U_MINUS

%left "||"
%left "&&"
%nonassoc "!"
%left "==" "!=" "<" "<=" ">" ">="


%%

input: expr "\n" { result = $1; }
    | stmt "\n" { result = $1; }
    | condition "\n" { result = $1; }

params : NAME { $$ = std::vector<std::string>{$1}; }
    | params "," NAME { $1.push_back($3); $$ = std::move($1); }


arguments : expr { $$ = std::vector<std::shared_ptr<Ast>>{$1}; }
    | arguments "," expr { $1.push_back($3); $$ = std::move($1); }


block : stmt { $$ = new_block($1); }
    | block "\n" stmt { $$ = add_to_block($1,$3); }


condition: expr "==" expr {$$ = new_binary(OpCode::EQUAL, $1, $3);}
        | expr "!=" expr {$$ = new_binary(OpCode::NOT_EQUAL, $1, $3);}
        | expr "&&" expr {$$ = new_binary(OpCode::AND, $1, $3);}
        | expr "||" expr {$$ = new_binary(OpCode::OR, $1, $3);}
        | expr ">=" expr {$$ = new_binary(OpCode::MORE_EQUAL, $1, $3);}
        | expr ">" expr {$$ = new_binary(OpCode::MORE, $1, $3);}
        | expr "<=" expr {$$ = new_binary(OpCode::LESS_EQUAL, $1, $3);}
        | expr "<" expr {$$ = new_binary(OpCode::LESS, $1, $3);}
        | "!" %prec NOT_EQUAL expr { $$ = new_unary(OpCode::NOT_EQUAL, $2); }

stmt: expr { $$ = $1; }
    | NAME "=" expr { $$ = new_assignment($1, $3);}
    | DEF NAME "(" params ")" ":" expr { $$ = new_definition($2, $4, $7); }
    | DEF NAME "(" params ")" ":" "do" "\n" block "\n" "done" { $$ = new_definition($2, $4, $9); }
    | "if" condition ":" block { $$ = new_union_condition($2, $4); }

expr: NUM { $$ = new_number($1); }
    | expr "+" expr { $$ = new_binary(OpCode::PLUS, $1, $3); }
    | expr "-" expr { $$ = new_binary(OpCode::MINUS, $1, $3); }
    | expr "*" expr { $$ = new_binary(OpCode::MUL, $1, $3); }
    | expr "/" expr { $$ = new_binary(OpCode::DIV, $1, $3); }
    | "(" expr ")" { $$ = $2; }
    | "-" %prec U_MINUS expr { $$ = new_unary(OpCode::U_MINUS, $2); }
    | NAME "(" arguments ")" { $$ = new_function($1, $3); }
    | NAME { $$ = new_variable($1); }
;
%%

void calc::Parser::error(const std::string& err)
{
    message = err;
}
