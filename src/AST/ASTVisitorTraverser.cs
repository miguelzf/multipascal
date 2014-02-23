﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using DGrok.Framework;

namespace crosspascal.AST
{
	// Delivers a visitor pattern with which to traverse the AST

	class ASTVisitorTraverser : GenericTraverser
	{
		public ASTVisitorTraverser(ASTProcessor processor) : base(processor) { }

		public override void traverse(AstNode n)
		{
			if (n != null)
				n.Accept(Processor);
		}
	}
}
