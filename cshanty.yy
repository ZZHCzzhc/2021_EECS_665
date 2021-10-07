%skeleton "lalr1.cc"
%require "3.0"
%debug
%defines
%define api.namespace{cshanty}
%define api.parser.class {Parser}
%define parse.error verbose
%output "parser.cc"
%token-table

%code requires{
	#include <list>
	#include "tokens.hpp"
   	#include "ast.hpp"
	namespace cshanty {
		class Scanner;
	}

//The following definition is required when 
// we don't use the %locations directive (which we won't)
# ifndef YY_NULLPTR
#  if defined __cplusplus && 201103L <= __cplusplus
#   define YY_NULLPTR nullptr
#  else
#   define YY_NULLPTR 0
#  endif
# endif

//End "requires" code
}

%parse-param { cshanty::Scanner &scanner }
%parse-param { cshanty::ProgramNode** root }
%code{
   // C std code for utility functions
   #include <iostream>
   #include <cstdlib>
   #include <fstream>

   // Our code for interoperation between scanner/parser
   #include "scanner.hpp"
   #include "tokens.hpp"

  //Request tokens from our scanner member, not 
  // from a global function
  #undef yylex
  #define yylex scanner.yylex
}

/*
The %union directive is a way to specify the 
set of possible types that might be used as
translation attributes on a symbol.
For this project, only terminals have types (we'll
have translation attributes for non-terminals in the next
project)
*/
%union {
   cshanty::Token* lexeme;
   cshanty::Token* transToken;
   cshanty::IDToken*                       transIDToken;
   cshanty::ProgramNode*                   transProgram;
   std::list<cshanty::DeclNode *> *        transDeclList;
   cshanty::DeclNode *                     transDecl;
   cshanty::VarDeclNode *                  transVarDecl;
   cshanty::TypeNode *                     transType;
   cshanty::IDNode *                       transID;
   cshanty::LValNode *                     transLVal;
}

%define parse.assert

/* Terminals 
 *  No need to touch these, but do note the translation type
 *  of each node. Most are just "transToken", which is defined in
 *  the %union above to mean that the token translation is an instance
 *  of cshanty::Token *, and thus has no fields (other than line and column).
 *  Some terminals, like ID, are "transIDToken", meaning the translation
 *  also has a name field. 
*/
%token                   END	   0 "end file"
%token	<transToken>     AND
%token	<transToken>     ASSIGN
%token	<transToken>     BOOL
%token	<transToken>     CLOSE
%token	<transToken>     COMMA
%token	<transToken>     DEC
%token	<transToken>     DIVIDE
%token	<transToken>     ELSE
%token	<transToken>     EQUALS
%token	<transToken>     FALSE
%token	<transToken>     GREATER
%token	<transToken>     GREATEREQ
%token	<transIDToken>   ID
%token	<transToken>     IF
%token	<transToken>     INC
%token	<transToken>     INT
%token	<transIntToken>  INTLITERAL
%token	<transToken>     LBRACE
%token	<transToken>     LESS
%token	<transToken>     LESSEQ
%token	<transToken>     LPAREN
%token	<transToken>     MINUS
%token	<transToken>     NOT
%token	<transToken>     NOTEQUALS
%token	<transToken>     OPEN
%token	<transToken>     OR
%token	<transToken>     PLUS
%token	<transToken>     RBRACE
%token	<transToken>     RECEIVE
%token	<transToken>     RECORD
%token	<transToken>     REPORT
%token	<transToken>     RETURN
%token	<transToken>     RPAREN
%token	<transToken>     SEMICOL
%token	<transToken>     STRING
%token	<transStrToken>  STRLITERAL
%token	<transToken>     TIMES
%token	<transToken>     TRUE
%token	<transToken>     VOID
%token	<transToken>     WHILE

/* Nonterminals
*  The specifier in angle brackets
*  indicates the type of the translation attribute using
*  the names defined in the %union directive above
*  TODO: You will need to add more attributes for other nonterminals
*  to this list as you add productions to the grammar
*  below (along with indicating the appropriate translation
*  attribute type).
*/
/*    (attribute type)    (nonterminal)    */
%type <transProgram>    program
%type <transDeclList>   globals
%type <transDecl>       decl
%type <transVarDecl>    varDecl
%type <transType>       type
%type <transLVal>       lval
%type <transID>         id


