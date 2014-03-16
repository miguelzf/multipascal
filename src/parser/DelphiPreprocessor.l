using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Linq;

namespace crosspascal.parser
{

/**
 * Delphi Lexer
 * Generated by C# Flex, based on <a href="http://www.jflex.de/">JFlex</a>.
 */
	
%%
	
//%abstract
%public 
%class DelphiPreprocessor
//%implements
//%extends 
%function Preprocess

%8bit
	// %unicode
	
//%column
%line
	//Delphi is case insensitive
%ignorecase

// ------------------------------------------------------
// EOF treatment:
%integer	// eof type. same as: %type Int32

/*	// Use explicit <<EOF>> rules instead 
%eofval{
	// code to be injected in non-specified <STATE><<EOF>> rules
	return YYEOF;
%eofval}
*/

// %eofclose	// close the stream at EOF
%eof{
	// code to be injected in zzDoEOF() if (!zzEOfDone)
	zzEOFDone = false;	// revert changes of zzDoEOF()! Should only apply to the top-level stream
%eof}
// ------------------------------------------------------

%init{
	// code injected in the constructor
	// Inits the scanner
	InitLexer(@in);
%init}

%{
		// **********************************************
		// Creation and control
	
		public DelphiPreprocessor()
		{
			zzReader = null;
		}
		
		public void InitLexer(string fname)
		{
			StreamReader sr = new StreamReader(fname, DelphiParser.DefaultEncoding);
			InitLexer(sr);
		}

		public void InitLexer(TextReader sr)
		{	
			yyreset(sr);
			InitPreprocessor();
			
			// for debug
			stateNames = new string[] {"INITIAL", "XCOMMENT1", "XCOMMENT2", "XNOTDEF" };
			stateStack.Push(INITIAL);
		}
		

		// **********************************************
		// Directives processing
	
		Stack<Boolean> defines = new Stack<Boolean>();
	
		string GetDirectiveArg(string directive)
		{
			int ignlen = directive.Length + 2; // from: "{$"
			return yytext().Substring(ignlen, yylength()-1-ignlen).Trim();
		}	

		bool IsDefinedDir(string dir)
		{
			Boolean defined = IsDefined(GetDirectiveArg(dir));
			defines.Push(defined);
			return defined;
		}

		
		// **********************************************
		// Create output
		
		StringBuilder strbuilder = new StringBuilder(10000);	// 10k buffer
		
		public string GetOutput()
		{
			return strbuilder.ToString().ToLowerInvariant();	// Delphi is case-insensitive
		}

		// Emit newline if it's in the original src file
		void CheckSourceNewline()
		{
			if (!yymoreStreams())
				strbuilder.Append('\n');
		} 
		

		// **********************************************
		// Message functions
	
		void yydebug(String msg)
		{
			if (DelphiParser.DebugLevel > 0)
				Console.Out.WriteLine("[Line " + yyline + "] " + msg);
		}
		
		void pperror(String msg = "Unknown preprocessing error")
		{
		//	throw new PreprocessorException(yyline, msg);
			Console.Error.WriteLine("[ERROR preprocessor] " + msg + " in line " + yyline);
		}
		
%}


	// exclusive states
%x XCOMMENT1 XCOMMENT2 XNOTDEF
	// inclusive states. shared with INITIAL
//%s SFUNCDECL

