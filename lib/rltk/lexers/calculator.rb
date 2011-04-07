# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2011/03/04
# Description:	This file contains a lexer for a simple calculator.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/lexer'

#######################
# Classes and Modules #
#######################

module RLTK
	module Lexers
		class Calculator < Lexer
			
			#################
			# Default State #
			#################
			
			rule(/\+/)	{ :PLS }
			rule(/-/)		{ :SUB }
			rule(/\*/)	{ :MUL }
			rule(/\//)	{ :DIV }
			
			rule(/\(/)	{ :LPAREN }
			rule(/\)/)	{ :RPAREN }
			
			rule(/[0-9]+/)	{ |t| [:NUM, t.to_i] }
			
			rule(/\s/)
		end
	end
end
