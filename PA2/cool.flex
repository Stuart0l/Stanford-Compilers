/*
 *  The scanner definition for COOL.
 */

/*
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */
%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
		YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

size_t cmt_layer = 0;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */

%}

/*
 * Define names for regular expressions here.
 */

DARROW		=>
digit		[0-9]
capital		[A-Z]
lower		[a-z]
space		[ \f\r\t\v]+

chars		[a-zA-Z_0-9]

int			{digit}+
type_id		{capital}{chars}*
obj_id		{lower}{chars}*
str			\"(\\.|[^\\"])*\"

%x			COMMENT
%x			STRING

%%

 /*
  *  Nested comments
  */
"--".*

<INITIAL,COMMENT>"(*" {
	cmt_layer++;
	BEGIN(COMMENT);
}

<COMMENT>"*)" {
	if (--cmt_layer == 0)
		BEGIN(INITIAL);
}
<COMMENT>.
<COMMENT>\n			++curr_lineno;

<COMMENT><<EOF>> {
	cool_yylval.error_msg = "EOF in comment.";
	BEGIN(INITIAL);
	return ERROR;
}
"*)" {
	cool_yylval.error_msg = "Unmatched *).";
	return ERROR;
}

 /*
  *  The multiple-character operators.
  */
{DARROW}		{ return DARROW; }
"<="			{ return LE; }
"<-"			{ return ASSIGN; }

 /*
  * Keywords are case-insensitive except for the values true and false,
  * which must begin with a lower-case letter.
  */
(?i:class)		{ return CLASS; }
(?i:else)		{ return ELSE; }
(?i:fi)			{ return FI; }
(?i:if)			{ return IF; }
(?i:in)			{ return IN; }
(?i:inherits)	{ return INHERITS; }
(?i:let)		{ return LET; }
(?i:loop)		{ return LOOP; }
(?i:pool)		{ return POOL; }
(?i:then)		{ return THEN; }
(?i:while)		{ return WHILE; }
(?i:case)		{ return CASE; }
(?i:esac)		{ return ESAC; }
(?i:of)			{ return OF; }
(?i:new)		{ return NEW; }
(?i:isvoid)		{ return ISVOID; }
(?i:not)		{ return NOT; }
t(?i:rue) {
	cool_yylval.boolean = 1;
	return BOOL_CONST;
}
f(?i:alse)	{
	cool_yylval.boolean = 0;
	return BOOL_CONST;
}

 /*
  *  String constants (C syntax)
  *  Escape sequence \c is accepted for all characters c. Except for 
  *  \n \t \b \f, the result is c.
  *
  */
  
\" {
	BEGIN(STRING);
	yymore();
}

<STRING>\n {
	cool_yylval.error_msg = "Unterminated string constant.";
	BEGIN(INITIAL);
	return ERROR;
}

 /*
 The regular expression can't match \0 well, thus handle this later.
<STRING>\0 {
	cool_yylval.error_msg = "String contains null character.";
	BEGIN(INITIAL);
	return ERROR;
}

<STRING>\\\0 {
	cool_yylval.error_msg = "String contains escaped null character.";
	BEGIN(INITIAL);
	return ERROR;
} */

<STRING><<EOF>> {
	cool_yylval.error_msg = "EOF in string constant.";
	BEGIN(INITIAL);
	yyrestart(yyin);
	return ERROR;
}

 /* www.lysator.liu.se/c/ANSI-C-grammar-l.html */
<STRING>(\\.|[^\\\"\n])* { yymore(); }

<STRING>\\\n {
	yymore();
	++curr_lineno;
}

<STRING>\" {
	std::string input(yytext, yyleng);
	std::string output = "";
	size_t i, last_i;
	
	input = input.substr(1, input.length() - 2);
	
	for (i = 0, last_i = 0; i < input.length(); i++) {
		if (input[i] == '\0') {
			cool_yylval.error_msg = "String contains null character.";
			BEGIN(INITIAL);
			return ERROR;
		}

		if (input[i] == '\\') {
			output += input.substr(last_i, i - last_i);

			switch (input[++i]) {
			case 'b':
				output += "\b";
				break;
			case 't':
				output += "\t";
				break;
			case 'n':
				output += "\n";
				break;
			case 'f':
				output += "\f";
				break;
			case '\0':
				cool_yylval.error_msg = "String contains escaped null character.";
				BEGIN(INITIAL);
				return ERROR;
			default:
				output += input[i];
				break;
			}
			last_i = i + 1;
		}
	}

	output += input.substr(last_i, i - last_i);
	
	if (output.length() >= MAX_STR_CONST) {
		cool_yylval.error_msg = "String constant too long.";
		BEGIN(INITIAL);
		return ERROR;
	}
	
	cool_yylval.symbol = stringtable.add_string((char *)output.c_str());
	BEGIN(INITIAL);
	return STR_CONST;
}

{int} {
    cool_yylval.symbol = inttable.add_string(yytext);
    return INT_CONST;
}
"SELF_TYPE"	{
	cool_yylval.symbol = idtable.add_string(yytext);
	return TYPEID;
}
"self" {
	cool_yylval.symbol = idtable.add_string(yytext);
	return OBJECTID;
}
{type_id} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return TYPEID;
}
{obj_id} {
	cool_yylval.symbol = idtable.add_string(yytext);
	return OBJECTID;
}

";"			{ return ';'; }
":"			{ return ':'; }
"."			{ return '.'; }
"@"			{ return '@'; }
"("			{ return '('; }
")"			{ return ')'; }
"{"			{ return '{'; }
"}"			{ return '}'; }
","			{ return ','; }
"+"			{ return '+'; }
"-"			{ return '-'; }
"*"			{ return '*'; }
"/"			{ return '/'; }
"~"			{ return '~'; }
"<"			{ return '<'; }
"="			{ return '='; }

{space}
"\n"			++curr_lineno;

. {
	cool_yylval.error_msg = yytext;
	return ERROR;
}

%%