	/* chomp up as much input as possible in one match */ 
ANYCHAR	= [ \t_a-zA-Z0-9:;!#.,=&*@><\\@$\[\]\^+\-]

NL      = (\r|\n|\r\n)	

%%

	/**************************************************************/
	/* Comments		*/

"//".*				{ }
\{					{ yypushstate(XCOMMENT1); }
\(\*				{ yypushstate(XCOMMENT2); }

<XCOMMENT1>\}		{ yypopstate(); }
<XCOMMENT2>\*\)		{ yypopstate(); }

<XCOMMENT2,XCOMMENT1> {
 [ \t_a-zA-Z0-9:;!#.,=&@><\\@$\[\]\^+\-')]	{ }
 {NL}				{ CheckSourceNewline(); }
 .					{ }
 <<EOF>>			{ throw new PreprocessorException(yyline, "Unterminated comment"); }
}


	/**************************************************************/
	/* PreProcessor - process compiler directives */
	
	
	/* includes */
"{$i "[^}]+\}		{
						string fpath = GetDirectiveArg("i");
						string incpath = SearchFile(fpath);
						
						if (incpath == null)
							pperror("Include file " + incpath + " not found");
						else
						{
							StreamReader sr = null;
							try {
								sr = new StreamReader(incpath, DelphiParser.DefaultEncoding);
							} 
							catch (IOException ioe) {
								pperror("Include file " + fpath + " could not be read: " + ioe.Message);
							}
							finally {
								yypushStream(sr);
								yydebug("Pushed stream from " + fpath + "");
							}
						}
					}

	/* defines */
"{$define "[^}]+\}	{	AddDefine(GetDirectiveArg("define"));	}

"{$undef "[^}]+\}	{	RemoveDefine(GetDirectiveArg("undef"));	}

	/* ifdefs */
"{$ifdef "[^}]+\}	{	if (!IsDefinedDir("ifdef"))
							yypushstate(XNOTDEF);
					}

"{$ifopt "[^}]+\}	{	if (!IsDefinedDir("ifopt"))
							yypushstate(XNOTDEF);
					}

"{$ifndef "[^}]+\}	{	Boolean defined = IsDefined(GetDirectiveArg("ifndef"));
						defines.Push(!defined);
						if (defined)
							yypushstate(XNOTDEF);
					}

"{$else"[^}]*\}		{	// currently in a defined section, switch to non-defined
						defines.Pop();
						defines.Push(false);
						yypushstate(XNOTDEF);
					}

"{$endif"[^}]*\}	{ defines.Pop(); }


/* Other compiler directives: ignored for now */
"{$"[^}]\}			{ }

	/* not-defined code section */
<XNOTDEF> {
 "//".*				{ }
 \{					{ yypushstate(XCOMMENT1); }
 \(\*				{ yypushstate(XCOMMENT2); }
 
					/* push true to signal that these defines are within a non-defined section */
 "{$ifdef "[^}]+\}	{ defines.Push(true); }

 "{$ifopt "[^}]+\}	{ defines.Push(true); }

 "{$ifndef "[^}]+\}	{ defines.Push(true); }

 "{$else"[^}]*\}	{	if (defines.Peek() == false)	// at the non-def section start, must leave
						{	yypopstate();
							defines.Pop();
							defines.Push(true);
						} // else, leave the top def as true
					}

 "{$endif"[^}]*\}	{	Boolean def = defines.Pop(); 
						if (def == false)
							yypopstate();
					}
 
 {ANYCHAR}+			{ /* chomp up as much as possible in one match */ }
 {NL}				{ CheckSourceNewline(); }
 .					{ /* ignore everything in a non-def section */ }
 <<EOF>>			{ throw new PreprocessorException(yyline, "Unterminated #ifdef"); }
}


	/**************************************************************/

{ANYCHAR}+			{ strbuilder.Append(zzBuffer, zzStartRead, zzMarkedPos-zzStartRead); }
											
'[^']*'				{ strbuilder.Append(zzBuffer, zzStartRead, zzMarkedPos-zzStartRead); }

\/|\(|\)			{ strbuilder.Append(yycharat(0)); }
{NL}				{ CheckSourceNewline(); }

<<EOF>>				{	if (yymoreStreams())
						{	yypopStream();
							yydebug("Popped stream and began initial state");
						}
						else
						{
							if (defines.Count > 0)
								throw new PreprocessorException(yyline, "Unterminated #ifdef");
							else
								return Accept(); /* top-level yyclose() */
						}
					}

.					{ pperror("Unknown char: " + text + " (ASCII " + ((int) text[0]) +")"); }


%%

}	// close outermost namespace