%right ASSIGN
%left OR
%left AND
%nonassoc LESS GREATER LESSEQ GREATEREQ EQUALS NOTEQUALS
%left MINUS PLUS
%left TIMES DIVIDE
%left NOT 

%%

program 	: globals
		  {
		  $$ = new ProgramNode($1);
		  *root = $$;
		  }

globals 	: globals decl 
	  	  { 
	  	  $$ = $1; 
	  	  DeclNode * declNode = $2;
		  $$->push_back(declNode);
	  	  }
		| /* epsilon */
		  {
		  $$ = new std::list<DeclNode * >();
		  }

decl 		: varDecl
		  {
			//Passhthrough rule. This nonterminal is just for 
			// grammar structure
			$$ = $1; 
		  }
		| fnDecl 
		  { 
			//TODO: Make sure to fill out this rule
			// (as well as any other empty rule!)
			// with the appropriate SDD to create an AST
		  }
		| recordDecl { /* SDD Rules can even be on the same line if you want */ }

recordDecl	: RECORD id OPEN varDeclList CLOSE { }

varDecl 	: type id SEMICOL 
		  { 
		    Position * p = new Position($1->pos(), $2->pos());
		    $$ = new VarDeclNode(p, $1, $2);
		  }

varDeclList     : varDecl { }
		| varDeclList varDecl { }

type 		: INT { $$ = new IntTypeNode($1->pos()); }
		| BOOL { }
		| id { }
		| STRING { }
		| VOID { }

fnDecl 		: type id LPAREN RPAREN OPEN stmtList CLOSE { }
		| type id LPAREN formals RPAREN OPEN stmtList CLOSE { }

formals 	: formalDecl { }
		| formals COMMA formalDecl { }

formalDecl 	: type id { }

stmtList 	: /* epsilon */ { }
		| stmtList stmt { }

stmt		: varDecl { }
		| assignExp SEMICOL { }
		| lval DEC SEMICOL { }
		| lval INC SEMICOL { }
		| RECEIVE lval SEMICOL { }
		| REPORT exp SEMICOL { }
		| IF LPAREN exp RPAREN OPEN stmtList CLOSE { }
		| IF LPAREN exp RPAREN OPEN stmtList CLOSE ELSE OPEN stmtList CLOSE { }
		| WHILE LPAREN exp RPAREN OPEN stmtList CLOSE { }
		| RETURN exp SEMICOL { }
		| RETURN SEMICOL { }
		| callExp SEMICOL { }

exp		: assignExp { } 
		| exp MINUS exp { }
		| exp PLUS exp { }
		| exp TIMES exp { }
		| exp DIVIDE exp { }
		| exp AND exp { }
		| exp OR exp { }
		| exp EQUALS exp { }
		| exp NOTEQUALS exp
	  	  {
		  }
		| exp GREATER exp
	  	  {
		  }
		| exp GREATEREQ exp
	  	  {
		  }
		| exp LESS exp
	  	  {
		  }
		| exp LESSEQ exp
	  	  {
		  }
		| NOT exp { }
		| MINUS term { }
		| term { }

assignExp	: lval ASSIGN exp { }

callExp		: id LPAREN RPAREN { }
		| id LPAREN actualsList RPAREN { }

actualsList	: exp { }
		| actualsList COMMA exp { }

term 		: lval { }
		| INTLITERAL { }
		| STRLITERAL { }
		| TRUE { }
		| FALSE { }
		| LPAREN exp RPAREN { }
		| callExp { }

lval		: id { $$ = $1; }
		| id LBRACE id RBRACE { }

id		: ID
		  {
		  Position * pos = $1->pos();
		  $$ = new IDNode(pos, $1->value()); 
		  }

	
%%

void cshanty::Parser::error(const std::string& msg){
	std::cout << msg << std::endl;
	std::cerr << "syntax error" << std::endl;
}
